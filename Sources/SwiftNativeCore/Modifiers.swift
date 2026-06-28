// Modifiers.swift
// View modifiers attach presentation props to the node(s) produced by their
// content, mirroring SwiftUI's chained-modifier ergonomics.

struct _ModifiedView<Content: View>: View, NodeProducing {
    let content: Content
    let transform: (Node) -> Void

    var body: Never { fatalError() }

    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        let nodes = renderNodes(content, &context)
        for node in nodes { transform(node) }
        return nodes
    }
}

extension View {
    public func padding(_ insets: EdgeInsets) -> some View {
        _ModifiedView(content: self) { $0.props["padding"] = .insets(insets) }
    }

    public func padding(_ length: Double = 12) -> some View {
        padding(EdgeInsets(all: length))
    }

    public func foregroundColor(_ color: Color) -> some View {
        _ModifiedView(content: self) { $0.props["foregroundColor"] = .color(color) }
    }

    public func background(_ color: Color) -> some View {
        _ModifiedView(content: self) { $0.props["background"] = .color(color) }
    }

    public func font(_ font: Font) -> some View {
        _ModifiedView(content: self) { $0.props["font"] = .font(font) }
    }

    public func frame(width: Double? = nil, height: Double? = nil) -> some View {
        _ModifiedView(content: self) { node in
            if let width { node.props["width"] = .double(width) }
            if let height { node.props["height"] = .double(height) }
        }
    }

    public func cornerRadius(_ radius: Double) -> some View {
        _ModifiedView(content: self) { $0.props["cornerRadius"] = .double(radius) }
    }
}
