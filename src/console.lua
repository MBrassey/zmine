-- Live mining console — real stats with line charts, per-tier hash
-- breakdown, and an event log. Renders in the right-half of the
-- facility area so the core orb still leads the eye.

local fmt        = require "src.format"
local minersDb   = require "src.miners"
local energyDb   = require "src.energy"

local M = {}

local HIST_LEN = 240  -- 60s @ 0.25s sample
local SAMPLE_INTERVAL = 0.25

function M.newHistory()
  return {
    hashrate     = {},  -- circular buffer of length HIST_LEN
    zps          = {},
    energy_used  = {},
    energy_supp  = {},
    block_times  = {},  -- absolute time of recent block finds
    last_sample  = 0,
    head         = 1,   -- next write index
    filled       = 0,
  }
end

function M.sample(hist, state, t)
  if (t - (hist.last_sample or 0)) < SAMPLE_INTERVAL then return end
  hist.last_sample = t
  local i = hist.head
  hist.hashrate[i]    = state.hashrate or 0
  hist.zps[i]         = state.z_per_sec or 0
  hist.energy_used[i] = state.energy_used or 0
  hist.energy_supp[i] = state.energy_supply or 0
  hist.head = (i % HIST_LEN) + 1
  hist.filled = math.min(HIST_LEN, hist.filled + 1)
end

function M.notifyBlock(hist, t)
  table.insert(hist.block_times, t)
  while #hist.block_times > 32 do table.remove(hist.block_times, 1) end
end

local function bufferIter(hist, key)
  local n = hist.filled
  if n == 0 then return function() return nil end end
  local start
  if n < HIST_LEN then start = 1 else start = hist.head end
  local i = 0
  return function()
    if i >= n then return nil end
    local idx = ((start - 1 + i) % HIST_LEN) + 1
    local v = hist[key][idx]
    i = i + 1
    return i, v
  end
end

local function bufferMaxMin(hist, key)
  local mn, mx = math.huge, 0
  for _, v in bufferIter(hist, key) do
    if v then
      if v < mn then mn = v end
      if v > mx then mx = v end
    end
  end
  if mn == math.huge then mn = 0 end
  if mx <= mn then mx = mn + 1 end
  return mn, mx
end

local function drawChartFrame(x, y, w, h, label, fonts, accentColor)
  love.graphics.setColor(0.04, 0.07, 0.06, 0.92)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  love.graphics.setColor(accentColor[1] * 0.55, accentColor[2] * 0.55, accentColor[3] * 0.55, 0.85)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h, 4, 4)
  -- Grid lines
  love.graphics.setColor(accentColor[1] * 0.30, accentColor[2] * 0.30, accentColor[3] * 0.30, 0.30)
  for k = 1, 3 do
    local gy = y + (k / 4) * h
    love.graphics.line(x + 4, gy, x + w - 4, gy)
  end
  -- Label
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.95)
  love.graphics.print(label, x + 6, y + 4)
end

local function drawLineChart(hist, key, x, y, w, h, accentColor, formatter)
  local n = hist.filled
  if n < 2 then return end
  local mn, mx = bufferMaxMin(hist, key)
  -- Use 0 as the floor for production-style charts
  if mn > 0 then mn = 0 end
  local range = mx - mn
  if range < 0.001 then range = 1 end
  local marginT, marginB = 18, 6
  local plotH = h - marginT - marginB
  -- Plot polyline
  love.graphics.setLineWidth(1.5)
  local prevX, prevY
  for i, v in bufferIter(hist, key) do
    local px = x + ((i - 1) / (n - 1)) * (w - 8) + 4
    local py = y + marginT + plotH - ((v - mn) / range) * plotH
    if prevX then
      love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.95)
      love.graphics.line(prevX, prevY, px, py)
      -- Soft fill below line
      love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.18)
      love.graphics.line(prevX, prevY, prevX, y + marginT + plotH)
    end
    prevX, prevY = px, py
  end
  love.graphics.setLineWidth(1)
  -- Latest value pulse
  if prevX then
    love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.95)
    love.graphics.circle("fill", prevX, prevY, 3)
    love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.40)
    love.graphics.circle("fill", prevX, prevY, 6)
  end
  -- Current value at top-right
  local n2 = hist.filled
  local lastIdx = (hist.head - 2) % HIST_LEN + 1
  local cur = hist[key][lastIdx] or 0
  love.graphics.setFont(love.graphics.getFont())
  love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 1)
  local valStr = formatter and formatter(cur) or fmt.zeptons(cur)
  local fw = love.graphics.getFont():getWidth(valStr)
  love.graphics.print(valStr, x + w - fw - 6, y + 4)
end

local function drawEnergyChart(hist, x, y, w, h, fonts, supplyColor, demandColor)
  drawChartFrame(x, y, w, h, "ENERGY GRID", fonts, supplyColor)
  local n = hist.filled
  if n < 2 then return end
  local _, mx_s = bufferMaxMin(hist, "energy_supp")
  local _, mx_d = bufferMaxMin(hist, "energy_used")
  local mx = math.max(mx_s, mx_d, 1)
  local marginT, marginB = 18, 6
  local plotH = h - marginT - marginB

  local function plot(key, color, alpha)
    local prevX, prevY
    for i, v in bufferIter(hist, key) do
      local px = x + ((i - 1) / (n - 1)) * (w - 8) + 4
      local py = y + marginT + plotH - (v / mx) * plotH
      if prevX then
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.line(prevX, prevY, px, py)
      end
      prevX, prevY = px, py
    end
  end
  love.graphics.setLineWidth(1.5)
  plot("energy_supp", supplyColor, 0.85)
  plot("energy_used", demandColor, 0.95)
  love.graphics.setLineWidth(1)

  -- Legend
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(supplyColor[1], supplyColor[2], supplyColor[3], 1)
  love.graphics.print("SUPPLY", x + w - 110, y + 4)
  love.graphics.setColor(demandColor[1], demandColor[2], demandColor[3], 1)
  love.graphics.print("DEMAND", x + w - 60, y + 4)
