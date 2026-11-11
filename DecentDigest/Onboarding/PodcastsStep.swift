import DigestCore
import SwiftData
import SwiftUI

/// Step 4: Podcasts. Apple Podcasts search, then the suggested shows from the library; none is
/// followed until picked.
struct PodcastsStep: View {
    var back: () -> Void
    var skip: () -> Void
    var next: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var sources: [Source]

    private var followed: [Source] {
        sources.filter { $0.kind == SourceKind.podcast.rawValue && !$0.isMuted }
    }

    var body: some View {
        OnboardingStep(
            number: 4,
            title: "Podcasts",
            intro: "Select the podcasts you follow. New episodes and their descriptions will show in your digest and open in the Apple Podcasts app.",
            canContinue: !followed.isEmpty,
            skipQuestion: followed.isEmpty ? nil : SkipQuestion(
                title: "Skip Podcasts?",
                message: followed.count == 1
                    ? "The show you picked will be unfollowed. You can add Podcasts later in Settings."
                    : "The \(followed.count) shows you picked will be unfollowed. You can add Podcasts later in Settings.",
                confirm: "Skip and unfollow",
                undo: {
                    for source in followed {
                        Following.unfollow(source.feedURL, kind: .podcast, in: context)
                    }
                }
            ),
            back: back,
            skip: skip,
            next: next
        ) {
            PodcastPicker()
        }
    }
}

/// Follow shows found with Apple's podcast search or picked from the suggestions. Only the typed
/// words are sent to Apple. Used in setup and in Settings.
struct PodcastPicker: View {
    /// Settings lists every show you follow first, then the suggestions you don't.
    var inSettings = false
    static let suggested = (try? FeedLibrary.bundled())?.suggestedPodcasts() ?? []

    @Environment(\.modelContext) private var context
    @Query(sort: \Source.sortOrder) private var sources: [Source]

    @State private var text = ""
    @State private var results: [ApplePodcasts.Show] = []
    @State private var isSearching = false
    @State private var searchedFor = ""
    @FocusState private var searchFocused: Bool

    private var followed: [Source] {
        sources.filter { $0.kind == SourceKind.podcast.rawValue && !$0.isMuted }
    }

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// From the tap on the search box until it's cleared and put away.
    private var searching: Bool { searchFocused || !query.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchBox(placeholder: "Search Apple Podcasts", text: $text, isFocused: $searchFocused) {
                searchFocused = false
            }
            // Searches once typing pauses.
            .task(id: query) {
                await search(query)
            }

            // Search mode starts with the tap, not the first letter: the lists step aside for a
            // short hint, then results.
            if searchFocused && query.isEmpty {
                quiet("Type a show's name or its host.")
                    .padding(.top, 6)
            } else if !query.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { show in
                        row(title: show.title, subtitle: show.author, feed: .init(kind: .podcast, feedURL: show.feedURL, title: show.title, appleID: show.id), clearsSearch: true)
                    }
                    if isSearching && results.isEmpty {
                        quiet("Searching…")
                    } else if !isSearching && results.isEmpty && searchedFor == query {
                        quiet("No shows found.")
                    }
                }
                .padding(.top, 6)
            }

            // In setup, shows followed from a search, so they can be unfollowed here too.
            // In Settings, every show followed.
            let extra = followed.filter { source in
                inSettings || !Self.suggested.contains { Following.key(for: $0.feedUrl) == Following.key(for: source.feedURL) }
            }
            if !searching && !extra.isEmpty {
                ListHeading("Following")
                ForEach(extra) { source in
                    row(title: source.title, subtitle: nil, feed: .init(kind: .podcast, feedURL: source.feedURL, title: source.title, appleID: source.appleID))
                }
            }

            let suggestions = inSettings
                ? Self.suggested.filter { !Following.isFollowing($0.feedUrl, in: followed) }
                : Self.suggested
            if !searching {
                if !suggestions.isEmpty {
                    ListHeading("Suggested")
                }
                ForEach(suggestions) { show in
                    row(title: show.title, subtitle: show.description, feed: .init(kind: .podcast, feedURL: show.feedUrl, title: show.title, category: show.category, appleID: show.appleId))
                }
            }
        }
    }

    /// A show with Follow or Unfollow. Following a search result clears the search, ready for the next
    /// one; the show then appears under Following.
    private func row(title: String, subtitle: String?, feed: Following.Feed, clearsSearch: Bool = false) -> some View {
        let following = Following.isFollowing(feed.feedURL, in: followed)
        let toggle = {
            if following {
                Following.unfollow(feed.feedURL, kind: .podcast, in: context)
            } else {
                Following.follow(feed, in: context)
                if clearsSearch {
                    text = ""
                    searchFocused = false
                }
            }
        }
        // In search results the whole row follows the show too.
        return ChoiceRow(title: title, subtitle: subtitle, emphasized: following && !inSettings, onTap: clearsSearch ? toggle : nil) {
            FollowLink(title: title, isFollowing: following, toggle: toggle)
        }
    }

    private func quiet(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
            .padding(.vertical, 6)
    }

    private func search(_ term: String) async {
        guard !term.isEmpty else {
            results = []
            isSearching = false
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(400))
        } catch {
            return
        }
        isSearching = true
        let found = await ApplePodcasts.search(term)
        guard !Task.isCancelled else { return }
        results = found
        searchedFor = term
        isSearching = false
    }
}
