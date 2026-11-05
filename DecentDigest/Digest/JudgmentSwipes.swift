import SwiftUI
import UIKit

extension View {
    /// Swipe right for useful (✓), left for not useful (✕). Each action shows its symbol with a
    /// small word under it, the same symbols as the action ribbon.
    func judgmentSwipes(useful: @escaping () -> Void, notUseful: @escaping () -> Void) -> some View {
        swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: useful) {
                SwipeLabel.useful
            }
            .accessibilityLabel("Useful")
            .tint(Theme.swipeUseful)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: notUseful) {
                SwipeLabel.notUseful
            }
            .accessibilityLabel("Not useful")
            .tint(Theme.swipeNotRelevant)
        }
    }
}

/// Swipe actions only draw an image or a title, not both stacked, so the symbol and word are drawn
/// into one image.
@MainActor
private enum SwipeLabel {
    static let useful = render(systemImage: "checkmark", title: "Useful")
    static let notUseful = render(systemImage: "xmark", title: "Not useful")

    private static func render(systemImage: String, title: String) -> Image {
        let content = VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 2)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return Image(systemName: systemImage) }
        return Image(uiImage: image)
    }
}
