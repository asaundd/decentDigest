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

    /// An in-memory container filled with sample headlines and episodes, for previews and the
    /// debug-only demo mode used for screenshots.
    @MainActor
    public static func previewContainer(now: Date = .now) -> ModelContainer {
        do {
            let container = try makeContainer(inMemory: true)
            let context = container.mainContext
            let sample = SampleDigest.make(now: now)
            var sources: [String: Source] = [:]
            let entries = sample.news.map { ($0, SourceKind.news) } + sample.episodes.map { ($0, SourceKind.podcast) }
            for (index, (entry, kind)) in entries.enumerated() {
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
                    fullText: entry.id == "n1" ? sampleFullPost : nil,
                    author: kind == .news ? sampleAuthors[index % sampleAuthors.count] : nil,
                    publishedAt: entry.published,
                    durationSeconds: kind == .podcast ? [42, 58, 35][index % 3] * 60 : nil
                ))
            }
            if let last = sample.news.last, let source = sources[last.sourceName] {
                context.insert(ItemState(itemID: last.id, sourceID: source.id, status: .read, firstShownAt: now))
            }
            context.insert(SavedItem(itemID: "saved-1", sourceID: "", sourceTitle: "Civic Weekly", title: "The long view on city buses", link: "https://example.com/saved-1", summary: "How a few small changes to routes and stops made buses the fastest way across town.", author: "Jordan Lee", publishedAt: now.addingTimeInterval(-3 * 86_400)))
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }

    private static let sampleAuthors = ["Maria Chen", "Sam Okafor", "Ruth Alvarez", "Theo Brandt"]

    /// A full post for the first sample headline, long enough to read as one.
    private static let sampleFullPost = """
    Walk down almost any new block in the city and you will pass young trees standing in neat squares of mulch. What you won't see is what sits underneath: wider, deeper pits filled with a loose soil mix, and in a growing number of them, a small sensor that reports how wet the ground is.

    For years, new street trees were watered on a schedule. A truck came by every week or two through the first summers, whether the tree needed it or not. Some drowned, more went thirsty, and a surprising share never made it past their third year.

    The sensors change that. Crews now see which blocks are dry and which are fine, and send the truck only where it's needed. In the first neighborhoods to try it, watering trips fell by almost half, and the share of trees that survived their first three years went up.

    The deeper pits matter just as much. Roots that have room to spread find water on their own after a rain, and the soil holds it for longer. A tree planted this way can go weeks without help once it settles in.

    None of this is expensive. The sensors cost less than a single replacement tree, and the soil mix is a small change to work crews already do. The harder part, the people running these programs say, is patience: a street tree takes a decade to really earn its keep, and the results of choices made today won't be clear for years.

    Still, the early numbers are encouraging. More trees are living past the tricky first years, the trucks are making fewer trips, and on a hot afternoon, the blocks that were planted this way are already a little cooler.
    """
}
#endif
