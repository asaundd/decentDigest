import Foundation

/// What the reader has done with a news story or podcast episode.
/// These states feed the reading history, so keep them distinct.
public enum ItemStatus: String, Codable, Sendable, CaseIterable {
    /// Arrived and not yet seen.
    case new
    /// Opened.
    case read
    /// Marked useful (swipe right).
    case useful
    /// Marked not relevant (swipe left).
    case notRelevant
    /// Expired without being touched.
    case ignored
    /// Opened, then marked unread again.
    case unread

    /// Whether the item still belongs in the digest list.
    public var isActive: Bool {
        switch self {
        case .new, .unread: true
        case .read, .useful, .notRelevant, .ignored: false
        }
    }
}
