import DigestCore
import SwiftUI
import UIKit

/// Where the forecast is for: the device's location, or a city the reader picks. One piece, used by
/// the Weather step in setup and by Weather settings. Picking is saving; there is nothing to confirm.
///
/// - "Use my location" has an Allow link (iOS then asks); ✓ In use with the place and "Turn off in the
///   Settings app ↗" once it's the source; Use when a city is in use instead; or "Turn on in the
///   Settings app ↗" when location was declined.
/// - "Don't use my location" has a search box under it. Each letter typed brings up to 5 cities from
///   Apple Maps; a tap picks one, which then shows ✓ In use over its name.
struct WeatherPlacePicker: View {
    var model: WeatherModel
    /// The gray line under "Don't use my location".
    var cityNote: String
    /// Puts a rule between the two choices.
    var ruled = true
    /// In setup, the offline note also offers Skip for now.
    var inSetup = false

    @Environment(\.openURL) private var openURL
    @Environment(NetworkStatus.self) private var network: NetworkStatus?
    @State private var text = ""
    @State private var isLooking = false
    @State private var notFound = false
    /// Apple Maps suggestions, set up only once the search box is tapped: the first use of Apple Maps
    /// in a launch tries to reach the network and can hold the screen while it does, so the page
    /// doesn't touch it just by opening (offline, the box can't be tapped at all).
    @State private var search: CitySearch?
    @FocusState private var searchFocused: Bool

    private var usingLocation: Bool {
        model.locationAccess == .granted && model.typedCity == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            locationRow

            if ruled {
                PlainRule(spacing: 20)
            }

            ChoiceRow(title: "Don’t use my location", subtitle: cityNote, emphasized: true) {
                if let city = model.typedCity {
                    // "✓ In use" over the city's name.
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("✓ In use")
                            .foregroundStyle(Theme.secondary)
                        Text(city.name)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("In use: \(city.name)")
                }
            }
            .padding(.top, ruled ? 0 : 8)

            // Finding a city needs a connection: offline, the box is grayed out with a note under it.
            let offline = network?.isOffline == true
            SearchBox(placeholder: "Search for a city", text: $text, isFocused: $searchFocused, submitLabel: .search, isDisabled: offline) {
                lookUp(text)
            }
            .onChange(of: searchFocused) { _, focused in
                if focused, search == nil {
                    search = CitySearch()
                }
            }
            .onChange(of: text) { _, typed in
                notFound = false
                if search == nil, !typed.isEmpty {
                    search = CitySearch()
                }
                search?.update(typed)
            }
            .onChange(of: offline) { _, nowOffline in
                if nowOffline {
                    text = ""
                    searchFocused = false
                }
            }
            .padding(.top, 6)
            if offline {
                OfflineNote(text: OfflineMessage.search(inSetup: inSetup))
            }

            if let search, !search.suggestions.isEmpty && !text.isEmpty {
                suggestions
                    .padding(.top, 4)
            }
            if isLooking {
                Text("Looking…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
            }
            if !text.isEmpty && (search?.isOffline == true || (notFound && model.isOffline)) {
                Text(OfflineMessage.search(inSetup: inSetup))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
            } else if notFound {
                Text("No city found by that name.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
            }
        }
    }

    /// "Use my location": Allow until iOS has asked; ✓ In use with the place and a way to turn it off
    /// in iOS Settings; Use when a city is in use instead; a way to turn it on once declined.
    private var locationRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use my location")
                        .fontWeight(.semibold)
                    locationNote
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                switch model.locationAccess {
                case .notAsked:
                    TextLink("Allow") { Task { await model.useCurrentLocation() } }
                        .accessibilityLabel("Allow location")
                        .accessibilityHint("Asks for your location")
                case .granted:
                    if usingLocation {
                        DoneNote(text: "In use")
                    } else {
                        TextLink("Use") { Task { await model.useCurrentLocation() } }
                            .accessibilityLabel("Use my location")
                    }
                case .denied:
                    EmptyView()
                }
            }
            .padding(.vertical, ruled ? 0 : 6)

            switch model.locationAccess {
            case .denied:
                TextLink("Turn on in the Settings app ↗", action: openSystemSettings)
                    .accessibilityHint("Opens Decent in the Settings app")
            case .granted where usingLocation:
                TextLink("Turn off in the Settings app ↗", action: openSystemSettings)
                    .accessibilityHint("Opens Decent in the Settings app")
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var locationNote: some View {
        switch model.locationAccess {
        case .denied:
            Text("Location is off for Decent digest.")
        case .granted where usingLocation:
            if let place = model.place, place.isCurrentLocation {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(place.name)
                    Image(systemName: "location")
                        .font(.caption2)
                        .accessibilityLabel("Current location")
                }
            } else {
                Text("Follows you when you travel.")
            }
        default:
            Text("Follows you when you travel.")
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(search?.suggestions ?? []) { suggestion in
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
                search?.clear()
                searchFocused = false
            }
        }
    }
}
