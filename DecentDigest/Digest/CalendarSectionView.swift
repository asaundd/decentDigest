import DigestCore
import SwiftUI

/// The week ahead from the calendars the reader keeps on the page, read live, as a bulleted list of days.
/// All of today shows, past events gray and struck; the next day shows at least its first event;
/// later days fill in up to the limit. Nothing here is stored.
struct CalendarSectionView: View {
    var model: AgendaModel

    @Environment(\.openURL) private var openURL
    @State private var expandedDays: Set<Date> = []
    @State private var showsAll = false
    @State private var openIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.titleToFirstItem - DayHeader.firstTopPadding) {
            SectionHeader(title: DigestSection.calendar.title) {
                if model.calendarAccess == .granted {
                    TextLink("Calendar ↗") { openURL(AgendaLinks.calendar(at: .now)) }
                        .accessibilityLabel("Open Calendar")
                }
            }

            // The digest shows this section only once Calendar access is on.
            if model.calendarAccess == .granted {
                // Redrawn each minute, so past and happening-now events change on their own.
                TimelineView(.everyMinute) { context in
                    days(now: context.date)
                }
            }
        }
    }

    @ViewBuilder
    private func days(now: Date) -> some View {
        let groups = CalendarAgenda.plan(model.events, now: now, expanded: expandedDays, showAll: showsAll)
        let shown = groups.filter { !$0.items.isEmpty }
        let todayStart = Calendar.current.startOfDay(for: now)
        VStack(alignment: .leading, spacing: 0) {
            if shown.first?.day != todayStart {
                DayHeader(title: "Today", isFirst: true)
                if model.hasLoaded {
                    Text("Nothing on the calendar today.")
                        .font(AgendaMetrics.itemFont)
                        .foregroundStyle(Theme.secondary)
                        .padding(.leading, DashColumn.width)
                }
            }
            ForEach(shown) { group in
                DayHeader(
                    title: AgendaFormat.dayName(group.day, now: now),
                    isFirst: group.day == todayStart
                )
                ForEach(group.items) { event in
                    EventRow(
                        event: event,
                        timing: CalendarAgenda.timing(of: event, now: now),
                        now: now,
                        isOpen: openIDs.contains(event.id),
                        onTap: { toggle(event.id) },
                        open: { openURL(AgendaLinks.calendar(at: event.entry.start)) },
                        directions: directionsAction(for: event.entry)
                    )
                    .padding(.leading, DashColumn.width)
                }
                if group.hiddenCount > 0 {
                    MoreLine(count: group.hiddenCount, noun: "event", leading: DashColumn.width + EventRow.timeWidth) {
                        expandedDays.insert(group.day)
                    }
                }
            }
            if model.hasLoaded {
                AgendaFooter(
                    hidden: DayPlanner.hiddenCount(groups),
                    phrase: { $0 == 1 ? "more event this week" : "more events this week" },
                    empty: "No other events this week",
                    showsAll: showsAll
                ) {
                    showsAll.toggle()
                    if !showsAll { expandedDays = [] }
                }
            }
        }
    }

    private func directionsAction(for entry: CalendarEntry) -> (() -> Void)? {
        guard let point = entry.mapPoint, let url = AgendaLinks.directions(to: point) else { return nil }
        return { openURL(url) }
    }

    private func toggle(_ id: String) {
        if openIDs.remove(id) == nil {
            openIDs.insert(id)
        }
    }
}

/// An event: time in a 60pt gray column, then its name. Past events are gray and struck; one happening
/// now has a thin slate line at its left. A tap makes the row semibold and opens a card with the details;
/// a tap on the row or the card closes it.
struct EventRow: View {
    static let timeWidth: CGFloat = 60

    var event: AgendaEvent
    var timing: EventTiming
    var now: Date
    var isOpen: Bool
    var onTap: () -> Void
    var open: () -> Void
    /// Present when the place is an address.
    var directions: (() -> Void)?

    @ScaledMetric(relativeTo: .subheadline) private var timeWidth: CGFloat = EventRow.timeWidth
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At the largest text sizes the time sits above the title instead of beside it.
    private var stacks: Bool { typeSize.isAccessibilitySize }

    private var isPast: Bool { timing == .past }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                let layout = stacks
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 0))
                layout {
                    Text(AgendaFormat.timeColumn(event.label))
                        .monospacedDigit()
                        .foregroundStyle(isPast ? Theme.past : (isOpen ? Theme.itemInk : Theme.secondary))
                        .frame(width: stacks ? nil : timeWidth, alignment: .leading)
                    Text(event.entry.title)
                        .foregroundStyle(isPast ? Theme.past : Theme.itemInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(AgendaMetrics.itemFont.weight(isOpen ? .semibold : .regular))
                // Regular to semibold is an instant change, never animated.
                .animation(nil, value: isOpen)
                .strikethrough(isPast, color: Theme.past)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(StillButtonStyle())
            // The event happening now gets a thin slate line at the left of its row.
            .overlay(alignment: .leading) {
                if timing == .now {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 2)
                        .offset(x: -AgendaMetrics.cardInset)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
            .accessibilityHint(isOpen ? "Shows less" : "Shows details")
            .accessibilityAddTraits(.isButton)

            if isOpen {
                card
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(lengthLine)
                // A long place, such as a meeting link, stays on one line.
                if let place = AgendaFormat.oneLinePlace(event.entry.location) {
                    Text(place)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if let people = AgendaFormat.people(event.entry.attendees) {
                    Text(people)
                }
                if !hasMore {
                    Text("No other details")
                }
            }
            .foregroundStyle(Theme.secondary)

            if let notes = AgendaFormat.notesWithoutCallLinks(event.entry.notes) {
                Text(notes)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .padding(.top, 6)
            }

            HStack(spacing: 12) {
                TextLink("Open ↗", action: open)
                    .accessibilityLabel("Open in Calendar")
                if let directions {
                    TextLink("Directions ↗", action: directions)
                        .accessibilityLabel("Directions in Maps")
                }
            }
            .padding(.top, 4)
        }
        .font(AgendaMetrics.itemFont)
        .agendaCard()
        // A tap on the card, away from its links, closes it.
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var hasMore: Bool {
        event.entry.location != nil
            || !event.entry.attendees.isEmpty
            || AgendaFormat.notesWithoutCallLinks(event.entry.notes) != nil
    }

    /// "45 minutes", or for an event happening now "45 minutes · ends 2:00p".
    private var lengthLine: String {
        let length = AgendaFormat.length(of: event.entry)
        guard timing == .now else { return length }
        return "\(length) · ends \(AgendaFormat.shortTime(event.entry.end))"
    }

    private var spokenLabel: String {
        let time: String
        switch event.label {
        case .allDay: time = "All day"
        case .starts(let start): time = start.formatted(date: .omitted, time: .shortened)
        case .until(let end): time = "Until \(end.formatted(date: .omitted, time: .shortened))"
        }
        let state = switch timing {
        case .past: ", ended"
        case .now: ", happening now"
        case .upcoming: ""
        }
        return "\(time), \(event.entry.title)\(state)"
    }
}

#Preview {
    @Previewable @State var model = AgendaModel(source: SampleAgendaSource())
    ScrollView {
        CalendarSectionView(model: model)
            .padding(Theme.margin)
    }
    .task { await model.reload() }
}
