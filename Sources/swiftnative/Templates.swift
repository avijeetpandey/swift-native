// Templates.swift — embedded sources for `swiftnative new`. The scaffold uses a
// familiar, RN-like layout (App entry point + Screens/Components/Models) and is
// runnable out of the box: native window on a Mac, headless preview anywhere.

enum Templates {
    static func packageSwift(appName: String, swiftnativePath: String) -> String {
        """
        // swift-tools-version:6.0
        import PackageDescription

        let package = Package(
            name: "\(appName)",
            platforms: [.macOS(.v13), .iOS(.v15)],
            dependencies: [
                .package(path: "\(swiftnativePath)"),
            ],
            targets: [
                .executableTarget(
                    name: "\(appName)",
                    dependencies: [
                        .product(name: "SwiftNativeCore", package: "swiftnative"),
                        .product(name: "SwiftNativeAppKit", package: "swiftnative"),
                        .product(name: "SwiftNativeUIKit", package: "swiftnative"),
                        .product(name: "SwiftNativeAndroid", package: "swiftnative"),
                    ]
                ),
            ]
        )
        """
    }

    static func appEntry(appName: String) -> String {
        """
        import SwiftNativeCore
        #if canImport(AppKit)
        import SwiftNativeAppKit
        #endif

        // The shared root of your app — rendered natively on every platform.
        func makeRoot() -> AnyView { AnyView(RootView()) }

        struct RootView: View {
            @State private var tab = 0
            var body: some View {
                VStack(spacing: 0) {
                    if tab == 0 {
                        HomeScreen()
                    } else if tab == 1 {
                        TodoScreen()
                    } else {
                        SettingsScreen()
                    }
                    Divider()
                    TabBar(tab: $tab)
                }
            }
        }

        struct TabBar: View {
            @Binding var tab: Int
            var body: some View {
                HStack(spacing: 24) {
                    Button("Home") { tab = 0 }
                    Button("Todos") { tab = 1 }
                    Button("Settings") { tab = 2 }
                }
                .padding(12)
            }
        }

        // Entry point. `--preview` renders the native tree headlessly (great for
        // CI or a machine without a display); otherwise it opens a native window.
        // `--tap "Button Title"` (repeatable) drives native clicks in preview.
        @main
        struct \(appName)App {
            static func main() {
                let args = CommandLine.arguments
                let preview = args.contains("--preview")
                var taps: [String] = []
                var i = 0
                while i < args.count {
                    if args[i] == "--tap", i + 1 < args.count { taps.append(args[i + 1]); i += 2 }
                    else { i += 1 }
                }
                #if canImport(AppKit)
                if preview {
                    print(SwiftNativePreview.render(taps: taps) { makeRoot() })
                } else {
                    SwiftNativeApp.run(title: "\(appName)") { makeRoot() }
                }
                #else
                print("Run on macOS (AppKit) or build for iOS/Android. See README.")
                #endif
            }
        }
        """
    }

    static func homeScreen() -> String {
        """
        import SwiftNativeCore

        struct HomeScreen: View {
            @State private var count = 0
            var body: some View {
                VStack(spacing: 16) {
                    Text("Welcome to Swift Native")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("A counter, rendered with native widgets:")
                    Text("Count: \\(count)")
                        .font(.system(size: 22, weight: .bold))
                    HStack(spacing: 12) {
                        Button("−") { count -= 1 }
                        Button("+") { count += 1 }
                    }
                }
                .padding(24)
            }
        }
        """
    }

    static func todoScreen() -> String {
        """
        import SwiftNativeCore

        struct TodoScreen: View {
            @State private var todos: [Todo] = [
                Todo(id: 1, title: "Learn Swift Native"),
                Todo(id: 2, title: "Build something great"),
            ]
            @State private var nextID = 3

            var body: some View {
                VStack(spacing: 12) {
                    Text("Todos (\\(todos.count))").font(.title)
                    Button("Add Task") {
                        todos.append(Todo(id: nextID, title: "New task \\(nextID)"))
                        nextID += 1
                    }
                    List {
                        ForEach(todos) { todo in
                            HStack {
                                Text(todo.title)
                                Button("Delete") { todos.removeAll { $0.id == todo.id } }
                            }
                            .padding(8)
                        }
                    }
                }
                .padding(24)
            }
        }
        """
    }

    static func settingsScreen() -> String {
        """
        import SwiftNativeCore

        struct SettingsScreen: View {
            @State private var notifications = true
            @State private var darkMode = false
            var body: some View {
                VStack(spacing: 16) {
                    Text("Settings").font(.title)
                    Toggle("Notifications", isOn: $notifications)
                    Toggle("Dark Mode", isOn: $darkMode)
                    Text(notifications ? "Notifications on" : "Notifications off")
                }
                .padding(24)
            }
        }
        """
    }

    static func todoModel() -> String {
        """
        // A simple model type used by the Todo screen.
        struct Todo: Identifiable {
            let id: Int
            var title: String
            var done: Bool = false
        }
        """
    }

    static func androidEntry(appName: String) -> String {
        """
        // Android entry point. The Swift core compiles to a native .so; the Kotlin
        // host (in the swiftnative package's android-host/) calls this to start.
        #if os(Android)
        import SwiftNativeCore
        import SwiftNativeAndroid

        @_cdecl("\(appName.lowercased())_register_root")
        public func registerRoot() {
            androidRootBuilder = { makeRoot() }
        }
        #endif
        """
    }

    static func readme(appName: String) -> String {
        """
        # \(appName)

        A Swift Native app — one Swift codebase, native UI on macOS, iOS and Android.

        ## Run it now (no Xcode/Android needed)

        ```sh
        swiftnative run            # native macOS window
        swiftnative run --preview  # headless: prints the native view tree
        ```

        ## Run on a device

        ```sh
        swiftnative doctor         # one-time: check toolchains
        swiftnative run ios        # iOS Simulator (requires Xcode)
        swiftnative run android    # Android emulator/device (requires Android SDK/NDK)
        ```

        See `SETUP.md` in the Swift Native repo for the exact, copy-paste setup.

        ## Structure

        - `Sources/\(appName)/App.swift` — entry point + shared root view
        - `Sources/\(appName)/Screens/` — Home, Todo, Settings screens
        - `Sources/\(appName)/Components/` — reusable views
        - `Sources/\(appName)/Models/` — model types
        - `Sources/\(appName)/Android.swift` — Android entry point
        """
    }

    static func gitignore() -> String {
        """
        .build/
        .swiftpm/
        .DS_Store
        *.profraw
        *.profdata
        """
    }
}
