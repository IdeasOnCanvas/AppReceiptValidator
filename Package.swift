// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "AppReceiptValidator",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        // .watchOS(.v6) watchOS doesn't have UIDevice.current so we can parse, but not validate hash, also, it cannot run XCTest
    ],
    products: [.library(name: "AppReceiptValidator", targets: ["AppReceiptValidator"])],
    dependencies: [
        .package(url: "https://github.com/IdeasOnCanvas/ASN1Decoder", from: "1.8.2"),
        .package(url: "https://github.com/apple/swift-crypto", from: "1.1.0")
    ],
    targets: [
        .target(name: "AppReceiptValidator",
                dependencies: ["ASN1Decoder",
                               .product(name: "Crypto", package: "swift-crypto")],
                resources: [
                    .copy("Resources/AppleIncRootCertificate.cer")
                ]
        ),
        .testTarget(name: "AppReceiptValidatorTests",
                    dependencies: ["AppReceiptValidator"],
                    resources: [
                        .copy("Resources/deprecatedSinglesTypeExpiredAppleCert_receipt.b64"),
                        .copy("Resources/grandUnifiedExpiredAppleCert_receipt.b64"),
                        .copy("Resources/hannes_mac_mindnode_pro_receipt"),
                        .copy("Resources/hannes_mac_mindnode_receipt"),
                        .copy("Resources/mac_mindnode_rebought_receipt"),
                        .copy("Resources/mindnode_ios_michaelsandbox_receipt1.b64"),
                        .copy("Resources/mindnode_ios_michaelsandbox_receipt2.b64"),
                        .copy("Resources/not_a_receipt"),
                        .copy("Resources/frank4dd-cacert.der")
                    ])
    ],
    swiftLanguageVersions: [.v5]
)
