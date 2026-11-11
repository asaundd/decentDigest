import SwiftUI
import UIKit

extension View {
    /// Swipe right to check a to-do off. The system swipe actions draw buttons, so this is drawn by
    /// hand: the symbol and a small gray word on the page, pinned to the edge the row is leaving,
    /// while a strike draws across the title. Letting go past the threshold, where the strike is
    /// complete, checks it off. There is no left swipe.
    func checkOffSwipe(_ action: @escaping () -> Void) -> some View {
        modifier(JudgmentSwipe(
            leading: SwipeAction(symbol: "checkmark", label: "Done", action: action),
            trailing: nil
        ))
    }
}

/// What a swipe in one direction shows and does.
struct SwipeAction {
    var symbol: String
    var label: String
    var action: () -> Void
}

/// Remembers when a row last moved sideways, so a swipe that is let go near where it began
/// isn't taken as a tap, and whether a row rests open on its actions.
/// Gestures and taps both run on the main thread.
final class SwipeGuard: @unchecked Sendable {
    /// A finger that moves less than this sideways is tapping, not swiping.
    static let tapTolerance: CGFloat = 10

    var lastMove = Date.distantPast
    /// True while a short swipe has left the row open on its actions.
    var restsOpen = false
    /// Slides an open row back.
    var closeStrip: (() -> Void)?

    /// True right after a swipe, when the finger lifting would otherwise count as a tap.
    var justSwiped: Bool { Date.now.timeIntervalSince(lastMove) < 0.4 }

    /// Call first when a row is tapped. True when the tap is used up: it ended a swipe, or it
    /// closed a row resting open on its actions.
    func takesTap() -> Bool {
        if justSwiped { return true }
        if restsOpen {
            closeStrip?()
            return true
        }
        return false
    }
}

/// Lets a closing row ask the digest to hold its scroll position for a moment.
/// Taps and layout both run on the main thread.
final class ScrollHold: @unchecked Sendable {
    /// Set by the digest: holds the page's place while a row closes or leaves.
    var onHold: (() -> Void)?
    /// How far the bottom of the screen reaches past the end of the page, last seen (negative while
    /// more of the page lies below). Kept here, not in view state, so scrolling never redraws the page.
    var overhang: CGFloat = 0
    /// While a row closes or leaves, the held space is kept whole.
    var holdsUntil = Date.distantPast
    /// The page's scroll offset, last seen.
    var offset: CGFloat = 0

    func hold() {
        onHold?()
    }
}

extension EnvironmentValues {
    @Entry var swipeGuard: SwipeGuard? = nil
    /// Told just before an open row closes, so the page keeps its place instead of scrolling back
    /// when a row near its bottom gets shorter.
    @Entry var scrollHold: ScrollHold? = nil
    /// How far a to-do's swipe has gone toward checking it off, from 0 to 1. Draws the strike on its title.
    @Entry var swipeProgress: Double = 0
}

private struct JudgmentSwipe: ViewModifier {
    /// Swiping right.
    var leading: SwipeAction?
    /// Swiping left.
    var trailing: SwipeAction?

    /// How far the row must travel before letting go acts on it.
    private static let threshold: CGFloat = 96

    /// How far the row has been dragged sideways.
    @State private var dragX: CGFloat = 0
    /// Where the row flies off to once it has been acted on.
    @State private var exit: CGFloat?
    @State private var swipeGuard = SwipeGuard()

    private var offset: CGFloat { exit ?? dragX }

    private var isArmed: Bool { abs(offset) >= Self.threshold }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background { band }
            .gesture(HorizontalPan(onChange: dragChanged, onEnd: dragEnded))
            .environment(\.swipeGuard, swipeGuard)
            .environment(\.swipeProgress, min(abs(offset) / Self.threshold, 1))
            .sensoryFeedback(.selection, trigger: isArmed) { _, armed in armed }
    }

    @ViewBuilder
    private var band: some View {
        if offset != 0, let swipe = offset > 0 ? leading : trailing {
            let isLeading = offset > 0
            // Only the strip the row has moved off is drawn, so the page color never changes
            // and the label never sits under the row's text.
            VStack(spacing: 3) {
                Image(systemName: swipe.symbol)
                    .font(.title3.weight(.light))
                Text(swipe.label)
                    .font(.caption.weight(.medium))
            }
            .fixedSize()
            // Gray while dragging; ink once letting go would act on the row.
            .foregroundStyle(isArmed ? Theme.ink : Theme.secondary)
            .padding(.horizontal, Theme.margin)
            .frame(width: abs(offset), alignment: isLeading ? .leading : .trailing)
            .frame(maxHeight: .infinity)
            .clipped()
            .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .trailing)
            .accessibilityHidden(true)
        }
    }

    private func dragChanged(_ x: CGFloat) {
        guard exit == nil else { return }
        // A finger that drifts a little while tapping is still a tap.
        guard abs(x) >= SwipeGuard.tapTolerance else { return }
        // A direction with no action doesn't move.
        dragX = (x > 0 && leading == nil) || (x < 0 && trailing == nil) ? 0 : x
        swipeGuard.lastMove = .now
    }

    private func dragEnded(_ x: CGFloat, cancelled: Bool) {
        guard abs(x) >= SwipeGuard.tapTolerance else {
            dragX = 0
            return
        }
        swipeGuard.lastMove = .now
        let swipe = x > 0 ? leading : trailing
        guard exit == nil, !cancelled, abs(x) >= Self.threshold, let swipe else {
            withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
            return
        }
        let toRight = x > 0
        withAnimation(.easeOut(duration: 0.18)) {
            exit = toRight ? 600 : -600
        } completion: {
            swipe.action()
            exit = nil
            dragX = 0
        }
    }
}

/// A sideways pan that only starts when the finger is moving mostly sideways, so it never
/// competes with scrolling the page up and down.
struct HorizontalPan: UIGestureRecognizerRepresentable {
    var onChange: (CGFloat) -> Void
    var onEnd: (CGFloat, _ cancelled: Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        // Let a tap that drifts a little reach the row; the swipe guard drops the taps that end a swipe.
        pan.cancelsTouchesInView = false
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let x = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed: onChange(x)
        case .ended: onEnd(x, false)
        case .cancelled, .failed: onEnd(x, true)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.5
        }
    }
}

/// A hand-drawn strike across each line of a title, drawn left to right as `progress` goes from 0 to 1.
struct StrikeRenderer: TextRenderer {
    var progress: Double
    var color: Color

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            context.draw(line)
        }
        guard progress > 0 else { return }

        let lines = Array(layout)
        let total = lines.reduce(0) { $0 + $1.typographicBounds.width }
        var remaining = total * min(progress, 1)
        for (index, line) in lines.enumerated() where remaining > 0 {
            let bounds = line.typographicBounds
            let length = min(bounds.width, remaining)
            remaining -= length
            // Through the middle of the lowercase letters, with a slight rise and sag so it looks drawn.
            let y = bounds.rect.minY + bounds.ascent * 0.68
            let rise: CGFloat = index.isMultiple(of: 2) ? -1.2 : 0.9
            var path = Path()
            path.move(to: CGPoint(x: bounds.rect.minX - 1, y: y + 0.6))
            path.addQuadCurve(
                to: CGPoint(x: bounds.rect.minX + length, y: y + rise * (length / max(bounds.width, 1))),
                control: CGPoint(x: bounds.rect.minX + length * 0.5, y: y - 1)
            )
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}
