// AppKitApp.swift
// A one-call launcher for running a Swift Native app as a real macOS window.
// On a Mac with a display this shows genuine native AppKit views. Headless
// environments (CI) use the test/preview path instead and never call this.

#if canImport(AppKit)
import AppKit
import SwiftNativeCore

public enum SwiftNativeApp {
    /// Launch a Swift Native root view as a native macOS application. Blocks on
    /// the AppKit run loop until the user quits. Must be called on the main thread.
    @MainActor
    public static func run(title: String = "Swift Native", _ root: @escaping () -> AnyView) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let backend = AppKitBackend()
        let driver = Driver(backend: backend) { root() }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = backend.container
        backend.container.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = scroll

        driver.start()
        // Keep the driver alive for the lifetime of the app.
        objc_setAssociatedObject(window, &driverKey, driver, .OBJC_ASSOCIATION_RETAIN)

        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

private nonisolated(unsafe) var driverKey: UInt8 = 0

public enum SwiftNativePreview {
    /// Mount a root view on a real AppKit backend **without** opening a window,
    /// optionally perform a sequence of native button clicks (by title), and
    /// return a textual snapshot of the native NSView tree after each step. Used
    /// by `swiftnative run --preview` so an app can be exercised headlessly (CI,
    /// or a machine without a display) while still using genuine native views.
    @MainActor
    public static func render(taps: [String] = [], _ root: @escaping () -> AnyView) -> String {
        let backend = AppKitBackend()
        let driver = Driver(backend: backend) { root() }
        driver.start()

        var output = "── initial ──\n" + treeDescription(backend.container)
        for title in taps {
            if let button = findButton(backend.container, title: title) {
                button.performClick(nil)
                output += "\n── after tapping \"\(title)\" ──\n" + treeDescription(backend.container)
            } else {
                output += "\n(no button titled \"\(title)\" found)\n"
            }
        }
        _ = driver
        return output
    }

    @MainActor
    public static func findButton(_ view: NSView, title: String) -> NSButton? {
        if let button = view as? NSButton, !(view is NSSwitch), button.title == title {
            return button
        }
        let children = (view as? NSStackView)?.arrangedSubviews ?? view.subviews
        for child in children {
            if let found = findButton(child, title: title) { return found }
        }
        return nil
    }

    @MainActor
    static func treeDescription(_ view: NSView, depth: Int = 0) -> String {
        var line = String(repeating: "  ", count: depth)
        switch view {
        case let label as NSTextField:
            line += "NSTextField \"\(label.stringValue)\""
        case let button as NSButton where !(view is NSSwitch):
            line += "NSButton \"\(button.title)\""
        case is NSSwitch:
            line += "NSSwitch"
        case is NSBox:
            line += "NSBox(separator)"
        case is NSStackView:
            line += "NSStackView"
        default:
            line += String(describing: type(of: view))
        }
        var result = line + "\n"
        let children = (view as? NSStackView)?.arrangedSubviews ?? view.subviews
        for child in children {
            result += treeDescription(child, depth: depth + 1)
        }
        return result
    }
}

#endif
