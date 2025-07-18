// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "PathKit",
    products: [
        .library(name: "PathKit", targets: ["PathKit"]),
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        .target(
            name: "PathKit",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "PathKitTests",
            dependencies: ["PathKit"],
            path: "Tests/PathKitTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
