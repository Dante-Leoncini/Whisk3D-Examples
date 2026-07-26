-- ============================================================
--  PONG — demo completa de los scripts lua de Whisk3D.
--
--  Hay TRES UIs (contenedores) y el script solo prende/apaga su
--  visibilidad, con un CROSSFADE de opacidad entre ellas:
--    * Juego         : palas, pelota, marcadores, mensaje.
--    * MenuInicial   : titulo PONG + 1/2 jugadores + idioma.
--    * MenuDificultad : facil / normal / dificil (solo 1 jugador).
--
--  IDIOMAS: espanol / english / portugues (opcion del menu, o las
--  flechas IZQUIERDA/DERECHA). SONIDO estilo Pong (beep()).
--
--  CONTROLES
--   Jugador 1 (izq): W / S  (o stick izq, o dedo mitad izquierda)
--   Jugador 2 (der): flechas ARRIBA / ABAJO  (o stick der, o dedo
--                    mitad derecha).   Menu: flechas + ESPACIO.
--                    Pausa: P.
-- ============================================================

propiedades = {
  jugador1  = "objeto", jugador2 = "objeto", pelota = "objeto",
  marcador1 = "objeto", marcador2 = "objeto",
  juego     = "objeto",                          -- UI del juego (palas/pelota/marcadores): se oculta en los menus
  menuIni   = "objeto",                          -- UI menu inicial (contenedor)
  menuDif   = "objeto",                          -- UI dificultad (contenedor)
  mensaje   = "objeto",                          -- texto grande de cuenta / pausa / fin
  mensajeBg = "objeto",                          -- marco negro detras del mensaje (para leerlo sobre la linea)
  mi1 = "objeto", mi2 = "objeto", mi3 = "objeto",-- opciones del menu inicial (columna)
  md1 = "objeto", md2 = "objeto", md3 = "objeto",-- opciones de dificultad (columna)
  selMI = "objeto", selMD = "objeto",            -- recuadro blanco que marca la opcion elegida
  titMI = "objeto", titMD = "objeto",            -- titulos (PONG / DIFICULTAD): se escalan a la ventana
  btnPausa = "objeto", pausaBar1 = "objeto", pausaBar2 = "objeto",  -- boton de pausa (escala)
  dificultad = { "normal", "facil", "dificil" },
}

-- ---- IDIOMAS. La fuente 2D (Texto2D) tiene la Ñ/ñ como glifo DIRECTO, pero NO las vocales
-- acentuadas (Á/É/Í/Ó/Ú se descomponen solo en el otro path del editor) -> uso la ñ y ASCII en el resto,
-- asi las palabras se leen (con acento la vocal se comia: "FÁCIL" salia "FCIL").
local NOM = { es = "ESPAÑOL", en = "ENGLISH", pt = "PORTUGUES" }
local TXT = {
  es = { p1="1 JUGADOR", p2="2 JUGADORES", facil="FACIL", normal="NORMAL", dificil="DIFICIL",
         pausa="PAUSA", volver="ESPACIO: menu", gano="GANO EL JUGADOR ", idioma="IDIOMA" },
  en = { p1="1 PLAYER", p2="2 PLAYERS", facil="EASY", normal="NORMAL", dificil="HARD",
         pausa="PAUSE", volver="SPACE: menu", gano="WINNER: PLAYER ", idioma="LANGUAGE" },
  pt = { p1="1 JOGADOR", p2="2 JOGADORES", facil="FACIL", normal="NORMAL", dificil="DIFICIL",
         pausa="PAUSA", volver="ESPACO: menu", gano="GANHOU O JOGADOR ", idioma="IDIOMA" },
}
local IDIOMAS = { "es", "en", "pt" }
local idioma = "es"
local function t(k) return TXT[idioma][k] end
local function cambiarIdioma(paso)
  local i = 1
  for k, v in ipairs(IDIOMAS) do if v == idioma then i = k end end
  i = i + paso; if i < 1 then i = #IDIOMAS end; if i > #IDIOMAS then i = 1 end
  idioma = IDIOMAS[i]
end

