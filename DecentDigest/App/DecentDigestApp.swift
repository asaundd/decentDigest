import DigestCore
import SwiftData
import SwiftUI

@main
struct DecentDigestApp: App {
    private let container: ModelContainer
    private let refresher: NewsRefresher

    init() {
        let container: ModelContainer
        do {
            container = try DigestStore.makeContainer()
        } catch {
            // If the store can't open, the app still runs for this session without saving.
            container = (try? DigestStore.makeContainer(inMemory: true)) ?? DigestStore.previewContainer()
        }
        self.container = container
        self.refresher = NewsRefresher(container: container)
    }

    var body: some Scene {
        WindowGroup {
            DigestView(refresh: { [refresher] force in await refresher.refresh(force: force) })
        }
        .modelContainer(container)
    }
}
