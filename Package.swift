// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoreLittleManComputer",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "CoreLittleManComputer",
            targets: ["CoreLittleManComputer"]
        ),
    ],
    targets: [
        .target(
            name: "CoreLittleManComputer"
        ),
        .testTarget(
            name: "CoreLittleManComputerTests",
            dependencies: ["CoreLittleManComputer"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
