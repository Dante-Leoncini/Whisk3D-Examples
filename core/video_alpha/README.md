# video_alpha

Un video con **alpha** (WebM) en loop **sobre** un video de fondo (MP4), con **assets
protegidos**. La decodificación, la reproducción y el descifrado los hace el **motor**
(`w3dEngine`), un módulo **opcional** del Core (`-DW3D_ENABLE_VIDEO`). El ejemplo no toca GL
ni ningún decoder: pide la textura del frame actual y dibuja dos quads.

## Encuadre al cambiar el tamaño de la ventana (como `object-fit`, sin deformar)

- **Fondo (mp4) → `cover`**: llena la ventana creciendo en ancho o alto; recorta lo que sobra.
- **Frente (webm) → `contain`**: se ve entero, centrado; si no encaja deja aire (letterbox).

## Assets protegidos (no son archivos sueltos)

Los videos **no** se sirven como archivos: van cifrados en un `.w3dpack`. En el navegador no
queda ningún `.mp4`/`.webm` con nombre ni URL que copiar (ver `THREAT_MODEL.md` del Core: es
disuasión fuerte, **no** DRM inquebrantable).

1. Empaquetá tus dos videos (el packer imprime la clave):
   ```
   w3dpacker assets.w3dpack --genkey  fondo.mp4=/ruta/fondo.mp4  frente.webm=/ruta/frente.webm
   ```
   (compilá el packer desde `libs/Whisk3DCore/tools/w3dpacker.cpp` + `io/W3dPack.cpp`.)
2. Dejá el `assets.w3dpack` en esta carpeta (`core/video_alpha/`).
3. Pegá la clave que imprimió en `main.cpp` (`PACK_KEY`). Embebida = disuasión; para
   protección fuerte, traela de tu servidor por sesión en vez de embeberla.

Los nombres dentro del pack deben ser `fondo.mp4` y `frente.webm` (los que busca `main.cpp`).

## Build

- **Web** (navegador = decodificación por **hardware**, VP9-alpha nativo):
  `cd examples/core && source /ruta/emsdk/emsdk_env.sh && ./build_web.sh`
  El `.w3dpack` se **embebe** (bytes ilegibles); levantá un server local
  (`python -m http.server`) y abrí `web/video_alpha.html`.
- **Desktop** (Win/Linux): backend FFmpeg del Core (HW d3d11va/vaapi + fallback SW; fuerza SW
  si el WebM trae alpha para no perderla). Requiere las dev-libs de FFmpeg linkeadas con
  `-DW3D_ENABLE_VIDEO`.

> El módulo `video/` y `io/W3dPack` viven en el submódulo `Whisk3DCore`. Si el puntero del
> submódulo en este repo todavía no los trae, `build_web.sh` saltea este ejemplo hasta que
> se bumpee.
