#!/usr/bin/env bash
# ============================================================================
#  build_android.sh - arma el APK de la Calculadora (ejemplo Whisk3D).
#    ndk-build (jni/Android.mk, contra el SDL2 del submodulo) -> libmain.so
#    -> jniLibs -> gradlew assembleDebug -> APK firmado con el keystore de debug.
#  Los assets (calculadora.w3dui + calculadora.lua + font.png) se copian al APK en cada build.
#
#  Requiere: ANDROID_NDK, y el SDK en local.properties (sdk.dir).
#  Uso:  bash build_android.sh [abi ...]
#        sin argumentos -> APK fat con las dos ABIs (armeabi-v7a + arm64-v8a).
#        con argumento(s) -> solo esa(s)  (ej: bash build_android.sh arm64-v8a).
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")"
ANDROID_DIR="$(pwd)"                          # ui/calculadora/platform/android
CALCULADORA="$(cd ../.. && pwd)"              # ui/calculadora (main.cpp, calculadora.lua, calculadora.w3dui)
W3D="$(cd ../../../../../Whisk3D && pwd)"     # repo Whisk3D (SDL2 + res/)

ANDROID_NDK="${ANDROID_NDK:-/opt/android-ndk}"
NDK_BUILD="$ANDROID_NDK/ndk-build"
[ -x "$NDK_BUILD" ] || { echo "ERROR: ndk-build no encontrado en '$NDK_BUILD' (exporta ANDROID_NDK)"; exit 1; }

# ABIs a compilar: sin argumentos -> las dos (APK fat 32+64); con argumento(s) -> solo esas.
if [ "$#" -ge 1 ]; then
    ABIS=("$@")
else
    ABIS=(armeabi-v7a arm64-v8a)
fi

# assets del APK: la escena + su script + la tipografia pixel. Gitignoreado (se regenera en cada build).
ASSETS="$ANDROID_DIR/app/src/main/assets"
mkdir -p "$ASSETS"
cp "$CALCULADORA/calculadora.w3dui"   "$ASSETS/calculadora.w3dui"
cp "$CALCULADORA/calculadora.lua"     "$ASSETS/calculadora.lua"
cp "$W3D/res/Skins/Whisk3D/font.png"  "$ASSETS/font.png"

# jniLibs se regenera limpio: el APK trae EXACTAMENTE las ABIs pedidas (sin sobras
# de builds previos con otra ABI).
rm -rf "$ANDROID_DIR/app/src/main/jniLibs"

for ABI in "${ABIS[@]}"; do
    echo "[BUILD] nativo ($ABI)"
    # APP_ABI="$ABI" pisa el APP_ABI del Application.mk -> se compila esta ABI sola por vuelta.
    "$NDK_BUILD" -j"$(nproc)" \
        APP_ABI="$ABI" \
        NDK_PROJECT_PATH="$ANDROID_DIR" \
        APP_BUILD_SCRIPT="$ANDROID_DIR/jni/Android.mk" \
        NDK_APPLICATION_MK="$ANDROID_DIR/jni/Application.mk"

    # las .so compiladas -> jniLibs (lo que empaqueta gradle en el APK)
    JNILIBS="$ANDROID_DIR/app/src/main/jniLibs/$ABI"
    mkdir -p "$JNILIBS"
    cp "$ANDROID_DIR/libs/$ABI"/*.so "$JNILIBS"/
done

echo "Empaquetando con gradlew..."
./gradlew assembleDebug

APK=$(find "$ANDROID_DIR" -path '*/outputs/apk/debug/whisk3d-calculadora-*-Android.apk' 2>/dev/null | head -1)
echo "APK -> ${APK:-(revisar app/.../outputs/apk/debug/)}"
