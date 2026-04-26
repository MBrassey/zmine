-- Per-tier visual renderers for miners and energy. Each draw function
-- runs at a screen-space pivot (sx, sy) representing the bottom-center
-- of a single instance. Higher tiers are visibly more complex / glowy.

local M = {}

-- ============================================================
-- Miners — render as motherboard / GPU / quantum / singularity rigs
-- ============================================================

local function chip(sx, sy, w, h, color, t, blink)
  love.graphics.setColor(0.05, 0.06, 0.08, 1)
  love.graphics.rectangle("fill", sx - w/2, sy - h, w, h, 2, 2)
  love.graphics.setColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 1)
  love.graphics.rectangle("line", sx - w/2, sy - h, w, h, 2, 2)
  -- Pin teeth
  love.graphics.setColor(0.45, 0.45, 0.45, 1)
  for i = 0, math.floor(w / 4) - 1 do
    love.graphics.rectangle("fill", sx - w/2 + 1 + i * 4, sy - 1, 2, 2)
  end
  -- LED
  if blink then
    local on = math.sin(t * 4 + sx * 0.05) > 0
    local a = on and 1 or 0.25
    love.graphics.setColor(color[1], color[2], color[3], a)
    love.graphics.circle("fill", sx + w/2 - 3, sy - h + 3, 1.5)
  end
end

local function fan(sx, sy, r, color, speed, t)
  -- Outer ring
  love.graphics.setColor(0.10, 0.12, 0.14, 1)
  love.graphics.circle("fill", sx, sy, r)
  love.graphics.setColor(0.30, 0.32, 0.36, 1)
  love.graphics.circle("line", sx, sy, r)
  -- Blades
  local rot = t * speed
  love.graphics.setColor(0.45, 0.50, 0.58, 0.9)
  for k = 0, 4 do
    local a = rot + k * (math.pi * 2 / 5)
    local x1 = sx + math.cos(a) * 1.5
    local y1 = sy + math.sin(a) * 1.5
    local x2 = sx + math.cos(a) * (r - 1.5)
    local y2 = sy + math.sin(a) * (r - 1.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(x1, y1, x2, y2)
  end
  love.graphics.setLineWidth(1)
  -- Hub
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.circle("fill", sx, sy, 2.5)
end

local function rgbStrip(sx, sy, w, t)
  for i = 0, w - 1 do
    local hue = ((i / w) + t * 0.2) % 1
    local r = 0.5 + 0.5 * math.sin(hue * math.pi * 2)
    local g = 0.5 + 0.5 * math.sin(hue * math.pi * 2 + math.pi * 2 / 3)
    local b = 0.5 + 0.5 * math.sin(hue * math.pi * 2 + math.pi * 4 / 3)
    love.graphics.setColor(r, g, b, 0.95)
    love.graphics.rectangle("fill", sx + i, sy, 1, 2)
  end
end

local function drawAsicZ1(sx, sy, color, t)
  -- Single PCB with three chips and a row of LEDs
  -- Base board
  love.graphics.setColor(0.10, 0.18, 0.10, 1)
  love.graphics.rectangle("fill", sx - 26, sy - 14, 52, 14, 2, 2)
  love.graphics.setColor(0.18, 0.30, 0.18, 1)
  love.graphics.rectangle("line", sx - 26, sy - 14, 52, 14, 2, 2)
  -- Solder traces
  love.graphics.setColor(0.30, 0.55, 0.30, 0.85)
  for i = 0, 5 do
    love.graphics.line(sx - 24 + i * 9, sy - 4, sx - 22 + i * 9, sy - 12)
  end
  -- Chips
  chip(sx - 14, sy - 4, 12, 8, color, t, true)
  chip(sx,      sy - 4, 12, 8, color, t, true)
  chip(sx + 14, sy - 4, 12, 8, color, t, false)
  -- Top connector
  love.graphics.setColor(0.45, 0.45, 0.45, 1)
  love.graphics.rectangle("fill", sx - 8, sy - 18, 16, 4, 1, 1)
  -- Heat shimmer
  love.graphics.setColor(color[1], color[2], color[3], 0.20 + math.sin(t * 3) * 0.08)
  love.graphics.rectangle("fill", sx - 26, sy - 22, 52, 4)
end

local function drawGpu(sx, sy, color, t)
  -- GPU card with fan and RGB
  -- PCB
  love.graphics.setColor(0.08, 0.10, 0.14, 1)
  love.graphics.rectangle("fill", sx - 30, sy - 36, 60, 36, 2, 2)
  love.graphics.setColor(0.18, 0.20, 0.30, 1)
  love.graphics.rectangle("line", sx - 30, sy - 36, 60, 36, 2, 2)
  -- Heatsink fins
  for i = 0, 9 do
    love.graphics.setColor(0.35, 0.38, 0.46, 1)
    love.graphics.rectangle("fill", sx - 28 + i * 6, sy - 34, 4, 22, 1, 1)
  end
  -- Fan
  fan(sx + 8, sy - 22, 9, color, 12, t)
  -- RGB strip along bottom
  rgbStrip(sx - 28, sy - 4, 56, t)
  -- Logo accent
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.rectangle("fill", sx - 26, sy - 10, 8, 4, 1, 1)
  -- I/O
  love.graphics.setColor(0.20, 0.22, 0.26, 1)
  love.graphics.rectangle("fill", sx + 26, sy - 28, 4, 24, 1, 1)
end

local function drawQuantum(sx, sy, color, t)
  -- Cryostat tube with glowing core, vapor wisps
  -- Base plate
  love.graphics.setColor(0.20, 0.22, 0.30, 1)
  love.graphics.rectangle("fill", sx - 18, sy - 6, 36, 6, 2, 2)
  -- Cryo cylinder (gradient via stacked rects)
  for i = 0, 30 do
    local a = 0.3 + (i / 30) * 0.6
    love.graphics.setColor(color[1] * 0.4, color[2] * 0.4, color[3] * 0.6, a)
    love.graphics.rectangle("fill", sx - 14, sy - 10 - i, 28, 2)
  end
  -- Glass outer
  love.graphics.setColor(0.55, 0.65, 0.85, 0.45)
  love.graphics.rectangle("line", sx - 14, sy - 42, 28, 36, 4, 4)
  -- Inner core glow
  local pulse = 0.7 + math.sin(t * 2.5) * 0.30
  for r = 8, 0, -1 do
    love.graphics.setColor(color[1], color[2], color[3], (1 - r/8) * 0.6 * pulse)
    love.graphics.circle("fill", sx, sy - 24, 4 + r)
  end
  love.graphics.setColor(1, 1, 1, 0.85 * pulse)
  love.graphics.circle("fill", sx, sy - 24, 3)
  -- Vapor wisps
  for k = 0, 2 do
    local ph = (t * 0.6 + k * 0.4) % 1
    local vx = sx + math.sin(t * 2 + k) * 4
    local vy = sy - 6 - ph * 36
    local va = (1 - ph) * 0.45
    love.graphics.setColor(0.9, 0.95, 1, va)
    love.graphics.circle("fill", vx, vy, 3 - ph * 2)
  end
  -- Top cap
  love.graphics.setColor(0.30, 0.32, 0.40, 1)
  love.graphics.rectangle("fill", sx - 14, sy - 46, 28, 4, 2, 2)
  love.graphics.setColor(color[1], color[2], color[3], 0.90)
  love.graphics.rectangle("fill", sx - 12, sy - 47, 24, 2, 1, 1)
end

local function drawNeural(sx, sy, color, t)
  -- Tower of stacked transformer modules with neural traces
  -- Base
  love.graphics.setColor(0.10, 0.10, 0.14, 1)
  love.graphics.rectangle("fill", sx - 22, sy - 6, 44, 6, 2, 2)
  -- Modules
  for k = 0, 5 do
    local y = sy - 10 - k * 8
    love.graphics.setColor(0.12, 0.14, 0.20, 1)
    love.graphics.rectangle("fill", sx - 20, y - 8, 40, 8, 2, 2)
    love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 0.85)
    love.graphics.rectangle("line", sx - 20, y - 8, 40, 8, 2, 2)
    -- Pulsing LED
    local ph = math.sin(t * 3 + k) * 0.5 + 0.5
    love.graphics.setColor(color[1], color[2], color[3], 0.4 + ph * 0.6)
    love.graphics.rectangle("fill", sx + 14, y - 5, 4, 2)
    -- Connectivity traces
    if k > 0 then
      love.graphics.setColor(color[1], color[2], color[3], 0.40 + ph * 0.30)
      love.graphics.line(sx - 16, y, sx + 16, y)
    end
  end
  -- Antenna array on top
  love.graphics.setColor(0.65, 0.70, 0.78, 1)
  love.graphics.line(sx - 8, sy - 56, sx - 8, sy - 64)
  love.graphics.line(sx,     sy - 56, sx,     sy - 68)
  love.graphics.line(sx + 8, sy - 56, sx + 8, sy - 64)
  for k = -1, 1 do
    local ax = sx + k * 8
    local ay = sy - 64 - (k == 0 and 4 or 0)
    love.graphics.setColor(color[1], color[2], color[3], 0.85 + math.sin(t*3+k)*0.15)
    love.graphics.circle("fill", ax, ay, 2)
  end
