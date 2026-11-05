import DigestCore
import SwiftData
import SwiftUI

/// Headlines saved for later. Works like News but nothing here expires.
struct SavedNewsSectionView: View {
    var saved: [SavedItem]
    @Binding var panel: PanelRequest?
    /// Scrolls an expanded row into view if its bottom (on screen) is past the visible area.
    var reveal: (String, CGFloat) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query private var items: [FeedItem]
    @Query private var states: [ItemState]

    /// Open rows stay open until the reader closes them.
    @State private var expandedIDs: Set<String> = []
    @State private var pendingReveal: String?

    var body: some View {
        Text(DigestSection.savedNews.title)
            .font(Theme.sectionTitleFont)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Theme.titleToList - HeadlineRow.verticalPadding)
            .digestRow()

        ForEach(saved, id: \.itemID) { item in
            let row = self.headline(for: item)
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
            // A row that leaves is gone at once, with no fade.
            .transition(.identity)
            .judgmentSwipes(useful: { resolve(item, as: .useful) }, notUseful: { resolve(item, as: .notRelevant) })
        }
    }

    private func headline(for item: SavedItem) -> Headline {
        let age = HeadlineAge.text(for: item.publishedAt)
        // The full post is only on this device while the feed still lists it.
        let cached = items.first { $0.itemID == item.itemID }
        let opened = states.first { $0.itemID == item.itemID }?.openedAt != nil
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
        var actions = HeadlineActions(
            useful: { resolve(item, as: .useful) },
            notUseful: { resolve(item, as: .notRelevant) },
            openInSafari: headline.link == nil ? nil : { open(item) },
            readLabel: headline.readLabel
        )
        if headline.opensPanel {
            let panelActions = actions
            actions.readFull = {
                ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
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
        if expandedIDs.remove(item.itemID) == nil {
            expandedIDs.insert(item.itemID)
            pendingReveal = item.itemID
        }
    }

    private func open(_ item: SavedItem) {
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
        if let url = item.linkURL {
            openURL(url)
        }
    }

    private func resolve(_ item: SavedItem, as status: ItemStatus) {
        let itemID = item.itemID
        let sourceID = item.sourceID
        // No animation: the row is gone at once and the rows below close the gap in the same frame.
        ReadingState.resolve(itemID: itemID, sourceID: sourceID, as: status, in: context)
    }
}
