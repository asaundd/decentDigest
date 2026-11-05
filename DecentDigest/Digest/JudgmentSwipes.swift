import SwiftUI

extension View {
    /// Swipe right for useful (✓), left for not useful (✕). The system swipe actions draw buttons,
    /// so this is drawn by hand: a plain band of color behind the row, with the symbol and a small
    /// word pinned to the edge the row is leaving. Letting go past the threshold acts on the row.
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

    /// The live drag. It springs back on its own if the drag ends short or is cancelled.
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: 0.2)))
    private var drag = Drag.undecided
    /// Where the row flies off to once it has been acted on.
    @State private var exit: CGFloat?
    @State private var swipeGuard = SwipeGuard()

    private enum Drag: Equatable {
        case undecided, vertical
        case sideways(CGFloat)
    }

    private var offset: CGFloat {
        if let exit { return exit }
        if case .sideways(let x) = drag { return x }
        return 0
    }

    private var isArmed: Bool { abs(offset) >= Self.threshold }

    func body(content: Content) -> some View {
        content
            // While the row moves, it hides the band behind it.
            .background {
                if offset != 0 {
                    Theme.page.padding(.horizontal, -Theme.margin)
                }
            }
            .offset(x: offset)
            .background { band }
            .simultaneousGesture(dragGesture)
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
                    Text(isUseful ? "Useful" : "Not useful")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .opacity(isArmed ? 1 : 0.7)
                if isUseful { Spacer(minLength: 0) }
            }
            .padding(.horizontal, Theme.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isUseful ? Theme.swipeUseful : Theme.swipeNotRelevant)
            .padding(.horizontal, -Theme.margin)
            .accessibilityHidden(true)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .updating($drag) { [swipeGuard] value, state, _ in
                let x = value.translation.width
                defer {
                    if case .sideways = state { swipeGuard.lastMove = .now }
                }
                switch state {
                case .vertical:
                    return
                case .undecided:
                    // Decide once which way the drag goes, so scrolling never moves the row.
                    if abs(x) > abs(value.translation.height) * 1.5 {
                        state = .sideways(x)
                    } else if abs(value.translation.height) > 10 {
                        state = .vertical
                    }
                case .sideways:
                    state = .sideways(x)
                }
            }
            .onEnded { value in
                let x = value.translation.width
                guard exit == nil, abs(x) >= Self.threshold, abs(x) > abs(value.translation.height) * 1.5 else { return }
                let toRight = x > 0
                withAnimation(.easeOut(duration: 0.18)) {
                    exit = toRight ? 600 : -600
                } completion: {
                    if toRight { useful() } else { notUseful() }
                    exit = nil
                }
            }
    }
}
