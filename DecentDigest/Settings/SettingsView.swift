import DigestCore
import SwiftData
import SwiftUI
import UIKit

/// Settings, opened from the logo button at the top right of the digest. One list, like the main page
/// of Apple's Settings app: appearance, what's on the digest, then your data, then a short footer.
struct SettingsView: View {
    var agenda: AgendaModel
    var weather: WeatherModel
    var preferences: DigestPreferences
    /// Closes Settings and replays setup.
    var showWelcome: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context
    @Query(sort: \Source.sortOrder) private var sources: [Source]
    @State private var confirmsStartOver = false

    enum Page: Hashable {
        case weather, calendar, todos, news, podcasts, sync, history
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsHeader(title: "Settings", closes: true)

                    SettingsLabel("Appearance")
                        .padding(.top, 24)
                    Picker("Appearance", selection: Binding(get: { preferences.appearance }, set: { preferences.setAppearance($0) })) {
                        Text("Automatic").tag(DigestPreferences.Appearance.automatic)
                        Text("Light").tag(DigestPreferences.Appearance.light)
                        Text("Dark").tag(DigestPreferences.Appearance.dark)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    SettingsLabel("On the digest")
                        .padding(.top, 28)
                    SettingsRow(title: "Weather", value: weatherValue, page: .weather, showsArrow: weather.place?.isCurrentLocation == true && weatherValue != "Off")
                    SettingsDivider()
                    SettingsRow(title: "Calendar", value: calendarValue, page: .calendar)
                    SettingsDivider()
                    SettingsRow(title: "To do", value: todoValue, page: .todos)
                    SettingsDivider()
                    SettingsRow(title: "News", value: count(of: .news, shown: preferences.isShown(.news), one: "site", many: "sites"), page: .news)
                    SettingsDivider()
                    SettingsRow(title: "Podcasts", value: count(of: .podcast, shown: preferences.isShown(.podcasts), one: "show", many: "shows"), page: .podcasts)

                    SettingsLabel("Your data")
                        .padding(.top, 28)
                    Text("What you follow, save, and read is stored on your device and in your own iCloud. It's never shared with developers.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                    SettingsRow(title: "Cloud sync", value: ICloudStatus.isSignedIn ? "On" : "Off", page: .sync)
                    SettingsDivider()
                    SettingsRow(title: "Reading history", value: preferences.keepsReadingHistory ? "On" : "Off", page: .history)

                    SectionRule()
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsMargins()
            }
            .settingsPage()
            .navigationDestination(for: Page.self) { page in
                destination(page)
            }
        }
        .tint(Theme.accent)
        .alert("Start setup over?", isPresented: $confirmsStartOver) {
            Button("Keep my choices") { showWelcome() }
            Button("Clear my choices", role: .destructive) { startOver() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keep your choices to look them over, or clear them to set up from the beginning. Clearing unfollows every site and show and forgets your city. Saved items and reading history stay.")
        }
    }

    /// A fresh start: nothing followed, every section and list shown, no typed city. Saved items and
    /// reading history are kept.
    private func startOver() {
        for source in sources {
            Following.unfollow(source.feedURL, kind: SourceKind(rawValue: source.kind) ?? .news, in: context)
        }
        preferences.showAllSections()
        Task {
            await agenda.showAllLists()
            await weather.clearCity()
        }
        showWelcome()
    }

    // MARK: Values

    private var weatherValue: String {
        guard preferences.isShown(.weather) else { return "Off" }
        guard weather.hasPlaceSource else { return "Not set" }
        return weather.place?.name ?? weather.typedCity?.name ?? "Your location"
    }

    private var calendarValue: String {
        guard preferences.isShown(.calendar), agenda.calendarAccess == .granted else { return "Off" }
        return names(agenda.calendars, excluding: agenda.excludedCalendarIDs)
    }

    private var todoValue: String {
        guard preferences.isShown(.todos), agenda.remindersAccess == .granted else { return "Off" }
        return names(agenda.reminderLists, excluding: agenda.excludedListIDs)
    }

