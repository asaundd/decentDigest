import Foundation
import Testing
@testable import DigestCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// Nov 9 2026 at the given hour and minute, UTC, shifted by whole days.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 0) -> Date {
    let components = DateComponents(year: 2026, month: 11, day: 9 + day, hour: hour, minute: minute)
    return utc.date(from: components)!
}

private func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEntry {
    CalendarEntry(id: id, title: id, start: start, end: end, isAllDay: allDay, calendarName: "Home")
}

// MARK: Calendar

@Test func todayListsAllDayFirstThenByTime() {
    let events = [
        event("lunch", at(12), at(13)),
        event("holiday", at(0), at(0, day: 1), allDay: true),
        event("standup", at(9), at(9, 15)),
    ]
    let today = CalendarAgenda.today(events, now: at(7), calendar: utc)
    #expect(today.map(\.entry.id) == ["holiday", "standup", "lunch"])
    #expect(today.first?.label == .allDay)
}

@Test func endedEventsLeaveTodayButAllDayStays() {
    let events = [
        event("holiday", at(0), at(0, day: 1), allDay: true),
        event("breakfast", at(7), at(8)),
        event("meeting", at(9), at(10)),
    ]
    let today = CalendarAgenda.today(events, now: at(9, 30), calendar: utc)
    #expect(today.map(\.entry.id) == ["holiday", "meeting"])
}

@Test func eventFromYesterdayShowsUntilItsEnd() {
    let overnight = event("flight", at(22, day: -1), at(6))
    let longTrip = event("trip", at(9, day: -1), at(9, day: 2))
    let today = CalendarAgenda.events(on: at(0), from: [overnight, longTrip], calendar: utc)
    #expect(today.first { $0.entry.id == "flight" }?.label == .until(at(6)))
    #expect(today.first { $0.entry.id == "trip" }?.label == .allDay)
}

@Test func restOfWeekGroupsByDayAndSkipsEmptyDays() {
    let events = [
        event("today", at(15), at(16)),
        event("tuesday", at(10, day: 1), at(11, day: 1)),
        event("thursday", at(18, day: 3), at(19, day: 3)),
        event("nextWeek", at(9, day: 7), at(10, day: 7)),
    ]
    let week = CalendarAgenda.restOfWeek(events, now: at(8), calendar: utc)
    #expect(week.map(\.date) == [at(0, day: 1), at(0, day: 3)])
    #expect(week.flatMap(\.events).map(\.entry.id) == ["tuesday", "thursday"])
}

@Test func allDayEventDoesNotSpillIntoNextDay() {
    let holiday = event("holiday", at(0), at(0, day: 1), allDay: true)
    #expect(CalendarAgenda.events(on: at(0, day: 1), from: [holiday], calendar: utc).isEmpty)
}

@Test func fetchRangeCoversTheWeek() {
    let range = CalendarAgenda.fetchRange(now: at(14), calendar: utc)
    #expect(range.lowerBound == at(0))
    #expect(range.upperBound == at(0, day: 7))
}

// MARK: To-dos

@Test func todosDueTodayOrEarlierComeFirstThenUndated() {
    let todos = [
        TodoEntry(id: "undatedB", title: "B", listName: "Family", listOrder: 1),
        TodoEntry(id: "tomorrow", title: "T", listName: "Home", due: at(9, day: 1)),
        TodoEntry(id: "today", title: "D", listName: "Home", due: at(17), dueIncludesTime: true),
        TodoEntry(id: "undatedA", title: "A", listName: "Home", listOrder: 0),
        TodoEntry(id: "lastWeek", title: "L", listName: "Home", due: at(0, day: -7)),
        TodoEntry(id: "done", title: "X", listName: "Home", isCompleted: true),
    ]
    let shown = TodoRules.forToday(todos, now: at(8), calendar: utc)
    #expect(shown.map(\.id) == ["lastWeek", "today", "undatedA", "undatedB"])
}

@Test func todosAreCapped() {
    let todos = (0..<25).map { TodoEntry(id: "\($0)", title: "\($0)", listName: "Home") }
    #expect(TodoRules.forToday(todos, now: at(8), calendar: utc).count == TodoRules.itemsShown)
}

