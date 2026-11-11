import DigestCore
import SwiftUI

/// What the reader can do with a headline or episode once they're done with it.
enum RowAction: String, Hashable, Sendable {
    case relevant, notRelevant, read

    var symbol: String {
        switch self {
        case .relevant: "arrow.up"
        case .notRelevant: "arrow.down"
        case .read: "checkmark"
        }
    }

    var label: String {
        switch self {
        case .relevant: "Relevant"
        case .notRelevant: "Not relevant"
        case .read: "Read"
        }
    }

    /// What the reading history records.
    var status: ItemStatus {
        switch self {
        case .relevant: .useful
        case .notRelevant: .notRelevant
        case .read: .read
        }
    }

    /// The actions in the order they show, left to right, on the card, the panel and the open swipe:
    /// ↓ Not relevant then ↑ Relevant, or one ✓ Read when reading history is off. The last one is what
    /// a full swipe does.
    static func choices(keepsHistory: Bool) -> [RowAction] {
        keepsHistory ? [.notRelevant, .relevant] : [.read]
    }
}

extension View {
    /// Swipe left, like Mail. A short swipe rests open on the actions, ↓ Not relevant then ↑ Relevant;
    /// a full swipe does the right-most one. Once an action is chosen, here or from the card or the
    /// panel (`request`), the row slides off to the left with the action riding out at its edge, rests
    /// a beat, then closes up and the rows below slide up. `perform` records the action at the end.
    func leaveSwipe(_ choices: [RowAction], request: RowAction?, perform: @escaping (RowAction) -> Void) -> some View {
        modifier(LeaveSwipe(stripActions: choices, request: request, perform: perform))
    }
}

private struct LeaveSwipe: ViewModifier {
    /// Left to right as they show in the open strip; the last one is what a full swipe does.
    var stripActions: [RowAction]
    var request: RowAction?
    var perform: (RowAction) -> Void

    /// Each action's share of the open strip.
    private static let actionWidth: CGFloat = 84
    /// A short flick this far opens the strip, whether it holds one action or two: the same effort as
    /// opening ✓ Read alone.
    private static let opensAt: CGFloat = (actionWidth + Theme.margin) * 0.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scrollHold) private var scrollHold

    @State private var dragX: CGFloat = 0
    @State private var width: CGFloat = 393
    @State private var height: CGFloat = 0
    @State private var swipeGuard = SwipeGuard()

    // Once an action is chosen.
    @State private var committed: RowAction?
    @State private var exitX: CGFloat = 0
    @State private var labelAtLeading = false
    @State private var labelOpacity: Double = 1
    @State private var frozenHeight: CGFloat?
    @State private var commitHaptic = 0

    private var primary: RowAction { stripActions.last ?? .read }

    /// How far a short swipe rests open: the actions, then the page margin.
    private var openWidth: CGFloat { Self.actionWidth * CGFloat(stripActions.count) + Theme.margin }

    /// Past this, letting go does the right-most action.
    private var fullThreshold: CGFloat { max(openWidth + 50, width * 0.6) }

    private var offset: CGFloat { committed != nil ? exitX : dragX }

    private var isArmed: Bool { committed == nil && -dragX >= fullThreshold }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: .trailing) { strip }
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
            .sensoryFeedback(.impact(weight: .light), trigger: commitHaptic)
            .onAppear { swipeGuard.closeStrip = { close() } }
            .onChange(of: request, initial: true) { _, action in
                if let action { commit(action, fromCard: true) }
            }
            .accessibilityActions {
                ForEach(Array(stripActions.reversed()), id: \.self) { action in
                    Button(action.label) { commit(action) }
                }
            }
    }

    // MARK: The strip behind the row

    @ViewBuilder
    private var strip: some View {
        if let committed {
            // The action rides out at the row's edge, then rests at the left.
            actionLabel(committed, color: Theme.ink)
                .opacity(labelOpacity)
                .padding(.horizontal, Theme.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: labelAtLeading ? .leading : .trailing)
                .accessibilityHidden(true)
        } else if dragX < 0 {
            HStack(spacing: 0) {
                if isArmed {
                    actionLabel(primary, color: Theme.ink)
                } else {
                    ForEach(stripActions, id: \.self) { action in
                        Button { commit(action) } label: {
                            actionLabel(action, color: Theme.secondary)
                                .frame(width: Self.actionWidth)
                                .frame(maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(StillButtonStyle())
                        .accessibilityHidden(true)
                    }
                }
            }
            .padding(.trailing, Theme.margin)
            // Only the strip the row has moved off is drawn, so the page color never changes.
            .frame(width: -dragX, alignment: .trailing)
            .frame(maxHeight: .infinity)
            .clipped()
        }
    }

    private func actionLabel(_ action: RowAction, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: action.symbol)
                .font(.title3.weight(.light))
            Text(action.label)
                .font(.caption.weight(.medium))
        }
        .fixedSize()
        .foregroundStyle(color)
    }

    // MARK: Gestures

    private func dragChanged(_ x: CGFloat) {
        guard committed == nil else { return }
        let base = swipeGuard.restsOpen ? -openWidth : 0
        // A finger that drifts a little while tapping is still a tap.
        guard swipeGuard.restsOpen || abs(x) >= SwipeGuard.tapTolerance else { return }
        swipeGuard.lastMove = .now
        // Swiping right does nothing, except close an open strip.
        dragX = min(0, base + x)
    }

    private func dragEnded(_ x: CGFloat, cancelled: Bool) {
        guard committed == nil else { return }
        let base = swipeGuard.restsOpen ? -openWidth : 0
        guard swipeGuard.restsOpen || abs(x) >= SwipeGuard.tapTolerance else {
            dragX = 0
            return
        }
        swipeGuard.lastMove = .now
        let position = min(0, base + x)
        if !cancelled, -position >= fullThreshold {
            commit(primary)
        } else if !cancelled, -position >= (swipeGuard.restsOpen ? openWidth * 0.5 : Self.opensAt) {
            withAnimation(.easeOut(duration: 0.2)) { dragX = -openWidth }
            swipeGuard.restsOpen = true
        } else {
            close()
        }
    }

    private func close() {
        swipeGuard.restsOpen = false
        withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
    }

    // MARK: Once an action is chosen

    /// - Parameter fromCard: true when chosen on the card or the panel, away from the finger: the action
    ///   rests a little longer at the left, so the reader sees what they chose before the row closes.
    private func commit(_ action: RowAction, fromCard: Bool = false) {
        guard committed == nil else { return }
        swipeGuard.restsOpen = false
        commitHaptic += 1
        if reduceMotion {
            scrollHold?.hold()
            perform(action)
            return
        }
        exitX = dragX
        frozenHeight = height
        committed = action
        let rowWidth = width

        Task { @MainActor in
            // 1. The row slides off to the left; the action rides out with its edge.
            withAnimation(.easeOut(duration: 0.18)) {
                exitX = -rowWidth
                labelAtLeading = true
            }
            try? await Task.sleep(for: .seconds(0.18))
            // 2. A beat to see what was done.
            try? await Task.sleep(for: .seconds(fromCard ? 0.3 : 0.08))
            // 3. The gap closes and the rows below slide up. The page holds its place meanwhile.
            scrollHold?.hold()
            withAnimation(.easeOut(duration: 0.16)) {
                frozenHeight = 0
                labelOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.16))
            perform(action)
        }
    }
}
