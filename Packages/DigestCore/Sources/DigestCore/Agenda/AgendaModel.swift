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
    /// The to-dos shown, including ones just checked off that are waiting to leave.
    public private(set) var todos: [TodoEntry] = []
    /// To-dos checked off moments ago. They stay struck through for a few seconds so a tap can undo.
    public private(set) var checkedIDs: Set<String> = []
    /// True once both sections have been read at least once.
    public private(set) var hasLoaded = false
    /// A short note when Reminders refused a change.
    public private(set) var problem: String?

    private let source: any AgendaSource
    private let undoWindow: Duration
    private let now: () -> Date
    @ObservationIgnored private var removals: [String: Task<Void, Never>] = [:]
    /// Counts reloads, so an older read that finishes late doesn't replace a newer one.
    @ObservationIgnored private var generation = 0

    /// - Parameter undoWindow: how long a checked-off to-do stays, struck through, before it leaves.
    public init(source: any AgendaSource, undoWindow: Duration = .seconds(4), now: @escaping () -> Date = { .now }) {
        self.source = source
        self.undoWindow = undoWindow
        self.now = now
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
        events = calendarAccess == .granted
            ? source.events(in: CalendarAgenda.fetchRange(now: date))
            : []

        if remindersAccess == .granted {
            let fetched = await source.incompleteReminders()
            guard current == generation else { return }
            todos = keepingChecked(TodoRules.forToday(fetched, now: date))
        } else {
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

    /// Checks a to-do off in Reminders, or undoes a check made moments ago.
    public func toggle(_ todo: TodoEntry) {
        let completing = !checkedIDs.contains(todo.id)
        do {
            try source.setCompleted(completing, todoID: todo.id)
        } catch {
            problem = completing ? "Couldn't check that off in Reminders." : "Couldn't undo that in Reminders."
            return
        }
        problem = nil
        removals[todo.id]?.cancel()
        removals[todo.id] = nil
        if completing {
            checkedIDs.insert(todo.id)
            removals[todo.id] = Task { [weak self, undoWindow] in
                try? await Task.sleep(for: undoWindow)
                guard !Task.isCancelled else { return }
                self?.finishChecking(todo.id)
            }
        } else {
            checkedIDs.remove(todo.id)
        }
    }

    /// The undo window has passed: the struck to-do leaves the list.
    func finishChecking(_ id: String) {
        removals[id] = nil
        guard checkedIDs.remove(id) != nil else { return }
        todos.removeAll { $0.id == id }
    }

    /// Fresh to-dos with any just-checked ones kept where they were, so they don't jump or vanish
    /// while their strike is showing. Reminders no longer lists them as open.
    private func keepingChecked(_ fresh: [TodoEntry]) -> [TodoEntry] {
        var result = fresh.filter { !checkedIDs.contains($0.id) }
        for (index, todo) in todos.enumerated() where checkedIDs.contains(todo.id) {
            result.insert(todo, at: min(index, result.count))
        }
        return result
    }
}
