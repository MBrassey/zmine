-- World view — Roblox-tycoon-style walkable plot.
-- Player walks with WASD; stepping on a glowing buy pad auto-purchases
-- the corresponding miner / energy when they can afford it. Built items
-- accumulate visually on adjacent platforms. Zepton canisters fill from
-- transparent to glowing green as zeptons accumulate, then pump.
--
-- Peers from the network mesh appear as Roblox-style avatars walking
-- the plot at deterministic positions (with slow drift).

local fmt        = require "src.format"
local Iso        = require "src.iso"
local Char       = require "src.character"
local Assets     = require "src.assets"
local Cosmetics  = require "src.cosmetics"
local Coin       = require "src.coin"
local Audio      = require "src.audio"
local MiracleFx  = require "src.miracle_fx"
local minersDb   = require "src.miners"
local energyDb   = require "src.energy"

local M = {}

local DESIGN_W, DESIGN_H = 1920, 1080
local PLOT_W, PLOT_H = 24, 18
local PAD_COOLDOWN = 0.65
-- Bulk-buy on pads: holding the step keeps buying; longer holds buy more
-- per tick. Thresholds are in seconds-on-pad.
local PAD_HOLD_X10  = 1.5
local PAD_HOLD_MAX  = 3.0

-- Camera origin (where world-coord (0,0) lands in screen space).
-- The plot's iso footprint is (PLOT_W+PLOT_H)*TILE_W/2 = 2016 px wide,
-- which exceeds the 1920 design canvas — a fixed camera always leaves
-- one corner offscreen. Solution: the camera lerps toward the player
-- character each frame so the player is always near canvas center.
-- Initial value here just spawns somewhere reasonable; M.update
-- recenters from frame 1.
local CAMERA = {
  sx = DESIGN_W / 2,
  sy = 96 + (DESIGN_H - 96 - 64) / 2,
}

local CAMERA_LERP = 5    -- frames-to-catch-up rate
local CAMERA_VIEW_Y = 540 -- canvas y where the character should sit

-- Particles + floats are drawn AFTER the world-camera transform pops,
-- so anything emitted in world coords needs the camera offset baked in
-- before reaching the shared particle/float systems. Use this helper at
-- every world-coord particle emit site.
function M.toAbsScreen(wx, wy, wz)
  local sx, sy = Iso.toScreen(wx, wy, wz)
  return sx + CAMERA.sx, sy + CAMERA.sy
end

function M.cameraOffset() return CAMERA.sx, CAMERA.sy end

-- ============================================================
-- Layout
-- ============================================================

local function buildPads()
  -- Layout (north → south): miner racks, miner pads, canisters,
  -- energy pads, energy plants. Miners (the things consuming Z/s) live
  -- at the top close to the operator's mental focus; energy (the
  -- foundation feeding them) lines the bottom of the plot.
  local pads = {}

  local minerList = minersDb.list
  local nM = #minerList
  for i, def in ipairs(minerList) do
    local frac = (i - 0.5) / nM
    local cx = 2 + frac * (PLOT_W - 4)
    table.insert(pads, {
      kind = "miner",
      key  = def.key,
      def  = def,
      wx   = cx,
      wy   = 4.0,
      anchor_wx = cx,
      anchor_wy = 1.5,    -- miner racks render NORTH of the pad
      phase = i * 0.27,
    })
  end

  local energyList = energyDb.list
  local nE = #energyList
  for i, def in ipairs(energyList) do
    local frac = (i - 0.5) / nE
    local cx = 1 + frac * (PLOT_W - 2)
    table.insert(pads, {
      kind = "energy",
      key  = def.key,
      def  = def,
      wx   = cx,
      wy   = PLOT_H - 4,
      anchor_wx = cx,
      anchor_wy = PLOT_H - 1.5,  -- energy plants render SOUTH of the pad
      phase = i * 0.31,
    })
  end

  return pads
end

