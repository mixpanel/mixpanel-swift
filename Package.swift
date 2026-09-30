// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Mixpanel",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v12),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "Mixpanel", targets: ["Mixpanel"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/mixpanel/mixpanel-swift-common.git",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "Mixpanel",
            dependencies: [
                .product(name: "MixpanelSwiftCommon", package: "mixpanel-swift-common"),
            ],
            path: "Sources",
            resources: [
                .copy("Mixpanel/PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
