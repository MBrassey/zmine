-- Miracle visual overlays. Drawn on top of (or behind) the world
-- entities depending on the kind. Each miracle has both a "sky"
-- (background) phase and a "post" (foreground) phase.

local M = {}

local DESIGN_W, DESIGN_H = 1920, 1080

local function active(state, key)
  local until_t = state.active_miracles and state.active_miracles[key]
  if not until_t then return false end
  local now = love.timer.getTime()
  if until_t < now then return false end
  -- 0..1 alpha based on age (fade in/out at the edges)
  local total = until_t - now
  local alpha = 1.0
  if total < 4 then alpha = total / 4 end
  return true, alpha
end

local function drawSunny(t, alpha)
  -- Warm gold tint + bright sun in upper-right
  love.graphics.setColor(1, 0.85, 0.45, 0.18 * alpha)
  love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  for r = 80, 0, -1 do
    love.graphics.setColor(1, 0.95, 0.55, (1 - r/80) * 0.06 * alpha)
    love.graphics.circle("fill", DESIGN_W - 200, 200, r)
  end
  love.graphics.setColor(1, 1, 0.65, 0.95 * alpha)
  love.graphics.circle("fill", DESIGN_W - 200, 200, 36)
end

local function drawRain(t, alpha)
  love.graphics.setColor(0.20, 0.30, 0.45, 0.28 * alpha)
  love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  -- Falling rain lines (deterministic seeded slots)
  love.graphics.setColor(0.65, 0.85, 1, 0.65 * alpha)
  love.graphics.setLineWidth(1.2)
  for i = 1, 220 do
    local x = ((i * 191 + math.floor(t * 800)) % DESIGN_W)
    local y = ((i * 73 + math.floor(t * 1200)) % DESIGN_H)
    love.graphics.line(x, y, x - 4, y + 12)
  end
  love.graphics.setLineWidth(1)
end

local function drawSnow(t, alpha)
  love.graphics.setColor(0.88, 0.92, 1, 0.18 * alpha)
  love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  for i = 1, 140 do
    local sway = math.sin(t + i * 0.7) * 14
    local x = ((i * 211 + math.floor(t * 60)) % DESIGN_W) + sway
    local y = ((i * 103 + math.floor(t * 90))  % DESIGN_H)
    love.graphics.setColor(1, 1, 1, 0.85 * alpha)
    love.graphics.circle("fill", x, y, 1.6 + (i % 3) * 0.8)
  end
end

local function drawLightning(t, alpha)
  love.graphics.setColor(0.05, 0.05, 0.10, 0.40 * alpha)
  love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  -- Occasional flash (every ~3 s)
  local cyc = t % 3.0
  if cyc < 0.18 then
    local f = 1 - cyc / 0.18
    love.graphics.setColor(0.85, 0.85, 1, 0.50 * f * alpha)
    love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
    -- Bolt zigzag
    local bx = 200 + ((math.floor(t / 3) * 217) % (DESIGN_W - 400))
    local by = 0
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setLineWidth(2)
    local lx, ly = bx, by
    for k = 1, 6 do
      local nx = lx + (love.math.random() - 0.5) * 60
      local ny = ly + 80
      love.graphics.line(lx, ly, nx, ny)
      lx, ly = nx, ny
    end
    love.graphics.setLineWidth(1)
  end
end

local function drawAurora(t, alpha)
  for band = 0, 5 do
    for x = 0, DESIGN_W, 12 do
      local wave = math.sin((x + t * 90 + band * 80) * 0.012) * 40
      local y = 100 + band * 20 + wave
      local hue = (band + math.sin(t * 0.3 + x * 0.005)) % 3
      local r, g, b
      if hue < 1 then r, g, b = 0.40, 1.00, 0.65
      elseif hue < 2 then r, g, b = 0.55, 0.85, 1.00
      else r, g, b = 0.85, 0.55, 1.00 end
      love.graphics.setColor(r, g, b, 0.30 * alpha)
      love.graphics.rectangle("fill", x, y, 12, 60)
    end
  end
end

