import DigestCore
import SwiftUI

/// Weather settings: whether the weather shows on the digest, and where the forecast is for.
/// Opened from Settings, or on its own from the place under the week (with ✕ to close). Uses the
/// same place picker as the Weather step in setup.
struct WeatherSettingsView: View {
    var model: WeatherModel
    var preferences: DigestPreferences
    /// True when opened from Settings: ‹ Settings at the top instead of ✕.
    var inSettings = false

    var body: some View {
        SettingsPage(title: "Weather", subtitle: "Show the forecast for where you are, or for a city you choose.", closes: !inSettings) {
            ShowSwitch(label: "Show weather on the digest", isOn: Binding(
                get: { preferences.isShown(.weather) },
                set: { preferences.setShown($0, .weather) }
            ))

            if preferences.isShown(.weather) {
                PlainRule(spacing: 20)
                WeatherPlacePicker(model: model, cityNote: "Select a city instead.")
                PlainRule(spacing: 20)
                Text(WeatherCopy.locationNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum WeatherCopy {
    static let locationNote = "Your location is used only to find the forecast from Apple Weather. It stays on this device."
}

#Preview {
    WeatherSettingsView(
        model: WeatherModel(provider: SampleWeatherProvider(), places: SamplePlaces()),
        preferences: DigestPreferences(defaults: UserDefaults(suiteName: "preview-weather")!)
    )
}
