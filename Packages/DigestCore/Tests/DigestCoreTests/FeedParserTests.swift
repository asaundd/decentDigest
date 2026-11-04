import Foundation
import Testing
@testable import DigestCore

private func data(_ string: String) -> Data { Data(string.utf8) }

@Test func parsesRSS() throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:dc="http://purl.org/dc/elements/1.1/">
      <channel>
        <title>Example News</title>
        <link>https://example.com</link>
        <item>
          <title><![CDATA[Hospitals &amp; clinics rebuild their portals]]></title>
          <link>https://example.com/a</link>
          <guid isPermaLink="false">post-1</guid>
          <pubDate>Tue, 03 Nov 2026 14:30:00 GMT</pubDate>
          <dc:creator>Jane Doe</dc:creator>
          <description><![CDATA[<p>A look at <b>why</b> health systems&#8217; front doors matter.</p>]]></description>
          <content:encoded><![CDATA[<p>The whole article, which is never kept.</p>]]></content:encoded>
        </item>
        <item>
          <title>Second story</title>
          <link>https://example.com/b</link>
          <pubDate>Mon, 2 Nov 2026 09:00:00 -0500</pubDate>
        </item>
      </channel>
    </rss>
    """
    let feed = try FeedParser.parse(data(xml))
    #expect(feed.title == "Example News")
    #expect(feed.items.count == 2)
    let first = feed.items[0]
    #expect(first.title == "Hospitals & clinics rebuild their portals")
    #expect(first.link == "https://example.com/a")
    #expect(first.guid == "post-1")
    #expect(first.author == "Jane Doe")
    #expect(first.summary == "A look at why health systems’ front doors matter.")
    #expect(first.published == Date(timeIntervalSince1970: 1_793_716_200))
    #expect(first.identity == "post-1")
    let second = feed.items[1]
    #expect(second.guid == nil)
    #expect(second.identity == "https://example.com/b")
    #expect(second.published == Date(timeIntervalSince1970: 1_793_628_000))
}

@Test func parsesAtom() throws {
    let xml = """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Simon's Weblog</title>
      <link href="https://example.org/" rel="alternate"/>
      <entry>
        <title type="html">On-device models &lt;em&gt;keep&lt;/em&gt; improving</title>
        <link href="https://example.org/2026/nov/3/models/" rel="alternate"/>
        <link href="https://example.org/2026/nov/3/models/#comments" rel="replies"/>
        <id>tag:example.org,2026:entry-1</id>
        <published>2026-11-03T22:10:00+00:00</published>
        <updated>2026-11-04T08:00:00Z</updated>
        <author><name>Simon</name></author>
        <summary type="html">&lt;p&gt;Notes from a week.&lt;/p&gt;</summary>
      </entry>
    </feed>
    """
    let feed = try FeedParser.parse(data(xml))
    #expect(feed.title == "Simon's Weblog")
    let entry = try #require(feed.items.first)
    #expect(entry.title == "On-device models keep improving")
    #expect(entry.link == "https://example.org/2026/nov/3/models/")
    #expect(entry.guid == "tag:example.org,2026:entry-1")
    #expect(entry.author == "Simon")
    #expect(entry.summary == "Notes from a week.")
    #expect(entry.published == Date(timeIntervalSince1970: 1_793_743_800))
}

@Test func parsesRDF() throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/" xmlns:dc="http://purl.org/dc/elements/1.1/">
      <channel rdf:about="https://www.nature.com/nature.rss"><title>Nature</title></channel>
      <item rdf:about="https://www.nature.com/articles/x1">
        <title>A new kind of cell</title>
        <link>https://www.nature.com/articles/x1</link>
        <dc:date>2026-11-02</dc:date>
      </item>
    </rdf:RDF>
    """
    let feed = try FeedParser.parse(data(xml))
    #expect(feed.title == "Nature")
    let item = try #require(feed.items.first)
    #expect(item.guid == "https://www.nature.com/articles/x1")
    #expect(item.title == "A new kind of cell")
    #expect(item.published != nil)
}

@Test func rejectsHTML() {
    #expect(throws: FeedParserError.notAFeed) {
        try FeedParser.parse(data("<html><body><p>Not a feed</p></body></html>"))
    }
}

@Test func plainTextStripsTagsAndTrims() {
    #expect(HTMLText.plain("<p>One&nbsp;<a href='x'>two</a></p>\n<p>three</p>") == "One two three")
    #expect(HTMLText.plain("<script>var x = 1;</script>Hello") == "Hello")
    #expect(HTMLText.plain("&lt;b&gt;bold&lt;/b&gt; &amp; plain") == "bold & plain")
    let long = String(repeating: "word ", count: 300)
    let cut = HTMLText.plain(long, limit: FeedParser.summaryLimit)
    #expect(cut.count <= FeedParser.summaryLimit + 1)
    #expect(cut.hasSuffix("…"))
}

@Test func parsesFeedDates() {
    #expect(FeedDate.parse("Tue, 03 Nov 2026 14:30:00 GMT") == Date(timeIntervalSince1970: 1_793_716_200))
    #expect(FeedDate.parse("Tue, 03 Nov 2026 14:30:00 +0000") == Date(timeIntervalSince1970: 1_793_716_200))
    #expect(FeedDate.parse("Tues, 03 Nov 2026 14:30:00 +0000") == Date(timeIntervalSince1970: 1_793_716_200))
    #expect(FeedDate.parse("2026-11-03T14:30:00Z") == Date(timeIntervalSince1970: 1_793_716_200))
    #expect(FeedDate.parse("2026-11-03T14:30:00.000Z") == Date(timeIntervalSince1970: 1_793_716_200))
    #expect(FeedDate.parse("2026-11-03T09:30:00-05:00") == Date(timeIntervalSince1970: 1_793_716_200))
    #expect(FeedDate.parse("not a date") == nil)
}

@Test func itemIdentityFallsBackToTitleAndDate() {
    let item = ParsedItem(title: "Untitled post", published: Date(timeIntervalSince1970: 100))
    #expect(item.identity == "Untitled post|100")
}

@Test func visibleNewsIsNewestFirstLimitedAndSkipsResolved() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let candidates = (0..<10).map { NewsRules.Candidate(itemID: "i\($0)", publishedAt: now.addingTimeInterval(Double(-$0) * 3_600)) }
        + [NewsRules.Candidate(itemID: "old", publishedAt: now.addingTimeInterval(-30 * 86_400))]
    let statuses: [String: ItemStatus] = ["i0": .useful, "i1": .notRelevant, "i2": .read]
    let shown = NewsRules.visible(candidates, statuses: statuses, now: now)
    #expect(shown.map(\.itemID) == ["i2", "i3", "i4", "i5", "i6"])
}

@Test func headlineAgeReadsLikeTheMockups() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9))!
    #expect(HeadlineAge.text(for: now.addingTimeInterval(-30), now: now, calendar: calendar) == "Just now")
    #expect(HeadlineAge.text(for: now.addingTimeInterval(-4 * 60), now: now, calendar: calendar) == "4 min")
    #expect(HeadlineAge.text(for: now.addingTimeInterval(-2 * 3_600), now: now, calendar: calendar) == "2 hr")
    #expect(HeadlineAge.text(for: now.addingTimeInterval(-20 * 3_600), now: now, calendar: calendar) == "Yesterday")
    #expect(HeadlineAge.text(for: now.addingTimeInterval(-3 * 86_400), now: now, calendar: calendar) == "3 days")
}
