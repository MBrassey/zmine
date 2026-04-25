local M = {}

-- Lightweight scalar particle system (CPU). Each particle is a flat table.
-- We avoid love.graphics.newParticleSystem to keep precise control over
-- additive blending, color life curves, and spawn behavior.

local function pack(p)
  return p
end

local Particles = {}
Particles.__index = Particles

function M.new()
  local s = setmetatable({}, Particles)
  s.list = {}
  s.cap  = 4000
  return s
end

function Particles:emit(p)
  if #self.list >= self.cap then
    -- Evict the oldest (front of list)
    table.remove(self.list, 1)
  end
  self.list[#self.list + 1] = pack(p)
end

function Particles:burst(opts)
  local n     = opts.n or 16
  local x, y  = opts.x, opts.y
  local color = opts.color or { 0.2, 1.0, 0.5 }
  local minS  = opts.minSpeed or 80
  local maxS  = opts.maxSpeed or 380
  local life  = opts.life or 1.2
  local size  = opts.size or 4
  local drag  = opts.drag or 1.4
  for i = 1, n do
    local a = love.math.random() * math.pi * 2
    local s = minS + love.math.random() * (maxS - minS)
    self:emit({
      x = x, y = y,
      vx = math.cos(a) * s,
      vy = math.sin(a) * s,
      ax = 0, ay = opts.gravity or 0,
      life = life * (0.7 + love.math.random() * 0.6),
      maxLife = life,
      color = { color[1], color[2], color[3] },
      size = size * (0.7 + love.math.random() * 0.7),
      drag = drag,
      kind = opts.kind or "spark",
      rot = love.math.random() * math.pi * 2,
      vrot = (love.math.random() - 0.5) * 6,
    })
  end
end

function Particles:stream(opts)
  -- Continuous emission; pass dt + rate
  local rate = opts.rate or 30
  local n = math.floor(rate * opts.dt + love.math.random())
  for i = 1, n do
    local a = (opts.angle or 0) + ((opts.spread or math.pi) * (love.math.random() - 0.5))
    local s = (opts.minSpeed or 60) + love.math.random() * ((opts.maxSpeed or 200) - (opts.minSpeed or 60))
    self:emit({
      x = opts.x, y = opts.y,
      vx = math.cos(a) * s,
      vy = math.sin(a) * s,
      ax = 0, ay = opts.gravity or 0,
      life = opts.life or 0.8,
      maxLife = opts.life or 0.8,
      color = { (opts.color or {0,1,0.5})[1], (opts.color or {0,1,0.5})[2], (opts.color or {0,1,0.5})[3] },
      size = opts.size or 3,
      drag = opts.drag or 1.5,
      kind = opts.kind or "spark",
      rot = 0, vrot = 0,
    })
  end
end

function Particles:flyTo(opts)
  -- A particle that homes toward a target with attraction
  self:emit({
    x = opts.fromX, y = opts.fromY,
    vx = (love.math.random() - 0.5) * 80,
    vy = (love.math.random() - 0.5) * 80 - 60,
    ax = 0, ay = 0,
    life = opts.life or 1.4,
    maxLife = opts.life or 1.4,
    color = { (opts.color or {0,1,0.5})[1], (opts.color or {0,1,0.5})[2], (opts.color or {0,1,0.5})[3] },
    size = opts.size or 4,
    drag = 0.4,
    kind = "homing",
    targetX = opts.toX, targetY = opts.toY,
    homing = opts.homing or 8,
    rot = 0, vrot = 0,
  })
end

function Particles:update(dt)
  local list = self.list
  local i = 1
  while i <= #list do
    local p = list[i]
    p.life = p.life - dt
    if p.life <= 0 then
      list[i] = list[#list]
      list[#list] = nil
    else
      if p.kind == "homing" and p.targetX then
        local dx = p.targetX - p.x
        local dy = p.targetY - p.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.001
        local accel = p.homing
        p.vx = p.vx + (dx / d) * accel * 60 * dt
        p.vy = p.vy + (dy / d) * accel * 60 * dt
      end
      p.vx = p.vx + p.ax * dt
      p.vy = p.vy + p.ay * dt
      local damp = math.max(0, 1 - p.drag * dt)
      p.vx = p.vx * damp
      p.vy = p.vy * damp
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.rot = p.rot + p.vrot * dt
      i = i + 1
    end
  end
end

local function drawSpark(p, alpha)
  love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
  love.graphics.circle("fill", p.x, p.y, p.size * (p.life / p.maxLife))
  love.graphics.setColor(1, 1, 1, alpha * 0.5)
  love.graphics.circle("fill", p.x, p.y, p.size * (p.life / p.maxLife) * 0.5)
end

local function drawTrail(p, alpha)
  local tail = p.size * (p.life / p.maxLife) * 6
  local len = math.sqrt(p.vx * p.vx + p.vy * p.vy) + 0.01
  local ux, uy = p.vx / len, p.vy / len
  love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
  love.graphics.setLineWidth(p.size * 0.5)
  love.graphics.line(p.x, p.y, p.x - ux * tail, p.y - uy * tail)
  love.graphics.circle("fill", p.x, p.y, p.size * 0.4)
end

local function drawPulse(p, alpha)
  local r = p.size * (1 + (1 - p.life / p.maxLife) * 4)
  love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", p.x, p.y, r)
end

local function drawHex(p, alpha)
  local r = p.size * (p.life / p.maxLife)
  love.graphics.push()
  love.graphics.translate(p.x, p.y)
  love.graphics.rotate(p.rot)
  love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
  local pts = {}
  for k = 0, 5 do
    local a = k * math.pi / 3
    pts[#pts + 1] = math.cos(a) * r
    pts[#pts + 1] = math.sin(a) * r
  end
  love.graphics.polygon("line", pts)
  love.graphics.pop()
end

function Particles:draw()
  love.graphics.setBlendMode("add")
  for _, p in ipairs(self.list) do
    local lf = p.life / p.maxLife
    local a = math.min(1, lf * 1.4)
    if p.kind == "trail" or p.kind == "homing" then
      drawTrail(p, a)
    elseif p.kind == "pulse" then
      drawPulse(p, a)
    elseif p.kind == "hex" then
      drawHex(p, a)
    else
      drawSpark(p, a)
    end
  end
  love.graphics.setBlendMode("alpha")
  love.graphics.setLineWidth(1)
end

function Particles:count()
  return #self.list
end

function Particles:clear()
  self.list = {}
end

return M
