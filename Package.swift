// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "swiftnative",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(name: "SwiftNativeCore", targets: ["SwiftNativeCore"])
    ],
    targets: [
        .target(name: "SwiftNativeCore")
    ]
)
