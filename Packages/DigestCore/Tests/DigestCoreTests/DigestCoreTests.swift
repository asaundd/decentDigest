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

@Test func choosingATopicFollowsItsTwoMostPopularSites() throws {
    let library = try FeedLibrary.bundled()
    for category in library.categories {
        let picks = library.topicPicks(in: category.id)
        #expect(picks.count == NewsRules.starterFeedsPerCategory)
        #expect(picks.allSatisfy { $0.feedUrl.hasPrefix("https://") && $0.category == category.id })
        #expect(!picks.contains { $0.id == "nature" })
    }
}

@Test func topicNamesAreSentenceCase() throws {
    let library = try FeedLibrary.bundled()
    #expect(library.categories.map(\.name).contains("Healthtech and digital health"))
    #expect(!library.categories.contains { $0.name.contains("&") })
}

@Test func librarySearchMatchesNamesFirst() throws {
    let library = try FeedLibrary.bundled()
    let found = library.searchFeeds("strat")
    #expect(found.first?.title.lowercased().hasPrefix("strat") == true)
    #expect(library.searchFeeds("   ").isEmpty)
    #expect(library.searchFeeds("a", limit: 3).count <= 3)
}

@MainActor @Test func skippedSectionsStayOff() {
    let defaults = UserDefaults(suiteName: "prefs-\(UUID().uuidString)")!
    let prefs = DigestPreferences(defaults: defaults)
    #expect(!prefs.hasFinishedSetup)
    #expect(prefs.isShown(.news))
    prefs.setShown(false, .news)
    prefs.finishSetup()

    let reopened = DigestPreferences(defaults: defaults)
    #expect(reopened.hasFinishedSetup)
    #expect(!reopened.isShown(.news))
    #expect(reopened.isShown(.podcasts))
    reopened.setShown(true, .news)
    #expect(DigestPreferences(defaults: defaults).isShown(.news))
}