local function drawStarfall(t, alpha)
  for i = 1, 40 do
    local seed = (i * 137 + math.floor(t / 2)) % 9999
    local x0 = (seed * 191) % DESIGN_W
    local y0 = (seed * 73)  % (DESIGN_H / 2)
    local pt = ((t * 0.6 + i * 0.1) % 1)
    local x = x0 + pt * 220
    local y = y0 + pt * 320
    love.graphics.setColor(1, 0.95, 0.70, (1 - pt) * 0.95 * alpha)
    love.graphics.line(x, y, x - 24, y - 30)
    love.graphics.circle("fill", x, y, 1.5)
  end
end

local function drawGrassy(t, alpha)
  love.graphics.setColor(0.30, 0.85, 0.40, 0.18 * alpha)
  love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  -- Subtle drifting leaves
  for i = 1, 30 do
    local sway = math.sin(t + i) * 30
    local x = ((i * 211 + math.floor(t * 40)) % DESIGN_W) + sway
    local y = ((i * 71  + math.floor(t * 30)) % DESIGN_H)
    love.graphics.setColor(0.40, 0.85, 0.35, 0.85 * alpha)
    love.graphics.circle("fill", x, y, 2)
  end
end

local function drawLakes(t, alpha)
  -- Shimmering blue ellipses at fixed ground positions
  for i = 1, 5 do
    local x = (i * 380) % DESIGN_W
    local y = 720 + (i * 53) % 200
    local r = 100 + math.sin(t + i) * 6
    love.graphics.setColor(0.30, 0.60, 1.00, 0.45 * alpha)
    love.graphics.ellipse("fill", x, y, r, r * 0.35)
    love.graphics.setColor(0.85, 0.95, 1.00, 0.55 * alpha)
    love.graphics.ellipse("line", x, y, r, r * 0.35)
  end
end

