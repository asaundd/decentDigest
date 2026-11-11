import DigestCore
import SwiftUI

/// What a headline or episode row shows and can do. Used by News, Podcasts and Saved.
struct Headline: Identifiable {
    var id: String
    var title: String
    /// Feed name and age, e.g. "STAT · 2 hr", or a show's name.
    var detail: String
    var author: String?
    var summary: String?
    var fullText: String?
    var link: URL?
    var isUnread: Bool
    /// True for a podcast episode: its text is show notes, and Open ↗ opens Podcasts.
    var isEpisode = false
    /// An episode's length, e.g. "58 min". It takes the byline's place on the card.
    var episodeLength: String?

    var kind: PostKind {
        PostKind.classify(summary: summary, fullText: fullText)
    }

    /// The whole post is in the feed.
    var readsHere: Bool { !isEpisode && kind == .fullPost }

    /// Full posts, excerpts and long show notes open in the panel; summaries and link-only rows go to the site.
    var opensPanel: Bool {
        if isEpisode { return (notes?.count ?? 0) > PostKind.rowTextLimit }
        return kind == .fullPost || kind == .excerpt
    }

    /// The ribbon's label for opening the panel. It also says what the feed sent.
    var readLabel: String {
        if isEpisode { return "Read notes" }
        return readsHere ? "Read full post" : "Read excerpt"
    }

    /// Only title-only headlines carry a marker: ↗ says reading it means going to the site.
    var marker: String? {
        !isEpisode && kind == .titleOnly ? "↗" : nil
    }

    /// An episode's show notes: the longest text the feed sent.
    private var notes: String? {
        PostKind.previewText(summary: summary, fullText: fullText)
    }

    /// The summary for full posts, otherwise the longest text the feed sent.
    private var previewText: String? {
        readsHere ? summary : PostKind.previewText(summary: summary, fullText: fullText)
    }

    /// What the expanded row shows, clipped so the action ribbon stays close.
    var expandedText: String? {
        previewText.map { PostKind.clipForRow($0) }
    }

    /// What the panel shows: the full post, the whole excerpt or all the show notes.
    var panelText: String? {
        readsHere ? fullText : previewText
    }

    /// The top line of the card: "By Jane Doe", or an episode's length.
    var byline: String? {
        if isEpisode { return episodeLength }
        return author.map { "By \($0)" }
    }
}

/// The actions a headline offers. A nil action is left out.
struct HeadlineActions {
    var save: (() -> Void)?
    var useful: () -> Void
    var notUseful: () -> Void
    /// Opens the panel. When present it is the ribbon's first action.
    var readFull: (() -> Void)?
    /// Open ↗: the site in the browser, or an episode in Podcasts.
    var open: (() -> Void)?
    /// "Read full post", "Read excerpt" or "Read notes".
    var readLabel = "Read full post"
    /// What VoiceOver says for Open ↗.
    var openLabel = "Open the site"
}

/// One headline or episode: gray dash, title (semibold while unread, regular once opened), then the
/// feed name and age, or the show's name.
/// Title-only rows end in ↗. A tap expands any row: under the title, a lighter card holds the byline
/// and up to 320 characters of text over a ribbon of actions. Another tap, on the title or the card, closes it.
struct HeadlineRow: View {
    static let verticalPadding: CGFloat = 5
    /// How far the open card reaches past the text on the right. On the left it starts under the dash,
    /// so it reads as indented under its title.
    static let cardInset: CGFloat = 12

    var headline: Headline
    var isExpanded: Bool
    var actions: HeadlineActions
    /// Reports where the expanded row ends on screen, so the list can scroll it into view.
    var onExpandedBottom: ((CGFloat) -> Void)? = nil
    var onTap: () -> Void

