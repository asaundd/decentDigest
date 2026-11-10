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
            back: back,
            skip: skip,
            next: next
        ) {
            VStack(alignment: .leading, spacing: 0) {
                AppAccessRow(
                    appName: "Calendar",
                    waiting: "Events from your calendars",
                    allowed: "Untick any you don't want to see.",
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
                    allowed: "Untick any lists you don't want to see.",
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
        ChoiceRow(title: appName, subtitle: subtitle) {
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
                .accessibilityHint("Access can be turned on for Decent in the Settings app")
            }
        }
    }

    private var subtitle: String {
        switch access {
        case .notAsked: waiting
        case .granted: allowed
        case .denied: "\(appName) access is off for Decent."
        }
    }
}

/// Calendars or Reminders lists, all ticked to start. A tap leaves one off the page: it gets a dash,
/// goes gray and is struck through. Used in setup and in Settings.
struct AgendaListPicker: View {
    var lists: [AgendaList]
    var excluded: Set<String>
    /// "calendar" or "list", for VoiceOver.
    var noun: String
    var setIncluded: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lists) { list in
                let included = !excluded.contains(list.id)
                Button {
                    setIncluded(list.id, !included)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(included ? "✓" : "–")
                            .foregroundStyle(included ? Theme.ink : Theme.secondary)
                            .frame(width: DashColumn.width + 4, alignment: .leading)
                        Text(list.title)
                            .strikethrough(!included, color: Theme.secondary)
                            .foregroundStyle(included ? Theme.ink : Theme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let note = list.note {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StillButtonStyle())
                .animation(nil, value: included)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(list.note.map { "\(list.title), \($0)" } ?? list.title)
                .accessibilityValue(included ? "Shown" : "Left out")
                .accessibilityHint(included ? "Leaves this \(noun) off your digest" : "Puts this \(noun) back on your digest")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.leading, 2)
        .padding(.bottom, 4)
    }
}
