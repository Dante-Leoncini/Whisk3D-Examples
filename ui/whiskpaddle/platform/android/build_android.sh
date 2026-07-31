#!/usr/bin/env bash
# ============================================================================
#  build_android.sh - arma el APK del WhiskPaddle (demo Whisk3D).
#    ndk-build (jni/Android.mk, contra el SDL2 del submodulo) -> libmain.so
#    -> jniLibs -> gradlew assembleDebug -> APK firmado con el keystore de debug.
#  Los assets (las 3 escenas .w3dui + sus .lua + font.png) se copian al APK en cada build.
#
#  Requiere: ANDROID_NDK, y el SDK en local.properties (sdk.dir).
#  Uso:  bash build_android.sh [abi ...]
#        sin argumentos -> APK fat con las dos ABIs (armeabi-v7a + arm64-v8a).
#        con argumento(s) -> solo esa(s)  (ej: bash build_android.sh arm64-v8a).
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")"
ANDROID_DIR="$(pwd)"                          # ui/whiskpaddle/platform/android
WHISKPADDLE="$(cd ../.. && pwd)"                      # ui/whiskpaddle (main.cpp, whiskpaddle.lua, whiskpaddle.w3dui)
W3D="$(cd ../../../../../Whisk3D && pwd)"       # repo Whisk3D (SDL2 + res/)

ANDROID_NDK="${ANDROID_NDK:-/opt/android-ndk}"
NDK_BUILD="$ANDROID_NDK/ndk-build"
[ -x "$NDK_BUILD" ] || { echo "ERROR: ndk-build no encontrado en '$NDK_BUILD' (exporta ANDROID_NDK)"; exit 1; }

# ABIs a compilar: sin argumentos -> las dos (APK fat 32+64); con argumento(s) -> solo esas.
if [ "$#" -ge 1 ]; then
    ABIS=("$@")
else
    ABIS=(armeabi-v7a arm64-v8a)
fi

# assets del APK: el juego + la tipografia pixel. Gitignoreado (se regenera en cada build).
# MULTI-ESCENA: las 3 escenas (.w3dui) + sus scripts (.lua) + sonidos.lua (comun a las 3).
ASSETS="$ANDROID_DIR/app/src/main/assets"
mkdir -p "$ASSETS"
cp "$WHISKPADDLE/menu.w3dui"                  "$ASSETS/menu.w3dui"
cp "$WHISKPADDLE/dificultad.w3dui"            "$ASSETS/dificultad.w3dui"
cp "$WHISKPADDLE/juego.w3dui"                 "$ASSETS/juego.w3dui"
cp "$WHISKPADDLE/menu.lua"                    "$ASSETS/menu.lua"
cp "$WHISKPADDLE/dificultad.lua"              "$ASSETS/dificultad.lua"
cp "$WHISKPADDLE/juego.lua"                   "$ASSETS/juego.lua"
cp "$WHISKPADDLE/sonidos.lua"                 "$ASSETS/sonidos.lua"
# la carpeta assets/ del juego va CON su subdirectorio (queda assets/assets/ en el
# APK): el loader en Android resuelve "assets/xxx.png" tal cual contra el asset root.
rm -rf "$ASSETS/assets"
mkdir -p "$ASSETS/assets"
cp -r "$WHISKPADDLE/assets/." "$ASSETS/assets/"
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

APK=$(find "$ANDROID_DIR" -path '*/outputs/apk/debug/whisk3d-whiskpaddle-*-Android.apk' 2>/dev/null | head -1)
echo "APK -> ${APK:-(revisar app/.../outputs/apk/debug/)}"
