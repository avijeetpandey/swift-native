// CLI.swift — shared utilities: shell execution, terminal styling, filesystem.

import Foundation

enum ANSI {
    static let enabled = isatty(fileno(stdout)) != 0
    static func wrap(_ code: String, _ text: String) -> String {
        enabled ? "\u{001B}[\(code)m\(text)\u{001B}[0m" : text
    }
    static func bold(_ t: String) -> String { wrap("1", t) }
    static func green(_ t: String) -> String { wrap("32", t) }
    static func red(_ t: String) -> String { wrap("31", t) }
    static func yellow(_ t: String) -> String { wrap("33", t) }
    static func cyan(_ t: String) -> String { wrap("36", t) }
    static func dim(_ t: String) -> String { wrap("2", t) }
}

struct CommandResult {
    let code: Int32
    let stdout: String
    let stderr: String
    var ok: Bool { code == 0 }
}

enum Shell {
    /// Run an executable found on PATH and capture its output.
    @discardableResult
    static func run(_ launchPath: String, _ arguments: [String], environment: [String: String]? = nil)
        -> CommandResult
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return CommandResult(code: 127, stdout: "", stderr: "failed to launch \(launchPath): \(error)")
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(
            code: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }

    /// Run a tool by name, resolving it via `/usr/bin/env`.
    @discardableResult
    static func tool(_ name: String, _ arguments: [String], environment: [String: String]? = nil)
        -> CommandResult
    {
        run("/usr/bin/env", [name] + arguments, environment: environment)
    }

    /// Locate an executable on PATH; returns its path or nil.
    static func which(_ name: String) -> String? {
        let result = run("/usr/bin/which", [name])
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.ok && !path.isEmpty ? path : nil
    }
}

enum Env {
    static func value(_ key: String) -> String? {
        let v = ProcessInfo.processInfo.environment[key]
        return (v?.isEmpty ?? true) ? nil : v
    }
    static var home: String { ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory() }
}

enum FS {
    static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    static func isDir(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
    static func firstExisting(_ paths: [String]) -> String? {
        paths.first(where: exists)
    }
}

enum SwiftNativeLocation {
    /// Locate the swiftnative package root. Uses `SWIFTNATIVE_HOME` if set,
    /// otherwise derives it from this source file's compile-time path (which
    /// lives inside the package), walking up to the directory with Package.swift.
    static func packageRoot() -> String? {
        if let env = Env.value("SWIFTNATIVE_HOME"), FS.exists(env + "/Package.swift") {
            return env
        }
        var dir = (#filePath as NSString).deletingLastPathComponent
        for _ in 0..<6 {
            let pkg = dir + "/Package.swift"
            if FS.exists(pkg), let contents = try? String(contentsOfFile: pkg, encoding: .utf8),
                contents.contains("name: \"swiftnative\"")
            {
                return dir
            }
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir { break }
            dir = parent
        }
        return nil
    }
}
