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

// MARK: The rest of the week

private func week(_ today: WeatherDay, _ days: [(Double, Sky)]) -> String? {
    let forecast = days.enumerated().map { day($0.offset + 1, $0.element.0, $0.element.0 - 14, $0.element.1) }
    return WeatherRules.weekLine(report(today, forecast), unit: .fahrenheit, calendar: utc, locale: us)
}

@Test func weekLineNamesAStormDay() {
    let line = week(day(0, 60, 46, .cloudy), [(60, .cloudy), (60, .cloudy), (60, .cloudy), (60, .storm), (60, .cloudy), (60, .cloudy)])
    #expect(line == "Storms likely Friday.")
}

@Test func weekLineSumsUpTheWeekend() {
    let line = week(day(0, 60, 46, .cloudy), [(60, .cloudy), (60, .cloudy), (58, .cloudy), (55, .cloudy), (48, .clear), (47, .clear)])
    #expect(line == "Cold and sunny this weekend.")
}

@Test func weekLineSaysWhenRainStartsLater() {
    let line = week(day(0, 60, 46, .clear), [(60, .clear), (60, .clear), (60, .rain), (60, .rain), (60, .cloudy), (60, .cloudy)])
    #expect(line == "Rain Thursday and Friday.")
}

@Test func weekLineNamesRainBeforeTheWeekend() {
    let line = week(day(0, 60, 46, .cloudy), [(60, .cloudy), (60, .cloudy), (60, .rain), (60, .cloudy), (60, .clear), (60, .clear)])
    #expect(line == "Rain Thursday.")
}

@Test func weekLineNamesTemperatureBeforeTheWeekend() {
    let line = week(day(0, 60, 46, .cloudy), [(60, .cloudy), (60, .cloudy), (70, .cloudy), (70, .cloudy), (70, .clear), (70, .clear)])
    #expect(line == "Warmer from Thursday.")
}

@Test func stormsShareTheLineWithOneMore() {
    let line = week(day(0, 60, 46, .cloudy), [(60, .cloudy), (60, .cloudy), (60, .storm), (60, .cloudy), (48, .clear), (47, .clear)])
    #expect(line == "Storms likely Thursday. Cold and sunny this weekend.")
}

@Test func weekLineLeavesRainTheChangeLineCovers() {
    // Rain from Wednesday is already in the two-day line.
    let line = week(day(0, 60, 46, .clear), [(60, .clear), (60, .rain), (60, .rain), (60, .rain), (60, .cloudy), (60, .cloudy)])
    #expect(line == nil)
}

@Test func weekLineNamesATurnInTemperature() {
    let line = week(day(0, 60, 46, .cloudy), [(61, .cloudy), (62, .cloudy), (70, .cloudy), (70, .cloudy), (62, .cloudy), (62, .cloudy)])
    #expect(line == "Warmer from Thursday.")
}

@Test func quietWeekHasNoWeekLine() {
    let line = week(day(0, 60, 46, .cloudy), [(60, .cloudy), (61, .cloudy), (59, .cloudy), (60, .cloudy), (62, .cloudy), (58, .cloudy)])
    #expect(line == nil)
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

private struct CreditedWeather: WeatherProvider {
    func report(latitude: Double, longitude: Double, now: Date) async throws -> WeatherReport {
        SampleDigest.weather(now: now)
    }

    func credit() async -> WeatherCredit? {
        let url = URL(string: "https://example.com")!
        return WeatherCredit(markLight: url, markDark: url, legalPage: url)
    }
}

@MainActor
@Test func cachedForecastStillGetsTheCredit() async {
    let defaults = UserDefaults(suiteName: "weather-tests-\(UUID().uuidString)")!
    let places = SamplePlaces()
    let first = WeatherModel(provider: CreditedWeather(), places: places, defaults: defaults)
    await first.reload()
    #expect(first.credit != nil)
    // A new launch opens with the cached forecast and doesn't fetch again, but shows the credit.
    let next = WeatherModel(provider: CreditedWeather(), places: places, defaults: defaults)
    #expect(next.report != nil)
    await next.reload()
    #expect(next.credit != nil)
}
