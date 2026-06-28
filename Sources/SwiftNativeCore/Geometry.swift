// Geometry.swift
// Basic value types shared by the layout engine and all backends.

public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }
    public static let zero = Point(x: 0, y: 0)
}

public struct Size: Equatable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double = 0, height: Double = 0) {
        self.width = width
        self.height = height
    }
    public static let zero = Size(width: 0, height: 0)
}

public struct Rect: Equatable, Sendable {
    public var origin: Point
    public var size: Size
    public init(origin: Point = .zero, size: Size = .zero) {
        self.origin = origin
        self.size = size
    }
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }
    public var x: Double { origin.x }
    public var y: Double { origin.y }
    public var width: Double { size.width }
    public var height: Double { size.height }
    public static let zero = Rect()
}

public struct EdgeInsets: Equatable, Sendable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double
    public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
    public init(all value: Double) {
        self.init(top: value, leading: value, bottom: value, trailing: value)
    }
    public static let zero = EdgeInsets()
    public var horizontal: Double { leading + trailing }
    public var vertical: Double { top + bottom }
}

public struct Color: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = Color(red: 0, green: 0, blue: 0)
    public static let white = Color(red: 1, green: 1, blue: 1)
    public static let red = Color(red: 1, green: 0, blue: 0)
    public static let green = Color(red: 0, green: 0.6, blue: 0)
    public static let blue = Color(red: 0, green: 0.48, blue: 1)
    public static let gray = Color(red: 0.5, green: 0.5, blue: 0.5)
    public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)

    /// `#RRGGBB` / `#RRGGBBAA` hex form used to ship the color across the bridge.
    public var hex: String {
        let digits = Array("0123456789ABCDEF")
        func channel(_ v: Double) -> String {
            let clamped = Swift.max(0, Swift.min(1, v))
            let n = Int((clamped * 255).rounded())
            return String([digits[(n >> 4) & 0xF], digits[n & 0xF]])
        }
        return "#" + channel(red) + channel(green) + channel(blue) + channel(alpha)
    }
}

public struct Font: Equatable, Sendable {
    public enum Weight: String, Equatable, Sendable {
        case regular, medium, semibold, bold
    }
    public var size: Double
    public var weight: Weight
    public init(size: Double, weight: Weight = .regular) {
        self.size = size
        self.weight = weight
    }
    public static let body = Font(size: 17)
    public static let title = Font(size: 28, weight: .bold)
    public static let caption = Font(size: 12)
    public static func system(size: Double, weight: Weight = .regular) -> Font {
        Font(size: size, weight: weight)
    }
}

public enum Axis: String, Sendable {
    case horizontal
    case vertical
}

public enum HorizontalAlignment: String, Sendable {
    case leading, center, trailing
}

public enum VerticalAlignment: String, Sendable {
    case top, center, bottom
}
