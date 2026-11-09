import Foundation
import Testing
@testable import DigestCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private let us = Locale(identifier: "en_US")

/// Monday Nov 9 2026 at the given hour, UTC, shifted by whole days.
private func at(_ hour: Int, day: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 11, day: 9 + day, hour: hour))!
}

private func day(_ offset: Int, _ high: Double, _ low: Double, _ sky: Sky, _ condition: String = "Cloudy") -> WeatherDay {
    WeatherDay(date: at(0, day: offset), high: high, low: low, condition: condition, sky: sky)
}

private func report(_ today: WeatherDay, _ days: [WeatherDay], now sky: Sky = .cloudy, condition: String = "Cloudy", hours: [WeatherHour] = []) -> WeatherReport {
    WeatherReport(fetchedAt: at(9), temperature: 48, condition: condition, sky: sky, today: today, hours: hours, days: days)
}

private func line(_ report: WeatherReport, unit: TemperatureUnit = .fahrenheit) -> String? {
    WeatherRules.changeLine(report, unit: unit, calendar: utc, locale: us)
}

// MARK: What changes next

@Test func nothingChangingSaysSo() {
    let r = report(day(0, 60, 45, .cloudy), [day(1, 62, 46, .cloudy), day(2, 58, 44, .cloudy)])
    #expect(line(r) == "Tomorrow and Wednesday look about the same.")
}

@Test func laterChangeNamesTheDay() {
    let r = report(day(0, 61, 46, .cloudy), [day(1, 57, 44, .cloudy), day(2, 49, 38, .rain)])
    #expect(line(r) == "Tomorrow is much like today. Rain Wednesday, and colder.")
}

@Test func heatGivesANumberInTheDeviceUnit() {
    let r = report(day(0, 88, 70, .clear), [day(1, 94, 72, .clear), day(2, 93, 73, .clear)])
    #expect(line(r) == "Hot tomorrow and Wednesday, highs near 94°.")
    #expect(line(r, unit: .celsius) == "Hot tomorrow and Wednesday, highs near 34°.")
}

@Test func stormsComeFirst() {
    let r = report(day(0, 77, 60, .cloudy), [day(1, 76, 61, .cloudy), day(2, 65, 55, .storm)])
    #expect(line(r) == "Tomorrow is much like today. Storms likely Wednesday, and colder.")
}

@Test func rainStoppingReadsAsDry() {
    let r = report(day(0, 49, 41, .rain), [day(1, 54, 43, .clear), day(2, 58, 45, .clear)])
    #expect(line(r) == "Dry tomorrow and Wednesday.")
}

@Test func twoDifferentChangesMakeTwoSentences() {
    let r = report(day(0, 60, 50, .clear), [day(1, 60, 50, .rain), day(2, 45, 30, .clear)])
    #expect(line(r) == "Rain tomorrow. Dry Wednesday, with a freeze.")
}

@Test func smallTemperatureChangesDoNotCount() {
    let r = report(day(0, 60, 45, .clear), [day(1, 67, 46, .clear), day(2, 53, 40, .clear)])
    #expect(line(r) == "Tomorrow and Wednesday look about the same.")
}

@Test func noLineWithoutTwoMoreDays() {
    let r = report(day(0, 60, 45, .clear), [day(1, 67, 46, .clear)])
    #expect(line(r) == nil)
}

// MARK: Today

@Test func todaySaysWhenRainStarts() {
    let hours = (0..<24).map { WeatherHour(date: at($0), sky: $0 >= 16 ? .rain : .cloudy) }
    let r = report(day(0, 61, 46, .rain), [], hours: hours)
    #expect(WeatherRules.todayPhrase(r, now: at(9), calendar: utc, locale: us) == "Rain after 4p")
}

@Test func todaySaysWhenRainStops() {
    let hours = (0..<24).map { WeatherHour(date: at($0), sky: $0 < 14 ? .rain : .cloudy) }
    let r = report(day(0, 61, 46, .rain), [], now: .rain, condition: "Rain", hours: hours)
    #expect(WeatherRules.todayPhrase(r, now: at(9), calendar: utc, locale: us) == "Rain until 2p")
}

@Test func rainAllDay() {
    let hours = (0..<24).map { WeatherHour(date: at($0), sky: .rain) }
    let r = report(day(0, 49, 41, .rain), [], now: .rain, condition: "Rain", hours: hours)
    #expect(WeatherRules.todayPhrase(r, now: at(9), calendar: utc, locale: us) == "Rain all day")
}

@Test func dryDayUsesTheConditionNow() {
    let hours = (0..<24).map { WeatherHour(date: at($0), sky: .clear) }
    let r = report(day(0, 68, 51, .clear), [], now: .clear, condition: "Sunny", hours: hours)
    #expect(WeatherRules.todayPhrase(r, now: at(9), calendar: utc, locale: us) == "Sunny")
}

@Test func rainThatAlreadyPassedIsIgnored() {
    let hours = (0..<24).map { WeatherHour(date: at($0), sky: $0 < 6 ? .rain : .clear) }
    let r = report(day(0, 68, 51, .rain), [], now: .clear, condition: "Clear", hours: hours)
    #expect(WeatherRules.todayPhrase(r, now: at(9), calendar: utc, locale: us) == "Clear")
}

// MARK: Formatting

@Test func temperaturesFollowTheUnit() {
    let d = day(0, 61, 46, .cloudy)
    #expect(WeatherRules.highLow(d, unit: .fahrenheit) == "High 61° · Low 46°")
    #expect(WeatherRules.lowToHigh(d, unit: .fahrenheit) == "46–61°")
    #expect(WeatherRules.highLow(d, unit: .celsius) == "High 16° · Low 8°")
    #expect(TemperatureUnit.current(locale: us) == .fahrenheit)
    #expect(TemperatureUnit.current(locale: Locale(identifier: "de_DE")) == .celsius)
}

@Test func conditionsUseSentenceCase() {
    #expect(WeatherRules.sentenceCase("Partly Cloudy") == "Partly cloudy")
    #expect(WeatherRules.sentenceCase("Clear") == "Clear")
}

// MARK: Model

@MainActor
private func model(access: AccessState = .granted) -> (WeatherModel, SamplePlaces) {
    let defaults = UserDefaults(suiteName: "weather-tests-\(UUID().uuidString)")!
    let places = SamplePlaces(access: access)
    return (WeatherModel(provider: SampleWeatherProvider(), places: places, defaults: defaults), places)
}

@MainActor
@Test func weatherLoadsForTheDeviceLocation() async {
    let (weather, _) = model()
    await weather.reload()
    #expect(weather.report != nil)
    #expect(weather.place?.name == "Brooklyn, NY")
    #expect(weather.place?.isCurrentLocation == true)
}

@MainActor
@Test func noLocationAndNoCityMeansNoWeather() async {
    let (weather, _) = model(access: .denied)
    await weather.reload()
    #expect(weather.report == nil)
    #expect(!weather.hasPlaceSource)
}

@MainActor
@Test func aTypedCityIsUsedWithoutLocation() async {
    let (weather, _) = model(access: .denied)
    let found = await weather.setCity("Philadelphia, PA")
    #expect(found)
    #expect(weather.report != nil)
    #expect(weather.place?.name == "Philadelphia, PA")
    #expect(weather.place?.isCurrentLocation == false)
    await weather.clearCity()
    #expect(weather.report == nil)
}
