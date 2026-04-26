-- Character: Roblox-style stacked-block humanoid with rich passive
-- micro-motion. Tries hard to feel "alive" without leaving 2D love2d.
-- Idle: breathing (chest expand), gentle sway, blink, occasional
-- head-tilt, hand twitch. Walking: head bob, leg lift, arm swing,
-- foot dust particles, lean into direction of travel.

local Iso = require "src.iso"

local M = {}

local ACCEL  = 60
local DRAG   = 7
local SPEED  = 6.5

function M.new(opts)
  opts = opts or {}
  return {
    wx           = opts.wx or 12,
    wy           = opts.wy or 9,
    vx           = 0,
    vy           = 0,
    facing       = 0,
    facingSmooth = 0,
    walkPhase    = 0,
    skinColor    = opts.skinColor or { 0.95, 0.78, 0.62 },
    shirtColor   = opts.shirtColor or { 0.30, 0.60, 1.00 },
    pantsColor   = opts.pantsColor or { 0.18, 0.22, 0.35 },
    accentColor  = opts.accentColor or { 0.30, 1.00, 0.55 },
    label        = opts.label,
    isPeer       = opts.isPeer or false,
    asleep       = opts.asleep or false,
    -- Passive motion state
    breath       = love.math.random() * 6.28,
    sway         = love.math.random() * 6.28,
    blinkT       = 1.5 + love.math.random() * 3,
    blinking     = 0,
    nextHeadTurn = 4 + love.math.random() * 5,
    headLook     = 0,
    nextHandTwitch = 3 + love.math.random() * 4,
    handTwitch   = 0,
    leanLerp     = 0,
    bodyOffset_x = 0,
    bodyOffset_y = 0,
  }
end

function M.update(c, dt, ax, ay, plot)
  c.vx = c.vx + ax * ACCEL * dt
  c.vy = c.vy + ay * ACCEL * dt
  c.vx = c.vx * math.exp(-DRAG * dt)
  c.vy = c.vy * math.exp(-DRAG * dt)
  local s = math.sqrt(c.vx * c.vx + c.vy * c.vy)
  if s > SPEED then
    c.vx = c.vx / s * SPEED
    c.vy = c.vy / s * SPEED
  end
  c.wx = c.wx + c.vx * dt
  c.wy = c.wy + c.vy * dt

  if plot then
    if c.wx < plot.minX then c.wx = plot.minX; c.vx = 0 end
    if c.wx > plot.maxX then c.wx = plot.maxX; c.vx = 0 end
    if c.wy < plot.minY then c.wy = plot.minY; c.vy = 0 end
    if c.wy > plot.maxY then c.wy = plot.maxY; c.vy = 0 end
  end

  if (c.vx * c.vx + c.vy * c.vy) > 0.04 then
    c.walkPhase = (c.walkPhase or 0) + dt
    if math.abs(c.vx) > math.abs(c.vy) then
      c.facing = (c.vx > 0) and 1 or -1
    else
      c.facing = 0
    end
  end

  -- Smooth facing
  c.facingSmooth = c.facingSmooth + (c.facing - c.facingSmooth) * math.min(1, dt * 8)

  -- Passive micro-motion
  c.breath = c.breath + dt * 1.2
  c.sway   = c.sway   + dt * 0.4

  -- Blink scheduler
  c.blinkT = c.blinkT - dt
  if c.blinking > 0 then
    c.blinking = c.blinking - dt
    if c.blinking < 0 then c.blinking = 0 end
  end
  if c.blinkT <= 0 then
    c.blinkT = 2.5 + love.math.random() * 4
    c.blinking = 0.13
    if love.math.random() < 0.18 then c.blinking = 0.45 end  -- occasional double-blink
  end

  -- Idle head turn
  c.nextHeadTurn = c.nextHeadTurn - dt
  if c.nextHeadTurn <= 0 then
    c.nextHeadTurn = 5 + love.math.random() * 6
    c.headLook = (love.math.random() - 0.5) * 1.4
  end
  -- Head returns toward zero
  c.headLook = c.headLook * math.exp(-dt * 0.5)

  -- Hand twitch
  c.nextHandTwitch = c.nextHandTwitch - dt
  if c.nextHandTwitch <= 0 then
    c.nextHandTwitch = 3 + love.math.random() * 5
    c.handTwitch = 1
  end
  c.handTwitch = c.handTwitch * math.exp(-dt * 4)

  -- Lean into direction of travel
  local target = c.vx * 0.4
  c.leanLerp = c.leanLerp + (target - c.leanLerp) * math.min(1, dt * 6)