local function canisterPositions()
  -- Canisters sit just south of the miner row (which is at y=4 now)
  -- so the green-glow zepton flow visually anchors to the rigs that
  -- are actually mining.
  local pos = {}
  local minerList = minersDb.list
  for i, def in ipairs(minerList) do
    local cx = 2 + ((i - 0.5) / #minerList) * (PLOT_W - 4)
    table.insert(pos, {
      key = def.key,
      def = def,
      wx  = cx,
      wy  = 6.5,
    })
  end
  return pos
end

-- ============================================================
-- Module state
-- ============================================================

function M.new(state)
  -- Seed the camera to the spawn position so the first frame is
  -- already centered, not lerping in from the previous frame's value.
  local spawnX, spawnY = PLOT_W / 2, PLOT_H / 2
  local _sx, _sy = Iso.toScreen(spawnX, spawnY, 0)
  CAMERA.sx = DESIGN_W / 2 - _sx
  CAMERA.sy = CAMERA_VIEW_Y - _sy

  local s = {
    char = Char.new({
      wx = spawnX,
      wy = spawnY,
      label = (state.facility_name or "OPERATOR"):sub(1, 18),
    }),
    plotBounds = { minX = 0.5, maxX = PLOT_W - 0.5, minY = 0.5, maxY = PLOT_H - 0.5 },
    pads = buildPads(),
    canisters = canisterPositions(),
    canister_fills = {},  -- key -> 0..1 fill
    pad_cooldowns = {},   -- pad index -> cooldown remaining
    peers = {},           -- userId -> peer character + walk path
    peerSimChars = {},    -- ghost peer characters
    helpVisible = true,
    helpTimer = 0,
    customizeOpen = false,
  }
  -- Initialize canister fills based on miner counts
  for _, c in ipairs(s.canisters) do
    s.canister_fills[c.key] = 0
  end
  -- Apply current cosmetics
  if state.cosmetics then
    Cosmetics.applyTo(s.char, state.cosmetics)
  end
  return s
end

-- ============================================================
-- Update
-- ============================================================

local function pollInput()
  local ax, ay = 0, 0
  if love.keyboard.isDown("w", "up")    then ax = ax - 1; ay = ay - 1 end
  if love.keyboard.isDown("s", "down")  then ax = ax + 1; ay = ay + 1 end
  if love.keyboard.isDown("a", "left")  then ax = ax - 1; ay = ay + 1 end
  if love.keyboard.isDown("d", "right") then ax = ax + 1; ay = ay - 1 end
  -- Normalize so diagonal isn't faster
  local s = math.sqrt(ax * ax + ay * ay)
  if s > 0 then ax = ax / s; ay = ay / s end
  return ax, ay
end

local function inPad(char, pad)
  local dx = char.wx - pad.wx
  local dy = char.wy - pad.wy
  return (dx * dx + dy * dy) < 1.1 * 1.1
end

local function emitTrailParticles(state, char)
  local def = char.effects and char.effects.trail
  if not def then return end
  if (char.vx * char.vx + char.vy * char.vy) < 0.05 then return end
  -- Absolute screen coords so the trail follows the character even
  -- though the particle system draws outside the world transform.
  local sx, sy = M.toAbsScreen(char.wx, char.wy, 0)
  local dx = -char.vx
  local dy = -char.vy
  local len = math.sqrt(dx * dx + dy * dy) + 0.001
  dx, dy = dx / len, dy / len
  local color = def.color
  if def.key == "trail_matrix" then
    -- Falling matrix-style green code
    for k = 1, 2 do
      state.particles:emit({
        x = sx + (love.math.random() - 0.5) * 14,
        y = sy - 30 + love.math.random() * 30,
        vx = 0, vy = 90 + love.math.random() * 50,
        ax = 0, ay = 0,
        life = 0.7, maxLife = 0.7,
        color = { color[1], color[2], color[3] },
        size = 2.4,
        drag = 0.0,
        kind = "trail",
        rot = 0, vrot = 0,
      })
    end
  elseif def.key == "trail_singularity" then
    state.particles:emit({
      x = sx + dx * 6, y = sy - 22 + dy * 6,
      vx = dx * 80 + (love.math.random() - 0.5) * 30,
      vy = dy * 80 + (love.math.random() - 0.5) * 30,
      ax = 0, ay = 0,
      life = 1.2, maxLife = 1.2,
      color = { color[1], color[2], color[3] },
      size = 3.2, drag = 1.0, kind = "trail",
      rot = 0, vrot = 0,
    })
  else
    -- Generic spark trail
    state.particles:emit({
      x = sx + dx * 4 + (love.math.random() - 0.5) * 6,
      y = sy - 18 + dy * 4 + (love.math.random() - 0.5) * 6,
      vx = dx * 30, vy = dy * 30 - 20,
      ax = 0, ay = 0,
      life = 0.8, maxLife = 0.8,
      color = { color[1], color[2], color[3] },
      size = 2.4, drag = 1.6, kind = "trail",
      rot = 0, vrot = 0,
    })
  end
end

local function emitSparkles(state, char)
  local def = char.effects and char.effects.sparkle
  if not def then return end
  if love.math.random() > 0.30 then return end
  local sx, sy = M.toAbsScreen(char.wx, char.wy, 0)
  local color = def.color
  state.particles:emit({
    x = sx + (love.math.random() - 0.5) * 26,
    y = sy - 30 + (love.math.random() - 0.5) * 30,
    vx = (love.math.random() - 0.5) * 30,
    vy = -20 - love.math.random() * 30,
    ax = 0, ay = 0,
    life = 0.9, maxLife = 0.9,
    color = { color[1], color[2], color[3] },
    size = 2.0, drag = 1.4, kind = "spark",
    rot = 0, vrot = 0,
  })
end

local function updatePeers(world, state, dt)
  -- Sync peer characters from network snapshots; deterministic walk paths.
  local snaps = state.network and state.network._snapshots or {}
  local seen = {}
  for _, snap in ipairs(snaps) do
    seen[snap.id] = true
    local pc = world.peers[snap.id]
    if not pc then
      pc = {
        char = Char.new({
          wx = 1 + ((snap.id and #snap.id or 1) % (PLOT_W - 2)),
          wy = 1 + ((snap.id and #snap.id * 7 or 1) % (PLOT_H - 2)),
          shirtColor  = snap.avatar and snap.avatar.color or { 0.5, 0.5, 0.7 },
          accentColor = snap.avatar and snap.avatar.color or { 0.5, 0.5, 0.7 },
          label = (snap.name or "operator"):sub(1, 18),
          isPeer = true,
        }),
        path_t = love.math.random() * 6.28,
        path_speed = 0.2 + love.math.random() * 0.4,
      }
      world.peers[snap.id] = pc
    else
      pc.char.label = (snap.name or "operator"):sub(1, 18)
    end
    -- Propagate wave timer from network event onto the peer character
    local realPeer = state.network.realPeers[snap.id]
    if realPeer and realPeer.waveTimer and realPeer.waveTimer > 0 then
      pc.char._waveTimer = realPeer.waveTimer
      realPeer.waveTimer = math.max(0, realPeer.waveTimer - dt)
    elseif pc.char._waveTimer and pc.char._waveTimer > 0 then
      pc.char._waveTimer = math.max(0, pc.char._waveTimer - dt)
    end
    -- Drift peer along a slow Lissajous
    pc.path_t = pc.path_t + dt * pc.path_speed
    if snap.status == "offline" then
      pc.char.vx = 0; pc.char.vy = 0
    else
      -- Peers visit from outside the player's working zone. The
      -- player's own area is now miner racks (y≈1.5) → miner pads
      -- (y=4) → canisters (y=6.5) → energy pads (y=14) → energy
      -- plants (y=16.5). We park visitors on a thin ribbon at the
      -- VERY south edge (y≈17.0–17.4), past the energy plants, so
      -- they don't walk through your equipment.
      local realPeer = state.network.realPeers[snap.id]
      local seedNum = 0
      for ch = 1, (snap.id and #snap.id or 1) do
        seedNum = seedNum + (snap.id and snap.id:byte(ch) or 0)
      end
      local visitorY = 17.0 + ((seedNum % 3) * 0.2)  -- 17.0 / 17.2 / 17.4
      local cx, cy
      if realPeer and realPeer.posX and realPeer.posY then
        local age = (state.network._t or 0) - (realPeer.posUpdatedAt or 0)
        cx = realPeer.posX + (realPeer.posVX or 0) * math.min(1.5, age)
        cy = visitorY + math.sin((realPeer.posUpdatedAt or 0) + age) * 0.2
      else
        cx = 2 + (math.sin(pc.path_t * 0.4) * 0.5 + 0.5) * (PLOT_W - 4)
        cy = visitorY + math.sin(pc.path_t * 0.7) * 0.2
      end
      if cx < 1.5 then cx = 1.5 end
      if cx > PLOT_W - 1.5 then cx = PLOT_W - 1.5 end
      local dx = cx - pc.char.wx
      local dy = cy - pc.char.wy
      local d = math.sqrt(dx * dx + dy * dy)
      if d > 0.05 then
        -- Lerp toward the target position so movement feels smooth even
        -- though pos events arrive every ~1 s.
        local lerp = math.min(1, dt * 4)
        pc.char.wx = pc.char.wx + dx * lerp
        pc.char.wy = pc.char.wy + dy * lerp
        pc.char.vx = dx
        pc.char.vy = dy
        pc.char.walkPhase = (pc.char.walkPhase or 0) + dt
        if math.abs(pc.char.vx) > math.abs(pc.char.vy) then
          pc.char.facing = pc.char.vx > 0 and 1 or -1
        else
          pc.char.facing = 0
        end
      else
        pc.char.vx = 0; pc.char.vy = 0
      end
    end
  end
  -- Cleanup peers no longer in snapshots
  for id, _ in pairs(world.peers) do
    if not seen[id] then world.peers[id] = nil end
  end
end

-- Tutorial state: contextual hint banner for first-session onboarding.
-- Hides automatically once the loop is established AND once the player
-- has visited the world view a second time across sessions (returning
-- players don't need the steps repeated). state._tutSessionCount is
-- bumped once per Game.new and saved.
local function tutorialPhase(state)
  -- Returning player: skip the tutorial entirely on session 2+.
  if (state._tutSessionCount or 1) >= 2 then return 4 end
  -- Phase 1: never walked yet
  if not state._tutPhase or state._tutPhase < 2 then
    if state.world and state.world.char and (state.world.char.walkPhase or 0) > 0.4 then
      state._tutPhase = 2
    else
      return 1
    end
  end
  local count = 0
  for _, def in ipairs(minersDb.list) do count = count + (state.miners[def.key] or 0) end
  for _, def in ipairs(energyDb.list) do count = count + (state.energy[def.key] or 0) end
  if state._tutPhase == 2 and count <= 2 then return 2 end
  if state._tutPhase < 3 then state._tutPhase = 3 end
  if state._tutPhase == 3 and not state._sawCoreOps then return 3 end
  if state._tutPhase < 4 then state._tutPhase = 4 end
  return 4
end

local function tickCanisters(world, state, dt)
  -- Canister fills from the per-tier z_per_sec contribution.
  -- Each miner type fills at its share of total z_per_sec.
  local totalRate = state.z_per_sec or 0
  if totalRate <= 0 then
    -- Drain slowly when idle
    for k, v in pairs(world.canister_fills) do
      world.canister_fills[k] = math.max(0, v - dt * 0.05)
    end
    return
  end
  for _, c in ipairs(world.canisters) do
    local count = state.miners[c.key] or 0
    if count > 0 then
      local mult = state.mods.miner_kind[c.key] or 1
      local share = count * c.def.produce * mult / totalRate
      -- Time to fill scales inverse to share — small share = slow fill.
      local fillRate = 0.04 + share * 0.30
      local f = (world.canister_fills[c.key] or 0) + fillRate * dt
      if f >= 1.0 then
        f = 0
        -- Combined pump rate limit: SFX + particles. Once every 1.2 s
        -- across all canisters so a late-game player with many tiers
        -- doesn't hear a machine-gun of pumps.
        world._lastPumpAt = world._lastPumpAt or 0
        if love.timer.getTime() - world._lastPumpAt > 1.2 then
          world._lastPumpAt = love.timer.getTime()
          Audio.canisterPump()
          -- Pump particles fly from canister to the player character.
          local sx, sy = M.toAbsScreen(c.wx, c.wy, 0)
          local cx, cy = M.toAbsScreen(world.char.wx, world.char.wy, 0.4)
          for k = 0, 12 do
            state.particles:emit({
              x = sx + (love.math.random() - 0.5) * 10,
              y = sy - 30 + (love.math.random() - 0.5) * 10,
              vx = (cx - sx) * 0.4 + (love.math.random() - 0.5) * 40,
              vy = (cy - sy) * 0.4 + (love.math.random() - 0.5) * 40,
              ax = 0, ay = 0,
              life = 1.0, maxLife = 1.0,
              color = { c.def.color[1], c.def.color[2], c.def.color[3] },
              size = 4, drag = 1.2, kind = "trail",
              rot = 0, vrot = 0,
            })
          end
        end
      end
      world.canister_fills[c.key] = f
    else
      world.canister_fills[c.key] = math.max(0, (world.canister_fills[c.key] or 0) - dt * 0.10)
    end
  end
end

function M.update(world, state, dt, callbacks)
  -- Movement input
  local ax, ay = pollInput()
  Char.update(world.char, dt, ax, ay, world.plotBounds)

  -- Camera follow: lerp toward the screen position that puts the
  -- character at canvas center. The plot's iso footprint is wider
  -- than the 1920 canvas, so a fixed camera always clips one corner
  -- offscreen. Following the player keeps you centered on your plot.
  local charSx, charSy = Iso.toScreen(world.char.wx, world.char.wy, 0)
  local targetSx = DESIGN_W / 2 - charSx
  local targetSy = CAMERA_VIEW_Y - charSy
  local lerp = math.min(1, dt * CAMERA_LERP)
  CAMERA.sx = CAMERA.sx + (targetSx - CAMERA.sx) * lerp
  CAMERA.sy = CAMERA.sy + (targetSy - CAMERA.sy) * lerp

  -- Apply current cosmetics each frame so unlocks reflect immediately
  if state.cosmetics then
    Cosmetics.applyTo(world.char, state.cosmetics)
  end

  -- Trails / sparkles (emit into shared particle system)
  emitTrailParticles(state, world.char)
  emitSparkles(state, world.char)

  -- Pad cooldowns
  for i, cd in pairs(world.pad_cooldowns) do
    world.pad_cooldowns[i] = math.max(0, cd - dt)
  end

  -- Pad step-on auto-buy. Track entering pad to play charge sound +
  -- accumulate hold time so longer holds buy ×10 / max.
  world._inPad      = world._inPad or {}
  world._padHold    = world._padHold or {}
  for i, pad in ipairs(world.pads) do
    local on = inPad(world.char, pad)
    if on and not world._inPad[i] then
      world._inPad[i]   = true
      world._padHold[i] = 0
      Audio.padCharge()
    elseif not on and world._inPad[i] then
      world._inPad[i]   = nil
      world._padHold[i] = 0
    end
    if on then
      world._padHold[i] = (world._padHold[i] or 0) + dt
    end
    if (world.pad_cooldowns[i] or 0) <= 0 and on then
      world.pad_cooldowns[i] = PAD_COOLDOWN
      local qty = 1
      if (world._padHold[i] or 0) > PAD_HOLD_MAX then qty = "max"
      elseif (world._padHold[i] or 0) > PAD_HOLD_X10 then qty = 10 end
      if pad.kind == "miner" and callbacks and callbacks.onBuyMiner then
        callbacks.onBuyMiner(pad.def, qty)
      elseif pad.kind == "energy" and callbacks and callbacks.onBuyEnergy then
        callbacks.onBuyEnergy(pad.def, qty)
      end
    end
  end

  -- Footstep cadence
  if (world.char.vx * world.char.vx + world.char.vy * world.char.vy) > 0.05 then
    world._stepAccum = (world._stepAccum or 0) + dt
    if world._stepAccum > 0.32 then
      world._stepAccum = 0
      Audio.footstep()
    end
  else
    world._stepAccum = 0
  end

  -- Canisters
  tickCanisters(world, state, dt)

  -- Peers
  updatePeers(world, state, dt)

  -- Help banner: stays visible while the contextual tutorial is active
  -- (phases 1-3) so the new player is never lost. Once the loop is
  -- established (phase 4) the player can hide with [H].
  local phase = tutorialPhase(state)
  if phase < 4 then
    world.helpVisible = true
  end
end

-- ============================================================
-- Drawing
-- ============================================================

local function drawFloor(t)
  -- Tiled iso floor with subtle pulse on grid lines
  for y = 0, PLOT_H - 1 do
    for x = 0, PLOT_W - 1 do
      -- Alternating shade
      local shade = ((x + y) % 2 == 0) and 0.06 or 0.04
      local g = ((x + y) % 2 == 0) and 0.10 or 0.08
      Iso.drawTile(x, y, shade, g, shade + 0.02, 0.95, { 0.20, 0.55, 0.32, 0.20 })
    end
  end
  -- Edge ring
  for k = 0, PLOT_W - 1 do
    Iso.drawTile(k, 0, 0.08, 0.18, 0.10, 1, { 0.30, 1.00, 0.55, 0.30 })
    Iso.drawTile(k, PLOT_H - 1, 0.08, 0.18, 0.10, 1, { 0.30, 1.00, 0.55, 0.30 })
  end
  for k = 0, PLOT_H - 1 do
    Iso.drawTile(0, k, 0.08, 0.18, 0.10, 1, { 0.30, 1.00, 0.55, 0.30 })
    Iso.drawTile(PLOT_W - 1, k, 0.08, 0.18, 0.10, 1, { 0.30, 1.00, 0.55, 0.30 })
  end
end

local function drawPad(pad, state, t)
  local sx, sy = Iso.toScreen(pad.wx, pad.wy, 0)
  local owned, cost
  if pad.kind == "miner" then
    owned = state.miners[pad.key] or 0
    cost = minersDb.unitCost(pad.def, owned)
  else
    owned = state.energy[pad.key] or 0
    cost = energyDb.unitCost(pad.def, owned)
  end
  local affordable = state.z >= cost
  local color = pad.def.color
  if not affordable then
    color = { color[1] * 0.45, color[2] * 0.45, color[3] * 0.45 }
  end
  Assets.drawBuyPad(sx, sy, color, t, { phase = pad.phase })

  -- Floating tier + cost label (full name, not short code, so a Tab-first
  -- player can navigate without prior shop knowledge). 26-char truncation
  -- so "Antimatter Trap Reactor" (23) lands clean.
  local font = love.graphics.getFont()
  local fullName = pad.def.name or pad.def.short or "?"
  if #fullName > 26 then fullName = fullName:sub(1, 25) .. "…" end
  local nameLine = string.format("%s [T%d]", fullName, pad.def.tier)
  local nameW = font:getWidth(nameLine)
  -- Stagger labels vertically: even-tier pads sit higher so adjacent name
  -- plates don't horizontally overlap when the row is densely packed.
  local labelY = sy - 38 - ((pad.def.tier % 2 == 0) and 18 or 0)

  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", sx - nameW/2 - 6, labelY - 2, nameW + 12, 18, 3, 3)
  love.graphics.setColor(color[1], color[2], color[3], 1)
  love.graphics.rectangle("line", sx - nameW/2 - 6, labelY - 2, nameW + 12, 18, 3, 3)
  love.graphics.setColor(0.95, 1, 0.92, 1)
  love.graphics.print(nameLine, sx - nameW/2, labelY)

  -- Cost with Z-coin centered under name plate
  local costStr = fmt.zeptons(cost)
  local costW = font:getWidth(costStr)
  local coinSize = 8
  local totalW = coinSize * 2 + 6 + costW
  local costX = sx - totalW / 2
  local costColor = affordable and { 0.55, 1, 0.75 } or { 0.55, 0.55, 0.55 }
  Coin.drawWithLabel(costX, labelY + 26, coinSize, t, costStr, font, costColor,
    { color = color })

  love.graphics.setColor(0.55, 0.85, 0.65, 0.8)
  local ownStr = string.format("OWNED %d", owned)
  local owW = font:getWidth(ownStr)
  love.graphics.print(ownStr, sx - owW/2, labelY + 44)

  -- Hold-to-bulk hint
  if pad._holdRef and pad._holdRef > 0.05 then
    local hint
    if pad._holdRef > PAD_HOLD_MAX then hint = "BUY MAX"
    elseif pad._holdRef > PAD_HOLD_X10 then hint = "BUY ×10"
    else hint = string.format("hold ×10 %.0f%%", math.min(100, (pad._holdRef / PAD_HOLD_X10) * 100)) end
    local hw = font:getWidth(hint)
    love.graphics.setColor(1, 0.95, 0.55, 0.95)
    love.graphics.rectangle("fill", sx - hw/2 - 6, labelY + 62, hw + 12, 16, 3, 3)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(hint, sx - hw/2, labelY + 63)
  end
end

local function drawBuilt(world, state, t)
  -- Render miner racks & energy stations near their pads.
  for _, pad in ipairs(world.pads) do
    local count = (pad.kind == "miner" and state.miners or state.energy)[pad.key] or 0
    if count > 0 then
      -- Visual cap: draw min(N, 6) units arranged in a 3-wide row.
      local visible = math.min(6, count)
      local extra = count - visible
      local fn = (pad.kind == "miner") and Assets.miners[pad.key] or Assets.energy[pad.key]
      if fn then
        for i = 1, visible do
          local col = (i - 1) % 3
          local row = math.floor((i - 1) / 3)
          local wx = pad.anchor_wx + (col - 1) * 0.85
          local wy = pad.anchor_wy + (row * 0.85)
          local sx, sy = Iso.toScreen(wx, wy, 0)
          -- Mini platform under the rack
          love.graphics.setColor(pad.def.color[1] * 0.18, pad.def.color[2] * 0.18, pad.def.color[3] * 0.18, 0.85)
          love.graphics.ellipse("fill", sx, sy, 22, 7)
          love.graphics.setColor(pad.def.color[1] * 0.65, pad.def.color[2] * 0.65, pad.def.color[3] * 0.65, 0.80)
          love.graphics.ellipse("line", sx, sy, 22, 7)
          fn(sx, sy - 1, pad.def.color, t + i * 0.15)
        end
        if extra > 0 then
          -- Stack indicator
          local sx, sy = Iso.toScreen(pad.anchor_wx, pad.anchor_wy + 1.8, 0)
          love.graphics.setFont(love.graphics.getFont())
          love.graphics.setColor(0, 0, 0, 0.6)
          love.graphics.rectangle("fill", sx - 22, sy - 8, 44, 16, 3, 3)
          love.graphics.setColor(pad.def.color[1], pad.def.color[2], pad.def.color[3], 1)
          love.graphics.rectangle("line", sx - 22, sy - 8, 44, 16, 3, 3)
          love.graphics.setColor(0.95, 1, 0.92, 1)
          local s = string.format("+%d more", extra)
          local sw = love.graphics.getFont():getWidth(s)
          love.graphics.print(s, sx - sw/2, sy - 6)
        end
      end
    end
  end
end

local function drawCanisters(world, state, t)
  for _, c in ipairs(world.canisters) do
    local count = state.miners[c.key] or 0
    if count > 0 then
      local sx, sy = Iso.toScreen(c.wx, c.wy, 0)
      local fill = world.canister_fills[c.key] or 0
      Assets.drawCanister(sx, sy, fill, c.def.color, t)
    end
  end
end

-- ============================================================
-- Cosmetic toast and unlock notice (drawn in screen space)
-- ============================================================

-- Tutorial state: drives a contextual hint banner so a new player has
local function drawHelpBanner(world, state, fonts)
  local x = 40
  local y = DESIGN_H - 200
  local phase = tutorialPhase(state)
  if phase == 4 and not world.helpVisible then return end

  love.graphics.setColor(0.04, 0.07, 0.06, 0.92)
  love.graphics.rectangle("fill", x, y, 760, 134, 8, 8)
  love.graphics.setColor(0.30, 0.85, 0.55, 0.90)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, 760, 134, 8, 8)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(fonts.bold)
  love.graphics.setColor(0.55, 1, 0.75, 1)
  if phase == 1 then
    love.graphics.print("STEP 1 / 3  —  WALK YOUR FACILITY", x + 20, y + 12)
  elseif phase == 2 then
    love.graphics.print("STEP 2 / 3  —  BUILD MORE", x + 20, y + 12)
  elseif phase == 3 then
    love.graphics.print("STEP 3 / 3  —  OPEN THE Z STORE", x + 20, y + 12)
  else
    love.graphics.print("FACILITY WORLD VIEW", x + 20, y + 12)
  end

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.85, 0.95, 0.90, 1)
  if phase == 1 then
    love.graphics.print("Mining runs passively in the background — your starter solar panel is", x + 20, y + 42)
    love.graphics.print("powering 1 ASIC miner right now. Walk around with [W A S D] to explore.", x + 20, y + 62)
    love.graphics.setColor(0.55, 0.85, 0.65, 0.95)
    love.graphics.print("Click the core orb in core ops for a manual bonus on top of passive Z/s.", x + 20, y + 90)
  elseif phase == 2 then
    love.graphics.print("Walk onto any glowing pad to build that miner or energy plant. Hold longer", x + 20, y + 42)
    love.graphics.print("for ×10 / MAX. Build more energy first when the grid throttles (red bar).", x + 20, y + 62)
    love.graphics.setColor(0.55, 0.85, 0.65, 0.95)
    love.graphics.print("Energy on top, mining on bottom. Climb the tiers as your Z balance grows.", x + 20, y + 90)
  elseif phase == 3 then
    love.graphics.print("[TAB] swaps to CORE OPS — the dashboard / Z store. Buy upgrades, see your", x + 20, y + 42)
    love.graphics.print("hash rate, find blocks, check the live mesh, and click the orb for a bonus.", x + 20, y + 62)
    love.graphics.setColor(0.55, 0.85, 0.65, 0.95)
    love.graphics.print("Tab back here any time to keep building.", x + 20, y + 90)
  else
    love.graphics.print("[WASD] walk  ·  step on a glowing pad to build (hold for ×10 / MAX)", x + 20, y + 42)
    love.graphics.print("[E] wave  ·  [F] flag  ·  [C/V/B/N/M] palette / trail / aura / halo / wings", x + 20, y + 62)
    love.graphics.setColor(0.55, 0.85, 0.65, 0.95)
    love.graphics.print("[TAB] core ops & Z store  ·  [H] hide this banner  ·  [P] pause  ·  [S] save", x + 20, y + 90)
  end

  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.45, 0.65, 0.55, 0.85)
  love.graphics.print("[H] hide / show this banner", x + 20, y + 114)
end

local function drawCosmeticToast(state, fonts, t)
  if not state._cosmeticToast then return end
  local toast = state._cosmeticToast
  local age = love.timer.getTime() - toast.t
  if age > 5 then state._cosmeticToast = nil; return end
  local alpha = math.min(1, math.min(age * 4, (5 - age) * 0.8))
  local x = DESIGN_W / 2 - 240
  local y = 130
  love.graphics.setColor(0.04, 0.07, 0.06, 0.92 * alpha)
  love.graphics.rectangle("fill", x, y, 480, 70, 8, 8)
  love.graphics.setColor(toast.color[1], toast.color[2], toast.color[3], alpha)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, 480, 70, 8, 8)
  love.graphics.setLineWidth(1)
  love.graphics.setFont(fonts.bold)
  love.graphics.setColor(0.95, 1, 0.92, alpha)
  love.graphics.print("✦  COSMETIC UNLOCKED", x + 16, y + 8)
  love.graphics.setFont(fonts.medium)
  love.graphics.setColor(toast.color[1], toast.color[2], toast.color[3], alpha)
  love.graphics.print(toast.name, x + 16, y + 36)
end

-- ============================================================
-- Top-level draw
-- ============================================================

function M.draw(world, state, fonts, t)
  -- Backdrop
  love.graphics.clear(0.01, 0.03, 0.02, 1)

  -- Soft starfield (deterministic)
  for i = 1, 80 do
    local sx = (i * 137) % DESIGN_W
    local sy = (i * 71) % (DESIGN_H - 200) + 80
    local twinkle = math.sin(t * 1.7 + i * 0.3) * 0.5 + 0.5
    love.graphics.setColor(0.55, 1, 0.75, 0.10 + twinkle * 0.18)
    love.graphics.points(sx, sy)
  end

  -- Miracle SKY phase — drawn in screen space behind the iso world
  -- so e.g. mountains appear as a horizon and rain falls behind racks.
  MiracleFx.drawSky(state, t)

  -- Camera transform
  love.graphics.push()
  love.graphics.translate(CAMERA.sx, CAMERA.sy)

  drawFloor(t)

  -- Build a depth-sorted entity list: pads, characters, peers, built items, canisters.
  local entities = {}

  for i, pad in ipairs(world.pads) do
    pad._holdRef = world._padHold and world._padHold[i] or 0
    table.insert(entities, { kind = "pad", pad = pad, depth = Iso.depth(pad.wx, pad.wy, 0) })
  end
  for _, c in ipairs(world.canisters) do
    if (state.miners[c.key] or 0) > 0 then
      table.insert(entities, { kind = "canister", c = c, depth = Iso.depth(c.wx, c.wy, 0) + 5 })
    end
  end
  for _, pad in ipairs(world.pads) do
    local count = (pad.kind == "miner" and state.miners or state.energy)[pad.key] or 0
    if count > 0 then
      local visible = math.min(6, count)
      -- Center the rack on the pad and shrink column step inversely with
      -- tier count so 11-energy/10-miner racks don't bump into neighbors.
      local listLen = (pad.kind == "miner") and #minersDb.list or #energyDb.list
      local slotW = (PLOT_W - 4) / listLen
      local colStep = math.min(0.85, slotW * 0.35)
      local rowStep = math.min(0.85, slotW * 0.35)
      local offset = (visible - 1) * 0.5
      for i = 1, visible do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local wx = pad.anchor_wx + (col - 1) * colStep
        local wy = pad.anchor_wy + (row * rowStep)
        local fn = (pad.kind == "miner") and Assets.miners[pad.key] or Assets.energy[pad.key]
        if fn then
          table.insert(entities, {
            kind = "built", fn = fn, color = pad.def.color,
            wx = wx, wy = wy,
            depth = Iso.depth(wx, wy, 0),
            phase = i * 0.15,
            count = count,  -- pass for visuals scaling
          })
        end
      end
    end
  end

  -- Player + peers — drop the +1 depth bias. We instead nudge the
  -- character's Y by 0.05 so a character standing on the same row as
  -- a rack sorts behind/in-front naturally based on actual position.
  table.insert(entities, { kind = "char", char = world.char,
    depth = Iso.depth(world.char.wx, world.char.wy + 0.05, 0) })
  for _, pc in pairs(world.peers) do
    table.insert(entities, { kind = "peer", char = pc.char,
      depth = Iso.depth(pc.char.wx, pc.char.wy + 0.05, 0) })
  end

  -- Monoliths — one entry per owned monolith, arranged in a row at
  -- the very top of the plot (north of the miner racks). Each gets
  -- its own world position so they read as a horizon of obelisks.
  if (state.monoliths or 0) > 0 then
    local count = state.monoliths
    -- Spread monoliths across the full plot width on a thin row
    for i = 1, math.min(count, 14) do
      local frac = (i - 0.5) / math.max(1, math.min(count, 14))
      local mx = 1 + frac * (PLOT_W - 2)
      local my = 0.5
      table.insert(entities, {
        kind = "monolith",
        wx = mx, wy = my,
        depth = Iso.depth(mx, my, 0) - 5,  -- behind characters/canisters
      })
    end
  end

  -- Self-planted flags
  if world.flags then
    for _, fl in ipairs(world.flags) do
      table.insert(entities, { kind = "flag", flag = fl,
        depth = Iso.depth(fl.wx or 0, fl.wy or 0, 0) - 1 })
    end
  end
  -- Peer flags
  if state.network and state.network.received_flags then
    for _, fl in ipairs(state.network.received_flags) do
      if fl.wx and fl.wy then
        table.insert(entities, { kind = "peer_flag", flag = fl,
          depth = Iso.depth(fl.wx, fl.wy, 0) - 1 })
      end
    end
  end

  table.sort(entities, function(a, b) return a.depth < b.depth end)

  for _, e in ipairs(entities) do
    if e.kind == "pad" then
      drawPad(e.pad, state, t)
    elseif e.kind == "canister" then
      local sx, sy = Iso.toScreen(e.c.wx, e.c.wy, 0)
      local fill = world.canister_fills[e.c.key] or 0
      Assets.drawCanister(sx, sy, fill, e.c.def.color, t)
    elseif e.kind == "built" then
      local sx, sy = Iso.toScreen(e.wx, e.wy, 0)
      -- Platform visibly grows as you build more of this tier.
      local growth = 1 + math.min(1.0, math.log10(math.max(1, e.count or 1)) * 0.18)
      love.graphics.setColor(e.color[1] * 0.18, e.color[2] * 0.18, e.color[3] * 0.18, 0.85)
      love.graphics.ellipse("fill", sx, sy, 22 * growth, 7 * growth)
      love.graphics.setColor(e.color[1] * 0.65, e.color[2] * 0.65, e.color[3] * 0.65, 0.80)
      love.graphics.ellipse("line", sx, sy, 22 * growth, 7 * growth)
      e.fn(sx, sy - 1, e.color, t + e.phase)
      -- Crown the rack with intensity sparks the more units you've built.
      if (e.count or 0) > 6 then
        local sparkN = math.min(8, math.floor(math.log10(e.count) * 4))
        for k = 0, sparkN do
          local a = (t * 0.7 + k / (sparkN + 1)) * math.pi * 2
          local rr = 24 * growth + math.sin(t * 2 + k) * 2
          love.graphics.setColor(e.color[1], e.color[2], e.color[3], 0.85)
          love.graphics.circle("fill",
            sx + math.cos(a) * rr,
            sy - 30 + math.sin(a) * rr * 0.45, 1.6)
        end
      end
    elseif e.kind == "char" then
      Char.draw(e.char, t)
    elseif e.kind == "peer" then
      Char.draw(e.char, t)
    elseif e.kind == "monolith" then
      local sx, sy = Iso.toScreen(e.wx, e.wy, 0)
      Assets.drawMonolith(sx, sy, t)
    elseif e.kind == "flag" or e.kind == "peer_flag" then
      local fl = e.flag
      local sx, sy = Iso.toScreen(fl.wx, fl.wy, 0)
      local age = love.timer.getTime() - (fl.plantedAt or fl.receivedAt or love.timer.getTime())
      local color = fl.color or { 1, 0.95, 0.55 }
      -- Pole
      love.graphics.setColor(0.40, 0.40, 0.45, 1)
      love.graphics.line(sx, sy, sx, sy - 32)
      -- Flag wave
      local wav = math.sin(t * 3) * 3
      local pts = {
        sx, sy - 32,
        sx + 18 + wav, sy - 28 + wav * 0.5,
        sx + 18 + wav, sy - 18 + wav * 0.5,
        sx, sy - 22,
      }
      love.graphics.setColor(color[1], color[2], color[3], 0.85)
      love.graphics.polygon("fill", pts)
      love.graphics.setColor(color[1], color[2], color[3], 1)
      love.graphics.polygon("line", pts)
      -- Glow base
      love.graphics.setColor(color[1], color[2], color[3], 0.30 + math.sin(t * 2) * 0.10)
      love.graphics.ellipse("fill", sx, sy + 2, 12, 4)
      -- Owner label
      if fl.name then
        local font = love.graphics.getFont()
        local lw = font:getWidth(fl.name)
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", sx - lw/2 - 4, sy - 50, lw + 8, 14, 3, 3)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("line", sx - lw/2 - 4, sy - 50, lw + 8, 14, 3, 3)
        love.graphics.setColor(0.95, 1, 0.92, 1)
        love.graphics.print(fl.name, sx - lw/2, sy - 49)
      end
    end
  end

  love.graphics.pop()

  -- Miracle POST phase — particles + fireflies + angels in screen
  -- space on top of the iso plot, but beneath the HUD chrome.
  MiracleFx.drawPost(state, t)

  -- Top label strip — reuse HUD-like top bar but tinted differently
  love.graphics.setColor(0.025, 0.05, 0.04, 0.92)
  love.graphics.rectangle("fill", 0, 96, DESIGN_W, 32)
  love.graphics.setColor(0.20, 0.55, 0.32, 0.7)
  love.graphics.line(0, 128, DESIGN_W, 128)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.55, 1, 0.75, 1)
  love.graphics.print("WORLD VIEW  ·  step on a pad to build  ·  [TAB] core ops", 24, 102)

  -- Banner help
  if world.helpVisible then
    drawHelpBanner(world, state, fonts)
  end

  -- Cosmetic toast
  drawCosmeticToast(state, fonts, t)
end

-- ============================================================
-- Input
-- ============================================================

function M.keypressed(world, state, key, callbacks)
  if key == "tab" or key == "escape" then
    if callbacks and callbacks.toCore then callbacks.toCore() end
  elseif key == "h" then
    world.helpVisible = not world.helpVisible
    world.helpTimer = 0
  elseif key == "c" then
    if state.cosmetics then
      local p = Cosmetics.cyclePalette(state.cosmetics, 1)
      Cosmetics.applyTo(world.char, state.cosmetics)
      if callbacks and callbacks.onMessage and p then
        callbacks.onMessage("Palette: " .. p.name, { 0.85, 0.95, 1 })
      end
    end
  elseif key == "v" then
    if state.cosmetics then
      local d = Cosmetics.cycleSlot(state.cosmetics, "trail", 1)
      Cosmetics.applyTo(world.char, state.cosmetics)
      if callbacks and callbacks.onMessage then
        callbacks.onMessage("Trail: " .. (d and d.name or "off"), { 0.55, 1, 0.75 })
      end
    end
  elseif key == "b" then
    if state.cosmetics then
      local d = Cosmetics.cycleSlot(state.cosmetics, "aura", 1)
      Cosmetics.applyTo(world.char, state.cosmetics)
      if callbacks and callbacks.onMessage then
        callbacks.onMessage("Aura: " .. (d and d.name or "off"), { 1, 0.85, 0.45 })
      end
    end
  elseif key == "n" then
    if state.cosmetics then
      local d = Cosmetics.cycleSlot(state.cosmetics, "halo", 1)
      Cosmetics.applyTo(world.char, state.cosmetics)
      if callbacks and callbacks.onMessage then
        callbacks.onMessage("Halo: " .. (d and d.name or "off"), { 0.55, 0.85, 1 })
      end
    end
  elseif key == "m" then
    if state.cosmetics then
      local d = Cosmetics.cycleSlot(state.cosmetics, "wings", 1)
      Cosmetics.applyTo(world.char, state.cosmetics)
      if callbacks and callbacks.onMessage then
        callbacks.onMessage("Wings: " .. (d and d.name or "off"), { 1, 0.5, 0.85 })
      end
    end
  elseif key == "e" then
    if callbacks and callbacks.onWave then callbacks.onWave() end
  elseif key == "f" then
    if callbacks and callbacks.onFlag then callbacks.onFlag() end
  end
end

return M
