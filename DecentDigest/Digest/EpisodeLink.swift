import DigestCore
import SwiftUI

/// Opens an episode in Apple Podcasts: the episode's own page when Apple lists it, otherwise the
/// show's page, otherwise the episode's web page, otherwise the Podcasts app.
@MainActor
enum EpisodeLink {
    static func open(showID: String?, guid: String?, title: String, fallback: URL?, with openURL: OpenURLAction) {
        Task {
            var url: URL?
            if let showID {
                url = await ApplePodcasts.episodeURL(showID: showID, guid: guid, title: title)
            }
            openURL(url ?? fallback ?? ApplePodcasts.app)
        }
    }
}
