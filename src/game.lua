local fmt        = require "src.format"
local minersDb   = require "src.miners"
local energyDb   = require "src.energy"
local upgradesDb = require "src.upgrades"
local Save       = require "src.save"
local Audio      = require "src.audio"
local Particles  = require "src.particles"
local Floats     = require "src.floats"
local Shaders    = require "src.shaders"
local Hud        = require "src.hud"
local Shop       = require "src.shop"
local Facility   = require "src.facility"
local Intro      = require "src.intro"
local Ach        = require "src.achievements"
local Fx         = require "src.fx"
local Network    = require "src.network"

local M = {}

local DESIGN_W, DESIGN_H = 1920, 1080
local SAVE_INTERVAL = 15
local AUTOBUY_INTERVAL = 30
local BLOCK_INTERVAL = 60   -- seconds between found blocks
local HALVING_BLOCKS = 100  -- halve base reward every N blocks
local HASH_PER_PRODUCE = 110e12  -- 110 TH/s per "1 produce" unit (calibrates hashrate display)

-- ============================================================
-- State helpers
-- ============================================================

local function freshState()
  local miners = {}
  for _, def in ipairs(minersDb.list) do miners[def.key] = 0 end
  local energy = {}
  for _, def in ipairs(energyDb.list) do energy[def.key] = 0 end
  return {
    facility_name = nil,
    facility_seed = love.math.random(0, 0xFFFFFFFF),
    z             = 0,
    z_lifetime    = 0,
    z_clicked     = 0,
    click_count   = 0,
    play_time     = 0,
    miners        = miners,
    energy        = energy,
    upgrades      = {},
    block_height  = 0,
    blocks_found  = 0,
    last_block_at = 0,
  }
end

local function ensureCompleteState(s)
  for _, def in ipairs(minersDb.list) do
    s.miners[def.key] = s.miners[def.key] or 0
  end
  for _, def in ipairs(energyDb.list) do
    s.energy[def.key] = s.energy[def.key] or 0
  end
  s.upgrades       = s.upgrades or {}
  s.facility_seed  = s.facility_seed or love.math.random(0, 0xFFFFFFFF)
  s.block_height   = s.block_height or 0
  s.blocks_found   = s.blocks_found or 0
  s.last_block_at  = s.last_block_at or 0
end

-- ============================================================
-- Modifier computation
-- ============================================================

local function freshMods()
  local m = {
    click_add        = 0,
    click_pct        = 0,
    mult_miners      = 0, -- additive percentage on top of 1.0
    energy_eff       = 0,
    miner_kind       = {},
    energy_kind      = {},
    network          = 0,
    crit_chance      = 0,
    crit_mult        = 1,
    buffer           = 0,
    autobuy_miners   = false,
    autobuy_energy   = false,
    speed            = 0,
    global_z         = 0,
  }
  for _, def in ipairs(minersDb.list) do m.miner_kind[def.key]   = 1 end
  for _, def in ipairs(energyDb.list) do m.energy_kind[def.key]  = 1 end
  return m
end

local function applyUpgrades(state)
  local m = freshMods()
  for key, _ in pairs(state.upgrades) do
    local u = upgradesDb.byKey[key]
    if u then
      local e = u.effect
      if e.type == "click_add" then
        m.click_add = m.click_add + e.amount
      elseif e.type == "click_pct" then
        m.click_pct = math.max(m.click_pct, e.amount)
      elseif e.type == "mult_miners" then
        m.mult_miners = m.mult_miners + e.amount
      elseif e.type == "energy_eff" then
        m.energy_eff = math.max(m.energy_eff, e.amount)
      elseif e.type == "mult_miner_kind" then
        m.miner_kind[e.key] = (m.miner_kind[e.key] or 1) + e.amount
      elseif e.type == "mult_energy_kind" then
        m.energy_kind[e.key] = (m.energy_kind[e.key] or 1) + e.amount
      elseif e.type == "mult_energy_kind_multi" then
        for _, k in ipairs(e.keys) do
          m.energy_kind[k] = (m.energy_kind[k] or 1) + e.amount
        end
      elseif e.type == "network" then
        m.network = math.max(m.network, e.amount)
      elseif e.type == "crit" then
        m.crit_chance = math.max(m.crit_chance, e.chance)
        m.crit_mult   = math.max(m.crit_mult, e.mult)
      elseif e.type == "buffer" then
        m.buffer = math.max(m.buffer, e.amount)
      elseif e.type == "autobuy" then
        if e.target == "miners" then m.autobuy_miners = true end
        if e.target == "energy" then m.autobuy_energy = true end
      elseif e.type == "speed" then
        m.speed = math.max(m.speed, e.amount)
      elseif e.type == "global_z" then
        m.global_z = m.global_z + e.amount
      end
    end
  end
  state.mods = m
end

-- ============================================================
-- Production calculation
-- ============================================================

