# Pong — scripts lua en Whisk3D

El "hola mundo" de los scripts de Whisk3D: un pong completo hecho con la UI 2D
del editor y UN archivo lua. Vos jugas con las **flechas arriba/abajo**; la
computadora juega la otra pala (dificultad configurable desde el editor).

## Como probarlo

1. **Doble click en `pong.w3d`** (o `whisk3d pong.w3d`): abre el proyecto y
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

- `pong.w3d` — EL PROYECTO: el objeto **Script** (con el `.lua` y sus
  referencias) ANTES de la UI, la UI referenciada, el layout y el fps.
- `pong.w3dui` — la interfaz: una UI negra de 480x480 con la fila de
  marcadores (2 textos), la linea central, las 2 palas y la pelota.
- `pong.lua` — TODA la logica, legible y comentada para estudiar.

El script va colgado del objeto **Script** (tarjeta **Script** del panel).
El orden de ejecucion de los scripts es el del arbol del outliner. La tabla
`propiedades` del .lua es lo que el editor expone estilo Unity:

```lua
propiedades = {
  jugador1   = "objeto",                         -- referencia a un objeto
  dificultad = { "normal", "facil", "dificil" }, -- menu desplegable
}
```

API disponible (ademas de la stdlib segura de lua: base/table/string/math):
`pantalla()`, `posPx(o)`, `setPosPx(o,x,y)`, `tamPx(o)`, `setTamPx(o,w,h)`,
`setTexto(o,v)`, `tecla("arriba")`, `objeto("prop")`, `opcion("prop")`.
Coordenadas en pixeles del lienzo con (0,0) en el centro.

## Compilar el juego

Con el UI seleccionado, el boton **Compilar juego** (tarjeta UI) hace todo e
informa el progreso: exporta el `.w3dui`, compila cada `.lua` a `.luac`
(bytecode) y empaqueta todo en `build/Pong.w3dgame` (un solo archivo ofuscado).
Los `.lua` originales quedan legibles en el proyecto: son EL asset.

Sin el editor tambien se puede (el compilado es independiente):

```sh
luac -s -o build/pong.luac pong.lua     # el luac compila junto al editor
```

y el engine del juego se compila como siempre (ver `Whisk3D-Examples/core`).
El interprete lua vive en `Whisk3DCore` (Lua 5.4 vendorizado, C plano): el
mismo runtime corre en PC, web y Symbian; lo que no corre en el N95 es el
EMPAQUETADO del editor, no el juego.
