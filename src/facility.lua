local fmt = require "src.format"
local minersDb = require "src.miners"
local energyDb = require "src.energy"

local M = {}

local DESIGN_W, DESIGN_H = 1920, 1080
-- Mining/visualization area on left:
local AREA = { x = 24, y = 116, w = 1196, h = 900 }
local CORE_X = AREA.x + AREA.w / 2 - 30
local CORE_Y = AREA.y + 360
local CORE_RADIUS = 200

local pixelImage  -- a 1×1 white image for shader-based rectangles

local function ensurePixel()
  if pixelImage then return end
  local d = love.image.newImageData(1, 1)
  d:setPixel(0, 0, 1, 1, 1, 1)
  pixelImage = love.graphics.newImage(d)
end

-- Background star/particle system, separate from gameplay particles.
local stars
local function ensureStars()
  if stars then return end
  stars = {}
  for i = 1, 220 do
    stars[#stars + 1] = {
      x = love.math.random() * AREA.w,
      y = love.math.random() * AREA.h,
      z = 0.2 + love.math.random() * 0.8,
      tw = love.math.random() * math.pi * 2,
      twF = 0.5 + love.math.random() * 2,
    }
  end
end

function M.init()
  ensurePixel()
  ensureStars()
end

function M.coreCenter()
  return CORE_X, CORE_Y
end

function M.coreRadius()
  return CORE_RADIUS
end

function M.area()
  return AREA
end

function M.pointInCore(x, y)
  local dx = x - CORE_X
  local dy = y - CORE_Y
  return dx * dx + dy * dy <= (CORE_RADIUS + 20) * (CORE_RADIUS + 20)
end

local function drawBackground(t, shaders, mood)
  ensurePixel()
  -- Grid shader
  if shaders.bgGrid then
    love.graphics.setShader(shaders.bgGrid)
    shaders.bgGrid:send("u_size", { AREA.w, AREA.h })
    shaders.bgGrid:send("u_time", t)
    local tint = mood or { 0.30, 1.00, 0.55 }
    shaders.bgGrid:send("u_tint", tint)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(pixelImage, AREA.x, AREA.y, 0, AREA.w, AREA.h)
    love.graphics.setShader()
  else
    love.graphics.setColor(0.02, 0.04, 0.03, 1)
    love.graphics.rectangle("fill", AREA.x, AREA.y, AREA.w, AREA.h)
  end

  -- Stars
  ensureStars()
  for _, s in ipairs(stars) do
    s.x = (s.x - 8 * s.z * love.timer.getDelta()) % AREA.w
    local tw = math.sin(t * s.twF + s.tw) * 0.5 + 0.5
    love.graphics.setColor(0.55, 1, 0.75, 0.15 + tw * 0.30 * s.z)
    love.graphics.points(AREA.x + s.x, AREA.y + s.y)
  end
end

