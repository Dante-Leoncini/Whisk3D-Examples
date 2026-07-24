-- ============================================================
--  PONG — el "hola mundo" de los scripts lua de Whisk3D.
--
--  Vos jugas con las flechas ARRIBA/ABAJO (la pala izquierda).
--  La computadora juega la derecha (dificultad en el panel).
--
--  Este archivo se cuelga del objeto "Pong" (la UI) desde la
--  tarjeta "Script" del editor. Las 'propiedades' de abajo
--  aparecen en el panel, estilo Unity: a las de tipo "objeto"
--  les asignas un objeto de la escena; las que son una lista
--  se eligen con un menu desplegable.
--
--  Coordenadas: PIXELES del lienzo, con (0,0) en el CENTRO.
--  API: pantalla() posPx() setPosPx() tamPx() setTexto()
--       tecla("arriba") objeto("prop") opcion("prop")
-- ============================================================

propiedades = {
  jugador1   = "objeto",                         -- tu pala (izquierda)
  jugador2   = "objeto",                         -- la pala de la maquina
  pelota     = "objeto",
  marcador1  = "objeto",                         -- el puntaje izquierdo (texto)
  marcador2  = "objeto",                         -- el puntaje derecho (texto)
  dificultad = { "normal", "facil", "dificil" }, -- desplegable (la primera es el default)
}

local VEL_PALA   = 360      -- pixeles por segundo
local VEL_PELOTA = 240
local vx, vy = 0, 0         -- velocidad actual de la pelota
local p1, p2 = 0, 0         -- los puntos

-- que tan buena es la maquina: velocidad de su pala y cuanto "le erra"
local IA = {
  facil   = { vel = 140, error = 60 },
  normal  = { vel = 210, error = 25 },
  dificil = { vel = 300, error = 4  },
}

-- la pelota sale del centro para un lado AL AZAR
local function saque()
  setPosPx(objeto("pelota"), 0, 0)
  local lado = (math.random(2) == 1) and 1 or -1
  vx = VEL_PELOTA * lado
  vy = VEL_PELOTA * (math.random() * 1.2 - 0.6)
end

-- se llama UNA vez al dar PLAY: el estado inicial del juego
function inicio()
  p1 = 0; p2 = 0
  setTexto(objeto("marcador1"), p1)
  setTexto(objeto("marcador2"), p2)
  saque()
end

-- mueve una pala 'dy' pixeles sin que se salga de la pantalla
local function moverPala(pala, dy)
  local _, alto = pantalla()
  local x, y = posPx(pala)
  local _, altoPala = tamPx(pala)
  y = y + dy
  local tope = alto / 2 - altoPala / 2
  if y < -tope then y = -tope end
  if y >  tope then y =  tope end
  setPosPx(pala, x, y)
end

-- la velocidad REAL de cada pala este frame (para darle efecto a la pelota)
local velPala1, velPala2 = 0, 0

-- se llama UNA vez por frame mientras el timeline esta en PLAY
function actualizar(dt)
  -- TU pala: flechas arriba/abajo, o el STICK IZQUIERDO analogico del gamepad
  -- (cuanto mas fuerte lo empujes, mas rapido va la pala)
  local _, y1antes = posPx(objeto("jugador1"))
  local sx, sy = stick("izq")
  if math.abs(sy) > 0.02 then moverPala(objeto("jugador1"), VEL_PALA * sy * dt) end
  if tecla("arriba") then moverPala(objeto("jugador1"), -VEL_PALA * dt) end
  if tecla("abajo")  then moverPala(objeto("jugador1"),  VEL_PALA * dt) end
  local _, y1despues = posPx(objeto("jugador1"))
  velPala1 = (y1despues - y1antes) / dt

  -- la MAQUINA persigue la pelota (mas lento y con mas error si es facil)
  local ia = IA[opcion("dificultad")] or IA.normal
  local bx, by = posPx(objeto("pelota"))
  local _, jy = posPx(objeto("jugador2"))
  local objetivo = by + ia.error * math.sin(bx * 0.05)
  local _, y2antes = posPx(objeto("jugador2"))
  if jy < objetivo - 6 then moverPala(objeto("jugador2"),  ia.vel * dt) end
  if jy > objetivo + 6 then moverPala(objeto("jugador2"), -ia.vel * dt) end
  local _, y2despues = posPx(objeto("jugador2"))
  velPala2 = (y2despues - y2antes) / dt

  -- la pelota avanza...
  local ancho, alto = pantalla()
  local x, y = posPx(objeto("pelota"))
  x = x + vx * dt
  y = y + vy * dt

  -- ...rebota arriba y abajo...
  if y < -alto / 2 and vy < 0 then vy = -vy end
  if y >  alto / 2 and vy > 0 then vy = -vy end

  -- ...y contra las palas. El angulo de salida NO es un espejo bobo:
  --   1) DONDE golpea en la pala inclina el tiro (pegarle con la punta abre
  --      el angulo; con el centro sale derecho), y
  --   2) la VELOCIDAD de la pala al golpear le da EFECTO (pegarle en
  --      movimiento arrastra la pelota; quieto no es lo mismo que a fondo).
  local function pega(pala)
    local px, py = posPx(pala)
    local pw, ph = tamPx(pala)
    return math.abs(x - px) < pw and math.abs(y - py) < ph / 2 + 10
  end
  local function reboteConEfecto(pala, velDeLaPala)
    local _, py = posPx(pala)
    local _, ph = tamPx(pala)
    local donde = (y - py) / (ph / 2)          -- -1 punta de arriba .. 1 punta de abajo
    if donde < -1 then donde = -1 end
    if donde >  1 then donde =  1 end
    vx = -vx * 1.05                            -- cada rebote acelera un poco
    vy = vy + donde * VEL_PELOTA * 0.9         -- la punta INCLINA el tiro
         + velDeLaPala * 0.45                  -- y el movimiento de la pala ARRASTRA
    local topeY = math.abs(vx) * 1.4           -- que nunca quede casi vertical
    if vy >  topeY then vy =  topeY end
    if vy < -topeY then vy = -topeY end
  end
  if vx < 0 and pega(objeto("jugador1")) then reboteConEfecto(objeto("jugador1"), velPala1) end
  if vx > 0 and pega(objeto("jugador2")) then reboteConEfecto(objeto("jugador2"), velPala2) end

  -- GOL: punto para el otro y saque de nuevo
  if x < -ancho / 2 then
    p2 = p2 + 1; setTexto(objeto("marcador2"), p2); saque(); return
  end
  if x > ancho / 2 then
    p1 = p1 + 1; setTexto(objeto("marcador1"), p1); saque(); return
  end

  setPosPx(objeto("pelota"), x, y)
end
