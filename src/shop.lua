local fmt = require "src.format"
local minersDb = require "src.miners"
local energyDb = require "src.energy"
local upgradesDb = require "src.upgrades"
local Monoliths = require "src.monoliths"
local MiraclesDb = require "src.miracles"
local Network = require "src.network"
local Coin = require "src.coin"

local M = {}

local DESIGN_W, DESIGN_H = 1920, 1080

local PANEL = { x = 1232, y = 116, w = 668, h = 900 }
local TAB_H = 56
local LIST_PAD = 12
local CARD_H = { miners = 168, energy = 168, upgrades = 124, zeptons = 110 }

local function inRect(mx, my, x, y, w, h)
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function M.new()
  local s = {
    tab = "miners",
    scroll = { miners = 0, energy = 0, upgrades = 0, network = 0, zeptons = 0 },
    hoverKey = nil,
  }
  return s
end

local function drawPanelBg()
  love.graphics.setColor(0.04, 0.07, 0.06, 1)
  love.graphics.rectangle("fill", PANEL.x, PANEL.y, PANEL.w, PANEL.h, 8, 8)
  love.graphics.setColor(0.18, 0.55, 0.32, 0.8)
  love.graphics.rectangle("line", PANEL.x, PANEL.y, PANEL.w, PANEL.h, 8, 8)
end

local function drawTabs(shop, fonts)
  local tabs = {
    { id = "miners",   label = "MINERS"   },
    { id = "energy",   label = "ENERGY"   },
    { id = "zeptons",  label = "ZEPTONS"  },
    { id = "upgrades", label = "RESEARCH" },
    { id = "network",  label = "NETWORK"  },
  }
  shop._tabRects = {}
  local tabW = (PANEL.w - 24) / #tabs
  for i, t in ipairs(tabs) do
    local x = PANEL.x + 12 + (i - 1) * tabW
    local y = PANEL.y + 12
    local active = (shop.tab == t.id)
    if active then
      love.graphics.setColor(0.10, 0.30, 0.18, 1)
    else
      love.graphics.setColor(0.06, 0.12, 0.08, 1)
    end
    love.graphics.rectangle("fill", x, y, tabW - 8, TAB_H, 6, 6)
    if active then
      love.graphics.setColor(0.30, 1, 0.55, 1)
      love.graphics.setLineWidth(2)
    else
      love.graphics.setColor(0.20, 0.55, 0.32, 0.6)
      love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", x, y, tabW - 8, TAB_H, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(active and fonts.bold or fonts.medium)
    love.graphics.setColor(active and 1 or 0.6, active and 1 or 0.8, active and 0.85 or 0.7, 1)
    local lw = (active and fonts.bold or fonts.medium):getWidth(t.label)
    love.graphics.print(t.label, x + (tabW - 8) / 2 - lw / 2, y + 16)
    -- Hint hotkey
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.4, 0.65, 0.5, active and 0.9 or 0.5)
    love.graphics.print(string.format("[%d]", i), x + 8, y + 8)
    shop._tabRects[i] = { id = t.id, x = x, y = y, w = tabW - 8, h = TAB_H }
  end
end

local function listAreaY()
  return PANEL.y + 12 + TAB_H + 12
end

local function listAreaH()
  return PANEL.h - (12 + TAB_H + 12) - 12
end

local function scissorList()
  local lay = listAreaY()
  local lah = listAreaH()
  -- Scissor is canvas-relative when a canvas is bound, so design coords go in directly.
  love.graphics.setScissor(
    PANEL.x + 8,
    lay,
    PANEL.w - 16,
    lah
  )
end

local function purchaseQty(shift, ctrl)
  if ctrl then return "max" end
  if shift then return 10 end
  return 1
end

local function drawMinerCard(shop, def, x, y, w, h, state, fonts, t, mx, my)
  local owned = state.miners[def.key] or 0
  local unitCost = minersDb.unitCost(def, owned)
  local affordable = state.z >= unitCost

  -- Hover
  local hover = inRect(mx, my, x, y, w, h)
  if hover then shop.hoverKey = def.key end

  -- Card bg
  if hover then
    love.graphics.setColor(0.07, 0.15, 0.10, 1)
  else
    love.graphics.setColor(0.05, 0.10, 0.07, 1)
  end
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(def.color[1] * 0.7, def.color[2] * 0.7, def.color[3] * 0.7, hover and 0.9 or 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(1)

  -- Icon block
  local iconW = 92
  love.graphics.setColor(def.color[1] * 0.20, def.color[2] * 0.20, def.color[3] * 0.20, 1)
  love.graphics.rectangle("fill", x + 8, y + 8, iconW, h - 16, 4, 4)

  -- Stylized icon: hex or grid based on tier
  love.graphics.push()
  love.graphics.translate(x + 8 + iconW / 2, y + 8 + (h - 16) / 2)
  local pulse = 0.85 + math.sin(t * 1.5 + def.tier) * 0.15
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], pulse)
  love.graphics.setLineWidth(2)
  -- Concentric hex rings
  for r = 1, math.min(def.tier, 4) do
    local rad = 12 + r * 8
    local pts = {}
    for k = 0, 5 do
      local a = k * math.pi / 3 + t * 0.2 * (r % 2 == 0 and 1 or -1)
      pts[#pts + 1] = math.cos(a) * rad
      pts[#pts + 1] = math.sin(a) * rad
    end
    love.graphics.polygon("line", pts)
  end
  -- Inner dot
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 1)
  love.graphics.circle("fill", 0, 0, 5)
  love.graphics.pop()
  love.graphics.setLineWidth(1)

  -- Tier badge
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.95)
  love.graphics.print(string.format("T%d", def.tier), x + 14, y + 14)

  -- Right column text
  local tx = x + 8 + iconW + 14

  love.graphics.setFont(fonts.bold)
  love.graphics.setColor(0.9, 1, 0.92, 1)
  love.graphics.print(def.name, tx, y + 10)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.55, 0.80, 0.65, 1)
  love.graphics.print(string.format("OWNED  %d", owned), tx, y + 38)

  -- Real-world spec lines
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.40, 0.85, 0.95, 0.95)
  love.graphics.print("ALGO  " .. (def.algo or "—"), tx, y + 58)
  love.graphics.setColor(0.40, 0.85, 0.95, 0.85)
  love.graphics.print("HASH  " .. (def.hashrate or "—"), tx, y + 76)
  love.graphics.setColor(0.95, 0.80, 0.45, 0.85)
  love.graphics.print("EFF   " .. (def.efficiency or "—"), tx, y + 94)

  -- In-game rate / consumption
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.55, 1, 0.75, 1)
  love.graphics.print("◐ " .. fmt.rate(def.produce * (state.mods.miner_kind[def.key] or 1)), tx, y + 116)
  love.graphics.setColor(1, 0.85, 0.45, 1)
  love.graphics.print("⚡ " .. fmt.energy(def.energy * (1 - state.mods.energy_eff)) .. "/u", tx + 200, y + 116)

  local btnW, btnH = 140, 56
  local bx = x + w - btnW - 12
  local by = y + h - btnH - 12

  if hover and inRect(mx, my, bx, by, btnW, btnH) then
    love.graphics.setColor(affordable and 0.18 or 0.10, affordable and 0.45 or 0.15, affordable and 0.30 or 0.12, 1)
  else
    love.graphics.setColor(affordable and 0.10 or 0.05, affordable and 0.25 or 0.10, affordable and 0.18 or 0.08, 1)
  end
  love.graphics.rectangle("fill", bx, by, btnW, btnH, 5, 5)
  love.graphics.setColor(affordable and 0.4 or 0.25, affordable and 1 or 0.5, affordable and 0.65 or 0.35, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, btnW, btnH, 5, 5)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.5, 0.85, 0.65, 1)
  love.graphics.print("BUY", bx + 10, by + 6)

  -- Cost with Z-coin
  love.graphics.setFont(fonts.bold)
  local costStr = fmt.zeptons(unitCost)
  local cw = fonts.bold:getWidth(costStr)
  local coinSize = 9
  local total = coinSize * 2 + 6 + cw
  local startCX = bx + btnW - 10 - total
  local color = affordable and { 0.55, 1, 0.75 } or { 0.55, 0.55, 0.55 }
  Coin.drawWithLabel(startCX, by + 36, coinSize, t, costStr, fonts.bold, color)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.45, 0.65, 0.55, 0.8)
  love.graphics.print("[shift]×10  [ctrl]MAX", x + 8 + iconW + 14, y + h - 22)

  return { kind = "buy_miner", def = def, x = bx, y = by, w = btnW, h = btnH }
