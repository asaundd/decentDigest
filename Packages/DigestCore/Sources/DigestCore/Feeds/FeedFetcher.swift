import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Downloads one feed, sending the validators from the last fetch so an unchanged feed costs almost nothing.
public struct FeedFetcher: Sendable {
    public enum Result: Sendable {
        case notModified
        case fetched(ParsedFeed, etag: String?, lastModified: String?)
    }

    public enum FetchError: Error, Equatable {
        case insecureURL
        case badURL
        case http(Int)
    }

    public var timeout: TimeInterval = 15

    public init(timeout: TimeInterval = 15) {
        self.timeout = timeout
    }

    public func fetch(feedURL: String, etag: String?, lastModified: String?) async throws -> Result {
        guard let url = URL(string: feedURL) else { throw FetchError.badURL }
        guard url.scheme?.lowercased() == "https" else { throw FetchError.insecureURL }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5", forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let lastModified { request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since") }

        let (data, response) = try await WebSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.http(0) }
        if http.statusCode == 304 { return .notModified }
        guard (200..<300).contains(http.statusCode) else { throw FetchError.http(http.statusCode) }
        // Refuse a redirect that left https.
        if let finalURL = http.url, finalURL.scheme?.lowercased() != "https" { throw FetchError.insecureURL }

        let feed = try FeedParser.parse(data)
        return .fetched(
            feed,
            etag: http.value(forHTTPHeaderField: "ETag"),
            lastModified: http.value(forHTTPHeaderField: "Last-Modified")
        )
    }
}
