#if os(iOS)
import CoreLocation
import Foundation

/// The device's location through Core Location, and typed cities through the geocoder.
/// Location is optional: without it the reader can type a city instead.
@MainActor
public final class LocationPlaces: NSObject, PlaceProvider {
    private let manager = CLLocationManager()
    private var accessWaiters: [CheckedContinuation<Void, Never>] = []
    private var locationWaiters: [CheckedContinuation<CLLocationCoordinate2D, Error>] = []

    override public init() {
        super.init()
        manager.delegate = self
        // A city is all the weather needs.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public func locationAccess() -> AccessState {
        Self.state(manager.authorizationStatus)
    }

    public func requestLocationAccess() async -> AccessState {
        guard manager.authorizationStatus == .notDetermined else { return locationAccess() }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            accessWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
        return locationAccess()
    }

    public func currentPlace() async throws -> WeatherPlace {
        let coordinate = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D, Error>) in
            locationWaiters.append(continuation)
            if locationWaiters.count == 1 { manager.requestLocation() }
        }
        let name = (try? await Self.name(latitude: coordinate.latitude, longitude: coordinate.longitude)) ?? "your location"
        return WeatherPlace(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude, isCurrentLocation: true)
    }

    public func place(named text: String) async throws -> WeatherPlace? {
        try await Self.lookUp(text)
    }

    // MARK: Delegate results, back on the main actor

    fileprivate func accessChanged() {
        guard manager.authorizationStatus != .notDetermined else { return }
        let waiters = accessWaiters
        accessWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    fileprivate func located(_ result: Result<CLLocationCoordinate2D, Error>) {
        let waiters = locationWaiters
        locationWaiters = []
        for waiter in waiters { waiter.resume(with: result) }
    }

    // MARK: Geocoding (off the main actor; only plain values come back)
    // CLGeocoder still works on iOS 26; MapKit's newer geocoding requests can replace it later.

    nonisolated private static func name(latitude: Double, longitude: Double) async throws -> String? {
        let marks = try await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        return marks.first.flatMap(placeName)
    }

    nonisolated private static func lookUp(_ text: String) async throws -> WeatherPlace? {
        let marks = try await CLGeocoder().geocodeAddressString(text)
        guard let mark = marks.first, let coordinate = mark.location?.coordinate else { return nil }
        return WeatherPlace(
            name: placeName(mark) ?? text,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            isCurrentLocation: false
        )
    }

    /// "Brooklyn, NY" in the US, "Lyon, France" elsewhere.
    nonisolated private static func placeName(_ mark: CLPlacemark) -> String? {
        guard let city = mark.subLocality.flatMap({ mark.locality == "New York" ? $0 : nil }) ?? mark.locality ?? mark.name else { return nil }
        let region = mark.isoCountryCode == "US" ? mark.administrativeArea : mark.country
        return [city, region].compactMap { $0 }.joined(separator: ", ")
    }

    private static func state(_ status: CLAuthorizationStatus) -> AccessState {
        switch status {
        case .notDetermined: .notAsked
        case .authorizedWhenInUse, .authorizedAlways: .granted
        default: .denied
        }
    }
}

extension LocationPlaces: CLLocationManagerDelegate {
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated { self.accessChanged() }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        MainActor.assumeIsolated { self.located(.success(coordinate)) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { self.located(.failure(error)) }
    }
}
#endif