local function drawRivers(t, alpha)
  for i = 0, 3 do
    local y = 740 + i * 70
    local pts = {}
    for x = 0, DESIGN_W, 12 do
      local wave = math.sin((x + t * 80 + i * 100) * 0.010) * 14
      pts[#pts + 1] = x
      pts[#pts + 1] = y + wave
    end
    love.graphics.setColor(0.40, 0.70, 1.00, 0.55 * alpha)
    love.graphics.setLineWidth(8)
    love.graphics.line(pts)
    love.graphics.setLineWidth(1)
  end
end

local function drawMountains(t, alpha)
  -- Silhouette polygons spanning the horizon
  love.graphics.setColor(0.18, 0.20, 0.28, 0.85 * alpha)
  local pts = { 0, 540 }
  for x = 0, DESIGN_W, 30 do
    local h = 540 - math.abs(math.sin(x * 0.0035 + 1.2)) * 280
              - math.abs(math.sin(x * 0.0011)) * 80
    pts[#pts + 1] = x
    pts[#pts + 1] = h
  end
  pts[#pts + 1] = DESIGN_W
  pts[#pts + 1] = 540
  love.graphics.polygon("fill", pts)
  -- Snow caps
  love.graphics.setColor(1, 1, 1, 0.45 * alpha)
  for x = 80, DESIGN_W, 200 do
    local h = 540 - math.abs(math.sin(x * 0.0035 + 1.2)) * 280
              - math.abs(math.sin(x * 0.0011)) * 80
    if h < 320 then
      love.graphics.polygon("fill",
        x - 18, h + 8, x + 18, h + 8, x, h - 4)
    end
  end
end

local function drawCherryBloom(t, alpha)
  for i = 1, 80 do
    local sway = math.sin(t + i * 0.6) * 30
    local x = ((i * 191 + math.floor(t * 40)) % DESIGN_W) + sway
    local y = ((i * 71  + math.floor(t * 30)) % DESIGN_H)
    love.graphics.setColor(1, 0.6 + (i % 3) * 0.1, 0.85, 0.85 * alpha)
    love.graphics.circle("fill", x, y, 2.5)
  end
end

local function drawFireflies(t, alpha)
  for i = 1, 60 do
    local x = ((i * 211 + math.floor(t * 12)) % DESIGN_W)
    local y = ((i * 91  + math.floor(t * 9))  % DESIGN_H)
    local pulse = math.sin(t * 3 + i) * 0.5 + 0.5
    love.graphics.setColor(1, 0.95, 0.55, 0.65 * pulse * alpha)
    love.graphics.circle("fill", x, y, 4)
    love.graphics.setColor(1, 1, 0.85, 0.95 * pulse * alpha)
    love.graphics.circle("fill", x, y, 1.4)
  end
end

local function drawAngels(t, alpha)
  for i = 1, 5 do
    local cx = (DESIGN_W / 6) + (i * DESIGN_W / 6)
    local cy = 200 + math.sin(t * 0.4 + i) * 60
    -- Body: glow halo
    love.graphics.setColor(1, 1, 0.95, 0.35 * alpha)
    love.graphics.circle("fill", cx, cy, 36)
    love.graphics.setColor(1, 1, 0.95, 0.85 * alpha)
    love.graphics.circle("fill", cx, cy, 14)
    -- Wings
    local flap = math.sin(t * 2 + i) * 10
    love.graphics.setColor(1, 1, 1, 0.85 * alpha)
    love.graphics.polygon("fill",
      cx - 26, cy + flap,  cx - 6, cy - 6,  cx - 6, cy + 12)
    love.graphics.polygon("fill",
      cx + 26, cy + flap,  cx + 6, cy - 6,  cx + 6, cy + 12)
    -- Halo
    love.graphics.setColor(1, 0.95, 0.55, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", cx, cy - 18, 12, 4)
    love.graphics.setLineWidth(1)
  end
end

-- ============================================================
-- Public draw — call BEFORE the world entities (sky phase) and AGAIN
-- after (post phase). Returns nothing.
-- ============================================================

function M.drawSky(state, t)
  local on, a
  on, a = active(state, "sunny_day");      if on then drawSunny(t, a) end
  on, a = active(state, "rainstorm");      if on then drawRain(t, a) end
  on, a = active(state, "snow");           if on then drawSnow(t, a) end
  on, a = active(state, "lightning");      if on then drawLightning(t, a) end
  on, a = active(state, "aurora");         if on then drawAurora(t, a) end
  on, a = active(state, "starfall");       if on then drawStarfall(t, a) end
  on, a = active(state, "grassy_fields");  if on then drawGrassy(t, a) end
  on, a = active(state, "mountains");      if on then drawMountains(t, a) end
  on, a = active(state, "lakes");          if on then drawLakes(t, a) end
  on, a = active(state, "rivers");         if on then drawRivers(t, a) end
end

function M.drawPost(state, t)
  local on, a
  on, a = active(state, "cherry_bloom");   if on then drawCherryBloom(t, a) end
  on, a = active(state, "fireflies");      if on then drawFireflies(t, a) end
  on, a = active(state, "angels");         if on then drawAngels(t, a) end
end

-- Status pills (one per active miracle) — drawn in the top-right HUD
-- area. Returns the bottom y of the last pill rendered so callers can
-- stack other elements beneath.
function M.drawStatus(state, fonts, t, x, y)
  local now = love.timer.getTime()
  local row = 0
  for key, expiresAt in pairs(state.active_miracles or {}) do
    if expiresAt and expiresAt > now then
      local def = require("src.miracles").byKey[key]
      if def then
        local rem = expiresAt - now
        local pulse = 0.7 + math.sin(t * 3) * 0.3
        local pw, ph = 220, 22
        local px = x
        local py = y + row * (ph + 4)
        love.graphics.setColor(0.04, 0.07, 0.06, 0.92)
        love.graphics.rectangle("fill", px, py, pw, ph, 4, 4)
        love.graphics.setColor(def.color[1], def.color[2], def.color[3], pulse)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", px, py, pw, ph, 4, 4)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(fonts.tiny)
        love.graphics.setColor(def.color[1], def.color[2], def.color[3], 1)
        love.graphics.print("✦ " .. def.name, px + 8, py + 4)
        local secs = math.floor(rem)
        local timeStr
        if secs >= 60 then timeStr = string.format("%dm%ds", math.floor(secs / 60), secs % 60)
        else timeStr = secs .. "s" end
        love.graphics.setColor(0.95, 1, 0.92, 0.95)
        love.graphics.printf(timeStr, px, py + 4, pw - 10, "right")
        row = row + 1
      end
    end
  end
  return y + row * (ph and (ph + 4) or 26)
end

return M
