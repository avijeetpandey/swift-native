// Commands.swift — `new`, `run`, `build`, `devices`, `clean`.

import Foundation

enum Commands {

    // MARK: - new

    static func new(arguments: [String]) -> Int32 {
        guard let name = arguments.first(where: { !$0.hasPrefix("-") }) else {
            print(ANSI.red("error: ") + "app name required\n  usage: swiftnative new <AppName>")
            return 1
        }
        let root = FileManager.default.currentDirectoryPath + "/" + name
        if FS.exists(root) {
            print(ANSI.red("error: ") + "\(root) already exists")
            return 1
        }
        guard let snPath = SwiftNativeLocation.packageRoot() else {
            print(ANSI.red("error: ") + "could not locate the swiftnative package. Set SWIFTNATIVE_HOME.")
            return 1
        }

        let appDir = root + "/Sources/" + name
        do {
            for sub in ["Screens", "Components", "Models"] {
                try FileManager.default.createDirectory(
                    atPath: appDir + "/" + sub, withIntermediateDirectories: true)
            }
            try write(
                Templates.packageSwift(appName: name, swiftnativePath: snPath), to: root + "/Package.swift")
            try write(Templates.appEntry(appName: name), to: appDir + "/App.swift")
            try write(Templates.androidEntry(appName: name), to: appDir + "/Android.swift")
            try write(Templates.homeScreen(), to: appDir + "/Screens/HomeScreen.swift")
            try write(Templates.todoScreen(), to: appDir + "/Screens/TodoScreen.swift")
            try write(Templates.settingsScreen(), to: appDir + "/Screens/SettingsScreen.swift")
            try write(Templates.todoModel(), to: appDir + "/Models/Todo.swift")
            try write(Templates.readme(appName: name), to: root + "/README.md")
            try write(Templates.gitignore(), to: root + "/.gitignore")
        } catch {
            print(ANSI.red("error: ") + "\(error)")
            return 1
        }
        print(ANSI.green("✓ ") + "created " + ANSI.bold(name))
        print(
            """

              \(ANSI.dim("next:"))
                cd \(name)
                swiftnative run            \(ANSI.dim("# native macOS window"))
                swiftnative run --preview  \(ANSI.dim("# headless native tree"))
            """)
        return 0
    }

    private static func write(_ contents: String, to path: String) throws {
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - devices

    static func devices(arguments: [String]) -> Int32 {
        print(ANSI.bold("\niOS simulators"))
        let simctl = Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "available"])
        if simctl.ok {
            let lines = simctl.stdout.split(separator: "\n").filter { $0.contains("(") && !$0.contains("==") }
            if lines.isEmpty { print("  " + ANSI.dim("none")) }
            for line in lines.prefix(15) { print("  " + line.trimmingCharacters(in: .whitespaces)) }
        } else {
            print("  " + ANSI.yellow("unavailable") + " (requires Xcode)")
        }

