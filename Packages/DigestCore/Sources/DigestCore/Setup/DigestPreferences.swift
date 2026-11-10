import Foundation
import Observation

/// What the reader chose in setup: whether setup is done, and which sections are on the page.
/// Skipping a setup step leaves its section off until it is turned on again. Kept on this device.
@MainActor
@Observable
public final class DigestPreferences {
    /// The parts of the page that can be turned off.
    public enum Section: String, CaseIterable, Sendable {
        case weather, calendar, todos, news, podcasts
    }

    /// True once the reader has been through setup.
    public private(set) var hasFinishedSetup: Bool
    private var hidden: Set<String>

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasFinishedSetup = defaults.bool(forKey: Keys.finishedSetup)
        self.hidden = Set(defaults.stringArray(forKey: Keys.hiddenSections) ?? [])
    }

    /// Whether the reader wants the section on the page. Calendar, To do and Weather also need
    /// access or a place before they show.
    public func isShown(_ section: Section) -> Bool {
        !hidden.contains(section.rawValue)
    }

    public func setShown(_ shown: Bool, _ section: Section) {
        if shown { hidden.remove(section.rawValue) } else { hidden.insert(section.rawValue) }
        defaults.set(hidden.sorted(), forKey: Keys.hiddenSections)
    }

    public func finishSetup() {
        hasFinishedSetup = true
        defaults.set(true, forKey: Keys.finishedSetup)
    }

    private enum Keys {
        static let finishedSetup = "setup.finished"
        static let hiddenSections = "setup.hiddenSections"
    }
}
