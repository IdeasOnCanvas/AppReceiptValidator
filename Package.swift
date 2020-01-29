// swift-tools-version:5.0
import PackageDescription


let package = Package(
    name: "AppReceiptValidator",
    platforms: [
        .macOS(.v10_11), .iOS(.v9)
    ],
    products: [
        .library(name: "AppReceiptValidator", targets: ["AppReceiptValidator"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/open-crypto.git", from: "4.0.0-beta.2")
    ],
    targets: [
        .target(name: "AppReceiptValidator", dependencies: ["OpenCrypto"]),
        .testTarget(name: "AppReceiptValidatorTests", dependencies: ["AppReceiptValidator"])
    ],
    swiftLanguageVersions: [.v5]
)