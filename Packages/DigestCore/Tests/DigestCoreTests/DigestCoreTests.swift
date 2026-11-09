import Foundation
import Testing
@testable import DigestCore

@Test func itemIDIsStable() {
    let a = ItemID.make(feedURL: "https://example.com/feed", guidOrLink: "post-1")
    let b = ItemID.make(feedURL: "https://example.com/feed", guidOrLink: "post-1")
    let c = ItemID.make(feedURL: "https://example.com/feed", guidOrLink: "post-2")
    #expect(a == b)
    #expect(a != c)
    #expect(a.count == 64)
}

@Test func bundledFeedLibraryLoads() throws {
    let library = try FeedLibrary.bundled()
    #expect(library.categories.count == 5)
    for category in library.categories {
        let starters = library.starterFeeds(in: category.id)
        #expect(!starters.isEmpty)
        #expect(starters.allSatisfy { $0.feedUrl.hasPrefix("https://") })
    }
}

@Test func sampleDigestHasEverySection() {
    let digest = SampleDigest.make()
    #expect(digest.weather != nil)
    #expect(digest.weatherPlace != nil)
    #expect(!digest.events.isEmpty)
    #expect(!digest.todos.isEmpty)
    #expect(!digest.news.isEmpty)
    #expect(!digest.episodes.isEmpty)
}

@Test func readItemsStayButResolvedItemsLeave() {
    #expect(ItemStatus.new.isActive)
    #expect(ItemStatus.unread.isActive)
    #expect(ItemStatus.read.isActive)
    #expect(!ItemStatus.useful.isActive)
    #expect(!ItemStatus.notRelevant.isActive)
    #expect(!ItemStatus.ignored.isActive)
    #expect(ItemStatus.new.isUnread)
    #expect(!ItemStatus.read.isUnread)
}

@Test func defaultFeedsAreHTTPSAndCoverEveryCategory() throws {
    let library = try FeedLibrary.bundled()
    let feeds = library.defaultFeeds()
    #expect(feeds.count == library.categories.count * NewsRules.starterFeedsPerCategory)
    #expect(feeds.allSatisfy { $0.feedUrl.hasPrefix("https://") })
    #expect(Set(feeds.map(\.category)).count == library.categories.count)
    #expect(!feeds.contains { $0.id == "nature" })
}
