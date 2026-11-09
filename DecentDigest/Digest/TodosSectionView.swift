import DigestCore
import SwiftUI

/// Open reminders due today or earlier, then ones with no date, read live from Reminders.
/// Tapping the dash checks a to-do off in Reminders with a hand-drawn strike; it stays a few
/// seconds so a second tap can undo, then leaves the list.
struct TodosSectionView: View {
    var model: AgendaModel
    var hide: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var expandedIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.titleToList - TodoRow.verticalPadding) {
            SectionHeader(title: DigestSection.todos.title) {
                if model.remindersAccess == .granted {
                    TextLink("Reminders ↗") { openURL(AgendaLinks.reminders) }
                        .accessibilityLabel("Open Reminders")
                }
            }

            if model.remindersAccess == .granted {
                list
            } else {
                AccessNote(
                    access: model.remindersAccess,
                    appName: "Reminders",
                    shows: "your to-dos",
                    request: { await model.requestRemindersAccess() },
                    hide: hide
                )
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.todos.isEmpty && model.hasLoaded {
                QuietLine("Nothing to do today.")
            }
            ForEach(model.todos) { todo in
                TodoRow(
                    todo: todo,
                    detail: TodoRules.detail(for: todo, now: .now),
                    isChecked: model.checkedIDs.contains(todo.id),
                    isExpanded: expandedIDs.contains(todo.id),
                    toggle: { model.toggle(todo) },
                    onTap: {
                        if expandedIDs.remove(todo.id) == nil {
                            expandedIDs.insert(todo.id)
                        }
                    },
                    open: { open(todo) }
                )
                // A to-do that leaves is gone at once; one that joins fades in after the slide.
                .transition(HeadlineMotion.transition)
            }
            if let problem = model.problem {
                Text(problem)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 4)
            }
        }
        // The rows below slide up briefly to close the gap a checked-off to-do leaves.
        .animation(HeadlineMotion.close, value: model.todos.map(\.id))
        // The app's one haptic: a light tap when a to-do is checked off.
        .sensoryFeedback(.impact(weight: .light), trigger: model.checkedIDs) { old, new in
            new.count > old.count
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

/// A to-do: a gray dash that checks it off, the title, and its list (with the time when due at a time today).
/// A tap on the title shows the due day and notes, with Check off and Open in Reminders.
struct TodoRow: View {
    static let verticalPadding: CGFloat = 5

    var todo: TodoEntry
    var detail: String
    var isChecked: Bool
    var isExpanded: Bool
    var toggle: () -> Void
    var onTap: () -> Void
    var open: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                dash
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(todo.title)
                            .textRenderer(StrikeRenderer(progress: isChecked ? 1 : 0, color: Theme.ink))
                            .foregroundStyle(isChecked ? Theme.secondary : Theme.ink)
                            // The strike draws left to right when checked; undoing clears it at once.
                            .animation(isChecked && !reduceMotion ? .easeOut(duration: 0.35) : nil, value: isChecked)
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Self.verticalPadding)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StillButtonStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(detail.isEmpty ? todo.title : "\(todo.title), \(detail)")
                .accessibilityValue(isChecked ? "Checked off" : "")
                .accessibilityHint(isExpanded ? "Shows less" : "Shows details")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: isChecked ? "Undo check off" : "Check off", toggle)
            }

            if isExpanded {
                details
                    .padding(.leading, DashColumn.width)
                    .padding(.bottom, 6)
            }
        }
    }

    /// The dash is the checkbox. Its tap area reaches into the margin so it is easy to hit.
    private var dash: some View {
        Button(action: toggle) {
            Text("–")
                .foregroundStyle(Theme.secondary)
                .frame(width: DashColumn.width, alignment: .leading)
                .padding(.leading, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(StillButtonStyle())
        .padding(.leading, -20)
        .padding(.vertical, -12 + Self.verticalPadding)
        .accessibilityLabel(isChecked ? "Undo check off" : "Check off")
        .accessibilityValue(todo.title)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let due = dueText {
                Text(due)
                    .font(.callout)
                    .foregroundStyle(Theme.secondary)
            }
            if let notes = todo.notes {
                Text(PostKind.clipForRow(notes))
                    .font(.callout)
            }
            HStack(spacing: 16) {
                TextLink(isChecked ? "Undo" : "Check off", action: toggle)
                    .accessibilityLabel(isChecked ? "Undo check off" : "Check off")
                TextLink("Open in Reminders ↗", action: open)
                    .accessibilityLabel("Open in Reminders")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The due day, plainly. An earlier day is just a date, never "overdue".
    private var dueText: String? {
        guard let due = todo.due else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(due) {
            return todo.dueIncludesTime ? nil : "Due today"
        }
        let day = due.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return todo.dueIncludesTime ? "Due \(day), \(due.formatted(date: .omitted, time: .shortened))" : "Due \(day)"
    }
}

#Preview {
    @Previewable @State var model = AgendaModel(source: SampleAgendaSource())
    ScrollView {
        TodosSectionView(model: model, hide: {})
            .padding(Theme.margin)
    }
    .task { await model.reload() }
}
