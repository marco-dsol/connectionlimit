// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ConnectionLimit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ConnLimitCore", targets: ["ConnLimitCore"]),
        .executable(name: "connlimit", targets: ["connlimit"]),
        .executable(name: "connlimit-selftest", targets: ["connlimit-selftest"]),
        .executable(name: "ConnectionLimitApp", targets: ["ConnectionLimitApp"]),
    ],
    targets: [
        .target(
            name: "ConnLimitCore",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "connlimit",
            dependencies: ["ConnLimitCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ConnectionLimitApp",
            dependencies: ["ConnLimitCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // XCTest und swift-testing sind nur mit vollständigem Xcode verfügbar.
        // Auf reinen Command Line Tools läuft die Prüfsuite deshalb als
        // eigenständiges Programm: `swift run connlimit-selftest`.
        .executableTarget(
            name: "connlimit-selftest",
            dependencies: ["ConnLimitCore"],
            path: "Sources/selftest",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
