import DigestCore
import SwiftUI
import UIKit

/// Links that hand off to Calendar, Reminders and Settings.
enum AgendaLinks {
    /// Opens Calendar at the event's day and time.
    static func calendar(at date: Date) -> URL {
        URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)")!
    }

    /// Opens the Reminders app.
    static let reminders = URL(string: "x-apple-reminderkit://")!

    /// Opens one reminder in Reminders. If iOS doesn't take it, open the app instead.
    static func reminder(id: String) -> URL? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard let escaped = id.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "x-apple-reminderkit://REMCDReminder/\(escaped)")
    }

    /// This app's page in Settings, where Calendar and Reminders access can be turned on.
    static let settings = URL(string: UIApplication.openSettingsURLString)!
}

/// A section title with an optional action at the right end of the row.
struct SectionHeader<Action: View>: View {
    var title: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            action
        }
    }
}

/// One quiet gray line, for an empty section.
struct QuietLine: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(Theme.secondary)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// What a section shows when it can't read Calendar or Reminders: a plain explanation and the way forward.
/// A hidden section comes back by itself once access is turned on.
struct AccessNote: View {
    var access: AccessState
    /// e.g. "Calendar".
    var appName: String
    /// What the section shows once allowed, e.g. "today's events".
    var shows: String
    var request: @MainActor () async -> Void
    var hide: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch access {
            case .notAsked:
                Text("See \(shows) from \(appName) here. They stay in \(appName); nothing is copied.")
                    .foregroundStyle(Theme.secondary)
                TextLink("Allow access") { Task { await request() } }
                    .accessibilityHint("Asks for access to \(appName)")
            case .denied:
                Text("\(appName) access is off, so \(shows) can't show here.")
                    .foregroundStyle(Theme.secondary)
                HStack(spacing: 16) {
                    TextLink("Turn on in Settings ↗") { openURL(AgendaLinks.settings) }
                        .accessibilityLabel("Turn on in Settings")
                    TextLink("Hide this section", action: hide)
                }
            case .granted:
                EmptyView()
            }
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
