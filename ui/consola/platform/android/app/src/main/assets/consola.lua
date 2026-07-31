-- consola.lua -- ejemplo didactico de LOG + MODO DEBUG en Whisk3D.
--
-- La idea: el MISMO codigo corre en el build DEBUG y en el de PRODUCCION, y es
-- el BUILD (la macro W3D_DEV_LOG del Core) quien decide que se ve:
--   * build DEBUG      -> depurar() emite, esDebug() = true, y el ring buffer
--                         del log guarda las ultimas lineas (el panel las lee).
--   * build PRODUCCION -> depurar() es no-op, esDebug() = false y el ring esta
--                         apagado (logCantidad() = 0): el panel avisa que la
--                         consola esta apagada. info/aviso/error tampoco emiten
--                         (en produccion el sink entero del log desaparece).
--
-- Binds de log del Core:  info(msg)  aviso(msg)  error(msg)  depurar(msg)
--                         esDebug()  logCantidad()  logLinea(i)
-- OJO: setTexto() NO interpreta "\n" (el texto 2D solo auto-parte por ancho),
-- por eso el panel son 8 textos hijos (Linea1..Linea8), uno por linea del log.

propiedades = {
  btnInfo = "objeto", btnAviso = "objeto", btnError = "objeto",
  btnDepurar = "objeto",                       -- solo visible en el build debug
  l1 = "objeto", l2 = "objeto", l3 = "objeto", l4 = "objeto",
  l5 = "objeto", l6 = "objeto", l7 = "objeto", l8 = "objeto",
}

local lineas          -- los 8 textos del panel (se resuelven en inicio())
local contador = 0    -- numera los mensajes del usuario (para que se distingan)
local vistas = -1     -- cuantas lineas del log ya mostramos (refresco perezoso)

-- vuelca las ULTIMAS 8 lineas del ring buffer del log al panel. logLinea(i) es
-- 1-based (1 = la mas vieja) y devuelve texto + nivel ("info"|"aviso"|"error").
local function refrescar()
  if not esDebug() then return end   -- produccion: el panel conserva su aviso fijo
  local total = logCantidad()
  local desde = total - 8            -- indice ANTERIOR a la primera que mostramos
  if desde < 0 then desde = 0 end
  for i = 1, 8 do
    local texto, nivel = logLinea(desde + i)   -- "" , "" si no hay tantas lineas
    if nivel ~= "" then
      -- sin color por linea en el texto 2D: el NIVEL va como prefijo de texto
      setTexto(lineas[i], nivel .. ": " .. texto)
    else
      setTexto(lineas[i], "")
    end
  end
end

function inicio()
  lineas = { objeto("l1"), objeto("l2"), objeto("l3"), objeto("l4"),
             objeto("l5"), objeto("l6"), objeto("l7"), objeto("l8") }
  -- EL punto didactico: la herramienta de debug solo existe si el BUILD es debug.
  -- Mismo .w3dui, mismo .lua: en produccion el boton DEPURAR desaparece.
  mostrar(objeto("btnDepurar"), esDebug())
  if esDebug() then
    depurar("inicio() del ejemplo consola")    -- este mensaje NO existe en produccion
  else
    -- produccion: el ring esta apagado y el panel no puede mostrar el log;
    -- lo decimos explicito para que el ejemplo se entienda igual
    setTexto(lineas[1], "consola apagada (produccion)")
    setTexto(lineas[2], "depurar() no emite y el ring esta apagado")
  end
  refrescar()
end

function actualizar(dt)
  -- cada boton emite al log del Core con su nivel (los mismos niveles que
  -- colorea el viewport Console del editor)
  if apretado(objeto("btnInfo")) then
    contador = contador + 1
    info("algo paso (" .. contador .. ")")
  end
  if apretado(objeto("btnAviso")) then
    contador = contador + 1
    aviso("ojo con esto (" .. contador .. ")")
  end
  if apretado(objeto("btnError")) then
    contador = contador + 1
    error("esto se rompio (" .. contador .. ")")   -- error() LOGUEA, no corta el script
  end
  if apretado(objeto("btnDepurar")) then
    contador = contador + 1
    depurar("detalle interno (" .. contador .. ")")  -- en produccion seria no-op
  end
  -- refresco PEREZOSO: solo cuando el log crecio (asi tambien entran las lineas
  -- que emite el propio motor, no solo las de los botones)
  if logCantidad() ~= vistas then
    vistas = logCantidad()
    refrescar()
  end
end
