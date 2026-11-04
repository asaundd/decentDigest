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
    public var isMuted: Bool = false
    public var sortOrder: Int = 0

    public init(kind: SourceKind = .news, feedURL: String, siteURL: String? = nil, title: String, category: String? = nil, sortOrder: Int = 0) {
        self.kind = kind.rawValue
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

/// What the reader did with one item. This is the reading history; it outlives the cached item.
@Model
public final class ItemState {
    public var itemID: String = ""
    public var sourceID: String = ""
    public var statusRaw: String = ItemStatus.new.rawValue
    public var firstShownAt: Date?
    public var openedAt: Date?
    public var readSeconds: Double?
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

// MARK: Kept on this device only

/// A fetched headline. Rebuilt from the feeds on each device; holds a short summary, never the article.
@Model
public final class FeedItem {
    public var itemID: String = ""
    public var sourceID: String = ""
    public var title: String = ""
    public var link: String?
    public var summary: String?
    public var author: String?
    public var publishedAt: Date = Date.now
    public var fetchedAt: Date = Date.now

    public init(itemID: String, sourceID: String, title: String, link: String?, summary: String?, author: String?, publishedAt: Date, fetchedAt: Date = .now) {
        self.itemID = itemID
        self.sourceID = sourceID
        self.title = title
        self.link = link
        self.summary = summary
        self.author = author
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
    }

    /// The article's web address; only http and https links are opened.
    public var linkURL: URL? {
        guard let url = link.flatMap(URL.init(string:)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return url
    }
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

    public init(sourceID: String) {
        self.sourceID = sourceID
    }
}
#endif
