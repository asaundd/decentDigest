import DigestCore
import SwiftUI

/// A request to show the article panel, shared by News and Saved news.
struct PanelRequest: Identifiable {
    var headline: Headline
    var actions: HeadlineActions
    var id: String { headline.id }
}

/// The full post a feed carries, read on a sheet in the page color.
struct ArticlePanel: View {
    var headline: Headline
    var actions: HeadlineActions

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(headline.detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    TextLink("Done") { dismiss() }
                }
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
                if let open = actions.openInSafari {
                    Button {
                        dismiss()
                        open()
                    } label: {
                        Text("Open on the web ↗")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.page)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { links }
                    VStack(alignment: .leading, spacing: 10) { links }
                }
                .padding(.top, 4)
            }
            .foregroundStyle(Theme.ink)
            .padding(Theme.margin)
        }
        .presentationBackground(Theme.page)
        .presentationDetents([.large])
        .presentationCornerRadius(18)
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var links: some View {
        if let save = actions.save {
            TextLink("Save") { dismiss(); save() }
        }
        TextLink("Useful") { dismiss(); actions.useful() }
        TextLink("Not useful") { dismiss(); actions.notUseful() }
    }
}