local VEL_PALA, VEL_PELOTA, GANA = 360, 240, 7   -- VEL_* se RECALCULAN en adaptar() (relativo a la ventana)
local REF = 480          -- alto de referencia del diseño (el juego se escala respecto a esto)
local gEsc = 1           -- factor de escala actual = alto de la ventana / REF (lo pone adaptar)
local estado    = "menu"
local jugadores, dif, sel, ganador = 1, "normal", 1, 0
local cuenta    = 3.0
local vx, vy = 0, 0
local p1, p2 = 0, 0
local velPala1, velPala2 = 0, 0
local IA = { facil={vel=140,error=60}, normal={vel=210,error=25}, dificil={vel=300,error=4} }

-- ---- flanco de teclas ----
local TECLAS = { "arriba","abajo","izquierda","derecha","w","s","espacio","enter","p","1","2","3" }
local prevTecla, prevA, prevDedo = {}, false, false
local prevRx, prevRy = -9999, -9999   -- ultima pos del mouse (para detectar movimiento en el hover)
local function apreto(n) return tecla(n) and not prevTecla[n] end
local function apretoA() return boton("a") and not prevA end
local function dedoActivo() return (select(3, dedo(1))) end   -- 3er retorno de dedo(1) = activo
local function apretoDedo() return dedoActivo() and not prevDedo end   -- flanco: click/tap RECIEN apretado
local function guardarPrev()
  for _, k in ipairs(TECLAS) do prevTecla[k] = tecla(k) end
  prevA = boton("a"); prevDedo = dedoActivo()
end

-- ---- CROSSFADE entre UIs: fade out 'sale' + fade in 'entra', luego 'luego()' ----
local trans = nil
local function fade(sale, entra, luego)
  if entra then mostrar(entra, true); setOpacidad(entra, 0) end
  trans = { t = 0, dur = 0.22, sale = sale, entra = entra, luego = luego }
end
local function actualizarFade(dt)
  if not trans then return false end
  trans.t = trans.t + dt
  local k = trans.t / trans.dur; if k > 1 then k = 1 end
  if trans.sale  then setOpacidad(trans.sale,  1 - k) end
  if trans.entra then setOpacidad(trans.entra, k) end
  if k >= 1 then
    if trans.sale  then mostrar(trans.sale, false); setOpacidad(trans.sale, 1) end
    if trans.entra then setOpacidad(trans.entra, 1) end
    local f = trans.luego; trans = nil
    if f then f() end
  end
  return true
end

-- ---- menu: opciones en columna + RECUADRO blanco sobre la elegida (en vez de ">") ----
local OPBASE, OPSTEP = -9.6, 48   -- y(px) de la 1a opcion y paso entre opciones (coincide con la escena)
local function opcionEnY(y, n)    -- que opcion cae en la Y (para mouse-over / tap)
  local i = math.floor((y - OPBASE) / OPSTEP + 0.5) + 1
  if i < 1 then i = 1 end; if i > n then i = n end
  return i
end
local function pintarOps(o1, o2, o3, selector, lista)
  local ops = { o1, o2, o3 }
  local n = 0
  for i = 1, 3 do
    if lista[i] then setTexto(ops[i], lista[i]); mostrar(ops[i], true); n = i
    else mostrar(ops[i], false) end
  end
  if sel > n then sel = n end
  if sel < 1 then sel = 1 end
  setPosPx(selector, 0, OPBASE + (sel - 1) * OPSTEP)   -- el recuadro sigue a la seleccion
  mostrar(selector, true)
end

-- mensaje grande (cuenta / pausa / fin) con su MARCO NEGRO detras (asi se lee sobre la linea blanca)
local function ponerMensaje(txt, tam, w, h)
  setTam(objeto("mensaje"), tam * gEsc); setTexto(objeto("mensaje"), txt)
  setTamPx(objeto("mensajeBg"), w * gEsc, h * gEsc)
  mostrar(objeto("mensajeBg"), true); mostrar(objeto("mensaje"), true)
end
local function ocultarMensaje()
  mostrar(objeto("mensajeBg"), false); mostrar(objeto("mensaje"), false)
end

local function saque()
  setPosPx(objeto("pelota"), 0, 0)
  local lado = (math.random(2) == 1) and 1 or -1
  vx = VEL_PELOTA * lado
  vy = VEL_PELOTA * (math.random() * 1.2 - 0.6)
end

local function empezarPartido()
  p1 = 0; p2 = 0
  setTexto(objeto("marcador1"), 0); setTexto(objeto("marcador2"), 0)
  saque()
  local x1 = ({ posPx(objeto("jugador1")) })[1]
  local x2 = ({ posPx(objeto("jugador2")) })[1]
  setPosPx(objeto("jugador1"), x1, 0); setPosPx(objeto("jugador2"), x2, 0)
  cuenta = 3.0; estado = "cuenta"