end

local function colorMul(c, k)
  return c[1] * k, c[2] * k, c[3] * k
end

local function drawAura(c, sx, sy, t)
  local def = c.effects and c.effects.aura
  if not def then return end
  local col = def.color
  for r = 0, 6 do
    local rr = 18 + r * 3
    local a = (1 - r / 7) * (0.36 + math.sin(t * 2.6 + r) * 0.10)
    love.graphics.setColor(col[1], col[2], col[3], a)
    love.graphics.ellipse("line", sx, sy + 4, rr, rr * 0.42)
  end
  -- Soft fill core
  for r = 6, 0, -1 do
    love.graphics.setColor(col[1], col[2], col[3], (1 - r/7) * 0.12)
    love.graphics.ellipse("fill", sx, sy + 4, 26 + r, 11 + r * 0.5)
  end
  -- Orbiting motes
  for k = 0, 5 do
    local a = (k / 6) * math.pi * 2 + t * (0.6 + (k % 2) * 0.4)
    local ox = math.cos(a) * (28 + math.sin(t + k) * 2)
    local oy = math.sin(a) * (10 + math.sin(t * 2 + k) * 1)
    love.graphics.setColor(col[1], col[2], col[3], 0.8)
    love.graphics.circle("fill", sx + ox, sy + 4 + oy, 1.5)
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.circle("fill", sx + ox, sy + 4 + oy, 0.6)
  end
end

local function drawWings(c, sx, sy, t)
  local def = c.effects and c.effects.wings
  if not def then return end
  local col = def.color
  for side = -1, 1, 2 do
    local bx, by = sx + side * 12, sy - 32
    local sweep = math.sin(t * 1.6 + (side > 0 and 0 or math.pi)) * 5
    local pts = {
      bx, by,
      bx + side * (22 + sweep), by - 8,
      bx + side * (28 + sweep * 0.6), by + 4,
      bx + side * (18 + sweep), by + 14,
    }
    -- Inner glow layers
    for i = 3, 0, -1 do
      local a = 0.20 + (3 - i) * 0.12
      love.graphics.setColor(col[1], col[2], col[3], a)
      love.graphics.polygon("fill", pts)
    end
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", pts)
    love.graphics.setLineWidth(1)
    -- Inner glints
    for k = 1, 3 do
      love.graphics.setColor(col[1], col[2], col[3], 0.65)
      love.graphics.line(bx, by + k * 3, bx + side * (18 + sweep * 0.6), by + 2 + k * 3)
    end
  end
end

local function drawHalo(c, sx, sy, t)
  local def = c.effects and c.effects.halo
  if not def then return end
  local col = def.color
  local hy = sy
  -- Soft glow underlay
  for r = 4, 0, -1 do
    love.graphics.setColor(col[1], col[2], col[3], (1 - r/5) * 0.18)
    love.graphics.ellipse("fill", sx, hy, 18 + r, 6 + r * 0.5)
  end
  -- Hard ring
  love.graphics.setColor(col[1], col[2], col[3], 0.85)
  love.graphics.setLineWidth(2)
  love.graphics.ellipse("line", sx, hy, 16, 5)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(col[1], col[2], col[3], 0.55)
  love.graphics.ellipse("line", sx, hy, 18, 6)
  if def.tier and def.tier >= 2 then
    local n = math.min(10, 3 + def.tier)
    for i = 0, n - 1 do
      local a = (i / n) * math.pi * 2 + t * 0.6
      local rx = math.cos(a) * 14
      local ry = math.sin(a) * 4
      local pulse = math.sin(t * 4 + i) * 0.5 + 0.5
      love.graphics.setColor(col[1], col[2], col[3], 0.85 - pulse * 0.10)
      love.graphics.line(sx + rx, hy + ry, sx + rx * 1.55, hy + ry * 1.55 - 4 - pulse * 1.5)
    end
  end
