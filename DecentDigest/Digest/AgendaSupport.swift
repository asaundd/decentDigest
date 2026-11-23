import DigestCore
import SwiftUI

/// Links that hand off to Calendar and Reminders.
enum AgendaLinks {
    /// Opens Calendar at the event's day and time.
    static func calendar(at date: Date) -> URL {
        URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)")!
    }

    /// Opens the Reminders app.
    static let reminders = URL(string: "x-apple-reminderkit://")!

    /// Opens one reminder in Reminders. If iOS doesn't take it, open the app instead.
    static func reminder(id: String) -> URL? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard let escaped = id.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "x-apple-reminderkit://REMCDReminder/\(escaped)")
    }

    /// Directions in Maps to an event's place.
    static func directions(to point: MapPoint) -> URL? {
        URL(string: "https://maps.apple.com/?daddr=\(point.latitude),\(point.longitude)")
    }
}

/// Sizes shared by the Calendar and To do lists.
enum AgendaMetrics {
    /// Events and to-dos sit a size below day names.
    static let itemFont = Font.subheadline
    /// Space above and below each event or to-do, which its tap area reaches into.
    static let rowPadding: CGFloat = 4
    /// Space above an open to-do's card, so it doesn't sit against the row or day above.
    static let openCardGap: CGFloat = 6
}

/// A day in the Calendar or To do list: the day's name in semibold, a small label at the margin with
/// no dash, a step under the section title and a step over the items.
/// Days after the first sit a little further from the one above.
struct DayHeader: View {
    static let firstTopPadding: CGFloat = 5

    var title: String
    var isFirst = false

    var body: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, isFirst ? Self.firstTopPadding : 10)
        .padding(.bottom, 1)
        .accessibilityAddTraits(.isHeader)
    }
}

/// "N more events" at the end of a cut-off day: plain gray, no underline. A tap fills in the rest.
struct MoreLine: View {
    var count: Int
    /// "event" or "item".
    var noun: String
    /// Indent, to line up with the titles above.
    var leading: CGFloat = 0
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(count) more \(count == 1 ? noun : noun + "s")")
                .font(AgendaMetrics.itemFont)
                .foregroundStyle(Theme.secondary)
                .padding(.leading, leading)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(StillButtonStyle())
        .accessibilityHint("Shows the rest")
    }
}

/// The line at the foot of a list: quiet links for Show N more or Show less and the app the section
/// comes from, joined by dots: "Show 4 more events · Calendar ↗". Used by Calendar, To do, News,
/// Podcasts and Saved. `text` (a gray lead-in) and `refresh` are still supported but not used.
struct ListFooter: View {
    struct Link {
        var title: String
        /// What VoiceOver says, when it differs from the title.
        var spoken: String?
        var action: () -> Void
    }

    var text: String?
    var toggle: Link?
    var app: Link?
    /// News' Clear all, before Refresh.
    var clear: Link? = nil
    var refresh: Link? = nil
    /// True while the refresh runs: the link gives way to a gray "Refreshing…".
    var isRefreshing = false

    var body: some View {
        // On a narrow screen or at large text sizes the links drop under the text.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { parts }
            VStack(alignment: .leading, spacing: 0) {
                if let text {
                    Text(text)
                        .foregroundStyle(Theme.secondary)
                        .padding(.vertical, 4)
                }
                HStack(spacing: 6) { links }
            }
        }
        // When a link comes or goes ("Show 1 more · Clear all" becoming "Clear all"), the line
        // changes at once: nothing fades out or slides along it. The line itself still moves with
        // the rows above it.
        .animation(nil, value: signature)
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What the line says, so a change to it is never animated.
    private var signature: String {
        [text, toggle?.title, app?.title, clear?.title, refresh?.title, isRefreshing ? "Refreshing…" : nil]
            .map { $0 ?? "" }
            .joined(separator: "|")
    }

    @ViewBuilder
    private var parts: some View {
        if let text {
            Text(text)
                .foregroundStyle(Theme.secondary)
                // "20 more" becomes "19 more" at once, never a crossfade of the two.
                .contentTransition(.identity)
                .fixedSize()
                .padding(.vertical, 4)
            if toggle != nil || app != nil || clear != nil || refresh != nil { dot }
        }
        links
    }

    @ViewBuilder
    private var links: some View {
        if let toggle {
            link(toggle)
            if app != nil || clear != nil || refresh != nil { dot }
        }
        if let app {
            link(app)
            if clear != nil || refresh != nil { dot }
        }
        if let clear {
            link(clear)
            if refresh != nil { dot }
        }
        if let refresh {
            if isRefreshing {
                Text("Refreshing…")
                    .foregroundStyle(Theme.secondary)
                    .fixedSize()
                    .padding(.vertical, 4)
            } else {
                link(refresh)
            }
        }
    }

