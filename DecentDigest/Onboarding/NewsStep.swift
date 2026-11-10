import DigestCore
import SwiftData
import SwiftUI

/// Step 3: News. Explains RSS feeds, then offers topics from the starter library and a box to find a
/// site by name or by its address.
struct NewsStep: View {
    var back: () -> Void
    var skip: () -> Void
    var next: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var sources: [Source]
    @State private var confirmsSkip = false

    private var followed: [Source] {
        sources.filter { $0.kind == SourceKind.news.rawValue && !$0.isMuted }
    }

    var body: some View {
        OnboardingStep(
            number: 3,
            title: "News",
            intro: "Decent digest reads RSS feeds, which most news sites and blogs publish. Open a topic to pick sites, or add a site you follow.",
            canContinue: !followed.isEmpty,
            back: back,
            skip: { if followed.isEmpty { skip() } else { confirmsSkip = true } },
            next: next
        ) {
            NewsPicker()
        }
        .confirmationDialog(
            followed.count == 1 ? "Skip News and unfollow the site you picked?" : "Skip News and unfollow the \(followed.count) sites you picked?",
            isPresented: $confirmsSkip,
            titleVisibility: .visible
        ) {
            Button("Skip and unfollow", role: .destructive) {
                for source in followed {
                    Following.unfollow(source.feedURL, kind: .news, in: context)
                }
                skip()
            }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("You can add News later in Settings.")
        }
    }
}

/// Follow sites by topic, by name, or by pasting an address. Every site has Follow, which becomes
/// Unfollow, and nothing is followed until the reader picks it. Used in setup, where sites added by
/// address come first, and in Settings, where everything followed comes first.
struct NewsPicker: View {
    /// Settings lists what you follow above the topics.
    var inSettings = false

    static let library = try? FeedLibrary.bundled()
    /// Sites shown under an open topic before "N more".
    static let topicPreview = 3

    @Environment(\.modelContext) private var context
    @Query(sort: \Source.sortOrder) private var sources: [Source]

    @State private var text = ""
    @State private var found: FoundFeed?
    @State private var isLooking = false
    @State private var notFound = false
    @State private var openTopics: Set<String> = []
    @State private var fullTopics: Set<String> = []
    @State private var showsAllFollowed = false
    @FocusState private var searchFocused: Bool

    private var followed: [Source] {
        sources.filter { $0.kind == SourceKind.news.rawValue && !$0.isMuted }
    }

    /// Sites followed by name or address rather than from a topic.
    private var addedByYou: [Source] {
        followed.filter { source in
            !(Self.library?.feeds.contains { Following.key(for: $0.feedUrl) == Following.key(for: source.feedURL) } ?? false)
        }
    }

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchBox(placeholder: "Search, or paste a site or feed address", text: $text, isFocused: $searchFocused, keyboard: .webSearch) {
                if FeedFinder.looksLikeAddress(query) { lookUp() }
            }
            .onChange(of: text) { _, _ in
                found = nil
                notFound = false
            }