local function drawTelemetryStrip(state, fonts, t)
  -- Top-left readout (operations metadata)
  local lx, ly = AREA.x + 18, AREA.y + 14
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.30, 0.65, 0.45, 0.85)
  local lines = {
    string.format("ID  %05X", (state.facility_seed or 0) % 0xFFFFF),
    string.format("LAT %.2f / LON %.2f", -71.21 + math.sin(t * 0.05) * 0.01, 42.39 + math.cos(t * 0.05) * 0.01),
    string.format("UTC %010d", math.floor(t * 60)),
    string.format("CYC %.2f Hz", 60 + math.sin(t) * 1.2),
  }
  for i, l in ipairs(lines) do
    love.graphics.print(l, lx, ly + (i - 1) * 14)
  end

  -- Top-right readout (PoW telemetry)
  local rx = AREA.x + AREA.w - 280
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.85, 0.95, 0.45, 0.95)
  local rlines = {
    string.format("HASH   %s", fmt.hashRate(state.hashrate or 0)),
    string.format("DIFF   %.2e", state.difficulty or 0),
    string.format("BLOCK  #%d", state.block_height or 0),
    string.format("UTIL   %s", fmt.percent(state.energy_supply > 0 and state.energy_used / state.energy_supply or 0)),
  }
  for i, l in ipairs(rlines) do
    love.graphics.print(l, rx, ly + (i - 1) * 14)
  end

  -- Block label (header)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.45, 0.85, 0.65, 0.95)
  local hdr = "::  CORE OPERATIONS  ::"
  local hw = fonts.small:getWidth(hdr)
  love.graphics.print(hdr, AREA.x + AREA.w / 2 - hw / 2, AREA.y + 14)

  -- Pool indicator (mid line, if pooled)
  if state.network and state.network.pool_with then
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.55, 0.85, 0.95, 0.95)
    local poolName = "?"
    for _, p in ipairs(state.network.players) do
      if p.id == state.network.pool_with then poolName = p.name; break end
    end
    local txt = "⛓  pooled with " .. poolName
    local tw = fonts.tiny:getWidth(txt)
    love.graphics.print(txt, AREA.x + AREA.w / 2 - tw / 2, AREA.y + 38)
  end

  -- Boost outflow indicator (last few)
  if state.network and state.network.interactions then
    local recent = 0
    for _, it in ipairs(state.network.interactions) do
      if (state.network._t or 0) - (it.t or 0) < 5 then recent = recent + 1 end
    end
    if recent > 0 then
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.55, 0.85, 1, 0.95)
      love.graphics.print("⇄  outbound boosts: " .. recent, AREA.x + AREA.w - 280, AREA.y + 76)
    end
  end
end

local function drawConduits(state, t)
  local cx, cy = CORE_X, CORE_Y
  -- Lower deck miners — draw rotating conduit lines from core to miner positions
  local miners = state.miners
  local total = 0
  for _, c in pairs(miners) do total = total + c end
  if total <= 0 then return end

  -- Place miners on an arc below the core
  local n = 0
  for _, def in ipairs(minersDb.list) do
    if (miners[def.key] or 0) > 0 then n = n + 1 end
  end
  if n == 0 then return end

  local idx = 0
  local arcStart = math.pi * 0.20
  local arcEnd   = math.pi * 0.80
  for _, def in ipairs(minersDb.list) do
    local count = miners[def.key] or 0
    if count > 0 then
      idx = idx + 1
      local frac = (n == 1) and 0.5 or (idx - 1) / (n - 1)
      local ang = arcStart + frac * (arcEnd - arcStart)
      local r = 360 + (def.tier - 1) * 12
      local mx = cx + math.cos(ang) * r
      local my = cy + math.sin(ang) * r * 0.55 + 80

      -- Conduit pulse
      local steps = 8
      for k = 0, steps - 1 do
        local p = (k / steps + (t * 0.4)) % 1
        local lx = cx + (mx - cx) * p
        local ly = cy + (my - cy) * p
        love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.55 - p * 0.4)
        love.graphics.circle("fill", lx, ly, 3 - p * 1.5)
      end
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.20)
      love.graphics.setLineWidth(1)
      love.graphics.line(cx, cy, mx, my)

      -- Miner glyph
      love.graphics.push()
      love.graphics.translate(mx, my)
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.90)
      local r2 = 22
      local pts = {}
      for k = 0, 5 do
        local a = k * math.pi / 3 + t * 0.5 * (def.tier % 2 == 0 and 1 or -1)
        pts[#pts + 1] = math.cos(a) * r2
        pts[#pts + 1] = math.sin(a) * r2
      end
      love.graphics.polygon("line", pts)
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.40)
      love.graphics.polygon("fill", pts)
      -- Inner indicator
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 1)
      love.graphics.circle("fill", 0, 0, 4)
      love.graphics.pop()

      -- Count badge
      love.graphics.setFont(love.graphics.getFont())
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.circle("fill", mx + 18, my - 18, 10)
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 1)
      love.graphics.circle("line", mx + 18, my - 18, 10)
      love.graphics.setColor(1, 1, 1, 1)
      local s = tostring(count)
      love.graphics.printf(s, mx + 18 - 14, my - 18 - 6, 28, "center")
    end
  end
end

