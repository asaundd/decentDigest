import Foundation

/// What the reader has done with a news story or podcast episode.
/// These states feed the reading history, so keep them distinct.
public enum ItemStatus: String, Codable, Sendable, CaseIterable {
    /// Arrived and not yet seen.
    case new
    /// Opened, or marked ✓ Read or cleared with Clear all (those have `resolvedAt` set; only an opened
    /// one has `openedAt`).
    case read
    /// Marked relevant. Earlier builds offered ↑; kept so existing reading history still reads.
    case useful
    /// Marked not relevant. Earlier builds offered ↓; kept so existing reading history still reads.
    case notRelevant
    /// Expired without being touched.
    case ignored
    /// Opened, then marked unread again.
    case unread
    /// Saved for later: moves to Saved and does not expire.
    case saved

    /// Whether the item can still appear in the News or Podcasts list. Read items stay until the next refresh.
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
