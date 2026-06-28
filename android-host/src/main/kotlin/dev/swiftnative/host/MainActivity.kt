package dev.swiftnative.host

import android.app.Activity
import android.os.Bundle
import android.widget.FrameLayout

// The Android entry point. It builds the root container (handle 0), hands it to
// the SwiftNativeHost, then asks the native Swift core to start rendering. The
// Swift core then drives real Android views through the JNI bridge.
class MainActivity : Activity() {
    private lateinit var host: SwiftNativeHost

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = FrameLayout(this)
        setContentView(root)

        host = SwiftNativeHost(this, root)
        SwiftNativeHost.shared = host

        // Load native libraries: libapp.so (your Swift app) + libbridge.so (JNI).
        System.loadLibrary("bridge")

        // Register this host with the C bridge, then start the Swift render loop.
        NativeBridge.registerHost(host)
        NativeBridge.start()
    }
}