end

local function drawEnergyCard(shop, def, x, y, w, h, state, fonts, t, mx, my)
  local owned = state.energy[def.key] or 0
  local unitCost = energyDb.unitCost(def, owned)
  local affordable = state.z >= unitCost

  local hover = inRect(mx, my, x, y, w, h)
  if hover then shop.hoverKey = def.key end

  if hover then
    love.graphics.setColor(0.10, 0.10, 0.05, 1)
  else
    love.graphics.setColor(0.07, 0.08, 0.04, 1)
  end
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(def.color[1] * 0.7, def.color[2] * 0.7, def.color[3] * 0.7, hover and 0.9 or 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(1)

  -- Icon block
  local iconW = 92
  love.graphics.setColor(def.color[1] * 0.20, def.color[2] * 0.20, def.color[3] * 0.20, 1)
  love.graphics.rectangle("fill", x + 8, y + 8, iconW, h - 16, 4, 4)

  -- Stylized icon: rotating bolts
  love.graphics.push()
  love.graphics.translate(x + 8 + iconW / 2, y + 8 + (h - 16) / 2)
  love.graphics.rotate(t * 0.5 * (def.tier % 2 == 0 and 1 or -1))
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.95)
  love.graphics.setLineWidth(2)
  for k = 0, math.min(def.tier + 1, 5) do
    local a = k * math.pi * 2 / math.max(3, def.tier + 1)
    local r = 18 + (k % 2) * 8
    love.graphics.line(0, 0, math.cos(a) * r, math.sin(a) * r)
    love.graphics.circle("fill", math.cos(a) * r, math.sin(a) * r, 3.5)
  end
  love.graphics.circle("fill", 0, 0, 5)
  love.graphics.pop()
  love.graphics.setLineWidth(1)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.95)
  love.graphics.print(string.format("T%d", def.tier), x + 14, y + 14)

  local tx = x + 8 + iconW + 14
  love.graphics.setFont(fonts.bold)
  love.graphics.setColor(1, 0.95, 0.85, 1)
  love.graphics.print(def.name, tx, y + 10)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.85, 0.75, 0.50, 1)
  love.graphics.print(string.format("OWNED  %d", owned), tx, y + 38)

  -- Real-world spec lines
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.55, 0.95, 0.85, 0.95)
  love.graphics.print("TECH  " .. (def.tech or "—"), tx, y + 58)
  love.graphics.setColor(0.55, 0.95, 0.85, 0.85)
  love.graphics.print("SPEC  " .. (def.spec or "—"), tx, y + 76)
  love.graphics.setColor(0.95, 0.85, 0.40, 0.85)
  love.graphics.print((def.cf or "—") .. (def.note and ("  ·  " .. def.note) or ""), tx, y + 94)

  -- In-game output
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(1, 0.85, 0.45, 1)
  local mult = state.mods.energy_kind[def.key] or 1
  local effective = def.produce * mult * (state._dynamicFactor and state._dynamicFactor[def.key] or 1)
  love.graphics.print("⚡ " .. fmt.energy(effective) .. " /u", tx, y + 116)

  local btnW, btnH = 140, 56
  local bx = x + w - btnW - 12
  local by = y + h - btnH - 12

  if hover and inRect(mx, my, bx, by, btnW, btnH) then
    love.graphics.setColor(affordable and 0.45 or 0.10, affordable and 0.32 or 0.10, affordable and 0.10 or 0.05, 1)
  else
    love.graphics.setColor(affordable and 0.30 or 0.08, affordable and 0.20 or 0.06, affordable and 0.05 or 0.04, 1)
  end
  love.graphics.rectangle("fill", bx, by, btnW, btnH, 5, 5)
  love.graphics.setColor(affordable and 1 or 0.4, affordable and 0.85 or 0.35, affordable and 0.40 or 0.20, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, btnW, btnH, 5, 5)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(1, 0.80, 0.45, 1)
  love.graphics.print("BUILD", bx + 10, by + 6)

  -- Cost with Z-coin
  love.graphics.setFont(fonts.bold)
  local costStr = fmt.zeptons(unitCost)
  local cw = fonts.bold:getWidth(costStr)
  local coinSize = 9
  local total = coinSize * 2 + 6 + cw
  local startCX = bx + btnW - 10 - total
  local color = affordable and { 1, 0.95, 0.55 } or { 0.55, 0.50, 0.40 }
  Coin.drawWithLabel(startCX, by + 36, coinSize, t, costStr, fonts.bold, color,
    { color = { 1, 0.85, 0.45 } })

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.65, 0.55, 0.35, 0.8)
  love.graphics.print("[shift]×10  [ctrl]MAX", x + 8 + iconW + 14, y + h - 22)

  return { kind = "buy_energy", def = def, x = bx, y = by, w = btnW, h = btnH }
end

