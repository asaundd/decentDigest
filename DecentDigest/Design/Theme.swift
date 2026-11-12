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
    /// Events and to-dos under a day's name: a touch lighter than ink, so the day names lead.
    static let itemInk = Color(light: 0x3A3F40, dark: 0xD3D5D1)
    /// Events that are over and to-dos just checked off: lighter than secondary, struck through.
    static let past = Color(light: 0xA7ABA9, dark: 0x6C726F)
    // An expanded headline sits on a card a shade lighter than the page; its actions share that color.
    static let expandedFill = Color(light: 0xFFFEFC, dark: 0x202524)
    /// A faint edge and shadow that lift the expanded card off the page.
    static let expandedRing = Color(light: 0x1A1D1E, dark: 0x000000).opacity(0.06)
    static let expandedShadow = Color(light: 0x1A1D1E, dark: 0x000000).opacity(0.06)
    /// A pale slate tint behind the event happening now.
    static let nowTint = Color(light: 0xE8E8EE, dark: 0x2A2C33)
    /// Faint, still bars that stand in for rows while a slow read finishes.
    static let placeholder = Color(light: 0xEDEDE9, dark: 0x232826)
    /// The small square buttons on the ribbon, a shade darker than the card.
    static let ribbonButtonFill = Color(light: 0xF2F1EC, dark: 0x151817)
    /// The panel matches the expanded card, so the post reads the same in both.
    static let panelFill = expandedFill
    static let panelShadow = Color.black.opacity(0.14)
    /// The faint wash over the digest while the panel is open.
    static let scrim = Color.black.opacity(0.12)

    /// The Dd logo on the Settings button: quiet, but still easy to find.
    static let logoButton = Color(light: 0x8C918F, dark: 0x6F7573)
    /// A button that can't be used yet: a fill one shade darker than the page, with gray text.
    static let buttonDimmedFill = Color(light: 0xECEBE6, dark: 0x232826)
    static let buttonDimmedText = Color(light: 0xA7ABA9, dark: 0x6F7573)
    /// The faint underline under links that undo a choice (Unfollow, Hide).
    static let faintUnderline = Color(light: 0xC9CBC7, dark: 0x4A504D)
    /// The "on" track of every switch. In dark mode a muted slate rather than gray, so on is plain to see
    /// against the dark off track.
    static let switchOn = Color(light: 0x6F7573, dark: 0x7A7A94)
    /// The Paste control beside a search box. iOS draws its label white, so the fill is a warm gray
    /// dark enough for white text to read.
    static let pasteFill = Color(light: 0x7A7266, dark: 0x5E574C)
    /// The filled search boxes in setup: a shade darker than the page in light mode, lighter in dark
    /// mode (the button fill there matches the page), so the box shows.
    static let fieldFill = Color(light: 0xE9E8E2, dark: 0x272C2A)
    /// Behind the buttons pinned at the foot of setup pages: the color the page tint reaches there,
    /// so the bar doesn't show as a band.
    static let bottomBarFill = pageTintBottom

    // Spacing
    static let margin: CGFloat = 24
    static let ruleSpacing: CGFloat = 24
    /// From a section title to the first line of News, Podcasts, Saved, Calendar or To do.
    static let titleToFirstItem: CGFloat = 11

    // Type: Georgia for the date and section titles only; SF Pro everywhere else.
    static let dateFont = Font.custom("Georgia", size: 30, relativeTo: .largeTitle)
    static let sectionTitleFont = Font.custom("Georgia", size: 22, relativeTo: .title2)
    static let wordmarkFont = Font.footnote
    /// Links and actions in cards, the panel and Settings: slate, semibold, underlined.
    static let actionFont = Font.subheadline.weight(.semibold)
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

/// A thin 1pt rule with the given space above and below, for pages other than the digest.
struct PlainRule: View {
    var spacing: CGFloat

    var body: some View {
        Rectangle()
            .fill(Theme.rule)
            .frame(height: 1)
            .padding(.vertical, spacing)
            .accessibilityHidden(true)
    }
}
