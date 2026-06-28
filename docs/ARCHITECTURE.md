# Architecture

This document explains how Swift Native turns a single Swift UI description into
real native widgets on each platform. If you've ever wondered how React Native's
renderer works, this will feel familiar — the design borrows the good ideas and
implements them in Swift.

## The big picture

```
        Your app (pure Swift, written once)
        VStack { Text("Count: \(n)"); Button("+") { n += 1 } }
                            │
                            ▼
                 ┌─────────────────────┐
                 │   Render pass        │   walks your View tree, runs `body`,
                 │   (RenderContext)    │   binds @State, produces a Node tree
                 └─────────┬───────────┘
                            ▼
                 ┌─────────────────────┐
                 │   Reconciler         │   diffs old vs new Node tree and emits
                 │   (keyed diff)       │   a minimal, ordered list of Mutations
                 └─────────┬───────────┘
                            ▼
         ┌──────────────────┼───────────────────┐
         ▼                  ▼                    ▼
   AppKitBackend      UIKitBackend         AndroidBackend
   (real NSView)      (real UIView)        (native Swift → JNI → Android View)
```

Everything above the backends is platform-agnostic and lives in
`SwiftNativeCore`, which has **zero imports** — not even Foundation — so it
compiles unchanged for macOS, iOS and Android.

## The pieces

### Views (`View.swift`, `Primitives.swift`, `Components.swift`)

A `View` is a value type with a `body`, exactly like SwiftUI:

```swift
struct Greeting: View {
    var body: some View {
        Text("Hello")
    }
}
```

`@ViewBuilder` collects the children of a container into a `TupleView`.
Primitives (`Text`, `Button`, stacks, …) conform to an internal `NodeProducing`
protocol and emit their own render nodes instead of recursing into a `body`.

### The Node tree (`Node.swift`)

A render pass flattens your views into a tree of `Node`s. A `Node` is a simple
class holding a `type` string (`"Text"`, `"Button"`, `"VStack"`, …), a dictionary
of `props`, its `children`, any event handlers, and — once mounted — a stable
backend `handle`. Event handlers stay on the Swift side and never cross the
bridge; the backend only learns a view is interactive through a boolean prop and
calls back by handle.

### State (`State.swift`, `RenderContext.swift`)

`@State` stores its value in a `StateBox` that lives in the driver's `StateStore`,
not in the view value (views are recreated every render). During a render pass,
`RenderContext` walks each composite view with reflection, finds its `@State`
properties by declaration order, and connects them to persistent boxes keyed by
the view's identity path. `ForEach` gives each element its own identity scope so
a row's state follows the row, not its position.

Mutating `@State` notifies the box, which calls back into the owning driver to
request a re-render. Notification is **driver-local** — there is no global
runtime — so multiple screens or previews are fully isolated from one another.

### The reconciler (`Reconciler.swift`)

This is the heart of the framework. Given the previous Node tree and the new one,
it produces the smallest set of `Mutation`s that turns one into the other:

```swift
enum Mutation {
    case createView(id: Int, type: String)
    case setProp(id: Int, key: String, value: PropValue)
    case removeProp(id: Int, key: String)
    case insertChild(parent: Int, child: Int, index: Int)
    case removeChild(parent: Int, child: Int)
    case destroyView(id: Int)
}
```

Handles are stable across renders, so a counter tap produces exactly **one**
`setProp(text:)` — the label is updated in place, not rebuilt. Crossings into the
native layer are therefore proportional to what changed, not to the size of the
tree (the same principle behind React's Fabric renderer).

When a list of children carries stable keys (from `ForEach`), the reconciler
switches to a **keyed** diff: it matches rows by key, so inserting, removing or
reordering rows moves the existing native views instead of rebuilding them — and
their state comes along for the ride.

### Layout (`Layout.swift`)

A small stack-based layout pass measures and positions nodes (vertical/horizontal
stacks, padding, fixed frames, spacers). It is deliberately self-contained and
is the piece most directly replaceable by a full Flexbox engine (e.g. Yoga)
behind the same call site.

### The driver and backends (`Runtime.swift`, `Mutation.swift`)

The `Driver` owns the loop: it runs a render pass, reconciles against the previous
tree, runs layout, and hands the mutation batch to a `Backend`. It also batches
all the state changes made inside a single event into one render — so
`items.append(items.removeFirst())` produces one coherent update rather than a
flicker of intermediate states.

A `Backend` is a tiny protocol:

```swift
protocol Backend: AnyObject {
    var rootHandle: Int { get }
    func apply(_ mutations: [Mutation])
    var eventSink: ((Int, String) -> Void)? { get set }
}
```

Each platform implements it:

- **AppKitBackend** maps mutations onto real `NSView`/`NSButton`/`NSTextField`/
  `NSStackView`/`NSSwitch` and routes clicks back through `eventSink`.
- **UIKitBackend** does the same with `UIView`/`UILabel`/`UIButton`/`UIStackView`.
- **AndroidBackend** runs as native Swift on the device and applies the batch
  through a thin JNI bridge to a Kotlin host that creates real `android.view.View`
  objects.
- **TestBackend** materialises mutations into an in-memory tree for deterministic
  tests.

Because everything funnels through this one protocol, adding a platform is a
matter of writing one backend — the core, the reconciler and your app code don't
change.

## The Android bridge

On Android the data flow is:

```
Swift core ──(C ABI: snhost_*)──▶ libbridge (JNI) ──▶ Kotlin SwiftNativeHost
Kotlin host ──(dispatchEvent)──▶ libbridge ──▶ swiftnative_android_dispatch_event
```

The Swift `AndroidBackend` calls a handful of C functions (declared with
`@_silgen_name`); a small C shim (`android-host/jni/bridge.c`) forwards each to
the Kotlin host, which applies it to real Android views on the UI thread. Events
travel back the other way into a `@_cdecl` Swift entry point. This is the one
place the framework is not pure Swift — the bridge needs a little Kotlin and C —
but your application code never sees it.

## Why this design

- **One mental model, many platforms.** You write views; the core decides what
  changed; each backend knows how to mount native widgets. Nothing about your app
  code is platform-specific.
- **Native, not emulated.** There is no webview and no drawing canvas. The output
  is the platform's own widgets, so accessibility, theming and system behaviours
  come for free.
- **Efficient by construction.** Stable handles + minimal diffs + batched events
  keep updates cheap and bridge traffic low.
