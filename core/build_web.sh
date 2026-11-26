#!/bin/bash
# ============================================================================
#  Compila los ejemplos a WebGL con Emscripten (usa el backend ES2 del Core).
#
#  Requisitos: Emscripten (emsdk) instalado y ACTIVADO en la shell:
#     source /ruta/a/emsdk/emsdk_env.sh    (deja emcc en el PATH)
#
#  Uso:  cd core && ./build_web.sh
#  Salida: core/web/*.html  (abrir con un server local, ver abajo)
# ============================================================================
set -e

CORE=../libs/Whisk3DCore   # el submodulo libs/Whisk3DCore de este repo
# --shell-file: HTML propio (canvas a pantalla completa, sin branding de emscripten)
# Layout del Core: graphics/ (render, texturas, video), base/ (log), io/ (archivos, pack, glTF), math/, thirdparty/ (stb).
COMMON="-DW3D_WEBGL -I$CORE -I$CORE/graphics -I$CORE/base -I$CORE/io -I$CORE/math -I$CORE/thirdparty -sUSE_SDL=2 -O2 --shell-file shell.html"
# backend de render ES2 (shaders) + math + log. El render usa el cache de texturas del Core (graphics/w3dTexture.cpp)
# aunque el ejemplo no cargue ninguna, asi que el cargador (stb, -DW3D_STB_IMPL) y la lectura de archivos van siempre.
BACKEND="$CORE/graphics/gles2/w3dGraphicsGLES2.cpp $CORE/math/Matrix4.cpp $CORE/math/Vector3.cpp $CORE/math/Quaternion.cpp $CORE/base/w3dlog.cpp"
BACKEND="$BACKEND $CORE/graphics/w3dTexture.cpp -DW3D_STB_IMPL $CORE/io/w3dFilesystem.cpp"
# assets protegidos (pack cifrado): lo usan glTF (texturas externas) y video_alpha
PACK="$CORE/io/W3dPack.cpp"

mkdir -p web

echo "compilando simple_cube (sin textura)..."
emcc simple_cube/main.cpp $BACKEND $COMMON -o web/simple_cube.html

echo "compilando textured_cube (Whisk3D_logo.png embebido)..."
emcc textured_cube/main.cpp $BACKEND $COMMON \
     --embed-file assets/Whisk3D_logo.png -o web/textured_cube.html

echo "compilando normal_map_cube (Whisk3D_logo_normal.png embebido)..."
emcc normal_map_cube/main.cpp $BACKEND $COMMON \
     --embed-file assets/Whisk3D_logo_normal.png -o web/normal_map_cube.html

# video_alpha: video con alpha (WebM) en loop sobre video de fondo (MP4), con ASSETS
# PROTEGIDOS. El navegador decodifica por HW; el modulo de video + el pack cifrado del
# Core son opcionales (-DW3D_ENABLE_VIDEO). El .w3dpack se EMBEBE (bytes ilegibles): en
# la pestania de red no queda ningun video con nombre ni URL que copiar.
echo "compilando video_alpha (assets protegidos)..."
VIDEO="$CORE/graphics/video/W3dVideo.cpp $CORE/graphics/video/W3dVideoWeb.cpp $PACK -DW3D_ENABLE_VIDEO"
EMBED=""
if [ -f video_alpha/assets.w3dpack ]; then
    EMBED="--embed-file video_alpha/assets.w3dpack@assets.w3dpack"
else
    echo "  (nota: falta video_alpha/assets.w3dpack -> empaquetalo con w3dpacker; el ejemplo compila pero no reproduce)"
fi
emcc video_alpha/main.cpp $BACKEND $VIDEO $COMMON $EMBED -o web/video_alpha.html

# animated_logo: LOGO ANIMADO con texturas en glTF/GLB, centrado sobre negro. El loader
# + renderer viven en el CORE (io/w3dGltf.h, solo cabecera).
echo "compilando animated_logo (logo animado glTF/GLB desde el Core)..."
emcc animated_logo/main.cpp $BACKEND $PACK $COMMON \
     --embed-file assets/whisk3d_logo.glb@assets/whisk3d_logo.glb \
     --embed-file assets/image_0.png@assets/image_0.png \
     -o web/animated_logo.html

echo ""
echo "LISTO -> core/web/*.html"
echo "Para verlos (WASM no corre con file://), levanta un server local:"
echo "    python -m http.server  y abri  http://localhost:8000/web/simple_cube.html"
