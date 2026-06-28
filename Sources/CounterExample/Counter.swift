// Counter.swift
// The Phase-1 walking skeleton, written in pure Swift Native. The SAME code is
// mounted by the host test renderer, the UIKit backend (iOS) and the Android
// backend (Android).

import SwiftNativeCore

public struct CounterView: View {
    @State private var count = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Swift Native")
                .font(.title)
                .foregroundColor(.blue)

            Text("Count: \(count)")
                .font(.system(size: 20, weight: .semibold))

            Button("Increment") {
                count += 1
            }
            .padding(8)

            Button("Decrement") {
                count -= 1
            }
            .padding(8)
        }
        .padding(24)
    }
}

public struct CounterApp: App {
    public init() {}
    public var body: some View {
        CounterView()
    }
}