end

local function drawTierBreakdown(state, x, y, w, h, fonts)
  -- Per-tier hash contribution bars
  drawChartFrame(x, y, w, h, "HASH BY TIER", fonts, { 0.85, 0.55, 1.00 })
  local entries = {}
  for _, def in ipairs(minersDb.list) do
    local count = state.miners[def.key] or 0
    if count > 0 then
      local mult = state.mods.miner_kind[def.key] or 1
      local contrib = count * def.produce * mult
      table.insert(entries, { name = def.short or def.name, count = count,
                              contrib = contrib, color = def.color })
    end
  end
  if #entries == 0 then
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.55, 0.45, 0.65, 0.85)
    love.graphics.print("no miners deployed yet", x + 8, y + h / 2 - 6)
    return
  end
  local total = 0
  for _, e in ipairs(entries) do total = total + e.contrib end
  if total <= 0 then return end
  -- Stacked horizontal bar chart
  local barH = 14
  local rowGap = 4
  local marginT = 22
  local rowsTotal = #entries
  local available = h - marginT - 4
  local rowH = math.min(barH + rowGap, available / rowsTotal)
  local barWmax = w - 76
  for i, e in ipairs(entries) do
    local ry = y + marginT + (i - 1) * rowH
    -- Label
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.85, 0.95, 0.92, 1)
    love.graphics.print(e.name, x + 6, ry + 1)
    -- Bar bg
    love.graphics.setColor(0.10, 0.10, 0.12, 1)
    love.graphics.rectangle("fill", x + 60, ry, barWmax, barH - 2, 2, 2)
    -- Bar fill
    local frac = e.contrib / total
    love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
    love.graphics.rectangle("fill", x + 60, ry, barWmax * frac, barH - 2, 2, 2)
    -- Pct
    love.graphics.setColor(0.95, 1, 0.92, 1)
    love.graphics.printf(string.format("%d%%", math.floor(frac * 100 + 0.5)),
      x + 60, ry, barWmax - 4, "right")
  end
end

local function drawBlockTimeline(hist, x, y, w, h, fonts, t)
  drawChartFrame(x, y, w, h, "BLOCK TIMELINE", fonts, { 1, 0.95, 0.55 })
  -- Show last 60 seconds; each block as a vertical pip
  local n = #hist.block_times
  if n == 0 then
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.85, 0.85, 0.55, 0.7)
    love.graphics.print("awaiting first block...", x + 8, y + h / 2 - 6)
    return
  end
  local marginT = 22
  local plotH = h - marginT - 6
  local startT = t - 120
  for _, bt in ipairs(hist.block_times) do
    if bt >= startT and bt <= t then
      local px = x + 4 + ((bt - startT) / 120) * (w - 8)
      love.graphics.setColor(1, 0.95, 0.55, 0.95)
      love.graphics.line(px, y + marginT, px, y + marginT + plotH)
      love.graphics.circle("fill", px, y + marginT, 2.5)
    end
  end
  -- "Now" marker
  love.graphics.setColor(1, 0.95, 0.55, 0.40)
  love.graphics.line(x + w - 4, y + marginT, x + w - 4, y + marginT + plotH)
  -- Average interval
  if n >= 2 then
    local recent = math.min(8, n)
    local avg = 0
    for i = n - recent + 1, n do
      avg = avg + (hist.block_times[i] - hist.block_times[i - 1] >= 0 and (hist.block_times[i] - hist.block_times[i - 1]) or 0)
    end
    avg = avg / (recent - 1)
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(1, 0.95, 0.55, 0.95)
    love.graphics.printf(string.format("avg %.0fs", avg), x, y + 4, w - 8, "right")
  end
end

-- ============================================================
-- Public draw
-- ============================================================

function M.draw(hist, state, fonts, t, x, y, w, h)
  -- Layout: 5 stacked panels in the right column of the facility area.
  local pad = 6
  local panelH = (h - pad * 4) / 5

  drawChartFrame(x, y + 0 * (panelH + pad), w, panelH, "HASH RATE", fonts,
    { 0.85, 0.95, 0.55 })
  drawLineChart(hist, "hashrate", x, y + 0 * (panelH + pad), w, panelH,
    { 1.00, 0.95, 0.65 }, function(v) return fmt.hashRate(v) end)

  drawChartFrame(x, y + 1 * (panelH + pad), w, panelH, "ZEPTONS / SEC", fonts,
    { 0.45, 1.00, 0.65 })
  drawLineChart(hist, "zps", x, y + 1 * (panelH + pad), w, panelH,
    { 0.55, 1.00, 0.75 }, function(v) return fmt.rate(v) end)

  drawEnergyChart(hist,
    x, y + 2 * (panelH + pad), w, panelH, fonts,
    { 0.45, 1.00, 0.55 }, { 1.00, 0.55, 0.30 })

  drawTierBreakdown(state, x, y + 3 * (panelH + pad), w, panelH, fonts)

  drawBlockTimeline(hist, x, y + 4 * (panelH + pad), w, panelH, fonts, t)
end

return M
