import DigestCore
import SwiftUI

/// Open reminders, read live: Past due first, then by day like Calendar, then Anytime for those with no date.
/// A to-do is checked off with the ✓ on its card or by swiping its row right; either writes back to Reminders.
struct TodosSectionView: View {
    var model: AgendaModel

    @Environment(\.openURL) private var openURL
    @Environment(\.scrollHold) private var scrollHold
    @State private var expandedDays: Set<Date> = []
    @State private var anytimeExpanded = false
    @State private var showsAll = false
    @State private var openIDs: Set<String> = []
    /// To-dos checked off on their card, riding out to the right.
    @State private var leavingIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reminders ↗ sits on the footer line.
            SectionHeader(title: DigestSection.todos.title) { EmptyView() }
                .padding(.bottom, Theme.titleToFirstItem - DayHeader.firstTopPadding)
                .digestRow()

            // The digest shows this section only once Reminders access is on.
            if model.remindersAccess == .granted, !model.hasLoaded {
                // Only when the first read is slow; the rows replace the bars in place.
                PlaceholderBars()
                    .padding(.top, DayHeader.firstTopPadding)
                    .digestRow()
            } else if model.remindersAccess == .granted {
                list(now: .now)
            }
        }
    }

    private func list(now: Date) -> some View {
        let plan = TodoRules.plan(model.todos, now: now, expanded: expandedDays, anytimeExpanded: anytimeExpanded, showAll: showsAll)
        let days = plan.days.filter { !$0.items.isEmpty }
        return VStack(alignment: .leading, spacing: 0) {
            if isEmpty(plan, days: days) {
                QuietLine("Nothing to do.")
                    .digestRow()
            }
            if !plan.pastDue.isEmpty {
                DayHeader(title: "Past due", isFirst: true)
                    .digestRow()
                ForEach(plan.pastDue) { todo in
                    row(todo, now: now)
                }
            }
            ForEach(days) { group in
                DayHeader(title: AgendaFormat.dayName(group.day, now: now), isFirst: plan.pastDue.isEmpty && group.id == days.first?.id)
                    .digestRow()
                ForEach(group.items) { todo in
                    row(todo, now: now)
                }
                if group.hiddenCount > 0 {
                    MoreLine(count: group.hiddenCount, noun: "item", leading: DashColumn.width) {
                        expandedDays.insert(group.day)
                    }
                    .digestRow()
                }
            }
            if !plan.anytime.isEmpty {
                DayHeader(title: "Anytime", isFirst: plan.pastDue.isEmpty && days.isEmpty)
                    .digestRow()
                ForEach(plan.anytime) { todo in
                    row(todo, now: now)
                }
                if plan.anytimeHidden > 0 {
                    MoreLine(count: plan.anytimeHidden, noun: "item", leading: DashColumn.width) {
                        anytimeExpanded = true
                    }
                    .digestRow()
                }
            }
            // Always shown, for Reminders ↗.
            ListFooter(
                hidden: plan.hiddenCount,
                phrase: { $0 == 1 ? "more item this week" : "more items this week" },
                empty: isEmpty(plan, days: days) ? nil : "No other items this week",
                showsAll: showsAll,
                app: ListFooter.Link(title: "Reminders ↗", spoken: "Open Reminders") { openURL(AgendaLinks.reminders) }
            ) {
                showsAll.toggle()
                if !showsAll {
                    expandedDays = []
                    anytimeExpanded = false
                }
            }
            .padding(.top, 10)
            .digestRow()
            if let problem = model.problem {
                Text(problem)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 4)
                    .digestRow()
            }
        }
        // The rows below slide up briefly to close the gap a checked-off to-do leaves.
        .animation(HeadlineMotion.close, value: model.todos.map(\.id))
        // The app's one haptic: a light tap when a to-do is checked off.
        .sensoryFeedback(.impact(weight: .light), trigger: model.checkedIDs) { old, new in
            new.count > old.count
        }
    }

    private func isEmpty(_ plan: TodoPlan, days: [DayGroup<TodoEntry>]) -> Bool {
        plan.pastDue.isEmpty && days.isEmpty && plan.anytime.isEmpty
    }

    private func row(_ todo: TodoEntry, now: Date) -> some View {
        TodoRow(
            todo: todo,
            note: TodoRules.note(for: todo, now: now),
            dueLine: AgendaFormat.dueLine(for: todo, now: now),
            isChecked: model.checkedIDs.contains(todo.id),
            isOpen: openIDs.contains(todo.id),
            onTap: { tap(todo) },
            check: { cardCheck(todo) },
            open: { open(todo) }
        )
        // Rows are full width so a swipe can draw its label at the page's edge.
        .padding(.leading, Theme.margin + DashColumn.width)
        .padding(.trailing, Theme.margin)
        .id(todo.id)
        // A to-do that leaves is gone at once; one that joins fades in after the slide.
        .transition(HeadlineMotion.transition)
        .checkOffSwipe(request: leavingIDs.contains(todo.id)) { swipeCheck(todo) }
    }

    // MARK: Actions

    /// Opens or closes a to-do's card. A to-do checked off on its card leaves on its own,
    /// or at once if its card is closed first.
    private func tap(_ todo: TodoEntry) {
        if openIDs.contains(todo.id) { scrollHold?.hold() }
        if openIDs.remove(todo.id) == nil {
            openIDs.insert(todo.id)
        } else if model.checkedIDs.contains(todo.id) {
            withAnimation(HeadlineMotion.close) {
                model.finishChecking(todo.id)
            }
        }
    }

    /// The ✓ on the card checks the to-do off: the strike draws, then the row rides out to the
    /// right as if swiped and leaves.
    private func cardCheck(_ todo: TodoEntry) {
        guard !model.checkedIDs.contains(todo.id), model.check(todo) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            leavingIDs.insert(todo.id)
        }
    }

    /// A swipe checks the to-do off and it leaves at once.
    private func swipeCheck(_ todo: TodoEntry) {
        leavingIDs.remove(todo.id)
        guard model.check(todo) else { return }
        scrollHold?.hold()
        openIDs.remove(todo.id)
        withAnimation(HeadlineMotion.close) {
            model.finishChecking(todo.id)
        }
    }

    private func open(_ todo: TodoEntry) {
        guard let url = AgendaLinks.reminder(id: todo.id) else {
            openURL(AgendaLinks.reminders)
            return
        }
        openURL(url) { accepted in
            if !accepted { openURL(AgendaLinks.reminders) }
        }
    }
}

