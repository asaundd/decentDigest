import Foundation

/// The short age under a headline: "4 min", "2 hr", "Yesterday", "3 days".
public enum HeadlineAge {
    public static func text(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        if seconds < 3_600 { return "\(Int(seconds / 60)) min" }
        if calendar.isDate(date, inSameDayAs: now) || seconds < 6 * 3_600 { return "\(Int(seconds / 3_600)) hr" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days <= 1 { return "Yesterday" }
        return "\(days) days"
    }
}
