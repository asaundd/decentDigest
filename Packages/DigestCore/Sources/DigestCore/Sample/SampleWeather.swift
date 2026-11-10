import Foundation

/// A fixed forecast for previews and tests.
public struct SampleWeatherProvider: WeatherProvider {
    public init() {}

    public func report(latitude: Double, longitude: Double, now: Date) async throws -> WeatherReport {
        SampleDigest.weather(now: now)
    }

    public func credit() async -> WeatherCredit? { nil }
}

/// A fixed place for previews and tests.
@MainActor
public final class SamplePlaces: PlaceProvider {
    public var access: AccessState
    public var current: WeatherPlace

    public init(access: AccessState = .granted, place: WeatherPlace = SampleDigest.weatherPlace) {
        self.access = access
        self.current = place
    }

    public func locationAccess() -> AccessState { access }

    public func requestLocationAccess() async -> AccessState {
        if access == .notAsked { access = .granted }
        return access
    }

    public func currentPlace() async throws -> WeatherPlace { current }

    public func place(named text: String) async throws -> WeatherPlace? {
        WeatherPlace(name: text, latitude: current.latitude, longitude: current.longitude, isCurrentLocation: false)
    }
}
