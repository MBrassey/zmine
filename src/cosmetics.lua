-- Cosmetics: earned via progression, auto-equipped best-per-slot.
-- Rendered by src/character.lua via the `effects` field on the character.
--
-- Slots: skin / shirt / pants / accent (palette presets the player can cycle)
--        trail / aura / halo / wings (visual effects unlocked by play)

local M = {}

-- ============================================================
-- Body palette presets (cycle with [C] in world view)
-- ============================================================

M.palettes = {
  { key = "default", name = "Operator A",
    skin = { 0.95, 0.78, 0.62 }, shirt = { 0.30, 0.60, 1.00 },
    pants = { 0.18, 0.22, 0.35 }, accent = { 0.30, 1.00, 0.55 } },
  { key = "noir",    name = "Field Tech",
    skin = { 0.78, 0.62, 0.50 }, shirt = { 0.10, 0.10, 0.15 },
    pants = { 0.05, 0.05, 0.10 }, accent = { 0.85, 0.90, 1.00 } },
  { key = "neon",    name = "Neon Operator",
    skin = { 0.92, 0.78, 0.70 }, shirt = { 0.95, 0.18, 0.55 },
    pants = { 0.10, 0.08, 0.18 }, accent = { 0.45, 1.00, 0.95 } },
  { key = "solar",   name = "Solar Engineer",
    skin = { 0.70, 0.55, 0.40 }, shirt = { 1.00, 0.78, 0.30 },
    pants = { 0.45, 0.25, 0.10 }, accent = { 1.00, 0.95, 0.55 } },
  { key = "void",    name = "Voidwalker",
    skin = { 0.60, 0.55, 0.65 }, shirt = { 0.20, 0.10, 0.30 },
    pants = { 0.05, 0.02, 0.10 }, accent = { 0.85, 0.55, 1.00 } },
  { key = "chrome",  name = "Chrome Tycoon",
    skin = { 0.90, 0.85, 0.78 }, shirt = { 0.65, 0.70, 0.78 },
    pants = { 0.30, 0.32, 0.38 }, accent = { 1.00, 0.90, 0.55 } },
  { key = "synth",   name = "Synthwave",
    skin = { 0.95, 0.78, 0.72 }, shirt = { 0.18, 0.10, 0.35 },
    pants = { 0.40, 0.10, 0.45 }, accent = { 1.00, 0.45, 0.85 } },
}

M.palettesByKey = {}
for _, p in ipairs(M.palettes) do M.palettesByKey[p.key] = p end

-- ============================================================
-- Effect catalog
-- Each entry: key, slot, name, color, tier (rank), unlock(state) -> bool
-- ============================================================

local function any(state, t)
  if t.lifetime_z and (state.z_lifetime or 0) >= t.lifetime_z then return true end
  if t.has_miner and (state.miners[t.has_miner] or 0) >= (t.count or 1) then return true end
  if t.has_energy and (state.energy[t.has_energy] or 0) >= (t.count or 1) then return true end
  if t.blocks and (state.blocks_found or 0) >= t.blocks then return true end
  if t.boosts and state.network and (state.network.boostCount or 0) >= t.boosts then return true end
  if t.upgrade and state.upgrades[t.upgrade] then return true end
  if t.miner_count and (state.miner_count or 0) >= t.miner_count then return true end
  return false
end

