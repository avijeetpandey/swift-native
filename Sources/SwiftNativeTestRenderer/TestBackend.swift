// TestBackend.swift
// A host-side backend that materialises mutations into an in-memory view tree.
// It lets us prove the entire pipeline (DSL -> reconciler -> mutations -> mount
// -> events -> re-render) on macOS, with deterministic assertions, without a
// device. Real backends (UIKit, Android) follow the exact same protocol.

import SwiftNativeCore

public final class TestView {
    public let id: Int
    public let type: String
    public var props: [String: PropValue] = [:]
    public var children: [TestView] = []

    init(id: Int, type: String) {
        self.id = id
        self.type = type
    }

    public var text: String? {
        if case let .string(value)? = props["text"] { return value }
        if case let .string(value)? = props["title"] { return value }
        return nil
    }
}

public final class TestBackend: Backend {
    public let rootHandle = 0
    public var eventSink: ((Int, String) -> Void)?

    public private(set) var root: TestView
    public private(set) var appliedBatches: [[Mutation]] = []
    private var views: [Int: TestView] = [:]

    public init() {
        let root = TestView(id: 0, type: "Root")
        self.root = root
        views[0] = root
    }

    public func apply(_ mutations: [Mutation]) {
        appliedBatches.append(mutations)
        for mutation in mutations {
            switch mutation {
            case let .createView(id, type):
                views[id] = TestView(id: id, type: type)
            case let .setProp(id, key, value):
                views[id]?.props[key] = value
            case let .removeProp(id, key):
                views[id]?.props[key] = nil
            case let .insertChild(parent, child, index):
                guard let parentView = views[parent], let childView = views[child] else { break }
                let clamped = min(max(0, index), parentView.children.count)
                parentView.children.insert(childView, at: clamped)
            case let .removeChild(parent, child):
                views[parent]?.children.removeAll { $0.id == child }
            case let .destroyView(id):
                views[id] = nil
            }
        }
    }

    // MARK: - Test helpers

    /// Number of mutations applied in the most recent batch.
    public var lastBatchCount: Int { appliedBatches.last?.count ?? 0 }

    /// Simulate a user tap on a view.
    public func tap(_ view: TestView) {
        eventSink?(view.id, "tap")
    }

    public func first(ofType type: String) -> TestView? {
        first(in: root) { $0.type == type }
    }

    public func first(where predicate: (TestView) -> Bool) -> TestView? {
        first(in: root, where: predicate)
    }

    public func all(ofType type: String) -> [TestView] {
        var result: [TestView] = []
        traverse(root) { if $0.type == type { result.append($0) } }
        return result
    }

    private func first(in view: TestView, where predicate: (TestView) -> Bool) -> TestView? {
        if predicate(view) { return view }
        for child in view.children {
            if let found = first(in: child, where: predicate) { return found }
        }
        return nil
    }

    private func traverse(_ view: TestView, _ visit: (TestView) -> Void) {
        visit(view)
        for child in view.children { traverse(child, visit) }
    }

    /// A deterministic textual snapshot of the mounted native tree.
    public func dump() -> String {
        var lines: [String] = []
        func walk(_ view: TestView, depth: Int) {
            let indent = String(repeating: "  ", count: depth)
            var line = indent + view.type
            if let text = view.text { line += " \"\(text)\"" }
            lines.append(line)
            for child in view.children { walk(child, depth: depth + 1) }
        }
        for child in root.children { walk(child, depth: 0) }
        return lines.joined(separator: "\n")
    }
}
