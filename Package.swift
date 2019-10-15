// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Mixpanel",
    products: [
        .library(name: "Mixpanel", targets: ["Mixpanel"])
    ],
    targets: [
        .target(name: "Mixpanel", dependencies: ["ExceptionWrapper"]),
        .target(name: "ExceptionWrapper")
    ]
)
