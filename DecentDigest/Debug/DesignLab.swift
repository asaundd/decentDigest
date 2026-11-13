import Observation
import SwiftUI

/// Switches for trying the Settings button's look on the device, in debug builds only (Settings › Design lab).
/// Release builds always draw today's look. Remove once the options are chosen.
@MainActor
@Observable
final class DesignLab {
    static let shared = DesignLab()

    /// The Settings button at the top right of the digest.
    enum ButtonStyle: String, CaseIterable, Identifiable {
        case glass = "A", shadow = "B", halo = "C", disc = "D", closeCircle = "E", frostedDisc = "F", paperGlass = "G"
        var id: String { rawValue }
        var name: String {
            switch self {
            case .glass: "A. Glass circle (today)"
            case .shadow: "B. Floating Dd, light shadow"
            case .halo: "C. Floating Dd, paper halo"
            case .disc: "D. Flat paper disc"
            case .closeCircle: "E. Gray circle, like Settings' ✕"
            case .frostedDisc: "F. Frosted paper disc"
            case .paperGlass: "G. Glass tinted to the page, even edge"
            }
        }
    }

    #if DEBUG
    var button: ButtonStyle {
        didSet { UserDefaults.standard.set(button.rawValue, forKey: "lab.button") }
    }

    private init() {
        let defaults = UserDefaults.standard
        button = defaults.string(forKey: "lab.button").flatMap(ButtonStyle.init(rawValue:)) ?? .glass
    }
    #else
    var button: ButtonStyle { .glass }
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
