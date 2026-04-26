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

  -- Section: facility name (top-left). Truncated so it never bleeds
  -- into the TAB / OPS pills sitting at x=360.
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.40, 0.70, 0.55, 1)
  love.graphics.print("FACILITY", 30, 14)

  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.85, 1, 0.92, 1)
  local name = state.facility_name or "—"
  -- Shrink the name's drawn width to fit 300 px so the next section
  -- (the TAB / OPS pill pair starting at x=360) never overlaps.
  local nameW = fonts.large:getWidth(name)
  local availW = 300
  if nameW > availW then
    -- Truncate with an ellipsis that fits.
    while #name > 1 and fonts.large:getWidth(name .. "…") > availW do
      name = name:sub(1, -2)
    end
    name = name .. "…"
  end
  love.graphics.print(name, 30, 36)

  -- Section: BITCOIN balance — fixed x band 540..880, never bleeds.
  --   BITCOIN label  y=10
  --   ₿ coin         y=42 (centered)
  --   Balance        y=28 (boldXL)
  --   Rate "+X /s"   y=66 (tiny)
  local zx = 540
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(1.00, 0.65, 0.20, 1)
  love.graphics.print("BITCOIN", zx, 10)

  Coin.drawBTC(zx + 16, 50, 16, t)

  love.graphics.setFont(fonts.boldXL)
  local s = fmt.zeptons(state.z or 0)
  love.graphics.setColor(1, 0.75, 0.30, 0.25)
  love.graphics.print(s, zx + 38 + 1, 28 + 1)
  love.graphics.setColor(1, 0.85, 0.40, 1)
  love.graphics.print(s, zx + 38, 28)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(1, 0.80, 0.35, 0.95)
  -- fmt.rate already appends "/s"; using fmt.zeptons here to avoid
  -- the double-suffix the previous build was producing.
  love.graphics.print("+" .. fmt.zeptons(state.z_per_sec or 0) .. " /s",
                      zx + 38, 70)

  -- Section: ZEPTONS — fixed x band 890..1080, never collides with BTC.
  local zptX = 890
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.30, 1.00, 0.55, 1)
  love.graphics.print("ZEPTONS", zptX, 10)

  Coin.draw(zptX + 14, 50, 14, t)

  love.graphics.setFont(fonts.medium)
  local zptStr = fmt.zeptons(state.zeptons or 0)
  love.graphics.setColor(0.30, 1.00, 0.55, 0.30)
  love.graphics.print(zptStr, zptX + 34 + 1, 36 + 1)
  love.graphics.setColor(0.55, 1, 0.75, 1)
  love.graphics.print(zptStr, zptX + 34, 36)

  if (state.zeptons_per_sec or 0) > 0 then
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.45, 0.95, 0.65, 0.95)
    love.graphics.print(string.format("+%.2f /s", state.zeptons_per_sec),
                        zptX + 34, 70)
  end

  -- Section: energy
  local ex = 1100
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.95, 0.85, 0.45, 1)
  love.graphics.print("ENERGY  GRID", ex, 14)

  -- Side-by-side SUPPLY / DEMAND so the readout is unambiguous —
  -- "8.4k / 4.6k" was being read as "using 8.4k of 4.6k available"
  -- which is logically impossible. Now each number is labeled.
  local demand = state.energy_demand_raw or state.energy_used or 0
  local supply = state.energy_supply or 0
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.55, 0.85, 0.65, 0.95)
  love.graphics.print("SUPPLY", ex, 30)
  local demandColor = (demand > supply) and { 1, 0.55, 0.30, 0.95 } or { 0.65, 0.85, 0.55, 0.95 }
  love.graphics.setColor(demandColor)
  love.graphics.print("DEMAND", ex + 190, 30)
  love.graphics.setFont(fonts.medium)
  love.graphics.setColor(0.55, 1.00, 0.75, 1)
  love.graphics.print(fmt.energy(supply), ex, 44)
  love.graphics.setColor(demandColor[1], demandColor[2], demandColor[3], 1)
  love.graphics.print(fmt.energy(demand), ex + 190, 44)

  -- Bar — pct of demand vs supply, capped at 1.0 visually.
  local barW, barH = 380, 14
  local pct = (supply > 0) and (demand / supply) or 0
  local barColor = { 0.30, 1.00, 0.55 }
  if pct > 1.0 then
    barColor = { 1.00, 0.40, 0.40 }
  elseif pct > 0.85 then
    barColor = { 1.00, 0.75, 0.30 }
  end
  drawProgressBar(ex, 74, barW, barH, math.min(1, pct), barColor, nil)

  -- Brownout overlay: when demand exceeds supply we show the throttle %
  if state.energy_demand_raw and state.energy_supply and
     state.energy_demand_raw > state.energy_supply and state.energy_supply > 0 then
    local throttle = 1 - (state.energy_supply / state.energy_demand_raw)
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(1, 0.55, 0.30, 0.95)
    love.graphics.printf(
      string.format("THROTTLING %d%%", math.floor(throttle * 100)),
      ex, 74 + (barH - 12) / 2, barW, "center")
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

  -- View-toggle icon buttons — icon-only, square. WORLD (iso plot
  -- glyph) and OPS (line-chart glyph). Active scene gets a solid fill
  -- with bright border; inactive is outlined dimmer. Tab still
  -- toggles; mouse users can click either icon from either scene.
  state._hudButtons = {}
  do
    local function drawWorldIcon(cx, cy, color, intensity)
      -- Iso plot diamond + tiny rack pip on the south corner
      love.graphics.setColor(color[1], color[2], color[3], intensity)
      love.graphics.setLineWidth(2)
      love.graphics.polygon("line",
        cx, cy - 9, cx + 14, cy, cx, cy + 9, cx - 14, cy)
      -- Cross-axis grid
      love.graphics.setColor(color[1], color[2], color[3], intensity * 0.55)
      love.graphics.setLineWidth(1)
      love.graphics.line(cx - 7, cy - 4, cx + 7, cy + 4)
      love.graphics.line(cx + 7, cy - 4, cx - 7, cy + 4)
      -- Player pip in the middle
      love.graphics.setColor(color[1], color[2], color[3], intensity)
      love.graphics.circle("fill", cx, cy, 2)
      -- Two visitor pips on the north edge
      love.graphics.circle("fill", cx - 5, cy - 5, 1.2)
      love.graphics.circle("fill", cx + 5, cy - 5, 1.2)
    end
    local function drawOpsIcon(cx, cy, color, intensity)
      -- Line chart with rising slope + axes
      love.graphics.setColor(color[1], color[2], color[3], intensity * 0.6)
      love.graphics.setLineWidth(1.5)
      love.graphics.line(cx - 11, cy + 8, cx + 11, cy + 8)  -- x axis
      love.graphics.line(cx - 11, cy + 8, cx - 11, cy - 9)  -- y axis
      -- Plot line segments
      love.graphics.setColor(color[1], color[2], color[3], intensity)
      love.graphics.setLineWidth(2)
      local pts = {
        cx - 11, cy + 5,
        cx - 6,  cy + 2,
        cx - 1,  cy - 2,
        cx + 4,  cy - 5,
        cx + 9,  cy - 8,
      }
      for i = 1, #pts - 2, 2 do
        love.graphics.line(pts[i], pts[i+1], pts[i+2], pts[i+3])
      end
      -- Endpoint dot pulse
      love.graphics.setColor(color[1], color[2], color[3], intensity)
      love.graphics.circle("fill", cx + 9, cy - 8, 2)
    end
    local function pill(px, py, isActive, drawIcon, sceneTarget, tooltip)
      local pw, ph = 48, 40
      local pulse = 0.65 + math.sin(t * 2.0) * 0.25
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
      drawIcon(px + pw / 2, py + ph / 2,
        isActive and { 0.55, 1, 0.80 } or { 0.40, 0.75, 0.55 },
        isActive and 1.0 or 0.75)
      table.insert(state._hudButtons, {
        x = px, y = py, w = pw, h = ph, kind = "scene", scene = sceneTarget,
        tooltip = tooltip,
      })
    end
    pill(360, 14, state.scene == "world", drawWorldIcon, "world", "WORLD VIEW")
    pill(414, 14, state.scene == "play",  drawOpsIcon,   "play",  "OPS DASHBOARD")
    -- Inline label beneath both icons identifying the active view, plus
    -- the toggle hint
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.55, 0.95, 0.75, 0.95)
    local label = (state.scene == "world") and "WORLD VIEW" or "OPS DASHBOARD"
    love.graphics.print(label, 360, 56)
    love.graphics.setColor(0.45, 0.65, 0.55, 0.75)
    love.graphics.print("[SPACE] toggle", 360, 70)
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
