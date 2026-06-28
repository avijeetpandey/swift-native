# Getting Started with Swift Native

Build a native iOS + Android + macOS app from one Swift codebase — and see it
running in under a minute, with **no Xcode or Android SDK required to start**.

## 1. Build the toolchain (once)

```sh
cd swiftnative
swift build
```

This produces the `swiftnative` CLI at `.build/debug/swiftnative`. Optionally put
it on your PATH:

```sh
export PATH="$PWD/.build/debug:$PATH"
```

## 2. Create an app

```sh
swiftnative new MyApp
cd MyApp
```

You get a familiar, RN-like structure:

```
MyApp/
├─ Package.swift
├─ Sources/MyApp/
│  ├─ App.swift             # entry point + shared root view (tabs)
│  ├─ Screens/              # HomeScreen, TodoScreen, SettingsScreen
│  ├─ Components/           # your reusable views
│  └─ Models/               # Todo, etc.
└─ README.md
```

## 3. Run it immediately (native, no extra setup)

```sh
swiftnative run --preview            # headless: prints the real native view tree
swiftnative run                      # opens a native macOS window
```

Drive it from the command line in preview mode:

```sh
swiftnative run --preview --tap Todos --tap "Add Task"
```

…and you'll see the native `NSView` tree update after each real click.

## 4. Write UI

Swift Native uses a SwiftUI-like API:

```swift
import SwiftNativeCore

struct CounterScreen: View {
    @State private var count = 0
    var body: some View {
        VStack(spacing: 16) {
            Text("Count: \(count)").font(.title)
            HStack {
                Button("−") { count -= 1 }
                Button("+") { count += 1 }
            }
        }
        .padding(24)
    }
}
```

Lists use `ForEach` with stable identity:

```swift
List {
    ForEach(todos) { todo in
        HStack { Text(todo.title); Button("Delete") { remove(todo) } }
    }
}
```

### Components
`Text`, `Button`, `Image`, `VStack`, `HStack`, `ZStack`, `Spacer`, `Divider`,
`ScrollView`, `List`, `ForEach`, `Toggle`.

### Modifiers
`.padding`, `.foregroundColor`, `.background`, `.font`, `.frame`, `.cornerRadius`.

### State
`@State`, `@Binding` — and `$value` to pass a binding to a child view.

## 5. Ship to a device when ready

```sh
swiftnative doctor          # tells you exactly what (if anything) to install
swiftnative run ios         # iOS Simulator   (needs Xcode — see SETUP.md)
swiftnative run android     # Android device  (needs Android SDK/NDK — see SETUP.md)
```

You are never forced through device setup just to start building — `doctor`
guides you only when you choose to target a device.

## 6. Run the framework's tests

```sh
./scripts/test.sh           # unit + integration + e2e (no Xcode needed)
./scripts/coverage.sh       # line/region/function coverage with an 80% gate
```

## Where to next

- [docs/COMPONENTS.md](docs/COMPONENTS.md) — every component, modifier and value type
- [docs/EXAMPLES.md](docs/EXAMPLES.md) — complete example apps
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how it all works under the hood
- [SETUP.md](SETUP.md) — set up iOS and Android builds
- [README.md](README.md) — project overview
