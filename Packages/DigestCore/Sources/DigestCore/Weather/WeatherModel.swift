import Foundation
import Observation

/// Where forecasts come from: WeatherKit on the device, a fixed sample in previews and tests.
public protocol WeatherProvider: Sendable {
    func report(latitude: Double, longitude: Double, now: Date) async throws -> WeatherReport
    /// The Apple Weather mark and legal link, when the provider needs them shown.
    func credit() async -> WeatherCredit?
}

/// The device's location, and cities the reader types in.
@MainActor
public protocol PlaceProvider: AnyObject {
    func locationAccess() -> AccessState
    func requestLocationAccess() async -> AccessState
    /// Where the device is now, named by its city.
    func currentPlace() async throws -> WeatherPlace
    /// The best match for a typed city, or nil when nothing matches.
    func place(named text: String) async throws -> WeatherPlace?
}

/// The weather lines under the date. Opens with the last forecast, then fetches a new one
/// when it is old. With no location and no typed-in city, there is no weather to show.
@MainActor
@Observable
public final class WeatherModel {
    public private(set) var report: WeatherReport?
    public private(set) var place: WeatherPlace?
    public private(set) var locationAccess: AccessState
    /// A city the reader typed in. When set, it is used instead of the device's location.
    public private(set) var typedCity: WeatherPlace?
    public private(set) var credit: WeatherCredit?
    /// True when the forecast couldn't be fetched and sample weather is showing instead (debug builds only).
    public private(set) var isSample = false

    private let provider: any WeatherProvider
    private let places: any PlaceProvider
    private let defaults: UserDefaults
    private let now: () -> Date
    private let sampleOnFailure: Bool
    @ObservationIgnored private var isLoading = false

    /// - Parameter sampleOnFailure: show sample weather when the forecast can't be fetched,
    ///   so the layout can be checked before WeatherKit is set up.
    public init(provider: any WeatherProvider, places: any PlaceProvider, defaults: UserDefaults = .standard, sampleOnFailure: Bool = false, now: @escaping () -> Date = { .now }) {
        self.provider = provider
        self.places = places
        self.defaults = defaults
        self.sampleOnFailure = sampleOnFailure
        self.now = now
        self.locationAccess = places.locationAccess()
        self.typedCity = Self.decode(WeatherPlace.self, defaults.data(forKey: Keys.typedCity))
        self.place = Self.decode(WeatherPlace.self, defaults.data(forKey: Keys.place))
        self.report = Self.decode(WeatherReport.self, defaults.data(forKey: Keys.report))
        if !hasPlaceSource { report = nil; place = nil }
    }

    /// True while there is a place to show weather for, even before the first forecast arrives.
    public var hasPlaceSource: Bool {
        typedCity != nil || locationAccess == .granted
    }

    /// Fetches a new forecast when the cached one is old or for another place.
    /// `force` (a pull to refresh, or a new place) still reuses a forecast for the same place
    /// fetched in the last few minutes.
    public func reload(force: Bool = false) async {
        locationAccess = places.locationAccess()
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let target = await resolvePlace() else {
            report = nil
            place = nil
            return
        }
        let date = now()
        let reuseFor = force ? WeatherRules.pullRefreshInterval : WeatherRules.refreshInterval
        if !isSample, let report, place == target,
           date.timeIntervalSince(report.fetchedAt) < reuseFor {
            // The page opened with a cached forecast; it still needs the Apple Weather credit.
            if credit == nil { credit = await provider.credit() }
            return
        }
        place = target
        do {
            let fresh = try await provider.report(latitude: target.latitude, longitude: target.longitude, now: date)
            report = fresh
            isSample = false
            save(fresh, forKey: Keys.report)
            save(target, forKey: Keys.place)
            if credit == nil { credit = await provider.credit() }
        } catch {
            // Keep the last forecast if there is one; it still says roughly the right thing.
            if report == nil, sampleOnFailure {
                report = SampleDigest.weather(now: date)
                isSample = true
            }
        }
    }

    /// Asks to use the device's location, then fetches the forecast for it.
    public func useCurrentLocation() async {
        locationAccess = await places.requestLocationAccess()
        guard locationAccess == .granted else { return }
        typedCity = nil
        defaults.removeObject(forKey: Keys.typedCity)
        await reload(force: true)
    }

    /// Looks up a typed city. Returns false when nothing matches.
    @discardableResult
    public func setCity(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let found = try? await places.place(named: trimmed) else { return false }
        typedCity = found
        save(found, forKey: Keys.typedCity)
        await reload(force: true)
        return true
    }

    /// Forgets the typed city, going back to the device's location if it is allowed.
    public func clearCity() async {
        typedCity = nil
        defaults.removeObject(forKey: Keys.typedCity)
        await reload(force: true)
    }

    // MARK: Private

    private func resolvePlace() async -> WeatherPlace? {
        if let typedCity { return typedCity }
        guard locationAccess == .granted else { return nil }
        if let found = try? await places.currentPlace() { return found }
        // Location can fail indoors; the last known place is close enough.
        return place?.isCurrentLocation == true ? place : nil
    }

    private enum Keys {
        static let report = "weather.report"
        static let place = "weather.place"
        static let typedCity = "weather.typedCity"
    }

    private func save(_ value: some Encodable, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
