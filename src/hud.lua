local fmt  = require "src.format"
local Coin = require "src.coin"

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

  -- Section: zepton balance (center-left) — with glowy Z-coin
  local zx = 540
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.35, 0.95, 0.55, 1)
  love.graphics.print("ZEPTONS", zx, 14)

  -- Big animated coin
  Coin.draw(zx + 26, 56, 22, t)

  love.graphics.setFont(fonts.giant)
  local s = fmt.zeptons(state.z)
  love.graphics.setColor(0.35, 1, 0.6, 0.30)
  love.graphics.print(s, zx + 60 + 2, 32 + 2)
  love.graphics.setColor(0.55, 1, 0.75, 1)
  love.graphics.print(s, zx + 60, 32)

  -- Rate beside balance
  love.graphics.setFont(fonts.medium)
  local rateStr = "+" .. fmt.rate(state.z_per_sec)
  local zw = fonts.giant:getWidth(s)
  love.graphics.setColor(0.50, 0.95, 0.65, 1)
  love.graphics.print(rateStr, zx + 60 + zw + 18, 56)

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

  -- Brownout overlay: when demand exceeds supply we show the throttle %
  if state.energy_demand_raw and state.energy_supply and
     state.energy_demand_raw > state.energy_supply and state.energy_supply > 0 then
    local throttle = 1 - (state.energy_supply / state.energy_demand_raw)
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(1, 0.55, 0.30, 0.95)
    love.graphics.printf(
      string.format("THROTTLING %d%%", math.floor(throttle * 100)),
      ex, 70 + (barH - 12) / 2, barW, "center")
  end

  -- Section: HASH and BLOCK chips, in their own column at right of energy.
  -- Bands: HASH/BLOCK column 1492-1670 (12px alley after energy bar),
  -- LIVE badge column 1690-1900 (210w).
  local hx = 1492
  -- HASH chip — amber so the dual-gold collision with BLOCK TIMELINE
  -- in the console is broken; the console's gold is reserved for
  -- block-found semantics.
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(1, 0.75, 0.30, 1)
  love.graphics.print("HASH", hx, 10)
  love.graphics.setFont(fonts.medium)
  love.graphics.setColor(1, 0.85, 0.40, 1)
  love.graphics.print(fmt.hashRate(state.hashrate or 0), hx, 26)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(1, 0.75, 0.30, 1)
  love.graphics.print("BLOCK", hx, 52)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(1, 0.85, 0.40, 1)
  love.graphics.print(string.format("#%d  ·  %s",
    state.block_height or 0, fmt.time(state.play_time or 0)), hx, 68)

  -- Live mesh badge — slim, right-pinned, no overlap with HASH/BLOCK.
  local Network = require "src.network"
  local activeRoom   = state.network and Network.activePeerCount(state.network)   or 0
  local activeGlobal = state.network and Network.globalActiveUsers(state.network) or 0
  local last24h      = state.network and Network.globalLast24h(state.network)     or 0
  local meshLive     = state.network and state.network.mode == "real"
  do
    local bw, bh = 210, 76
    local bx, by = DESIGN_W - bw - 10, 10
    local pulse = 0.65 + math.sin(t * 4) * 0.35
    if meshLive then
      love.graphics.setColor(0.04, 0.10, 0.20, 0.95)
      love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
      love.graphics.setColor(0.30, 0.85, 1.00, pulse)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
      love.graphics.setLineWidth(1)
      love.graphics.setColor(0.30, 1, 0.55, pulse)
      love.graphics.circle("fill", bx + 16, by + 22, 6)
      love.graphics.setColor(0.30, 1, 0.55, pulse * 0.4)
      love.graphics.circle("fill", bx + 16, by + 22, 11)
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.30, 1, 0.55, 1)
      love.graphics.print("LIVE", bx + 30, by + 6)
      love.graphics.setColor(0.55, 0.95, 1, 0.85)
      love.graphics.print("ON GAMES.BRASSEY.IO", bx + 60, by + 6)
      love.graphics.setFont(fonts.bold)
      love.graphics.setColor(0.85, 0.95, 1, 1)
      love.graphics.printf(string.format("%d operator%s online",
        activeGlobal, activeGlobal == 1 and "" or "s"), bx + 30, by + 22, bw - 36, "left")
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.55, 0.75, 0.95, 0.95)
      love.graphics.printf(string.format("you + %d in room  ·  %d /24h",
        activeRoom, last24h), bx + 8, by + 54, bw - 16, "center")
    else
      -- Subtle solo-mode tag in the same slot so layout never reflows.
      love.graphics.setColor(0.05, 0.08, 0.12, 0.85)
      love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
      love.graphics.setColor(0.45, 0.55, 0.65, 0.55)
      love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.55, 0.65, 0.75, 0.85)
      love.graphics.printf("SOLO MODE  ·  no portal mesh", bx + 8, by + 30, bw - 16, "center")
    end
  end

  -- View-toggle icon buttons — clickable and keyboard-accessible.
  -- Two pills side by side: WORLD (iso diamond glyph) and OPS (bar-chart
  -- glyph). Active scene gets a solid fill; inactive is outlined.
  -- Tab still toggles, but mouse users can click straight to either view.
  state._hudButtons = {}
  do
    local function drawWorldIcon(cx, cy, color)
      love.graphics.setColor(color[1], color[2], color[3], 1)
      love.graphics.setLineWidth(1.5)
      love.graphics.polygon("line",
        cx, cy - 6, cx + 9, cy, cx, cy + 6, cx - 9, cy)
      love.graphics.line(cx - 9, cy, cx + 9, cy)
      love.graphics.line(cx, cy - 6, cx, cy + 6)
      love.graphics.circle("fill", cx, cy, 1.5)
      love.graphics.setLineWidth(1)
    end
    local function drawOpsIcon(cx, cy, color)
      love.graphics.setColor(color[1], color[2], color[3], 1)
      love.graphics.rectangle("fill", cx - 8, cy + 2, 3, 4, 1, 1)
      love.graphics.rectangle("fill", cx - 3, cy - 2, 3, 8, 1, 1)
      love.graphics.rectangle("fill", cx + 2, cy - 6, 3, 12, 1, 1)
    end
    local function pill(px, py, label, isActive, drawIcon, sceneTarget)
      local pw, ph = 78, 36
      local pulse = 0.55 + math.sin(t * 2.0) * 0.20
      if isActive then
        love.graphics.setColor(0.10, 0.30, 0.18, 1)
        love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
        love.graphics.setColor(0.30, 1.00, 0.55, pulse)
        love.graphics.setLineWidth(2)
      else
        love.graphics.setColor(0.06, 0.13, 0.10, 0.92)
        love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
        love.graphics.setColor(0.30, 0.85, 0.55, 0.55)
        love.graphics.setLineWidth(1)
      end
      love.graphics.rectangle("line", px, py, pw, ph, 6, 6)
      love.graphics.setLineWidth(1)
      drawIcon(px + 16, py + ph / 2, isActive and { 0.55, 1, 0.75 } or { 0.45, 0.75, 0.55 })
      love.graphics.setFont(fonts.bold)
      love.graphics.setColor(isActive and 1 or 0.7, isActive and 1 or 0.8, isActive and 0.85 or 0.7, 1)
      love.graphics.print(label, px + 30, py + 8)
      table.insert(state._hudButtons, {
        x = px, y = py, w = pw, h = ph, kind = "scene", scene = sceneTarget,
      })
    end
    pill(360, 14, "WORLD", state.scene == "world", drawWorldIcon, "world")
    pill(444, 14, "OPS",   state.scene == "play",  drawOpsIcon,   "play")
    -- Shared TAB hint underneath both pills
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.45, 0.65, 0.55, 0.85)
    love.graphics.print("[ TAB ] toggle", 360, 56)
  end

  -- Global SURGE banner — bold full-width strip when active
  local surgeRem = state.network and Network.surgeRemaining(state.network) or 0
  if surgeRem > 0 then
    local sw = 540
    local sx = DESIGN_W / 2 - sw / 2
    local sy = HUD_H - 22
    local pulse = 0.7 + math.sin(t * 6) * 0.3
    love.graphics.setColor(0.30, 0.10, 0.04, 0.95)
    love.graphics.rectangle("fill", sx, sy, sw, 38, 6, 6)
    love.graphics.setColor(1, 0.55, 0.25, pulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx, sy, sw, 38, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.bold)
    local mult = state.network and Network.surgeMultiplier(state.network) or 0.5
    local txt = string.format("⚡  GLOBAL SURGE  +%d%%   %ds",
      math.floor(mult * 100), math.floor(surgeRem))
    local tw = fonts.bold:getWidth(txt)
    love.graphics.setColor(1, 0.85, 0.45, pulse)
    love.graphics.print(txt, sx + sw/2 - tw/2, sy + 8)
  end

  -- Pause indicator — centered above all HUD chrome so it never clips
  -- into the LIVE badge or any other widget.
  if state.paused then
    love.graphics.setFont(fonts.bold)
    local pulse = math.sin(t * 4) * 0.4 + 0.6
    local label = "[ PAUSED ]"
    local lw = fonts.bold:getWidth(label)
    local px = DESIGN_W / 2 - lw / 2 - 10
    local py = 0
    -- 28px tall so bold descenders aren't clipped
    love.graphics.setColor(0.20, 0.04, 0.02, 0.95)
    love.graphics.rectangle("fill", px, py, lw + 20, 28, 0, 0)
    love.graphics.setColor(1, 0.55, 0.30, pulse)
    love.graphics.print(label, px + 10, py + 3)
  end
end

function M.height() return HUD_H end

return M
