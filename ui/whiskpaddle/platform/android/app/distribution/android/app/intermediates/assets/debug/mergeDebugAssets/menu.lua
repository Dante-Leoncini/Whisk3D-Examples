-- ============================================================================
--  menu.lua  ---  la pantalla de INICIO: 1 jugador, 2 jugadores, idioma.
--
--  El titulo, las 3 opciones, el recuadro que resalta la elegida y la barra de
--  abajo estan puestos en menu.w3dui con su posicion y su ancla: aca no se calcula
--  ni un tamano, solo QUE dice cada opcion y QUE pasa al elegirla. El motor llama
--  a inicio() al entrar a la escena y a actualizar(dt) una vez por cuadro.
-- ============================================================================

-- Los objetos que usa este script; en menu.w3dui, "refs" dice cual es cual.
propiedades = { op1 = "objeto", op2 = "objeto", op3 = "objeto",
                sel = "objeto", btnSalir = "objeto" }

-- Los textos en los 3 idiomas (la fuente no dibuja tildes: van sin acentos).
local TXT = {
  es = { p1 = "1 JUGADOR", p2 = "2 JUGADORES", idioma = "IDIOMA",   salir = "SALIR", nombre = "ESPAÑOL"   },
  en = { p1 = "1 PLAYER",  p2 = "2 PLAYERS",   idioma = "LANGUAGE", salir = "EXIT",  nombre = "ENGLISH"   },
  pt = { p1 = "1 JOGADOR", p2 = "2 JOGADORES", idioma = "IDIOMA",   salir = "SAIR",  nombre = "PORTUGUES" },
}
local IDIOMAS = { "es", "en", "pt" }
local ops, sel, btnSalir   -- los objetos de la lista (se buscan una vez, en inicio)
local elegido, idioma      -- cual opcion esta resaltada (1..3) y el idioma actual

-- Pasa al idioma siguiente y lo deja GUARDADO para la proxima vez que se abra.
local function siguienteIdioma()
  local i = 1
  for k = 1, #IDIOMAS do if IDIOMAS[k] == idioma then i = k end end
  idioma = IDIOMAS[i % #IDIOMAS + 1]
  setConfig("idioma", idioma); guardarConfig()
end

function inicio()
  ops = { objeto("op1"), objeto("op2"), objeto("op3") }
  sel = objeto("sel"); btnSalir = objeto("btnSalir")
  idioma = config("idioma", "en")
  elegido = 1
end

function actualizar(dt)
  local txt = TXT[idioma] or TXT.en
  setTexto(ops[1], txt.p1); setTexto(ops[2], txt.p2)
  setTexto(ops[3], txt.idioma .. ": " .. txt.nombre)
  setTexto(btnSalir, txt.salir)

  -- Moverse por la lista. teclaApretada() y botonApretado() son del motor: dan
  -- true SOLO en el cuadro en que se aprieta, no mientras se mantiene apretado.
  if teclaApretada("arriba") then elegido = elegido - 1; beep(320, 30, 0.35) end
  if teclaApretada("abajo")  then elegido = elegido + 1; beep(320, 30, 0.35) end
  if elegido < 1 then elegido = #ops elseif elegido > #ops then elegido = 1 end
  -- El recuadro se para sobre la opcion elegida: le COPIA la posicion (no la
  -- calcula). cajaUI() da el rect que el layout le dio de verdad a la opcion
  -- (cada una vive dentro de su caja en menu.w3dui, por eso no sirve posPx).
  local _, y = cajaUI(ops[elegido])
  setPosPx(sel, 0, y)

  -- Confirmar: espacio / enter / boton A del gamepad, o tocar una opcion.
  -- apretado(objeto) es del motor: true en el cuadro del toque nuevo sobre ESE objeto.
  local eleccion = 0
  if teclaApretada("espacio") or teclaApretada("enter") or botonApretado("a") then
    eleccion = elegido
  end
  for i = 1, #ops do if apretado(ops[i]) then elegido = i; eleccion = i end end
  if apretado(btnSalir) then salir() end
  if eleccion == 0 then return end

  beep(520, 70, 0.5)
  -- cambiarEscena(nombre, true) = ir a esa pantalla y arrancarla de cero. Cuantos
  -- jugadores hay viaja por la config: las escenas no comparten variables.
  if eleccion == 1 then
    setConfig("wp_jugadores", 1); cambiarEscena("Dificultad", true)
  elseif eleccion == 2 then
    setConfig("wp_jugadores", 2); cambiarEscena("Juego", true)
  else
    siguienteIdioma()
  end
end
