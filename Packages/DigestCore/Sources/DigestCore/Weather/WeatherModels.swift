import Foundation

/// The kind of weather, as far as the digest's rules care. Conditions are shown as words, never icons.
public enum Sky: String, Codable, Sendable, Hashable {
    case clear, cloudy, rain, snow
    /// Thunderstorms and other severe weather.
    case storm

    /// Rain, snow or storms.
    public var isWet: Bool { self == .rain || self == .snow || self == .storm }
}

/// One day of the forecast. Temperatures are kept in °F; the rules are written in °F,
/// and they are shown in the unit the device uses.
public struct WeatherDay: Codable, Sendable, Hashable, Identifiable {
    public var id: Date { date }
    /// The start of the day.
    public var date: Date
    public var high: Double
    public var low: Double
    /// Sentence case, e.g. "Partly cloudy".
    public var condition: String
    public var sky: Sky

    public init(date: Date, high: Double, low: Double, condition: String, sky: Sky) {
        self.date = date
        self.high = high
        self.low = low
        self.condition = condition
        self.sky = sky
    }
}

/// One hour of today's forecast, used to say when rain starts or stops.
public struct WeatherHour: Codable, Sendable, Hashable {
    public var date: Date
    public var sky: Sky

    public init(date: Date, sky: Sky) {
        self.date = date
        self.sky = sky
    }
}

/// Everything the weather lines need. Cached on the device so the page opens with it at once.
public struct WeatherReport: Codable, Sendable, Hashable {
    public var fetchedAt: Date
    /// Now, in °F.
    public var temperature: Double
    /// Now, sentence case.
    public var condition: String
    public var sky: Sky
    public var today: WeatherDay
    /// The rest of today, hour by hour.
    public var hours: [WeatherHour]
    /// The days after today, in order.
    public var days: [WeatherDay]

    public init(fetchedAt: Date, temperature: Double, condition: String, sky: Sky, today: WeatherDay, hours: [WeatherHour], days: [WeatherDay]) {
        self.fetchedAt = fetchedAt
        self.temperature = temperature
        self.condition = condition
        self.sky = sky
        self.today = today
        self.hours = hours
        self.days = days
    }
}

/// Where the forecast is for: the device's location, or a city the reader typed in.
public struct WeatherPlace: Codable, Sendable, Hashable {
    /// e.g. "Brooklyn, NY".
    public var name: String
    public var latitude: Double
    public var longitude: Double
    /// True when it comes from the device's location (shown with a small location arrow).
    public var isCurrentLocation: Bool

    public init(name: String, latitude: Double, longitude: Double, isCurrentLocation: Bool) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.isCurrentLocation = isCurrentLocation
    }
}

/// The Apple Weather mark and legal page WeatherKit asks apps to show.
public struct WeatherCredit: Sendable, Hashable {
    /// The Apple Weather mark's images. Nil in the fallback, which shows the words "Apple Weather".
    public var markLight: URL?
    public var markDark: URL?
    public var legalPage: URL

    public init(markLight: URL?, markDark: URL?, legalPage: URL) {
        self.markLight = markLight
        self.markDark = markDark
        self.legalPage = legalPage
    }

    /// Used while Apple's own credit can't be fetched (offline, say), so a cached forecast still
    /// shows the credit: the words "Apple Weather" and Apple's data source and legal page.
    public static let fallback = WeatherCredit(
        markLight: nil,
        markDark: nil,
        legalPage: URL(string: "https://developer.apple.com/weatherkit/data-source-attribution/")!
    )

    /// True for the fallback, which is replaced once Apple's credit arrives.
    public var isFallback: Bool { markLight == nil && markDark == nil }
}

/// °F or °C, following the device's setting.
public enum TemperatureUnit: Sendable, Equatable {
    case fahrenheit, celsius

    /// The unit the device shows temperatures in.
    public static func current(locale: Locale = .current) -> TemperatureUnit {
        // Formatting for weather converts to the reader's preferred unit, so a known value tells which one it is.
        let boiling = Measurement(value: 100, unit: UnitTemperature.celsius)
        let text = boiling.formatted(.measurement(width: .narrow, usage: .weather).locale(locale))
        if text.contains("212") { return .fahrenheit }
        if text.contains("100") { return .celsius }
        return locale.measurementSystem == .us ? .fahrenheit : .celsius
    }

    /// A °F value in this unit, rounded.
    public func value(_ fahrenheit: Double) -> Int {
        switch self {
        case .fahrenheit: Int(fahrenheit.rounded())
        case .celsius: Int(((fahrenheit - 32) * 5 / 9).rounded())
        }
    }

    /// "48°".
    public func degrees(_ fahrenheit: Double) -> String {
        "\(value(fahrenheit))°"
    }
}
