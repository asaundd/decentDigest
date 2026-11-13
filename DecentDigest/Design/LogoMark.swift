import SwiftUI

/// The Dd logo: a capital D and a lowercase d drawn as seven slightly ragged strokes, from the
/// app icon's source (design/app-icon). Drawn bare, with no tile, in the given color.
/// `progress` below 1 draws only part of it, stroke by stroke, left to right and top to bottom,
/// for the launch animation.
struct LogoMark: View {
    var color: Color = Theme.slate
    var progress: Double = 1

    var body: some View {
        LogoShape(progress: progress)
            .fill(color)
            .aspectRatio(LogoShape.bounds.width / LogoShape.bounds.height, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// The logo's strokes as one filled outline, so it can be drawn in by animating `progress`.
struct LogoShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Each stroke: start, end and width, in the icon's 100-point grid, in reading order.
    private static let strokes: [(CGPoint, CGPoint, CGFloat)] = [
        (CGPoint(x: 15.08, y: 26.15), CGPoint(x: 31.80, y: 25.49), 4.78),
        (CGPoint(x: 77.42, y: 26.01), CGPoint(x: 82.38, y: 25.44), 4.69),
        (CGPoint(x: 14.47, y: 33.92), CGPoint(x: 39.73, y: 34.39), 4.43),
        (CGPoint(x: 77.08, y: 34.45), CGPoint(x: 85.11, y: 34.09), 4.66),
        (CGPoint(x: 16.64, y: 42.36), CGPoint(x: 41.69, y: 41.75), 4.44),
        (CGPoint(x: 71.10, y: 42.32), CGPoint(x: 83.58, y: 41.62), 4.82),
        (CGPoint(x: 15.83, y: 50.05), CGPoint(x: 43.89, y: 49.48), 4.37),
        (CGPoint(x: 59.61, y: 49.93), CGPoint(x: 85.37, y: 49.78), 4.83),
        (CGPoint(x: 15.39, y: 58.29), CGPoint(x: 42.91, y: 58.24), 4.53),
        (CGPoint(x: 58.68, y: 58.38), CGPoint(x: 84.62, y: 58.28), 4.57),
        (CGPoint(x: 16.65, y: 65.92), CGPoint(x: 39.86, y: 66.31), 4.45),
        (CGPoint(x: 60.28, y: 66.17), CGPoint(x: 82.29, y: 66.32), 4.82),
        (CGPoint(x: 16.40, y: 74.20), CGPoint(x: 32.59, y: 74.11), 4.82),
        (CGPoint(x: 71.91, y: 74.44), CGPoint(x: 86.13, y: 73.97), 4.89),
    ]

    /// The part of the grid the strokes cover, with room for their round ends.
    static let bounds = CGRect(x: 12, y: 22, width: 77, height: 56)

    private static let totalLength: CGFloat = strokes.reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.bounds.width, rect.height / Self.bounds.height)
        let offset = CGPoint(
            x: rect.minX + (rect.width - Self.bounds.width * scale) / 2,
            y: rect.minY + (rect.height - Self.bounds.height * scale) / 2
        )
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: offset.x + (point.x - Self.bounds.minX) * scale, y: offset.y + (point.y - Self.bounds.minY) * scale)
        }
        var remaining = Self.totalLength * CGFloat(min(max(progress, 0), 1))
        var outline = Path()
        for (start, end, width) in Self.strokes where remaining > 0 {
            let length = hypot(end.x - start.x, end.y - start.y)
            let drawn = min(length, remaining)
            remaining -= drawn
            let fraction = length > 0 ? drawn / length : 1
            let tip = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
            var line = Path()
            line.move(to: place(start))
            line.addLine(to: place(tip))
            outline.addPath(line.strokedPath(StrokeStyle(lineWidth: width * scale, lineCap: .round)))
        }
        return outline
    }
}

/// The launch animation: after iOS's plain paper launch screen, the logo draws itself at the center of
/// the page, its slate lines left to right and top to bottom, in the same hand as the strike.
struct LaunchLogo: View {
    /// How long the lines take to draw.
    static let drawDuration: Double = 0.5
    /// The logo's width at the center of the page.
    static let width: CGFloat = 88

