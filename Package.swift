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
                "Info.plist",
                "Mixpanel.h"
            ],
            resources: [
                .process("MiniNotificationViewController.xib"),
                .process("MPCloseButton.png"),
                .process("MPCloseButton@2x.png"),
                .process("MPCloseButton@3x.png"),
                .process("placeholder-image.png"),
                .process("TakeoverNotificationViewController~ipad.xib"),
                .process("TakeoverNotificationViewController~iphonelandscape.xib"),
                .process("TakeoverNotificationViewController~iphoneportrait.xib")
            ],
            swiftSettings: [
                .define("DECIDE")
            ]
        ),
        .target(
            name: "ExceptionWrapper",
            path: "Mixpanel/ExceptionWrapper"
        )
    ]
)
