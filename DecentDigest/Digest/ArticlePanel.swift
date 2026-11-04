import DigestCore
import SwiftUI

/// A request to show the article panel, shared by News and Saved news.
struct PanelRequest: Identifiable {
    var headline: Headline
    var actions: HeadlineActions
    var id: String { headline.id }
}

/// The full post a feed carries, on a floating panel that slides in from the right over the digest.
/// Its actions stay pinned at the bottom while the post scrolls.
struct ArticlePanel: View {
    var headline: Headline
    var actions: HeadlineActions
    var onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(headline.detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                Spacer()
                TextLink("Done", action: onClose)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(headline.title)
                        .font(Theme.sectionTitleFont)
                        .accessibilityAddTraits(.isHeader)
                    if let byline = headline.byline {
                        Text(byline)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }
                    if let text = headline.fullText ?? headline.summary {
                        Text(text)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 12)
            }

            ActionRibbon(actions: panelActions, leadingInset: 0, bleedsToEdges: false)
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 0.5)
        )
        .shadow(color: Theme.panelShadow, radius: 24, x: 0, y: 8)
        .offset(x: dragOffset)
        // Swipe right to close.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = max(0, value.translation.width)
                }
                .onEnded { value in
                    if value.translation.width > 90, abs(value.translation.width) > abs(value.translation.height) {
                        onClose()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                    }
                }
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    /// The row's actions, each closing the panel first. Reading on the site is the first action here.
    private var panelActions: HeadlineActions {
        let close = onClose
        let actions = actions
        return HeadlineActions(
            save: actions.save.map { save -> () -> Void in { close(); save() } },
            useful: { close(); actions.useful() },
            notUseful: { close(); actions.notUseful() },
            readFull: nil,
            openInSafari: actions.openInSafari.map { open -> () -> Void in { close(); open() } }
        )
    }
}

/// Dims the digest and shows the panel inset from the right edge.
struct ArticlePanelHost: View {
    @Binding var panel: PanelRequest?

    var body: some View {
        ZStack(alignment: .trailing) {
            if let request = panel {
                Theme.scrim
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .accessibilityLabel("Close article")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)
                ArticlePanel(headline: request.headline, actions: request.actions, onClose: close)
                    .padding(.leading, 28)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
                    .transition(.move(edge: .trailing))
                    .id(request.id)
            }
        }
        .animation(.easeOut(duration: 0.25), value: panel?.id)
    }

    private func close() {
        panel = nil
    }
}
