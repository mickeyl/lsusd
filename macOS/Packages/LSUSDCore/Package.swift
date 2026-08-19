// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LSUSDCore",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "LSUSDCore", targets: ["LSUSDCore"]),
    ],
    targets: [
        .target(
            name: "LSUSDCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(
            name: "LSUSDCoreTests",
            dependencies: ["LSUSDCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
