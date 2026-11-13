import CryptoKit
import Foundation

/// A stable id for a feed item, the same on every device.
/// SHA-256 of the feed address's key plus the item's guid (or its link when there is no guid).
/// Synced reading state is keyed by this id, so it must never change.
public enum ItemID {
    /// The id of an item in the feed at `feedURL`. The address goes in as its key, so two devices
    /// that added the same feed as `https://www.site.com/feed/` and `site.com/feed` give its items
    /// the same ids.
    public static func make(feedURL: String, guidOrLink: String) -> String {
        let input = Data((key(for: feedURL) + "\n" + guidOrLink).utf8)
        return SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    }

    /// A feed address without its scheme, "www." or a trailing slash, lowercased. Two addresses with
    /// the same key are the same feed.
    public static func key(for feedURL: String) -> String {
        var text = feedURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasPrefix("www.") { text.removeFirst(4) }
        while text.hasSuffix("/") { text.removeLast() }
        return text
    }
}
