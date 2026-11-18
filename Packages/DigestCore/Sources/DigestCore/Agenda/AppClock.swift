import Foundation

/// The time the digest goes by: the real time, except in the debug-only demo mode, which moves
/// it to a fixed morning so screenshots match the 9:41 status bar on any day they are taken.
public enum AppClock {
    /// Seconds added to the real time. Zero outside demo mode.
    nonisolated(unsafe) public static var offset: TimeInterval = 0

    public static var now: Date { Date.now.addingTimeInterval(offset) }

    /// Moves the clock so it reads `date` now, and keeps it ticking from there.
    public static func pin(to date: Date) {
        offset = date.timeIntervalSince(Date.now)
    }
}
