// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "AppReceiptValidator",
    platforms: [
        .iOS("13.4"),
        .macOS(.v10_11),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "AppReceiptValidator", targets: ["AppReceiptValidator"])
    ],
    dependencies: [
        .package(url: "https://github.com/filom/ASN1Decoder", from: "1.3.0"),
    ],
    targets: [
        .target(name: "AppReceiptValidator",
                dependencies: ["ASN1Decoder"],
                path: "AppReceiptValidator/AppReceiptValidator",
                exclude: [
                    "OpenSSL/openssl.xcframework",
                    "Supporting Files/Info.plist",
                ],
                resources: [
                    .copy("AppleIncRootCertificate.cer")
                ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
