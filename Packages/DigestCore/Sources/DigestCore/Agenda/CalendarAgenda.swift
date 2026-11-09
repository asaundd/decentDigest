import Foundation

/// What sits in the time column beside an event.
public enum EventTimeLabel: Sendable, Hashable {
    /// An all-day event, or one that covers the whole day.
    case allDay
    /// Starts at this time on the day shown.
    case starts(Date)
    /// Began on an earlier day and ends at this time on the day shown.
    case until(Date)
}

/// Where an event stands against the clock.
public enum EventTiming: Sendable {
    /// Ended. Shown gray and struck through.
    case past
    /// Happening now. Marked with a thin slate line.
    case now
    case upcoming
}

/// One event as it appears on one day.
public struct AgendaEvent: Sendable, Identifiable, Hashable {
    public var entry: CalendarEntry
    public var label: EventTimeLabel
    /// The day this row is listed under, so an event spanning days has one row per day.
    public var day: Date

    public var id: String { "\(entry.id)#\(Int(day.timeIntervalSince1970))" }
}

/// Rules for the Calendar section: the week ahead as days, today first.
public enum CalendarAgenda {
    /// Today plus the six days after it.
    public static let daysShown = 7

    /// The span to read from Calendar: the start of today to the end of the last day shown.
    public static func fetchRange(now: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: daysShown, to: start) ?? start.addingTimeInterval(Double(daysShown) * 86_400)
        return start...end
    }

    /// Each day of the week ahead with its events, today first, before the list is fit to its limit.
    public static func week(_ events: [CalendarEntry], now: Date, calendar: Calendar = .current) -> [(day: Date, items: [AgendaEvent])] {
        let today = calendar.startOfDay(for: now)
        return (0..<daysShown).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (day: day, items: self.events(on: day, from: events, calendar: calendar))
        }
    }

    /// The days the Calendar section lists: all of today, the next day's first event at least,
    /// then later days up to the limit.
    public static func plan(_ events: [CalendarEntry], now: Date, expanded: Set<Date> = [], showAll: Bool = false, calendar: Calendar = .current) -> [DayGroup<AgendaEvent>] {
        DayPlanner.plan(week(events, now: now, calendar: calendar), expanded: expanded, showAll: showAll)
    }

    /// Whether an event is over, happening, or still to come. All-day events are never over or happening.
    public static func timing(of event: AgendaEvent, now: Date) -> EventTiming {
        guard event.label != .allDay else { return .upcoming }
        if event.entry.end <= now && event.entry.end > event.entry.start { return .past }
        if event.entry.start <= now && now < event.entry.end { return .now }
        return event.entry.start < now ? .past : .upcoming
    }

    /// Every event that touches the day starting at `day`: all-day events first, then by start time.
    public static func events(on day: Date, from events: [CalendarEntry], calendar: Calendar = .current) -> [AgendaEvent] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let listed = events.enumerated().compactMap { index, entry -> (Int, AgendaEvent)? in
            let overlaps = entry.start < dayEnd && (entry.end > dayStart || entry.start >= dayStart)
            guard overlaps else { return nil }
            let label: EventTimeLabel
            if entry.isAllDay {
                label = .allDay
            } else if entry.start < dayStart {
                label = entry.end >= dayEnd ? .allDay : .until(entry.end)
            } else {
                label = .starts(entry.start)
            }
            return (index, AgendaEvent(entry: entry, label: label, day: dayStart))
        }

        return listed.sorted { a, b in
            let (ra, rb) = (rank(a.1.label), rank(b.1.label))
            if ra.group != rb.group { return ra.group < rb.group }
            if ra.time != rb.time { return ra.time < rb.time }
            return a.0 < b.0
        }.map(\.1)
    }

    private static func rank(_ label: EventTimeLabel) -> (group: Int, time: Date) {
        switch label {
        case .allDay: (0, .distantPast)
        case .until(let end): (1, end)
        case .starts(let start): (2, start)
        }
    }
}
