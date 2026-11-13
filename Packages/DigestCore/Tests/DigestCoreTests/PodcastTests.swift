import Foundation
import Testing
@testable import DigestCore

@Test func readsEpisodeLengths() {
    #expect(PodcastRules.durationSeconds("01:08:19") == 4_099)
    #expect(PodcastRules.durationSeconds("58:00") == 3_480)
    #expect(PodcastRules.durationSeconds("3723") == 3_723)
    #expect(PodcastRules.durationSeconds("") == nil)
    #expect(PodcastRules.durationSeconds("about an hour") == nil)
}

@Test func writesEpisodeLengths() {
    #expect(PodcastRules.length(seconds: 3_480) == "58 min")
    #expect(PodcastRules.length(seconds: 4_099) == "1 hr 8 min")
    #expect(PodcastRules.length(seconds: 7_200) == "2 hr")
    #expect(PodcastRules.length(seconds: 20) == "1 min")
}

@Test func newShowBringsItsNewestEpisodeFromTheLastWeek() {
    let now = Date(timeIntervalSince1970: 1_794_000_000)
    let twoDaysAgo = now.addingTimeInterval(-2 * 86_400)
    let fiveDaysAgo = now.addingTimeInterval(-5 * 86_400)
    let nineDaysAgo = now.addingTimeInterval(-9 * 86_400)
    #expect(PodcastRules.backfillCutoff(publishedDates: [fiveDaysAgo, twoDaysAgo, nineDaysAgo], now: now) == twoDaysAgo)
    // Nothing recent: only episodes from now on come in.
    #expect(PodcastRules.backfillCutoff(publishedDates: [nineDaysAgo], now: now) == now)
    #expect(PodcastRules.backfillCutoff(publishedDates: [], now: now) == now)
}

@Test func parsesPodcastFields() throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <title>Hard Fork</title>
        <item>
          <guid isPermaLink="false">24554896-fc5f-409d-b8c7-a3524586f3ed</guid>
          <title>Why the Tech Right Lost Big This Week</title>
          <pubDate>Fri, 6 Nov 2026 11:00:00 +0000</pubDate>
          <itunes:author>The New York Times</itunes:author>
          <itunes:duration>01:08:19</itunes:duration>
          <itunes:summary>Kevin and Casey on the week in tech.</itunes:summary>
        </item>
      </channel>
    </rss>
    """
    let feed = try FeedParser.parse(Data(xml.utf8))
    let item = try #require(feed.items.first)
    #expect(item.guid == "24554896-fc5f-409d-b8c7-a3524586f3ed")
    #expect(item.durationSeconds == 4_099)
    #expect(item.summary == "Kevin and Casey on the week in tech.")
    #expect(item.author == "The New York Times")
}

private let lookup = """
{"resultCount":3,"results":[
 {"wrapperType":"track","kind":"podcast","collectionId":1528594034,"collectionViewUrl":"https://podcasts.apple.com/us/podcast/hard-fork/id1528594034?uo=4"},
 {"wrapperType":"podcastEpisode","kind":"podcast-episode","trackName":"Are We in an A.I. Bubble? We're About to Find Out.","episodeGuid":"54147085-2b19-4a9a-8168-21bc0bb2f086","trackViewUrl":"https://podcasts.apple.com/us/podcast/x/id1528594034?i=1000798873825&uo=4"},
 {"wrapperType":"podcastEpisode","kind":"podcast-episode","trackName":"What's a Hard Fork?","episodeGuid":"4e573fc5-f8ff-404c-af6e-a003d8835d31","trackViewUrl":"https://podcasts.apple.com/us/podcast/y/id1528594034?i=1000580800516&uo=4"}
]}
"""

@Test func findsTheEpisodeInApplePodcasts() {
    let data = Data(lookup.utf8)
    let byGuid = ApplePodcasts.match(lookup: data, guid: "4e573fc5-f8ff-404c-af6e-a003d8835d31", title: "Something else")
    #expect(byGuid?.absoluteString.contains("i=1000580800516") == true)
    // Titles match when the guid doesn't, ignoring case and curly quotes.
    let byTitle = ApplePodcasts.match(lookup: data, guid: "other", title: "What’s a hard fork?")
    #expect(byTitle?.absoluteString.contains("i=1000580800516") == true)
    // An episode Apple hasn't listed yet opens the show instead.
    let show = ApplePodcasts.match(lookup: data, guid: nil, title: "Brand new episode")
    #expect(show?.absoluteString == "https://podcasts.apple.com/us/podcast/hard-fork/id1528594034?uo=4")
}

private let chart = """
{"feed":{"title":"Top Shows","country":"us","results":[
 {"artistName":"The New York Times","id":"1200361736","name":"The Daily","kind":"podcasts"},
 {"artistName":"Someone","id":"1528594034","name":"Hard Fork","kind":"podcasts"},
 {"artistName":"Nobody","id":"not-a-number","name":"Odd","kind":"podcasts"}
]}}
"""

@Test func topChartKeepsItsOrder() throws {
    let ids = try #require(ApplePodcasts.chartIDs(fromChart: Data(chart.utf8)))
    #expect(ids == ["1200361736", "1528594034"])
    #expect(ApplePodcasts.chartIDs(fromChart: Data("nope".utf8)) == nil)
    // The lookup may answer in its own order; the chart's order wins, and strays are left out.
    let looked = [
        ApplePodcasts.Show(id: "1528594034", title: "Hard Fork", feedURL: "https://example.com/a"),
        ApplePodcasts.Show(id: "999", title: "Stray", feedURL: "https://example.com/b"),
        ApplePodcasts.Show(id: "1200361736", title: "The Daily", feedURL: "https://example.com/c"),
    ]
    #expect(ApplePodcasts.inChartOrder(looked, ids: ids).map(\.title) == ["The Daily", "Hard Fork"])
}

@Test func topChartSendsOnlyTheCountry() {
    let urls = ApplePodcasts.chartURLs(country: "gb")
    #expect(urls.first?.absoluteString == "https://rss.marketingtools.apple.com/api/v2/gb/podcasts/top/20/podcasts.json")
    #expect(urls.allSatisfy { $0.query == nil })
}

private let search = """
{"resultCount":3,"results":[
 {"wrapperType":"track","kind":"podcast","collectionId":1528594034,"collectionName":"Hard Fork","artistName":"The New York Times","feedUrl":"https://feeds.simplecast.com/6HKOhNgS"},
 {"wrapperType":"track","kind":"podcast","collectionId":111,"collectionName":"Old Show","artistName":"Someone","feedUrl":"http://example.com/feed"},
 {"wrapperType":"track","kind":"podcast","collectionId":222,"collectionName":"No Feed"}
]}
"""

@Test func podcastSearchKeepsShowsWithHTTPSFeeds() {
    let shows = ApplePodcasts.shows(fromSearch: Data(search.utf8))
    #expect(shows.map(\.title) == ["Hard Fork"])
    #expect(shows.first?.id == "1528594034")
    #expect(shows.first?.author == "The New York Times")
    #expect(ApplePodcasts.shows(fromSearch: Data("nope".utf8)).isEmpty)
}

@Test func podcastSearchSendsOnlyTheTypedWords() throws {
    let url = try #require(ApplePodcasts.searchURL("  hard fork "))
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(url.host() == "itunes.apple.com")
    #expect(items.first { $0.name == "term" }?.value == "hard fork")
    #expect(items.first { $0.name == "media" }?.value == "podcast")
    #expect(ApplePodcasts.searchURL("   ") == nil)
}
