// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "AppReceiptValidator",
    platforms: [
        .iOS("13.4"),
        .macOS(.v10_15),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "AppReceiptValidator", targets: ["AppReceiptValidator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IdeasOnCanvas/ASN1Decoder", .branch("enhancement/storeBundleIDDataInReceipt")),
        .package(url: "https://github.com/apple/swift-crypto", from: "1.1.0")
    ],
    targets: [
        .target(name: "AppReceiptValidator",
                dependencies: ["ASN1Decoder",
                               .product(name: "Crypto", package: "swift-crypto")],
                path: "AppReceiptValidator/AppReceiptValidator",
                exclude: [
                    "OpenSSL/openssl.xcframework",
                    "Supporting Files/Info.plist",
                ],
                resources: [
                    .copy("AppleIncRootCertificate.cer")
                ]
        ),
        .testTarget(name: "AppReceiptValidatorTests",
                    dependencies: ["AppReceiptValidator"],
                    path: "AppReceiptValidator/AppReceiptValidator Tests Shared",
                    resources: [
                        .process("Test Assets")
                    ])
    ],
    swiftLanguageVersions: [.v5]
)
