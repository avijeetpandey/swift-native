// UnitTests — small, focused tests of individual units: geometry, color, fonts,
// the layout engine, and that each component emits the correct render node.

import SwiftNativeCore
import SwiftNativeTestRenderer
import SwiftNativeTesting

func unitTests() -> [TestSuite] {
    [geometrySuite(), layoutSuite(), componentSuite(), modifierSuite()]
}

private func geometrySuite() -> TestSuite {
    let s = TestSuite("Unit: Geometry & Color")

    s.test("Color hex encodes RGB") { t in
        t.expectEqual(Color.red.hex, "#FF0000FF")
        t.expectEqual(Color.white.hex, "#FFFFFFFF")
        t.expectEqual(Color.black.hex, "#000000FF")
        t.expectEqual(Color(red: 0, green: 0, blue: 0, alpha: 0).hex, "#00000000")
    }

    s.test("Color hex clamps out-of-range channels") { t in
        t.expectEqual(Color(red: 2, green: -1, blue: 0.5).hex, "#FF0080FF")
    }

    s.test("EdgeInsets convenience") { t in
        let all = EdgeInsets(all: 10)
        t.expectEqual(all.horizontal, 20)
        t.expectEqual(all.vertical, 20)
        t.expectEqual(EdgeInsets.zero.top, 0)
    }

    s.test("Rect accessors") { t in
        let r = Rect(x: 1, y: 2, width: 3, height: 4)
        t.expectEqual(r.x, 1)
        t.expectEqual(r.y, 2)
        t.expectEqual(r.width, 3)
        t.expectEqual(r.height, 4)
    }

    s.test("Font presets") { t in
        t.expectEqual(Font.title.weight, .bold)
        t.expectEqual(Font.body.size, 17)
        t.expectEqual(Font.system(size: 10, weight: .medium).weight, .medium)
    }

    return s
}

private func layoutSuite() -> TestSuite {
    let s = TestSuite("Unit: Layout engine")

    s.test("VStack stacks children vertically with spacing") { t in
        let a = Node(type: "Text", props: ["text": .string("a")])
        let b = Node(type: "Text", props: ["text": .string("bbbb")])
        let stack = Node(type: "VStack", props: ["spacing": .double(10)], children: [a, b])
        Layout.perform(on: [stack], container: Size(width: 400, height: 800))
        t.expectEqual(a.frame.origin.y, 0)
        t.expect(b.frame.origin.y > a.frame.origin.y, "b below a")
        t.expectEqual(b.frame.origin.y, a.frame.size.height + 10, "spacing applied")
    }

    s.test("HStack stacks children horizontally") { t in
        let a = Node(type: "Text", props: ["text": .string("a")])
        let b = Node(type: "Text", props: ["text": .string("b")])
        let stack = Node(type: "HStack", props: ["spacing": .double(5)], children: [a, b])
        Layout.perform(on: [stack], container: Size(width: 400, height: 800))
        t.expectEqual(a.frame.origin.x, 0)
        t.expect(b.frame.origin.x > a.frame.origin.x, "b right of a")
        t.expectEqual(a.frame.origin.y, b.frame.origin.y, "same row")
    }

    s.test("Padding offsets children") { t in
        let child = Node(type: "Text", props: ["text": .string("x")])
        let stack = Node(type: "VStack", props: ["padding": .insets(EdgeInsets(all: 20))], children: [child])
        Layout.perform(on: [stack], container: Size(width: 400, height: 800))
        t.expectEqual(child.frame.origin.x, 20)
        t.expectEqual(child.frame.origin.y, 20)
    }

    s.test("Explicit width/height override measured size") { t in
        let n = Node(
            type: "Text", props: ["text": .string("x"), "width": .double(123), "height": .double(45)])
        Layout.perform(on: [n], container: Size(width: 400, height: 800))
        t.expectEqual(n.frame.width, 123)
        t.expectEqual(n.frame.height, 45)
    }

    s.test("ZStack overlays children at same origin") { t in
        let a = Node(type: "Text", props: ["text": .string("a")])
        let b = Node(type: "Text", props: ["text": .string("b")])
        let z = Node(type: "ZStack", children: [a, b])
        Layout.perform(on: [z], container: Size(width: 400, height: 800))
        t.expectEqual(a.frame.origin.x, b.frame.origin.x)
        t.expectEqual(a.frame.origin.y, b.frame.origin.y)
    }

    return s
}

