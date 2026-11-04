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

    /// Rows with more than a title expand in place; title-only rows open Safari.
    var expands: Bool {
        author != nil || summary != nil || fullText != nil
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
/// It ends in … when a tap shows more here, or ↗ when a tap opens Safari.
/// Expanded, it shows the byline, the first lines of the post and text-link actions.
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
                    Text(headline.expands ? "…" : "↗")
                        .foregroundStyle(Theme.secondary)
                }
                .padding(.vertical, Self.verticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(headline.title), \(headline.detail)")
            .accessibilityValue(Text(headline.isUnread ? "Unread" : "Read"))
            .accessibilityHint(Text(headline.expands ? (isExpanded ? "Shows less" : "Shows more") : "Opens in Safari"))
            .accessibilityAddTraits(.isButton)
            .accessibilityActions {
                if let save = actions.save {
                    Button("Save for later", action: save)
                }
            }

            if isExpanded {
                expandedDetail
                    .padding(.bottom, Self.verticalPadding + 4)
            }
        }
    }

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let byline = headline.byline {
                Text(byline)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
            if let summary = headline.summary {
                Text(summary)
                    .font(.callout)
                    .lineLimit(4)
            }
            actionLinks
                .padding(.top, 2)
        }
        // Line up with the title, past the dash column.
        .padding(.leading, DashColumn.width)
        .padding(.trailing, DashColumn.width)
    }

    private var actionLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { links }
            VStack(alignment: .leading, spacing: 10) { links }
        }
    }

    @ViewBuilder
    private var links: some View {
        if let save = actions.save {
            TextLink("Save for later", action: save)
        }
        TextLink("Useful", action: actions.useful)
        TextLink("Not useful", action: actions.notUseful)
        if let readFull = actions.readFull {
            TextLink("Read full post", action: readFull)
        } else if let openInSafari = actions.openInSafari {
            TextLink("Open in Safari ↗", action: openInSafari)
        }
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
