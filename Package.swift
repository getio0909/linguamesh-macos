// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LinguaMeshMacOS",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "LinguaMeshFeature",
            targets: ["LinguaMeshFeature"]
        ),
        .executable(
            name: "LinguaMesh",
            targets: ["LinguaMeshApp"]
        ),
    ],
    dependencies: [
        .package(path: "../linguamesh-core/bindings/apple"),
    ],
    targets: [
        .target(
            name: "LinguaMeshFeature",
            dependencies: [
                .product(name: "LinguaMeshCore", package: "apple"),
            ],
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
            ]
        ),
        .executableTarget(
            name: "LinguaMeshApp",
            dependencies: ["LinguaMeshFeature"]
        ),
        .testTarget(
            name: "LinguaMeshFeatureTests",
            dependencies: ["LinguaMeshFeature"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
