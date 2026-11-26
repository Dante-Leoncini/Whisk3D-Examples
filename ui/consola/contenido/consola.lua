-- consola.lua -- ejemplo didactico de LOG + MODO DEBUG en Whisk3D.
--
-- La idea: el MISMO codigo corre en el build DEBUG y en el de PRODUCCION, y es
-- el BUILD (la macro W3D_DEV_LOG del Core) quien decide que se ve:
--   * build DEBUG      -> debugLog() emite, isDebug() = true, y el ring buffer
--                         del log guarda las ultimas lineas (el panel las lee).
--   * build PRODUCCION -> debugLog() es no-op, isDebug() = false y el ring esta
--                         apagado (logCount() = 0): el panel avisa que la
--                         consola esta apagada. info/warning/error tampoco emiten
--                         (en produccion el sink entero del log desaparece).
--
-- Binds de log del Core:  info(msg)  warning(msg)  error(msg)  debugLog(msg)
--                         isDebug()  logCount()  logLine(i)
-- OJO: setText() NO interpreta "\n" (el texto 2D solo auto-parte por ancho),
-- por eso el panel son 8 textos hijos (Linea1..Linea8), uno por linea del log.

properties = {
  btnInfo = "object", btnAviso = "object", btnError = "object",
  btnDepurar = "object",                       -- solo visible en el build debug
  l1 = "object", l2 = "object", l3 = "object", l4 = "object",
  l5 = "object", l6 = "object", l7 = "object", l8 = "object",
}

local lines            -- los 8 textos del panel (se resuelven en start())
local counter = 0      -- numera los mensajes del usuario (para que se distingan)
local shown = -1       -- cuantas lineas del log ya mostramos (refresco perezoso)

-- vuelca las ULTIMAS 8 lineas del ring buffer del log al panel. logLine(i) es
-- 1-based (1 = la mas vieja) y devuelve texto + nivel ("info"|"warning"|"error").
local function refresh()
  if not isDebug() then return end   -- produccion: el panel conserva su aviso fijo
  local total = logCount()
  local from = total - 8             -- indice ANTERIOR a la primera que mostramos
  if from < 0 then from = 0 end
  for i = 1, 8 do
    local text, level = logLine(from + i)   -- "" , "" si no hay tantas lineas
    if level ~= "" then
      -- sin color por linea en el texto 2D: el NIVEL va como prefijo de texto
      setText(lines[i], level .. ": " .. text)
    else
      setText(lines[i], "")
    end
  end
end

function start()
  lines = { object("l1"), object("l2"), object("l3"), object("l4"),
            object("l5"), object("l6"), object("l7"), object("l8") }
  -- EL punto didactico: la herramienta de debug solo existe si el BUILD es debug.
  -- Mismo .w3dui, mismo .lua: en produccion el boton DEPURAR desaparece.
  show(object("btnDepurar"), isDebug())
  if isDebug() then
    debugLog("start() del ejemplo consola")    -- este mensaje NO existe en produccion
  else
    -- produccion: el ring esta apagado y el panel no puede mostrar el log;
    -- lo decimos explicito para que el ejemplo se entienda igual
    setText(lines[1], "consola apagada (produccion)")
    setText(lines[2], "debugLog() no emite y el ring esta apagado")
  end
  refresh()
end

function update(dt)
  -- cada boton emite al log del Core con su nivel (los mismos niveles que
  -- colorea el viewport Console del editor)
  if pressed(object("btnInfo")) then
    counter = counter + 1
    info("algo paso (" .. counter .. ")")
  end
  if pressed(object("btnAviso")) then
    counter = counter + 1
    warning("ojo con esto (" .. counter .. ")")
  end
  if pressed(object("btnError")) then
    counter = counter + 1
    error("esto se rompio (" .. counter .. ")")   -- error() LOGUEA, no corta el script
  end
  if pressed(object("btnDepurar")) then
    counter = counter + 1
    debugLog("detalle interno (" .. counter .. ")")  -- en produccion seria no-op
  end
  -- refresco PEREZOSO: solo cuando el log crecio (asi tambien entran las lineas
  -- que emite el propio motor, no solo las de los botones)
  if logCount() ~= shown then
    shown = logCount()
    refresh()
  end
end
