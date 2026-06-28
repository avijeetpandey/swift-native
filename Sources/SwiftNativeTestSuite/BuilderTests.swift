// BuilderTests — exercises the ViewBuilder arities, conditional branches and
// the Binding plumbing that the higher-level scenario tests don't fully cover.

import SwiftNativeCore
import SwiftNativeTestRenderer
import SwiftNativeTesting

func builderTests() -> [TestSuite] {
    [viewBuilderSuite(), bindingSuite(), erasureSuite()]
}

private struct NChildren: View {
    let n: Int
    var body: some View {
        // Distinct child counts hit the different buildBlock overloads.
        switch n {
        case 4:
            return AnyView(
                VStack {
                    Text("1")
                    Text("2")
                    Text("3")
                    Text("4")
                })
        case 5:
            return AnyView(
                VStack {
                    Text("1")
                    Text("2")
                    Text("3")
                    Text("4")
                    Text("5")
                })
        case 6:
            return AnyView(
                VStack {
                    Text("1")
                    Text("2")
                    Text("3")
                    Text("4")
                    Text("5")
                    Text("6")
                })
        case 7:
            return AnyView(
                VStack {
                    Text("1")
                    Text("2")
                    Text("3")
                    Text("4")
                    Text("5")
                    Text("6")
                    Text("7")
                })
        case 9:
            return AnyView(
                VStack {
                    Text("1")
                    Text("2")
                    Text("3")
                    Text("4")
                    Text("5")
                    Text("6")
                    Text("7")
                    Text("8")
                    Text("9")
                })
        default: return AnyView(EmptyView())
        }
    }
}

private struct EitherView: View {
    let flag: Bool
    var body: some View {
        VStack {
            if flag {
                Text("yes")
            } else {
                Text("no")
            }
        }
    }
}

private func viewBuilderSuite() -> TestSuite {
    let s = TestSuite("Unit: ViewBuilder arities & branches")

    for count in [4, 5, 6, 7, 9] {
        s.test("buildBlock with \(count) children") { t in
            let (backend, driver) = host(NChildren(n: count))
            _ = driver
            t.expectEqual(backend.all(ofType: "Text").count, count)
        }
    }

    s.test("if/else picks the right branch (buildEither)") { t in
        let (yesBackend, d1) = host(EitherView(flag: true))
        let (noBackend, d2) = host(EitherView(flag: false))
        _ = (d1, d2)
        t.expect(yesBackend.allText().contains("yes"), "true branch")
        t.expect(!yesBackend.allText().contains("no"), "false branch absent")
        t.expect(noBackend.allText().contains("no"), "false branch")
    }

    s.test("EmptyView renders nothing") { t in
        let (backend, driver) = host(EmptyView())
        _ = driver
        t.expectEqual(backend.root.children.count, 0)
    }

    return s
}

private struct CounterWithBinding: View {
    @State var value = 0
    var body: some View {
        VStack {
            Text("v=\(value)")
            StepperRow(value: $value)
        }
    }
}

private struct StepperRow: View {
    @Binding var value: Int
    var body: some View {
        HStack {
            Button("inc") { value += 1 }
            Button("dec") { value -= 1 }
        }
    }
}

private func bindingSuite() -> TestSuite {
    let s = TestSuite("Unit: Bindings")

    s.test("@Binding drives parent @State") { t in
        let (backend, driver) = host(CounterWithBinding())
        _ = driver
        t.expect(backend.allText().contains("v=0"), "starts at 0")
        backend.tap(backend.first { $0.text == "inc" }!)
        backend.tap(backend.first { $0.text == "inc" }!)
        t.expect(backend.allText().contains("v=2"), "binding incremented parent state")
        backend.tap(backend.first { $0.text == "dec" }!)
        t.expect(backend.allText().contains("v=1"), "binding decremented parent state")
    }

    s.test("Binding.map projects and writes back") { t in
        final class Box { var v = 5 }
        let box = Box()
        let base = Binding(get: { box.v }, set: { box.v = $0 })
        base.wrappedValue = 10
        t.expectEqual(box.v, 10, "direct set")

        let doubled = base.map(get: { $0 * 2 }, set: { _, new in new / 2 })
        t.expectEqual(doubled.wrappedValue, 20, "projected getter")
        doubled.wrappedValue = 30
        t.expectEqual(box.v, 15, "projected setter writes back")

        // projectedValue returns self.
        t.expectEqual(base.projectedValue.wrappedValue, box.v)
    }

    return s
}

private func erasureSuite() -> TestSuite {
    let s = TestSuite("Unit: Type erasure")

    s.test("AnyView wraps and renders any view") { t in
        let views: [AnyView] = [AnyView(Text("a")), AnyView(Button("b") {})]
        let (backend, driver) = host(VStack { ForEach(0..<views.count, id: \.self) { i in views[i] } })
        _ = driver
        t.expect(backend.allText().contains("a"), "wrapped Text")
        t.expect(backend.allText().contains("b"), "wrapped Button")
    }

    return s
}