    var progress: Double

    var body: some View {
        LogoMark(progress: progress)
            .frame(width: Self.width)
            .accessibilityHidden(true)
    }
}

/// Whether the launch animation has played in this run of the app. It plays once, on a cold launch,
/// never when the reader comes back from another app.
@MainActor
enum LaunchIntro {
    static var hasPlayed = false
}

/// The Dd logo button pinned at the top right of the digest: today a round see-through button; debug
/// builds can try other looks in the Design lab. Opens Settings.
struct SettingsButton: View {
    var action: () -> Void

    var body: some View {
        let style = DesignLab.shared.button
        Button(action: action) {
            mark(style)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(ButtonBackground(style: style))
        .accessibilityLabel("Settings")
    }

    @ViewBuilder
    private func mark(_ style: DesignLab.ButtonStyle) -> some View {
        switch style {
        case .glass, .paperGlass:
            LogoMark(color: Theme.logoButton).frame(width: 22)
        case .shadow:
            // Just the logo, lifted off the page by a soft shadow under its lines.
            LogoMark(color: Theme.logoButton)
                .frame(width: 26)
                .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
        case .halo:
            // Just the logo, with the page color fading out around it.
            LogoMark(color: Theme.logoButton)
                .frame(width: 26)
                .background(
                    RadialGradient(colors: [Theme.page, Theme.page.opacity(0.9), Theme.page.opacity(0)], center: .center, startRadius: 0, endRadius: 30)
                        .frame(width: 60, height: 60)
                )
        case .disc, .frostedDisc:
            LogoMark(color: Theme.logoButton).frame(width: 20)
        case .closeCircle:
            // The same gray circle as Settings' ✕.
            LogoMark(color: Theme.secondary)
                .frame(width: 18)
                .frame(width: 36, height: 36)
                .background(Theme.fieldFill, in: Circle())
        }
    }
}

/// Clear glass for today's button, a flat paper disc for D, nothing for the floating logos.
private struct ButtonBackground: ViewModifier {
    var style: DesignLab.ButtonStyle

    func body(content: Content) -> some View {
        switch style {
        case .glass:
            // Clear glass, so the page shows through more than the regular kind.
            content.glassEffect(.clear.interactive(), in: .circle)
        case .disc:
            content
                .background(Theme.page, in: Circle())
                .overlay(Circle().strokeBorder(Theme.rule, lineWidth: 1))
        case .paperGlass:
            // Today's clear glass, tinted with the page color so it doesn't lift lighter than the
            // paper, and ringed with an even hairline so the edge reads the same all the way round.
            content
                .glassEffect(.clear.tint(Theme.page.opacity(0.55)).interactive(), in: .circle)
                .overlay(Circle().strokeBorder(Theme.rule, lineWidth: 0.5).allowsHitTesting(false))
        case .frostedDisc:
            // The flat disc, but see-through: words passing under it blur softly, tinted with the page.
            content
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Theme.page.opacity(0.45)))
                }
                .overlay(Circle().strokeBorder(Theme.rule, lineWidth: 1))
        case .shadow, .halo, .closeCircle:
            content
        }
    }
}

/// The small round logo used inside a line of text ("Tap [Dd] in the app…"), drawn as an image
/// so it sits in the text and wraps with it.
@MainActor
enum InlineLogo {
    static func image(size: CGFloat, scale: CGFloat, colorScheme: ColorScheme) -> Image {
        let badge = ZStack {
            Circle()
                .fill(Theme.ribbonButtonFill)
            Circle()
                .strokeBorder(Theme.rule, lineWidth: 0.5)
            LogoMark(color: Theme.logoButton)
                .frame(width: size * 0.52)
        }
        .frame(width: size, height: size)
        .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: badge)
        renderer.scale = scale
        guard let image = renderer.uiImage else { return Image(systemName: "circle") }
        return Image(uiImage: image)
    }
}

#Preview {
    VStack(spacing: 24) {
        LogoMark().frame(width: 72)
        SettingsButton {}
    }
    .padding()
    .background(Theme.page)
}
