// RenderContext.swift
// Carried through the render walk. Resolves composite views into nodes and
// binds their `@State` to persistent storage using an identity path plus the
// declaration order of state properties (discovered by reflection).

public final class StateStore {
    private var boxes: [String: StateBox] = [:]

    func box(forKey key: String, initial: Any) -> StateBox {
        if let existing = boxes[key] { return existing }
        let box = StateBox(initial)
        boxes[key] = box
        return box
    }

    func reset() { boxes.removeAll() }
}

struct RenderContext {
    let store: StateStore
    /// Driver-local re-render trigger, stored onto each bound `StateBox`.
    let notify: () -> Void
    private var path: String = ""
    private var siblingCounters: [String: Int] = [:]

    init(store: StateStore, notify: @escaping () -> Void) {
        self.store = store
        self.notify = notify
    }

    mutating func renderComposite<V: View>(_ view: V) -> [Node] {
        let typeName = String(describing: V.self)
        let counterKey = path + "|" + typeName
        let index = siblingCounters[counterKey, default: 0]
        siblingCounters[counterKey] = index + 1
        let myPath = path + "/" + typeName + "#" + String(index)

        bindState(of: view, at: myPath)

        let previousPath = path
        let previousCounters = siblingCounters
        path = myPath
        siblingCounters = [:]
        let nodes = renderNodes(view.body, &self)
        path = previousPath
        siblingCounters = previousCounters
        return nodes
    }

    /// Render `view` under an explicit identity scope (used by `ForEach` so each
    /// element's child state is keyed by element id, not sibling position).
    mutating func renderIdentified<V: View>(_ id: String, _ view: V) -> [Node] {
        let previousPath = path
        let previousCounters = siblingCounters
        path = path + "/id=" + id
        siblingCounters = [:]
        let nodes = renderNodes(view, &self)
        path = previousPath
        siblingCounters = previousCounters
        return nodes
    }

    private func bindState<V: View>(of view: V, at path: String) {
        let mirror = Mirror(reflecting: view)
        var slot = 0
        for child in mirror.children {
            guard let stateProperty = child.value as? StatePropertyProtocol else { continue }
            let key = path + ".s" + String(slot)
            let box = store.box(forKey: key, initial: stateProperty.storage.initial)
            box.onChange = notify
            stateProperty.storage.box = box
            slot += 1
        }
    }
}