end

local function drawHyperdrive(sx, sy, color, t)
  -- Floating lattice of geometric shapes around a central core
  love.graphics.setColor(0.10, 0.10, 0.16, 1)
  love.graphics.ellipse("fill", sx, sy, 22, 7)
  -- Core orb
  for r = 10, 0, -1 do
    love.graphics.setColor(color[1], color[2], color[3], (1 - r/10) * 0.55)
    love.graphics.circle("fill", sx, sy - 22, 4 + r * 0.5)
  end
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.circle("fill", sx, sy - 22, 3)
  -- Orbiting platonic shapes
  for k = 0, 5 do
    local a = t * (0.6 + (k % 3) * 0.4) + k * (math.pi * 2 / 6)
    local r = 18
    local px = sx + math.cos(a) * r
    local py = sy - 22 + math.sin(a) * r * 0.5
    love.graphics.setColor(color[1], color[2], color[3], 0.85)
    if k % 2 == 0 then
      love.graphics.polygon("line",
        px - 3, py + 3, px, py - 4, px + 3, py + 3)
    else
      love.graphics.polygon("line",
        px - 3, py - 3, px + 3, py - 3, px + 3, py + 3, px - 3, py + 3)
    end
  end
  -- Lower scaffold
  love.graphics.setColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 0.65)
  love.graphics.line(sx - 14, sy, sx - 6, sy - 10)
  love.graphics.line(sx + 14, sy, sx + 6, sy - 10)
end

local function drawSingularity(sx, sy, color, t)
  -- Dark sphere with bright accretion ring
  -- Outer haze
  for r = 28, 0, -1 do
    love.graphics.setColor(color[1] * 0.6, color[2] * 0.4, color[3] * 0.4, (1 - r/28) * 0.18)
    love.graphics.circle("fill", sx, sy - 18, r)
  end
  -- Accretion ring
  for k = 0, 24 do
    local a = (k / 24) * math.pi * 2 + t * 0.8
    local rx = math.cos(a) * 16
    local ry = math.sin(a) * 5
    love.graphics.setColor(color[1], color[2], color[3], 0.6 + math.sin(t * 4 + k) * 0.3)
    love.graphics.circle("fill", sx + rx, sy - 18 + ry, 1.5)
  end
  -- Event horizon (black)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.circle("fill", sx, sy - 18, 9)
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.circle("line", sx, sy - 18, 9)
  -- Lensing distortion lines
  for k = 0, 3 do
    local a = t * 0.3 + k * (math.pi / 2)
    local r1 = 11
    local r2 = 18
    local x1, y1 = sx + math.cos(a) * r1, sy - 18 + math.sin(a) * r1
    local x2, y2 = sx + math.cos(a) * r2, sy - 18 + math.sin(a) * r2
    love.graphics.setColor(color[1], color[2], color[3], 0.5)
    love.graphics.line(x1, y1, x2, y2)
  end
  -- Pillar base
  love.graphics.setColor(0.18, 0.10, 0.12, 1)
  love.graphics.rectangle("fill", sx - 4, sy - 6, 8, 6, 1, 1)
end

local function drawEonchamber(sx, sy, color, t)
  -- Central sphere with multiple branching satellite spheres
  -- Base
  love.graphics.setColor(0.18, 0.16, 0.10, 1)
  love.graphics.ellipse("fill", sx, sy, 26, 8)
  -- Central core
  for r = 14, 0, -1 do
    love.graphics.setColor(color[1], color[2], color[3], (1 - r/14) * 0.5)
    love.graphics.circle("fill", sx, sy - 24, 4 + r * 0.6)
  end
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.circle("fill", sx, sy - 24, 4)
  -- Satellite spheres orbiting in two rings
  for ring = 1, 2 do
    local count = ring == 1 and 5 or 7
    local rad = ring == 1 and 14 or 22
    for k = 0, count - 1 do
      local a = (k / count) * math.pi * 2 + t * (ring == 1 and 0.8 or -0.5)
      local px = sx + math.cos(a) * rad
      local py = sy - 24 + math.sin(a) * rad * 0.45
      -- Connection
      love.graphics.setColor(color[1], color[2], color[3], 0.30)
      love.graphics.line(sx, sy - 24, px, py)
      -- Sphere
      love.graphics.setColor(color[1], color[2], color[3], 0.85)
      love.graphics.circle("fill", px, py, 2.5)
      love.graphics.setColor(1, 1, 1, 0.7)
      love.graphics.circle("fill", px, py, 1)
    end
  end
