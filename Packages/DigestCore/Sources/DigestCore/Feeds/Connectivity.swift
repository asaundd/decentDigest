import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Tells a failure for want of a connection from any other, from the error iOS returns. The app
/// never watches the network itself.
public enum Connectivity {
    /// Thrown by a lookup that couldn't reach the web at all, so the reader can be told they're
    /// offline rather than that nothing was found.
    public struct Offline: Error, Equatable {
        public init() {}
    }

    private static let offlineCodes: Set<Int> = [
        URLError.notConnectedToInternet.rawValue,
        URLError.networkConnectionLost.rawValue,
        URLError.dataNotAllowed.rawValue,
        URLError.internationalRoamingOff.rawValue,
        URLError.callIsActive.rawValue,
        URLError.cannotFindHost.rawValue,
        URLError.dnsLookupFailed.rawValue,
    ]

    /// True when the error, or one it wraps, means the device has no connection.
    public static func isOffline(_ error: any Error) -> Bool {
        if error is Offline { return true }
        var current: NSError? = error as NSError
        var depth = 0
        while let nsError = current, depth < 5 {
            if nsError.domain == NSURLErrorDomain, offlineCodes.contains(nsError.code) { return true }
            // Core Location's geocoder: kCLErrorNetwork.
            if nsError.domain == "kCLErrorDomain", nsError.code == 2 { return true }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return false
    }
}
