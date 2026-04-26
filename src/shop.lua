local fmt = require "src.format"
local minersDb = require "src.miners"
local energyDb = require "src.energy"
local upgradesDb = require "src.upgrades"
local Network = require "src.network"
local Coin = require "src.coin"

local M = {}

local DESIGN_W, DESIGN_H = 1920, 1080

local PANEL = { x = 1232, y = 116, w = 668, h = 900 }
local TAB_H = 56
local LIST_PAD = 12
local CARD_H = { miners = 168, energy = 168, upgrades = 124 }

local function inRect(mx, my, x, y, w, h)
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function M.new()
  local s = {
    tab = "miners",
    scroll = { miners = 0, energy = 0, upgrades = 0, network = 0 },
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

  -- Pool indicator
  if network.pool_with then
    love.graphics.setColor(0.55, 0.85, 0.95, 0.95)
    local poolName = "?"
    for _, p in ipairs(network.players) do
      if p.id == network.pool_with then poolName = p.name; break end
    end
    love.graphics.printf("⛓ POOLED w/ " .. poolName, startX, lay + 56, cardW - 14, "right")
  end

  -- Sort snaps so live operators surface first, demo placeholders last,
  -- and offline-known peers stay accessible without burying the live ones.
  local function statusRank(s)
    if s.placeholder then return 4 end
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

  -- Compute subhead injections: a thin header row whenever the section changes
  local sections = {}
  local lastRank
  for i, s in ipairs(snaps) do
    local r = statusRank(s)
    if r ~= lastRank then
      local label
      if r == 0 then label = "ONLINE"
      elseif r == 1 then label = "AFK"
      elseif r == 2 then label = "OFFLINE — KNOWN"
      elseif r == 3 then label = "OFFLINE"
      else label = "DEMO PEERS" end
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

      -- Pool / Leave
      local poolB_x = b1x + btnW + 4
      local hover2 = inRect(mx, my, poolB_x, by1, btnW, btnH)
      local pooled = (network.pool_with == snap.id)
      if pooled then
        love.graphics.setColor(hover2 and 0.55 or 0.35, hover2 and 0.20 or 0.10, hover2 and 0.20 or 0.10, 1)
      else
        love.graphics.setColor(hover2 and 0.18 or 0.10, hover2 and 0.45 or 0.30, hover2 and 0.32 or 0.18, 1)
      end
      love.graphics.rectangle("fill", poolB_x, by1, btnW, btnH, 4, 4)
      love.graphics.setColor(pooled and 1 or 0.55, pooled and 0.55 or 0.95, pooled and 0.55 or 0.65, hover2 and 1 or 0.7)
      love.graphics.rectangle("line", poolB_x, by1, btnW, btnH, 4, 4)
      love.graphics.setColor(0.85, 0.95, 0.85, 1)
      love.graphics.printf(pooled and "LEAVE" or "POOL", poolB_x, by1 + 8, btnW, "center")
      table.insert(shop._buttons, { kind = pooled and "leave_pool" or "pool", target_id = snap.id, x = poolB_x, y = by1, w = btnW, h = btnH })

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

function M.draw(shop, state, fonts, t, mx, my)
  drawPanelBg()
  drawTabs(shop, fonts)

  shop._buttons = {}
  shop.hoverKey = nil

  if shop.tab == "network" then
    drawNetworkPanel(shop, state, fonts, t, mx, my)
    return
  end

  local lay = listAreaY()
  local lah = listAreaH()

  local list, db, cardH, drawCard
  if shop.tab == "miners" then
    list = minersDb.list; cardH = CARD_H.miners; drawCard = drawMinerCard
  elseif shop.tab == "energy" then
    list = energyDb.list; cardH = CARD_H.energy; drawCard = drawEnergyCard
  else
    list = upgradesDb.list; cardH = CARD_H.upgrades; drawCard = drawUpgradeCard
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
  local startY = lay - scroll
  for i, def in ipairs(list) do
    local y = startY + (i - 1) * (cardH + LIST_PAD)
    -- Cull
    if y + cardH > lay - cardH and y < lay + lah + cardH then
      local btn = drawCard(shop, def, startX, y, cardW, cardH, state, fonts, t, mx, my)
      if btn then table.insert(shop._buttons, btn) end
    end
  end
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
