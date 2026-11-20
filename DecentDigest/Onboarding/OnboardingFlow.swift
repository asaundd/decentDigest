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

/// The first page: the logo, what the app is, and three promises. The words sit at the foot of the
/// page just above Get started, the way Apple's own welcome pages do, and the logo, at the size it
/// draws at launch, sits centered in the space above them, at the left margin.
/// On first launch the logo draws itself at the center as on every launch, then glides into its place
/// at the same size while the words and Get started fade in. With Reduce Motion on, the page just
/// fades in.
struct WelcomePage: View {
    var start: () -> Void

    private enum Intro {
        /// The lines draw in at the center.
        case drawing
        /// The logo glides up to the top of the page.
        case gliding
        case done
    }

    /// The logo's width on the page: the size it draws at launch, so the glide only moves it.
    private static let logoWidth: CGFloat = LaunchLogo.width

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var intro: Intro = LaunchIntro.hasPlayed ? .done : .drawing
    @State private var wordsShown = LaunchIntro.hasPlayed
    @State private var logoProgress: Double = 0
    /// Where the logo on the page sits on screen.
    @State private var logoFrame: CGRect = .zero
    /// The height the page has to fill above Get started.
    @State private var pageHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The logo, centered in the space above the words.
                Spacer(minLength: 32)
                LogoMark()
                    .frame(width: Self.logoWidth)
                    .opacity(intro == .done && wordsShown ? 1 : 0)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { logoFrame = $0 }
                Spacer(minLength: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text("A front page for your day.")
                        .font(Theme.dateFont)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Decent digest brings your weather, calendar, reminders, news, and podcasts together on one page, from the Apple apps you already use.")
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                    SectionRule()
                    // Supporting lines, a step under the sentence above.
                    VStack(alignment: .leading, spacing: 8) {
                        DashLine("No account, no ads, and no tracking.")
                        DashLine("What you follow, save, and read stays on your device and in your own iCloud. It’s never shared with the developer.")
                        DashLine("Each step is optional and can be changed later.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.itemInk)
                }
                .opacity(wordsShown ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: pageHeight, alignment: .leading)
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, Theme.margin)
        }
        // The page fills the screen above Get started, so the words rest just above it; on a small
        // screen or at large text sizes it simply scrolls.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom - Theme.margin
        } action: { _, height in
            pageHeight = max(height, 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Get started", action: start)
                .padding(.horizontal, Theme.margin)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Theme.bottomBarFill)
                .opacity(wordsShown ? 1 : 0)
        }
        .overlay { introLogo }
        .onboardingPage()
        .task { await playIntro() }
    }

    /// The logo while it draws at the center, then glides up into its place.
    @ViewBuilder
    private var introLogo: some View {
        if intro != .done {
            GeometryReader { proxy in
                let page = proxy.frame(in: .global)
                let centered = intro == .drawing
                let width = centered ? LaunchLogo.width : Self.logoWidth
                let position = centered
                    ? CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    : CGPoint(x: logoFrame.midX - page.minX, y: logoFrame.midY - page.minY)
                LogoMark(progress: logoProgress)
                    .frame(width: width)
                    .position(position)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func playIntro() async {
        guard intro != .done else { return }
        LaunchIntro.hasPlayed = true
        if reduceMotion {
            intro = .done
            withAnimation(.easeOut(duration: 0.25)) { wordsShown = true }
            return
        }
        withAnimation(.easeInOut(duration: LaunchLogo.drawDuration)) { logoProgress = 1 }
        try? await Task.sleep(for: .seconds(LaunchLogo.drawDuration))
        withAnimation(.easeInOut(duration: 0.35)) {
            intro = .gliding
            wordsShown = true
        }
        try? await Task.sleep(for: .seconds(0.35))
        intro = .done
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
                message: "The weather won’t show on the digest. You can turn it on later in Settings.",
                confirm: "Skip",
                destructive: false
            ) : nil,
            back: back,
            skip: skip,
            next: next
        ) {
            WeatherPlacePicker(
                model: weather,
                cityNote: "Select a city instead and change it at any time in Settings.",
                inSetup: true
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
                    DashLine("In News and Podcasts, swipe an item left to mark it read, and it’s removed from the list. A short swipe shows Save too, to keep it for later.")
                    DashLine("Any news or podcast item you don’t get to clears after a week to keep the list fresh.")
                }
                Text("Decent digest keeps a private reading history of the news and episodes you open, save, and mark read. It stays on your device and in your own iCloud, and is never shared with the developer. You can turn it off in Settings.")
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
                .background(Theme.bottomBarFill)
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
