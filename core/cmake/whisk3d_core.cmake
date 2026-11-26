# ============================================================================
#  Las piezas del Core que usan los ejemplos de core/: el render de escritorio
#  (OpenGL de pipeline fijo, graphics/opengl/), las texturas (el cargador de
#  imagenes stb y su cache de estado, que el render usa siempre), la lectura de
#  archivos y el log.
#
#    w3d_core_example(<target>)
#
#  W3DCORE apunta al Core: por defecto el submodulo libs/Whisk3DCore de este repo.
# ============================================================================
if(NOT DEFINED W3DCORE)
    set(W3DCORE ${CMAKE_CURRENT_LIST_DIR}/../../libs/Whisk3DCore)
endif()
include(${W3DCORE}/graphics/w3dGraphicsBackend.cmake)
find_package(SDL2 REQUIRED)

function(w3d_core_example TARGET)
    target_sources(${TARGET} PRIVATE
        ${W3DCORE}/graphics/opengl/w3dGraphics.cpp
        ${W3DCORE}/graphics/w3dTexture.cpp
        ${W3DCORE}/io/w3dFilesystem.cpp
        ${W3DCORE}/base/w3dlog.cpp)
    target_compile_definitions(${TARGET} PRIVATE W3D_STB_IMPL)
    target_include_directories(${TARGET} PRIVATE
        ${W3DCORE} ${W3DCORE}/base ${W3DCORE}/graphics ${W3DCORE}/io ${W3DCORE}/math ${W3DCORE}/thirdparty)
    w3d_configure_graphics_backend(${TARGET})
    target_link_libraries(${TARGET} PRIVATE SDL2::SDL2)
endfunction()
