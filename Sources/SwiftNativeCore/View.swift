// View.swift
// The declarative surface: the `View` protocol, the result builder, and
// type-erasure. User code conforms to `View` exactly like SwiftUI.

public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

extension Never: View {
    public typealias Body = Never
    public var body: Never { fatalError("Never has no body") }
}

/// Views that translate directly into render nodes (primitives, containers,
/// groups). The reconciler asks these to emit their nodes instead of recursing
/// into `body`.
protocol NodeProducing {
    func _renderNodes(_ context: inout RenderContext) -> [Node]
}

/// An empty view contributes no nodes.
public struct EmptyView: View, NodeProducing {
    public init() {}
    public var body: Never { fatalError() }
    func _renderNodes(_ context: inout RenderContext) -> [Node] { [] }
}

/// Type-erased view used by the result builder and by `AnyView`.
public struct AnyView: View, NodeProducing {
    private let render: (inout RenderContext) -> [Node]

    public init<V: View>(_ view: V) {
        self.render = { ctx in renderNodes(view, &ctx) }
    }

    public var body: Never { fatalError() }
    func _renderNodes(_ context: inout RenderContext) -> [Node] { render(&context) }
}

/// Produced by the result builder when a block contains several children.
public struct TupleView: View, NodeProducing {
    let children: [AnyView]
    init(_ children: [AnyView]) { self.children = children }
    public var body: Never { fatalError() }
    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        children.flatMap { $0._renderNodes(&context) }
    }
}

/// `if`-without-`else` produces an `Optional` view via `buildOptional`. Making
/// `Optional` a view (rendering its wrapped value or nothing) lets the result
/// builder infer the element type cleanly.
extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

extension Optional: NodeProducing where Wrapped: View {
    func _renderNodes(_ context: inout RenderContext) -> [Node] {
        switch self {
        case .some(let wrapped): return renderNodes(wrapped, &context)
        case .none: return []
        }
    }
}

@resultBuilder
public enum ViewBuilder {
    public static func buildExpression<V: View>(_ expression: V) -> V { expression }

    public static func buildBlock() -> EmptyView { EmptyView() }

    public static func buildBlock<V: View>(_ content: V) -> V { content }

    public static func buildBlock<V0: View, V1: View>(_ v0: V0, _ v1: V1) -> TupleView {
        TupleView([AnyView(v0), AnyView(v1)])
    }
    public static func buildBlock<V0: View, V1: View, V2: View>(_ v0: V0, _ v1: V1, _ v2: V2) -> TupleView {
        TupleView([AnyView(v0), AnyView(v1), AnyView(v2)])
    }
    public static func buildBlock<V0: View, V1: View, V2: View, V3: View>(
        _ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3
    ) -> TupleView {
        TupleView([AnyView(v0), AnyView(v1), AnyView(v2), AnyView(v3)])
    }
    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View>(
        _ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4
    ) -> TupleView {
        TupleView([AnyView(v0), AnyView(v1), AnyView(v2), AnyView(v3), AnyView(v4)])
    }
    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View>(
        _ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5
    ) -> TupleView {
        TupleView([AnyView(v0), AnyView(v1), AnyView(v2), AnyView(v3), AnyView(v4), AnyView(v5)])
    }
    public static func buildBlock<V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View>(
        _ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6
    ) -> TupleView {
        TupleView([AnyView(v0), AnyView(v1), AnyView(v2), AnyView(v3), AnyView(v4), AnyView(v5), AnyView(v6)])
    }
    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View
    >(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7) -> TupleView {
        TupleView([
            AnyView(v0), AnyView(v1), AnyView(v2), AnyView(v3), AnyView(v4), AnyView(v5), AnyView(v6),
            AnyView(v7),
        ])
    }
    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View
    >(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8) -> TupleView {
        TupleView([
            AnyView(v0), AnyView(v1), AnyView(v2), AnyView(v3), AnyView(v4), AnyView(v5), AnyView(v6),
            AnyView(v7), AnyView(v8),
        ])
    }
    public static func buildBlock<
        V0: View, V1: View, V2: View, V3: View, V4: View, V5: View, V6: View, V7: View, V8: View, V9: View
    >(_ v0: V0, _ v1: V1, _ v2: V2, _ v3: V3, _ v4: V4, _ v5: V5, _ v6: V6, _ v7: V7, _ v8: V8, _ v9: V9)
        -> TupleView
    {
        TupleView([
            AnyView(v0), AnyView(v1), AnyView(v2), AnyView(v3), AnyView(v4), AnyView(v5), AnyView(v6),
            AnyView(v7), AnyView(v8), AnyView(v9),
        ])
    }

    public static func buildOptional<V: View>(_ component: V?) -> V? {
        component
    }
    public static func buildEither<V: View>(first component: V) -> AnyView {
        AnyView(component)
    }
    public static func buildEither<V: View>(second component: V) -> AnyView {
        AnyView(component)
    }
    public static func buildArray<V: View>(_ components: [V]) -> TupleView {
        TupleView(components.map { AnyView($0) })
    }
    public static func buildLimitedAvailability<V: View>(_ component: V) -> AnyView {
        AnyView(component)
    }
}

/// Entry point of the render walk: reduce any `View` to a flat list of nodes.
func renderNodes<V: View>(_ view: V, _ context: inout RenderContext) -> [Node] {
    if let producer = view as? NodeProducing {
        return producer._renderNodes(&context)
    }
    return context.renderComposite(view)
}
