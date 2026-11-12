#if os(iOS)
import Foundation
import MapKit
import Observation

/// City suggestions while the reader types in Settings › Weather, from Apple Maps on the device.
/// Picking one is looked up like a typed city, so its name and place come out the same.
@MainActor
@Observable
public final class CitySearch {
    public struct Suggestion: Identifiable, Hashable, Sendable {
        public var id: String { title + "|" + subtitle }
        /// e.g. "Philadelphia".
        public var title: String
        /// e.g. "PA, United States".
        public var subtitle: String

        /// What to look up when it is picked.
        public var query: String {
            subtitle.isEmpty ? title : "\(title), \(subtitle)"
        }
    }

    /// At most this many suggestions show under the field.
    public static let limit = 5

    public private(set) var suggestions: [Suggestion] = []
    /// True when Apple Maps couldn't be reached for want of a connection.
    public private(set) var isOffline = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var delegate: CompleterDelegate?

    public init() {
        completer.resultTypes = .address
        // Cities and towns only, not street addresses.
        completer.addressFilter = MKAddressFilter(including: .locality)
        let delegate = CompleterDelegate { [weak self] in
            self?.refresh()
        } onFailure: { [weak self] offline in
            self?.isOffline = offline
        }
        self.delegate = delegate
        completer.delegate = delegate
    }

    /// Updates the suggestions for what the reader has typed so far.
    public func update(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            completer.cancel()
            suggestions = []
            isOffline = false
        } else {
            completer.queryFragment = trimmed
        }
    }

    public func clear() {
        completer.cancel()
        suggestions = []
        isOffline = false
    }

    private func refresh() {
        guard !completer.queryFragment.isEmpty else { return }
        isOffline = false
        suggestions = Array(completer.results.prefix(Self.limit).map {
            Suggestion(title: $0.title, subtitle: $0.subtitle)
        })
    }
}

/// Hands the completer's callbacks back to the main actor.
private final class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private let onUpdate: @MainActor @Sendable () -> Void
    private let onFailure: @MainActor @Sendable (Bool) -> Void

    init(onUpdate: @escaping @MainActor @Sendable () -> Void, onFailure: @escaping @MainActor @Sendable (Bool) -> Void) {
        self.onUpdate = onUpdate
        self.onFailure = onFailure
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let update = onUpdate
        MainActor.assumeIsolated { update() }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        let failure = onFailure
        let offline = Connectivity.isOffline(error)
        MainActor.assumeIsolated { failure(offline) }
    }
}
#endif
