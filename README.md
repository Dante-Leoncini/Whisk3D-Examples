# Whisk3D — Ejemplos

Ejemplos de **[Whisk3D](https://whisk3d.com.ar)**: el motor de render ([Whisk3D Core](https://github.com/Dante-Leoncini/Whisk3Dcore)) usado directo desde C++, y juegos hechos con el editor (escenas, scripts de Lua y proyectos `.w3d`).

Desde el 22/11/2026 la API de Lua y el formato `.w3d` están en inglés (`start()`, `update(dt)`, `properties`, `object()`, `setText()`…). Todos los ejemplos de este repo ya usan la API nueva; los proyectos de antes de ese cambio no abren en el editor actual.

## Ejemplos del Core (`core/`)

Usan **solo el Core** (`w3dEngine`), sin llamar a OpenGL directamente: el Core resuelve el backend por debajo (pipeline fijo de OpenGL en la PC, shaders de OpenGL ES 2.0 en WebGL).

| Ejemplo | Qué muestra | PC | Web |
| --- | --- | --- | --- |
| **simple_cube** | Un cubo liso iluminado por una luz. Lo mínimo: geometría + una luz + un color de material. | ✓ | ✓ |
| **textured_cube** | Un cubo con una **textura** cargada de archivo por el Core (`w3dEngine::LoadTexture`). | ✓ | ✓ |
| **normal_map_cube** | Un cubo con **normal map (DOT3)**: la geometría es un cubo liso, pero una textura de normales hace que agarre luz como si tuviera relieve. | ✓ | ✓ |
| **animated_logo** | El logo de Whisk3D animado, cargado de un **glTF/GLB** con sus texturas por el Core (`io/w3dGltf.h`). | | ✓ |
| **video_alpha** | Un video con alfa sobre un video de fondo, con los videos **cifrados** en un `.w3dpack` (ver `core/video_alpha/README.md`). | | ✓ |

### Compilar para la PC (Windows / Linux) — necesita SDL2

```sh
cd core
cmake -B build && cmake --build build
```

Cada ejemplo tiene su propio `CMakeLists.txt` (las piezas del Core que usan están en `core/cmake/whisk3d_core.cmake`), y el de `core/` compila los tres de una.

### Compilar para WebGL — necesita [Emscripten](https://emscripten.org/) (emsdk)

```sh
source /ruta/a/emsdk/emsdk_env.sh   # deja emcc en el PATH
cd core
./build_web.sh                      # genera core/web/*.html
python -m http.server               # y abrís http://localhost:8000/web/simple_cube.html
```

> WebGL no corre abriendo el `.html` con `file://` (el navegador bloquea el `.wasm`): hay que servirlo por HTTP, como arriba.

## Juegos hechos con el editor (`ui/` y `w3d_format/`)

Cada uno es un proyecto `.w3d` que se abre en el editor y se juega con **Play**. Para compilarlo a un sistema (Linux, Windows, WebGL, Android, PSP, PS Vita, 3DS, Dreamcast, Symbian) se usa **Compilar juego** en la tarjeta **Juego** del editor: arma el ejecutable en `build/<plataforma>/`.

| Ejemplo | Qué muestra |
| --- | --- |
| **ui/hola** | El juego más simple: un cuadro que se mueve con las flechas (unas 15 líneas de Lua). |
| **ui/calculadora** | Una calculadora: todo el diseño en la escena (filas, columnas, anclas) y la lógica en Lua. |
| **ui/consola** | El log del motor y el modo debug: el mismo script se comporta distinto en un build de depuración y en uno de producción. |
| **ui/whiskpaddle** | Un pong completo: tres escenas (menú, dificultad, partida), física simple del motor, teclado, mando y pantalla táctil, sonido e idiomas. |
| **w3d_format/cubo** | Un cubo 3D que gira con un script de Lua (ver `w3d_format/README.md`). |

## Estructura

```
libs/
├── Whisk3DCore/   submódulo — el motor de render (Whisk3D Core)
└── WhiskUI/       submódulo — la UI de Whisk3D
core/              ejemplos que usan SOLO el Core (C++)
ui/                juegos 2D hechos con el editor (escena .w3dui + scripts .lua en contenido/)
w3d_format/        proyectos .w3d que el editor compila a cualquier sistema (ver w3d_format/README.md)
game/              el runtime de los juegos que compila el editor (lo usa "Compilar juego")
```

`game/` y la plantilla Android de `ui/whiskpaddle/platform/android` los usa el compilador de juegos del editor: el repo de Whisk3D los busca en la carpeta `Whisk3D-Examples`, al lado suyo.

Los submódulos se traen con:

```sh
git clone --recurse-submodules <este-repo>
# o, si ya lo clonaste:
git submodule update --init --recursive
```
