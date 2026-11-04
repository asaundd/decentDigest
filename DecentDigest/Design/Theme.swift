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

    // Spacing
    static let margin: CGFloat = 24
    static let ruleSpacing: CGFloat = 24
    static let titleToList: CGFloat = 6

    // Type: Georgia for the date and section titles only; SF Pro everywhere else.
    static let dateFont = Font.custom("Georgia", size: 30, relativeTo: .largeTitle)
    static let sectionTitleFont = Font.custom("Georgia", size: 22, relativeTo: .title2)
    static let wordmarkFont = Font.footnote
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
