#if canImport(SwiftData)
import Foundation
import SwiftData

/// Builds the app's SwiftData container: one store that syncs through iCloud and one that stays on the device.
public enum DigestStore {
    public static var syncedModels: [any PersistentModel.Type] { [Source.self, ItemState.self] }
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

    /// An in-memory container filled with sample headlines, for previews.
    @MainActor
    public static func previewContainer(now: Date = .now) -> ModelContainer {
        do {
            let container = try makeContainer(inMemory: true)
            let context = container.mainContext
            let sample = SampleDigest.make(now: now)
            var sources: [String: Source] = [:]
            for entry in sample.news {
                let source: Source
                if let existing = sources[entry.sourceName] {
                    source = existing
                } else {
                    source = Source(feedURL: "https://example.com/\(sources.count)/feed", title: entry.sourceName)
                    context.insert(source)
                    sources[entry.sourceName] = source
                }
                context.insert(FeedItem(itemID: entry.id, sourceID: source.id, title: entry.title, link: "https://example.com/\(entry.id)", summary: entry.summary, author: nil, publishedAt: entry.published))
            }
            if let first = sample.news.last, let source = sources[first.sourceName] {
                context.insert(ItemState(itemID: first.id, sourceID: source.id, status: .read))
            }
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }
}
#endif
