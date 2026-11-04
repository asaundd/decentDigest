import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// One item as it appears in a feed, before it is stored.
public struct ParsedItem: Sendable, Hashable {
    public var guid: String?
    public var link: String?
    public var title: String
    public var summary: String?
    public var author: String?
    public var published: Date?

    public init(guid: String? = nil, link: String? = nil, title: String, summary: String? = nil, author: String? = nil, published: Date? = nil) {
        self.guid = guid
        self.link = link
        self.title = title
        self.summary = summary
        self.author = author
        self.published = published
    }

    /// The value `ItemID` hashes: the guid, then the link, then the title plus date.
    public var identity: String {
        if let guid, !guid.isEmpty { return guid }
        if let link, !link.isEmpty { return link }
        let date = published.map { String(Int($0.timeIntervalSince1970)) } ?? ""
        return title + "|" + date
    }
}

public struct ParsedFeed: Sendable, Hashable {
    public var title: String?
    public var items: [ParsedItem]
}

public enum FeedParserError: Error, Equatable {
    case notAFeed
    case malformed(String)
}

/// Reads RSS 2.0, RSS 1.0 (RDF) and Atom feeds.
public enum FeedParser {
    /// Summaries keep at most this many characters, as plain text.
    public static let summaryLimit = 600

    public static func parse(_ data: Data) throws -> ParsedFeed {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.delegate = delegate
        let ok = parser.parse()
        guard delegate.sawFeedRoot else { throw FeedParserError.notAFeed }
        if !ok && delegate.items.isEmpty {
            throw FeedParserError.malformed(parser.parserError?.localizedDescription ?? "unknown")
        }
        return ParsedFeed(title: delegate.feedTitle, items: delegate.items)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var sawFeedRoot = false
        var feedTitle: String?
        var items: [ParsedItem] = []

        private var isAtom = false
        private var current: ItemBuilder?
        private var text = ""
        private var path: [String] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
            let name = elementName.lowercased()
            if path.isEmpty {
                switch name {
                case "rss", "rdf:rdf": sawFeedRoot = true
                case "feed": sawFeedRoot = true; isAtom = true
                default: break
                }
            }
            path.append(name)
            text = ""

            if name == "item" || (isAtom && name == "entry") {
                let item = ItemBuilder()
                item.guid = attributes["rdf:about"]
                current = item
            } else if let current, isAtom, name == "link" {
                // Atom: prefer rel="alternate" (or no rel) for the article link.
                let rel = attributes["rel"] ?? "alternate"
                if rel == "alternate", current.link == nil, let href = attributes["href"] {
                    current.link = href
                }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            text += String(decoding: CDATABlock, as: UTF8.self)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let name = elementName.lowercased()
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            defer {
                if !path.isEmpty { path.removeLast() }
                text = ""
            }

            guard let current else {
                // Feed-level title: a direct child of <channel> (RSS) or <feed> (Atom).
                if name == "title", feedTitle == nil, let parent = path.dropLast().last, parent == "channel" || parent == "feed" {
                    feedTitle = HTMLText.plain(value)
                }
                return
            }

            if name == "item" || (isAtom && name == "entry") {
                if let item = current.build() { items.append(item) }
                self.current = nil
                return
            }

            let ancestors = path.dropLast()
            let parent = ancestors.last
            // Atom authors are <author><name>…</name></author>.
            if name == "name", parent == "author", current.author == nil, !value.isEmpty {
                current.author = value
                return
            }
            // Only read direct children of the item, so nested elements (like Atom <source>) don't leak in.
            guard parent == "item" || parent == "entry" else { return }

            switch name {
            case "title": current.title = value
            case "link" where !isAtom: if !value.isEmpty { current.link = value }
            case "guid", "id": if !value.isEmpty { current.guid = value }
            case "description", "summary": if current.summary == nil { current.summary = value }
            case "content:encoded", "content": if current.content == nil { current.content = value }
            case "pubdate", "published", "dc:date": if current.published == nil { current.published = FeedDate.parse(value) }
            case "updated": if current.updated == nil { current.updated = FeedDate.parse(value) }
            case "author", "dc:creator": if current.author == nil, !value.isEmpty { current.author = value }
            default: break
            }
        }
    }

    private final class ItemBuilder {
        var guid: String?
        var link: String?
        var title = ""
        var summary: String?
        var content: String?
        var author: String?
        var published: Date?
        var updated: Date?

        func build() -> ParsedItem? {
            let cleanTitle = HTMLText.plain(title)
            let source = summary ?? content
            let cleanSummary = source.map { HTMLText.plain($0, limit: FeedParser.summaryLimit) }
            guard !cleanTitle.isEmpty || link != nil else { return nil }
            return ParsedItem(
                guid: guid,
                link: link,
                title: cleanTitle.isEmpty ? (link ?? "") : cleanTitle,
                summary: (cleanSummary?.isEmpty ?? true) ? nil : cleanSummary,
                author: author.map { HTMLText.plain($0) },
                published: published ?? updated
            )
        }
    }
}
