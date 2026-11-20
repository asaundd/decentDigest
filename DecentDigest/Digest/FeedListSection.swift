import DigestCore
import SwiftData
import SwiftUI

/// Live headlines from the followed feeds, or new episodes from the followed shows.
/// Each row can be expanded and swiped. News and Podcasts share every rule.
struct FeedListSection: View {
    /// News or podcasts.
    var kind: SourceKind = .news
    /// True while this list's feeds are being checked.
    var isRefreshing: Bool
    /// News' Refresh link on its footer line: checks every news feed now. Nil for Podcasts.
    var refresh: (() -> Void)? = nil
    @Binding var panel: PanelRequest?
    /// Scrolls an expanded row into view if its bottom (on screen) is past the visible area.
    var reveal: (String, CGFloat) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.scrollHold) private var scrollHold
    @Environment(NetworkStatus.self) private var network: NetworkStatus?

    @Query(sort: \FeedItem.publishedAt, order: .reverse) private var items: [FeedItem]
    @Query private var sources: [Source]
    @Query private var states: [ItemState]
    @AppStorage(NewsRefresher.listStartedAtKey) private var listStartedAt: Double = 0
    @AppStorage(NewsRefresher.offlineKey(.news)) private var newsOffline = false
    @AppStorage(NewsRefresher.offlineKey(.podcast)) private var podcastsOffline = false

    /// Open rows stay open until the reader closes them.
    @State private var expandedIDs: Set<String> = []
    @State private var pendingReveal: String?
    @State private var showsAll = false
    @State private var titlePlace = TitlePlace()
    /// Rows playing their leaving animation, and what was chosen for each.
    @State private var leaving: [String: RowAction] = [:]
    /// Rows closing up as they leave. They no longer count toward the rows shown, so the next one
    /// joins while they close and the list below them doesn't move twice.
    @State private var closing: Set<String> = []
    /// News' Clear all: the rows on screen and every row, as they were when it was tapped.
    @State private var clearing: Clearing?
    /// Rows cleared but not yet written: they leave the list at once while the writes finish.
    @State private var clearedIDs: Set<String> = []
    /// True while Clear all's writes run, so the footer can say so.
    @State private var isClearing = false

    var body: some View {
        let eligible = clearedIDs.isEmpty ? eligibleEntries : eligibleEntries.filter { !clearedIDs.contains($0.item.itemID) }
        // Bars stand in while the first feeds arrive. Rows already showing stay while feeds are checked.
        let waiting = isRefreshing && eligible.isEmpty
        // Show all opens the list up to 25 rows, never further.
        let shown = waiting ? [] : visible(eligible, limit: showsAll ? NewsRules.expandedLimit : limit)
        let staying = eligible.count(where: { !closing.contains($0.item.itemID) })
        let remaining = staying - shown.count(where: { !closing.contains($0.item.itemID) })

        Text(isEpisodes ? DigestSection.podcasts.title : DigestSection.news.title)
            .font(Theme.sectionTitleFont)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tracksPlace(in: titlePlace)
            .padding(.bottom, Theme.titleToFirstItem - HeadlineRow.verticalPadding)
        .digestRow()

        if waiting {
            // The rows replace the bars as each feed comes in.
            PlaceholderBars()
                .digestRow()
        } else if staying == 0 {
            // Shown as the last row starts closing up, in the same update, so the list's height
            // changes once instead of shrinking and then growing again.
            // While Clear all's writes run, the same line says so, so nothing moves when they end.
            Text(isClearing && !isEpisodes ? "Clearing…" : emptyMessage)
                .foregroundStyle(Theme.secondary)
                .contentTransition(.identity)
                .padding(.vertical, HeadlineRow.verticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .digestRow()
                .transition(.identity)
        }

        ForEach(shown, id: \.item.itemID) { entry in
            let row = self.headline(for: entry)
            HeadlineRow(
                headline: row,
                isExpanded: expandedIDs.contains(entry.item.itemID),
                actions: actions(for: entry, headline: row),
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
            .leaveSwipe(choices, request: leaving[entry.item.itemID], closing: {
                closing.insert(entry.item.itemID)
            }) { choice in
                finish(entry, as: choice)
            }
            // A row that leaves is gone at once. One that joins while another closes up stays
            // hidden until the rows above have finished sliding, then fades in, so it never
            // overlaps them.
            .joinFade(waits: !closing.isEmpty)
            .transition(.identity)
            .onAppear {
                ReadingState.markShown(itemID: entry.item.itemID, sourceID: entry.item.sourceID, in: context)
            }
        }

        // Podcasts always shows its line, for Podcasts ↗. News has no Refresh of its own: pull to
        // refresh and the footer's Refresh all do it.
        let toggles = !showsAll && remaining > 0 || showsAll && staying > limit
        // News' Clear all marks the whole list read at once, after a question.
        let offersClear = !isEpisodes && staying > 0
        if !waiting && (toggles || isEpisodes || offersClear) {
            ListFooter(
                hidden: showsAll ? 0 : remaining,
                reveals: NewsRules.expandedLimit - limit,
                phrase: { _ in "more" },
                showsAll: showsAll && staying > limit,
                app: isEpisodes ? ListFooter.Link(title: "Podcasts ↗", spoken: "Open Podcasts") { openURL(ApplePodcasts.app) } : nil,
                clear: offersClear ? ListFooter.Link(title: "Clear all", spoken: "Clear all news items") {
                    let open = eligible.filter { !closing.contains($0.item.itemID) && leaving[$0.item.itemID] == nil }
                    let onScreen = Set(shown.map(\.item.itemID))
                    clearing = Clearing(
                        visible: open.filter { onScreen.contains($0.item.itemID) }.map(\.item),
                        all: open.map(\.item)
                    )
                } : nil,
                isRefreshing: isRefreshing
            ) {
                let folding = showsAll
                showsAll.toggle()
                // Show less brings the list's title back when the reader had scrolled past it.
                if folding { scrollHold?.bringBack(titleTop: titlePlace.top) }
            }
            .padding(.top, 4)
            .digestRow()
            // The footer keeps the app's links color; only the question takes iOS's own.
            .tint(Theme.accent)
            .alert("Clear news items?", isPresented: clearingBinding, presenting: clearing) { clearing in
                if clearing.visible.count < clearing.all.count {
                    Button("Clear all visible (\(clearing.visible.count))", role: .destructive) { clear(clearing.visible) }
                }
                Button("Clear all (\(clearing.all.count))", role: .destructive) { clear(clearing.all) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Cleared items are marked read and will be removed from the list.")
            }
            .tint(Theme.alertTint)
        }
    }

    // MARK: Data

    private struct Clearing {
        var visible: [FeedItem]
        var all: [FeedItem]
    }

    private var clearingBinding: Binding<Bool> {
        Binding(get: { clearing != nil }, set: { if !$0 { clearing = nil } })
    }

    private var isEpisodes: Bool { kind == .podcast }

    /// The first rows up to the limit, plus any closing up among them, which don't count.
    private func visible(_ eligible: [Entry], limit: Int) -> [Entry] {
        var counted = 0
        return eligible.filter { entry in
            guard counted < limit else { return false }
            if !closing.contains(entry.item.itemID) { counted += 1 }
            return true
        }
    }

    private var limit: Int { isEpisodes ? PodcastRules.itemsShown : NewsRules.itemsShown }

    private var choices: [RowAction] { RowAction.choices(canSave: true) }

    private struct Entry {
        var item: FeedItem
        var sourceName: String
        var appleID: String?
        var status: ItemStatus
    }

    /// True while offline, or while this list's last check couldn't connect.
    private var isOffline: Bool { network?.isOffline == true || (isEpisodes ? podcastsOffline : newsOffline) }

    private var emptyMessage: String {
        if isOffline { return isEpisodes ? "New episodes will show once you’re connected." : "New items will show once you’re connected." }
        return isEpisodes ? "No new episodes right now." : "Nothing new right now."
    }

    private var eligibleEntries: [Entry] {
        let followed = Dictionary(
            sources.filter { $0.kind == kind.rawValue }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let byID = Dictionary(items.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        // Only the records of items still on the device matter here, not the whole history.
        let readings = Dictionary(
            states.lazy
                .filter { byID[$0.itemID] != nil }
                .map { ($0.itemID, NewsRules.Reading(status: $0.status, openedAt: $0.openedAt, resolvedAt: $0.resolvedAt)) },
            uniquingKeysWith: { first, _ in first }
        )
        let candidates = items
            .filter { followed[$0.sourceID] != nil }
            .map { NewsRules.Candidate(itemID: $0.itemID, publishedAt: $0.publishedAt) }
        let started = listStartedAt > 0 ? Date(timeIntervalSince1970: listStartedAt) : nil
        return NewsRules.eligible(candidates, readings: readings, listStartedAt: started, now: AppClock.now).compactMap { candidate in
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

    private func actions(for entry: Entry, headline row: Headline) -> HeadlineActions {
        let item = entry.item
        let openAction: (() -> Void)?
        if isEpisodes {
            openAction = { openEpisode(entry) }
        } else if row.link != nil {
            openAction = { open(item) }
        } else {
            openAction = nil
        }
        var actions = HeadlineActions(
            choices: choices,
            choose: { leaving[item.itemID] = $0 },
            open: openAction,
            readLabel: row.readLabel,
            openLabel: isEpisodes ? "Open in Podcasts" : "Open the site",
            share: isEpisodes ? nil : row.link,
            shareTitle: row.title
        )
        if row.opensPanel {
            let panelActions = actions
            actions.readFull = {
                ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, inDepth: true, in: context)
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
        if expandedIDs.contains(id) {
            scrollHold?.hold()
            // Closing a card counts as having opened it.
            markSeen(id)
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
            pendingReveal = id
        }
    }

    private func markSeen(_ itemID: String) {
        guard let item = items.first(where: { $0.itemID == itemID }) else { return }
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
    }

    private func open(_ item: FeedItem) {
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, inDepth: true, in: context)
        if let url = item.linkURL {
            openURL(url)
        }
    }

    private func openEpisode(_ entry: Entry) {
        let item = entry.item
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, inDepth: true, in: context)
        EpisodeLink.open(showID: entry.appleID, guid: item.guid, title: item.title, fallback: item.linkURL, with: openURL)
    }

    /// Clear all: the rows go together at once while the rows below slide up, then every item is
    /// marked read in one batch, after the page has moved, so the screen never waits on the writes.
    /// "Clearing…" shows in the empty list's line until they're done.
    private func clear(_ cleared: [FeedItem]) {
        let ids = Set(cleared.map(\.itemID))
        let opened = cleared.filter { expandedIDs.contains($0.itemID) }
        scrollHold?.hold()
        isClearing = true
        withAnimation(HeadlineMotion.close) {
            clearedIDs.formUnion(ids)
            expandedIDs.subtract(ids)
        }
        Task { @MainActor in
            // Let the rows' leaving animation start before the writes.
            try? await Task.sleep(for: .milliseconds(350))
            for item in opened {
                ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
            }
            ReadingState.resolveAll(cleared.map { (itemID: $0.itemID, sourceID: $0.sourceID) }, as: .read, in: context)
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) {
                clearedIDs.subtract(ids)
                isClearing = false
            }
        }
    }

    /// Records the action once the row has played its leaving animation and closed up: Save moves it
    /// to Saved, ✓ Read marks it done.
    private func finish(_ entry: Entry, as choice: RowAction) {
        let item = entry.item
        leaving[item.itemID] = nil
        // Marked from an open card: the history records that it was opened first.
        if expandedIDs.remove(item.itemID) != nil {
            ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
        }
        withAnimation(HeadlineMotion.close) {
            switch choice {
            case .save:
                ReadingState.save(item, sourceTitle: entry.sourceName, kind: kind, in: context)
            case .read:
                ReadingState.resolve(itemID: item.itemID, sourceID: item.sourceID, as: .read, in: context)
            }
        }
    }
}
