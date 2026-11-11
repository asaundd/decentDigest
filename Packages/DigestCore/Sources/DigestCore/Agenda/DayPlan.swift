import Foundation

/// One day in the Calendar or To do list: the items shown and how many wait behind "N more".
public struct DayGroup<Item: Sendable>: Sendable, Identifiable {
    /// The start of the day.
    public var day: Date
    public var items: [Item]
    /// Items of this day left out by the limit. Tapping "N more" shows them.
    public var hiddenCount: Int

    public var id: Date { day }
}

/// How the Calendar and To do sections fit a week into a short list.
///
/// At most three days show: today, then the next two days that have anything. Today shows in full.
/// The next day always shows at least its first item, and the one after fills in until `limit` items
/// show in all. A day cut short ends with "N more", and the rest of the week is counted in the footer.
public enum DayPlanner {
    /// The most items the list shows before "N more".
    public static let limit = 10
    /// The most days the list shows before Show all, today included even when it is empty.
    public static let maxDays = 3

    /// - Parameters:
    ///   - days: each day's items in order, today first. Days with nothing are skipped.
    ///   - alreadyShown: items shown above the days (To do's Past due), counted toward `limit`.
    ///   - expanded: days whose "N more" was tapped; they show in full.
    ///   - showAll: true once the footer's Show all was tapped.
    public static func plan<Item: Sendable>(
        _ days: [(day: Date, items: [Item])],
        limit: Int = limit,
        alreadyShown: Int = 0,
        expanded: Set<Date> = [],
        showAll: Bool = false
    ) -> [DayGroup<Item>] {
        var shown = alreadyShown
        // Today takes a place whether or not it has anything.
        var daysUsed = 1
        var groups: [DayGroup<Item>] = []
        for (index, day) in days.enumerated() where !day.items.isEmpty {
            var take: Int
            if index == 0 {
                take = day.items.count
            } else if daysUsed >= maxDays {
                take = 0
            } else if daysUsed == 1 {
                daysUsed += 1
                take = max(1, limit - shown)
            } else {
                daysUsed += 1
                take = max(0, limit - shown)
            }
            take = min(take, day.items.count)
            // Counting comes first, so filling in one day never pushes a later day out.
            shown += take
            if showAll || expanded.contains(day.day) {
                take = day.items.count
            }
            groups.append(DayGroup(day: day.day, items: Array(day.items.prefix(take)), hiddenCount: day.items.count - take))
        }
        return groups
    }

    /// Items left out across every day, for the footer.
    public static func hiddenCount<Item>(_ groups: [DayGroup<Item>]) -> Int {
        groups.reduce(0) { $0 + $1.hiddenCount }
    }
}
