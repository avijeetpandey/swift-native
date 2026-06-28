// bridge.c — the thin JNI layer between the native Swift core and the Kotlin
// host. Two directions:
//
//   1. Kotlin -> Swift:  Java_..._start / _dispatchEvent call the Swift @_cdecl
//                        entry points (swiftnative_android_start, ...).
//   2. Swift -> Kotlin:  snhost_* C functions (called by AndroidBackend) invoke
//                        SwiftNativeHost methods through cached jmethodIDs.
//
// This file is built into libbridge.so by CMake (see CMakeLists.txt) using the
// Android NDK. It is NOT compiled on the host; it requires the Android toolchain.

#include <jni.h>
#include <string.h>

// Swift @_cdecl entry points exported by libapp.so (the cross-compiled core).
extern void swiftnative_android_start(void);
extern void swiftnative_android_dispatch_event(int id, const char *event);

static JavaVM *g_vm = NULL;
static jobject g_host = NULL;            // global ref to the SwiftNativeHost
static jclass  g_hostClass = NULL;
static jmethodID m_createView, m_setProp, m_removeProp,
                 m_insertChild, m_removeChild, m_destroyView;

jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    g_vm = vm;
    return JNI_VERSION_1_6;
}

static JNIEnv *env(void) {
    JNIEnv *e = NULL;
    (*g_vm)->AttachCurrentThread(g_vm, &e, NULL);
    return e;
}

// ---- Kotlin -> Swift -------------------------------------------------------

JNIEXPORT void JNICALL
Java_dev_swiftnative_host_NativeBridge_registerHost(JNIEnv *e, jobject thiz, jobject host) {
    g_host = (*e)->NewGlobalRef(e, host);
    jclass cls = (*e)->GetObjectClass(e, host);
    g_hostClass = (jclass)(*e)->NewGlobalRef(e, cls);
    m_createView  = (*e)->GetMethodID(e, cls, "createView",  "(ILjava/lang/String;)V");
    m_setProp     = (*e)->GetMethodID(e, cls, "setProp",     "(ILjava/lang/String;ILjava/lang/String;)V");
    m_removeProp  = (*e)->GetMethodID(e, cls, "removeProp",  "(ILjava/lang/String;)V");
    m_insertChild = (*e)->GetMethodID(e, cls, "insertChild", "(III)V");
    m_removeChild = (*e)->GetMethodID(e, cls, "removeChild", "(II)V");
    m_destroyView = (*e)->GetMethodID(e, cls, "destroyView", "(I)V");
}

JNIEXPORT void JNICALL
Java_dev_swiftnative_host_NativeBridge_start(JNIEnv *e, jobject thiz) {
    swiftnative_android_start();
}

JNIEXPORT void JNICALL
Java_dev_swiftnative_host_NativeBridge_dispatchEvent(JNIEnv *e, jobject thiz, jint id, jstring event) {
    const char *cstr = (*e)->GetStringUTFChars(e, event, NULL);
    swiftnative_android_dispatch_event((int)id, cstr);
    (*e)->ReleaseStringUTFChars(e, event, cstr);
}

// ---- Swift -> Kotlin (snhost_* called by AndroidBackend) -------------------

void snhost_begin_batch(void) { /* could post to UI thread / pause layout */ }
void snhost_end_batch(void)   { /* request layout pass on the root */ }

void snhost_create_view(int id, const char *type) {
    JNIEnv *e = env();
    jstring jtype = (*e)->NewStringUTF(e, type);
    (*e)->CallVoidMethod(e, g_host, m_createView, id, jtype);
    (*e)->DeleteLocalRef(e, jtype);
}

void snhost_set_prop(int id, const char *key, int kind, const char *value) {
    JNIEnv *e = env();
    jstring jkey = (*e)->NewStringUTF(e, key);
    jstring jval = (*e)->NewStringUTF(e, value);
    (*e)->CallVoidMethod(e, g_host, m_setProp, id, jkey, kind, jval);
    (*e)->DeleteLocalRef(e, jkey);
    (*e)->DeleteLocalRef(e, jval);
}

void snhost_remove_prop(int id, const char *key) {
    JNIEnv *e = env();
    jstring jkey = (*e)->NewStringUTF(e, key);
    (*e)->CallVoidMethod(e, g_host, m_removeProp, id, jkey);
    (*e)->DeleteLocalRef(e, jkey);
}

void snhost_insert_child(int parent, int child, int index) {
    (*env())->CallVoidMethod(env(), g_host, m_insertChild, parent, child, index);
}

void snhost_remove_child(int parent, int child) {
    (*env())->CallVoidMethod(env(), g_host, m_removeChild, parent, child);
}

void snhost_destroy_view(int id) {
    (*env())->CallVoidMethod(env(), g_host, m_destroyView, id);
}
