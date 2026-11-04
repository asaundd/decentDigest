import CryptoKit
import Foundation

/// A stable id for a feed item, the same on every device.
/// SHA-256 of the feed URL plus the item's guid (or its link when there is no guid).
/// Synced reading state is keyed by this id, so it must never change.
public enum ItemID {
    public static func make(feedURL: String, guidOrLink: String) -> String {
        let input = Data((feedURL + "\n" + guidOrLink).utf8)
        return SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    }
}
