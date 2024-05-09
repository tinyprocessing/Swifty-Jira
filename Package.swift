// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftJiraCLI",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "jira", targets: ["SwiftJiraCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", from: "0.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "0.0.1")),
    ],
    targets: [
        .target(name: "SwiftJiraCLI",
                dependencies: [
                    .product(name: "SwiftyTextTable", package: "SwiftyTextTable"),
                    .product(name: "ArgumentParser", package: "swift-argument-parser"),
                ], path: "Sources")
    ]
)
