-- Helpers for portal magic-print effects. Anti-spam guarded by minimum
-- intervals; safe to call from frequent events.

local M = {}

local lastFire = {}
local MIN_INTERVAL = {
  flash    = 0.18,
  shake    = 0.20,
  invert   = 0.30,
  chroma   = 0.20,
  pulse    = 0.15,
  ripple   = 0.10,
  glow     = 0.20,
  flicker  = 0.30,
  shatter  = 1.00,
  scanlines = 0.50,
  zoom     = 0.30,
  vignette = 0.40,
}

local function gate(verb)
  local now = love.timer.getTime()
  local lim = MIN_INTERVAL[verb] or 0
  if (now - (lastFire[verb] or -10)) < lim then return false end
  lastFire[verb] = now
  return true
end

local function emit(verb, args)
  print("[[LOVEWEB_FX]]" .. verb .. " " .. args)
end

function M.flash(color, ms, intensity)
  if not gate("flash") then return end
  if intensity then
    emit("flash", string.format("%s %d %.2f", color, ms, intensity))
  else
    emit("flash", string.format("%s %d", color, ms))
  end
end

function M.shake(intensity, ms)
  if not gate("shake") then return end
  emit("shake", string.format("%.2f %d", intensity, ms))
end

function M.invert(ms)
  if not gate("invert") then return end
  emit("invert", string.format("%d", ms))
end

function M.chroma(intensity, ms)
  if not gate("chroma") then return end
  emit("chroma", string.format("%.2f %d", intensity, ms))
end

function M.pulse(color, ms)
  if not gate("pulse") then return end
  emit("pulse", string.format("%s %d", color, ms))
end

function M.ripple(color, x, y, ms)
  if not gate("ripple") then return end
  emit("ripple", string.format("%s %.2f %.2f %d", color, x, y, ms))
end

function M.glow(color, intensity, ms)
  if not gate("glow") then return end
  emit("glow", string.format("%s %.2f %d", color, intensity, ms))
end

function M.flicker(intensity, ms)
  if not gate("flicker") then return end
  emit("flicker", string.format("%.2f %d", intensity, ms))
end

function M.shatter(intensity, ms)
  if not gate("shatter") then return end
  emit("shatter", string.format("%.2f %d", intensity, ms))
end

function M.zoom(amount, ms)
  if not gate("zoom") then return end
  emit("zoom", string.format("%.2f %d", amount, ms))
end

function M.vignette(intensity, ms)
  if not gate("vignette") then return end
  emit("vignette", string.format("%.2f %d", intensity, ms))
end

function M.scanlines(intensity, ms)
  if not gate("scanlines") then return end
  emit("scanlines", string.format("%.2f %d", intensity, ms))
end

function M.mood(color, intensity)
  if color == "none" then
    emit("mood", "none")
  else
    emit("mood", string.format("%s %.2f", color, intensity))
  end
end

function M.calm(color, intensity)
  if color == "none" then
    emit("calm", "none")
  else
    emit("calm", string.format("%s %.2f", color, intensity))
  end
end

function M.pulsate(color, bpm, intensity)
  if color == "off" then
    emit("pulsate", "off")
  else
    emit("pulsate", string.format("%s %d %.2f", color, math.floor(bpm), intensity))
  end
end

return M
