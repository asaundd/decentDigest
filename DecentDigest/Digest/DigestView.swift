import Combine
import DigestCore
import EventKit
import SwiftData
import SwiftUI
import UIKit

/// The main screen: one calm page with every section the user set up.
struct DigestView: View {
    /// Calendar and Reminders, read live.
    var agenda: AgendaModel
    /// The weather lines under the date.
    var weather: WeatherModel
    /// Which sections the reader set up, and whether setup is done.
    var preferences: DigestPreferences
    /// Fetches news and podcasts, or only one of them. `true` means the reader asked for it
    /// (pull to refresh, Refresh all, or News' Refresh).
    var refresh: @Sendable (Bool, SourceKind?) async -> Void = { _, _ in }
    var sectionOrder: [DigestSection] = DigestSection.allCases

    @Environment(\.scenePhase) private var scenePhase
    @Environment(NetworkStatus.self) private var network: NetworkStatus?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \SavedItem.savedAt, order: .reverse) private var saved: [SavedItem]
    @State private var panel: PanelRequest?
    @State private var showsWeatherSettings = false
    @State private var showsSettings = false
    /// Setup replayed from Start setup over in Settings.
    @State private var showsSetup = false
    /// Set when Start setup over closes Settings, so setup opens once Settings has gone.
    @State private var setupAfterSettings = false
    /// True while feeds are being checked, so News and Podcasts can say so.
    @State private var isRefreshing = false
    /// Set while only one list's feeds are checked (News' Refresh), so the other doesn't say so.
    @State private var refreshingOnly: SourceKind?
    /// Where the visible list ends on screen.
    @State private var listBottom: CGFloat = .infinity
    /// False until the launch animation lets the page show, whole.
    @State private var revealed = false
    /// How much of the launch logo is drawn, and whether it is still on screen.
    @State private var logoProgress: Double = 0
    @State private var logoOpacity: Double = 1
    @State private var showsLogo = false
    /// Empty space held at the foot of the page after a row near the bottom closes, so the page stays
    /// where it is instead of scrolling back. It goes once it is out of view.
    @State private var bottomSlack: CGFloat = 0
    /// A row closing asks the page to hold its place for a moment. It also keeps the last scroll
    /// position seen, outside of view state, so scrolling never redraws the page.
    @State private var scrollHold = ScrollHold()
    /// Set only to scroll an opened row into view, by offset. (Scrolling to a row by id made iOS keep
    /// that row's bottom pinned, so closing it later pulled the page back.)
    @State private var scrollPosition = ScrollPosition(idType: String.self)
    /// When the app last went to the background.
    @State private var leftAt: Date?
    /// Bumped to open the page fresh after a long time away: every section starts over, cards closed.
    @State private var pageEdition = 0
    /// Back sooner than this, the page is just as it was left, and new items wait for a pull to
    /// refresh. Away longer, it opens fresh, at the top, with new items in place.
    private static let freshAfter: TimeInterval = 30 * 60

    var body: some View {
        // A plain scrolling page. (A List re-measured expanded rows late, which made titles jump.)
        ScrollViewReader { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, Theme.margin)
                        .digestRow()
                    ForEach(sectionOrder) { section in
                        if isShown(section) {
                            SectionRule()
                                .digestRow()
                            sectionView(section) { _, bottom in reveal(bottom: bottom) }
                        }
                    }
                    SectionRule()
                        .digestRow()
                    footer
                        .padding(.bottom, Theme.margin)
                        .digestRow()
                }
                .id(pageEdition)
                .opacity(revealed ? 1 : 0)
                .padding(.bottom, bottomSlack)
            }
            // The held space shrinks as soon as less of it is needed, so it never shows as a gap.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height
                    - geometry.contentInsets.bottom - geometry.contentSize.height
            } action: { _, overhang in
                scrollHold.overhang = overhang
                trimSlack()
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offset in
                scrollHold.offset = offset
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentInsets.top
            } action: { _, inset in
                scrollHold.topInset = inset
            }
            .scrollPosition($scrollPosition)
            .environment(\.scrollHold, scrollHold)
            .onAppear {
                scrollHold.onHold = { holdPlace() }
                scrollHold.scrollBy = { delta in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollPosition.scrollTo(y: scrollHold.offset + delta)
                    }
                }
            }
            // Pull to refresh on the digest only. Set here, on the page's own scroll view, so it
            // doesn't reach the scroll views in Settings and setup, where a pull down closes the sheet.
            .refreshable {
                await refreshAll()
            }
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .background(
                LinearGradient(colors: [Theme.pageTintTop, Theme.pageTintBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY
            } action: { bottom in
                listBottom = bottom
            }
        }
        // Settings: the round logo button, pinned at the top right while the page scrolls under it.
        .overlay(alignment: .topTrailing) {
            SettingsButton { showsSettings = true }
                .padding(.trailing, 16)
                .padding(.top, 4)
                .opacity(revealed ? 1 : 0)
        }
        // The launch logo draws itself at the center, then fades as the page fades in.
        .overlay {
            if showsLogo {
                LaunchLogo(progress: logoProgress)
                    .opacity(logoOpacity)
            }
        }
        .task { await playLaunch() }
        // On first launch the page stays hidden under setup, then fades in when setup is done.
        .onChange(of: preferences.hasFinishedSetup) { _, finished in
            guard finished, !revealed else { return }
            withAnimation(.easeOut(duration: 0.25)) { revealed = true }
        }
        .blur(radius: panel == nil ? 0 : 2)
        .overlay { ArticlePanelHost(panel: $panel) }
        .sheet(isPresented: $showsSettings, onDismiss: {
            if setupAfterSettings {
                setupAfterSettings = false
                showsSetup = true
            }
        }) {
            SettingsView(agenda: agenda, weather: weather, preferences: preferences) {
                setupAfterSettings = true
                showsSettings = false
            }
        }
        .fullScreenCover(isPresented: setupBinding) {
            OnboardingFlow(agenda: agenda, weather: weather, preferences: preferences) {
                showsSetup = false
                Task { await reloadAgenda() }
                Task { await reloadWeather() }
                Task { await runRefresh(force: false) }
            }
        }
        .sheet(isPresented: $showsWeatherSettings) {
            // In a navigation stack so the search box's Done key above the keyboard shows.
            NavigationStack {
                WeatherSettingsView(model: weather, preferences: preferences)
            }
        }
        .onChange(of: preferences.appearance, initial: true) { _, appearance in
            AppearanceStyle.apply(appearance)
        }
        // Back online: finish what couldn't be checked while offline, so the offline notes clear.
        // Only what failed is checked again; nothing else is fetched.
        .onChange(of: network?.isOffline) { wasOffline, isOffline in
            guard wasOffline == true, isOffline == false else { return }
            let missed = SourceKind.allCases.filter { UserDefaults.standard.bool(forKey: NewsRefresher.offlineKey($0)) }
            if !missed.isEmpty {
                Task { await runRefresh(force: true, only: missed.count == 1 ? missed[0] : nil) }
            }
            if weather.isOffline {
                Task { await reloadWeather(force: true) }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Checked-off to-dos still showing leave when the app goes away.
            if phase == .background {
                agenda.finishAllChecked()
                leftAt = .now
            }
            guard phase == .active else { return }
            Task { await reloadAgenda() }
            Task { await reloadWeather() }
            // Nothing moves on a page the reader is in the middle of: back soon, new items wait for
            // a pull to refresh; back after a long time, the page opens fresh with them in place.
            if let left = leftAt {
                leftAt = nil
                guard Date.now.timeIntervalSince(left) >= Self.freshAfter else { return }
                startFresh()
            }
            Task { await runRefresh(force: false) }
        }
        // Edits made in Calendar or Reminders, or checking off here, show within moments.
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged).receive(on: RunLoop.main)) { _ in
            Task { await reloadAgenda() }
        }
        // A new day, or a time zone change.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification).receive(on: RunLoop.main)) { _ in
            Task { await reloadAgenda() }
        }
    }

    /// On a cold launch: the logo draws itself (about 0.5s) while the phone's own reads finish
    /// (Calendar and Reminders; stored news and the cached forecast are already there), then the logo
    /// fades as the page fades in, whole (about 0.25s). A read still going after 0.6s shows placeholder
    /// bars in its section. With Reduce Motion on, the page just fades in. On first launch the welcome
    /// page plays its own version, and the page stays hidden under setup until it is done, so nothing
    /// shows while setup slides up.
    private func playLaunch() async {
        guard !revealed, preferences.hasFinishedSetup else { return }
        guard !LaunchIntro.hasPlayed else {
            revealed = true
            return
        }
        LaunchIntro.hasPlayed = true
        let start = ContinuousClock.now
        if !reduceMotion {
            showsLogo = true
            withAnimation(.easeInOut(duration: LaunchLogo.drawDuration)) { logoProgress = 1 }
            try? await Task.sleep(for: .seconds(LaunchLogo.drawDuration))
        }
        while !agenda.hasLoaded, ContinuousClock.now - start < .milliseconds(600) {
            try? await Task.sleep(for: .milliseconds(30))
        }
        withAnimation(.easeOut(duration: 0.25)) {
            revealed = true
            logoOpacity = 0
        }
        try? await Task.sleep(for: .seconds(0.25))
        showsLogo = false
    }

    /// When a row near the foot of the page closes or leaves, the page gets shorter and iOS would
    /// scroll it back. Before the change lands, plenty of empty space goes at the foot of the page, in
    /// the same update, so the page can't move; once the row has settled, the space shrinks to just
    /// what keeps the screen where it is, and it goes as the reader scrolls up.
    private func holdPlace() {
        scrollHold.holdsUntil = .now.addingTimeInterval(0.6)
        // Never animated, even when the row's own change is, so the space is there before the row
        // gets shorter.
        setSlack(bottomSlack + 2_000)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.65))
            trimSlack()
        }
    }

    private func trimSlack() {
        guard bottomSlack > 0, Date.now >= scrollHold.holdsUntil else { return }
        let needed = max(0, (bottomSlack + scrollHold.overhang).rounded(.up))
        // Only when it changes by a point or more, so scrolling through the space doesn't redraw
        // the page on every frame.
        if needed < bottomSlack - 0.5 { setSlack(needed) }
    }

    /// Back after a long time away: the page starts over at the top, every card closed and every
    /// list folded, like a cold launch.
    private func startFresh() {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            panel = nil
            bottomSlack = 0
            pageEdition += 1
            scrollPosition.scrollTo(edge: .top)
        }
    }

    private func setSlack(_ slack: CGFloat) {
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { bottomSlack = slack }
    }

    private func reloadAgenda() async {
        await agenda.reload()
    }

    private func reloadWeather(force: Bool = false) async {
        await weather.reload(force: force)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Decent digest")
                .font(Theme.wordmarkFont)
                .foregroundStyle(Theme.secondary)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(Theme.dateFont)
                .accessibilityAddTraits(.isHeader)
                // Clear of the Settings button at the top right; a long date wraps instead.
                .padding(.trailing, 52)
                .fixedSize(horizontal: false, vertical: true)
            if network?.isOffline == true {
                OfflineBar()
                    .padding(.top, 8)
            }
            // Weather is the page's opening lines, not a titled section.
            if preferences.isShown(.weather) {
                WeatherLines(model: weather) { showsWeatherSettings = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Setup shows on first launch, and again from Start setup over in Settings.
    private var setupBinding: Binding<Bool> {
        Binding(
            get: { !preferences.hasFinishedSetup || showsSetup },
            set: { showsSetup = $0 }
        )
    }

    /// A section skipped in setup, or whose access is off, isn't shown at all.
    private func isShown(_ section: DigestSection) -> Bool {
        switch section {
        // Saved appears only once something is saved.
        case .saved: !saved.isEmpty
        case .calendar: preferences.isShown(.calendar) && agenda.calendarAccess == .granted
        case .todos: preferences.isShown(.todos) && agenda.remindersAccess == .granted
        case .news: preferences.isShown(.news)
        case .podcasts: preferences.isShown(.podcasts)
        }
    }

    /// Fetches news and podcasts, or only `kind`. The page draws right away; items appear as each
    /// feed arrives.
    private func runRefresh(force: Bool, only kind: SourceKind? = nil) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshingOnly = kind
        await refresh(force, kind)
        isRefreshing = false
        refreshingOnly = nil
    }

    /// Pull to refresh, and Refresh all at the foot of the page: everything on the page, read again.
    private func refreshAll() async {
        await reloadAgenda()
        await reloadWeather(force: true)
        await runRefresh(force: true)
    }

    private func refreshes(_ kind: SourceKind) -> Bool {
        isRefreshing && (refreshingOnly == nil || refreshingOnly == kind)
    }

    /// Scrolls an expanded row up only when its bottom is hidden, so rows higher on the screen stay put.
    private func reveal(bottom: CGFloat) {
        guard bottom > listBottom - 8 else { return }
        let target = scrollHold.offset + bottom - listBottom
        withAnimation(.easeInOut(duration: 0.25)) {
            scrollPosition.scrollTo(y: target)
        }
    }

    @ViewBuilder
    private func sectionView(_ section: DigestSection, reveal: @escaping (String, CGFloat) -> Void) -> some View {
        switch section {
        case .calendar:
            CalendarSectionView(model: agenda)
                .digestRow()
        case .todos:
            // Rows set their own margins, so swipes can reach the page's edge.
            TodosSectionView(model: agenda)
        case .news:
            FeedListSection(kind: .news, isRefreshing: refreshes(.news), refresh: {
                Task { await runRefresh(force: true, only: .news) }
            }, panel: $panel, reveal: reveal)
        case .podcasts:
            FeedListSection(kind: .podcast, isRefreshing: refreshes(.podcast), panel: $panel, reveal: reveal)
        case .saved:
            SavedSectionView(saved: saved, panel: $panel, reveal: reveal)
        }
    }

    /// The end of the page, on one line: Refresh all on the left, the weather credit on the right.
    /// No logo or name, since the Dd button sits at the top. On a narrow screen or at large text
    /// sizes the credit drops to a second line.
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                refreshPart
                Spacer(minLength: 0)
                weatherCredit
            }
            VStack(alignment: .leading, spacing: 12) {
                refreshPart
                weatherCredit
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Left out while offline; the bar under the date says why.
    @ViewBuilder
    private var refreshPart: some View {
        if network?.isOffline != true {
            refreshAllLink
        }
    }

    /// Does what pulling down at the top does, for a reader at the foot of the page. Reads
    /// "Refreshing…" in gray while anything is being checked.
    @ViewBuilder
    private var refreshAllLink: some View {
        if isRefreshing {
            Text("Refreshing…")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .fixedSize()
                .padding(.vertical, 4)
        } else {
            FooterLink("Refresh all", still: true) {
                Task { await refreshAll() }
            }
            .accessibilityHint("Checks for new events, to-dos, weather, news and episodes")
        }
    }

    /// WeatherKit asks for the Apple Weather mark and a link to its legal page.
    @ViewBuilder
    private var weatherCredit: some View {
        if let credit = weather.credit, weather.report != nil, !weather.isSample, preferences.isShown(.weather) {
            WeatherCreditLine(credit: credit)
                .fixedSize()
        }
    }
}

/// Under the date while the device has no connection: one line on the same pale slate as the event
/// happening now. Everything on the page is what was saved; nothing is fetched until it is back.
struct OfflineBar: View {
    var body: some View {
        Text("You're offline. Showing only what's saved on this device.")
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The tint reaches past the text on both sides, so the words line up with the page's.
            .padding(.horizontal, 10)
            .background(Theme.nowTint, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, -10)
    }
}

extension View {
    /// Sets a row in from the page's side margins.
    func digestRow() -> some View {
        padding(.horizontal, Theme.margin)
    }
}

@MainActor
private func samplePreferences() -> DigestPreferences {
    let defaults = UserDefaults(suiteName: "preview-preferences")!
    defaults.set(true, forKey: "setup.finished")
    return DigestPreferences(defaults: defaults)
}

@MainActor
private func sampleWeather(access: AccessState = .granted) -> WeatherModel {
    WeatherModel(provider: SampleWeatherProvider(), places: SamplePlaces(access: access), defaults: UserDefaults(suiteName: "preview")!)
}

#Preview("Light") {
    DigestView(agenda: AgendaModel(source: SampleAgendaSource()), weather: sampleWeather(), preferences: samplePreferences())
        .modelContainer(DigestStore.previewContainer())
}

#Preview("Dark") {
    DigestView(agenda: AgendaModel(source: SampleAgendaSource()), weather: sampleWeather(), preferences: samplePreferences())
        .modelContainer(DigestStore.previewContainer())
        .preferredColorScheme(.dark)
}

#Preview("Access declined") {
    DigestView(agenda: AgendaModel(source: SampleAgendaSource(access: .denied)), weather: sampleWeather(access: .denied), preferences: samplePreferences())
        .modelContainer(DigestStore.previewContainer())
}
