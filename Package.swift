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
            dependencies: [
                "ExceptionWrapper"
            ],
            path: "Mixpanel",
            exclude: [
                "ExceptionWrapper",
                "Info.plist"
            ],
            resources: [
                .process("Resources/MPCloseButton.png"),
                .process("Resources/MPCloseButton@2x.png"),
                .process("Resources/MPCloseButton@3x.png"),
                .process("Resources/placeholder-image.png")
            ],
            swiftSettings: [
                .define("DECIDE")
            ]
        ),
        .target(
            name: "ExceptionWrapper",
            path: "Mixpanel/ExceptionWrapper",
            publicHeadersPath: "."
        )
    ]
)
