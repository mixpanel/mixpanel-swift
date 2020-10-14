// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Mixpanel",
    products: [
        .library(name: "Mixpanel", targets: ["Mixpanel"])
    ],
    targets: [
        .target(
            name: "Mixpanel",
            path: "Sources",
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("placeholder-image.png"),
            ],
            swiftSettings: [
                .define("DECIDE")
            ]
        ),
    ]
)
