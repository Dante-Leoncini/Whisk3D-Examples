#!/bin/bash
# ============================================================================
#  Compila la CONSOLA a WebGL con Emscripten — el MISMO consola.w3dui +
#  consola.lua que se abren en el editor, corriendo en el navegador sin el editor.
#
#  Requisitos: Emscripten (emsdk) activado en la shell:
#     source /ruta/a/emsdk/emsdk_env.sh
#
#  Uso:  bash platform/web/build_web.sh
#  Salida: ui/consola/platform/web/build/consola.html
#  Para verlo (WASM no corre con file://): python -m http.server -> localhost:8000
# ============================================================================
set -e

# este script vive en ui/consola/platform/web/ ; el codigo (main.cpp, consola.lua, consola.w3dui)
# esta 2 niveles arriba (raiz del ejemplo). Nos paramos ahi para que las rutas relativas no cambien;
# la SALIDA va DENTRO de platform/web/build (build prolijo, adentro de su carpeta de plataforma).
SELF="$(cd "$(dirname "$0")" && pwd)"
cd "$SELF/../.."

W3D=../../../Whisk3D          # repo del editor (Core + UI 2D + lua)
CORE=$W3D/libs/Whisk3DCore
UILIB=$W3D/libs/WhiskUI
GAME=../../game
LUA=$W3D/thirdparty/lua/src

# el interprete lua (C plano); sin el REPL ni luac
LUA_SRC=$(ls $LUA/*.c | grep -vE '/lua\.c|/luac\.c')

# MODO DEBUG del ejemplo: default DEBUG (W3D_DEV_LOG=1: log + ring + depurar()).
# Con  MODO=prod bash build_web.sh  (o: bash build_web.sh prod) compila PRODUCCION
# (W3D_DEV_LOG=0: sin log ni ring; el panel avisa "consola apagada").
MODO="${MODO:-${1:-debug}}"
if [ "$MODO" = "prod" ]; then DBG=0; else DBG=1; fi
echo "modo: $MODO (W3D_DEV_LOG=$DBG)"

# defines: WebGL + runtime del juego + backend shaders GLES2 + stb + consola sin texturas.
# W3D_SIN_FISICA: la consola no usa velocidad/rebotes (binds stub, build mas liviano).
# Sin W3D_ENABLE_AUDIO: tampoco suena (W3dAudio.cpp queda como dispatcher stub).
DEF="-DW3D_WEBGL -DW3D_GLES2 -DW3D_GAME_RUNTIME -DW3D_GAME_NO_TEX -DW3D_STB_IMPL -DLUA_USE_C89 -DW3D_SIN_FISICA -DW3D_DEV_LOG=$DBG"

# include dirs (el mismo layout que el CMake de Linux)
INC="-I$GAME -I$W3D -I$W3D/libs -I$W3D/main -I$W3D/main/render -I$W3D/main/io \
     -I$CORE -I$CORE/base -I$CORE/gfx -I$CORE/io -I$CORE/math -I$CORE/objects \
     -I$CORE/script -I$CORE/animation -I$CORE/thirdparty \
     -I$UILIB -I$UILIB/text -I$UILIB/draw -I$UILIB/core -I$UILIB/theme -I$UILIB/widgets \
     -I$LUA"

# Core (engine con backend GLES2 shaders) + escena + animacion + lua
CORESRC="$CORE/gles2/w3dGraphicsGLES2.cpp $CORE/gfx/w3dTexture.cpp \
    $CORE/io/w3dFilesystem.cpp $CORE/io/w3dCompress.cpp \
    $CORE/base/w3dlog.cpp $CORE/base/W3dInteractionState.cpp $CORE/base/W3dConfig.cpp \
    $CORE/math/Vector3.cpp $CORE/math/Quaternion.cpp $CORE/math/Matrix4.cpp \
    $CORE/objects/Objects.cpp $CORE/objects/Mesh.cpp $CORE/objects/Light.cpp \
    $CORE/objects/Materials.cpp $CORE/objects/Textures.cpp $CORE/objects/CameraBase.cpp \
    $CORE/objects/Armature.cpp $CORE/objects/RenderColors.cpp \
    $CORE/animation/Animation.cpp $CORE/animation/VertexAnimation.cpp \
    $CORE/animation/SkeletalAnimation.cpp $CORE/script/W3dScript.cpp \
    $CORE/audio/W3dAudio.cpp"
# sin physics/W3dFisica.cpp (W3D_SIN_FISICA) ni audio/W3dAudioSDL.cpp (sin
# W3D_ENABLE_AUDIO); W3dAudio.cpp va igual: es el stub que hace linkear a beep()

# WhiskUI (tipografia pixel + dibujo)
UISRC="$UILIB/text/W3dFont.cpp $UILIB/text/bitmapText.cpp $UILIB/text/font.cpp \
    $UILIB/draw/glesdraw.cpp $UILIB/draw/W3dAtlasPacker.cpp \
    $UILIB/core/UI.cpp $UILIB/theme/colores.cpp"

# UI 2D del editor (render + parser + fuente), reusada tal cual
UI2D="$W3D/main/render/UIOverlay.cpp $W3D/main/script/BindsJuego.cpp $W3D/main/W3dEscena.cpp $W3D/main/io/UI2DFormato.cpp $W3D/main/io/Fuente2D.cpp $W3D/main/io/Textura2D.cpp"

OUT="$SELF/build"        # salida DENTRO de platform/web/build
mkdir -p "$OUT"

echo "compilando la consola a WebGL..."
# UNA escena (.w3dui) + su script (.lua) + la tipografia pixel.
emcc main.cpp $GAME/w3drun.cpp $CORESRC $UISRC $UI2D $LUA_SRC \
     $DEF $INC -sUSE_SDL=2 -O2 \
     --embed-file consola.w3dui@consola.w3dui \
     --embed-file consola.lua@consola.lua \
     --embed-file $W3D/res/Skins/Whisk3D/font.png@font.png \
     --shell-file ../../core/shell.html \
     -o "$OUT/consola.html"

echo ""
echo "LISTO -> ui/consola/platform/web/build/consola.html"
echo "Para verlo:  python -m http.server --directory platform/web/build   y abri  http://localhost:8000/consola.html"
