// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Mixpanel",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12),
        .macOS(.v10_13),
        .watchOS(.v4),
    ],
    products: [
        .library(name: "Mixpanel", targets: ["Mixpanel"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/advantagefse/json-logic-swift",
            from: "1.2.0"
        ),
        .package(
            url: "https://github.com/mixpanel/mixpanel-swift-common.git",
            from: "1.0.0"
        ),
    ],
    targets: [
        // Objective-C target for exception handling
        .target(
            name: "MixpanelObjC",
            dependencies: [],
            path: "Sources/MixpanelObjC",
            publicHeadersPath: "include"
        ),

        // Swift target
        .target(
            name: "Mixpanel",
            dependencies: [
                "MixpanelObjC",
                .product(name: "MixpanelSwiftCommon", package: "mixpanel-swift-common"),
                .product(name: "jsonlogic", package: "json-logic-swift"),
            ],
            path: "Sources/Mixpanel",
            resources: [
                .copy("Mixpanel/PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
