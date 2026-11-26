cmake_minimum_required(VERSION 3.16)
project(simple_cube CXX)

# Whisk3D-Core: por defecto el submodulo libs/Whisk3DCore de este repo (W3DCORE lo cambia).
# El ejemplo solo necesita el render del Core y el log.
include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/whisk3d_core.cmake)

add_executable(simple_cube main.cpp)
w3d_core_example(simple_cube)
