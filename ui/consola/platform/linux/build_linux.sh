#!/usr/bin/env bash
# ============================================================================
#  build_linux.sh - compila el Consola (demo Whisk3D) para GNU/Linux (SDL2 + OpenGL).
#  Salida: platform/linux/build/consola  +  el .deb (whisk3d-consola-1.0.0-Linux.deb)
#  Requiere: libsdl2-dev, libgl1-mesa-dev, libglu1-mesa-dev, cmake.
#
#  MODO DEBUG (el punto didactico del ejemplo): por defecto compila DEBUG
#  (W3D_DEV_LOG=1: log + ring + depurar() + boton DEPURAR visible). Para el
#  build de PRODUCCION (W3D_DEV_LOG=0, sin nada de eso):
#      MODO=prod bash build_linux.sh      (o: bash build_linux.sh prod)
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"
MODO="${MODO:-${1:-debug}}"
if [ "$MODO" = "prod" ]; then DBG=0; else DBG=1; fi
echo "modo: $MODO (W3D_DEV_LOG=$DBG)"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DW3D_DEBUG=$DBG
cmake --build build -j"$(nproc)"
# genera el .deb en el mismo build/ (para instalar y probar). No aborta el build si cpack falla.
( cd build && cpack -G DEB ) || echo "AVISO: no se pudo generar el .deb (cpack). El binario igual quedo listo."
echo
echo "Listo -> $(pwd)/build/consola   (modo $MODO)"
echo ".deb   -> $(pwd)/build/whisk3d-consola-1.0.0-Linux.deb"
