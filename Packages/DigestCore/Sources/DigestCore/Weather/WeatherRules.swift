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

    // MARK: The rest of the week

    /// One short sentence (two at most) on anything notable later in the week, after the two days
    /// the change line covers: storms, the weekend ("Cold and sunny this weekend."), rain or snow
    /// starting, heat or a freeze, or a turn warmer or colder. Nil when nothing stands out.
    public static func weekLine(_ report: WeatherReport, unit: TemperatureUnit, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        let days = Array(report.days.prefix(weekDays))
        guard days.count > 2 else { return nil }
        let later = Array(days.dropFirst(2))
        let today = report.today
        func name(_ day: WeatherDay) -> String {
            AgendaFormat.dayName(midday(day), now: today.date, calendar: calendar, locale: locale)
        }

        var sentences: [String] = []

        // Storms come first.
        let stormDays = later.filter { $0.sky == .storm }
        if !stormDays.isEmpty {
            sentences.append("Storms likely \(daysPhrase(stormDays.map(name))).")
        }

        // The weekend, when both days are later in the week and storms aren't already named there.
        let weekend = later.filter { calendar.isDateInWeekend(midday($0)) }
        if weekend.count == 2, !weekend.contains(where: { $0.sky == .storm }),
           let words = weekendWords(weekend, today: today) {
            sentences.append(capitalized(words) + " this weekend.")
        }

        if sentences.isEmpty {
            if let wet = later.firstIndex(where: { $0.sky.isWet }) {
                // Only rain or snow that starts later in the week; the change line covers anything sooner.
                let before = wet == 0 ? days[1] : later[wet - 1]
                if !before.sky.isWet {
                    let kind = later[wet].sky == .snow ? "Snow" : "Rain"
                    let run = later[wet...].prefix { $0.sky.isWet }
                    sentences.append("\(kind) \(daysPhrase(run.map(name))).")
                }
            }
        }

        if sentences.isEmpty, let line = temperatureTurn(later, before: days[1], today: today, unit: unit, name: name) {
            sentences.append(line)
        }

        return sentences.isEmpty ? nil : sentences.prefix(2).joined(separator: " ")
    }

    /// "cold and sunny", "rainy", "warm": what stands out about the weekend, or nil.
    private static func weekendWords(_ weekend: [WeatherDay], today: WeatherDay) -> String? {
        let high = weekend.map(\.high).reduce(0, +) / Double(weekend.count)
        var temperature: String?
        if weekend.contains(where: { $0.high >= heat }) {
            temperature = "hot"
        } else if weekend.contains(where: { $0.low <= freeze }) && today.low > freeze {
            temperature = "freezing"
        } else if today.high - high >= notableHighChange {
            temperature = "cold"
        } else if high - today.high >= notableHighChange {
            temperature = "warm"
        }
        var sky: String?
        if weekend.allSatisfy({ $0.sky == .clear }) {
            sky = "sunny"
        } else if weekend.allSatisfy({ $0.sky == .snow }) {
            sky = "snowy"
        } else if weekend.allSatisfy({ $0.sky.isWet }) {
            sky = "rainy"
        }
        switch (temperature, sky) {
        case let (t?, s?): return "\(t) and \(s)"
        case let (t?, nil): return t
        case let (nil, s?): return s
        default: return nil
        }
    }

    /// Heat, a freeze, or highs turning 8° or more from today's, starting later in the week.
    private static func temperatureTurn(_ later: [WeatherDay], before: WeatherDay, today: WeatherDay, unit: TemperatureUnit, name: (WeatherDay) -> String) -> String? {
        if before.high < heat, today.high < heat, let hot = later.first(where: { $0.high >= heat }) {
            return "Hot \(name(hot)), highs near \(unit.degrees(hot.high))."
        }
        if before.low > freeze, today.low > freeze, let cold = later.first(where: { $0.low <= freeze }) {
            return "A freeze \(name(cold)), lows near \(unit.degrees(cold.low))."
        }
        let soonDiff = before.high - today.high
        guard abs(soonDiff) < notableHighChange else { return nil }
        if let warmer = later.first(where: { $0.high - today.high >= notableHighChange }) {
            return "Warmer from \(name(warmer))."
        }
        if let colder = later.first(where: { today.high - $0.high >= notableHighChange }) {
            return "Colder from \(name(colder))."
        }
        return nil
    }

    /// "Friday", "Friday and Saturday", or "from Friday" for three or more.
    private static func daysPhrase(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return "from \(names[0])"
        }
    }

    /// Forecast days start at midnight where the place is; midday keeps the right weekday
    /// when the device is in another time zone.
    private static func midday(_ day: WeatherDay) -> Date {
        day.date.addingTimeInterval(12 * 3_600)
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