local function drawUpgradeCard(shop, def, x, y, w, h, state, fonts, t, mx, my)
  local owned = state.upgrades[def.key]
  local can, status = upgradesDb.canPurchase(def, state.upgrades)
  local affordable = state.z >= def.cost
  local locked = (status == "locked")

  local hover = inRect(mx, my, x, y, w, h) and not owned and not locked
  if hover then shop.hoverKey = def.key end

  if owned then
    love.graphics.setColor(0.05, 0.10, 0.20, 1)
  elseif locked then
    love.graphics.setColor(0.05, 0.05, 0.06, 1)
  elseif hover then
    love.graphics.setColor(0.08, 0.08, 0.15, 1)
  else
    love.graphics.setColor(0.05, 0.06, 0.10, 1)
  end
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)

  if owned then
    love.graphics.setColor(0.55, 0.75, 1.00, 0.95)
    love.graphics.setLineWidth(2)
  elseif locked then
    love.graphics.setColor(0.20, 0.20, 0.25, 0.7)
    love.graphics.setLineWidth(1)
  else
    love.graphics.setColor(0.35, 0.55, 1, hover and 0.95 or 0.55)
    love.graphics.setLineWidth(2)
  end
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(1)

  -- Icon (gear/atom)
  local iconW = 80
  love.graphics.setColor(0.08, 0.10, 0.20, 1)
  love.graphics.rectangle("fill", x + 8, y + 8, iconW, h - 16, 4, 4)

  love.graphics.push()
  love.graphics.translate(x + 8 + iconW / 2, y + 8 + (h - 16) / 2)
  if owned then
    love.graphics.setColor(0.5, 0.8, 1, 1)
  elseif locked then
    love.graphics.setColor(0.3, 0.3, 0.35, 0.7)
  else
    love.graphics.setColor(0.45, 0.7, 1, 0.95)
  end
  love.graphics.setLineWidth(2)
  love.graphics.rotate(t * 0.4)
  for k = 0, 7 do
    local a = k * math.pi / 4
    love.graphics.line(math.cos(a) * 12, math.sin(a) * 12, math.cos(a) * 22, math.sin(a) * 22)
  end
  love.graphics.circle("line", 0, 0, 12)
  love.graphics.circle("line", 0, 0, 24)
  love.graphics.pop()
  love.graphics.setLineWidth(1)

  local tx = x + 8 + iconW + 14
  love.graphics.setFont(fonts.bold)
  if owned then
    love.graphics.setColor(0.65, 0.85, 1, 1)
  elseif locked then
    love.graphics.setColor(0.3, 0.4, 0.5, 1)
  else
    love.graphics.setColor(0.85, 0.95, 1, 1)
  end
  love.graphics.print(def.name, tx, y + 10)

  love.graphics.setFont(fonts.tiny)
  if locked then
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
  else
    love.graphics.setColor(0.55, 0.70, 0.95, 0.95)
  end
  love.graphics.printf(def.desc, tx, y + 38, w - iconW - 180, "left")

  -- Right side: cost or owned tag
  local btnW, btnH = 130, 52
  local bx = x + w - btnW - 12
  local by = y + h - btnH - 12

  if owned then
    love.graphics.setColor(0.20, 0.40, 0.65, 1)
    love.graphics.rectangle("fill", bx, by, btnW, btnH, 5, 5)
    love.graphics.setColor(0.55, 0.85, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, btnW, btnH, 5, 5)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.bold)
    local label = "INSTALLED"
    local lw = fonts.bold:getWidth(label)
    love.graphics.setColor(0.7, 0.9, 1, 1)
    love.graphics.print(label, bx + (btnW - lw) / 2, by + 16)
    return nil
  end

  if locked then
    love.graphics.setColor(0.10, 0.10, 0.12, 1)
    love.graphics.rectangle("fill", bx, by, btnW, btnH, 5, 5)
    love.graphics.setColor(0.30, 0.30, 0.35, 0.7)
    love.graphics.rectangle("line", bx, by, btnW, btnH, 5, 5)
    love.graphics.setFont(fonts.bold)
    local label = "LOCKED"
    local lw = fonts.bold:getWidth(label)
    love.graphics.setColor(0.40, 0.45, 0.55, 0.95)
    love.graphics.print(label, bx + (btnW - lw) / 2, by + 6)
    -- Show requirement
    if def.requires then
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.4, 0.45, 0.55, 0.9)
      love.graphics.printf("REQ: " .. def.requires[1], bx + 8, by + 32, btnW - 16, "center")
    end
    return nil
  end

  -- Available, possibly affordable
  if hover then
    love.graphics.setColor(affordable and 0.18 or 0.08, affordable and 0.30 or 0.12, affordable and 0.55 or 0.22, 1)
  else
    love.graphics.setColor(affordable and 0.10 or 0.06, affordable and 0.20 or 0.08, affordable and 0.40 or 0.15, 1)
  end
  love.graphics.rectangle("fill", bx, by, btnW, btnH, 5, 5)
  love.graphics.setColor(affordable and 0.6 or 0.4, affordable and 0.85 or 0.5, 1, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, btnW, btnH, 5, 5)
  love.graphics.setLineWidth(1)
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.45, 0.65, 0.95, 1)
  love.graphics.print("UNLOCK", bx + 10, by + 6)

  love.graphics.setFont(fonts.bold)
  local costStr = fmt.zeptons(def.cost)
  local cw = fonts.bold:getWidth(costStr)
  local coinSize = 9
  local total = coinSize * 2 + 6 + cw
  local startCX = bx + btnW - 10 - total
  local color = affordable and { 0.65, 0.85, 1 } or { 0.45, 0.50, 0.65 }
  Coin.drawWithLabel(startCX, by + 36, coinSize, t, costStr, fonts.bold, color,
    { color = { 0.45, 0.70, 1.00 } })

  return { kind = "buy_upgrade", def = def, x = bx, y = by, w = btnW, h = btnH }
end

