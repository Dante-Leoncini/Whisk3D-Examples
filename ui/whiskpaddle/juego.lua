-- ============================================================================
--  juego.lua  ---  las REGLAS del Pong, y nada mas.
--
--  A la pelota NO la movemos nosotros: le damos una VELOCIDAD y la mueve el
--  motor, que ademas resuelve los rebotes (rebotar / rebotarEn) y nos avisa.
--  Donde va cada cosa en la pantalla lo decide juego.w3dui: aca no hay cuentas
--  de posiciones, y de tamanos solo UNA (la pelota, ver inicio()).
--
--  CONTROLES  1 jugador: flechas / stick / dedo (la maquina juega la derecha).
--  2 jugadores: la izquierda con W/S, stick izquierdo o el dedo de su mitad; la
--  derecha con las flechas, stick derecho o su mitad. Pausa: tecla P o su boton.
-- ============================================================================

-- Los objetos que usa este script; en juego.w3dui, "refs" dice cual es cual.
propiedades = { pelota = "objeto", pala1 = "objeto", pala2 = "objeto", cancha = "objeto",
                marcador1 = "objeto", marcador2 = "objeto", cartel = "objeto",
                cartelTexto = "objeto", btnPausa = "objeto", btnMenu = "objeto" }

-- Los textos en los 3 idiomas (la fuente no dibuja tildes: van sin acentos).
local TXT = {
  es = { pausa = "PAUSA", gano = "GANO EL JUGADOR ",  volver = "VOLVER AL MENU" },
  en = { pausa = "PAUSE", gano = "WINNER: PLAYER ",   volver = "BACK TO MENU"   },
  pt = { pausa = "PAUSA", gano = "GANHOU O JOGADOR ", volver = "VOLTAR AO MENU" },
}

-- Los numeros que dan el "sabor" del juego: cambialos y probalo. Estan pensados
-- para una pantalla de 480 px de lado menor; como el lienzo ahora ES la pantalla
-- real (en un celu hay muchos mas px), inicio() los multiplica por escala()
-- (= lado menor / 480) y guarda el resultado en las variables v* / ia*.
local GANA       = 7     -- puntos para ganar la partida
local VEL_PALA   = 320   -- px por segundo que se mueve una pala
local VEL_PELOTA = 260   -- px por segundo con que sale la pelota al sacar
local VEL_MAX    = 520   -- mas rapido que esto la pelota no se pone nunca
local TAM_PELOTA = 14    -- lado de la pelota (cuadrada, por eso va en px y no relativa)
local IA = {   -- la maquina, por dificultad: cuanto corre y cuanto se equivoca
  facil = { vel = 150, error = 60 }, normal = { vel = 220, error = 25 }, dificil = { vel = 320, error = 4 } }

-- Los objetos de la escena (se buscan UNA vez, en inicio) y el estado de la partida
local pelota, pala1, pala2, marcador1, marcador2, cancha, cartel, cartelTexto, btnPausa, btnMenu
local txt, jugadores, ia      -- idioma y lo que se eligio en las pantallas anteriores
local p1, p2, estado, cuenta  -- puntaje; "cuenta"/"jugando"/"pausa"/"fin"; cuenta regresiva
local guardaVx, guardaVy      -- velocidad de la pelota mientras esta en pausa
local vPala, vPelota, vMax    -- las VEL_* ya pasadas a la pantalla real (inicio)
local iaVel, iaError          -- idem para la maquina

-- Pone la pelota en el medio de la cancha. El medio NO lo calculamos: cajaUI(objeto)
-- devuelve el CENTRO (y el tamano) del rectangulo que ese objeto ocupa de verdad.
local function alMedio()
  local cx, cy = cajaUI(cancha); setPosPx(pelota, cx, cy)
end

-- Saca: la pelota al medio y disparada para un lado al azar. velocidad(obj, vx, vy)
-- se la entrega al MOTOR: desde aca la mueve el solo.
local function saque()
  alMedio()
  local lado = (azar(1, 2) == 1) and 1 or -1
  velocidad(pelota, vPelota * lado, vPelota * (azar() * 1.2 - 0.6))
