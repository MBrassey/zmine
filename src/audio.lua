-- Procedural audio. Layered detuned oscillators with pitch envelopes,
-- short FIR-tap reverb tails, harmonic stacks, and a continuous hum
-- that subtly tracks production rate.
--
-- All cached sources are in-memory mono SoundData converted to Sources;
-- no asset files are bundled.

local M = {}

local SR = 44100

-- ============================================================
-- Tone generators
-- ============================================================

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

local function makeBuffer(dur)
  local samples = math.floor(SR * dur)
  return love.sound.newSoundData(samples, SR, 16, 1), samples
end

-- Sum of partials with optional detune (cents)
local function partials(t, freq, harmonics)
  local v = 0
  for _, h in ipairs(harmonics) do
    local cents = h.cents or 0
    local f = freq * h.mult * math.pow(2, cents / 1200)
    local g = h.gain or 1
    v = v + math.sin(2 * math.pi * f * t) * g
  end
  return v
end

-- Apply a small FIR-tap reverb tail in-place (tail length proportional to dur)
local function reverbTail(sd, samples, tailGain, tapDelays)
  tailGain = tailGain or 0.20
  tapDelays = tapDelays or { 1500, 3700, 6700, 11000, 17000 }
  -- We blend forward: out[i] += sum( in[i - delay] * gain * (1 - delay/maxTail) )
  -- For simplicity, build a second buffer and merge.
  for tap = 1, #tapDelays do
    local delay = tapDelays[tap]
    local gain = tailGain * (1 - tap / (#tapDelays + 1))
    if delay < samples then
      for i = delay, samples - 1 do
        local cur = sd:getSample(i)
        local src = sd:getSample(i - delay)
        local v = cur + src * gain
        if v > 1 then v = 1 elseif v < -1 then v = -1 end
        sd:setSample(i, v)
      end
    end
  end
end

local function fillBuffer(builder, dur, opts)
  opts = opts or {}
  local sd, samples = makeBuffer(dur)
  for i = 0, samples - 1 do
    local t = i / SR
    local v = builder(t, i)
    sd:setSample(i, softClip(v))
  end
  if opts.reverb then
    reverbTail(sd, samples, opts.reverb.gain, opts.reverb.taps)
  end
  return sd
end

-- ============================================================
-- Sound builders
-- ============================================================

local function clickChime(freqBase)
  -- Layered detuned partials, brief pitch sweep, short reverb tail.
  local dur = 0.18
  return fillBuffer(function(t)
    local sweep = math.exp(-t * 30) * 0.05  -- subtle pitch drop
    local f = freqBase * (1 + sweep)
    local env = envADSR(t, dur, 0.005, 0.06, 0.25, 0.10)
    local v = partials(t, f, {
      { mult = 1.0, cents = 0,  gain = 0.65 },
      { mult = 1.0, cents = 7,  gain = 0.45 },
      { mult = 2.0, cents = -3, gain = 0.18 },
      { mult = 3.0, cents = 0,  gain = 0.10 },
    })
    return v * env * 0.42
  end, dur, { reverb = { gain = 0.18, taps = { 800, 2200, 4800 } } })
end

local function buyChime(notes)
  -- Up-arpeggio chord with shimmer reverb
  local dur = 0.42
  return fillBuffer(function(t)
    local v = 0
    for i, freq in ipairs(notes) do
      local startT = (i - 1) * 0.06
      local localT = t - startT
      if localT >= 0 and localT < dur then
        local env = envADSR(localT, dur - startT, 0.01, 0.08, 0.30, 0.15)
        v = v + partials(localT, freq, {
          { mult = 1, cents = 0, gain = 0.70 },
          { mult = 1, cents = 9, gain = 0.40 },
          { mult = 2, cents = 0, gain = 0.18 },
          { mult = 3, cents = 0, gain = 0.10 },
        }) * env
      end
    end
    return v / #notes * 0.35
  end, dur + 0.4, { reverb = { gain = 0.30, taps = { 1500, 3500, 7500, 14000 } } })
end

local function fanfare(notes, totalDur, vol)
  vol = vol or 0.32
  local dur = totalDur + 0.5  -- room for tail
  local perNote = totalDur / #notes
  return fillBuffer(function(t)
    local idx = math.floor(t / perNote) + 1
    if idx > #notes then idx = #notes end
    local nt = t - (idx - 1) * perNote
    local f = notes[idx]
    local env = envADSR(nt, perNote, 0.005, 0.06, 0.45, perNote * 0.4)
    local s = math.sin(2 * math.pi * f * t) * 0.62
            + math.sin(2 * math.pi * f * 1.005 * t) * 0.32
            + math.sin(2 * math.pi * f * 2 * t) * 0.18
            + math.sin(2 * math.pi * f * 3 * t) * 0.08
    return s * env * vol
  end, dur, { reverb = { gain = 0.32, taps = { 2000, 5500, 11000, 19000 } } })
end

local function tierUp(rootHz)
  -- 4-note ascending major-7 arpeggio
  return fanfare(
    { rootHz, rootHz * 1.25, rootHz * 1.5, rootHz * 1.875 },
    0.62, 0.30)
end

local function noiseBurst(dur, freqLow, freqHigh, vol)
  -- Filtered "shaped" noise — ascending sweep
  vol = vol or 0.25
  return fillBuffer(function(t)
    local env = envADSR(t, dur, 0.001, 0.04, 0.0, 0.0)
    local n = (love.math.random() * 2 - 1)
    local f = freqLow + (freqHigh - freqLow) * (t / dur)
    local sine = math.sin(2 * math.pi * f * t)
    return (n * 0.4 + sine * 0.4) * env * vol
  end, dur)
end

local function footStep()
  -- Low thud + brief noise tap
  local dur = 0.10
  return fillBuffer(function(t)
    local env = envADSR(t, dur, 0.002, 0.02, 0.0, 0.06)
    local thud = math.sin(2 * math.pi * (60 + math.exp(-t * 90) * 80) * t) * 0.6
    local tap = (love.math.random() * 2 - 1) * math.exp(-t * 60) * 0.25
    return (thud + tap) * env * 0.4
  end, dur)
end

local function pulsePump()
  -- Whoosh + bright chime tail (canister pump release)
  local dur = 0.5
  return fillBuffer(function(t)
    local n = (love.math.random() * 2 - 1)
    local env = envADSR(t, dur, 0.005, 0.10, 0.10, 0.30)
    local sweep = 200 + (1 - math.exp(-t * 4)) * 800
    local sw = math.sin(2 * math.pi * sweep * t)
    local chime = math.sin(2 * math.pi * 880 * t) * 0.35 * math.exp(-t * 6)
    return (n * 0.3 + sw * 0.45 + chime) * env * 0.30
  end, dur + 0.3, { reverb = { gain = 0.25, taps = { 1800, 4500, 9000 } } })
end

local function worldSwoosh()
  -- Filter-sweep whoosh for view transition
  local dur = 0.45
  return fillBuffer(function(t)
    local env = envADSR(t, dur, 0.01, 0.05, 0.40, 0.30)
    local n = (love.math.random() * 2 - 1) * env
    -- Doppler-style pitch sweep on a sine
    local freq = 110 + math.sin(t * 3) * 60 + 220 * (1 - math.exp(-t * 4))
    local s = math.sin(2 * math.pi * freq * t) * env * 0.45
    return n * 0.35 + s
  end, dur + 0.4, { reverb = { gain = 0.25, taps = { 1500, 3700, 7500, 13000 } } })
end

local function peerJoinChime()
  -- Bright bell-like chime
  local notes = { 1046.50, 1318.51, 1567.98 }
  local dur = 0.65
  return fillBuffer(function(t)
    local v = 0
    for i, f in ipairs(notes) do
      local startT = (i - 1) * 0.05
      local localT = t - startT
      if localT >= 0 then
        local env = envADSR(localT, dur - startT, 0.005, 0.10, 0.50, 0.25)
        v = v + math.sin(2 * math.pi * f * t) * env
      end
    end
    return v / #notes * 0.35
  end, dur + 0.5, { reverb = { gain = 0.32, taps = { 1700, 4500, 9500, 16000 } } })
end

local function padCharge()
  local dur = 0.32
  return fillBuffer(function(t)
    local env = envADSR(t, dur, 0.003, 0.06, 0.30, 0.20)
    local fSweep = 220 + 880 * (t / dur)
    local s = math.sin(2 * math.pi * fSweep * t) * 0.5
            + math.sin(2 * math.pi * fSweep * 2 * t) * 0.20
            + (love.math.random() * 2 - 1) * 0.12
    return s * env * 0.30
  end, dur + 0.3, { reverb = { gain = 0.20, taps = { 1500, 3500, 7000 } } })
end

local function richDrone(freq, dur, vol)
  vol = vol or 0.10
  return fillBuffer(function(t)
    local env = envADSR(t, dur, 0.4, 0.4, 0.7, 0.5)
    local lfo1 = math.sin(2 * math.pi * 0.2 * t) * 0.5 + 0.5
    local lfo2 = math.sin(2 * math.pi * 0.07 * t + 1.4) * 0.3 + 0.7
    local s = math.sin(2 * math.pi * freq * t) * 0.55
            + math.sin(2 * math.pi * freq * 1.5 * t) * 0.20 * lfo1
            + math.sin(2 * math.pi * freq * 0.5 * t) * 0.30
            + math.sin(2 * math.pi * freq * 2.01 * t) * 0.10 * lfo2
    return s * env * vol
  end, dur)
end

local function emoteWave()
  local dur = 0.30
  return fillBuffer(function(t)
    local env = envADSR(t, dur, 0.005, 0.05, 0.20, 0.20)
    local f = 660 + math.sin(t * 30) * 80
    return math.sin(2 * math.pi * f * t) * env * 0.30
  end, dur + 0.2, { reverb = { gain = 0.18, taps = { 1500, 3800 } } })
end

local function flagPlant()
  local dur = 0.18
  return fillBuffer(function(t)
    local env = envADSR(t, dur, 0.005, 0.04, 0.1, 0.10)
    local thud = math.sin(2 * math.pi * 120 * t) * 0.5
    local clk = math.sin(2 * math.pi * 1800 * t) * 0.3 * math.exp(-t * 12)
    return (thud + clk) * env * 0.32
  end, dur + 0.2)
end

local function critStrike()
  local dur = 0.55
  local notes = { 880, 1320, 1760, 2640 }
  return fillBuffer(function(t)
    local v = 0
    for i, f in ipairs(notes) do
      local s = (i - 1) * 0.04
      local lt = t - s
      if lt > 0 then
        local env = envADSR(lt, dur - s, 0.003, 0.06, 0.5, 0.20)
        v = v + math.sin(2 * math.pi * f * t) * env
      end
    end
    return v / #notes * 0.40
  end, dur + 0.3, { reverb = { gain = 0.30, taps = { 1500, 3700, 7400 } } })
end

-- ============================================================
-- Cache + pool
-- ============================================================

local cache = {}
local sources = {}

local function ensure()
  if cache.click then return end

  cache.click       = clickChime(880)
  cache.click_alt   = clickChime(990)
  cache.coreHum     = richDrone(120, 4.0, 0.06)
  cache.buy         = buyChime({ 523.25, 659.25, 783.99 })
  cache.sell        = buyChime({ 392.00, 329.63 })
  cache.error       = buyChime({ 196.00, 174.61 })
  cache.tabSwitch   = clickChime(1320)
  cache.upgrade     = buyChime({ 523.25, 659.25, 783.99, 1046.50 })
  cache.achievement = fanfare({ 659.25, 783.99, 987.77, 1318.51 }, 0.85, 0.32)
  cache.tierUp      = tierUp(523.25)
  cache.zap         = noiseBurst(0.07, 800, 2400, 0.25)
  cache.miner       = clickChime(440)
  cache.power       = buyChime({ 261.63, 329.63, 392.00 })
  cache.footstep    = footStep()
  cache.padCharge   = padCharge()
  cache.canisterPump = pulsePump()
  cache.worldSwoosh = worldSwoosh()
  cache.peerJoin    = peerJoinChime()
  cache.peerLeave   = buyChime({ 392.00, 311.13 })
  cache.emoteWave   = emoteWave()
  cache.flagPlant   = flagPlant()
  cache.critStrike  = critStrike()
end

local function pool(name, count)
  count = count or 4
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
  local p = pool(name, opts.poolSize or 6)
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

-- ============================================================
-- Public API
-- ============================================================

function M.click(intensity)
  intensity = intensity or 1
  local pitch = 0.85 + love.math.random() * 0.3 + (intensity - 1) * 0.2
  local name = (love.math.random() < 0.5) and "click" or "click_alt"
  play(name, { pitch = pitch, volume = 0.55 + intensity * 0.2 })
end

function M.zap()
  play("zap", { pitch = 0.9 + love.math.random() * 0.4 })
end

function M.buy()       play("buy",       { volume = 0.7 }) end
function M.upgrade()   play("upgrade",   { volume = 0.8 }) end
function M.error_()    play("error",     { volume = 0.5 }) end
function M.tab()       play("tabSwitch", { volume = 0.4 }) end
function M.power()     play("power",     { volume = 0.6 }) end
function M.achievement() play("achievement", { volume = 0.7 }) end
function M.miner()     play("miner",     { volume = 0.3, pitch = 0.9 + love.math.random() * 0.3 }) end
function M.tierUp()    play("tierUp",    { volume = 0.7 }) end
function M.footstep()  play("footstep",  { volume = 0.3, pitch = 0.85 + love.math.random() * 0.3 }) end
function M.padCharge() play("padCharge", { volume = 0.55 }) end
function M.canisterPump() play("canisterPump", { volume = 0.55 }) end
function M.worldSwoosh()  play("worldSwoosh",  { volume = 0.65 }) end
function M.peerJoin()  play("peerJoin",  { volume = 0.65 }) end
function M.peerLeave() play("peerLeave", { volume = 0.4 }) end
function M.emoteWave() play("emoteWave", { volume = 0.5 }) end
function M.flagPlant() play("flagPlant", { volume = 0.55 }) end
function M.crit()      play("critStrike",{ volume = 0.7 }) end

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
  hum:setPitch(0.9 + math.min(0.6, x) * 0.4)
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