            if query.isEmpty {
                if inSettings && !followed.isEmpty {
                    followingList(followed, heading: "Following", limit: showsAllFollowed ? nil : 4)
                } else if !inSettings && !addedByYou.isEmpty {
                    followingList(addedByYou, heading: "Added by you", limit: nil)
                }
                topics
            } else {
                results
                if !followed.isEmpty {
                    followingList(followed, heading: "Following", limit: nil)
                }
            }
        }
    }

    /// Sites the reader follows, each with Unfollow. In Settings, the first 4, then "N more · Show all".
    @ViewBuilder
    private func followingList(_ followed: [Source], heading: String, limit: Int?) -> some View {
        let shown = limit.map { Array(followed.prefix($0)) } ?? followed
        ListHeading(heading)
        ForEach(shown) { source in
            ChoiceRow(title: source.title, subtitle: categoryName(source.category) ?? (heading == "Added by you" ? Self.host(source.siteURL ?? source.feedURL) : "Added by you"), emphasized: !inSettings) {
                FollowLink(title: source.title, isFollowing: true) {
                    Following.unfollow(source.feedURL, kind: .news, in: context)
                }
            }
        }
        if inSettings && query.isEmpty && followed.count > 4 {
            HStack(spacing: 6) {
                if shown.count < followed.count {
                    Text("\(followed.count - shown.count) more")
                        .foregroundStyle(Theme.secondary)
                    Text("·")
                        .foregroundStyle(Theme.secondary)
                        .accessibilityHidden(true)
                }
                TextLink(showsAllFollowed ? "Show less" : "Show all") { showsAllFollowed.toggle() }
            }
            .font(.subheadline)
            .padding(.top, 2)
        }
    }

    // MARK: Topics

    private var topics: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListHeading("Topics")
            ForEach(Self.library?.categories ?? []) { category in
                topic(category)
            }
        }
    }

    /// A topic: its name over a few of its sites, and how many are followed. A tap anywhere on it opens
    /// or closes its sites, each with Follow, plus Follow all.
    @ViewBuilder
    private func topic(_ category: FeedLibrary.Category) -> some View {
        let feeds = Self.library?.starterFeeds(in: category.id) ?? []
        let followedCount = feeds.filter { isFollowing($0.feedUrl) }.count
        let isOpen = openTopics.contains(category.id)
        Button {
            if isOpen { openTopics.remove(category.id) } else { openTopics.insert(category.id) }
        } label: {
            ChoiceRow(
                title: category.name,
                subtitle: isOpen ? nil : feeds.prefix(3).map(\.title).joined(separator: ", "),
                emphasized: followedCount > 0 && !inSettings
            ) {
                Text(followedCount > 0 ? (inSettings ? "\(followedCount) of \(feeds.count) followed" : "\(followedCount) of \(feeds.count) ✓") : "\(feeds.count) sites")
                    .font(.subheadline.weight(followedCount > 0 ? .semibold : .regular))
                    .foregroundStyle(followedCount > 0 ? Theme.ink : Theme.secondary)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StillButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isOpen ? "Hides the sites in \(category.name)" : "Shows the sites in \(category.name)")
        if isOpen {
            let showsAll = fullTopics.contains(category.id)
            let shown = showsAll ? feeds : Array(feeds.prefix(Self.topicPreview))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { feed in
                    libraryRow(feed, subtitle: nil, dashed: true)
                }
                HStack(spacing: 6) {
                    if feeds.count > shown.count {
                        Button {
                            fullTopics.insert(category.id)
                        } label: {
                            Text("\(feeds.count - shown.count) more")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(StillButtonStyle())
                        .accessibilityHint("Shows the rest of \(category.name)")
                        Text("·")
                            .foregroundStyle(Theme.secondary)
                            .accessibilityHidden(true)
                    }
                    if followedCount < feeds.count {
                        TextLink("Follow all") {
                            for feed in feeds where !isFollowing(feed.feedUrl) { follow(feed) }
                            fullTopics.insert(category.id)
                        }
                        .accessibilityLabel("Follow all of \(category.name)")
                    } else {
                        QuietLink("Unfollow all") {
                            for feed in feeds { Following.unfollow(feed.feedUrl, kind: .news, in: context) }
                        }
                        .accessibilityLabel("Unfollow all of \(category.name)")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: Search

    @ViewBuilder
    private var results: some View {
        let matches = Self.library?.searchFeeds(query) ?? []
        let isAddress = FeedFinder.looksLikeAddress(query)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(matches) { feed in
                libraryRow(feed, subtitle: Self.host(feed.siteUrl))
            }
            if isAddress {
                if let found {
                    ChoiceRow(title: found.title, subtitle: [Self.host(found.siteURL ?? found.feedURL), "Feed found"].compactMap { $0 }.joined(separator: " · "), emphasized: !inSettings && isFollowing(found.feedURL)) {
                        FollowLink(title: found.title, isFollowing: isFollowing(found.feedURL)) {
                            if isFollowing(found.feedURL) {
                                Following.unfollow(found.feedURL, kind: .news, in: context)
                            } else {
                                Following.follow(.init(kind: .news, feedURL: found.feedURL, title: found.title, siteURL: found.siteURL), in: context)
                                // Ready for the next one; the site now shows under Added by you.
                                clearSearch()
                            }
                        }
                    }
                } else if isLooking {
                    quiet("Looking for a feed…")
                } else if notFound {
                    quiet("No feed found at that address. Try the site's feed address instead.")
                } else {
                    TextLink("Find this site's feed", action: lookUp)
                        .padding(.top, 6)
                }
            } else if matches.isEmpty {
                quiet("No sites by that name in the library. Paste a site's address to add it.")
            }
        }
        .padding(.top, 6)
    }

    private func lookUp() {
        let address = query
        guard !isLooking, FeedFinder.looksLikeAddress(address) else { return }
        isLooking = true
        notFound = false
        Task {
            let result = await FeedFinder.find(address)
            isLooking = false
            // The reader may have typed something else meanwhile.
            guard query == address else { return }
            found = result
            notFound = result == nil
            searchFocused = false
        }
    }

    // MARK: Rows

    private func libraryRow(_ feed: FeedLibrary.Feed, subtitle: String?, dashed: Bool = false) -> some View {
        ChoiceRow(title: feed.title, subtitle: subtitle, emphasized: !inSettings && isFollowing(feed.feedUrl), dashed: dashed) {
            FollowLink(title: feed.title, isFollowing: isFollowing(feed.feedUrl)) {
                if isFollowing(feed.feedUrl) {
                    Following.unfollow(feed.feedUrl, kind: .news, in: context)
                } else {
                    follow(feed)
                    if !query.isEmpty { clearSearch() }
                }
            }
        }
    }

    private func clearSearch() {
        text = ""
        found = nil
        notFound = false
        searchFocused = false
    }

    private func quiet(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
    }

    private func follow(_ feed: FeedLibrary.Feed) {
        Following.follow(.init(kind: .news, feedURL: feed.feedUrl, title: feed.title, siteURL: feed.siteUrl, category: feed.category), in: context)
    }

    private func isFollowing(_ feedURL: String) -> Bool {
        Following.isFollowing(feedURL, in: followed)
    }

    private func categoryName(_ id: String?) -> String? {
        guard let id else { return nil }
        return Self.library?.categories.first { $0.id == id }?.name
    }

    /// "stratechery.com" from a site's address.
    static func host(_ address: String?) -> String? {
        guard let host = address.flatMap(URL.init(string:))?.host() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
