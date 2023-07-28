// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "LexiconGen",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "lexicon-gen",
             targets: ["LexiconGen"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-format.git", revision: "508.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", revision: "508.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "LexiconGen",
            dependencies: [
                .target(name: "LexiconGenKit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftFormat", package: "swift-format"),
            ]
        ),
        .target(
            name: "LexiconGenKit"
        ),
        .testTarget(
            name: "LexiconGenTests",
            dependencies: [
                .target(name: "LexiconGenKit")
            ]
        ),
    ]
)
