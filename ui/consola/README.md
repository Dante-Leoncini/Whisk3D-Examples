# Consola, log + modo debug con el editor Whisk3D

Ejemplo didactico, un escalon como `ui/calculadora`: cuatro botones que emiten
mensajes al LOG del Core y un panel "Pantalla" que muestra las ultimas 8 lineas
del ring buffer del log, con DOS archivos:

- `consola.w3dui` (la INTERFAZ): titulo, una columna de 4 botones (INFO celeste,
  AVISO amarillo, ERROR rojo, DEPURAR gris) y el panel oscuro con 8 textos
  (`Linea1..Linea8`, uno por linea: `setTexto()` no interpreta `\n`).
- `consola.lua` (SOLO la logica): cada boton llama a `info()` / `aviso()` /
  `error()` / `depurar()`; el panel se refresca leyendo `logCantidad()` +
  `logLinea(i)`.
- `consola.w3d` (el proyecto para abrirlo en el editor).

## Debug vs produccion (el punto del ejemplo)

El MISMO `.w3dui` + `.lua` corren en los dos builds; la macro `W3D_DEV_LOG` del
Core (`base/w3dlog.h`) decide que se ve:

|                        | build DEBUG (`W3D_DEV_LOG=1`) | build PRODUCCION (`W3D_DEV_LOG=0`) |
|------------------------|-------------------------------|------------------------------------|
| `info/aviso/error`     | al log del sistema + al ring  | no emiten (el sink desaparece)     |
| `depurar()`            | emite (prefijo `debug:`)      | no-op                              |
| `esDebug()`            | `true`                        | `false`                            |
| boton DEPURAR          | visible                       | oculto (`mostrar(btn, esDebug())`) |
| panel "Pantalla"       | las ultimas 8 lineas del log  | "consola apagada (produccion)"     |

En el editor (Play) siempre se ve todo: el editor compila con el default
`W3D_DEV_LOG=1`. En la tarjeta Juego del editor, el checkbox "Modo debug"
(default destildado = produccion) define la misma macro al Compilar juego.

## Abrirlo en el editor

Doble click en `consola.w3d` (o `whisk3d consola.w3d`): abre el proyecto y
arranca jugando (Play). Los botones responden al mouse sobre el viewport.

## Compilar standalone (sin el editor)

Los scripts compilan DEBUG por defecto (el ejemplo muestra todo); con
`MODO=prod` compilan produccion:

**Linux (SDL2 + OpenGL):**
```sh
bash platform/linux/build_linux.sh             # DEBUG -> platform/linux/build/consola
MODO=prod bash platform/linux/build_linux.sh   # PRODUCCION
```

**WebGL (Emscripten, con emsdk activado):**
```sh
bash platform/web/build_web.sh                 # -> platform/web/build/consola.html
MODO=prod bash platform/web/build_web.sh
python -m http.server --directory platform/web/build   # abrir localhost:8000/consola.html
```

**Android (NDK + gradle; APK fat armeabi-v7a + arm64-v8a):**
```sh
bash platform/android/build_android.sh         # -> whisk3d-consola-<fecha>-Android.apk
MODO=prod bash platform/android/build_android.sh
```

Los tres builds reusan el Core del editor (`../../../Whisk3D`), la UI 2D y lua:
es el MISMO `.w3dui` + `.lua` que se abren en el editor, corriendo solos.
