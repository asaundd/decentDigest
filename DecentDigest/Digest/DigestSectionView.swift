import DigestCore
import SwiftUI

/// A section title followed by a plain bulleted list.
struct DigestSectionView: View {
    struct Row: Identifiable {
        var id: String
        var leading: String? = nil
        var title: String
        var detail: String? = nil
        var trailing: String? = nil
    }

    var title: String
    var rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.titleToList) {
            Text(title)
                .font(Theme.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
            // A grid keeps the leading column (times, dashes) one width, so titles line up.
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 10) {
                ForEach(rows) { row in
                    GridRow {
                        Text(row.leading ?? "–")
                            .foregroundStyle(Theme.secondary)
                            .monospacedDigit()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                            if let detail = row.detail {
                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.trailing ?? "")
                            .foregroundStyle(Theme.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }
}

/// Now, plus a one-line summary of the rest of the week.
struct WeatherSectionView: View {
    var weather: WeatherSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.titleToList) {
            Text("Weather")
                .font(Theme.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(weather.temperature)°")
                    .font(.system(size: 40, weight: .light))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(weather.condition), high \(weather.today.high)°, low \(weather.today.low)°")
                    Text(weather.place)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(weather.restOfWeek) { day in
                    GridRow {
                        Text(day.date, format: .dateTime.weekday(.abbreviated))
                            .foregroundStyle(Theme.secondary)
                        Text("\(day.high)° / \(day.low)°")
                            .monospacedDigit()
                        Text(day.condition)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
