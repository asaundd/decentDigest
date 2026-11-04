import DigestCore
import SwiftData
import SwiftUI

/// Live headlines from the followed feeds. Each headline is its own List row so it can be swiped.
struct NewsSectionView: View {
    var refresh: @Sendable (Bool) async -> Void
    @Binding var panel: PanelRequest?
    /// Scrolls an expanded row into view.
    var reveal: (String) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query(sort: \FeedItem.publishedAt, order: .reverse) private var items: [FeedItem]
    @Query private var sources: [Source]
    @Query private var states: [ItemState]
    @AppStorage(NewsRefresher.listStartedAtKey) private var listStartedAt: Double = 0

    @State private var refreshState = RefreshState.idle
    @State private var expandedID: String?
    @State private var showsAll = false

    private enum RefreshState {
        case idle, running, done

        var label: String {
            switch self {
            case .idle: "Refresh"
            case .running: "Checking…"
            case .done: "Up to date"
            }
        }
    }

    var body: some View {
        let eligible = eligibleEntries
        let shown = showsAll ? eligible : Array(eligible.prefix(NewsRules.itemsShown))
        let remaining = eligible.count - shown.count

        HStack(alignment: .firstTextBaseline) {
            Text(DigestSection.news.title)
                .font(Theme.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            TextLink(refreshState.label) {
                Task { await refreshNow() }
            }
            .disabled(refreshState == .running)
            .accessibilityHint("Checks your feeds for new headlines")
        }
        .padding(.bottom, Theme.titleToList - HeadlineRow.verticalPadding)
        .digestRow()

        if eligible.isEmpty {
            Text("No new headlines right now.")
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
                actions: actions(for: entry)
            ) {
                tap(entry, headline: row)
            }
            .digestRow(background: expandedID == entry.item.itemID ? Theme.expandedFill : .clear)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button("Useful") { resolve(entry.item, as: .useful) }
                    .tint(Theme.swipeUseful)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Not useful") { resolve(entry.item, as: .notRelevant) }
                    .tint(Theme.swipeNotRelevant)
            }
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
            openInSafari: row.link == nil ? nil : { open(item) }
        )
        if row.hasMore {
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
        if headline.expands {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedID = previous == id ? nil : id
            }
            if previous != id {
                reveal(id)
            }
        } else {
            expandedID = nil
            open(entry.item)
        }
    }

    private func markSeen(_ itemID: String) {
        guard let item = items.first(where: { $0.itemID == itemID }) else { return }
        ReadingState.markOpened(itemID: item.itemID, sourceID: item.sourceID, in: context)
    }

    private func refreshNow() async {
        refreshState = .running
        await refresh(true)
        refreshState = .done
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
