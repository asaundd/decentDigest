#if canImport(SwiftData)
import Foundation
import SwiftData

/// Settings › Delete all my data: everything the reader has followed, saved and read, gone from the
/// device and, through sync, from their iCloud and their other devices.
@MainActor
public enum MyData {
    /// Deletes every followed site and show, saved item and reading history record, and every
    /// cached news item and episode with them. Settings such as which sections show are kept.
    /// Each record is deleted one by one rather than in a batch, so iCloud sync sees every deletion.
    public static func deleteAll(in context: ModelContext) throws {
        try deleteEach(Source.self, in: context)
        try deleteEach(ItemState.self, in: context)
        try deleteEach(SavedItem.self, in: context)
        try deleteEach(FeedItem.self, in: context)
        try deleteEach(FetchState.self, in: context)
        try context.save()
    }

    private static func deleteEach<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<Model>()) {
            context.delete(record)
        }
    }
}
#endif
