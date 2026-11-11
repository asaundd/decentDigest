import Foundation

/// The To do list: a Past due group, dated to-dos by day, then an Anytime group for those with no date.
public struct TodoPlan: Sendable {
    /// Open to-dos from earlier days, oldest first. They always show in full, before today.
    public var pastDue: [TodoEntry]
    /// Today, then the days ahead.
    public var days: [DayGroup<TodoEntry>]
    /// To-dos with no due date, in Reminders order.
    public var anytime: [TodoEntry]
    /// Anytime to-dos left out. Tapping "N more items" shows them.
    public var anytimeHidden: Int

    /// Every to-do left out, for the footer.
    public var hiddenCount: Int { DayPlanner.hiddenCount(days) + anytimeHidden }
}

/// Which open reminders the To do section lists, and in what order.
public enum TodoRules {
    /// Anytime shows at least this many before "N more items".
    public static let anytimeShown = 5

    /// Open to-dos the section can list: due within the week ahead, overdue, or with no date.
    /// Ones due later wait for their week.
    public static func candidates(_ todos: [TodoEntry], now: Date, calendar: Calendar = .current) -> [TodoEntry] {
        let end = CalendarAgenda.fetchRange(now: now, calendar: calendar).upperBound
        return todos.filter { todo in
            guard !todo.isCompleted else { return false }
            guard let due = todo.due else { return true }
            return due < end
        }
    }

    /// Fits the to-dos to the list, using the same day rules as Calendar.
    /// - Parameters:
    ///   - expanded: days whose "N more" was tapped.
    ///   - anytimeExpanded: true once Anytime's "N more items" was tapped.
    ///   - showAll: true once the footer's Show all was tapped.
    public static func plan(
        _ todos: [TodoEntry],
        now: Date,
        expanded: Set<Date> = [],
        anytimeExpanded: Bool = false,
        showAll: Bool = false,
        calendar: Calendar = .current
    ) -> TodoPlan {
        let today = calendar.startOfDay(for: now)
        let open = candidates(todos, now: now, calendar: calendar).enumerated().map { (index: $0.offset, todo: $0.element) }

        let byDue: ((index: Int, todo: TodoEntry), (index: Int, todo: TodoEntry)) -> Bool = { a, b in
            let (dueA, dueB) = (a.todo.due ?? .distantPast, b.todo.due ?? .distantPast)
            if dueA != dueB { return dueA < dueB }
            if a.todo.listOrder != b.todo.listOrder { return a.todo.listOrder < b.todo.listOrder }
            return a.index < b.index
        }

        // Dated to-dos by day. Earlier days go to Past due.
        var byDay: [Date: [(index: Int, todo: TodoEntry)]] = [:]
        var earlier: [(index: Int, todo: TodoEntry)] = []
        for entry in open {
            guard let due = entry.todo.due else { continue }
            let day = calendar.startOfDay(for: due)
            if day < today {
                earlier.append(entry)
            } else {
                byDay[day, default: []].append(entry)
            }
        }
        let pastDue = earlier.sorted(by: byDue).map(\.todo)
        let days = (0..<CalendarAgenda.daysShown).compactMap { offset -> (day: Date, items: [TodoEntry])? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (day: day, items: (byDay[day] ?? []).sorted(by: byDue).map(\.todo))
        }
        // Past due shows in full and counts toward the list's limit, as today does.
        let groups = DayPlanner.plan(days, alreadyShown: pastDue.count, expanded: expanded, showAll: showAll)

        // Anytime takes at least 5, or more when the dated list leaves room under the limit.
        let anytime = open
            .filter { $0.todo.due == nil }
            .sorted { a, b in
                if a.todo.listOrder != b.todo.listOrder { return a.todo.listOrder < b.todo.listOrder }
                return a.index < b.index
            }
            .map(\.todo)
        // Counted before any day is filled in, so opening a day never shrinks Anytime.
        let datedShown = pastDue.count + DayPlanner.plan(days, alreadyShown: pastDue.count).reduce(0) { $0 + $1.items.count }
        let room = max(anytimeShown, DayPlanner.limit - datedShown)
        let take = (showAll || anytimeExpanded) ? anytime.count : min(room, anytime.count)
        return TodoPlan(pastDue: pastDue, days: groups, anytime: Array(anytime.prefix(take)), anytimeHidden: anytime.count - take)
    }

    /// The gray note after a to-do's title in the list: its time, for one due today or later at a set time.
    /// Past due to-dos and ones due on a day with no time have none; the card says which day.
    public static func note(for todo: TodoEntry, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        guard let due = todo.due, todo.dueIncludesTime else { return nil }
        guard calendar.startOfDay(for: due) >= calendar.startOfDay(for: now) else { return nil }
        return AgendaFormat.shortTime(due, calendar: calendar, locale: locale)
    }
}
