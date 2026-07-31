# Guia: anclar el layout del WhiskPaddle en el .w3dui (sin lua)

Objetivo: que la POSICION y el TAMANO de cada pieza vivan en el `.w3dui` (anclas + flexbox,
armados en el Editor 2D) y NO en `whiskpaddle.lua`. El lua se queda SOLO con lo que se mueve
(palas en Y, pelota) y lee del layout donde termina la cancha.

Todo esto ya funciona igual en el editor y corriendo solo (el mismo `UIOverlay` dibuja en los
dos lados). No hace falta tocar el motor: ya se agrego `cajaUI()` para el contrato con el lua
(ver el final).

> **ESTADO: aplicado (y con cambios).** El ejemplo ya no calcula layout en lua.
> Lo que finalmente se hizo difiere de este documento en dos puntos:
> 1. Se uso la regla responsive de la seccion 0 con `igualQueRender = true`: el
>    lienzo ES la pantalla real (el juego llena el celu, sin barras negras), las
>    medidas van RELATIVAS (`tamPx` apagado) y los textos con `autoTam`. (Antes se
>    probo la alternativa del lienzo FIJO 640x480 con letterbox, pero en el celu
>    dejaba el juego chico entre bandas negras y se volvio a las relativas.) Lo
>    UNICO en px que ajusta el lua: velocidades y lado de la pelota, una vez en
>    `inicio()` de `juego.lua` multiplicando por `escala()`.
> 2. `chocan()`, `limitar()` (el objeto limitado) y la fisica trabajan con la
>    posicion CRUDA del objeto (`pos` x lienzo), NO con la que resuelve el layout.
>    Por eso lo que el lua MUEVE (palas, pelota) y lo que SIGUE con `cajaUI`/
>    `setPosPx` (Sel de los menus, cartel) es hijo DIRECTO de la raiz con `ancla`
>    = centro; `apretado()` en cambio usa la caja RESUELTA, asi que los botones si
>    pueden vivir en el flex de la Barra. Los nombres de objetos de la seccion 7
>    cambiaron: ver los `refs` de cada `.w3dui`.

---

## 0) La regla responsive (importante)

Con la ventana en modo "igual que el render" (`igualQueRender = true`, como esta hoy) el lienzo
del juego ES la zona segura y la escala interna es 1:1. Consecuencia:

- Los tamanos en PIXELES (`tamPx` prendido, y el `tam` del texto) quedan FIJOS: no escalan con la
  pantalla. En un celu grande se ven chicos.
- Los tamanos RELATIVOS (`tamPx` apagado: ancho/alto son fraccion del padre, 1 = 100%) y el texto
  con `autoTam` SI escalan solos.

Por eso, para que quede responsive sin lua:
- Rectangulos / palas / linea / barra -> `tamPx` APAGADO (medidas relativas, ej. 0.15 = 15%).
- Textos (marcadores, titulos, opciones) -> `autoTam` PRENDIDO (se ajustan a su celda).

(Alternativa: poner la ventana en modo responsive `igualQueRender = false` con un lienzo fijo, ej.
480x800. Ahi los px SI escalan (con letterbox / barras negras). Elegir uno u otro, no mezclar.)

---

## 1) La raiz = la zona segura (ya es automatica)

El runtime dibuja TODA la interfaz DENTRO del rect seguro (descuenta notch/barras del celu). O sea:
el rect del UI raiz YA es la zona segura. Todo lo que ancles al UI (o a un contenedor que llene el
UI) cae automaticamente adentro de la zona segura. No hay que hacer nada especial.

---

## 2) Partir la pantalla: cancha arriba + barra abajo (flex en filas)

Contenedor raiz del juego, "Juego":
- `ancla` = centro, `ancho` = 1, `alto` = 1, `tamPx` APAGADO  -> llena la zona segura.
- `layoutHijos` = FILAS. `layoutAjuste` = estirar.  -> reparte a sus hijos de arriba hacia abajo por PESO.

Hijos de "Juego" (en este orden):
1. Contenedor "Cancha"  -> `peso` = 85  (el area de juego, arriba)
2. Contenedor "Barra"   -> `peso` = 15  (la barra de controles, abajo)

Asi la barra mide ~15% del alto de la zona segura y la cancha el resto, y se re-ajusta solo cuando
cambia la pantalla. (Si queres la barra con alto MINIMO fijo en vez de porcentaje: `layoutAjuste` =
minimo en "Juego", darle a "Barra" un `alto` relativo y poner un elemento "Expandir" como primer
hijo de "Juego" para que la cancha absorba el resto.)

---

## 3) La barra de abajo por dentro (flex en columnas + expandir)

Contenedor "Barra":
- `layoutHijos` = COLUMNAS. `layoutAjuste` = minimo. `layoutAlign` = centro.
- Sus hijos se ponen en fila horizontal y quedan CENTRADOS en vertical solos (los textos y botones
  se centran en su celda). Con `gap` se separan.

Hijos de "Barra" (izquierda a derecha), usando "Expandir" para empujar y distribuir:
- Boton "BtnSonido" (con su icono "SonIcono")   -> pegado a la izquierda
- Expandir  -> empuja
- "Marcador 1"  (texto, `autoTam`)
- "Marcador 2"  (texto, `autoTam`)
- Expandir  -> empuja
- Boton "BtnPausa" (con "PausaBar1"/"PausaBar2" o un icono) -> pegado a la derecha

