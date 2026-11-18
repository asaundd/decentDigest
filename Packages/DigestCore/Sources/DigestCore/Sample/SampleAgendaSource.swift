import Foundation

/// Sample events and to-dos for previews. Checking off changes only this copy.
@MainActor
public final class SampleAgendaSource: AgendaSource {
    public var access: AccessState
    private var todos: [TodoEntry]
    private let entries: [CalendarEntry]

    public init(access: AccessState = .granted, now: Date = AppClock.now) {
        let digest = SampleDigest.make(now: now)
        self.access = access
        self.entries = digest.events
        self.todos = digest.todos
    }

    public func calendarAccess() -> AccessState { access }
    public func remindersAccess() -> AccessState { access }
    public func requestCalendarAccess() async -> AccessState { access }
    public func requestRemindersAccess() async -> AccessState { access }

    public func calendars() -> [AgendaList] {
        guard access == .granted else { return [] }
        return [
            AgendaList(id: "personal", title: "Personal", note: "iCloud"),
            AgendaList(id: "family", title: "Family", note: "iCloud"),
            AgendaList(id: "holidays", title: "US Holidays", note: "Subscribed"),
        ]
    }

    public func reminderLists() -> [AgendaList] {
        guard access == .granted else { return [] }
        return [
            AgendaList(id: "personal", title: "Personal", note: "iCloud"),
            AgendaList(id: "family", title: "Family", note: "iCloud"),
            AgendaList(id: "home", title: "Home", note: "iCloud"),
        ]
    }

    public func events(in range: ClosedRange<Date>) -> [CalendarEntry] {
        entries.filter { $0.start < range.upperBound && $0.end > range.lowerBound }
    }

    public func incompleteReminders() async -> [TodoEntry] {
        todos.filter { !$0.isCompleted }
    }

    public func setCompleted(_ completed: Bool, todoID: String) throws {
        guard let index = todos.firstIndex(where: { $0.id == todoID }) else { throw AgendaError.notFound }
        todos[index].isCompleted = completed
    }
}
