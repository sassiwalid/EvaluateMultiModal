// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ReceiptKit",
    platforms: [.iOS("27.0"), .macOS("27.0"), .visionOS("27.0")],
    products: [
        .library(name: "ReceiptKit", targets: ["ReceiptKit"])
    ],
    targets: [
        .target(name: "ReceiptKit")
    ]
)