local function totalMinerCount(state)
  local n = 0
  for _, c in pairs(state.miners) do n = n + c end
  return n
end

local function rawZRate(state)
  local rate = 0
  local mods = state.mods
  for _, def in ipairs(minersDb.list) do
    local c = state.miners[def.key] or 0
    if c > 0 then
      rate = rate + c * def.produce * (mods.miner_kind[def.key] or 1)
    end
  end
  -- Global multipliers
  local globalMult = (1 + mods.mult_miners) * (1 + mods.global_z)
  rate = rate * globalMult
  -- Network bonus
  local nm = totalMinerCount(state)
  if mods.network > 0 then
    rate = rate * (1 + mods.network * nm)
  end
  return rate
end

local function rawEnergyDemand(state)
  local d = 0
  local mods = state.mods
  for _, def in ipairs(minersDb.list) do
    local c = state.miners[def.key] or 0
    if c > 0 then
      d = d + c * def.energy
    end
  end
  d = d * (1 - mods.energy_eff)
  return d
end

local function rawEnergySupply(state, t, dayPhase)
  local s = 0
  state._dynamicFactor = state._dynamicFactor or {}
  local mods = state.mods
  for _, def in ipairs(energyDb.list) do
    local c = state.energy[def.key] or 0
    local f = energyDb.dynamicFactor(def, t, dayPhase)
    state._dynamicFactor[def.key] = f
    if c > 0 then
      s = s + c * def.produce * f * (mods.energy_kind[def.key] or 1)
    end
  end
  return s
end

local function recompute(state, t)
  applyUpgrades(state)
  local supply = rawEnergySupply(state, t, state.day_phase or 0.4)
  local demand = rawEnergyDemand(state)
  local rawRate = rawZRate(state)
  -- Power efficiency: if demand > supply, throttle
  local efficiency = 1
  if demand > supply and demand > 0 then
    efficiency = supply / demand
  end
  state.z_per_sec_base = rawRate
  state.z_per_sec = rawRate * efficiency
  state.energy_supply = supply
  state.energy_used = math.min(demand, supply + 0.0001)
  state.energy_demand_raw = demand
  state.miner_count = totalMinerCount(state)
  -- Computational hash rate: based on raw production before energy throttle
  state.hashrate = rawRate * HASH_PER_PRODUCE
  -- Network difficulty scales with cumulative blocks; cosmetic
  state.difficulty = 0.5e12 * (1 + (state.block_height or 0) * 0.012)
end

-- ============================================================
-- Achievements
-- ============================================================

local ACH_ORDER = {
  z_thresholds   = { { key = "z_1k", v = 1e3 }, { key = "z_1m", v = 1e6 }, { key = "z_1b", v = 1e9 }, { key = "z_1t", v = 1e12 } },
  rate_thresholds = { { key = "rate_1k", v = 1e3 }, { key = "rate_1m", v = 1e6 }, { key = "rate_1b", v = 1e9 } },
  miner_count_thresholds = { { key = "ten_miners", v = 10 }, { key = "hundred_miners", v = 100 }, { key = "thousand_miners", v = 1000 } },
  click_thresholds = { { key = "click_100", v = 100 }, { key = "click_1000", v = 1000 } },
  play_thresholds = { { key = "play_1h", v = 3600 }, { key = "play_10h", v = 36000 } },
}

local FIRST_ENERGY = {
  solar = "first_solar", wind = "first_wind", hydro = "first_hydro",
  geothermal = "first_geothermal", fission = "first_nuclear",
  fusion = "first_fusion", antimatter = "first_antimatter",
  zeropoint = "first_zeropoint",
}

local function tryAchievement(state, key, meta)
  if state._earned[key] then return false end
  state._earned[key] = { key = key, points = 0, fresh = true }
  Ach.unlock(key, meta)
  Audio.achievement()
  -- Also push portal FX
  Fx.flash("#33ff88", 220, 0.5)
  Fx.glow("#33ff88", 0.5, 600)
  -- Status message
  local def
  for _, a in ipairs(state._catalog) do if a.key == key then def = a end end
  if def then
    M.message(state, "★ Achievement: " .. def.title, { 0.55, 1, 0.75 })
  end
  return true
end