    private func names(_ lists: [AgendaList], excluding excluded: Set<String>) -> String {
        let shown = lists.filter { !excluded.contains($0.id) }.map(\.title)
        return shown.isEmpty ? "None" : shown.joined(separator: ", ")
    }

    private func count(of kind: SourceKind, shown: Bool, one: String, many: String) -> String {
        guard shown else { return "Off" }
        let count = sources.filter { $0.kind == kind.rawValue && !$0.isMuted }.count
        return count == 0 ? "None" : "\(count) \(count == 1 ? one : many)"
    }

    // MARK: Pages

    @ViewBuilder
    private func destination(_ page: Page) -> some View {
        switch page {
        case .weather:
            WeatherSettingsView(model: weather, preferences: preferences, inSettings: true)
        case .calendar:
            AgendaSettingsPage(agenda: agenda, preferences: preferences, kind: .calendar)
        case .todos:
            AgendaSettingsPage(agenda: agenda, preferences: preferences, kind: .todos)
        case .news:
            SettingsPage(title: "News", subtitle: "Decent digest reads RSS feeds, which most news sites and blogs publish. Follow sites by topic, or add a site you read.") {
                ShowSwitch(label: "Show news on the digest", isOn: preferenceBinding(.news))
                if preferences.isShown(.news) {
                    PlainRule(spacing: 20)
                    NewsPicker(inSettings: true)
                }
            }
        case .podcasts:
            SettingsPage(title: "Podcasts", subtitle: "New episodes of the shows you follow show in your digest and open in the Apple Podcasts app.") {
                ShowSwitch(label: "Show podcasts on the digest", isOn: preferenceBinding(.podcasts))
                if preferences.isShown(.podcasts) {
                    PlainRule(spacing: 20)
                    PodcastPicker(inSettings: true)
                }
            }
        case .sync:
            ICloudSyncPage()
        case .history:
            ReadingHistoryPage(preferences: preferences)
        }
    }

    private func preferenceBinding(_ section: DigestPreferences.Section) -> Binding<Bool> {
        Binding(get: { preferences.isShown(section) }, set: { preferences.setShown($0, section) })
    }

    // MARK: Footer

    @ViewBuilder
    private var footerLinks: some View {
        if let privacy = AppLinks.privacy {
            TextLink("Privacy") { openURL(privacy) }
        }
        if let feedback = AppLinks.feedback {
            TextLink("Send feedback") { openURL(feedback) }
        }
    }

    /// For testing setup again; not in release builds, where every choice can be changed in Settings.
    private var startOverLink: some View {
        TextLink("Start setup over") { confirmsStartOver = true }
            .accessibilityHint("Shows the welcome and setup again")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                LogoMark()
                    .frame(width: 28)
                Text("Decent digest \(AppVersion.short)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
            // One line, or two on a narrow screen or at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    footerLinks
                    #if DEBUG
                    startOverLink
                    #endif
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 16) { footerLinks }
                    #if DEBUG
                    startOverLink
                    #endif
                }
            }
            #if DEBUG
            // A test-only page for trying designs on the phone.
            NavigationLink {
                DesignLabView()
            } label: {
                Text("Design lab")
                    .font(Theme.actionFont)
                    .underline()
                    .foregroundStyle(Theme.accent)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderless)
            #endif
        }
    }
}

/// Where the Privacy and Send feedback links go. Left out of the footer when nil.
/// Placeholders for now: replace with the real privacy page and feedback address before release.
enum AppLinks {
    static let privacy: URL? = URL(string: "https://example.com/privacy")
    static let feedback: URL? = URL(string: "mailto:feedback@example.com?subject=Decent%20digest")
}

enum AppVersion {
    static var short: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

enum ICloudStatus {
    /// True when the device is signed in to iCloud, which is when sync runs.
    static var isSignedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}

// MARK: Pieces

/// The paper page every Settings screen sits on, with no navigation bar.
extension View {
    /// The same margins on every Settings page, so headers line up from page to page.
    func settingsMargins() -> some View {
        padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, Theme.margin)
    }

