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

    /// - Parameters:
    ///   - force: true when the reader asked; otherwise only feeds older than the refresh interval are fetched.
    ///   - only: news feeds only (News' Refresh link) or shows only; nil checks both.
    public func refresh(force: Bool = false, only kind: SourceKind? = nil) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let store = await feedStore()
        let started = Date.now
        let keepsHistory = !UserDefaults.standard.bool(forKey: DigestPreferences.readingHistoryOffKey)
        let outcome = await store.refresh(force: force, only: kind, keepsHistory: keepsHistory)
        // Headlines opened before this refresh leave the News list.
        if outcome.checked > 0, !outcome.offline, kind != .podcast {
            UserDefaults.standard.set(started.timeIntervalSince1970, forKey: Self.listStartedAtKey)
        }
        // A check that reached nothing for want of a connection marks its lists offline until one gets through.
        if outcome.checked > 0 {
            for listKind in kind.map({ [$0] }) ?? SourceKind.allCases {
                UserDefaults.standard.set(outcome.offline, forKey: Self.offlineKey(listKind))
            }
        }
    }

    /// True in UserDefaults while News' or Podcasts' last check couldn't connect.
    nonisolated public static func offlineKey(_ kind: SourceKind) -> String {
        "offline.\(kind.rawValue)"
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
