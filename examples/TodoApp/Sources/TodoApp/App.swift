import SwiftNativeCore

#if canImport(AppKit)
import SwiftNativeAppKit
#endif

func makeRoot() -> AnyView { AnyView(RootView()) }

struct RootView: View {
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            if tab == 0 {
                TodoScreen()
            } else {
                AboutScreen()
            }

            Divider()

            HStack(spacing: 24) {
                Button("To-do") { tab = 0 }
                Button("About") { tab = 1 }
            }
            .padding(12)
        }
    }
}

@main
struct TodoApp {
    static func main() {
        #if canImport(AppKit)
        if CommandLine.arguments.contains("--preview") {
            let taps = parseTaps(CommandLine.arguments)
            print(SwiftNativePreview.render(taps: taps) { makeRoot() })
        } else {
            SwiftNativeApp.run(title: "TodoApp") { makeRoot() }
        }
        #else
        print("Run on macOS, or build for iOS/Android. See the Swift Native README.")
        #endif
    }

    static func parseTaps(_ args: [String]) -> [String] {
        var taps: [String] = []
        var i = 0
        while i < args.count {
            if args[i] == "--tap", i + 1 < args.count {
                taps.append(args[i + 1])
                i += 2
            } else {
                i += 1
            }
        }
        return taps
    }
}
