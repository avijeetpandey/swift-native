// AppKitBackend.swift
// Native macOS backend: maps Swift Native mutations onto REAL AppKit views
// (NSTextField, NSButton, NSStackView, NSSwitch, NSBox, NSScrollView). Built
// only where AppKit is available. This is the backend used to run Swift Native
// apps natively on macOS and to integration-test against a real OS UI toolkit.

#if canImport(AppKit)
import AppKit
import SwiftNativeCore

/// Native macOS backend. All view mutation happens on the main thread; the
/// class is `@unchecked Sendable` with that documented invariant, enforced at
/// runtime by `MainActor.assumeIsolated`.
public final class AppKitBackend: Backend, @unchecked Sendable {
    public let rootHandle = 0
    public var eventSink: ((Int, String) -> Void)?

    public let container: NSView
    private var views: [Int: NSView] = [:]
    private var targets: [Int: ControlTarget] = [:]
    private var sizeConstraints: [Int: (width: NSLayoutConstraint?, height: NSLayoutConstraint?)] = [:]

    public init(container: NSView? = nil) {
        let root =
            container
            ?? MainActor.assumeIsolated { () -> NSView in
                let stack = NSStackView()
                stack.orientation = .vertical
                stack.alignment = .centerX
                stack.spacing = 0
                return stack
            }
        self.container = root
        views[0] = root
    }

    /// Read access to a mounted native view (used by integration tests and for
    /// embedding Swift Native inside a hand-written AppKit screen).
    public func nativeView(_ handle: Int) -> NSView? { views[handle] }

    public func apply(_ mutations: [Mutation]) {
        MainActor.assumeIsolated {
            for mutation in mutations { applyOne(mutation) }
        }
    }

    @MainActor
    private func applyOne(_ mutation: Mutation) {
        switch mutation {
        case let .createView(id, type):
            views[id] = makeView(id: id, type: type)
        case let .setProp(id, key, value):
            if let view = views[id] { apply(prop: key, value: value, to: view, id: id) }
        case let .removeProp(id, key):
            if let view = views[id] { apply(prop: key, value: nil, to: view, id: id) }
        case let .insertChild(parent, child, index):
            guard let parentView = views[parent], let childView = views[child] else { return }
            insert(childView, into: parentView, at: index)
        case let .removeChild(_, child):
            guard let childView = views[child] else { return }
            remove(childView)
        case let .destroyView(id):
            views[id]?.removeFromSuperview()
            views[id] = nil
            targets[id] = nil
            sizeConstraints[id] = nil
        }
    }

    @MainActor
    private func makeView(id: Int, type: String) -> NSView {
        switch type {
        case "Text":
            return NSTextField(labelWithString: "")
        case "Button":
            let button = NSButton(title: "", target: nil, action: nil)
            button.bezelStyle = .rounded
            let target = ControlTarget(id: id) { [weak self] handle in self?.eventSink?(handle, "tap") }
            button.target = target
            button.action = #selector(ControlTarget.fire)
            targets[id] = target
            return button
        case "Toggle":
            let toggle = NSSwitch()
            let target = ControlTarget(id: id) { [weak self] handle in self?.eventSink?(handle, "toggle") }
            toggle.target = target
            toggle.action = #selector(ControlTarget.fire)
            targets[id] = target
            return toggle
        case "VStack":
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 8
            return stack
        case "HStack":
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 8
            return stack
        case "ZStack":
            return NSView()
        case "ScrollView":
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .centerX
            return stack
        case "Divider":
            let box = NSBox()
            box.boxType = .separator
            return box
        case "Image":
            return NSImageView()
        case "Spacer":
            return NSView()
        default:
            return NSView()
        }
    }

    @MainActor
    private func apply(prop key: String, value: PropValue?, to view: NSView, id: Int) {
        switch key {
        case "text":
            if case let .string(text)? = value { (view as? NSTextField)?.stringValue = text }
        case "title":
            if case let .string(title)? = value {
                (view as? NSButton)?.title = title
                (view as? NSSwitch)?.toolTip = title
            }
        case "on":
            if case let .bool(on)? = value {
                (view as? NSSwitch)?.state = on ? .on : .off
            }
        case "foregroundColor":
            if case let .color(color)? = value { (view as? NSTextField)?.textColor = color.nsColor }
        case "background":
            if case let .color(color)? = value {
                view.wantsLayer = true
                view.layer?.backgroundColor = color.nsColor.cgColor
            }
        case "font":
            if case let .font(font)? = value { (view as? NSTextField)?.font = font.nsFont }
        case "spacing":
            if case let .double(spacing)? = value { (view as? NSStackView)?.spacing = spacing }
        case "cornerRadius":
            if case let .double(radius)? = value {
                view.wantsLayer = true
                view.layer?.cornerRadius = radius
            }
        case "padding":
            if case let .insets(insets)? = value, let stack = view as? NSStackView {
                stack.edgeInsets = NSEdgeInsets(
                    top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
            }
        case "width":
            updateSizeConstraint(id: id, view: view, isWidth: true, value: value)
        case "height":
            updateSizeConstraint(id: id, view: view, isWidth: false, value: value)
        default:
            break
        }
    }

    /// Reuse a single width/height constraint per view, updating its constant
    /// (or removing it) instead of stacking new, conflicting constraints on
    /// every change.
    @MainActor
    private func updateSizeConstraint(id: Int, view: NSView, isWidth: Bool, value: PropValue?) {
        var pair = sizeConstraints[id] ?? (nil, nil)
        let existing = isWidth ? pair.width : pair.height
        if case let .double(amount)? = value {
            if let existing {
                existing.constant = amount
            } else {
                let constraint =
                    isWidth
                    ? view.widthAnchor.constraint(equalToConstant: amount)
                    : view.heightAnchor.constraint(equalToConstant: amount)
                constraint.isActive = true
                if isWidth { pair.width = constraint } else { pair.height = constraint }
            }
        } else {
            // Removal: deactivate and drop the stored constraint.
            existing?.isActive = false
            if isWidth { pair.width = nil } else { pair.height = nil }
        }
        sizeConstraints[id] = pair
    }

    @MainActor
    private func insert(_ child: NSView, into parent: NSView, at index: Int) {
        if let stack = parent as? NSStackView {
            let clamped = min(index, stack.arrangedSubviews.count)
            stack.insertArrangedSubview(child, at: clamped)
        } else {
            parent.addSubview(child)
        }
    }

    @MainActor
    private func remove(_ child: NSView) {
        if let stack = child.superview as? NSStackView {
            stack.removeArrangedSubview(child)
        }
        child.removeFromSuperview()
    }
}

final class ControlTarget: NSObject {
    let id: Int
    let handler: (Int) -> Void
    init(id: Int, handler: @escaping (Int) -> Void) {
        self.id = id
        self.handler = handler
    }
    @objc func fire() { handler(id) }
}

extension Color {
    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Font {
    var nsFont: NSFont {
        let weight: NSFont.Weight
        switch self.weight {
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }
}

#else

/// Placeholder so the target is non-empty on hosts without AppKit.
public enum AppKitBackend {}

#endif
