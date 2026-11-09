import Foundation

/// Whether the app may read Calendar or Reminders.
public enum AccessState: Sendable, Equatable {
    /// Not asked yet.
    case notAsked
    case granted
    /// Declined, restricted, or write-only. The section explains and offers Settings.
    case denied
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
    /// Events from every calendar on the device, including shared and subscribed ones.
    func events(in range: ClosedRange<Date>) -> [CalendarEntry]
    /// Every open reminder, in every list.
    func incompleteReminders() async -> [TodoEntry]
    /// Checks a to-do off in Reminders, or back on.
    func setCompleted(_ completed: Bool, todoID: String) throws
}
