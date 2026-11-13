import Foundation

/// Fixed rules for the news list.
public enum NewsRules {
    /// Headlines shown in the News section.
    public static let itemsShown = 5
    /// News, Podcasts and Saved open to at most this many rows. Past it, the footer offers
    /// "Show 25" instead of "Show all", so a long list never fills the page.
    public static let expandedLimit = 25

    /// The footer's link for opening a list of `count` rows: all of them, or the first 25.
    public static func showMoreTitle(count: Int) -> String {
        count > expandedLimit ? "Show \(expandedLimit)" : "Show all"
    }
    /// Items older than this are not shown and leave the cache.
    public static let expiryDays = 7
    /// A source is fetched again only after this long, unless the reader pulls to refresh.
    public static let refreshInterval: TimeInterval = 15 * 60
    /// A feed that has failed this many times in a row is marked "Couldn't load" in Settings.
    public static let failingAfter = 3
    /// The longest a failing feed waits before it is tried again.
    public static let longestRetry: TimeInterval = 24 * 60 * 60

    /// How long a source waits before its next fetch: the usual 15 minutes, doubled after each failure
    /// in a row (30 minutes, an hour, two hours…) up to once a day, so a feed that keeps failing isn't
    /// tried over and over. A failure for want of a connection doesn't count.
    public static func retryInterval(failures: Int) -> TimeInterval {
        guard failures > 0 else { return refreshInterval }
        let doubled = refreshInterval * pow(2, Double(min(failures, 16)))
        return min(doubled, longestRetry)
    }

    /// Feeds fetched at the same time.
    public static let maxConcurrentFetches = 6

    /// How long the reading history keeps a record, from the last time anything happened to it.
    public static let historyMonths = 12

    /// Records with nothing newer than this are deleted (saved items keep theirs).
    public static func historyCutoff(now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: -historyMonths, to: now) ?? now.addingTimeInterval(-365 * 86_400)
    }

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
        /// When the reader acted on it. A read item with this set was marked Read (with reading
        /// history off) and leaves at once.
        public var resolvedAt: Date?
        public init(status: ItemStatus, openedAt: Date? = nil, resolvedAt: Date? = nil) {
            self.status = status
            self.openedAt = openedAt
            self.resolvedAt = resolvedAt
        }
    }

    /// Headlines that belong in the News list, newest first: not expired, not acted on (marked Read
    /// counts), and, if only opened, opened since the list last refreshed.
    public static func eligible(_ candidates: [Candidate], readings: [String: Reading], listStartedAt: Date?, now: Date) -> [Candidate] {
        let cutoff = expiryCutoff(now: now)
        return candidates
            .filter { candidate in
                guard candidate.publishedAt >= cutoff else { return false }
                guard let reading = readings[candidate.itemID] else { return true }
                guard reading.status.isActive else { return false }
                if reading.status == .read, reading.resolvedAt != nil { return false }
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

