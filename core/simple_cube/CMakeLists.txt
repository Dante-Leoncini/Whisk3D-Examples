cmake_minimum_required(VERSION 3.16)
project(simple_cube CXX)

# Whisk3D-Core: por defecto el submodulo LOCAL de examples/. El ejemplo solo necesita
# el render del Core (w3dGraphics.cpp).
if(NOT DEFINED W3DCORE)
    set(W3DCORE ${CMAKE_CURRENT_SOURCE_DIR}/../../libs/Whisk3DCore)
endif()

find_package(SDL2 REQUIRED)

add_executable(simple_cube
    main.cpp
    ${W3DCORE}/w3dGraphics.cpp
)
target_include_directories(simple_cube PRIVATE ${W3DCORE})
target_compile_definitions(simple_cube PRIVATE SDL_MAIN_HANDLED)

if(WIN32)
    target_link_libraries(simple_cube PRIVATE SDL2::SDL2 opengl32 glu32)
else()
    find_package(OpenGL REQUIRED)
    target_link_libraries(simple_cube PRIVATE SDL2::SDL2 OpenGL::GL)
endif()
