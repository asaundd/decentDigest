import DigestCore
import SwiftUI

/// Open reminders, read live, grouped by day like Calendar, then Anytime for those with no date.
/// A to-do is checked off with the ✓ on its card or by swiping its row right; either writes back to Reminders.
struct TodosSectionView: View {
    var model: AgendaModel

    @Environment(\.openURL) private var openURL
    @State private var expandedDays: Set<Date> = []
    @State private var anytimeExpanded = false
    @State private var showsAll = false
    @State private var openIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: DigestSection.todos.title) {
                if model.remindersAccess == .granted {
                    TextLink("Reminders ↗") { openURL(AgendaLinks.reminders) }
                        .accessibilityLabel("Open Reminders")
                }
            }
            .padding(.bottom, Theme.titleToList)
            .digestRow()

            if model.remindersAccess == .granted {
                list(now: .now)
            } else {
                AccessNote(
                    appName: "Reminders",
                    shows: "your to-dos",
                    request: { await model.requestRemindersAccess() }
                )
                .digestRow()
            }
        }
    }

    private func list(now: Date) -> some View {
        let plan = TodoRules.plan(model.todos, now: now, expanded: expandedDays, anytimeExpanded: anytimeExpanded, showAll: showsAll)
        let days = plan.days.filter { !$0.items.isEmpty }
        return VStack(alignment: .leading, spacing: 0) {
            if days.isEmpty && plan.anytime.isEmpty && model.hasLoaded {
                QuietLine("Nothing to do.")
                    .digestRow()
            }
            ForEach(days) { group in
                DayHeader(title: AgendaFormat.dayName(group.day, now: now), isFirst: group.id == days.first?.id)
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
                DayHeader(title: "Anytime", isFirst: days.isEmpty)
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
            if model.hasLoaded && !(days.isEmpty && plan.anytime.isEmpty) {
                AgendaFooter(
                    hidden: plan.hiddenCount,
                    phrase: { $0 == 1 ? "more item" : "more items" },
                    empty: "No other items this week",
                    showsAll: showsAll
                ) {
                    showsAll.toggle()
                    if !showsAll {
                        expandedDays = []
                        anytimeExpanded = false
                    }
                }
                .digestRow()
            }
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

    private func row(_ todo: TodoEntry, now: Date) -> some View {
        TodoRow(
            todo: todo,
            note: TodoRules.note(for: todo, now: now),
            dueLine: AgendaFormat.dueLine(for: todo, now: now),
            isChecked: model.checkedIDs.contains(todo.id),
            isOpen: openIDs.contains(todo.id),
            onTap: { tap(todo) },
            toggleCheck: { toggleCheck(todo) },
            open: { open(todo) }
        )
        // Rows are full width so a swipe can draw its label at the page's edge.
        .padding(.leading, Theme.margin + DashColumn.width)
        .padding(.trailing, Theme.margin)
        .id(todo.id)
        // A to-do that leaves is gone at once; one that joins fades in after the slide.
        .transition(HeadlineMotion.transition)
        .checkOffSwipe { swipeCheck(todo) }
    }

    // MARK: Actions

    /// Opens or closes a to-do's card. A checked-off to-do leaves when its card closes.
    private func tap(_ todo: TodoEntry) {
        if openIDs.remove(todo.id) == nil {
            openIDs.insert(todo.id)
        } else if model.checkedIDs.contains(todo.id) {
            withAnimation(HeadlineMotion.close) {
                model.finishChecking(todo.id)
            }
        }
    }

    /// The ✓ on the card checks off; once checked it is the undo arrow.
    private func toggleCheck(_ todo: TodoEntry) {
        if model.checkedIDs.contains(todo.id) {
            model.uncheck(todo)
        } else {
            model.check(todo)
        }
    }

    /// A swipe checks the to-do off and it leaves at once.
    private func swipeCheck(_ todo: TodoEntry) {
        guard model.check(todo) else { return }
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

/// A to-do: its title, with "Past due" (or today's time) in gray after it.
/// A tap makes the title semibold and opens a card: due day and list, notes, ✓ at the top right, Open ↗.
/// A tap on the title or the card closes it.
struct TodoRow: View {
    var todo: TodoEntry
    var note: String?
    var dueLine: String
    var isChecked: Bool
    var isOpen: Bool
    var onTap: () -> Void
    var toggleCheck: () -> Void
    var open: () -> Void

    @Environment(\.swipeGuard) private var swipeGuard
    @Environment(\.swipeProgress) private var swipeProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A swipe let go near where it began is ignored, not taken as a tap.
            Button {
                guard swipeGuard?.justSwiped != true else { return }
                onTap()
            } label: {
                title
                    .font(AgendaMetrics.itemFont.weight(isOpen ? .semibold : .regular))
                    // Regular to semibold is an instant change, never animated.
                    .animation(nil, value: isOpen)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(StillButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(note.map { "\(todo.title), \($0)" } ?? todo.title)
            .accessibilityValue(isChecked ? "Checked off" : "")
            .accessibilityHint(isOpen ? "Shows less" : "Shows details")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: isChecked ? "Undo check off" : "Check off", toggleCheck)

            if isOpen {
                card
            }
        }
    }

    /// The strike draws when checked from the card, or follows the finger during a swipe.
    private var strike: Double { isChecked ? 1 : swipeProgress }

    private var title: some View {
        var text = Text(todo.title)
        if let note {
            // Once struck, the note goes the same gray as the title.
            text = text + Text("  \(note)").foregroundStyle(strike >= 1 ? Theme.past : Theme.secondary)
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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // ✓ sits at the top right, where it is on a News card. Once checked it is the undo arrow.
                RibbonButton(
                    systemImage: isChecked ? "arrow.uturn.backward" : "checkmark",
                    label: isChecked ? "Undo check off" : "Check off",
                    action: toggleCheck
                )
                .padding(.top, -8)
                .padding(.trailing, -RibbonButton.gap - 4)
            }
            TextLink("Open ↗", action: open)
                .accessibilityLabel("Open in Reminders")
                .padding(.top, 4)
        }
        .font(AgendaMetrics.itemFont)
        .agendaCard()
        // A tap on the card, away from its buttons, closes it like a tap on the title.
        .contentShape(Rectangle())
        .onTapGesture {
            guard swipeGuard?.justSwiped != true else { return }
            onTap()
        }
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
