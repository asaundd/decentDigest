import DigestCore
import SwiftUI
import UIKit

/// Where the forecast is for: the device's location, or a city the reader picks. One piece, used by
/// the Weather step in setup and by Weather settings. Picking is saving; there is nothing to confirm.
///
/// - "Use my location" has an Allow link (iOS then asks), ✓ In use once it's the source, Use when a
///   city is in use instead, or Open Settings ↗ when location was declined.
/// - "Don't use my location" has a search box under it. Each letter typed brings up to 5 cities from
///   Apple Maps; a tap picks one, which then says ✓ In use.
struct WeatherPlacePicker: View {
    var model: WeatherModel
    /// The gray line under "Don't use my location".
    var cityNote: String
    /// Shows the picked city's weather under the search box, so the reader can see it's the right place.
    var showsCityWeather = false

    @Environment(\.openURL) private var openURL
    @State private var text = ""
    @State private var isLooking = false
    @State private var notFound = false
    @State private var search = CitySearch()
    @FocusState private var searchFocused: Bool

    private var usingLocation: Bool {
        model.locationAccess == .granted && model.typedCity == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChoiceRow(title: "Use my location", subtitle: locationSubtitle) {
                locationAction
            }
            .accessibilityElement(children: .contain)

            ChoiceRow(title: "Don't use my location", subtitle: model.typedCity?.name ?? cityNote) {
                if model.typedCity != nil {
                    DoneNote(text: "In use")
                }
            }
            .padding(.top, 8)

            SearchBox(placeholder: "Search for a city", text: $text, isFocused: $searchFocused) {
                lookUp(text)
            }
            .textContentType(.addressCity)
            .onChange(of: text) { _, typed in
                notFound = false
                search.update(typed)
            }
            .padding(.top, 6)

            if !search.suggestions.isEmpty && !text.isEmpty {
                suggestions
                    .padding(.top, 4)
            }
            if isLooking {
                Text("Looking…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
            }
            if notFound {
                Text("No city found by that name.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
            }
            if showsCityWeather, text.isEmpty, let city = model.typedCity, let report = model.report, model.place == city {
                cityWeather(report, city: city, unit: .current())
                    .padding(.top, 14)
            }
        }
    }

    private var locationSubtitle: String {
        switch model.locationAccess {
        case .denied:
            return "Location is off for Decent."
        case .granted where model.typedCity == nil:
            if let place = model.place, place.isCurrentLocation { return place.name }
            return "Follows you when you travel."
        default:
            return "Follows you when you travel."
        }
    }

    @ViewBuilder
    private var locationAction: some View {
        switch model.locationAccess {
        case .notAsked:
            TextLink("Allow") { Task { await model.useCurrentLocation() } }
                .accessibilityLabel("Allow location")
                .accessibilityHint("Asks for your location")
        case .denied:
            TextLink("Open Settings ↗") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .accessibilityHint("Location can be turned on for Decent in the Settings app")
        case .granted:
            if usingLocation {
                DoneNote(text: "In use")
            } else {
                TextLink("Use") { Task { await model.useCurrentLocation() } }
                    .accessibilityLabel("Use my location")
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(search.suggestions) { suggestion in
                Button {
                    lookUp(suggestion.query)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("–")
                            .foregroundStyle(Theme.secondary)
                            .frame(width: DashColumn.width, alignment: .leading)
                            .accessibilityHidden(true)
                        Text(suggestion.title)
                        if !suggestion.subtitle.isEmpty {
                            Text("  \(suggestion.subtitle)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StillButtonStyle())
                .accessibilityLabel(suggestion.subtitle.isEmpty ? suggestion.title : "\(suggestion.title), \(suggestion.subtitle)")
                .accessibilityHint("Shows the weather for this city")
            }
        }
    }

    /// "52°  Cloudy  High 58° · Low 44° in Philadelphia": a first look at the picked city.
    private func cityWeather(_ report: WeatherReport, city: WeatherPlace, unit: TemperatureUnit) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(unit.degrees(report.temperature))
                .font(.system(size: 28, weight: .light))
                .monospacedDigit()
            VStack(alignment: .leading, spacing: 1) {
                Text(WeatherRules.todayPhrase(report, now: .now))
                Text("\(WeatherRules.highLow(report.today, unit: unit)) in \(city.name)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func lookUp(_ query: String) {
        guard !isLooking, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLooking = true
        notFound = false
        Task {
            let found = await model.setCity(query)
            isLooking = false
            notFound = !found
            if found {
                text = ""
                search.clear()
                searchFocused = false
            }
        }
    }
}
