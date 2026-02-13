// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MicLatchKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "MicLatchKit",
            targets: ["MicLatchKit"]
        ),
    ],
    dependencies: [
        // Add external dependencies here
    ],
    targets: [
        .target(
            name: "MicLatchKit",
            dependencies: [],
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
