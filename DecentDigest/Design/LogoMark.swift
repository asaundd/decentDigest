import SwiftUI

/// The Dd logo: a capital D and a lowercase d drawn as seven slightly ragged strokes, from the
/// app icon's source (design/app-icon). Drawn bare, with no tile, in the given color.
/// `progress` below 1 draws only part of it, stroke by stroke, left to right and top to bottom,
/// for the launch animation.
struct LogoMark: View {
    var color: Color = Theme.slate
    var progress: Double = 1
    /// The small-size version, for the Settings button and other marks under about 32pt.
    var small = false

    var body: some View {
        LogoShape(progress: progress, small: small)
            .fill(color)
            .aspectRatio(LogoShape.bounds.width / LogoShape.bounds.height, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// The logo's strokes as one filled outline, so it can be drawn in by animating `progress`.
struct LogoShape: Shape {
    var progress: Double
    /// Five heavier strokes a letter instead of seven: at small sizes the full logo's thin lines and
    /// narrow gaps blur into stripes. Same D and d shapes, same bounds.
    var small = false

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

    /// The small-size version: five rows a letter, each about 40% heavier, with the same slight tilts.
    private static let smallStrokes: [(CGPoint, CGPoint, CGFloat)] = [
        (CGPoint(x: 15.1, y: 26.0), CGPoint(x: 31.8, y: 25.5), 6.6),
        (CGPoint(x: 76.9, y: 26.0), CGPoint(x: 83.6, y: 25.6), 6.4),
        (CGPoint(x: 14.6, y: 38.2), CGPoint(x: 40.9, y: 38.6), 6.5),
        (CGPoint(x: 70.6, y: 38.2), CGPoint(x: 84.3, y: 37.7), 6.4),
        (CGPoint(x: 15.9, y: 50.0), CGPoint(x: 44.0, y: 49.6), 6.7),
        (CGPoint(x: 59.7, y: 50.0), CGPoint(x: 85.3, y: 49.9), 6.5),
        (CGPoint(x: 15.4, y: 61.9), CGPoint(x: 41.6, y: 62.1), 6.4),
        (CGPoint(x: 59.0, y: 61.9), CGPoint(x: 84.4, y: 62.0), 6.6),
        (CGPoint(x: 16.4, y: 74.0), CGPoint(x: 32.9, y: 73.9), 6.5),
        (CGPoint(x: 71.6, y: 74.0), CGPoint(x: 86.1, y: 73.6), 6.7),
    ]

    /// The part of the grid the strokes cover, with room for their round ends.
    static let bounds = CGRect(x: 12, y: 22, width: 77, height: 56)

    private static func length(of strokes: [(CGPoint, CGPoint, CGFloat)]) -> CGFloat {
        strokes.reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

    private static let totalLength = length(of: strokes)
    private static let smallTotalLength = length(of: smallStrokes)

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.bounds.width, rect.height / Self.bounds.height)
        let offset = CGPoint(
            x: rect.minX + (rect.width - Self.bounds.width * scale) / 2,
            y: rect.minY + (rect.height - Self.bounds.height * scale) / 2
        )
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: offset.x + (point.x - Self.bounds.minX) * scale, y: offset.y + (point.y - Self.bounds.minY) * scale)
        }
        let strokes = small ? Self.smallStrokes : Self.strokes
        var remaining = (small ? Self.smallTotalLength : Self.totalLength) * CGFloat(min(max(progress, 0), 1))
        var outline = Path()
        for (start, end, width) in strokes where remaining > 0 {
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

/// The Dd logo in a round glass button pinned at the top right of the digest: clear glass tinted
/// with the page color, so it doesn't lift lighter than the paper, ringed with an even hairline so
/// the edge reads the same all the way round. The small-size logo in the secondary gray, so it reads
/// as Dd at 22pt. Opens Settings. The digest slides it away while the reader scrolls down.
struct SettingsButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            LogoMark(color: Theme.secondary, small: true)
                .frame(width: 22)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // Flat paper: the page's own color, so it covers what scrolls under it, ringed with an
        // even hairline. No glass, whose bent edges read heavier at the sides than top and bottom.
        .background(Circle().fill(Theme.pageTintTop))
        .overlay(Circle().strokeBorder(Theme.rule, lineWidth: 0.5).allowsHitTesting(false))
        .accessibilityLabel("Settings")
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
            LogoMark(color: Theme.secondary, small: true)
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
