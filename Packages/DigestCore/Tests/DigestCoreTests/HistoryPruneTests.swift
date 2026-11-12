#if canImport(SwiftData)
import Foundation
import SwiftData
import Testing
@testable import DigestCore

@Suite struct HistoryPruneTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func recordsUntouchedForAYearAreDeleted() async throws {
        let container = try DigestStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let longAgo = now.addingTimeInterval(-400 * 86_400)
        context.insert(ItemState(itemID: "old", sourceID: "s", status: .ignored, firstShownAt: longAgo))
        let reopened = ItemState(itemID: "reopened", sourceID: "s", status: .read, firstShownAt: longAgo)
        reopened.openedAt = now.addingTimeInterval(-30 * 86_400)
        context.insert(reopened)
        context.insert(ItemState(itemID: "kept", sourceID: "s", status: .saved, firstShownAt: longAgo))
        context.insert(SavedItem(itemID: "kept", sourceID: "s", sourceTitle: "Example", title: "Kept", link: nil, summary: nil, author: nil, publishedAt: longAgo))
        context.insert(ItemState(itemID: "recent", sourceID: "s", status: .useful, firstShownAt: now.addingTimeInterval(-86_400)))
        try context.save()

        try await FeedStore(modelContainer: container).prune(now: now)

        let left = try ModelContext(container).fetch(FetchDescriptor<ItemState>()).map(\.itemID).sorted()
        #expect(left == ["kept", "recent", "reopened"])
    }

    @Test func anUndatedItemKeepsItsRecordWhenHistoryIsOff() async throws {
        let container = try DigestStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let weekAgo = now.addingTimeInterval(-8 * 86_400)
        let undated = FeedItem(itemID: "undated", sourceID: "s", title: "No date", link: nil, summary: nil, author: nil, publishedAt: weekAgo)
        undated.undated = true
        context.insert(undated)
        context.insert(FeedItem(itemID: "dated", sourceID: "s", title: "Dated", link: nil, summary: nil, author: nil, publishedAt: weekAgo))
        context.insert(ItemState(itemID: "undated", sourceID: "s", status: .new, firstShownAt: weekAgo))
        context.insert(ItemState(itemID: "dated", sourceID: "s", status: .new, firstShownAt: weekAgo))
        try context.save()

        try await FeedStore(modelContainer: container).prune(now: now, keepsHistory: false)

        let check = ModelContext(container)
        #expect(try check.fetchCount(FetchDescriptor<FeedItem>()) == 0)
        let states = try check.fetch(FetchDescriptor<ItemState>())
        #expect(states.map(\.itemID) == ["undated"])
        #expect(states.first?.status == .ignored)
    }
}
#endif
