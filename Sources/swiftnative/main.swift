// main.swift — swiftnative CLI entry point and command dispatch.

import Foundation

let version = "0.2.0"

func printUsage() {
    print(
        """
        \(ANSI.bold("swiftnative")) \(ANSI.dim("v\(version)")) — one Swift codebase, native on macOS, iOS and Android

        \(ANSI.bold("USAGE"))
          swiftnative <command> [options]

        \(ANSI.bold("COMMANDS"))
          doctor              Check that all toolchains are installed (run this first)
          new <AppName>       Scaffold a new Swift Native app
          run [target]        Build & run. Targets: macos (default), ios, android.
                              Use --preview for a headless native render.
          build [target]      Build without launching
          devices             List available simulators, emulators and devices
          clean               Remove build artifacts
          help                Show this help
          version             Print the version

        \(ANSI.bold("EXAMPLES"))
          swiftnative new HelloWorld
          cd HelloWorld
          swiftnative run                \(ANSI.dim("# native macOS window"))
          swiftnative run --preview      \(ANSI.dim("# headless native tree (CI-friendly)"))
          swiftnative run ios            \(ANSI.dim("# iOS Simulator (needs Xcode)"))
          swiftnative run android        \(ANSI.dim("# Android (needs Android SDK/NDK)"))

        \(ANSI.dim("Setup is one command (`doctor`); building still requires Xcode (iOS) and"))
        \(ANSI.dim("the Android SDK/NDK + Swift Android SDK (Android). `doctor` guides you."))
        """)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    printUsage()
    exit(0)
}
let rest = Array(arguments.dropFirst())

let exitCode: Int32
switch command {
case "doctor":
    exitCode = Doctor.run(arguments: rest)
case "new":
    exitCode = Commands.new(arguments: rest)
case "run":
    exitCode = Commands.run(arguments: rest)
case "build":
    exitCode = Commands.build(arguments: rest)
case "devices":
    exitCode = Commands.devices(arguments: rest)
case "clean":
    exitCode = Commands.clean(arguments: rest)
case "version", "--version", "-v":
    print("swiftnative \(version)")
    exitCode = 0
case "help", "--help", "-h":
    printUsage()
    exitCode = 0
default:
    print(ANSI.red("error: ") + "unknown command '\(command)'\n")
    printUsage()
    exitCode = 1
}
exit(exitCode)