local function checkAchievements(state)
  local earned = state._earned
  if state.z_lifetime > 0 and not earned.first_zepton then tryAchievement(state, "first_zepton") end
  if state.facility_name and not earned.name_facility then tryAchievement(state, "name_facility") end

  for _, t in ipairs(ACH_ORDER.z_thresholds) do
    if state.z_lifetime >= t.v and not earned[t.key] then tryAchievement(state, t.key) end
  end
  for _, t in ipairs(ACH_ORDER.rate_thresholds) do
    if state.z_per_sec >= t.v and not earned[t.key] then tryAchievement(state, t.key) end
  end
  if state.miner_count >= 1 and not earned.first_miner then tryAchievement(state, "first_miner") end
  for _, t in ipairs(ACH_ORDER.miner_count_thresholds) do
    if state.miner_count >= t.v and not earned[t.key] then tryAchievement(state, t.key) end
  end
  for _, t in ipairs(ACH_ORDER.click_thresholds) do
    if (state.click_count or 0) >= t.v and not earned[t.key] then tryAchievement(state, t.key) end
  end
  for _, t in ipairs(ACH_ORDER.play_thresholds) do
    if (state.play_time or 0) >= t.v and not earned[t.key] then tryAchievement(state, t.key) end
  end

  for k, achKey in pairs(FIRST_ENERGY) do
    if (state.energy[k] or 0) >= 1 and not earned[achKey] then
      tryAchievement(state, achKey)
    end
  end

  -- All energy types
  if not earned.all_energy_types then
    local all = true
    for _, def in ipairs(energyDb.list) do
      if (state.energy[def.key] or 0) <= 0 then all = false; break end
    end
    if all then tryAchievement(state, "all_energy_types") end
  end
  -- All miner tiers
  if not earned.all_miner_tiers then
    local all = true
    for _, def in ipairs(minersDb.list) do
      if (state.miners[def.key] or 0) <= 0 then all = false; break end
    end
    if all then tryAchievement(state, "all_miner_tiers") end
  end

  -- Upgrade related
  local upgradeCount = 0
  for _ in pairs(state.upgrades) do upgradeCount = upgradeCount + 1 end
  if upgradeCount >= 1 and not earned.first_upgrade then tryAchievement(state, "first_upgrade") end
  if upgradeCount >= #upgradesDb.list and not earned.all_upgrades then tryAchievement(state, "all_upgrades") end

  -- Block / network related
  if (state.blocks_found or 0) >= 1 and not earned.first_block then tryAchievement(state, "first_block") end
  if (state.blocks_found or 0) >= 10 and not earned.ten_blocks then tryAchievement(state, "ten_blocks") end
  if (state._lastHalvingNotice or 0) >= 1 and not earned.first_halving then tryAchievement(state, "first_halving") end
  if state.network and (state.network.boostCount or 0) >= 1 and not earned.first_boost then tryAchievement(state, "first_boost") end
  if state.network and (state.network.boostCount or 0) >= 10 and not earned.ten_boosts then tryAchievement(state, "ten_boosts") end
  if state.network and state.network.pool_with and not earned.first_pool then tryAchievement(state, "first_pool") end

  -- Blackout: demand exceeds supply
  if state.energy_demand_raw > state.energy_supply and state.energy_demand_raw > 0 and state.energy_supply > 0 and not earned.blackout then
    tryAchievement(state, "blackout")
  end

  -- Surplus 50%: supply >= 1.5x demand and demand > 0
  if state.energy_demand_raw > 0 and state.energy_supply > state.energy_demand_raw * 1.5 and not earned.surplus_50 then
    tryAchievement(state, "surplus_50")
  end

  -- Balanced grid: util in [0.95, 1.00] for 10s
  if state.energy_supply > 0 and state.energy_demand_raw > 0 then
    local u = state.energy_demand_raw / state.energy_supply
    if u >= 0.95 and u <= 1.00 then
      state._balancedTimer = (state._balancedTimer or 0) + state._lastDt
      if state._balancedTimer > 10 and not earned.balanced_grid then
        tryAchievement(state, "balanced_grid")
      end
    else
      state._balancedTimer = 0
    end
  end
end

-- ============================================================
-- Public API
-- ============================================================

function M.message(state, text, color)
  state.messages = state.messages or {}
  table.insert(state.messages, { text = text, c = color or { 0.85, 1, 0.92 }, t = love.timer.getTime() })
  while #state.messages > 12 do table.remove(state.messages, 1) end
end

local function newGameState()
  local s = freshState()
  ensureCompleteState(s)
  return s
end

