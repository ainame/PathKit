// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "PathKit",
    products: [
        .library(name: "PathKit", targets: ["PathKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/Spectre.git", from: "0.10.1"),
    ],
    targets: [
        .target(
            name: "PathKit",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "PathKitTests",
            dependencies: ["PathKit", "Spectre"],
            path: "Tests/PathKitTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
