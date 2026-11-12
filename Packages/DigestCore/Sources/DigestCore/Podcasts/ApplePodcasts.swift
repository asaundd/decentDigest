import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Finds an episode's page in Apple Podcasts, so Open ↗ opens the episode in the Podcasts app.
/// Uses Apple's public lookup, which needs no key; it is asked only when the reader taps Open ↗.
/// Apple Podcasts can't be told to add an episode to Up Next, so opening it is as far as the app goes.
public enum ApplePodcasts {
    /// Opens the Podcasts app.
    public static let app = URL(string: "podcasts://")!

    /// The episode's Apple Podcasts link, or the show's when the episode isn't listed yet.
    /// - Parameters:
    ///   - showID: the show's Apple Podcasts id (the number after "id" in its link).
    ///   - guid: the episode's guid from the feed.
    public static func episodeURL(showID: String, guid: String?, title: String) async -> URL? {
        guard let id = Int(showID),
              let url = URL(string: "https://itunes.apple.com/lookup?id=\(id)&entity=podcastEpisode&limit=200") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let fetched = try? await WebSession.data(for: request),
              (fetched.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return match(lookup: fetched.0, guid: guid, title: title)
    }

    /// Picks the episode out of a lookup response: by guid, then by title; else the show's own page.
    static func match(lookup data: Data, guid: String?, title: String) -> URL? {
        guard let response = try? JSONDecoder().decode(LookupResponse.self, from: data) else { return nil }
        let episodes = response.results.filter { $0.wrapperType == "podcastEpisode" }
        let wantedTitle = normalized(title)
        let episode = episodes.first { guid != nil && $0.episodeGuid == guid }
            ?? episodes.first { $0.trackName.map(normalized) == wantedTitle }
        let link = episode?.trackViewUrl ?? response.results.first { $0.wrapperType == "track" }?.collectionViewUrl
        return link.flatMap(URL.init(string:))
    }

    // MARK: Search

    /// A show found with Apple's podcast search.
    public struct Show: Sendable, Hashable, Identifiable {
        /// The show's Apple Podcasts id.
        public var id: String
        public var title: String
        /// Who makes it, e.g. "The New York Times".
        public var author: String?
        public var feedURL: String

        public init(id: String, title: String, author: String? = nil, feedURL: String) {
            self.id = id
            self.title = title
            self.author = author
            self.feedURL = feedURL
        }
    }

    /// At most this many shows come back from a search.
    public static let searchLimit = 10

    /// Searches Apple Podcasts for shows. Uses Apple's public search, which needs no key;
    /// only the typed words are sent. Shows without an https feed are left out.
    /// - Throws: `Connectivity.Offline` when the device has no connection.
    public static func search(_ term: String) async throws -> [Show] {
        guard let url = searchURL(term) else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let fetched: (Data, URLResponse)
        do {
            fetched = try await WebSession.data(for: request)
        } catch {
            if Connectivity.isOffline(error) { throw Connectivity.Offline() }
            return []
        }
        guard (fetched.1 as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return shows(fromSearch: fetched.0)
    }

    static func searchURL(_ term: String) -> URL? {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: String(searchLimit)),
            URLQueryItem(name: "term", value: trimmed),
        ]
        return components?.url
    }

    /// Reads a search response: shows with an https feed, in Apple's order.
    static func shows(fromSearch data: Data) -> [Show] {
        guard let response = try? JSONDecoder().decode(SearchResponse.self, from: data) else { return [] }
        var seen: Set<String> = []
        return response.results.compactMap { result in
            guard let id = result.collectionId, let title = result.collectionName,
                  let feed = result.feedUrl, feed.lowercased().hasPrefix("https://"),
                  seen.insert(feed).inserted else { return nil }
            return Show(id: String(id), title: title, author: result.artistName, feedURL: feed)
        }
    }

    private struct SearchResponse: Decodable {
        var results: [SearchResult]
    }

    private struct SearchResult: Decodable {
        var collectionId: Int?
        var collectionName: String?
        var artistName: String?
        var feedUrl: String?
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct LookupResponse: Decodable {
        var results: [Result]
    }

    private struct Result: Decodable {
        var wrapperType: String?
        var episodeGuid: String?
        var trackName: String?
        var trackViewUrl: String?
        var collectionViewUrl: String?
    }
}
