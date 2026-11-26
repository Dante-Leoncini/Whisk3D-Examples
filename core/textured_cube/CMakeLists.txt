cmake_minimum_required(VERSION 3.16)
project(textured_cube CXX)

# Whisk3D-Core: por defecto el submodulo libs/Whisk3DCore de este repo (W3DCORE lo cambia).
# El ejemplo usa el render del Core, su cargador de texturas y el log.
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/whisk3d_core.cmake)

add_executable(textured_cube main.cpp)
w3d_core_example(textured_cube)

# las imagenes del ejemplo, al lado del ejecutable (el main las abre como assets/...)
add_custom_command(TARGET textured_cube POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/../assets $<TARGET_FILE_DIR:textured_cube>/assets)
