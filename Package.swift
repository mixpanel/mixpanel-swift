// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "Mixpanel",
  platforms: [
    .iOS(.v14),
    .tvOS(.v14),
    .macOS(.v11),
    .watchOS(.v7),
  ],
  products: [
    .library(name: "Mixpanel", targets: ["Mixpanel"]),
    .library(name: "MixpanelOpenFeature", targets: ["MixpanelOpenFeature"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/advantagefse/json-logic-swift",
      from: "1.2.0"
    ),
    .package(
      name: "OpenFeature",
      url: "https://github.com/open-feature/swift-sdk.git",
      from: "0.5.0"
    ),
  ],
  targets: [
    .target(
      name: "Mixpanel",
      dependencies: [
        .product(name: "jsonlogic", package: "json-logic-swift")
      ],
      path: "Sources",
      exclude: ["MixpanelOpenFeature"],
      resources: [
        .copy("Mixpanel/PrivacyInfo.xcprivacy")
      ]
    ),
    .target(
      name: "MixpanelOpenFeature",
      dependencies: [
        "Mixpanel",
        .product(name: "OpenFeature", package: "OpenFeature"),
      ],
      path: "Sources/MixpanelOpenFeature"
    ),
    .testTarget(
      name: "MixpanelOpenFeatureTests",
      dependencies: ["MixpanelOpenFeature"],
      path: "Tests/MixpanelOpenFeatureTests"
    ),
  ]
)