    @Environment(\.swipeGuard) private var swipeGuard
    @Environment(\.swipeProgress) private var swipeProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A swipe let go near where it began is ignored, not taken as a tap.
            Button {
                guard swipeGuard?.justSwiped != true else { return }
                onTap()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("–")
                        .foregroundStyle(Theme.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline.title)
                            .fontWeight(headline.isUnread ? .semibold : .regular)
                            // Bold to regular is an instant change, never animated.
                            .animation(nil, value: headline.isUnread)
                            // A swipe strikes the title through; once far enough to act, it goes gray.
                            .textRenderer(StrikeRenderer(progress: swipeProgress, color: Theme.ink))
                            .foregroundStyle(swipeProgress >= 1 ? Theme.secondary : Theme.ink)
                        Text(headline.detail)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let marker = headline.marker {
                        Text(marker)
                            .foregroundStyle(Theme.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, Self.verticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(StillButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(headline.title), \(headline.detail)")
            .accessibilityValue(Text(headline.isUnread ? "Unread" : "Read"))
            .accessibilityHint(Text(isExpanded ? "Shows less" : "Shows details and actions"))
            .accessibilityAddTraits(.isButton)
            .accessibilityActions {
                if let save = actions.save {
                    Button("Save", action: save)
                }
            }

            if isExpanded {
                // Only the details sit on the card, so the title stays where it was.
                expandedDetail
                    .padding(.top, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.expandedFill)
                            .shadow(color: Theme.expandedShadow, radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Theme.expandedRing, lineWidth: 1)
                            )
                            .padding(.trailing, -Self.cardInset)
                    }
                    .padding(.top, 2)
                    // A tap anywhere on the card, away from its buttons and links, closes it like a tap on the title.
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard swipeGuard?.justSwiped != true else { return }
                        onTap()
                    }
                    .padding(.bottom, 10)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).maxY
        } action: { bottom in
            if isExpanded { onExpandedBottom?(bottom) }
        }
    }

    private var noSummary: some View {
        Text("No summary available.")
            .font(.callout)
            .italic()
            .foregroundStyle(Theme.secondary)
    }

    /// The card: byline with Save, ✓ and ✕ at the top right where the thumb is, then the text,
    /// then the way to read it.
    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                // Link-only rows put their note on this line; others put the byline here.
                if headline.expandedText == nil {
                    noSummary
                } else if let byline = headline.byline {
                    Text(byline)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
                JudgmentButtons(actions: actions)
            }
            .padding(.leading, DashColumn.width)
            .padding(.trailing, -RibbonButton.gap)

            Group {
                if let text = headline.expandedText {
                    if let readFull = actions.readFull {
                        // Tapping the text opens the rest in the panel.
                        Button {
                            guard swipeGuard?.justSwiped != true else { return }
                            readFull()
                        } label: {
                            Text(text)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(StillButtonStyle())
                        .accessibilityHint("Opens the rest in a panel")
                    } else {
                        Text(text)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if let byline = headline.byline {
                    Text(byline)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
            }
            // Line up with the title, past the dash column.
            .padding(.horizontal, DashColumn.width)

            HStack(spacing: 16) {
                ActionLinks(actions: actions)
            }
            .padding(.leading, DashColumn.width)
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
    }
}

/// The actions pinned at the bottom of the panel: the way to read it first, then small square
/// buttons for Save, ✓ (useful) and ✕ (not useful).
struct ActionRibbon: View {
    var actions: HeadlineActions
    /// Space before the first action.
    var leadingPadding: CGFloat
    /// Space after the last button.
    var trailingPadding: CGFloat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                ActionLinks(actions: actions)
                Spacer(minLength: 0)
                JudgmentButtons(actions: actions)
            }
            // At large text sizes the links sit above the buttons.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) { ActionLinks(actions: actions) }
                HStack {
                    Spacer(minLength: 0)
                    JudgmentButtons(actions: actions)
                }
            }
        }
        .padding(.vertical, 1)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding - RibbonButton.gap)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The text actions: read in the panel first when the post opens there, then Open ↗.
struct ActionLinks: View {
    var actions: HeadlineActions

    var body: some View {
        if let readFull = actions.readFull {
            TextLink(actions.readLabel, action: readFull)
        }
        if let open = actions.open {
            TextLink("Open ↗", action: open)
                .accessibilityLabel(actions.openLabel)
        }
    }
}

/// Small square buttons for Save (when offered), ✓ (useful) and ✕ (not useful).
struct JudgmentButtons: View {
    var actions: HeadlineActions

    var body: some View {
        HStack(spacing: 0) {
            if let save = actions.save {
                RibbonButton(systemImage: "bookmark", label: "Save", action: save)
            }
            RibbonButton(systemImage: "checkmark", label: "Relevant", action: actions.useful)
            RibbonButton(systemImage: "xmark", label: "Not relevant", action: actions.notUseful)
        }
    }
}

/// A small square symbol button on the ribbon, a shade darker than the card, with a larger tap target and a spoken label.
struct RibbonButton: View {
    /// Half the space between two squares.
    static let gap: CGFloat = 3

    var systemImage: String
    var label: String
    var action: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var width: CGFloat = 32
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 28

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Theme.ribbonIconFont)
                .foregroundStyle(Theme.ink)
                .frame(width: width, height: height)
                .background(Theme.ribbonButtonFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.horizontal, Self.gap)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}

/// A button that doesn't dim while pressed, so a headline keeps its color until it is read.
struct StillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// How headlines leave and join the list.
@MainActor
enum HeadlineMotion {
    /// The rows below slide up to close the gap a row leaves.
    static let close = Animation.easeOut(duration: 0.2)
    /// Leaving is instant; joining fades in after the slide has finished.
    static let transition = AnyTransition.asymmetric(
        insertion: .opacity.animation(.easeOut(duration: 0.15).delay(0.2)),
        removal: .identity
    )
}

/// The width of the gray dash plus its gap, so expanded text lines up with titles.
enum DashColumn {
    static let width: CGFloat = 16
}

/// An action shown as a plain link: slate, semibold, underlined. No outline or fill.
struct TextLink: View {
    var title: String
    /// True for a link whose label changes when tapped (Show week / Show less): it skips the
    /// pressed dimming, which otherwise fades back in on the new label.
    var still = false
    var action: () -> Void

    init(_ title: String, still: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.still = still
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.actionFont)
                .underline()
                .foregroundStyle(Theme.accent)
                .fixedSize()
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(LinkButtonStyle(still: still))
    }
}

/// The borderless look, optionally without the pressed dimming.
private struct LinkButtonStyle: PrimitiveButtonStyle {
    var still: Bool

    func makeBody(configuration: Configuration) -> some View {
        if still {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(StillButtonStyle())
        } else {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(.borderless)
        }
    }
}