function M.new(opts)
  Shaders.load()
  Audio.preload()
  Facility.init()

  local state = newGameState()

  -- Try load save
  local data = Save.load()
  if data and data.facility_name then
    state.facility_name = data.facility_name
    state.facility_seed = data.facility_seed or state.facility_seed
    state.z             = data.z or 0
    state.z_lifetime    = data.z_lifetime or 0
    state.z_clicked     = data.z_clicked or 0
    state.click_count   = data.click_count or 0
    state.play_time     = data.play_time or 0
    state.miners        = data.miners or state.miners
    state.energy        = data.energy or state.energy
    state.upgrades      = data.upgrades or {}
    state.block_height  = data.block_height or 0
    state.blocks_found  = data.blocks_found or 0
    state.last_block_at = data.last_block_at or 0
    ensureCompleteState(state)
  end

  state.scene          = state.facility_name and "play" or "intro"
  state.coreIntensity  = 1
  state.corePulse      = 0
  state.coreHold       = 0
  state.coreHoldDown   = false
  state.paused         = false
  state.day_phase      = 0.30
  state._catalog       = Ach.loadCatalog()
  state._earned        = Ach.loadUnlocks()
  state._lastDt        = 1/60
  state._lastSave      = love.timer.getTime()
  state._lastAutobuy   = love.timer.getTime()
  state._lastClickT    = 0

  state.messages       = {}

  state.particles      = Particles.new()
  state.floats         = Floats.new()

  state.shop           = Shop.new()

  state.network        = Network.new(state.facility_seed, state)
  if data and data.network then
    state.network.pool_with  = data.network.pool_with
    state.network.boostCount = data.network.boostCount or 0
  end

  -- Pre-populate intro scene
  state.intro = Intro.new({
    fonts    = opts.fonts,
    onSubmit = function(name)
      state.facility_name = name
      state.scene = "play"
      tryAchievement(state, "name_facility")
      M.message(state, "Facility " .. name .. " online.", { 0.55, 1, 0.75 })
      Audio.power()
      Fx.glow("#33ff88", 0.7, 800)
      Fx.pulse("#33ff88", 700)
      Fx.mood("#0a1a12", 0.18)
      M.save(state)
    end,
  })

  applyUpgrades(state)
  recompute(state, 0)

  -- Persistent ambient effects in portal
  Fx.mood("#0a1a12", 0.18)
  Fx.calm("#33ff88", 0.20)
  Audio.startHum()

  return state
end

-- ============================================================
-- Update / Draw
-- ============================================================

