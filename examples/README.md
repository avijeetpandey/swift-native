# Examples

Runnable apps built with Swift Native.

## TodoApp

A small two-screen app — a to-do list (add/remove rows backed by `ForEach`) and
an about screen with a like button. It references the framework from this repo by
relative path, so it builds straight from a checkout.

```sh
cd examples/TodoApp
swift run                       # opens a native macOS window
swift run TodoApp --preview     # prints the native view tree
swift run TodoApp --preview --tap "Add Task" --tap About
```

The same code is what you'd ship to iOS and Android; see
[../SETUP.md](../SETUP.md) for building those targets.

## More

- The [`CounterExample`](../Sources/CounterExample) target is the smallest
  possible example, shared with the test suite.
- [`swiftnative new <AppName>`](../GETTING_STARTED.md) scaffolds a fresh,
  multi-screen app you can run immediately.
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) is a cookbook of copy-pasteable snippets.
