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

        let events = [
            CalendarEntry(id: "e1", title: "Coffee with Priya", start: at(9, 30), end: at(10, 15), calendarName: "Personal", calendarID: "personal", location: "Corner café"),
            CalendarEntry(id: "e2", title: "Design review with Sam", start: at(13), end: at(14), calendarName: "Personal", calendarID: "personal", attendees: ["Sam Rivera"], notes: "Bring the floor plan sketches.\nhttps://zoom.us/j/123456"),
            CalendarEntry(id: "e3", title: "Soccer pickup", start: at(16, 30), end: at(17), calendarName: "Family", calendarID: "family", location: "Lincoln Park, field 3", mapPoint: MapPoint(latitude: 37.78, longitude: -122.50), notes: "Maya has the orange slices this week. Practice can run late if it rains, so check the team chat before leaving."),
            CalendarEntry(id: "e4", title: "Family dinner", start: at(18, 30), end: at(20), calendarName: "Family", calendarID: "family", attendees: ["Maya", "Leo", "Grandma", "Uncle Ben"]),
            CalendarEntry(id: "e5", title: "Run with Alex", start: at(8, dayOffset: 1), end: at(9, dayOffset: 1), calendarName: "Personal", calendarID: "personal"),
            CalendarEntry(id: "e6", title: "School pickup", start: at(15, 15, dayOffset: 1), end: at(15, 45, dayOffset: 1), calendarName: "Family", calendarID: "family"),
            CalendarEntry(id: "e7", title: "Call with the contractor", start: at(11, dayOffset: 2), end: at(11, 30, dayOffset: 2), calendarName: "Personal", calendarID: "personal"),
            CalendarEntry(id: "e8", title: "Book club", start: at(17, dayOffset: 2), end: at(18, 30, dayOffset: 2), calendarName: "Personal", calendarID: "personal"),
            CalendarEntry(id: "e9", title: "Grandma visiting", start: day(3), end: day(4), isAllDay: true, calendarName: "Family", calendarID: "family"),
            CalendarEntry(id: "e10", title: "Dentist", start: at(8, 30, dayOffset: 3), end: at(9, 15, dayOffset: 3), calendarName: "Family", calendarID: "family"),
            CalendarEntry(id: "e11", title: "Piano lesson", start: at(16, dayOffset: 3), end: at(16, 45, dayOffset: 3), calendarName: "Family", calendarID: "family"),
            CalendarEntry(id: "e12", title: "Date night", start: at(19, dayOffset: 4), end: at(21, dayOffset: 4), calendarName: "Personal", calendarID: "personal"),
        ]

        let todos = [
            TodoEntry(id: "t1", title: "Call the pharmacy about the refill", listName: "Personal", listID: "personal", due: day(-1)),
            TodoEntry(id: "t2", title: "Book dentist for the kids", listName: "Family", listID: "family", due: today, notes: "Ask about the Saturday slot. Dr. Patel's office opens at 8, and the kids are free after 10."),
            TodoEntry(id: "t3", title: "Send thank-you note to Dana", listName: "Personal", listID: "personal", due: at(17), dueIncludesTime: true),
            TodoEntry(id: "t4", title: "Pay the water bill", listName: "Home", listID: "home", due: day(1)),
            TodoEntry(id: "t5", title: "Pick up dry cleaning", listName: "Personal", listID: "personal", due: day(2)),
            TodoEntry(id: "t6", title: "Look into bike repair shops", listName: "Personal", listID: "personal", listOrder: 0),
            TodoEntry(id: "t7", title: "Plan dinner for Grandma's visit", listName: "Family", listID: "family", listOrder: 1),
            TodoEntry(id: "t8", title: "Buy a birthday card for Mom", listName: "Family", listID: "family", listOrder: 1),
        ]

        let news = [
            FeedEntry(id: "n1", title: "Why city trees are getting smarter about water", sourceName: "Field Notes", published: at(6, 40), summary: "Street trees are being planted with sensors and deeper soil pits, and the early results suggest they need far less watering than anyone expected."),
            FeedEntry(id: "n2", title: "The case for a shorter grocery list", sourceName: "Kitchen Table", published: at(6, 5), summary: "Cooking from a handful of staples is cheaper, calmer and wastes less food. Here is how one family made the switch without…"),
            FeedEntry(id: "n3", title: "Libraries are lending more than books now", sourceName: "Civic Weekly", published: at(5, 30)),
            FeedEntry(id: "n4", title: "A beginner's guide to reading the night sky", sourceName: "Starlight Notes", published: at(21, 15, dayOffset: -1), summary: "Five constellations you can find from a city balcony this month."),
            FeedEntry(id: "n5", title: "What a year of walking to work taught me", sourceName: "The Slow Web", published: at(19, 40, dayOffset: -1), summary: "Forty minutes each way, in every kind of weather."),
            FeedEntry(id: "n6", title: "How small towns are reviving their main streets", sourceName: "Civic Weekly", published: at(17, 10, dayOffset: -1), summary: "Pop-up shops, shared kitchens and a lot of patience."),
            FeedEntry(id: "n7", title: "Notes on keeping a paper notebook", sourceName: "The Slow Web", published: at(14, 30, dayOffset: -1), summary: "Why writing things down by hand still helps."),
        ]

        let episodes = [
            FeedEntry(id: "p1", title: "The science of a good night's sleep", sourceName: "Everyday Science", published: at(4), summary: "What actually happens while we sleep, why the hour before bed matters more than the hour we wake, and three small changes researchers say are worth trying this week."),
            FeedEntry(id: "p2", title: "Starting a garden from scratch", sourceName: "Back Yard Hours", published: at(21, dayOffset: -1), summary: "Soil, sun and patience: a first season, start to finish."),
            FeedEntry(id: "p3", title: "The quiet history of the public library", sourceName: "Long Story Short", published: at(9, dayOffset: -2), summary: "How lending libraries spread, one town at a time."),
        ]

        return Digest(date: now, weather: weather(now: now, calendar: calendar), weatherPlace: weatherPlace, events: events, todos: todos, news: news, episodes: episodes)
    }

    /// Where the sample weather is for.
    public static let weatherPlace = WeatherPlace(name: "Brooklyn, NY", latitude: 40.68, longitude: -73.94, isCurrentLocation: true)

    /// A fixed forecast: rain this afternoon, then colder with rain from the day after tomorrow.
    public static func weather(now: Date = .now, calendar: Calendar = .current) -> WeatherReport {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        let hours = (0..<24).map { hour in
            WeatherHour(date: calendar.date(byAdding: .hour, value: hour, to: today) ?? today, sky: hour >= 16 ? .rain : .cloudy)
        }
        return WeatherReport(
            fetchedAt: now,
            temperature: 48,
            condition: "Cloudy",
            sky: .cloudy,
            today: WeatherDay(date: today, high: 61, low: 46, condition: "Cloudy", sky: .cloudy),
            hours: hours,
            days: [
                WeatherDay(date: day(1), high: 57, low: 44, condition: "Cloudy", sky: .cloudy),
                WeatherDay(date: day(2), high: 49, low: 38, condition: "Rain", sky: .rain),
                WeatherDay(date: day(3), high: 48, low: 36, condition: "Cloudy", sky: .cloudy),
                WeatherDay(date: day(4), high: 47, low: 34, condition: "Clear", sky: .clear),
                WeatherDay(date: day(5), high: 50, low: 37, condition: "Clear", sky: .clear),
                WeatherDay(date: day(6), high: 52, low: 40, condition: "Showers", sky: .rain),
            ]
        )
    }
}
