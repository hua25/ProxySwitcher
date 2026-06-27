// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ProxySwitcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ProxySwitcherCore", targets: ["ProxySwitcherCore"]),
        .executable(name: "ProxySwitcher", targets: ["ProxySwitcher"])
    ],
    targets: [
        .target(name: "ProxySwitcherCore"),
        .executableTarget(
            name: "ProxySwitcher",
            dependencies: ["ProxySwitcherCore"],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "ProxySwitcherTests",
            dependencies: ["ProxySwitcherCore"]
        )
    ]
)
