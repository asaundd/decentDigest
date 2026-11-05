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

    /// The whole post is in the feed, so Read more opens it in the panel.
    var readsHere: Bool { kind == .fullPost }

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

    /// What the panel shows: the full post. Only full posts open the panel.
    var panelText: String? {
        fullText
    }

    /// The label for going to the site: an excerpt continues there, anything else opens it.
    var siteLabel: String {
        kind == .excerpt ? "Continue reading ↗" : "Open in Safari ↗"
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
    /// Opens the panel. For full posts it is the ribbon's first action.
    var readFull: (() -> Void)?
    var openInSafari: (() -> Void)?
    /// "Open in Safari ↗" or "Continue reading ↗".
    var siteLabel = "Open in Safari ↗"
    /// Read more comes first in the ribbon, ahead of going to the site.
    var readsHere = false
}

/// One headline: gray dash, title (semibold while unread, gray once opened), feed name and age.
/// Title-only rows end in ↗. A tap expands any row: a small gray label naming what the feed sent,
/// the byline and up to 320 characters of text, over a ribbon of actions, all on a faint band.
struct HeadlineRow: View {
    static let verticalPadding: CGFloat = 5

    var headline: Headline
    var isExpanded: Bool
    var actions: HeadlineActions
    /// Reports where the expanded row ends on screen, so the list can scroll it into view.
    var onExpandedBottom: ((CGFloat) -> Void)? = nil
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("–")
                        .foregroundStyle(Theme.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline.title)
                            .fontWeight(headline.isUnread ? .semibold : .regular)
                            .foregroundStyle(headline.isUnread ? Theme.ink : Theme.secondary)
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
                expandedDetail
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
                Text(headline.kind.label)
                    .font(Theme.typeLabelFont)
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondary)
                    .accessibilityLabel(headline.kind.label)
                if let byline = headline.byline {
                    Text(byline)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
                if let text = headline.expandedText {
                    if let readFull = actions.readFull {
                        // Tapping the text opens the rest in the panel.
                        Button(action: readFull) {
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

            ActionRibbon(actions: actions)
        }
    }
}

/// The actions under an expanded headline, on one darker band: the way to read it first, lined up
/// with the text above, then small square buttons for Save, ✓ (useful) and ✕ (not useful).
struct ActionRibbon: View {
    var actions: HeadlineActions
    /// Indent for the first action, so it lines up with the text above it.
    var leadingInset: CGFloat = DashColumn.width
    /// In a digest row the ribbon runs past the row's margins to the screen edges.
    var bleedsToEdges = true

    var body: some View {
        HStack(spacing: 6) {
            primary
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                if let save = actions.save {
                    RibbonButton(systemImage: "bookmark", label: "Save", action: save)
                }
                RibbonButton(systemImage: "checkmark", label: "Useful", action: actions.useful)
                RibbonButton(systemImage: "xmark", label: "Not useful", action: actions.notUseful)
            }
        }
        .padding(.vertical, 1)
        .padding(.leading, Theme.margin + leadingInset)
        .padding(.trailing, Theme.margin - RibbonButton.gap)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ribbonFill)
        .padding(.horizontal, bleedsToEdges ? -Theme.margin : 0)
    }

    @ViewBuilder
    private var primary: some View {
        if actions.readsHere, let readFull = actions.readFull {
            TextLink("Read more", action: readFull)
        } else if let openInSafari = actions.openInSafari {
            TextLink(actions.siteLabel, action: openInSafari)
        } else if let readFull = actions.readFull {
            TextLink("Read more", action: readFull)
        }
    }
}

/// A small square symbol button on the ribbon, in the page color, with a larger tap target and a spoken label.
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
