// Doctor.swift — `swiftnative doctor`: detect and validate every toolchain
// needed to build Swift Native apps, with exact, verified remediation. This is
// the "one-step setup, no setup loop" entry point.

import Foundation

struct Check {
    enum Status { case ok, warn, missing }
    let name: String
    let status: Status
    let detail: String
    let fix: [String]
}

enum Doctor {
    static func run(arguments: [String]) -> Int32 {
        let strict = arguments.contains("--strict")
        print(ANSI.bold("\nswiftnative doctor") + ANSI.dim("  — toolchain readiness\n"))

        let common = commonChecks()
        let ios = iosChecks()
        let android = androidChecks()

        printSection("Common", common)
        printSection("iOS", ios)
        printSection("Android", android)

        let all = common + ios + android
        let okCount = all.filter { $0.status == .ok }.count
        let warnCount = all.filter { $0.status == .warn }.count
        let missingCount = all.filter { $0.status == .missing }.count

        print(
            ANSI.bold("Summary: ") + ANSI.green("\(okCount) ok") + ", " + ANSI.yellow("\(warnCount) warnings")
                + ", " + ANSI.red("\(missingCount) missing"))

        let iosReady = ios.allSatisfy { $0.status != .missing }
        let androidReady = android.allSatisfy { $0.status != .missing }
        print("  iOS builds:     " + (iosReady ? ANSI.green("ready") : ANSI.red("blocked")))
        print("  Android builds: " + (androidReady ? ANSI.green("ready") : ANSI.red("blocked")))
        print("")

        if strict && missingCount > 0 { return 1 }
        return 0
    }

    private static func printSection(_ title: String, _ checks: [Check]) {
        print(ANSI.bold(title))
        for check in checks {
            let mark: String
            switch check.status {
            case .ok: mark = ANSI.green("✓")
            case .warn: mark = ANSI.yellow("!")
            case .missing: mark = ANSI.red("✗")
            }
            let name = check.name.padding(toLength: 22, withPad: " ", startingAt: 0)
            print("  \(mark) \(name) \(check.detail)")
            if check.status != .ok {
                for line in check.fix {
                    print("      " + ANSI.dim("→ ") + ANSI.cyan(line))
                }
            }
        }
        print("")
    }

    // MARK: - Common

    private static func commonChecks() -> [Check] {
        var checks: [Check] = []

        if let info = swiftInfo() {
            checks.append(
                Check(
                    name: "Swift toolchain",
                    status: .ok,
                    detail: "\(info.version) (\(info.isApple ? "Apple" : "open-source"))",
                    fix: []
                ))
        } else {
            checks.append(
                Check(
                    name: "Swift toolchain",
                    status: .missing,
                    detail: "not found",
                    fix: ["Install Swift from https://swift.org/install"]
                ))
        }

        if let java = javaMajor() {
            checks.append(
                Check(
                    name: "JDK (17+)",
                    status: java >= 17 ? .ok : .warn,
                    detail: "Java \(java)",
                    fix: java >= 17 ? [] : ["Install JDK 17+: brew install openjdk"]
                ))
        } else {
            checks.append(
                Check(
                    name: "JDK (17+)",
                    status: .missing,
                    detail: "not found",
                    fix: ["brew install openjdk"]
                ))
        }

        return checks
    }

    // MARK: - iOS

    private static func iosChecks() -> [Check] {
        var checks: [Check] = []
        let xcode = xcodeSelectPath()
        let hasFullXcode = xcode?.contains("Xcode.app") ?? false

        if hasFullXcode, let version = xcodebuildVersion() {
            checks.append(Check(name: "Xcode", status: .ok, detail: version, fix: []))
        } else {
            checks.append(
                Check(
                    name: "Xcode",
                    status: .missing,
                    detail: hasFullXcode ? "present but xcodebuild failed" : "Command Line Tools only",
                    fix: [
                        "Install Xcode from the App Store (required for iOS — Apple constraint),",
                        "then: sudo xcode-select -s /Applications/Xcode.app",
                    ]
                ))
        }

        let simctl = Shell.run("/usr/bin/xcrun", ["simctl", "help"]).ok
        checks.append(
            Check(
                name: "iOS Simulator",
                status: simctl ? .ok : .missing,
                detail: simctl ? "simctl available" : "unavailable (needs Xcode)",
                fix: simctl ? [] : ["Provided by Xcode; install Xcode first."]
            ))

        return checks
    }

    // MARK: - Android

