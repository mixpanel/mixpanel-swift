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
            path: "Mixpanel",
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("MPCloseButton.png"),
                .process("MPCloseButton@2x.png"),
                .process("MPCloseButton@3x.png"),
                .process("placeholder-image.png")
            ],
            swiftSettings: [
                .define("DECIDE")
            ]
        ),
    ]
)
