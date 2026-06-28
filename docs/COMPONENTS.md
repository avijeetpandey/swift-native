# Components & Modifiers

A reference for everything you can use in a Swift Native view. The API mirrors
SwiftUI, so most of it will look immediately familiar.

> All of these live in `SwiftNativeCore`. Add `import SwiftNativeCore` at the top
> of your file.

## Layout containers

### `VStack`

Stacks children vertically.

```swift
VStack(alignment: .center, spacing: 12) {
    Text("Title")
    Text("Subtitle")
}
```

- `alignment: HorizontalAlignment` — `.leading`, `.center` (default), `.trailing`
- `spacing: Double` — gap between children (default `8`)

### `HStack`

Stacks children horizontally.

```swift
HStack(alignment: .center, spacing: 8) {
    Image(systemName: "star")
    Text("Favourite")
}
```

- `alignment: VerticalAlignment` — `.top`, `.center` (default), `.bottom`
- `spacing: Double` — default `8`

### `ZStack`

Overlays children on top of each other.

```swift
ZStack {
    Color.blue
    Text("On top")
}
```

### `ScrollView`

A scrolling container.

```swift
ScrollView(.vertical) {
    ForEach(items, id: \.self) { Text("\($0)") }
}
```

### `List`

A vertically scrolling list — convenience over `ScrollView` + `VStack`.

```swift
List {
    ForEach(people) { person in
        Text(person.name)
    }
}
```

### `Spacer`

Flexible empty space that pushes siblings apart.

```swift
HStack {
    Text("Left")
    Spacer()
    Text("Right")
}
```

## Content views

### `Text`

```swift
Text("Hello, world")
Text(42)                     // also accepts Int
Text("Count: \(count)")      // string interpolation
```

### `Button`

```swift
Button("Tap me") { print("tapped") }

// Custom label
Button(action: { save() }) {
    HStack { Image(systemName: "tray"); Text("Save") }
}
```

### `Image`

A system symbol image (SF Symbols-style name).

```swift
Image(systemName: "heart.fill")
```

### `Toggle`

A boolean switch bound to state.

```swift
@State private var isOn = false

Toggle("Notifications", isOn: $isOn)
```

### `Divider`

A thin separator line.

```swift
VStack {
    Text("Above")
    Divider()
    Text("Below")
}
```

### `ForEach`

Renders a view per element. Provide a stable identity so list updates are
efficient and state-preserving.

```swift
// By key path
ForEach(items, id: \.self) { item in
    Text("\(item)")
}

// By Identifiable
struct Person: Identifiable { let id: Int; let name: String }
ForEach(people) { person in
    Text(person.name)
}

// By explicit closure
ForEach(rows, id: { $0.token }) { row in
    Text(row.title)
}
```

## Modifiers

Chain these on any view. Each returns a new view.

| Modifier | Example | Effect |
|---|---|---|
| `padding(_:)` | `.padding(16)` or `.padding(EdgeInsets(all: 8))` | Insets the view |
| `foregroundColor(_:)` | `.foregroundColor(.blue)` | Text/tint colour |
| `background(_:)` | `.background(.white)` | Background colour |
| `font(_:)` | `.font(.title)` | Text font |
| `frame(width:height:)` | `.frame(width: 100, height: 44)` | Fixed size |
| `cornerRadius(_:)` | `.cornerRadius(8)` | Rounded corners |

```swift
Text("Styled")
    .font(.system(size: 20, weight: .semibold))
    .foregroundColor(.white)
    .padding(12)
    .background(.blue)
    .cornerRadius(8)
```

## Values

### `Color`

```swift
Color.black  Color.white  Color.red  Color.green
Color.blue   Color.gray   Color.clear
Color(red: 0.2, green: 0.5, blue: 0.9)            // alpha defaults to 1
Color(red: 0, green: 0, blue: 0, alpha: 0.5)
```

### `Font`

```swift
Font.body            // size 17
Font.title           // size 28, bold
Font.caption         // size 12
Font.system(size: 20, weight: .semibold)
// weights: .regular, .medium, .semibold, .bold
```

### `EdgeInsets`

```swift
EdgeInsets(all: 16)
EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
```

## State

### `@State`

Local, mutable, view-owned state. Mutating it re-renders the view.

```swift
struct Counter: View {
    @State private var count = 0
    var body: some View {
        Button("Count: \(count)") { count += 1 }
    }
}
```

### `@Binding`

A read/write reference to state owned elsewhere — pass it with `$`.

```swift
struct Parent: View {
    @State private var on = false
    var body: some View {
        Switch(isOn: $on)
    }
}

struct Switch: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(isOn ? "On" : "Off") { isOn.toggle() }
    }
}
```

`Binding` also has `map(get:set:)` to derive a binding to a sub-value.

## Conditionals and loops

`if`/`else` and `ForEach` work inside any view builder:

```swift
VStack {
    if isLoggedIn {
        Text("Welcome back")
    } else {
        Button("Log in") { logIn() }
    }

    ForEach(notifications) { note in
        Text(note.message)
    }
}
```
