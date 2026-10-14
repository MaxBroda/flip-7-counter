// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flip7",
    platforms: [.macOS("27.0")],
    targets: [
        .target(name: "Flip7Core"),
        .executableTarget(name: "Flip7", dependencies: ["Flip7Core"]),
        .testTarget(name: "Flip7CoreTests", dependencies: ["Flip7Core"]),
    ],
    swiftLanguageModes: [.v5]
)
