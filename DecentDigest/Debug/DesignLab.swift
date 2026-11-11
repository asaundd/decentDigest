#if DEBUG
import SwiftUI

/// A test-only page for trying news row actions on the phone before they're built into the digest.
/// Opened from the Settings footer in debug builds. Nothing here touches real feeds or reading state.
struct DesignLabView: View {
    @State private var style: LabStyle = .fill
    @State private var keepsHistory = true
    @State private var slowMotion = false
    @State private var items = LabItem.samples
    @State private var openID: Int?
    @AppStorage(SlowLoading.key) private var slowLoading = false

    var body: some View {
        SettingsPage(title: "Design lab", subtitle: "For testing only. Sample news items; nothing is saved.") {
            VStack(alignment: .leading, spacing: 14) {
                SettingsLabel("When an action is done")
                Picker("Animation", selection: $style) {
                    ForEach(LabStyle.allCases) { style in
                        Text(style.name).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Text(style.note)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Keep reading history", isOn: $keepsHistory)
                    .tint(Theme.switchOn)
                Toggle("Slow motion", isOn: $slowMotion)
                    .tint(Theme.switchOn)

                TextLink("Reset the list") {
                    openID = nil
                    items = LabItem.samples
                }

                SettingsLabel("Loading")
                Toggle("Slow loading", isOn: $slowLoading)
                    .tint(Theme.switchOn)
                Text("Every read and fetch on the digest waits 3 seconds first, so the launch logo, placeholder bars and late rows can be checked. Quit and reopen the app to see a cold launch. Stays on until turned off.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SectionRule()

            Text("News")
                .font(Theme.sectionTitleFont)
                .padding(.bottom, Theme.titleToFirstItem - LabRow.verticalPadding)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    LabRow(
                        item: item,
                        style: style,
                        keepsHistory: keepsHistory,
                        speed: slowMotion ? 4 : 1,
                        isOpen: openID == item.id,
                        toggleOpen: { openID = openID == item.id ? nil : item.id },
                        remove: {
                            if openID == item.id { openID = nil }
                            withAnimation(HeadlineMotion.close) {
                                items.removeAll { $0.id == item.id }
                            }
                        }
                    )
                    .transition(.identity)
                }
            }
            if items.isEmpty {
                QuietLine("All done. Reset the list to try again.")
            }
        }
    }
}

/// The animation played once an action is chosen.
enum LabStyle: String, CaseIterable, Identifiable {
    case fill, ride, nudge

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fill: "L · Fill"
        case .ride: "K · Ride out"
        case .nudge: "M · Nudge"
        }
    }

    var note: String {
        switch self {
        case .fill: "A tone fills the row, like Mail: slate for Relevant, gray for Not relevant and Read. Then the row closes."
        case .ride: "No color. The action rides out with the row's edge, rests at the left, then the row closes."
        case .nudge: "No color. The row slides out, the arrow hops in its own direction and settles, then the row closes."
        }
    }
}

enum LabAction {
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

    var fill: Color {
        self == .relevant ? Theme.accent : Theme.rule
    }

    var fillText: Color {
        self == .relevant ? Theme.page : Theme.ink
    }

    /// Which way the arrow hops in the nudge.
    var hop: CGFloat {
        switch self {
        case .relevant: -8
        case .notRelevant: 8
        case .read: -4
        }
    }
}

struct LabItem: Identifiable {
    var id: Int
    var title: String
    var source: String
    var byline: String
    var text: String

    static let samples: [LabItem] = [
        LabItem(id: 1, title: "Payers push prior authorization deadlines into next year", source: "Fierce Healthcare · 7 hr", byline: "Jane Doe · Fierce Healthcare", text: "Large insurers say they need more time to meet the new electronic prior authorization rules, citing vendor delays and the cost of rebuilding their review systems."),
        LabItem(id: 2, title: "What product leaders get wrong about roadmaps", source: "Lenny's Newsletter · 5 hr", byline: "Lenny Rachitsky", text: "Most roadmaps fail in year one for the same reason: they promise dates before the team knows the problem well enough to size it."),
        LabItem(id: 3, title: "Health systems slow AI scribe rollouts", source: "STAT · 2 hr", byline: "STAT staff", text: "Several large systems are pausing wider rollouts as pilots wrap up, asking for better evidence on time saved and note quality."),
        LabItem(id: 4, title: "Notes from a month of building on device", source: "The Batch · 20 min", byline: "The Batch", text: "Small models running on the phone are good enough for sorting and short summaries, and they keep everything private."),
        LabItem(id: 5, title: "Why small teams ship faster", source: "Stratechery · 1 hr", byline: "Ben Thompson", text: "Fewer handoffs, fewer meetings, and one person who holds the whole picture."),
        LabItem(id: 6, title: "Hospitals test new discharge checklists", source: "Modern Healthcare · 3 hr", byline: "Modern Healthcare", text: "A short checklist at discharge cut readmissions in a pilot across four hospitals."),
        LabItem(id: 7, title: "The quiet return of RSS readers", source: "The Verge · 6 hr", byline: "The Verge", text: "People tired of feeds picked by someone else are going back to choosing their own sources."),
        LabItem(id: 8, title: "A plain guide to Medicare Advantage changes", source: "KFF Health News · 8 hr", byline: "KFF Health News", text: "What changes next year for plans, prior authorization and star ratings, in plain terms."),
    ]
}

