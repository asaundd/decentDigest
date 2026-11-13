import Observation
import SwiftUI

/// Switches for trying design options on the device, in debug builds only (Settings › Design lab).
/// Release builds always draw today's look. Remove once the options are chosen.
@MainActor
@Observable
final class DesignLab {
    static let shared = DesignLab()

    /// The Settings button at the top right of the digest.
    enum ButtonStyle: String, CaseIterable, Identifiable {
        case glass = "A", shadow = "B", halo = "C", disc = "D"
        var id: String { rawValue }
        var name: String {
            switch self {
            case .glass: "A. Glass circle (today)"
            case .shadow: "B. Floating Dd, light shadow"
            case .halo: "C. Floating Dd, paper halo"
            case .disc: "D. Flat paper disc"
            }
        }
    }

    /// The color of links and actions.
    enum LinkColor: String, CaseIterable, Identifiable {
        case slate = "L1", blueSlate = "L2", deeperBlue = "L3", grayBlue = "L4"
        var id: String { rawValue }
        var name: String {
            switch self {
            case .slate: "L1. Slate (today)"
            case .blueSlate: "L2. Blue slate"
            case .deeperBlue: "L3. Deeper blue"
            case .grayBlue: "L4. Gray blue"
            }
        }
        var color: Color {
            switch self {
            case .slate: Color(light: 0x3C3C4C, dark: 0xCECED5)
            case .blueSlate: Color(light: 0x47557A, dark: 0xB4BEDB)
            case .deeperBlue: Color(light: 0x3D5A80, dark: 0xA9BDD9)
            case .grayBlue: Color(light: 0x4A5D73, dark: 0xB8C4D2)
            }
        }
    }

    #if DEBUG
    var button: ButtonStyle {
        didSet { UserDefaults.standard.set(button.rawValue, forKey: "lab.button") }
    }
    var link: LinkColor {
        didSet { UserDefaults.standard.set(link.rawValue, forKey: "lab.link") }
    }
    /// Setup's and Settings' offline notes on the pale slate tint, like the bar under the date.
    var offlineNotesOnTint: Bool {
        didSet { UserDefaults.standard.set(offlineNotesOnTint, forKey: "lab.offlineTint") }
    }

    private init() {
        let defaults = UserDefaults.standard
        button = defaults.string(forKey: "lab.button").flatMap(ButtonStyle.init(rawValue:)) ?? .glass
        link = defaults.string(forKey: "lab.link").flatMap(LinkColor.init(rawValue:)) ?? .slate
        offlineNotesOnTint = defaults.bool(forKey: "lab.offlineTint")
    }
    #else
    var button: ButtonStyle { .glass }
    var link: LinkColor { .slate }
    var offlineNotesOnTint: Bool { false }
    private init() {}
    #endif
}

#if DEBUG
/// Settings › Design lab: the options from the board, to switch between on the device.
struct DesignLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var lab = DesignLab.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Settings button") {
                    Picker("Settings button", selection: $lab.button) {
                        ForEach(DesignLab.ButtonStyle.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Link color") {
                    Picker("Link color", selection: $lab.link) {
                        ForEach(DesignLab.LinkColor.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Toggle("Offline notes on the slate tint", isOn: $lab.offlineNotesOnTint)
                } footer: {
                    Text("The notes under the Podcasts, News and city search boxes in setup and Settings. Turn off Wi-Fi and cellular to see them.")
                }
            }
            .navigationTitle("Design lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
