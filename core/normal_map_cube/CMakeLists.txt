cmake_minimum_required(VERSION 3.16)
project(normal_map_cube CXX)

# Whisk3D-Core: por defecto el submodulo LOCAL de examples/.
if(NOT DEFINED W3DCORE)
    set(W3DCORE ${CMAKE_CURRENT_SOURCE_DIR}/../../libs/Whisk3DCore)
endif()

find_package(SDL2 REQUIRED)

# render (w3dGraphics) + loader de texturas (w3dTexture, con stb via W3D_STB_IMPL)
add_executable(normal_map_cube
    main.cpp
    ${W3DCORE}/w3dGraphics.cpp
    ${W3DCORE}/w3dTexture.cpp
)
target_include_directories(normal_map_cube PRIVATE ${W3DCORE} ${W3DCORE}/thirdparty)
target_compile_definitions(normal_map_cube PRIVATE SDL_MAIN_HANDLED W3D_STB_IMPL)

if(WIN32)
    target_link_libraries(normal_map_cube PRIVATE SDL2::SDL2 opengl32 glu32)
else()
    find_package(OpenGL REQUIRED)
    target_link_libraries(normal_map_cube PRIVATE SDL2::SDL2 OpenGL::GL GLU)
endif()

add_custom_command(TARGET normal_map_cube POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/../assets $<TARGET_FILE_DIR:normal_map_cube>/assets)
