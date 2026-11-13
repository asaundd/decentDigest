import Foundation

/// The bundled starter feed library (Resources/feed-library.json).
public struct FeedLibrary: Decodable, Sendable {
    public struct Category: Decodable, Sendable, Identifiable, Hashable {
        public var id: String
        public var name: String
    }

    public struct Feed: Decodable, Sendable, Identifiable, Hashable {
        public var id: String
        public var title: String
        public var siteUrl: String
        public var feedUrl: String
        public var category: String
        public var tags: [String]?
        public var access: String?
        public var description: String?
        public var verified: Bool?
        public var popularityRank: Int?
    }

    public var version: Int
    public var categories: [Category]
    public var feeds: [Feed]

    /// Loads the library bundled with DigestCore.
    public static func bundled() throws -> FeedLibrary {
        guard let url = Bundle.module.url(forResource: "feed-library", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(FeedLibrary.self, from: Data(contentsOf: url))
    }

    /// Feeds safe to offer as onboarding defaults: verified, https only, in popularity order.
    public func starterFeeds(in categoryID: String) -> [Feed] {
        feeds
            .filter { $0.category == categoryID && $0.verified == true && $0.feedUrl.hasPrefix("https://") }
            .sorted { ($0.popularityRank ?? .max) < ($1.popularityRank ?? .max) }
    }

    /// Library feeds whose name or site matches what the reader typed, best first.
    public func searchFeeds(_ text: String, limit: Int = 5) -> [Feed] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        let offered = feeds.filter { $0.verified == true && $0.feedUrl.hasPrefix("https://") }
        let starts = offered.filter { $0.title.lowercased().hasPrefix(query) }
        let contains = offered.filter {
            !$0.title.lowercased().hasPrefix(query)
                && ($0.title.lowercased().contains(query) || $0.siteUrl.lowercased().contains(query))
        }
        return Array((starts + contains).prefix(limit))
    }
}
