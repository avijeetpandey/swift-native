// Reconciler.swift
// Diffs the previous node tree against the new one and emits a minimal,
// ordered batch of mutations. Handles are stable across renders so the backend
// updates views in place instead of rebuilding them.

final class Reconciler {
    private var nextHandle = 1
    private var nodesByHandle: [Int: Node] = [:]

    func reconcileRoot(rootHandle: Int, old: [Node], new: [Node], into mutations: inout [Mutation]) {
        diffChildren(parent: rootHandle, old: old, new: new, into: &mutations)
    }

    /// Route a backend event to the live handler for that handle.
    func dispatch(handle: Int, event: String) {
        nodesByHandle[handle]?.events[event]?()
    }

    private func diffChildren(parent: Int, old: [Node], new: [Node], into mutations: inout [Mutation]) {
        // Keyed path: when the new children carry stable keys (e.g. ForEach),
        // match by key so reordering preserves native views and their state.
        if new.contains(where: { $0.key != nil }) || old.contains(where: { $0.key != nil }) {
            diffKeyedChildren(parent: parent, old: old, new: new, into: &mutations)
            return
        }

        let common = min(old.count, new.count)
        for i in 0..<common {
            diffNode(old: old[i], new: new[i], parent: parent, index: i, into: &mutations)
        }
        if new.count > old.count {
            for i in common..<new.count {
                mount(new[i], parent: parent, index: i, into: &mutations)
            }
        } else if old.count > new.count {
            for i in stride(from: old.count - 1, through: common, by: -1) {
                unmount(old[i], parent: parent, into: &mutations)
            }
        }
    }

    /// Keyed reconciliation. Reuses matching keys (preserving handles + native
    /// state), mounts new keys, unmounts removed keys, and reorders by moving
    /// existing views (remove+insert of the same handle, which keeps the view
    /// object and its state intact).
    private func diffKeyedChildren(parent: Int, old: [Node], new: [Node], into mutations: inout [Mutation]) {
        // Stable keys: explicitly-keyed nodes use their key; un-keyed siblings
        // use type + their occurrence *among un-keyed siblings*. This keeps a
        // trailing sibling (e.g. a footer after a variable-length ForEach)
        // stable when the list length changes, instead of keying it by absolute
        // position (which would churn its native view on every insert/remove).
        func keys(of nodes: [Node]) -> [String] {
            var counts: [String: Int] = [:]
            return nodes.map { node in
                if let key = node.key { return key }
                let n = counts[node.type, default: 0]
                counts[node.type] = n + 1
                return "\u{0}\(node.type)#\(n)"
            }
        }

        let oldKeys = keys(of: old)
        let newKeys = keys(of: new)

        var oldByKey: [String: Node] = [:]
        for (i, node) in old.enumerated() { oldByKey[oldKeys[i]] = node }

        let newKeySet = Set(newKeys)

        // 1. Unmount old children whose keys are gone.
        for (i, node) in old.enumerated() where !newKeySet.contains(oldKeys[i]) {
            unmount(node, parent: parent, into: &mutations)
        }

        // Live order = surviving old children in their original order.
        var liveOrder: [String] = oldKeys.filter { newKeySet.contains($0) }

        // 2. Walk the desired order, reusing/mounting and moving into place.
        for (targetIndex, node) in new.enumerated() {
            let key = newKeys[targetIndex]
            if let existing = oldByKey[key] {
                diffNode(old: existing, new: node, parent: parent, index: targetIndex, into: &mutations)
                let currentIndex = liveOrder.firstIndex(of: key)!
                if currentIndex != targetIndex {
                    mutations.append(.removeChild(parent: parent, child: node.handle))
                    liveOrder.remove(at: currentIndex)
                    let clamped = min(targetIndex, liveOrder.count)
                    mutations.append(.insertChild(parent: parent, child: node.handle, index: clamped))
                    liveOrder.insert(key, at: clamped)
                }
            } else {
                let clamped = min(targetIndex, liveOrder.count)
                mount(node, parent: parent, index: clamped, into: &mutations)
                liveOrder.insert(key, at: clamped)
            }
        }
    }

    private func diffNode(old: Node, new: Node, parent: Int, index: Int, into mutations: inout [Mutation]) {
        guard old.type == new.type else {
            unmount(old, parent: parent, into: &mutations)
            mount(new, parent: parent, index: index, into: &mutations)
            return
        }

        new.handle = old.handle
        nodesByHandle[new.handle] = new

        for key in new.props.keys.sorted() {
            let value = new.props[key]!
            if old.props[key] != value {
                mutations.append(.setProp(id: new.handle, key: key, value: value))
            }
        }
        for key in old.props.keys.sorted() where new.props[key] == nil {
            mutations.append(.removeProp(id: new.handle, key: key))
        }

        diffChildren(parent: new.handle, old: old.children, new: new.children, into: &mutations)
    }

    private func mount(_ node: Node, parent: Int, index: Int, into mutations: inout [Mutation]) {
        node.handle = nextHandle
        nextHandle += 1
        nodesByHandle[node.handle] = node

        mutations.append(.createView(id: node.handle, type: node.type))
        for key in node.props.keys.sorted() {
            mutations.append(.setProp(id: node.handle, key: key, value: node.props[key]!))
        }
        mutations.append(.insertChild(parent: parent, child: node.handle, index: index))

        for (childIndex, child) in node.children.enumerated() {
            mount(child, parent: node.handle, index: childIndex, into: &mutations)
        }
    }

    private func unmount(_ node: Node, parent: Int, into mutations: inout [Mutation]) {
        mutations.append(.removeChild(parent: parent, child: node.handle))
        destroySubtree(node, into: &mutations)
    }

    private func destroySubtree(_ node: Node, into mutations: inout [Mutation]) {
        for child in node.children {
            destroySubtree(child, into: &mutations)
        }
        mutations.append(.destroyView(id: node.handle))
        nodesByHandle[node.handle] = nil
    }
}
