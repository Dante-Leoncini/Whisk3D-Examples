# WhiskPaddle — scripts lua en Whisk3D

Un pong completo hecho con la UI 2D del editor y scripts lua: menu, dificultad y
partida, para 1 jugador (contra la maquina) o 2 jugadores en la misma pantalla.

## Como probarlo

1. **Doble click en `whiskpaddle.w3d`** (o `whisk3d whiskpaddle.w3d`): abre el proyecto y
   arranca JUGANDO solo (un proyecto con scripts entra en modo Juego + play).
2. En el menu, **flechas arriba/abajo** y **Enter** (o espacio, o el boton A del mando),
   o se toca la opcion.
3. Tu pala se mueve con las **flechas**, el **stick** del mando (analogico: mas
   fuerte = mas rapido) o el **dedo** en su mitad de la pantalla. En 2 jugadores, la
   izquierda va con **W/S**. **Pausa** con la tecla **P** o su boton.
4. Con el mouse **sobre el viewport**, el teclado es del juego (los atajos del
   editor no se disparan). Fuera del viewport, el editor se usa normal.
5. Con el juego en pausa, los botones `<` `>` del timeline van **frame a frame**:
   adelante re-simula, atras **viaja en el tiempo** (el editor graba un snapshot
   por frame). PLAY desde un frame anterior descarta el futuro grabado y se sigue
   jugando desde ahi.
6. **Stop** (el boton `|<` inicio) devuelve TODO al estado inicial.

## Como esta armado

La raiz del proyecto queda limpia: `whiskpaddle.w3d` + este README. Todo lo
demas vive en `contenido/` (escenas `.w3dui`, scripts `.lua` y `assets/` con
las texturas y el icono), y `versiones/` (si guardaste versiones) los snapshots
del proyecto. `platform/android/` es la plantilla Android que usa **Compilar juego**
del editor para cualquier juego (ver abajo).

Tres PANTALLAS (escenas), cada una un `.w3dui` con su script (en `contenido/`):

- `menu.w3dui` + `menu.lua` — 1 jugador / 2 jugadores / idioma.
- `dificultad.w3dui` + `dificultad.lua` — facil / normal / dificil.
- `juego.w3dui` + `juego.lua` — la partida (las REGLAS del pong y nada mas).
- `sonidos.lua` — el boton de sonido; va como 2do script de las tres escenas.
- `whiskpaddle.w3d` — el proyecto: lista las tres escenas y cual arranca.

La regla del ejemplo: **el layout vive en el `.w3dui`, el lua solo tiene juego**.
El lienzo es la PANTALLA REAL (`sameAsRender` prendido): el juego ocupa toda la
pantalla del celu, sin barras negras. Para que eso funcione las medidas del
`.w3dui` son RELATIVAS (`sizePx` apagado: fracciones del padre) y los textos usan
`autoSize` (se ajustan a su caja); las posiciones y los tamanos salen de las
anclas y del layout en filas/columnas del `.w3dui`. El lua NO deriva ni un borde:
cuando una regla necesita una zona, le pasa el OBJETO que la representa y el
motor lee su caja ya resuelta —`limit(paddle, court)`,
`bounceOn(ball, court, "top bottom")`, `inside(court, x)`— y si le hace
falta el centro de algo, lo LEE con `uiBox(obj)`. La UNICA cuenta de pixeles
que quedo en lua esta en `start()` de `juego.lua`: las velocidades (px/segundo)
y el lado de la pelota (cuadrada, no puede ser relativa por-eje) se multiplican
UNA vez por `getScale()` (= lado menor de la pantalla / 480).

Y la fisica es del motor, no del script: a la pelota se le da una velocidad
(`getVelocity(obj, vx, vy)`) y el motor la mueve e informa los rebotes (`bounce`,
`bounceOn`), con `accelerate()` para el 5% por golpe. El lua no integra posiciones
ni compara rectangulos a mano.

API que usa el ejemplo (ademas de la stdlib segura de lua: base/table/string/math):
`object("prop")`, `getPosPx`/`setPosPx`, `getSizePx`/`setSizePx`, `setText`, `show`,
`uiBox`, `pressed`, `limit`, `inside`, `getVelocity`, `accelerate`, `bounce`,
`bounceOn`, `key`/`keyPressed`, `stick`, `finger`, `button`/`buttonPressed`, `beep`,
`random`, `getConfig`/`setConfig`/`saveConfig`, `mute`/`isMuted`, `getScale`,
`changeScene`, `quit`. Coordenadas en pixeles del lienzo con (0,0) en el centro.

La tabla `properties` del `.lua` es lo que el editor expone estilo Unity:

```lua
properties = {
  pelota     = "object",                         -- referencia a un objeto
  dificultad = { "normal", "facil", "dificil" }, -- menu desplegable
}
```

En cada `.w3dui`, el array `scripts` dice que `.lua` corre y a que objeto de la
escena apunta cada una de esas propiedades (`refs`).

## Compilar el juego

**Compilar juego** en la tarjeta **Juego** del editor: elegis la plataforma
(Linux, Windows, WebGL, Android, PSP, PS Vita, 3DS, Dreamcast, Symbian) y el
resultado queda en `build/<plataforma>/` (lo intermedio, en `platform-build/`).
El juego compilado corre con el runtime `game/w3drun` de este repo: el mismo
render 2D y el mismo interprete lua del editor.

`platform/android/` es la plantilla del proyecto Android (gradle, la Activity de
SDL, el manifest y los iconos): **Compilar juego** la copia para cada juego, le
pone su nombre y su icono, y genera su `Android.mk`.
