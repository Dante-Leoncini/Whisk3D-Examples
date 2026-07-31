cmake_minimum_required(VERSION 3.16)
project(consola CXX C)
set(CMAKE_CXX_STANDARD 11)

# ============================================================================
#  Consola standalone: el ejemplo de UI (consola.w3dui + consola.lua)
#  corriendo SIN el editor. Reusa el Core (render + lua), la UI 2D (UIOverlay) y
#  el runtime game/w3drun. Compila para Linux; para WebGL usar build_web.sh.
# ============================================================================

# MODO DEBUG del ejemplo: -DW3D_DEBUG=1 (default: la consola muestra todo) o
# -DW3D_DEBUG=0 (produccion: W3D_DEV_LOG=0 -> sin log, sin ring, depurar() no-op
# y el boton DEPURAR oculto). Lo setea build_linux.sh segun MODO=debug|prod.
if(NOT DEFINED W3D_DEBUG)
    set(W3D_DEBUG 1)
endif()

# raiz del repo Whisk3D (Core + UI 2D). Por defecto, al lado del ecosistema.
if(NOT DEFINED W3DROOT)
    set(W3DROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../Whisk3D)
endif()
set(CORE ${W3DROOT}/libs/Whisk3DCore)
set(UILIB ${W3DROOT}/libs/WhiskUI)
# el codigo de la consola (main.cpp, consola.lua, consola.w3dui) vive 2 niveles arriba (raiz del ejemplo)
set(CONSOLA ${CMAKE_CURRENT_SOURCE_DIR}/../..)
set(GAME ${CMAKE_CURRENT_SOURCE_DIR}/../../../../game)
set(LUA ${W3DROOT}/thirdparty/lua/src)

find_package(SDL2 REQUIRED)
find_package(OpenGL REQUIRED)

