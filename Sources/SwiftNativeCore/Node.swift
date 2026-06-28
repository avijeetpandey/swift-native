// Node.swift
// The virtual element tree produced by a render pass. Nodes are diffed by the
// reconciler to produce a minimal batch of backend mutations.

public enum PropValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case color(Color)
    case font(Font)
    case insets(EdgeInsets)
}

public final class Node {
    public let type: String
    public var props: [String: PropValue]
    public var children: [Node]

    /// Optional stable identity for keyed reconciliation (set by `ForEach`).
    /// When siblings carry keys, the reconciler matches by key instead of by
    /// position, preserving native views and their state across reorders.
    public var key: String?

    /// Event handlers are kept Swift-side; they never become mutations. The
    /// backend only learns a view is interactive via a boolean prop and calls
    /// back by handle.
    var events: [String: () -> Void]

    /// Backend handle, assigned when the node is mounted. Stable across diffs
    /// because the reconciler copies it from the matched previous node.
    var handle: Int = -1

    /// Computed by the layout pass.
    public var frame: Rect = .zero

    public init(
        type: String,
        props: [String: PropValue] = [:],
        children: [Node] = [],
        events: [String: () -> Void] = [:]
    ) {
        self.type = type
        self.props = props
        self.children = children
        self.events = events
    }
}
