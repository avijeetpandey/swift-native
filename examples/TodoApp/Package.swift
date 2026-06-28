// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TodoApp",
    platforms: [.macOS(.v13), .iOS(.v15)],
    dependencies: [
        // The Swift Native framework, referenced from this repo.
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "TodoApp",
            dependencies: [
                .product(name: "SwiftNativeCore", package: "swiftnative"),
                .product(name: "SwiftNativeAppKit", package: "swiftnative"),
            ]
        )
    ]
)
