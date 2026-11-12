import DigestCore
import SwiftData
import SwiftUI
import UIKit

@main
struct DecentDigestApp: App {
    private let container: ModelContainer
    private let refresher: NewsRefresher
    private let agenda: AgendaModel
    private let weather: WeatherModel
    private let preferences = DigestPreferences()

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
            DigestView(agenda: agenda, weather: weather, preferences: preferences, refresh: { [refresher] force, kind in await refresher.refresh(force: force, only: kind) })
        }
        .modelContainer(container)
    }
}

/// Light, dark, or the device's setting, from Settings › Appearance. Set on the window, so sheets and
/// setup follow it too.
@MainActor
enum AppearanceStyle {
    static func apply(_ appearance: DigestPreferences.Appearance) {
        let style: UIUserInterfaceStyle = switch appearance {
        case .automatic: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
