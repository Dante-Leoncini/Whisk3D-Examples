#!/bin/bash
# ============================================================================
#  Compila el PONG a WebGL con Emscripten — el MISMO pong.w3dui + pong.lua que
#  se abren en el editor, corriendo en el navegador sin el editor.
#
#  Requisitos: Emscripten (emsdk) activado en la shell:
#     source /ruta/a/emsdk/emsdk_env.sh
#
#  Uso:  cd examples/ui/pong && ./build_web.sh
#  Salida: examples/ui/pong/web/pong.html
#  Para verlo (WASM no corre con file://): python -m http.server -> localhost:8000
# ============================================================================
set -e

W3D=../../../Whisk3D          # repo del editor (Core + UI 2D + lua)
CORE=$W3D/libs/Whisk3DCore
UILIB=$W3D/libs/WhiskUI
GAME=../../game
LUA=$W3D/thirdparty/lua/src

# el interprete lua (C plano); sin el REPL ni luac
LUA_SRC=$(ls $LUA/*.c | grep -vE '/lua\.c|/luac\.c')

# defines: WebGL + runtime del juego + backend shaders GLES2 + stb + pong sin texturas
DEF="-DW3D_WEBGL -DW3D_GLES2 -DW3D_GAME_RUNTIME -DW3D_GAME_NO_TEX -DW3D_STB_IMPL -DLUA_USE_C89 -DW3D_ENABLE_AUDIO"

# include dirs (el mismo layout que el CMake de Linux)
INC="-I$GAME -I$W3D -I$W3D/libs -I$W3D/main -I$W3D/main/render -I$W3D/main/io \
     -I$CORE -I$CORE/base -I$CORE/gfx -I$CORE/io -I$CORE/math -I$CORE/objects \
     -I$CORE/script -I$CORE/animation -I$CORE/thirdparty \
     -I$UILIB -I$UILIB/text -I$UILIB/draw -I$UILIB/core -I$UILIB/theme -I$UILIB/widgets \
     -I$LUA"

# Core (engine con backend GLES2 shaders) + escena + animacion + lua
CORESRC="$CORE/gles2/w3dGraphicsGLES2.cpp $CORE/gfx/w3dTexture.cpp \
    $CORE/io/w3dFilesystem.cpp $CORE/io/w3dCompress.cpp \
    $CORE/base/w3dlog.cpp $CORE/base/W3dInteractionState.cpp \
    $CORE/math/Vector3.cpp $CORE/math/Quaternion.cpp $CORE/math/Matrix4.cpp \
    $CORE/objects/Objects.cpp $CORE/objects/Mesh.cpp $CORE/objects/Light.cpp \
    $CORE/objects/Materials.cpp $CORE/objects/Textures.cpp $CORE/objects/CameraBase.cpp \
    $CORE/objects/Armature.cpp $CORE/objects/RenderColors.cpp \
    $CORE/animation/Animation.cpp $CORE/animation/VertexAnimation.cpp \
    $CORE/animation/SkeletalAnimation.cpp $CORE/script/W3dScript.cpp \
    $CORE/audio/W3dAudio.cpp $CORE/audio/W3dAudioSDL.cpp"

# WhiskUI (tipografia pixel + dibujo)
UISRC="$UILIB/text/W3dFont.cpp $UILIB/text/bitmapText.cpp $UILIB/text/font.cpp \
    $UILIB/draw/glesdraw.cpp $UILIB/draw/W3dAtlasPacker.cpp \
    $UILIB/core/UI.cpp $UILIB/theme/colores.cpp"

# UI 2D del editor (render + parser + fuente), reusada tal cual
UI2D="$W3D/main/render/UIOverlay.cpp $W3D/main/io/UI2DFormato.cpp $W3D/main/io/Fuente2D.cpp"

mkdir -p web

echo "compilando pong a WebGL..."
emcc main.cpp $GAME/w3drun.cpp $CORESRC $UISRC $UI2D $LUA_SRC \
     $DEF $INC -sUSE_SDL=2 -O2 \
     --embed-file pong.w3dui@pong.w3dui \
     --embed-file pong.lua@pong.lua \
     --embed-file $W3D/res/Skins/Whisk3D/font.png@font.png \
     --shell-file ../../core/shell.html \
     -o web/pong.html

echo ""
echo "LISTO -> examples/ui/pong/web/pong.html"
echo "Para verlo:  python -m http.server   y abri  http://localhost:8000/web/pong.html"
