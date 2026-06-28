// SwiftNativeTesting — a tiny, dependency-free test framework.
//
// Full Xcode (and therefore XCTest) is not available with the Command Line
// Tools, and swift-testing is not wired into SwiftPM there either. This module
// provides just enough structure — suites, cases, assertions and a runner with
// a process exit code — to write unit, integration and end-to-end tests that
// run anywhere a Swift toolchain exists, and to measure coverage with llvm-cov.

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Collects assertion results for one test case. Used only on the runner's
/// thread (the main thread), hence `@unchecked Sendable` so assertions may run
/// inside `MainActor.assumeIsolated` blocks for native-UI backends.
public final class TestContext: @unchecked Sendable {
    public private(set) var failures: [String] = []
    public private(set) var assertions = 0
    let caseName: String

    init(caseName: String) { self.caseName = caseName }

    public func expect(
        _ condition: Bool, _ message: @autoclosure () -> String, file: StaticString = #file,
        line: UInt = #line
    ) {
        assertions += 1
        if !condition {
            failures.append("\(shortFile(file)):\(line): \(message())")
        }
    }

    public func expectEqual<T: Equatable>(
        _ actual: T, _ expected: T, _ message: @autoclosure () -> String = "", file: StaticString = #file,
        line: UInt = #line
    ) {
        assertions += 1
        if actual != expected {
            let extra = message().isEmpty ? "" : " — \(message())"
            failures.append("\(shortFile(file)):\(line): expected \(expected), got \(actual)\(extra)")
        }
    }

    public func expectNotNil<T>(
        _ value: T?, _ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line
    ) {
        assertions += 1
        if value == nil {
            failures.append("\(shortFile(file)):\(line): expected non-nil — \(message())")
        }
    }

    public func fail(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        assertions += 1
        failures.append("\(shortFile(file)):\(line): \(message())")
    }

    private func shortFile(_ file: StaticString) -> String {
        let path = "\(file)"
        return path.split(separator: "/").last.map(String.init) ?? path
    }
}

public struct TestCase {
    public let name: String
    public let body: (TestContext) -> Void
    public init(_ name: String, _ body: @escaping (TestContext) -> Void) {
        self.name = name
        self.body = body
    }
}

public final class TestSuite {
    public let name: String
    public private(set) var cases: [TestCase] = []
    public init(_ name: String) { self.name = name }

    public func test(_ name: String, _ body: @escaping (TestContext) -> Void) {
        cases.append(TestCase(name, body))
    }
}

public enum ANSIColor {
    static let enabled = isatty(fileno(stdout)) != 0
    static func green(_ s: String) -> String { enabled ? "\u{001B}[32m\(s)\u{001B}[0m" : s }
    static func red(_ s: String) -> String { enabled ? "\u{001B}[31m\(s)\u{001B}[0m" : s }
    static func bold(_ s: String) -> String { enabled ? "\u{001B}[1m\(s)\u{001B}[0m" : s }
    static func dim(_ s: String) -> String { enabled ? "\u{001B}[2m\(s)\u{001B}[0m" : s }
}

public final class TestRunner {
    private var suites: [TestSuite] = []
    public init() {}

    public func add(_ suite: TestSuite) { suites.append(suite) }

    /// Run all suites. Returns a process exit code (0 = all passed).
    @discardableResult
    public func run() -> Int32 {
        var totalCases = 0
        var failedCases = 0
        var totalAssertions = 0

        for suite in suites {
            print("\n" + ANSIColor.bold("◆ \(suite.name)"))
            for testCase in suite.cases {
                totalCases += 1
                let context = TestContext(caseName: testCase.name)
                testCase.body(context)
                totalAssertions += context.assertions
                if context.failures.isEmpty {
                    print(
                        "  " + ANSIColor.green("✓") + " \(testCase.name) "
                            + ANSIColor.dim("(\(context.assertions) assertions)"))
                } else {
                    failedCases += 1
                    print("  " + ANSIColor.red("✗") + " \(testCase.name)")
                    for failure in context.failures {
                        print("      " + ANSIColor.red(failure))
                    }
                }
            }
        }

        let passedCases = totalCases - failedCases
        print("\n" + String(repeating: "─", count: 56))
        if failedCases == 0 {
            print(
                ANSIColor.green(ANSIColor.bold("✓ \(passedCases)/\(totalCases) test cases passed"))
                    + ANSIColor.dim(" (\(totalAssertions) assertions)"))
        } else {
            print(
                ANSIColor.red(ANSIColor.bold("✗ \(failedCases)/\(totalCases) test cases FAILED"))
                    + ANSIColor.dim(" (\(totalAssertions) assertions)"))
        }
        return failedCases == 0 ? 0 : 1
    }
}
