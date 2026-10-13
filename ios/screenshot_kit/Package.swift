// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "screenshot_kit",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "screenshot-kit", targets: ["screenshot_kit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "screenshot_kit",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