/// A to-do: its title, with its time in gray after it when it is due today or later at a set time.
/// A tap makes the title semibold and opens a card behind it: due day and list, notes, ✓ at the top
/// right, Open ↗. A tap anywhere on the open row, away from its buttons and links, closes it.
struct TodoRow: View {
    var todo: TodoEntry
    var note: String?
    var dueLine: String
    var isChecked: Bool
    var isOpen: Bool
    var onTap: () -> Void
    var check: () -> Void
    var open: () -> Void

    @Environment(\.swipeGuard) private var swipeGuard
    @Environment(\.swipeProgress) private var swipeProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A swipe let go near where it began is ignored, not taken as a tap.
            Button {
                guard swipeGuard?.takesTap() != true else { return }
                onTap()
            } label: {
                title
                    .font(AgendaMetrics.itemFont.weight(isOpen ? .semibold : .regular))
                    // Regular to semibold is an instant change, never animated.
                    .animation(nil, value: isOpen)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The tap area reaches into the space between rows.
                    .padding(.vertical, AgendaMetrics.rowPadding)
                    .contentShape(Rectangle())
            }
            .buttonStyle(StillButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(note.map { "\(todo.title), \($0)" } ?? todo.title)
            .accessibilityValue(isChecked ? "Checked off" : "")
            .accessibilityHint(isOpen ? "Shows less" : "Shows details")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Check off", check)

            if isOpen {
                card
            }
        }
        // One card holds the row and its details, so nothing moves when it opens.
        .openCard(isOpen)
        // A tap anywhere on the open row, away from its buttons and links, closes it.
        .contentShape(Rectangle())
        .onTapGesture {
            guard isOpen, swipeGuard?.takesTap() != true else { return }
            onTap()
        }
        .padding(.bottom, isOpen ? 6 : 0)
    }

    /// The strike draws when checked from the card, or follows the finger during a swipe.
    private var strike: Double { isChecked ? 1 : swipeProgress }

    private var title: some View {
        var text = Text(todo.title)
        if let note {
            // Once struck, the note goes the same gray as the title.
            let noteText = Text("  \(note)").foregroundStyle(strike >= 1 ? Theme.past : Theme.secondary)
            text = Text("\(text)\(noteText)")
        }
        return text
            .textRenderer(StrikeRenderer(progress: strike, color: Theme.itemInk))
            .foregroundStyle(strike >= 1 ? Theme.past : Theme.itemInk)
            // Checking from the card draws the strike left to right; undoing clears it at once.
            .animation(isChecked && !reduceMotion ? .easeOut(duration: 0.35) : nil, value: isChecked)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    if !dueLine.isEmpty {
                        Text(dueLine)
                            .foregroundStyle(Theme.secondary)
                    }
                    if let notes = todo.notes {
                        Text(notes)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // ✓ sits at the top right, where it is on a News card.
                RibbonButton(systemImage: "checkmark", label: "Check off", action: check)
                    .disabled(isChecked)
                    .padding(.top, -6)
                    .padding(.trailing, -RibbonButton.gap)
            }
            TextLink("Open ↗", action: open)
                .accessibilityLabel("Open in Reminders")
                .padding(.top, 4)
        }
        .font(AgendaMetrics.itemFont)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }
}

#Preview {
    @Previewable @State var model = AgendaModel(source: SampleAgendaSource())
    ScrollView {
        TodosSectionView(model: model)
            .padding(.vertical, Theme.margin)
    }
    .task { await model.reload() }
}
