import Foundation

/// The Design lab's Slow loading switch (debug builds only): every read and fetch waits 3 seconds
/// first, so the launch, the placeholder bars and late rows can be checked on a phone. Release builds
/// never wait.
enum SlowLoading {
    static let key = "debug.slowLoading"

    static func pause() async {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: key) {
            try? await Task.sleep(for: .seconds(3))
        }
        #endif
    }
}
