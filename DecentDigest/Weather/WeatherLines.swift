import DigestCore
import SwiftUI
import UIKit

/// The weather under the date, in words: the temperature now with today in a few words, then a
/// gray line on what changes over the next two days and anything notable later in the week.
/// Show week, at the bottom, lists the rest of the week, then the place (which opens Weather
/// settings) and Weather ↗.
struct WeatherLines: View {
    var model: WeatherModel
    /// Opens Settings › Weather.
    var openSettings: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var showsWeek = false

    var body: some View {
        // With no location and no city, the date stands alone.
        if let report = model.report, let place = model.place {
            forecast(report, place: place, unit: .current())
        }
    }

    private func forecast(_ report: WeatherReport, place: WeatherPlace, unit: TemperatureUnit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Text(unit.degrees(report.temperature))
                    .font(.system(size: 40, weight: .light))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 1) {
                    Text(WeatherRules.todayPhrase(report, now: .now))
                    Text(WeatherRules.highLow(report.today, unit: unit))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.top, 14)
            .accessibilityElement(children: .combine)

            // The next two days, then anything notable later in the week.
            Text([WeatherRules.changeLine(report, unit: unit), WeatherRules.weekLine(report, unit: unit)].compactMap { $0 }.joined(separator: " "))
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            if model.isSample {
                // Debug builds only, until WeatherKit is turned on for the app.
                Text("Sample weather: WeatherKit isn't set up for this build.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 4)
            }

            if showsWeek {
                week(report.days, unit: unit)
                    .padding(.top, 6)
                placeLine(place)
                    .padding(.top, 8)
            }

            // At the bottom, like Show all under News and the agenda.
            if !report.days.isEmpty {
                TextLink(showsWeek ? "Show less" : "Show week", still: true) {
                    // A clean swap: the label and the week change at once, with no fade or slide.
                    var instant = Transaction()
                    instant.disablesAnimations = true
                    withTransaction(instant) { showsWeek.toggle() }
                }
                .contentTransition(.identity)
                .animation(nil, value: showsWeek)
                // A fresh link each time, so nothing from the tap carries over to the new label.
                .id(showsWeek)
                .transition(.identity)
                .accessibilityHint(showsWeek ? "Hides the week" : "Lists the rest of the week")
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One bullet per day: the day's name, then the condition and low to high, all regular weight.
    private func week(_ days: [WeatherDay], unit: TemperatureUnit) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 0, verticalSpacing: 4) {
            ForEach(Array(days.prefix(WeatherRules.weekDays))) { day in
                GridRow {
                    Text("–")
                        .foregroundStyle(Theme.secondary)
                        .frame(width: DashColumn.width, alignment: .leading)
                        .accessibilityHidden(true)
                    // Forecast days start at midnight where the place is; midday keeps the right weekday.
                    Text(day.date.addingTimeInterval(12 * 3_600), format: .dateTime.weekday(.wide))
                        .padding(.trailing, 12)
                    Text(day.condition)
                        .foregroundStyle(Theme.itemInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(WeatherRules.lowToHigh(day, unit: unit))
                        .foregroundStyle(Theme.itemInk)
                        .gridColumnAlignment(.trailing)
                        .accessibilityLabel("Low \(unit.degrees(day.low)), high \(unit.degrees(day.high))")
                }
            }
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    /// "For Brooklyn, NY" on the left, with a small location arrow when it comes from the device's
    /// location, and Weather ↗ on the right. The city is the link to Weather settings.
    private func placeLine(_ place: WeatherPlace) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: openSettings) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("For \(Text(place.name).underline(color: Theme.secondary.opacity(0.35)))")
                    if place.isCurrentLocation {
                        Image(systemName: "location")
                            .font(.caption2)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(StillButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(place.isCurrentLocation ? "For \(place.name), current location" : "For \(place.name)")
            .accessibilityHint("Changes where the weather is for")
            .accessibilityAddTraits(.isButton)

            Spacer(minLength: 0)

            if WeatherApp.canOpen {
                TextLink("Weather ↗") { openURL(WeatherApp.url) }
                    .accessibilityLabel("Open Weather")
            }
        }
    }
}

/// The Weather app has no documented link. `weather://` opens it on current iOS; when it doesn't,
/// the link is left out.
enum WeatherApp {
    static let url = URL(string: "weather://")!

    @MainActor
    static var canOpen: Bool {
        UIApplication.shared.canOpenURL(url)
    }
}

/// The Apple Weather mark and Legal link that WeatherKit asks for, in the page footer.
struct WeatherCreditLine: View {
    var credit: WeatherCredit

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            AsyncImage(url: colorScheme == .dark ? credit.markDark : credit.markLight) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text("Apple Weather")
            }
            .frame(height: 12)
            .accessibilityLabel("Apple Weather")
            Link(destination: credit.legalPage) {
                Text("Legal")
                    .underline()
            }
            .accessibilityLabel("Weather data sources and legal notices")
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondary)
        .tint(Theme.secondary)
    }
}
