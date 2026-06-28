# Swift Native — Setup Guide

This guide lists the **exact, copy-paste** steps to enable each build target.
Nothing here is run for you — install only what you need, when you need it.

Swift Native is layered so you are **never stuck in a setup loop**:

| You want to… | You need | Setup time |
|---|---|---|
| Try the framework / run an app now | Just the Swift toolchain (you have it) | none |
| Ship to **macOS** (native window) | Same Swift toolchain | none |
| Ship to **iOS** | Full Xcode | one-time |
| Ship to **Android** | Swift Android SDK + NDK + JDK | one-time |

Run `swiftnative doctor` at any point — it checks everything and prints the exact
fix for whatever is missing.

---

## 0. Zero-setup: run right now (macOS host)

No Xcode, no Android SDK required.

```sh
cd swiftnative
swift build
swift run swiftnative new MyApp        # scaffold an app
cd MyApp
swift run swiftnative run --preview    # render the native view tree headlessly
swift run swiftnative run              # open a native macOS window
```

`--preview` is CI-friendly and works on a machine without a display. It uses
**real AppKit views** (NSTextField/NSButton/NSStackView), not a mock.

---

## 1. iOS setup (one-time)

iOS builds require a Mac with **full Xcode** (Apple constraint — the iOS SDK and
Simulator ship only with Xcode).

```sh
# 1. Install Xcode from the App Store (≈ 10–15 GB), then point the tools at it:
sudo xcode-select -s /Applications/Xcode.app

# 2. Accept the license and install components:
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch

# 3. Verify:
xcodebuild -version
xcrun simctl list devices available

# 4. From your app:
swiftnative run ios
```

Notes:
- The iOS **Simulator** needs no Apple Developer account.
- Running on a **physical device** requires signing (a free Apple ID works for
  development): set your team in the generated Xcode project.

---

## 2. Android setup (one-time)

Android builds compile Swift natively (no JVM, no wrapper) using the official
**Swift SDK for Android** plus the **Android NDK**. On macOS you must use the
**open-source** Swift toolchain (Xcode's toolchain can't cross-compile), at a
version that **matches** the SDK exactly.

```sh
# 1. Install the open-source Swift toolchain manager (swiftly) and a matching toolchain.
#    macOS uses the signed installer package:
curl -fsSL -o swiftly.pkg https://download.swift.org/swiftly/darwin/swiftly.pkg
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
~/.swiftly/bin/swiftly init --assume-yes
swiftly install 6.3.2          # match the SDK version below
swiftly use 6.3.2

# 2. Install the Swift SDK for Android (pin the version to your toolchain):
swift sdk install \
  https://download.swift.org/swift-6.3.2-release/android-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_android.artifactbundle.tar.gz \
  --checksum 939e933549d12d28f2e0bf71019d734d309859e9773c572657ce565a81f85d68
swift sdk list                 # should list swift-6.3.2-RELEASE_android

# 3. Install the Android NDK (r27d or newer). Easiest is a direct download:
cd ~/Library/org.swift.swiftpm/swift-sdks/swift-6.3.2-RELEASE_android.artifactbundle/swift-android/
curl -fSL -o ndk.zip "https://dl.google.com/android/repository/android-ndk-r27d-darwin.zip"
unzip -q ndk.zip
export ANDROID_NDK_HOME=$PWD/android-ndk-r27d
./scripts/setup-android-sdk.sh

# 4. Install the Android SDK platform-tools + an emulator image (via Android
#    Studio, or the command-line tools). Then:
export ANDROID_HOME=$HOME/Library/Android/sdk
sdkmanager "platform-tools" "platforms;android-34" "system-images;android-34;google_apis;arm64-v8a"
avdmanager create avd -n sn_test -k "system-images;android-34;google_apis;arm64-v8a"

# 5. Verify and run:
swift sdk list
adb devices
swiftnative run android
```

### Storage note
The Android toolchain is large (Swift toolchain ≈ 1.5 GB, NDK ≈ 1 GB, system
image ≈ 1 GB). Make sure you have several GB free before step 1.

---

## 3. What `swiftnative doctor` checks

- Swift toolchain (and whether it's the Apple or open-source build)
- JDK 17+
- Xcode (full, not just Command Line Tools) and the iOS Simulator
- The open-source toolchain requirement for Android cross-compilation
- The Swift Android SDK (`swift sdk list`)
- The Android SDK, NDK (r27d+), `adb`, and an emulator

Each missing item is printed with the exact command to fix it.

---

## 4. Honest limitations

- **iOS requires a Mac + full Xcode.** There is no way around this (Apple).
- **Apple's SwiftUI does not run on Android.** Swift Native gives you a
  SwiftUI-like API that maps to native Android views.
- **Framework internals are not 100% Swift**: the Android bridge needs a small
  Kotlin host + JNI C shim and Gradle. *Your app code is pure Swift.*
- **Android has a small, non-zero runtime cost** (the Swift runtime `.so` ships
  in the APK; JNI crossings have a per-call cost). It is minimized, not zero.

---

## See also

- [GETTING_STARTED.md](GETTING_STARTED.md) — scaffold and run your first app
- [README.md](README.md) — project overview
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the renderer and backends work
