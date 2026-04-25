-- Floating "+Z" texts that drift up from emit point and fade out.
local M = {}

local Floats = {}
Floats.__index = Floats

function M.new()
  local f = setmetatable({}, Floats)
  f.list = {}
  return f
end

function Floats:emit(opts)
  self.list[#self.list + 1] = {
    x = opts.x, y = opts.y,
    vx = opts.vx or (love.math.random() - 0.5) * 80,
    vy = opts.vy or -(110 + love.math.random() * 60),
    text = opts.text or "+Z",
    color = opts.color or { 0.4, 1.0, 0.6 },
    size = opts.size or 1.0,
    life = opts.life or 1.4,
    maxLife = opts.life or 1.4,
    weight = opts.weight or "normal",
  }
end

function Floats:update(dt)
  local list = self.list
  local i = 1
  while i <= #list do
    local f = list[i]
    f.life = f.life - dt
    if f.life <= 0 then
      list[i] = list[#list]
      list[#list] = nil
    else
      f.x = f.x + f.vx * dt
      f.y = f.y + f.vy * dt
      f.vx = f.vx * (1 - 1.5 * dt)
      f.vy = f.vy + 80 * dt
      i = i + 1
    end
  end
end

function Floats:draw(fonts)
  for _, f in ipairs(self.list) do
    local lf = f.life / f.maxLife
    local a = math.min(1, lf * 1.6)
    local font = (f.weight == "bold") and fonts.boldL or fonts.bold
    if f.size > 1.5 then font = fonts.boldXL end
    love.graphics.setFont(font)
    -- Soft shadow
    love.graphics.setColor(0, 0, 0, a * 0.6)
    love.graphics.print(f.text, f.x + 2, f.y + 2)
    love.graphics.setColor(f.color[1], f.color[2], f.color[3], a)
    love.graphics.print(f.text, f.x, f.y)
  end
end

function Floats:count() return #self.list end
function Floats:clear() self.list = {} end

return M
