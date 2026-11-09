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

    /// Directions in Maps to an event's place.
    static func directions(to point: MapPoint) -> URL? {
        URL(string: "https://maps.apple.com/?daddr=\(point.latitude),\(point.longitude)")
    }
}

/// Sizes shared by the Calendar and To do lists.
enum AgendaMetrics {
    /// Events and to-dos sit a size below day names.
    static let itemFont = Font.subheadline
    /// The open card reaches this far past the text on each side, so its text lines up with the list.
    static let cardInset: CGFloat = 12
}

/// A day in the Calendar or To do list: a gray dash, then the day's name in semibold.
/// Days after the first sit a little further from the one above.
struct DayHeader: View {
    static let firstTopPadding: CGFloat = 5

    var title: String
    var isFirst = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("–")
                .foregroundStyle(Theme.secondary)
                .frame(width: DashColumn.width, alignment: .leading)
                .accessibilityHidden(true)
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, isFirst ? Self.firstTopPadding : 10)
        .padding(.bottom, 1)
        .accessibilityAddTraits(.isHeader)
    }
}

/// "N more events" at the end of a cut-off day: plain gray, no underline. A tap fills in the rest.
struct MoreLine: View {
    var count: Int
    /// "event" or "item".
    var noun: String
    /// Indent, to line up with the titles above.
    var leading: CGFloat = 0
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(count) more \(count == 1 ? noun : noun + "s")")
                .font(AgendaMetrics.itemFont)
                .foregroundStyle(Theme.secondary)
                .padding(.leading, leading)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(StillButtonStyle())
        .accessibilityHint("Shows the rest")
    }
}

/// The footer under Calendar and To do, like News: "N more events this week" then Show all,
/// Show less once everything is showing, or "No other events this week" when nothing waits.
struct AgendaFooter: View {
    var hidden: Int
    /// e.g. "more events this week".
    var phrase: (Int) -> String
    /// e.g. "No other events this week".
    var empty: String
    var showsAll: Bool
    var toggle: () -> Void

    var body: some View {
        // Spaced and dotted the same as the line under News.
        HStack(spacing: 6) {
            if hidden > 0 {
                Text("\(hidden) \(phrase(hidden))")
                    .foregroundStyle(Theme.secondary)
                Text("·")
                    .foregroundStyle(Theme.secondary)
                    .accessibilityHidden(true)
                TextLink("Show all", action: toggle)
            } else if showsAll {
                TextLink("Show less", action: toggle)
            } else {
                Text(empty)
                    .foregroundStyle(Theme.secondary)
                    .padding(.vertical, 4)
            }
        }
        .font(.subheadline)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// The lighter card an open event or to-do sits on, a shade above the page like an open headline.
    /// Its text lines up with the list; the card reaches a little past it on both sides.
    func agendaCard() -> some View {
        padding(.horizontal, AgendaMetrics.cardInset)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.expandedFill)
                    .shadow(color: Theme.expandedShadow, radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.expandedRing, lineWidth: 1)
                    )
            }
            .padding(.horizontal, -AgendaMetrics.cardInset)
            .padding(.top, 4)
            .padding(.bottom, 6)
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
