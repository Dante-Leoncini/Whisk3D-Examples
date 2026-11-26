-- ============================================================================
--  juego.lua  ---  las REGLAS del Pong, y nada mas.
--
--  A la pelota NO la movemos nosotros: le damos una VELOCIDAD y la mueve el
--  motor, que ademas resuelve los rebotes (bounce / bounceOn) y nos avisa.
--  Donde va cada cosa en la pantalla lo decide juego.w3dui: aca no hay cuentas
--  de posiciones, y de tamanos solo UNA (la pelota, ver start()).
--
--  CONTROLES  1 jugador: flechas / stick / dedo (la maquina juega la derecha).
--  2 jugadores: la izquierda con W/S, stick izquierdo o el dedo de su mitad; la
--  derecha con las flechas, stick derecho o su mitad. Pausa: tecla P o su boton.
-- ============================================================================

-- Los objetos que usa este script; en juego.w3dui, "refs" dice cual es cual.
properties = { pelota = "object", pala1 = "object", pala2 = "object", cancha = "object",
               marcador1 = "object", marcador2 = "object", cartel = "object",
               cartelTexto = "object", btnPausa = "object", btnMenu = "object" }

-- Los textos en los 3 idiomas (la fuente no dibuja tildes: van sin acentos).
local TXT = {
  es = { pause = "PAUSA", winner = "GANO EL JUGADOR ",  back = "VOLVER AL MENU" },
  en = { pause = "PAUSE", winner = "WINNER: PLAYER ",   back = "BACK TO MENU"   },
  pt = { pause = "PAUSA", winner = "GANHOU O JOGADOR ", back = "VOLTAR AO MENU" },
}

-- Los numeros que dan el "sabor" del juego: cambialos y probalo. Estan pensados
-- para una pantalla de 480 px de lado menor; como el lienzo ahora ES la pantalla
-- real (en un celu hay muchos mas px), start() los multiplica por getScale()
-- (= lado menor / 480) y guarda el resultado en las variables v* / ai*.
local WIN_SCORE    = 7     -- puntos para ganar la partida
local PADDLE_SPEED = 320   -- px por segundo que se mueve una pala
local BALL_SPEED   = 260   -- px por segundo con que sale la pelota al sacar
local MAX_SPEED    = 520   -- mas rapido que esto la pelota no se pone nunca
local BALL_SIZE    = 14    -- lado de la pelota (cuadrada, por eso va en px y no relativa)
local AI = {   -- la maquina, por dificultad: cuanto corre y cuanto se equivoca
  facil = { speed = 150, error = 60 }, normal = { speed = 220, error = 25 }, dificil = { speed = 320, error = 4 } }

-- Los objetos de la escena (se buscan UNA vez, en start) y el estado de la partida
local ball, paddle1, paddle2, score1Text, score2Text, court, banner, bannerText, btnPause, btnMenu
local txt, players, ai             -- idioma y lo que se eligio en las pantallas anteriores
local p1, p2, state, countdown     -- puntaje; "countdown"/"playing"/"paused"/"over"; cuenta regresiva
local savedVx, savedVy             -- velocidad de la pelota mientras esta en pausa
local vPaddle, vBall, vMax         -- las *_SPEED ya pasadas a la pantalla real (start)
local aiSpeed, aiError             -- idem para la maquina

-- Pone la pelota en el medio de la cancha. El medio NO lo calculamos: uiBox(obj)
-- devuelve el CENTRO (y el tamano) del rectangulo que ese objeto ocupa de verdad.
local function centerBall()
  local cx, cy = uiBox(court); setPosPx(ball, cx, cy)
end

-- Saca: la pelota al medio y disparada para un lado al azar. getVelocity(obj, vx, vy)
-- se la entrega al MOTOR: desde aca la mueve el solo.
local function serve()
  centerBall()
  local side = (random(1, 2) == 1) and 1 or -1
  getVelocity(ball, vBall * side, vBall * (random() * 1.2 - 0.6))
end

-- Frena todo lo que se mueve (al pausar y al terminar la partida).
local function stopAll()
  getVelocity(ball, 0, 0); getVelocity(paddle1, 0, 0); getVelocity(paddle2, 0, 0)
end
-- Muestra el cartel del medio y el boton de volver al menu; nil = esconderlos.
local function showBanner(text, buttonLabel)
  show(banner, text ~= nil);  if text then setText(bannerText, text) end
  show(btnMenu, buttonLabel ~= nil); if buttonLabel then setText(btnMenu, buttonLabel) end
end

-- Mueve UNA pala: no le sumamos la posicion a mano, le damos VELOCIDAD. "half":
-- -1 = le hace caso al dedo de la izquierda, 1 = al de la derecha, 0 = a cualquiera.
local function movePaddle(paddle, upKey, downKey, whichStick, half)
  local v = 0
  if key(upKey)   then v = -vPaddle end
  if key(downKey) then v =  vPaddle end
  local _, sy = stick(whichStick)
  if sy < -0.2 or sy > 0.2 then v = vPaddle * sy end
  getVelocity(paddle, 0, v)
  for d = 1, 4 do                      -- finger(1..4): hasta 4 dedos a la vez
    local dx, dy, touching = finger(d)
    -- Del dedo solo importa su MITAD en x: aunque se vaya a la barra, mas alla del
    -- borde o mas abajo de la cancha, la pala lo sigue igual (no se pierde el
    -- control); el limit() de abajo la deja clampeada dentro de la cancha.
    if touching and dx * half >= 0 then
      setPosPx(paddle, nil, dy); getVelocity(paddle, 0, 0)   -- x en nil = ese eje no se toca
    end
  end
  limit(paddle, court)                -- que no se salga de la cancha (el motor lee su caja)
