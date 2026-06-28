#if canImport(XCTest)
import XCTest
import SwiftNativeCore
import SwiftNativeTestRenderer

private struct ToggleView: View {
    @State var showExtra = false
    var body: some View {
        VStack {
            Text("header")
            Button("toggle") { showExtra.toggle() }
            if showExtra {
                Text("extra")
            }
        }
    }
}

final class ReconcilerTests: XCTestCase {
    func testMountEmitsCreateAndInsert() {
        let backend = TestBackend()
        let driver = mount(ToggleView(), on: backend)
        withExtendedLifetime(driver) {
            let firstBatch = backend.appliedBatches.first ?? []
            XCTAssertTrue(
                firstBatch.contains { if case .createView = $0 { return true } else { return false } })
            XCTAssertTrue(
                firstBatch.contains { if case .insertChild = $0 { return true } else { return false } })
            XCTAssertNil(backend.first { $0.text == "extra" })
        }
    }

    func testConditionalChildMountsAndUnmounts() {
        let backend = TestBackend()
        let driver = mount(ToggleView(), on: backend)
        withExtendedLifetime(driver) {
            let toggle = backend.first { $0.type == "Button" && $0.text == "toggle" }!

            backend.tap(toggle)
            XCTAssertNotNil(backend.first { $0.text == "extra" })
            let onBatch = backend.appliedBatches.last ?? []
            XCTAssertTrue(
                onBatch.contains { if case .createView(_, "Text") = $0 { return true } else { return false } }
            )
            XCTAssertTrue(
                onBatch.contains { if case .insertChild = $0 { return true } else { return false } })

            backend.tap(toggle)
            XCTAssertNil(backend.first { $0.text == "extra" })
            let offBatch = backend.appliedBatches.last ?? []
            XCTAssertTrue(
                offBatch.contains { if case .removeChild = $0 { return true } else { return false } })
            XCTAssertTrue(
                offBatch.contains { if case .destroyView = $0 { return true } else { return false } })
        }
    }

    func testHandlesAreStableAcrossRenders() {
        let backend = TestBackend()
        let driver = mount(ToggleView(), on: backend)
        withExtendedLifetime(driver) {
            let headerBefore = backend.first { $0.text == "header" }!
            let toggle = backend.first { $0.type == "Button" && $0.text == "toggle" }!
            backend.tap(toggle)
            let headerAfter = backend.first { $0.text == "header" }!
            // Same backend handle => updated in place, not recreated.
            XCTAssertEqual(headerBefore.id, headerAfter.id)
        }
    }
}

#endif
