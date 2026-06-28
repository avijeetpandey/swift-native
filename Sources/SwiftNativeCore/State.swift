// State.swift
// SwiftUI-style `@State`, `@Binding`. Persistent storage lives in the owning
// driver's `StateStore`, keyed by the view's identity path and the declaration
// order of state properties (discovered via reflection before `body` runs).
//
// Change notification is driver-local: each persistent `StateBox` carries an
// `onChange` set by the driver when it binds the box. There is intentionally no
// global runtime, so multiple drivers (screens, previews, tests) are fully
// isolated from one another.

public final class StateBox {
    public var value: Any
    /// Set by the owning driver during state binding. Invoked after every
    /// mutation to request a re-render of that driver only.
    var onChange: (() -> Void)?
    public init(_ value: Any) { self.value = value }

    func mutate(_ newValue: Any) {
        value = newValue
        onChange?()
    }
}

final class StateStorage {
    let initial: Any
    var box: StateBox?
    init(initial: Any) { self.initial = initial }
}

/// Internal protocol so the reconciler can find `@State` via reflection.
protocol StatePropertyProtocol {
    var storage: StateStorage { get }
}

@propertyWrapper
public struct State<Value>: StatePropertyProtocol {
    let storage: StateStorage

    public init(wrappedValue: Value) {
        self.storage = StateStorage(initial: wrappedValue)
    }

    public var wrappedValue: Value {
        get {
            guard let box = storage.box else { return storage.initial as! Value }
            return box.value as! Value
        }
        nonmutating set {
            storage.box?.mutate(newValue)
        }
    }

    public var projectedValue: Binding<Value> {
        let storage = self.storage
        return Binding(
            get: { (storage.box?.value as? Value) ?? (storage.initial as! Value) },
            set: { newValue in storage.box?.mutate(newValue) }
        )
    }
}

@propertyWrapper
public struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.get = get
        self.set = set
    }

    public var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }

    public var projectedValue: Binding<Value> { self }

    /// Derive a binding to a sub-value (e.g. `$user.name`).
    public func map<T>(get getter: @escaping (Value) -> T, set setter: @escaping (Value, T) -> Value)
        -> Binding<T>
    {
        Binding<T>(
            get: { getter(self.wrappedValue) },
            set: { newValue in self.set(setter(self.get(), newValue)) }
        )
    }
}
