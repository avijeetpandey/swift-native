package dev.swiftnative.host

import android.content.Context
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView

// Applies the Swift core's mutation batch to REAL android.view.View objects.
// Every method here is invoked from the C bridge (jni/bridge.c), which the Swift
// `AndroidBackend` calls over the C ABI. Events flow back via NativeBridge.dispatchEvent.
class SwiftNativeHost(private val context: Context, root: ViewGroup) {

    companion object {
        // The active host, used by the C bridge to route snhost_* calls.
        @JvmStatic var shared: SwiftNativeHost? = null
    }

    private val views = HashMap<Int, View>()

    init {
        views[0] = root // handle 0 is the root container
    }

    fun createView(id: Int, type: String) {
        val view: View = when (type) {
            "Text" -> TextView(context)
            "Button" -> Button(context).apply {
                isAllCaps = false
                setOnClickListener { NativeBridge.dispatchEvent(id, "tap") }
            }
            "Toggle" -> Switch(context).apply {
                setOnClickListener { NativeBridge.dispatchEvent(id, "toggle") }
            }
            "VStack" -> LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
            }
            "HStack" -> LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }
            "ScrollView" -> ScrollView(context).apply {
                addView(LinearLayout(context).apply { orientation = LinearLayout.VERTICAL })
            }
            "ZStack" -> FrameLayout(context)
            "Divider" -> View(context).apply {
                setBackgroundColor(0xFFCCCCCC.toInt())
                minimumHeight = 2
            }
            "Spacer" -> View(context)
            else -> View(context)
        }
        views[id] = view
    }

    fun setProp(id: Int, key: String, kind: Int, value: String) {
        val view = views[id] ?: return
        when (key) {
            "text" -> (view as? TextView)?.text = value
            "title" -> {
                (view as? Button)?.text = value
                (view as? Switch)?.text = value
            }
            "on" -> (view as? Switch)?.isChecked = (value == "true")
            "foregroundColor" -> (view as? TextView)?.setTextColor(parseColor(value))
            "background" -> view.setBackgroundColor(parseColor(value))
            "font" -> {
                val size = value.substringBefore(",").toFloatOrNull() ?: return
                (view as? TextView)?.textSize = size
            }
            "spacing" -> { /* LinearLayout spacing handled via child margins */ }
            "padding" -> {
                val parts = value.split(",").mapNotNull { it.toFloatOrNull() }
                if (parts.size == 4) {
                    val (t, l, b, r) = parts
                    view.setPadding(l.toInt(), t.toInt(), r.toInt(), b.toInt())
                }
            }
        }
    }

    fun removeProp(id: Int, key: String) {
        val view = views[id] ?: return
        when (key) {
            "text" -> (view as? TextView)?.text = ""
            "title" -> (view as? Button)?.text = ""
        }
    }

    fun insertChild(parent: Int, child: Int, index: Int) {
        // A ScrollView hosts a single inner LinearLayout that holds the children.
        val parentView = (views[parent] as? ScrollView)?.getChildAt(0) as? ViewGroup
            ?: views[parent] as? ViewGroup ?: return
        val childView = views[child] ?: return
        val clamped = minOf(index, parentView.childCount)
        parentView.addView(childView, clamped)
    }

    fun removeChild(parent: Int, child: Int) {
        val parentView = views[parent] as? ViewGroup ?: return
        val childView = views[child] ?: return
        parentView.removeView(childView)
    }

    fun destroyView(id: Int) {
        views.remove(id)
    }

    private fun parseColor(hex: String): Int {
        // Accept #RRGGBB / #RRGGBBAA.
        val clean = hex.removePrefix("#")
        return when (clean.length) {
            6 -> (0xFF000000.toInt()) or clean.toInt(16)
            8 -> {
                val rgba = clean.toLong(16)
                val a = (rgba and 0xFF).toInt()
                val rgb = (rgba shr 8).toInt() and 0xFFFFFF
                (a shl 24) or rgb
            }
            else -> 0xFF000000.toInt()
        }
    }
}
