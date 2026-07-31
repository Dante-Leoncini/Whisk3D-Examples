#!/usr/bin/env bash
# ============================================================================
#  build_android.sh - arma el APK de la Consola (ejemplo Whisk3D).
#    ndk-build (jni/Android.mk, contra el SDL2 del submodulo) -> libmain.so
#    -> jniLibs -> gradlew assembleDebug -> APK firmado con el keystore de debug.
#  Los assets (consola.w3dui + consola.lua + font.png) se copian al APK en cada build.
#
#  Requiere: ANDROID_NDK, y el SDK en local.properties (sdk.dir).
#  Uso:  bash build_android.sh [abi ...]
#        sin argumentos -> APK fat con las dos ABIs (armeabi-v7a + arm64-v8a).
#        con argumento(s) -> solo esa(s)  (ej: bash build_android.sh arm64-v8a).
#
#  MODO DEBUG (el punto didactico del ejemplo): por defecto compila DEBUG
#  (W3D_DEV_LOG=1: logcat + ring + depurar() + boton DEPURAR visible). Para el
#  APK de PRODUCCION (W3D_DEV_LOG=0, sin nada de eso):
#      MODO=prod bash build_android.sh
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")"
ANDROID_DIR="$(pwd)"                          # ui/consola/platform/android
CONSOLA="$(cd ../.. && pwd)"              # ui/consola (main.cpp, consola.lua, consola.w3dui)
W3D="$(cd ../../../../../Whisk3D && pwd)"     # repo Whisk3D (SDL2 + res/)

# modo debug|prod -> valor de la macro W3D_DEV_LOG (ver base/w3dlog.h). Se pasa a
# ndk-build por linea de comando (pisa el default del Android.mk). Al cambiar de
# modo hay que recompilar limpio: ndk-build no detecta el cambio de flags solo.
MODO="${MODO:-debug}"
if [ "$MODO" = "prod" ]; then DBG=0; else DBG=1; fi
echo "modo: $MODO (W3D_DEV_LOG=$DBG)"
MODO_PREVIO=""
[ -f "$ANDROID_DIR/obj/.modo" ] && MODO_PREVIO="$(cat "$ANDROID_DIR/obj/.modo")"
if [ "$MODO_PREVIO" != "$MODO" ]; then
    rm -rf "$ANDROID_DIR/obj" "$ANDROID_DIR/libs"
fi

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
cp "$CONSOLA/consola.w3dui"   "$ASSETS/consola.w3dui"
cp "$CONSOLA/consola.lua"     "$ASSETS/consola.lua"
cp "$W3D/res/Skins/Whisk3D/font.png"  "$ASSETS/font.png"

# jniLibs se regenera limpio: el APK trae EXACTAMENTE las ABIs pedidas (sin sobras
# de builds previos con otra ABI).
rm -rf "$ANDROID_DIR/app/src/main/jniLibs"

for ABI in "${ABIS[@]}"; do
    echo "[BUILD] nativo ($ABI, modo $MODO)"
    # APP_ABI="$ABI" pisa el APP_ABI del Application.mk -> se compila esta ABI sola por vuelta.
    # W3D_DEV_LOG=$DBG pisa el default del Android.mk (1 = debug, 0 = produccion).
    "$NDK_BUILD" -j"$(nproc)" \
        APP_ABI="$ABI" \
        W3D_DEV_LOG="$DBG" \
        NDK_PROJECT_PATH="$ANDROID_DIR" \
        APP_BUILD_SCRIPT="$ANDROID_DIR/jni/Android.mk" \
        NDK_APPLICATION_MK="$ANDROID_DIR/jni/Application.mk"

    # las .so compiladas -> jniLibs (lo que empaqueta gradle en el APK)
    JNILIBS="$ANDROID_DIR/app/src/main/jniLibs/$ABI"
    mkdir -p "$JNILIBS"
    cp "$ANDROID_DIR/libs/$ABI"/*.so "$JNILIBS"/
done

# recordar con que modo se compilo (para limpiar solo cuando cambia)
mkdir -p "$ANDROID_DIR/obj" && echo "$MODO" > "$ANDROID_DIR/obj/.modo"

echo "Empaquetando con gradlew..."
./gradlew assembleDebug

APK=$(find "$ANDROID_DIR" -path '*/outputs/apk/debug/whisk3d-consola-*-Android.apk' 2>/dev/null | head -1)
echo "APK -> ${APK:-(revisar app/.../outputs/apk/debug/)}"
