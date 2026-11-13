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
    /// A pull to refresh fetches the forecast again only after this long, so pulling over and
    /// over doesn't spend WeatherKit's monthly quota.
    public static let pullRefreshInterval: TimeInterval = 10 * 60

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

        // Rain, snow or storms today and tomorrow too comes first: "Rain again tomorrow."
        if let again = wetAgain(report, first: first, second: second, secondName: secondName, unit: unit) {
            return again
        }

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

    /// When today is wet and tomorrow is too: "Rain again tomorrow.", "Storms again tomorrow and
    /// Wednesday.", "Rain again tomorrow, and colder." A different kind reads plainly ("Snow
    /// tomorrow.", "Storms likely tomorrow."). Then what changes the day after, if anything. Nil when
    /// today or tomorrow is dry.
    static func wetAgain(_ report: WeatherReport, first: WeatherDay, second: WeatherDay, secondName: String, unit: TemperatureUnit) -> String? {
        let today = report.today
        let todaySky = today.sky.isWet ? today.sky : report.sky
        guard todaySky.isWet, first.sky.isWet else { return nil }
        let kind = word(for: first.sky)
        let opening: String
        if word(for: todaySky) == kind {
            opening = "\(kind) again"
        } else {
            opening = first.sky == .storm ? "Storms likely" : kind
        }
        let alsoNext = second.sky.isWet && word(for: second.sky) == kind
        var text = opening + (alsoNext ? " tomorrow and \(secondName)" : " tomorrow")
        text += temperatureSuffix(change(from: today, to: first).temperature) + "."
        if !alsoNext {
            let next = change(from: first, to: second)
            if !next.isEmpty {
                text += " " + sentence(next, when: secondName, days: [second], unit: unit)
            }
        }
        return text
    }

    // MARK: The rest of the week

    /// One short sentence (two at most) on anything notable later in the week, after the two days
    /// the change line covers. In order: storms, rain or snow starting, heat, a freeze or a turn
    /// warmer or colder, then the weekend ("Cold and sunny this weekend."). Storms can share the
    /// line with one other sentence. Nil when nothing stands out.
    public static func weekLine(_ report: WeatherReport, unit: TemperatureUnit, calendar: Calendar = .current, locale: Locale = .current) -> String? {
        let days = Array(report.days.prefix(weekDays))
        guard days.count > 2 else { return nil }
        let later = Array(days.dropFirst(2))
        let today = report.today
        func name(_ day: WeatherDay) -> String {
            AgendaFormat.dayName(midday(day), now: today.date, calendar: calendar, locale: locale)
        }

        // Storms come first.
        let stormDays = later.filter { $0.sky == .storm }
        let storms = stormDays.isEmpty ? nil : "Storms likely \(daysPhrase(stormDays.map(name)))."

        // Then rain or snow that starts later in the week; the change line covers anything sooner.
        var precipitation: String?
        if let wet = later.firstIndex(where: { $0.sky.isWet && $0.sky != .storm }) {
            let before = wet == 0 ? days[1] : later[wet - 1]
            if !before.sky.isWet {
                let kind = later[wet].sky == .snow ? "Snow" : "Rain"
                let run = later[wet...].prefix { $0.sky.isWet && $0.sky != .storm }
                precipitation = "\(kind) \(daysPhrase(run.map(name)))."
            }
        }

        // Then heat, a freeze or a turn warmer or colder, then the weekend. A turn that starts on
        // the weekend is left to the weekend sentence, which says it better ("Cold and sunny this weekend.").
        let weekend = later.filter { calendar.isDateInWeekend(midday($0)) }
        var weekendLine: String?
        if weekend.count == 2, !weekend.contains(where: { $0.sky == .storm }),
           let words = weekendWords(weekend, today: today) {
            weekendLine = capitalized(words) + " this weekend."
        }
        var temperature: String?
        if let turn = temperatureTurn(later, before: days[1], today: today, unit: unit) {
            if !(weekendLine != nil && calendar.isDateInWeekend(midday(turn.day))) {
                temperature = turn.text(name(turn.day))
            }
        }

        // Storms, plus the first of the rest: one sentence, two at most.
        let rest = precipitation ?? temperature ?? weekendLine
        let sentences = [storms, rest].compactMap { $0 }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
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

    /// Heat, a freeze, or highs turning 8° or more from today's, starting later in the week:
    /// the day it starts, and the words for it once the day is named.
    private static func temperatureTurn(_ later: [WeatherDay], before: WeatherDay, today: WeatherDay, unit: TemperatureUnit) -> (day: WeatherDay, text: (String) -> String)? {
        if before.high < heat, today.high < heat, let hot = later.first(where: { $0.high >= heat }) {
            let high = unit.degrees(hot.high)
            return (hot, { "Hot \($0), highs near \(high)." })
        }
        if before.low > freeze, today.low > freeze, let cold = later.first(where: { $0.low <= freeze }) {
            let low = unit.degrees(cold.low)
            return (cold, { "A freeze \($0), lows near \(low)." })
        }
        guard abs(before.high - today.high) < notableHighChange else { return nil }
        if let warmer = later.first(where: { $0.high - today.high >= notableHighChange }) {
            return (warmer, { "Warmer starting \($0)." })
        }
        if let colder = later.first(where: { today.high - $0.high >= notableHighChange }) {
            return (colder, { "Colder starting \($0)." })
        }
        return nil
    }

    /// "Friday", "Friday and Saturday", or "starting Friday" for three or more.
    private static func daysPhrase(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return "starting \(names[0])"
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
        text += temperatureSuffix(change.temperature)
        return text + "."
    }

    /// ", and colder" after rain, snow or storms; empty when the temperature holds.
    private static func temperatureSuffix(_ temperature: Change.Lead?) -> String {
        switch temperature {
        case .warmer: ", and warmer"
        case .colder: ", and colder"
        case .hot: ", and hot"
        case .freeze: ", with a freeze"
        default: ""
        }
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

    /// The gray note under the weather while the device is offline: "Weather from 9:40a",
    /// "from yesterday 9:40p", or the weekday when it is older.
    public static func offlineNote(fetchedAt: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = AgendaFormat.shortTime(fetchedAt, calendar: calendar, locale: locale)
        let when: String
        if calendar.isDate(fetchedAt, inSameDayAs: now) {
            when = time
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(fetchedAt, inSameDayAs: yesterday) {
            when = "yesterday \(time)"
        } else {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("EEEE")
            when = "\(formatter.string(from: fetchedAt)) \(time)"
        }
        return "Weather from \(when)"
    }

    private static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
