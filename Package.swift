// swift-tools-version:5.0
import PackageDescription


let package = Package(
    name: "AppReceiptValidator",
    platforms: [
        .macOS(.v10_14), .iOS(.v9)
    ],
    products: [
        .library(name: "AppReceiptValidator", targets: ["AppReceiptValidator"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/crypto.git", from: "3.3.0")
    ],
    targets: [
        .target(name: "AppReceiptValidator", dependencies: ["Crypto"]),
        .testTarget(name: "AppReceiptValidatorTests", dependencies: ["AppReceiptValidator"])
    ],
    swiftLanguageVersions: [.v5]
)