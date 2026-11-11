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
    let today = CalendarAgenda.events(on: at(7), from: events, calendar: utc)
    #expect(today.map(\.entry.id) == ["holiday", "standup", "lunch"])
    #expect(today.first?.label == .allDay)
}

@Test func eventFromYesterdayShowsUntilItsEnd() {
    let overnight = event("flight", at(22, day: -1), at(6))
    let longTrip = event("trip", at(9, day: -1), at(9, day: 2))
    let today = CalendarAgenda.events(on: at(0), from: [overnight, longTrip], calendar: utc)
    #expect(today.first { $0.entry.id == "flight" }?.label == .until(at(6)))
    #expect(today.first { $0.entry.id == "trip" }?.label == .allDay)
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

@Test func pastNowAndUpcomingEvents() {
    let events = [
        event("breakfast", at(7), at(8)),
        event("meeting", at(9), at(10)),
        event("lunch", at(12), at(13)),
        event("holiday", at(0), at(0, day: 1), allDay: true),
    ]
    let today = CalendarAgenda.events(on: at(0), from: events, calendar: utc)
    let timing = Dictionary(uniqueKeysWithValues: today.map { ($0.entry.id, CalendarAgenda.timing(of: $0, now: at(9, 30))) })
    #expect(timing["breakfast"] == .past)
    #expect(timing["meeting"] == .now)
    #expect(timing["lunch"] == .upcoming)
    #expect(timing["holiday"] == .upcoming)
}

@Test func defaultShowsTodayAndTheNextTwoDaysWithEvents() {
    // Today 4 (two already over), Tuesday 2, Wednesday 2, Thursday 3, Friday 1.
    var events = [
        event("t1", at(7), at(8)), event("t2", at(9), at(10)), event("t3", at(13), at(14)), event("t4", at(18), at(19)),
        event("tue1", at(8, day: 1), at(9, day: 1)), event("tue2", at(15, day: 1), at(16, day: 1)),
        event("wed1", at(11, day: 2), at(12, day: 2)), event("wed2", at(17, day: 2), at(18, day: 2)),
        event("thu1", at(8, day: 3), at(9, day: 3)), event("thu2", at(10, day: 3), at(11, day: 3)), event("thu3", at(16, day: 3), at(17, day: 3)),
    ]
    events.append(event("fri1", at(9, day: 4), at(10, day: 4)))
    let plan = CalendarAgenda.plan(events, now: at(12), calendar: utc)
    let shown = plan.filter { !$0.items.isEmpty }
    #expect(shown.map(\.items.count) == [4, 2, 2])
    // All of Thursday and Friday wait for Show all.
    #expect(DayPlanner.hiddenCount(plan) == 4)
}

@Test func anEmptyTodayStillTakesOneOfTheThreeDays() {
    let plan = DayPlanner.plan(
        [(day: at(0), items: [Int]()), (day: at(0, day: 1), items: [1]), (day: at(0, day: 2), items: [1]), (day: at(0, day: 3), items: [1])]
    )
    #expect(plan.map(\.items.count) == [1, 1, 0])
    #expect(DayPlanner.hiddenCount(plan) == 1)
}

@Test func theThreeDaysStillStopAtTen() {
    let plan = DayPlanner.plan(
        [(day: at(0), items: Array(1...6)), (day: at(0, day: 1), items: Array(1...3)), (day: at(0, day: 2), items: Array(1...3))]
    )
    #expect(plan.map(\.items.count) == [6, 3, 1])
    #expect(plan.last?.hiddenCount == 2)
}

@Test func busyTodayStillShowsTheNextDaysFirstEvent() {
    let today = (0..<11).map { event("t\($0)", at(7 + $0), at(7 + $0, 30)) }
    let tomorrow = [event("tue1", at(8, day: 1), at(9, day: 1)), event("tue2", at(10, day: 1), at(11, day: 1))]
    let plan = CalendarAgenda.plan(today + tomorrow, now: at(6), calendar: utc).filter { !$0.items.isEmpty }
    #expect(plan.map(\.items.count) == [11, 1])
    #expect(plan.last?.hiddenCount == 1)
}

@Test func fillingInADayDoesNotPushLaterDaysOut() {
    let plan = DayPlanner.plan(
        [(day: at(0), items: Array(1...6)), (day: at(0, day: 1), items: Array(1...6)), (day: at(0, day: 2), items: [1])],
        expanded: [at(0, day: 1)]
    )
    #expect(plan.map(\.items.count) == [6, 6, 0])
    #expect(DayPlanner.hiddenCount(plan) == 1)
}

@Test func showAllShowsEverything() {
    let plan = DayPlanner.plan(
        [(day: at(0), items: Array(1...8)), (day: at(0, day: 1), items: Array(1...8))],
        showAll: true
    )
    #expect(plan.map(\.items.count) == [8, 8])
    #expect(DayPlanner.hiddenCount(plan) == 0)
}

// MARK: Formatting

@Test func shortTimesUseAAndP() {
    let us = Locale(identifier: "en_US")
    #expect(AgendaFormat.shortTime(at(9, 30), calendar: utc, locale: us) == "9:30a")
    #expect(AgendaFormat.shortTime(at(14, 15), calendar: utc, locale: us) == "2:15p")
    #expect(AgendaFormat.shortTime(at(0, 5), calendar: utc, locale: us) == "12:05a")
    #expect(AgendaFormat.shortTime(at(14, 15), calendar: utc, locale: Locale(identifier: "de_DE")) == "14:15")
}

@Test func eventLengths() {
    #expect(AgendaFormat.length(of: event("a", at(9), at(9, 45)), calendar: utc) == "45 minutes")
    #expect(AgendaFormat.length(of: event("b", at(9), at(10)), calendar: utc) == "1 hour")
    #expect(AgendaFormat.length(of: event("c", at(9), at(10, 30)), calendar: utc) == "1 hour 30 minutes")
    #expect(AgendaFormat.length(of: event("d", at(0), at(0, day: 1), allDay: true), calendar: utc) == "All day")
    #expect(AgendaFormat.length(of: event("e", at(0), at(0, day: 3), allDay: true), calendar: utc) == "3 days")
}

@Test func peopleNamesUpToThree() {
    #expect(AgendaFormat.people([]) == nil)
    #expect(AgendaFormat.people(["Sam"]) == "Sam")
    #expect(AgendaFormat.people(["Sam", "Maya"]) == "Sam and Maya")
    #expect(AgendaFormat.people(["Sam", "Maya", "Leo", "Ana", "Ben"]) == "Sam, Maya, Leo and 2 others")
}

@Test func placesFitOnOneLine() {
    #expect(AgendaFormat.oneLinePlace("Blue Bottle\n 450 W 15th St\n\nNew York, NY") == "Blue Bottle, 450 W 15th St, New York, NY")
    #expect(AgendaFormat.oneLinePlace(" \n ") == nil)
    #expect(AgendaFormat.oneLinePlace(nil) == nil)
}

@Test func videoCallLinksLeaveTheNotes() {
    let notes = "Bring the draft.\nJoin: https://zoom.us/j/123\nhttps://meet.google.com/abc"
    #expect(AgendaFormat.notesWithoutCallLinks(notes) == "Bring the draft.")
    #expect(AgendaFormat.notesWithoutCallLinks("https://zoom.us/j/1") == nil)
}

@Test func earlierDueDatesAreNeverOverdue() {
    let us = Locale(identifier: "en_US")
    #expect(AgendaFormat.earlierDue(at(9, day: -1), now: at(8), calendar: utc, locale: us) == "Yesterday")
    #expect(AgendaFormat.earlierDue(at(9, day: -3), now: at(8), calendar: utc, locale: us) == "Fri")
    #expect(AgendaFormat.earlierDue(at(9, day: -7), now: at(8), calendar: utc, locale: us) == "Nov 2")
}

// MARK: To-dos

private func todo(_ id: String, due: Date? = nil, timed: Bool = false, order: Int = 0) -> TodoEntry {
    TodoEntry(id: id, title: id, listName: "Home", due: due, dueIncludesTime: timed, listOrder: order)
}

@Test func earlierTodosGoToPastDueAndLaterOnesWait() {
    let todos = [
        todo("today", due: at(17), timed: true),
        todo("lastWeek", due: at(0, day: -7)),
        todo("tomorrow", due: at(0, day: 1)),
        todo("nextMonth", due: at(0, day: 30)),
        todo("anytime"),
        TodoEntry(id: "done", title: "done", listName: "Home", isCompleted: true),
    ]
    let plan = TodoRules.plan(todos, now: at(8), calendar: utc)
    let days = plan.days.filter { !$0.items.isEmpty }
    #expect(plan.pastDue.map(\.id) == ["lastWeek"])
    #expect(days.map { $0.items.map(\.id) } == [["today"], ["tomorrow"]])
    #expect(plan.anytime.map(\.id) == ["anytime"])
    #expect(plan.hiddenCount == 0)
}

@Test func anytimeShowsFiveWhenTheDayListIsFull() {
    let dated = (0..<10).map { todo("d\($0)", due: at(9)) }
    let anytime = (0..<8).map { todo("a\($0)", order: $0) }
    let plan = TodoRules.plan(dated + anytime, now: at(8), calendar: utc)
    #expect(plan.anytime.count == 5)
    #expect(plan.anytimeHidden == 3)
    #expect(plan.hiddenCount == 3)
}

@Test func anytimeFillsRoomOnALightDay() {
    let dated = [todo("d1", due: at(9)), todo("d2", due: at(10))]
    let anytime = (0..<8).map { todo("a\($0)", order: $0) }
    let plan = TodoRules.plan(dated + anytime, now: at(8), calendar: utc)
    #expect(plan.anytime.count == 8)
    #expect(plan.hiddenCount == 0)
}

@Test func pastDueOldestFirstAndCountsTowardTheLimit() {
    let past = (1...6).map { todo("p\($0)", due: at(9, day: -$0)) }
    let today = (0..<3).map { todo("t\($0)", due: at(10 + $0), timed: true) }
    let tomorrow = (0..<4).map { todo("m\($0)", due: at(9 + $0, day: 1), timed: true) }
    let plan = TodoRules.plan(past + today + tomorrow, now: at(8), calendar: utc)
    #expect(plan.pastDue.map(\.id) == ["p6", "p5", "p4", "p3", "p2", "p1"])
    let days = plan.days.filter { !$0.items.isEmpty }
    // 6 past due + 3 today leave room for one of tomorrow's four.
    #expect(days.map { $0.items.count } == [3, 1])
    #expect(plan.hiddenCount == 3)
}

@Test func todoNotesGiveTimesOnlyForTodayOrLater() {
    let us = Locale(identifier: "en_US")
    #expect(TodoRules.note(for: todo("a", due: at(9, day: -1)), now: at(8), calendar: utc, locale: us) == nil)
    #expect(TodoRules.note(for: todo("a2", due: at(9, day: -9), timed: true), now: at(8), calendar: utc, locale: us) == nil)
    #expect(TodoRules.note(for: todo("b", due: at(17), timed: true), now: at(8), calendar: utc, locale: us) == "5:00p")
    #expect(TodoRules.note(for: todo("b2", due: at(9, day: 1), timed: true), now: at(8), calendar: utc, locale: us) == "9:00a")
    #expect(TodoRules.note(for: todo("c", due: at(0)), now: at(8), calendar: utc, locale: us) == nil)
}

@Test func dueLineSaysWhenAndWhere() {
    let us = Locale(identifier: "en_US")
    #expect(AgendaFormat.dueLine(for: todo("a", due: at(0)), now: at(8), calendar: utc, locale: us) == "Due today · Home")
    #expect(AgendaFormat.dueLine(for: todo("b", due: at(9, day: -1)), now: at(8), calendar: utc, locale: us) == "Due yesterday · Home")
    #expect(AgendaFormat.dueLine(for: todo("c"), now: at(8), calendar: utc, locale: us) == "Home")
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
    func calendars() -> [AgendaList] { [AgendaList(id: "work", title: "Work"), AgendaList(id: "home", title: "Home")] }
    func reminderLists() -> [AgendaList] { [AgendaList(id: "Home", title: "Home")] }
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

@MainActor @Test func checkingOffWritesBackAndStaysUntilTheCardCloses() async {
    let source = FakeSource(todos: threeTodos())
    let model = AgendaModel(source: source, now: { at(8) })
    await model.reload()

    model.check(model.todos[1])
    #expect(source.writes.map(\.id) == ["b"])
    #expect(source.writes.first?.completed == true)
    #expect(model.checkedIDs == ["b"])

    // Reminders now says it's done, but it stays in place, struck, while its card is open.
    await model.reload()
    #expect(model.todos.map(\.id) == ["a", "b", "c"])

    model.finishChecking("b")
    #expect(model.todos.map(\.id) == ["a", "c"])
    #expect(model.checkedIDs.isEmpty)
}

@MainActor @Test func undoArrowBringsItBack() async {
    let source = FakeSource(todos: threeTodos())
    let model = AgendaModel(source: source, now: { at(8) })
    await model.reload()

    let todo = model.todos[0]
    model.check(todo)
    model.uncheck(todo)
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

    #expect(model.check(model.todos[0]) == false)
    #expect(model.checkedIDs.isEmpty)
    #expect(model.problem != nil)
}

@MainActor @Test func goingToTheBackgroundClearsCheckedTodos() async {
    let source = FakeSource(todos: threeTodos())
    let model = AgendaModel(source: source, now: { at(8) })
    await model.reload()

    model.check(model.todos[0])
    model.check(model.todos[2])
    model.finishAllChecked()
    #expect(model.todos.map(\.id) == ["b"])
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

@MainActor @Test func leftOutCalendarsAndListsStayOffThePage() async {
    let defaults = UserDefaults(suiteName: "agenda-\(UUID().uuidString)")!
    let source = FakeSource(todos: threeTodos().enumerated().map { index, todo in
        var todo = todo
        todo.listID = index == 1 ? "errands" : "home"
        return todo
    })
    source.events = [
        CalendarEntry(id: "x", title: "Standup", start: at(9), end: at(10), calendarName: "Work", calendarID: "work"),
        CalendarEntry(id: "y", title: "Dinner", start: at(18), end: at(19), calendarName: "Home", calendarID: "home"),
    ]
    let model = AgendaModel(source: source, defaults: defaults, now: { at(8) })
    await model.reload()
    #expect(model.calendars.map(\.id) == ["work", "home"])
    #expect(model.events.count == 2)

    await model.setIncluded(false, calendar: "work")
    await model.setIncluded(false, list: "errands")
    #expect(model.events.map(\.id) == ["y"])
    #expect(model.todos.map(\.id) == ["a", "c"])

    // Remembered on this device.
    let reopened = AgendaModel(source: source, defaults: defaults, now: { at(8) })
    await reopened.reload()
    #expect(reopened.excludedCalendarIDs == ["work"])
    #expect(reopened.events.map(\.id) == ["y"])

    await reopened.setIncluded(true, calendar: "work")
    #expect(reopened.events.count == 2)
}
