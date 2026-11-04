import DigestCore
import SwiftData
import SwiftUI

/// Live headlines from the followed feeds. Each headline is its own List row so it can be swiped.
struct NewsSectionView: View {
    var refresh: @Sendable (Bool) async -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query(sort: \FeedItem.publishedAt, order: .reverse) private var items: [FeedItem]
    @Query private var sources: [Source]
    @Query private var states: [ItemState]
    @State private var refreshState = RefreshState.idle

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
        let shown = visibleItems

        HStack(alignment: .firstTextBaseline) {
            Text(DigestSection.news.title)
                .font(Theme.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(refreshState.label) {
                Task { await refreshNow() }
            }
            .buttonStyle(.borderless)
            .font(Theme.actionFont)
            .foregroundStyle(Theme.accent)
            .underline()
            .disabled(refreshState == .running)
            .accessibilityHint("Checks your feeds for new headlines")
        }
        .padding(.bottom, Theme.titleToList - NewsRow.verticalPadding)
        .digestRow()

        if shown.isEmpty {
            Text("No new headlines right now.")
                .foregroundStyle(Theme.secondary)
                .padding(.vertical, NewsRow.verticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .digestRow()
        }

        ForEach(shown, id: \.item.itemID) { entry in
            NewsRow(title: entry.item.title, detail: detail(for: entry), isUnread: entry.status.isUnread) {
                open(entry.item)
            }
            .digestRow()
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button("Useful") { resolve(entry.item, as: .useful) }
                    .tint(Theme.swipeUseful)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Not relevant") { resolve(entry.item, as: .notRelevant) }
                    .tint(Theme.swipeNotRelevant)
            }
            .onAppear {
                ReadingState.markShown(itemID: entry.item.itemID, sourceID: entry.item.sourceID, in: context)
            }
        }
    }

    private struct Entry {
        var item: FeedItem
        var sourceName: String
        var status: ItemStatus
    }

    private var visibleItems: [Entry] {
        let newsSources = Dictionary(
            sources.filter { $0.kind == SourceKind.news.rawValue && !$0.isMuted }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let statuses = Dictionary(states.map { ($0.itemID, $0.status) }, uniquingKeysWith: { first, _ in first })
        let byID = Dictionary(items.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        let candidates = items
            .filter { newsSources[$0.sourceID] != nil }
            .map { NewsRules.Candidate(itemID: $0.itemID, publishedAt: $0.publishedAt) }
        return NewsRules.visible(candidates, statuses: statuses, now: .now).compactMap { candidate in
            guard let item = byID[candidate.itemID] else { return nil }
            return Entry(
                item: item,
                sourceName: newsSources[item.sourceID]?.title ?? "",
                status: statuses[item.itemID] ?? .new
            )
        }
    }

    private func detail(for entry: Entry) -> String {
        let age = HeadlineAge.text(for: entry.item.publishedAt)
        return entry.sourceName.isEmpty ? age : "\(entry.sourceName) · \(age)"
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

    private func resolve(_ item: FeedItem, as status: ItemStatus) {
        withAnimation {
            ReadingState.resolve(itemID: item.itemID, sourceID: item.sourceID, as: status, in: context)
        }
    }
}

/// One headline: dash, title (semibold while unread, gray once read), feed name and age, and ↗ because it opens Safari.
struct NewsRow: View {
    static let verticalPadding: CGFloat = 5

    var title: String
    var detail: String
    var isUnread: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("–")
                    .foregroundStyle(Theme.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(isUnread ? .semibold : .regular)
                        .foregroundStyle(isUnread ? Theme.ink : Theme.secondary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("↗")
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.vertical, Self.verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityValue(Text(isUnread ? "Unread" : "Read"))
        .accessibilityHint("Opens in Safari")
        .accessibilityAddTraits(.isButton)
    }
}
