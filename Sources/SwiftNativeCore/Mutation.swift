// Mutation.swift
// The batch protocol between the Swift core and a platform backend. The
// reconciler emits an ordered list of these; the backend applies them to real
// native views. Crossings are O(changes), not O(tree) — the Fabric approach.

public enum Mutation: Equatable, Sendable {
    case createView(id: Int, type: String)
    case setProp(id: Int, key: String, value: PropValue)
    case removeProp(id: Int, key: String)
    case insertChild(parent: Int, child: Int, index: Int)
    case removeChild(parent: Int, child: Int)
    case destroyView(id: Int)
}

/// Implemented per platform (UIKit, Android/JNI, host test renderer).
public protocol Backend: AnyObject {
    /// Handle of the backend's pre-existing root container. Children of the app
    /// root are inserted here.
    var rootHandle: Int { get }

    /// Apply a batch of mutations to real native views.
    func apply(_ mutations: [Mutation])

    /// Set by the driver. The backend invokes it as `(viewHandle, eventName)`
    /// when the user interacts with a mounted view.
    var eventSink: ((Int, String) -> Void)? { get set }
}
