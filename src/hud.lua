local fmt = require "src.format"

local M = {}

local DESIGN_W, DESIGN_H = 1920, 1080
local HUD_H = 96

local function colorBg() love.graphics.setColor(0.04, 0.07, 0.06, 0.95) end

local function drawProgressBar(x, y, w, h, pct, color, label)
  pct = math.max(0, math.min(1, pct))
  love.graphics.setColor(0.05, 0.10, 0.08, 1)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  love.graphics.setColor(color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 0.5)
  love.graphics.rectangle("fill", x, y, w * 1.0, h, 4, 4)
  love.graphics.setColor(color[1], color[2], color[3], 0.95)
  love.graphics.rectangle("fill", x, y, w * pct, h, 4, 4)
  love.graphics.setColor(color[1], color[2], color[3], 1)
  love.graphics.rectangle("line", x, y, w, h, 4, 4)
  if label then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(label, x + 8, y + 2)
  end
end

function M.draw(state, fonts, t)
  -- Background bar
  love.graphics.setColor(0.025, 0.05, 0.04, 1)
  love.graphics.rectangle("fill", 0, 0, DESIGN_W, HUD_H)
  -- Bottom rule
  love.graphics.setColor(0.20, 0.85, 0.50, 0.7)
  love.graphics.setLineWidth(1)
  love.graphics.line(0, HUD_H, DESIGN_W, HUD_H)
  love.graphics.setColor(0.20, 0.85, 0.50, 0.25)
  love.graphics.rectangle("fill", 0, HUD_H - 1, DESIGN_W, 4)

  -- Section: facility name (top-left)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.40, 0.70, 0.55, 1)
  love.graphics.print("FACILITY", 30, 14)

  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.85, 1, 0.92, 1)
  love.graphics.print(state.facility_name or "—", 30, 36)

  -- Section: zepton balance (center-left)
  local zx = 540
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.35, 0.95, 0.55, 1)
  love.graphics.print("ZEPTONS", zx, 14)

  love.graphics.setFont(fonts.giant)
  -- Glow underlay
  local s = fmt.zeptons(state.z)
  love.graphics.setColor(0.35, 1, 0.6, 0.30)
  love.graphics.print(s, zx + 2, 32 + 2)
  love.graphics.setColor(0.55, 1, 0.75, 1)
  love.graphics.print(s, zx, 32)

  -- Rate beside balance
  love.graphics.setFont(fonts.medium)
  local rateStr = "+" .. fmt.rate(state.z_per_sec)
  local zw = fonts.giant:getWidth(s)
  love.graphics.setColor(0.50, 0.95, 0.65, 1)
  love.graphics.print(rateStr, zx + zw + 18, 56)

  -- Section: energy
  local ex = 1100
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.95, 0.85, 0.45, 1)
  love.graphics.print("ENERGY  GRID", ex, 14)

  -- Use / supply
  love.graphics.setFont(fonts.medium)
  love.graphics.setColor(0.98, 0.95, 0.78, 1)
  local energyStr = string.format("%s / %s", fmt.energy(state.energy_used), fmt.energy(state.energy_supply))
  love.graphics.print(energyStr, ex, 38)

  -- Bar
  local barW, barH = 380, 18
  local pct = (state.energy_supply > 0) and (state.energy_used / state.energy_supply) or 0
  local barColor = { 0.30, 1.00, 0.55 }
  if pct > 0.95 then
    barColor = { 1.00, 0.40, 0.40 }
  elseif pct > 0.85 then
    barColor = { 1.00, 0.75, 0.30 }
  end
  drawProgressBar(ex, 70, barW, barH, pct, barColor, nil)

  -- Section: time + miner count + status
  local tx = 1560
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.55, 0.85, 0.95, 1)
  love.graphics.print("UPTIME", tx, 14)

  love.graphics.setFont(fonts.medium)
  love.graphics.setColor(0.85, 0.95, 1, 1)
  love.graphics.print(fmt.time(state.play_time or 0), tx, 38)

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.45, 0.75, 0.90, 1)
  love.graphics.print(string.format("MINERS %d", state.miner_count or 0), tx, 70)

  -- Pause indicator
  if state.paused then
    love.graphics.setFont(fonts.bold)
    local pulse = math.sin(t * 4) * 0.4 + 0.6
    love.graphics.setColor(1, 0.55, 0.30, pulse)
    love.graphics.print("[ PAUSED ]", DESIGN_W - 200, 14)
  end
end

function M.height() return HUD_H end

return M