function M.update(state, dt, fonts)
  local effDt = dt
  if state.paused then
    if state.scene == "intro" and state.intro then
      Intro.update(state.intro, dt, love.timer.getTime())
    end
    return
  end

  -- Speed multiplier
  if state.mods and state.mods.speed > 0 then
    effDt = effDt * (1 + state.mods.speed)
  end

  state._lastDt = effDt
  state.play_time = (state.play_time or 0) + effDt

  -- Day cycle: full day every 240s
  state.day_phase = ((state.day_phase or 0) + effDt / 240) % 1

  if state.scene == "intro" then
    if state.intro then Intro.update(state.intro, dt, love.timer.getTime()) end
    state.particles:update(dt)
    state.floats:update(dt)
    return
  end

  -- Recompute production every frame (cheap)
  recompute(state, love.timer.getTime())

  -- Earn zeptons over time
  local earn = state.z_per_sec * effDt
  if earn > 0 then
    state.z = state.z + earn
    state.z_lifetime = (state.z_lifetime or 0) + earn
  end

  -- Hold-to-mine: continuous click pulse
  if state.coreHoldDown then
    state.coreHold = (state.coreHold or 0) + effDt
    state._heldPulse = (state._heldPulse or 0) + effDt
    if state._heldPulse > 0.20 then
      state._heldPulse = state._heldPulse - 0.20
      M.clickCore(state, nil, nil, { sustained = true })
    end
    -- Secret zen achievement
    if state.coreHold and state.coreHold >= 10 and not state._earned.secret_zen then
      tryAchievement(state, "secret_zen")
    end
  else
    -- Decay hold meter
    if state.coreHold and state.coreHold > 0 then
      state.coreHold = state.coreHold - effDt * 1.5
      if state.coreHold < 0 then state.coreHold = 0 end
    end
  end

  -- Core pulse decay
  if state.corePulse > 0 then
    state.corePulse = state.corePulse - effDt * 4
    if state.corePulse < 0 then state.corePulse = 0 end
  end

  -- Stochastic crit on miner ticks (once per second window)
  state._critAccum = (state._critAccum or 0) + effDt
  while state._critAccum >= 1.0 do
    state._critAccum = state._critAccum - 1.0
    if state.mods.crit_chance > 0 and state.z_per_sec > 0 then
      if love.math.random() < state.mods.crit_chance then
        local bonus = state.z_per_sec * (state.mods.crit_mult - 1)
        state.z = state.z + bonus
        state.z_lifetime = state.z_lifetime + bonus
        local cx, cy = Facility.coreCenter()
        state.floats:emit({
          x = cx - 80 + love.math.random() * 160,
          y = cy - 80 + love.math.random() * 60,
          text = "CRIT! +" .. fmt.zeptons(bonus),
          color = { 1, 0.85, 0.30 },
          size = 1.7, weight = "bold",
          life = 1.6,
          vy = -150,
        })
        state.particles:burst({
          x = cx, y = cy, n = 60,
          color = { 1, 0.85, 0.30 },
          minSpeed = 200, maxSpeed = 700,
          life = 1.4, size = 5,
          kind = "trail",
        })
        Audio.upgrade()
        Fx.flash("#ffd866", 200, 0.7)
      end
    end
  end

  -- Hum intensity tracks rate
  Audio.setHumIntensity(math.log(1 + state.z_per_sec) / 14)

  -- Update particles, floats
  state.particles:update(dt)
  state.floats:update(dt)

  -- Emit ambient particles around the core
  state._ambientAccum = (state._ambientAccum or 0) + dt
  if state._ambientAccum > 0.05 then
    state._ambientAccum = state._ambientAccum - 0.05
    local cx, cy = Facility.coreCenter()
    local r = Facility.coreRadius() + 20
    local a = love.math.random() * math.pi * 2
    state.particles:emit({
      x = cx + math.cos(a) * r,
      y = cy + math.sin(a) * r,
      vx = math.cos(a) * 50,
      vy = math.sin(a) * 50,
      ax = 0, ay = 0,
      life = 0.7, maxLife = 0.7,
      color = { 0.3, 1, 0.55 },
      size = 2,
      drag = 1.2,
      kind = "spark",
      rot = 0, vrot = 0,
    })
  end

  -- Block events: every BLOCK_INTERVAL seconds (Poisson-ish jitter)
  state._blockAccum = (state._blockAccum or 0) + effDt
  local interval = BLOCK_INTERVAL * (0.85 + 0.30 * (state.facility_seed % 100) / 100)
  if state._blockAccum > interval and state.z_per_sec > 0 then
    state._blockAccum = 0
    M.findBlock(state)
  end

  -- Auto-buy
  if love.timer.getTime() - state._lastAutobuy > AUTOBUY_INTERVAL then
    state._lastAutobuy = love.timer.getTime()
    if state.mods.autobuy_miners then
      local cheapest, cheapestCost
      for _, def in ipairs(minersDb.list) do
        local c = minersDb.unitCost(def, state.miners[def.key] or 0)
        if c <= state.z and (not cheapestCost or c < cheapestCost) then
          cheapest, cheapestCost = def, c
        end
      end
      if cheapest then M.buyMiner(state, cheapest, 1, true) end
    end
    if state.mods.autobuy_energy then
      local cheapest, cheapestCost
      for _, def in ipairs(energyDb.list) do
        local c = energyDb.unitCost(def, state.energy[def.key] or 0)
        if c <= state.z and (not cheapestCost or c < cheapestCost) then
          cheapest, cheapestCost = def, c
        end
      end
      if cheapest then M.buyEnergy(state, cheapest, 1, true) end
    end
  end

  -- Network mesh simulation
  Network.update(state.network, dt, state)

  -- Pool sharing economy
  if state.network.pool_with then
    local outflow, payout = Network.tickPool(state.network, effDt, state.z_per_sec)
    if outflow > 0 then state.z = state.z - outflow end
    if payout > 0 then
      state.z = state.z + payout
      state.z_lifetime = (state.z_lifetime or 0) + payout
      M.message(state, string.format("Pool payout +%s Z", fmt.zeptons(payout)), { 0.55, 0.85, 0.95 })
    end
  end

  -- Boost responses
  local pendingBonus = Network.collectPendingBonuses(state.network)
  if pendingBonus > 0 then
    state.z = state.z + pendingBonus
    state.z_lifetime = (state.z_lifetime or 0) + pendingBonus
  end

  -- Achievements
  checkAchievements(state)

  -- Periodic save
  if love.timer.getTime() - state._lastSave > SAVE_INTERVAL then
    state._lastSave = love.timer.getTime()
    M.save(state)
  end
end

-- ============================================================
-- Click handler
-- ============================================================

local function clickValue(state)
  local base = 1 + (state.mods and state.mods.click_add or 0)
  local pct = state.mods and state.mods.click_pct or 0
  if pct > 0 then
    base = base + state.z_per_sec * pct
  end
  return base * (1 + (state.mods and state.mods.global_z or 0))
end

function M.clickCore(state, lx, ly, opts)
  opts = opts or {}
  if state.scene ~= "play" then return end
  local v = clickValue(state)
  state.z = state.z + v
  state.z_lifetime = (state.z_lifetime or 0) + v
  state.z_clicked = (state.z_clicked or 0) + v
  state.click_count = (state.click_count or 0) + 1

  state.corePulse = math.min(1, (state.corePulse or 0) + 0.6)

  local cx, cy = Facility.coreCenter()
  local px = lx or cx + (love.math.random() - 0.5) * 80
  local py = ly or cy + (love.math.random() - 0.5) * 80
  state.floats:emit({
    x = px - 40, y = py - 80,
    text = "+" .. fmt.zeptons(v) .. " Z",
    color = { 0.55, 1, 0.75 },
    size = opts.sustained and 0.9 or 1.0,
    life = opts.sustained and 1.0 or 1.4,
  })
  state.particles:burst({
    x = cx, y = cy,
    n = opts.sustained and 8 or 24,
    color = { 0.30, 1, 0.55 },
    minSpeed = 80, maxSpeed = 360,
    life = 0.9, size = 4,
    kind = "trail",
  })

  if not opts.sustained then
    Audio.click(1)
    Fx.flash("#33ff88", 90, 0.30)
    Fx.shake(0.18, 110)
    Fx.ripple("#33ff88", 0.32, 0.50, 800)
  else
    Audio.miner()
  end
