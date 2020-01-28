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
    targets: [
        .target(name: "AppReceiptValidator", dependencies: []),
        .testTarget(name: "AppReceiptValidatorTests", dependencies: ["AppReceiptValidator"])
    ],
    swiftLanguageVersions: [.v5]
)