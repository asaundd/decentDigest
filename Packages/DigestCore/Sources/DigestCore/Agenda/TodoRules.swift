import Foundation

/// Which open reminders the To-dos section shows, and in what order.
public enum TodoRules {
    /// A calm cap. The rest stay in Reminders, a tap away.
    public static let itemsShown = 10

    /// Open to-dos due today or earlier, then those with no due date.
    /// Ones due on a later day wait for their day. Earlier ones are never called overdue.
    public static func forToday(_ todos: [TodoEntry], now: Date, calendar: Calendar = .current) -> [TodoEntry] {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)

        let open = todos.enumerated().filter { _, todo in
            guard !todo.isCompleted else { return false }
            guard let due = todo.due else { return true }
            return due < tomorrow
        }

        let sorted = open.sorted { a, b in
            switch (a.element.due, b.element.due) {
            case let (dueA?, dueB?):
                if dueA != dueB { return dueA < dueB }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                if a.element.listOrder != b.element.listOrder { return a.element.listOrder < b.element.listOrder }
            }
            return a.offset < b.offset
        }
        return sorted.prefix(itemsShown).map(\.element)
    }

    /// The gray line under a to-do: its list, with the time when it is due at a time today.
    public static func detail(for todo: TodoEntry, now: Date, calendar: Calendar = .current) -> String {
        guard let due = todo.due, todo.dueIncludesTime, calendar.isDate(due, inSameDayAs: now) else {
            return todo.listName
        }
        let time = due.formatted(date: .omitted, time: .shortened)
        return todo.listName.isEmpty ? time : "\(time) · \(todo.listName)"
    }
}
