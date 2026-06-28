// Helpers shared across the test suites.

import SwiftNativeCore
import SwiftNativeTestRenderer

/// Mount a view on a fresh TestBackend and return both for inspection. The
/// driver is retained by the caller for the duration of the test.
@discardableResult
func host<V: View>(_ view: @autoclosure @escaping () -> V) -> (TestBackend, Driver) {
    let backend = TestBackend()
    let driver = mount(view(), on: backend)
    return (backend, driver)
}

extension TestBackend {
    /// Convenience: the text/title of the first view matching a predicate.
    func text(where predicate: (TestView) -> Bool) -> String? {
        first(where: predicate)?.text
    }

    /// All text/title strings in the mounted tree, in pre-order.
    func allText() -> [String] {
        var result: [String] = []
        func walk(_ v: TestView) {
            if let t = v.text { result.append(t) }
            for c in v.children { walk(c) }
        }
        for c in root.children { walk(c) }
        return result
    }
}
