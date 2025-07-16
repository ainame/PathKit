// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "PathKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "PathKit", targets: ["PathKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/Spectre.git", .upToNextMinor(from: "0.10.0"))
    ],
    targets: [
        .target(
            name: "PathKit",
            dependencies: [],
            path: "Sources",
            exclude: ["PathKit.swift.backup"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "PathKitTests", 
            dependencies: ["PathKit", "Spectre"],
            path: "Tests/PathKitTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