local function drawAvatar(av, x, y, r)
  -- Hex avatar with letter glyph
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.setColor(av.color[1] * 0.20, av.color[2] * 0.20, av.color[3] * 0.20, 1)
  local pts = {}
  for k = 0, 5 do
    local a = k * math.pi / 3 + math.pi / 6
    pts[#pts + 1] = math.cos(a) * r
    pts[#pts + 1] = math.sin(a) * r
  end
  love.graphics.polygon("fill", pts)
  love.graphics.setColor(av.color[1], av.color[2], av.color[3], 1)
  love.graphics.setLineWidth(2)
  love.graphics.polygon("line", pts)
  love.graphics.setLineWidth(1)
  -- Glyph ring
  for k = 0, 2 do
    local rr = r * (0.55 - k * 0.13)
    love.graphics.setColor(av.color[1], av.color[2], av.color[3], 0.5 - k * 0.12)
    love.graphics.circle("line", 0, 0, rr)
  end
  love.graphics.pop()
end

local function statusColor(status)
  if status == "online" then return { 0.30, 1, 0.55 } end
  if status == "afk"    then return { 1, 0.85, 0.30 } end
  return { 0.55, 0.55, 0.65 }
end

local function statusText(status)
  if status == "online" then return "ONLINE" end
  if status == "afk"    then return "AFK" end
  return "OFFLINE"
end

local function drawNetworkPanel(shop, state, fonts, t, mx, my)
  local network = state.network
  if not network then return end
  shop._buttons = shop._buttons or {}

  local lay = listAreaY()
  local lah = listAreaH()
  local cardW = PANEL.w - 24
  local startX = PANEL.x + 12

  -- Header summary (fixed, above scrollable list)
  local headerH = 84
  love.graphics.setColor(0.05, 0.10, 0.07, 1)
  love.graphics.rectangle("fill", startX, lay, cardW, headerH, 6, 6)
  love.graphics.setColor(0.30, 0.85, 0.55, 0.5)
  love.graphics.rectangle("line", startX, lay, cardW, headerH, 6, 6)

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.55, 0.85, 0.70, 0.95)
  love.graphics.print("MESH STATUS  ·  " .. (Network.statusText(network) or "—"), startX + 14, lay + 8)

  love.graphics.setFont(fonts.medium)
  love.graphics.setColor(0.95, 1, 0.92, 1)
  local snaps = network._snapshots or {}
  local online = 0
  for _, s in ipairs(snaps) do if s.status == "online" then online = online + 1 end end
  love.graphics.print(
    string.format("FACILITIES  %d  ::  ONLINE %d", #snaps, online),
    startX + 14, lay + 28)

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.85, 0.95, 0.55, 0.95)
  love.graphics.print(string.format("⚙ network hash rate  %s",
    fmt.hashRate(network.totalHashRate or 0)),
    startX + 14, lay + 56)

  -- Global breakdown (slug-wide stats)
  local activeGlobal = Network.globalActiveUsers(network)
  if activeGlobal > 0 then
    local last24 = Network.globalLast24h(network)
    local allT   = Network.globalAllTimeUsers(network)
    local rooms  = Network.globalTotalRooms(network)
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.55, 0.85, 1, 0.95)
    love.graphics.printf(
      string.format("GLOBAL %d active  ·  %d rooms  ·  %d /24h  ·  %d all-time",
        activeGlobal, rooms, last24, allT),
      startX, lay + 56, cardW - 14, "right")
  end

  -- Pool indicator (lookup partner via realPeers / snapshots — the
  -- old `network.players` field was nil after the sim-ghost removal).
  if network.pool_with then
    love.graphics.setColor(0.55, 0.85, 0.95, 0.95)
    local poolName = "?"
    local rp = network.realPeers and network.realPeers[network.pool_with]
    if rp then poolName = rp.facility_name or rp.handle or "?" end
    if poolName == "?" then
      for _, sn in ipairs(network._snapshots or {}) do
        if sn.id == network.pool_with then poolName = sn.name; break end
      end
    end
    love.graphics.printf("⛓ POOLED w/ " .. poolName, startX, lay + 56, cardW - 14, "right")
  end

  -- Sort snaps so live operators surface first; offline-known peers
  -- stay accessible without burying the live ones.
  local function statusRank(s)
    if s.status == "online"  then return 0 end
    if s.status == "afk"     then return 1 end
    if s.status == "offline" then return 2 end
    return 3
  end
  table.sort(snaps, function(a, b)
    local ra, rb = statusRank(a), statusRank(b)
    if ra ~= rb then return ra < rb end
    return (a.z_lifetime or 0) > (b.z_lifetime or 0)
  end)

  local sections = {}
  local lastRank
  for i, s in ipairs(snaps) do
    local r = statusRank(s)
    if r ~= lastRank then
      local label
      if r == 0 then label = "ONLINE"
      elseif r == 1 then label = "AFK"
      else label = "OFFLINE — KNOWN" end
      sections[#sections + 1] = { i = i, label = label }
      lastRank = r
    end
  end

  -- Player list
  local listY = lay + headerH + 10
  local listH = lah - headerH - 10 - 220 -- leave 220 for ticker
  local rowH = 86
  local subH = 22
  local total = #snaps * (rowH + 8) + #sections * subH
  local maxScroll = math.max(0, total - listH)
  shop.scroll[shop.tab] = shop.scroll[shop.tab] or 0
  if shop.scroll[shop.tab] > maxScroll then shop.scroll[shop.tab] = maxScroll end
  if shop.scroll[shop.tab] < 0 then shop.scroll[shop.tab] = 0 end
  local scroll = shop.scroll[shop.tab]

  -- Scissor list (canvas-relative, design coords)
  love.graphics.setScissor(startX, listY, cardW, listH)

  -- Inbound pool request banner — sits above the list with ACCEPT and
  -- DECLINE buttons. The receiver decides; pool only forms on accept.
  if network.pool_pending_incoming then
    local req = network.pool_pending_incoming
    local bx, by, bw, bh = startX, listY, cardW, 70
    love.graphics.setColor(0.06, 0.18, 0.10, 0.95)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    love.graphics.setColor(0.55, 0.95, 1.0, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.85, 1, 0.92, 1)
    love.graphics.print("⛓  POOL REQUEST  —  " .. (req.from_name or "operator"),
      bx + 16, by + 10)
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.55, 0.85, 0.95, 0.95)
    love.graphics.print("Accepting costs 1% of your Z balance",
      bx + 16, by + 36)
    -- ACCEPT
    local axw, axh = 110, 32
    local axx = bx + bw - (axw * 2 + 16)
    local axy = by + (bh - axh) / 2
    local hovA = inRect(mx, my, axx, axy, axw, axh)
    love.graphics.setColor(hovA and 0.18 or 0.10, hovA and 0.45 or 0.30, hovA and 0.32 or 0.18, 1)
    love.graphics.rectangle("fill", axx, axy, axw, axh, 4, 4)
    love.graphics.setColor(0.55, 1, 0.75, hovA and 1 or 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", axx, axy, axw, axh, 4, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.95, 1, 0.92, 1)
    love.graphics.printf("ACCEPT", axx, axy + 7, axw, "center")
    table.insert(shop._buttons, { kind = "accept_pool", target_id = req.from_id,
                                  x = axx, y = axy, w = axw, h = axh })
    -- DECLINE
    local dxx = axx + axw + 8
    local hovD = inRect(mx, my, dxx, axy, axw, axh)
    love.graphics.setColor(hovD and 0.45 or 0.30, hovD and 0.20 or 0.10, hovD and 0.20 or 0.10, 1)
    love.graphics.rectangle("fill", dxx, axy, axw, axh, 4, 4)
    love.graphics.setColor(1, 0.55, 0.55, hovD and 1 or 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", dxx, axy, axw, axh, 4, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.95, 1, 0.92, 1)
    love.graphics.printf("DECLINE", dxx, axy + 7, axw, "center")
    table.insert(shop._buttons, { kind = "decline_pool", target_id = req.from_id,
                                  x = dxx, y = axy, w = axw, h = axh })
    -- Compress the player-list height so the banner doesn't overlap.
    listY = listY + bh + 8
    listH = listH - bh - 8
  end

  -- Solo operator: empty list. Show a friendly hint instead of a void.
  if #snaps == 0 then
    love.graphics.setColor(0.04, 0.07, 0.06, 0.95)
    love.graphics.rectangle("fill", startX, listY + 60, cardW, 180, 8, 8)
    love.graphics.setColor(0.30, 0.85, 0.55, 0.5)
    love.graphics.rectangle("line", startX, listY + 60, cardW, 180, 8, 8)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(0.55, 1, 0.75, 1)
    love.graphics.printf("YOU ARE THE ONLY OPERATOR HERE", startX, listY + 84, cardW, "center")
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.85, 0.95, 0.92, 1)
    love.graphics.printf("Mine alone, or invite a friend to join the A-TEK Mesh.",
      startX + 20, listY + 124, cardW - 40, "center")
    love.graphics.setColor(0.55, 0.85, 0.65, 0.85)
    love.graphics.printf("When other operators connect, they'll appear here in real time:",
      startX + 20, listY + 154, cardW - 40, "center")
    love.graphics.printf("you'll see their facility, hash rate, and live mining events.",
      startX + 20, listY + 174, cardW - 40, "center")
  end

  -- Walk snaps with subhead injections
  local rowOffset = 0
  local sectionIdx = 1
  for i, snap in ipairs(snaps) do
    -- Render subhead between sections
    if sections[sectionIdx] and sections[sectionIdx].i == i then
      local headY = listY + rowOffset - scroll
      love.graphics.setColor(0.06, 0.13, 0.10, 1)
      love.graphics.rectangle("fill", startX, headY, cardW, subH, 4, 4)
      love.graphics.setColor(0.30, 0.85, 0.55, 0.50)
      love.graphics.rectangle("line", startX, headY, cardW, subH, 4, 4)
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.55, 0.95, 0.75, 1)
      love.graphics.print(sections[sectionIdx].label, startX + 10, headY + 5)
      rowOffset = rowOffset + subH + 4
      sectionIdx = sectionIdx + 1
    end
    local rowY = listY + rowOffset - scroll
    rowOffset = rowOffset + rowH + 8
    if rowY + rowH > listY - rowH and rowY < listY + listH + rowH then
      -- Background — desaturate placeholder/demo rows
      local bgA = snap.placeholder and 0.55 or 1.0
      love.graphics.setColor(0.04, 0.07, 0.06, bgA)
      love.graphics.rectangle("fill", startX, rowY, cardW, rowH, 5, 5)
      local r, g, b = snap.avatar.color[1] * 0.6, snap.avatar.color[2] * 0.6, snap.avatar.color[3] * 0.6
      if snap.placeholder then r, g, b = r * 0.7, g * 0.7, b * 0.7 end
      love.graphics.setColor(r, g, b, snap.placeholder and 0.30 or 0.55)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", startX, rowY, cardW, rowH, 5, 5)

      -- Avatar
      drawAvatar(snap.avatar, startX + 40, rowY + rowH / 2, 30)

      -- Name + stats
      local nx = startX + 86
      love.graphics.setFont(fonts.bold)
      love.graphics.setColor(0.95, 1, 0.92, 1)
      love.graphics.print(snap.name, nx, rowY + 8)

      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.65, 0.85, 0.75, 0.95)
      love.graphics.print(
        string.format("⚡ %s   ◐ %s", fmt.rate(snap.z_per_sec), fmt.hashRate(snap.hashrate)),
        nx, rowY + 36)
      love.graphics.setColor(0.55, 0.75, 0.65, 0.85)
      love.graphics.print(
        string.format("Z lifetime  %s", fmt.zeptons(snap.z_lifetime)),
        nx, rowY + 54)

      -- Status badge
      local sc_col = statusColor(snap.status)
      local badgeW = 64
      local badgeX = startX + cardW - 220 - badgeW
      love.graphics.setColor(sc_col[1] * 0.25, sc_col[2] * 0.25, sc_col[3] * 0.25, 1)
      love.graphics.rectangle("fill", badgeX, rowY + 12, badgeW, 22, 3, 3)
      love.graphics.setColor(sc_col[1], sc_col[2], sc_col[3], 1)
      love.graphics.rectangle("line", badgeX, rowY + 12, badgeW, 22, 3, 3)
      love.graphics.setFont(fonts.tiny)
      love.graphics.printf(statusText(snap.status), badgeX, rowY + 16, badgeW, "center")

      -- Buttons: Boost + Pool/Leave
      local btnW, btnH = 92, 30
      local b1x = startX + cardW - btnW * 2 - 18
      local by1 = rowY + 12
      local by2 = rowY + 46

      -- Boost — show the cost on the button so the player knows what it does.
      local boostCost = math.max(25, (state.z or 0) * 0.05)
      local boostStr = "−" .. fmt.zeptons(boostCost)
      local hover1 = inRect(mx, my, b1x, by1, btnW, btnH)
      love.graphics.setColor(hover1 and 0.18 or 0.10, hover1 and 0.30 or 0.18, hover1 and 0.55 or 0.36, 1)
      love.graphics.rectangle("fill", b1x, by1, btnW, btnH, 4, 4)
      love.graphics.setColor(0.55, 0.85, 1, hover1 and 1 or 0.7)
      love.graphics.rectangle("line", b1x, by1, btnW, btnH, 4, 4)
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.85, 0.95, 1, 1)
      love.graphics.printf("BOOST " .. boostStr, b1x, by1 + 8, btnW, "center")
      table.insert(shop._buttons, { kind = "boost", target_id = snap.id, x = b1x, y = by1, w = btnW, h = btnH })

      -- Pool / Pending / Leave — three-state button.
      local poolB_x = b1x + btnW + 4
      local hover2 = inRect(mx, my, poolB_x, by1, btnW, btnH)
      local pooled = (network.pool_with == snap.id)
      local pending = (network.pool_pending_outgoing
                       and network.pool_pending_outgoing.target_id == snap.id)
      local label, fillR, fillG, fillB, lineR, lineG, lineB
      local btnKind
      if pooled then
        label = "LEAVE"
        fillR, fillG, fillB = (hover2 and 0.55 or 0.35), (hover2 and 0.20 or 0.10), (hover2 and 0.20 or 0.10)
        lineR, lineG, lineB = 1, 0.55, 0.55
        btnKind = "leave_pool"
      elseif pending then
        label = "PENDING"
        fillR, fillG, fillB = 0.20, 0.18, 0.10
        lineR, lineG, lineB = 0.85, 0.75, 0.30
        btnKind = nil  -- not clickable
      else
        label = "POOL"
        fillR, fillG, fillB = (hover2 and 0.18 or 0.10), (hover2 and 0.45 or 0.30), (hover2 and 0.32 or 0.18)
        lineR, lineG, lineB = 0.55, 0.95, 0.65
        btnKind = "pool"
      end
      love.graphics.setColor(fillR, fillG, fillB, 1)
      love.graphics.rectangle("fill", poolB_x, by1, btnW, btnH, 4, 4)
      love.graphics.setColor(lineR, lineG, lineB, hover2 and 1 or 0.7)
      love.graphics.rectangle("line", poolB_x, by1, btnW, btnH, 4, 4)
      love.graphics.setColor(0.85, 0.95, 0.85, 1)
      love.graphics.printf(label, poolB_x, by1 + 8, btnW, "center")
      if btnKind then
        table.insert(shop._buttons, { kind = btnKind, target_id = snap.id,
                                       x = poolB_x, y = by1, w = btnW, h = btnH })
      end

      -- Compare row (no-op cosmetic)
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.55, 0.75, 0.65, 0.85)
      local diff = (snap.z_per_sec or 0) - (state.z_per_sec or 0)
      local diffStr
      if diff > 0 then
        diffStr = "+" .. fmt.rate(diff) .. " ahead"
        love.graphics.setColor(1, 0.6, 0.55, 1)
      else
        diffStr = fmt.rate(-diff) .. " behind"
        love.graphics.setColor(0.55, 1, 0.7, 1)
      end
      love.graphics.printf(diffStr, b1x, by2 + 12, btnW * 2 + 4, "right")
    end
  end
  love.graphics.setScissor()

  -- Scrollbar
  if maxScroll > 0 then
    local trackX = PANEL.x + PANEL.w - 8
    love.graphics.setColor(0.05, 0.10, 0.07, 1)
    love.graphics.rectangle("fill", trackX, listY, 4, listH, 2, 2)
    local thumbH = math.max(40, listH * (listH / total))
    local thumbY = listY + (listH - thumbH) * (scroll / maxScroll)
    love.graphics.setColor(0.30, 0.85, 0.55, 0.85)
    love.graphics.rectangle("fill", trackX, thumbY, 4, thumbH, 2, 2)
  end

  -- Event ticker (bottom 220h)
  local tickerY = listY + listH + 10
  local tickerH = 210
  love.graphics.setColor(0.04, 0.07, 0.06, 1)
  love.graphics.rectangle("fill", startX, tickerY, cardW, tickerH, 6, 6)
  love.graphics.setColor(0.20, 0.55, 0.32, 0.7)
  love.graphics.rectangle("line", startX, tickerY, cardW, tickerH, 6, 6)

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.55, 0.85, 0.65, 0.95)
  love.graphics.print("EVENT TICKER", startX + 12, tickerY + 8)

  love.graphics.setFont(fonts.tiny)
  local events = Network.events(network, 9)
  local ey = tickerY + 32
  for i = #events, 1, -1 do
    local e = events[i]
    local age = (network._t or 0) - e.t
    local alpha = math.max(0.35, 1 - age / 60)
    love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha)
    love.graphics.print(e.text, startX + 12, ey)
    ey = ey + 18
    if ey > tickerY + tickerH - 8 then break end
  end
