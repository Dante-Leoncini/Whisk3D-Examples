cmake_minimum_required(VERSION 3.16)
project(whisk3d_examples CXX)

# Cada ejemplo es independiente y se puede compilar solo (ver su CMakeLists). 
# Este agrupador los compila todos de una.
add_subdirectory(simple_cube)
add_subdirectory(textured_cube)
add_subdirectory(normal_map_cube)