end

-- Frena todo lo que se mueve (al pausar y al terminar la partida).
local function frenar()
  velocidad(pelota, 0, 0); velocidad(pala1, 0, 0); velocidad(pala2, 0, 0)
end
-- Muestra el cartel del medio y el boton de volver al menu; nil = esconderlos.
local function cartelCon(texto, boton)
  mostrar(cartel, texto ~= nil);  if texto then setTexto(cartelTexto, texto) end
  mostrar(btnMenu, boton ~= nil); if boton then setTexto(btnMenu, boton) end
end

-- Mueve UNA pala: no le sumamos la posicion a mano, le damos VELOCIDAD. "mitad":
-- -1 = le hace caso al dedo de la izquierda, 1 = al de la derecha, 0 = a cualquiera.
local function moverPala(pala, teclaArriba, teclaAbajo, cualStick, mitad)
  local v = 0
  if tecla(teclaArriba) then v = -vPala end
  if tecla(teclaAbajo)  then v =  vPala end
  local _, sy = stick(cualStick)
  if sy < -0.2 or sy > 0.2 then v = vPala * sy end
  velocidad(pala, 0, v)
  for d = 1, 4 do                      -- dedo(1..4): hasta 4 dedos a la vez
    local dx, dy, tocando = dedo(d)
    -- Del dedo solo importa su MITAD en x: aunque se vaya a la barra, mas alla del
    -- borde o mas abajo de la cancha, la pala lo sigue igual (no se pierde el
    -- control); el limitar() de abajo la deja clampeada dentro de la cancha.
    if tocando and dx * mitad >= 0 then
      setPosPx(pala, nil, dy); velocidad(pala, 0, 0)   -- x en nil = ese eje no se toca
    end
  end
  limitar(pala, cancha)                -- que no se salga de la cancha (el motor lee su caja)
end
-- La maquina (modo 1 jugador): el error se mueve con la X de la pelota, asi
-- "duda" mientras la pelota viaja y se acomoda cuando la tiene cerca.
local function maquina()
  local bx, by = posPx(pelota)
  local _, py = posPx(pala2)
  local objetivo = by + iaError * math.sin(bx * 0.05)
  local v = 0
  if py < objetivo - 6 then v = iaVel elseif py > objetivo + 6 then v = -iaVel end
  velocidad(pala2, 0, v)
  limitar(pala2, cancha)
end

-- El golpe contra una pala: el motor ya la hizo rebotar (le dio vuelta la velocidad
-- en X); aca va el EFECTO del pong (sale mas abierta segun DONDE le pego y para
-- donde se movia la pala) y el 5% de aceleracion de cada golpe.
local function golpe(pala)
  local _, py = posPx(pala)
  local _, alto = tamPx(pala)
  local _, by = posPx(pelota)
  local donde = (by - py) / (alto / 2)    -- -1 le pego arriba, 0 al medio, 1 abajo
  local _, velPala = velocidad(pala)
  local vx = velocidad(pelota)
  velocidad(pelota, vx, (donde * 0.9 + velPala / vPala * 0.45) * vPelota)
  acelerar(pelota, 1.05, vMax)            -- 5% mas rapida, nunca mas que vMax
  beep(226, 90, 0.6)
end
-- Alguien hizo un punto: la pelota se fue por un costado.
local function punto(quien)
  if quien == 1 then p1 = p1 + 1; setTexto(marcador1, p1)
  else               p2 = p2 + 1; setTexto(marcador2, p2) end
  beep(490, 250, 0.7)
  if p1 < GANA and p2 < GANA then saque(); return end
  estado = "fin"                          -- alguien llego a GANA: se termino
  frenar(); mostrar(pelota, false)
  cartelCon(txt.gano .. quien, txt.volver)
end