end

local function drawZeptonsCard(shop, def, x, y, w, h, state, fonts, t, mx, my)
  local hover = inRect(mx, my, x, y, w, h)
  if hover then shop.hoverKey = def.key end

  local isMonolith = (def.kind == "monolith")
  local isMiracle = (def.kind == "miracle")
  local active = false
  local remaining = 0
  if isMiracle then
    local exp = state.active_miracles and state.active_miracles[def.miracle.key]
    if exp and exp > love.timer.getTime() then
      active = true
      remaining = exp - love.timer.getTime()
    end
  end

  -- Background
  if active then
    love.graphics.setColor(0.10, 0.04, 0.18, 1)
  elseif hover then
    love.graphics.setColor(0.08, 0.10, 0.06, 1)
  else
    love.graphics.setColor(0.05, 0.07, 0.05, 1)
  end
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  local accent = isMonolith and Monoliths.def.color or def.miracle.color
  love.graphics.setColor(accent[1], accent[2], accent[3], hover and 0.95 or 0.60)
  love.graphics.setLineWidth(active and 3 or 2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(1)

  -- Icon block
  local iconW = 80
  love.graphics.setColor(accent[1] * 0.20, accent[2] * 0.20, accent[3] * 0.20, 1)
  love.graphics.rectangle("fill", x + 8, y + 8, iconW, h - 16, 4, 4)

  if isMonolith then
    -- Mini-monolith inside the icon block
    require("src.assets").drawMonolith(x + 8 + iconW / 2, y + h - 18, t,
      { h = h - 36, w = 12, eyeColor = accent })
  else
    -- Miracle icon: stylized pulse + sparkle
    local cxx, cyy = x + 8 + iconW / 2, y + 8 + (h - 16) / 2
    for r = 22, 0, -1 do
      love.graphics.setColor(accent[1], accent[2], accent[3], (1 - r/22) * 0.18)
      love.graphics.circle("fill", cxx, cyy, r)
    end
    love.graphics.setColor(accent[1], accent[2], accent[3], 1)
    love.graphics.circle("fill", cxx, cyy, 6)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.circle("fill", cxx, cyy, 2.5)
    -- Orbiting sparkles
    for k = 0, 4 do
      local a = t * 1.2 + k * (math.pi * 2 / 5)
      love.graphics.setColor(accent[1], accent[2], accent[3], 0.85)
      love.graphics.circle("fill", cxx + math.cos(a) * 18, cyy + math.sin(a) * 18, 1.4)
    end
  end

  local tx = x + 8 + iconW + 14

  -- Title
  love.graphics.setFont(fonts.bold)
  love.graphics.setColor(0.95, 1, 0.92, 1)
  love.graphics.print(def.name, tx, y + 10)

  -- Subtitle (category / state info)
  love.graphics.setFont(fonts.tiny)
  if isMonolith then
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
    love.graphics.print(string.format("OWNED %d  ·  %.2f Z/s each",
      state.monoliths or 0, Monoliths.def.produce_zps), tx, y + 38)
  else
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
    if active then
      love.graphics.print(string.format("ACTIVE  —  %ds remaining", math.floor(remaining)),
        tx, y + 38)
    else
      love.graphics.print(string.format("%s · %d sec",
        def.miracle.category:upper(), def.miracle.duration), tx, y + 38)
    end
  end

  -- Description
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.75, 0.85, 0.75, 0.95)
  love.graphics.printf(def.desc, tx, y + 56, w - iconW - 180, "left")

  -- Cost button (right side)
  local btnW, btnH = 140, 56
  local bx = x + w - btnW - 12
  local by = y + h - btnH - 12

  local cost, currency, currencyColor, currencyAvail
  if isMonolith then
    cost = Monoliths.unitCost(state.monoliths or 0)
    currency = "BTC"
    currencyColor = { 1, 0.85, 0.40 }
    currencyAvail = (state.z or 0) >= cost
  else
    cost = def.miracle.cost
    currency = "Z"
    currencyColor = { 0.55, 1, 0.75 }
    currencyAvail = (state.zeptons or 0) >= cost
  end

  if active then
    love.graphics.setColor(0.20, 0.10, 0.30, 1)
    love.graphics.rectangle("fill", bx, by, btnW, btnH, 5, 5)
    love.graphics.setColor(accent[1], accent[2], accent[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, btnW, btnH, 5, 5)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.bold)
    love.graphics.setColor(accent[1], accent[2], accent[3], 1)
    love.graphics.printf("ACTIVE", bx, by + 16, btnW, "center")
    return nil
  end

  if hover then
    love.graphics.setColor(currencyAvail and 0.25 or 0.10, currencyAvail and 0.20 or 0.10, currencyAvail and 0.10 or 0.05, 1)
  else
    love.graphics.setColor(currencyAvail and 0.18 or 0.06, currencyAvail and 0.14 or 0.06, currencyAvail and 0.06 or 0.04, 1)
  end
  love.graphics.rectangle("fill", bx, by, btnW, btnH, 5, 5)
  love.graphics.setColor(currencyAvail and accent[1] or accent[1] * 0.5,
                         currencyAvail and accent[2] or accent[2] * 0.5,
                         currencyAvail and accent[3] or accent[3] * 0.5, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, btnW, btnH, 5, 5)
  love.graphics.setLineWidth(1)
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(currencyAvail and accent[1] or 0.55,
                         currencyAvail and accent[2] or 0.55,
                         currencyAvail and accent[3] or 0.55, 1)
  love.graphics.print(isMonolith and "RAISE" or "INVOKE", bx + 10, by + 6)

  -- Cost with currency icon
  local coinSize = 9
  local costStr = fmt.zeptons(cost) .. " " .. currency
  if isMonolith then
    Coin.drawBTC(bx + 16, by + 38, coinSize, t)
  else
    Coin.draw(bx + 16, by + 38, coinSize, t)
  end
  love.graphics.setFont(fonts.bold)
  love.graphics.setColor(currencyAvail and currencyColor[1] or 0.55,
                         currencyAvail and currencyColor[2] or 0.55,
                         currencyAvail and currencyColor[3] or 0.55, 1)
  love.graphics.printf(fmt.zeptons(cost), bx + 28, by + 30, btnW - 38, "right")

  return {
    kind = isMonolith and "buy_monolith" or "invoke_miracle",
    miracle_def = isMiracle and def.miracle or nil,
    x = bx, y = by, w = btnW, h = btnH,
  }
