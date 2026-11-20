import DigestCore
import SwiftUI

/// A request to show the article panel, shared by News, Podcasts and Saved.
struct PanelRequest: Identifiable {
    var headline: Headline
    var actions: HeadlineActions
    var id: String { headline.id }
}

/// The full post a feed carries, or an episode's show notes, on a floating panel that slides in from the right over the digest.
/// Its actions stay pinned at the bottom while the post scrolls.
struct ArticlePanel: View {
    var headline: Headline
    var actions: HeadlineActions
    var onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The same round ✕ as Settings, then where the item came from.
            HStack(spacing: 4) {
                CloseButton(action: onClose)
                Text(headline.detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.margin - 4)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(headline.title)
                        .font(Theme.panelTitleFont)
                        .accessibilityAddTraits(.isHeader)
                    if let byline = headline.byline {
                        Text(byline)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }
                    if let text = headline.panelText {
                        Text(text)
                            .font(Theme.readingFont)
                            .lineSpacing(7)
                            .textSelection(.enabled)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 12)
            }

            ActionRibbon(actions: panelActions, leadingPadding: Theme.margin, trailingPadding: Theme.margin)
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.expandedRing, lineWidth: 1)
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
            choices: actions.choices,
            choose: { choice in
                close()
                // The row leaves once the panel has slid away, so the reader sees it go.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.25))
                    actions.choose(choice)
                }
            },
            readFull: nil,
            open: actions.open.map { open -> () -> Void in { close(); open() } },
            openLabel: actions.openLabel,
            share: actions.share,
            shareTitle: actions.shareTitle
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
                    .accessibilityLabel("Close")
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
