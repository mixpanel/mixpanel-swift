// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "Mixpanel",
  platforms: [
    .iOS(.v13),
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
      from: "1.0.1"
    )
  ],
  targets: [
    .target(
      name: "Mixpanel",
      dependencies: [
        .product(name: "MixpanelSwiftCommon", package: "mixpanel-swift-common"),
        .product(name: "jsonlogic", package: "json-logic-swift"),
      ],
      path: "Sources",
      resources: [
        .copy("Mixpanel/PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
