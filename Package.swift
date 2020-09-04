// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "AppReceiptValidator",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_11),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "AppReceiptValidator", targets: ["AppReceiptValidator"])
    ],
    targets: [
        .target(
            name: "AppReceiptValidator",
            path: "AppReceiptValidator/AppReceiptValidator",
            exclude: ["AppReceiptValidator/AppReceiptValidator/Supporting Files/Info.plist"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