private func componentSuite() -> TestSuite {
    let s = TestSuite("Unit: Components emit nodes")

    s.test("Text emits a Text node") { t in
        let (backend, driver) = host(Text("hello"))
        _ = driver
        let node = backend.first(ofType: "Text")
        t.expectNotNil(node, "Text node")
        t.expectEqual(node?.text, "hello")
    }

    s.test("Text(Int) renders the number") { t in
        let (backend, driver) = host(Text(42))
        _ = driver
        t.expectEqual(backend.first(ofType: "Text")?.text, "42")
    }

    s.test("Button carries a title and is tappable") { t in
        let (backend, driver) = host(Button("Go") {})
        _ = driver
        let node = backend.first(ofType: "Button")
        t.expectNotNil(node, "Button node")
        t.expectEqual(node?.text, "Go")
    }

    s.test("VStack/HStack/ZStack/Spacer/Divider/Image emit their nodes") { t in
        let (backend, driver) = host(
            VStack {
                HStack {
                    Text("a")
                    Spacer()
                    Image(systemName: "star")
                }
                Divider()
                ZStack { Text("z") }
            }
        )
        _ = driver
        t.expectNotNil(backend.first(ofType: "VStack"), "VStack")
        t.expectNotNil(backend.first(ofType: "HStack"), "HStack")
        t.expectNotNil(backend.first(ofType: "ZStack"), "ZStack")
        t.expectNotNil(backend.first(ofType: "Spacer"), "Spacer")
        t.expectNotNil(backend.first(ofType: "Divider"), "Divider")
        t.expectNotNil(backend.first(ofType: "Image"), "Image")
    }

    s.test("ScrollView and List render their content") { t in
        let (backend, driver) = host(
            ScrollView {
                Text("one")
                Text("two")
            }
        )
        _ = driver
        t.expectNotNil(backend.first(ofType: "ScrollView"), "ScrollView")
        t.expectEqual(backend.allText().filter { $0 == "one" || $0 == "two" }.count, 2)
    }

    s.test("Builder supports up to 10 children") { t in
        let (backend, driver) = host(
            VStack {
                Text("1")
                Text("2")
                Text("3")
                Text("4")
                Text("5")
                Text("6")
                Text("7")
                Text("8")
                Text("9")
                Text("10")
            }
        )
        _ = driver
        t.expectEqual(backend.all(ofType: "Text").count, 10)
    }

    return s
}

private func modifierSuite() -> TestSuite {
    let s = TestSuite("Unit: Modifiers")

    s.test("padding/foreground/background/font/cornerRadius set props") { t in
        let (backend, driver) = host(
            Text("styled")
                .foregroundColor(.blue)
                .background(.white)
                .font(.title)
                .padding(16)
                .cornerRadius(8)
        )
        _ = driver
        let node = backend.first(ofType: "Text")
        t.expectNotNil(node, "node")
        t.expect(node?.props["foregroundColor"] != nil, "foregroundColor set")
        t.expect(node?.props["background"] != nil, "background set")
        t.expect(node?.props["font"] != nil, "font set")
        t.expect(node?.props["padding"] != nil, "padding set")
        t.expect(node?.props["cornerRadius"] != nil, "cornerRadius set")
    }

    s.test("frame sets width and height") { t in
        let (backend, driver) = host(Text("x").frame(width: 100, height: 50))
        _ = driver
        let node = backend.first(ofType: "Text")
        t.expectEqual(node?.props["width"], .double(100))
        t.expectEqual(node?.props["height"], .double(50))
    }

    return s
}
