local M = {}

local SR = 44100

local function envADSR(t, dur, attack, decay, sustain, release)
  if t < attack then
    return t / attack
  elseif t < attack + decay then
    return 1 - (1 - sustain) * ((t - attack) / decay)
  elseif t < dur - release then
    return sustain
  elseif t < dur then
    return sustain * (1 - (t - (dur - release)) / release)
  end
  return 0
end

local function softClip(x)
  if x > 1 then return 1 end
  if x < -1 then return -1 end
  return x - (x * x * x) / 3
end

local function makeTone(builder, dur, channels)
  channels = channels or 1
  local samples = math.floor(SR * dur)
  local sd = love.sound.newSoundData(samples, SR, 16, channels)
  for i = 0, samples - 1 do
    local t = i / SR
    if channels == 2 then
      local l, r = builder(t, i)
      sd:setSample(i * 2, softClip(l))
      sd:setSample(i * 2 + 1, softClip(r))
    else
      sd:setSample(i, softClip(builder(t, i)))
    end
  end
  return sd
end

local function fmTone(freq, modFreq, modIndex, dur, vol)
  vol = vol or 0.4
  return makeTone(function(t)
    local env = envADSR(t, dur, 0.005, 0.04, 0.5, 0.12)
    local m = math.sin(2 * math.pi * modFreq * t) * modIndex
    return math.sin(2 * math.pi * freq * t + m) * env * vol
  end, dur)
end

local function chime(freqs, dur, vol)
  vol = vol or 0.25
  return makeTone(function(t)
    local v = 0
    for _, f in ipairs(freqs) do
      local env = envADSR(t, dur, 0.003, 0.05, 0.4, dur - 0.06)
      v = v + math.sin(2 * math.pi * f * t) * env
    end
    return v * vol / #freqs
  end, dur)
end

local function noiseBurst(dur, freq, vol)
  vol = vol or 0.3
  return makeTone(function(t)
    local env = envADSR(t, dur, 0.001, 0.03, 0.0, 0.0)
    local n = (love.math.random() * 2 - 1)
    local sine = math.sin(2 * math.pi * freq * t)
    return (n * 0.5 + sine * 0.5) * env * vol
  end, dur)
end

local function fanfare(notes, totalDur, vol)
  vol = vol or 0.28
  local samples = math.floor(SR * totalDur)
  local sd = love.sound.newSoundData(samples, SR, 16, 1)
  local perNote = totalDur / #notes
  for i = 0, samples - 1 do
    local t = i / SR
    local idx = math.floor(t / perNote) + 1
    if idx > #notes then idx = #notes end
    local nt = t - (idx - 1) * perNote
    local f = notes[idx]
    local env = envADSR(nt, perNote, 0.005, 0.06, 0.3, perNote * 0.3)
    -- Light overtone
    local s = math.sin(2 * math.pi * f * t) * 0.7
            + math.sin(2 * math.pi * f * 2 * t) * 0.18
            + math.sin(2 * math.pi * f * 3 * t) * 0.08
    sd:setSample(i, softClip(s * env * vol))
  end
  return sd
end

local function drone(freq, dur, vol)
  vol = vol or 0.10
  return makeTone(function(t)
    local env = envADSR(t, dur, 0.4, 0.4, 0.7, 0.5)
    local lfo = math.sin(2 * math.pi * 0.3 * t) * 0.5 + 0.5
    local s = math.sin(2 * math.pi * freq * t) * 0.6
            + math.sin(2 * math.pi * freq * 1.5 * t) * 0.25 * lfo
            + math.sin(2 * math.pi * freq * 0.5 * t) * 0.4
    return s * env * vol
  end, dur, 1)
end

local cache = {}
local sources = {}

local function ensure()
  if cache.click then return end

  cache.click       = fmTone(880, 220, 1.5, 0.10, 0.35)
  cache.click_alt   = fmTone(990, 250, 1.6, 0.10, 0.32)
  cache.coreHum     = drone(120, 4.0, 0.06)
  cache.buy         = chime({ 523.25, 659.25, 783.99 }, 0.30, 0.30)
  cache.sell        = chime({ 392.00, 329.63 }, 0.18, 0.22)
  cache.error       = chime({ 196.00, 174.61 }, 0.20, 0.30)
  cache.tabSwitch   = fmTone(1200, 600, 0.8, 0.06, 0.20)
  cache.upgrade     = chime({ 523.25, 659.25, 783.99, 1046.50 }, 0.45, 0.32)
  cache.achievement = fanfare({ 659.25, 783.99, 987.77, 1318.51 }, 0.85, 0.32)
  cache.zap         = noiseBurst(0.07, 1500, 0.25)
  cache.miner       = fmTone(440, 110, 0.6, 0.06, 0.18)
  cache.power       = chime({ 261.63, 329.63, 392.00 }, 0.35, 0.28)
end

local function pool(name, count)
  count = count or 3
  ensure()
  local sd = cache[name]
  if not sd then return nil end
  if not sources[name] then
    sources[name] = { idx = 1, list = {} }
    for i = 1, count do
      sources[name].list[i] = love.audio.newSource(sd, "static")
    end
  end
  return sources[name]
end

local function play(name, opts)
  opts = opts or {}
  local p = pool(name, opts.poolSize or 4)
  if not p then return end
  local s = p.list[p.idx]
  p.idx = p.idx + 1
  if p.idx > #p.list then p.idx = 1 end
  s:stop()
  if opts.pitch then s:setPitch(opts.pitch) end
  if opts.volume then s:setVolume(opts.volume) end
  s:play()
  return s
end

function M.click(intensity)
  intensity = intensity or 1
  local pitch = 0.85 + love.math.random() * 0.3 + (intensity - 1) * 0.2
  local name = (love.math.random() < 0.5) and "click" or "click_alt"
  play(name, { pitch = pitch, volume = 0.55 + intensity * 0.2 })
end

function M.zap()
  play("zap", { pitch = 0.9 + love.math.random() * 0.4 })
end

function M.buy()      play("buy",      { volume = 0.7 }) end
function M.upgrade()  play("upgrade",  { volume = 0.8 }) end
function M.error_()   play("error",    { volume = 0.5 }) end
function M.tab()      play("tabSwitch",{ volume = 0.4 }) end
function M.power()    play("power",    { volume = 0.6 }) end
function M.achievement() play("achievement", { volume = 0.7 }) end
function M.miner()    play("miner",    { volume = 0.3, pitch = 0.9 + love.math.random() * 0.3 }) end

local hum
function M.startHum()
  if hum then return end
  ensure()
  hum = love.audio.newSource(cache.coreHum, "static")
  hum:setLooping(true)
  hum:setVolume(0.18)
  hum:play()
end

function M.setHumIntensity(x)
  if not hum then return end
  hum:setVolume(0.10 + math.min(0.5, x) * 0.45)
end

function M.pause()
  if hum then hum:pause() end
end

function M.resume()
  if hum and not hum:isPlaying() then hum:play() end
end

function M.preload()
  ensure()
end

return M
