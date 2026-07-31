cmake_minimum_required(VERSION 3.16)
project(whiskpaddle CXX C)
set(CMAKE_CXX_STANDARD 11)

# ============================================================================
#  WhiskPaddle standalone: el juego del Editor 2D (whiskpaddle.w3dui + whiskpaddle.lua) corriendo
#  SIN el editor. Reusa el Core (render + lua), la UI 2D (UIOverlay) y el
#  runtime game/w3drun. Compila para Linux; para WebGL usar build_web.sh.
# ============================================================================

# raiz del repo Whisk3D (Core + UI 2D). Por defecto, al lado del ecosistema.
if(NOT DEFINED W3DROOT)
    set(W3DROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../Whisk3D)
endif()
set(CORE ${W3DROOT}/libs/Whisk3DCore)
set(UILIB ${W3DROOT}/libs/WhiskUI)
# el codigo del whiskpaddle (main.cpp, whiskpaddle.lua, whiskpaddle.w3dui) vive 2 niveles arriba (raiz del ejemplo)
set(WHISKPADDLE ${CMAKE_CURRENT_SOURCE_DIR}/../..)
set(GAME ${CMAKE_CURRENT_SOURCE_DIR}/../../../../game)
set(LUA ${W3DROOT}/thirdparty/lua/src)

find_package(SDL2 REQUIRED)
find_package(OpenGL REQUIRED)

