// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CheatCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CheatCore", targets: ["CheatCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "CheatCore",
            dependencies: ["TOMLKit"]
        ),
        .testTarget(
            name: "CheatCoreTests",
            dependencies: ["CheatCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
