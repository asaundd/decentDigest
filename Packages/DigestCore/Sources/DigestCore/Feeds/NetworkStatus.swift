#if canImport(Network)
import Foundation
import Network
import Observation

/// Whether the device has a connection, from Apple's network monitor on the device. It needs no
/// permission and sends nothing anywhere. The digest shows a note while offline, and setup's
/// searches that need the web are turned off. A failure that `Connectivity.isOffline` recognizes
/// still says so too, for a network that claims a connection but reaches nothing.
@MainActor
@Observable
public final class NetworkStatus {
    public private(set) var isOffline = false

    @ObservationIgnored private let monitor = NWPathMonitor()

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in self?.isOffline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "com.decentdigest.network"))
    }
}
#endif
