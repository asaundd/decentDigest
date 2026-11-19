import Foundation

/// Fixed sample content for previews and for running the app without any sources set up.
public enum SampleDigest {
    public static func make(now: Date = AppClock.now, calendar: Calendar = .current) -> Digest {
        let today = calendar.startOfDay(for: now)
        func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        // Today and tomorrow only, so the week's forecast, the calendar and the first to-dos all
        // fit on one screen with the week open.
        let events = [
            CalendarEntry(id: "e1", title: "Run with Alex", start: at(7), end: at(7, 45), calendarName: "Personal", calendarID: "personal", location: "Prospect Park"),
            CalendarEntry(id: "e2", title: "Coffee with Priya", start: at(9, 30), end: at(10, 15), calendarName: "Personal", calendarID: "personal", location: "Corner café"),
            CalendarEntry(id: "e3", title: "Piano lesson", start: at(16), end: at(16, 45), calendarName: "Family", calendarID: "family", location: "Music school, room 2", notes: "Maya is practicing the Clementi sonatina this week."),
            CalendarEntry(id: "e4", title: "Dentist", start: at(9, dayOffset: 1), end: at(9, 45, dayOffset: 1), calendarName: "Family", calendarID: "family"),
            CalendarEntry(id: "e5", title: "Book club", start: at(19, dayOffset: 1), end: at(20, 30, dayOffset: 1), calendarName: "Personal", calendarID: "personal", attendees: ["Sam Rivera", "Dana Brooks"]),
        ]

        let todos = [
            TodoEntry(id: "t1", title: "Renew library books", listName: "Personal", listID: "personal", due: today, notes: "Three are due Thursday. The branch on 7th Avenue opens at 10."),
            TodoEntry(id: "t2", title: "Send thank-you note to Dana", listName: "Personal", listID: "personal", due: at(17), dueIncludesTime: true),
            TodoEntry(id: "t3", title: "Pay the water bill", listName: "Home", listID: "home", due: day(1)),
            TodoEntry(id: "t4", title: "Pick up dry cleaning", listName: "Personal", listID: "personal", due: day(2)),
            TodoEntry(id: "t5", title: "Plan dinner for Grandma’s visit", listName: "Family", listID: "family", listOrder: 0),
            TodoEntry(id: "t6", title: "Find snow boots for Maya", listName: "Family", listID: "family", listOrder: 1),
            TodoEntry(id: "t7", title: "Buy a birthday card for Mom", listName: "Family", listID: "family", listOrder: 2),
        ]

        // Real titles from public feeds (one shortened), picked to stay timely for a while, with short summaries
        // written for the sample.
        let news = [
            FeedEntry(id: "n1", title: "Practice Mindfulness with Roeselien Raimond’s Portraits of Relaxed Winter Foxes", sourceName: "Colossal", published: at(7, 15), summary: "Portraits of wild foxes resting in the winter sun, and a reminder that the cold months hold plenty of life and beauty."),
            FeedEntry(id: "n2", title: "The Evolving Story of How Chemistry Became Biology", sourceName: "Quanta Magazine", published: at(6, 30), summary: "After decades of arguing over which molecules came first, a new generation of scientists is rethinking what life was, is and could be."),
            FeedEntry(id: "n3", title: "Procrastinating Your Winter Runs? Here’s What Will Actually Get You Out the Door", sourceName: "Runner’s World", published: at(5, 45), summary: "A sports psychologist on which strategies work on cold, dark mornings, and which ones backfire."),
            FeedEntry(id: "n4", title: "Kale Pesto Pasta", sourceName: "RecipeTin Eats", published: at(20, dayOffset: -1), summary: "Garlic, lemon and parmesan make a pesto that’s faster than basil and stays bright green for days."),
            FeedEntry(id: "n5", title: "The Country’s Oldest Operating Lighthouse Still Shines on New York Harbor", sourceName: "Smithsonian Magazine", published: at(18, 30, dayOffset: -1), summary: "The Sandy Hook lighthouse in New Jersey predates the American Revolution, and it still lights the way into the harbor."),
            FeedEntry(id: "n6", title: "Woodcocks and Snipes: The Quintessential Odd Birds", sourceName: "Nautilus", published: at(15, dayOffset: -1), summary: "Why these long-billed shorebirds are so unusual, and how life on islands may have made them odder still."),
            FeedEntry(id: "n7", title: "Gegenschein is the elusive glow of interplanetary dust", sourceName: "EarthSky", published: at(11, dayOffset: -1), summary: "A faint glow opposite the sun, from sunlight on dust in space, and how to see it."),
        ]

        let episodes = [
            FeedEntry(id: "p1", title: "100 Objects #19: Western Electric 500 Series", sourceName: "99% Invisible", published: at(5), summary: "For more than 50 years this was the telephone in homes and offices everywhere. How it became the default."),
            FeedEntry(id: "p2", title: "790: An Hour With Dorie Greenspan", sourceName: "The Splendid Table", published: at(18, dayOffset: -1), summary: "The cookbook author on her start in food, her early love of project baking, and becoming the writer readers know today."),
            FeedEntry(id: "p3", title: "Do You Have Trouble Sleeping?", sourceName: "Hidden Brain", published: at(8, dayOffset: -2), summary: "A sleep researcher on how short nights change the way we decide and even what we value, and what helps."),
        ]

        return Digest(date: now, weather: weather(now: now, calendar: calendar), weatherPlace: weatherPlace, events: events, todos: todos, news: news, episodes: episodes)
    }

    /// Where the sample weather is for.
    public static let weatherPlace = WeatherPlace(name: "Brooklyn, NY", latitude: 40.68, longitude: -73.94, isCurrentLocation: true)

    /// A fixed winter forecast: snow late today, a steady few days, then snow over the weekend.
    public static func weather(now: Date = AppClock.now, calendar: Calendar = .current) -> WeatherReport {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        let hours = (0..<24).map { hour in
            WeatherHour(date: calendar.date(byAdding: .hour, value: hour, to: today) ?? today, sky: hour >= 16 ? .snow : .cloudy)
        }
        return WeatherReport(
            fetchedAt: now,
            temperature: 31,
            condition: "Cloudy",
            sky: .cloudy,
            today: WeatherDay(date: today, high: 38, low: 27, condition: "Cloudy", sky: .cloudy),
            hours: hours,
            days: [
                WeatherDay(date: day(1), high: 37, low: 26, condition: "Cloudy", sky: .cloudy),
                WeatherDay(date: day(2), high: 39, low: 28, condition: "Partly cloudy", sky: .cloudy),
                WeatherDay(date: day(3), high: 36, low: 27, condition: "Clear", sky: .clear),
                WeatherDay(date: day(4), high: 33, low: 24, condition: "Snow", sky: .snow),
                WeatherDay(date: day(5), high: 31, low: 22, condition: "Snow", sky: .snow),
                WeatherDay(date: day(6), high: 35, low: 25, condition: "Clear", sky: .clear),
            ]
        )
    }
}