end

function inicio()
  estado = "menu"; jugadores = 1; sel = 1; dif = opcion("dificultad")
  mostrar(objeto("juego"), false)                -- en el menu NO se ve la pista (linea/palas) -> se lee mejor
  mostrar(objeto("menuIni"), true);  setOpacidad(objeto("menuIni"), 1)
  mostrar(objeto("menuDif"), false)
  ocultarMensaje()
end

local function moverPala(pala, dy)
  local _, alto = pantalla()
  local x, y = posPx(pala); local _, altoPala = tamPx(pala)
  y = y + dy
  local tope = alto / 2 - altoPala / 2
  if y < -tope then y = -tope end
  if y >  tope then y =  tope end
  setPosPx(pala, x, y)
end
local function moverHacia(pala, objetivoY, dt)
  local _, y = posPx(pala)
  local paso = VEL_PALA * dt
  local dy = objetivoY - y
  if dy >  paso then dy =  paso end
  if dy < -paso then dy = -paso end
  moverPala(pala, dy)
end
local function inputJugador1(dt)
  if tecla("w") then moverPala(objeto("jugador1"), -VEL_PALA * dt) end
  if tecla("s") then moverPala(objeto("jugador1"),  VEL_PALA * dt) end
  if jugadores == 1 then
    if tecla("arriba") then moverPala(objeto("jugador1"), -VEL_PALA * dt) end
    if tecla("abajo")  then moverPala(objeto("jugador1"),  VEL_PALA * dt) end
  end
  local _, sy = stick("izq")
  if math.abs(sy) > 0.02 then moverPala(objeto("jugador1"), VEL_PALA * sy * dt) end
  for d = 1, 4 do local tx, ty, toc = dedo(d)
    if toc and (jugadores == 1 or tx < 0) then moverHacia(objeto("jugador1"), ty, dt) end end
end
local function inputJugador2(dt)
  if tecla("arriba") then moverPala(objeto("jugador2"), -VEL_PALA * dt) end
  if tecla("abajo")  then moverPala(objeto("jugador2"),  VEL_PALA * dt) end
  local _, sy = stick("der")
  if math.abs(sy) > 0.02 then moverPala(objeto("jugador2"), VEL_PALA * sy * dt) end
  for d = 1, 4 do local tx, ty, toc = dedo(d)
    if toc and tx >= 0 then moverHacia(objeto("jugador2"), ty, dt) end end
end
local function inputMaquina(dt)
  local ia = IA[dif] or IA.normal
  local bx, by = posPx(objeto("pelota"))
  local _, jy = posPx(objeto("jugador2"))
  local objetivo = by + ia.error * math.sin(bx * 0.05)
  if jy < objetivo - 6 then moverPala(objeto("jugador2"),  ia.vel * dt) end
  if jy > objetivo + 6 then moverPala(objeto("jugador2"), -ia.vel * dt) end
end

local function fisicaPelota(dt)
  local ancho, alto = pantalla()
  local x, y = posPx(objeto("pelota"))
  x = x + vx * dt; y = y + vy * dt
  if y < -alto / 2 and vy < 0 then vy = -vy; beep(459, 70, 0.5) end
  if y >  alto / 2 and vy > 0 then vy = -vy; beep(459, 70, 0.5) end
  local function pega(pala)
    local px, py = posPx(pala); local pw, ph = tamPx(pala)
    return math.abs(x - px) < pw and math.abs(y - py) < ph / 2 + 10
  end
  local function reboteConEfecto(pala, velDeLaPala)
    local _, py = posPx(pala); local _, ph = tamPx(pala)
    local donde = (y - py) / (ph / 2)
    if donde < -1 then donde = -1 end
    if donde >  1 then donde =  1 end
    beep(226, 90, 0.6)
    vx = -vx * 1.05
    vy = vy + donde * VEL_PELOTA * 0.9 + velDeLaPala * 0.45
    local topeY = math.abs(vx) * 1.4
    if vy >  topeY then vy =  topeY end
    if vy < -topeY then vy = -topeY end
  end
  if vx < 0 and pega(objeto("jugador1")) then reboteConEfecto(objeto("jugador1"), velPala1) end
  if vx > 0 and pega(objeto("jugador2")) then reboteConEfecto(objeto("jugador2"), velPala2) end
  if x < -ancho / 2 then
    p2 = p2 + 1; setTexto(objeto("marcador2"), p2); beep(490, 250, 0.7); saque()
    if p2 >= GANA then ganador = 2; estado = "fin" end; return
  end
  if x > ancho / 2 then
    p1 = p1 + 1; setTexto(objeto("marcador1"), p1); beep(490, 250, 0.7); saque()
    if p1 >= GANA then ganador = 1; estado = "fin" end; return
  end
  setPosPx(objeto("pelota"), x, y)
