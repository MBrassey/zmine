-- ZMINE — Zepton Mining
-- Built for love.js / games.brassey.io

local Game = require "src.game"
local Fx   = require "src.fx"

local DESIGN_W, DESIGN_H = 1920, 1080

local state
local fonts
local canvas
local crtShader
local Shaders

local function makeFonts()
  return {
    tiny    = love.graphics.newFont(12),
    small   = love.graphics.newFont(16),
    medium  = love.graphics.newFont(22),
    large   = love.graphics.newFont(28),
    bold    = love.graphics.newFont(22),
    boldL   = love.graphics.newFont(28),
    boldXL  = love.graphics.newFont(38),
    giant   = love.graphics.newFont(48),
  }
end

local function setupCanvas()
  canvas = love.graphics.newCanvas(DESIGN_W, DESIGN_H)
  canvas:setFilter("linear", "linear")
end

local function mouseToDesign(mx, my)
  local w, h = love.graphics.getDimensions()
  local scale = math.min(w / DESIGN_W, h / DESIGN_H)
  local dx = (w - DESIGN_W * scale) * 0.5
  local dy = (h - DESIGN_H * scale) * 0.5
  return (mx - dx) / scale, (my - dy) / scale
end

function love.load()
  love.graphics.setBackgroundColor(0.005, 0.015, 0.010)
  -- Window scaling/positioning hint
  if love.window.setMode then
    love.window.setTitle("ZMINE — Zepton Mining")
  end

  fonts = makeFonts()
  setupCanvas()

  Shaders = require "src.shaders"
  Shaders.load()
  crtShader = Shaders.crt

  state = Game.new({ fonts = fonts })

  -- Welcome message
  print("[ZMINE] facility runtime online")
end

-- ============================================================
-- Deep test harness — set ZMINE_AUTOTEST=1 to drive the game through
-- every scene + tab + interaction in sequence and quit, so smoke
-- tests can verify there are no runtime errors anywhere in the loop.
-- ============================================================
local autotest = os.getenv("ZMINE_AUTOTEST") == "1"
local autoT = 0
local autoStep = 1
local autoSteps

local function pushKey(k)  love.event.push("keypressed", k, k, false) end
local function pushClick(x, y, button)
  love.event.push("mousepressed", x, y, button or 1, false, 1)
  love.event.push("mousereleased", x, y, button or 1, false, 1)
end

if autotest then
  autoSteps = {
    -- {at_seconds, action}
    { 0.5,  function()
        if state and state.scene == "intro" then
          for c in ("AUTOTEST"):gmatch(".") do
            love.event.push("textinput", c)
          end
          pushKey("return")
        end
      end },
    -- World view exercises
    { 1.5,  function() pushKey("d") end },
    { 1.7,  function() pushKey("d") end },
    { 1.9,  function() pushKey("s") end },  -- save AND walk-down (scoped: cross-scene save handler)
    { 2.5,  function() pushKey("c") end },  -- cycle palette
    { 2.7,  function() pushKey("v") end },  -- cycle trail
    { 2.9,  function() pushKey("b") end },  -- cycle aura
    { 3.1,  function() pushKey("n") end },  -- cycle halo
    { 3.3,  function() pushKey("m") end },  -- cycle wings
    { 3.5,  function() pushKey("e") end },  -- wave
    { 3.7,  function() pushKey("f") end },  -- flag
    { 3.9,  function() pushKey("h") end },  -- toggle help
    { 4.0,  function() pushKey("h") end },  -- toggle back
    -- Tab to core ops, cycle every shop tab
    { 4.5,  function() pushKey("space") end },
    { 5.0,  function() pushKey("1") end },
    { 5.3,  function() pushKey("2") end },
    { 5.6,  function() pushKey("3") end },
    { 5.9,  function() pushKey("4") end },
    -- Stress: hammer tab back and forth quickly
    { 6.0,  function() pushKey("space") end },
    { 6.05, function() pushKey("space") end },
    { 6.10, function() pushKey("space") end },
    { 6.15, function() pushKey("space") end },
    { 6.20, function() pushKey("space") end },
    -- HUD scene-icon click (world-pill at x=360-438, y=14-50)
    { 6.30, function() pushClick(395, 32, 1) end },  -- click WORLD icon
    { 6.40, function() pushClick(478, 32, 1) end },  -- click OPS icon
    { 6.50, function() pushClick(395, 32, 1) end },  -- click WORLD again
    -- Click the orb a bunch (streak)
    { 6.5,  function() for i = 1, 12 do pushClick(615, 540, 1) end end },
    -- Pause + resume
    { 7.0,  function() pushKey("p") end },
    { 7.5,  function() pushKey("p") end },
    -- Tab back to world
    { 8.0,  function() pushKey("space") end },
    -- Walk over a pad to trigger pad-step (south side, miner pads)
    { 8.5,  function() pushKey("s") end },
    { 9.0,  function() pushKey("s") end },
    { 9.5,  function() pushKey("s") end },
    -- Save + quit
    { 10.0, function() pushKey("s") end },
    { 10.5, function() pushKey("escape") end },  -- first esc warns
    { 11.0, function() pushKey("escape") end },  -- second esc quits
    { 12.0, function() love.event.quit() end },  -- safety hammer
  }