end

local function drawZeptonsTab(shop, state, fonts, t, mx, my)
  local lay = listAreaY()
  local lah = listAreaH()
  local cardW = PANEL.w - 24
  local startX = PANEL.x + 12
  local cardH = CARD_H.zeptons

  -- Build a flat list with synthetic _category entries.
  local list = {}
  table.insert(list, { _category = "MONOLITH" })
  table.insert(list, {
    kind = "monolith",
    name = Monoliths.def.name,
    desc = Monoliths.def.desc,
  })
  for _, c in ipairs(MiraclesDb.categories) do
    table.insert(list, { _category = "MIRACLE · " .. c.name })
    for _, mdef in ipairs(c.items) do
      table.insert(list, {
        kind = "miracle",
        name = mdef.name,
        desc = mdef.desc,
        miracle = mdef,
      })
    end
  end

  local subheadH = 26
  local realTotal = 0
  for _, def in ipairs(list) do
    if def._category then realTotal = realTotal + subheadH + 4
    else realTotal = realTotal + cardH + LIST_PAD end
  end
  shop.scroll[shop.tab] = shop.scroll[shop.tab] or 0
  local maxScroll = math.max(0, realTotal - lah)
  if shop.scroll[shop.tab] > maxScroll then shop.scroll[shop.tab] = maxScroll end
  if shop.scroll[shop.tab] < 0 then shop.scroll[shop.tab] = 0 end
  local scroll = shop.scroll[shop.tab]

  scissorList()
  local cursorY = lay - scroll
  for i, def in ipairs(list) do
    if def._category then
      if cursorY + subheadH > lay - subheadH and cursorY < lay + lah then
        love.graphics.setColor(0.06, 0.10, 0.13, 1)
        love.graphics.rectangle("fill", startX, cursorY, cardW, subheadH, 4, 4)
        love.graphics.setColor(0.55, 0.85, 0.95, 0.50)
        love.graphics.rectangle("line", startX, cursorY, cardW, subheadH, 4, 4)
        love.graphics.setFont(fonts.tiny)
        love.graphics.setColor(0.55, 0.95, 1.0, 1)
        love.graphics.print(def._category, startX + 10, cursorY + 7)
      end
      cursorY = cursorY + subheadH + 4
    else
      if cursorY + cardH > lay - cardH and cursorY < lay + lah + cardH then
        local btn = drawZeptonsCard(shop, def, startX, cursorY, cardW, cardH, state, fonts, t, mx, my)
        if btn then table.insert(shop._buttons, btn) end
      end
      cursorY = cursorY + cardH + LIST_PAD
    end
  end
  love.graphics.setScissor()

  if maxScroll > 0 then
    local trackX = PANEL.x + PANEL.w - 8
    love.graphics.setColor(0.05, 0.10, 0.07, 1)
    love.graphics.rectangle("fill", trackX, lay, 4, lah, 2, 2)
    local thumbH = math.max(40, lah * (lah / realTotal))
    local thumbY = lay + (lah - thumbH) * (scroll / maxScroll)
    love.graphics.setColor(0.55, 0.85, 0.95, 0.85)
    love.graphics.rectangle("fill", trackX, thumbY, 4, thumbH, 2, 2)
  end
