import DigestCore
import SwiftUI

/// Links that hand off to Calendar and Reminders.
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

/// Shown in a section until the app has asked for access. Once onboarding asks, this is only a fallback.
/// A section whose access was declined isn't shown at all; it is added back from Settings.
struct AccessNote: View {
    /// e.g. "Calendar".
    var appName: String
    /// What the section shows once allowed, e.g. "today's events".
    var shows: String
    var request: @MainActor () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("See \(shows) from \(appName) here. They stay in \(appName); nothing is copied.")
                .foregroundStyle(Theme.secondary)
            TextLink("Allow access") { Task { await request() } }
                .accessibilityHint("Asks for access to \(appName)")
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
