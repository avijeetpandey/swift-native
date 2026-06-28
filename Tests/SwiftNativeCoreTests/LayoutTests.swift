#if canImport(XCTest)
import XCTest
@testable import SwiftNativeCore

final class LayoutTests: XCTestCase {
    func testVStackStacksChildrenVertically() {
        let a = Node(type: "Text", props: ["text": .string("a")])
        let b = Node(type: "Text", props: ["text": .string("bbbb")])
        let stack = Node(
            type: "VStack",
            props: ["axis": .string("vertical"), "spacing": .double(10)],
            children: [a, b]
        )

        Layout.perform(on: [stack], container: Size(width: 400, height: 800))

        XCTAssertEqual(a.frame.origin.y, 0, accuracy: 0.001)
        XCTAssertGreaterThan(b.frame.origin.y, a.frame.origin.y)
        // b sits below a, separated by a's height plus the 10pt spacing.
        XCTAssertEqual(b.frame.origin.y, a.frame.size.height + 10, accuracy: 0.001)
    }

    func testHStackStacksChildrenHorizontally() {
        let a = Node(type: "Text", props: ["text": .string("a")])
        let b = Node(type: "Text", props: ["text": .string("b")])
        let stack = Node(
            type: "HStack",
            props: ["axis": .string("horizontal"), "spacing": .double(5)],
            children: [a, b]
        )

        Layout.perform(on: [stack], container: Size(width: 400, height: 800))

        XCTAssertEqual(a.frame.origin.x, 0, accuracy: 0.001)
        XCTAssertGreaterThan(b.frame.origin.x, a.frame.origin.x)
        XCTAssertEqual(a.frame.origin.y, b.frame.origin.y, accuracy: 0.001)
    }

    func testPaddingOffsetsChildren() {
        let child = Node(type: "Text", props: ["text": .string("x")])
        let stack = Node(
            type: "VStack",
            props: ["padding": .insets(EdgeInsets(all: 20))],
            children: [child]
        )

        Layout.perform(on: [stack], container: Size(width: 400, height: 800))

        XCTAssertEqual(child.frame.origin.x, 20, accuracy: 0.001)
        XCTAssertEqual(child.frame.origin.y, 20, accuracy: 0.001)
    }
}

#endif