end

function M.draw(shop, state, fonts, t, mx, my)
  drawPanelBg()
  drawTabs(shop, fonts)

  shop._buttons = {}
  shop.hoverKey = nil

  if shop.tab == "network" then
    drawNetworkPanel(shop, state, fonts, t, mx, my)
    return
  end
  if shop.tab == "zeptons" then
    drawZeptonsTab(shop, state, fonts, t, mx, my)
    return
  end

  local lay = listAreaY()
  local lah = listAreaH()

  local list, db, cardH, drawCard
  -- For the upgrades tab we use the pre-categorized flat list (each
  -- entry has a hidden _category tag) so the iterator can inject
  -- subheads when the category changes.
  if shop.tab == "miners" then
    list = minersDb.list; cardH = CARD_H.miners; drawCard = drawMinerCard
  elseif shop.tab == "energy" then
    list = energyDb.list; cardH = CARD_H.energy; drawCard = drawEnergyCard
  else
    -- Build a flat list with category boundaries from upgradesDb.categories
    list = {}
    for _, c in ipairs(upgradesDb.categories or {}) do
      table.insert(list, { _category = c.name })
      for _, u in ipairs(c.items) do table.insert(list, u) end
    end
    cardH = CARD_H.upgrades; drawCard = drawUpgradeCard
  end

  local cardW = PANEL.w - 24
  local startX = PANEL.x + 12

  -- Compute total height & clamp scroll
  local total = #list * (cardH + LIST_PAD)
  local maxScroll = math.max(0, total - lah)
  if shop.scroll[shop.tab] > maxScroll then shop.scroll[shop.tab] = maxScroll end
  if shop.scroll[shop.tab] < 0 then shop.scroll[shop.tab] = 0 end
  local scroll = shop.scroll[shop.tab]

  scissorList()
  -- For the upgrades tab the list contains synthetic `_category` entries
  -- that render as subheads instead of cards. Compute total y on the fly.
  local subheadH = 26
  local cardWWithoutScroll = cardW
  scissorList()
  local cursorY = lay - scroll
  -- Recompute total respecting subheads
  local realTotal = 0
  for _, def in ipairs(list) do
    if def._category then realTotal = realTotal + subheadH + 4
    else realTotal = realTotal + cardH + LIST_PAD end
  end
  maxScroll = math.max(0, realTotal - lah)
  if shop.scroll[shop.tab] > maxScroll then shop.scroll[shop.tab] = maxScroll end
  if shop.scroll[shop.tab] < 0 then shop.scroll[shop.tab] = 0 end
  scroll = shop.scroll[shop.tab]
  cursorY = lay - scroll

  for i, def in ipairs(list) do
    if def._category then
      if cursorY + subheadH > lay - subheadH and cursorY < lay + lah then
        love.graphics.setColor(0.06, 0.13, 0.10, 1)
        love.graphics.rectangle("fill", startX, cursorY, cardW, subheadH, 4, 4)
        love.graphics.setColor(0.30, 0.85, 0.55, 0.50)
        love.graphics.rectangle("line", startX, cursorY, cardW, subheadH, 4, 4)
        love.graphics.setFont(fonts.tiny)
        love.graphics.setColor(0.55, 0.95, 0.75, 1)
        love.graphics.print(def._category, startX + 10, cursorY + 7)
      end
      cursorY = cursorY + subheadH + 4
    else
      if cursorY + cardH > lay - cardH and cursorY < lay + lah + cardH then
        local btn = drawCard(shop, def, startX, cursorY, cardW, cardH, state, fonts, t, mx, my)
        if btn then table.insert(shop._buttons, btn) end
      end
      cursorY = cursorY + cardH + LIST_PAD
    end
  end
  total = realTotal
  love.graphics.setScissor()

  -- Scrollbar
  if maxScroll > 0 then
    local trackX = PANEL.x + PANEL.w - 8
    local trackY = lay
    local trackH = lah
    love.graphics.setColor(0.05, 0.10, 0.07, 1)
    love.graphics.rectangle("fill", trackX, trackY, 4, trackH, 2, 2)
    local thumbH = math.max(40, trackH * (lah / total))
    local thumbY = trackY + (trackH - thumbH) * (scroll / maxScroll)
    love.graphics.setColor(0.30, 0.85, 0.55, 0.85)
    love.graphics.rectangle("fill", trackX, thumbY, 4, thumbH, 2, 2)
  end

  -- Hover tooltip area at footer
  if shop.hoverKey then
    local def
    if shop.tab == "miners" then def = minersDb.byKey[shop.hoverKey]
    elseif shop.tab == "energy" then def = energyDb.byKey[shop.hoverKey]
    else def = upgradesDb.byKey[shop.hoverKey] end
    if def and def.desc then
      love.graphics.setFont(fonts.tiny)
      love.graphics.setColor(0.45, 0.85, 0.65, 0.85)
      love.graphics.printf(def.desc, PANEL.x + 12, PANEL.y + PANEL.h - 28, PANEL.w - 24, "left")
    end
  end
