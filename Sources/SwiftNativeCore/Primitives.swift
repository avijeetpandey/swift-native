// Primitives.swift
// The built-in component set. Each primitive emits its own render node(s).

public struct Text: View, NodeProducing {
    let content: String
    public init(_ content: String) { self.content = content }
    public init(_ value: Int) { self.content = String(value) }
    public var body: Never { fatalError() }
    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        [Node(type: "Text", props: ["text": .string(content)])]
    }
}

public struct Button<Label: View>: View, NodeProducing {
    let action: () -> Void
    let label: Label

    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    public var body: Never { fatalError() }

    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        let children = renderNodes(label, &context)
        // A simple text button is represented by a `title` prop with no child
        // views, so backends render a single native button (not a button that
        // also contains a separate label).
        if children.count == 1,
            children[0].type == "Text",
            case let .string(title)? = children[0].props["text"]
        {
            return [
                Node(
                    type: "Button",
                    props: ["tappable": .bool(true), "title": .string(title)],
                    events: ["tap": action]
                )
            ]
        }
        return [
            Node(
                type: "Button",
                props: ["tappable": .bool(true)],
                children: children,
                events: ["tap": action]
            )
        ]
    }
}

extension Button where Label == Text {
    public init(_ title: String, action: @escaping () -> Void) {
        self.init(action: action) { Text(title) }
    }
}

public struct VStack<Content: View>: View, NodeProducing {
    let alignment: HorizontalAlignment
    let spacing: Double
    let content: Content

    public init(
        alignment: HorizontalAlignment = .center, spacing: Double = 8, @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }

    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        let children = renderNodes(content, &context)
        return [
            Node(
                type: "VStack",
                props: [
                    "axis": .string(Axis.vertical.rawValue),
                    "spacing": .double(spacing),
                    "alignment": .string(alignment.rawValue),
                ],
                children: children
            )
        ]
    }
}

public struct HStack<Content: View>: View, NodeProducing {
    let alignment: VerticalAlignment
    let spacing: Double
    let content: Content

    public init(
        alignment: VerticalAlignment = .center, spacing: Double = 8, @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: Never { fatalError() }

    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        let children = renderNodes(content, &context)
        return [
            Node(
                type: "HStack",
                props: [
                    "axis": .string(Axis.horizontal.rawValue),
                    "spacing": .double(spacing),
                    "alignment": .string(alignment.rawValue),
                ],
                children: children
            )
        ]
    }
}

public struct ZStack<Content: View>: View, NodeProducing {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never { fatalError() }

    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        let children = renderNodes(content, &context)
        return [Node(type: "ZStack", children: children)]
    }
}

public struct Spacer: View, NodeProducing {
    public init() {}
    public var body: Never { fatalError() }
    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        [Node(type: "Spacer", props: ["flexible": .bool(true)])]
    }
}

public struct Image: View, NodeProducing {
    let systemName: String
    public init(systemName: String) { self.systemName = systemName }
    public var body: Never { fatalError() }
    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        [Node(type: "Image", props: ["systemName": .string(systemName)])]
    }
}
