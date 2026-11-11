import Foundation

/// The titled sections of the digest, in their default order. Weather isn't one: it is the
/// page's opening lines under the date.
public enum DigestSection: String, Codable, Sendable, CaseIterable, Identifiable {
    case calendar, todos, news, podcasts, saved

    public var id: String { rawValue }

    /// Sentence-case title shown above the section.
    public var title: String {
        switch self {
        case .calendar: "Calendar"
        case .todos: "To do"
        case .news: "News"
        case .podcasts: "Podcasts"
        case .saved: "Saved"
        }
    }
}

/// A point on the map, for directions to an event's place.
public struct MapPoint: Sendable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
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
    /// The calendar's identifier, so a calendar the reader left out stays off the page.
    public var calendarID: String
    public var location: String?
    /// Set when the place is an address Maps can route to.
    public var mapPoint: MapPoint?
    /// Invitees' names, leaving out the person using the app.
    public var attendees: [String]
    public var notes: String?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, calendarName: String, calendarID: String = "", location: String? = nil, mapPoint: MapPoint? = nil, attendees: [String] = [], notes: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarName = calendarName
        self.calendarID = calendarID
        self.location = location
        self.mapPoint = mapPoint
        self.attendees = attendees
        self.notes = notes
    }
}

/// A to-do read live from Reminders. Never stored by the app.
public struct TodoEntry: Sendable, Identifiable, Hashable {
    /// The reminder's `calendarItemIdentifier`.
    public var id: String
    public var title: String
    public var listName: String
    /// The Reminders list's identifier, so a list the reader left out stays off the page.
    public var listID: String
    public var due: Date?
    /// False when the reminder has a due day but no time.
    public var dueIncludesTime: Bool
    public var notes: String?
    /// The list's position in Reminders, used to order to-dos with no due date.
    public var listOrder: Int
    public var isCompleted: Bool

    public init(id: String, title: String, listName: String, listID: String = "", due: Date? = nil, dueIncludesTime: Bool = false, notes: String? = nil, listOrder: Int = 0, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.listName = listName
        self.listID = listID
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
    public var weather: WeatherReport?
    public var weatherPlace: WeatherPlace?
    public var events: [CalendarEntry]
    public var todos: [TodoEntry]
    public var news: [FeedEntry]
    public var episodes: [FeedEntry]

    public init(date: Date, sectionOrder: [DigestSection] = DigestSection.allCases, weather: WeatherReport? = nil, weatherPlace: WeatherPlace? = nil, events: [CalendarEntry] = [], todos: [TodoEntry] = [], news: [FeedEntry] = [], episodes: [FeedEntry] = []) {
        self.date = date
        self.sectionOrder = sectionOrder
        self.weather = weather
        self.weatherPlace = weatherPlace
        self.events = events
        self.todos = todos
        self.news = news
        self.episodes = episodes
    }
}
