#!/bin/bash
# ============================================================================
#  Compila los ejemplos a WebGL con Emscripten (usa el backend ES2 del Core).
#
#  Requisitos: Emscripten (emsdk) instalado y ACTIVADO en la shell:
#     source /ruta/a/emsdk/emsdk_env.sh    (deja emcc en el PATH)
#
#  Uso:  cd examples/core && ./build_web.sh
#  Salida: examples/core/web/*.html  (abrir con un server local, ver abajo)
# ============================================================================
set -e

CORE=../libs/Whisk3DCore   # submodulo en examples/libs/
# --shell-file: HTML propio (canvas a pantalla completa, sin branding de emscripten)
# Layout del Core: headers repartidos en gfx/ (render+texturas), base/ (log), io/ (pack+glTF), thirdparty/ (stb).
COMMON="-DW3D_WEBGL -I$CORE -I$CORE/gfx -I$CORE/base -I$CORE/io -I$CORE/thirdparty -sUSE_SDL=2 -O2 --shell-file shell.html"
# backend de render ES2 (shaders) + math
BACKEND="$CORE/gles2/w3dGraphicsGLES2.cpp $CORE/math/Matrix4.cpp $CORE/math/Vector3.cpp $CORE/math/Quaternion.cpp $CORE/base/w3dlog.cpp"
# loader de texturas del Core (stb): la implementacion stb se compila aca (-DW3D_STB_IMPL).
# w3dTexture lee archivos via w3dFileSystem -> hay que linkear tambien io/w3dFilesystem.cpp.
TEX="$CORE/gfx/w3dTexture.cpp -DW3D_STB_IMPL $CORE/io/w3dFilesystem.cpp"
# assets protegidos (pack cifrado) — lo usan glTF (texturas externas) y video_alpha
PACK="$CORE/io/W3dPack.cpp"

mkdir -p web

echo "compilando simple_cube (sin textura)..."
emcc simple_cube/main.cpp $BACKEND $COMMON -o web/simple_cube.html

echo "compilando textured_cube (Whisk3D_logo.png embebido)..."
emcc textured_cube/main.cpp $BACKEND $TEX $COMMON \
     --embed-file assets/Whisk3D_logo.png -o web/textured_cube.html

echo "compilando normal_map_cube (Whisk3D_logo_normal.png embebido)..."
emcc normal_map_cube/main.cpp $BACKEND $TEX $COMMON \
     --embed-file assets/Whisk3D_logo_normal.png -o web/normal_map_cube.html

# video_alpha: video con alpha (WebM) en loop sobre video de fondo (MP4), con ASSETS
# PROTEGIDOS. El navegador decodifica por HW; el modulo de video + el pack cifrado del
# Core son opcionales (-DW3D_ENABLE_VIDEO). El .w3dpack se EMBEBE (bytes ilegibles): en
# la pestania de red no queda ningun video con nombre ni URL que copiar.
if [ -f "$CORE/video/W3dVideo.cpp" ]; then
    echo "compilando video_alpha (assets protegidos)..."
    VIDEO="$CORE/video/W3dVideo.cpp $CORE/video/W3dVideoWeb.cpp $CORE/io/W3dPack.cpp -DW3D_ENABLE_VIDEO"
    EMBED=""
    if [ -f video_alpha/assets.w3dpack ]; then
        EMBED="--embed-file video_alpha/assets.w3dpack@assets.w3dpack"
    else
        echo "  (nota: falta video_alpha/assets.w3dpack -> empaquetalo con w3dpacker; el ejemplo compila pero no reproduce)"
    fi
    emcc video_alpha/main.cpp $BACKEND $VIDEO $COMMON $EMBED -o web/video_alpha.html
else
    echo "(salteando video_alpha: el submodulo Core todavia no trae video/ — falta bumpear el puntero)"
fi

# animated_logo: LOGO ANIMADO con texturas en glTF/GLB, centrado sobre negro. El loader
# + renderer viven en el CORE (io/w3dGltf.h). Necesita el Core NUEVO (layout base/gfx/io/):
# si el submodulo todavia es viejo (sin io/w3dGltf.h) se saltea, como video_alpha.
if [ -f "$CORE/io/w3dGltf.h" ]; then
    echo "compilando animated_logo (logo animado glTF/GLB desde el Core)..."
    emcc animated_logo/main.cpp $BACKEND $TEX $PACK $COMMON \
         --embed-file assets/whisk3d_logo.glb@assets/whisk3d_logo.glb \
         --embed-file assets/image_0.png@assets/image_0.png \
         -o web/animated_logo.html
else
    echo "(salteando animated_logo: el submodulo Core todavia no trae io/w3dGltf.h — falta bumpear el puntero)"
fi

echo ""
echo "LISTO -> examples/core/web/*.html"
echo "Para verlos (WASM no corre con file://), levanta un server local:"
echo "    python -m http.server  y abri  http://localhost:8000/web/simple_cube.html"
