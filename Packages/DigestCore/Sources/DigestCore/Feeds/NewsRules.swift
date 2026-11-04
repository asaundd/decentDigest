import Foundation

/// Fixed rules for the news list.
public enum NewsRules {
    /// Headlines shown in the News section.
    public static let itemsShown = 5
    /// Items older than this are not shown and leave the cache.
    public static let expiryDays = 7
    /// A source is fetched again only after this long, unless the reader pulls to refresh.
    public static let refreshInterval: TimeInterval = 15 * 60
    /// Feeds fetched at the same time.
    public static let maxConcurrentFetches = 6
    /// Starter feeds followed per library category when the reader has no sources.
    public static let starterFeedsPerCategory = 2

    public static func expiryCutoff(now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -expiryDays, to: now) ?? now.addingTimeInterval(-Double(expiryDays) * 86_400)
    }

    /// A headline to consider for the list.
    public struct Candidate: Sendable, Hashable {
        public var itemID: String
        public var publishedAt: Date
        public init(itemID: String, publishedAt: Date) {
            self.itemID = itemID
            self.publishedAt = publishedAt
        }
    }

    /// What the reader has done with an item, as far as the list cares.
    public struct Reading: Sendable, Hashable {
        public var status: ItemStatus
        public var openedAt: Date?
        public init(status: ItemStatus, openedAt: Date? = nil) {
            self.status = status
            self.openedAt = openedAt
        }
    }

    /// Headlines that belong in the News list, newest first: not expired, not acted on,
    /// and, if only opened, opened since the list last refreshed.
    public static func eligible(_ candidates: [Candidate], readings: [String: Reading], listStartedAt: Date?, now: Date) -> [Candidate] {
        let cutoff = expiryCutoff(now: now)
        return candidates
            .filter { candidate in
                guard candidate.publishedAt >= cutoff else { return false }
                guard let reading = readings[candidate.itemID] else { return true }
                guard reading.status.isActive else { return false }
                if reading.status == .read, let listStartedAt, let opened = reading.openedAt, opened < listStartedAt {
                    return false
                }
                return true
            }
            .sorted { $0.publishedAt > $1.publishedAt }
    }

    /// The first `limit` eligible headlines.
    public static func visible(_ candidates: [Candidate], readings: [String: Reading], listStartedAt: Date? = nil, now: Date, limit: Int = itemsShown) -> [Candidate] {
        Array(eligible(candidates, readings: readings, listStartedAt: listStartedAt, now: now).prefix(limit))
    }

    /// For a source's first fetch: where its history starts. Today if it has anything from today,
    /// otherwise yesterday, so a new source doesn't fill the list with old posts.
    public static func backfillCutoff(publishedDates: [Date], now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today.addingTimeInterval(-86_400)
        return publishedDates.contains { $0 >= today } ? today : yesterday
    }
}

extension FeedLibrary {
    /// The feeds followed before the reader has chosen any: the most popular starters in each category.
    public func defaultFeeds(perCategory: Int = NewsRules.starterFeedsPerCategory) -> [Feed] {
        categories.flatMap { starterFeeds(in: $0.id).prefix(perCategory) }
    }
}
