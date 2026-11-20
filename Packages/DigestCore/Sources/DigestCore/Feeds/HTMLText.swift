import Foundation

/// Turns feed HTML into plain text.
public enum HTMLText {
    /// Plain text that keeps paragraph breaks, for showing a full post the feed carries.
    public static func paragraphs(_ html: String, limit: Int = FeedParser.fullTextLimit) -> String {
        var text = html
        for tag in ["script", "style", "figure", "figcaption"] {
            text = text.replacingOccurrences(of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>", with: " ", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</(p|div|h[1-6]|blockquote|pre|ul|ol)>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<li[^>]*>", with: "\n– ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = removeInvisible(decodeTwice(text))
        let lines = text.components(separatedBy: "\n").map {
            $0.replacingOccurrences(of: "[ \\t\u{00A0}]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        text = lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > limit {
            text = String(text.prefix(limit)) + "…"
        }
        return text
    }

    public static func plain(_ html: String, limit: Int? = nil) -> String {
        var text = html
        // Drop blocks whose contents are never readable text.
        for tag in ["script", "style", "figure", "figcaption"] {
            text = text.replacingOccurrences(of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>", with: " ", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = removeInvisible(decodeTwice(text))
        // A second pass catches tags that were entity-encoded (e.g. &lt;p&gt;).
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let limit, text.count > limit {
            let cut = text.prefix(limit)
            // End on a word boundary when one is close.
            if let space = cut.lastIndex(of: " "), cut.distance(from: space, to: cut.endIndex) < 40 {
                text = String(cut[..<space]) + "…"
            } else {
                text = String(cut) + "…"
            }
        }
        return text
    }

    /// Drops characters a feed could use to make text display misleadingly: control characters
    /// (other than line breaks and tabs), the marks that override or isolate text direction, and
    /// invisible zero-width spaces. The joiners that emoji and some scripts need are kept.
    static func removeInvisible(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: text.unicodeScalars.lazy.filter { !isInvisible($0) })
        return String(scalars)
    }

    private static func isInvisible(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09, 0x0A, 0x0D: return false
        case 0x00...0x1F, 0x7F...0x9F: return true   // control characters
        case 0x061C, 0x200E, 0x200F: return true      // direction marks
        case 0x202A...0x202E, 0x2066...0x2069: return true  // direction overrides and isolates
        case 0x200B, 0x2060, 0xFEFF: return true      // zero-width space, word joiner, byte order mark
        default: return false
        }
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "ndash": "–", "mdash": "—", "hellip": "…", "lsquo": "‘", "rsquo": "’",
        "ldquo": "“", "rdquo": "”", "middot": "·", "bull": "•", "copy": "©",
        "reg": "®", "trade": "™", "eacute": "é", "egrave": "è", "aacute": "á",
        "iacute": "í", "oacute": "ó", "uacute": "ú", "ntilde": "ñ", "uuml": "ü",
        "ouml": "ö", "auml": "ä", "ccedil": "ç",
    ]

    /// Some feeds encode their entities twice ("&amp;#160;"), which one pass would leave showing as
    /// "&#160;". A second pass turns those into the characters too.
    static func decodeTwice(_ string: String) -> String {
        let once = decodeEntities(string)
        return once.contains("&") ? decodeEntities(once) : once
    }

    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = ""
        result.reserveCapacity(string.count)
        var index = string.startIndex
        while index < string.endIndex {
            let char = string[index]
            guard char == "&",
                  let semicolon = string[index...].prefix(12).firstIndex(of: ";") else {
                result.append(char)
                index = string.index(after: index)
                continue
            }
            let entity = string[string.index(after: index)..<semicolon]
            if let decoded = decode(entity) {
                result += decoded
                index = string.index(after: semicolon)
            } else {
                result.append(char)
                index = string.index(after: index)
            }
        }
        return result
    }

    private static func decode(_ entity: Substring) -> String? {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            return UInt32(entity.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if entity.hasPrefix("#") {
            return UInt32(entity.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return named[String(entity).lowercased()]
    }
}

/// Dates as feeds write them: RFC 822 for RSS, ISO 8601 for Atom and Dublin Core.
public enum FeedDate {
    public static func parse(_ string: String) -> Date? {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let date = iso8601(value) { return date }
        return rfc822(value)
    }

    // Formatters are costly to create, so they are built once and only read after that.
    nonisolated(unsafe) private static let isoFormatters: [ISO8601DateFormatter] = {
        let options: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate],
        ]
        return options.map { option in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = option
            return formatter
        }
    }()

    private static let rfc822Formatters: [DateFormatter] = [
        "EEE, d MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm zzz",
        "EEE, d MMM yyyy HH:mm Z",
        "d MMM yyyy HH:mm:ss zzz",
        "d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss",
        "EEE, d MMM yy HH:mm:ss zzz",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss",
        // Some sites write "Nov 10, 2026 4:09pm".
        "MMM d, yyyy h:mma",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }

    private static func iso8601(_ value: String) -> Date? {
        for formatter in isoFormatters {
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static func rfc822(_ value: String) -> Date? {
        // Some feeds write "Tues" or "Thurs"; drop the weekday rather than fail.
        let withoutWeekday = value.replacingOccurrences(of: "^[A-Za-z]+,\\s*", with: "", options: .regularExpression)
        for candidate in [value, withoutWeekday] {
            for formatter in rfc822Formatters {
                if let date = formatter.date(from: candidate) { return date }
            }
        }
        return nil
    }
}
