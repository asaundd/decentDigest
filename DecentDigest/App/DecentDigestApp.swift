import DigestCore
import SwiftData
import SwiftUI

@main
struct DecentDigestApp: App {
    private let container: ModelContainer
    private let refresher: NewsRefresher
    private let agenda: AgendaModel
    private let weather: WeatherModel

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
        self.agenda = AgendaModel(source: EventKitSource())
        #if DEBUG
        // Until WeatherKit is turned on for the app's identifier, debug builds show sample weather
        // with a note saying so, so the layout can be checked on a device.
        let sampleOnFailure = true
        #else
        let sampleOnFailure = false
        #endif
        self.weather = WeatherModel(provider: WeatherKitSource(), places: LocationPlaces(), sampleOnFailure: sampleOnFailure)
    }

    var body: some Scene {
        WindowGroup {
            DigestView(agenda: agenda, weather: weather, refresh: { [refresher] force in await refresher.refresh(force: force) })
        }
        .modelContainer(container)
    }
}
