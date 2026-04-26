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
local World      = require "src.world"
local Cosmetics  = require "src.cosmetics"
local Console    = require "src.console"

local M = {}

local json = require "lib.json"

local DESIGN_W, DESIGN_H = 1920, 1080
local SAVE_INTERVAL = 15
local AUTOBUY_INTERVAL = 30
local BLOCK_INTERVAL = 60
local HALVING_BLOCKS = 100
local HASH_PER_PRODUCE = 110e12
local PROFILE_INTERVAL = 30  -- write public_profile.json every N seconds

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
    cosmetics     = Cosmetics.fresh(),
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
  s.cosmetics      = s.cosmetics or Cosmetics.fresh()
  s.cosmetics.equipped = s.cosmetics.equipped or {}
  s.cosmetics.locked   = s.cosmetics.locked   or {}
  s.cosmetics.earned   = s.cosmetics.earned   or {}
  s.cosmetics.palette  = s.cosmetics.palette  or "default"
end

-- ============================================================
-- Modifier computation
-- ============================================================

local function freshMods()
  local m = {
    click_add        = 0,
    click_pct        = 0,
    mult_miners      = 0,
    energy_eff       = 0,
    miner_kind       = {},
    energy_kind      = {},
    network          = 0,
    crit_chance      = 0,
    crit_mult        = 1,
    buffer           = 0,
    autobuy_miners   = false,
    autobuy_energy   = false,
    autobuy_rate     = 30,    -- seconds between auto-buy ticks
    speed            = 0,
    global_z         = 0,
    surge_extend     = 0,     -- multiplier on surge duration
    surge_mult_bonus = 0,     -- additive bonus to surge mult
    pool_in_bonus    = 0,     -- bonus on pool partner contribution
    streak_cap       = 20,    -- max click streak count
    block_reward     = 0,     -- additive multiplier on block reward
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
      elseif e.type == "mult_miner_kind_multi" then
        for _, k in ipairs(e.keys) do
          m.miner_kind[k] = (m.miner_kind[k] or 1) + e.amount
        end
      elseif e.type == "autobuy_rate" then
        m.autobuy_rate = math.min(m.autobuy_rate, e.amount)
      elseif e.type == "surge_extend" then
        m.surge_extend = math.max(m.surge_extend, e.amount)
      elseif e.type == "surge_mult_bonus" then
        m.surge_mult_bonus = math.max(m.surge_mult_bonus, e.amount)
      elseif e.type == "pool_in_bonus" then
        m.pool_in_bonus = math.max(m.pool_in_bonus, e.amount)
      elseif e.type == "streak_cap" then
        m.streak_cap = math.max(m.streak_cap, e.amount)
      elseif e.type == "block_reward" then
        m.block_reward = m.block_reward + e.amount
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
  -- Surge multiplier from slug-wide global state, plus any local
  -- surge_mult_bonus upgrades.
  local surgeMult = state.network and Network.surgeMultiplier(state.network) or 0
  if surgeMult > 0 then
    surgeMult = surgeMult + (state.mods and state.mods.surge_mult_bonus or 0)
    rawRate = rawRate * (1 + surgeMult)
  end
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
  state.hashrate = rawRate * HASH_PER_PRODUCE
  state.difficulty = 0.5e12 * (1 + (state.block_height or 0) * 0.012)
  state.surge_mult = surgeMult
  state.surge_remaining = state.network and Network.surgeRemaining(state.network) or 0
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

  -- Cosmetic unlocks (cheap to recheck each tick) — celebrate on the
  -- character (world view) AND the orb (core ops view).
  if state.cosmetics then
    local newCos = Cosmetics.checkUnlocks(state.cosmetics, state)
    for _, def in ipairs(newCos) do
      state._cosmeticToast = { name = def.name, color = def.color, t = love.timer.getTime() }
      Audio.cosmetic()
      Audio.duckHum(0.40, 300)
      local hex = string.format("#%02x%02x%02x",
        math.floor(def.color[1]*255), math.floor(def.color[2]*255), math.floor(def.color[3]*255))
      Fx.flash(hex, 280, 0.6)
      Fx.glow(hex, 0.7, 800)
      Fx.ripple(hex, 0.5, 0.5, 1400)
      Fx.shatter(0.35, 600)
      M.message(state, "✦ Cosmetic: " .. def.name, def.color)
      -- Burst on the character (world view) — use the camera-aware
      -- helper so particles land on the actual character position.
      if state.world and state.world.char then
        local sx, sy = World.toAbsScreen(state.world.char.wx, state.world.char.wy, 0)
        state.particles:burst({
          x = sx, y = sy - 30, n = 50,
          color = { def.color[1], def.color[2], def.color[3] },
          minSpeed = 100, maxSpeed = 380,
          life = 1.6, size = 4,
          kind = "trail",
        })
      end
      -- Burst on the orb (core ops view) too
      local cx, cy = Facility.coreCenter()
      state.particles:burst({
        x = cx, y = cy, n = 50,
        color = { def.color[1], def.color[2], def.color[3] },
        minSpeed = 120, maxSpeed = 420,
        life = 1.4, size = 4,
        kind = "trail",
      })
      state.floats:emit({
        x = cx - 80, y = cy - 110,
        text = "✦ " .. def.name,
        color = { def.color[1], def.color[2], def.color[3] },
        size = 1.5, weight = "bold", life = 2.0, vy = -110,
      })
    end
  end

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
    state.cosmetics     = data.cosmetics or Cosmetics.fresh()
    ensureCompleteState(state)
  end

  -- World view is the primary scene: that's where the player physically
  -- places miners + energy and sees the facility grow. Core ops is the
  -- secondary "Z STORE / dashboard" reachable via Tab.
  state.scene          = state.facility_name and "world" or "intro"
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
    if data.network.peer_memory then
      state.network.peer_memory = data.network.peer_memory
    end
    if data.network._broadcastedNewTiers then
      state.network._broadcastedNewTiers = data.network._broadcastedNewTiers
    end
    if data.network._broadcastedBlocks then
      state.network._broadcastedBlocks = data.network._broadcastedBlocks
    end
    if data.network._broadcastedHalvings then
      state.network._broadcastedHalvings = data.network._broadcastedHalvings
    end
  end

  state.world          = World.new(state)
  state.console        = Console.newHistory()

  -- Pre-populate intro scene
  state.intro = Intro.new({
    fonts    = opts.fonts,
    onSubmit = function(name)
      state.facility_name = name
      state.scene = "world"
      -- Grant a starter Solar + ASIC so mining begins as a passive loop
      -- the moment the player walks onto the plot. Manual clicking is a
      -- bonus, not the bootstrap.
      if (state.energy.solar or 0) == 0 and (state.miners.asic_z1 or 0) == 0 then
        state.energy.solar  = 1
        state.miners.asic_z1 = 1
      end
      tryAchievement(state, "name_facility")
      M.message(state, "Facility " .. name .. " online.", { 0.55, 1, 0.75 })
      M.message(state, "Starter rig deployed. Mining is passive; click the core for a bonus.",
        { 0.85, 1, 0.92 })
      M.message(state, "Walk WASD onto a glowing pad to build more. [Tab] for the Z store.",
        { 0.85, 0.95, 1 })
      Audio.power()
      Fx.glow("#33ff88", 0.7, 800)
      Fx.pulse("#33ff88", 700)
      Fx.mood("#0a1a12", 0.18)
      Fx.ripple("#33ff88", 0.5, 0.5, 1300)
      recompute(state, love.timer.getTime())
      M.save(state)
    end,
  })

  applyUpgrades(state)
  recompute(state, 0)

  -- Persistent ambient effects in portal
  Fx.mood("#0a1a12", 0.18)
  Fx.calm("#33ff88", 0.20)
  -- Hide the floating top-right ↩ exit handle. The status-bar exit
  -- button at the bottom is the canonical escape hatch; the floating
  -- overlay was visually intrusive on the canvas. Silent no-op on
  -- older portal builds.
  Fx.hideExitHandle()
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

  -- World scene: tick world. Wrapped in pcall so one bad frame in
  -- the iso pipeline doesn't crash the runtime.
  if state.scene == "world" and state.world then
    local ok, err = pcall(World.update, state.world, state, dt, {
      onBuyMiner  = function(def, qty) M.buyMiner(state, def, qty or 1) end,
      onBuyEnergy = function(def, qty) M.buyEnergy(state, def, qty or 1) end,
    })
    if not ok then
      io.stderr:write("[zmine] World.update: " .. tostring(err) .. "\n")
    end
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
        Audio.crit()
        Audio.duckHum(0.45, 250)
        Fx.flash("#ffd866", 220, 0.75)
        Fx.chroma(0.55, 200)
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

  -- Auto-buy: prefer the highest tier whose unit cost is ≤ 50% of current
  -- balance (so it actually advances tiers instead of grinding T1).
  -- Fallback to the cheapest affordable if nothing fits the budget gate.
  -- Interval is upgrade-driven (autobuy_rate; default 30s, min 15s).
  local autobuyInterval = (state.mods and state.mods.autobuy_rate) or AUTOBUY_INTERVAL
  if love.timer.getTime() - state._lastAutobuy > autobuyInterval then
    state._lastAutobuy = love.timer.getTime()
    local function pickBestMiner()
      local budget = state.z * 0.50
      local best, bestTier
      for _, def in ipairs(minersDb.list) do
        local c = minersDb.unitCost(def, state.miners[def.key] or 0)
        if c <= budget then
          if not best or def.tier > bestTier then best, bestTier = def, def.tier end
        end
      end
      if best then return best end
      -- Fallback: cheapest affordable
      local cheapest, cheapestCost
      for _, def in ipairs(minersDb.list) do
        local c = minersDb.unitCost(def, state.miners[def.key] or 0)
        if c <= state.z and (not cheapestCost or c < cheapestCost) then
          cheapest, cheapestCost = def, c
        end
      end
      return cheapest
    end
    local function pickBestEnergy()
      local budget = state.z * 0.50
      local best, bestTier
      for _, def in ipairs(energyDb.list) do
        local c = energyDb.unitCost(def, state.energy[def.key] or 0)
        if c <= budget then
          if not best or def.tier > bestTier then best, bestTier = def, def.tier end
        end
      end
      if best then return best end
      local cheapest, cheapestCost
      for _, def in ipairs(energyDb.list) do
        local c = energyDb.unitCost(def, state.energy[def.key] or 0)
        if c <= state.z and (not cheapestCost or c < cheapestCost) then
          cheapest, cheapestCost = def, c
        end
      end
      return cheapest
    end
    if state.mods.autobuy_miners then
      local pick = pickBestMiner()
      if pick then M.buyMiner(state, pick, 1, true) end
    end
    if state.mods.autobuy_energy then
      local pick = pickBestEnergy()
      if pick then M.buyEnergy(state, pick, 1, true) end
    end
  end

  -- Network mesh simulation — also pcall-wrapped so a malformed peer
  -- payload (e.g. nil fields from a buggy slug snapshot) can't crash
  -- the runtime.
  local ok, err = pcall(Network.update, state.network, dt, state)
  if not ok then
    io.stderr:write("[zmine] Network.update: " .. tostring(err) .. "\n")
  end
  -- Greet newly-arrived real peers with a chime + ripple + log
  local joined = Network.popJoined and Network.popJoined(state.network) or {}
  for _, p in ipairs(joined) do
    Audio.peerJoin()
    Fx.flash("#5db4ff", 220, 0.40)
    Fx.ripple("#5db4ff", 0.5, 0.5, 1100)
    M.message(state, "★ " .. (p.facility_name or "operator") .. " connected", { 0.55, 0.85, 1 })
  end
  -- Surge transition audio (rising edge only)
  local surgeNow = Network.surgeRemaining(state.network) > 0
  if surgeNow and not state._surgeAnnounced then
    state._surgeAnnounced = true
    Audio.surge()
    Audio.duckHum(0.55, 500)
    Fx.flash("#ff8a3a", 320, 0.65)
    Fx.glow("#ff8a3a", 0.8, 1100)
    Fx.ripple("#ff8a3a", 0.5, 0.5, 1500)
    Fx.zoom(0.06, 500)
    Fx.pulsate("#ff8a3a", 90, 0.30)
    M.message(state, "⚡ GLOBAL SURGE — production +" ..
      math.floor((state.surge_mult or 0.5) * 100) .. "%",
      { 1, 0.55, 0.30 })
  elseif not surgeNow and state._surgeAnnounced then
    state._surgeAnnounced = false
    Fx.pulsate("off")
    M.message(state, "⚡ surge ended", { 0.85, 0.55, 0.30 })
  end

  -- Pool sharing economy (with pool_in_bonus upgrade)
  if state.network.pool_with then
    local outflow, payout = Network.tickPool(state.network, effDt, state.z_per_sec)
    if outflow > 0 then state.z = state.z - outflow end
    if payout > 0 then
      payout = payout * (1 + (state.mods.pool_in_bonus or 0))
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

  -- Live mining console history sampler (4 Hz) — drives the charts
  -- shown in the core ops view.
  if state.console then
    Console.sample(state.console, state, love.timer.getTime())
  end

  -- Periodic save
  if love.timer.getTime() - state._lastSave > SAVE_INTERVAL then
    state._lastSave = love.timer.getTime()
    M.save(state)
  end

  -- Periodic public_profile.json write so peers see our facility when we're offline.
  -- First write fires ~3s after entering play (so stats are populated).
  if not state._lastProfile then
    state._lastProfile = love.timer.getTime() - PROFILE_INTERVAL + 3
  end
  if love.timer.getTime() - state._lastProfile > PROFILE_INTERVAL then
    state._lastProfile = love.timer.getTime()
    M.writeProfile(state)
  end
end

-- ============================================================
-- Click handler
-- ============================================================

-- Click value: base + click_add + click_pct × z_per_sec, with the
-- click_pct component multiplied by the current click streak so active
-- play scales meaningfully even when idle rate dwarfs base click.
local function clickValue(state, streakMult)
  local base = 1 + (state.mods and state.mods.click_add or 0)
  local pct  = state.mods and state.mods.click_pct or 0
  local pctTerm = 0
  if pct > 0 then
    pctTerm = state.z_per_sec * pct * (streakMult or 1)
  end
  return (base + pctTerm) * (1 + (state.mods and state.mods.global_z or 0))
end

function M.clickCore(state, lx, ly, opts)
  opts = opts or {}
  if state.scene ~= "play" then return end

  -- Click streak: consecutive clicks within 1.5s scale value up to 2×
  -- on the base, AND multiply the click_pct component (so a 20-streak
  -- click at click_pct=5% adds 100% of z_per_sec — meaningful at scale).
  -- Streak cap is upgrade-driven (default 20, max 200 with Eldritch Reflex).
  local now = love.timer.getTime()
  local cap = (state.mods and state.mods.streak_cap) or 20
  if (now - (state._lastClickTime or 0)) < 1.5 then
    state.click_streak = math.min(cap, (state.click_streak or 0) + 1)
  else
    state.click_streak = 1
  end
  state._lastClickTime = now
  local streakMult = 1 + math.min(cap, state.click_streak) * 0.05
  local v = clickValue(state, streakMult) * streakMult
  -- Apply surge bonus to click value too
  if state.surge_mult and state.surge_mult > 0 then
    v = v * (1 + state.surge_mult)
  end

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
    Audio.click(streakMult)
    Fx.flash("#33ff88", 90, 0.30 + (streakMult - 1) * 0.20)
    Fx.shake(0.18 + (streakMult - 1) * 0.10, 110)
    Fx.ripple("#33ff88", 0.32, 0.50, 800)
    -- Streak callout every 5 clicks
    if state.click_streak and state.click_streak > 1 and state.click_streak % 5 == 0 then
      state.floats:emit({
        x = (lx or cx) - 60, y = (ly or cy) - 120,
        text = string.format("STREAK ×%d", state.click_streak),
        color = { 1, 0.95, 0.55 },
        size = 1.4, weight = "bold",
        life = 1.6, vy = -110,
      })
    end
  else
    Audio.miner()
  end
end

-- ============================================================
-- Buy handlers
-- ============================================================

-- Tier-up celebration scales by `def.tier`. T1 ASIC is a soft cymbal;
-- T10 Omega Engine is a wall-bending fanfare with shake + extra zoom.
local function celebrateFirstOfTier(state, def, kind)
  local T = def.tier or 1
  Audio.tier()
  Audio.duckHum(0.45 + T * 0.03, 300 + T * 25)
  local hex = string.format("#%02x%02x%02x",
    math.floor(def.color[1]*255), math.floor(def.color[2]*255), math.floor(def.color[3]*255))
  Fx.flash(hex,   260 + T * 12, math.min(0.95, 0.55 + T * 0.04))
  Fx.shatter(math.min(0.55, 0.20 + T * 0.04), 480 + T * 24)
  Fx.zoom(0.025 + T * 0.005, 320 + T * 22)
  Fx.glow(hex,  math.min(0.95, 0.55 + T * 0.04), 700 + T * 40)
  Fx.ripple(hex, 0.5, 0.5, 1100 + T * 50)
  if T >= 6 then Fx.shake(0.18 + math.min(0.30, T * 0.025), 200 + T * 10) end
  if T >= 8 then Fx.chroma(0.35, 220) end

  local cx, cy = Facility.coreCenter()
  state.floats:emit({
    x = cx - 120, y = cy - 100,
    text = string.format("✦ TIER %d UNLOCKED", T),
    color = def.color,
    size = 1.5 + T * 0.05, weight = "bold", life = 2.4, vy = -110,
  })
  state.floats:emit({
    x = cx - 90, y = cy - 70,
    text = def.name,
    color = def.color,
    size = 1.0 + T * 0.04, weight = "bold", life = 2.4, vy = -90,
  })
  state.particles:burst({
    x = cx, y = cy, n = 60 + T * 14,
    color = def.color,
    minSpeed = 180 + T * 12, maxSpeed = 600 + T * 60,
    life = 1.4 + T * 0.06, size = 4 + math.min(4, T * 0.4),
    kind = "trail",
  })
  M.message(state, string.format("✦ TIER %d UNLOCKED — %s", T, def.name), def.color)
end

function M.buyMiner(state, def, qty, silent)
  if state.scene ~= "play" and state.scene ~= "world" then return end
  local owned = state.miners[def.key] or 0
  local toBuy
  if qty == "max" then
    local n, cost = minersDb.maxAffordable(def, owned, state.z)
    if n <= 0 then if not silent then Audio.error_() end; return end
    toBuy = n
  else
    toBuy = qty or 1
    local total = minersDb.totalCost(def, owned, toBuy)
    while toBuy > 0 do
      total = minersDb.totalCost(def, owned, toBuy)
      if total <= state.z then break end
      toBuy = toBuy - 1
    end
    if toBuy <= 0 then if not silent then Audio.error_() end; return end
  end
  local firstOfTier = (owned == 0)
  local total = minersDb.totalCost(def, owned, toBuy)
  state.z = state.z - total
  state.miners[def.key] = owned + toBuy
  if not silent then
    if firstOfTier then
      celebrateFirstOfTier(state, def, "miner")
    else
      Audio.buy()
      local glowI = math.min(0.85, 0.45 + toBuy * 0.04)
      Fx.glow("#33ff88", glowI, 320 + math.min(180, toBuy * 8))
      Fx.ripple("#33ff88", 0.42, 0.5, 600)
      if toBuy >= 5 then Fx.shake(0.18 + math.min(0.30, toBuy * 0.02), 200) end
    end
  end
  M.message(state, string.format("+%d %s", toBuy, def.name), def.color)
  Network.notify(state.network, "build", { kind = "miner", key = def.key, count = toBuy })
  local cx, cy = Facility.coreCenter()
  state.particles:burst({
    x = cx, y = cy + 200, n = 18 + toBuy * 4,
    color = def.color, minSpeed = 80, maxSpeed = 240,
    life = 1.0, size = 4, kind = "spark",
  })
  recompute(state, love.timer.getTime())
end

function M.buyEnergy(state, def, qty, silent)
  if state.scene ~= "play" and state.scene ~= "world" then return end
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
  local firstOfTier = (owned == 0)
  local total = energyDb.totalCost(def, owned, toBuy)
  state.z = state.z - total
  state.energy[def.key] = owned + toBuy
  if not silent then
    if firstOfTier then
      celebrateFirstOfTier(state, def, "energy")
    else
      Audio.power()
      local glowI = math.min(0.85, 0.45 + toBuy * 0.04)
      Fx.glow("#ffd866", glowI, 320 + math.min(180, toBuy * 8))
      Fx.pulse("#ffd866", 600)
      if toBuy >= 5 then Fx.shake(0.18 + math.min(0.30, toBuy * 0.02), 200) end
    end
  end
  M.message(state, string.format("+%d %s", toBuy, def.name), def.color)
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

function M.emoteWave(state)
  if state.scene ~= "world" or not state.world then return end
  Audio.emoteWave()
  Network.notify(state.network, "wave", {
    wx = state.world.char.wx,
    wy = state.world.char.wy,
  })
  state.world.char._waveTimer = 1.4
  state.world._lastSelfWave = love.timer.getTime()
  M.message(state, "Waved at the mesh", { 0.55, 0.85, 1 })
  Fx.ripple("#5db4ff", 0.5, 0.5, 700)
end

function M.plantFlag(state)
  if state.scene ~= "world" or not state.world then return end
  Audio.flagPlant()
  local wx, wy = state.world.char.wx, state.world.char.wy
  Network.notify(state.network, "flag", {
    wx = wx, wy = wy,
    name = state.facility_name,
  })
  state.world.flags = state.world.flags or {}
  table.insert(state.world.flags, {
    wx = wx, wy = wy,
    color = state.cosmetics and { 0.30, 1.00, 0.55 } or { 0.30, 1, 0.55 },
    name = state.facility_name,
    plantedAt = love.timer.getTime(),
    self = true,
  })
  M.message(state, "Flag planted", { 0.55, 1, 0.75 })
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
  if state.scene ~= "play" and state.scene ~= "world" then return end
  -- Send a pool REQUEST. The partner sees an ACCEPT/DECLINE banner;
  -- pool only becomes active if they accept. The 1% Z fee is charged
  -- only on accept (handled in the pool_accept event handler).
  Network.interact(state.network, target_id, "pool")
  Audio.tab()
  Fx.glow("#88aaff", 0.40, 500)
  M.message(state, "Pool request sent — awaiting response", { 0.55, 0.85, 0.95 })
end

function M.acceptPool(state, target_id)
  if state.scene ~= "play" and state.scene ~= "world" then return end
  -- The 1% fee is paid on acceptance.
  local cost = math.max(50, state.z * 0.01)
  if state.z < cost then Audio.error_(); return end
  state.z = state.z - cost
  Network.interact(state.network, target_id, "accept_pool")
  Audio.peerJoin()
  Fx.glow("#88aaff", 0.55, 700)
  M.message(state, "Pool sync established", { 0.55, 0.85, 0.95 })
end

function M.declinePool(state, target_id)
  Network.interact(state.network, target_id, "decline_pool")
  Audio.tab()
  M.message(state, "Pool request declined", { 0.85, 0.55, 0.55 })
end

function M.leavePool(state)
  Network.interact(state.network, nil, "leave_pool")
  Audio.peerLeave()
  M.message(state, "Pool sync dissolved", { 0.85, 0.55, 0.55 })
end

function M.findBlock(state)
  state.block_height = (state.block_height or 0) + 1
  state.blocks_found = (state.blocks_found or 0) + 1
  state.last_block_at = state.play_time or 0
  -- Halving applies to BOTH the floor reward and the rate-tied component
  -- so the deflationary mechanic the UI advertises is real.
  local halvings = math.floor(state.blocks_found / HALVING_BLOCKS)
  local halvingMult = 0.5 ^ halvings
  local baseReward = 50 * halvingMult
  local rateReward = state.z_per_sec * 30 * halvingMult
  local total = (baseReward + rateReward) * (1 + (state.mods and state.mods.block_reward or 0))
  state.z = state.z + total
  state.z_lifetime = (state.z_lifetime or 0) + total

  -- Broadcast to room mesh
  Network.notify(state.network, "block", { reward = total, height = state.block_height })
  -- Advance the slug-wide global block counter (may trigger a surge).
  -- Weight by the player's highest-tier owned miner so endgame slugs
  -- accumulate global blocks faster and surge cadence keeps pace.
  local maxTier = 1
  for _, def in ipairs(minersDb.list) do
    if (state.miners[def.key] or 0) > 0 and def.tier > maxTier then
      maxTier = def.tier
    end
  end
  local tierWeight = math.max(1, math.floor(1 + maxTier / 3))
  Network.maybeAdvanceGlobalBlocks(state.network, state.block_height, tierWeight)
  -- Notify the live console
  if state.console then Console.notifyBlock(state.console, love.timer.getTime()) end

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
  -- Block: distinct gold signature, no Fx.pulse (glow + ripple already
  -- imply rhythm and pulse stacked on top muddied the moment).
  Audio.block()
  Audio.duckHum(0.55, 350)
  Fx.flash("#ffe066", 240, 0.65)
  Fx.glow("#ffe066", 0.7, 800)
  Fx.ripple("#ffe066", 0.42, 0.5, 1300)
  Fx.zoom(0.05, 380)

  if halvings > (state._lastHalvingNotice or -1) then
    state._lastHalvingNotice = halvings
    if halvings > 0 then
      M.message(state, string.format("HALVING #%d — base reward → %d Z", halvings, math.floor(baseReward)),
        { 0.85, 0.65, 1 })
      Audio.halving()
      Audio.duckHum(0.70, 700)
      Fx.flash("#cf8aff", 320, 0.90)
      Fx.invert(180)
      Fx.shatter(0.45, 750)
      Fx.shake(0.30, 240)
      -- Loud float so the rarest event in the loop has the biggest typographic footprint
      local cx, cy = Facility.coreCenter()
      state.floats:emit({
        x = cx - 140, y = cy - 130,
        text = string.format("HALVING #%d", halvings),
        color = { 0.85, 0.65, 1 },
        size = 1.9, weight = "bold",
        life = 3.0, vy = -100,
      })
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
  if state.scene ~= "play" and state.scene ~= "world" then return end
  local ok, err = Save.save(state)
  if ok then
    M.message(state, "// save synced", { 0.55, 0.85, 0.95 })
  end
end

-- Write a small public_profile.json snapshot so peers can see our
-- facility data even when we're offline. Anyone (signed in or not) can
-- read this through the portal's profiles endpoint.
function M.writeProfile(state)
  if not state.facility_name then return end
  local profile = {
    facility_name = state.facility_name,
    z_lifetime    = math.floor(state.z_lifetime or 0),
    z_per_sec     = state.z_per_sec or 0,
    hashrate      = state.hashrate or 0,
    level         = state.z_lifetime and state.z_lifetime > 1
                      and math.log(state.z_lifetime) / math.log(10)
                      or 0,
    block_height  = state.block_height or 0,
    miner_count   = state.miner_count or 0,
    palette       = (state.cosmetics and state.cosmetics.palette) or "default",
    accent_color  = state.cosmetics and state.cosmetics.equipped and state.cosmetics.equipped.aura,
    updated_at    = os.time(),
  }
  local ok, encoded = pcall(json.encode, profile)
  if ok and #encoded < 32000 then
    love.filesystem.write("public_profile.json", encoded)
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

-- Wrap a renderer in pcall so a latent runtime error in one panel
-- doesn't crash the whole game. The error is logged once to stderr
-- (visible in the browser console) and a small RENDER-FAULT badge is
-- shown so the player knows something went wrong.
local function protect(fn, label)
  local ok, err = pcall(fn)
  if not ok then
    if not protect._seen then protect._seen = {} end
    if not protect._seen[label] then
      protect._seen[label] = true
      io.stderr:write("[zmine] render fault in " .. label .. ": " .. tostring(err) .. "\n")
    end
    return err
  end
end

function M.draw(state, fonts, mx, my)
  local t = love.timer.getTime()

  if state.scene == "intro" then
    love.graphics.clear(0.01, 0.04, 0.02, 1)
    protect(function() Intro.draw(state.intro, t) end, "Intro.draw")
    state.particles:draw()
    state.floats:draw(fonts)
    return
  end

  if state.scene == "world" and state.world then
    protect(function() World.draw(state.world, state, fonts, t) end, "World.draw")
    state.particles:draw()
    state.floats:draw(fonts)
    protect(function() Hud.draw(state, fonts, t) end, "Hud.draw")
    drawBottomBar(state, fonts)
    if state.paused then drawPauseOverlay(fonts, t) end
    return
  end

  love.graphics.clear(0.01, 0.03, 0.02, 1)

  protect(function() Hud.draw(state, fonts, t) end, "Hud.draw")

  protect(function() Facility.draw(state, fonts, t, Shaders, getMood(state)) end, "Facility.draw")

  -- Live mining console (wrapped in pcall — a latent error in one
  -- chart panel won't take down the whole ops view).
  if state.console then
    local area = Facility.area()
    local cw = 320
    local cx = area.x + area.w - cw - 12
    local cy = area.y + 200
    local ch = area.h - 290
    protect(function()
      Console.draw(state.console, state, fonts, t, cx, cy, cw, ch)
    end, "Console.draw")
  end

  -- Particles overlay clipped to facility area (canvas-relative, design coords)
  local area = Facility.area()
  love.graphics.setScissor(area.x, area.y, area.w, area.h)
  state.particles:draw()
  state.floats:draw(fonts)
  love.graphics.setScissor()

  protect(function() Shop.draw(state.shop, state, fonts, t, mx, my) end, "Shop.draw")

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
  -- HUD scene-toggle icons are click-routable from BOTH scenes.
  if button == 1 and state._hudButtons then
    for _, b in ipairs(state._hudButtons) do
      if lx >= b.x and lx <= b.x + b.w and ly >= b.y and ly <= b.y + b.h then
        if b.kind == "scene" and b.scene ~= state.scene then
          if b.scene == "world" then
            state.scene = "world"
            Audio.worldSwoosh()
            Fx.flash("#33ff88", 180, 0.30)
          else
            state.scene = "play"
            state._sawCoreOps = true
            Audio.worldSwoosh()
            Fx.flash("#33ff88", 180, 0.30)
          end
        end
        return
      end
    end
  end
  if state.scene == "world" then
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
      onTabChange   = function(id) Audio.tab() end,
      onBuyMiner    = function(def, qty) M.buyMiner(state, def, qty) end,
      onBuyEnergy   = function(def, qty) M.buyEnergy(state, def, qty) end,
      onBuyUpgrade  = function(def) M.buyUpgrade(state, def) end,
      onBoost       = function(id) M.boost(state, id) end,
      onPool        = function(id) M.joinPool(state, id) end,
      onLeavePool   = function() M.leavePool(state) end,
      onAcceptPool  = function(id) M.acceptPool(state, id) end,
      onDeclinePool = function(id) M.declinePool(state, id) end,
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
  -- Cross-scene keys (handled before scene-specific routing): save + pause
  if key == "s" then
    M.save(state)
    Audio.tab()
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
    return
  end

  -- Scene toggle: Tab moves browser focus out of the iframe (it's NOT
  -- in the portal's preventDefault list — only space + arrow keys are),
  -- which fires love.focus(false) and auto-pauses the game so the
  -- screen ends up looking blank. Bind primarily to SPACE (which IS
  -- preventDefaulted by the portal) and accept Tab/Q as aliases. The
  -- focus-loss guard in M.focus also kills the auto-pause within 1 s
  -- of any scene toggle so even Tab still works without the blank-
  -- screen bug.
  local isToggle = (key == "space" or key == "tab" or key == "q")

  -- World view scoped keys
  if state.scene == "world" and state.world then
    if isToggle then
      state.scene = "play"
      state._sawCoreOps = true
      state._lastSceneToggleAt = love.timer.getTime()
      Audio.worldSwoosh()
      Fx.flash("#33ff88", 180, 0.30)
      return
    end
    World.keypressed(state.world, state, key, {
      toCore     = function()
        state.scene = "play"; state._sawCoreOps = true
        state._lastSceneToggleAt = love.timer.getTime()
        Audio.worldSwoosh(); Fx.flash("#33ff88", 180, 0.30)
      end,
      onMessage  = function(msg, color) M.message(state, msg, color); Audio.tab() end,
      onWave     = function() M.emoteWave(state) end,
      onFlag     = function() M.plantFlag(state) end,
    })
    return
  end
  if isToggle then
    state.scene = "world"
    state._lastSceneToggleAt = love.timer.getTime()
    Audio.worldSwoosh()
    Fx.flash("#33ff88", 180, 0.30)
    return
  end
  if key == "1" then
    Shop.setTab(state.shop, "miners"); Audio.tab()
  elseif key == "2" then
    Shop.setTab(state.shop, "energy"); Audio.tab()
  elseif key == "3" then
    Shop.setTab(state.shop, "upgrades"); Audio.tab()
  elseif key == "4" then
    Shop.setTab(state.shop, "network"); Audio.tab()
  elseif key == "escape" then
    -- Two-step quit: first Esc warns, second within 4 s saves + quits.
    local now = love.timer.getTime()
    if state._escAt and (now - state._escAt) < 4 then
      M.save(state)
      love.event.quit()
    else
      state._escAt = now
      M.message(state, "Press Esc again within 4s to quit (save first)", { 1, 0.85, 0.55 })
      Audio.error_()
    end
  end
end

function M.focus(state, hasFocus)
  if not hasFocus then
    -- Focus-loss guard: if the player just toggled scenes (e.g. via
    -- Tab, which the browser also uses for focus management on top of
    -- our keypress handler), don't pause — they're still playing.
    local sinceToggle = love.timer.getTime() - (state._lastSceneToggleAt or -10)
    if sinceToggle < 1.0 then return end
    state.paused = true
    Audio.pause()
  else
    state.paused = false
    Audio.resume()
  end
end

function M.quit(state)
  M.save(state)
end

return M
