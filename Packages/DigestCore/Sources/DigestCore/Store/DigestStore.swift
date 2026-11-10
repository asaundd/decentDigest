#if canImport(SwiftData)
import Foundation
import SwiftData

/// Builds the app's SwiftData container: one store that syncs through iCloud and one that stays on the device.
public enum DigestStore {
    public static var syncedModels: [any PersistentModel.Type] { [Source.self, ItemState.self, SavedItem.self] }
    public static var localModels: [any PersistentModel.Type] { [FeedItem.self, FetchState.self] }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let synced = ModelConfiguration(
            "Synced",
            schema: Schema(syncedModels),
            isStoredInMemoryOnly: inMemory,
            // Syncs to the private iCloud database once the app has the iCloud capability;
            // until then it stays on the device.
            cloudKitDatabase: inMemory ? ModelConfiguration.CloudKitDatabase.none : ModelConfiguration.CloudKitDatabase.automatic
        )
        let local = ModelConfiguration(
            "Local",
            schema: Schema(localModels),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: Schema(syncedModels + localModels), configurations: [synced, local])
    }

    /// An in-memory container filled with sample headlines and episodes, for previews.
    @MainActor
    public static func previewContainer(now: Date = .now) -> ModelContainer {
        do {
            let container = try makeContainer(inMemory: true)
            let context = container.mainContext
            let sample = SampleDigest.make(now: now)
            var sources: [String: Source] = [:]
            let entries = sample.news.map { ($0, SourceKind.news) } + sample.episodes.map { ($0, SourceKind.podcast) }
            for (entry, kind) in entries {
                let source: Source
                if let existing = sources[entry.sourceName] {
                    source = existing
                } else {
                    source = Source(kind: kind, feedURL: "https://example.com/\(sources.count)/feed", title: entry.sourceName)
                    context.insert(source)
                    sources[entry.sourceName] = source
                }
                context.insert(FeedItem(
                    itemID: entry.id,
                    sourceID: source.id,
                    title: entry.title,
                    link: "https://example.com/\(entry.id)",
                    summary: entry.summary,
                    author: nil,
                    publishedAt: entry.published,
                    durationSeconds: kind == .podcast ? 58 * 60 : nil
                ))
            }
            if let last = sample.news.last, let source = sources[last.sourceName] {
                context.insert(ItemState(itemID: last.id, sourceID: source.id, status: .read, firstShownAt: now))
            }
            context.insert(SavedItem(itemID: "saved-1", sourceID: "", sourceTitle: "Stratechery", title: "The long view on platform shifts", link: "https://example.com/saved-1", summary: "A sample saved headline.", author: "Ben Thompson", publishedAt: now.addingTimeInterval(-3 * 86_400)))
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }
}
#endif
