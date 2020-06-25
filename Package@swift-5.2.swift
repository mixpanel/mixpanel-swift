// swift-tools-version:5.2

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
