import CoreHaptics
import SwiftUI

extension View {
    /// Plays the done haptic, the one tap the phone gives when the reader is done with something
    /// (a to-do checked off, or a news item or episode saved or marked read), each time `trigger`
    /// changes in a way `when` accepts: a single sharp click drawn with Core Haptics.
    func doneHaptic<T: Equatable>(trigger: T, when: @escaping (T, T) -> Bool = { _, _ in true }) -> some View {
        onChange(of: trigger) { old, new in
            if when(old, new) { SharpClick.shared.play() }
        }
    }
}

/// One transient Core Haptics event at full sharpness. The engine starts on first use and stops on
/// its own when idle.
@MainActor
final class SharpClick {
    static let shared = SharpClick()

    private var engine: CHHapticEngine?

    func play() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            if engine == nil {
                let engine = try CHHapticEngine()
                engine.isAutoShutdownEnabled = true
                engine.playsHapticsOnly = true
                self.engine = engine
            }
            guard let engine else { return }
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1),
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            engine = nil
        }
    }
}