function inicio()   -- el motor la llama al entrar a la escena: partida nueva
  pelota = objeto("pelota"); pala1 = objeto("pala1"); pala2 = objeto("pala2")
  marcador1 = objeto("marcador1"); marcador2 = objeto("marcador2")
  cancha = objeto("cancha"); cartel = objeto("cartel"); cartelTexto = objeto("cartelTexto")
  btnPausa = objeto("btnPausa"); btnMenu = objeto("btnMenu")
  -- config() son los ajustes guardados: ahi dejaron las pantallas anteriores lo
  -- elegido (cada escena corre aparte, no comparte variables con las otras).
  txt = TXT[config("idioma", "en")] or TXT.en
  jugadores = tonumber(config("wp_jugadores", "1")) or 1
  ia = IA[config("wp_dificultad", "normal")] or IA.normal
  -- La UNICA cuenta de tamanos del script: escala() = lado menor de la pantalla / 480.
  -- Las velocidades son px por segundo (mas pantalla = mas px que recorrer) y la
  -- pelota tiene que ser CUADRADA (las medidas relativas del .w3dui van por eje
  -- y en un celu vertical la deformarian), asi que sus px se ajustan aca.
  local esc = escala()
  vPala = VEL_PALA * esc; vPelota = VEL_PELOTA * esc; vMax = VEL_MAX * esc
  iaVel = ia.vel * esc;   iaError = ia.error * esc
  setTamPx(pelota, TAM_PELOTA * esc, TAM_PELOTA * esc)
  p1, p2 = 0, 0
  setTexto(marcador1, 0); setTexto(marcador2, 0)
  -- el rotulo del boton de pausa, en el idioma elegido (la misma palabra del cartel)
  setTexto(btnPausa, txt.pausa)
  mostrar(pelota, true)
  alMedio()
  frenar(); cartelCon(nil)
  estado = "cuenta"; cuenta = 3
end

function actualizar(dt)
  if estado == "cuenta" then
    local antes = math.ceil(cuenta)       -- 3.. 2.. 1.. con un tic en cada numero
    cuenta = cuenta - dt
    local n = math.ceil(cuenta)
    if n ~= antes then beep(n >= 1 and 400 or 720, 200, 0.5) end
    if n >= 1 then cartelCon(n) else cartelCon(nil); estado = "jugando"; saque() end
  elseif estado == "jugando" then
    if teclaApretada("p") or apretado(btnPausa) then
      guardaVx, guardaVy = velocidad(pelota)   -- congelar la pelota donde esta
      frenar(); estado = "pausa"
      cartelCon(txt.pausa, txt.volver)
    else
      if jugadores == 2 then
        moverPala(pala1, "w", "s", "izq", -1)
        moverPala(pala2, "arriba", "abajo", "der", 1)
      else
        moverPala(pala1, "arriba", "abajo", "izq", 0)
        maquina()
      end
      -- rebotarEn(obj, area, "lados"): la cancha es el area y solo existen las paredes
      -- nombradas; los costados quedan ABIERTOS, por ahi se tiene que poder ir (el punto).
      if rebotarEn(pelota, cancha, "arriba abajo") then beep(459, 70, 0.5) end
      if rebotar(pelota, pala1) then golpe(pala1) end
      if rebotar(pelota, pala2) then golpe(pala2) end
      -- salio por un costado (dentro(area, x) no mira la y): el punto es del que la mando para alla
      local bx = posPx(pelota)
      if not dentro(cancha, bx) then punto(velocidad(pelota) < 0 and 2 or 1) end
    end
  else   -- "pausa" o "fin": en los dos hay un cartel y el boton que lleva al menu
    if estado == "pausa" and (teclaApretada("p") or apretado(btnPausa)) then
      cartelCon(nil); velocidad(pelota, guardaVx, guardaVy); estado = "jugando"
    elseif apretado(btnMenu) or apretado(cartel) or teclaApretada("espacio")
           or teclaApretada("enter") or botonApretado("a") then
      cambiarEscena("Menu")
    end
  end
end
