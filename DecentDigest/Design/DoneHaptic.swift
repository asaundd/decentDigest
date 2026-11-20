import CoreHaptics
import SwiftUI

/// The one tap the phone gives when the reader is done with something: a to-do checked off, or a
/// news item or episode saved or marked read.
enum DoneHaptic: String, CaseIterable, Identifiable {
    /// A soft, light bump.
    case light
    /// A firm, short knock.
    case rigid
    /// The same knock at full strength.
    case rigidFull
    /// A medium bump.
    case medium
    /// The shortest tick iOS has, like a picker wheel.
    case tick
    /// Two quick taps, the iOS "success".
    case success
    /// A single sharp click, drawn with Core Haptics: full sharpness, no rumble.
    case sharpClick

    /// What the app plays. Debug builds can try the others in Design lab.
    static let standard: DoneHaptic = .sharpClick

    var id: String { rawValue }

    var name: String {
        switch self {
        case .light: "Light"
        case .rigid: "Rigid"
        case .rigidFull: "Rigid, full strength"
        case .medium: "Medium"
        case .tick: "Tick"
        case .success: "Success"
        case .sharpClick: "Sharp click"
        }
    }

    var note: String {
        switch self {
        case .light: "A soft, light bump."
        case .rigid: "A firm, short knock at 70%."
        case .rigidFull: "The same knock at full strength."
        case .medium: "A rounder, heavier bump."
        case .tick: "The shortest tick, like a picker wheel."
        case .success: "Two quick taps."
        case .sharpClick: "One sharp click, crisper than any of the built-in ones."
        }
    }

    #if DEBUG
    static let choiceKey = "debug.doneHaptic"

    /// The one picked in Design lab, or the standard one.
    static var current: DoneHaptic {
        UserDefaults.standard.string(forKey: choiceKey).flatMap(DoneHaptic.init(rawValue:)) ?? standard
    }
    #else
    static var current: DoneHaptic { standard }
    #endif

    /// The built-in feedback, or nil for the sharp click, which Core Haptics plays.
    var feedback: SensoryFeedback? {
        switch self {
        case .light: .impact(weight: .light)
        case .rigid: .impact(flexibility: .rigid, intensity: 0.7)
        case .rigidFull: .impact(flexibility: .rigid, intensity: 1)
        case .medium: .impact(weight: .medium)
        case .tick: .selection
        case .success: .success
        case .sharpClick: nil
        }
    }
}

extension View {
    /// Plays the done haptic each time `trigger` changes in a way `when` accepts.
    func doneHaptic<T: Equatable>(trigger: T, when: @escaping (T, T) -> Bool = { _, _ in true }) -> some View {
        playsHaptic(DoneHaptic.current, trigger: trigger, when: when)
    }

    /// Plays one haptic each time `trigger` changes in a way `when` accepts.
    func playsHaptic<T: Equatable>(_ choice: DoneHaptic, trigger: T, when: @escaping (T, T) -> Bool = { _, _ in true }) -> some View {
        sensoryFeedback(trigger: trigger) { old, new in
            when(old, new) ? choice.feedback : nil
        }
        .onChange(of: trigger) { old, new in
            if choice == .sharpClick, when(old, new) { SharpClick.shared.play() }
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

#if DEBUG
/// Debug only: try each haptic, then pick the one the app plays when a to-do is checked off or a
/// news item or episode is saved or marked read; and try a shaded band at the top of the digest.
/// Opened from Settings' footer.
struct DesignLabView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DoneHaptic.choiceKey) private var choice = DoneHaptic.standard.rawValue
    @AppStorage(TopStyle.storageKey) private var topStyle = TopStyle.rule.rawValue
    @State private var tries = 0
    @State private var tried: DoneHaptic = .standard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                .padding(.leading, -10)

                Text("Design lab")
                    .font(Theme.sectionTitleFont)
                    .padding(.top, 4)
                Text("Done haptic. Tap Try to feel each one, then Use to play it when a to-do is checked off or a news item or episode is saved or marked read. Debug builds only.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 6)
                SectionRule()

                ForEach(DoneHaptic.allCases) { haptic in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(haptic.name)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.ink)
                            Text(haptic.note)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        TextLink("Try") { play(haptic) }
                            .accessibilityLabel("Try \(haptic.name)")
                        if choice == haptic.rawValue {
                            Text("✓ In use")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                                .fixedSize()
                        } else {
                            TextLink("Use") {
                                choice = haptic.rawValue
                                play(haptic)
                            }
                            .accessibilityLabel("Use \(haptic.name)")
                        }
                    }
                    .padding(.vertical, 8)
                }

                SectionRule()
                Text("Top of the digest")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.ink)
                Text("How the date and weather are set apart from Calendar. Use one, then close Settings to see it.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                ForEach(TopStyle.allCases) { style in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.name)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.ink)
                            Text(style.note)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if topStyle == style.rawValue {
                            Text("✓ In use")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondary)
                                .fixedSize()
                        } else {
                            TextLink("Use") { topStyle = style.rawValue }
                                .accessibilityLabel("Use \(style.name)")
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, Theme.margin)
        }
        .background(Theme.page.ignoresSafeArea())
        .sensoryFeedback(trigger: tries) { _, _ in tried.feedback }
        .onChange(of: tries) {
            if tried == .sharpClick { SharpClick.shared.play() }
        }
    }

    private func play(_ haptic: DoneHaptic) {
        tried = haptic
        tries += 1
    }
}
#endif
