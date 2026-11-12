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
    private let network = NetworkStatus()
    /// True when the saved data couldn't be opened: the app says so instead of showing an empty digest.
    private let storageFailed: Bool

    init() {
        var container: ModelContainer?
        #if DEBUG
        // Edit Scheme › Run › Arguments: -simulateStorageFailure shows the message below.
        let simulatesFailure = ProcessInfo.processInfo.arguments.contains("-simulateStorageFailure")
        #else
        let simulatesFailure = false
        #endif
        if !simulatesFailure {
            container = try? DigestStore.makeContainer()
        }
        storageFailed = container == nil
        // An empty store in memory, only so the app has something to hang the message on.
        let opened = container ?? (try! DigestStore.makeContainer(inMemory: true))
        self.container = opened
        self.refresher = NewsRefresher(container: opened)
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
            if storageFailed {
                StorageProblemView()
            } else {
                digest
            }
        }
        .modelContainer(container)
        .environment(network)
    }

    private var digest: some View {
        DigestView(agenda: agenda, weather: weather, preferences: preferences, refresh: { [refresher] force, kind in await refresher.refresh(force: force, only: kind) })
    }
}

/// Shown instead of the digest when the saved data can't be opened, which should never happen.
/// Nothing is shown from memory, so nothing the reader does is lost on quit.
struct StorageProblemView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LogoMark(color: Theme.logoButton)
                .frame(width: 44)
                .accessibilityHidden(true)
            Text("Decent digest couldn't open its saved data.")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Close the app and open it again. If this keeps happening, restart your device.")
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.page.ignoresSafeArea())
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
