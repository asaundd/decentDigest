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
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    RowView(row: row)
                }
            }
        }
    }
}

private struct RowView: View {
    var row: DigestSectionView.Row

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
            Spacer(minLength: 8)
            if let trailing = row.trailing {
                Text(trailing)
                    .foregroundStyle(Theme.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
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
            ForEach(weather.restOfWeek) { day in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(day.date, format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 40, alignment: .leading)
                    Text("\(day.high)° / \(day.low)°  \(day.condition)")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
