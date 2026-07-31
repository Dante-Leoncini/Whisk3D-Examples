cmake_minimum_required(VERSION 3.16)
project(calculadora CXX C)
set(CMAKE_CXX_STANDARD 11)

# ============================================================================
#  Calculadora standalone: el ejemplo de UI (calculadora.w3dui + calculadora.lua)
#  corriendo SIN el editor. Reusa el Core (render + lua), la UI 2D (UIOverlay) y
#  el runtime game/w3drun. Compila para Linux; para WebGL usar build_web.sh.
# ============================================================================

# raiz del repo Whisk3D (Core + UI 2D). Por defecto, al lado del ecosistema.
if(NOT DEFINED W3DROOT)
    set(W3DROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../Whisk3D)
endif()
set(CORE ${W3DROOT}/libs/Whisk3DCore)
set(UILIB ${W3DROOT}/libs/WhiskUI)
# el codigo de la calculadora (main.cpp, calculadora.lua, calculadora.w3dui) vive 2 niveles arriba (raiz del ejemplo)
set(CALCULADORA ${CMAKE_CURRENT_SOURCE_DIR}/../..)
set(GAME ${CMAKE_CURRENT_SOURCE_DIR}/../../../../game)
set(LUA ${W3DROOT}/thirdparty/lua/src)

find_package(SDL2 REQUIRED)
find_package(OpenGL REQUIRED)

# ---- lua (interprete del Core) ----
file(GLOB LUA_SRC ${LUA}/*.c)
list(REMOVE_ITEM LUA_SRC ${LUA}/lua.c ${LUA}/luac.c)

add_executable(calculadora
    ${CALCULADORA}/main.cpp
    ${GAME}/w3drun.cpp
    # --- Core: engine (render fijo desktop) + escena + animacion + lua ---
    ${CORE}/gfx/w3dGraphics.cpp
    ${CORE}/gfx/w3dTexture.cpp
    ${CORE}/io/w3dFilesystem.cpp
    ${CORE}/io/w3dCompress.cpp
    ${CORE}/base/w3dlog.cpp
    ${CORE}/base/W3dInteractionState.cpp
    ${CORE}/base/W3dConfig.cpp   # config persistente (la usan los binds; la calculadora no guarda nada)

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
    # SIN FISICA: la calculadora no usa velocidad/rebotes -> no se compila
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
    ${W3DROOT}/main/io/Textura2D.cpp   # carga de imagenes (la calculadora no usa; el video queda stubeado)
    ${LUA_SRC}
)

target_compile_definitions(calculadora PRIVATE
    W3D_OPENGL         # backend de render fijo (desktop OpenGL), como el editor
    W3D_GAME_RUNTIME   # las piezas 2D del editor compilan sin el editor
    W3D_GAME_NO_TEX    # la calculadora es botones+texto: sin texturas ni video (stubs)
    SDL_MAIN_HANDLED
    LUA_USE_POSIX
    W3D_STB_IMPL
    W3D_SIN_FISICA     # sin motor de fisica (binds stub); la calculadora no lo usa
    # sin W3D_ENABLE_AUDIO: la calculadora no suena (build mas liviano)
)

target_include_directories(calculadora PRIVATE
    ${GAME}
    ${W3DROOT} ${W3DROOT}/libs ${W3DROOT}/main
    ${W3DROOT}/main/render ${W3DROOT}/main/io
    ${CORE} ${CORE}/base ${CORE}/gfx ${CORE}/io ${CORE}/math ${CORE}/objects
    ${CORE}/script ${CORE}/animation ${CORE}/thirdparty
    ${UILIB} ${UILIB}/text ${UILIB}/draw ${UILIB}/core ${UILIB}/theme ${UILIB}/widgets
    ${LUA}
)

target_link_libraries(calculadora PRIVATE SDL2::SDL2 OpenGL::GL OpenGL::GLU)

# copiar los assets al lado del binario (para correr desde build/)
add_custom_command(TARGET calculadora POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${CALCULADORA}/calculadora.w3dui $<TARGET_FILE_DIR:calculadora>/calculadora.w3dui
    COMMAND ${CMAKE_COMMAND} -E copy ${CALCULADORA}/calculadora.lua   $<TARGET_FILE_DIR:calculadora>/calculadora.lua
    COMMAND ${CMAKE_COMMAND} -E copy ${W3DROOT}/res/Skins/Whisk3D/font.png $<TARGET_FILE_DIR:calculadora>/font.png
)

# ============================================================================
#  Instalacion + paquete .deb (cpack -G DEB desde build/). El binario carga sus
#  assets del directorio actual -> se instalan juntos en /usr/lib/whisk3d-calculadora
#  y un script en /usr/bin hace cd ahi antes de lanzar.
# ============================================================================
install(TARGETS calculadora DESTINATION lib/whisk3d-calculadora)
install(FILES ${CALCULADORA}/calculadora.w3dui ${CALCULADORA}/calculadora.lua
              ${W3DROOT}/res/Skins/Whisk3D/font.png
        DESTINATION lib/whisk3d-calculadora)
file(WRITE ${CMAKE_BINARY_DIR}/whisk3d-calculadora
"#!/bin/sh\ncd /usr/lib/whisk3d-calculadora && exec ./calculadora \"$@\"\n")
install(PROGRAMS ${CMAKE_BINARY_DIR}/whisk3d-calculadora DESTINATION bin)
file(WRITE ${CMAKE_BINARY_DIR}/whisk3d-calculadora.desktop
"[Desktop Entry]\nType=Application\nName=Calculadora (Whisk3D)\nComment=Calculadora hecha con Whisk3D\nExec=whisk3d-calculadora\nTerminal=false\nCategories=Utility;\n")
install(FILES ${CMAKE_BINARY_DIR}/whisk3d-calculadora.desktop DESTINATION share/applications)

set(CPACK_GENERATOR DEB)
set(CPACK_PACKAGE_NAME "whisk3d-calculadora")
set(CPACK_PACKAGE_VERSION "1.0.0")
set(CPACK_PACKAGE_CONTACT "Dante Leoncini")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libsdl2-2.0-0")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Calculadora hecha con el editor Whisk3D (ejemplo standalone)")
include(CPack)
