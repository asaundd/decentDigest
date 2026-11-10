#if canImport(SwiftData)
import Foundation
import SwiftData

/// Records what the reader does with a headline. Runs on the view's context so the list updates at once.
public enum ReadingState {
    /// Notes the first time an item is shown, so an item that expires untouched can be marked ignored.
    public static func markShown(itemID: String, sourceID: String, in context: ModelContext, now: Date = .now) {
        guard state(for: itemID, in: context) == nil else { return }
        context.insert(ItemState(itemID: itemID, sourceID: sourceID, status: .new, firstShownAt: now))
        try? context.save()
    }

    /// The reader opened the item.
    public static func markOpened(itemID: String, sourceID: String, in context: ModelContext, now: Date = .now) {
        let state = stateOrNew(itemID: itemID, sourceID: sourceID, in: context, now: now)
        if state.status.isUnread { state.status = .read }
        state.openedAt = now
        try? context.save()
    }

    /// Useful (swipe right) or not useful (swipe left): the item leaves its list, or Saved if it was saved.
    public static func resolve(itemID: String, sourceID: String, as status: ItemStatus, in context: ModelContext, now: Date = .now) {
        let state = stateOrNew(itemID: itemID, sourceID: sourceID, in: context, now: now)
        state.status = status
        state.resolvedAt = now
        let saved = FetchDescriptor<SavedItem>(predicate: #Predicate { $0.itemID == itemID })
        for item in (try? context.fetch(saved)) ?? [] {
            context.delete(item)
        }
        try? context.save()
    }

    /// Moves a headline or episode to Saved, where it stays until the reader marks it.
    public static func save(_ item: FeedItem, sourceTitle: String, kind: SourceKind = .news, in context: ModelContext, now: Date = .now) {
        let state = stateOrNew(itemID: item.itemID, sourceID: item.sourceID, in: context, now: now)
        state.status = .saved
        let itemID = item.itemID
        let existing = (try? context.fetchCount(FetchDescriptor<SavedItem>(predicate: #Predicate { $0.itemID == itemID }))) ?? 0
        if existing == 0 {
            context.insert(SavedItem(
                itemID: item.itemID,
                sourceID: item.sourceID,
                sourceTitle: sourceTitle,
                title: item.title,
                link: item.link,
                summary: item.summary,
                author: item.author,
                publishedAt: item.publishedAt,
                savedAt: now,
                kind: kind,
                durationSeconds: item.durationSeconds,
                guid: item.guid
            ))
        }
        try? context.save()
    }

    public static func state(for itemID: String, in context: ModelContext) -> ItemState? {
        var descriptor = FetchDescriptor<ItemState>(predicate: #Predicate { $0.itemID == itemID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func stateOrNew(itemID: String, sourceID: String, in context: ModelContext, now: Date) -> ItemState {
        if let state = state(for: itemID, in: context) { return state }
        let state = ItemState(itemID: itemID, sourceID: sourceID, status: .new, firstShownAt: now)
        context.insert(state)
        return state
    }
}
#endif
