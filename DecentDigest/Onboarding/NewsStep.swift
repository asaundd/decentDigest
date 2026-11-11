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

    private var followed: [Source] {
        sources.filter { $0.kind == SourceKind.news.rawValue && !$0.isMuted }
    }

    var body: some View {
        OnboardingStep(
            number: 3,
            title: "News",
            intro: "Decent digest reads RSS feeds, which most news sites and blogs publish. Open a topic to pick sites, or add a site you follow.",
            canContinue: !followed.isEmpty,
            skipQuestion: followed.isEmpty ? nil : SkipQuestion(
                title: "Skip News?",
                message: followed.count == 1
                    ? "The site you picked will be unfollowed. You can add News later in Settings."
                    : "The \(followed.count) sites you picked will be unfollowed. You can add News later in Settings.",
                confirm: "Skip and unfollow",
                undo: {
                    for source in followed {
                        Following.unfollow(source.feedURL, kind: .news, in: context)
                    }
                }
            ),
            back: back,
            skip: skip,
            next: next
        ) {
            NewsPicker()
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
    static let topicPreview = 10

    @Environment(\.modelContext) private var context
    @Query(sort: \Source.sortOrder) private var sources: [Source]

    @State private var text = ""
    @State private var found: FoundFeed?
    @State private var isLooking = false
    /// The last change to the box came in all at once, as a paste does.
    @State private var arrivedWhole = false
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
            SearchBox(placeholder: "Search, or paste a site or feed address", text: $text, isFocused: $searchFocused, keyboard: .webSearch, submitLabel: .search) {
                searchFocused = false
            }
            .onChange(of: text) { old, new in
                found = nil
                notFound = false
                // Several characters at once means a paste (or autofill), not typing.
                arrivedWhole = new.count - old.count > 3
            }
            // An address finds its feed on its own once typing pauses (at once when pasted), so
            // the reader only has to tap Follow.
            .task(id: query) {
                await lookUp(query)
            }

            // Search mode starts with the tap, not the first letter: the lists step aside for a
            // short hint and a Paste button, then results.
            if searchFocused && query.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    quiet("Type a site's name, or paste its address.")
                    Spacer(minLength: 0)
                    PasteButton(payloadType: String.self) { strings in
                        guard let pasted = strings.first else { return }
                        Task { @MainActor in text = pasted }
                    }
                    .labelStyle(.titleOnly)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(Theme.accent)
                }
                .padding(.top, 6)
            } else if query.isEmpty {
                if inSettings && !followed.isEmpty {
                    followingList(followed, heading: "Following", limit: showsAllFollowed ? nil : 4)
                    PlainRule(spacing: 20)
                        .padding(.top, 6)
                } else if !inSettings && !addedByYou.isEmpty {
                    followingList(addedByYou, heading: "Added by you", limit: nil)
                    PlainRule(spacing: 20)
                        .padding(.top, 6)
                }
                topics
            } else {
                results
                // A name search also lists what's followed, to unfollow; an address doesn't.
                if !FeedFinder.looksLikeAddress(query) && !followed.isEmpty {
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
            // A heading that opens, unlike a site or show row: semibold, with a › that turns down
            // when open.
            ChoiceRow(title: category.name, subtitle: nil, emphasized: true) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if followedCount > 0 {
                        Text(inSettings ? "\(followedCount) of \(feeds.count) followed" : "\(followedCount) of \(feeds.count) ✓")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize()
                    }
                    Text("›")
                        .foregroundStyle(Theme.secondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .accessibilityHidden(true)
                }
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
                        TextLink("Show \(feeds.count - shown.count) more") {
                            fullTopics.insert(category.id)
                        }
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
                .padding(.leading, DashColumn.width)
                .padding(.bottom, 8)
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
                libraryRow(feed, subtitle: Self.host(feed.siteUrl), tapsToFollow: true)
            }
            if isAddress {
                if let found {
                    let toggle = {
                        if isFollowing(found.feedURL) {
                            Following.unfollow(found.feedURL, kind: .news, in: context)
                        } else {
                            Following.follow(.init(kind: .news, feedURL: found.feedURL, title: found.title, siteURL: found.siteURL), in: context)
                            // Ready for the next one; the site now shows under Added by you.
                            clearSearch()
                        }
                    }
                    ChoiceRow(title: found.title, subtitle: [Self.host(found.siteURL ?? found.feedURL), "Feed found"].compactMap { $0 }.joined(separator: " · "), emphasized: !inSettings && isFollowing(found.feedURL), onTap: toggle) {
                        FollowLink(title: found.title, isFollowing: isFollowing(found.feedURL), toggle: toggle)
                    }
                } else if isLooking {
                    quiet("Looking for a feed…")
                } else if notFound {
                    quiet("No feed found at that address. Try the site's feed address instead.")
                }
            } else if matches.isEmpty {
                quiet("No sites by that name in the library. Paste a site's address to add it.")
            }
        }
        .padding(.top, 6)
    }

    /// Finds the feed behind an address. Runs for each change to the box; a newer change cancels it.
    private func lookUp(_ address: String) async {
        guard FeedFinder.looksLikeAddress(address) else {
            isLooking = false
            return
        }
        isLooking = true
        // A pasted address is looked up at once; a typed one waits for a pause. (Yield first so
        // the change handler has marked how the text arrived.)
        await Task.yield()
        do {
            try await Task.sleep(for: .milliseconds(arrivedWhole ? 0 : 700))
        } catch {
            return
        }
        let result = await FeedFinder.find(address)
        // The reader may have typed something else meanwhile.
        guard !Task.isCancelled, query == address else { return }
        isLooking = false
        found = result
        notFound = result == nil
    }

    // MARK: Rows

    /// A library site with Follow or Unfollow. In search results the whole row follows it too.
    private func libraryRow(_ feed: FeedLibrary.Feed, subtitle: String?, dashed: Bool = false, tapsToFollow: Bool = false) -> some View {
        let toggle = {
            if isFollowing(feed.feedUrl) {
                Following.unfollow(feed.feedUrl, kind: .news, in: context)
            } else {
                follow(feed)
                if !query.isEmpty { clearSearch() }
            }
        }
        return ChoiceRow(title: feed.title, subtitle: subtitle, emphasized: !inSettings && isFollowing(feed.feedUrl), dashed: dashed, onTap: tapsToFollow ? toggle : nil) {
            FollowLink(title: feed.title, isFollowing: isFollowing(feed.feedUrl), toggle: toggle)
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