end

local function drawCosmosLattice(sx, sy, color, t)
  -- 11D brane lattice: nested polyhedra with rotating axes + bright glints
  -- Base hex platform
  love.graphics.setColor(0.10, 0.14, 0.20, 1)
  local pts = {}
  for k = 0, 5 do
    local a = (k / 6) * math.pi * 2
    pts[#pts + 1] = sx + math.cos(a) * 22
    pts[#pts + 1] = sy + math.sin(a) * 7
  end
  love.graphics.polygon("fill", pts)
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.polygon("line", pts)

  -- Outer glow
  for r = 30, 0, -1 do
    love.graphics.setColor(color[1], color[2], color[3], (1 - r/30) * 0.06)
    love.graphics.circle("fill", sx, sy - 30, r)
  end

  -- Three nested rotating polyhedra (squares projected, rotating on different axes)
  for k = 1, 3 do
    local r = 8 + k * 6
    local rot = t * (0.3 + k * 0.4) * (k % 2 == 0 and 1 or -1)
    love.graphics.setColor(color[1], color[2], color[3], 0.85 - k * 0.15)
    love.graphics.setLineWidth(1.5)
    local poly = {}
    for j = 0, 5 do
      local a = rot + j * math.pi / 3
      poly[#poly + 1] = sx + math.cos(a) * r
      poly[#poly + 1] = sy - 30 + math.sin(a) * r * 0.5
    end
    love.graphics.polygon("line", poly)
  end
  love.graphics.setLineWidth(1)

  -- Central bright pulse + brane streaks
  local pulse = 0.85 + math.sin(t * 3) * 0.15
  love.graphics.setColor(1, 1, 1, pulse)
  love.graphics.circle("fill", sx, sy - 30, 3.5)
  for k = 0, 5 do
    local a = t * 1.2 + k * (math.pi * 2 / 6)
    local rx = math.cos(a) * 30
    local ry = math.sin(a) * 30
    love.graphics.setColor(color[1], color[2], color[3], 0.50)
    love.graphics.line(sx, sy - 30, sx + rx, sy - 30 + ry)
  end
  -- Outer brane sparks
  for k = 0, 8 do
    local a = (t * 0.7 + k / 9) * math.pi * 2
    local rr = 30 + math.sin(t * 2 + k) * 4
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.circle("fill", sx + math.cos(a) * rr, sy - 30 + math.sin(a) * rr, 1.4)
  end
end

local function drawEldritchPrime(sx, sy, color, t)
  -- Non-Euclidean spirals + tindalos hound coil + acausal eyes
  -- Dark base
  love.graphics.setColor(0.16, 0.06, 0.22, 1)
  love.graphics.ellipse("fill", sx, sy, 28, 9)
  love.graphics.setColor(color[1], color[2], color[3], 0.70)
  love.graphics.ellipse("line", sx, sy, 28, 9)

  -- Pulsating outer aura
  for r = 36, 0, -1 do
    love.graphics.setColor(color[1] * 0.85, color[2] * 0.45, color[3] * 0.95, (1 - r/36) * 0.10)
    love.graphics.circle("fill", sx, sy - 32, r)
  end

  -- Spiral arms (drawn as polylines, varying with time)
  for arm = 0, 4 do
    love.graphics.setColor(color[1], color[2], color[3], 0.85)
    love.graphics.setLineWidth(1.5)
    local pts2 = {}
    local armBase = arm * (math.pi * 2 / 5)
    for s = 0, 18 do
      local f = s / 18
      local r = 4 + f * 24
      local a = armBase + t * 0.6 + f * 3.2 * (arm % 2 == 0 and 1 or -1)
      pts2[#pts2 + 1] = sx + math.cos(a) * r
      pts2[#pts2 + 1] = sy - 32 + math.sin(a) * r * 0.55
    end
    love.graphics.line(pts2)
  end
  love.graphics.setLineWidth(1)

  -- Acausal eyes (2-3 randomly orbiting)
  for k = 0, 2 do
    local a = t * (0.4 + k * 0.13) + k * 2.1
    local rx = math.cos(a) * (12 + k * 3)
    local ry = math.sin(a * 0.7) * (6 + k * 2)
    love.graphics.setColor(0.05, 0.02, 0.08, 1)
    love.graphics.circle("fill", sx + rx, sy - 32 + ry, 4)
    love.graphics.setColor(color[1], color[2], color[3], 0.95)
    love.graphics.circle("line", sx + rx, sy - 32 + ry, 4)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", sx + rx + math.sin(t * 5) * 1, sy - 32 + ry, 1.5)
  end

  -- Central reality-rip
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.circle("fill", sx, sy - 32, 2)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.circle("fill", sx + math.sin(t * 7) * 0.4, sy - 32 + math.cos(t * 9) * 0.4, 1)
end

local function drawOmegaEngine(sx, sy, color, t)
  -- Tipler-cylinder core: counter-rotating cylinders with bright accretion;
  -- everything trails inward.
  -- Base
  love.graphics.setColor(0.18, 0.18, 0.22, 1)
  love.graphics.ellipse("fill", sx, sy, 32, 10)
  love.graphics.setColor(0.55, 0.55, 0.58, 1)
  love.graphics.ellipse("line", sx, sy, 32, 10)

  -- Outer corona
  for r = 50, 0, -1 do
    love.graphics.setColor(1, 1, 1, (1 - r/50) * 0.08)
    love.graphics.circle("fill", sx, sy - 38, r)
  end

  -- Two cylinders (stylized as ellipses) rotating opposite
  for cyl = -1, 1, 2 do
    local rot = t * 1.2 * cyl
    love.graphics.push()
    love.graphics.translate(sx, sy - 38)
    love.graphics.rotate(rot)
    love.graphics.setColor(0.85, 0.85, 0.95, 1)
    love.graphics.rectangle("fill", -16, -3, 32, 6, 2, 2)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("line", -16, -3, 32, 6, 2, 2)
    -- Bright tips
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", -16, 0, 2)
    love.graphics.circle("fill", 16, 0, 2)
    love.graphics.pop()
  end

  -- Accretion disk in the middle
  for k = 0, 36 do
    local a = (k / 36) * math.pi * 2 + t * 0.8
    local rr = 22 + math.sin(t * 3 + k) * 1.5
    love.graphics.setColor(1, 1, 1, 0.85 - (k % 5) * 0.10)
    love.graphics.circle("fill",
      sx + math.cos(a) * rr,
      sy - 38 + math.sin(a) * rr * 0.5, 0.8)
  end

  -- Central white singularity point
  for r = 6, 0, -1 do
    love.graphics.setColor(1, 1, 1, (1 - r/7) * 1)
    love.graphics.circle("fill", sx, sy - 38, r)
  end

  -- Outward radiating beams
  for k = 0, 7 do
    local a = (k / 8) * math.pi * 2 + t * 0.3
    local x1 = sx + math.cos(a) * 28
    local y1 = sy - 38 + math.sin(a) * 14
    local x2 = sx + math.cos(a) * 44
    local y2 = sy - 38 + math.sin(a) * 22
    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(x1, y1, x2, y2)
  end
  love.graphics.setLineWidth(1)
end

M.miners = {
  asic_z1            = drawAsicZ1,
  gpu_cluster        = drawGpu,
  quantum_miner      = drawQuantum,
  neural_forge       = drawNeural,
  hyperdrive_rig     = drawHyperdrive,
  singularity_engine = drawSingularity,
  eonchamber         = drawEonchamber,
  cosmos_lattice     = drawCosmosLattice,
  eldritch_prime     = drawEldritchPrime,
  omega_engine       = drawOmegaEngine,
}

-- ============================================================
-- Energy infrastructure
-- ============================================================

local function drawSolar(sx, sy, color, t)
  -- Tilted PV panel array on a base, sun glint
  -- Mount post
  love.graphics.setColor(0.25, 0.25, 0.30, 1)
  love.graphics.rectangle("fill", sx - 2, sy - 8, 4, 8)
  -- Panel (tilted parallelogram)
  local pts = {
    sx - 24, sy - 22,
    sx + 16, sy - 30,
    sx + 24, sy - 14,
    sx - 16, sy - 6,
  }
  love.graphics.setColor(0.10, 0.18, 0.30, 1)
  love.graphics.polygon("fill", pts)
  love.graphics.setColor(0.30, 0.55, 0.95, 1)
  love.graphics.polygon("line", pts)
  -- Cells
  for i = 0, 4 do
    local fx = i / 5
    love.graphics.setColor(0.20, 0.40, 0.65, 0.85)
    love.graphics.line(
      sx - 24 + (40) * fx, sy - 22 + (-8) * fx,
      sx - 16 + (40) * fx, sy - 6 + (-8) * fx)
  end
  -- Sun glint
  local glint = math.max(0, math.sin(t * 0.6))
  love.graphics.setColor(1, 0.95, 0.55, glint * 0.8)
  love.graphics.circle("fill", sx + 6 + glint * 2, sy - 22, 2 + glint * 1.5)
  -- Accent stripe
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.line(sx - 24, sy - 22, sx + 16, sy - 30)
end

local function drawWind(sx, sy, color, t)
  -- Tower with three spinning blades
  love.graphics.setColor(0.85, 0.85, 0.88, 1)
  love.graphics.polygon("fill",
    sx - 2, sy,
    sx + 2, sy,
    sx + 1, sy - 50,
    sx - 1, sy - 50)
  -- Hub
  love.graphics.setColor(0.30, 0.32, 0.36, 1)
  love.graphics.circle("fill", sx, sy - 50, 4)
  -- Blades
  local rot = t * 2.2
  love.graphics.setColor(0.85, 0.90, 0.95, 0.95)
  love.graphics.setLineWidth(2.5)
  for k = 0, 2 do
    local a = rot + k * (math.pi * 2 / 3)
    local bx = sx + math.cos(a) * 18
    local by = sy - 50 + math.sin(a) * 18
    love.graphics.line(sx, sy - 50, bx, by)
  end
  love.graphics.setLineWidth(1)
  -- Wing tip glow
  love.graphics.setColor(color[1], color[2], color[3], 0.70 + math.sin(t * 4) * 0.25)
  love.graphics.circle("fill", sx, sy - 50, 2)
  -- Base pad
  love.graphics.setColor(0.18, 0.20, 0.24, 1)
  love.graphics.ellipse("fill", sx, sy + 1, 8, 3)
end

local function drawHydro(sx, sy, color, t)
  -- Dam wall with flowing water
  -- Wall
  love.graphics.setColor(0.30, 0.35, 0.42, 1)
  love.graphics.rectangle("fill", sx - 26, sy - 28, 52, 28, 2, 2)
  love.graphics.setColor(0.18, 0.22, 0.28, 1)
  love.graphics.rectangle("line", sx - 26, sy - 28, 52, 28, 2, 2)
  -- Sluice gates
  for i = 0, 2 do
    local gx = sx - 18 + i * 18
    love.graphics.setColor(0.10, 0.18, 0.30, 1)
    love.graphics.rectangle("fill", gx - 4, sy - 14, 8, 14, 1, 1)
    -- Falling water
    for k = 0, 4 do
      local ph = ((t * 1.5 + i * 0.2 + k * 0.2) % 1)
      local wy = sy - 14 + ph * 14
      love.graphics.setColor(color[1], color[2], color[3], (1 - ph) * 0.85)
      love.graphics.rectangle("fill", gx - 2, wy, 4, 2)
    end
  end
  -- Reservoir line
  love.graphics.setColor(color[1], color[2], color[3], 0.80)
  love.graphics.rectangle("fill", sx - 26, sy - 30, 52, 2)
  love.graphics.setColor(color[1], color[2], color[3], 0.45)
  love.graphics.rectangle("fill", sx - 26, sy - 32, 52, 2)
  -- Foam splash
  love.graphics.setColor(1, 1, 1, 0.55)
  for i = 0, 2 do
    love.graphics.circle("fill", sx - 18 + i * 18, sy + math.sin(t * 4 + i) * 1, 2)
  end
end

local function drawGeothermal(sx, sy, color, t)
  -- Pipe / vent with steam plume
  -- Concrete pad
  love.graphics.setColor(0.30, 0.32, 0.36, 1)
  love.graphics.rectangle("fill", sx - 16, sy - 4, 32, 4)
  -- Pipe
  love.graphics.setColor(0.55, 0.55, 0.58, 1)
  love.graphics.rectangle("fill", sx - 6, sy - 24, 12, 22, 2, 2)
  love.graphics.setColor(0.30, 0.30, 0.34, 1)
  love.graphics.rectangle("line", sx - 6, sy - 24, 12, 22, 2, 2)
  -- Hot interior
  love.graphics.setColor(color[1], color[2], color[3], 0.80)
  love.graphics.rectangle("fill", sx - 4, sy - 22, 8, 4, 1, 1)
  -- Side valve wheels
  love.graphics.setColor(0.65, 0.65, 0.70, 1)
  love.graphics.circle("line", sx - 8, sy - 14, 3)
  love.graphics.circle("line", sx + 8, sy - 14, 3)
  -- Steam puffs
  for k = 0, 4 do
    local ph = ((t * 0.6 + k * 0.2) % 1)
    local px = sx + math.sin(t * 1.2 + k) * 4
    local py = sy - 24 - ph * 28
    local pr = 3 + ph * 4
    love.graphics.setColor(0.95, 0.95, 0.95, (1 - ph) * 0.55)
    love.graphics.circle("fill", px, py, pr)
  end
end

local function drawFission(sx, sy, color, t)
  -- Hyperboloid cooling tower with steam plume + dome
  -- Hyperboloid (curved profile via stacked trapezoids)
  for i = 0, 14 do
    local y0 = sy - i * 3
    local y1 = sy - (i + 1) * 3
    local k = i / 14
    local w0 = 22 - math.sin(k * math.pi) * 7
    local w1 = 22 - math.sin((k + 1/14) * math.pi) * 7
    local shade = 0.30 + (1 - k) * 0.20
    love.graphics.setColor(shade, shade, shade + 0.04, 1)
    love.graphics.polygon("fill",
      sx - w0/2, y0,
      sx + w0/2, y0,
      sx + w1/2, y1,
      sx - w1/2, y1)
  end
  -- Top rim
  love.graphics.setColor(0.65, 0.65, 0.70, 1)
  love.graphics.ellipse("line", sx, sy - 45, 11, 3)
  -- Steam billow
  for k = 0, 7 do
    local ph = ((t * 0.4 + k * 0.13) % 1)
    local pr = 6 + ph * 8
    local py = sy - 45 - ph * 30
    local px = sx + math.sin(t * 0.6 + k) * 4
    love.graphics.setColor(0.95, 0.97, 1, (1 - ph) * 0.55)
    love.graphics.circle("fill", px, py, pr)
  end
  -- Reactor dome (small) at base
  love.graphics.setColor(0.40, 0.45, 0.55, 1)
  love.graphics.arc("fill", "open", sx + 18, sy - 6, 8, math.pi, math.pi * 2)
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.circle("fill", sx + 18, sy - 6, 2)
end

local function drawFusion(sx, sy, color, t)
  -- Tokamak ring on a platform with magnetic coils
  -- Platform
  love.graphics.setColor(0.20, 0.22, 0.28, 1)
  love.graphics.ellipse("fill", sx, sy, 24, 7)
  love.graphics.setColor(0.30, 0.35, 0.42, 1)
  love.graphics.ellipse("line", sx, sy, 24, 7)
  -- Toroidal coils (drawn as outer ring)
  love.graphics.setColor(0.30, 0.32, 0.40, 1)
  for k = 0, 7 do
    local a = (k / 8) * math.pi * 2
    local rx = math.cos(a) * 18
    local ry = math.sin(a) * 5
    love.graphics.rectangle("fill", sx + rx - 2, sy - 22 + ry, 4, 8, 1, 1)
  end
  -- Plasma ring (bright)
  for r = 6, 0, -1 do
    local a = (1 - r/6) * 0.55
    love.graphics.setColor(color[1], color[2], color[3], a)
    love.graphics.ellipse("line", sx, sy - 18, 14 + r, 4 + r * 0.5)
  end
  -- Plasma sparks orbiting
  for k = 0, 5 do
    local a = t * 4 + k * (math.pi / 3)
    local px = sx + math.cos(a) * 14
    local py = sy - 18 + math.sin(a) * 4
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", px, py, 1.5)
  end
  -- Top cap
  love.graphics.setColor(0.45, 0.50, 0.55, 1)
  love.graphics.ellipse("fill", sx, sy - 22, 8, 2)
end

local function drawAntimatter(sx, sy, color, t)
  -- Penning trap: caged magnetic field with contained anti-particle
  -- Base
  love.graphics.setColor(0.18, 0.10, 0.18, 1)
  love.graphics.rectangle("fill", sx - 14, sy - 4, 28, 4, 1, 1)
  -- Cage rings (vertical)
  for k = -1, 1, 1 do
    love.graphics.setColor(0.55, 0.30, 0.55, 1)
    love.graphics.line(sx + k * 10, sy, sx + k * 10, sy - 36)
  end
  -- Cage rings (horizontal)
  for j = 0, 4 do
    local y = sy - 4 - j * 8
    love.graphics.setColor(color[1] * 0.6, color[2] * 0.4, color[3] * 0.5, 0.80)
    love.graphics.ellipse("line", sx, y, 12, 4)
  end
  -- Anti-particle glow
  local pulse = 0.7 + math.sin(t * 5) * 0.3
  for r = 6, 0, -1 do
    love.graphics.setColor(color[1], color[2], color[3], (1 - r/6) * 0.7 * pulse)
    love.graphics.circle("fill", sx, sy - 20, 1.5 + r)
  end
  love.graphics.setColor(1, 1, 1, 0.95 * pulse)
  love.graphics.circle("fill", sx, sy - 20, 2)
  -- Containment sparks
  for k = 0, 3 do
    local a = t * 6 + k * (math.pi / 2)
    local px = sx + math.cos(a) * 9
    local py = sy - 20 + math.sin(a) * 3
    love.graphics.setColor(color[1], color[2], color[3], 0.85)
    love.graphics.circle("fill", px, py, 1)
  end
end

local function drawZeropoint(sx, sy, color, t)
  -- Floating Casimir crystal cluster, rainbow shimmer
  -- Base hex platform
  local pts = {}
  for k = 0, 5 do
    local a = (k / 6) * math.pi * 2
    pts[#pts + 1] = sx + math.cos(a) * 14
    pts[#pts + 1] = sy + math.sin(a) * 5
  end
  love.graphics.setColor(0.20, 0.18, 0.30, 1)
  love.graphics.polygon("fill", pts)
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.polygon("line", pts)
  -- Crystals (3 floating shapes)
  for k = 0, 2 do
    local a = t * 0.6 + k * (math.pi * 2 / 3)
    local r = 8
    local cx = sx + math.cos(a) * r
    local cy = sy - 22 + math.sin(a) * 3 + math.sin(t * 1.5 + k) * 2
    -- Crystal diamond
    local hue = ((t * 0.1 + k * 0.33) % 1)
    local cr = 0.5 + 0.5 * math.sin(hue * math.pi * 2)
    local cg = 0.5 + 0.5 * math.sin(hue * math.pi * 2 + math.pi * 2 / 3)
    local cb = 0.5 + 0.5 * math.sin(hue * math.pi * 2 + math.pi * 4 / 3)
    love.graphics.setColor(cr, cg, cb, 0.85)
    love.graphics.polygon("fill",
      cx, cy - 5, cx + 4, cy, cx, cy + 5, cx - 4, cy)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.polygon("line",
      cx, cy - 5, cx + 4, cy, cx, cy + 5, cx - 4, cy)
  end
  -- Central shimmer
  local pulse = 0.7 + math.sin(t * 2) * 0.3
  love.graphics.setColor(color[1], color[2], color[3], 0.85 * pulse)
  love.graphics.circle("fill", sx, sy - 20, 2.5)
  -- Sparks
  for k = 0, 5 do
    local a = (t * 1.5 + k) % (math.pi * 2)
    local rx = math.cos(a) * 18
    local ry = math.sin(a) * 6
    love.graphics.setColor(0.95, 0.95, 1, 0.7)
    love.graphics.circle("fill", sx + rx, sy - 20 + ry, 0.8)
  end
end

local function drawHiggsManifold(sx, sy, color, t)
  -- Resonance lattice: vibrating mesh with bright bosons darting through
  love.graphics.setColor(0.22, 0.10, 0.28, 1)
  love.graphics.rectangle("fill", sx - 22, sy - 4, 44, 4, 1, 1)
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.rectangle("line", sx - 22, sy - 4, 44, 4, 1, 1)
  -- Resonance grid
  for j = 0, 4 do
    for i = 0, 5 do
      local x = sx - 18 + i * 7
      local y = sy - 8 - j * 7 - math.sin(t * 4 + i + j) * 1.5
      love.graphics.setColor(color[1], color[2], color[3], 0.40 + math.sin(t * 6 + i * j) * 0.30)
      love.graphics.circle("fill", x, y, 1.2)
    end
  end
  -- Bright bosons
  for k = 0, 3 do
    local ph = ((t * 1.2 + k * 0.25) % 1)
    local bx = sx - 22 + ph * 44
    local by = sy - 22 + math.sin(t * 5 + k) * 4
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", bx, by, 2)
    love.graphics.setColor(color[1], color[2], color[3], 0.65)
    love.graphics.circle("fill", bx, by, 4)
  end
  -- Containment top cap
  love.graphics.setColor(0.45, 0.30, 0.55, 1)
  love.graphics.rectangle("fill", sx - 14, sy - 44, 28, 4, 1, 1)
  love.graphics.setColor(color[1], color[2], color[3], 0.95)
  love.graphics.rectangle("fill", sx - 12, sy - 45, 24, 1)
end

local function drawEternalSun(sx, sy, color, t)
  -- Captive star: bright sphere with corona + occasional flares
  -- Base shell
  love.graphics.setColor(0.25, 0.22, 0.30, 1)
  love.graphics.ellipse("fill", sx, sy, 26, 8)
  love.graphics.setColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 0.85)
  love.graphics.ellipse("line", sx, sy, 26, 8)

  -- Corona haze
  for r = 32, 0, -1 do
    love.graphics.setColor(color[1], color[2], color[3], (1 - r/32) * 0.16)
    love.graphics.circle("fill", sx, sy - 26, r)
  end

  -- Star body
  for r = 16, 0, -1 do
    local k = r / 16
    love.graphics.setColor(1 - k * 0.10, 0.85 - k * 0.10, 0.30 + k * 0.20, 1)
    love.graphics.circle("fill", sx, sy - 26, r)
  end
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.circle("fill", sx, sy - 26, 4)

  -- Flares
  for k = 0, 5 do
    local a = (k / 6) * math.pi * 2 + t * 0.4
    local len = 18 + math.sin(t * 2 + k) * 5
    local x1 = sx + math.cos(a) * 16
    local y1 = sy - 26 + math.sin(a) * 16
    local x2 = sx + math.cos(a) * (16 + len)
    local y2 = sy - 26 + math.sin(a) * (16 + len)
    love.graphics.setColor(1, 0.85, 0.30, 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.line(x1, y1, x2, y2)
  end
  love.graphics.setLineWidth(1)

  -- Containment torus
  love.graphics.setColor(0.40, 0.35, 0.45, 1)
  love.graphics.ellipse("line", sx, sy - 26, 22, 6)
  love.graphics.ellipse("line", sx, sy - 26, 24, 7)
end

local function drawMultiverseTap(sx, sy, color, t)
  -- Everett-routing manifold: rainbow-shimmer cluster of branching crystals
  -- Hex base
  love.graphics.setColor(0.10, 0.18, 0.22, 1)
  local pts3 = {}
  for k = 0, 5 do
    local a = (k / 6) * math.pi * 2
    pts3[#pts3 + 1] = sx + math.cos(a) * 26
    pts3[#pts3 + 1] = sy + math.sin(a) * 8
  end
  love.graphics.polygon("fill", pts3)
  love.graphics.setColor(color[1], color[2], color[3], 0.85)
  love.graphics.polygon("line", pts3)

  -- Floating branch crystals (color rotates)
  for k = 0, 6 do
    local a = t * 0.3 + k * (math.pi * 2 / 7)
    local rr = 22
    local cx2 = sx + math.cos(a) * rr
    local cy2 = sy - 30 + math.sin(a) * rr * 0.45 + math.sin(t * 2 + k) * 2
    local hue = ((t * 0.05 + k * 0.143) % 1)
    local r = 0.5 + 0.5 * math.sin(hue * math.pi * 2)
    local g = 0.5 + 0.5 * math.sin(hue * math.pi * 2 + math.pi * 2 / 3)
    local b = 0.5 + 0.5 * math.sin(hue * math.pi * 2 + math.pi * 4 / 3)
    -- Tall thin diamond
    love.graphics.setColor(r, g, b, 0.75)
    love.graphics.polygon("fill",
      cx2, cy2 - 8,
      cx2 + 4, cy2,
      cx2, cy2 + 8,
      cx2 - 4, cy2)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.polygon("line",
      cx2, cy2 - 8,
      cx2 + 4, cy2,
      cx2, cy2 + 8,
      cx2 - 4, cy2)
    -- Connection to center
    love.graphics.setColor(r, g, b, 0.30)
    love.graphics.line(sx, sy - 30, cx2, cy2)
  end

  -- Central white bright
  for r = 7, 0, -1 do
    love.graphics.setColor(1, 1, 1, (1 - r/7) * 0.85)
    love.graphics.circle("fill", sx, sy - 30, r)
  end

  -- Branching tendrils outward (rainbow)
  for k = 0, 3 do
    local hue = ((t * 0.1 + k * 0.25) % 1)
    local r = 0.5 + 0.5 * math.sin(hue * math.pi * 2)
    local g = 0.5 + 0.5 * math.sin(hue * math.pi * 2 + math.pi * 2 / 3)
    local b = 0.5 + 0.5 * math.sin(hue * math.pi * 2 + math.pi * 4 / 3)
    local a = t * 0.6 + k * (math.pi / 2)
    local pts4 = {}
    for s = 0, 12 do
      local f = s / 12
      local rr = 4 + f * 38
      local aa = a + f * 1.4
      pts4[#pts4 + 1] = sx + math.cos(aa) * rr
      pts4[#pts4 + 1] = sy - 30 + math.sin(aa) * rr * 0.55
    end
    love.graphics.setColor(r, g, b, 0.50)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(pts4)
  end
  love.graphics.setLineWidth(1)
end

M.energy = {
  solar           = drawSolar,
  wind            = drawWind,
  hydro           = drawHydro,
  geothermal      = drawGeothermal,
  fission         = drawFission,
  fusion          = drawFusion,
  antimatter      = drawAntimatter,
  zeropoint       = drawZeropoint,
  higgs_manifold  = drawHiggsManifold,
  eternal_sun     = drawEternalSun,
  multiverse_tap  = drawMultiverseTap,
}

-- ============================================================
-- Buy pad (a glowing floor button with tier ring + price text)
-- ============================================================

function M.drawBuyPad(sx, sy, color, t, opts)
  opts = opts or {}
  -- Pads animate ONLY when the local player is standing on them
  -- (opts.active = true). Idle pads are completely static so the
  -- player can't mistake an idle ripple for "someone else is using
  -- that pad" — there are no other-user pads in this world; the
  -- ambient pulsing on pads they didn't step on was reading as
  -- foreign activity.
  local active = opts.active
  local outerPulse = active and (0.30 + math.sin(t * 3 + (opts.phase or 0)) * 0.15) or 0.22
  love.graphics.setColor(color[1], color[2], color[3], outerPulse)
  love.graphics.ellipse("fill", sx, sy + 2, 38, 14)
  love.graphics.setColor(color[1], color[2], color[3], active and 0.85 or 0.45)
  love.graphics.setLineWidth(2)
  love.graphics.ellipse("line", sx, sy + 2, 38, 14)
  -- Inner pad
  love.graphics.setColor(color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 0.95)
  love.graphics.ellipse("fill", sx, sy + 2, 30, 11)
  -- Up arrow — bobs / pulses only when active
  local arrowAlpha = active and (0.8 + math.sin(t * 4) * 0.2) or 0.55
  local arrowYOff  = active and (math.sin(t * 4) * 2) or 0
  love.graphics.setColor(color[1], color[2], color[3], arrowAlpha)
  local ay = sy - 8 - arrowYOff
  love.graphics.polygon("fill",
    sx - 5, ay, sx + 5, ay, sx, ay - 6)
  love.graphics.setLineWidth(1)
  -- Spark dots — only orbit while active. Idle pads have a static
  -- ring of 6 dim dots so the pad is still legible without spinning.
  if active then
    for k = 0, 5 do
      local a = (t * 0.8 + k / 6) * math.pi * 2
      local rx = math.cos(a) * 30
      local ry = math.sin(a) * 11
      love.graphics.setColor(color[1], color[2], color[3], 0.85)
      love.graphics.circle("fill", sx + rx, sy + 2 + ry, 1.5)
    end
  else
    for k = 0, 5 do
      local a = (k / 6) * math.pi * 2
      local rx = math.cos(a) * 30
      local ry = math.sin(a) * 11
      love.graphics.setColor(color[1], color[2], color[3], 0.40)
      love.graphics.circle("fill", sx + rx, sy + 2 + ry, 1.2)
    end
  end
  -- When the player is on the pad, add a strong concentric ripple
  -- so the response is unmistakable — this is YOUR step, on YOUR
  -- pad, doing something.
  if active then
    for r = 0, 2 do
      local ph = (t * 1.6 + r * 0.33) % 1
      local rad = 14 + ph * 30
      love.graphics.setColor(color[1], color[2], color[3], (1 - ph) * 0.55)
      love.graphics.setLineWidth(2)
      love.graphics.ellipse("line", sx, sy + 2, rad * 1.0, rad * 0.36)
    end
    love.graphics.setLineWidth(1)
  end
end

-- ============================================================
-- Zepton canister (drawn at iso-projected screen position)
-- Fill: 0..1; when fill ≥ 1.0 the canister "pumps" (caller resets fill).
-- ============================================================

-- Monolith — featureless obsidian obelisk with a single glowing red
-- eye at the top. Tall vertical structure that looks majestic against
-- the iso plot horizon.
function M.drawMonolith(sx, sy, t, opts)
  opts = opts or {}
  local h = opts.h or 110
  local w = opts.w or 18
  local eye = opts.eyeColor or { 1.00, 0.18, 0.20 }
  local body = opts.bodyColor or { 0.06, 0.04, 0.06 }

  -- Long shadow beneath
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.ellipse("fill", sx, sy + 4, w * 1.5, 5)

  -- Body — slightly tapered top, rectangular
  local taper = 2
  love.graphics.setColor(body[1], body[2], body[3], 1)
  love.graphics.polygon("fill",
    sx - w/2,        sy,
    sx + w/2,        sy,
    sx + w/2 - taper, sy - h,
    sx - w/2 + taper, sy - h)
  -- Subtle vertical sheen
  love.graphics.setColor(0.12, 0.10, 0.14, 0.60)
  love.graphics.polygon("fill",
    sx - w/2 + 1,         sy - 2,
    sx - w/2 + 4,         sy - 2,
    sx - w/2 + taper + 4, sy - h + 4,
    sx - w/2 + taper + 1, sy - h + 4)
  -- Edge outline
  love.graphics.setColor(0.20, 0.16, 0.22, 0.95)
  love.graphics.setLineWidth(1)
  love.graphics.polygon("line",
    sx - w/2,        sy,
    sx + w/2,        sy,
    sx + w/2 - taper, sy - h,
    sx - w/2 + taper, sy - h)

  -- Red eye at the top — pulsing slowly
  local eyeY = sy - h + 6
  local pulse = 0.75 + math.sin(t * 1.3) * 0.25
  -- Outer glow halo
  for r = 14, 0, -1 do
    love.graphics.setColor(eye[1], eye[2], eye[3], (1 - r/14) * 0.45 * pulse)
    love.graphics.circle("fill", sx, eyeY, r)
  end
  -- Eye itself
  love.graphics.setColor(0.10, 0.02, 0.04, 1)
  love.graphics.circle("fill", sx, eyeY, 4)
  love.graphics.setColor(eye[1], eye[2], eye[3], 1)
  love.graphics.circle("fill", sx, eyeY, 3)
  love.graphics.setColor(1, 1, 1, pulse * 0.7)
  love.graphics.circle("fill", sx, eyeY, 1)

  -- Dark vapor wisps drifting upward
  for k = 0, 2 do
    local ph = ((t * 0.4 + k * 0.33) % 1)
    local vx = sx + math.sin(t * 1.1 + k) * 5
    local vy = sy - h - ph * 30
    local va = (1 - ph) * 0.30
    love.graphics.setColor(0.18, 0.10, 0.18, va)
    love.graphics.circle("fill", vx, vy, 4 - ph * 2)
  end

  -- Occasional eye-pulse shockwave (every ~3 s)
  local cyc = (t % 3.0)
  if cyc < 0.6 then
    local p = cyc / 0.6
    love.graphics.setColor(eye[1], eye[2], eye[3], (1 - p) * 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", sx, eyeY, 6 + p * 22)
    love.graphics.setLineWidth(1)
  end
end

-- Bitcoin wallet — a hardened vault that visibly fills with stacked
-- gold coins as the player's BTC balance grows. Stack height saturates
-- on a log scale so even endgame balances stay legible.
function M.drawBTCWallet(sx, sy, btcAmount, t, opts)
  opts = opts or {}
  local W = 64
  local H = 56
  local bx = sx - W / 2
  local by = sy - H

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.ellipse("fill", sx, sy + 2, W * 0.55, 6)

  -- Vault body
  love.graphics.setColor(0.18, 0.16, 0.20, 1)
  love.graphics.rectangle("fill", bx, by, W, H, 4, 4)
  love.graphics.setColor(0.32, 0.30, 0.36, 1)
  love.graphics.rectangle("fill", bx + 2, by + 2, W - 4, 8, 3, 3)
  -- Lid hinges
  love.graphics.setColor(0.55, 0.55, 0.62, 1)
  love.graphics.circle("fill", bx + 8,  by + 6, 2)
  love.graphics.circle("fill", bx + W - 8, by + 6, 2)
  -- Outline
  love.graphics.setColor(0.55, 0.55, 0.62, 1)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", bx, by, W, H, 4, 4)
  love.graphics.setLineWidth(1)

  -- Fill: log-scaled level
  local fillFrac = 0
  if btcAmount and btcAmount > 0 then
    fillFrac = math.min(1, math.log10(1 + btcAmount) / 12)
  end
  local fillH = (H - 12) * fillFrac
  if fillH > 0 then
    love.graphics.setColor(0.20, 0.14, 0.04, 1)
    love.graphics.rectangle("fill", bx + 4, by + H - 4 - fillH, W - 8, fillH, 2, 2)
    -- Stack of glowing gold layers inside
    local layers = math.max(1, math.floor(fillFrac * 6))
    local layerH = fillH / layers
    for i = 0, layers - 1 do
      local k = (i + math.sin(t * 1.5 + i)) / layers
      love.graphics.setColor(0.96, 0.65 + (1 - k) * 0.20, 0.18 + (1 - k) * 0.10, 0.95)
      local ly = by + H - 4 - (i + 1) * layerH + 1
      love.graphics.rectangle("fill", bx + 6, ly, W - 12, layerH - 2, 1, 1)
    end
    -- Coin highlights
    for i = 0, math.min(4, layers - 1) do
      love.graphics.setColor(1, 1, 0.85, 0.85)
      love.graphics.circle("fill",
        bx + 12 + (i * 12) + math.sin(t + i) * 1.5,
        by + H - 4 - i * layerH - 4, 2.5)
    end
  end

  -- ₿ glyph on the front (orange diamond emblem)
  local emblemY = by + H - 14
  love.graphics.setColor(0.96, 0.58, 0.10, 1)
  love.graphics.polygon("fill",
    sx, emblemY - 8,
    sx + 8, emblemY,
    sx, emblemY + 8,
    sx - 8, emblemY)
  love.graphics.setColor(0.45, 0.25, 0.05, 1)
  love.graphics.setLineWidth(1.5)
  love.graphics.polygon("line",
    sx, emblemY - 8,
    sx + 8, emblemY,
    sx, emblemY + 8,
    sx - 8, emblemY)
  love.graphics.setLineWidth(1)
  -- White tick mark inside the diamond
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.line(sx - 3, emblemY, sx, emblemY + 3, sx + 4, emblemY - 3)
  love.graphics.setLineWidth(1)

  -- Pulsing glow around the emblem when fill > 0
  if fillFrac > 0.05 then
    local pulse = 0.55 + math.sin(t * 2) * 0.20
    for r = 12, 0, -1 do
      love.graphics.setColor(0.96, 0.58, 0.10, (1 - r/12) * 0.18 * pulse)
      love.graphics.circle("fill", sx, emblemY, 8 + r)
    end
  end
end

function M.drawCanister(sx, sy, fill, color, t, opts)
  opts = opts or {}
  fill = math.max(0, math.min(1, fill or 0))
  -- Bigger canisters so they read as substantial industrial hardware,
  -- matching the new mid-game / late-game tier visuals.
  local h = 84
  local w = 32

  -- Base
  love.graphics.setColor(0.18, 0.20, 0.24, 1)
  love.graphics.ellipse("fill", sx, sy, w * 0.7, 5)
  love.graphics.setColor(0.30, 0.32, 0.36, 1)
  love.graphics.rectangle("fill", sx - w/2 - 3, sy - 4, w + 6, 4, 1, 1)

  -- Glass cylinder outline
  love.graphics.setColor(0.65, 0.85, 0.95, 0.40)
  love.graphics.rectangle("line", sx - w/2, sy - h, w, h, 4, 4)
  love.graphics.ellipse("line", sx, sy - h, w/2, 4)
  love.graphics.ellipse("line", sx, sy, w/2, 4)

  -- Liquid fill — color tints from neutral (transparent) to glowing green
  local fillH = h * fill
  local glow = fill  -- the more compressed the cluster, the brighter
  local r, g, b = color[1], color[2], color[3]
  -- Background "neutral" tint when low
  love.graphics.setColor(r * 0.20, g * 0.30, b * 0.25, 0.30 + glow * 0.30)
  love.graphics.rectangle("fill", sx - w/2 + 1, sy - fillH, w - 2, fillH, 3, 3)
  -- Cluster glow at top of fill
  if glow > 0.05 then
    for r2 = 0, 6 do
      love.graphics.setColor(r, g, b, glow * (1 - r2/7) * 0.65)
      love.graphics.rectangle("fill", sx - w/2 + 1 - r2, sy - fillH - r2, w - 2 + r2 * 2, math.max(2, fillH * 0.6))
    end
    -- Central bright stripe
    love.graphics.setColor(r * 1.4, g * 1.4, b * 1.4, glow)
    love.graphics.rectangle("fill", sx - 3, sy - fillH, 6, fillH * 0.6)
  end
  -- Bubbles when filling
  for k = 0, 3 do
    local ph = ((t * 0.8 + k * 0.25) % 1)
    if ph < fill then
      local bx = sx - w/4 + math.sin(t * 2 + k) * 4
      local by = sy - ph * h
      love.graphics.setColor(r * 1.2, g * 1.2, b * 1.2, 0.85)
      love.graphics.circle("fill", bx, by, 1.5)
    end
  end
  -- Top cap with LED (lights up at high fill)
  love.graphics.setColor(0.30, 0.32, 0.40, 1)
  love.graphics.rectangle("fill", sx - w/2 - 2, sy - h - 4, w + 4, 4, 1, 1)
  local lit = fill > 0.85 and (math.sin(t * 6) * 0.5 + 0.5) or 0.15
  love.graphics.setColor(r, g, b, 0.30 + lit)
  love.graphics.circle("fill", sx, sy - h - 2, 2.5)
  -- Halo when full
  if fill >= 0.99 then
    for r3 = 0, 8 do
      love.graphics.setColor(r, g, b, (1 - r3/9) * 0.30)
      love.graphics.circle("fill", sx, sy - h/2, 18 + r3)
    end
  end
end

return M