end

-- ============================================================
-- Buy handlers
-- ============================================================

function M.buyMiner(state, def, qty, silent)
  if state.scene ~= "play" then return end
  local owned = state.miners[def.key] or 0
  local toBuy
  if qty == "max" then
    local n, cost = minersDb.maxAffordable(def, owned, state.z)
    if n <= 0 then if not silent then Audio.error_() end; return end
    toBuy = n
  else
    toBuy = qty or 1
    local total = minersDb.totalCost(def, owned, toBuy)
    -- Reduce qty if we can't afford full request
    while toBuy > 0 do
      total = minersDb.totalCost(def, owned, toBuy)
      if total <= state.z then break end
      toBuy = toBuy - 1
    end
    if toBuy <= 0 then if not silent then Audio.error_() end; return end
  end
  local total = minersDb.totalCost(def, owned, toBuy)
  state.z = state.z - total
  state.miners[def.key] = owned + toBuy
  if not silent then
    Audio.buy()
    Fx.glow("#33ff88", 0.45, 320)
    Fx.ripple("#33ff88", 0.42, 0.5, 600)
  end
  M.message(state, string.format("+%d %s", toBuy, def.name), def.color)
  -- Broadcast build to mesh
  Network.notify(state.network, "build", { kind = "miner", key = def.key, count = toBuy })
  -- Particle puff at core
  local cx, cy = Facility.coreCenter()
  state.particles:burst({
    x = cx, y = cy + 200, n = 18,
    color = def.color, minSpeed = 80, maxSpeed = 240,
    life = 1.0, size = 4, kind = "spark",
  })
  recompute(state, love.timer.getTime())
end

function M.buyEnergy(state, def, qty, silent)
  if state.scene ~= "play" then return end
  local owned = state.energy[def.key] or 0
  local toBuy
  if qty == "max" then
    local n = energyDb.maxAffordable(def, owned, state.z)
    if n <= 0 then if not silent then Audio.error_() end; return end
    toBuy = n
  else
    toBuy = qty or 1
    while toBuy > 0 do
      local total = energyDb.totalCost(def, owned, toBuy)
      if total <= state.z then break end
      toBuy = toBuy - 1
    end
    if toBuy <= 0 then if not silent then Audio.error_() end; return end
  end
  local total = energyDb.totalCost(def, owned, toBuy)
  state.z = state.z - total
  state.energy[def.key] = owned + toBuy
  if not silent then
    Audio.power()
    Fx.glow("#ffd866", 0.45, 320)
    Fx.pulse("#ffd866", 600)
  end
  M.message(state, string.format("+%d %s", toBuy, def.name), def.color)
  -- Broadcast build to mesh
  Network.notify(state.network, "build", { kind = "energy", key = def.key, count = toBuy })
  -- Particle puff
  local cx, cy = Facility.coreCenter()
  state.particles:burst({
    x = cx, y = cy - 200, n = 18,
    color = def.color, minSpeed = 80, maxSpeed = 240,
    life = 1.0, size = 4, kind = "spark",
  })
  recompute(state, love.timer.getTime())
end

function M.boost(state, target_id)
  if state.scene ~= "play" then return end
  -- Cost: 5% of current Z, min 25
  local cost = math.max(25, state.z * 0.05)
  if state.z < cost then Audio.error_(); return end
  state.z = state.z - cost
  Network.interact(state.network, target_id, "boost", cost)
  Audio.buy()
  Fx.flash("#5db4ff", 180, 0.45)
  Fx.ripple("#5db4ff", 0.42, 0.5, 800)
  M.message(state, string.format("Boost sent — %s Z", fmt.zeptons(cost)),
    { 0.55, 0.85, 0.95 })
  -- Particles flying out
  local cx, cy = Facility.coreCenter()
  state.particles:burst({
    x = cx, y = cy, n = 40,
    color = { 0.55, 0.85, 1 },
    minSpeed = 250, maxSpeed = 600,
    life = 1.2, size = 4, kind = "trail",
  })
end

function M.joinPool(state, target_id)
  if state.scene ~= "play" then return end
  -- Cost: 1% of Z to join
  local cost = math.max(50, state.z * 0.01)
  if state.z < cost then Audio.error_(); return end
  state.z = state.z - cost
  Network.interact(state.network, target_id, "pool", cost)
  Audio.upgrade()
  Fx.glow("#88aaff", 0.5, 600)
  M.message(state, "Pool sync established", { 0.55, 0.85, 0.95 })
end

