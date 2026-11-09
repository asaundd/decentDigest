#if canImport(EventKit)
import CoreLocation
import EventKit
import Foundation

/// Reads Calendar and Reminders through EventKit, live. Nothing read here is stored.
@MainActor
public final class EventKitSource: AgendaSource {
    private let store = EKEventStore()

    public init() {}

    // MARK: Access

    public func calendarAccess() -> AccessState {
        Self.state(EKEventStore.authorizationStatus(for: .event))
    }

    public func remindersAccess() -> AccessState {
        Self.state(EKEventStore.authorizationStatus(for: .reminder))
    }

    public func requestCalendarAccess() async -> AccessState {
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            Self.requestEvents(from: store, continuation)
        }
        store.refreshSourcesIfNecessary()
        return calendarAccess()
    }

    public func requestRemindersAccess() async -> AccessState {
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            Self.requestReminders(from: store, continuation)
        }
        store.refreshSourcesIfNecessary()
        return remindersAccess()
    }

    // MARK: Reading

    public func events(in range: ClosedRange<Date>) -> [CalendarEntry] {
        guard calendarAccess() == .granted else { return [] }
        // nil reads every calendar: the user's own, shared iCloud calendars and subscriptions.
        let predicate = store.predicateForEvents(withStart: range.lowerBound, end: range.upperBound, calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            guard event.status != .canceled, !Self.wasDeclined(event) else { return nil }
            let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
            return CalendarEntry(
                // Repeating events share an identifier, so the start time keeps each one distinct.
                id: "\(identifier)@\(Int(event.startDate.timeIntervalSince1970))",
                title: Self.cleaned(event.title) ?? "Untitled event",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                calendarName: event.calendar?.title ?? "",
                location: Self.cleaned(event.location),
                mapPoint: event.structuredLocation?.geoLocation.map {
                    MapPoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                },
                attendees: (event.attendees ?? []).compactMap { person in
                    person.isCurrentUser ? nil : Self.cleaned(person.name)
                },
                notes: Self.cleaned(event.notes)
            )
        }
    }

    public func incompleteReminders() async -> [TodoEntry] {
        guard remindersAccess() == .granted else { return [] }
        let lists = store.calendars(for: .reminder)
        let order = Dictionary(
            lists.enumerated().map { ($1.calendarIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        return await withCheckedContinuation { (continuation: CheckedContinuation<[TodoEntry], Never>) in
            Self.fetchReminders(from: store, matching: predicate, listOrder: order, continuation)
        }
    }

    // MARK: Writing back

    public func setCompleted(_ completed: Bool, todoID: String) throws {
        guard let reminder = store.calendarItem(withIdentifier: todoID) as? EKReminder else {
            throw AgendaError.notFound
        }
        reminder.isCompleted = completed
        try store.save(reminder, commit: true)
    }

    // MARK: Helpers

    private static func state(_ status: EKAuthorizationStatus) -> AccessState {
        switch status {
        case .fullAccess: .granted
        case .notDetermined: .notAsked
        case .denied, .restricted, .writeOnly: .denied
        @unknown default: .denied
        }
    }

    private static func wasDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }

    private nonisolated static func cleaned(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    // EventKit calls these completion handlers on its own queue. They are built outside the main
    // actor so Swift doesn't expect them to run there.

    private nonisolated static func requestEvents(from store: EKEventStore, _ continuation: CheckedContinuation<Bool, Never>) {
        store.requestFullAccessToEvents { granted, _ in
            continuation.resume(returning: granted)
        }
    }

    private nonisolated static func requestReminders(from store: EKEventStore, _ continuation: CheckedContinuation<Bool, Never>) {
        store.requestFullAccessToReminders { granted, _ in
            continuation.resume(returning: granted)
        }
    }

    private nonisolated static func fetchReminders(
        from store: EKEventStore,
        matching predicate: NSPredicate,
        listOrder: [String: Int],
        _ continuation: CheckedContinuation<[TodoEntry], Never>
    ) {
        _ = store.fetchReminders(matching: predicate) { reminders in
            let calendar = Calendar.current
            let todos = (reminders ?? []).map { reminder in
                let components = reminder.dueDateComponents
                return TodoEntry(
                    id: reminder.calendarItemIdentifier,
                    title: cleaned(reminder.title) ?? "Untitled to-do",
                    listName: reminder.calendar?.title ?? "",
                    due: components.flatMap { calendar.date(from: $0) },
                    dueIncludesTime: components?.hour != nil,
                    notes: cleaned(reminder.notes),
                    listOrder: reminder.calendar.flatMap { listOrder[$0.calendarIdentifier] } ?? Int.max,
                    isCompleted: reminder.isCompleted
                )
            }
            continuation.resume(returning: todos)
        }
    }
}
#endif
