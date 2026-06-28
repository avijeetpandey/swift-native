// UIKitBackend.swift
// iOS backend: maps mutations onto real UIKit views (UILabel, UIButton,
// UIStackView, ...). Built only when UIKit is available (i.e. when compiling
// for iOS with Xcode). On other hosts it reduces to a marker so the package
// still builds everywhere.

#if canImport(UIKit)
import UIKit
import SwiftNativeCore

public final class UIKitBackend: Backend {
    public let rootHandle = 0
    public var eventSink: ((Int, String) -> Void)?

    private var views: [Int: UIView] = [:]
    private var actions: [Int: ButtonAction] = [:]
    private var scrollContent: [Int: UIStackView] = [:]
    private let container: UIView

    public init(container: UIView) {
        self.container = container
        views[0] = container
    }

    public func apply(_ mutations: [Mutation]) {
        for mutation in mutations { applyOne(mutation) }
    }

    private func applyOne(_ mutation: Mutation) {
        switch mutation {
        case let .createView(id, type):
            views[id] = makeView(id: id, type: type)
        case let .setProp(id, key, value):
            if let view = views[id] { apply(prop: key, value: value, to: view) }
        case let .removeProp(id, key):
            if let view = views[id] { apply(prop: key, value: nil, to: view) }
        case let .insertChild(parent, child, index):
            guard let childView = views[child] else { return }
            // A ScrollView's children go into its inner content stack.
            let parentView = scrollContent[parent] ?? views[parent]
            guard let parentView else { return }
            if let stack = parentView as? UIStackView {
                let clamped = min(index, stack.arrangedSubviews.count)
                stack.insertArrangedSubview(childView, at: clamped)
            } else {
                parentView.addSubview(childView)
                childView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    childView.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
                    childView.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
                ])
            }
        case let .removeChild(_, child):
            views[child]?.removeFromSuperview()
        case let .destroyView(id):
            views[id]?.removeFromSuperview()
            views[id] = nil
            actions[id] = nil
            scrollContent[id] = nil
        }
    }

    private func makeView(id: Int, type: String) -> UIView {
        switch type {
        case "Text":
            let label = UILabel()
            label.numberOfLines = 0
            return label
        case "Button":
            let button = UIButton(type: .system)
            let action = ButtonAction(id: id) { [weak self] handle in self?.eventSink?(handle, "tap") }
            button.addTarget(action, action: #selector(ButtonAction.fire), for: .touchUpInside)
            actions[id] = action
            return button
        case "VStack":
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .center
            return stack
        case "HStack":
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.alignment = .center
            return stack
        case "ZStack":
            return UIView()
        case "ScrollView":
            let scroll = UIScrollView()
            let stack = UIStackView()
            stack.axis = .vertical
            stack.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            ])
            scrollContent[id] = stack
            return scroll
        case "Toggle":
            let toggle = UISwitch()
            let action = ButtonAction(id: id) { [weak self] handle in self?.eventSink?(handle, "toggle") }
            toggle.addTarget(action, action: #selector(ButtonAction.fire), for: .valueChanged)
            actions[id] = action
            return toggle
        case "Divider":
            let line = UIView()
            line.backgroundColor = .separator
            line.heightAnchor.constraint(equalToConstant: 1).isActive = true
            return line
        case "Image":
            return UIImageView()
        case "Spacer":
            let view = UIView()
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            view.setContentHuggingPriority(.defaultLow, for: .vertical)
            return view
        default:
            return UIView()
        }
    }

    private func apply(prop key: String, value: PropValue?, to view: UIView) {
        switch key {
        case "text":
            if case let .string(text)? = value { (view as? UILabel)?.text = text }
        case "title":
            if case let .string(title)? = value { (view as? UIButton)?.setTitle(title, for: .normal) }
        case "on":
            if case let .bool(on)? = value { (view as? UISwitch)?.setOn(on, animated: false) }
        case "foregroundColor":
            if case let .color(color)? = value {
                let uiColor = color.uiColor
                (view as? UILabel)?.textColor = uiColor
                (view as? UIButton)?.setTitleColor(uiColor, for: .normal)
            }
        case "background":
            if case let .color(color)? = value { view.backgroundColor = color.uiColor }
        case "font":
            if case let .font(font)? = value {
                let uiFont = font.uiFont
                (view as? UILabel)?.font = uiFont
                (view as? UIButton)?.titleLabel?.font = uiFont
            }
        case "spacing":
            if case let .double(spacing)? = value { (view as? UIStackView)?.spacing = spacing }
        case "cornerRadius":
            if case let .double(radius)? = value {
                view.layer.cornerRadius = radius
                view.clipsToBounds = true
            }
        case "padding":
            if case let .insets(insets)? = value, let stack = view as? UIStackView {
                stack.isLayoutMarginsRelativeArrangement = true
                stack.layoutMargins = UIEdgeInsets(
                    top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
            }
        case "width":
            if case let .double(width)? = value {
                view.widthAnchor.constraint(equalToConstant: width).isActive = true
            }
        case "height":
            if case let .double(height)? = value {
                view.heightAnchor.constraint(equalToConstant: height).isActive = true
            }
        default:
            break
        }
    }
}

final class ButtonAction: NSObject {
    let id: Int
    let handler: (Int) -> Void
    init(id: Int, handler: @escaping (Int) -> Void) {
        self.id = id
        self.handler = handler
    }
    @objc func fire() { handler(id) }
}

extension Color {
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Font {
    var uiFont: UIFont {
        let weight: UIFont.Weight
        switch self.weight {
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

/// Convenience hosting controller: mount a Swift Native view as an iOS screen.
public final class SwiftNativeViewController: UIViewController {
    private let make: (UIView) -> Driver
    private var driver: Driver?

    public init(_ rootBuilder: @escaping () -> AnyView) {
        self.make = { container in
            Driver(backend: UIKitBackend(container: container)) { rootBuilder() }
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let driver = make(view)
        self.driver = driver
        driver.start()
    }
}

#else

/// Placeholder so the target is non-empty on hosts without UIKit (e.g. macOS).
public enum UIKitBackend {}

#endif