local function drawEnergyRing(state, t, fonts)
  local cx, cy = CORE_X, CORE_Y
  -- Place energy sources on an upper arc
  local energy = state.energy
  local n = 0
  for _, def in ipairs(energyDb.list) do
    if (energy[def.key] or 0) > 0 then n = n + 1 end
  end
  if n == 0 then return end

  local idx = 0
  local arcStart = math.pi * 1.10
  local arcEnd   = math.pi * 1.90
  for _, def in ipairs(energyDb.list) do
    local count = energy[def.key] or 0
    if count > 0 then
      idx = idx + 1
      local frac = (n == 1) and 0.5 or (idx - 1) / (n - 1)
      local ang = arcStart + frac * (arcEnd - arcStart)
      local r = 320 + (def.tier - 1) * 6
      local ex = cx + math.cos(ang) * r
      local ey = cy + math.sin(ang) * r * 0.7

      -- Conduit pulse (energy → core)
      local steps = 8
      for k = 0, steps - 1 do
        local p = (k / steps - (t * 0.5)) % 1
        local lx = ex + (cx - ex) * p
        local ly = ey + (cy - ey) * p
        love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.55 - p * 0.35)
        love.graphics.circle("fill", lx, ly, 3 - p * 1.5)
      end
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.18)
      love.graphics.line(ex, ey, cx, cy)

      -- Energy glyph: rotating bolts
      love.graphics.push()
      love.graphics.translate(ex, ey)
      love.graphics.rotate(t * 0.4 * (def.tier % 2 == 0 and 1 or -1))
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 1)
      love.graphics.setLineWidth(2)
      local rays = math.min(def.tier + 2, 7)
      for k = 0, rays - 1 do
        local a = k * math.pi * 2 / rays
        love.graphics.line(0, 0, math.cos(a) * 20, math.sin(a) * 20)
      end
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.6)
      love.graphics.circle("fill", 0, 0, 6)
      love.graphics.setColor(1, 1, 1, 0.85)
      love.graphics.circle("fill", 0, 0, 3)
      love.graphics.pop()
      love.graphics.setLineWidth(1)

      -- Count
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.circle("fill", ex + 18, ey - 18, 10)
      love.graphics.setColor(def.color[1], def.color[2], def.color[3], 1)
      love.graphics.circle("line", ex + 18, ey - 18, 10)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setFont(fonts.tiny)
      love.graphics.printf(tostring(count), ex + 18 - 14, ey - 18 - 6, 28, "center")
    end
  end
end

