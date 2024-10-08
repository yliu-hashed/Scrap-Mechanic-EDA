// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Scrap Mechanic EDA",
    platforms: [
        .macOS(.v13),
        .custom("Linux", versionString: "1.0"),
        .custom("Windows", versionString: "10.0"),
    ],
    products: [
        .library(name: "SMEDABlueprint", targets: ["SMEDABlueprint"]),
        .library(name: "SMEDANetlist", targets: ["SMEDANetlist"]),
        .library(name: "SMEDAResult", targets: ["SMEDAResult"]),
        .executable(name: "sm-eda", targets: ["sm-eda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SMEDABlueprint",
            packageAccess: true
        ),
        .target(
            name: "SMEDANetlist",
            packageAccess: true
        ),
        .target(
            name: "SMEDAResult",
            packageAccess: true
        ),
        .executableTarget(
            name: "sm-eda",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "SMEDABlueprint"),
                .target(name: "SMEDANetlist"),
                .target(name: "SMEDAResult"),
            ]
        )
    ]
)