end
-- La maquina (modo 1 jugador): el error se mueve con la X de la pelota, asi
-- "duda" mientras la pelota viaja y se acomoda cuando la tiene cerca.
local function aiPlay()
  local bx, by = getPosPx(ball)
  local _, py = getPosPx(paddle2)
  local target = by + aiError * math.sin(bx * 0.05)
  local v = 0
  if py < target - 6 then v = aiSpeed elseif py > target + 6 then v = -aiSpeed end
  getVelocity(paddle2, 0, v)
  limit(paddle2, court)
end

-- El golpe contra una pala: el motor ya la hizo rebotar (le dio vuelta la velocidad
-- en X); aca va el EFECTO del pong (sale mas abierta segun DONDE le pego y para
-- donde se movia la pala) y el 5% de aceleracion de cada golpe.
local function hit(paddle)
  local _, py = getPosPx(paddle)
  local _, height = getSizePx(paddle)
  local _, by = getPosPx(ball)
  local where = (by - py) / (height / 2)    -- -1 le pego arriba, 0 al medio, 1 abajo
  local _, paddleVy = getVelocity(paddle)
  local vx = getVelocity(ball)
  getVelocity(ball, vx, (where * 0.9 + paddleVy / vPaddle * 0.45) * vBall)
  accelerate(ball, 1.05, vMax)            -- 5% mas rapida, nunca mas que vMax
  beep(226, 90, 0.6)
end
-- Alguien hizo un punto: la pelota se fue por un costado.
local function point(who)
  if who == 1 then p1 = p1 + 1; setText(score1Text, p1)
  else             p2 = p2 + 1; setText(score2Text, p2) end
  beep(490, 250, 0.7)
  if p1 < WIN_SCORE and p2 < WIN_SCORE then serve(); return end
  state = "over"                          -- alguien llego a WIN_SCORE: se termino
  stopAll(); show(ball, false)
  showBanner(txt.winner .. who, txt.back)
end

function start()   -- el motor la llama al entrar a la escena: partida nueva
  ball = object("pelota"); paddle1 = object("pala1"); paddle2 = object("pala2")
  score1Text = object("marcador1"); score2Text = object("marcador2")
  court = object("cancha"); banner = object("cartel"); bannerText = object("cartelTexto")
  btnPause = object("btnPausa"); btnMenu = object("btnMenu")
  -- getConfig() son los ajustes guardados: ahi dejaron las pantallas anteriores lo
  -- elegido (cada escena corre aparte, no comparte variables con las otras).
  txt = TXT[getConfig("idioma", "en")] or TXT.en
  players = tonumber(getConfig("wp_jugadores", "1")) or 1
  ai = AI[getConfig("wp_dificultad", "normal")] or AI.normal
  -- La UNICA cuenta de tamanos del script: getScale() = lado menor de la pantalla / 480.
  -- Las velocidades son px por segundo (mas pantalla = mas px que recorrer) y la
  -- pelota tiene que ser CUADRADA (las medidas relativas del .w3dui van por eje
  -- y en un celu vertical la deformarian), asi que sus px se ajustan aca.
  local scale = getScale()
  vPaddle = PADDLE_SPEED * scale; vBall = BALL_SPEED * scale; vMax = MAX_SPEED * scale
  aiSpeed = ai.speed * scale;     aiError = ai.error * scale
  setSizePx(ball, BALL_SIZE * scale, BALL_SIZE * scale)
  p1, p2 = 0, 0
  setText(score1Text, 0); setText(score2Text, 0)
  -- el rotulo del boton de pausa, en el idioma elegido (la misma palabra del cartel)
  setText(btnPause, txt.pause)
  show(ball, true)
  centerBall()
  stopAll(); showBanner(nil)
  state = "countdown"; countdown = 3
end

function update(dt)
  if state == "countdown" then
    local before = math.ceil(countdown)   -- 3.. 2.. 1.. con un tic en cada numero
    countdown = countdown - dt
    local n = math.ceil(countdown)
    if n ~= before then beep(n >= 1 and 400 or 720, 200, 0.5) end
    if n >= 1 then showBanner(n) else showBanner(nil); state = "playing"; serve() end
  elseif state == "playing" then
    if keyPressed("p") or pressed(btnPause) then
      savedVx, savedVy = getVelocity(ball)   -- congelar la pelota donde esta
      stopAll(); state = "paused"
      showBanner(txt.pause, txt.back)
    else
      if players == 2 then
        movePaddle(paddle1, "w", "s", "left", -1)
        movePaddle(paddle2, "up", "down", "right", 1)
      else
        movePaddle(paddle1, "up", "down", "left", 0)
        aiPlay()
      end
      -- bounceOn(obj, area, "lados"): la cancha es el area y solo existen las paredes
      -- nombradas; los costados quedan ABIERTOS, por ahi se tiene que poder ir (el punto).
      if bounceOn(ball, court, "top bottom") then beep(459, 70, 0.5) end
      if bounce(ball, paddle1) then hit(paddle1) end
      if bounce(ball, paddle2) then hit(paddle2) end
      -- salio por un costado (inside(area, x) no mira la y): el punto es del que la mando para alla
      local bx = getPosPx(ball)
      if not inside(court, bx) then point(getVelocity(ball) < 0 and 2 or 1) end
    end
  else   -- "paused" u "over": en los dos hay un cartel y el boton que lleva al menu
    if state == "paused" and (keyPressed("p") or pressed(btnPause)) then
      showBanner(nil); getVelocity(ball, savedVx, savedVy); state = "playing"
    elseif pressed(btnMenu) or pressed(banner) or keyPressed("space")
           or keyPressed("enter") or buttonPressed("a") then
      changeScene("Menu")
    end
  end
end
