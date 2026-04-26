-- Z-coin logo. Glowy hexagonal coin with a stylized Z stroke,
-- animated rim shimmer, orbiting sparkles. Rendered at any size.
--
-- Use M.draw(sx, sy, size, t, opts?) — sx,sy is the center.
-- M.drawWithLabel(sx, sy, size, t, value, font, color?) renders coin then
-- a numeric label to its right; returns the total drawn width.

local fmt = require "src.format"

local M = {}

local function hsv(h, s, v)
  -- minimal HSV→RGB
  local r, g, b
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  i = i % 6
  if i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  else r, g, b = v, p, q end
  return r, g, b
end

local DEFAULT_COLOR = { 0.30, 1.00, 0.55 }

function M.draw(sx, sy, size, t, opts)
  opts = opts or {}
  size = size or 14
  local c = opts.color or DEFAULT_COLOR
  local cR, cG, cB = c[1], c[2], c[3]
  local pulse = 0.85 + math.sin(t * 2.4) * 0.15

  -- Outer glow halo
  for r = 6, 0, -1 do
    local a = (1 - r / 7) * 0.25 * pulse
    love.graphics.setColor(cR, cG, cB, a)
    love.graphics.circle("fill", sx, sy, size * (1.05 + r * 0.13))
  end

  -- Coin body — hex shape with subtle gradient
  local hexPts = {}
  for k = 0, 5 do
    local a = (k / 6) * math.pi * 2 + math.pi / 6 + t * 0.15
    hexPts[#hexPts + 1] = sx + math.cos(a) * size
    hexPts[#hexPts + 1] = sy + math.sin(a) * size
  end
  -- Dark center fill
  love.graphics.setColor(0.05, 0.10, 0.07, 1)
  love.graphics.polygon("fill", hexPts)
  -- Inner gradient rings
  for r = 0, 5 do
    local k = r / 5
    love.graphics.setColor(cR * (0.20 + k * 0.20), cG * (0.30 + k * 0.30),
                           cB * (0.20 + k * 0.20), 0.85 - k * 0.10)
    local rr = size * (1 - r * 0.08)
    love.graphics.circle("fill", sx, sy, rr)
  end

  -- Rim hex
  love.graphics.setColor(cR, cG, cB, 1)
  love.graphics.setLineWidth(math.max(1.2, size * 0.10))
  love.graphics.polygon("line", hexPts)

  -- Inner rim ring
  love.graphics.setColor(cR * 0.6, cG * 0.6, cB * 0.6, 0.85)
  love.graphics.setLineWidth(math.max(1, size * 0.06))
  love.graphics.circle("line", sx, sy, size * 0.78)
  love.graphics.setLineWidth(1)

  -- Z letter — three connected strokes forming a Z
  local s = size * 0.55
  local zL = sx - s
  local zR = sx + s
  local zT = sy - s * 0.85
  local zB = sy + s * 0.85
  local zw = math.max(1.5, size * 0.18)
  -- Drop shadow
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.setLineWidth(zw)
  love.graphics.line(zL + 1, zT + 1, zR + 1, zT + 1)
  love.graphics.line(zR + 1, zT + 1, zL + 1, zB + 1)
  love.graphics.line(zL + 1, zB + 1, zR + 1, zB + 1)
  -- Bright Z
  love.graphics.setColor(0.95, 1, 0.92, 1)
  love.graphics.line(zL, zT, zR, zT)
  love.graphics.line(zR, zT, zL, zB)
  love.graphics.line(zL, zB, zR, zB)
  -- Inner highlight
  love.graphics.setColor(cR, cG, cB, 0.85 + pulse * 0.10)
  love.graphics.setLineWidth(math.max(1, size * 0.08))
  love.graphics.line(zL, zT, zR, zT)
  love.graphics.line(zR, zT, zL, zB)
  love.graphics.line(zL, zB, zR, zB)
  love.graphics.setLineWidth(1)

  -- Orbital sparkles
  if size >= 8 then
    local n = math.min(6, math.floor(size / 4))
    for k = 0, n - 1 do
      local a = (t * 1.2 + k / n) * math.pi * 2
      local rx = math.cos(a) * size * 1.35
      local ry = math.sin(a) * size * 1.35
      local sa = 0.6 + math.sin(t * 3 + k) * 0.30
      love.graphics.setColor(cR, cG, cB, sa)
      love.graphics.circle("fill", sx + rx, sy + ry, size * 0.08)
      love.graphics.setColor(1, 1, 1, sa * 0.6)
      love.graphics.circle("fill", sx + rx, sy + ry, size * 0.04)
    end
  end

  -- Specular highlight (top-left moon)
  love.graphics.setColor(1, 1, 1, 0.30)
  love.graphics.arc("fill", "open", sx - size * 0.25, sy - size * 0.25,
                    size * 0.30, math.pi * 1.1, math.pi * 1.6)
end

-- Draw the coin and a numeric label to its right at the same vertical center.
-- Returns the total drawn width (coin + gap + text).
function M.drawWithLabel(sx, sy, size, t, value, font, color, opts)
  opts = opts or {}
  M.draw(sx + size, sy, size, t, opts)
  local label = (type(value) == "string") and value or fmt.zeptons(value)
  local f = font or love.graphics.getFont()
  love.graphics.setFont(f)
  local lw = f:getWidth(label)
  local fh = f:getHeight()
  if color then
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
  else
    love.graphics.setColor(0.95, 1, 0.92, 1)
  end
  local lx = sx + size * 2 + 6
  local ly = sy - fh / 2
  love.graphics.print(label, lx, ly)
  return (size * 2) + 6 + lw
end

-- Draw a coin and label centered around (cx, cy).
function M.drawCentered(cx, cy, size, t, value, font, color, opts)
  local label = (type(value) == "string") and value or fmt.zeptons(value)
  local f = font or love.graphics.getFont()
  local lw = f:getWidth(label)
  local total = size * 2 + 6 + lw
  M.drawWithLabel(cx - total / 2, cy, size, t, value, f, color, opts)
end

-- BTC coin — official Bitcoin orange disk + white ₿ glyph constructed
-- from filled primitives so the symbol is solid and reads cleanly at
-- any size. Composition matches the real Bitcoin logo:
--   * orange circle (#F7931A)
--   * white vertical stem
--   * two white D-loops on the right with orange ring-cutouts
--   * two short vertical serifs above the top and below the bottom
function M.drawBTC(sx, sy, size, t, opts)
  opts = opts or {}
  size = size or 14
  local pulse = 0.85 + math.sin(t * 2.4) * 0.15
  -- Bitcoin orange #F7931A
  local cR, cG, cB = 0.969, 0.576, 0.102

  -- Outer halo
  for r = 5, 0, -1 do
    love.graphics.setColor(cR, cG, cB, (1 - r/6) * 0.22 * pulse)
    love.graphics.circle("fill", sx, sy, size * (1.05 + r * 0.10))
  end

  -- Coin body — slightly darker outer disc, brighter inner highlight
  love.graphics.setColor(cR * 0.92, cG * 0.92, cB * 0.92, 1)
  love.graphics.circle("fill", sx, sy, size)
  local hiR, hiG, hiB = math.min(1, cR + 0.05), math.min(1, cG + 0.06), math.min(1, cB + 0.06)
  love.graphics.setColor(hiR, hiG, hiB, 1)
  love.graphics.circle("fill", sx, sy, size * 0.94)

  -- Outer rim (darker)
  love.graphics.setColor(cR * 0.55, cG * 0.40, cB * 0.25, 1)
  love.graphics.setLineWidth(math.max(1.2, size * 0.06))
  love.graphics.circle("line", sx, sy, size)
  love.graphics.setLineWidth(1)

  -- ₿ geometry. Stem on the left, two D-loops on the right.
  local stemW   = size * 0.20
  local stemH   = size * 1.04
  local stemX   = sx - size * 0.36
  local stemY   = sy - stemH * 0.5
  local stemR   = stemX + stemW
  local loopR   = size * 0.36
  local loopInR = size * 0.18
  local topLoopY = stemY + loopR
  local botLoopY = stemY + stemH - loopR

  -- Drop shadow (subtle, baked into the coin face)
  love.graphics.setColor(0.32, 0.16, 0.04, 0.40)
  love.graphics.rectangle("fill", stemX + size * 0.05, stemY + size * 0.05, stemW, stemH)
  love.graphics.arc("fill", "pie",
    stemR + size * 0.05, topLoopY + size * 0.05, loopR, -math.pi / 2, math.pi / 2)
  love.graphics.arc("fill", "pie",
    stemR + size * 0.05, botLoopY + size * 0.05, loopR, -math.pi / 2, math.pi / 2)

  -- White ₿
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", stemX, stemY, stemW, stemH)
  -- Top D-loop (white semicircle, flat side facing the stem)
  love.graphics.arc("fill", "pie", stemR, topLoopY, loopR, -math.pi / 2, math.pi / 2)
  -- Bottom D-loop
  love.graphics.arc("fill", "pie", stemR, botLoopY, loopR, -math.pi / 2, math.pi / 2)

  -- Orange ring-cutouts inside each loop so they read as rings, not pies.
  -- This matches the Wikipedia Bitcoin logo where orange shows through.
  love.graphics.setColor(hiR, hiG, hiB, 1)
  love.graphics.arc("fill", "pie", stemR, topLoopY, loopInR, -math.pi / 2, math.pi / 2)
  love.graphics.arc("fill", "pie", stemR, botLoopY, loopInR, -math.pi / 2, math.pi / 2)

  -- White connecting bar between the two cutouts (so the cutouts are
  -- separate "eyes" not one big slot — and so the stem reads connected
  -- to both loops at the inner edge).
  love.graphics.setColor(1, 1, 1, 1)
  local connY = sy - size * 0.06
  local connH = size * 0.12
  love.graphics.rectangle("fill", stemX, connY, stemW + size * 0.02, connH)

  -- Top + bottom serifs: two short vertical bars above the top of the
  -- stem and two below the bottom. These align with the "left edges"
  -- of where the inner cut-outs would be if extrapolated.
  local serifH = size * 0.18
  local serifW = stemW * 0.45
  local serifL = stemX + stemW * 0.08
  local serifR = stemX + stemW * 0.50
  -- Top
  love.graphics.rectangle("fill", serifL, stemY - serifH, serifW, serifH + size * 0.02)
  love.graphics.rectangle("fill", serifR, stemY - serifH, serifW, serifH + size * 0.02)
  -- Bottom
  love.graphics.rectangle("fill", serifL, stemY + stemH - size * 0.02, serifW, serifH + size * 0.02)
  love.graphics.rectangle("fill", serifR, stemY + stemH - size * 0.02, serifW, serifH + size * 0.02)

  -- Specular highlight (top-left of disc)
  love.graphics.setColor(1, 1, 1, 0.28)
  love.graphics.arc("fill", "open", sx - size * 0.32, sy - size * 0.32,
                    size * 0.34, math.pi * 1.1, math.pi * 1.6)

  -- Orbital sparkles
  if size >= 8 then
    for k = 0, 3 do
      local a = (t * 1.2 + k / 4) * math.pi * 2
      local rx = math.cos(a) * size * 1.30
      local ry = math.sin(a) * size * 1.30
      love.graphics.setColor(cR, cG, cB, 0.60)
      love.graphics.circle("fill", sx + rx, sy + ry, size * 0.07)
    end
  end
end

return M