    private var dot: some View {
        Text("·")
            .foregroundStyle(Theme.secondary)
            .accessibilityHidden(true)
            // A dot that goes with its link is gone at once, never faded.
            .transition(.identity)
    }

    private func link(_ link: Link) -> some View {
        FooterLink(link.title, still: true, action: link.action)
            .accessibilityLabel(link.spoken ?? link.title)
            // Show all and Show less are separate links: the underline never slides from one to the other.
            .id(link.title)
            .transition(.identity)
            .animation(nil, value: link.title)
    }
}

extension ListFooter {
    /// "Show 4 more events" (the count is part of the link) or "Show less", each followed by the
    /// app link. When nothing waits, only the app link shows: the line doesn't say there's nothing
    /// more. `reveals` is how many rows Show adds, for a list that opens only part of the way
    /// (News opens to 25 rows); it defaults to all of them.
    init(hidden: Int, reveals: Int? = nil, phrase: (Int) -> String, showsAll: Bool, app: Link?, clear: Link? = nil, refresh: Link? = nil, isRefreshing: Bool = false, toggle: @escaping () -> Void) {
        if hidden > 0 {
            let count = min(reveals ?? hidden, hidden)
            let title = "Show \(count) \(phrase(count))"
            self.init(text: nil, toggle: Link(title: title, action: toggle), app: app, clear: clear, refresh: refresh, isRefreshing: isRefreshing)
        } else if showsAll {
            self.init(text: nil, toggle: Link(title: "Show less", action: toggle), app: app, clear: clear, refresh: refresh, isRefreshing: isRefreshing)
        } else {
            self.init(text: nil, toggle: nil, app: app, clear: clear, refresh: refresh, isRefreshing: isRefreshing)
        }
    }
}

/// A section's Charter title. Title rows carry no links.
struct SectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(Theme.sectionTitleFont)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One quiet gray line, for an empty section.
struct QuietLine: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(Theme.secondary)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Faint bars standing in for a section's rows while a slow first read finishes. Top to bottom,
/// each bar turns a shade darker and stays so, like a list being written out, slower than the
/// launch logo draws; once the last one has, they all lighten together and it starts again.
/// With Reduce Motion on, the bars stay still.
struct PlaceholderBars: View {
    /// Each bar's share of the line.
    var widths: [CGFloat] = [0.72, 0.48, 0.6]
    var rowHeight: CGFloat = 28
    /// Before this, nothing shows: most reads finish while the launch logo is still on screen.
    var delay: Duration = .milliseconds(600)

    /// Time between one bar darkening and the next.
    static let step: Double = 0.28
    /// How long each bar takes to darken.
    static let darken: Double = 0.25
    /// How long all the bars stay dark once the last one has darkened.
    static let hold: Double = 0.3
    /// How long they take to lighten again, all together.
    static let lighten: Double = 0.3
    /// The rest before the shade starts again at the top.
    static let pause: Double = 0.4

    @State private var shows = false
    @State private var start = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !shows)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                    GeometryReader { proxy in
                        let bar = RoundedRectangle(cornerRadius: 3, style: .continuous)
                        bar.fill(Theme.placeholder)
                            // The passing shade is the rule color laid over the bar.
                            .overlay(bar.fill(Theme.rule).opacity(reduceMotion ? 0 : Self.shade(bar: index, of: widths.count, at: elapsed)))
                            .frame(width: proxy.size.width * width, height: 10)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: rowHeight)
                }
            }
        }
        .opacity(shows ? 1 : 0)
        .task {
            try? await Task.sleep(for: delay)
            start = .now
            shows = true
        }
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }

    /// How dark one bar is `elapsed` seconds into the loop, from 0 (resting) to 1. Each bar darkens
    /// in turn and stays dark until the last one has, then they all lighten together.
    static func shade(bar: Int, of count: Int, at elapsed: TimeInterval) -> Double {
        let allDark = Double(max(count - 1, 0)) * step + darken
        let lightensAt = allDark + hold
        let cycle = lightensAt + lighten + pause
        let local = elapsed.truncatingRemainder(dividingBy: cycle)
        let level: Double
        if local >= lightensAt {
            level = 1 - min((local - lightensAt) / lighten, 1)
        } else {
            level = min(max((local - Double(bar) * step) / darken, 0), 1)
        }
        // Eased, so each change starts and ends gently.
        return level * level * (3 - 2 * level)
    }
}
