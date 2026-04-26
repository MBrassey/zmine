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
-- Pass opts.btc=true for the orange ₿ coin; default is the green Z.
function M.drawWithLabel(sx, sy, size, t, value, font, color, opts)
  opts = opts or {}
  if opts.btc then
    M.drawBTC(sx + size, sy, size, t, opts)
  else
    M.draw(sx + size, sy, size, t, opts)
  end
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

-- BTC coin — orange disk + the actual ₿ Unicode glyph (U+20BF). If the
-- bundled font doesn't have ₿, fall back to a "B" plus four short
-- vertical strokes (two above, two below) so the glyph is recognisable
-- on any font. Way cleaner than hand-rolling the geometry from primitives.

local btcFontCache = {}
local function btcFont(s)
  local key = math.max(8, math.floor(s))
  if not btcFontCache[key] then
    btcFontCache[key] = love.graphics.newFont(key)
  end
  return btcFontCache[key]
end

local btcGlyphResolved
local function btcGlyph()
  if btcGlyphResolved ~= nil then return btcGlyphResolved end
  local f = btcFont(20)
  -- Preference order:
  --   1. ₿ (U+20BF) — the actual Bitcoin Sign codepoint, but missing
  --      from older bundled fonts.
  --   2. B + ⃦ (U+0042 + U+20E6 combining double vertical stroke
  --      overlay) — renders as a B with two vertical strokes through
  --      it; supported by any font that handles basic combining marks.
  --   3. Plain B + manual rectangle strokes (universal fallback).
  if f.hasGlyphs and f:hasGlyphs("₿") then
    btcGlyphResolved = "₿"
  elseif f.hasGlyphs and f:hasGlyphs("B\u{20E6}") then
    btcGlyphResolved = "B\u{20E6}"
  else
    btcGlyphResolved = "B"
  end
  return btcGlyphResolved
end
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

  -- Disc — slightly darker outer body, brighter inner highlight
  love.graphics.setColor(cR * 0.92, cG * 0.92, cB * 0.92, 1)
  love.graphics.circle("fill", sx, sy, size)
  love.graphics.setColor(math.min(1, cR + 0.04), math.min(1, cG + 0.05), math.min(1, cB + 0.05), 1)
  love.graphics.circle("fill", sx, sy, size * 0.94)

  -- Rim
  love.graphics.setColor(cR * 0.55, cG * 0.40, cB * 0.25, 1)
  love.graphics.setLineWidth(math.max(1.2, size * 0.06))
  love.graphics.circle("line", sx, sy, size)
  love.graphics.setLineWidth(1)

  -- Print the ₿ glyph (or "B" + manual strokes if the bundled font
  -- doesn't have U+20BF). Font size is derived from coin size; cache
  -- per-integer-size so we don't re-allocate fonts on every frame.
  local prevFont = love.graphics.getFont()
  local fontSize = math.floor(size * 1.55)
  local font = btcFont(fontSize)
  love.graphics.setFont(font)
  local glyph = btcGlyph()
  local glyphW = font:getWidth(glyph)
  local glyphH = font:getHeight()
  local gx = sx - glyphW / 2
  local gy = sy - glyphH / 2 - size * 0.04

  -- Drop shadow
  love.graphics.setColor(0.20, 0.10, 0.02, 0.45)
  love.graphics.print(glyph, gx + math.max(1, size * 0.05), gy + math.max(1, size * 0.05))
  -- Bright glyph
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(glyph, gx, gy)

  -- Fallback strokes when the font doesn't carry ₿: emulate the two
  -- vertical bars sticking above the top and below the bottom of a B.
  if glyph == "B" then
    local strokeW = math.max(1.5, size * 0.13)
    local strokeH = math.max(2,   size * 0.20)
    local b1 = sx - glyphW / 2 + glyphW * 0.18
    local b2 = sx - glyphW / 2 + glyphW * 0.42
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", b1, gy - strokeH * 0.55, strokeW, strokeH)
    love.graphics.rectangle("fill", b2, gy - strokeH * 0.55, strokeW, strokeH)
    love.graphics.rectangle("fill", b1, gy + glyphH - strokeH * 0.45, strokeW, strokeH)
    love.graphics.rectangle("fill", b2, gy + glyphH - strokeH * 0.45, strokeW, strokeH)
  end

  if prevFont then love.graphics.setFont(prevFont) end

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
