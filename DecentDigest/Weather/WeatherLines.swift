import DigestCore
import SwiftUI
import UIKit

/// The weather under the date, in words: the temperature now with today in a few words, then a
/// gray line on what changes over the next two days and anything notable later in the week.
/// Show week, at the bottom, lists the rest of the week under it and becomes Show less in the same
/// place; under the week, one line: the place (which opens Weather settings) and Weather ↗.
struct WeatherLines: View {
    var model: WeatherModel
    /// Opens Settings › Weather.
    var openSettings: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(NetworkStatus.self) private var network: NetworkStatus?
    @State private var showsWeek = false
    /// The temperature now, 40pt at the default text size, growing with it.
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize: CGFloat = 40

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
                    .font(.system(size: temperatureSize, weight: .light))
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

            if model.isOffline || network?.isOffline == true, !model.isSample {
                // The last forecast still shows; this says when it is from.
                Text(WeatherRules.offlineNote(fetchedAt: report.fetchedAt, now: .now))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            if model.isSample {
                // Debug builds only, until WeatherKit is turned on for the app.
                Text("Sample weather: WeatherKit isn't set up for this build.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 4)
            }

            if !report.days.isEmpty {
                // Show week, then Show less in the same place once the week is open.
                weekToggle
                    .padding(.top, 4)
            }
            if showsWeek {
                week(report.days, unit: unit)
                    .padding(.top, 6)
                openFooter(place)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One bullet per day: the day's name, then the condition and low to high, all regular weight.
    /// Spaced like the Calendar and To do rows.
    @ViewBuilder
    private func week(_ days: [WeatherDay], unit: TemperatureUnit) -> some View {
        if typeSize.isAccessibilitySize {
            stackedWeek(days, unit: unit)
        } else {
            gridWeek(days, unit: unit)
        }
    }

    /// At the largest text sizes each day takes two lines: its name, then the condition and low to high.
    private func stackedWeek(_ days: [WeatherDay], unit: TemperatureUnit) -> some View {
        VStack(alignment: .leading, spacing: 2 * AgendaMetrics.rowPadding) {
            ForEach(Array(days.prefix(WeatherRules.weekDays))) { day in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("–")
                        .foregroundStyle(Theme.secondary)
                        .frame(width: DashColumn.width, alignment: .leading)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(day.date.addingTimeInterval(12 * 3_600), format: .dateTime.weekday(.wide))
                        Text("\(day.condition) \(WeatherRules.lowToHigh(day, unit: unit))")
                            .foregroundStyle(Theme.itemInk)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    private func gridWeek(_ days: [WeatherDay], unit: TemperatureUnit) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 0, verticalSpacing: 2 * AgendaMetrics.rowPadding) {
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

    /// Show week, or Show less once the week is open. A footer link, like Show all.
    private var weekToggle: some View {
        FooterLink(showsWeek ? "Show less" : "Show week", still: true) {
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
    }

    /// Under the open week, on one line like the other sections' footers: "For Brooklyn, NY" (the
    /// city opens Weather settings, with a small location arrow when it comes from the device's
    /// location), then Weather ↗. On a narrow screen Weather ↗ drops under the place.
    private func openFooter(_ place: WeatherPlace) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                placeLink(place)
                appLink(afterDot: true)
            }
            VStack(alignment: .leading, spacing: 0) {
                // A long city name wraps here instead of being cut.
                placeLink(place, wraps: true)
                appLink(afterDot: false)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func appLink(afterDot: Bool) -> some View {
        if WeatherApp.canOpen {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if afterDot { dot }
                FooterLink("Weather ↗", still: true) { openURL(WeatherApp.url) }
                    .accessibilityLabel("Open Weather")
            }
        }
    }

    private var dot: some View {
        Text("·")
            .foregroundStyle(Theme.secondary)
            .accessibilityHidden(true)
    }

    private func placeLink(_ place: WeatherPlace, wraps: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("For")
                .foregroundStyle(Theme.secondary)
                .accessibilityHidden(true)
            FooterLink(place.name, still: true, wraps: wraps, action: openSettings)
                .accessibilityLabel(place.isCurrentLocation ? "For \(place.name), current location" : "For \(place.name)")
                .accessibilityHint("Changes where the weather is for")
            if place.isCurrentLocation {
                Image(systemName: "location")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondary)
                    .accessibilityHidden(true)
            }
        }
        .fixedSize(horizontal: !wraps, vertical: true)
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
