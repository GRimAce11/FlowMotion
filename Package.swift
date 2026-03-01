// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FlowMotion",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "FlowMotion",
            targets: ["FlowMotion"]
        ),
    ],
    targets: [
        .target(
            name: "FlowMotion",
            path: "Sources/FlowMotion",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "FlowMotionTests",
            dependencies: ["FlowMotion"],
            path: "Tests/FlowMotionTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
