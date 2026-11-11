import Foundation

/// The short words and times the Calendar and To do sections show.
public enum AgendaFormat {
    /// "9:30a" and "2:15p", or "14:15" where the clock is 24-hour.
    public static func shortTime(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = String(format: "%02d", parts.minute ?? 0)
        guard uses12HourClock(locale) else {
            return "\(hour):\(minute)"
        }
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve):\(minute)\(hour < 12 ? "a" : "p")"
    }

    /// What sits in the time column beside an event.
    public static func timeColumn(_ label: EventTimeLabel, calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch label {
        case .allDay: "All day"
        case .starts(let start): shortTime(start, calendar: calendar, locale: locale)
        case .until(let end): "to \(shortTime(end, calendar: calendar, locale: locale))"
        }
    }

    /// "Today", then the weekday's name. The list never reaches a week ahead, so names are enough.
    public static func dayName(_ day: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        var style = Date.FormatStyle.dateTime.weekday(.wide)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return day.formatted(style.locale(locale))
    }

    /// How long an event runs: "45 minutes", "1 hour 30 minutes", "All day" or "3 days".
    public static func length(of entry: CalendarEntry, calendar: Calendar = .current) -> String {
        if entry.isAllDay {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.start), to: calendar.startOfDay(for: entry.end)).day ?? 1
            return days > 1 ? "\(days) days" : "All day"
        }
        let minutes = max(0, Int(entry.end.timeIntervalSince(entry.start) / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
        let minuteText = rest == 1 ? "1 minute" : "\(rest) minutes"
        switch (hours, rest) {
        case (0, _): return minuteText
        case (_, 0): return hourText
        default: return "\(hourText) \(minuteText)"
        }
    }

    /// Up to three names, then how many more: "Sam, Maya, Jordan and 2 others".
    public static func people(_ names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        if names.count <= 3 {
            guard names.count > 1 else { return names[0] }
            return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
        let others = names.count - 3
        return names.prefix(3).joined(separator: ", ") + " and \(others) \(others == 1 ? "other" : "others")"
    }

    /// Hosts of video call links, which are left out of an event's notes.
    static let videoCallHosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "facetime.apple.com", "whereby.com", "gotomeeting.com", "chime.aws"]

    /// An event's place on one line: an address's lines joined with commas. The card cuts it off with "…".
    public static func oneLinePlace(_ location: String?) -> String? {
        guard let location else { return nil }
        let parts = location
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// An event's notes without lines that carry a video call link, or nil when nothing is left.
    public static func notesWithoutCallLinks(_ notes: String?) -> String? {
        guard let notes else { return nil }
        let kept = notes
            .components(separatedBy: .newlines)
            .filter { line in
                let lower = line.lowercased()
                return !videoCallHosts.contains { lower.contains($0) }
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return kept.isEmpty ? nil : kept
    }

    /// When an open to-do from an earlier day was due: "Yesterday", "Fri" up to a week back, then "Nov 2".
    /// Never "overdue".
    public static func earlierDue(_ due: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: calendar.startOfDay(for: now)).day ?? 0
        var style: Date.FormatStyle
        switch days {
        case ...1: return "Yesterday"
        case 2...6: style = .dateTime.weekday(.abbreviated)
        default: style = .dateTime.month(.abbreviated).day()
        }
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return due.formatted(style.locale(locale))
    }

    /// The gray line at the top of an open to-do: "Due today · Family", "Due Fri · Home", or just the list.
    public static func dueLine(for todo: TodoEntry, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let due = todo.due else { return todo.listName }
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: due)
        var when: String
        if day == today {
            when = "Due today"
        } else if day < today {
            when = "Due " + earlierDue(due, now: now, calendar: calendar, locale: locale).lowercasedIfYesterday
        } else {
            when = "Due " + dayName(due, now: now, calendar: calendar, locale: locale)
        }
        if todo.dueIncludesTime {
            when += " at \(shortTime(due, calendar: calendar, locale: locale))"
        }
        return todo.listName.isEmpty ? when : "\(when) · \(todo.listName)"
    }

    private static func uses12HourClock(_ locale: Locale) -> Bool {
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "h a"
        // Quoted text such as German 'Uhr' is a literal, not a field.
        let fields = pattern.split(separator: "'", omittingEmptySubsequences: false)
            .enumerated()
            .filter { $0.offset.isMultiple(of: 2) }
            .map(\.element)
            .joined()
        return fields.contains("a") || fields.contains("h") || fields.contains("K")
    }
}

private extension String {
    var lowercasedIfYesterday: String { self == "Yesterday" ? "yesterday" : self }
}
