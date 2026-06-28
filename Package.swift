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
        .library(name: "SwiftNativeUIKit", targets: ["SwiftNativeUIKit"]),
        .library(name: "SwiftNativeAndroid", targets: ["SwiftNativeAndroid"]),
        .library(name: "CounterExample", targets: ["CounterExample"]),
    ],
    targets: [
        .target(name: "SwiftNativeCore"),
        .target(name: "SwiftNativeTestRenderer", dependencies: ["SwiftNativeCore"]),
        .target(name: "SwiftNativeAppKit", dependencies: ["SwiftNativeCore"]),
        .target(name: "SwiftNativeUIKit", dependencies: ["SwiftNativeCore"]),
        .target(name: "SwiftNativeAndroid", dependencies: ["SwiftNativeCore"]),
        .target(name: "CounterExample", dependencies: ["SwiftNativeCore"]),
    ]
)
