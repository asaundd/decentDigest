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
        PostKind.classify(summary: summary, fullText: fullText, author: author)
    }

    /// Rows with more than a title expand in place; title-only rows open Safari.
    var expands: Bool { kind != .titleOnly }

    /// The whole post is in the feed, so Read more opens it in the panel.
    var readsHere: Bool { kind == .fullPost }

    /// › full post to read here, … a preview that expands, ↗ title only, opens the site.
    var marker: String {
        switch kind {
        case .fullPost: "›"
        case .preview: "…"
        case .titleOnly: "↗"
        }
    }

    /// The summary for full posts, otherwise the longest text the feed sent.
    private var previewText: String? {
        readsHere ? summary : PostKind.previewText(summary: summary, fullText: fullText)
    }

    /// What the expanded row shows, clipped so the action ribbon stays close.
    var expandedText: String? {
        previewText.map { PostKind.clipForRow($0) }
    }

    /// There is more to read in the panel than the row shows.
    var hasMore: Bool {
        readsHere || (previewText?.count ?? 0) > PostKind.rowTextLimit
    }

    /// What the panel shows: the full post, or the whole preview.
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
    var readFull: (() -> Void)?
    var openInSafari: (() -> Void)?
}

/// One headline: gray dash, title (semibold while unread, gray once opened), feed name and age.
/// It ends in › when the feed carries the full post, … when it carries a preview, and ↗ when it has
/// only a title. A tap expands the first two; title-only rows open Safari.
/// Expanded, the row sits on a faint band and shows the whole summary over a ribbon of actions.
struct HeadlineRow: View {
    static let verticalPadding: CGFloat = 5

    var headline: Headline
    var isExpanded: Bool
    var actions: HeadlineActions
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
                    Text(headline.marker)
                        .foregroundStyle(Theme.secondary)
                }
                .padding(.vertical, Self.verticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(headline.title), \(headline.detail)")
            .accessibilityValue(Text(headline.isUnread ? "Unread" : "Read"))
            .accessibilityHint(Text(headline.expands ? (isExpanded ? "Shows less" : (headline.readsHere ? "Shows a summary of the full post" : "Shows a preview")) : "Opens in Safari"))
            .accessibilityAddTraits(.isButton)
            .accessibilityActions {
                if let save = actions.save {
                    Button("Save", action: save)
                }
            }

            if isExpanded {
                expandedDetail
                    .transition(.opacity)
            }
        }
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
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
                }
            }
            // Line up with the title, past the dash column.
            .padding(.leading, DashColumn.width)
            .padding(.trailing, DashColumn.width)

            ActionRibbon(actions: actions)
        }
    }
}

/// The actions under an expanded headline, on one darker band: the way to read it first,
/// then Save, then ✓ for useful and ✕ for not useful.
struct ActionRibbon: View {
    var actions: HeadlineActions
    /// Indent for the first action, so it lines up with the text above it.
    var leadingInset: CGFloat = DashColumn.width
    /// In a digest row the ribbon runs past the row's margins to the screen edges.
    var bleedsToEdges = true

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                primary
                save
                Spacer(minLength: 0)
                judgments
            }
            VStack(alignment: .leading, spacing: 4) {
                primary
                HStack(spacing: 20) {
                    save
                    Spacer(minLength: 0)
                    judgments
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, Theme.margin + leadingInset)
        .padding(.trailing, Theme.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ribbonFill)
        .padding(.horizontal, bleedsToEdges ? -Theme.margin : 0)
    }

    @ViewBuilder
    private var primary: some View {
        if let readFull = actions.readFull {
            TextLink("Read more", action: readFull)
        } else if let openInSafari = actions.openInSafari {
            TextLink("Open in Safari ↗", action: openInSafari)
        }
    }

    @ViewBuilder
    private var save: some View {
        if let save = actions.save {
            TextLink("Save", action: save)
        }
    }

    private var judgments: some View {
        HStack(spacing: 4) {
            IconLink(systemImage: "checkmark", label: "Useful", action: actions.useful)
            IconLink(systemImage: "xmark", label: "Not useful", action: actions.notUseful)
        }
    }
}

/// A small slate symbol button with a full-size tap target and a spoken label.
struct IconLink: View {
    var systemImage: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Theme.actionFont)
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 44, minHeight: 36)
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
