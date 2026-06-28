// IntegrationTests — multiple units working together: the full
// DSL → reconciler → backend pipeline on the in-memory TestBackend, driver
// isolation, and the REAL AppKit backend driven through genuine native events.

import CounterExample
import SwiftNativeCore
import SwiftNativeTestRenderer
import SwiftNativeTesting

#if canImport(AppKit)
import AppKit
import SwiftNativeAppKit
#endif

func integrationTests() -> [TestSuite] {
    var suites = [pipelineSuite(), isolationSuite()]
    #if canImport(AppKit)
    suites.append(appKitSuite())
    #endif
    return suites
}

private func pipelineSuite() -> TestSuite {
    let s = TestSuite("Integration: render pipeline")

    s.test("Initial mount builds the expected native tree") { t in
        let (backend, driver) = host(CounterView())
        _ = driver
        t.expectNotNil(backend.first(ofType: "VStack"), "root VStack")
        t.expect(backend.allText().contains("Swift Native"), "title present")
        t.expect(backend.allText().contains("Count: 0"), "counter at 0")
    }

    s.test("State change emits a single minimal mutation") { t in
        let (backend, driver) = host(CounterView())
        _ = driver
        let inc = backend.first { $0.type == "Button" && $0.text == "Increment" }!
        backend.tap(inc)
        t.expectEqual(backend.lastBatchCount, 1, "exactly one mutation for an increment")
        if case let .setProp(_, key, value)? = backend.appliedBatches.last?.first {
            t.expectEqual(key, "text")
            t.expectEqual(value, .string("Count: 1"))
        } else {
            t.fail("expected a single setProp mutation")
        }
    }

    s.test("Handles stay stable across re-renders") { t in
        let (backend, driver) = host(CounterView())
        _ = driver
        let titleBefore = backend.first { $0.text == "Swift Native" }!
        let inc = backend.first { $0.type == "Button" && $0.text == "Increment" }!
        backend.tap(inc)
        let titleAfter = backend.first { $0.text == "Swift Native" }!
        t.expectEqual(titleBefore.id, titleAfter.id, "unchanged view keeps its handle")
    }

    s.test("Conditional content mounts and unmounts") { t in
        let (backend, driver) = host(ToggleContentView())
        _ = driver
        t.expect(backend.first { $0.text == "extra" } == nil, "extra hidden initially")
        let toggle = backend.first { $0.type == "Button" && $0.text == "toggle" }!
        backend.tap(toggle)
        t.expectNotNil(backend.first { $0.text == "extra" }, "extra shown")
        let onBatch = backend.appliedBatches.last ?? []
        t.expect(
            onBatch.contains { if case .createView(_, "Text") = $0 { return true } else { return false } },
            "createView emitted")
        backend.tap(toggle)
        t.expect(backend.first { $0.text == "extra" } == nil, "extra hidden again")
        let offBatch = backend.appliedBatches.last ?? []
        t.expect(
            offBatch.contains { if case .destroyView = $0 { return true } else { return false } },
            "destroyView emitted")
    }

    return s
}

private func isolationSuite() -> TestSuite {
    let s = TestSuite("Integration: driver isolation")

    // Regression test for the old global-singleton bug: two independent drivers
    // must not affect each other's state.
    s.test("Two drivers keep independent state") { t in
        let backendA = TestBackend()
        let driverA = mount(CounterView(), on: backendA)
        let backendB = TestBackend()
        let driverB = mount(CounterView(), on: backendB)
        _ = (driverA, driverB)

        let incA = backendA.first { $0.type == "Button" && $0.text == "Increment" }!
        backendA.tap(incA)
        backendA.tap(incA)

        t.expectEqual(
            backendA.text { $0.type == "Text" && ($0.text?.hasPrefix("Count:") ?? false) }, "Count: 2",
            "A advanced")
        t.expectEqual(
            backendB.text { $0.type == "Text" && ($0.text?.hasPrefix("Count:") ?? false) }, "Count: 0",
            "B untouched")
    }

    s.test("Interleaved taps stay isolated") { t in
        let backendA = TestBackend()
        let dA = mount(CounterView(), on: backendA)
        let backendB = TestBackend()
        let dB = mount(CounterView(), on: backendB)
        _ = (dA, dB)
        func inc(_ b: TestBackend) { b.tap(b.first { $0.type == "Button" && $0.text == "Increment" }!) }
        inc(backendA)
        inc(backendB)
        inc(backendB)
        t.expectEqual(backendA.text { $0.text?.hasPrefix("Count:") ?? false }, "Count: 1")
        t.expectEqual(backendB.text { $0.text?.hasPrefix("Count:") ?? false }, "Count: 2")
    }

    return s
}

