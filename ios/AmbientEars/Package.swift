// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HearingCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "HearingCore", targets: ["HearingCore"]),
    ],
    targets: [
        .target(name: "HearingCore"),
        .testTarget(name: "HearingCoreTests", dependencies: ["HearingCore"]),
    ]
)
