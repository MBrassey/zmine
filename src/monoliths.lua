-- Monoliths — the only source of zeptons.
-- They are placed structures that absorb zeptons from the underlying
-- substrate at a slow rate. Bitcoin (the working currency) buys them;
-- the zeptons they accumulate fund miracles.

local M = {}

-- Single tier for now; cost compounds per unit. Monoliths are
-- intentionally rare and expensive — zeptons are the apex resource.
M.def = {
  key             = "monolith",
  name            = "Zepton Monolith",
  short           = "MNL",
  desc            = "A featureless obsidian obelisk with a single red eye. " ..
                    "Absorbs zeptons from the underlying field. Slow, " ..
                    "expensive, irreplaceable.",
  cost            = 250000,    -- in BTC (state.z)
  growth          = 1.55,
  produce_zps     = 0.04,      -- zeptons per second per monolith
  color           = { 1.00, 0.18, 0.20 },  -- the red eye
  body_color      = { 0.06, 0.04, 0.06 },  -- obsidian body
}

function M.unitCost(owned)
  return math.floor(M.def.cost * (M.def.growth ^ owned))
end

function M.maxAffordable(owned, budget)
  local count = 0
  local total = 0
  while count < 1000 do
    local c = math.floor(M.def.cost * (M.def.growth ^ (owned + count)))
    if total + c > budget then break end
    total = total + c
    count = count + 1
  end
  return count, total
end

return M
