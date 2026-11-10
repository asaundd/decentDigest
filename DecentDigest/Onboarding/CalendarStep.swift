import DigestCore
import SwiftUI
import UIKit

/// Step 2: Calendar and Reminders. One Allow link per app; once allowed, that app's calendars or
/// lists open underneath, all ticked, and a tap leaves one off the page.
struct CalendarStep: View {
    var agenda: AgendaModel
    var back: () -> Void
    var skip: () -> Void
    var next: () -> Void

    var body: some View {
        OnboardingStep(
            number: 2,
            title: "Calendar and To do",
            intro: "Show your upcoming events and to-dos from the Apple Calendar and Reminders apps, if you use them.",
            note: "Your events and to-dos stay in Calendar and Reminders and are never copied or shared.",
            canContinue: agenda.calendarAccess == .granted || agenda.remindersAccess == .granted,
            skipQuestion: agenda.calendarAccess == .granted || agenda.remindersAccess == .granted ? SkipQuestion(
                title: "Skip Calendar and To do?",
                message: "Your events and to-dos won't show on the digest. You can turn them on later in Settings.",
                confirm: "Skip",
                destructive: false
            ) : nil,
            back: back,
            skip: skip,
            next: next
        ) {
            VStack(alignment: .leading, spacing: 0) {
                AppAccessRow(
                    appName: "Calendar",
                    waiting: "Events from your calendars",
                    allowed: "Hide any you don't want to see.",
                    access: agenda.calendarAccess,
                    request: { await agenda.requestCalendarAccess() }
                )
                if agenda.calendarAccess == .granted {
                    AgendaListPicker(lists: agenda.calendars, excluded: agenda.excludedCalendarIDs, noun: "calendar") { id, included in
                        Task { await agenda.setIncluded(included, calendar: id) }
                    }
                }
                AppAccessRow(
                    appName: "Reminders",
                    waiting: "To-dos from your lists",
                    allowed: "Hide any lists you don't want to see.",
                    access: agenda.remindersAccess,
                    request: { await agenda.requestRemindersAccess() }
                )
                .padding(.top, 10)
                if agenda.remindersAccess == .granted {
                    AgendaListPicker(lists: agenda.reminderLists, excluded: agenda.excludedListIDs, noun: "list") { id, included in
                        Task { await agenda.setIncluded(included, list: id) }
                    }
                }
            }
        }
    }
}

/// An app the digest reads from, with Allow (iOS then asks), ✓ Allowed, or Open Settings ↗ once declined.
struct AppAccessRow: View {
    var appName: String
    /// The gray line before access is on.
    var waiting: String
    /// The gray line once access is on.
    var allowed: String
    var access: AccessState
    var request: @MainActor () async -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ChoiceRow(title: appName, subtitle: subtitle, emphasized: true) {
            switch access {
            case .notAsked:
                TextLink("Allow") { Task { await request() } }
                    .accessibilityLabel("Allow \(appName)")
                    .accessibilityHint("Asks for access to \(appName)")
            case .granted:
                DoneNote(text: "Allowed")
            case .denied:
                TextLink("Open Settings ↗") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .accessibilityHint("Access can be turned on for Decent digest in the Settings app")
            }
        }
    }

    private var subtitle: String {
        switch access {
        case .notAsked: waiting
        case .granted: allowed
        case .denied: "\(appName) access is off for Decent digest."
        }
    }
}

/// Calendars or Reminders lists, all shown to start, as a dashed list in a slightly smaller, lighter
/// type than the app above them. Each has a link that says what a tap does:
/// Hide, or Show once hidden, when the name turns gray and it stays off the digest. Used in setup and,
/// grouped by account, in Settings.
struct AgendaListPicker: View {
    var lists: [AgendaList]
    var excluded: Set<String>
    /// "calendar" or "list", for VoiceOver.
    var noun: String
    /// Groups lists under their account ("iCloud", "Google") instead of naming it on each row.
    var grouped = false
    var setIncluded: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if grouped {
                ForEach(groups, id: \.name) { group in
                    ListHeading(group.name)
                    ForEach(group.lists) { list in
                        row(list, note: nil)
                    }
                }
            } else {
                ForEach(lists) { list in
                    row(list, note: list.note)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var groups: [(name: String, lists: [AgendaList])] {
        var order: [String] = []
        var byName: [String: [AgendaList]] = [:]
        for list in lists {
            let name = list.note ?? "Other"
            if byName[name] == nil { order.append(name) }
            byName[name, default: []].append(list)
        }
        return order.map { ($0, byName[$0] ?? []) }
    }

    private func row(_ list: AgendaList, note: String?) -> some View {
        let included = !excluded.contains(list.id)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("–")
                    .foregroundStyle(Theme.secondary)
                    .frame(width: DashColumn.width, alignment: .leading)
                    .accessibilityHidden(true)
                Text(list.title)
                    .font(.callout)
                    .foregroundStyle(included ? Theme.itemInk : Theme.secondary)
                    .padding(.trailing, 8)
                if let note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if included {
                    QuietLink("Hide") { setIncluded(list.id, false) }
                        .accessibilityLabel("Hide \(list.title)")
                        .accessibilityHint("Leaves this \(noun) off your digest")
                } else {
                    TextLink("Show") { setIncluded(list.id, true) }
                        .accessibilityLabel("Show \(list.title)")
                        .accessibilityHint("Puts this \(noun) back on your digest")
                }
            }
            .animation(nil, value: included)
        }
        .padding(.vertical, 4)
    }
}
