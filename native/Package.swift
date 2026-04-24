// swift-tools-version: 5.9
//
// SwiftPM manifest for OpenClicky — the minimal native macOS companion
// that backs the openclicky. Builds a single `openclicky` executable
// which the Makefile wraps into `OpenClicky.app` via a post-build bundle step.
//
// Testing: `swift test` runs the XCTest suite under Tests/OpenClickyTests/.
// No TCC / no Accessibility / no Screen Recording required — the tests
// exercise pure Swift logic (arg building, persistence, scaling math).
//

import PackageDescription

let package = Package(
    name: "OpenClicky",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "OpenClicky",
            path: "Sources/OpenClicky"
        ),
        .testTarget(
            name: "OpenClickyTests",
            dependencies: ["OpenClicky"],
            path: "Tests/OpenClickyTests"
        ),
    ]
)
