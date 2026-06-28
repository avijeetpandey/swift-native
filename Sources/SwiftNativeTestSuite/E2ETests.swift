// E2ETests — complete app scenarios exercised end to end through user events:
// a todo app built with ForEach (keyed lists), a settings screen with toggles,
// and multi-screen navigation. These drive the full stack and assert both the
// resulting native tree and the efficiency of the emitted mutations.

import SwiftNativeCore
import SwiftNativeTestRenderer
import SwiftNativeTesting

func e2eTests() -> [TestSuite] {
    [todoSuite(), navigationSuite(), keyedListSuite()]
}

// MARK: - Todo app

struct Todo: Identifiable {
    let id: Int
    var title: String
    var done: Bool
}

struct TodoApp: View {
    @State var todos: [Todo] = [
        Todo(id: 1, title: "Buy milk", done: false),
        Todo(id: 2, title: "Walk dog", done: false),
    ]
    @State var nextID = 3

    var body: some View {
        VStack(spacing: 8) {
            Text("Todos: \(todos.count)")
            Button("Add") {
                todos.append(Todo(id: nextID, title: "Task \(nextID)", done: false))
                nextID += 1
            }
            List {
                ForEach(todos) { todo in
                    HStack {
                        Text(todo.title)
                        Button("x") {
                            todos.removeAll { $0.id == todo.id }
                        }
                    }
                }
            }
        }
    }
}

private func todoSuite() -> TestSuite {
    let s = TestSuite("E2E: Todo app (ForEach lists)")

    s.test("Initial todos render") { t in
        let (backend, driver) = host(TodoApp())
        _ = driver
        t.expect(backend.allText().contains("Buy milk"), "first todo")
        t.expect(backend.allText().contains("Walk dog"), "second todo")
        t.expect(backend.allText().contains("Todos: 2"), "count label")
    }

    s.test("Adding a todo appends a row") { t in
        let (backend, driver) = host(TodoApp())
        _ = driver
        let add = backend.first { $0.type == "Button" && $0.text == "Add" }!
        backend.tap(add)
        t.expect(backend.allText().contains("Task 3"), "new row added")
        t.expect(backend.allText().contains("Todos: 3"), "count updated")
    }

    s.test("Removing a middle todo keeps the others") { t in
        let (backend, driver) = host(TodoApp())
        _ = driver
        // Remove "Buy milk" via its delete button (first 'x').
        let deletes = backend.all(ofType: "Button").filter { $0.text == "x" }
        t.expectEqual(deletes.count, 2, "two delete buttons")
        backend.tap(deletes[0])
        t.expect(!backend.allText().contains("Buy milk"), "first todo removed")
        t.expect(backend.allText().contains("Walk dog"), "second todo remains")
        t.expect(backend.allText().contains("Todos: 1"), "count decreased")
    }

    s.test("Add then remove returns to original set") { t in
        let (backend, driver) = host(TodoApp())
        _ = driver
        let add = backend.first { $0.type == "Button" && $0.text == "Add" }!
        backend.tap(add)
        let deletes = backend.all(ofType: "Button").filter { $0.text == "x" }
        backend.tap(deletes.last!)  // remove the just-added "Task 3"
        t.expect(!backend.allText().contains("Task 3"), "added row removed")
        t.expect(backend.allText().contains("Todos: 2"), "back to 2")
    }

    return s
}

// MARK: - Keyed list correctness

struct ReorderApp: View {
    @State var items: [Int] = [1, 2, 3]
    var body: some View {
        VStack {
            Button("rotate") {
                if !items.isEmpty { items.append(items.removeFirst()) }
            }
            Button("prepend") { items.insert(items.count + 100, at: 0) }
            ForEach(items, id: \.self) { n in
                Text("item-\(n)")
            }
        }
    }
}

