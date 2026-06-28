// AndroidBackend.swift
// Android backend: native Swift (compiled for Android via the Swift Android SDK
// + NDK) that drives REAL android.view.View objects through a thin JNI bridge.
//
// Data flow:
//   Swift core  --(C ABI: snhost_*)-->  libbridge (JNI)  -->  Kotlin host
//   Kotlin host --(nativeDispatchEvent)--> libbridge --> swiftnative_android_*
//
// Built only when compiling for Android. On other hosts it reduces to a marker
// so the package still builds everywhere.

#if os(Android)
import SwiftNativeCore

// Host operations implemented by the JNI bridge (android-host/jni/bridge.c),
// which forwards each call to the Kotlin SwiftNativeHost on the UI thread.
@_silgen_name("snhost_begin_batch") func snhost_begin_batch()
@_silgen_name("snhost_end_batch") func snhost_end_batch()
@_silgen_name("snhost_create_view") func snhost_create_view(_ id: Int32, _ type: UnsafePointer<CChar>)
@_silgen_name("snhost_set_prop") func snhost_set_prop(
    _ id: Int32, _ key: UnsafePointer<CChar>, _ kind: Int32, _ value: UnsafePointer<CChar>)
@_silgen_name("snhost_remove_prop") func snhost_remove_prop(_ id: Int32, _ key: UnsafePointer<CChar>)
@_silgen_name("snhost_insert_child") func snhost_insert_child(_ parent: Int32, _ child: Int32, _ index: Int32)
@_silgen_name("snhost_remove_child") func snhost_remove_child(_ parent: Int32, _ child: Int32)
@_silgen_name("snhost_destroy_view") func snhost_destroy_view(_ id: Int32)

public final class AndroidBackend: Backend {
    public let rootHandle = 0
    public var eventSink: ((Int, String) -> Void)?

    static weak var active: AndroidBackend?

    public init() {
        AndroidBackend.active = self
    }

    public func apply(_ mutations: [Mutation]) {
        snhost_begin_batch()
        for mutation in mutations { applyOne(mutation) }
        snhost_end_batch()
    }

    private func applyOne(_ mutation: Mutation) {
        switch mutation {
        case let .createView(id, type):
            type.withCString { snhost_create_view(Int32(id), $0) }
        case let .setProp(id, key, value):
            let (kind, encoded) = encode(value)
            key.withCString { keyPtr in
                encoded.withCString { valuePtr in
                    snhost_set_prop(Int32(id), keyPtr, kind, valuePtr)
                }
            }
        case let .removeProp(id, key):
            key.withCString { snhost_remove_prop(Int32(id), $0) }
        case let .insertChild(parent, child, index):
            snhost_insert_child(Int32(parent), Int32(child), Int32(index))
        case let .removeChild(parent, child):
            snhost_remove_child(Int32(parent), Int32(child))
        case let .destroyView(id):
            snhost_destroy_view(Int32(id))
        }
    }

    /// Flatten a PropValue into (kindTag, stringPayload) for the C boundary.
    private func encode(_ value: PropValue) -> (Int32, String) {
        switch value {
        case let .string(text): return (0, text)
        case let .int(number): return (1, String(number))
        case let .double(number): return (2, String(number))
        case let .bool(flag): return (3, flag ? "true" : "false")
        case let .color(color): return (4, color.hex)
        case let .font(font): return (5, "\(font.size),\(font.weight.rawValue)")
        case let .insets(insets):
            return (6, "\(insets.top),\(insets.leading),\(insets.bottom),\(insets.trailing)")
        }
    }
}

/// Called by the JNI bridge when the Kotlin host reports a UI event.
@_cdecl("swiftnative_android_dispatch_event")
public func swiftnative_android_dispatch_event(_ id: Int32, _ event: UnsafePointer<CChar>) {
    let name = String(cString: event)
    AndroidBackend.active?.eventSink?(Int(id), name)
}

/// Entry point the JNI bridge calls once the host view tree is ready. The app
/// sets `androidRootBuilder` from its `@main` before the activity starts.
public var androidRootBuilder: (() -> AnyView)?
private var androidDriver: Driver?

@_cdecl("swiftnative_android_start")
public func swiftnative_android_start() {
    guard let builder = androidRootBuilder else { return }
    let backend = AndroidBackend()
    let driver = Driver(backend: backend) { builder() }
    androidDriver = driver
    driver.start()
}

#else

/// Placeholder so the target is non-empty on hosts without Android.
public enum AndroidBackend {}

#endif
