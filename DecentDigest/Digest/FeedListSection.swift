import DigestCore
import SwiftData
import SwiftUI

/// Live headlines from the followed feeds, or new episodes from the followed shows.
/// Each row can be expanded and swiped. News and Podcasts share every rule.
struct FeedListSection: View {
    /// News or podcasts.
    var kind: SourceKind = .news
    /// True while feeds are being checked.
    var isRefreshing: Bool
    /// Checks every feed now.
    var refresh: () async -> Void
    @Binding var panel: PanelRequest?
    /// Scrolls an expanded row into view if its bottom (on screen) is past the visible area.
    var reveal: (String, CGFloat) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query(sort: \FeedItem.publishedAt, order: .reverse) private var items: [FeedItem]
    @Query private var sources: [Source]
    @Query private var states: [ItemState]
    @AppStorage(NewsRefresher.listStartedAtKey) private var listStartedAt: Double = 0

    /// Set once the reader has refreshed, so the link can say the list is current.
    @State private var refreshedByReader = false
    /// Open rows stay open until the reader closes them.
    @State private var expandedIDs: Set<String> = []
    @State private var pendingReveal: String?
    @State private var showsAll = false

    var body: some View {
        let eligible = eligibleEntries
        let shown = showsAll ? eligible : Array(eligible.prefix(limit))
        let remaining = eligible.count - shown.count

        HStack(alignment: .firstTextBaseline) {
            Text(isEpisodes ? DigestSection.podcasts.title : DigestSection.news.title)
                .font(Theme.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if isEpisodes {
                TextLink("Podcasts ↗") { openURL(ApplePodcasts.app) }
                    .accessibilityLabel("Open Podcasts")
            } else {
                TextLink(isRefreshing ? "Checking…" : (refreshedByReader ? "Up to date" : "Refresh")) {
                    Task {
                        await refresh()
                        refreshedByReader = true
                    }
                }
                .disabled(isRefreshing)
                .accessibilityHint("Checks your feeds for new items")
            }
        }
        .padding(.bottom, Theme.titleToFirstItem - HeadlineRow.verticalPadding)
        .digestRow()

        if eligible.isEmpty {
            // On first launch the list fills in as each feed arrives.
            HStack(spacing: 8) {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(emptyText)
            }
            .foregroundStyle(Theme.secondary)
            .padding(.vertical, HeadlineRow.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .digestRow()
        }

        ForEach(shown, id: \.item.itemID) { entry in
            let row = self.headline(for: entry)
            HeadlineRow(
                headline: row,
                isExpanded: expandedIDs.contains(entry.item.itemID),
                actions: actions(for: entry),
                onExpandedBottom: { bottom in
                    guard pendingReveal == entry.item.itemID else { return }
                    pendingReveal = nil
                    reveal(entry.item.itemID, bottom)
                }
            ) {
                tap(entry, headline: row)
            }
            .digestRow()
            .id(entry.item.itemID)
            // A row that leaves is gone at once. One that joins waits for the slide, then fades in,
            // so it never overlaps the rows still moving.
            .transition(HeadlineMotion.transition)
            .judgmentSwipes(useful: { resolve(entry.item, as: .useful) }, notUseful: { resolve(entry.item, as: .notRelevant) })
            .onAppear {
                ReadingState.markShown(itemID: entry.item.itemID, sourceID: entry.item.sourceID, in: context)
            }
        }

        if remaining > 0 || showsAll && eligible.count > limit {
            HStack(spacing: 6) {
                if remaining > 0 {
                    Text("\(remaining) more")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                    Text("·")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                        .accessibilityHidden(true)
                }
                TextLink(showsAll ? "Show less" : "Show all") {
                    withAnimation { showsAll.toggle() }
                }
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .digestRow()
        }
    }

    // MARK: Data

    private var isEpisodes: Bool { kind == .podcast }

    private var limit: Int { isEpisodes ? PodcastRules.itemsShown : NewsRules.itemsShown }

    private var emptyText: String {
        switch (isEpisodes, isRefreshing) {
        case (false, true): "Checking your feeds…"
        case (false, false): "No new news right now."
        case (true, true): "Checking your shows…"
        case (true, false): "No new episodes right now."
        }
    }

    private struct Entry {
        var item: FeedItem
        var sourceName: String
        var appleID: String?
        var status: ItemStatus
    }

    private var eligibleEntries: [Entry] {
        let followed = Dictionary(
            sources.filter { $0.kind == kind.rawValue && !$0.isMuted }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let readings = Dictionary(
            states.map { ($0.itemID, NewsRules.Reading(status: $0.status, openedAt: $0.openedAt)) },
            uniquingKeysWith: { first, _ in first }
        )
        let byID = Dictionary(items.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        let candidates = items
            .filter { followed[$0.sourceID] != nil }
            .map { NewsRules.Candidate(itemID: $0.itemID, publishedAt: $0.publishedAt) }
        let started = listStartedAt > 0 ? Date(timeIntervalSince1970: listStartedAt) : nil
        return NewsRules.eligible(candidates, readings: readings, listStartedAt: started, now: .now).compactMap { candidate in
            guard let item = byID[candidate.itemID] else { return nil }
            return Entry(
                item: item,
                sourceName: followed[item.sourceID]?.title ?? "",
                appleID: followed[item.sourceID]?.appleID,
                status: readings[item.itemID]?.status ?? .new
            )
        }
    }

    private func headline(for entry: Entry) -> Headline {
        if isEpisodes {
            // An episode shows only its show's name; its length waits on the card.
            return Headline(
                id: entry.item.itemID,
                title: entry.item.title,
                detail: entry.sourceName,
                summary: entry.item.summary,
                fullText: entry.item.fullText,
                link: entry.item.linkURL,
                isUnread: entry.status.isUnread,
                isEpisode: true,
                episodeLength: entry.item.durationSeconds.map { PodcastRules.length(seconds: $0) }
            )
        }
        let age = HeadlineAge.text(for: entry.item.publishedAt)
        return Headline(
            id: entry.item.itemID,
            title: entry.item.title,
            detail: entry.sourceName.isEmpty ? age : "\(entry.sourceName) · \(age)",
            author: entry.item.author,
            summary: entry.item.summary,
            fullText: entry.item.fullText,
            link: entry.item.linkURL,
            isUnread: entry.status.isUnread
        )
    }

    private func actions(for entry: Entry) -> HeadlineActions {
        let item = entry.item
        let row = self.headline(for: entry)
        let openAction: (() -> Void)?
        if isEpisodes {
            openAction = { openEpisode(entry) }
        } else if row.link != nil {
            openAction = { open(item) }
        } else {
            openAction = nil
        }
        var actions = HeadlineActions(
            save: { save(item, sourceName: entry.sourceName) },
            useful: { resolve(item, as: .useful) },
            notUseful: { resolve(item, as: .notRelevant) },
            open: openAction,
            readLabel: row.readLabel,
            openLabel: isEpisodes ? "Open in Podcasts" : "Open the site",
            share: isEpisodes ? nil : row.link,
            shareTitle: row.title
        )
        if row.opensPanel {
            let panelActions = actions
            actions.readFull = {
                ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
                panel = PanelRequest(headline: row, actions: panelActions)
            }
        }
        return actions
    }

    // MARK: Actions

    private func tap(_ entry: Entry, headline: Headline) {
        let id = entry.item.itemID
        // Rows already open count as seen once another row is tapped, but stay open.
        for other in expandedIDs { markSeen(other) }
        // No animation, so the title stays put while the details appear under it.
        if expandedIDs.remove(id) == nil {
            expandedIDs.insert(id)
            pendingReveal = id
        }
    }

    private func markSeen(_ itemID: String) {
        guard let item = items.first(where: { $0.itemID == itemID }) else { return }
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
    }

    private func open(_ item: FeedItem) {
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
        if let url = item.linkURL {
            openURL(url)
        }
    }

    private func openEpisode(_ entry: Entry) {
        let item = entry.item
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
        EpisodeLink.open(showID: entry.appleID, guid: item.guid, title: item.title, fallback: item.linkURL, with: openURL)
    }

    private func save(_ item: FeedItem, sourceName: String) {
        // The row is gone at once; the rows below slide up briefly to close the gap.
        withAnimation(HeadlineMotion.close) {
            ReadingState.save(item, sourceTitle: sourceName, kind: kind, in: context)
        }
    }

    private func resolve(_ item: FeedItem, as status: ItemStatus) {
        // The row is gone at once; the rows below slide up briefly to close the gap.
        withAnimation(HeadlineMotion.close) {
            ReadingState.resolve(itemID: item.itemID, sourceID: item.sourceID, as: status, in: context)
        }
    }
}