    private static func androidChecks() -> [Check] {
        var checks: [Check] = []

        // Open-source toolchain requirement for cross-compiling on macOS.
        if let info = swiftInfo(), info.isApple {
            checks.append(
                Check(
                    name: "OSS Swift (Android)",
                    status: .warn,
                    detail: "Apple toolchain active; cross-compile needs the open-source build",
                    fix: [
                        "Install swiftly + a matching OSS toolchain:",
                        "  curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash",
                        "  swiftly install \(info.version)",
                    ]
                ))
        }

        // Swift Android SDK bundle.
        let sdkList = Shell.tool("swift", ["sdk", "list"]).stdout.lowercased()
        let hasAndroidSDK = sdkList.contains("android")
        checks.append(
            Check(
                name: "Swift Android SDK",
                status: hasAndroidSDK ? .ok : .missing,
                detail: hasAndroidSDK ? "installed" : "not installed",
                fix: hasAndroidSDK
                    ? []
                    : [
                        "swift sdk install \\",
                        "  https://download.swift.org/swift-6.3.2-release/android-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_android.artifactbundle.tar.gz \\",
                        "  --checksum 939e933549d12d28f2e0bf71019d734d309859e9773c572657ce565a81f85d68",
                    ]
            ))

        // Android SDK.
        let sdk = androidHome()
        checks.append(
            Check(
                name: "Android SDK",
                status: sdk != nil ? .ok : .missing,
                detail: sdk ?? "not found (set ANDROID_HOME)",
                fix: sdk != nil
                    ? []
                    : [
                        "Install the Android SDK (Android Studio, or cmdline-tools), then:",
                        "  export ANDROID_HOME=$HOME/Library/Android/sdk",
                    ]
            ))

        // Android NDK r27d+.
        let ndk = ndkHome(sdk: sdk)
        checks.append(
            Check(
                name: "Android NDK (r27d+)",
                status: ndk != nil ? .ok : .missing,
                detail: ndk ?? "not found (set ANDROID_NDK_HOME)",
                fix: ndk != nil
                    ? []
                    : [
                        "Download NDK r27d: https://developer.android.com/ndk/downloads",
                        "then: export ANDROID_NDK_HOME=<path-to-ndk>",
                    ]
            ))

        // adb / emulator.
        let adb =
            sdk.map { $0 + "/platform-tools/adb" }.flatMap { FS.exists($0) ? $0 : nil } ?? Shell.which("adb")
        checks.append(
            Check(
                name: "adb",
                status: adb != nil ? .ok : .missing,
                detail: adb ?? "not found",
                fix: adb != nil ? [] : ["Provided by Android SDK platform-tools."]
            ))

        let emulator = sdk.map { $0 + "/emulator/emulator" }.flatMap { FS.exists($0) ? $0 : nil }
        checks.append(
            Check(
                name: "Android emulator",
                status: emulator != nil ? .ok : .warn,
                detail: emulator ?? "no emulator binary (a physical device also works)",
                fix: emulator != nil
                    ? []
                    : [
                        "Install via: sdkmanager --install emulator 'system-images;android-34;google_apis;arm64-v8a'"
                    ]
            ))

        return checks
    }

    // MARK: - Detection helpers

    static func swiftInfo() -> (version: String, isApple: Bool)? {
        let result = Shell.tool("swift", ["--version"])
        guard result.ok else { return nil }
        let text = result.stdout + result.stderr
        let isApple = text.contains("Apple Swift")
        var version = "unknown"
        if let range = text.range(of: #"version ([0-9]+\.[0-9]+(\.[0-9]+)?)"#, options: .regularExpression) {
            version = String(text[range]).replacingOccurrences(of: "version ", with: "")
        }
        return (version, isApple)
    }

    static func javaMajor() -> Int? {
        let result = Shell.tool("java", ["-version"])
        let text = result.stdout + result.stderr
        guard let range = text.range(of: #"version "([0-9]+)"#, options: .regularExpression) else {
            // Some JDKs print "26.0.1" — grab the first integer.
            if let r = text.range(of: #"([0-9]+)\."#, options: .regularExpression) {
                return Int(text[r].dropLast())
            }
            return nil
        }
        let digits = text[range].filter { $0.isNumber }
        return Int(digits)
    }

    static func xcodeSelectPath() -> String? {
        let result = Shell.run("/usr/bin/xcode-select", ["-p"])
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.ok && !path.isEmpty ? path : nil
    }

    static func xcodebuildVersion() -> String? {
        let result = Shell.run("/usr/bin/xcrun", ["xcodebuild", "-version"])
        guard result.ok else { return nil }
        return result.stdout.split(separator: "\n").first.map(String.init)
    }

    static func androidHome() -> String? {
        if let h = Env.value("ANDROID_HOME"), FS.isDir(h) { return h }
        if let h = Env.value("ANDROID_SDK_ROOT"), FS.isDir(h) { return h }
        let def = Env.home + "/Library/Android/sdk"
        return FS.isDir(def) ? def : nil
    }

    static func ndkHome(sdk: String?) -> String? {
        if let h = Env.value("ANDROID_NDK_HOME"), FS.isDir(h) { return h }
        if let sdk, FS.isDir(sdk + "/ndk") {
            let versions = (try? FileManager.default.contentsOfDirectory(atPath: sdk + "/ndk")) ?? []
            if let latest = versions.sorted().last { return sdk + "/ndk/" + latest }
        }
        return nil
    }
}