/// One sample news row: swipe left to reveal the actions, tap to open the card.
private struct LabRow: View {
    static let verticalPadding: CGFloat = 6
    /// How far a short swipe rests open, per action.
    static let actionWidth: CGFloat = 84

    var item: LabItem
    var style: LabStyle
    var keepsHistory: Bool
    /// 1 for normal speed, higher for slow motion.
    var speed: Double
    var isOpen: Bool
    var toggleOpen: () -> Void
    var remove: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var restsOpen = false
    @State private var width: CGFloat = 345
    @State private var height: CGFloat = 0
    @State private var lastMove = Date.distantPast

    // The animation once an action is chosen.
    @State private var committed: LabAction?
    @State private var exitX: CGFloat = 0
    @State private var fillFraction: CGFloat = 0
    @State private var labelAtLeading = false
    @State private var hopY: CGFloat = 0
    @State private var frozenHeight: CGFloat?
    @State private var labelOpacity: Double = 1
    @State private var commitHaptic = 0

    private var actions: [LabAction] {
        keepsHistory ? [.notRelevant, .relevant] : [.read]
    }

    /// The right-most action, which a full swipe does.
    private var primary: LabAction { actions.last ?? .read }

    private var openWidth: CGFloat { Self.actionWidth * CGFloat(actions.count) + Theme.margin }

    /// Past this, letting go does the primary action.
    private var fullThreshold: CGFloat { max(openWidth + 50, width * 0.6) }

    private var offset: CGFloat { committed != nil ? exitX : dragX }

    private var isArmed: Bool { -offset >= fullThreshold }

    private var justSwiped: Bool { Date.now.timeIntervalSince(lastMove) < 0.4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
                .offset(x: offset)
                .background(alignment: .trailing) { strip }
                .gesture(HorizontalPan(onChange: dragChanged, onEnd: dragEnded))
                .sensoryFeedback(.selection, trigger: isArmed) { _, armed in armed }
                .sensoryFeedback(.impact(weight: .light), trigger: commitHaptic)

            if isOpen, committed == nil {
                card
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            width = size.width
            if frozenHeight == nil { height = size.height }
        }
        .frame(height: frozenHeight, alignment: .top)
        // Clip top and bottom only, so the strip still reaches the screen edges.
        .mask { Rectangle().padding(.horizontal, -Theme.margin) }
        .onChange(of: keepsHistory) { close() }
    }

