import DigestCore
import SwiftData
import SwiftUI

/// Headlines and episodes saved for later. Works like News and Podcasts, but nothing here expires.
struct SavedSectionView: View {
    var saved: [SavedItem]
    @Binding var panel: PanelRequest?
    /// Scrolls an expanded row into view if its bottom (on screen) is past the visible area.
    var reveal: (String, CGFloat) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.scrollHold) private var scrollHold

    @Query private var items: [FeedItem]
    /// Only the records of saved items, not the whole reading history.
    @Query(filter: #Predicate<ItemState> { $0.statusRaw == "saved" }) private var states: [ItemState]
    @Query private var sources: [Source]

    /// Open rows stay open until the reader closes them.
    @State private var expandedIDs: Set<String> = []
    @State private var pendingReveal: String?
    /// Rows playing their leaving animation, and what was chosen for each.
    @State private var leaving: [String: RowAction] = [:]
    @State private var showsAll = false
    @State private var titlePlace = TitlePlace()

    /// Like News, Saved shows a few rows, then "N more · Show all".
    private let limit = NewsRules.itemsShown

    var body: some View {
        Text(DigestSection.saved.title)
            .font(Theme.sectionTitleFont)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tracksPlace(in: titlePlace)
            .padding(.bottom, Theme.titleToFirstItem - HeadlineRow.verticalPadding)
            .digestRow()

        let shown = Array(saved.prefix(showsAll ? NewsRules.expandedLimit : limit))
        // Looked up once per redraw, not once per row.
        let shownIDs = Set(shown.map(\.itemID))
        let cached = Dictionary(items.lazy.filter { shownIDs.contains($0.itemID) }.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        ForEach(shown, id: \.itemID) { item in
            let row = self.headline(for: item, cached: cached[item.itemID])
            HeadlineRow(
                headline: row,
                isExpanded: expandedIDs.contains(item.itemID),
                actions: actions(for: item, headline: row),
                onExpandedBottom: { bottom in
                    guard pendingReveal == item.itemID else { return }
                    pendingReveal = nil
                    reveal(item.itemID, bottom)
                }
            ) {
                tap(item, headline: row)
            }
            .digestRow()
            .id(item.itemID)
            // A row that leaves is gone at once. One that joins waits for the slide, then fades in,
            // so it never overlaps the rows still moving.
            .transition(HeadlineMotion.transition)
            .leaveSwipe(choices, request: leaving[item.itemID]) { choice in
                finish(item, as: choice)
            }
        }

        if saved.count > limit {
            ListFooter(
                hidden: showsAll ? 0 : saved.count - shown.count,
                phrase: { _ in "more" },
                empty: nil,
                showsAll: showsAll,
                showTitle: NewsRules.showMoreTitle(count: saved.count),
                app: nil
            ) {
                let folding = showsAll
                showsAll.toggle()
                // Show less brings the list's title back when the reader had scrolled past it.
                if folding { scrollHold?.bringBack(titleTop: titlePlace.top) }
            }
            .padding(.top, 4)
            .digestRow()
        }
    }

    /// - Parameter cached: the item as the feed last sent it; the full post is only on this device
    ///   while the feed still lists it.
    private func headline(for item: SavedItem, cached: FeedItem?) -> Headline {
        let opened = states.first { $0.itemID == item.itemID }?.openedAt != nil
        if item.isEpisode {
            return Headline(
                id: item.itemID,
                title: item.title,
                // Saved holds both kinds, so an episode says what it is.
                detail: item.sourceTitle.isEmpty ? "Episode" : "Episode · \(item.sourceTitle)",
                summary: item.summary,
                fullText: cached?.fullText,
                link: item.linkURL,
                isUnread: !opened,
                isEpisode: true,
                episodeLength: item.durationSeconds.map { PodcastRules.length(seconds: $0) }
            )
        }
        let age = HeadlineAge.text(for: item.publishedAt)
        return Headline(
            id: item.itemID,
            title: item.title,
            detail: item.sourceTitle.isEmpty ? age : "\(item.sourceTitle) · \(age)",
            author: item.author,
            summary: item.summary,
            fullText: cached?.fullText,
            link: item.linkURL,
            isUnread: !opened
        )
    }

    private func actions(for item: SavedItem, headline: Headline) -> HeadlineActions {
        let openAction: (() -> Void)?
        if item.isEpisode {
            openAction = { openEpisode(item) }
        } else if headline.link != nil {
            openAction = { open(item) }
        } else {
            openAction = nil
        }
        var actions = HeadlineActions(
            choices: choices,
            choose: { leaving[item.itemID] = $0 },
            open: openAction,
            readLabel: headline.readLabel,
            openLabel: item.isEpisode ? "Open in Podcasts" : "Open the site",
            share: item.isEpisode ? nil : headline.link,
            shareTitle: headline.title
        )
        if headline.opensPanel {
            let panelActions = actions
            actions.readFull = {
                ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, inDepth: true, in: context)
                panel = PanelRequest(headline: headline, actions: panelActions)
            }
        }
        return actions
    }

    private func tap(_ item: SavedItem, headline: Headline) {
        // Rows already open count as seen once another row is tapped, but stay open.
        for seen in saved where expandedIDs.contains(seen.itemID) {
            ReadingState.markOpened(itemID: seen.itemID, sourceID: seen.sourceID, in: context)
        }
        // No animation, so the title stays put while the details appear under it.
        if expandedIDs.contains(item.itemID) {
            scrollHold?.hold()
            // Closing a card counts as having opened it.
            ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
            expandedIDs.remove(item.itemID)
        } else {
            expandedIDs.insert(item.itemID)
            pendingReveal = item.itemID
        }
    }

    private func open(_ item: SavedItem) {
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, inDepth: true, in: context)
        if let url = item.linkURL {
            openURL(url)
        }
    }

    private func openEpisode(_ item: SavedItem) {
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, inDepth: true, in: context)
        let showID = sources.first { $0.id == item.sourceID }?.appleID
        EpisodeLink.open(showID: showID, guid: item.guid, title: item.title, fallback: item.linkURL, with: openURL)
    }

    /// Already saved, so ✓ Read is the only action.
    private var choices: [RowAction] { RowAction.choices(canSave: false) }

    /// Records the action once the row has played its leaving animation and closed up.
    private func finish(_ item: SavedItem, as choice: RowAction) {
        let itemID = item.itemID
        let sourceID = item.sourceID
        leaving[itemID] = nil
        // Marked from an open card: the history records that it was opened first.
        if expandedIDs.remove(itemID) != nil {
            ReadingState.markOpened(itemID: itemID, sourceID: sourceID, in: context)
        }
        withAnimation(HeadlineMotion.close) {
            ReadingState.resolve(itemID: itemID, sourceID: sourceID, as: .read, in: context)
        }
    }
}
