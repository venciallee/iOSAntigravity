// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AntigravityData",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AntigravityData",
            targets: ["AntigravityData"]
        )
    ],
    targets: [
        .target(
            name: "AntigravityData",
            path: "Sources/AntigravityData"
        ),
        .testTarget(
            name: "AntigravityDataTests",
            dependencies: ["AntigravityData"],
            path: "Tests/AntigravityDataTests"
        )
    ]
)