    private var titleRow: some View {
        Button {
            guard !justSwiped else { return }
            if restsOpen { close() } else { toggleOpen() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("–")
                    .foregroundStyle(Theme.secondary)
                    .frame(width: DashColumn.width, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.ink)
                    Text(item.source)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Self.verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(StillButtonStyle())
        .accessibilityActions {
            ForEach(actions, id: \.label) { action in
                Button(action.label) { commit(action) }
            }
        }
    }

    // MARK: The strip behind the row

    @ViewBuilder
    private var strip: some View {
        if let committed {
            committedStrip(committed)
        } else if dragX < 0 {
            let showsAll = !isArmed
            HStack(spacing: 0) {
                if showsAll {
                    ForEach(actions, id: \.label) { action in
                        Button { commit(action) } label: {
                            actionLabel(action, color: Theme.secondary)
                                .frame(width: Self.actionWidth)
                                .frame(maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(StillButtonStyle())
                    }
                } else {
                    actionLabel(primary, color: Theme.ink)
                }
            }
            .padding(.trailing, Theme.margin)
            .frame(width: -dragX + Theme.margin, alignment: .trailing)
            .frame(maxHeight: .infinity)
            .clipped()
            .offset(x: Theme.margin)
        }
    }

    private func committedStrip(_ action: LabAction) -> some View {
        let fillWidth = (width + Theme.margin * 2) * fillFraction
        let usesFill = style == .fill
        let color = usesFill ? action.fillText : Theme.ink
        return ZStack(alignment: .trailing) {
            if usesFill {
                Rectangle()
                    .fill(action.fill)
                    .frame(width: fillWidth)
            }
            actionLabel(action, color: color, hop: hopY)
                .opacity(labelOpacity)
                .scaleEffect(labelOpacity < 1 ? 0.85 : 1)
                .padding(.horizontal, Theme.margin + 8)
                .frame(maxWidth: .infinity, alignment: labelAtLeading ? .leading : .trailing)
        }
        .frame(width: width + Theme.margin * 2, alignment: .trailing)
        .frame(maxHeight: .infinity)
        .offset(x: Theme.margin)
        .accessibilityHidden(true)
    }

    private func actionLabel(_ action: LabAction, color: Color, hop: CGFloat = 0) -> some View {
        VStack(spacing: 3) {
            Image(systemName: action.symbol)
                .font(.title3.weight(.light))
                .offset(y: hop)
            Text(action.label)
                .font(.caption.weight(.medium))
        }
        .fixedSize()
        .foregroundStyle(color)
    }

    // MARK: The open card

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.byline)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    RibbonButton(systemImage: "bookmark", label: "Save") { remove() }
                    ForEach(Array(actions.reversed()), id: \.label) { action in
                        RibbonButton(systemImage: action.symbol, label: action.label) {
                            cardTap(action)
                        }
                    }
                }
                .padding(.trailing, -RibbonButton.gap)
            }
            Text(item.text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 16) {
                TextLink("Open ↗") {}
            }
            .padding(.bottom, 6)
        }
        .padding(.trailing, 12)
        .padding(.top, 4)
        .padding(.leading, 12)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.expandedFill)
                .shadow(color: Theme.expandedShadow, radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.expandedRing, lineWidth: 1)
                )
        }
        .padding(.leading, DashColumn.width - 12)
        .padding(.trailing, -12)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onTapGesture { toggleOpen() }
    }

    // MARK: Gestures

    private func dragChanged(_ x: CGFloat) {
        guard committed == nil else { return }
        lastMove = .now
        let base = restsOpen ? -openWidth : 0
        dragX = min(0, base + x)
    }

    private func dragEnded(_ x: CGFloat, cancelled: Bool) {
        guard committed == nil else { return }
        lastMove = .now
        let base = restsOpen ? -openWidth : 0
        let position = min(0, base + x)
        if !cancelled, -position >= fullThreshold {
            commit(primary)
        } else if !cancelled, -position >= openWidth * 0.5 {
            withAnimation(.easeOut(duration: 0.2)) { dragX = -openWidth }
            restsOpen = true
        } else {
            close()
        }
    }

    private func close() {
        restsOpen = false
        withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
    }

    private func cardTap(_ action: LabAction) {
        // The card folds away first, then the row plays the animation.
        toggleOpen()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            commit(action)
        }
    }

    // MARK: The animation once an action is chosen

    private func commit(_ action: LabAction) {
        guard committed == nil else { return }
        exitX = dragX
        frozenHeight = height
        committed = action
        commitHaptic += 1
        let slow = speed
        let start: CGFloat = style == .fill ? min(1, max(0, -dragX / (width + Theme.margin * 2))) : 0
        fillFraction = start

        Task { @MainActor in
            // 1. The row slides off and the action plays.
            withAnimation(.easeOut(duration: 0.2 * slow)) {
                exitX = -(width + Theme.margin * 2)
                fillFraction = 1
                if style != .nudge { labelAtLeading = true }
            }
            if style == .nudge {
                withAnimation(.easeOut(duration: 0.12 * slow).delay(0.08 * slow)) { hopY = action.hop }
                try? await Task.sleep(for: .seconds(0.22 * slow))
                withAnimation(.spring(duration: 0.25 * slow, bounce: 0.4)) { hopY = 0 }
                try? await Task.sleep(for: .seconds(0.2 * slow))
            } else {
                try? await Task.sleep(for: .seconds(0.2 * slow))
                // 2. A beat to see it.
                try? await Task.sleep(for: .seconds(0.12 * slow))
            }
            // 3. The row closes and the rows below slide up.
            withAnimation(.easeOut(duration: 0.2 * slow)) {
                frozenHeight = 0
                labelOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.2 * slow))
            remove()
        }
    }
}

#Preview {
    NavigationStack {
        DesignLabView()
    }
}
#endif
