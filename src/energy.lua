-- Energy infrastructure modelled on real-world generation tech.
-- Output values are normalized abstract "energy units" used by the
-- game economy; the spec/cf strings are the realistic flavor that
-- shows up on each card.

local M = {}

M.list = {
  {
    key      = "solar",
    tier     = 1,
    name     = "Solar PV Array",
    short    = "SOL",
    desc     = "Monocrystalline silicon photovoltaic array. Output curves with the day cycle.",
    tech     = "PV / monocrystalline Si",
    spec     = "22% conversion eff.",
    cf       = "CF ~25%",
    produce  = 30,
    cost     = 50,
    growth   = 1.10,
    color    = { 1.00, 0.85, 0.30 },
    dynamic  = "day_cycle",
    note     = "Variable: day cycle",
  },
  {
    key      = "wind",
    tier     = 2,
    name     = "Wind Turbine Field",
    short    = "WND",
    desc     = "Onshore three-blade upwind turbines. Stochastic gusts model real wind variance.",
    tech     = "Onshore HAWT / Class III",
    spec     = "Cut-in 3.5 m/s · Cut-out 25 m/s",
    cf       = "CF ~38%",
    produce  = 90,
    cost     = 280,
    growth   = 1.10,
    color    = { 0.55, 0.85, 1.00 },
    dynamic  = "wind_noise",
    note     = "Variable: gusts",
  },
  {
    key      = "hydro",
    tier     = 3,
    name     = "Hydroelectric Dam",
    short    = "HYD",
    desc     = "Reservoir-type Francis-turbine hydro station. Stable river flow, high capacity factor.",
    tech     = "Reservoir Francis turbines",
    spec     = "240 m head · 410 m³/s",
    cf       = "CF ~95%",
    produce  = 380,
    cost     = 1700,
    growth   = 1.11,
    color    = { 0.40, 0.75, 1.00 },
    dynamic  = nil,
    note     = "Stable",
  },
  {
    key      = "geothermal",
    tier     = 4,
    name     = "Geothermal EGS Plant",
    short    = "GEO",
    desc     = "Enhanced geothermal system. Hot dry rock fracturing with binary-cycle conversion.",
    tech     = "EGS / binary cycle",
    spec     = "220°C reservoir · ORC loop",
    cf       = "CF ~92%",
    produce  = 1200,
    cost     = 11000,
    growth   = 1.12,
    color    = { 1.00, 0.55, 0.35 },
    dynamic  = nil,
    note     = "Stable",
  },
  {
    key      = "fission",
    tier     = 5,
    name     = "Gen-IV Fission Reactor",
    short    = "FIS",
    desc     = "Pressurized water reactor with passive safety. ²³⁵U fuel cycle and supercritical loop.",
    tech     = "PWR / Gen-IV passive",
    spec     = "1.4 GWe · burnup 60 GWd/tHM",
    cf       = "CF ~93%",
    produce  = 6000,
    cost     = 90000,
    growth   = 1.13,
    color    = { 0.45, 1.00, 0.55 },
    dynamic  = nil,
    note     = "Stable",
  },
  {
    key      = "fusion",
    tier     = 6,
    name     = "Tokamak Fusion Core",
    short    = "FUS",
    desc     = "D–T tokamak with superconducting toroidal coils. Lithium blanket breeds tritium.",
    tech     = "Tokamak / D-T plasma",
    spec     = "150 MK plasma · Q ≈ 25",
    cf       = "CF ~85%",
    produce  = 35000,
    cost     = 850000,
    growth   = 1.14,
    color    = { 0.85, 1.00, 0.30 },
    dynamic  = "soft_pulse",
    note     = "Slight pulse (plasma cycle)",
  },
  {
    key      = "antimatter",
    tier     = 7,
    name     = "Antimatter Trap Reactor",
    short    = "AMT",
    desc     = "Penning trap stores anti-protons; positron-electron annihilation harvested at 511 keV/pair.",
    tech     = "Penning trap / e⁺e⁻ annihilation",
    spec     = "511 keV/pair · 99.99% capture",
    cf       = "CF ~98%",
    produce  = 240000,
    cost     = 13000000,
    growth   = 1.15,
    color    = { 1.00, 0.30, 0.70 },
    dynamic  = nil,
    note     = "Stable",
  },
  {
    key      = "zeropoint",
    tier     = 8,
    name     = "Zero-Point Vacuum Tap",
    short    = "ZPT",
    desc     = "Speculative dynamical-Casimir mirror array. Amplifies zero-point fluctuations into harvestable photons.",
    tech     = "Dynamical Casimir / ZPF",
    spec     = "Casimir-effect mirror lattice",
    cf       = "CF ~99.5%",
    produce  = 1700000,
    cost     = 280000000,
    growth   = 1.18,
    color    = { 0.85, 0.80, 1.00 },
    dynamic  = nil,
    note     = "Stable",
  },
}

M.byKey = {}
for _, e in ipairs(M.list) do
  M.byKey[e.key] = e
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

function M.dynamicFactor(def, t, dayPhase)
  if not def.dynamic then return 1 end
  if def.dynamic == "day_cycle" then
    local s = math.sin(dayPhase * math.pi * 2 - math.pi / 2)
    return math.max(0.05, 0.7 + s * 0.7)
  elseif def.dynamic == "wind_noise" then
    local a = math.sin(t * 0.21) * 0.25
    local b = math.sin(t * 0.073 + 1.3) * 0.22
    return math.max(0.25, 0.95 + a + b)
  elseif def.dynamic == "soft_pulse" then
    return 1.0 + math.sin(t * 0.6) * 0.05
  end
  return 1
end

return M
