-- ============================================================================
--  menu.lua  ---  la pantalla de INICIO: 1 jugador, 2 jugadores, idioma.
--
--  El titulo, las 3 opciones, el recuadro que resalta la elegida y la barra de
--  abajo estan puestos en menu.w3dui con su posicion y su ancla: aca no se calcula
--  ni un tamano, solo QUE dice cada opcion y QUE pasa al elegirla. El motor llama
--  a start() al entrar a la escena y a update(dt) una vez por cuadro.
-- ============================================================================

-- Los objetos que usa este script; en menu.w3dui, "refs" dice cual es cual.
properties = { op1 = "object", op2 = "object", op3 = "object",
               sel = "object", btnSalir = "object" }

-- Los textos en los 3 idiomas (la fuente no dibuja tildes: van sin acentos).
local TXT = {
  es = { p1 = "1 JUGADOR", p2 = "2 JUGADORES", language = "IDIOMA",   exit = "SALIR", name = "ESPAÑOL"   },
  en = { p1 = "1 PLAYER",  p2 = "2 PLAYERS",   language = "LANGUAGE", exit = "EXIT",  name = "ENGLISH"   },
  pt = { p1 = "1 JOGADOR", p2 = "2 JOGADORES", language = "IDIOMA",   exit = "SAIR",  name = "PORTUGUES" },
}
local LANGUAGES = { "es", "en", "pt" }
local options, sel, btnExit   -- los objetos de la lista (se buscan una vez, en start)
local selected, language      -- cual opcion esta resaltada (1..3) y el idioma actual

-- Pasa al idioma siguiente y lo deja GUARDADO para la proxima vez que se abra.
local function nextLanguage()
  local i = 1
  for k = 1, #LANGUAGES do if LANGUAGES[k] == language then i = k end end
  language = LANGUAGES[i % #LANGUAGES + 1]
  setConfig("idioma", language); saveConfig()
end

function start()
  options = { object("op1"), object("op2"), object("op3") }
  sel = object("sel"); btnExit = object("btnSalir")
  language = getConfig("idioma", "en")
  selected = 1
end

function update(dt)
  local txt = TXT[language] or TXT.en
  setText(options[1], txt.p1); setText(options[2], txt.p2)
  setText(options[3], txt.language .. ": " .. txt.name)
  setText(btnExit, txt.exit)

  -- Moverse por la lista. keyPressed() y buttonPressed() son del motor: dan
  -- true SOLO en el cuadro en que se aprieta, no mientras se mantiene apretado.
  if keyPressed("up")   then selected = selected - 1; beep(320, 30, 0.35) end
  if keyPressed("down") then selected = selected + 1; beep(320, 30, 0.35) end
  if selected < 1 then selected = #options elseif selected > #options then selected = 1 end
  -- El recuadro se para sobre la opcion elegida: le COPIA la posicion (no la
  -- calcula). uiBox() da el rect que el layout le dio de verdad a la opcion
  -- (cada una vive dentro de su caja en menu.w3dui, por eso no sirve getPosPx).
  local _, y = uiBox(options[selected])
  setPosPx(sel, 0, y)

  -- Confirmar: espacio / enter / boton A del gamepad, o tocar una opcion.
  -- pressed(objeto) es del motor: true en el cuadro del toque nuevo sobre ESE objeto.
  local choice = 0
  if keyPressed("space") or keyPressed("enter") or buttonPressed("a") then
    choice = selected
  end
  for i = 1, #options do if pressed(options[i]) then selected = i; choice = i end end
  if pressed(btnExit) then quit() end
  if choice == 0 then return end

  beep(520, 70, 0.5)
  -- changeScene(nombre, true) = ir a esa pantalla y arrancarla de cero. Cuantos
  -- jugadores hay viaja por la config: las escenas no comparten variables.
  if choice == 1 then
    setConfig("wp_jugadores", 1); changeScene("Dificultad", true)
  elseif choice == 2 then
    setConfig("wp_jugadores", 2); changeScene("Juego", true)
  else
    nextLanguage()
  end
end
