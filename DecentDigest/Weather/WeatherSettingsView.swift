import DigestCore
import SwiftUI
import UIKit

/// Settings › Weather: use the device's location, or type a city. Opened from the place under the
/// week, or from "Set up weather". Kept on the same paper page as the digest.
struct WeatherSettingsView: View {
    var model: WeatherModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var city = ""
    @State private var isLooking = false
    @State private var notFound = false
    @FocusState private var cityFocused: Bool

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

                if let place = model.place, model.report != nil {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Showing the weather for \(place.name)")
                        if place.isCurrentLocation {
                            Image(systemName: "location")
                                .font(.caption2)
                                .accessibilityLabel("Current location")
                        }
                    }
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
                }

                SectionRule()

                Text("Your location")
                    .font(Theme.sectionTitleFont)
                    .accessibilityAddTraits(.isHeader)
                locationOptions
                    .padding(.top, Theme.titleToList)

                SectionRule()

                Text("A city")
                    .font(Theme.sectionTitleFont)
                    .accessibilityAddTraits(.isHeader)
                cityOptions
                    .padding(.top, Theme.titleToList)

                SectionRule()

                Text("Your location is used only to name your city and get its forecast from Apple Weather. It stays on this device and is never shared with the developer.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
            }
            .padding(Theme.margin)
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .background(Theme.page.ignoresSafeArea())
        .presentationBackground(Theme.page)
    }

    @ViewBuilder
    private var locationOptions: some View {
        switch model.locationAccess {
        case .granted where model.typedCity == nil:
            Text("Using your location.")
                .foregroundStyle(Theme.secondary)
        case .granted, .notAsked:
            VStack(alignment: .leading, spacing: 4) {
                Text("Show the weather wherever you are.")
                    .foregroundStyle(Theme.secondary)
                TextLink("Use my location") {
                    Task { await model.useCurrentLocation() }
                }
                .accessibilityHint("Asks for your location if needed")
            }
        case .denied:
            VStack(alignment: .leading, spacing: 4) {
                Text("Location is off for Decent digest. You can turn it on in Settings, or type a city below.")
                    .foregroundStyle(Theme.secondary)
                TextLink("Open Settings ↗") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        }
    }

    private var cityOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let typed = model.typedCity {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Using \(typed.name).")
                        .foregroundStyle(Theme.secondary)
                    Text("·")
                        .foregroundStyle(Theme.secondary)
                        .accessibilityHidden(true)
                    TextLink("Stop using it") {
                        Task { await model.clearCity() }
                    }
                    .accessibilityLabel("Stop using \(typed.name)")
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                TextField("Type a city", text: $city)
                    .textContentType(.addressCity)
                    .submitLabel(.search)
                    .focused($cityFocused)
                    .onSubmit(lookUp)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.rule).frame(height: 1)
                    }
                TextLink(isLooking ? "Looking…" : "Use this city", action: lookUp)
                    .disabled(isLooking || city.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if notFound {
                Text("No city found by that name.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private func lookUp() {
        guard !isLooking else { return }
        isLooking = true
        notFound = false
        Task {
            let found = await model.setCity(city)
            isLooking = false
            notFound = !found
            if found {
                city = ""
                cityFocused = false
            }
        }
    }
}

#Preview {
    WeatherSettingsView(model: WeatherModel(provider: SampleWeatherProvider(), places: SamplePlaces()))
}
