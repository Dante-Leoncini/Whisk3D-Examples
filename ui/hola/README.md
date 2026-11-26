# Hola — el ejemplo mas simple de Whisk3D

El "hola mundo" de un juego Whisk3D: una UI con un cuadro y ~15 lineas de lua.
Para correrlo: abri `hola.w3d` en el editor y dale **Play**; move el cuadro con las flechas **arriba/abajo**.

La raiz del proyecto es solo `hola.w3d` + este README; la escena (`hola.w3dui`)
y el script (`hola.lua`) viven en `contenido/`.

El contrato de un juego (mira `contenido/hola.lua`):
- `properties` = tabla que declara los objetos de la escena que usa el script (por nombre).
- `start()` = corre UNA vez al dar Play (aca solo suena un beep).
- `update(dt)` = corre CADA frame; `dt` son los segundos desde el frame anterior.

Para compilarlo a un sistema (Linux, Windows, WebGL, Android, consolas...): **Compilar juego**
en la tarjeta **Juego** del editor. El resultado queda en `build/<plataforma>/`.
