import Foundation

/// Fixed sample content for previews and for running the app without any sources set up.
public enum SampleDigest {
    public static func make(now: Date = .now, calendar: Calendar = .current) -> Digest {
        let today = calendar.startOfDay(for: now)
        func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        let weather = WeatherSummary(
            place: "San Francisco",
            temperature: 48,
            condition: "Clear",
            today: WeatherDay(date: today, high: 58, low: 41, condition: "Sunny"),
            restOfWeek: [
                WeatherDay(date: day(1), high: 61, low: 45, condition: "Partly cloudy"),
                WeatherDay(date: day(2), high: 55, low: 43, condition: "Rain in the afternoon"),
                WeatherDay(date: day(3), high: 52, low: 39, condition: "Cloudy"),
            ]
        )

        let events = [
            CalendarEntry(id: "e1", title: "School drop-off", start: at(8, 15), end: at(8, 45), calendarName: "Family"),
            CalendarEntry(id: "e2", title: "Coffee with Priya", start: at(10), end: at(11), calendarName: "Personal", location: "Corner café"),
            CalendarEntry(id: "e3", title: "Soccer practice", start: at(17, 30), end: at(18, 30), calendarName: "Family"),
        ]

        let todos = [
            TodoEntry(id: "t1", title: "Renew car registration", listName: "Personal", due: today),
            TodoEntry(id: "t2", title: "Book dentist appointment", listName: "Personal"),
            TodoEntry(id: "t3", title: "Order birthday present", listName: "Family", due: day(2)),
        ]

        let news = [
            FeedEntry(id: "n1", title: "Hospitals are quietly rebuilding their patient portals", sourceName: "Healthcare Dive", published: at(6, 40), summary: "A look at why health systems are rethinking the front door to care."),
            FeedEntry(id: "n2", title: "What product managers can learn from small teams", sourceName: "Lenny's Newsletter", published: at(5, 55)),
            FeedEntry(id: "n3", title: "On-device models are getting good enough", sourceName: "Simon Willison's Weblog", published: at(22, 10, dayOffset: -1), summary: "Notes from a week of running small models locally."),
        ]

        let episodes = [
            FeedEntry(id: "p1", title: "The future of primary care", sourceName: "Out-Of-Pocket", published: at(4)),
            FeedEntry(id: "p2", title: "Building calm software", sourceName: "Design Details", published: at(21, dayOffset: -1), summary: "Show notes: a conversation about interfaces that respect attention."),
        ]

        return Digest(date: now, weather: weather, events: events, todos: todos, news: news, episodes: episodes)
    }
}
