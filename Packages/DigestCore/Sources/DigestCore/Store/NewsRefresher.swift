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
        let started = Date.now
        let fetched = await store.refresh(force: force)
        // Headlines opened before this refresh leave the News list.
        if fetched > 0 {
            UserDefaults.standard.set(started.timeIntervalSince1970, forKey: Self.listStartedAtKey)
        }
    }

    /// When the News list last refreshed, as seconds since 1970 in UserDefaults.
    nonisolated public static let listStartedAtKey = "newsListStartedAt"

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
