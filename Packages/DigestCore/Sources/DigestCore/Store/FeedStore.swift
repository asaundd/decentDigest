#if canImport(SwiftData)
import Foundation
import SwiftData

/// The one place that writes fetched feeds into SwiftData, off the main thread.
@ModelActor
public actor FeedStore {
    /// Follows the default starter feeds when the reader has no sources yet.
    public func addStarterSourcesIfNeeded(library: FeedLibrary) throws {
        let existing = try modelContext.fetchCount(FetchDescriptor<Source>())
        guard existing == 0 else { return }
        for (index, feed) in library.defaultFeeds().enumerated() {
            modelContext.insert(Source(
                kind: .news,
                feedURL: feed.feedUrl,
                siteURL: feed.siteUrl,
                title: feed.title,
                category: feed.category,
                sortOrder: index
            ))
        }
        try modelContext.save()
    }

    /// Fetches every followed news feed that is due, stores new headlines and prunes expired ones.
    /// - Parameter force: fetch every source now, even if it was fetched recently.
    public func refresh(force: Bool = false, now: Date = .now, fetcher: FeedFetcher = FeedFetcher()) async {
        let jobs: [Job]
        do {
            jobs = try dueJobs(force: force, now: now)
        } catch {
            return
        }

        await withTaskGroup(of: (Job, Swift.Result<FeedFetcher.Result, Error>).self) { group in
            var queue = jobs.makeIterator()
            for _ in 0..<NewsRules.maxConcurrentFetches {
                guard let job = queue.next() else { break }
                group.addTask { await Self.run(job, with: fetcher) }
            }
            for await (job, result) in group {
                store(result, for: job, now: now)
                // Save per feed so headlines appear as each feed arrives.
                try? modelContext.save()
                if let next = queue.next() {
                    group.addTask { await Self.run(next, with: fetcher) }
                }
            }
        }

        try? prune(now: now)
        try? modelContext.save()
    }

    /// Deletes cached items past the expiry window. Items shown but never touched are recorded as ignored.
    public func prune(now: Date = .now) throws {
        let cutoff = NewsRules.expiryCutoff(now: now)
        let expired = try modelContext.fetch(FetchDescriptor<FeedItem>(predicate: #Predicate { $0.publishedAt < cutoff }))
        guard !expired.isEmpty else { return }
        let expiredIDs = Set(expired.map(\.itemID))
        let states = try modelContext.fetch(FetchDescriptor<ItemState>(predicate: #Predicate { $0.resolvedAt == nil }))
        for state in states where expiredIDs.contains(state.itemID) && state.status.isUnread {
            state.status = .ignored
            state.resolvedAt = now
        }
        for item in expired { modelContext.delete(item) }
        try modelContext.save()
    }

    // MARK: Private

    private struct Job: Sendable {
        var sourceID: String
        var feedURL: String
        var etag: String?
        var lastModified: String?
    }

    private static func run(_ job: Job, with fetcher: FeedFetcher) async -> (Job, Swift.Result<FeedFetcher.Result, Error>) {
        do {
            return (job, .success(try await fetcher.fetch(feedURL: job.feedURL, etag: job.etag, lastModified: job.lastModified)))
        } catch {
            return (job, .failure(error))
        }
    }

    private func dueJobs(force: Bool, now: Date) throws -> [Job] {
        let news = SourceKind.news.rawValue
        let sources = try modelContext.fetch(FetchDescriptor<Source>(
            predicate: #Predicate { $0.kind == news && !$0.isMuted },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))
        let states = Dictionary(try modelContext.fetch(FetchDescriptor<FetchState>()).map { ($0.sourceID, $0) }, uniquingKeysWith: { first, _ in first })
        return sources.compactMap { source in
            let state = states[source.id]
            if !force, let last = state?.lastFetchedAt, now.timeIntervalSince(last) < NewsRules.refreshInterval {
                return nil
            }
            return Job(sourceID: source.id, feedURL: source.feedURL, etag: state?.etag, lastModified: state?.lastModified)
        }
    }

    private func fetchState(for sourceID: String) -> FetchState {
        let descriptor = FetchDescriptor<FetchState>(predicate: #Predicate { $0.sourceID == sourceID })
        if let state = try? modelContext.fetch(descriptor).first { return state }
        let state = FetchState(sourceID: sourceID)
        modelContext.insert(state)
        return state
    }

    private func store(_ result: Swift.Result<FeedFetcher.Result, Error>, for job: Job, now: Date) {
        let state = fetchState(for: job.sourceID)
        state.lastFetchedAt = now
        switch result {
        case .failure(let error):
            state.lastError = String(describing: error)
            state.failureCount += 1
        case .success(.notModified):
            state.lastError = nil
            state.failureCount = 0
        case .success(.fetched(let feed, let etag, let lastModified)):
            state.etag = etag
            state.lastModified = lastModified
            state.lastError = nil
            state.failureCount = 0
            insert(feed.items, sourceID: job.sourceID, feedURL: job.feedURL, now: now)
        }
    }

    private func insert(_ items: [ParsedItem], sourceID: String, feedURL: String, now: Date) {
        let cutoff = NewsRules.expiryCutoff(now: now)
        let descriptor = FetchDescriptor<FeedItem>(predicate: #Predicate { $0.sourceID == sourceID })
        var known = Set(((try? modelContext.fetch(descriptor)) ?? []).map(\.itemID))
        for item in items {
            let published = item.published ?? now
            guard published >= cutoff else { continue }
            let itemID = ItemID.make(feedURL: feedURL, guidOrLink: item.identity)
            guard known.insert(itemID).inserted else { continue }
            modelContext.insert(FeedItem(
                itemID: itemID,
                sourceID: sourceID,
                title: item.title,
                link: item.link,
                summary: item.summary,
                author: item.author,
                // A future date (bad clock on the server) would pin an item to the top.
                publishedAt: min(published, now),
                fetchedAt: now
            ))
        }
    }
}
#endif
