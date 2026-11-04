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

    /// The headlines to show: still in the digest, not expired, newest first, at most `limit`.
    public static func visible(_ candidates: [Candidate], statuses: [String: ItemStatus], now: Date, limit: Int = itemsShown) -> [Candidate] {
        let cutoff = expiryCutoff(now: now)
        return candidates
            .filter { $0.publishedAt >= cutoff && (statuses[$0.itemID] ?? .new).isActive }
            .sorted { $0.publishedAt > $1.publishedAt }
            .prefix(limit)
            .map { $0 }
    }
}

extension FeedLibrary {
    /// The feeds followed before the reader has chosen any: the most popular starters in each category.
    public func defaultFeeds(perCategory: Int = NewsRules.starterFeedsPerCategory) -> [Feed] {
        categories.flatMap { starterFeeds(in: $0.id).prefix(perCategory) }
    }
}
