#if canImport(SwiftData)
import Foundation
import SwiftData

// CloudKit rules for every model here: each property optional or defaulted, no unique
// constraints, no relationships (models link by id strings). Once the schema is in
// production, fields can be added but never renamed or removed.

// MARK: Synced through the user's private iCloud

/// A feed the reader follows.
@Model
public final class Source {
    public var id: String = UUID().uuidString
    /// "news" or "podcast".
    public var kind: String = SourceKind.news.rawValue
    public var feedURL: String = ""
    public var siteURL: String?
    public var title: String = ""
    public var category: String?
    public var addedAt: Date = Date.now
    public var sortOrder: Int = 0
    /// A podcast's Apple Podcasts id, so Open ↗ can open its episodes in the Podcasts app.
    public var appleID: String?

    public init(kind: SourceKind = .news, feedURL: String, siteURL: String? = nil, title: String, category: String? = nil, sortOrder: Int = 0, appleID: String? = nil) {
        self.kind = kind.rawValue
        self.appleID = appleID
        self.feedURL = feedURL
        self.siteURL = siteURL
        self.title = title
        self.category = category
        self.sortOrder = sortOrder
    }
}

public enum SourceKind: String, Sendable {
    case news, podcast
}

/// An article's web address; only http and https links are opened.
public enum WebLink {
    public static func url(_ link: String?) -> URL? {
        guard let url = link.flatMap(URL.init(string:)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return url
    }
}

/// What the reader did with one item. This is the reading history; it outlives the cached item.
@Model
public final class ItemState {
    public var itemID: String = ""
    public var sourceID: String = ""
    public var statusRaw: String = ItemStatus.new.rawValue
    public var firstShownAt: Date?
    public var openedAt: Date?
    /// When the item left the digest (useful, not relevant or ignored).
    public var resolvedAt: Date?

    public var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    public init(itemID: String, sourceID: String, status: ItemStatus = .new, firstShownAt: Date? = nil) {
        self.itemID = itemID
        self.sourceID = sourceID
        self.statusRaw = status.rawValue
        self.firstShownAt = firstShownAt
    }
}

/// A headline or episode saved for later. Keeps what Saved needs to show it after the cached item
/// expires; the full post is not synced.
@Model
public final class SavedItem {
    public var itemID: String = ""
    public var sourceID: String = ""
    public var sourceTitle: String = ""
    public var title: String = ""
    public var link: String?
    public var summary: String?
    public var author: String?
    public var publishedAt: Date = Date.now
    public var savedAt: Date = Date.now
    /// "news" or "podcast".
    public var kind: String = SourceKind.news.rawValue
    /// An episode's length.
    public var durationSeconds: Int?
    /// An episode's guid from its feed, to find it in Apple Podcasts.
    public var guid: String?

    public init(itemID: String, sourceID: String, sourceTitle: String, title: String, link: String?, summary: String?, author: String?, publishedAt: Date, savedAt: Date = .now, kind: SourceKind = .news, durationSeconds: Int? = nil, guid: String? = nil) {
        self.kind = kind.rawValue
        self.durationSeconds = durationSeconds
        self.guid = guid
        self.itemID = itemID
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.title = title
        self.link = link
        self.summary = summary
        self.author = author
        self.publishedAt = publishedAt
        self.savedAt = savedAt
    }

    public var linkURL: URL? { WebLink.url(link) }
    public var isEpisode: Bool { kind == SourceKind.podcast.rawValue }
}

// MARK: Kept on this device only

/// A fetched headline or episode. Rebuilt from the feeds on each device; holds a short summary, never the article.
@Model
public final class FeedItem {
    public var itemID: String = ""
    public var sourceID: String = ""
    public var title: String = ""
    public var link: String?
    public var summary: String?
    /// The whole post when the feed carries it. Stays on this device and leaves with the item.
    public var fullText: String?
    public var author: String?
    public var publishedAt: Date = Date.now
    public var fetchedAt: Date = Date.now
    /// An episode's length.
    public var durationSeconds: Int?
    /// The item's guid from its feed, to find an episode in Apple Podcasts.
    public var guid: String?

    public init(itemID: String, sourceID: String, title: String, link: String?, summary: String?, fullText: String? = nil, author: String?, publishedAt: Date, fetchedAt: Date = .now, durationSeconds: Int? = nil, guid: String? = nil) {
        self.durationSeconds = durationSeconds
        self.guid = guid
        self.itemID = itemID
        self.sourceID = sourceID
        self.title = title
        self.link = link
        self.summary = summary
        self.fullText = fullText
        self.author = author
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
    }

    public var linkURL: URL? { WebLink.url(link) }
}

/// Validators and errors from the last fetch of one source.
@Model
public final class FetchState {
    public var sourceID: String = ""
    public var etag: String?
    public var lastModified: String?
    public var lastFetchedAt: Date?
    public var lastError: String?
    public var failureCount: Int = 0
    /// Set on the first successful fetch: items published before it are never added,
    /// so a new source starts with today's items (or yesterday's) instead of its whole backlog.
    public var backfillCutoff: Date?

    public init(sourceID: String) {
        self.sourceID = sourceID
    }
}
#endif
