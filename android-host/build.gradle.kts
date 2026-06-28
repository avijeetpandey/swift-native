plugins {
    id("com.android.application")
    kotlin("android")
}

android {
    namespace = "dev.swiftnative.host"
    compileSdk = 34

    defaultConfig {
        applicationId = "dev.swiftnative.host"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"
        ndk {
            // Match the Swift Android SDK targets you cross-compile for.
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("jni/CMakeLists.txt")
        }
    }

    // Prebuilt native libraries: libapp.so (the Swift core) plus the Swift
    // runtime .so files copied from the Swift Android SDK sysroot.
    sourceSets["main"].jniLibs.srcDirs("src/main/jniLibs")

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}
