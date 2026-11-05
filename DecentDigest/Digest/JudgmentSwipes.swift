import SwiftUI
import UIKit

extension View {
    /// Swipe right for useful (✓), left for not useful (✕). The system swipe actions draw buttons,
    /// so this is drawn by hand: the symbol and a small gray word on the page, pinned to the edge
    /// the row is leaving. Letting go past the threshold acts on the row.
    func judgmentSwipes(useful: @escaping () -> Void, notUseful: @escaping () -> Void) -> some View {
        modifier(JudgmentSwipe(useful: useful, notUseful: notUseful))
            .accessibilityAction(named: "Useful", useful)
            .accessibilityAction(named: "Not useful", notUseful)
    }
}

/// Remembers when a row last moved sideways, so a swipe that is let go near where it began
/// isn't taken as a tap.
/// Gestures and taps both run on the main thread.
final class SwipeGuard: @unchecked Sendable {
    fileprivate var lastMove = Date.distantPast

    /// True right after a swipe, when the finger lifting would otherwise count as a tap.
    var justSwiped: Bool { Date.now.timeIntervalSince(lastMove) < 0.4 }
}

extension EnvironmentValues {
    @Entry var swipeGuard: SwipeGuard? = nil
}

private struct JudgmentSwipe: ViewModifier {
    var useful: () -> Void
    var notUseful: () -> Void

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
            // While the row moves, it hides the band behind it.
            .background {
                if offset != 0 {
                    Theme.page
                }
            }
            .offset(x: offset)
            .background { band }
            .gesture(HorizontalPan(onChange: dragChanged, onEnd: dragEnded))
            .environment(\.swipeGuard, swipeGuard)
            .sensoryFeedback(.selection, trigger: isArmed) { _, armed in armed }
    }

    @ViewBuilder
    private var band: some View {
        if offset != 0 {
            let isUseful = offset > 0
            HStack {
                if !isUseful { Spacer(minLength: 0) }
                VStack(spacing: 3) {
                    Image(systemName: isUseful ? "checkmark" : "xmark")
                        .font(.body.weight(.semibold))
                    Text(isUseful ? "Relevant" : "Not relevant")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(isArmed ? Theme.ink : Theme.secondary)
                if isUseful { Spacer(minLength: 0) }
            }
            .padding(.horizontal, Theme.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
    }

    private func dragChanged(_ x: CGFloat) {
        guard exit == nil else { return }
        dragX = x
        swipeGuard.lastMove = .now
    }

    private func dragEnded(_ x: CGFloat, cancelled: Bool) {
        swipeGuard.lastMove = .now
        guard exit == nil, !cancelled, abs(x) >= Self.threshold else {
            withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
            return
        }
        let toRight = x > 0
        withAnimation(.easeOut(duration: 0.18)) {
            exit = toRight ? 600 : -600
        } completion: {
            if toRight { useful() } else { notUseful() }
            exit = nil
            dragX = 0
        }
    }
}

/// A sideways pan that only starts when the finger is moving mostly sideways, so it never
/// competes with scrolling the page up and down.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    var onChange: (CGFloat) -> Void
    var onEnd: (CGFloat, _ cancelled: Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
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
