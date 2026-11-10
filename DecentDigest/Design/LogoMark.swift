import SwiftUI

/// The Dd logo: a capital D and a lowercase d drawn as seven slightly ragged strokes, from the
/// app icon's source (design/app-icon). Drawn bare, with no tile, in the given color.
struct LogoMark: View {
    var color: Color = Theme.accent

    /// Each stroke: start, end and width, in the icon's 100-point grid.
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
    private static let bounds = CGRect(x: 12, y: 22, width: 77, height: 56)

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.bounds.width, size.height / Self.bounds.height)
            let offset = CGPoint(
                x: (size.width - Self.bounds.width * scale) / 2,
                y: (size.height - Self.bounds.height * scale) / 2
            )
            func place(_ point: CGPoint) -> CGPoint {
                CGPoint(x: offset.x + (point.x - Self.bounds.minX) * scale, y: offset.y + (point.y - Self.bounds.minY) * scale)
            }
            for (start, end, width) in Self.strokes {
                var path = Path()
                path.move(to: place(start))
                path.addLine(to: place(end))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width * scale, lineCap: .round))
            }
        }
        .aspectRatio(Self.bounds.width / Self.bounds.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The round see-through button with the Dd logo, pinned at the top right of the digest. Opens Settings.
struct SettingsButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            LogoMark(color: Theme.logoButton)
                .frame(width: 22)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
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
