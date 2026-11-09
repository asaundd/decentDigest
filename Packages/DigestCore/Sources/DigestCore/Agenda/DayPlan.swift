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
/// Today shows in full. The next day that has anything always shows at least its first item.
/// Later days fill in until `limit` items show in all. A day cut short ends with "N more", and the
/// rest of the week is counted in the footer.
public enum DayPlanner {
    /// The most items the list shows before "N more".
    public static let limit = 10

    /// - Parameters:
    ///   - days: each day's items in order, today first. Days with nothing are skipped.
    ///   - expanded: days whose "N more" was tapped; they show in full.
    ///   - showAll: true once the footer's Show all was tapped.
    public static func plan<Item: Sendable>(
        _ days: [(day: Date, items: [Item])],
        limit: Int = limit,
        expanded: Set<Date> = [],
        showAll: Bool = false
    ) -> [DayGroup<Item>] {
        var shown = 0
        var reachedNextDay = false
        var groups: [DayGroup<Item>] = []
        for (index, day) in days.enumerated() where !day.items.isEmpty {
            var take: Int
            if index == 0 {
                take = day.items.count
            } else if !reachedNextDay {
                reachedNextDay = true
                take = max(1, limit - shown)
            } else {
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
