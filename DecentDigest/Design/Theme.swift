import SwiftUI
import UIKit

/// Colors and type from the UI principles doc: plain text on a paper page.
enum Theme {
    // Colors (light / dark)
    static let page = Color(light: 0xFAF9F6, dark: 0x151817)
    static let pageTintTop = Color(light: 0xFCFBF8, dark: 0x181B1A)
    static let pageTintBottom = Color(light: 0xF2F1EC, dark: 0x121514)
    static let ink = Color(light: 0x1A1D1E, dark: 0xECEDEA)
    static let secondary = Color(light: 0x6F7573, dark: 0xA3A8A5)
    static let rule = Color(light: 0xDFE0DC, dark: 0x343937)
    static let accent = Color(light: 0x3C3C4C, dark: 0xCECED5)
    // An expanded headline sits on a faint band, with its actions on a slightly darker one.
    static let expandedFill = Color(light: 0xF2F1EC, dark: 0x1B1F1E)
    static let ribbonFill = Color(light: 0xE8E7E1, dark: 0x232827)
    /// The small square buttons on the ribbon, in the page color.
    static let ribbonButtonFill = Color(light: 0xFAF9F6, dark: 0x151817)
    // The article panel: paper in light mode, a step lighter than the page in dark mode.
    static let panelFill = Color(light: 0xFAF9F6, dark: 0x202524)
    static let panelShadow = Color.black.opacity(0.14)
    /// The faint wash over the digest while the panel is open.
    static let scrim = Color.black.opacity(0.12)
    // Swipe action fills carry white labels, so they stay dark in both modes.
    static let swipeUseful = Color(light: 0x3C3C4C, dark: 0x3C3C4C)
    static let swipeNotRelevant = Color(light: 0x6F7573, dark: 0x5A605E)

    // Spacing
    static let margin: CGFloat = 24
    static let ruleSpacing: CGFloat = 24
    static let titleToList: CGFloat = 6

    // Type: Georgia for the date and section titles only; SF Pro everywhere else.
    static let dateFont = Font.custom("Georgia", size: 30, relativeTo: .largeTitle)
    static let sectionTitleFont = Font.custom("Georgia", size: 22, relativeTo: .title2)
    static let wordmarkFont = Font.footnote
    /// Section actions such as Refresh: slate, semibold, underlined.
    static let actionFont = Font.subheadline.weight(.semibold)
    /// The small gray label naming what the feed sent ("Full post", "Excerpt").
    static let typeLabelFont = Font.caption.weight(.semibold)
    static let ribbonIconFont = Font.subheadline
}

extension Color {
    /// A color that switches between two hex values for light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// The thin 1pt rule between sections.
struct SectionRule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(height: 1)
            .padding(.vertical, Theme.ruleSpacing)
            .accessibilityHidden(true)
    }
}
