# Calculadora, una interfaz con el editor Whisk3D + logica en lua

Ejemplo didactico, un escalon arriba de `ui/hola`: una calculadora basica estilo
telefono (display arriba, grilla de botones abajo) hecha con DOS archivos:

- `calculadora.w3dui` (la INTERFAZ), 100% con el layout del editor: dos textos
  anclados arriba (Historial y Display) y un contenedor en FILAS con 5 filas de
  botones, cada fila un contenedor en COLUMNAS con `weight`/`expand`/`gap`.
  El lienzo es la pantalla real (`sameAsRender` prendido): el layout se acomoda
  solo a cualquier pantalla.
- `calculadora.lua` (SOLO la logica): lee los botones con `pressed()` y escribe
  los textos con `setText()`. CERO posiciones ni cuentas de layout en lua.
- `calculadora.w3d` (el proyecto para abrirlo en el editor).

La raiz del proyecto queda limpia: el `.w3d` + este README. La escena, el lua y
`assets/` (icono) viven en `contenido/`.

El script va embebido en el `.w3dui` (array raiz `"scripts"` con `path` + `refs`):
las `refs` conectan cada propiedad del lua (`b7`, `mas`, `display`...) con el
objeto de la escena por su nombre (`Btn7`, `BtnMas`, `Display`...).

## Abrirlo en el editor

Doble click en `calculadora.w3d` (o `whisk3d calculadora.w3d`): abre el proyecto
y arranca jugando (Play). Los botones responden al mouse sobre el viewport.

## Compilarlo

**Compilar juego** en la tarjeta **Juego** del editor: elegis la plataforma
(Linux, Windows, WebGL, Android, consolas...) y el resultado queda en
`build/<plataforma>/`. Es el MISMO `.w3dui` + `.lua` que se abren en el editor,
corriendo solos.