M.catalog = {
  -- Trails
  { key = "trail_spark",       slot = "trail", name = "Spark Trail",
    color = { 0.45, 1.00, 0.65 }, tier = 1,
    cond = { has_miner = "asic_z1" } },
  { key = "trail_zepton",      slot = "trail", name = "Zepton Drip",
    color = { 0.30, 1.00, 0.55 }, tier = 2,
    cond = { lifetime_z = 1e3 } },
  { key = "trail_gpu",         slot = "trail", name = "RGB Pixel Stream",
    color = { 0.40, 0.85, 1.00 }, tier = 3,
    cond = { has_miner = "gpu_cluster" } },
  { key = "trail_matrix",      slot = "trail", name = "Matrix Rain",
    color = { 0.30, 1.00, 0.45 }, tier = 4,
    cond = { has_miner = "quantum_miner" } },
  { key = "trail_neural",      slot = "trail", name = "Neural Wisps",
    color = { 1.00, 0.45, 0.85 }, tier = 5,
    cond = { has_miner = "neural_forge" } },
  { key = "trail_warp",        slot = "trail", name = "Warp Wake",
    color = { 1.00, 0.65, 0.35 }, tier = 6,
    cond = { has_miner = "hyperdrive_rig" } },
  { key = "trail_singularity", slot = "trail", name = "Event-Horizon Wake",
    color = { 1.00, 0.40, 0.50 }, tier = 7,
    cond = { has_miner = "singularity_engine" } },
  { key = "trail_eon",         slot = "trail", name = "Eon Echoes",
    color = { 1.00, 0.88, 0.40 }, tier = 8,
    cond = { has_miner = "eonchamber" } },

  -- Auras (ring at feet)
  { key = "aura_ember",     slot = "aura", name = "Ember Halo",
    color = { 1.00, 0.55, 0.30 }, tier = 1,
    cond = { has_energy = "solar" } },
  { key = "aura_wind",      slot = "aura", name = "Cyclone",
    color = { 0.55, 0.85, 1.00 }, tier = 2,
    cond = { has_energy = "wind" } },
  { key = "aura_river",     slot = "aura", name = "Riverflow Ring",
    color = { 0.30, 0.75, 1.00 }, tier = 3,
    cond = { has_energy = "hydro" } },
  { key = "aura_magma",     slot = "aura", name = "Magma Pool",
    color = { 1.00, 0.45, 0.30 }, tier = 4,
    cond = { has_energy = "geothermal" } },
  { key = "aura_fission",   slot = "aura", name = "Cherenkov Glow",
    color = { 0.45, 1.00, 0.55 }, tier = 5,
    cond = { has_energy = "fission" } },
  { key = "aura_fusion",    slot = "aura", name = "Plasma Toroid",
    color = { 0.85, 1.00, 0.30 }, tier = 6,
    cond = { has_energy = "fusion" } },
  { key = "aura_antimatter",slot = "aura", name = "Annihilation",
    color = { 1.00, 0.30, 0.70 }, tier = 7,
    cond = { has_energy = "antimatter" } },
  { key = "aura_zeropoint", slot = "aura", name = "ZPT Shimmer",
    color = { 0.85, 0.80, 1.00 }, tier = 8,
    cond = { has_energy = "zeropoint" } },

  -- Halos / crowns (above head)
  { key = "crown_kilo",     slot = "halo", name = "Kilozepton Crown",
    color = { 0.55, 1.00, 0.75 }, tier = 1,
    cond = { lifetime_z = 1e3 } },
  { key = "crown_mega",     slot = "halo", name = "Megazepton Crown",
    color = { 0.85, 1.00, 0.55 }, tier = 2,
    cond = { lifetime_z = 1e6 } },
  { key = "crown_giga",     slot = "halo", name = "Gigazepton Crown",
    color = { 1.00, 0.85, 0.45 }, tier = 3,
    cond = { lifetime_z = 1e9 } },
  { key = "crown_tera",     slot = "halo", name = "Terazepton Crown",
    color = { 1.00, 0.45, 0.85 }, tier = 4,
    cond = { lifetime_z = 1e12 } },
  { key = "halo_blocks",    slot = "halo", name = "Blockfinder's Halo",
    color = { 1.00, 0.95, 0.55 }, tier = 5,
    cond = { blocks = 10 } },
  { key = "halo_singularity", slot = "halo", name = "Singularity Halo",
    color = { 1.00, 0.40, 0.50 }, tier = 6,
    cond = { has_miner = "singularity_engine" } },
  { key = "halo_eon",       slot = "halo", name = "Eon Halo",
    color = { 1.00, 0.88, 0.40 }, tier = 7,
    cond = { has_miner = "eonchamber" } },

  -- Wings / shoulder pieces (back)
  { key = "wings_solar",    slot = "wings", name = "Photon Sails",
    color = { 1.00, 0.85, 0.35 }, tier = 1,
    cond = { has_energy = "solar", count = 5 } },
  { key = "wings_neural",   slot = "wings", name = "Neural Wings",
    color = { 1.00, 0.45, 0.85 }, tier = 2,
    cond = { has_miner = "neural_forge" } },
  { key = "wings_hyperdrive", slot = "wings", name = "Warp Drives",
    color = { 1.00, 0.65, 0.35 }, tier = 3,
    cond = { has_miner = "hyperdrive_rig" } },
  { key = "wings_eon",      slot = "wings", name = "Eon Wings",
    color = { 1.00, 0.88, 0.40 }, tier = 4,
    cond = { has_miner = "eonchamber" } },

  -- Sparkles (extra atmospheric, always-on once unlocked)
  { key = "sparkle_giver",  slot = "sparkle", name = "Generous Aura",
    color = { 0.55, 0.85, 1.00 }, tier = 1,
    cond = { boosts = 1 } },
  { key = "sparkle_pool",   slot = "sparkle", name = "Pool Sync",
    color = { 0.55, 0.85, 0.95 }, tier = 2,
    cond = { boosts = 10 } },
  { key = "sparkle_endgame",slot = "sparkle", name = "Endgame Glitter",
    color = { 1.00, 0.88, 0.40 }, tier = 3,
    cond = { upgrade = "global_2" } },
}

