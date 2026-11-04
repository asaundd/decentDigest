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

    /// Swipe right (useful) or left (not relevant): the item leaves the digest.
    public static func resolve(itemID: String, sourceID: String, as status: ItemStatus, in context: ModelContext, now: Date = .now) {
        let state = stateOrNew(itemID: itemID, sourceID: sourceID, in: context, now: now)
        state.status = status
        state.resolvedAt = now
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
