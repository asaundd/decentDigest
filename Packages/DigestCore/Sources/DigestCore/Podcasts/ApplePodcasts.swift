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
        guard let fetched = try? await URLSession.shared.data(for: request),
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