Para los marcadores juntos y centrados, se pueden meter en un sub-contenedor "Marcadores"
(columnas, con su gap) y ese contenedor va entre los dos Expandir.

Nota: una IMAGEN o un RECT dentro de una celda de layout la LLENA entera (se puede deformar). Para
iconos que deben mantener su forma (mute, pausa), usar un BOTON con icono (el boton centra el icono
y le respeta el tamano) en vez de una imagen suelta.

La linea fina arriba de la barra ("BarraLinea"): rect, primer hijo de "Barra" con `ancla` = arriba,
`ancho` = 1 relativo, alto finito. O dejarla como hoy (rect suelto) anclada al borde superior de la
barra. Sirve ademas de marca visual para que el lua lea el borde de la cancha (ver contrato).

---

## 4) La cancha por dentro (libre)

Contenedor "Cancha":
- `layoutHijos` = LIBRE (cada hijo con su ancla + posicion).

Hijos:
- "Linea" (linea central vertical): rect, `ancla` = centro, `ancho` FINO relativo (ej. 0.006),
  `alto` = 1 relativo. Al ser hija de "Cancha" ocupa SOLO la cancha (arriba de la barra) y se estira
  con ella. `tamPx` APAGADO.
- "Pala 1": rect, `ancla` = izquierda (queda pegada al borde izq de la cancha). Ancho/alto RELATIVOS
  (ej. ancho 0.02, alto 0.16). La Y la mueve el lua (queda centrada si el lua no la toca).
- "Pala 2": igual pero `ancla` = derecha.
- "Pelota": rect, `ancla` = centro. Tamano relativo chico. La posicion la maneja el lua.
- "MensajeBg" / "Mensaje": `ancla` = centro (cartel de la cuenta regresiva / fin).

Ojo: los objetos que el lua MUEVE con `setPosPx` (palas, pelota) tienen que quedar con `ancla` =
centro respecto a un contenedor que llene el mismo espacio que ve el lua. La forma segura hoy: que
"Cancha" NO cambie el sistema de coordenadas del lua -> palas y pelota como hijas de "Cancha" con
ancla en el borde (palas) o centro (pelota). El lua sigue usando `posPx/setPosPx` en px del lienzo.

---

## 5) Los menus

"MenuInicial" y "MenuDificultad" son contenedores que se prenden/apagan (eso lo sigue haciendo el
lua con `mostrar`). Adentro se pueden anclar/flexar igual: contenedor en FILAS, titulo arriba, y las
opciones (MI1/MI2/MI3, MD1/MD2/MD3) como celdas centradas con `autoTam`. El rect de seleccion
(SelMI/SelMD) se ancla detras de la opcion activa.

---

## 6) Contrato lua <-> UI

El lua ya NO calcula la barra (`barH = 84 * escala()`). En vez de eso LEE del layout donde termina la
cancha, con la funcion nueva del runtime:

    cajaUI(objeto)  ->  x, y, ancho, alto
    -- x,y = CENTRO del objeto (igual que posPx); ancho,alto = su tamano (igual que tamPx),
    -- pero YA RESUELTOS por el layout (anclas/flex). En coords de lienzo (centro 0,0, +y abajo).

El borde de la cancha (piso) sale de la barra / de la linea:

    -- opcion A (leyendo la linea de arriba de la barra):
    local _, piso = cajaUI(objeto("BarraLinea"))

    -- opcion B (leyendo la barra entera):
    local _, cy, _, ah = cajaUI(objeto("Barra"))
    local piso = cy - ah / 2      -- borde superior de la barra

De ahi el lua saca los limites: techo = borde de arriba de la cancha (via `areaSegura()` o
`cajaUI(objeto("Cancha"))`), piso = lo de arriba. Palas/pelota rebotan y se limitan contra eso.

IMPORTANTE: `cajaUI` es del ULTIMO frame dibujado (1 frame de atraso, como `areaSegura()`). No usar
en `inicio()` (todavia no se dibujo nada); usarlo en `actualizar(dt)`.

---

## 7) Nombres que la UI DEBE conservar

El lua encuentra los objetos por su `nombre` en el `.w3dui`, resuelto en `main.cpp` con `W3dGameRef`.
Si renombras un objeto en el editor, tenes que renombrarlo tambien en `main.cpp` (y viceversa), sino
el lua recibe `nil`. Nombres que hoy espera el lua:

- Juego / palas / pelota: `Juego`, `Pala 1`, `Pala 2`, `Pelota`
- Marcadores y cartel: `Marcador 1`, `Marcador 2`, `Mensaje`, `MensajeBg`
- Barra / cancha: `BarraLinea`, `Linea`   (si agregas contenedores `Cancha` / `Barra` para leerlos
  con `cajaUI`, agregales su `W3dGameRef` en `main.cpp`)
- Botones: `BtnSonido`, `SonIcono`, `BtnPausa`, `PausaBar1`, `PausaBar2`
- Menus: `MenuInicial`, `MenuDificultad`, `TituloMI`, `TituloMD`,
  `MI1`, `MI2`, `MI3`, `MD1`, `MD2`, `MD3`, `SelMI`, `SelMD`, `PausaOp1`, `PausaOp2`

Los nombres NUEVOS que quieras leer desde el lua (ej. `Cancha`, `Barra`) hay que darlos de alta en
`main.cpp` con una linea `W3dGameRef("nombreEnLua", "Nombre En El w3dui");` en el bloque del script
que los use.
