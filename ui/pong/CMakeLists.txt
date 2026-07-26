cmake_minimum_required(VERSION 3.16)
project(pong CXX C)
set(CMAKE_CXX_STANDARD 11)

# ============================================================================
#  Pong standalone: el juego del Editor 2D (pong.w3dui + pong.lua) corriendo
#  SIN el editor. Reusa el Core (render + lua), la UI 2D (UIOverlay) y el
#  runtime game/w3drun. Compila para Linux; para WebGL usar build_web.sh.
# ============================================================================

# raiz del repo Whisk3D (Core + UI 2D). Por defecto, al lado del ecosistema.
if(NOT DEFINED W3DROOT)
    set(W3DROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../Whisk3D)
endif()
set(CORE ${W3DROOT}/libs/Whisk3DCore)
set(UILIB ${W3DROOT}/libs/WhiskUI)
set(GAME ${CMAKE_CURRENT_SOURCE_DIR}/../../game)
set(LUA ${W3DROOT}/thirdparty/lua/src)

find_package(SDL2 REQUIRED)
find_package(OpenGL REQUIRED)

# ---- lua (interprete del Core) ----
file(GLOB LUA_SRC ${LUA}/*.c)
list(REMOVE_ITEM LUA_SRC ${LUA}/lua.c ${LUA}/luac.c)

add_executable(pong
    main.cpp
    ${GAME}/w3drun.cpp
    # --- Core: engine (render fijo desktop) + escena + animacion + lua ---
    ${CORE}/gfx/w3dGraphics.cpp
    ${CORE}/gfx/w3dTexture.cpp
    ${CORE}/io/w3dFilesystem.cpp
    ${CORE}/io/w3dCompress.cpp
    ${CORE}/base/w3dlog.cpp
    ${CORE}/base/W3dInteractionState.cpp
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
    # AUDIO (beep estilo Pong): mixer del Core + salida SDL2
    ${CORE}/audio/W3dAudio.cpp
    ${CORE}/audio/W3dAudioSDL.cpp
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
    ${W3DROOT}/main/io/UI2DFormato.cpp
    ${W3DROOT}/main/io/Fuente2D.cpp
    ${LUA_SRC}
)

target_compile_definitions(pong PRIVATE
    W3D_OPENGL         # backend de render fijo (desktop OpenGL), como el editor
    W3D_GAME_RUNTIME   # las piezas 2D del editor compilan sin el editor
    W3D_GAME_NO_TEX    # el pong es rects+texto: sin texturas ni video (stubs)
    SDL_MAIN_HANDLED
    LUA_USE_POSIX
    W3D_STB_IMPL
    W3D_ENABLE_AUDIO   # sonido (beep() del script) via SDL2 audio
)

target_include_directories(pong PRIVATE
    ${GAME}
    ${W3DROOT} ${W3DROOT}/libs ${W3DROOT}/main
    ${W3DROOT}/main/render ${W3DROOT}/main/io
    ${CORE} ${CORE}/base ${CORE}/gfx ${CORE}/io ${CORE}/math ${CORE}/objects
    ${CORE}/script ${CORE}/animation ${CORE}/thirdparty
    ${UILIB} ${UILIB}/text ${UILIB}/draw ${UILIB}/core ${UILIB}/theme ${UILIB}/widgets
    ${LUA}
)

target_link_libraries(pong PRIVATE SDL2::SDL2 OpenGL::GL OpenGL::GLU)

# copiar los assets del juego al lado del binario (para correr desde build/)
add_custom_command(TARGET pong POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/pong.w3dui $<TARGET_FILE_DIR:pong>/pong.w3dui
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/pong.lua   $<TARGET_FILE_DIR:pong>/pong.lua
    COMMAND ${CMAKE_COMMAND} -E copy ${W3DROOT}/res/Skins/Whisk3D/font.png  $<TARGET_FILE_DIR:pong>/font.png
)

# ============================================================================
#  Instalacion + paquete .deb (cpack -G DEB desde build/). El binario carga sus
#  assets del directorio actual -> se instalan juntos en /usr/lib/whisk3d-pong
#  y un script en /usr/bin hace cd ahi antes de lanzar.
# ============================================================================
install(TARGETS pong DESTINATION lib/whisk3d-pong)
install(FILES pong.w3dui pong.lua ${W3DROOT}/res/Skins/Whisk3D/font.png
        DESTINATION lib/whisk3d-pong)
file(WRITE ${CMAKE_BINARY_DIR}/whisk3d-pong
"#!/bin/sh\ncd /usr/lib/whisk3d-pong && exec ./pong \"$@\"\n")
install(PROGRAMS ${CMAKE_BINARY_DIR}/whisk3d-pong DESTINATION bin)
file(WRITE ${CMAKE_BINARY_DIR}/whisk3d-pong.desktop
"[Desktop Entry]\nType=Application\nName=Pong (Whisk3D)\nComment=Pong hecho con Whisk3D\nExec=whisk3d-pong\nTerminal=false\nCategories=Game;\n")
install(FILES ${CMAKE_BINARY_DIR}/whisk3d-pong.desktop DESTINATION share/applications)

set(CPACK_GENERATOR DEB)
set(CPACK_PACKAGE_NAME "whisk3d-pong")
set(CPACK_PACKAGE_VERSION "1.0.0")
set(CPACK_PACKAGE_CONTACT "Dante Leoncini")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libsdl2-2.0-0")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Pong hecho con el editor Whisk3D (juego standalone)")
include(CPack)
