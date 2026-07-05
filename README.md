# Whisk3D — Ejemplos

Ejemplos de uso de **[Whisk3D Core](https://github.com/Dante-Leoncini/Whisk3Dcore)**, el motor de render multiplataforma de Whisk3D.

Cada ejemplo usa **solo el Core** (`w3dEngine`), sin llamar a OpenGL directamente. La gracia es que **el mismo código de render corre en Windows, Linux, Android, Symbian y WebGL** — el Core resuelve el backend por debajo (pipeline fijo de GL/GLES1 en desktop y el N95; shaders de OpenGL ES 2.0 en WebGL).

## Ejemplos (`core/`)

| Ejemplo | Qué muestra |
| --- | --- |
| **simple_cube** | Un cubo liso iluminado por una luz. Lo mínimo: geometría + una luz + un color de material. |
| **textured_cube** | Un cubo con una **textura** cargada de archivo. La carga la hace el Core (`w3dEngine::LoadTexture`); el ejemplo no toca ningún loader ni GL directo. |
| **normal_map_cube** | Un cubo con **normal map (DOT3)**: el relieve es falso (la geometría es un cubo liso), pero una textura de normales hace que agarre luz como si tuviera detalles al girar. |

Los tres rotan de forma continua y se adaptan al tamaño de la ventana / el canvas.

## Compilar

### Desktop (Windows / Linux) — necesita SDL2

```sh
cd core
cmake -B build && cmake --build build
```

Cada ejemplo tiene su propio `CMakeLists.txt`, y el de `core/` los compila todos de una.

### WebGL — necesita [Emscripten](https://emscripten.org/) (emsdk)

```sh
source /ruta/a/emsdk/emsdk_env.sh   # deja emcc en el PATH
cd core
./build_web.sh                      # genera core/web/*.html
python -m http.server               # y abrís http://localhost:8000/web/simple_cube.html
```

> WebGL no corre abriendo el `.html` con `file://` (el browser bloquea el `.wasm`): hay que servirlo por HTTP, como lo muestro arriba.

## Estructura

```
libs/
├── Whisk3DCore/   submódulo — el motor de render (Whisk3D Core)
└── WhiskUI/       submódulo — la UI de Whisk3D (para los ejemplos de UI)
core/              ejemplos que usan SOLO el Core
ui/                ejemplos de la UI (próximamente)
```

Los submódulos se traen con:

```sh
git clone --recurse-submodules <este-repo>
# o, si ya lo clonaste:
git submodule update --init --recursive
```

## Próximamente

Se van a ir agregando **más ejemplos** — otros usos del Core, y los primeros que demuestran la **UI** de Whisk3D en `ui/`.