end

-- navega 'n' opciones con FLECHAS/ENTER, MOUSE-OVER y CLICK/TAP. IZQ/DER cambian idioma.
-- Devuelve la opcion elegida (con beep) o 0.
local function navegar(n)
  if apreto("izquierda") then cambiarIdioma(-1); beep(320, 30, 0.35) end
  if apreto("derecha")   then cambiarIdioma(1);  beep(320, 30, 0.35) end
  if apreto("arriba") then sel = sel - 1; if sel < 1 then sel = n end; beep(320, 30, 0.35) end
  if apreto("abajo")  then sel = sel + 1; if sel > n then sel = 1 end; beep(320, 30, 0.35) end
  -- MOUSE-OVER: la opcion bajo el cursor se resalta (SOLO al mover el mouse, asi no pisa las flechas)
  local rx, ry, dentro = raton()
  if dentro and (math.abs(rx - prevRx) > 1 or math.abs(ry - prevRy) > 1) then
    local o = opcionEnY(ry, n); if o ~= sel then sel = o; beep(300, 20, 0.25) end
  end
  prevRx, prevRy = rx, ry
  local e = 0
  if apreto("1") then sel = 1; e = 1 end
  if apreto("2") and n >= 2 then sel = 2; e = 2 end
  if apreto("3") and n >= 3 then sel = 3; e = 3 end
  if apreto("espacio") or apreto("enter") or apretoA() then e = sel end
  -- CLICK (mouse) o TAP (tactil): confirma. Un tap sin mouse elige primero por la Y del dedo.
  if apretoDedo() then
    local tx, ty = dedo(1)
    if not dentro then sel = opcionEnY(ty, n) end
    e = sel
  end
  if e > 0 then beep(520, 70, 0.5) end
  return e
end

-- ADAPTAR a la ventana: con "igual que el render" el lienzo = la ventana REAL (dinamico), asi que todo
-- lo que estaba en PIXELES fijos (tamaños, fuentes, velocidades, posiciones del menu) se escala respecto
-- a REF. Lo FRACCIONAL (posiciones de palas/opciones/boton) ya se adapta solo. Se llama cada frame -> el
-- juego sigue a cualquier tamaño/aspecto de ventana, sin definicion fija.
local function adaptar()
  local ancho, alto = pantalla()
  -- escala por la dimension MENOR: asi el texto y las palas entran a cualquier proporcion de ventana
  -- (con altura sola, en una ventana estirada el texto se pasaba de ancho y "PAUSA" salia partido).
  gEsc = math.min(ancho, alto) / REF
  local e = gEsc
  VEL_PALA   = 360 * e
  VEL_PELOTA = 240 * e
  OPBASE = -0.02 * alto      -- misma Y (fraccional) que las opciones del menu en la escena
  OPSTEP =  0.10 * alto      -- paso entre opciones
  setTamPx(objeto("jugador1"), 10*e, 70*e); setTamPx(objeto("jugador2"), 10*e, 70*e)
  setTamPx(objeto("pelota"), 14*e, 14*e)
  setTam(objeto("marcador1"), 46*e); setTam(objeto("marcador2"), 46*e)
  setTam(objeto("titMI"), 78*e); setTam(objeto("titMD"), 44*e)
  setTam(objeto("mi1"), 30*e); setTam(objeto("mi2"), 30*e); setTam(objeto("mi3"), 24*e)
  setTam(objeto("md1"), 30*e); setTam(objeto("md2"), 30*e); setTam(objeto("md3"), 30*e)
  setTamPx(objeto("selMI"), 300*e, 48*e); setTamPx(objeto("selMD"), 300*e, 48*e)
  -- BOTON DE PAUSA: cuadrado fijo. Las dos barras se PEGAN a su centro con offset en PX (no fraccional):
  -- con pos fraccional, en una ventana ANCHA las barras se separaban y el boton parecia "estirado".
  local cx, cy = 0.42 * ancho, -0.42 * alto      -- centro del boton (esquina sup-der) en px de lienzo
  setPosPx(objeto("btnPausa"), cx, cy);        setTamPx(objeto("btnPausa"), 44*e, 44*e)
  setPosPx(objeto("pausaBar1"), cx - 8*e, cy); setTamPx(objeto("pausaBar1"), 7*e, 22*e)
  setPosPx(objeto("pausaBar2"), cx + 8*e, cy); setTamPx(objeto("pausaBar2"), 7*e, 22*e)
