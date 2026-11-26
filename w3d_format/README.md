# Ejemplos en formato .w3d

Proyectos del editor Whisk3D listos para compilar a cualquier sistema desde el editor, sin escribir C++. Cada carpeta tiene un `.w3d`: un solo archivo con la escena, las mallas, los scripts de Lua y el HUD adentro.

| Ejemplo | Qué tiene |
| --- | --- |
| **cubo** | Un cubo que gira con un script de Lua (`girar.lua`, colgado del cubo), una luz y la cámara. |

## Compilar

1. Abrí el `.w3d` en el editor (Archivo > Abrir).
2. En la tarjeta **Juego**, elegí con qué escena o juego **Empieza**, la **Plataforma** y el **Backend gráfico**.
3. Tocá **Compilar juego**. La barra de abajo muestra el avance.

El resultado queda al lado del proyecto, en `build/<plataforma>/`. Lo intermedio queda en `platform-build/<plataforma>/`: el código generado, el Makefile o el CMakeLists y el `build.log`. Las dos carpetas se regeneran y están en el `.gitignore`.

## Plataformas

Se compila desde Linux. Cada kit es libre y queda afuera del proyecto: lo baja el script `preparar_*` de `Whisk3D/platform/<plataforma>/`.

| Plataforma | Backends | Resultado | Kit |
| --- | --- | --- | --- |
| Linux (.deb / AppImage) | OpenGL, OpenGL ES 2.0, Vulkan | el ejecutable y el `.deb` | gcc, cmake y SDL2 del sistema |
| Windows | OpenGL, OpenGL ES 2.0, Vulkan | `<juego>/<juego>.exe` y un `.zip` | llvm-mingw y SDL2 (`platform/windows/preparar_mingw.sh`) |
| WebGL | WebGL | `.html`, `.js` y `.wasm` | emsdk en `~/emsdk` |
| Android | OpenGL ES 1.1, OpenGL ES 2.0, Vulkan | `.apk` | el NDK y el SDK de Android |
| Android 2.3 | OpenGL ES 2.0 | `.apk` (ARMv6, API 10) | `platform/android-viejo` |
| PSP | sceGu (GE) | `PSP/GAME/<juego>/EBOOT.PBP` y un `.zip` | pspdev (`preparar_psp.sh`) |
| PS Vita | vitaGL | `.vpk` | VitaSDK (`preparar_vita.sh`) |
| Nintendo 3DS | citro3d | `.3dsx` | devkitARM (`preparar_3ds.sh`) |
| Dreamcast | GLdc | `.cdi` y `.elf` | KallistiOS (`preparar_dreamcast.sh`) |
| Symbian | OpenGL ES 1.1, OpenGL ES 2.0 | un kit para compilar en Windows | el SDK de S60 (en Windows) |

### Vulkan

Con Vulkan el juego lleva los tres backends: arranca en Vulkan y, si la máquina no lo tiene (sin el driver o sin la GPU), sigue con OpenGL (OpenGL ES 2.0 en Android). Vulkan compila sus shaders mientras corre, con shaderc. Para que vaya adentro del juego, compilalo una vez para cada plataforma:

```sh
bash Whisk3D/tools/preparar_shaderc.sh linux windows android
```

Queda en `~/shaderc`. Sin eso el juego busca shaderc instalado en el sistema (`libshaderc_shared`, o `shaderc_shared.dll` al lado del `.exe`), y si no lo encuentra dibuja con OpenGL.

## Para correrlo

- **Windows:** el `.exe` no necesita DLLs al lado. Funciona en Windows 10 y 11; en Windows 7 y 8.1 hace falta la actualización del runtime de C universal (KB2999226).
- **PSP:** la carpeta `PSP` del `.zip` va en la raíz del Memory Stick, de modo que quede `PSP/GAME/<juego>/EBOOT.PBP`. La consola necesita un firmware modificado (como 6.61 PRO) o HEN activo: con el firmware oficial, todo programa casero aparece como "Datos dañados".
- **PS Vita:** el `.vpk` se instala con VitaShell. vitaGL necesita el compilador de shaders del sistema (`ur0:data/external/libshacccg.suprx`). No viene con la consola: se instala una vez con la aplicación ShaRKBR33D. Las versiones viejas de ShaRKBR33D lo dejaban en `ur0:data/libshacccg.suprx`: si está ahí, el juego lo copia solo a `ur0:data/external/` la primera vez.
- **Nintendo 3DS:** el `.3dsx` va en `sdmc:/3ds/` y se abre desde el Homebrew Launcher. El juego se dibuja en la pantalla de arriba.
- **Dreamcast:** el `.cdi` lo abren los emuladores (Flycast) y se puede grabar en un CD-R o cargar en un GDEMU.
- **Symbian:** en `build/symbian/` quedan el proyecto (`juego.w3d`), el instalador (`<juego>.pkg`) y `build_symbian.bat`. En Windows, con el SDK de S60, el `.bat` compila la app de Whisk3D y arma `<juego>.sisx`. Es Whisk3D en modo juego: la app abre el proyecto sola a pantalla completa. Tiene la misma UID que el editor, así que instalar el juego reemplaza al editor en el teléfono.

En las consolas, el log del juego compilado en modo debug queda en su carpeta de datos: al lado del `EBOOT.PBP` en la PSP, en `ux0:data/<juego>` en la Vita y en `sdmc:/3ds/<juego>` en la 3DS. En la Dreamcast sale por el puerto serie.
