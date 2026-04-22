// swift-tools-version: 5.9
//
// SwiftPM manifest for Clicky — the minimal native macOS companion
// that backs the clicky-ai-plugin. Builds a single `clicky` executable
// which the Makefile wraps into `Clicky.app` via a post-build bundle step.
//
// Testing: `swift test` runs the XCTest suite under Tests/ClickyTests/.
// No TCC / no Accessibility / no Screen Recording required — the tests
// exercise pure Swift logic (arg building, persistence, scaling math).
//

import PackageDescription

let package = Package(
    name: "Clicky",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "Clicky",
            path: "Sources/Clicky"
        ),
        .testTarget(
            name: "ClickyTests",
            dependencies: ["Clicky"],
            path: "Tests/ClickyTests"
        ),
    ]
)
