# Consola, log + modo debug con el editor Whisk3D

Ejemplo didactico, un escalon como `ui/calculadora`: cuatro botones que emiten
mensajes al LOG del Core y un panel "Pantalla" que muestra las ultimas 8 lineas
del ring buffer del log, con DOS archivos:

- `consola.w3dui` (la INTERFAZ): titulo, una columna de 4 botones (INFO celeste,
  AVISO amarillo, ERROR rojo, DEPURAR gris) y el panel oscuro con 8 textos
  (`Linea1..Linea8`, uno por linea: `setText()` no interpreta `\n`).
- `consola.lua` (SOLO la logica): cada boton llama a `info()` / `warning()` /
  `error()` / `debugLog()`; el panel se refresca leyendo `logCount()` +
  `logLine(i)`.
- `consola.w3d` (el proyecto para abrirlo en el editor).

La raiz del proyecto queda limpia: el `.w3d` + este README. La escena, el lua y
`assets/` (icono) viven en `contenido/`.

## Debug vs produccion (el punto del ejemplo)

El MISMO `.w3dui` + `.lua` corren en los dos builds; la macro `W3D_DEV_LOG` del
Core (`base/w3dlog.h`) decide que se ve:

|                        | build DEBUG (`W3D_DEV_LOG=1`) | build PRODUCCION (`W3D_DEV_LOG=0`) |
|------------------------|-------------------------------|------------------------------------|
| `info/warning/error`   | al log del sistema + al ring  | no emiten (el sink desaparece)     |
| `debugLog()`           | emite (prefijo `debug:`)      | no-op                              |
| `isDebug()`            | `true`                        | `false`                            |
| boton DEPURAR          | visible                       | oculto (`show(btn, isDebug())`) |
| panel "Pantalla"       | las ultimas 8 lineas del log  | "consola apagada (produccion)"     |

En el editor (Play) siempre se ve todo: el editor compila con el default
`W3D_DEV_LOG=1`. En la tarjeta Juego del editor, el checkbox "Modo debug"
(default destildado = produccion) define la misma macro al Compilar juego.

## Abrirlo en el editor

Doble click en `consola.w3d` (o `whisk3d consola.w3d`): abre el proyecto y
arranca jugando (Play). Los botones responden al mouse sobre el viewport.

## Compilarlo

**Compilar juego** en la tarjeta **Juego** del editor: elegis la plataforma
(Linux, Windows, WebGL, Android, consolas...) y el resultado queda en
`build/<plataforma>/`. El checkbox **Modo debug** de esa tarjeta decide el build:
tildado, DEBUG (se ve todo); destildado, PRODUCCION. Es el MISMO `.w3dui` + `.lua`
que se abren en el editor, corriendo solos.
