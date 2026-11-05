import Foundation

/// How much of a post its feed carries. Feeds don't say whether their text is the whole post,
/// so this is a judgment from length and the "continue reading" lines publishers add to excerpts.
public enum PostKind: Sendable, Equatable {
    /// The whole post is in the feed and can be read in the app.
    case fullPost
    /// A short summary of the post, written to stand on its own.
    case summary
    /// The opening of the post, cut off before the end. The rest is on the site.
    case excerpt
    /// Only a title: reading it means going to the site.
    case titleOnly

    /// The first line of an expanded row, naming what the feed sent.
    public var label: String {
        switch self {
        case .fullPost: "Full post"
        case .summary: "Summary"
        case .excerpt: "Excerpt"
        case .titleOnly: "Link only"
        }
    }

    /// The row shows a preview of the post, not the whole of it.
    public var isPreview: Bool { self == .summary || self == .excerpt }

    /// Text shorter than this is treated as an excerpt, not a full post.
    public static let fullPostMinimum = 1_500
    /// An expanded row shows at most this many characters; the rest is one tap away in the panel.
    public static let rowTextLimit = 320

    /// Cuts text for an expanded row at a word boundary, ending in "…". Returns the text unchanged if it fits.
    public static func clipForRow(_ text: String, limit: Int = rowTextLimit) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        let end = cut.lastIndex(where: { $0 == " " || $0 == "\n" }) ?? cut.endIndex
        return cut[..<end].trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) + "…"
    }

    public static func classify(summary: String?, fullText: String?) -> PostKind {
        if let fullText, isComplete(fullText) { return .fullPost }
        guard let text = previewText(summary: summary, fullText: fullText) else { return .titleOnly }
        // Post text that stops short, or a summary with a "read more" note, is an excerpt.
        return fullText != nil || endsLikeExcerpt(text) ? .excerpt : .summary
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
