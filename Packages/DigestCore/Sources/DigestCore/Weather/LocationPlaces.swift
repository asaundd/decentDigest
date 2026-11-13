#if os(iOS)
import CoreLocation
import Foundation
import MapKit

/// The device's location through Core Location, and city names through MapKit.
/// Location is optional: without it the reader can type a city instead.
@MainActor
public final class LocationPlaces: NSObject, PlaceProvider {
    /// The place's name when the device's location can't be put into words (offline, say).
    public static let unnamed = "Your location"

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
        let name = (try? await Self.name(latitude: coordinate.latitude, longitude: coordinate.longitude)) ?? Self.unnamed
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

    // MARK: Geocoding with MapKit (off the main actor; only plain values come back)

    nonisolated private static func name(latitude: Double, longitude: Double) async throws -> String? {
        let request: MKReverseGeocodingRequest? = MKReverseGeocodingRequest(location: CLLocation(latitude: latitude, longitude: longitude))
        guard let request else { return nil }
        return try await request.mapItems.first.flatMap(placeName)
    }

    nonisolated private static func lookUp(_ text: String) async throws -> WeatherPlace? {
        let request: MKGeocodingRequest? = MKGeocodingRequest(addressString: text)
        guard let request, let item = try await request.mapItems.first else { return nil }
        let coordinate = item.location.coordinate
        return WeatherPlace(
            name: placeName(item) ?? text,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            isCurrentLocation: false
        )
    }

    /// "Brooklyn, NY" in the US, "Lyon, France" elsewhere.
    nonisolated private static func placeName(_ item: MKMapItem) -> String? {
        item.addressRepresentations?.cityWithContext ?? item.name
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
