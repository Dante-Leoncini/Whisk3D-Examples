# Calculadora, una interfaz con el editor Whisk3D + logica en lua

Ejemplo didactico, un escalon arriba de `ui/hola`: una calculadora basica estilo
telefono (display arriba, grilla de botones abajo) hecha con DOS archivos:

- `calculadora.w3dui` (la INTERFAZ), 100% con el layout del editor: dos textos
  anclados arriba (Historial y Display) y un contenedor en FILAS con 5 filas de
  botones, cada fila un contenedor en COLUMNAS con `peso`/`expandir`/`gap`.
  El lienzo es fijo (360x640, `igualQueRender` apagado): el motor lo encaja en
  cualquier pantalla con barras negras.
- `calculadora.lua` (SOLO la logica): lee los botones con `apretado()` y escribe
  los textos con `setTexto()`. CERO posiciones ni cuentas de layout en lua.
- `calculadora.w3d` (el proyecto para abrirlo en el editor).

El script va embebido en el `.w3dui` (array raiz `"scripts"` con `ruta` + `refs`):
las `refs` conectan cada propiedad del lua (`b7`, `mas`, `display`...) con el
objeto de la escena por su nombre (`Btn7`, `BtnMas`, `Display`...).

## Abrirlo en el editor

Doble click en `calculadora.w3d` (o `whisk3d calculadora.w3d`): abre el proyecto
y arranca jugando (Play). Los botones responden al mouse sobre el viewport.

## Compilar standalone (sin el editor)

**Linux (SDL2 + OpenGL):**
```sh
bash platform/linux/build_linux.sh     # -> platform/linux/build/calculadora (+ .deb)
```

**WebGL (Emscripten, con emsdk activado):**
```sh
bash platform/web/build_web.sh         # -> platform/web/build/calculadora.html
python -m http.server --directory platform/web/build   # abrir localhost:8000/calculadora.html
```

**Android (NDK + gradle; APK fat armeabi-v7a + arm64-v8a):**
```sh
bash platform/android/build_android.sh   # -> whisk3d-calculadora-<fecha>-Android.apk
```

Los tres builds reusan el Core del editor (`../../../Whisk3D`), la UI 2D y lua:
es el MISMO `.w3dui` + `.lua` que se abren en el editor, corriendo solos.
