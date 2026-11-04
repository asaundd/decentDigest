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
    /// Saved for later: moves to Saved news and does not expire.
    case saved

    /// Whether the item can still appear in the News list. Read items stay until the next refresh.
    public var isActive: Bool {
        switch self {
        case .new, .unread, .read: true
        case .useful, .notRelevant, .ignored, .saved: false
        }
    }

    /// Unread items show their title in bold.
    public var isUnread: Bool {
        self == .new || self == .unread
    }
}
