import Foundation

/// Whether the app may read Calendar or Reminders.
public enum AccessState: Sendable, Equatable {
    /// Not asked yet.
    case notAsked
    case granted
    /// Declined, restricted, or write-only. The section explains and offers Settings.
    case denied
}

/// A calendar or a Reminders list, for leaving some off the page.
public struct AgendaList: Sendable, Identifiable, Hashable {
    public var id: String
    public var title: String
    /// Where it comes from, in a word or two: "iCloud", "Google", "Subscribed".
    public var note: String?

    public init(id: String, title: String, note: String? = nil) {
        self.id = id
        self.title = title
        self.note = note
    }
}

public enum AgendaError: Error, Equatable {
    /// The reminder is no longer in Reminders.
    case notFound
}

/// Where the Calendar and To-dos sections read from. EventKit on the device; a fixed sample in previews and tests.
@MainActor
public protocol AgendaSource: AnyObject {
    func calendarAccess() -> AccessState
    func remindersAccess() -> AccessState
    func requestCalendarAccess() async -> AccessState
    func requestRemindersAccess() async -> AccessState
    /// Every calendar on the device, including shared and subscribed ones.
    func calendars() -> [AgendaList]
    /// Every Reminders list.
    func reminderLists() -> [AgendaList]
    /// Events from every calendar on the device, including shared and subscribed ones.
    func events(in range: ClosedRange<Date>) -> [CalendarEntry]
    /// Every open reminder, in every list.
    func incompleteReminders() async -> [TodoEntry]
    /// Checks a to-do off in Reminders, or back on.
    func setCompleted(_ completed: Bool, todoID: String) throws
}

extension AgendaSource {
    public func calendars() -> [AgendaList] { [] }
    public func reminderLists() -> [AgendaList] { [] }
}
