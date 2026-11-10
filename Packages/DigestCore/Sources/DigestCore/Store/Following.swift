#if canImport(SwiftData)
import Foundation
import SwiftData

/// Follows and unfollows sites and shows from the UI. A new source is fetched on the next refresh.
@MainActor
public enum Following {
    /// What to follow: a site's or show's feed, with what the page shows for it.
    public struct Feed: Sendable, Hashable {
        public var kind: SourceKind
        public var feedURL: String
        public var title: String
        public var siteURL: String?
        public var category: String?
        /// A show's Apple Podcasts id.
        public var appleID: String?

        public init(kind: SourceKind, feedURL: String, title: String, siteURL: String? = nil, category: String? = nil, appleID: String? = nil) {
            self.kind = kind
            self.feedURL = feedURL
            self.title = title
            self.siteURL = siteURL
            self.category = category
            self.appleID = appleID
        }
    }

    /// True when the feed is followed and not muted. Addresses match by `key(for:)`.
    public static func isFollowing(_ feedURL: String, in sources: [Source]) -> Bool {
        let wanted = key(for: feedURL)
        return sources.contains { !$0.isMuted && key(for: $0.feedURL) == wanted }
    }

    public static func follow(_ feed: Feed, in context: ModelContext) {
        let wanted = key(for: feed.feedURL)
        let kind = feed.kind.rawValue
        let existing = (try? context.fetch(FetchDescriptor<Source>(predicate: #Predicate { $0.kind == kind }))) ?? []
        if let source = existing.first(where: { key(for: $0.feedURL) == wanted }) {
            source.isMuted = false
        } else {
            context.insert(Source(
                kind: feed.kind,
                feedURL: feed.feedURL,
                siteURL: feed.siteURL,
                title: feed.title,
                category: feed.category,
                sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1,
                appleID: feed.appleID
            ))
        }
        try? context.save()
    }

    /// Stops following a feed. Its cached items go; what the reader did with them stays in the history.
    public static func unfollow(_ feedURL: String, kind: SourceKind, in context: ModelContext) {
        let wanted = key(for: feedURL)
        let kindRaw = kind.rawValue
        let sources = (try? context.fetch(FetchDescriptor<Source>(predicate: #Predicate { $0.kind == kindRaw }))) ?? []
        for source in sources where key(for: source.feedURL) == wanted {
            let sourceID = source.id
            let items = (try? context.fetch(FetchDescriptor<FeedItem>(predicate: #Predicate { $0.sourceID == sourceID }))) ?? []
            for item in items { context.delete(item) }
            let fetches = (try? context.fetch(FetchDescriptor<FetchState>(predicate: #Predicate { $0.sourceID == sourceID }))) ?? []
            for fetch in fetches { context.delete(fetch) }
            context.delete(source)
        }
        try? context.save()
    }

    /// A feed address compared without its scheme, "www." or a trailing slash.
    nonisolated public static func key(for feedURL: String) -> String {
        var text = feedURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasPrefix("www.") { text.removeFirst(4) }
        while text.hasSuffix("/") { text.removeLast() }
        return text
    }
}
#endif
