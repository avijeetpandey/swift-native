cmake_minimum_required(VERSION 3.22)
project(bridge C)

# The JNI glue library. It links against libapp.so — the Swift Native core
# cross-compiled by `swift build --swift-sdk aarch64-unknown-linux-android24`
# and dropped into src/main/jniLibs/<abi>/ alongside the Swift runtime .so files.
add_library(bridge SHARED bridge.c)

find_library(log-lib log)

add_library(app SHARED IMPORTED)
set_target_properties(app PROPERTIES
    IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../src/main/jniLibs/${ANDROID_ABI}/libapp.so)

target_link_libraries(bridge ${log-lib} app)