    func settingsPage() -> some View {
        scrollDismissesKeyboard(.interactively)
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .background(Theme.page.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// The top of every Settings page: ✕ (the main page, or a page opened on its own) or ‹ Settings in a
/// 44pt row, then the Georgia title and an optional gray subtitle.
struct SettingsHeader: View {
    var title: String
    var subtitle: String?
    /// ✕ instead of ‹ Settings.
    var closes = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if closes {
                    // Pulled toward the sheet's corner, so the space to its left matches the space
                    // above it (about 14pt each). The title below stays on the page margin.
                    CloseButton { dismiss() }
                        .offset(x: -10, y: 2)
                } else {
                    BackLink(title: "Settings") { dismiss() }
                }
            }
            .frame(height: 44, alignment: .leading)
            Text(title)
                .font(Theme.dateFont)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 8)
            if let subtitle {
                Text(subtitle)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
    }
}

/// ✕ in a small round button, to close Settings.
struct CloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.secondary)
                .frame(width: 36, height: 36)
                .background(Theme.fieldFill, in: Circle())
                .frame(width: 44, height: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Close")
    }
}

/// A section page in Settings: the header, a rule, then the page's switch and choices.
struct SettingsPage<Content: View>: View {
    var title: String
    var subtitle: String?
    /// ✕ instead of ‹ Settings, when the page opens on its own from the digest.
    var closes = false
    @ViewBuilder var content: Content

    @State private var keyboardShown = false

    var body: some View {
        RevealingScrollView(keyboardShown: $keyboardShown) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsHeader(title: title, subtitle: subtitle, closes: closes)
                PlainRule(spacing: 20)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .settingsMargins()
        }
        .settingsPage()
    }
}

/// A small gray label over a group of rows.
struct SettingsLabel: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.secondary)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A row on the main Settings page: the label, its value in gray, then ›.
struct SettingsRow: View {
    var title: String
    var value: String?
    var page: SettingsView.Page
    /// The small location arrow after a place that comes from the device's location.
    var showsArrow = false

    var body: some View {
        NavigationLink(value: page) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 12)
                if let value {
                    Text(value)
                        .font(.body)
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if showsArrow {
                    Image(systemName: "location")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondary)
                        .accessibilityLabel("Current location")
                }
                Text("›")
                    .font(.body)
                    .foregroundStyle(Theme.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(StillButtonStyle())
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// "Show … on the digest": a native switch, tinted gray (muted slate in dark mode).
struct ShowSwitch: View {
    var label: String
    var isOn: Binding<Bool>

    var body: some View {
        Toggle(label, isOn: isOn)
            .tint(Theme.switchOn)
    }
}

/// "Reminders access is off for Decent digest." with a way to turn it on in iOS Settings, or, once
/// allowed, "… is on" with a way to turn it off there, as for location.
struct AccessNote: View {
    var appName: String
    var isOn: Bool

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(appName) access is \(isOn ? "on" : "off") for Decent digest.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
            TextLink(isOn ? "Turn off in the Settings app ↗" : "Turn on in the Settings app ↗") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .accessibilityHint("Opens Decent digest in the Settings app")
        }
        .padding(.top, 10)
    }
}

/// Settings › Calendar or Settings › To do: the switch, then calendars or lists grouped by account,
/// each with Hide or Show.
struct AgendaSettingsPage: View {
    enum Kind { case calendar, todos }

    var agenda: AgendaModel
    var preferences: DigestPreferences
    var kind: Kind

    private var section: DigestPreferences.Section { kind == .calendar ? .calendar : .todos }
    private var access: AccessState { kind == .calendar ? agenda.calendarAccess : agenda.remindersAccess }
    private var isOn: Bool { preferences.isShown(section) && access == .granted }

