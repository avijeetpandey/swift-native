# Contributing

Thanks for taking a look. Swift Native is a from-scratch, native cross-platform
UI framework, and there's plenty to build — contributions are welcome.

## Getting set up

You only need a Swift 6 toolchain to work on the core and the macOS backend:

```sh
git clone <your-fork-url>
cd swiftnative
swift build
./scripts/test.sh
```

For iOS or Android work, see [SETUP.md](SETUP.md).

## Before you open a PR

Please make sure:

1. **It builds** — `swift build`
2. **Tests pass** — `./scripts/test.sh` (46+ cases: unit, integration, e2e)
3. **Coverage holds** — `./scripts/coverage.sh` keeps line coverage above 80%
4. **It's formatted** — `swift format --in-place --recursive --configuration .swift-format Sources Tests`
   and the lint check is clean:
   `swift format lint --strict --recursive --configuration .swift-format Sources Tests`

CI runs the same build, test and lint steps on every PR.

## Project layout

```
Sources/
  SwiftNativeCore/         the platform-agnostic engine (zero imports)
  SwiftNativeTestRenderer/ in-memory backend for tests
  SwiftNativeTesting/      tiny Xcode-free test framework
  SwiftNativeAppKit/       macOS backend
  SwiftNativeUIKit/        iOS backend
  SwiftNativeAndroid/      Android backend (native Swift + JNI)
  SwiftNativeTestSuite/    the test runner
  swiftnative/             the CLI
android-host/              Kotlin host + JNI bridge for Android
docs/                      architecture, components, examples
scripts/                   test.sh, coverage.sh
```

A good place to start reading is [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Where help is wanted

- More components and modifiers (see `docs/COMPONENTS.md` for the current set)
- A real Flexbox layout pass (the current one is intentionally minimal)
- A navigation stack
- Hot reload
- Exercising the Android backend end to end on a device

## Style

- Match the existing style; the `.swift-format` config is the source of truth.
- Keep `SwiftNativeCore` free of platform imports — it must cross-compile.
- Comment the *why*, not the *what*. The code should read clearly on its own.

## Commits

Small, focused commits with clear messages are easier to review. No particular
convention is enforced.
