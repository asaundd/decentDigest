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
    #expect(!digest.events.isEmpty)
    #expect(!digest.todos.isEmpty)
    #expect(!digest.news.isEmpty)
    #expect(!digest.episodes.isEmpty)
}

@Test func onlyNewAndUnreadStayInTheList() {
    #expect(ItemStatus.new.isActive)
    #expect(ItemStatus.unread.isActive)
    #expect(!ItemStatus.useful.isActive)
    #expect(!ItemStatus.notRelevant.isActive)
}
