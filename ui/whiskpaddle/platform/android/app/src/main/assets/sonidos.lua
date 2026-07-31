-- ============================================================================
--  sonidos.lua  ---  el boton de SONIDO (prender / apagar), y nada mas.
--
--  Se agrega a las TRES escenas, asi el boton anda igual en todas. Los efectos NO
--  pasan por aca: cada escena toca su beep(frecuenciaHz, duracionMs, volumen) donde
--  ocurre la cosa, y beep() ya respeta el mute. El boton son 3 objetos del .w3dui:
--  el cuadradito que se toca y los DOS dibujos del parlante (se ve el que va).
-- ============================================================================

propiedades = { btnSonido = "objeto", icono = "objeto", iconoMudo = "objeto" }

function actualizar(dt)
  -- Tocar el boton, o la tecla M, da vuelta el mute y lo deja guardado.
  if apretado(objeto("btnSonido")) or teclaApretada("m") then
    silenciar(not estaMudo())
    guardarConfig()
    if not estaMudo() then beep(520, 60, 0.5) end   -- pitido al PRENDER el sonido
  end
  mostrar(objeto("icono"),     not estaMudo())
  mostrar(objeto("iconoMudo"), estaMudo())
end