#if canImport(AppKit)
private func appKitSuite() -> TestSuite {
    let s = TestSuite("Integration: native AppKit backend")

    s.test("Counter renders to real NSViews and reacts to native clicks") { t in
        MainActor.assumeIsolated {
            let backend = AppKitBackend()
            let driver = Driver(backend: backend) { AnyView(CounterView()) }
            driver.start()

            let labels0 = collectLabels(backend.container)
            t.expect(labels0.contains("Swift Native"), "native title label present")
            t.expect(labels0.contains("Count: 0"), "native counter starts at 0")

            guard let increment = collectButtons(backend.container).first(where: { $0.title == "Increment" })
            else {
                t.fail("Increment NSButton not found")
                return
            }
            increment.performClick(nil)  // genuine AppKit action → ControlTarget → driver

            let labels1 = collectLabels(backend.container)
            t.expect(labels1.contains("Count: 1"), "native counter updated to 1 after real click")
            _ = driver
        }
    }

    s.test("List of toggles maps to native NSSwitch controls") { t in
        MainActor.assumeIsolated {
            let backend = AppKitBackend()
            let driver = Driver(backend: backend) { AnyView(SettingsView()) }
            driver.start()
            let switches = collectSwitches(backend.container)
            t.expect(switches.count >= 1, "at least one native NSSwitch")
            _ = driver
        }
    }

    s.test("SwiftNativePreview renders a native tree and replays taps") { t in
        MainActor.assumeIsolated {
            let tree = SwiftNativePreview.render(taps: ["Increment"]) { AnyView(CounterView()) }
            t.expect(tree.contains("NSTextField \"Count: 0\""), "initial native tree rendered")
            t.expect(tree.contains("NSButton \"Increment\""), "native button present")
            t.expect(tree.contains("after tapping \"Increment\""), "tap replayed")
            t.expect(tree.contains("NSTextField \"Count: 1\""), "tree updated after native tap")
        }
    }

    s.test("Frame changes reuse one constraint (no accumulation)") { t in
        MainActor.assumeIsolated {
            let backend = AppKitBackend()
            let driver = Driver(backend: backend) { AnyView(ResizableView()) }
            driver.start()

            guard let box = collectColoredViews(backend.container).first else {
                t.fail("resizable view not found")
                return
            }
            let widthConstraints0 = box.constraints.filter { $0.firstAttribute == .width }.count
            t.expect(widthConstraints0 <= 1, "at most one width constraint initially")

            // Grow several times; the constraint count must stay bounded.
            let grow = SwiftNativePreview.findButton(backend.container, title: "grow")
            grow?.performClick(nil)
            grow?.performClick(nil)
            grow?.performClick(nil)

            let widthConstraints1 = box.constraints.filter { $0.firstAttribute == .width }.count
            t.expect(
                widthConstraints1 <= 1,
                "still at most one width constraint after 3 resizes (got \(widthConstraints1))")
            _ = driver
        }
    }

    return s
}

@MainActor private func collectColoredViews(_ view: NSView) -> [NSView] {
    // The resizable box is a plain NSView (Spacer/background) with a width constraint.
    var out: [NSView] = []
    func walk(_ v: NSView) {
        if v.constraints.contains(where: { $0.firstAttribute == .width }) { out.append(v) }
        for sub in v.subviews { walk(sub) }
    }
    walk(view)
    return out
}

@MainActor private func collectLabels(_ view: NSView) -> [String] {
    var out: [String] = []
    func walk(_ v: NSView) {
        if let tf = v as? NSTextField { out.append(tf.stringValue) }
        for sub in v.subviews { walk(sub) }
    }
    walk(view)
    return out
}

@MainActor private func collectButtons(_ view: NSView) -> [NSButton] {
    var out: [NSButton] = []
    func walk(_ v: NSView) {
        if let b = v as? NSButton { out.append(b) }
        for sub in v.subviews { walk(sub) }
    }
    walk(view)
    return out
}

@MainActor private func collectSwitches(_ view: NSView) -> [NSSwitch] {
    var out: [NSSwitch] = []
    func walk(_ v: NSView) {
        if let sw = v as? NSSwitch { out.append(sw) }
        for sub in v.subviews { walk(sub) }
    }
    walk(view)
    return out
}
#endif

// MARK: - Views used by the integration tests

struct ToggleContentView: View {
    @State var show = false
    var body: some View {
        VStack {
            Text("header")
            Button("toggle") { show.toggle() }
            if show { Text("extra") }
        }
    }
}

struct SettingsView: View {
    @State var notifications = true
    @State var darkMode = false
    var body: some View {
        VStack {
            Toggle("Notifications", isOn: $notifications)
            Toggle("Dark Mode", isOn: $darkMode)
        }
    }
}

struct ResizableView: View {
    @State var w = 50.0
    var body: some View {
        VStack {
            Button("grow") { w += 20 }
            Spacer().frame(width: w, height: 10)
        }
    }
}