end

function M.mousepressed(shop, lx, ly, button, state, callbacks, mods)
  if button ~= 1 then return false end
  -- Tabs
  if shop._tabRects then
    for _, r in ipairs(shop._tabRects) do
      if inRect(lx, ly, r.x, r.y, r.w, r.h) then
        if shop.tab ~= r.id and callbacks.onTabChange then
          callbacks.onTabChange(r.id)
        end
        shop.tab = r.id
        return true
      end
    end
  end

  -- Buttons (clip to list area)
  local lay = listAreaY()
  local lah = listAreaH()
  if ly < lay or ly > lay + lah then return false end

  if shop._buttons then
    for _, b in ipairs(shop._buttons) do
      if inRect(lx, ly, b.x, b.y, b.w, b.h) then
        local qty = purchaseQty(mods.shift, mods.ctrl)
        if b.kind == "buy_miner" then
          callbacks.onBuyMiner(b.def, qty)
        elseif b.kind == "buy_energy" then
          callbacks.onBuyEnergy(b.def, qty)
        elseif b.kind == "buy_upgrade" then
          callbacks.onBuyUpgrade(b.def)
        elseif b.kind == "boost" then
          if callbacks.onBoost then callbacks.onBoost(b.target_id) end
        elseif b.kind == "pool" then
          if callbacks.onPool then callbacks.onPool(b.target_id) end
        elseif b.kind == "leave_pool" then
          if callbacks.onLeavePool then callbacks.onLeavePool() end
        elseif b.kind == "accept_pool" then
          if callbacks.onAcceptPool then callbacks.onAcceptPool(b.target_id) end
        elseif b.kind == "decline_pool" then
          if callbacks.onDeclinePool then callbacks.onDeclinePool(b.target_id) end
        elseif b.kind == "buy_monolith" then
          if callbacks.onBuyMonolith then callbacks.onBuyMonolith(qty) end
        elseif b.kind == "invoke_miracle" then
          if callbacks.onInvokeMiracle and b.miracle_def then
            callbacks.onInvokeMiracle(b.miracle_def)
          end
        end
        return true
      end
    end
  end
  return false
end

function M.wheelmoved(shop, dx, dy, lx, ly)
  -- Only scroll if cursor within panel
  if lx >= PANEL.x and lx <= PANEL.x + PANEL.w and ly >= PANEL.y and ly <= PANEL.y + PANEL.h then
    shop.scroll[shop.tab] = (shop.scroll[shop.tab] or 0) - dy * 60
    return true
  end
  return false
end

function M.setTab(shop, tabId)
  if shop.tab ~= tabId then
    shop.tab = tabId
    return true
  end
  return false
end

return M
