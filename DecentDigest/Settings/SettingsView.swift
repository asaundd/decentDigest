import DigestCore
import SwiftData
import SwiftUI
import UIKit

/// Settings, opened from the logo button at the top right of the digest. One list, like the main page
/// of Apple's Settings app: what's on the digest, then your data, then a short footer.
struct SettingsView: View {
    var agenda: AgendaModel
    var weather: WeatherModel
    var preferences: DigestPreferences
    /// Closes Settings and replays setup.
    var showWelcome: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \Source.sortOrder) private var sources: [Source]

    enum Page: Hashable {
        case weather, calendar, todos, news, podcasts, sync, history
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextLink("Done") { dismiss() }
                        Spacer()
                    }
                    Text("Settings")
                        .font(Theme.dateFont)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 12)

                    SettingsLabel("On the digest")
                        .padding(.top, 20)
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
                    Text("Kept on your device and in your own iCloud. Never sent to us.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                    SettingsRow(title: "iCloud sync", value: ICloudStatus.isSignedIn ? "On" : "Off", page: .sync)
                    SettingsDivider()
                    SettingsRow(title: "Reading history", value: nil, page: .history)

                    SectionRule()
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.margin)
            }
            .settingsPage()
            .navigationDestination(for: Page.self) { page in
                destination(page)
            }
        }
        .tint(Theme.accent)
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
            WeatherSettingsView(model: weather, preferences: preferences, backTitle: "Settings")
        case .calendar:
            AgendaSettingsPage(agenda: agenda, preferences: preferences, kind: .calendar)
        case .todos:
            AgendaSettingsPage(agenda: agenda, preferences: preferences, kind: .todos)
        case .news:
            SettingsPage(title: "News") {
                ShowSwitch(label: "Show news on the digest", isOn: preferenceBinding(.news))
                if preferences.isShown(.news) {
                    PlainRule(spacing: 20)
                    NewsPicker(inSettings: true)
                }
            }
        case .podcasts:
            SettingsPage(title: "Podcasts") {
                ShowSwitch(label: "Show podcasts on the digest", isOn: preferenceBinding(.podcasts))
                if preferences.isShown(.podcasts) {
                    PlainRule(spacing: 20)
                    PodcastPicker(inSettings: true)
                }
            }
        case .sync:
            ICloudSyncPage()
        case .history:
            ReadingHistoryPage()
        }
    }

    private func preferenceBinding(_ section: DigestPreferences.Section) -> Binding<Bool> {
        Binding(get: { preferences.isShown(section) }, set: { preferences.setShown($0, section) })
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                LogoMark()
                    .frame(width: 28)
                Text("Decent digest \(AppVersion.short) · Free, no ads")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
            HStack(spacing: 16) {
                if let privacy = AppLinks.privacy {
                    TextLink("Privacy") { openURL(privacy) }
                }
                if let feedback = AppLinks.feedback {
                    TextLink("Send feedback") { openURL(feedback) }
                }
                TextLink("Show welcome again", action: showWelcome)
            }
        }
    }
}

/// Where the Privacy and Send feedback links go. Left out of the footer until they are set.
enum AppLinks {
    static let privacy: URL? = nil
    static let feedback: URL? = nil
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
    func settingsPage() -> some View {
        scrollDismissesKeyboard(.interactively)
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .background(Theme.page.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// A section page in Settings: ‹ Settings, a Georgia title, an optional gray subtitle, a rule, then
/// the page's switch and choices.
struct SettingsPage<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BackLink(title: "Settings") { dismiss() }
                Text(title)
                    .font(Theme.dateFont)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 12)
                if let subtitle {
                    Text(subtitle)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
                PlainRule(spacing: 20)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, Theme.margin)
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
            .font(.subheadline)
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

/// "Show … on the digest": a native switch, tinted gray rather than slate.
struct ShowSwitch: View {
    var label: String
    var isOn: Binding<Bool>

    var body: some View {
        Toggle(label, isOn: isOn)
            .tint(Theme.secondary)
    }
}

/// "Reminders access is off for Decent digest." with a way to turn it on in iOS Settings.
struct AccessOffNote: View {
    var appName: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(appName) access is off for Decent digest.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
            TextLink("Turn on in the Settings app ↗") {
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
        SettingsPage(title: kind == .calendar ? "Calendar" : "To do") {
            ShowSwitch(
                label: kind == .calendar ? "Show calendar on the digest" : "Show to-dos on the digest",
                isOn: Binding(get: { isOn }, set: { turnOn in setShown(turnOn) })
            )
            .disabled(access == .denied)
            if access == .denied {
                AccessOffNote(appName: kind == .calendar ? "Calendar" : "Reminders")
            } else if isOn {
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

/// Settings › iCloud sync: what syncs and what doesn't.
struct ICloudSyncPage: View {
    var body: some View {
        SettingsPage(title: "iCloud sync", subtitle: "Keeps what you follow, save and read in your own iCloud, so it comes back on a new device and stays the same on each device you use.") {
            ChoiceRow(title: "Sync", subtitle: "On by default when you're signed in to iCloud.") {
                Text(ICloudStatus.isSignedIn ? "On" : "Off")
                    .foregroundStyle(Theme.secondary)
            }
            ListHeading("What syncs")
            VStack(alignment: .leading, spacing: 6) {
                DashLine("The sites and shows you follow")
                DashLine("Your saved items")
                DashLine("Your reading history")
            }
            ListHeading("What doesn't")
            VStack(alignment: .leading, spacing: 6) {
                DashLine("Your calendar, to-dos and location")
                DashLine("Headlines and episodes, which each device fetches fresh")
            }
            Text("Only you can see this data. To stop syncing, open the Settings app, tap your name, then iCloud, and turn off Decent digest.")
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
        }
    }
}

/// Settings › Reading history: what it is, and a way to clear it.
struct ReadingHistoryPage: View {
    @Environment(\.modelContext) private var context
    @State private var confirming = false
    @State private var cleared = false

    var body: some View {
        SettingsPage(title: "Reading history", subtitle: "A private record of the news and episodes you open, save, and mark relevant or not relevant.") {
            VStack(alignment: .leading, spacing: 8) {
                DashLine("It stays on your device and in your own iCloud. It is never sent to us or anyone else.")
                DashLine("Today it keeps your lists tidy, so items you've dealt with don't come back.")
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
        .confirmationDialog("Clear reading history?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Clear reading history", role: .destructive) {
                ReadingState.clearHistory(in: context)
                cleared = true
            }
        } message: {
            Text("Your saved items stay. This can't be undone.")
        }
    }
}
