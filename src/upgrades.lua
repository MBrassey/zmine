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

  -- ============================================================
  -- Late-game expansion: per-tier ladders for the new endgame rigs.
  -- ============================================================

  -- Mining multiplier ladder
  { key = "mult_5", name = "Hash Acceleration V",   desc = "+200% miner output total.",
    cost = 1.5e11,      effect = { type = "mult_miners", amount = 2.0 },
    requires = { "mult_4" } },
  { key = "mult_6", name = "Hash Acceleration VI",  desc = "+300% miner output total.",
    cost = 4.5e12,      effect = { type = "mult_miners", amount = 3.0 },
    requires = { "mult_5" } },
  { key = "mult_7", name = "Hash Acceleration VII", desc = "+500% miner output total.",
    cost = 9.0e13,      effect = { type = "mult_miners", amount = 5.0 },
    requires = { "mult_6" } },
  { key = "mult_8", name = "Hash Acceleration VIII", desc = "+800% miner output total.",
    cost = 1.5e15,      effect = { type = "mult_miners", amount = 8.0 },
    requires = { "mult_7" } },

  -- Power efficiency ladder
  { key = "eff_4", name = "Power Conditioning IV",  desc = "Miners use 50% less energy total.",
    cost = 8.0e9,       effect = { type = "energy_eff", amount = 0.50 },
    requires = { "eff_3" } },
  { key = "eff_5", name = "Power Conditioning V",   desc = "Miners use 65% less energy total.",
    cost = 1.5e12,      effect = { type = "energy_eff", amount = 0.65 },
    requires = { "eff_4" } },
  { key = "eff_6", name = "Cryogenic Bus",          desc = "Miners use 80% less energy total.",
    cost = 4.0e14,      effect = { type = "energy_eff", amount = 0.80 },
    requires = { "eff_5" } },

  -- Click upgrades
  { key = "click_5", name = "Resonant Cascade",     desc = "Click yields 5% of Z/s (streak-amplified).",
    cost = 1.2e10,      effect = { type = "click_pct", amount = 0.05 },
    requires = { "click_4" } },
  { key = "click_6", name = "Operator Sigil",       desc = "Click yields 12% of Z/s (streak-amplified).",
    cost = 9.0e12,      effect = { type = "click_pct", amount = 0.12 },
    requires = { "click_5" } },

  -- Per-tier mining kind ladder for endgame rigs
  { key = "boost_eonchamber",   name = "Many-Worlds Tuning", desc = "Eonchamber rigs produce 2×.",
    cost = 1.2e9,       effect = { type = "mult_miner_kind", key = "eonchamber", amount = 1.0 } },
  { key = "boost_cosmos",       name = "Brane Phasing",      desc = "Cosmos Lattice produces 2×.",
    cost = 1.2e10,      effect = { type = "mult_miner_kind", key = "cosmos_lattice", amount = 1.0 } },
  { key = "boost_eldritch",     name = "Acausal Pact",       desc = "Eldritch Prime produces 2×.",
    cost = 1.5e11,      effect = { type = "mult_miner_kind", key = "eldritch_prime", amount = 1.0 } },
  { key = "boost_omega",        name = "Anthropic Lock",     desc = "Omega Engine produces 2×.",
    cost = 2.0e12,      effect = { type = "mult_miner_kind", key = "omega_engine", amount = 1.0 } },
  -- Tier-2 miner-kind boosts (super-charged)
  { key = "boost2_quantum",     name = "Decoherence Lock",   desc = "Quantum Miners produce 4× total.",
    cost = 5.0e8,       effect = { type = "mult_miner_kind", key = "quantum_miner", amount = 2.0 },
    requires = { "boost_quantum" } },
  { key = "boost2_neural",      name = "Latent Recall",      desc = "Neural Forges produce 4× total.",
    cost = 5.0e9,       effect = { type = "mult_miner_kind", key = "neural_forge", amount = 2.0 },
    requires = { "boost_neural" } },
  { key = "boost2_hyper",       name = "Subliminal Cascade", desc = "Hyperdrives produce 4× total.",
    cost = 5.0e10,      effect = { type = "mult_miner_kind", key = "hyperdrive_rig", amount = 2.0 },
    requires = { "boost_hyper" } },
  { key = "boost2_singularity", name = "Horizon Charge",     desc = "Singularity Engines produce 4× total.",
    cost = 5.0e11,      effect = { type = "mult_miner_kind", key = "singularity_engine", amount = 2.0 },
    requires = { "boost_singularity" } },

  -- Per-tier energy kind ladder
  { key = "energy_geothermal",  name = "Magma Tap",          desc = "Geothermal output 2×.",
    cost = 8.5e6,       effect = { type = "mult_energy_kind", key = "geothermal", amount = 1.0 } },
  { key = "energy_antimatter",  name = "Containment Tuning", desc = "Antimatter output 2×.",
    cost = 1.2e10,      effect = { type = "mult_energy_kind", key = "antimatter", amount = 1.0 } },
  { key = "energy_zeropoint",   name = "Casimir Resonance",  desc = "Zero-Point output 2×.",
    cost = 5.0e11,      effect = { type = "mult_energy_kind", key = "zeropoint", amount = 1.0 } },
  { key = "energy_higgs",       name = "Boson Routing",      desc = "Higgs Manifold output 2×.",
    cost = 9.0e12,      effect = { type = "mult_energy_kind", key = "higgs_manifold", amount = 1.0 } },
  { key = "energy_eternal",     name = "Stellar Bind",       desc = "Eternal Sun output 2×.",
    cost = 1.4e14,      effect = { type = "mult_energy_kind", key = "eternal_sun", amount = 1.0 } },
  { key = "energy_multiverse",  name = "Branch Skim",        desc = "Multiverse Tap output 2×.",
    cost = 2.0e15,      effect = { type = "mult_energy_kind", key = "multiverse_tap", amount = 1.0 } },

  -- Network synergy ladder
  { key = "network3", name = "Hyper-Mesh",        desc = "Each miner adds +0.5% to all miner output total.",
    cost = 5.0e9,       effect = { type = "network", amount = 0.005 },
    requires = { "network2" } },
  { key = "network4", name = "Singular Mesh",     desc = "Each miner adds +1% to all miner output total.",
    cost = 6.0e11,      effect = { type = "network", amount = 0.010 },
    requires = { "network3" } },

  -- Crit ladder
  { key = "crit_4", name = "Eldritch Luck",     desc = "Crit chance 15%, multiplier 5,000×.",
    cost = 8.0e9,       effect = { type = "crit", chance = 0.15, mult = 5000 },
    requires = { "crit_3" } },
  { key = "crit_5", name = "Anthropic Crit",    desc = "Crit chance 25%, multiplier 25,000×.",
    cost = 5.0e11,      effect = { type = "crit", chance = 0.25, mult = 25000 },
    requires = { "crit_4" } },

  -- Auto-buy reach
  { key = "autobuy_3", name = "Recursive Procurement", desc = "Auto-buy fires every 15s instead of 30s.",
    cost = 5.0e8,       effect = { type = "autobuy_rate", amount = 15 },
    requires = { "autobuy_2" } },

  -- Speed
  { key = "compress2", name = "Time Compression II",   desc = "Game runs 2× faster total.",
    cost = 5.0e10,      effect = { type = "speed", amount = 1.0 },
    requires = { "compress" } },
  { key = "compress3", name = "Eternal Now",           desc = "Game runs 3× faster total.",
    cost = 5.0e12,      effect = { type = "speed", amount = 2.0 },
    requires = { "compress2" } },

  -- Global Z multipliers continued
  { key = "global_3", name = "Z-Multiplier III",       desc = "All zepton production +100%.",
    cost = 5.0e10,      effect = { type = "global_z", amount = 1.00 },
    requires = { "global_2" } },
  { key = "global_4", name = "Z-Multiplier IV",        desc = "All zepton production +200%.",
    cost = 8.0e12,      effect = { type = "global_z", amount = 2.00 },
    requires = { "global_3" } },
  { key = "global_5", name = "Z-Multiplier V",         desc = "All zepton production +400%.",
    cost = 4.0e14,      effect = { type = "global_z", amount = 4.00 },
    requires = { "global_4" } },

  -- Surge enhancements
  { key = "surge_1", name = "Surge Conductor",         desc = "Global surge windows are 50% longer locally.",
    cost = 4.0e9,       effect = { type = "surge_extend", amount = 0.5 } },
  { key = "surge_2", name = "Resonance Tuning",        desc = "Surge multiplier +25% locally.",
    cost = 2.5e11,      effect = { type = "surge_mult_bonus", amount = 0.25 },
    requires = { "surge_1" } },

  -- Pool ratio booster
  { key = "pool_1", name = "Liquidity Bridge",         desc = "Pool partner contribution +25% on your side.",
    cost = 8.0e8,       effect = { type = "pool_in_bonus", amount = 0.25 } },
  { key = "pool_2", name = "Mesh Liaison",             desc = "Pool partner contribution +50% on your side.",
    cost = 5.0e10,      effect = { type = "pool_in_bonus", amount = 0.50 },
    requires = { "pool_1" } },

  -- Heat / cooling / safety etc
  { key = "cooling_1", name = "Phase-Change Cooling",  desc = "All miners produce +20% (heat-recovery).",
    cost = 6.0e8,       effect = { type = "mult_miners", amount = 0.20 } },
  { key = "cooling_2", name = "Sub-Zero Bus",          desc = "All miners produce +40% (subzero loop).",
    cost = 5.0e10,      effect = { type = "mult_miners", amount = 0.40 },
    requires = { "cooling_1" } },

  -- Specialized boosters
  { key = "ai_prefetch", name = "AI Prefetch Cache",   desc = "GPU + Quantum + Neural produce +100%.",
    cost = 1.2e10,      effect = { type = "mult_miner_kind_multi",
      keys = { "gpu_cluster", "quantum_miner", "neural_forge" }, amount = 1.0 } },
  { key = "exotic_lock", name = "Exotic Lock-In",      desc = "Singularity + Eonchamber + Cosmos + Eldritch + Omega produce +200%.",
    cost = 8.0e12,      effect = { type = "mult_miner_kind_multi",
      keys = { "singularity_engine", "eonchamber", "cosmos_lattice", "eldritch_prime", "omega_engine" },
      amount = 2.0 } },
  { key = "renewables", name = "Renewables Grid",      desc = "Solar + Wind + Hydro produce +200%.",
    cost = 4.0e7,       effect = { type = "mult_energy_kind_multi",
      keys = { "solar", "wind", "hydro" }, amount = 2.0 } },
  { key = "fission_breeder", name = "Breeder Reactor", desc = "Fission produces +200%.",
    cost = 2.5e9,       effect = { type = "mult_energy_kind", key = "fission", amount = 2.0 },
    requires = { "energy_reactor" } },
  { key = "fusion_optimum", name = "Q-Limit Burn",     desc = "Fusion produces +200%.",
    cost = 5.0e10,      effect = { type = "mult_energy_kind", key = "fusion", amount = 2.0 },
    requires = { "energy_reactor" } },
  { key = "exotic_grid", name = "Exotic Energy Grid",  desc = "ZPT + Higgs + Eternal + Multiverse produce +300%.",
    cost = 9.0e14,      effect = { type = "mult_energy_kind_multi",
      keys = { "zeropoint", "higgs_manifold", "eternal_sun", "multiverse_tap" },
      amount = 3.0 } },

  -- Click-tier helpers
  { key = "click_streak", name = "Quantum Reflex",     desc = "Click streak cap raised from 20 to 50.",
    cost = 8.0e7,       effect = { type = "streak_cap", amount = 50 } },
  { key = "click_streak2", name = "Eldritch Reflex",   desc = "Click streak cap raised from 50 to 200.",
    cost = 5.0e12,      effect = { type = "streak_cap", amount = 200 },
    requires = { "click_streak" } },

  -- Block reward enhancements
  { key = "block_yield_1", name = "Wider Mempool",     desc = "Block reward +50%.",
    cost = 5.0e9,       effect = { type = "block_reward", amount = 0.50 } },
  { key = "block_yield_2", name = "MEV Capture",       desc = "Block reward +200% total.",
    cost = 1.5e12,      effect = { type = "block_reward", amount = 2.00 },
    requires = { "block_yield_1" } },

  -- Buffer / capacity
  { key = "buffer_2", name = "Capacitor Banks",        desc = "+150% energy headroom total.",
    cost = 1.0e8,       effect = { type = "buffer", amount = 1.5 },
    requires = { "buffer" } },

  -- Endgame capstones (require many other upgrades)
  { key = "ascendant",  name = "Ascendant Operator",   desc = "All zepton production +1000%.",
    cost = 5.0e16,      effect = { type = "global_z", amount = 10.0 },
    requires = { "global_5" } },
  { key = "transcend",  name = "Transcendent Loop",    desc = "All zepton production +5000% total.",
    cost = 5.0e18,      effect = { type = "global_z", amount = 50.0 },
    requires = { "ascendant" } },
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
