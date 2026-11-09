import DigestCore
import SwiftUI

/// Today's events from every calendar on the phone, read live. "This week" adds the days ahead.
/// Events that have ended leave the list; nothing here is stored.
struct CalendarSectionView: View {
    var model: AgendaModel
    var hide: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var showsWeek = false
    @State private var expandedIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.titleToList - EventRow.verticalPadding) {
            SectionHeader(title: DigestSection.calendar.title) {
                if model.calendarAccess == .granted {
                    TextLink(showsWeek ? "Today only" : "This week") {
                        showsWeek.toggle()
                    }
                    .accessibilityHint(showsWeek ? "Shows only today's events" : "Adds the next six days")
                }
            }

            if model.calendarAccess == .granted {
                // Redrawn each minute, so finished events leave on their own.
                TimelineView(.everyMinute) { context in
                    agenda(now: context.date)
                }
            } else {
                AccessNote(
                    access: model.calendarAccess,
                    appName: "Calendar",
                    shows: "today's events",
                    request: { await model.requestCalendarAccess() },
                    hide: hide
                )
            }
        }
    }

    @ViewBuilder
    private func agenda(now: Date) -> some View {
        let today = CalendarAgenda.today(model.events, now: now)
        VStack(alignment: .leading, spacing: 0) {
            if today.isEmpty && model.hasLoaded {
                QuietLine("Nothing on the calendar today.")
            }
            ForEach(today) { event in
                row(event)
            }

            if showsWeek {
                let week = CalendarAgenda.restOfWeek(model.events, now: now)
                if week.isEmpty {
                    QuietLine("Nothing else this week.")
                        .padding(.top, 8)
                }
                ForEach(week) { day in
                    Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 12)
                        .padding(.bottom, 2)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(day.events) { event in
                        row(event)
                    }
                }
            }
        }
    }

    private func row(_ event: AgendaEvent) -> some View {
        EventRow(
            event: event,
            isExpanded: expandedIDs.contains(event.id),
            onTap: {
                if expandedIDs.remove(event.id) == nil {
                    expandedIDs.insert(event.id)
                }
            },
            openInCalendar: { openURL(AgendaLinks.calendar(at: event.entry.start)) }
        )
    }
}

/// An event: time in a fixed gray column, then the title over its calendar's name. No marker.
/// A tap shows when it ends, where it is, and a link to Calendar.
struct EventRow: View {
    static let verticalPadding: CGFloat = 5

    var event: AgendaEvent
    var isExpanded: Bool
    var onTap: () -> Void
    var openInCalendar: () -> Void

    /// The time column, so titles line up.
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = 96
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At the largest text sizes the time sits above the title instead of beside it.
    private var stacks: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                let layout = stacks
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                layout {
                    Text(timeText)
                        .foregroundStyle(Theme.secondary)
                        .monospacedDigit()
                        .frame(width: stacks ? nil : timeWidth, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.entry.title)
                        if !event.entry.calendarName.isEmpty {
                            Text(event.entry.calendarName)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, Self.verticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(StillButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
            .accessibilityHint(isExpanded ? "Shows less" : "Shows details")
            .accessibilityAddTraits(.isButton)

            if isExpanded {
                details
                    .padding(.leading, stacks ? 0 : timeWidth + 8)
                    .padding(.bottom, 6)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rangeText)
                .font(.callout)
                .foregroundStyle(Theme.secondary)
            if let location = event.entry.location {
                Text(location)
                    .font(.callout)
            }
            TextLink("Open in Calendar ↗", action: openInCalendar)
                .accessibilityLabel("Open in Calendar")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeText: String {
        switch event.label {
        case .allDay: "All day"
        case .starts(let start): start.formatted(date: .omitted, time: .shortened)
        case .until(let end): "Until \(end.formatted(date: .omitted, time: .shortened))"
        }
    }

    /// When it runs, in full: "10:00 AM – 11:00 AM", with days when it spans more than one.
    private var rangeText: String {
        let entry = event.entry
        let calendar = Calendar.current
        if entry.isAllDay {
            // EventKit ends an all-day event at the start of the next day.
            let lastDay = calendar.date(byAdding: .second, value: -1, to: entry.end) ?? entry.end
            if calendar.isDate(entry.start, inSameDayAs: lastDay) { return "All day" }
            let format = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
            return "All day, \(entry.start.formatted(format)) – \(lastDay.formatted(format))"
        }
        if calendar.isDate(entry.start, inSameDayAs: entry.end) {
            return "\(entry.start.formatted(date: .omitted, time: .shortened)) – \(entry.end.formatted(date: .omitted, time: .shortened))"
        }
        let format = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
        return "\(entry.start.formatted(format)) – \(entry.end.formatted(format))"
    }

    private var spokenLabel: String {
        let home = event.entry.calendarName.isEmpty ? "" : ", \(event.entry.calendarName) calendar"
        return "\(timeText), \(event.entry.title)\(home)"
    }
}

#Preview {
    @Previewable @State var model = AgendaModel(source: SampleAgendaSource())
    ScrollView {
        CalendarSectionView(model: model, hide: {})
            .padding(Theme.margin)
    }
    .task { await model.reload() }
}
