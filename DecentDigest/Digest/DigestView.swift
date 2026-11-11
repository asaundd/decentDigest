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
    /// Fetches news and podcasts. `true` means the reader pulled to refresh.
    var refresh: @Sendable (Bool) async -> Void = { _ in }
    var sectionOrder: [DigestSection] = DigestSection.allCases

    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \SavedItem.savedAt, order: .reverse) private var saved: [SavedItem]
    @State private var panel: PanelRequest?
    @State private var showsWeatherSettings = false
    @State private var showsSettings = false
    /// Setup replayed from Show welcome again in Settings.
    @State private var showsSetup = false
    /// Set when Show welcome again closes Settings, so setup opens once Settings has gone.
    @State private var setupAfterSettings = false
    /// True while feeds are being checked, so News can say so.
    @State private var isRefreshing = false
    /// Where the visible list ends on screen.
    @State private var listBottom: CGFloat = .infinity

    var body: some View {
        // A plain scrolling page. (A List re-measured expanded rows late, which made titles jump.)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, Theme.margin)
                        .digestRow()
                    ForEach(sectionOrder) { section in
                        if isShown(section) {
                            SectionRule()
                                .digestRow()
                            sectionView(section) { id, bottom in reveal(id, bottom: bottom, with: proxy) }
                        }
                    }
                    SectionRule()
                        .digestRow()
                    footer
                        .padding(.bottom, Theme.margin)
                        .digestRow()
                }
            }
            // Pull to refresh on the digest only. Set here, on the page's own scroll view, so it
            // doesn't reach the scroll views in Settings and setup, where a pull down closes the sheet.
            .refreshable {
                await agenda.reload()
                await weather.reload(force: true)
                await runRefresh(force: true)
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
                Task { await agenda.reload() }
                Task { await weather.reload() }
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
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Checked-off to-dos still showing leave when the app goes away.
            if phase == .background { agenda.finishAllChecked() }
            guard phase == .active else { return }
            Task { await agenda.reload() }
            Task { await weather.reload() }
            Task { await runRefresh(force: false) }
        }
        // Edits made in Calendar or Reminders, or checking off here, show within moments.
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged).receive(on: RunLoop.main)) { _ in
            Task { await agenda.reload() }
        }
        // A new day, or a time zone change.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification).receive(on: RunLoop.main)) { _ in
            Task { await agenda.reload() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Decent digest")
                .font(Theme.wordmarkFont)
                .foregroundStyle(Theme.secondary)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(Theme.dateFont)
                .accessibilityAddTraits(.isHeader)
            // Weather is the page's opening lines, not a titled section.
            if preferences.isShown(.weather) {
                WeatherLines(model: weather) { showsWeatherSettings = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Setup shows on first launch, and again from Show welcome again in Settings.
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

    /// Fetches news. The page draws right away; headlines appear as each feed arrives.
    private func runRefresh(force: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await refresh(force)
        isRefreshing = false
    }

    /// Scrolls an expanded row up only when its bottom is hidden, so rows higher on the screen stay put.
    private func reveal(_ id: String, bottom: CGFloat, with proxy: ScrollViewProxy) {
        guard bottom > listBottom - 8 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(id, anchor: .bottom)
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
            FeedListSection(kind: .news, isRefreshing: isRefreshing, refresh: { await runRefresh(force: true) }, panel: $panel, reveal: reveal)
        case .podcasts:
            FeedListSection(kind: .podcast, isRefreshing: isRefreshing, refresh: { await runRefresh(force: true) }, panel: $panel, reveal: reveal)
        case .saved:
            SavedSectionView(saved: saved, panel: $panel, reveal: reveal)
        }
    }

    /// The end of the page, on one line: the small logo and name, like the foot of Settings, then the
    /// weather credit. On a narrow screen or at large text sizes the credit drops to a second line.
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                appName
                weatherCredit
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 12) {
                appName
                weatherCredit
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appName: some View {
        HStack(alignment: .center, spacing: 8) {
            LogoMark(color: Theme.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text("Decent digest")
                .font(Theme.wordmarkFont)
                .foregroundStyle(Theme.secondary)
                .fixedSize()
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
