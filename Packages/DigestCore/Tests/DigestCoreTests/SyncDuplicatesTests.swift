#if canImport(SwiftData)
import Foundation
import SwiftData
import Testing
@testable import DigestCore

@MainActor @Suite struct SyncDuplicatesTests {
    let container: ModelContainer
    let context: ModelContext
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try DigestStore.makeContainer(inMemory: true)
        context = ModelContext(container)
    }

    @Test func aFeedFollowedTwiceBecomesOneSource() throws {
        let first = Source(feedURL: "https://www.example.com/feed/", title: "Example")
        first.addedAt = now
        let second = Source(feedURL: "http://example.com/feed", title: "Example", appleID: nil)
        second.addedAt = now.addingTimeInterval(60)
        second.siteURL = "https://example.com"
        let podcast = Source(kind: .podcast, feedURL: "https://example.com/feed", title: "Same address, other kind")
        context.insert(first)
        context.insert(second)
        context.insert(podcast)
        context.insert(ItemState(itemID: "a", sourceID: second.id, status: .read))
        context.insert(SavedItem(itemID: "b", sourceID: second.id, sourceTitle: "Example", title: "B", link: nil, summary: nil, author: nil, publishedAt: now))
        context.insert(FeedItem(itemID: "a", sourceID: first.id, title: "A", link: nil, summary: nil, author: nil, publishedAt: now))
        context.insert(FeedItem(itemID: "a", sourceID: second.id, title: "A", link: nil, summary: nil, author: nil, publishedAt: now))
        context.insert(FeedItem(itemID: "c", sourceID: second.id, title: "C", link: nil, summary: nil, author: nil, publishedAt: now))
        context.insert(FetchState(sourceID: second.id))
        try context.save()

        #expect(try SyncDuplicates.merge(in: context))

        let sources = try context.fetch(FetchDescriptor<Source>())
        #expect(sources.count == 2)
        let news = try #require(sources.first { $0.kind == SourceKind.news.rawValue })
        #expect(news.id == first.id)
        #expect(news.siteURL == "https://example.com")
        #expect(try context.fetch(FetchDescriptor<ItemState>()).allSatisfy { $0.sourceID == first.id })
        #expect(try context.fetch(FetchDescriptor<SavedItem>()).allSatisfy { $0.sourceID == first.id })
        let items = try context.fetch(FetchDescriptor<FeedItem>())
        #expect(items.map(\.itemID).sorted() == ["a", "c"])
        #expect(items.allSatisfy { $0.sourceID == first.id })
        #expect(try context.fetch(FetchDescriptor<FetchState>()).map(\.sourceID) == [first.id])
    }

    @Test func theLatestMarkWinsForAnItem() throws {
        let earlier = ItemState(itemID: "x", sourceID: "s", status: .notRelevant, firstShownAt: now.addingTimeInterval(-600))
        earlier.resolvedAt = now.addingTimeInterval(-60)
        let later = ItemState(itemID: "x", sourceID: "s", status: .useful, firstShownAt: now.addingTimeInterval(-300))
        later.resolvedAt = now
        let opened = ItemState(itemID: "x", sourceID: "s", status: .read, firstShownAt: now.addingTimeInterval(-900))
        opened.openedAt = now.addingTimeInterval(-120)
        for state in [opened, earlier, later] { context.insert(state) }
        try context.save()

        try SyncDuplicates.merge(in: context)

        let states = try context.fetch(FetchDescriptor<ItemState>())
        #expect(states.count == 1)
        #expect(states.first?.status == .useful)
        #expect(states.first?.resolvedAt == now)
        #expect(states.first?.firstShownAt == now.addingTimeInterval(-900))
        #expect(states.first?.openedAt == now.addingTimeInterval(-120))
    }

    @Test func savedBeatsOpenedWhenNothingWasMarked() throws {
        context.insert(ItemState(itemID: "y", sourceID: "s", status: .read))
        context.insert(ItemState(itemID: "y", sourceID: "s", status: .saved))
        context.insert(ItemState(itemID: "z", sourceID: "s", status: .new))
        try context.save()

        try SyncDuplicates.merge(in: context)

        let states = try context.fetch(FetchDescriptor<ItemState>())
        #expect(states.count == 2)
        #expect(states.first { $0.itemID == "y" }?.status == .saved)
    }

    @Test func anItemSavedTwiceIsSavedOnce() throws {
        for offset in [120.0, 0, 60] {
            context.insert(SavedItem(itemID: "s1", sourceID: "s", sourceTitle: "Example", title: "Saved", link: nil, summary: nil, author: nil, publishedAt: now, savedAt: now.addingTimeInterval(offset)))
        }
        try context.save()

        try SyncDuplicates.merge(in: context)

        let saved = try context.fetch(FetchDescriptor<SavedItem>())
        #expect(saved.count == 1)
        #expect(saved.first?.savedAt == now)
    }

    @Test func nothingToMergeChangesNothing() throws {
        context.insert(Source(feedURL: "https://example.com/feed", title: "Example"))
        context.insert(ItemState(itemID: "x", sourceID: "s"))
        try context.save()

        #expect(try SyncDuplicates.merge(in: context) == false)
        #expect(try context.fetchCount(FetchDescriptor<Source>()) == 1)
    }

    @Test func followingAFeedAlreadyFollowedAddsNothing() throws {
        let feed = Following.Feed(kind: .news, feedURL: "https://example.com/feed", title: "Example")
        Following.follow(feed, in: context)
        Following.follow(Following.Feed(kind: .news, feedURL: "http://www.example.com/feed/", title: "Example"), in: context)
        #expect(try context.fetchCount(FetchDescriptor<Source>()) == 1)
        #expect(Following.isFollowing("https://example.com/feed", in: try context.fetch(FetchDescriptor<Source>())))
    }
}
#endif
