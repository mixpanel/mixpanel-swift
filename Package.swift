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
        // TEMPORARY (hierarchical-groups): MixpanelIdentity is on mixpanel-swift-common's
        // hierarchical-groups branch. Restore the released dependency once it ships:
        // .package(url: "https://github.com/mixpanel/mixpanel-swift-common.git", from: "2.1.0")
        .package(path: "../mixpanel-swift-common")
    ],
    targets: [
        .target(
            name: "Mixpanel",
            dependencies: [
                .product(name: "MixpanelSwiftCommon", package: "mixpanel-swift-common")
            ],
            path: "Sources",
            resources: [
                .copy("Mixpanel/PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
