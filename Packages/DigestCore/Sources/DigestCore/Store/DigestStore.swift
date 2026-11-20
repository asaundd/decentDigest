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
    public static func previewContainer(now: Date = AppClock.now) -> ModelContainer {
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
                    source = Source(kind: kind, feedURL: sampleFeeds[entry.sourceName] ?? "https://example.com/\(sources.count)/feed", title: entry.sourceName)
                    context.insert(source)
                    sources[entry.sourceName] = source
                }
                context.insert(FeedItem(
                    itemID: entry.id,
                    sourceID: source.id,
                    title: entry.title,
                    link: "https://example.com/\(entry.id)",
                    summary: entry.summary,
                    fullText: samplePostText[entry.id],
                    author: sampleAuthors[entry.id],
                    publishedAt: entry.published,
                    durationSeconds: sampleMinutes[entry.id].map { $0 * 60 }
                ))
            }
            if let last = sample.news.last, let source = sources[last.sourceName] {
                context.insert(ItemState(itemID: last.id, sourceID: source.id, status: .read, firstShownAt: now))
            }
            context.insert(SavedItem(itemID: "saved-1", sourceID: "", sourceTitle: "Atlas Obscura", title: "Glass Wonders Gallery in Karpacz, Poland", link: "https://example.com/saved-1", summary: "A gallery of glass art in a small town in the Karkonosze mountains.", author: nil, publishedAt: now.addingTimeInterval(-3 * 86_400)))
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }

    private static let sampleAuthors = [
        "n1": "Kate Mothes", "n2": "Yasemin Saplakoglu", "n4": "Nagi", "n6": "Devin Reese",
    ]

    /// Post text for two headlines, so demo mode shows each kind the panel reads: a full post
    /// (Read full post) and an excerpt longer than the card shows (Read excerpt and Open ↗).
    /// Written for the demo; it isn't the publishers' own text.
    private static let samplePostText = [
        "n2": """
        After decades of arguing over which molecules came first, a new generation of scientists is rethinking what life was, is and could be.

        For most of the last century, the origin of life was framed as a contest. Was it the genetic molecules, able to copy themselves, or the metabolic ones, able to gather energy from their surroundings? Each camp built experiments to show that its favorite could stand alone, and each found the other’s answer hard to accept.

        That framing is starting to look like the wrong question. Researchers are finding that early chemistry may have run as a web, with no single molecule in charge. Simple compounds that speed up one another’s formation can, in the right conditions, keep a cycle of reactions going long after the first ingredients run low.

        Such a cycle isn’t alive. It has no cell wall and passes nothing on in the way genes do. But it has something living things depend on: a pattern that keeps itself going, and that can change when its surroundings do. Some chemists now think that is where the line between chemistry and biology starts to blur.

        The idea changes what counts as evidence. Instead of searching for one molecule that could have done everything, labs are looking for mixtures that settle into lasting patterns on their own, in warm pools, at deep-sea vents, or on the surfaces of minerals. Several have found reaction networks that grow more orderly over time rather than less.

        None of this settles how life began on Earth, and it may never be settled. What has shifted is the picture of the starting line. Rather than a single lucky molecule, it looks more like a slow crowding together of many reactions, until the whole began to behave like something more than the sum of its parts.
        """,
        "n3": """
        A sports psychologist on which strategies work on cold, dark mornings, and which ones backfire.

        The hardest part of a winter run is usually the first five minutes, and most of that is in your head. Laying out your clothes the night before helps, but only if you also decide on a route and a time, so there’s nothing left to talk yourself out of. Running with a friend works better than any app, because skipping means letting someone down.

        What doesn’t help: promising yourself a reward afterward, or waiting until you feel like it. Here are the six strategies that…
        """,
    ]

    /// Real addresses so setup screens show real sites. Demo mode never fetches them.
    private static let sampleFeeds = [
        "Colossal": "https://www.thisiscolossal.com/feed/",
        "Quanta Magazine": "https://www.quantamagazine.org/feed/",
        "Runner’s World": "https://www.runnersworld.com/rss/all.xml/",
        "RecipeTin Eats": "https://www.recipetineats.com/feed/",
        "Smithsonian Magazine": "https://www.smithsonianmag.com/rss/latest_articles/",
        "Nautilus": "https://nautil.us/feed/",
        "EarthSky": "https://earthsky.org/feed/",
        "99% Invisible": "https://feeds.simplecast.com/BqbsxVfO",
        "The Splendid Table": "https://feeds.publicradio.org/public_feeds/the-splendid-table",
        "Hidden Brain": "https://feeds.simplecast.com/kwWc0lhf",
    ]

    private static let sampleMinutes = ["p1": 39, "p2": 50, "p3": 91]
}
#endif
