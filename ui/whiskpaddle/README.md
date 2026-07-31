# WhiskPaddle — scripts lua en Whisk3D

El "hola mundo" de los scripts de Whisk3D: un whiskpaddle completo hecho con la UI 2D
del editor y UN archivo lua. Vos jugas con las **flechas arriba/abajo**; la
computadora juega la otra pala (dificultad configurable desde el editor).

## Como probarlo

1. **Doble click en `whiskpaddle.w3d`** (o `whisk3d whiskpaddle.w3d`): abre el proyecto y
   arranca JUGANDO solo (un proyecto con scripts entra en modo Juego + play).
2. Tu pala se mueve con las **flechas** o el **stick izquierdo** del gamepad
   (analogico: mas fuerte = mas rapido). Pausa con la barra espaciadora.
3. Con el mouse **sobre el viewport**, el teclado es del juego (los atajos del
   editor no se disparan). Fuera del viewport, el editor se usa normal.
4. **Pausa** (barra espaciadora) congela; los botones `<` `>` del timeline van
   **frame a frame**: adelante re-simula, atras **viaja en el tiempo** (el
   editor graba un snapshot por frame). PLAY desde un frame anterior descarta
   el futuro grabado y se sigue jugando desde ahi.
5. **Stop** (el boton `|<` inicio) devuelve TODO al estado inicial.

## Como esta armado

Tres PANTALLAS (escenas), cada una un `.w3dui` con su script:

- `menu.w3dui` + `menu.lua` — 1 jugador / 2 jugadores / idioma.
- `dificultad.w3dui` + `dificultad.lua` — facil / normal / dificil.
- `juego.w3dui` + `juego.lua` — la partida (las REGLAS del pong y nada mas).
- `sonidos.lua` — el boton de sonido; va como 2do script de las tres escenas.
- `whiskpaddle.w3d` — el proyecto: lista las tres escenas y cual arranca.

La regla del ejemplo: **el layout vive en el `.w3dui`, el lua solo tiene juego**.
El lienzo es la PANTALLA REAL (`igualQueRender` prendido): el juego ocupa toda la
pantalla del celu, sin barras negras. Para que eso funcione las medidas del
`.w3dui` son RELATIVAS (`tamPx` apagado: fracciones del padre) y los textos usan
`autoTam` (se ajustan a su caja); las posiciones y los tamanos salen de las
anclas y del layout en filas/columnas del `.w3dui`. El lua NO deriva ni un borde:
cuando una regla necesita una zona, le pasa el OBJETO que la representa y el
motor lee su caja ya resuelta —`limitar(pala, cancha)`,
`rebotarEn(pelota, cancha, "arriba abajo")`, `dentro(cancha, x)`— y si le hace
falta el centro de algo, lo LEE con `cajaUI(objeto)`. La UNICA cuenta de pixeles
que quedo en lua esta en `inicio()` de `juego.lua`: las velocidades (px/segundo)
y el lado de la pelota (cuadrada, no puede ser relativa por-eje) se multiplican
UNA vez por `escala()` (= lado menor de la pantalla / 480).

Y la fisica es del motor, no del script: a la pelota se le da una `velocidad()`
y el motor la mueve e informa los rebotes (`rebotar`, `rebotarEn`), con
`acelerar()` para el 5% por golpe. El lua no integra posiciones ni compara
rectangulos a mano.

API que usa el ejemplo (ademas de la stdlib segura de lua: base/table/string/math):
`objeto("prop")`, `posPx`/`setPosPx`, `tamPx`, `setTexto`, `mostrar`, `cajaUI`,
`apretado`, `limitar`, `dentro`, `velocidad`, `acelerar`, `rebotar`, `rebotarEn`,
`tecla`/`teclaApretada`, `stick`, `dedo`, `boton`/`botonApretado`, `beep`,
`azar`, `config`/`setConfig`/`guardarConfig`, `silenciar`/`estaMudo`,
`cambiarEscena`, `salir`. Coordenadas en pixeles del lienzo con (0,0) en el centro.

La tabla `propiedades` del `.lua` es lo que el editor expone estilo Unity:

```lua
propiedades = {
  pelota     = "objeto",                         -- referencia a un objeto
  dificultad = { "normal", "facil", "dificil" }, -- menu desplegable
}
```

En cada `.w3dui`, el array `scripts` dice que `.lua` corre y a que objeto de la
escena apunta cada una de esas propiedades (`refs`).

## Compilar el juego

Con el UI seleccionado, el boton **Compilar juego** (tarjeta UI) hace todo e
informa el progreso: exporta el `.w3dui`, compila cada `.lua` a `.luac`
(bytecode) y empaqueta todo en `build/WhiskPaddle.w3dgame` (un solo archivo ofuscado).
Los `.lua` originales quedan legibles en el proyecto: son EL asset.

Sin el editor tambien se puede (el compilado es independiente):

```sh
luac -s -o build/whiskpaddle.luac whiskpaddle.lua     # el luac compila junto al editor
```

y el engine del juego se compila como siempre (ver `Whisk3D-Examples/core`).
El interprete lua vive en `Whisk3DCore` (Lua 5.4 vendorizado, C plano): el
mismo runtime corre en PC, web y Symbian; lo que no corre en el N95 es el
EMPAQUETADO del editor, no el juego.


## Compilar el juego SIN el editor

El whiskpaddle es un juego Whisk3D 2D: una interfaz (`.w3dui`) + un script Lua. El runtime
`examples/game/w3drun` reusa el mismo render 2D y el mismo interprete lua del editor,
asi que el juego corre solo en PC y en la web con el mismo codigo.

**Linux (OpenGL):**
```sh
cd examples/ui/whiskpaddle
cmake -S . -B build && cmake --build build -j
./build/whiskpaddle
```

**WebGL (Emscripten):**
```sh
source /ruta/a/emsdk/emsdk_env.sh
cd examples/ui/whiskpaddle
./build_web.sh              # -> web/whiskpaddle.html
python -m http.server      # y abri http://localhost:8000/web/whiskpaddle.html
```

Ambos builds apuntan al repo del editor (`../../../Whisk3D`) por el Core, la UI 2D y
lua. Desde el editor, el boton **Compilar juego** (tarjeta Juego) automatiza esto y
deja elegir la plataforma (Linux .deb / AppImage / WebGL).
