// Components.swift
// Higher-level components an app typically needs: lists (ForEach/List),
// scrolling, toggles and dividers. ForEach assigns stable keys and an identity
// scope per element so child state survives insertion, removal and reordering.

public struct ForEach<Element, ID: Hashable, Content: View>: View, NodeProducing {
    let elements: [Element]
    let idOf: (Element) -> ID
    let content: (Element) -> Content

    public init<Data: RandomAccessCollection>(
        _ data: Data,
        id: @escaping (Element) -> ID,
        @ViewBuilder content: @escaping (Element) -> Content
    ) where Data.Element == Element {
        self.elements = Array(data)
        self.idOf = id
        self.content = content
    }

    public init<Data: RandomAccessCollection>(
        _ data: Data,
        id idKeyPath: KeyPath<Element, ID>,
        @ViewBuilder content: @escaping (Element) -> Content
    ) where Data.Element == Element {
        self.init(data, id: { $0[keyPath: idKeyPath] }, content: content)
    }

    public var body: Never { fatalError() }

    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        var result: [Node] = []
        for element in elements {
            let idString = String(describing: idOf(element))
            let nodes = context.renderIdentified(idString, content(element))
            for (i, node) in nodes.enumerated() {
                node.key = nodes.count > 1 ? "\(idString)#\(i)" : idString
            }
            result.append(contentsOf: nodes)
        }
        return result
    }
}

extension ForEach where Element: Identifiable, ID == Element.ID {
    public init<Data: RandomAccessCollection>(
        _ data: Data,
        @ViewBuilder content: @escaping (Element) -> Content
    ) where Data.Element == Element {
        self.init(data, id: { $0.id }, content: content)
    }
}

public struct ScrollView<Content: View>: View, NodeProducing {
    let axis: Axis
    let content: Content

    public init(_ axis: Axis = .vertical, @ViewBuilder content: () -> Content) {
        self.axis = axis
        self.content = content()
    }

    public var body: Never { fatalError() }

    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        let children = renderNodes(content, &context)
        return [
            Node(
                type: "ScrollView",
                props: ["axis": .string(axis.rawValue)],
                children: children
            )
        ]
    }
}

public struct List<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
        }
    }
}

public struct Toggle: View, NodeProducing {
    let title: String
    let isOn: Binding<Bool>

    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self.isOn = isOn
    }

    public var body: Never { fatalError() }

    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        let binding = isOn
        return [
            Node(
                type: "Toggle",
                props: ["title": .string(title), "on": .bool(isOn.wrappedValue)],
                events: ["toggle": { binding.wrappedValue.toggle() }]
            )
        ]
    }
}

public struct Divider: View, NodeProducing {
    public init() {}
    public var body: Never { fatalError() }
    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        [Node(type: "Divider")]
    }
}