@Test func todoDetailShowsTimeOnlyWhenDueAtATimeToday() {
    let timed = TodoEntry(id: "a", title: "A", listName: "Home", due: at(17), dueIncludesTime: true)
    let dayOnly = TodoEntry(id: "b", title: "B", listName: "Home", due: at(0))
    let earlier = TodoEntry(id: "c", title: "C", listName: "Home", due: at(9, day: -2), dueIncludesTime: true)
    #expect(TodoRules.detail(for: timed, now: at(8), calendar: utc).hasSuffix("· Home"))
    #expect(TodoRules.detail(for: dayOnly, now: at(8), calendar: utc) == "Home")
    #expect(TodoRules.detail(for: earlier, now: at(8), calendar: utc) == "Home")
}

// MARK: Model

@MainActor
private final class FakeSource: AgendaSource {
    var access: AccessState = .granted
    var todos: [TodoEntry]
    var events: [CalendarEntry] = []
    var failWrites = false
    private(set) var writes: [(id: String, completed: Bool)] = []

    init(todos: [TodoEntry]) {
        self.todos = todos
    }

    func calendarAccess() -> AccessState { access }
    func remindersAccess() -> AccessState { access }
    func requestCalendarAccess() async -> AccessState { access }
    func requestRemindersAccess() async -> AccessState { access }
    func events(in range: ClosedRange<Date>) -> [CalendarEntry] { events }
    func incompleteReminders() async -> [TodoEntry] { todos.filter { !$0.isCompleted } }

    func setCompleted(_ completed: Bool, todoID: String) throws {
        if failWrites { throw AgendaError.notFound }
        writes.append((todoID, completed))
        if let index = todos.firstIndex(where: { $0.id == todoID }) {
            todos[index].isCompleted = completed
        }
    }
}

private func threeTodos() -> [TodoEntry] {
    ["a", "b", "c"].enumerated().map { TodoEntry(id: $1, title: $1, listName: "Home", listOrder: $0) }
}

@MainActor @Test func checkingOffWritesBackAndStaysUntilTheUndoWindowEnds() async {
    let source = FakeSource(todos: threeTodos())
    let model = AgendaModel(source: source, undoWindow: .seconds(60), now: { at(8) })
    await model.reload()

    model.toggle(model.todos[1])
    #expect(source.writes.map(\.id) == ["b"])
    #expect(source.writes.first?.completed == true)
    #expect(model.checkedIDs == ["b"])

    // Reminders now says it's done, but it stays in place, struck, while undo is possible.
    await model.reload()
    #expect(model.todos.map(\.id) == ["a", "b", "c"])

    model.finishChecking("b")
    #expect(model.todos.map(\.id) == ["a", "c"])
    #expect(model.checkedIDs.isEmpty)
}

@MainActor @Test func secondTapUndoesTheCheck() async {
    let source = FakeSource(todos: threeTodos())
    let model = AgendaModel(source: source, undoWindow: .seconds(60), now: { at(8) })
    await model.reload()

    let todo = model.todos[0]
    model.toggle(todo)
    model.toggle(todo)
    #expect(source.writes.map(\.completed) == [true, false])
    #expect(model.checkedIDs.isEmpty)

    model.finishChecking(todo.id)
    await model.reload()
    #expect(model.todos.map(\.id) == ["a", "b", "c"])
}

@MainActor @Test func aFailedWriteLeavesTheTodoOpenAndSaysSo() async {
    let source = FakeSource(todos: threeTodos())
    source.failWrites = true
    let model = AgendaModel(source: source, now: { at(8) })
    await model.reload()

    model.toggle(model.todos[0])
    #expect(model.checkedIDs.isEmpty)
    #expect(model.problem != nil)
}

@MainActor @Test func checkedTodoLeavesOnItsOwn() async throws {
    let source = FakeSource(todos: threeTodos())
    let model = AgendaModel(source: source, undoWindow: .milliseconds(20), now: { at(8) })
    await model.reload()

    model.toggle(model.todos[0])
    try await Task.sleep(for: .milliseconds(200))
    #expect(model.todos.map(\.id) == ["b", "c"])
}

@MainActor @Test func declinedAccessShowsNothing() async {
    let source = FakeSource(todos: threeTodos())
    source.access = .denied
    source.events = [event("x", at(9), at(10))]
    let model = AgendaModel(source: source, now: { at(8) })
    await model.reload()
    #expect(model.calendarAccess == .denied)
    #expect(model.events.isEmpty)
    #expect(model.todos.isEmpty)
}
