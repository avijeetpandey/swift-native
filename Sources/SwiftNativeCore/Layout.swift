// Layout.swift
// A small stack/flex layout pass that assigns frames to nodes. It is
// intentionally minimal and self-contained; it is the component most directly
// replaceable by Yoga (Flexbox) later, behind the same call site.

public enum Layout {
    public static func perform(on roots: [Node], container: Size) {
        var y = 0.0
        for node in roots {
            let size = measure(node, proposed: container)
            place(node, origin: Point(x: 0, y: y), size: size)
            y += size.height
        }
    }

    static func measure(_ node: Node, proposed: Size) -> Size {
        let padding = node.insets("padding")
        var content: Size
        switch node.type {
        case "Text":
            let text = node.string("text") ?? ""
            let fontSize = node.font("font")?.size ?? 17
            content = Size(width: Double(text.count) * fontSize * 0.55, height: fontSize * 1.3)
        case "Button":
            let title = node.string("title") ?? ""
            let fontSize = node.font("font")?.size ?? 17
            content = Size(width: Double(title.count) * fontSize * 0.55 + 24, height: fontSize * 1.3 + 16)
        case "Image":
            content = Size(width: 24, height: 24)
        case "Divider":
            content = Size(width: proposed.width, height: 1)
        case "Toggle":
            let title = node.string("title") ?? ""
            let fontSize = node.font("font")?.size ?? 17
            content = Size(width: Double(title.count) * fontSize * 0.55 + 52, height: fontSize * 1.6)
        case "Spacer":
            content = Size(width: 0, height: 0)
        case "ScrollView":
            var width = 0.0
            var height = 0.0
            for child in node.children {
                let s = measure(child, proposed: proposed)
                width = max(width, s.width)
                height += s.height
            }
            content = Size(width: width, height: height)
        case "VStack":
            let spacing = node.double("spacing") ?? 8
            var width = 0.0
            var height = 0.0
            for (i, child) in node.children.enumerated() {
                let s = measure(child, proposed: proposed)
                width = max(width, s.width)
                height += s.height
                if i < node.children.count - 1 { height += spacing }
            }
            content = Size(width: width, height: height)
        case "HStack":
            let spacing = node.double("spacing") ?? 8
            var width = 0.0
            var height = 0.0
            for (i, child) in node.children.enumerated() {
                let s = measure(child, proposed: proposed)
                height = max(height, s.height)
                width += s.width
                if i < node.children.count - 1 { width += spacing }
            }
            content = Size(width: width, height: height)
        case "ZStack":
            var width = 0.0
            var height = 0.0
            for child in node.children {
                let s = measure(child, proposed: proposed)
                width = max(width, s.width)
                height = max(height, s.height)
            }
            content = Size(width: width, height: height)
        default:
            content = .zero
        }

        var result = Size(
            width: content.width + padding.horizontal,
            height: content.height + padding.vertical
        )
        if let w = node.double("width") { result.width = w }
        if let h = node.double("height") { result.height = h }
        return result
    }

    static func place(_ node: Node, origin: Point, size: Size) {
        node.frame = Rect(origin: origin, size: size)
        let padding = node.insets("padding")
        let innerOrigin = Point(x: origin.x + padding.leading, y: origin.y + padding.top)
        let innerWidth = size.width - padding.horizontal

        switch node.type {
        case "VStack":
            let spacing = node.double("spacing") ?? 8
            var y = innerOrigin.y
            for child in node.children {
                let s = measure(child, proposed: size)
                let x =
                    innerOrigin.x
                    + alignOffset(node.string("alignment"), available: innerWidth, content: s.width)
                place(child, origin: Point(x: x, y: y), size: s)
                y += s.height + spacing
            }
        case "HStack":
            let spacing = node.double("spacing") ?? 8
            var x = innerOrigin.x
            for child in node.children {
                let s = measure(child, proposed: size)
                place(child, origin: Point(x: x, y: innerOrigin.y), size: s)
                x += s.width + spacing
            }
        case "ZStack":
            for child in node.children {
                let s = measure(child, proposed: size)
                place(child, origin: innerOrigin, size: s)
            }
        case "ScrollView":
            var y = innerOrigin.y
            for child in node.children {
                let s = measure(child, proposed: size)
                place(child, origin: Point(x: innerOrigin.x, y: y), size: s)
                y += s.height
            }
        default:
            break
        }
    }

    private static func alignOffset(_ alignment: String?, available: Double, content: Double) -> Double {
        switch alignment {
        case "center": return max(0, (available - content) / 2)
        case "trailing": return max(0, available - content)
        default: return 0
        }
    }
}

extension Node {
    func string(_ key: String) -> String? {
        if case let .string(value)? = props[key] { return value }
        return nil
    }
    func double(_ key: String) -> Double? {
        if case let .double(value)? = props[key] { return value }
        return nil
    }
    func insets(_ key: String) -> EdgeInsets {
        if case let .insets(value)? = props[key] { return value }
        return .zero
    }
    func font(_ key: String) -> Font? {
        if case let .font(value)? = props[key] { return value }
        return nil
    }
}
