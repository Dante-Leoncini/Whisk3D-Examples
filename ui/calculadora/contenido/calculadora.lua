-- calculadora.lua -- la LOGICA de una calculadora basica (como la del telefono).
--
-- La regla del ejemplo: TODO el layout vive en calculadora.w3dui (anclas + filas y
-- columnas con weight/expand del editor). Este script no posiciona nada: solo lee
-- los botones con pressed() (tap o click sobre el rect que dibuja el layout) y
-- escribe los dos textos (Display e Historial) con setText().

-- properties: los objetos de la escena que usa el script; el .w3dui conecta
-- cada nombre de aca con un objeto real via "refs".
properties = {
  display = "object", historial = "object",              -- los dos textos de arriba
  ac = "object", signo = "object", porc = "object",      -- fila AC  +/-  %
  div = "object", por = "object", menos = "object",      -- operaciones...
  mas = "object", igual = "object",                      -- ...y el =
  b0 = "object", b1 = "object", b2 = "object", b3 = "object", b4 = "object",
  b5 = "object", b6 = "object", b7 = "object", b8 = "object", b9 = "object",
  punto = "object",
}

-- estado de la calculadora (alcanzan estos datos):
local current   = "0"    -- el numero que se esta tipeando, como TEXTO (para poder armarlo digito a digito)
local stored    = nil    -- el operando guardado a la izquierda (numero), o nil si no hay cuenta en curso
local operation = nil    -- la operacion pendiente: "+", "-", "x", "/" (nil = ninguna)
local startNew  = true   -- true = el proximo digito ARRANCA un numero nuevo (tras una operacion o el =)
local lastExpr  = ""     -- lo que muestra el Historial: la ultima cuenta RESUELTA (ej "38 + 4 =")

-- las tablas boton -> significado se arman en start() (recien ahi existe object())
local digits, operations

-- formatea un numero sin el ruido de los float (0.30000000000004 -> 0.3)
local function fmt(n) return string.format("%.10g", n) end

-- vuelca el estado a los dos textos de la pantalla. El Display muestra la CUENTA
-- EN CURSO mientras se tipea: "2" -> "2 +" -> "2 + 2" (y el resultado tras el =)
local function refresh()
  local line = current
  if operation then
    line = fmt(stored) .. " " .. operation                    -- "2 +"
    if not startNew then line = line .. " " .. current end    -- "2 + 2"
  end
  setText(object("display"), line)
  setText(object("historial"), lastExpr)
end

-- resuelve la operacion pendiente: stored (op) current -> current
local function calculate()
  if not operation then return end
  local a, b = stored, tonumber(current) or 0
  local r = 0
  if     operation == "+" then r = a + b
  elseif operation == "-" then r = a - b
  elseif operation == "x" then r = a * b
  elseif operation == "/" then r = (b == 0) and 0 or a / b end  -- dividir por 0: devolvemos 0 (ejemplo simple)
  current = fmt(r)
  stored, operation = nil, nil
end

function start()
  -- cada boton con el digito (o el punto) que agrega al numero
  digits = {
    { object("b0"), "0" }, { object("b1"), "1" }, { object("b2"), "2" },
    { object("b3"), "3" }, { object("b4"), "4" }, { object("b5"), "5" },
    { object("b6"), "6" }, { object("b7"), "7" }, { object("b8"), "8" },
    { object("b9"), "9" }, { object("punto"), "." },
  }
  -- cada boton de operacion con su simbolo
  operations = {
    { object("div"), "/" }, { object("por"), "x" },
    { object("menos"), "-" }, { object("mas"), "+" },
  }
  refresh()   -- display "0", historial vacio
end

function update(dt)
  -- DIGITOS y PUNTO: van armando el numero como texto
  for i = 1, #digits do
    local obj, d = digits[i][1], digits[i][2]
    if pressed(obj) then
      if startNew and not operation then lastExpr = "" end   -- tras el "=": empezar otro numero limpia el Historial viejo
      if startNew or #current < 12 then                     -- tope de 12 caracteres: no desborda el display (si arranca numero nuevo siempre pasa)
        if d == "." then
          if startNew then current = "0."; startNew = false                     -- ".5" se escribe "0.5"
          elseif not string.find(current, ".", 1, true) then current = current .. "." end  -- un solo punto
        elseif startNew then current = d; startNew = false                      -- arranca un numero nuevo
        elseif current == "0" then current = d                                  -- "0" y despues "7" -> "7" (no "07")
        else current = current .. d end
      end
      refresh()
    end
  end

  -- OPERACIONES + - x / : guardan el operando y dejan la cuenta pendiente
  -- (el Historial NO se toca aca: solo se llena al apretar el =)
  for i = 1, #operations do
    local obj, op = operations[i][1], operations[i][2]
    if pressed(obj) then
      if operation and not startNew then calculate() end   -- encadenar: "2 + 3 +" resuelve el 2+3 primero
      stored = tonumber(current) or 0
      operation = op
      startNew = true
      refresh()
    end
  end

  -- IGUAL: resuelve la cuenta pendiente y muestra la cuenta completa arriba
  if pressed(object("igual")) then
    if operation then
      lastExpr = fmt(stored) .. " " .. operation .. " " .. current .. " ="
      calculate()
      startNew = true
    end
    refresh()
  end

  -- AC: borra todo y vuelve al estado inicial
  if pressed(object("ac")) then
    current, stored, operation, startNew, lastExpr = "0", nil, nil, true, ""
    refresh()
  end

  -- +/- : cambia el signo del numero visible, tocando el TEXTO (pasarlo por fmt()
  -- perderia lo tipeado a medias: "0." se volvia "-0" y "1.50" se volvia "-1.5")
  if pressed(object("signo")) then
    if string.sub(current, 1, 1) == "-" then current = string.sub(current, 2)  -- ya era negativo: sacar el "-"
    elseif current ~= "0" then current = "-" .. current end                    -- el "0" queda "0" (nunca "-0")
    refresh()
  end

  -- % : el numero visible pasa a ser su porcentaje (38 -> 0.38)
  if pressed(object("porc")) then
    current = fmt((tonumber(current) or 0) / 100)
    refresh()
  end
end
