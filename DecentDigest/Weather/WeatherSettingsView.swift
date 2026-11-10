import DigestCore
import SwiftUI

/// Weather settings: where the forecast is for. Opened from the place under the week.
/// The same place picker as the Weather step in setup, on the same paper page as the digest.
struct WeatherSettingsView: View {
    var model: WeatherModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Weather")
                        .font(Theme.dateFont)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    TextLink("Done") { dismiss() }
                }

                Group {
                    if let place = model.place, model.report != nil {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Showing the weather for \(place.name)")
                            if place.isCurrentLocation {
                                Image(systemName: "location")
                                    .font(.caption2)
                                    .accessibilityLabel("Current location")
                            }
                        }
                    } else {
                        Text("Pick where the forecast is for.")
                    }
                }
                .foregroundStyle(Theme.secondary)
                .padding(.top, 8)

                WeatherPlacePicker(model: model, cityNote: "Select a city instead.")
                    .padding(.top, 20)

                Text(WeatherCopy.locationNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 24)
            }
            .padding(Theme.margin)
        }
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
    WeatherSettingsView(model: WeatherModel(provider: SampleWeatherProvider(), places: SamplePlaces()))
}
