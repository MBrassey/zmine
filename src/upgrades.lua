-- Research / upgrade tree. Each upgrade is one-time purchase.
-- Effects are applied to the global modifier table; see game.applyUpgrades().

local M = {}

M.list = {
  -- Click amplifiers
  { key = "click_1", name = "Manual Drift",       desc = "+5 Z per click.",
    cost = 100,         effect = { type = "click_add", amount = 5 } },
  { key = "click_2", name = "Tactile Feedback",   desc = "+50 Z per click.",
    cost = 8000,        effect = { type = "click_add", amount = 50 } },
  { key = "click_2b", name = "Inertial Drift",    desc = "+250 Z per click.",
    cost = 60000,       effect = { type = "click_add", amount = 250 },
    requires = { "click_2" } },
  { key = "click_3", name = "Resonant Touch",     desc = "Click yields 0.5% of Z/s (streak-amplified).",
    cost = 250000,      effect = { type = "click_pct", amount = 0.005 },
    requires = { "click_2b" } },
  { key = "click_4", name = "Hyperclick",         desc = "Click yields 2% of Z/s (streak-amplified).",
    cost = 50000000,    effect = { type = "click_pct", amount = 0.02 },
    requires = { "click_3" } },

  -- Global mining multipliers
  { key = "mult_1", name = "Hash Acceleration I",  desc = "+25% miner output.",
    cost = 1500,        effect = { type = "mult_miners", amount = 0.25 } },
  { key = "mult_2", name = "Hash Acceleration II", desc = "+50% miner output.",
    cost = 75000,       effect = { type = "mult_miners", amount = 0.5 },
    requires = { "mult_1" } },
  { key = "mult_3", name = "Hash Acceleration III", desc = "+100% miner output.",
    cost = 6500000,     effect = { type = "mult_miners", amount = 1.0 },
    requires = { "mult_2" } },
  { key = "mult_4", name = "Hash Acceleration IV", desc = "+150% miner output.",
    cost = 850000000,   effect = { type = "mult_miners", amount = 1.5 },
    requires = { "mult_3" } },

  -- Energy efficiency
  { key = "eff_1", name = "Power Conditioning I",  desc = "Miners use 10% less energy.",
    cost = 7000,        effect = { type = "energy_eff", amount = 0.10 } },
  { key = "eff_2", name = "Power Conditioning II", desc = "Miners use 20% less energy total.",
    cost = 350000,      effect = { type = "energy_eff", amount = 0.20 },
    requires = { "eff_1" } },
  { key = "eff_3", name = "Power Conditioning III", desc = "Miners use 35% less energy total.",
    cost = 35000000,    effect = { type = "energy_eff", amount = 0.35 },
    requires = { "eff_2" } },

  -- Per-tier miner boosts
  { key = "boost_quantum", name = "Quantum Sync",    desc = "Quantum Miners produce 2×.",
    cost = 150000,      effect = { type = "mult_miner_kind", key = "quantum_miner", amount = 1.0 } },
  { key = "boost_neural",  name = "Neural Bias",     desc = "Neural Forges produce 2×.",
    cost = 1500000,     effect = { type = "mult_miner_kind", key = "neural_forge", amount = 1.0 } },
  { key = "boost_hyper",   name = "Hyperdrive Boost", desc = "Hyperdrive Rigs produce 2×.",
    cost = 15000000,    effect = { type = "mult_miner_kind", key = "hyperdrive_rig", amount = 1.0 } },
  { key = "boost_singularity", name = "Singularity Pull", desc = "Singularity Engines produce 2×.",
    cost = 150000000,   effect = { type = "mult_miner_kind", key = "singularity_engine", amount = 1.0 } },

  -- Per-tier energy boosts
  { key = "energy_solar",  name = "Solar Lens Array", desc = "Solar arrays output 2×.",
    cost = 6500,        effect = { type = "mult_energy_kind", key = "solar", amount = 1.0 } },
  { key = "energy_wind",   name = "Variable Pitch",   desc = "Wind turbines output 2×.",
    cost = 30000,       effect = { type = "mult_energy_kind", key = "wind", amount = 1.0 } },
  { key = "energy_hydro",  name = "Hydro Surge",      desc = "Hydroelectric output 2×.",
    cost = 280000,      effect = { type = "mult_energy_kind", key = "hydro", amount = 1.0 } },
  { key = "energy_reactor", name = "Reactor Tuning",  desc = "Fission/Fusion output 2×.",
    cost = 7500000,     effect = { type = "mult_energy_kind_multi", keys = { "fission", "fusion" }, amount = 1.0 } },

  -- Network effects
  { key = "network",  name = "Resonance Network",   desc = "Each miner adds +0.1% to all miner output.",
    cost = 1200000,     effect = { type = "network", amount = 0.001 } },
  { key = "network2", name = "Quantum Mesh",        desc = "Each miner adds +0.25% to all miner output total.",
    cost = 80000000,    effect = { type = "network", amount = 0.0025 },
    requires = { "network" } },

  -- Crit system
  { key = "crit_1", name = "Lucky Pulse",     desc = "1% chance per tick to mine 50× value.",
    cost = 280000,      effect = { type = "crit", chance = 0.01, mult = 50 } },
  { key = "crit_2", name = "Quantum Luck",    desc = "Crit chance 5%, multiplier 50×.",
    cost = 6500000,     effect = { type = "crit", chance = 0.05, mult = 50 },
    requires = { "crit_1" } },
  { key = "crit_3", name = "Megacrit",        desc = "Crit chance 10%, multiplier 1000×.",
    cost = 250000000,   effect = { type = "crit", chance = 0.10, mult = 1000 },
    requires = { "crit_2" } },

  -- Convenience / endgame
  { key = "buffer",   name = "Bus Voltage Buffer",  desc = "+50% energy headroom (buffer above net positive).",
    cost = 180000,      effect = { type = "buffer", amount = 0.5 } },
  { key = "autobuy_1", name = "Auto-Buy: Miners",   desc = "Auto-buys cheapest miner every 30s when affordable.",
    cost = 2500000,     effect = { type = "autobuy", target = "miners" } },
  { key = "autobuy_2", name = "Auto-Buy: Energy",   desc = "Auto-buys cheapest energy every 30s when affordable.",
    cost = 9500000,     effect = { type = "autobuy", target = "energy" },
    requires = { "autobuy_1" } },
  { key = "compress", name = "Time Compression",   desc = "Game runs 1.5× faster.",
    cost = 65000000,    effect = { type = "speed", amount = 0.5 } },
  { key = "global_1", name = "Z-Multiplier I",      desc = "All zepton production +25%.",
    cost = 600000000,   effect = { type = "global_z", amount = 0.25 } },
  { key = "global_2", name = "Z-Multiplier II",     desc = "All zepton production +50% total.",
    cost = 8000000000,  effect = { type = "global_z", amount = 0.50 },
    requires = { "global_1" } },
}

M.byKey = {}
for _, u in ipairs(M.list) do
  M.byKey[u.key] = u
end

function M.canPurchase(def, owned)
  if owned[def.key] then return false, "owned" end
  if def.requires then
    for _, req in ipairs(def.requires) do
      if not owned[req] then return false, "locked" end
    end
  end
  return true
end

return M
