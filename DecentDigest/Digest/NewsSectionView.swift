import DigestCore
import SwiftData
import SwiftUI

/// Live headlines from the followed feeds. Each headline can be expanded and swiped.
struct NewsSectionView: View {
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
    @State private var expandedID: String?
    @State private var pendingReveal: String?
    @State private var showsAll = false

    var body: some View {
        let eligible = eligibleEntries
        let shown = showsAll ? eligible : Array(eligible.prefix(NewsRules.itemsShown))
        let remaining = eligible.count - shown.count

        HStack(alignment: .firstTextBaseline) {
            Text(DigestSection.news.title)
                .font(Theme.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            TextLink(isRefreshing ? "Checking…" : (refreshedByReader ? "Up to date" : "Refresh")) {
                Task {
                    await refresh()
                    refreshedByReader = true
                }
            }
            .disabled(isRefreshing)
            .accessibilityHint("Checks your feeds for new headlines")
        }
        .padding(.bottom, Theme.titleToList - HeadlineRow.verticalPadding)
        .digestRow()

        if eligible.isEmpty {
            // On first launch the list fills in as each feed arrives.
            HStack(spacing: 8) {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(isRefreshing ? "Checking your feeds…" : "No new headlines right now.")
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
                isExpanded: expandedID == entry.item.itemID,
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
            .judgmentSwipes(useful: { resolve(entry.item, as: .useful) }, notUseful: { resolve(entry.item, as: .notRelevant) })
            .onAppear {
                ReadingState.markShown(itemID: entry.item.itemID, sourceID: entry.item.sourceID, in: context)
            }
        }

        if remaining > 0 || showsAll && eligible.count > NewsRules.itemsShown {
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
                TextLink(showsAll ? "Show fewer" : "Show all") {
                    withAnimation { showsAll.toggle() }
                }
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .digestRow()
        }
    }

    // MARK: Data

    private struct Entry {
        var item: FeedItem
        var sourceName: String
        var status: ItemStatus
    }

    private var eligibleEntries: [Entry] {
        let newsSources = Dictionary(
            sources.filter { $0.kind == SourceKind.news.rawValue && !$0.isMuted }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let readings = Dictionary(
            states.map { ($0.itemID, NewsRules.Reading(status: $0.status, openedAt: $0.openedAt)) },
            uniquingKeysWith: { first, _ in first }
        )
        let byID = Dictionary(items.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        let candidates = items
            .filter { newsSources[$0.sourceID] != nil }
            .map { NewsRules.Candidate(itemID: $0.itemID, publishedAt: $0.publishedAt) }
        let started = listStartedAt > 0 ? Date(timeIntervalSince1970: listStartedAt) : nil
        return NewsRules.eligible(candidates, readings: readings, listStartedAt: started, now: .now).compactMap { candidate in
            guard let item = byID[candidate.itemID] else { return nil }
            return Entry(
                item: item,
                sourceName: newsSources[item.sourceID]?.title ?? "",
                status: readings[item.itemID]?.status ?? .new
            )
        }
    }

    private func headline(for entry: Entry) -> Headline {
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
        var actions = HeadlineActions(
            save: { save(item, sourceName: entry.sourceName) },
            useful: { resolve(item, as: .useful) },
            notUseful: { resolve(item, as: .notRelevant) },
            openInSafari: row.link == nil ? nil : { open(item) },
            readLabel: row.readLabel
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
        let previous = expandedID
        // A row that was expanded and then closed counts as seen, even with no action taken.
        if let previous {
            markSeen(previous)
        }
        // No animation, so the title stays put while the details appear under it.
        expandedID = previous == id ? nil : id
        pendingReveal = expandedID
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

    private func save(_ item: FeedItem, sourceName: String) {
        withAnimation {
            ReadingState.save(item, sourceTitle: sourceName, in: context)
        }
    }

    private func resolve(_ item: FeedItem, as status: ItemStatus) {
        withAnimation {
            ReadingState.resolve(itemID: item.itemID, sourceID: item.sourceID, as: status, in: context)
        }
    }
}
