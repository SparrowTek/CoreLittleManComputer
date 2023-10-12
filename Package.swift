// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CoreLittleManComputer",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v10_15),
        .watchOS(.v9),
        .tvOS(.v16),
    ],
    products: [
        .library(
            name: "CoreLittleManComputer",
            targets: ["CoreLittleManComputer"]),
    ],
    targets: [
        .target(
            name: "CoreLittleManComputer"),
        .testTarget(
            name: "CoreLittleManComputerTests",
            dependencies: ["CoreLittleManComputer"]),
    ]
)
