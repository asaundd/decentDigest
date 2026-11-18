import Foundation
import Observation

/// Live Calendar and Reminders data for the digest. Read when the app opens and whenever
/// Calendar or Reminders change; never stored.
@MainActor
@Observable
public final class AgendaModel {
    public private(set) var calendarAccess: AccessState
    public private(set) var remindersAccess: AccessState
    /// Every event from the start of today through the week ahead.
    public private(set) var events: [CalendarEntry] = []
    /// Open to-dos the section can list, plus ones just checked off whose card is still open.
    public private(set) var todos: [TodoEntry] = []
    /// To-dos checked off whose row is still showing, struck through, so the undo arrow can bring them back.
    public private(set) var checkedIDs: Set<String> = []
    /// True once both sections have been read at least once.
    public private(set) var hasLoaded = false
    /// A short note when Reminders refused a change.
    public private(set) var problem: String?
    /// Every calendar, once Calendar access is on, for leaving some off the page.
    public private(set) var calendars: [AgendaList] = []
    /// Every Reminders list, once Reminders access is on.
    public private(set) var reminderLists: [AgendaList] = []
    /// Calendars the reader left off the page. Kept on this device, since identifiers differ between devices.
    public private(set) var excludedCalendarIDs: Set<String>
    /// Reminders lists the reader left off the page.
    public private(set) var excludedListIDs: Set<String>

    private let source: any AgendaSource
    private let now: () -> Date
    private let defaults: UserDefaults
    /// Counts reloads, so an older read that finishes late doesn't replace a newer one.
    @ObservationIgnored private var generation = 0

    public init(source: any AgendaSource, defaults: UserDefaults = .standard, now: @escaping () -> Date = { AppClock.now }) {
        self.source = source
        self.now = now
        self.defaults = defaults
        self.excludedCalendarIDs = Set(defaults.stringArray(forKey: Keys.excludedCalendars) ?? [])
        self.excludedListIDs = Set(defaults.stringArray(forKey: Keys.excludedLists) ?? [])
        self.calendarAccess = source.calendarAccess()
        self.remindersAccess = source.remindersAccess()
    }

    /// Reads Calendar and Reminders again.
    public func reload() async {
        generation += 1
        let current = generation
        calendarAccess = source.calendarAccess()
        remindersAccess = source.remindersAccess()

        let date = now()
        if calendarAccess == .granted {
            calendars = source.calendars()
            events = source.events(in: CalendarAgenda.fetchRange(now: date))
                .filter { !excludedCalendarIDs.contains($0.calendarID) }
        } else {
            calendars = []
            events = []
        }

        if remindersAccess == .granted {
            reminderLists = source.reminderLists()
            let fetched = await source.incompleteReminders()
            guard current == generation else { return }
            let included = fetched.filter { !excludedListIDs.contains($0.listID) }
            todos = keepingChecked(TodoRules.candidates(included, now: date))
        } else {
            reminderLists = []
            todos = []
            checkedIDs = []
        }
        hasLoaded = true
    }

    public func requestCalendarAccess() async {
        calendarAccess = await source.requestCalendarAccess()
        await reload()
    }

    public func requestRemindersAccess() async {
        remindersAccess = await source.requestRemindersAccess()
        await reload()
    }

    /// Puts a calendar on the page, or leaves it off.
    /// Shows every calendar and list again, for starting setup over.
    public func showAllLists() async {
        excludedCalendarIDs = []
        excludedListIDs = []
        defaults.removeObject(forKey: Keys.excludedCalendars)
        defaults.removeObject(forKey: Keys.excludedLists)
        await reload()
    }

    public func setIncluded(_ included: Bool, calendar id: String) async {
        if included { excludedCalendarIDs.remove(id) } else { excludedCalendarIDs.insert(id) }
        defaults.set(excludedCalendarIDs.sorted(), forKey: Keys.excludedCalendars)
        await reload()
    }

    /// Puts a Reminders list on the page, or leaves it off.
    public func setIncluded(_ included: Bool, list id: String) async {
        if included { excludedListIDs.remove(id) } else { excludedListIDs.insert(id) }
        defaults.set(excludedListIDs.sorted(), forKey: Keys.excludedLists)
        await reload()
    }

    /// Checks a to-do off in Reminders. It stays in the list, struck through, until `finishChecking`.
    /// - Returns: false when Reminders refused the change.
    @discardableResult
    public func check(_ todo: TodoEntry) -> Bool {
        guard !checkedIDs.contains(todo.id) else { return true }
        do {
            try source.setCompleted(true, todoID: todo.id)
        } catch {
            problem = "Couldn't check that off in Reminders."
            return false
        }
        problem = nil
        checkedIDs.insert(todo.id)
        return true
    }

    /// Undoes a check made while the to-do's card is still open.
    public func uncheck(_ todo: TodoEntry) {
        guard checkedIDs.contains(todo.id) else { return }
        do {
            try source.setCompleted(false, todoID: todo.id)
        } catch {
            problem = "Couldn't undo that in Reminders."
            return
        }
        problem = nil
        checkedIDs.remove(todo.id)
    }

    /// The card of a checked-off to-do closed: it leaves the list.
    public func finishChecking(_ id: String) {
        guard checkedIDs.remove(id) != nil else { return }
        todos.removeAll { $0.id == id }
    }

    /// Clears every checked-off to-do, for when the app goes to the background.
    public func finishAllChecked() {
        for id in checkedIDs { finishChecking(id) }
    }

    private enum Keys {
        static let excludedCalendars = "agenda.excludedCalendarIDs"
        static let excludedLists = "agenda.excludedListIDs"
    }

    /// Fresh to-dos with any checked ones kept where they were, so they don't vanish while
    /// their card is open. Reminders no longer lists them as open.
    private func keepingChecked(_ fresh: [TodoEntry]) -> [TodoEntry] {
        var result = fresh.filter { !checkedIDs.contains($0.id) }
        for (index, todo) in todos.enumerated() where checkedIDs.contains(todo.id) {
            result.insert(todo, at: min(index, result.count))
        }
        return result
    }
}