# ---- lua (interprete del Core) ----
file(GLOB LUA_SRC ${LUA}/*.c)
list(REMOVE_ITEM LUA_SRC ${LUA}/lua.c ${LUA}/luac.c)

add_executable(whiskpaddle
    ${WHISKPADDLE}/main.cpp
    ${GAME}/w3drun.cpp
    # --- Core: engine (render fijo desktop) + escena + animacion + lua ---
    ${CORE}/gfx/w3dGraphics.cpp
    ${CORE}/gfx/w3dTexture.cpp
    ${CORE}/io/w3dFilesystem.cpp
    ${CORE}/io/w3dCompress.cpp
    ${CORE}/base/w3dlog.cpp
    ${CORE}/base/W3dInteractionState.cpp
    ${CORE}/base/W3dConfig.cpp   # config persistente (idioma + mute) del juego

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
    # fisica minima del Core (velocidad + rebotes AABB): va SIEMPRE junto a W3dScript.cpp (registra sus binds)
    ${CORE}/physics/W3dFisica.cpp
    # AUDIO (beep estilo WhiskPaddle): mixer del Core + salida SDL2
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
    ${W3DROOT}/main/script/BindsJuego.cpp   # binds 2D de juego COMPARTIDOS con el editor (Play)
    ${W3DROOT}/main/W3dEscena.cpp           # motor multi-escena COMPARTIDO con el editor
    ${W3DROOT}/main/io/UI2DFormato.cpp
    ${W3DROOT}/main/io/Fuente2D.cpp
    ${W3DROOT}/main/io/Textura2D.cpp   # carga el PNG del parlante (imagen). El video queda stubeado.
    ${LUA_SRC}
)

target_compile_definitions(whiskpaddle PRIVATE
    W3D_OPENGL         # backend de render fijo (desktop OpenGL), como el editor
    W3D_GAME_RUNTIME   # las piezas 2D del editor compilan sin el editor
    W3D_GAME_NO_TEX    # el whiskpaddle es rects+texto: sin texturas ni video (stubs)
    SDL_MAIN_HANDLED
    LUA_USE_POSIX
    W3D_STB_IMPL
    W3D_ENABLE_AUDIO   # sonido (beep() del script) via SDL2 audio
)

target_include_directories(whiskpaddle PRIVATE
    ${GAME}
    ${W3DROOT} ${W3DROOT}/libs ${W3DROOT}/main
    ${W3DROOT}/main/render ${W3DROOT}/main/io
    ${CORE} ${CORE}/base ${CORE}/gfx ${CORE}/io ${CORE}/math ${CORE}/objects
    ${CORE}/script ${CORE}/animation ${CORE}/thirdparty
    ${UILIB} ${UILIB}/text ${UILIB}/draw ${UILIB}/core ${UILIB}/theme ${UILIB}/widgets
    ${LUA}
)

target_link_libraries(whiskpaddle PRIVATE SDL2::SDL2 OpenGL::GL OpenGL::GLU)

# copiar los assets del juego al lado del binario (para correr desde build/)
# MULTI-ESCENA: las 3 escenas (.w3dui) + sus scripts (.lua) + sonidos.lua (comun a las 3).
# Los iconos (pausa/salir/parlante) viven en assets/ y se copian CON su carpeta:
# los .w3dui los referencian como "assets/xxx.png" (relativo a la carpeta del .w3dui).
add_custom_command(TARGET whiskpaddle POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${WHISKPADDLE}/menu.w3dui        $<TARGET_FILE_DIR:whiskpaddle>/menu.w3dui
    COMMAND ${CMAKE_COMMAND} -E copy ${WHISKPADDLE}/dificultad.w3dui  $<TARGET_FILE_DIR:whiskpaddle>/dificultad.w3dui
    COMMAND ${CMAKE_COMMAND} -E copy ${WHISKPADDLE}/juego.w3dui       $<TARGET_FILE_DIR:whiskpaddle>/juego.w3dui
    COMMAND ${CMAKE_COMMAND} -E copy ${WHISKPADDLE}/menu.lua          $<TARGET_FILE_DIR:whiskpaddle>/menu.lua
    COMMAND ${CMAKE_COMMAND} -E copy ${WHISKPADDLE}/dificultad.lua    $<TARGET_FILE_DIR:whiskpaddle>/dificultad.lua
    COMMAND ${CMAKE_COMMAND} -E copy ${WHISKPADDLE}/juego.lua         $<TARGET_FILE_DIR:whiskpaddle>/juego.lua
    COMMAND ${CMAKE_COMMAND} -E copy ${WHISKPADDLE}/sonidos.lua       $<TARGET_FILE_DIR:whiskpaddle>/sonidos.lua
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${WHISKPADDLE}/assets  $<TARGET_FILE_DIR:whiskpaddle>/assets
    COMMAND ${CMAKE_COMMAND} -E copy ${W3DROOT}/res/Skins/Whisk3D/font.png  $<TARGET_FILE_DIR:whiskpaddle>/font.png
)

# ============================================================================
#  Instalacion + paquete .deb (cpack -G DEB desde build/). El binario carga sus
#  assets del directorio actual -> se instalan juntos en /usr/lib/whisk3d-whiskpaddle
#  y un script en /usr/bin hace cd ahi antes de lanzar.
# ============================================================================
install(TARGETS whiskpaddle DESTINATION lib/whisk3d-whiskpaddle)
install(FILES ${WHISKPADDLE}/menu.w3dui ${WHISKPADDLE}/dificultad.w3dui ${WHISKPADDLE}/juego.w3dui
              ${WHISKPADDLE}/menu.lua ${WHISKPADDLE}/dificultad.lua ${WHISKPADDLE}/juego.lua ${WHISKPADDLE}/sonidos.lua
              ${W3DROOT}/res/Skins/Whisk3D/font.png
        DESTINATION lib/whisk3d-whiskpaddle)
# la carpeta assets/ ENTERA (sin barra final: se instala assets/ adentro del destino)
install(DIRECTORY ${WHISKPADDLE}/assets DESTINATION lib/whisk3d-whiskpaddle)
file(WRITE ${CMAKE_BINARY_DIR}/whisk3d-whiskpaddle
"#!/bin/sh\ncd /usr/lib/whisk3d-whiskpaddle && exec ./whiskpaddle \"$@\"\n")
install(PROGRAMS ${CMAKE_BINARY_DIR}/whisk3d-whiskpaddle DESTINATION bin)
file(WRITE ${CMAKE_BINARY_DIR}/whisk3d-whiskpaddle.desktop
"[Desktop Entry]\nType=Application\nName=WhiskPaddle (Whisk3D)\nComment=WhiskPaddle hecho con Whisk3D\nExec=whisk3d-whiskpaddle\nTerminal=false\nCategories=Game;\n")
install(FILES ${CMAKE_BINARY_DIR}/whisk3d-whiskpaddle.desktop DESTINATION share/applications)

set(CPACK_GENERATOR DEB)
set(CPACK_PACKAGE_NAME "whisk3d-whiskpaddle")
set(CPACK_PACKAGE_VERSION "1.0.0")
set(CPACK_PACKAGE_CONTACT "Dante Leoncini")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libsdl2-2.0-0")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "WhiskPaddle hecho con el editor Whisk3D (juego standalone)")
include(CPack)
