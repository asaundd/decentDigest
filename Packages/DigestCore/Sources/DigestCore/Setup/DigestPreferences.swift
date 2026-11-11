import Foundation
import Observation

/// What the reader chose in setup and Settings: whether setup is done, which sections are on the page,
/// whether reading history is kept, and the appearance. Skipping a setup step leaves its section off
/// until it is turned on again. Kept on this device.
@MainActor
@Observable
public final class DigestPreferences {
    /// The parts of the page that can be turned off.
    public enum Section: String, CaseIterable, Sendable {
        case weather, calendar, todos, news, podcasts
    }

    /// Light, dark, or following the device.
    public enum Appearance: String, CaseIterable, Sendable {
        case automatic, light, dark
    }

    /// True once the reader has been through setup.
    public private(set) var hasFinishedSetup: Bool
    /// False when the reader turns reading history off: items they dealt with leave no record once
    /// they expire.
    public private(set) var keepsReadingHistory: Bool
    public private(set) var appearance: Appearance
    private var hidden: Set<String>

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasFinishedSetup = defaults.bool(forKey: Keys.finishedSetup)
        self.hidden = Set(defaults.stringArray(forKey: Keys.hiddenSections) ?? [])
        self.keepsReadingHistory = !defaults.bool(forKey: Self.readingHistoryOffKey)
        self.appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .automatic
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

    /// Puts every section back on the page, for starting setup over.
    public func showAllSections() {
        hidden = []
        defaults.removeObject(forKey: Keys.hiddenSections)
    }

    public func setKeepsReadingHistory(_ keeps: Bool) {
        keepsReadingHistory = keeps
        defaults.set(!keeps, forKey: Self.readingHistoryOffKey)
    }

    public func setAppearance(_ appearance: Appearance) {
        self.appearance = appearance
        defaults.set(appearance.rawValue, forKey: Keys.appearance)
    }

    /// Read by the background refresh, which prunes expired items.
    nonisolated public static let readingHistoryOffKey = "history.off"

    private enum Keys {
        static let finishedSetup = "setup.finished"
        static let hiddenSections = "setup.hiddenSections"
        static let appearance = "appearance"
    }
}
