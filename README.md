# Swift Native

[![CI](https://github.com/avijeetpandey/swift-native/actions/workflows/ci.yml/badge.svg)](https://github.com/avijeetpandey/swift-native/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-6-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Android-blue.svg)

**Write your app once in Swift. Get genuinely native UI on macOS, iOS and Android.**

Swift Native is a React Native–style framework, except the language is Swift all
the way down. You describe your UI with a SwiftUI-like API; it renders to **real
AppKit views on macOS, real UIKit views on iOS, and real `android.view.View`s on
Android**. No webview, no HTML, no JavaScript, no bundled browser. Your app logic
compiles to native machine code on every platform — there's no interpreter and no
garbage collector on Apple platforms.

```swift
struct Counter: View {
    @State private var count = 0
    var body: some View {
        VStack(spacing: 16) {
            Text("Count: \(count)").font(.title)
            Button("Increment") { count += 1 }
        }
        .padding(24)
    }
}
```

That single view becomes an `NSStackView` + `NSTextField` + `NSButton` on macOS,
a `UIStackView` + `UILabel` + `UIButton` on iOS, and a `LinearLayout` +
`TextView` + `Button` on Android.

---

## Contents

- [Quick start](#quick-start)
- [What it looks like running](#what-it-looks-like-running)
- [How it works](#how-it-works)
- [The CLI](#the-cli)
- [Platform support](#platform-support)
- [Testing](#testing)
- [Documentation](#documentation)
- [Project structure](#project-structure)
- [Status and honest limitations](#status-and-honest-limitations)
- [Roadmap](#roadmap)
- [A note on prior art](#a-note-on-prior-art)

---

## Quick start

You only need a Swift 6 toolchain to get going — **no Xcode and no Android SDK
required** to build the framework and run an app natively on macOS.

```sh
git clone https://github.com/avijeetpandey/swift-native.git
cd swift-native
swift build

# scaffold a new app
swift run swiftnative new MyApp
cd MyApp

# run it natively
swift run --package-path ../ swiftnative run            # opens a native macOS window
swift run --package-path ../ swiftnative run --preview  # prints the native view tree
```

Once the `swiftnative` binary is on your `PATH` it's simply:

```sh
swiftnative new MyApp
cd MyApp
swiftnative run
```

New here? Start with **[GETTING_STARTED.md](GETTING_STARTED.md)**.

## What it looks like running

`swiftnative run --preview` mounts your app on the real AppKit backend without
opening a window and prints the native view tree — and it can replay clicks, so
you can verify behaviour from the terminal or in CI:

```sh
swiftnative run --preview --tap Todos --tap "Add Task"
```

```
── after tapping "Add Task" ──
NSStackView
  NSTextField "To-do (3)"
  NSButton "Add"
  NSStackView
    NSStackView
      NSTextField "Learn Swift Native"
      NSButton "Delete"
    NSStackView
      NSTextField "Task 3"
      NSButton "Delete"
  NSBox(separator)
  NSStackView
    NSButton "Counter"  NSButton "To-do"  NSButton "Settings"
```

Those are real `NSTextField`/`NSButton`/`NSStackView` objects, updated by genuine
`NSButton` clicks routed back into your Swift state.

## How it works

Your views are flattened into a lightweight node tree. A **reconciler** diffs the
old tree against the new one and emits the *minimal* set of changes — so a counter
tap produces exactly one "set text" instruction, not a rebuild. Each platform has
a thin **backend** that applies those changes to native widgets.

```
View tree  ──▶  Reconciler (keyed diff)  ──▶  [ mutations ]  ──▶  native backend
```

`SwiftNativeCore` — the views, reconciler, layout, state and runtime — has **zero
imports**, not even Foundation, so the exact same code compiles for macOS, iOS and
Android. The full design is written up in
**[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

| React Native | Swift Native |
|---|---|
| JavaScript + Hermes (interpreted) | **Swift, compiled natively** on every platform |
| JSI / bridge | Direct calls on Apple platforms · **JNI** on Android |
| Fabric shadow tree + diff | `Reconciler` → batched `Mutation` list |
| Yoga (Flexbox) | A small built-in layout pass (Flexbox-replaceable) |
| Host views (UIView / Android View) | `AppKitBackend` / `UIKitBackend` / `AndroidBackend` |
| Native modules / TurboModules | The `Backend` protocol |

## The CLI

```
swiftnative new <AppName>      scaffold a new app (App / Screens / Components / Models)
swiftnative run [target]       build & run — target is macos (default), ios or android
swiftnative run --preview      render the native view tree headlessly (great for CI)
swiftnative build [target]     build without running
swiftnative doctor             check every toolchain and print exact fixes
swiftnative devices            list simulators, emulators and devices
swiftnative clean              remove build artifacts
```

`doctor` is the antidote to setup loops: it inspects your machine and tells you
*exactly* what to install for each target, with copy-pasteable commands. You're
never forced through device setup just to start building — macOS runs out of the
box.

## Platform support

| Platform | UI toolkit | Status | Needs |
|---|---|---|---|
| **macOS** | AppKit (`NSView`) | ✅ Runs today, out of the box | Swift 6 toolchain |
| **iOS** | UIKit (`UIView`) | ✅ Backend implemented | Full Xcode — see [SETUP.md](SETUP.md) |
| **Android** | Android Views (via JNI) | ✅ Backend + host implemented | Swift Android SDK + NDK — see [SETUP.md](SETUP.md) |

Setup for iOS and Android is documented step by step in **[SETUP.md](SETUP.md)**.

## Testing

The framework ships its own tiny test framework so the suite runs **without
Xcode**:

```sh
./scripts/test.sh        # 46 cases: unit + integration + end-to-end
./scripts/coverage.sh    # llvm-cov report with an 80% line-coverage gate
```

The integration tests drive the **real AppKit backend** — mounting views,
clicking actual `NSButton`s and asserting on the resulting `NSView` tree — so the
"it's really native" claim is tested, not just stated. Current coverage of the
framework sources is around **87% lines**.

## Documentation

| Doc | What's in it |
|---|---|
| [GETTING_STARTED.md](GETTING_STARTED.md) | Install, scaffold and run your first app |
| [SETUP.md](SETUP.md) | Exact, copy-paste setup for iOS (Xcode) and Android (Swift SDK + NDK) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the renderer, reconciler and backends work |
| [docs/COMPONENTS.md](docs/COMPONENTS.md) | Every component, modifier and value type |
| [docs/EXAMPLES.md](docs/EXAMPLES.md) | Complete, copy-pasteable example apps |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to build, test and contribute |

## Project structure

```
swift-native/
├─ Sources/
│  ├─ SwiftNativeCore/         view DSL, reconciler (keyed), layout, state, runtime
│  ├─ SwiftNativeTestRenderer/ in-memory backend for deterministic tests
│  ├─ SwiftNativeTesting/      Xcode-free test framework
│  ├─ SwiftNativeAppKit/       macOS backend (real NSView) + window/preview runner
│  ├─ SwiftNativeUIKit/        iOS backend (real UIKit)
│  ├─ SwiftNativeAndroid/      Android backend (native Swift + JNI)
│  ├─ CounterExample/          a small shared example
│  ├─ SwiftNativeTestSuite/    unit + integration + e2e tests (runnable)
│  └─ swiftnative/             the command-line tool
├─ android-host/              Kotlin host + JNI C bridge for Android
├─ docs/                      architecture, components, examples
├─ scripts/                   test.sh, coverage.sh
└─ Tests/                     XCTest mirror (for Xcode users)
```

## Status and honest limitations

This is a real, working framework, but it's young. In the spirit of no surprises:

**Works today, verified:**
- The core engine — views, **keyed** reconciler, layout, `@State`/`@Binding` with
  per-driver isolation and event-batched re-renders.
- A native **macOS (AppKit)** backend. A scaffolded app runs with `swiftnative run`
  and responds to real clicks.
- The CLI, and a test suite of 46 cases (including real-AppKit integration tests)
  with >80% coverage enforced in CI.

**Hard constraints (no hand-waving):**
- **iOS requires a Mac with full Xcode.** That's an Apple constraint, not a choice.
- **Apple's SwiftUI does not run on Android.** Swift Native gives you a
  *SwiftUI-like* API that maps onto native Android views.
- **The framework isn't 100% Swift internally.** The Android bridge needs a small
  Kotlin host and a JNI C shim, plus Gradle. *Your application code is pure Swift.*
- **Android has a small, non-zero runtime cost** — the Swift runtime ships in the
  APK and JNI calls aren't free. It's minimised, not eliminated.
- It's single-window today, with no hot reload yet.

## Roadmap

- A full Flexbox layout pass
- More components and modifiers
- A navigation stack
- Hot reload / fast refresh
- `doctor --fix` to automate installs
- An optional Jetpack Compose backend on Android

## A note on prior art

If your goal is to *ship* a cross-platform app in Swift today, look at
[Skip](https://skip.dev) — it's a mature, open-source product doing this in
production. Swift Native exists to build the thing from first principles and
understand every layer, from the reconciler to the JNI bridge. It stands on the
shoulders of the official [Swift Android
workgroup](https://www.swift.org/android-workgroup/) and the
[Swift SDK for Android](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html).
