#if canImport(SwiftData)
import Foundation
import SwiftData
import Testing
@testable import DigestCore

@MainActor
@Test func deleteAllLeavesNothingBehind() throws {
    let container = try DigestStore.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let source = Source(feedURL: "https://example.com/feed", title: "Example")
    context.insert(source)
    context.insert(FetchState(sourceID: source.id))
    context.insert(FeedItem(itemID: "a", sourceID: source.id, title: "A", link: nil, summary: nil, author: nil, publishedAt: .now))
    context.insert(ItemState(itemID: "a", sourceID: source.id, status: .read))
    context.insert(ItemState(itemID: "b", sourceID: source.id, status: .saved))
    context.insert(SavedItem(itemID: "b", sourceID: source.id, sourceTitle: "Example", title: "B", link: nil, summary: nil, author: nil, publishedAt: .now))
    try context.save()

    try MyData.deleteAll(in: context)

    let fresh = ModelContext(container)
    #expect(try fresh.fetchCount(FetchDescriptor<Source>()) == 0)
    #expect(try fresh.fetchCount(FetchDescriptor<ItemState>()) == 0)
    #expect(try fresh.fetchCount(FetchDescriptor<SavedItem>()) == 0)
    #expect(try fresh.fetchCount(FetchDescriptor<FeedItem>()) == 0)
    #expect(try fresh.fetchCount(FetchDescriptor<FetchState>()) == 0)
}
#endif
