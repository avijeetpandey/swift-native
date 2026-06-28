// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "swiftnative",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(name: "SwiftNativeCore", targets: ["SwiftNativeCore"]),
        .library(name: "SwiftNativeTestRenderer", targets: ["SwiftNativeTestRenderer"]),
        .library(name: "SwiftNativeAppKit", targets: ["SwiftNativeAppKit"]),
        .library(name: "CounterExample", targets: ["CounterExample"]),
    ],
    targets: [
        .target(name: "SwiftNativeCore"),
        .target(name: "SwiftNativeTestRenderer", dependencies: ["SwiftNativeCore"]),
        .target(name: "SwiftNativeAppKit", dependencies: ["SwiftNativeCore"]),
        .target(name: "CounterExample", dependencies: ["SwiftNativeCore"]),
    ]
)
