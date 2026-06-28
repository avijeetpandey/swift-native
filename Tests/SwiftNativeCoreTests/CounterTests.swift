#if canImport(XCTest)
import XCTest
import SwiftNativeCore
import SwiftNativeTestRenderer
import CounterExample

final class CounterTests: XCTestCase {
    func testInitialRenderMountsNativeTree() {
        let backend = TestBackend()
        let driver = mount(CounterView(), on: backend)
        withExtendedLifetime(driver) {
            XCTAssertNotNil(backend.first(ofType: "VStack"))

            let texts = backend.all(ofType: "Text").compactMap { $0.text }
            XCTAssertTrue(texts.contains("Swift Native"))
            XCTAssertTrue(texts.contains("Count: 0"))

            let buttons = backend.all(ofType: "Button").compactMap { $0.text }
            XCTAssertEqual(buttons, ["Increment", "Decrement"])
        }
    }

    func testTapIncrementUpdatesCounterText() {
        let backend = TestBackend()
        let driver = mount(CounterView(), on: backend)
        withExtendedLifetime(driver) {
            let increment = backend.first { $0.type == "Button" && $0.text == "Increment" }!
            backend.tap(increment)

            let counter = backend.first { $0.type == "Text" && ($0.text?.hasPrefix("Count:") ?? false) }
            XCTAssertEqual(counter?.text, "Count: 1")
        }
    }

    func testStateChangeProducesMinimalMutationBatch() {
        let backend = TestBackend()
        let driver = mount(CounterView(), on: backend)
        withExtendedLifetime(driver) {
            let increment = backend.first { $0.type == "Button" && $0.text == "Increment" }!
            backend.tap(increment)

            // The diff re-renders the whole tree but emits ONLY the one prop that
            // changed — proof the reconciler mutates in place, like Fabric.
            XCTAssertEqual(backend.lastBatchCount, 1)
            if case let .setProp(_, key, value)? = backend.appliedBatches.last?.first {
                XCTAssertEqual(key, "text")
                XCTAssertEqual(value, .string("Count: 1"))
            } else {
                XCTFail("expected a single setProp mutation")
            }
        }
    }

    func testIncrementAndDecrement() {
        let backend = TestBackend()
        let driver = mount(CounterView(), on: backend)
        withExtendedLifetime(driver) {
            let increment = backend.first { $0.type == "Button" && $0.text == "Increment" }!
            let decrement = backend.first { $0.type == "Button" && $0.text == "Decrement" }!

            backend.tap(increment)
            backend.tap(increment)
            backend.tap(increment)
            XCTAssertEqual(currentCount(backend), "Count: 3")

            backend.tap(decrement)
            XCTAssertEqual(currentCount(backend), "Count: 2")
        }
    }

    private func currentCount(_ backend: TestBackend) -> String? {
        backend.first { $0.type == "Text" && ($0.text?.hasPrefix("Count:") ?? false) }?.text
    }
}

#endif
