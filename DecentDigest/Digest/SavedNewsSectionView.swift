import DigestCore
import SwiftData
import SwiftUI

/// Headlines saved for later. Works like News but nothing here expires.
struct SavedNewsSectionView: View {
    var saved: [SavedItem]
    @Binding var panel: PanelRequest?

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query private var items: [FeedItem]
    @Query private var states: [ItemState]

    @State private var expandedID: String?

    var body: some View {
        Text(DigestSection.savedNews.title)
            .font(Theme.sectionTitleFont)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Theme.titleToList - HeadlineRow.verticalPadding)
            .digestRow()

        ForEach(saved, id: \.itemID) { item in
            let row = self.headline(for: item)
            HeadlineRow(headline: row, isExpanded: expandedID == item.itemID, actions: actions(for: item, headline: row)) {
                tap(item, headline: row)
            }
            .digestRow(background: expandedID == item.itemID ? Theme.expandedFill : .clear)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button("Useful") { resolve(item, as: .useful) }
                    .tint(Theme.swipeUseful)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Not useful") { resolve(item, as: .notRelevant) }
                    .tint(Theme.swipeNotRelevant)
            }
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
            openInSafari: headline.link == nil ? nil : { open(item) }
        )
        if headline.readsHere {
            let panelActions = actions
            actions.readFull = {
                ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
                panel = PanelRequest(headline: headline, actions: panelActions)
            }
        }
        return actions
    }

    private func tap(_ item: SavedItem, headline: Headline) {
        if headline.expands {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedID = expandedID == item.itemID ? nil : item.itemID
            }
        } else {
            open(item)
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
        withAnimation {
            ReadingState.resolve(itemID: itemID, sourceID: sourceID, as: status, in: context)
        }
    }
}
