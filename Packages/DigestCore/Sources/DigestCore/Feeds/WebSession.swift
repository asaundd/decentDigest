import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The one way the app reaches the web: feeds, the page behind a pasted address and Apple's
/// podcast lookup. Every request stands alone: no cookies are kept or sent, nothing is cached
/// on disk, and a download stops at a size and time limit so one bad feed can't stall a refresh.
public enum WebSession {
    /// A download larger than this is refused. Real feeds are well under 1 MB.
    public static let maxBytes = 5_000_000

    /// A download that takes longer than this in all is stopped.
    public static let maxSeconds: TimeInterval = 30

    public enum DownloadError: Error, Equatable {
        case tooLarge
    }

    public static let shared: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.urlCredentialStorage = nil
        config.timeoutIntervalForResource = maxSeconds
        return URLSession(configuration: config)
    }()

    /// Downloads the response body, refusing one larger than `limit` bytes.
    public static func data(for request: URLRequest, session: URLSession = shared, limit: Int = maxBytes) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
        let (data, response) = try await session.data(for: request)
        guard data.count <= limit else { throw DownloadError.tooLarge }
        return (data, response)
        #else
        let (bytes, response) = try await session.bytes(for: request)
        let expected = response.expectedContentLength
        if expected > Int64(limit) {
            bytes.task.cancel()
            throw DownloadError.tooLarge
        }
        var data = Data()
        if expected > 0 { data.reserveCapacity(Int(expected)) }
        for try await byte in bytes {
            data.append(byte)
            if data.count > limit {
                bytes.task.cancel()
                throw DownloadError.tooLarge
            }
        }
        return (data, response)
        #endif
    }
}
