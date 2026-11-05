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
    let readings: [String: NewsRules.Reading] = [
        "i0": .init(status: .useful),
        "i1": .init(status: .notRelevant),
        "i2": .init(status: .read, openedAt: now),
        "i3": .init(status: .saved),
    ]
    let shown = NewsRules.visible(candidates, readings: readings, now: now)
    #expect(shown.map(\.itemID) == ["i2", "i4", "i5", "i6", "i7"])
    #expect(NewsRules.eligible(candidates, readings: readings, listStartedAt: nil, now: now).count == 7)
}

@Test func openedItemsLeaveAfterTheNextRefresh() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let candidates = [
        NewsRules.Candidate(itemID: "before", publishedAt: now.addingTimeInterval(-600)),
        NewsRules.Candidate(itemID: "after", publishedAt: now.addingTimeInterval(-500)),
    ]
    let readings: [String: NewsRules.Reading] = [
        "before": .init(status: .read, openedAt: now.addingTimeInterval(-300)),
        "after": .init(status: .read, openedAt: now.addingTimeInterval(-60)),
    ]
    let shown = NewsRules.visible(candidates, readings: readings, listStartedAt: now.addingTimeInterval(-120), now: now)
    #expect(shown.map(\.itemID) == ["after"])
}

@Test func firstFetchStartsTodayOrYesterday() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9))!
    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
    #expect(NewsRules.backfillCutoff(publishedDates: [now.addingTimeInterval(-3_600), threeDaysAgo], now: now, calendar: calendar) == today)
    #expect(NewsRules.backfillCutoff(publishedDates: [now.addingTimeInterval(-12 * 3_600), threeDaysAgo], now: now, calendar: calendar) == yesterday)
    #expect(NewsRules.backfillCutoff(publishedDates: [], now: now, calendar: calendar) == yesterday)
}

@Test func keepsFullPostWhenTheFeedCarriesOne() throws {
    let long = (1...20).map { "<p>Paragraph \($0) has enough words to make the post longer than a summary.</p>" }.joined()
    let xml = """
    <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel><title>T</title>
    <item><title>Long</title><link>https://example.com/long</link><description>Short teaser.</description>
    <content:encoded><![CDATA[\(long)]]></content:encoded></item>
    <item><title>Short</title><link>https://example.com/short</link><description>Just a line.</description></item>
    </channel></rss>
    """
    let feed = try FeedParser.parse(Data(xml.utf8))
    let full = try #require(feed.items[0].fullText)
    #expect(feed.items[0].summary == "Short teaser.")
    #expect(full.hasPrefix("Paragraph 1 has"))
    #expect(full.contains("\n\nParagraph 2 has"))
    #expect(feed.items[1].fullText == nil)
}

@Test func paragraphsKeepBreaksAndDropTags() {
    let text = HTMLText.paragraphs("<p>One <b>bold</b></p>\n\n<p>Two<br>lines</p><ul><li>a</li><li>b</li></ul>")
    #expect(text == "One bold\n\nTwo\nlines\n\n– a\n– b")
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

@Test func classifiesHowMuchOfAPostTheFeedCarries() {
    let long = String(repeating: "A full sentence of the post. ", count: 80)
    #expect(PostKind.classify(summary: "Teaser", fullText: long) == .fullPost)
    #expect(PostKind.classify(summary: "Teaser", fullText: long + "\n\nContinue reading on Example →") == .excerpt)
    #expect(PostKind.classify(summary: "Teaser", fullText: long + "\n\nThe post Title appeared first on Example.") == .excerpt)
    #expect(PostKind.classify(summary: "Teaser", fullText: "Two short paragraphs.\n\nThen a cut") == .excerpt)
    #expect(PostKind.classify(summary: "A short teaser.", fullText: nil) == .summary)
    #expect(PostKind.classify(summary: "The opening lines and then…", fullText: nil) == .excerpt)
    #expect(PostKind.classify(summary: nil, fullText: nil) == .titleOnly)
    #expect(PostKind.previewText(summary: "Short", fullText: "Short plus more") == "Short plus more")
    #expect(PostKind.previewText(summary: "Short", fullText: nil) == "Short")
}

@Test func rowTextIsClippedAtAWord() {
    let text = String(repeating: "word ", count: 200)
    let clipped = PostKind.clipForRow(text)
    #expect(clipped.count <= PostKind.rowTextLimit + 1)
    #expect(clipped.hasSuffix("word…"))
    #expect(PostKind.clipForRow("Short.") == "Short.")
}
