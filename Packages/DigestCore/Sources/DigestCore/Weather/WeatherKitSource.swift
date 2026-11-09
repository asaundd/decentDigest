#if os(iOS) && canImport(WeatherKit)
import CoreLocation
import Foundation
import WeatherKit

/// Forecasts from Apple's WeatherKit. Needs the WeatherKit capability on the app's identifier,
/// which only a paid Apple Developer Program team can turn on.
public struct WeatherKitSource: WeatherProvider {
    public init() {}

    public func report(latitude: Double, longitude: Double, now: Date) async throws -> WeatherReport {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let (current, hourly, daily) = try await WeatherService.shared.weather(for: location, including: .current, .hourly, .daily)
        let days = daily.forecast.map(Self.day)
        // The first forecast day is today where the place is.
        guard let today = days.first else { throw WeatherKitSourceError.noForecast }
        let endOfToday = today.date.addingTimeInterval(86_400)
        let hours = hourly.forecast
            .filter { $0.date < endOfToday }
            .map { WeatherHour(date: $0.date, sky: Self.sky($0.condition, precipitation: $0.precipitation, chance: $0.precipitationChance)) }
        return WeatherReport(
            fetchedAt: now,
            temperature: current.temperature.converted(to: .fahrenheit).value,
            condition: WeatherRules.sentenceCase(current.condition.description),
            sky: Self.sky(current.condition, precipitation: .none, chance: 0),
            today: today,
            hours: hours,
            days: Array(days.dropFirst())
        )
    }

    public func credit() async -> WeatherCredit? {
        guard let attribution = try? await WeatherService.shared.attribution else { return nil }
        return WeatherCredit(
            markLight: attribution.combinedMarkLightURL,
            markDark: attribution.combinedMarkDarkURL,
            legalPage: attribution.legalPageURL
        )
    }

    private static func day(_ day: DayWeather) -> WeatherDay {
        WeatherDay(
            date: day.date,
            high: day.highTemperature.converted(to: .fahrenheit).value,
            low: day.lowTemperature.converted(to: .fahrenheit).value,
            condition: WeatherRules.sentenceCase(day.condition.description),
            sky: sky(day.condition, precipitation: day.precipitation, chance: day.precipitationChance)
        )
    }

    /// Sorts WeatherKit's conditions into the few kinds the rules care about.
    /// A likely chance of rain or snow counts as wet even when the headline condition is cloudy.
    static func sky(_ condition: WeatherCondition, precipitation: Precipitation, chance: Double) -> Sky {
        switch condition {
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms,
             .tropicalStorm, .hurricane, .blizzard, .hail:
            return .storm
        case .snow, .heavySnow, .flurries, .sunFlurries, .blowingSnow:
            return .snow
        case .rain, .heavyRain, .drizzle, .sunShowers, .freezingRain, .freezingDrizzle, .sleet, .wintryMix:
            return .rain
        default:
            break
        }
        if chance >= 0.5 {
            switch precipitation {
            case .snow: return .snow
            case .rain, .sleet, .mixed, .hail: return .rain
            default: break
            }
        }
        switch condition {
        case .clear, .mostlyClear, .hot: return .clear
        default: return .cloudy
        }
    }
}

enum WeatherKitSourceError: Error {
    case noForecast
}
#endif