end

function actualizar(dt)
  if dt > 0.05 then dt = 0.05 end
  adaptar()                                              -- el juego sigue el tamaño de la ventana
  if actualizarFade(dt) then guardarPrev(); return end   -- durante el crossfade no se navega

  if estado == "menu" then
    pintarOps(objeto("mi1"), objeto("mi2"), objeto("mi3"), objeto("selMI"),
              { t("p1"), t("p2"), t("idioma") .. ": " .. NOM[idioma] })
    local e = navegar(3)
    if e == 3 then cambiarIdioma(1)
    elseif e == 1 then jugadores = 1; sel = 2
      fade(objeto("menuIni"), objeto("menuDif"), function() estado = "dificultad" end)
    elseif e == 2 then jugadores = 2
      fade(objeto("menuIni"), objeto("juego"), function() empezarPartido() end)
    end

  elseif estado == "dificultad" then
    pintarOps(objeto("md1"), objeto("md2"), objeto("md3"), objeto("selMD"), { t("facil"), t("normal"), t("dificil") })
    local e = navegar(3)
    if e >= 1 then
      dif = ({ "facil", "normal", "dificil" })[e]
      fade(objeto("menuDif"), objeto("juego"), function() empezarPartido() end)
    end

  elseif estado == "cuenta" then
    local antes = math.ceil(cuenta)
    cuenta = cuenta - dt
    local n = math.ceil(cuenta)
    if n ~= antes then if n >= 1 then beep(400, 120, 0.5) else beep(720, 250, 0.6) end end
    if n < 1 then ocultarMensaje(); estado = "jugando"
    else ponerMensaje(n, 72, 120, 110) end

  elseif estado == "jugando" then
    if apreto("p") then estado = "pausa"; guardarPrev(); return end
    -- BOTON DE PAUSA (arriba a la derecha): un click/tap sobre el lo pausa (region relativa a la ventana)
    if apretoDedo() then local bx, by = dedo(1); local aw, ah = pantalla()
      if math.abs(bx - 0.42*aw) < 26*gEsc and math.abs(by + 0.42*ah) < 26*gEsc then estado = "pausa"; guardarPrev(); return end
    end
    local _, y1a = posPx(objeto("jugador1")); inputJugador1(dt)
    velPala1 = (({ posPx(objeto("jugador1")) })[2] - y1a) / dt
    local _, y2a = posPx(objeto("jugador2"))
    if jugadores == 2 then inputJugador2(dt) else inputMaquina(dt) end
    velPala2 = (({ posPx(objeto("jugador2")) })[2] - y2a) / dt
    fisicaPelota(dt)

  elseif estado == "pausa" then
    ponerMensaje(t("pausa"), 44, 260, 90)
    -- REANUDAR: tecla P, o un click/tap sobre el MISMO boton de pausa (toggle). Sin esto, si pausabas
    -- con el boton (sin teclado, ej. tactil/web) te quedabas trabado y no habia forma de seguir.
    local tocoBtn = false
    if apretoDedo() then local bx, by = dedo(1); local aw, ah = pantalla()
      tocoBtn = math.abs(bx - 0.42*aw) < 26*gEsc and math.abs(by + 0.42*ah) < 26*gEsc end
    if apreto("p") or tocoBtn then ocultarMensaje(); estado = "jugando" end
    if apreto("espacio") or apreto("enter") then ocultarMensaje(); inicio() end

  elseif estado == "fin" then
    ponerMensaje(t("gano") .. ganador, 30, 430, 80)
    mostrar(objeto("pelota"), false)
    if apreto("espacio") or apreto("enter") or apretoA() or apretoDedo() then
      ocultarMensaje(); mostrar(objeto("pelota"), true); inicio()
    end
  end

  guardarPrev()
end
