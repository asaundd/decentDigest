import SwiftUI
import UIKit

extension View {
    /// Swipe right to check a to-do off; a left swipe does nothing. Drawn by hand like the News swipe,
    /// mirrored: ✓ Done on one line in the strip the row has moved off, gray until letting go would
    /// check it off, then ink. Once checked, here or from the card's ✓ (`request`), the row slides off
    /// to the right with ✓ Done riding out at its edge, rests a beat at the right, then closes up and
    /// the rows below slide up.
    /// - Parameters:
    ///   - check: runs as the row starts to leave; false (Reminders refused) brings the row back.
    ///   - finish: runs once the gap has closed, to take the to-do off the list.
    func checkOffSwipe(request: Bool = false, check: @escaping () -> Bool, finish: @escaping () -> Void) -> some View {
        modifier(DoneSwipe(request: request, check: check, finish: finish))
    }
}

/// Remembers when a row last moved sideways, so a swipe that is let go near where it began
/// isn't taken as a tap, and whether a row rests open on its actions.
@MainActor
final class SwipeGuard {
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
@MainActor
final class ScrollHold {
    /// Set by the digest: holds the page's place while a row closes or leaves.
    var onHold: (() -> Void)?
    /// How far the bottom of the screen reaches past the end of the page, last seen (negative while
    /// more of the page lies below). Kept here, not in view state, so scrolling never redraws the page.
    var overhang: CGFloat = 0
    /// While a row closes or leaves, the held space is kept whole.
    var holdsUntil = Date.distantPast
    /// The page's scroll offset, last seen.
    var offset: CGFloat = 0
    /// The space at the top of the page that the status bar covers, last seen.
    var topInset: CGFloat = 0
    /// Set by the digest: scrolls the page by this many points (negative is up).
    var scrollBy: ((CGFloat) -> Void)?

    /// After Show less, brings a list's title back on screen when it has scrolled off the top.
    /// - Parameter titleTop: the title's top, in the page's visible frame, before the list folded.
    func bringBack(titleTop: CGFloat) {
        let wanted = topInset + 12
        guard titleTop < wanted else { return }
        scrollBy?(titleTop - wanted)
    }

    func hold() {
        onHold?()
    }
}

/// Where a list's title sits on screen, last seen. Kept in a box, not view state, so scrolling
/// never redraws the list.
final class TitlePlace {
    var top: CGFloat = 0
}

extension View {
    /// Notes where this title sits in the page's visible frame, for `ScrollHold.bringBack`.
    func tracksPlace(in place: TitlePlace) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { place.top = $0 }
    }
}

extension EnvironmentValues {
    @Entry var swipeGuard: SwipeGuard? = nil
    /// Told just before an open row closes, so the page keeps its place instead of scrolling back
    /// when a row near its bottom gets shorter.
    @Entry var scrollHold: ScrollHold? = nil
}

private struct DoneSwipe: ViewModifier {
    var request: Bool
    var check: () -> Bool
    var finish: () -> Void

    /// How far the row must travel before letting go checks it off.
    private static let threshold: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scrollHold) private var scrollHold

    @State private var dragX: CGFloat = 0
    @State private var width: CGFloat = 393
    @State private var height: CGFloat = 0
    @State private var swipeGuard = SwipeGuard()

    // Once checked off.
    @State private var committed = false
    @State private var exitX: CGFloat = 0
    @State private var labelAtTrailing = false
    @State private var labelOpacity: Double = 1
    @State private var frozenHeight: CGFloat?

    private var offset: CGFloat { committed ? exitX : dragX }

    private var isArmed: Bool { !committed && dragX >= Self.threshold }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: .leading) { strip }
            .gesture(HorizontalPan(onChange: dragChanged, onEnd: dragEnded))
            .environment(\.swipeGuard, swipeGuard)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                width = size.width
                if frozenHeight == nil { height = size.height }
            }
            .frame(height: frozenHeight, alignment: .top)
            // While the row closes up, nothing spills over the rows below it.
            .mask { Rectangle().padding(.vertical, frozenHeight == nil ? -24 : 0) }
            .sensoryFeedback(.selection, trigger: isArmed) { _, armed in armed }
            .onChange(of: request) { _, requested in
                if requested { commit() }
            }
    }

    @ViewBuilder
    private var strip: some View {
        if committed {
            // ✓ Done rides out with the row's edge, then rests at the right.
            label(color: Theme.ink)
                .opacity(labelOpacity)
                .padding(.horizontal, Theme.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: labelAtTrailing ? .trailing : .leading)
                .accessibilityHidden(true)
        } else if dragX > 0 {
            label(color: isArmed ? Theme.ink : Theme.secondary)
                .padding(.horizontal, Theme.margin)
                // Only the strip the row has moved off is drawn, so the page color never changes.
                .frame(width: dragX, alignment: .leading)
                .frame(maxHeight: .infinity)
                .clipped()
                .accessibilityHidden(true)
        }
    }

    /// ✓ and Done on one line at the row's text size, so they fit a compact row.
    private func label(color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(AgendaMetrics.itemFont.weight(.light))
            Text("Done")
                .font(AgendaMetrics.itemFont.weight(.medium))
        }
        .fixedSize()
        .foregroundStyle(color)
    }

    private func dragChanged(_ x: CGFloat) {
        guard !committed else { return }
        // A finger that drifts a little while tapping is still a tap.
        guard abs(x) >= SwipeGuard.tapTolerance else { return }
        swipeGuard.lastMove = .now
        dragX = max(0, x)
    }

    private func dragEnded(_ x: CGFloat, cancelled: Bool) {
        guard !committed else { return }
        guard abs(x) >= SwipeGuard.tapTolerance else {
            dragX = 0
            return
        }
        swipeGuard.lastMove = .now
        if !cancelled, x >= Self.threshold {
            commit()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
        }
    }

    private func commit() {
        guard !committed else { return }
        // Set first, so a second swipe or tap can't check the to-do off twice.
        exitX = dragX
        committed = true
        guard check() else {
            committed = false
            withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
            return
        }
        if reduceMotion {
            scrollHold?.hold()
            finish()
            return
        }
        frozenHeight = height
        let rowWidth = width

        Task { @MainActor in
            // 1. The row slides off to the right; ✓ Done rides out with its edge.
            withAnimation(.easeOut(duration: 0.18)) {
                exitX = rowWidth
                labelAtTrailing = true
            }
            try? await Task.sleep(for: .seconds(0.18))
            // 2. A beat to see it was done, as on News.
            try? await Task.sleep(for: .seconds(0.18))
            // 3. The gap closes and the rows below slide up. The page holds its place meanwhile.
            scrollHold?.hold()
            withAnimation(.easeOut(duration: 0.16)) {
                frozenHeight = 0
                labelOpacity = 0
            }
            // Taken off the list only once the gap has fully closed on screen.
            try? await Task.sleep(for: .seconds(0.26))
            finish()
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
