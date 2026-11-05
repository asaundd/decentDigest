import DigestCore
import SwiftUI

/// What a headline row shows and can do. Used by News and Saved news.
struct Headline: Identifiable {
    var id: String
    var title: String
    /// Feed name and age, e.g. "STAT · 2 hr".
    var detail: String
    var author: String?
    var summary: String?
    var fullText: String?
    var link: URL?
    var isUnread: Bool

    var kind: PostKind {
        PostKind.classify(summary: summary, fullText: fullText)
    }

    /// The whole post is in the feed.
    var readsHere: Bool { kind == .fullPost }

    /// Full posts and excerpts open in the panel; summaries and link-only rows go to the site.
    var opensPanel: Bool { kind == .fullPost || kind == .excerpt }

    /// The ribbon's label for opening the panel. It also says what the feed sent.
    var readLabel: String { readsHere ? "Read full post" : "Read excerpt" }

    /// Only title-only rows carry a marker: ↗ says reading it means going to the site.
    var marker: String? {
        kind == .titleOnly ? "↗" : nil
    }

    /// The summary for full posts, otherwise the longest text the feed sent.
    private var previewText: String? {
        readsHere ? summary : PostKind.previewText(summary: summary, fullText: fullText)
    }

    /// What the expanded row shows, clipped so the action ribbon stays close.
    var expandedText: String? {
        previewText.map { PostKind.clipForRow($0) }
    }

    /// What the panel shows: the full post, or the whole excerpt.
    var panelText: String? {
        readsHere ? fullText : previewText
    }

    var byline: String? {
        author.map { "By \($0)" }
    }
}

/// The actions a headline offers. A nil action is left out.
struct HeadlineActions {
    var save: (() -> Void)?
    var useful: () -> Void
    var notUseful: () -> Void
    /// Opens the panel. When present it is the ribbon's first action.
    var readFull: (() -> Void)?
    var openInSafari: (() -> Void)?
    /// "Read full post" or "Read excerpt".
    var readLabel = "Read full post"
}

/// One headline: gray dash, title (semibold while unread, regular once opened), feed name and age.
/// Title-only rows end in ↗. A tap expands any row: under the title, a lighter card holds the byline
/// and up to 320 characters of text over a ribbon of actions.
struct HeadlineRow: View {
    static let verticalPadding: CGFloat = 5
    /// How far the open card reaches past the text on each side.
    static let cardInset: CGFloat = 12

    var headline: Headline
    var isExpanded: Bool
    var actions: HeadlineActions
    /// Reports where the expanded row ends on screen, so the list can scroll it into view.
    var onExpandedBottom: ((CGFloat) -> Void)? = nil
    var onTap: () -> Void

    @Environment(\.swipeGuard) private var swipeGuard

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
            .buttonStyle(.plain)
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
                    .padding(.top, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.expandedFill)
                            .shadow(color: Theme.expandedShadow, radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Theme.expandedRing, lineWidth: 1)
                            )
                            .padding(.horizontal, -Self.cardInset)
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 10)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).maxY
        } action: { bottom in
            if isExpanded { onExpandedBottom?(bottom) }
        }
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                if let byline = headline.byline {
                    Text(byline)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
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
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the rest in a panel")
                    } else {
                        Text(text)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("No summary available.")
                        .font(.callout)
                        .italic()
                        .foregroundStyle(Theme.secondary)
                }
            }
            // Line up with the title, past the dash column.
            .padding(.leading, DashColumn.width)
            .padding(.trailing, DashColumn.width)

            ActionRibbon(
                actions: actions,
                leadingPadding: Self.cardInset + DashColumn.width,
                trailingPadding: Self.cardInset,
                bleed: Self.cardInset
            )
        }
    }
}

/// The actions under an expanded headline, in the same color as the card: the way to read it first,
/// lined up with the text above, then small square buttons for Save, ✓ (useful) and ✕ (not useful).
struct ActionRibbon: View {
    var actions: HeadlineActions
    /// Space before the first action, so it lines up with the text above it.
    var leadingPadding: CGFloat
    /// Space after the last button.
    var trailingPadding: CGFloat
    /// How far the ribbon runs past its container on each side.
    var bleed: CGFloat = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                links
                Spacer(minLength: 0)
                buttons
            }
            // At large text sizes the links sit above the buttons.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) { links }
                HStack {
                    Spacer(minLength: 0)
                    buttons
                }
            }
        }
        .padding(.vertical, 1)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding - RibbonButton.gap)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, -bleed)
    }

    /// Read in the panel first when the post opens there, otherwise go to the site.
    @ViewBuilder
    private var links: some View {
        if let readFull = actions.readFull {
            TextLink(actions.readLabel, action: readFull)
            if let openInSafari = actions.openInSafari {
                TextLink("Open ↗", action: openInSafari)
                    .accessibilityLabel("Open the site")
            }
        } else if let openInSafari = actions.openInSafari {
            TextLink("Open ↗", action: openInSafari)
                .accessibilityLabel("Open the site")
        }
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            if let save = actions.save {
                RibbonButton(systemImage: "bookmark", label: "Save", action: save)
            }
            RibbonButton(systemImage: "checkmark", label: "Useful", action: actions.useful)
            RibbonButton(systemImage: "xmark", label: "Not useful", action: actions.notUseful)
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

/// The width of the gray dash plus its gap, so expanded text lines up with titles.
enum DashColumn {
    static let width: CGFloat = 16
}

/// An action shown as a plain link: slate, semibold, underlined. No outline or fill.
struct TextLink: View {
    var title: String
    var action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
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
        .buttonStyle(.borderless)
    }
}
