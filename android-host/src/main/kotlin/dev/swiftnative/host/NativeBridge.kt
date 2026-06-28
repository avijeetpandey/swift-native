package dev.swiftnative.host

// Declarations of the native methods implemented by libbridge.so (jni/bridge.c).
//   - registerHost: cache the host + method IDs in C
//   - start:        call swiftnative_android_start() in the Swift core
//   - dispatchEvent: forward a UI event to swiftnative_android_dispatch_event()
object NativeBridge {
    external fun registerHost(host: SwiftNativeHost)
    external fun start()
    external fun dispatchEvent(id: Int, event: String)
}
