# APK fat: 32 bits (armeabi-v7a, moviles viejos) + 64 bits (arm64-v8a, casi todos los
# Android actuales). build_android.sh sin argumento compila las dos; con un argumento
# (ej. 'arm64-v8a') pisa este APP_ABI y compila solo esa. Para sumar x86_64 agregarla
# aca y en abiFilters de app/build.gradle.
APP_ABI := armeabi-v7a arm64-v8a
APP_PLATFORM := android-21
APP_STL := c++_shared
