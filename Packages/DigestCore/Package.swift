// swift-tools-version: 6.2
import PackageDescription

// DigestCore holds the app's models and services, with no UI.
let package = Package(
    name: "DigestCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "DigestCore", targets: ["DigestCore"]),
    ],
    targets: [
        .target(
            name: "DigestCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DigestCoreTests",
            dependencies: ["DigestCore"]
        ),
    ]
)