# ---- lua (interprete del Core) ----
file(GLOB LUA_SRC ${LUA}/*.c)
list(REMOVE_ITEM LUA_SRC ${LUA}/lua.c ${LUA}/luac.c)

add_executable(consola
    ${CONSOLA}/main.cpp
    ${GAME}/w3drun.cpp
    # --- Core: engine (render fijo desktop) + escena + animacion + lua ---
    ${CORE}/gfx/w3dGraphics.cpp
    ${CORE}/gfx/w3dTexture.cpp
    ${CORE}/io/w3dFilesystem.cpp
    ${CORE}/io/w3dCompress.cpp
    ${CORE}/base/w3dlog.cpp
    ${CORE}/base/W3dInteractionState.cpp
    ${CORE}/base/W3dConfig.cpp   # config persistente (la usan los binds; la consola no guarda nada)

    ${CORE}/math/Vector3.cpp
    ${CORE}/math/Quaternion.cpp
    ${CORE}/math/Matrix4.cpp
    ${CORE}/objects/Objects.cpp
    ${CORE}/objects/Mesh.cpp
    ${CORE}/objects/Light.cpp
    ${CORE}/objects/Materials.cpp
    ${CORE}/objects/Textures.cpp
    ${CORE}/objects/CameraBase.cpp
    ${CORE}/objects/Armature.cpp
    ${CORE}/objects/RenderColors.cpp
    ${CORE}/animation/Animation.cpp
    ${CORE}/animation/VertexAnimation.cpp
    ${CORE}/animation/SkeletalAnimation.cpp
    ${CORE}/script/W3dScript.cpp
    # SIN FISICA: la consola no usa velocidad/rebotes -> no se compila
    # physics/W3dFisica.cpp; W3D_SIN_FISICA (abajo) deja los binds como stubs no-op.
    # SIN SONIDO: sin W3D_ENABLE_AUDIO, W3dAudio.cpp es el dispatcher stub (hace
    # linkear al beep() del Core, mudo); el backend SDL (W3dAudioSDL.cpp) no viaja.
    ${CORE}/audio/W3dAudio.cpp
    # --- WhiskUI: tipografia pixel + dibujo ---
    ${UILIB}/text/W3dFont.cpp
    ${UILIB}/text/bitmapText.cpp
    ${UILIB}/text/font.cpp
    ${UILIB}/draw/glesdraw.cpp
    ${UILIB}/draw/W3dAtlasPacker.cpp
    ${UILIB}/core/UI.cpp
    ${UILIB}/theme/colores.cpp
    # --- UI 2D del editor (render + parser + fuente), reusada tal cual ---
    ${W3DROOT}/main/render/UIOverlay.cpp
    ${W3DROOT}/main/script/BindsJuego.cpp   # binds 2D de juego COMPARTIDOS con el editor (Play)
    ${W3DROOT}/main/W3dEscena.cpp           # motor multi-escena COMPARTIDO con el editor
    ${W3DROOT}/main/io/UI2DFormato.cpp
    ${W3DROOT}/main/io/Fuente2D.cpp
    ${W3DROOT}/main/io/Textura2D.cpp   # carga de imagenes (la consola no usa; el video queda stubeado)
    ${LUA_SRC}
)

target_compile_definitions(consola PRIVATE
    W3D_OPENGL         # backend de render fijo (desktop OpenGL), como el editor
    W3D_GAME_RUNTIME   # las piezas 2D del editor compilan sin el editor
    W3D_GAME_NO_TEX    # la consola es botones+texto: sin texturas ni video (stubs)
    SDL_MAIN_HANDLED
    LUA_USE_POSIX
    W3D_STB_IMPL
    W3D_SIN_FISICA     # sin motor de fisica (binds stub); la consola no lo usa
    # sin W3D_ENABLE_AUDIO: la consola no suena (build mas liviano)
    W3D_DEV_LOG=${W3D_DEBUG}   # 1 = modo debug (log + ring + depurar()); 0 = produccion
)

target_include_directories(consola PRIVATE
    ${GAME}
    ${W3DROOT} ${W3DROOT}/libs ${W3DROOT}/main
    ${W3DROOT}/main/render ${W3DROOT}/main/io
    ${CORE} ${CORE}/base ${CORE}/gfx ${CORE}/io ${CORE}/math ${CORE}/objects
    ${CORE}/script ${CORE}/animation ${CORE}/thirdparty
    ${UILIB} ${UILIB}/text ${UILIB}/draw ${UILIB}/core ${UILIB}/theme ${UILIB}/widgets
    ${LUA}
)

target_link_libraries(consola PRIVATE SDL2::SDL2 OpenGL::GL OpenGL::GLU)

# copiar los assets al lado del binario (para correr desde build/)
add_custom_command(TARGET consola POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${CONSOLA}/consola.w3dui $<TARGET_FILE_DIR:consola>/consola.w3dui
    COMMAND ${CMAKE_COMMAND} -E copy ${CONSOLA}/consola.lua   $<TARGET_FILE_DIR:consola>/consola.lua
    COMMAND ${CMAKE_COMMAND} -E copy ${W3DROOT}/res/Skins/Whisk3D/font.png $<TARGET_FILE_DIR:consola>/font.png
)

# ============================================================================
#  Instalacion + paquete .deb (cpack -G DEB desde build/). El binario carga sus
#  assets del directorio actual -> se instalan juntos en /usr/lib/whisk3d-consola
#  y un script en /usr/bin hace cd ahi antes de lanzar.
# ============================================================================
install(TARGETS consola DESTINATION lib/whisk3d-consola)
install(FILES ${CONSOLA}/consola.w3dui ${CONSOLA}/consola.lua
              ${W3DROOT}/res/Skins/Whisk3D/font.png
        DESTINATION lib/whisk3d-consola)
file(WRITE ${CMAKE_BINARY_DIR}/whisk3d-consola
"#!/bin/sh\ncd /usr/lib/whisk3d-consola && exec ./consola \"$@\"\n")
install(PROGRAMS ${CMAKE_BINARY_DIR}/whisk3d-consola DESTINATION bin)
file(WRITE ${CMAKE_BINARY_DIR}/whisk3d-consola.desktop
"[Desktop Entry]\nType=Application\nName=Consola (Whisk3D)\nComment=Consola hecha con Whisk3D\nExec=whisk3d-consola\nTerminal=false\nCategories=Utility;\n")
install(FILES ${CMAKE_BINARY_DIR}/whisk3d-consola.desktop DESTINATION share/applications)

set(CPACK_GENERATOR DEB)
set(CPACK_PACKAGE_NAME "whisk3d-consola")
set(CPACK_PACKAGE_VERSION "1.0.0")
set(CPACK_PACKAGE_CONTACT "Dante Leoncini")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libsdl2-2.0-0")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Consola hecha con el editor Whisk3D (ejemplo standalone)")
include(CPack)
