# Hola — el ejemplo mas simple de Whisk3D

El "hola mundo" de un juego Whisk3D: una UI con un cuadro y ~15 lineas de lua.
Para correrlo: abri `hola.w3d` en el editor y dale **Play**; mové el cuadro con las flechas **arriba/abajo**.

El contrato de un juego (mira `hola.lua`):
- `propiedades` = tabla que declara los objetos de la escena que usa el script (por nombre).
- `inicio()` = corre UNA vez al dar Play (aca solo suena un beep).
- `actualizar(dt)` = corre CADA frame; `dt` son los segundos desde el frame anterior.
