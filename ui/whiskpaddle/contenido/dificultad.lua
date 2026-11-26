-- ============================================================================
--  dificultad.lua  ---  elegir FACIL / NORMAL / DIFICIL (solo en 1 jugador).
--
--  Es la misma lista de 3 opciones que menu.lua, mas corta: al elegir una guarda
--  la dificultad y arranca la partida. Todo lo visual esta en dificultad.w3dui.
-- ============================================================================

properties = { titulo = "object", op1 = "object", op2 = "object", op3 = "object",
               sel = "object", btnVolver = "object" }

local TXT = {
  es = { title = "DIFICULTAD",  facil = "FACIL", normal = "NORMAL", dificil = "DIFICIL", back = "VOLVER AL MENU" },
  en = { title = "DIFFICULTY",  facil = "EASY",  normal = "NORMAL", dificil = "HARD",    back = "BACK TO MENU"   },
  pt = { title = "DIFICULDADE", facil = "FACIL", normal = "NORMAL", dificil = "DIFICIL", back = "VOLTAR AO MENU" },
}
-- El orden de la lista. El nombre guardado es el que despues lee juego.lua.
local DIFFICULTIES = { "facil", "normal", "dificil" }
local title, options, sel, btnBack
local selected, language

function start()
  title = object("titulo"); sel = object("sel"); btnBack = object("btnVolver")
  options = { object("op1"), object("op2"), object("op3") }
  language = getConfig("idioma", "en")
  selected = 2   -- arranca en NORMAL
end

function update(dt)
  local txt = TXT[language] or TXT.en
  setText(title, txt.title); setText(btnBack, txt.back)
  for i = 1, #options do setText(options[i], txt[DIFFICULTIES[i]]) end

  -- Moverse por la lista, igual que en el menu de inicio.
  if keyPressed("up")   then selected = selected - 1; beep(320, 30, 0.35) end
  if keyPressed("down") then selected = selected + 1; beep(320, 30, 0.35) end
  if selected < 1 then selected = #options elseif selected > #options then selected = 1 end
  -- uiBox() = el rect que el layout le dio a la opcion (viven dentro de cajas).
  local _, y = uiBox(options[selected])
  setPosPx(sel, 0, y)

  if pressed(btnBack) then changeScene("Menu") end

  local choice = 0
  if keyPressed("space") or keyPressed("enter") or buttonPressed("a") then
    choice = selected
  end
  for i = 1, #options do if pressed(options[i]) then selected = i; choice = i end end
  if choice == 0 then return end

  beep(520, 70, 0.5)
  setConfig("wp_dificultad", DIFFICULTIES[choice])
  changeScene("Juego", true)
end
