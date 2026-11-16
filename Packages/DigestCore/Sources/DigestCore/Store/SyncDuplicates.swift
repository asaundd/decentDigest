#if canImport(SwiftData)
import Foundation
import SwiftData

/// Folds together records that iCloud sync left doubled. CloudKit can't enforce unique values,
/// so two devices (or a reinstall that runs setup again before iCloud catches up) can each add
/// the same followed feed, the same item's reading record or the same saved item. Each pass keeps
/// one record per feed or item and carries over what the others knew.
public enum SyncDuplicates {
    /// Merges duplicate sources, reading records and saved items. Returns true when anything changed.
    @discardableResult
    public static func merge(in context: ModelContext) throws -> Bool {
        let sources = try mergeSources(in: context)
        let states = try mergeItemStates(in: context)
        let saved = try mergeSavedItems(in: context)
        let changed = sources || states || saved
        if changed { try context.save() }
        return changed
    }

    // MARK: Sources

    /// One source per kind and feed address (compared by `Following.key(for:)`). The one followed
    /// first stays; records that point at the others move over to it.
    static func mergeSources(in context: ModelContext) throws -> Bool {
        let all = try context.fetch(FetchDescriptor<Source>())
        let groups = Dictionary(grouping: all) { "\($0.kind)|\(Following.key(for: $0.feedURL))" }
        var changed = false
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted { ($0.addedAt, $0.id) < ($1.addedAt, $1.id) }
            let keeper = ordered[0]
            for extra in ordered.dropFirst() {
                keeper.siteURL = keeper.siteURL ?? extra.siteURL
                keeper.category = keeper.category ?? extra.category
                keeper.appleID = keeper.appleID ?? extra.appleID
                try moveRecords(from: extra.id, to: keeper.id, in: context)
                context.delete(extra)
            }
            changed = true
        }
        return changed
    }

    private static func moveRecords(from oldID: String, to newID: String, in context: ModelContext) throws {
        for state in try context.fetch(FetchDescriptor<ItemState>(predicate: #Predicate { $0.sourceID == oldID })) {
            state.sourceID = newID
        }
        for saved in try context.fetch(FetchDescriptor<SavedItem>(predicate: #Predicate { $0.sourceID == oldID })) {
            saved.sourceID = newID
        }
        // Cached items and fetch state stay on this device. Keep the cached items the keeper
        // doesn't have yet, and the fetch state only if the keeper has none.
        let kept = Set(try context.fetch(FetchDescriptor<FeedItem>(predicate: #Predicate { $0.sourceID == newID })).map(\.itemID))
        for item in try context.fetch(FetchDescriptor<FeedItem>(predicate: #Predicate { $0.sourceID == oldID })) {
            if kept.contains(item.itemID) {
                context.delete(item)
            } else {
                item.sourceID = newID
            }
        }
        let keeperHasFetch = try context.fetchCount(FetchDescriptor<FetchState>(predicate: #Predicate { $0.sourceID == newID })) > 0
        for fetch in try context.fetch(FetchDescriptor<FetchState>(predicate: #Predicate { $0.sourceID == oldID })) {
            if keeperHasFetch {
                context.delete(fetch)
            } else {
                fetch.sourceID = newID
            }
        }
    }

    // MARK: Reading records

    /// One reading record per item. The latest choice wins: a record marked Relevant, Not relevant,
    /// Read or ignored beats one that wasn't, the later of two such marks wins, and otherwise Saved
    /// beats opened, which beats unread and new. The first time shown and opened carry over.
    static func mergeItemStates(in context: ModelContext) throws -> Bool {
        let all = try context.fetch(FetchDescriptor<ItemState>())
        let groups = Dictionary(grouping: all, by: \.itemID)
        var changed = false
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted { wins($0, over: $1) }
            let keeper = ordered[0]
            for extra in ordered.dropFirst() {
                keeper.firstShownAt = earliest(keeper.firstShownAt, extra.firstShownAt)
                keeper.openedAt = earliest(keeper.openedAt, extra.openedAt)
                keeper.readInDepthAt = earliest(keeper.readInDepthAt, extra.readInDepthAt)
                context.delete(extra)
            }
            changed = true
        }
        return changed
    }

    /// True when `a` should be kept over `b`.
    static func wins(_ a: ItemState, over b: ItemState) -> Bool {
        switch (a.resolvedAt, b.resolvedAt) {
        case let (x?, y?) where x != y: return x > y
        case (.some, nil): return true
        case (nil, .some): return false
        default: break
        }
        let ra = rank(a.status), rb = rank(b.status)
        if ra != rb { return ra > rb }
        return (a.firstShownAt ?? .distantFuture) < (b.firstShownAt ?? .distantFuture)
    }

    private static func rank(_ status: ItemStatus) -> Int {
        switch status {
        case .useful, .notRelevant, .ignored: 5
        case .saved: 4
        case .read: 3
        case .unread: 2
        case .new: 1
        }
    }

    private static func earliest(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (x?, y?): min(x, y)
        default: a ?? b
        }
    }

    // MARK: Saved items

    /// One saved item per item: the one saved first stays.
    static func mergeSavedItems(in context: ModelContext) throws -> Bool {
        let all = try context.fetch(FetchDescriptor<SavedItem>())
        let groups = Dictionary(grouping: all, by: \.itemID)
        var changed = false
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted { $0.savedAt < $1.savedAt }
            for extra in ordered.dropFirst() { context.delete(extra) }
            changed = true
        }
        return changed
    }
}
#endif
