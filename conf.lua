function love.conf(t)
  t.identity         = "zmine"
  t.version          = "11.5"
  t.console          = false
  t.window.title     = "ZMINE — Zepton Mining"
  t.window.width     = 1920
  t.window.height    = 1080
  t.window.resizable = true
  t.window.minwidth  = 800
  t.window.minheight = 450
  t.window.vsync     = 1
  t.window.msaa      = 0
  t.window.highdpi   = true

  t.modules.thread   = false
  t.modules.video    = false
end
