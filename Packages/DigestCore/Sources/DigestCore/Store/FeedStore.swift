#if canImport(SwiftData)
import Foundation
import SwiftData

/// The one place that writes fetched feeds into SwiftData, off the main thread.
@ModelActor
public actor FeedStore {
    /// Follows the default starter feeds when the reader has no news sources yet,
    /// and the default shows when the reader follows no podcasts yet.
    public func addStarterSourcesIfNeeded(library: FeedLibrary) throws {
        let news = SourceKind.news.rawValue
        let podcast = SourceKind.podcast.rawValue
        let newsCount = try modelContext.fetchCount(FetchDescriptor<Source>(predicate: #Predicate { $0.kind == news }))
        let podcastCount = try modelContext.fetchCount(FetchDescriptor<Source>(predicate: #Predicate { $0.kind == podcast }))
        if newsCount == 0 {
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
        }
        if podcastCount == 0 {
            for (index, show) in library.defaultPodcasts().enumerated() {
                modelContext.insert(Source(
                    kind: .podcast,
                    feedURL: show.feedUrl,
                    title: show.title,
                    category: show.category,
                    sortOrder: index,
                    appleID: show.appleId
                ))
            }
        }
        try modelContext.save()
    }

    /// Fetches every followed feed and show that is due, stores new items and prunes expired ones.
    /// - Parameter force: fetch every source now, even if it was fetched recently.
    /// - Returns: how many feeds were fetched.
    @discardableResult
    public func refresh(force: Bool = false, now: Date = .now, fetcher: FeedFetcher = FeedFetcher()) async -> Int {
        let jobs: [Job]
        do {
            jobs = try dueJobs(force: force, now: now)
        } catch {
            return 0
        }
        guard !jobs.isEmpty else { return 0 }

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
        return jobs.count
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
        var kind: SourceKind
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
        let sources = try modelContext.fetch(FetchDescriptor<Source>(
            predicate: #Predicate { !$0.isMuted },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))
        let states = Dictionary(try modelContext.fetch(FetchDescriptor<FetchState>()).map { ($0.sourceID, $0) }, uniquingKeysWith: { first, _ in first })
        return sources.compactMap { source in
            let state = states[source.id]
            if !force, let last = state?.lastFetchedAt, now.timeIntervalSince(last) < NewsRules.refreshInterval {
                return nil
            }
            // Until a source has a backfill cutoff, fetch it in full so the cutoff can be set.
            let hasCutoff = state?.backfillCutoff != nil
            return Job(
                sourceID: source.id,
                kind: SourceKind(rawValue: source.kind) ?? .news,
                feedURL: source.feedURL,
                etag: hasCutoff ? state?.etag : nil,
                lastModified: hasCutoff ? state?.lastModified : nil
            )
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
            let backfillCutoff: Date
            if let existing = state.backfillCutoff {
                backfillCutoff = existing
            } else {
                let dates = feed.items.map { $0.published ?? now }
                // News starts with today's items; a new show with its newest episode from the last week.
                backfillCutoff = job.kind == .podcast
                    ? PodcastRules.backfillCutoff(publishedDates: dates, now: now)
                    : NewsRules.backfillCutoff(publishedDates: dates, now: now)
                state.backfillCutoff = backfillCutoff
                removeUntouchedItems(sourceID: job.sourceID, before: backfillCutoff)
            }
            insert(feed.items, sourceID: job.sourceID, feedURL: job.feedURL, notBefore: backfillCutoff, now: now)
        }
    }

    /// Clears cached items from before a new backfill cutoff that the reader never saw.
    private func removeUntouchedItems(sourceID: String, before cutoff: Date) {
        let descriptor = FetchDescriptor<FeedItem>(predicate: #Predicate { $0.sourceID == sourceID && $0.publishedAt < cutoff })
        guard let old = try? modelContext.fetch(descriptor), !old.isEmpty else { return }
        let stateDescriptor = FetchDescriptor<ItemState>(predicate: #Predicate { $0.sourceID == sourceID })
        let touched = Set(((try? modelContext.fetch(stateDescriptor)) ?? []).filter { $0.openedAt != nil || $0.resolvedAt != nil }.map(\.itemID))
        for item in old where !touched.contains(item.itemID) {
            modelContext.delete(item)
        }
    }

    private func insert(_ items: [ParsedItem], sourceID: String, feedURL: String, notBefore backfillCutoff: Date, now: Date) {
        let cutoff = max(NewsRules.expiryCutoff(now: now), backfillCutoff)
        let descriptor = FetchDescriptor<FeedItem>(predicate: #Predicate { $0.sourceID == sourceID })
        var known = Dictionary(((try? modelContext.fetch(descriptor)) ?? []).map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        for item in items {
            let itemID = ItemID.make(feedURL: feedURL, guidOrLink: item.identity)
            if let existing = known[itemID] {
                // Fill in text an earlier version of the app didn't keep.
                if existing.fullText == nil, let fullText = item.fullText { existing.fullText = fullText }
                if existing.author == nil, let author = item.author { existing.author = author }
                if existing.durationSeconds == nil, let duration = item.durationSeconds { existing.durationSeconds = duration }
                if existing.guid == nil, let guid = item.guid { existing.guid = guid }
                continue
            }
            let published = item.published ?? now
            guard published >= cutoff else { continue }
            let feedItem = FeedItem(
                itemID: itemID,
                sourceID: sourceID,
                title: item.title,
                link: item.link,
                summary: item.summary,
                fullText: item.fullText,
                author: item.author,
                // A future date (bad clock on the server) would pin an item to the top.
                publishedAt: min(published, now),
                fetchedAt: now,
                durationSeconds: item.durationSeconds,
                guid: item.guid
            )
            modelContext.insert(feedItem)
            known[itemID] = feedItem
        }
    }
}
#endif
