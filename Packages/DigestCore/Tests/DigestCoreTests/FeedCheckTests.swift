import Foundation
import Testing
@testable import DigestCore

/// A check of real feeds over the network, for keeping the feed library healthy.
///
/// It is skipped unless the folder `~/Public/feed-check` exists, so ordinary test runs never
/// touch the network. When it runs, it reads `candidates.txt` in that folder (one feed per line:
/// `topic|title|site address|feed address|access`), or the bundled library when there is no such
/// file, fetches each feed the way the app does, and writes `results.json` beside it.
enum FeedCheck {
    struct Candidate: Codable, Sendable {
        var topic: String
        var title: String
        var site: String
        var feed: String
        var access: String
    }

    struct Report: Codable, Sendable {
        var order: Int
        var candidate: Candidate
        var ok = false
        /// Why the listed feed address failed, if it did.
        var error: String?
        /// Set when the listed address failed but the site names another feed that works.
        var workingFeed: String?
        var feedTitle: String?
        var items = 0
        /// The newest item's date, as yyyy-MM-dd.
        var newest: String?
        var itemsInLast30Days = 0
        var fullPost = 0
        var excerpt = 0
        var summary = 0
        var linkOnly = 0
    }

    static let folder = URL(filePath: NSHomeDirectory()).appending(path: "Public/feed-check", directoryHint: .isDirectory)

    static var isRequested: Bool {
        FileManager.default.fileExists(atPath: folder.path(percentEncoded: false))
    }

    static func candidates() throws -> [Candidate] {
        let list = folder.appending(path: "candidates.txt")
        if let text = try? String(contentsOf: list, encoding: .utf8) {
            return text.split(whereSeparator: \.isNewline).compactMap { line in
                let parts = line.split(separator: "|", omittingEmptySubsequences: false).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard parts.count >= 5, !parts[0].hasPrefix("#") else { return nil }
                return Candidate(topic: parts[0], title: parts[1], site: parts[2], feed: parts[3], access: parts[4])
            }
        }
        return try FeedLibrary.bundled().feeds.map {
            Candidate(topic: $0.category, title: $0.title, site: $0.siteUrl, feed: $0.feedUrl, access: $0.access ?? "")
        }
    }

    static func check(_ candidate: Candidate, order: Int) async -> Report {
        var report = Report(order: order, candidate: candidate)
        do {
            fill(&report, with: try await parsed(candidate.feed))
            report.ok = true
        } catch {
            report.error = String(describing: error)
            // The address may have moved: ask the site, as the app does with a pasted address.
            if let found = try? await FeedFinder.find(candidate.site),
               found.feedURL != candidate.feed,
               let feed = try? await parsed(found.feedURL) {
                report.workingFeed = found.feedURL
                fill(&report, with: feed)
                report.ok = true
            }
        }
        return report
    }

    static func parsed(_ address: String) async throws -> ParsedFeed {
        switch try await FeedFetcher(timeout: 20).fetch(feedURL: address, etag: nil, lastModified: nil) {
        case .fetched(let feed, _, _): return feed
        case .notModified: throw FeedFetcher.FetchError.http(304)
        }
    }

    static func fill(_ report: inout Report, with feed: ParsedFeed) {
        report.feedTitle = feed.title
        report.items = feed.items.count
        let dates = feed.items.compactMap(\.published)
        if let newest = dates.max() {
            report.newest = newest.formatted(.iso8601.year().month().day())
        }
        let monthAgo = Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        report.itemsInLast30Days = dates.filter { $0 > monthAgo }.count
        for item in feed.items {
            switch PostKind.classify(summary: item.summary, fullText: item.fullText) {
            case .fullPost: report.fullPost += 1
            case .excerpt: report.excerpt += 1
            case .summary: report.summary += 1
            case .titleOnly: report.linkOnly += 1
            }
        }
    }
}

@Test(.enabled(if: FeedCheck.isRequested), .timeLimit(.minutes(10)))
func checkFeeds() async throws {
    let candidates = try FeedCheck.candidates()
    let reports = await withTaskGroup(of: FeedCheck.Report.self) { group in
        var next = 0
        var done: [FeedCheck.Report] = []
        while true {
            // Keep 12 checks going at a time.
            while next < candidates.count, next - done.count < 12 {
                let candidate = candidates[next]
                let order = next
                group.addTask { await FeedCheck.check(candidate, order: order) }
                next += 1
            }
            guard let report = await group.next() else { break }
            done.append(report)
        }
        return done.sorted { $0.order < $1.order }
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(reports).write(to: FeedCheck.folder.appending(path: "results.json"))
}
