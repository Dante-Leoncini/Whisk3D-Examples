-- hola.lua -- el juego MAS SIMPLE de Whisk3D (un "hola mundo").
-- El contrato de todo juego son 3 cosas: propiedades, inicio() y actualizar(dt).

-- propiedades: declara los objetos de la escena que este script usa, por su nombre.
-- Aca pido uno solo: un rectangulo al que llamo "cuadro" (lo conecto en el .w3d).
propiedades = {
  cuadro = "objeto",
}

-- inicio(): el motor la llama UNA sola vez, al dar Play. Sirve para preparar cosas.
function inicio()
  beep(440, 120, 0.5)   -- pitido corto de bienvenida (frecuencia Hz, duracion ms, volumen)
end

-- actualizar(dt): el motor la llama CADA frame. dt = segundos desde el frame anterior.
-- Movemos el cuadro con las flechas arriba/abajo, a 200 px por segundo.
function actualizar(dt)
  local x, y = posPx(objeto("cuadro"))          -- posicion actual (centro, en px; 0,0 = centro)
  if tecla("arriba") then y = y - 200 * dt end   -- arriba = restar en y
  if tecla("abajo")  then y = y + 200 * dt end   -- abajo  = sumar en y
  setPosPx(objeto("cuadro"), x, y)              -- reubicamos el cuadro
end
