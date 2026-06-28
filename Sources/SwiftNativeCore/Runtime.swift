// Runtime.swift
// Ties everything together: the `App` entry point and the `Driver` that owns
// the render loop, state store, reconciler, and backend.

public protocol App {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
    init()
}

public final class Driver {
    private let backend: Backend
    private let store = StateStore()
    private let reconciler = Reconciler()
    private let rootFactory: () -> AnyView
    private var previousRoot: [Node] = []
    private let containerSize: Size
    private var isRendering = false
    private var isDispatching = false
    private var needsRerender = false

    public init(
        backend: Backend, containerSize: Size = Size(width: 390, height: 844), root: @escaping () -> AnyView
    ) {
        self.backend = backend
        self.rootFactory = root
        self.containerSize = containerSize

        backend.eventSink = { [weak self] handle, event in
            self?.dispatchEvent(handle: handle, event: event)
        }
    }

    public func start() {
        render()
    }

    /// Dispatch a UI event, batching all state changes it makes into a single
    /// re-render afterwards (like SwiftUI transactions). This prevents
    /// intermediate states — e.g. `array.append(array.removeFirst())` writing
    /// `@State` twice — from producing spurious renders that rebuild views.
    private func dispatchEvent(handle: Int, event: String) {
        isDispatching = true
        reconciler.dispatch(handle: handle, event: event)
        isDispatching = false
        if needsRerender { render() }
    }

    /// Driver-local re-render request. Coalesces requests that arrive while a
    /// render is in flight or while an event is being dispatched.
    private func requestRender() {
        if isRendering || isDispatching {
            needsRerender = true
            return
        }
        render()
    }

    private func render() {
        isRendering = true
        defer { isRendering = false }

        repeat {
            needsRerender = false

            var context = RenderContext(store: store, notify: { [weak self] in self?.requestRender() })
            let newRoot = renderNodes(rootFactory(), &context)

            var mutations: [Mutation] = []
            reconciler.reconcileRoot(
                rootHandle: backend.rootHandle, old: previousRoot, new: newRoot, into: &mutations)

            Layout.perform(on: newRoot, container: containerSize)
            previousRoot = newRoot

            backend.apply(mutations)
        } while needsRerender
    }
}

/// Mount a root view onto a backend and start the render loop.
@discardableResult
public func mount<V: View>(_ view: @escaping @autoclosure () -> V, on backend: Backend) -> Driver {
    let driver = Driver(backend: backend) { AnyView(view()) }
    driver.start()
    return driver
}

/// Mount an `App`'s body.
@discardableResult
public func mount<A: App>(_ app: A, on backend: Backend) -> Driver {
    let driver = Driver(backend: backend) { AnyView(app.body) }
    driver.start()
    return driver
}
