import DigestCore
import SwiftUI

/// Weather settings: whether the weather shows on the digest, and where the forecast is for.
/// Opened from the place under the week. Uses the same place picker as the Weather step in setup,
/// on the same paper page as the digest, with an even 20pt around each rule.
struct WeatherSettingsView: View {
    var model: WeatherModel
    var preferences: DigestPreferences
    /// "Settings" when opened from Settings: ‹ Settings at the top instead of Done.
    var backTitle: String? = nil

    @Environment(\.dismiss) private var dismiss

    private static let gap: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let backTitle {
                    BackLink(title: backTitle) { dismiss() }
                        .padding(.bottom, 12)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("Weather")
                        .font(Theme.dateFont)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if backTitle == nil {
                        TextLink("Done") { dismiss() }
                    }
                }
                Text("Show the forecast for where you are, or for a city you choose.")
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                PlainRule(spacing: Self.gap)

                ShowSwitch(label: "Show weather on the digest", isOn: Binding(
                    get: { preferences.isShown(.weather) },
                    set: { preferences.setShown($0, .weather) }
                ))

                if preferences.isShown(.weather) {
                    PlainRule(spacing: Self.gap)
                    WeatherPlacePicker(model: model, cityNote: "Select a city instead.", ruled: true)
                    PlainRule(spacing: Self.gap)
                    Text(WeatherCopy.locationNote)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, backTitle == nil ? Theme.margin : 0)
            .padding(.bottom, backTitle == nil ? 0 : Theme.margin)
        }
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .background(Theme.page.ignoresSafeArea())
        .presentationBackground(Theme.page)
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