end

function love.update(dt)
  if dt > 0.1 then dt = 0.1 end
  Game.update(state, dt, fonts)

  if autotest then
    autoT = autoT + dt
    while autoSteps[autoStep] and autoT >= autoSteps[autoStep][1] do
      local ok, err = pcall(autoSteps[autoStep][2])
      if not ok then
        io.stderr:write("[autotest] step " .. autoStep .. " error: " .. tostring(err) .. "\n")
      end
      autoStep = autoStep + 1
    end
  end
end

function love.draw()
  -- Render scene to internal canvas at design res
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 1)
  local mx, my = mouseToDesign(love.mouse.getPosition())
  Game.draw(state, fonts, mx, my)
  love.graphics.setCanvas()

  -- Letterbox + scale
  local w, h = love.graphics.getDimensions()
  local scale = math.min(w / DESIGN_W, h / DESIGN_H)
  local dx = (w - DESIGN_W * scale) * 0.5
  local dy = (h - DESIGN_H * scale) * 0.5

  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)

  -- Apply CRT post-process if available
  if crtShader then
    love.graphics.setShader(crtShader)
    crtShader:send("u_size", { canvas:getWidth(), canvas:getHeight() })
    crtShader:send("u_time", love.timer.getTime())
    -- Calmer baseline; ramp up during a global surge so the screen
    -- visibly stresses when the +50% window is open.
    local surgeOn = state and state.network and state.network._surgeUntil
                    and state.network._surgeUntil > love.timer.getTime()
    crtShader:send("u_strength", surgeOn and 0.32 or 0.10)
  end
  love.graphics.draw(canvas, dx, dy, 0, scale, scale)
  if crtShader then love.graphics.setShader() end

  -- Letterbox edges (subtle frame)
  if dx > 0 or dy > 0 then
    love.graphics.setColor(0.02, 0.05, 0.04, 1)
    if dx > 0 then
      love.graphics.rectangle("fill", 0, 0, dx, h)
      love.graphics.rectangle("fill", w - dx, 0, dx, h)
    end
    if dy > 0 then
      love.graphics.rectangle("fill", 0, 0, w, dy)
      love.graphics.rectangle("fill", 0, h - dy, w, dy)
    end
  end
end

function love.mousepressed(mx, my, button, istouch, presses)
  local lx, ly = mouseToDesign(mx, my)
  Game.mousepressed(state, lx, ly, button)
end

function love.mousereleased(mx, my, button, istouch, presses)
  local lx, ly = mouseToDesign(mx, my)
  Game.mousereleased(state, lx, ly, button)
end

function love.mousemoved(mx, my, dxs, dys, istouch)
  local lx, ly = mouseToDesign(mx, my)
  Game.mousemoved(state, lx, ly, dxs, dys)
end

function love.wheelmoved(dx, dy)
  Game.wheelmoved(state, dx, dy)
end

function love.textinput(text)
  Game.textinput(state, text)
end

function love.keypressed(key, scancode, isrepeat)
  Game.keypressed(state, key)
end

function love.resize(w, h)
  -- Canvas size is fixed; scaling is applied in draw()
end

function love.focus(hasFocus)
  Game.focus(state, hasFocus)
end

function love.quit()
  Game.quit(state)
  -- Clear persistent portal effects so we exit cleanly
  Fx.mood("none", 0)
  Fx.calm("none", 0)
  Fx.pulsate("off")
end

function love.errorhandler(msg)
  -- Minimal error reporter; let LÖVE default fall through if needed
  print("[ZMINE] error: " .. tostring(msg))
  print(debug.traceback())
  return nil
end
