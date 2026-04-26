-- Miracles — temporary world transformations powered by zeptons.
-- Each miracle costs N zeptons, lasts up to 10 minutes, and applies a
-- visual overlay to the world (and sometimes to core ops too).

local M = {}

-- Each entry:
--   key, name, desc, cost (in zeptons), duration (seconds),
--   color (accent for UI + tinting), category
M.list = {
  { key = "sunny_day",     name = "Sunny Day",          cost = 1,
    duration = 300, color = { 1.00, 0.85, 0.30 },
    category = "Weather",
    desc = "Bright sunlight bathes the plot. The sky goes warm gold." },

  { key = "rainstorm",     name = "Rainstorm",          cost = 2,
    duration = 480, color = { 0.55, 0.75, 0.95 },
    category = "Weather",
    desc = "Heavy rain falls across the facility for several minutes." },

  { key = "snow",          name = "Snowfall",           cost = 2,
    duration = 360, color = { 0.95, 0.97, 1.00 },
    category = "Weather",
    desc = "Slow, fat snowflakes drift down. The ground keeps a silver tint." },

  { key = "lightning",     name = "Lightning Storm",    cost = 4,
    duration = 240, color = { 0.85, 0.85, 1.00 },
    category = "Weather",
    desc = "Cracks of lightning fork through dark clouds." },

  { key = "aurora",        name = "Aurora Veil",        cost = 5,
    duration = 420, color = { 0.55, 1.00, 0.85 },
    category = "Sky",
    desc = "Curtains of green and violet light ripple across the sky." },

  { key = "starfall",      name = "Starfall",           cost = 6,
    duration = 300, color = { 1.00, 0.92, 0.65 },
    category = "Sky",
    desc = "A meteor shower streaks above the plot in slow trails." },

  { key = "grassy_fields", name = "Grassy Fields",      cost = 8,
    duration = 600, color = { 0.40, 0.85, 0.40 },
    category = "Terrain",
    desc = "The plot tiles bloom into rolling green grassland." },

  { key = "lakes",         name = "Sudden Lakes",       cost = 10,
    duration = 540, color = { 0.30, 0.60, 1.00 },
    category = "Terrain",
    desc = "Pools of water materialise around your facility." },

  { key = "rivers",        name = "Flowing Rivers",     cost = 12,
    duration = 480, color = { 0.40, 0.75, 1.00 },
    category = "Terrain",
    desc = "Living waterways carve channels through the plot." },

  { key = "mountains",     name = "Mountain Horizon",   cost = 18,
    duration = 600, color = { 0.45, 0.50, 0.60 },
    category = "Terrain",
    desc = "Distant snow-capped mountains rise across the horizon." },

  { key = "cherry_bloom",  name = "Cherry Bloom",       cost = 22,
    duration = 540, color = { 1.00, 0.60, 0.85 },
    category = "Flora",
    desc = "Pink petals drift across every walkable surface." },

  { key = "fireflies",     name = "Fireflies",          cost = 28,
    duration = 540, color = { 1.00, 0.95, 0.55 },
    category = "Flora",
    desc = "Thousands of glowing motes wake up at dusk." },

  { key = "angels",        name = "Choir of Angels",    cost = 50,
    duration = 300, color = { 1.00, 1.00, 0.95 },
    category = "Mystic",
    desc = "Winged figures circle silently above the facility." },

  { key = "monolith_pulse", name = "Monolith Pulse",     cost = 75,
    duration = 240, color = { 1.00, 0.30, 0.45 },
    category = "Mystic",
    desc = "Every monolith doubles its zepton absorption rate." },

  { key = "time_dilation", name = "Time Dilation",      cost = 120,
    duration = 180, color = { 0.85, 0.55, 1.00 },
    category = "Mystic",
    desc = "Subjective time slows. The grid runs at 3× speed for you." },

  { key = "midas",         name = "Midas Touch",        cost = 200,
    duration = 180, color = { 1.00, 0.78, 0.30 },
    category = "Apex",
    desc = "Every Bitcoin you earn during the window is doubled." },

  { key = "singularity",   name = "Singularity Touch",  cost = 500,
    duration = 120, color = { 1.00, 1.00, 1.00 },
    category = "Apex",
    desc = "All hash output multiplied by 10 while the singularity holds." },
}

M.byKey = {}
for _, m in ipairs(M.list) do M.byKey[m.key] = m end

-- Group miracles by category for the MIRACLES tab subheads.
local CATEGORIES = { "Weather", "Sky", "Terrain", "Flora", "Mystic", "Apex" }
M.categories = {}
local byCat = {}
for _, m in ipairs(M.list) do
  byCat[m.category] = byCat[m.category] or {}
  table.insert(byCat[m.category], m)
end
for _, c in ipairs(CATEGORIES) do
  if byCat[c] then table.insert(M.categories, { name = c:upper(), items = byCat[c] }) end
end

-- Apply / clear: returns the modifier dict the rest of the game reads.
-- e.g. { speed_mult = 3.0, btc_mult = 2.0, hash_mult = 10, monolith_mult = 2 }
function M.modifierFor(key)
  if key == "time_dilation"    then return { speed_mult    = 3.0 } end
  if key == "midas"            then return { btc_mult      = 2.0 } end
  if key == "singularity"      then return { hash_mult     = 10  } end
  if key == "monolith_pulse"   then return { monolith_mult = 2.0 } end
  return {}
end

return M
