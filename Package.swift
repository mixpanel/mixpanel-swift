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
      name: "jsonlogic",
      url: "https://github.com/advantagefse/json-logic-swift",
      from: "1.2.0"
    ),
    .package(
      name: "MixpanelSwiftCommon",
      url: "https://github.com/mixpanel/mixpanel-swift-common.git",
      from: "1.0.0"
    )
  ],
  targets: [
    .target(
      name: "Mixpanel",
      dependencies: [
        "MixpanelSwiftCommon",
        "jsonlogic",
      ],
      path: "Sources",
      resources: [
        .copy("Mixpanel/PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
