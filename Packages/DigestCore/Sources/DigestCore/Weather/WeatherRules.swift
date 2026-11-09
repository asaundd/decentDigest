import Foundation

/// The words under the date. Plain rules, no AI: today in a few words, then one line on
/// what changes over the next two days compared with today.
public enum WeatherRules {
    /// Highs this far apart (°F) count as warmer or colder.
    public static let notableHighChange: Double = 8
    /// A high at or above this (°F) counts as hot.
    public static let heat: Double = 90
    /// A low at or below this (°F) counts as a freeze.
    public static let freeze: Double = 32
    /// Days listed under Show week.
    public static let weekDays = 6
    /// A cached forecast is fetched again after this long.
    public static let refreshInterval: TimeInterval = 30 * 60

    // MARK: Today

    /// Today in a few words: "Rain after 4p", "Rain until 2p", "Rain all day", or the condition now.
    public static func todayPhrase(_ report: WeatherReport, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let thisHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let rest = report.hours.filter { hour in
            hour.date >= thisHour && calendar.isDate(hour.date, inSameDayAs: now)
        }
        if report.sky.isWet || rest.first?.sky.isWet == true {
            let wetSky = report.sky.isWet ? report.sky : rest.first?.sky ?? report.sky
            if let dry = rest.first(where: { !$0.sky.isWet }) {
                return "\(word(for: wetSky)) until \(hour(dry.date, calendar: calendar, locale: locale))"
            }
            return "\(word(for: wetSky)) all day"
        }
        if let wet = rest.first(where: { $0.sky.isWet }) {
            return "\(word(for: wet.sky)) after \(hour(wet.date, calendar: calendar, locale: locale))"
        }
        return report.condition
    }

    /// "High 61° · Low 46°".
    public static func highLow(_ day: WeatherDay, unit: TemperatureUnit) -> String {
        "High \(unit.degrees(day.high)) · Low \(unit.degrees(day.low))"
    }

    /// "44–57°" for a row in the week list.
    public static func lowToHigh(_ day: WeatherDay, unit: TemperatureUnit) -> String {
        "\(unit.value(day.low))–\(unit.degrees(day.high))"
    }

    // MARK: What changes next

    /// One sentence, two at most, on what changes tomorrow and the day after compared with today.
    public static func changeLine(_ report: WeatherReport, unit: TemperatureUnit, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        guard report.days.count >= 2 else { return nil }
        let today = report.today
        let first = report.days[0]
        let second = report.days[1]
        // Forecast days start at midnight where the place is; naming them from midday keeps the
        // right weekday when the device is in another time zone.
        let secondName = AgendaFormat.dayName(second.date.addingTimeInterval(12 * 3_600), now: today.date, calendar: calendar, locale: locale)

        let tomorrowChange = change(from: today, to: first)
        let laterChange = change(from: today, to: second)

        switch (tomorrowChange.isEmpty, laterChange.isEmpty) {
        case (true, true):
            return "Tomorrow and \(secondName) look about the same."
        case (true, false):
            return "Tomorrow is much like today. " + sentence(laterChange, when: secondName, days: [second], unit: unit)
        case (false, _):
            if tomorrowChange.lead == laterChange.lead {
                return sentence(tomorrowChange, when: "tomorrow and \(secondName)", days: [first, second], unit: unit)
            }
            let opening = sentence(tomorrowChange, when: "tomorrow", days: [first], unit: unit)
            let next = change(from: first, to: second)
            guard !next.isEmpty else { return opening }
            return opening + " " + sentence(next, when: secondName, days: [second], unit: unit)
        }
    }

    /// What is different about one day compared with another.
    struct Change: Equatable {
        enum Lead: Equatable {
            case storms, rain, snow, dry, hot, freeze, warmer, colder
        }

        var storms = false
        /// Rain or snow starting, or stopping (dry).
        var precipitation: Lead?
        var temperature: Lead?

        var isEmpty: Bool { !storms && precipitation == nil && temperature == nil }

        /// The change that matters most: storms, then rain or snow, then temperature.
        var lead: Lead? {
            if storms { return .storms }
            return precipitation ?? temperature
        }
    }

    static func change(from base: WeatherDay, to day: WeatherDay) -> Change {
        var change = Change()
        if day.sky == .storm, base.sky != .storm {
            change.storms = true
        } else if day.sky.isWet, !base.sky.isWet {
            change.precipitation = day.sky == .snow ? .snow : .rain
        } else if !day.sky.isWet, base.sky.isWet {
            change.precipitation = .dry
        }
        if day.high >= heat, base.high < heat {
            change.temperature = .hot
        } else if day.low <= freeze, base.low > freeze {
            change.temperature = .freeze
        } else if day.high - base.high >= notableHighChange {
            change.temperature = .warmer
        } else if base.high - day.high >= notableHighChange {
            change.temperature = .colder
        }
        return change
    }

    /// e.g. "Rain tomorrow, and colder." or "Hot tomorrow and Wednesday, highs near 94°."
    static func sentence(_ change: Change, when: String, days: [WeatherDay], unit: TemperatureUnit) -> String {
        guard let lead = change.lead else { return "" }
        var text: String
        switch lead {
        case .storms: text = "Storms likely \(when)"
        case .rain: text = "Rain \(when)"
        case .snow: text = "Snow \(when)"
        case .dry: text = "Dry \(when)"
        case .hot, .freeze, .warmer, .colder:
            return capitalized(temperatureWords(lead, when: when, days: days, unit: unit)) + "."
        }
        // Temperature comes second when rain, snow or storms lead.
        if let temperature = change.temperature {
            switch temperature {
            case .warmer: text += ", and warmer"
            case .colder: text += ", and colder"
            case .hot: text += ", and hot"
            case .freeze: text += ", with a freeze"
            default: break
            }
        }
        return text + "."
    }

    private static func temperatureWords(_ lead: Change.Lead, when: String, days: [WeatherDay], unit: TemperatureUnit) -> String {
        switch lead {
        case .hot:
            let high = days.map(\.high).max() ?? 0
            return "hot \(when), highs near \(unit.degrees(high))"
        case .freeze:
            let low = days.map(\.low).min() ?? 0
            return "a freeze \(when), lows near \(unit.degrees(low))"
        case .warmer: return "warmer \(when)"
        case .colder: return "colder \(when)"
        default: return ""
        }
    }

    // MARK: Words

    static func word(for sky: Sky) -> String {
        switch sky {
        case .snow: "Snow"
        case .storm: "Storms"
        default: "Rain"
        }
    }

    /// "4p", or "16:00" on a 24-hour clock.
    static func hour(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let time = AgendaFormat.shortTime(date, calendar: calendar, locale: locale)
        return time.replacingOccurrences(of: ":00a", with: "a").replacingOccurrences(of: ":00p", with: "p")
    }

    /// Weather services write conditions in title case ("Partly Cloudy"); the digest uses sentence case.
    public static func sentenceCase(_ text: String) -> String {
        capitalized(text.lowercased())
    }

    private static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
