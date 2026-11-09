import Foundation

/// The sections of the digest, in their default order.
public enum DigestSection: String, Codable, Sendable, CaseIterable, Identifiable {
    case weather, calendar, todos, news, savedNews, podcasts

    public var id: String { rawValue }

    /// Sentence-case title shown above the section.
    public var title: String {
        switch self {
        case .weather: "Weather"
        case .calendar: "Calendar"
        case .todos: "To-dos"
        case .news: "News"
        case .savedNews: "Saved news"
        case .podcasts: "Podcasts"
        }
    }
}

public struct WeatherDay: Sendable, Identifiable, Hashable {
    public var id: Date { date }
    public var date: Date
    public var high: Int
    public var low: Int
    public var condition: String

    public init(date: Date, high: Int, low: Int, condition: String) {
        self.date = date
        self.high = high
        self.low = low
        self.condition = condition
    }
}

public struct WeatherSummary: Sendable, Hashable {
    public var place: String
    public var temperature: Int
    public var condition: String
    public var today: WeatherDay
    public var restOfWeek: [WeatherDay]

    public init(place: String, temperature: Int, condition: String, today: WeatherDay, restOfWeek: [WeatherDay]) {
        self.place = place
        self.temperature = temperature
        self.condition = condition
        self.today = today
        self.restOfWeek = restOfWeek
    }
}

/// An event read live from Calendar. Never stored by the app.
public struct CalendarEntry: Sendable, Identifiable, Hashable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var calendarName: String
    public var location: String?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, calendarName: String, location: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarName = calendarName
        self.location = location
    }
}

/// A to-do read live from Reminders. Never stored by the app.
public struct TodoEntry: Sendable, Identifiable, Hashable {
    /// The reminder's `calendarItemIdentifier`.
    public var id: String
    public var title: String
    public var listName: String
    public var due: Date?
    /// False when the reminder has a due day but no time.
    public var dueIncludesTime: Bool
    public var notes: String?
    /// The list's position in Reminders, used to order to-dos with no due date.
    public var listOrder: Int
    public var isCompleted: Bool

    public init(id: String, title: String, listName: String, due: Date? = nil, dueIncludesTime: Bool = false, notes: String? = nil, listOrder: Int = 0, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.listName = listName
        self.due = due
        self.dueIncludesTime = dueIncludesTime
        self.notes = notes
        self.listOrder = listOrder
        self.isCompleted = isCompleted
    }
}

/// A news story or podcast episode from a followed feed.
public struct FeedEntry: Sendable, Identifiable, Hashable {
    public var id: String
    public var title: String
    public var sourceName: String
    public var published: Date
    public var link: URL?
    public var summary: String?
    public var status: ItemStatus

    public init(id: String, title: String, sourceName: String, published: Date, link: URL? = nil, summary: String? = nil, status: ItemStatus = .new) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.published = published
        self.link = link
        self.summary = summary
        self.status = status
    }

    /// Items with more than a title open in the in-app panel; title-only items open the source directly.
    public var opensInPanel: Bool {
        guard let summary else { return false }
        return !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Everything one digest screen shows.
public struct Digest: Sendable {
    public var date: Date
    public var sectionOrder: [DigestSection]
    public var weather: WeatherSummary?
    public var events: [CalendarEntry]
    public var todos: [TodoEntry]
    public var news: [FeedEntry]
    public var episodes: [FeedEntry]

    public init(date: Date, sectionOrder: [DigestSection] = DigestSection.allCases, weather: WeatherSummary? = nil, events: [CalendarEntry] = [], todos: [TodoEntry] = [], news: [FeedEntry] = [], episodes: [FeedEntry] = []) {
        self.date = date
        self.sectionOrder = sectionOrder
        self.weather = weather
        self.events = events
        self.todos = todos
        self.news = news
        self.episodes = episodes
    }
}