private func keyedListSuite() -> TestSuite {
    let s = TestSuite("E2E: Keyed reconciliation")

    s.test("Reordering preserves the same native view handles") { t in
        let (backend, driver) = host(ReorderApp())
        _ = driver
        func handleOf(_ label: String) -> Int? { backend.first { $0.text == label }?.id }

        let h1 = handleOf("item-1")
        let h2 = handleOf("item-2")
        let h3 = handleOf("item-3")
        t.expectNotNil(h1, "item-1 exists")
        t.expectNotNil(h2, "item-2")
        t.expectNotNil(h3, "item-3")

        let rotate = backend.first { $0.type == "Button" && $0.text == "rotate" }!
        backend.tap(rotate)  // [1,2,3] -> [2,3,1]

        // Same elements keep their handles (matched by key), proving moves not rebuilds.
        t.expectEqual(handleOf("item-1"), h1, "item-1 handle stable after move")
        t.expectEqual(handleOf("item-2"), h2, "item-2 handle stable after move")
        t.expectEqual(handleOf("item-3"), h3, "item-3 handle stable after move")

        // Order in the tree now reflects the rotation.
        let order = backend.allText().filter { $0.hasPrefix("item-") }
        t.expectEqual(order, ["item-2", "item-3", "item-1"], "tree order rotated")
    }

    s.test("Prepending inserts without rebuilding existing rows") { t in
        let (backend, driver) = host(ReorderApp())
        _ = driver
        let h1 = backend.first { $0.text == "item-1" }?.id
        let prepend = backend.first { $0.type == "Button" && $0.text == "prepend" }!
        backend.tap(prepend)
        let order = backend.allText().filter { $0.hasPrefix("item-") }
        t.expectEqual(order.first, "item-103", "new item prepended")
        t.expectEqual(backend.first { $0.text == "item-1" }?.id, h1, "existing row handle preserved")
    }

    // Regression: a non-keyed sibling positioned after a variable-length ForEach
    // must keep its native handle when the list length changes (previously it
    // was keyed by absolute index and got destroyed/recreated).
    s.test("Trailing non-keyed sibling survives list growth") { t in
        let (backend, driver) = host(ListWithFooter())
        _ = driver
        let footerBefore = backend.first { $0.text == "footer" }
        t.expectNotNil(footerBefore, "footer present")
        let add = backend.first { $0.type == "Button" && $0.text == "add" }!
        backend.tap(add)
        let footerAfter = backend.first { $0.text == "footer" }
        t.expectEqual(footerAfter?.id, footerBefore?.id, "footer handle stable after list grew")
        // And it must not have been recreated: no destroy/create for the footer.
        let batch = backend.appliedBatches.last ?? []
        t.expect(
            !batch.contains { if case .destroyView = $0 { return true } else { return false } },
            "no destroyView when only adding a list item")
    }

    return s
}

struct ListWithFooter: View {
    @State var items = [1, 2]
    @State var next = 3
    var body: some View {
        VStack {
            Button("add") {
                items.append(next)
                next += 1
            }
            ForEach(items, id: \.self) { n in Text("row-\(n)") }
            Text("footer")
        }
    }
}

// MARK: - Navigation

struct NavApp: View {
    @State var screen = 0
    var body: some View {
        VStack {
            if screen == 0 {
                Text("Home")
                Button("Go to Details") { screen = 1 }
            } else {
                Text("Details")
                Button("Back") { screen = 0 }
            }
        }
    }
}

private func navigationSuite() -> TestSuite {
    let s = TestSuite("E2E: Screen navigation")

    s.test("Navigating swaps screen content") { t in
        let (backend, driver) = host(NavApp())
        _ = driver
        t.expect(backend.allText().contains("Home"), "starts on Home")
        backend.tap(backend.first { $0.type == "Button" && $0.text == "Go to Details" }!)
        t.expect(backend.allText().contains("Details"), "now on Details")
        t.expect(!backend.allText().contains("Home"), "Home gone")
        backend.tap(backend.first { $0.type == "Button" && $0.text == "Back" }!)
        t.expect(backend.allText().contains("Home"), "back on Home")
    }

    return s
}
