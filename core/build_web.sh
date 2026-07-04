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
COMMON="-DW3D_WEBGL -I$CORE -sUSE_SDL=2 -O2 --shell-file shell.html"
# backend de render ES2 (shaders) + math
BACKEND="$CORE/gles2/w3dGraphicsGLES2.cpp $CORE/math/Matrix4.cpp $CORE/math/Vector3.cpp $CORE/w3dlog.cpp"
# loader de texturas del Core (stb): -I a stb + compila la implementacion aca
TEX="$CORE/w3dTexture.cpp -DW3D_STB_IMPL -I$CORE/thirdparty"

mkdir -p web

echo "compilando simple_cube (sin textura)..."
emcc simple_cube/main.cpp $BACKEND $COMMON -o web/simple_cube.html

echo "compilando textured_cube (Whisk3D_logo.png embebido)..."
emcc textured_cube/main.cpp $BACKEND $TEX $COMMON \
     --embed-file assets/Whisk3D_logo.png -o web/textured_cube.html

echo "compilando normal_map_cube (Whisk3D_logo_normal.png embebido)..."
emcc normal_map_cube/main.cpp $BACKEND $TEX $COMMON \
     --embed-file assets/Whisk3D_logo_normal.png -o web/normal_map_cube.html

echo ""
echo "LISTO -> examples/core/web/*.html"
echo "Para verlos (WASM no corre con file://), levanta un server local:"
echo "    python -m http.server  y abri  http://localhost:8000/web/simple_cube.html"
