import Foundation
import Testing
@testable import DigestCore

@Test func typedAddressesBecomeHTTPS() {
    #expect(FeedFinder.address(from: "stratechery.com")?.absoluteString == "https://stratechery.com")
    #expect(FeedFinder.address(from: " http://example.com/feed ")?.absoluteString == "https://example.com/feed")
    #expect(FeedFinder.address(from: "feed://example.com/rss")?.absoluteString == "https://example.com/rss")
    #expect(FeedFinder.address(from: "https://www.statnews.com/feed/")?.absoluteString == "https://www.statnews.com/feed/")
    #expect(FeedFinder.address(from: "health news") == nil)
    #expect(FeedFinder.address(from: "stratechery") == nil)
    #expect(FeedFinder.address(from: "ftp://example.com") == nil)
}

@Test func wordsAreSearchedAndAddressesAreFetched() {
    #expect(FeedFinder.looksLikeAddress("stratechery.com"))
    #expect(FeedFinder.looksLikeAddress("https://example.com/feed"))
    #expect(!FeedFinder.looksLikeAddress("Stratechery"))
    #expect(!FeedFinder.looksLikeAddress("product and leadership"))
}

@Test func findsTheFeedsAPageNames() throws {
    let html = """
    <html><head>
    <link rel="stylesheet" href="/style.css">
    <link rel="alternate" type="application/rss+xml" title="Posts" href="/feed/">
    <LINK REL='alternate' TYPE='application/atom+xml' HREF='https://example.com/atom.xml'>
    <link rel="alternate" type="application/rss+xml" href="http://example.com/insecure.xml">
    <link rel="alternate" type="text/html" href="/fr/">
    </head></html>
    """
    let base = try #require(URL(string: "https://example.com/blog/"))
    let links = FeedFinder.feedLinks(inHTML: html, base: base).map(\.absoluteString)
    #expect(links == ["https://example.com/feed/", "https://example.com/atom.xml"])
}

#if canImport(SwiftData)
@Test func followedFeedsMatchWithoutSchemeOrSlash() {
    #expect(Following.key(for: "https://www.statnews.com/feed/") == Following.key(for: "http://statnews.com/feed"))
    #expect(Following.key(for: "https://a.com/feed") != Following.key(for: "https://b.com/feed"))
}
#endif

@Test func localAndNumericAddressesAreRefused() throws {
    #expect(FeedFinder.address(from: "192.168.1.1") == nil)
    #expect(FeedFinder.address(from: "https://10.0.0.5/feed") == nil)
    #expect(FeedFinder.address(from: "https://[::1]/feed") == nil)
    #expect(FeedFinder.address(from: "localhost/feed") == nil)
    #expect(FeedFinder.address(from: "printer.local") == nil)
    #expect(FeedFinder.address(from: "example.com")?.absoluteString == "https://example.com")
    let html = """
    <link rel="alternate" type="application/rss+xml" href="https://192.168.1.1/feed">
    <link rel="alternate" type="application/rss+xml" href="https://example.com/feed">
    """
    let links = FeedFinder.feedLinks(inHTML: html, base: try #require(URL(string: "https://example.com")))
    #expect(links.map(\.absoluteString) == ["https://example.com/feed"])
}
