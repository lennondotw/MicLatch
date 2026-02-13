// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MicLatchKit",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MicLatchKit",
            targets: ["MicLatchKit"]
        ),
    ],
    targets: [
        .target(
            name: "MicLatchKit",
            path: "Sources/MicLatchKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "MicLatchKitTests",
            dependencies: ["MicLatchKit"],
            path: "Tests/MicLatchKitTests"
        ),
    ]
)
