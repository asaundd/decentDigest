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
            CalendarEntry(id: "e4", title: "Parent-teacher night", start: at(18, 30), end: at(20), calendarName: "Family", calendarID: "family", attendees: ["Ms. Rivera"]),
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

        // Recent real titles from public feeds, with short summaries written for the sample.
        let news = [
            FeedEntry(id: "n1", title: "Scientists debut map of basal ganglia, a key brain region involved in an array of diseases", sourceName: "STAT", published: at(6, 40), summary: "A large research collaboration has produced the most detailed cell map yet of the basal ganglia, a brain region tied to a range of psychiatric and neurological disorders."),
            FeedEntry(id: "n2", title: "Gemini Decisions API", sourceName: "Simon Willison's Weblog", published: at(6, 5), summary: "Notes on Google's new multimodal model for yes-or-no answers, multiple choice and rubric scoring, and how its pricing compares."),
            FeedEntry(id: "n3", title: "Claude Code + Obsidian: My family's AI brain | Scott Farrar", sourceName: "Lenny's Newsletter", published: at(5, 30), summary: "A walkthrough of a household knowledge system built with Claude Code and Obsidian, covering appliances, insurance and the family's to-dos."),
            FeedEntry(id: "n4", title: "The backlash about data centers might really just be about electricity", sourceName: "MIT Technology Review", published: at(21, 15, dayOffset: -1), summary: "Local opposition to new data centers may have less to do with AI itself than with power use and strain on the grid."),
            FeedEntry(id: "n5", title: "Blackstone backs Pfizer's bet on monthly obesity treatment", sourceName: "STAT", published: at(19, 40, dayOffset: -1), summary: "Pfizer is bringing in Blackstone to help fund its push into a once-a-month obesity drug."),
            FeedEntry(id: "n6", title: "aws-emulator", sourceName: "Simon Willison's Weblog", published: at(17, 10, dayOffset: -1), summary: "An official emulator for running tests against local copies of AWS services."),
            FeedEntry(id: "n7", title: "Nvidia privately confirmed it could track chips to fight smuggling, even as industry publicly questioned feasibility", sourceName: "MIT Technology Review", published: at(14, 30, dayOffset: -1), summary: "Chip-location tracking may be more feasible than the industry has said in public."),
        ]

        let episodes = [
            FeedEntry(id: "p1", title: "Open models have real benefits. Do they outweigh the risks?", sourceName: "MIT Technology Review Narrated", published: at(5), summary: "Why the debate over open and closed AI models is more complicated than it seems. Written by Grace Huckins."),
            FeedEntry(id: "p2", title: "Designing for Agents — Zeno Rocha, Resend", sourceName: "Latent Space: The AI Engineer Podcast", published: at(20, dayOffset: -1), summary: "The founder of Resend on optimizing for AI agents as customers, after a coding agent picked Resend on its own to send email."),
            FeedEntry(id: "p3", title: "Why PMs are suddenly valuable again | Tulsee Doshi (Head of Product, Gemini)", sourceName: "Lenny's Podcast", published: at(8, dayOffset: -2), summary: "The head of product for Google's Gemini models on how frontier models get built, what product managers do inside a model lab, and why the role matters more as models improve."),
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