    var body: some View {
        SettingsPage(
            title: kind == .calendar ? "Calendar" : "To do",
            subtitle: kind == .calendar
                ? "Show your upcoming events from the Apple Calendar app."
                : "Show your to-dos from the Apple Reminders app."
        ) {
            ShowSwitch(
                label: kind == .calendar ? "Show calendar on the digest" : "Show to-dos on the digest",
                isOn: Binding(get: { isOn }, set: { turnOn in setShown(turnOn) })
            )
            .disabled(access == .denied)
            if access == .denied {
                AccessNote(appName: kind == .calendar ? "Calendar" : "Reminders", isOn: false)
            } else if access == .granted {
                AccessNote(appName: kind == .calendar ? "Calendar" : "Reminders", isOn: true)
            }
            if isOn {
                PlainRule(spacing: 20)
                if kind == .calendar {
                    AgendaListPicker(lists: agenda.calendars, excluded: agenda.excludedCalendarIDs, noun: "calendar", grouped: true) { id, included in
                        Task { await agenda.setIncluded(included, calendar: id) }
                    }
                } else {
                    AgendaListPicker(lists: agenda.reminderLists, excluded: agenda.excludedListIDs, noun: "list", grouped: true) { id, included in
                        Task { await agenda.setIncluded(included, list: id) }
                    }
                }
            }
        }
    }

    /// Turning the switch on when the app never asked shows the iOS question first.
    private func setShown(_ shown: Bool) {
        guard shown else {
            preferences.setShown(false, section)
            return
        }
        if access == .granted {
            preferences.setShown(true, section)
            return
        }
        Task {
            if kind == .calendar {
                await agenda.requestCalendarAccess()
            } else {
                await agenda.requestRemindersAccess()
            }
            preferences.setShown(access == .granted, section)
        }
    }
}

/// Settings › Cloud sync (iCloud): whether it's on, how to change that, and what it covers.
struct ICloudSyncPage: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        SettingsPage(title: "Cloud sync", subtitle: "Decent digest keeps what you follow, save, and read in your own iCloud, so it's the same on each device you use and comes back on a new one.") {
            ChoiceRow(title: "Sync", subtitle: "On when you're signed in to iCloud.") {
                Text(ICloudStatus.isSignedIn ? "On" : "Off")
                    .foregroundStyle(Theme.secondary)
            }
            Text("Only you can see this data. To stop syncing, open the Settings app, tap your name, then iCloud, and turn off Decent digest.")
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            TextLink("Open the Settings app ↗") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .padding(.top, 6)
            ListHeading("What syncs")
            VStack(alignment: .leading, spacing: 6) {
                DashLine("The sites and shows you follow")
                DashLine("Your saved items")
                DashLine("Your reading history")
            }
            Text("Your events and to-dos sync through the Apple Calendar and Reminders apps, not the Decent digest app. Each device fetches news items and episodes fresh.")
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
        }
    }
}

/// Settings › Reading history: a switch, what it is, and a way to clear it.
struct ReadingHistoryPage: View {
    var preferences: DigestPreferences

    @Environment(\.modelContext) private var context
    @State private var confirming = false
    @State private var cleared = false

    var body: some View {
        SettingsPage(title: "Reading history", subtitle: "Decent digest keeps a private reading history of the news and episodes you open, save, and mark relevant or not relevant.") {
            ShowSwitch(label: "Keep reading history", isOn: Binding(
                get: { preferences.keepsReadingHistory },
                set: { preferences.setKeepsReadingHistory($0) }
            ))
            PlainRule(spacing: 20)
            VStack(alignment: .leading, spacing: 8) {
                DashLine("It stays on your device and in your own iCloud, and is never shared with developers.")
                DashLine("Today it keeps your lists tidy, so news and episodes you've already opened, saved, or marked don't come back.")
                DashLine("A later update will use it, on your device, to put the news and episodes you care about most at the top.")
            }
            PlainRule(spacing: 20)
            if cleared {
                Text("Reading history cleared.")
                    .foregroundStyle(Theme.secondary)
            } else {
                TextLink("Clear reading history") { confirming = true }
            }
            Text("Your saved items stay. This can't be undone.")
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .padding(.top, 4)
        }
        .alert("Clear reading history?", isPresented: $confirming) {
            Button("Clear", role: .destructive) {
                ReadingState.clearHistory(in: context)
                cleared = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your saved items stay. This can't be undone.")
        }
    }
}
