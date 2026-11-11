import DigestCore
import SwiftUI

/// Setup, shown on first launch: a welcome page, four optional steps in the order of the page
/// (weather, calendar and to-dos, news, podcasts), then a short page on how the digest works.
/// Each step can be skipped; a skipped step leaves its section off the page.
struct OnboardingFlow: View {
    static let stepCount = 4

    var agenda: AgendaModel
    var weather: WeatherModel
    var preferences: DigestPreferences
    /// Called from the last page, once setup is saved.
    var finish: () -> Void

    @State private var path: [Page] = []

    enum Page: Hashable {
        case weather, calendar, news, podcasts, ready
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomePage { path.append(.weather) }
                .navigationDestination(for: Page.self) { page in
                    destination(page)
                }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private func destination(_ page: Page) -> some View {
        switch page {
        case .weather:
            WeatherStep(
                weather: weather,
                back: back,
                skip: { decide(.weather, shown: false, then: .calendar) },
                next: { decide(.weather, shown: true, then: .calendar) }
            )
        case .calendar:
            CalendarStep(
                agenda: agenda,
                back: back,
                skip: {
                    preferences.setShown(false, .calendar)
                    preferences.setShown(false, .todos)
                    path.append(.news)
                },
                next: {
                    preferences.setShown(agenda.calendarAccess == .granted, .calendar)
                    preferences.setShown(agenda.remindersAccess == .granted, .todos)
                    path.append(.news)
                }
            )
        case .news:
            NewsStep(
                back: back,
                skip: { decide(.news, shown: false, then: .podcasts) },
                next: { decide(.news, shown: true, then: .podcasts) }
            )
        case .podcasts:
            PodcastsStep(
                back: back,
                skip: { decide(.podcasts, shown: false, then: .ready) },
                next: { decide(.podcasts, shown: true, then: .ready) }
            )
        case .ready:
            ReadyPage(back: back) {
                preferences.finishSetup()
                finish()
            }
        }
    }

    private func decide(_ section: DigestPreferences.Section, shown: Bool, then next: Page) {
        preferences.setShown(shown, section)
        path.append(next)
    }

    private func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

/// The first page: the logo, the name, what the app is, and three promises.
struct WelcomePage: View {
    var start: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LogoMark()
                    .frame(width: 64)
                    .padding(.top, 48)
                Text("Decent digest")
                    .font(Theme.wordmarkFont)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 20)
                Text("Your personal digest starts here.")
                    .font(Theme.dateFont)
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                Text("Decent digest can show your weather, calendar, reminders, news, and more from the Apple apps you already use, all in one clean view.")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                SectionRule()
                VStack(alignment: .leading, spacing: 8) {
                    DashLine("No account, no ads, and no tracking.")
                    DashLine("What you follow, save, and read stays on your device and in your own iCloud. It's never shared with developers.")
                    DashLine("Each step is optional and can be changed later.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, Theme.margin)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Get started", action: start)
                .padding(.horizontal, Theme.margin)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Theme.page)
        }
        .onboardingPage()
    }
}

/// Step 1: where the forecast is for.
struct WeatherStep: View {
    var weather: WeatherModel
    var back: () -> Void
    var skip: () -> Void
    var next: () -> Void

    var body: some View {
        OnboardingStep(
            number: 1,
            title: "Weather",
            intro: "Show the forecast for where you are, or for a city you choose.",
            note: WeatherCopy.locationNote,
            canContinue: weather.hasPlaceSource,
            skipQuestion: weather.hasPlaceSource ? SkipQuestion(
                title: "Skip Weather?",
                message: "The weather won't show on the digest. You can turn it on later in Settings.",
                confirm: "Skip",
                destructive: false
            ) : nil,
            back: back,
            skip: skip,
            next: next
        ) {
            WeatherPlacePicker(
                model: weather,
                cityNote: "Select a city instead and change it at any time in Settings."
            )
        }
    }
}

/// The last page: where Settings is, then how the digest works in five short lines.
struct ReadyPage: View {
    var back: () -> Void
    var open: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BackLink(action: back)
                    .padding(.top, 12)
                LogoMark()
                    .frame(width: 64)
                    .padding(.top, 24)
                Text("Decent digest")
                    .font(Theme.wordmarkFont)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 20)
                Text("Your digest is ready.")
                    .font(Theme.dateFont)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 6)
                settingsLine
                    .padding(.top, 12)
                SectionRule()
                VStack(alignment: .leading, spacing: 8) {
                    DashLine("Tap an item to see more. Tap it again to close it.")
                    DashLine("Swipe a to-do right, or open it and tap ✓, to mark it done in Reminders.")
                    DashLine("Tap ↗ to open the app or website an item came from.")
                    DashLine("In News and Podcasts, swipe right if relevant or left if not to remove it from the list. To keep it for later, save it with the bookmark.")
                    DashLine("Any news or podcast item you don't get to clears after a week to keep the list fresh.")
                }
                Text("Decent digest keeps a private reading history of the news and episodes you open, save, and mark relevant or not relevant. It stays on your device and in your own iCloud, and is never shared with developers. You can turn it off in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, Theme.margin)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Open my digest", action: open)
                .padding(.horizontal, Theme.margin)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Theme.page)
        }
        .onboardingPage()
    }

    /// "Tap [the round Dd logo] in the app to change your settings at any time.", with the logo
    /// centered on the line of text.
    private var settingsLine: some View {
        let logo = Text(InlineLogo.image(size: logoSize, scale: displayScale, colorScheme: colorScheme))
            .baselineOffset(-logoSize * 0.28)
        return Text("Tap \(logo) in the app to change your settings at any time.")
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Tap the round logo button at the top right of your digest to change your settings at any time.")
    }
}
