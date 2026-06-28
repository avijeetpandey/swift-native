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
        .library(name: "SwiftNativeTesting", targets: ["SwiftNativeTesting"]),
        .library(name: "SwiftNativeUIKit", targets: ["SwiftNativeUIKit"]),
        .library(name: "SwiftNativeAppKit", targets: ["SwiftNativeAppKit"]),
        .library(name: "SwiftNativeAndroid", targets: ["SwiftNativeAndroid"]),
        .library(name: "CounterExample", targets: ["CounterExample"]),
        .executable(name: "swiftnative", targets: ["swiftnative"]),
        .executable(name: "SwiftNativeTestSuite", targets: ["SwiftNativeTestSuite"]),
    ],
    targets: [
        .target(name: "SwiftNativeCore"),
        .target(
            name: "SwiftNativeTestRenderer",
            dependencies: ["SwiftNativeCore"]
        ),
        .target(
            name: "SwiftNativeTesting"
        ),
        .target(
            name: "SwiftNativeUIKit",
            dependencies: ["SwiftNativeCore"]
        ),
        .target(
            name: "SwiftNativeAppKit",
            dependencies: ["SwiftNativeCore"]
        ),
        .target(
            name: "SwiftNativeAndroid",
            dependencies: ["SwiftNativeCore"]
        ),
        .target(
            name: "CounterExample",
            dependencies: ["SwiftNativeCore"]
        ),
        .executableTarget(name: "swiftnative"),
        .executableTarget(
            name: "SwiftNativeTestSuite",
            dependencies: [
                "SwiftNativeCore",
                "SwiftNativeTestRenderer",
                "SwiftNativeTesting",
                "SwiftNativeAppKit",
                "CounterExample",
            ]
        ),
        .testTarget(
            name: "SwiftNativeCoreTests",
            dependencies: [
                "SwiftNativeCore",
                "SwiftNativeTestRenderer",
                "CounterExample",
            ]
        ),
    ]
)