M.byKey = {}
for _, c in ipairs(M.catalog) do M.byKey[c.key] = c end

-- ============================================================
-- Earn / equip logic
-- ============================================================

function M.checkUnlocks(cos, state)
  local newlyEarned = {}
  for _, def in ipairs(M.catalog) do
    if not cos.earned[def.key] and any(state, def.cond) then
      cos.earned[def.key] = true
      table.insert(newlyEarned, def)
    end
  end
  M.autoEquip(cos)
  return newlyEarned
end

function M.autoEquip(cos)
  -- For each slot, equip the highest-tier earned cosmetic. Player can
  -- override later via a customize UI — we never overwrite an explicit
  -- player choice once `cos.locked[slot]` is set.
  cos.equipped = cos.equipped or {}
  cos.locked   = cos.locked   or {}
  local bestPerSlot = {}
  for _, def in ipairs(M.catalog) do
    if cos.earned[def.key] then
      local b = bestPerSlot[def.slot]
      if not b or (def.tier or 0) > (b.tier or 0) then
        bestPerSlot[def.slot] = def
      end
    end
  end
  for slot, def in pairs(bestPerSlot) do
    if not cos.locked[slot] then
      cos.equipped[slot] = def.key
    end
  end
end

function M.cyclePalette(cos, dir)
  cos.palette = cos.palette or "default"
  local idx = 1
  for i, p in ipairs(M.palettes) do
    if p.key == cos.palette then idx = i; break end
  end
  idx = idx + (dir or 1)
  while idx < 1 do idx = idx + #M.palettes end
  while idx > #M.palettes do idx = idx - #M.palettes end
  cos.palette = M.palettes[idx].key
  return M.palettes[idx]
end

function M.cycleSlot(cos, slot, dir)
  -- Cycle equipped cosmetic through earned options for the given slot.
  local options = {}
  for _, def in ipairs(M.catalog) do
    if def.slot == slot and cos.earned[def.key] then
      table.insert(options, def)
    end
  end
  if #options == 0 then return nil end
  table.sort(options, function(a, b) return (a.tier or 0) < (b.tier or 0) end)
  local cur = cos.equipped[slot]
  local idx = 0
  for i, opt in ipairs(options) do if opt.key == cur then idx = i; break end end
  idx = idx + (dir or 1)
  if idx < 0 then idx = #options + 1 end
  if idx > #options then idx = 0 end  -- 0 means "hide this slot"
  if idx == 0 then
    cos.equipped[slot] = nil
    cos.locked[slot]   = true
    return nil
  end
  cos.equipped[slot] = options[idx].key
  cos.locked[slot]   = true
  return options[idx]
end

function M.fresh()
  return {
    palette  = "default",
    equipped = {},  -- slot -> key
    locked   = {},  -- slot -> true if player has manually overridden
    earned   = {},  -- key -> true
  }
end

function M.applyTo(character, cos)
  -- Push palette into the character struct.
  local p = M.palettesByKey[cos.palette or "default"] or M.palettes[1]
  character.skinColor   = p.skin
  character.shirtColor  = p.shirt
  character.pantsColor  = p.pants
  character.accentColor = p.accent
  character.effects     = {}
  for slot, key in pairs(cos.equipped or {}) do
    local def = M.byKey[key]
    if def then character.effects[slot] = def end
  end
end

return M