local function drawCore(state, t, shaders)
  ensurePixel()
  local cx, cy = CORE_X, CORE_Y
  -- Outer halo
  for i = 0, 6 do
    local r = CORE_RADIUS + 30 + i * 12
    local a = (1 - i / 7) * 0.10 * (0.85 + math.sin(t * 1.3 + i) * 0.15)
    love.graphics.setColor(0.30, 1.00, 0.55, a)
    love.graphics.circle("fill", cx, cy, r)
  end

  if shaders.coreGlow then
    love.graphics.setShader(shaders.coreGlow)
    shaders.coreGlow:send("u_color", { 0.30, 1.00, 0.55 })
    shaders.coreGlow:send("u_time", t)
    shaders.coreGlow:send("u_intensity", state.coreIntensity or 1.0)
    shaders.coreGlow:send("u_pulse", state.corePulse or 0.0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(pixelImage,
      cx - CORE_RADIUS, cy - CORE_RADIUS, 0,
      CORE_RADIUS * 2, CORE_RADIUS * 2)
    love.graphics.setShader()
  else
    -- Fallback
    love.graphics.setColor(0.30, 1.00, 0.55, 1)
    love.graphics.circle("fill", cx, cy, CORE_RADIUS * 0.5)
  end

  -- Rotating runes around core
  local runes = 12
  love.graphics.setColor(0.45, 1, 0.65, 0.85)
  love.graphics.setLineWidth(1.5)
  for i = 0, runes - 1 do
    local a = (i / runes) * math.pi * 2 + t * 0.20
    local r1 = CORE_RADIUS + 38
    local r2 = CORE_RADIUS + 60
    local x1 = cx + math.cos(a) * r1
    local y1 = cy + math.sin(a) * r1
    local x2 = cx + math.cos(a) * r2
    local y2 = cy + math.sin(a) * r2
    love.graphics.line(x1, y1, x2, y2)
  end
  love.graphics.setLineWidth(1)

  -- Hold ring (when player is holding click on core)
  if state.coreHold and state.coreHold > 0 then
    local p = math.min(1, state.coreHold / 10) -- ten-second secret
    love.graphics.setColor(0.55, 1, 0.75, 0.45 + math.sin(t * 6) * 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", cx, cy,
      CORE_RADIUS + 80,
      -math.pi / 2,
      -math.pi / 2 + p * math.pi * 2)
    love.graphics.setLineWidth(1)
  end

  -- Core text label
  love.graphics.setFont(love.graphics.getFont())
  love.graphics.setColor(0.85, 1, 0.92, 0.95)
  local label = "CLICK / HOLD"
  local lw = love.graphics.getFont():getWidth(label)
  love.graphics.print(label, cx - lw / 2, cy + CORE_RADIUS + 90)
end

local function drawFooterStrip(state, fonts, t)
  local fx = AREA.x
  local fy = AREA.y + AREA.h - 86
  local fw = AREA.w
  local fh = 80
  love.graphics.setColor(0.04, 0.07, 0.06, 0.90)
  love.graphics.rectangle("fill", fx, fy, fw, fh, 6, 6)
  love.graphics.setColor(0.20, 0.55, 0.32, 0.7)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", fx, fy, fw, fh, 6, 6)

  -- Hint columns
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.50, 0.85, 0.65, 0.95)
  love.graphics.print("◐ CLICK CORE TO MINE     │     [SHIFT] BUY ×10     │     [CTRL] BUY MAX     │     [P] PAUSE     │     [S] SAVE     │     [1] MINERS  [2] ENERGY  [3] RESEARCH  [4] NETWORK",
    fx + 18, fy + 18)

  -- Day cycle info
  local phase = state.day_phase or 0
  local hours = (phase * 24)
  local ampm = (hours >= 12) and "PM" or "AM"
  local dispH = math.floor(hours) % 12
  if dispH == 0 then dispH = 12 end
  local mins = math.floor((hours - math.floor(hours)) * 60)
  love.graphics.setColor(1, 0.95, 0.55, 0.95)
  love.graphics.print(string.format("◌ FACILITY CLOCK  %02d:%02d %s",
    dispH, mins, ampm), fx + 18, fy + 42)

  -- Status messages (last 3 from state.messages)
  if state.messages then
    local mx = fx + fw - 480
    for i = #state.messages, math.max(1, #state.messages - 2), -1 do
      local m = state.messages[i]
      local age = love.timer.getTime() - m.t
      if age < 8 then
        local alpha = math.min(1, math.max(0.2, 1 - age / 8))
        love.graphics.setColor(m.c[1], m.c[2], m.c[3], alpha)
        love.graphics.print(m.text, mx, fy + 14 + (#state.messages - i) * 18)
      end
    end
  end
end

function M.draw(state, fonts, t, shaders, mood)
  -- Outer frame
  love.graphics.setColor(0.04, 0.07, 0.06, 1)
  love.graphics.rectangle("fill", AREA.x, AREA.y, AREA.w, AREA.h, 8, 8)
  love.graphics.setColor(0.18, 0.55, 0.32, 0.8)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", AREA.x, AREA.y, AREA.w, AREA.h, 8, 8)
  love.graphics.setLineWidth(1)

  -- Inner clip for content
  local sw, sh = love.graphics.getDimensions()
  local sc = math.min(sw / DESIGN_W, sh / DESIGN_H)
  local dx = (sw - DESIGN_W * sc) * 0.5
  local dy = (sh - DESIGN_H * sc) * 0.5
  love.graphics.setScissor(
    math.floor((AREA.x + 2) * sc + dx),
    math.floor((AREA.y + 2) * sc + dy),
    math.ceil((AREA.w - 4) * sc),
    math.ceil((AREA.h - 4) * sc))
  drawBackground(t, shaders, mood)
  drawTelemetryStrip(state, fonts, t)
  drawEnergyRing(state, t, fonts)
  drawConduits(state, t)
  drawCore(state, t, shaders)
  drawFooterStrip(state, fonts, t)
  love.graphics.setScissor()
end

return M