end

local function drawFootDust(c, sx, sy, t)
  -- Already-emitted particles handled by world; here we draw a subtle on-the-fly puff
  local moving = (c.vx * c.vx + c.vy * c.vy) > 0.05
  if not moving then return end
  local wp = c.walkPhase or 0
  for k = 0, 1 do
    local kick = math.sin(wp * 9 + k * math.pi)
    if kick > 0.85 then
      local px = sx + (k == 0 and -6 or 6)
      local py = sy + 3
      love.graphics.setColor(0.65, 0.95, 0.75, 0.30)
      love.graphics.circle("fill", px, py, 3)
      love.graphics.setColor(0.45, 0.85, 0.65, 0.18)
      love.graphics.circle("fill", px, py, 6)
    end
  end
end

-- Sleep pod: a small futuristic levitating capsule the peer lies in
-- when their snapshot status is offline. Replaces the upright body
-- entirely so the player reads "they're asleep at their station", not
-- "they're standing there ignoring me". Iso-projected centred on the
-- character's foot position.
local function drawSleepPod(c, sx, sy, t)
  local cx, cy = sx, sy - 8
  local sR, sG, sB = c.shirtColor[1], c.shirtColor[2], c.shirtColor[3]
  local aR, aG, aB = c.accentColor[1], c.accentColor[2], c.accentColor[3]

  local hover = math.sin(t * 1.6 + (c.breath or 0)) * 1.2

  -- Levitation glow under the pod
  for r = 4, 0, -1 do
    love.graphics.setColor(aR * 0.5, aG * 0.7, aB * 1.0, (1 - r/5) * 0.18)
    love.graphics.ellipse("fill", cx, sy + 6, 32 + r * 3, 6 + r)
  end

  -- Pod hull (dark base shell)
  love.graphics.setColor(0.05, 0.07, 0.10, 0.95)
  love.graphics.ellipse("fill", cx, cy + hover + 4, 30, 11)
  love.graphics.setColor(0.10, 0.13, 0.18, 1)
  love.graphics.ellipse("fill", cx, cy + hover + 2, 30, 10)
  love.graphics.setColor(aR * 0.45, aG * 0.55, aB * 0.65, 0.85)
  love.graphics.ellipse("line", cx, cy + hover + 2, 30, 10)

  -- Lying body inside the pod: head + torso silhouette, oriented
  -- west→east so the head sits at the player's left in iso.
  local bodyY = cy + hover - 1
  -- Torso (horizontal capsule)
  love.graphics.setColor(sR, sG, sB, 1)
  love.graphics.rectangle("fill", cx - 12, bodyY - 3, 22, 6, 3, 3)
  love.graphics.setColor(sR * 0.55, sG * 0.55, sB * 0.55, 1)
  love.graphics.rectangle("line", cx - 12, bodyY - 3, 22, 6, 3, 3)
  -- Chest accent stripe (matches upright character's accent)
  love.graphics.setColor(aR, aG, aB, 0.85)
  love.graphics.rectangle("fill", cx - 10, bodyY - 1, 18, 1.5)
  -- Head (small skin-toned circle at the west end)
  local skR, skG, skB = c.skinColor[1], c.skinColor[2], c.skinColor[3]
  love.graphics.setColor(skR, skG, skB, 1)
  love.graphics.circle("fill", cx - 14, bodyY, 3.5)
  love.graphics.setColor(skR * 0.55, skG * 0.55, skB * 0.55, 1)
  love.graphics.circle("line", cx - 14, bodyY, 3.5)

  -- Glass canopy: rim arc + faint highlight sweep
  love.graphics.setColor(aR, aG, aB, 0.55)
  love.graphics.setLineWidth(1.2)
  love.graphics.arc("line", "open", cx, cy + hover + 1, 28, math.pi, 0)
  love.graphics.setColor(1, 1, 1, 0.15)
  love.graphics.arc("line", "open", cx - 6, cy + hover - 2, 18, math.pi * 1.05, math.pi * 1.55)
  love.graphics.setLineWidth(1)

  -- Two pulsing status pips on the pod rim
  local pip = 0.55 + math.sin(t * 2.4) * 0.35
  love.graphics.setColor(aR, aG, aB, pip)
  love.graphics.circle("fill", cx + 22, cy + hover + 2, 1.5)
  love.graphics.setColor(0.95, 0.55, 0.45, pip * 0.85)
  love.graphics.circle("fill", cx - 22, cy + hover + 2, 1.5)

  return cx - 14, bodyY -- head position so caller can place the Zs
end

function M.draw(c, t)
  local sx, sy = Iso.toScreen(c.wx, c.wy, c.wz or 0)

  if c.asleep then
    -- Pod replaces the entire standing render. Soft contact shadow
    -- under the levitation glow keeps the iso depth read.
    for r = 3, 0, -1 do
      love.graphics.setColor(0, 0, 0, (1 - r/4) * 0.40)
      love.graphics.ellipse("fill", sx, sy + 6, 22 + r * 2, 4 + r)
    end
    local hx, hy = drawSleepPod(c, sx, sy, t)
    -- Three Z's drifting up from the head end of the pod
    for i = 0, 2 do
      local cycle = (t * 0.55 + i * 0.40) % 1
      local zx = hx - 4 + math.sin(cycle * 6.28 + i) * 3 - i * 2
      local zy = hy - 8 - cycle * 22
      local alpha = (1 - cycle) * 0.85
      love.graphics.setColor(0.70, 0.85, 1.00, alpha)
      love.graphics.print("z", zx, zy)
    end
    -- Label above the pod (desaturated, no halo, no rest of body)
    if c.label then
      local font = love.graphics.getFont()
      local lw = font:getWidth(c.label)
      local labelY = sy - 44
      love.graphics.setColor(0, 0, 0, 0.65)
      love.graphics.rectangle("fill", sx - lw/2 - 5, labelY - 2, lw + 10, 16, 3, 3)
      love.graphics.setColor(0.50, 0.55, 0.60, 0.85)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", sx - lw/2 - 5, labelY - 2, lw + 10, 16, 3, 3)
      love.graphics.setColor(0.65, 0.70, 0.75, 0.90)
      love.graphics.print(c.label, sx - lw/2, labelY)
    end
    return
  end

  local moving = (c.vx * c.vx + c.vy * c.vy) > 0.05
  local wp = c.walkPhase or 0
  -- Walking pose
  local leg     = moving and math.sin(wp * 9) * 7 or 0
  local arm     = moving and math.sin(wp * 9) * 6 or
                   math.sin(t * 1.2) * 1.4 + c.handTwitch * 4
  local bob     = moving and math.abs(math.sin(wp * 9)) * 1.8 or
                   math.sin(c.breath) * 1.0
  local breathe = math.sin(c.breath) * 0.55  -- chest expand factor (0..1)
  local sway    = math.sin(c.sway) * 0.6 + math.sin(c.sway * 0.7 + 1) * 0.3
  local lean    = c.leanLerp or 0  -- horizontal pixel lean

  -- Aura ring at feet first
  drawAura(c, sx, sy, t)
  -- Foot dust on contact
  drawFootDust(c, sx, sy, t)

  -- Soft contact shadow
  for r = 3, 0, -1 do
    love.graphics.setColor(0, 0, 0, (1 - r/4) * 0.45)
    love.graphics.ellipse("fill", sx + lean * 0.3, sy + 4, 16 + r * 2, 5 + r)
  end

  -- Wings behind torso
  drawWings(c, sx + lean * 0.5, sy - 2 - bob + breathe, t)

  local bodyX = sx + lean * 0.4 + sway
  local bodyY = sy - 2 - bob

  -- Pants / legs
  local pR, pG, pB = c.pantsColor[1], c.pantsColor[2], c.pantsColor[3]
  -- Left leg
  love.graphics.setColor(pR, pG, pB, 1)
  love.graphics.rectangle("fill", bodyX - 7, bodyY - 18 - leg, 6, 18, 1, 1)
  love.graphics.setColor(pR * 0.65, pG * 0.65, pB * 0.65, 1)
  love.graphics.rectangle("line", bodyX - 7, bodyY - 18 - leg, 6, 18, 1, 1)
  -- Knee accent line
  love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], 0.55)
  love.graphics.line(bodyX - 6, bodyY - 11 - leg, bodyX - 2, bodyY - 11 - leg)
  -- Right leg
  love.graphics.setColor(pR, pG, pB, 1)
  love.graphics.rectangle("fill", bodyX + 1, bodyY - 18 + leg, 6, 18, 1, 1)
  love.graphics.setColor(pR * 0.65, pG * 0.65, pB * 0.65, 1)
  love.graphics.rectangle("line", bodyX + 1, bodyY - 18 + leg, 6, 18, 1, 1)
  love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], 0.55)
  love.graphics.line(bodyX + 2, bodyY - 11 + leg, bodyX + 6, bodyY - 11 + leg)

  -- Hip belt
  love.graphics.setColor(0.05, 0.05, 0.08, 0.85)
  love.graphics.rectangle("fill", bodyX - 11, bodyY - 22, 22, 4, 1, 1)
  love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], 0.75)
  love.graphics.rectangle("fill", bodyX - 4, bodyY - 22, 8, 4, 1, 1)

  -- Torso (with breathing expansion)
  local torsoW = 22 + breathe
  local torsoH = 22
  local sR, sG, sB = c.shirtColor[1], c.shirtColor[2], c.shirtColor[3]
  love.graphics.setColor(sR, sG, sB, 1)
  love.graphics.rectangle("fill", bodyX - torsoW/2, bodyY - 22 - torsoH, torsoW, torsoH, 2, 2)
  -- Shading: darker right side, lighter left
  love.graphics.setColor(sR * 0.6, sG * 0.6, sB * 0.6, 0.75)
  love.graphics.rectangle("fill", bodyX + torsoW/2 - 4, bodyY - 22 - torsoH, 4, torsoH, 0, 2)
  love.graphics.setColor(1, 1, 1, 0.10)
  love.graphics.rectangle("fill", bodyX - torsoW/2, bodyY - 22 - torsoH, 4, torsoH, 2, 0)
  -- Outline
  love.graphics.setColor(sR * 0.45, sG * 0.45, sB * 0.45, 1)
  love.graphics.rectangle("line", bodyX - torsoW/2, bodyY - 22 - torsoH, torsoW, torsoH, 2, 2)
  -- Chest accent stripe
  love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], 0.95)
  love.graphics.rectangle("fill", bodyX - torsoW/2, bodyY - 38, torsoW, 3)
  -- Chest emblem (octagonal core)
  do
    local cx, cy = bodyX, bodyY - 32
    local r = 4
    love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], 0.85)
    love.graphics.circle("fill", cx, cy, r)
    love.graphics.setColor(0.05, 0.10, 0.15, 0.8)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setColor(1, 1, 1, 0.85 + math.sin(t * 3) * 0.10)
    love.graphics.circle("fill", cx, cy, 1.5)
  end

  -- Arms
  local kR, kG, kB = c.skinColor[1], c.skinColor[2], c.skinColor[3]
  -- Shoulder pads
  love.graphics.setColor(sR * 0.55, sG * 0.55, sB * 0.55, 1)
  love.graphics.rectangle("fill", bodyX - torsoW/2 - 4, bodyY - 44, 4, 6, 1, 1)
  love.graphics.rectangle("fill", bodyX + torsoW/2,     bodyY - 44, 4, 6, 1, 1)
  -- Upper arms
  love.graphics.setColor(sR * 0.85, sG * 0.85, sB * 0.85, 1)
  love.graphics.rectangle("fill", bodyX - torsoW/2 - 4, bodyY - 38 - arm, 4, 10, 1, 1)
  love.graphics.rectangle("fill", bodyX + torsoW/2,     bodyY - 38 + arm, 4, 10, 1, 1)
  -- Forearms / hands (skin)
  love.graphics.setColor(kR, kG, kB, 1)
  love.graphics.rectangle("fill", bodyX - torsoW/2 - 4, bodyY - 28 - arm, 4, 9, 1, 1)
  love.graphics.rectangle("fill", bodyX + torsoW/2,     bodyY - 28 + arm, 4, 9, 1, 1)
  love.graphics.setColor(kR * 0.7, kG * 0.7, kB * 0.7, 1)
  love.graphics.rectangle("line", bodyX - torsoW/2 - 4, bodyY - 38 - arm, 4, 19, 1, 1)
  love.graphics.rectangle("line", bodyX + torsoW/2,     bodyY - 38 + arm, 4, 19, 1, 1)

  -- Neck
  love.graphics.setColor(kR * 0.85, kG * 0.85, kB * 0.85, 1)
  love.graphics.rectangle("fill", bodyX - 3, bodyY - 47, 6, 4, 1, 1)

  -- Head with passive lookL
  local headTurn = c.headLook + c.facingSmooth * 0.5
  local headX = bodyX + headTurn
  local headY = bodyY - 60
  love.graphics.setColor(kR, kG, kB, 1)
  love.graphics.rectangle("fill", headX - 9, headY, 18, 16, 3, 3)
  love.graphics.setColor(kR * 0.7, kG * 0.7, kB * 0.7, 1)
  love.graphics.rectangle("line", headX - 9, headY, 18, 16, 3, 3)
  -- Cheek shading
  love.graphics.setColor(0, 0, 0, 0.10)
  love.graphics.rectangle("fill", headX + 5, headY + 4, 4, 12, 0, 2)
  love.graphics.setColor(1, 1, 1, 0.06)
  love.graphics.rectangle("fill", headX - 9, headY, 4, 16, 2, 0)

  -- Eyes (with blink + facing offset)
  do
    local eyeY = headY + 6
    local lEyeX = headX - 4 + headTurn * 0.3
    local rEyeX = headX + 2 + headTurn * 0.3
    local closed = (c.blinking or 0) > 0
    if closed then
      love.graphics.setColor(0.1, 0.1, 0.15, 1)
      love.graphics.rectangle("fill", lEyeX - 1, eyeY + 1, 4, 1)
      love.graphics.rectangle("fill", rEyeX - 1, eyeY + 1, 4, 1)
    else
      -- Eye whites
      love.graphics.setColor(0.95, 0.95, 0.95, 1)
      love.graphics.rectangle("fill", lEyeX - 1, eyeY, 4, 3)
      love.graphics.rectangle("fill", rEyeX - 1, eyeY, 4, 3)
      -- Pupils (face direction tints them)
      local pupOff = (headTurn) * 0.25
      love.graphics.setColor(0.05, 0.10, 0.15, 1)
      love.graphics.rectangle("fill", lEyeX + pupOff, eyeY + 1, 2, 2)
      love.graphics.rectangle("fill", rEyeX + pupOff, eyeY + 1, 2, 2)
    end
  end

  -- Mouth (subtle)
  love.graphics.setColor(0.30, 0.18, 0.22, 0.85)
  love.graphics.rectangle("fill", headX - 2, headY + 12, 4, 1)

  -- Cap / hat (accent strip)
  love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], 0.95)
  love.graphics.rectangle("fill", headX - 10, headY - 2, 20, 3, 1, 1)
  love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], 0.45)
  love.graphics.rectangle("fill", headX - 10, headY - 4, 20, 2, 1, 1)
  -- Hat brim
  love.graphics.setColor(c.accentColor[1] * 0.6, c.accentColor[2] * 0.6, c.accentColor[3] * 0.6, 0.85)
  love.graphics.rectangle("fill", headX - 11, headY, 22, 1)

  -- Wave gesture: raise the right arm and float a "hi" bubble directly
  -- above the head so it doesn't bleed into the next peer's lane.
  if c._waveTimer and c._waveTimer > 0 then
    local wt = c._waveTimer
    local raise = math.sin((1.4 - wt) * 8) * 6
    love.graphics.setColor(c.skinColor[1], c.skinColor[2], c.skinColor[3], 1)
    love.graphics.rectangle("fill", bodyX + torsoW/2 + 2, bodyY - 60 + raise, 4, 14, 1, 1)
    love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], math.min(1, wt))
    love.graphics.circle("fill", bodyX + torsoW/2 + 4, bodyY - 60 + raise - 3, 3 + math.sin(wt * 14) * 1.2)
    love.graphics.setColor(0, 0, 0, math.min(0.7, wt))
    love.graphics.rectangle("fill", bodyX - 15, headY - 22, 30, 14, 4, 4)
    love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], math.min(1, wt))
    love.graphics.rectangle("line", bodyX - 15, headY - 22, 30, 14, 4, 4)
    love.graphics.setColor(1, 1, 1, math.min(1, wt))
    love.graphics.print("hi", bodyX - 7, headY - 21)
  end

  -- Halo / crown above head
  drawHalo(c, headX, headY - 8, t)

  -- Peer halo glow (faint blue ambient).
  if c.isPeer then
    local pulse = 0.18 + math.sin(t * 2) * 0.06
    love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], pulse)
    love.graphics.circle("fill", bodyX, bodyY - 36, 30)
  end

  -- Label above head, with a status pip on the left edge:
  --   green  = online (broadcasting recently)
  --   amber  = afk    (in roster but quiet)
  --   gray   = stale  (in roster but >90s silent)
  if c.label then
    local font = love.graphics.getFont()
    local lw = font:getWidth(c.label)
    local labelY = headY - 26
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", bodyX - lw/2 - 5, labelY - 2, lw + 10, 16, 3, 3)
    love.graphics.setColor(c.accentColor[1], c.accentColor[2], c.accentColor[3], 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bodyX - lw/2 - 5, labelY - 2, lw + 10, 16, 3, 3)
    love.graphics.setColor(0.95, 1, 0.92, 1)
    love.graphics.print(c.label, bodyX - lw/2, labelY)
    if c.isPeer then
      local pipX = bodyX - lw/2 - 11
      local pipY = labelY + 6
      local pulse = 0.55 + math.sin(t * 3.5) * 0.35
      if c.online then
        love.graphics.setColor(0.30, 1.00, 0.45, pulse)
        love.graphics.circle("fill", pipX, pipY, 3)
        love.graphics.setColor(0.30, 1.00, 0.45, pulse * 0.35)
        love.graphics.circle("fill", pipX, pipY, 5.5)
      elseif c.afk then
        love.graphics.setColor(1.00, 0.75, 0.25, 0.85)
        love.graphics.circle("fill", pipX, pipY, 2.5)
      else
        love.graphics.setColor(0.55, 0.60, 0.65, 0.75)
        love.graphics.circle("fill", pipX, pipY, 2.5)
      end
    end
  end
end

return M
