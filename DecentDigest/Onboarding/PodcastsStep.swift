import DigestCore
import SwiftData
import SwiftUI

/// Step 4: Podcasts. Apple Podcasts search, then Apple's current top 12; none is followed until picked.
struct PodcastsStep: View {
    var back: () -> Void
    var skip: () -> Void
    var next: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var sources: [Source]

    private var followed: [Source] {
        sources.filter { $0.kind == SourceKind.podcast.rawValue }
    }

    var body: some View {
        OnboardingStep(
            number: 4,
            title: "Podcasts",
            intro: "Add the podcasts you follow. New episodes and their descriptions will show in your digest and open in the Apple Podcasts app.",
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

/// Follow shows found with Apple's podcast search or picked from Apple's current top 12. Only the
/// typed words, and for the chart the country, are sent to Apple. Everything here needs a
/// connection, so offline it says so and offers nothing to pick. Used in setup and in Settings.
struct PodcastPicker: View {
    /// Settings lists every show you follow first, then the chart's shows you don't.
    var inSettings = false
    /// In Settings, Following shows 4 shows, then "N more · Show all".
    @State private var showsAllFollowed = false

    @Environment(\.modelContext) private var context
    @Environment(NetworkStatus.self) private var network: NetworkStatus?
    @Query(sort: \Source.sortOrder) private var sources: [Source]

    @State private var text = ""
    @State private var results: [ApplePodcasts.Show] = []
    @State private var isSearching = false
    @State private var searchedFor = ""
    @State private var isOffline = false
    @State private var chart: [ApplePodcasts.Show] = TopShows.cached ?? []
    @State private var chartLoading = false
    @State private var chartFailed = false
    @FocusState private var searchFocused: Bool

    private var followed: [Source] {
        sources.filter { $0.kind == SourceKind.podcast.rawValue }
    }

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// From the tap on the search box until it's cleared and put away.
    private var searching: Bool { searchFocused || !query.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Searching Apple Podcasts needs a connection: offline, the box is grayed out with a note under it.
            let offline = network?.isOffline == true
            SearchBox(placeholder: "Search Apple Podcasts", text: $text, isFocused: $searchFocused, isDisabled: offline) {
                searchFocused = false
            }
            // Searches once typing pauses.
            .task(id: query) {
                await search(query)
            }
            .onChange(of: offline) { _, nowOffline in
                if nowOffline {
                    text = ""
                    searchFocused = false
                }
            }
            if offline {
                OfflineNote(text: OfflineMessage.podcasts(inSetup: !inSettings))
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
                        quiet(isOffline ? OfflineMessage.podcasts(inSetup: !inSettings) : "No shows found.")
                    }
                }
                .padding(.top, 6)
            }

            // In setup, shows followed from a search, so they can be unfollowed here too.
            // In Settings, every show followed.
            let extra = followed.filter { source in
                inSettings || !chart.contains { Following.key(for: $0.feedURL) == Following.key(for: source.feedURL) }
            }
            if !searching && !extra.isEmpty {
                let limited = inSettings && !showsAllFollowed
                let shownFollowing = limited ? Array(extra.prefix(4)) : extra
                ListHeading("Following")
                ForEach(shownFollowing) { source in
                    row(title: source.title, subtitle: nil, feed: .init(kind: .podcast, feedURL: source.feedURL, title: source.title, appleID: source.appleID))
                }
                if inSettings && extra.count > 4 {
                    ListFooter(hidden: extra.count - shownFollowing.count, phrase: { _ in "more" }, empty: nil, showsAll: showsAllFollowed, app: nil) {
                        showsAllFollowed.toggle()
                    }
                    .padding(.top, 2)
                }
                PlainRule(spacing: 20)
            }

            let top = inSettings
                ? chart.filter { !Following.isFollowing($0.feedURL, in: followed) }
                : chart
            if !searching && !offline {
                if !top.isEmpty || chartLoading || (chart.isEmpty && chartFailed) {
                    ListHeading("Top 12 on Apple Podcasts")
                }
                if top.isEmpty && chartLoading {
                    quiet("Loading…")
                } else if chart.isEmpty && chartFailed {
                    quiet("The top 12 couldn't be loaded just now. You can still search for a show above.")
                }
                ForEach(top) { show in
                    row(title: show.title, subtitle: show.author, feed: .init(kind: .podcast, feedURL: show.feedURL, title: show.title, appleID: show.id))
                }
            }
        }
        // Loads the chart once per launch, and again when the connection comes back.
        .task(id: network?.isOffline == true) {
            await loadChart()
        }
    }

    private func loadChart() async {
        if let cached = TopShows.cached {
            chart = cached
            return
        }
        guard network?.isOffline != true else { return }
        chartLoading = true
        chartFailed = false
        let shows = await TopShows.load()
        chartLoading = false
        chart = shows
        chartFailed = shows.isEmpty && network?.isOffline != true
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
        let found: [ApplePodcasts.Show]
        var offline = false
        do {
            found = try await ApplePodcasts.search(term)
        } catch {
            found = []
            offline = true
        }
        guard !Task.isCancelled else { return }
        isOffline = offline
        results = found
        searchedFor = term
        isSearching = false
    }
}

/// Apple's top 12, kept for the rest of the launch so setup and Settings don't ask again. The
/// lookup runs on its own, so a view that redraws or goes away (as setup's does while the network
/// monitor settles) never cancels it; every caller waits for the same one.
@MainActor
enum TopShows {
    static var cached: [ApplePodcasts.Show]?
    private static var loading: Task<[ApplePodcasts.Show], Never>?

    static func load() async -> [ApplePodcasts.Show] {
        if let cached { return cached }
        let task = loading ?? Task {
            (try? await ApplePodcasts.topShows(country: Locale.current.region?.identifier)) ?? []
        }
        loading = task
        let shows = await task.value
        loading = nil
        if !shows.isEmpty { cached = shows }
        return shows
    }
}
