#if canImport(SwiftData)
import Foundation
import SwiftData

/// Starts news refreshes from the UI, one at a time.
@MainActor
public final class NewsRefresher {
    private let container: ModelContainer
    private var store: FeedStore?
    private var isRefreshing = false

    public init(container: ModelContainer) {
        self.container = container
    }

    /// - Parameter force: true for pull to refresh; otherwise only feeds older than the refresh interval are fetched.
    public func refresh(force: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let store = await feedStore()
        if let library = try? FeedLibrary.bundled() {
            try? await store.addStarterSourcesIfNeeded(library: library)
        }
        await store.refresh(force: force)
    }

    private func feedStore() async -> FeedStore {
        if let store { return store }
        // Created off the main thread so its work runs in the background.
        let container = self.container
        let created = await Task.detached { FeedStore(modelContainer: container) }.value
        store = created
        return created
    }
}
#endif