function M.leavePool(state)
  Network.interact(state.network, nil, "leave_pool")
  Audio.tab()
  M.message(state, "Pool sync dissolved", { 0.85, 0.55, 0.55 })
end

function M.findBlock(state)
  state.block_height = (state.block_height or 0) + 1
  state.blocks_found = (state.blocks_found or 0) + 1
  state.last_block_at = state.play_time or 0
  -- Halving cycle: base reward halves every HALVING_BLOCKS blocks
  local halvings = math.floor(state.blocks_found / HALVING_BLOCKS)
  local baseReward = 50 * (0.5 ^ halvings)
  local rateReward = state.z_per_sec * 30
  local total = math.max(baseReward, baseReward + rateReward)
  state.z = state.z + total
  state.z_lifetime = (state.z_lifetime or 0) + total

  -- Broadcast to mesh (real-mode) so other players see our block
  Network.notify(state.network, "block", { reward = total, height = state.block_height })

  -- Notification
  M.message(state, string.format("BLOCK #%d FOUND  +%s Z", state.block_height, fmt.zeptons(total)),
    { 1.00, 0.95, 0.55 })

  local cx, cy = Facility.coreCenter()
  state.floats:emit({
    x = cx - 120, y = cy - 80,
    text = string.format("BLOCK +%s Z", fmt.zeptons(total)),
    color = { 1, 0.95, 0.55 },
    size = 1.7, weight = "bold",
    life = 2.2, vy = -120,
  })
  state.particles:burst({
    x = cx, y = cy, n = 80,
    color = { 1, 0.95, 0.55 },
    minSpeed = 200, maxSpeed = 700,
    life = 1.4, size = 5,
    kind = "trail",
  })
  Audio.upgrade()
  Fx.flash("#ffe066", 220, 0.55)
  Fx.glow("#ffe066", 0.6, 700)
  Fx.ripple("#ffe066", 0.42, 0.5, 1100)

  if halvings > (state._lastHalvingNotice or -1) then
    state._lastHalvingNotice = halvings
    if halvings > 0 then
      M.message(state, string.format("HALVING #%d — base reward → %d Z", halvings, math.floor(baseReward)),
        { 0.85, 0.65, 1 })
      Fx.invert(180)
      Fx.shatter(0.35, 600)
      Network.notify(state.network, "halving", { count = halvings, base = math.floor(baseReward) })
    end
  end
end

function M.buyUpgrade(state, def)
  if state.scene ~= "play" then return end
  if state.upgrades[def.key] then Audio.error_(); return end
  local can, status = upgradesDb.canPurchase(def, state.upgrades)
  if not can then Audio.error_(); return end
  if state.z < def.cost then Audio.error_(); return end
  state.z = state.z - def.cost
  state.upgrades[def.key] = true
  Audio.upgrade()
  M.message(state, "Research: " .. def.name, { 0.65, 0.85, 1 })
  Fx.flash("#5db4ff", 250, 0.5)
  Fx.glow("#5db4ff", 0.8, 600)
  Fx.ripple("#5db4ff", 0.5, 0.5, 1100)
  applyUpgrades(state)
  recompute(state, love.timer.getTime())
end

-- ============================================================
-- Save
-- ============================================================

function M.save(state)
  if state.scene ~= "play" then return end
  local ok, err = Save.save(state)
  if ok then
    M.message(state, "// save synced", { 0.55, 0.85, 0.95 })
  end
end

function M.wipe(state)
  Save.wipe()
end

-- ============================================================
-- Drawing
-- ============================================================

local function getMood(state)
  if state.scene == "intro" then
    return { 0.30, 1, 0.55 }
  end
  -- Slight tint shift if energy stressed
  if state.energy_demand_raw and state.energy_demand_raw > state.energy_supply * 0.95 then
    return { 0.95, 0.45, 0.30 }
  end
  return { 0.30, 1, 0.55 }
end

local function drawBottomBar(state, fonts)
  local y = 1018
  love.graphics.setColor(0.04, 0.07, 0.06, 1)
  love.graphics.rectangle("fill", 0, y, 1920, 1080 - y)
  love.graphics.setColor(0.20, 0.55, 0.32, 0.6)
  love.graphics.line(0, y, 1920, y)

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.40, 0.70, 0.55, 0.95)
  love.graphics.print("A-TEK / ZEPTON OPS / FACILITY ONLINE", 24, 1018 + 14)

  local n = 0
  for _ in pairs(state.upgrades) do n = n + 1 end
  local right = string.format(
    "LIFETIME %s   ::   CLICKED %s   ::   UPGRADES %d/%d",
    fmt.zeptons(state.z_lifetime or 0),
    fmt.zeptons(state.z_clicked or 0),
    n, #upgradesDb.list)
  love.graphics.printf(right, 0, 1018 + 14, 1920 - 24, "right")
end

local function drawPauseOverlay(fonts, t)
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, 0, 1920, 1080)
  love.graphics.setFont(fonts.giant)
  love.graphics.setColor(0.55, 1, 0.75, 1)
  local s = "[ PAUSED ]"
  local w = fonts.giant:getWidth(s)
  love.graphics.print(s, 1920 / 2 - w / 2, 1080 / 2 - 60)
  love.graphics.setFont(fonts.medium)
  love.graphics.setColor(0.75, 0.95, 0.85, 0.85)
  local sub = "press P to resume"
  local sw = fonts.medium:getWidth(sub)
  love.graphics.print(sub, 1920 / 2 - sw / 2, 1080 / 2 + 30)
