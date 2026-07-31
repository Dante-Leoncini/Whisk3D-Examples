#!/usr/bin/env bash
# ============================================================================
#  build_linux.sh - compila el WhiskPaddle (demo Whisk3D) para GNU/Linux (SDL2 + OpenGL).
#  Salida: platform/linux/build/whiskpaddle  +  el .deb (whisk3d-whiskpaddle-1.0.0-Linux.deb)
#  Requiere: libsdl2-dev, libgl1-mesa-dev, libglu1-mesa-dev, cmake.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
# genera el .deb en el mismo build/ (para instalar y probar). No aborta el build si cpack falla.
( cd build && cpack -G DEB ) || echo "AVISO: no se pudo generar el .deb (cpack). El binario igual quedo listo."
echo
echo "Listo -> $(pwd)/build/whiskpaddle"
echo ".deb   -> $(pwd)/build/whisk3d-whiskpaddle-1.0.0-Linux.deb"
