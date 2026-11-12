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
}

/// A day in the Calendar or To do list: a gray dash, then the day's name in semibold.
/// Days after the first sit a little further from the one above.
struct DayHeader: View {
    static let firstTopPadding: CGFloat = 5

    var title: String
    var isFirst = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("–")
                .foregroundStyle(Theme.secondary)
                .frame(width: DashColumn.width, alignment: .leading)
                .accessibilityHidden(true)
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

/// The gray line at the foot of a list: what waits ("4 more events this week"), then quiet links for
/// Show all or Show less and the app the section comes from, joined by dots:
/// "4 more events this week · Show all · Calendar ↗". Used by Calendar, To do, News and Podcasts.
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
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var parts: some View {
        if let text {
            Text(text)
                .foregroundStyle(Theme.secondary)
                .fixedSize()
                .padding(.vertical, 4)
            if toggle != nil || app != nil { dot }
        }
        links
    }

    @ViewBuilder
    private var links: some View {
        if let toggle {
            link(toggle)
            if app != nil { dot }
        }
        if let app {
            link(app)
        }
    }

    private var dot: some View {
        Text("·")
            .foregroundStyle(Theme.secondary)
            .accessibilityHidden(true)
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
    /// "4 more events this week · Show all", "Show less", or "No other events this week" when nothing
    /// waits, each followed by the app link.
    init(hidden: Int, phrase: (Int) -> String, empty: String?, showsAll: Bool, app: Link?, toggle: @escaping () -> Void) {
        if hidden > 0 {
            self.init(text: "\(hidden) \(phrase(hidden))", toggle: Link(title: "Show all", action: toggle), app: app)
        } else if showsAll {
            self.init(text: nil, toggle: Link(title: "Show less", action: toggle), app: app)
        } else {
            self.init(text: empty, toggle: nil, app: app)
        }
    }
}

/// A section title with an optional action at the right end of the row.
struct SectionHeader<Action: View>: View {
    var title: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.sectionTitleFont)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            action
        }
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

/// Faint bars standing in for a section's rows while a slow first read finishes. A slightly
/// darker shade passes down the bars, one after another, like a list being written out, slower
/// than the launch logo draws. With Reduce Motion on, the bars stay still.
struct PlaceholderBars: View {
    /// Each bar's share of the line.
    var widths: [CGFloat] = [0.72, 0.48, 0.6]
    var rowHeight: CGFloat = 28
    /// Before this, nothing shows: most reads finish while the launch logo is still on screen.
    var delay: Duration = .milliseconds(600)

    /// Time between one bar darkening and the next.
    static let step: Double = 0.28
    /// How long each bar takes to darken and lighten again.
    static let pulse: Double = 0.7
    /// The rest after the last bar, before the shade starts again at the top.
    static let pause: Double = 0.6

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

    /// How dark one bar is `elapsed` seconds into the loop, from 0 (resting) to 1.
    static func shade(bar: Int, of count: Int, at elapsed: TimeInterval) -> Double {
        let cycle = Double(max(count - 1, 0)) * step + pulse + pause
        let local = elapsed.truncatingRemainder(dividingBy: cycle) - Double(bar) * step
        guard local > 0, local < pulse else { return 0 }
        return sin(.pi * local / pulse)
    }
}