end

function M.draw(state, fonts, mx, my)
  local t = love.timer.getTime()

  if state.scene == "intro" then
    love.graphics.clear(0.01, 0.04, 0.02, 1)
    Intro.draw(state.intro, t)
    state.particles:draw()
    state.floats:draw(fonts)
    return
  end

  love.graphics.clear(0.01, 0.03, 0.02, 1)

  Hud.draw(state, fonts, t)

  Facility.draw(state, fonts, t, Shaders, getMood(state))

  -- Particles overlay clipped to facility area (canvas-relative, design coords)
  local area = Facility.area()
  love.graphics.setScissor(area.x, area.y, area.w, area.h)
  state.particles:draw()
  state.floats:draw(fonts)
  love.graphics.setScissor()

  Shop.draw(state.shop, state, fonts, t, mx, my)

  drawBottomBar(state, fonts)

  if state.paused then
    drawPauseOverlay(fonts, t)
  end
end

-- ============================================================
-- Input dispatch
-- ============================================================

function M.mousepressed(state, lx, ly, button)
  if state.scene == "intro" then
    Intro.mousepressed(state.intro, lx, ly, button)
    return
  end
  if button == 1 then
    -- Click core?
    if Facility.pointInCore(lx, ly) then
      state.coreHoldDown = true
      M.clickCore(state, lx, ly)
      return
    end
    -- Shop?
    local mods = {
      shift = love.keyboard.isDown("lshift", "rshift"),
      ctrl  = love.keyboard.isDown("lctrl", "rctrl"),
    }
    Shop.mousepressed(state.shop, lx, ly, button, state, {
      onTabChange  = function(id) Audio.tab() end,
      onBuyMiner   = function(def, qty) M.buyMiner(state, def, qty) end,
      onBuyEnergy  = function(def, qty) M.buyEnergy(state, def, qty) end,
      onBuyUpgrade = function(def) M.buyUpgrade(state, def) end,
      onBoost      = function(id) M.boost(state, id) end,
      onPool       = function(id) M.joinPool(state, id) end,
      onLeavePool  = function() M.leavePool(state) end,
    }, mods)
  end
end

function M.mousereleased(state, lx, ly, button)
  if state.scene ~= "play" then return end
  if button == 1 then
    state.coreHoldDown = false
  end
end

function M.mousemoved(state, lx, ly, dx, dy)
  -- noop for now
end

function M.wheelmoved(state, dx, dy)
  if state.scene ~= "play" then return end
  local mx, my = love.mouse.getPosition()
  local sw, sh = love.graphics.getDimensions()
  local sc = math.min(sw / DESIGN_W, sh / DESIGN_H)
  local sdx = (sw - DESIGN_W * sc) * 0.5
  local sdy = (sh - DESIGN_H * sc) * 0.5
  local lx = (mx - sdx) / sc
  local ly = (my - sdy) / sc
  Shop.wheelmoved(state.shop, dx, dy, lx, ly)
end

function M.textinput(state, text)
  if state.scene == "intro" then
    Intro.textinput(state.intro, text)
  end
end

function M.keypressed(state, key)
  if state.scene == "intro" then
    Intro.keypressed(state.intro, key)
    return
  end
  if key == "p" then
    state.paused = not state.paused
    if state.paused then
      Audio.pause()
      Fx.calm("#33ff88", 0.30)
      Fx.pulsate("off")
    else
      Audio.resume()
      Fx.calm("#33ff88", 0.20)
    end
  elseif key == "s" then
    M.save(state)
    Audio.tab()
  elseif key == "1" then
    Shop.setTab(state.shop, "miners"); Audio.tab()
  elseif key == "2" then
    Shop.setTab(state.shop, "energy"); Audio.tab()
  elseif key == "3" then
    Shop.setTab(state.shop, "upgrades"); Audio.tab()
  elseif key == "4" then
    Shop.setTab(state.shop, "network"); Audio.tab()
  elseif key == "escape" then
    -- Try clean exit
    M.save(state)
    love.event.quit()
  end
end

function M.focus(state, hasFocus)
  if state.scene ~= "play" then return end
  if not hasFocus then
    state.paused = true
    Audio.pause()
  else
    -- Don't auto-resume; let user press P
  end
end

function M.quit(state)
  M.save(state)
end

return M