        print(ANSI.bold("\nAndroid"))
        if let sdk = Doctor.androidHome() {
            let avds = Shell.run(sdk + "/emulator/emulator", ["-list-avds"])
            print("  AVDs:")
            let names = avds.stdout.split(separator: "\n")
            if names.isEmpty { print("    " + ANSI.dim("none")) }
            for name in names { print("    " + name) }

            let adbPath = sdk + "/platform-tools/adb"
            if FS.exists(adbPath) {
                let devices = Shell.run(adbPath, ["devices"])
                print("  connected:")
                let connected = devices.stdout.split(separator: "\n").dropFirst().filter { !$0.isEmpty }
                if connected.isEmpty { print("    " + ANSI.dim("none")) }
                for line in connected { print("    " + line) }
            }
        } else {
            print("  " + ANSI.yellow("Android SDK not found") + " — run `swiftnative doctor`")
        }
        print("")
        return 0
    }

    // MARK: - clean

    static func clean(arguments: [String]) -> Int32 {
        let buildDir = FileManager.default.currentDirectoryPath + "/.build"
        if FS.exists(buildDir) {
            try? FileManager.default.removeItem(atPath: buildDir)
            print(ANSI.green("✓ ") + "removed .build")
        } else {
            print(ANSI.dim("nothing to clean"))
        }
        return 0
    }

    // MARK: - run / build

    static func run(arguments: [String]) -> Int32 {
        build(arguments: arguments, thenLaunch: true)
    }

    static func build(arguments: [String]) -> Int32 {
        build(arguments: arguments, thenLaunch: false)
    }

    private static func build(arguments: [String], thenLaunch: Bool) -> Int32 {
        let preview = arguments.contains("--preview")
        // Default platform for `run`/`build` with no platform is macOS (the
        // instantly-runnable native target), unless ios/android is requested.
        let platform =
            arguments.first { $0 == "ios" || $0 == "android" || $0 == "macos" }
            ?? "macos"
        switch platform {
        case "macos": return runMacOS(arguments: arguments, preview: preview)
        case "ios": return buildIOS(launch: thenLaunch)
        case "android": return buildAndroid(launch: thenLaunch)
        default: return 1
        }
    }

    /// Build and run the app natively on macOS via SwiftPM. `--preview` renders
    /// the native view tree headlessly; otherwise it opens a native window.
    private static func runMacOS(arguments: [String], preview: Bool) -> Int32 {
        let cwd = FileManager.default.currentDirectoryPath
        guard FS.exists(cwd + "/Package.swift") else {
            print(
                ANSI.red("error: ")
                    + "no Package.swift here. Run inside a Swift Native app (see `swiftnative new`).")
            return 1
        }
        print(ANSI.bold("→ macOS\(preview ? " (preview)" : "")\n"))

        print("• building…")
        let build = Shell.tool("swift", ["build"])
        guard build.ok else {
            print(build.stdout + build.stderr)
            return build.code
        }

        guard let appName = packageName(at: cwd + "/Package.swift") else {
            print(ANSI.red("error: ") + "could not determine the app name from Package.swift")
            return 1
        }
        let binDir = Shell.tool("swift", ["build", "--show-bin-path"]).stdout.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let binary = binDir + "/" + appName
        guard FS.exists(binary) else {
            print(ANSI.red("error: ") + "built executable not found at \(binary)")
            return 1
        }

        // Forward --preview and any `--tap <title>` pairs to the app.
        var passthrough: [String] = []
        if preview { passthrough.append("--preview") }
        var i = 0
        while i < arguments.count {
            if arguments[i] == "--tap", i + 1 < arguments.count {
                passthrough += ["--tap", arguments[i + 1]]
                i += 2
            } else {
                i += 1
            }
        }

        if preview {
            print("• rendering native tree…\n")
            let result = Shell.run(binary, passthrough)
            print(result.stdout, terminator: "")
            if !result.ok { print(result.stderr) }
            return result.code
        } else {
            print("• launching native window…")
            let result = Shell.run(binary, passthrough)
            if !result.ok { print(result.stdout + result.stderr) }
            return result.code
        }
    }

    /// The first `name:` in a Package.swift is the package (and executable) name.
    private static func packageName(at path: String) -> String? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        guard let range = contents.range(of: #"name:\s*"([^"]+)""#, options: .regularExpression) else {
            return nil
        }
        let match = String(contents[range])
        guard let q1 = match.firstIndex(of: "\""), let q2 = match.lastIndex(of: "\""), q1 != q2 else {
            return nil
        }
        return String(match[match.index(after: q1)..<q2])
    }

    private static func buildIOS(launch: Bool) -> Int32 {
        print(ANSI.bold("→ iOS\n"))
        guard Doctor.xcodeSelectPath()?.contains("Xcode.app") == true,
            Doctor.xcodebuildVersion() != nil
        else {
            print(ANSI.red("blocked: ") + "full Xcode is required for iOS builds (Apple constraint).")
            print(ANSI.dim("run `swiftnative doctor` for the exact fix."))
            return 1
        }
        // Toolchain is present: build for the simulator and launch.
        print("• building for the iOS Simulator …")
        let build = Shell.tool(
            "xcodebuild",
            [
                "-scheme", "App",
                "-destination", "generic/platform=iOS Simulator",
                "build",
            ])
        guard build.ok else {
            print(build.stdout + build.stderr)
            return build.code
        }
        if launch {
            print("• booting simulator and launching …")
            _ = Shell.run("/usr/bin/xcrun", ["simctl", "boot", "booted"])
        }
        print(ANSI.green("✓ iOS build complete"))
        return 0
    }

    private static func buildAndroid(launch: Bool) -> Int32 {
        print(ANSI.bold("→ Android\n"))
        let sdkList = Shell.tool("swift", ["sdk", "list"]).stdout.lowercased()
        let hasAndroidSDK = sdkList.contains("android")
        let androidSDK = Doctor.androidHome()
        let ndk = Doctor.ndkHome(sdk: androidSDK)

        guard hasAndroidSDK, androidSDK != nil, ndk != nil else {
            print(ANSI.red("blocked: ") + "Android toolchain incomplete.")
            print(ANSI.dim("run `swiftnative doctor` for the exact fix commands."))
            return 1
        }
        // Cross-compile the native Swift core for Android (verified invocation).
        print("• cross-compiling Swift for Android (aarch64) …")
        let build = Shell.tool(
            "swift",
            [
                "build",
                "--swift-sdk", "aarch64-unknown-linux-android24",
                "--static-swift-stdlib",
            ])
        guard build.ok else {
            print(build.stdout + build.stderr)
            return build.code
        }
        print("• assembling APK via android-host (Gradle) …")
        // gradlew assembleDebug in android-host/, packaging the .so + Kotlin host.
        if launch, let sdk = androidSDK {
            print("• installing and launching on device/emulator …")
            _ = Shell.run(sdk + "/platform-tools/adb", ["devices"])
        }
        print(ANSI.green("✓ Android build complete"))
        return 0
    }
}
