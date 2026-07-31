-- calculadora.lua -- la LOGICA de una calculadora basica (como la del telefono).
--
-- La regla del ejemplo: TODO el layout vive en calculadora.w3dui (anclas + filas y
-- columnas con peso/expandir del editor). Este script no posiciona nada: solo lee
-- los botones con apretado() (tap o click sobre el rect que dibuja el layout) y
-- escribe los dos textos (Display e Historial) con setTexto().

-- propiedades: los objetos de la escena que usa el script; el .w3dui conecta
-- cada nombre de aca con un objeto real via "refs".
propiedades = {
  display = "objeto", historial = "objeto",              -- los dos textos de arriba
  ac = "objeto", signo = "objeto", porc = "objeto",      -- fila AC  +/-  %
  div = "objeto", por = "objeto", menos = "objeto",      -- operaciones...
  mas = "objeto", igual = "objeto",                      -- ...y el =
  b0 = "objeto", b1 = "objeto", b2 = "objeto", b3 = "objeto", b4 = "objeto",
  b5 = "objeto", b6 = "objeto", b7 = "objeto", b8 = "objeto", b9 = "objeto",
  punto = "objeto",
}

-- estado de la calculadora (3 datos alcanzan):
local actual    = "0"    -- el numero que se esta tipeando, como TEXTO (para poder armarlo digito a digito)
local acumulado = nil    -- el operando guardado a la izquierda (numero), o nil si no hay cuenta en curso
local operacion = nil    -- la operacion pendiente: "+", "-", "x", "/" (nil = ninguna)
local nuevo     = true   -- true = el proximo digito ARRANCA un numero nuevo (tras una operacion o el =)
local cuenta    = ""     -- lo que muestra el Historial: la ultima cuenta RESUELTA (ej "38 + 4 =")

-- las tablas boton -> significado se arman en inicio() (recien ahi existe objeto())
local digitos, operaciones

-- formatea un numero sin el ruido de los float (0.30000000000004 -> 0.3)
local function fmt(n) return string.format("%.10g", n) end

-- vuelca el estado a los dos textos de la pantalla. El Display muestra la CUENTA
-- EN CURSO mientras se tipea: "2" -> "2 +" -> "2 + 2" (y el resultado tras el =)
local function refrescar()
  local linea = actual
  if operacion then
    linea = fmt(acumulado) .. " " .. operacion                -- "2 +"
    if not nuevo then linea = linea .. " " .. actual end      -- "2 + 2"
  end
  setTexto(objeto("display"), linea)
  setTexto(objeto("historial"), cuenta)
end

-- resuelve la operacion pendiente: acumulado (op) actual -> actual
local function calcular()
  if not operacion then return end
  local a, b = acumulado, tonumber(actual) or 0
  local r = 0
  if     operacion == "+" then r = a + b
  elseif operacion == "-" then r = a - b
  elseif operacion == "x" then r = a * b
  elseif operacion == "/" then r = (b == 0) and 0 or a / b end  -- dividir por 0: devolvemos 0 (ejemplo simple)
  actual = fmt(r)
  acumulado, operacion = nil, nil
end

function inicio()
  -- cada boton con el digito (o el punto) que agrega al numero
  digitos = {
    { objeto("b0"), "0" }, { objeto("b1"), "1" }, { objeto("b2"), "2" },
    { objeto("b3"), "3" }, { objeto("b4"), "4" }, { objeto("b5"), "5" },
    { objeto("b6"), "6" }, { objeto("b7"), "7" }, { objeto("b8"), "8" },
    { objeto("b9"), "9" }, { objeto("punto"), "." },
  }
  -- cada boton de operacion con su simbolo
  operaciones = {
    { objeto("div"), "/" }, { objeto("por"), "x" },
    { objeto("menos"), "-" }, { objeto("mas"), "+" },
  }
  refrescar()   -- display "0", historial vacio
end

function actualizar(dt)
  -- DIGITOS y PUNTO: van armando el numero como texto
  for i = 1, #digitos do
    local obj, d = digitos[i][1], digitos[i][2]
    if apretado(obj) then
      if nuevo and not operacion then cuenta = "" end   -- tras el "=": empezar otro numero limpia el Historial viejo
      if nuevo or #actual < 12 then                     -- tope de 12 caracteres: no desborda el display (si arranca numero nuevo siempre pasa)
        if d == "." then
          if nuevo then actual = "0."; nuevo = false                     -- ".5" se escribe "0.5"
          elseif not string.find(actual, ".", 1, true) then actual = actual .. "." end  -- un solo punto
        elseif nuevo then actual = d; nuevo = false                      -- arranca un numero nuevo
        elseif actual == "0" then actual = d                             -- "0" y despues "7" -> "7" (no "07")
        else actual = actual .. d end
      end
      refrescar()
    end
  end

  -- OPERACIONES + - x / : guardan el operando y dejan la cuenta pendiente
  -- (el Historial NO se toca aca: solo se llena al apretar el =)
  for i = 1, #operaciones do
    local obj, op = operaciones[i][1], operaciones[i][2]
    if apretado(obj) then
      if operacion and not nuevo then calcular() end   -- encadenar: "2 + 3 +" resuelve el 2+3 primero
      acumulado = tonumber(actual) or 0
      operacion = op
      nuevo = true
      refrescar()
    end
  end

  -- IGUAL: resuelve la cuenta pendiente y muestra la cuenta completa arriba
  if apretado(objeto("igual")) then
    if operacion then
      cuenta = fmt(acumulado) .. " " .. operacion .. " " .. actual .. " ="
      calcular()
      nuevo = true
    end
    refrescar()
  end

  -- AC: borra todo y vuelve al estado inicial
  if apretado(objeto("ac")) then
    actual, acumulado, operacion, nuevo, cuenta = "0", nil, nil, true, ""
    refrescar()
  end

  -- +/- : cambia el signo del numero visible, tocando el TEXTO (pasarlo por fmt()
  -- perderia lo tipeado a medias: "0." se volvia "-0" y "1.50" se volvia "-1.5")
  if apretado(objeto("signo")) then
    if string.sub(actual, 1, 1) == "-" then actual = string.sub(actual, 2)  -- ya era negativo: sacar el "-"
    elseif actual ~= "0" then actual = "-" .. actual end                    -- el "0" queda "0" (nunca "-0")
    refrescar()
  end

  -- % : el numero visible pasa a ser su porcentaje (38 -> 0.38)
  if apretado(objeto("porc")) then
    actual = fmt((tonumber(actual) or 0) / 100)
    refrescar()
  end
end
