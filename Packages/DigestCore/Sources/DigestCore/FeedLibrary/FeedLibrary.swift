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
        /// False for feeds offered in the library but not followed by default (for example, long academic articles).
        public var defaultFollow: Bool?
    }

    /// A podcast offered in the library. Its Apple Podcasts id lets Open ↗ open episodes in Podcasts.
    public struct Podcast: Decodable, Sendable, Identifiable, Hashable {
        public var id: String
        public var title: String
        public var appleId: String
        public var feedUrl: String
        public var category: String
        public var description: String?
        public var verified: Bool?
        /// True for the shows followed before the reader has chosen any.
        public var defaultFollow: Bool?
    }

    public var version: Int
    public var categories: [Category]
    public var feeds: [Feed]
    public var podcasts: [Podcast]?

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

    /// The shows followed before the reader has chosen any: verified, https only.
    public func defaultPodcasts() -> [Podcast] {
        (podcasts ?? []).filter { $0.defaultFollow == true && $0.verified == true && $0.feedUrl.hasPrefix("https://") }
    }
}
