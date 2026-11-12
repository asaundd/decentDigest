import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A feed found from an address the reader typed or pasted.
public struct FoundFeed: Sendable, Hashable {
    public var title: String
    public var feedURL: String
    public var siteURL: String?

    public init(title: String, feedURL: String, siteURL: String? = nil) {
        self.title = title
        self.feedURL = feedURL
        self.siteURL = siteURL
    }
}

/// Finds the feed behind a website or feed address. A feed address is used as it is; a website's
/// home page is read once for the feed it names, then the usual feed paths are tried.
/// Only runs when the reader adds a site, and only over https.
public enum FeedFinder {
    /// Paths sites commonly publish their feed at, tried when the page names none.
    static let commonPaths = ["/feed", "/rss", "/feed.xml", "/rss.xml", "/atom.xml", "/index.xml"]

    /// An https address from what the reader typed, or nil when it doesn't look like one.
    /// "stratechery.com" and "http://example.com/feed" both become https.
    public static func address(from text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("feed://") {
            trimmed = "https://" + String(trimmed.dropFirst("feed://".count))
        } else if lowered.hasPrefix("http://") {
            trimmed = "https://" + String(trimmed.dropFirst("http://".count))
        } else if !lowered.hasPrefix("https://") {
            guard !trimmed.contains("://") else { return nil }
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed), let host = url.host(), host.contains("."),
              !host.hasPrefix("."), !host.hasSuffix(".") else { return nil }
        return url
    }

    /// True when the text reads as an address rather than words to search for.
    public static func looksLikeAddress(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return address(from: trimmed) != nil && (trimmed.contains("/") || trimmed.contains("."))
    }

    /// Feed addresses a web page names in its `<link rel="alternate">` tags, https only, in page order.
    public static func feedLinks(inHTML html: String, base: URL) -> [URL] {
        guard let tagPattern = try? NSRegularExpression(pattern: "<link\\b[^>]*>", options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        var found: [URL] = []
        for match in tagPattern.matches(in: html, range: range) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tag = String(html[tagRange])
            guard let rel = attribute("rel", in: tag)?.lowercased(), rel.split(separator: " ").contains("alternate"),
                  let type = attribute("type", in: tag)?.lowercased(),
                  type.contains("rss") || type.contains("atom"),
                  let href = attribute("href", in: tag),
                  let url = URL(string: decodeEntities(href), relativeTo: base)?.absoluteURL,
                  url.scheme?.lowercased() == "https",
                  !found.contains(url) else { continue }
            found.append(url)
        }
        return found
    }

    /// Looks for the feed behind an address. Returns nil when none is found.
    public static func find(_ text: String, session: URLSession = WebSession.shared) async -> FoundFeed? {
        guard let url = address(from: text) else { return nil }
        guard let page = await download(url, session: session) else {
            return await tryCommonPaths(near: url, session: session)
        }
        let (data, finalURL) = page
        if let feed = try? FeedParser.parse(data) {
            return found(feed, at: finalURL)
        }
        // A web page: try the feeds it names, then the usual paths.
        let html = String(decoding: data.prefix(512_000), as: UTF8.self)
        for link in feedLinks(inHTML: html, base: finalURL).prefix(3) {
            if let linked = await download(link, session: session),
               let feed = try? FeedParser.parse(linked.data) {
                return found(feed, at: linked.url)
            }
        }
        return await tryCommonPaths(near: finalURL, session: session)
    }

    // MARK: Private

    private static func tryCommonPaths(near url: URL, session: URLSession) async -> FoundFeed? {
        guard let host = url.host() else { return nil }
        for path in commonPaths {
            guard let candidate = URL(string: "https://\(host)\(path)"),
                  let fetched = await download(candidate, session: session),
                  let feed = try? FeedParser.parse(fetched.data) else { continue }
            return found(feed, at: fetched.url)
        }
        return nil
    }

    private static func found(_ feed: ParsedFeed, at url: URL) -> FoundFeed {
        let host = url.host().map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 }
        let title = feed.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return FoundFeed(
            title: (title?.isEmpty == false ? title : nil) ?? host ?? url.absoluteString,
            feedURL: url.absoluteString,
            siteURL: url.host().map { "https://\($0)" }
        )
    }

    /// Downloads a page or feed, refusing anything that ends up off https.
    private static func download(_ url: URL, session: URLSession) async -> (data: Data, url: URL)? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, text/html;q=0.8, */*;q=0.5", forHTTPHeaderField: "Accept")
        guard let fetched = try? await WebSession.data(for: request, session: session),
              let http = fetched.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        let finalURL = http.url ?? url
        guard finalURL.scheme?.lowercased() == "https" else { return nil }
        return (fetched.0, finalURL)
    }

    /// The value of one attribute in an HTML tag, quoted or not.
    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\\b\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)) else { return nil }
        for group in 1...3 {
            if let range = Range(match.range(at: group), in: tag) { return String(tag[range]) }
        }
        return nil
    }

    private static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
    }
}
