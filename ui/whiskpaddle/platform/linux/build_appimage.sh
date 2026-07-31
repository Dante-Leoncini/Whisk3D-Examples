#!/usr/bin/env bash
# ============================================================================
#  build_appimage.sh - genera el AppImage de WhiskPaddle (demo Whisk3D, Linux).
#
#  Requiere el binario ya compilado por  platform/linux/build_linux.sh
#  (platform/linux/build/whiskpaddle) con sus assets copiados al lado
#  (whiskpaddle.w3dui, *.lua, *.png, font.png -> los pone el POST_BUILD del CMake).
#
#  POR QUE un AppRun a mano (no el symlink por defecto de linuxdeploy):
#  el whiskpaddle carga sus assets por nombre RELATIVO ("font.png",
#  "whiskpaddle.w3dui", "sonidos.lua"...) que fopen resuelve contra el CWD.
#  Al montar un AppImage el CWD es cualquiera -> no los encuentra. El .deb ya
#  resuelve esto con un launcher que hace 'cd <carpeta de recursos> && exec';
#  aca replicamos lo mismo en el AppRun (cd a usr/bin, donde estan binario+assets).
#
#  Genera:  platform/linux/build/WhiskPaddle-<ver>-x86_64.AppImage
#  Uso:     platform/linux/build_appimage.sh
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"   # platform/linux/

BUILD=build
if [[ ! -x "$BUILD/whiskpaddle" ]]; then
    echo "ERROR: falta el binario ($BUILD/whiskpaddle). Compila primero:  platform/linux/build_linux.sh" >&2
    exit 1
fi

VER=$(date +%y.%m.%d)

# --- herramientas (PATH -> cache -> descargar). Misma cache que el editor. ---
TOOLS="${APPIMAGE_TOOLS:-$HOME/.cache/whisk3d-appimage}"
mkdir -p "$TOOLS"
obtener() { # $1=comando $2=archivo $3=url  -> imprime la ruta ejecutable
    if command -v "$1" >/dev/null 2>&1; then command -v "$1"; return; fi
    if [[ ! -x "$TOOLS/$2" ]]; then echo "Descargando $2..." >&2; wget -qO "$TOOLS/$2" "$3"; chmod +x "$TOOLS/$2"; fi
    echo "$TOOLS/$2"
}
LD=$(obtener linuxdeploy  linuxdeploy-x86_64.AppImage  "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage")
AT=$(obtener appimagetool appimagetool-x86_64.AppImage "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage")
export PATH="$(dirname "$AT"):$PATH"      # linuxdeploy invoca appimagetool desde el PATH
export APPIMAGE_EXTRACT_AND_RUN=1         # sin FUSE (headless/CI) las AppImage de las tools no montan

# --- armar AppDir: binario + assets JUNTOS en usr/bin (el CWD al que salta el AppRun) ---
WORK=$(mktemp -d); APPDIR="$WORK/AppDir"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps"

cp "$BUILD/whiskpaddle" "$APPDIR/usr/bin/"
# los assets que el POST_BUILD del CMake dejo al lado del binario
for a in menu.w3dui dificultad.w3dui juego.w3dui menu.lua dificultad.lua juego.lua sonidos.lua font.png; do
    [[ -f "$BUILD/$a" ]] && cp "$BUILD/$a" "$APPDIR/usr/bin/"
done
# la carpeta assets/ (iconos pausa/salir/parlante) va ENTERA con su subdirectorio
[[ -d "$BUILD/assets" ]] && cp -r "$BUILD/assets" "$APPDIR/usr/bin/"

# icono (reusa el del editor; W3DROOT esta 5 niveles arriba, igual que en el CMakeLists) + .desktop
ICON="../../../../../Whisk3D/res/Whisk3D.png"
cp "$ICON" "$APPDIR/usr/share/icons/hicolor/256x256/apps/whiskpaddle.png"
cat > "$APPDIR/usr/share/applications/whiskpaddle.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=WhiskPaddle (Whisk3D)
Comment=WhiskPaddle hecho con Whisk3D
Exec=whiskpaddle
Icon=whiskpaddle
Terminal=false
Categories=Game;
EOF

# AppRun a mano: cd a la carpeta de recursos (usr/bin) antes de lanzar, como el launcher del .deb.
cat > "$WORK/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH}"
cd "$HERE/usr/bin" && exec ./whiskpaddle "$@"
EOF
chmod +x "$WORK/AppRun"

export ARCH=x86_64 VERSION="$VER"
( cd "$WORK" && "$LD" --appdir AppDir \
    --executable AppDir/usr/bin/whiskpaddle \
    --desktop-file AppDir/usr/share/applications/whiskpaddle.desktop \
    --icon-file AppDir/usr/share/icons/hicolor/256x256/apps/whiskpaddle.png \
    --custom-apprun "$WORK/AppRun" \
    --output appimage )

GEN=$(ls "$WORK"/*.AppImage | head -1)
OUT="$BUILD/WhiskPaddle-$VER-x86_64.AppImage"
mv "$GEN" "$OUT"
rm -rf "$WORK"
echo
echo "AppImage generado -> $(cd "$(dirname "$0")" && pwd)/$OUT"
