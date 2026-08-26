// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DopaBreakCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DopaBreakCore",
            targets: ["DopaBreakCore"]
        )
    ],
    targets: [
        .target(
            name: "DopaBreakCore",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "DopaBreakCoreTests",
            dependencies: ["DopaBreakCore"]
        )
    ]
)
