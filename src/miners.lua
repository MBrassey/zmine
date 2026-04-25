-- Miner definitions modelled on real proof-of-work mining hardware.
-- Hash rates, joules-per-terahash, and algorithm references reflect actual
-- production gear at each tier (T1-T2) plus near-future and speculative rigs
-- for the higher tiers.

local M = {}

M.list = {
  {
    key       = "asic_z1",
    tier      = 1,
    name      = "ASIC-Z1 Hashboard",
    short     = "Z1",
    desc      = "Single-board SHA-256d ASIC. 7 nm node. Reference: Antminer S19 class.",
    algo      = "SHA-256d / SHA-256-Z",
    hashrate  = "110 TH/s",
    efficiency = "29.5 J/TH",
    spec      = "BM1398 / 7nm",
    produce   = 1,
    energy    = 4,
    cost      = 15,
    growth    = 1.07,
    color     = { 0.30, 1.00, 0.55 },
  },
  {
    key       = "gpu_cluster",
    tier      = 2,
    name      = "GPU Mining Cluster",
    short     = "GPU",
    desc      = "Multi-rig GPU farm. Memory-hard algorithms. Reference: 8× RTX 4090.",
    algo      = "Ethash / KawPow / Equihash",
    hashrate  = "4.4 GH/s memory-hard",
    efficiency = "0.18 W/MH",
    spec      = "CUDA / OpenCL",
    produce   = 8,
    energy    = 18,
    cost      = 220,
    growth    = 1.075,
    color     = { 0.40, 0.85, 1.00 },
  },
  {
    key       = "quantum_miner",
    tier      = 3,
    name      = "Cryogenic Quantum Rig",
    short     = "QUANT",
    desc      = "Logical qubit array running Grover-accelerated nonce search. Sqrt(N) speedup vs classical SHA.",
    algo      = "Grover-SHA-256 (quantum)",
    hashrate  = "1.8 EH/s effective",
    efficiency = "0.8 J/TH @ 14 mK",
    spec      = "1024 logical qubits / dilution fridge",
    produce   = 50,
    energy    = 90,
    cost      = 2800,
    growth    = 1.08,
    color     = { 0.70, 0.55, 1.00 },
  },
  {
    key       = "neural_forge",
    tier      = 4,
    name      = "Neural Forge",
    short     = "NRL",
    desc      = "Transformer model predicts low-entropy nonce candidates pre-hash. Trained on solved zepton blocks.",
    algo      = "Predictive nonce / SHA-256-Z",
    hashrate  = "180 EH/s eff. (predicted)",
    efficiency = "0.04 J/TH eff.",
    spec      = "TPU v9 / 2 PB model weights",
    produce   = 320,
    energy    = 420,
    cost      = 38000,
    growth    = 1.085,
    color     = { 1.00, 0.45, 0.85 },
  },
  {
    key       = "hyperdrive_rig",
    tier      = 5,
    name      = "Hyperdrive Lattice",
    short     = "HYP",
    desc      = "Speculative. Subliminal-channel nonce extraction across nested logical folds.",
    algo      = "Subliminal-SHA-Z",
    hashrate  = "11 ZH/s sustained",
    efficiency = "0.0009 J/TH",
    spec      = "Topological lattice / 4D",
    produce   = 1900,
    energy    = 1900,
    cost      = 470000,
    growth    = 1.09,
    color     = { 1.00, 0.65, 0.35 },
  },
  {
    key       = "singularity_engine",
    tier      = 6,
    name      = "Singularity Engine",
    short     = "SNG",
    desc      = "Speculative. Localised space-time fold collapses the hash space onto the solved nonce in O(1).",
    algo      = "Folded-SHA / Closed Timelike",
    hashrate  = "65 YH/s emergent",
    efficiency = "0.000004 J/TH",
    spec      = "Kerr-metric well / event-horizon",
    produce   = 11000,
    energy    = 9000,
    cost      = 5800000,
    growth    = 1.10,
    color     = { 1.00, 0.40, 0.50 },
  },
  {
    key       = "eonchamber",
    tier      = 7,
    name      = "Eonchamber",
    short     = "EON",
    desc      = "Speculative. Million-history eigenstate sampler. Each cycle returns a million blocks across alternate timelines.",
    algo      = "Many-Worlds / Hash-Eigen",
    hashrate  = "≫ network",
    efficiency = "vacuum-limited",
    spec      = "Everett-branching shell",
    produce   = 70000,
    energy    = 38000,
    cost      = 72000000,
    growth    = 1.11,
    color     = { 1.00, 0.88, 0.40 },
  },
}

M.byKey = {}
for _, m in ipairs(M.list) do
  M.byKey[m.key] = m
end

function M.unitCost(def, owned)
  return math.floor(def.cost * (def.growth ^ owned))
end

function M.totalCost(def, owned, count)
  local total = 0
  for i = 0, count - 1 do
    total = total + math.floor(def.cost * (def.growth ^ (owned + i)))
  end
  return total
end

function M.maxAffordable(def, owned, budget)
  local count = 0
  local total = 0
  while count < 10000 do
    local c = math.floor(def.cost * (def.growth ^ (owned + count)))
    if total + c > budget then break end
    total = total + c
    count = count + 1
  end
  return count, total
end

return M
