import Foundation

/// Rules for the Podcasts list. Episodes follow News's timing: they leave 7 days after they came out,
/// and one never touched is noted as ignored.
public enum PodcastRules {
    /// Episodes shown before "N more · Show all".
    public static let itemsShown = NewsRules.itemsShown

    /// For a show's first fetch: where its history starts. Many shows post weekly, so a newly followed
    /// show brings in its newest episode from the last 7 days (and nothing older). With no episode
    /// that recent, only episodes from now on come in.
    public static func backfillCutoff(publishedDates: [Date], now: Date, calendar: Calendar = .current) -> Date {
        let window = NewsRules.expiryCutoff(now: now, calendar: calendar)
        guard let newest = publishedDates.filter({ $0 <= now }).max(), newest >= window else { return now }
        return newest
    }

    /// Reads `<itunes:duration>`: seconds ("3723"), "MM:SS" or "HH:MM:SS".
    public static func durationSeconds(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        var total = 0
        for part in parts {
            guard let value = Double(part), value >= 0 else { return nil }
            total = total * 60 + Int(value)
        }
        return total > 0 ? total : nil
    }

    /// An episode's length for its open card: "58 min", "1 hr 12 min", "2 hr".
    public static func length(seconds: Int) -> String {
        let minutes = max(1, Int((Double(seconds) / 60).rounded()))
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(rest) min"
        }
    }
}
