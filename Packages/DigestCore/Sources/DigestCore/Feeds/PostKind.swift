import Foundation

/// How much of a post its feed carries. Feeds don't say whether their text is the whole post,
/// so this is a judgment from length and the "continue reading" lines publishers add to excerpts.
public enum PostKind: Sendable, Equatable {
    /// The whole post is in the feed and can be read in the app.
    case fullPost
    /// A summary or excerpt to preview before going to the site.
    case preview
    /// Only a title: reading it means going to the site.
    case titleOnly

    /// Text shorter than this is treated as an excerpt, not a full post.
    public static let fullPostMinimum = 1_500

    public static func classify(summary: String?, fullText: String?, author: String?) -> PostKind {
        if let fullText, isComplete(fullText) { return .fullPost }
        if fullText != nil || summary != nil || author != nil { return .preview }
        return .titleOnly
    }

    /// The text to show when a preview row is expanded: the longer of the excerpt and the summary.
    public static func previewText(summary: String?, fullText: String?) -> String? {
        guard let fullText, fullText.count > (summary?.count ?? 0) else { return summary }
        return fullText
    }

    static func isComplete(_ text: String) -> Bool {
        text.count >= fullPostMinimum && !endsLikeExcerpt(text)
    }

    private static let excerptEndings = [
        "continue reading", "read more", "read the full", "read the rest", "keep reading",
        "appeared first on", "[…]", "[...]", "subscribe to read", "for paid subscribers",
        "click here to read", "view the full",
    ]

    /// True when the last lines carry a publisher's "read the rest on our site" note.
    static func endsLikeExcerpt(_ text: String) -> Bool {
        let tail = String(text.suffix(240)).lowercased()
        if excerptEndings.contains(where: tail.contains) { return true }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("…") || trimmed.hasSuffix("...")
    }
}
