-- ============================================================================
--  dificultad.lua  ---  elegir FACIL / NORMAL / DIFICIL (solo en 1 jugador).
--
--  Es la misma lista de 3 opciones que menu.lua, mas corta: al elegir una guarda
--  la dificultad y arranca la partida. Todo lo visual esta en dificultad.w3dui.
-- ============================================================================

propiedades = { titulo = "objeto", op1 = "objeto", op2 = "objeto", op3 = "objeto",
                sel = "objeto", btnVolver = "objeto" }

local TXT = {
  es = { titulo = "DIFICULTAD",  facil = "FACIL", normal = "NORMAL", dificil = "DIFICIL", volver = "VOLVER AL MENU" },
  en = { titulo = "DIFFICULTY",  facil = "EASY",  normal = "NORMAL", dificil = "HARD",    volver = "BACK TO MENU"   },
  pt = { titulo = "DIFICULDADE", facil = "FACIL", normal = "NORMAL", dificil = "DIFICIL", volver = "VOLTAR AO MENU" },
}
-- El orden de la lista. El nombre guardado es el que despues lee juego.lua.
local DIFS = { "facil", "normal", "dificil" }
local titulo, ops, sel, btnVolver
local elegido, idioma

function inicio()
  titulo = objeto("titulo"); sel = objeto("sel"); btnVolver = objeto("btnVolver")
  ops = { objeto("op1"), objeto("op2"), objeto("op3") }
  idioma = config("idioma", "en")
  elegido = 2   -- arranca en NORMAL
end

function actualizar(dt)
  local txt = TXT[idioma] or TXT.en
  setTexto(titulo, txt.titulo); setTexto(btnVolver, txt.volver)
  for i = 1, #ops do setTexto(ops[i], txt[DIFS[i]]) end

  -- Moverse por la lista, igual que en el menu de inicio.
  if teclaApretada("arriba") then elegido = elegido - 1; beep(320, 30, 0.35) end
  if teclaApretada("abajo")  then elegido = elegido + 1; beep(320, 30, 0.35) end
  if elegido < 1 then elegido = #ops elseif elegido > #ops then elegido = 1 end
  -- cajaUI() = el rect que el layout le dio a la opcion (viven dentro de cajas).
  local _, y = cajaUI(ops[elegido])
  setPosPx(sel, 0, y)

  if apretado(btnVolver) then cambiarEscena("Menu") end

  local eleccion = 0
  if teclaApretada("espacio") or teclaApretada("enter") or botonApretado("a") then
    eleccion = elegido
  end
  for i = 1, #ops do if apretado(ops[i]) then elegido = i; eleccion = i end end
  if eleccion == 0 then return end

  beep(520, 70, 0.5)
  setConfig("wp_dificultad", DIFS[eleccion])
  cambiarEscena("Juego", true)
end
