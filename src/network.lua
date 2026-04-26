-- Network mesh — primary path uses the portal's real multi-user layer
-- via [[LOVEWEB_NET]] magic-prints (see src/net.lua) and the
-- __loveweb__/net/* file snapshots. A deterministic simulated mesh is
-- retained as a graceful fallback for desktop / pre-connect / signed-out
-- play, so the panel is never empty.
--
-- The same public API is exposed regardless of mode, so shop.lua /
-- game.lua / facility.lua never need to branch:
--
--   Network.new(facility_seed, playerStats)
--   Network.update(state, dt, playerStats)
--   Network.snapshots(state)            -> NetSnapshot[]
--   Network.events(state, count)        -> NetTickerEvent[]
--   Network.interact(state, target_id, kind, paid?)
--   Network.tickPool(state, dt, playerZps) -> outflow, payout
--   Network.collectPendingBonuses(state) -> total
--   Network.notify(state, kind, payload) -> broadcast a game event

local fmt        = require "src.format"
local minersDb   = require "src.miners"
local energyDb   = require "src.energy"
local Net        = require "src.net"

local M = {}

-- ============================================================
-- Naming / avatar (used by sim and as an avatar derivation for real peers)
-- ============================================================

local PREFIXES = {
  "VOIDREACH", "ARCLIGHT", "SOLEMN", "WATTSPRING", "GLEAMHOUSE",
  "DEEPSEAM", "FALLOW", "AURELION", "STARBOUND", "PALEHORIZON",
  "BLACKBOX", "PRISMA", "RIVERHEART", "EMERALD-K", "AETHERFOLD",
  "QUARTZ", "BRIGHTHALO", "ZEROTH", "FUNDAMENT", "VANTABLOCK",
  "CRYO-DELTA", "STORMWAY", "HELIOMARK", "OBSIDIAN", "SENTINEL",
}
local SUFFIXES = {
  "OPS", "WORKS", "DEEP", "LABS", "FOUNDRY", "CONSORTIUM", "REFINERY",
  "FORGE", "INSTALLATION", "GRID", "ALIGNMENT", "STACK", "NODE", "VAULT",
  "INC.", "CO.", "GROUP", "SYNDICATE",
}
local CODES = { "K", "Z", "X", "9", "K9", "ZX", "II", "III", "IV" }

local function pickFromSeed(rng, list)
  return list[1 + (rng:random(0, #list - 1))]
end

local function nameFromSeed(seed, idx)
  local rng = love.math.newRandomGenerator(seed * 7919 + idx * 31)
  local p = pickFromSeed(rng, PREFIXES)
  local s = pickFromSeed(rng, SUFFIXES)
  if rng:random(0, 100) < 70 then
    return p .. " " .. s
  end
  return p .. "-" .. pickFromSeed(rng, CODES) .. " " .. s
end

local function pickAvatar(seedNum)
  local rng = love.math.newRandomGenerator(seedNum)
  local hue = rng:random(0, 360)
  local h = hue / 60
  local i = math.floor(h)
  local f = h - i
  local p = 0.3
  local q = 0.3 + 0.6 * (1 - f)
  local r, g, b
  if i == 0 then r, g, b = 0.95, q, p
  elseif i == 1 then r, g, b = 0.6 + 0.3 * (1 - f), 0.95, p
  elseif i == 2 then r, g, b = p, 0.95, q
  elseif i == 3 then r, g, b = p, 0.5 + 0.45 * (1 - f), 0.95
  elseif i == 4 then r, g, b = q, p, 0.95
  else r, g, b = 0.95, p, q end
  return {
    color = { r, g, b },
    glyph_index = rng:random(0, 5),
    frame_kind = rng:random(0, 3),
  }
end

local function hashUserIdToInt(s)
  -- Simple deterministic 32-bit hash for userId -> int seed
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 4294967296
  end
  return h
end

-- ============================================================
-- Sim layer (fallback)
-- ============================================================

local PLAYER_COUNT_SIM = 14

local function statusFromCycle(p, t)
  local cycleLen = 6 * 60 + (p.cycleSeed % 360)
  local x = ((t + p.cycleOffset) / cycleLen) % 1
  if x < 0.60 then return "online"
  elseif x < 0.85 then return "afk"
  else return "offline" end
end

local function makeSimPlayer(seed, idx, t0)
  local rng = love.math.newRandomGenerator(seed * 4093 + idx * 17 + 3)
  return {
    id           = string.format("ghost-%d-%d", seed % 0xFFFF, idx),
    name         = nameFromSeed(seed, idx),
    seed         = seed * 4093 + idx,
    levelOffset  = rng:random(-25, 35) / 10,
    growthRate   = 0.85 + rng:random(0, 60) / 100,
    cycleOffset  = rng:random(0, 12 * 60),
    cycleSeed    = rng:random(0, 1000),
    avatar       = pickAvatar(seed * 4093 + idx + 11),
    last_block_announced = -10,
    last_built_announced = -10,
    spawn_t      = t0,
  }
end

local function levelFromZ(z)
  if z <= 1 then return 0 end
  return math.log(z) / math.log(10)
end

local function zFromLevel(L)
  if L <= 0 then return 0 end
  return math.pow(10, L)
end

local function simSnapshot(p, t, playerStats)
  local pl = levelFromZ(math.max(1, playerStats.z_lifetime or 1))
  local elapsed = math.max(0, t - p.spawn_t)
  local levelDrift = (elapsed / 600) * (p.growthRate - 1) * 1.2
  local level = pl + p.levelOffset + levelDrift
  if level < 0 then level = 0 end
  local lifetime = zFromLevel(level)
  local rate = lifetime / 200 * (0.6 + (p.seed % 80) / 100)
  local hashrate = rate * 110e12
  local status = statusFromCycle(p, t)
  local effectiveRate = rate
  if status == "offline" then effectiveRate = 0
  elseif status == "afk" then effectiveRate = rate * 0.4 end
  return {
    z_lifetime = lifetime,
    z_per_sec  = effectiveRate,
    hashrate   = hashrate,
    status     = status,
    level      = level,
    avatar     = p.avatar,
    name       = p.name,
    id         = p.id,
    sim        = true,
  }
end

-- ============================================================
-- Event ticker management
-- ============================================================

local function pushEvent(state, kind, text, color)
  state.events = state.events or {}
  table.insert(state.events, {
    t     = state._t or 0,
    kind  = kind,
    text  = text,
    color = color or { 0.85, 1, 0.92 },
  })
  while #state.events > 32 do table.remove(state.events, 1) end
end

local function maybeSimAnnounceBlock(state, p, snap)
  if snap.status == "offline" then return end
  if snap.z_per_sec <= 0 then return end
  local rng = love.math.newRandomGenerator(p.seed + math.floor(state._t / 12))
  if (state._t - p.last_block_announced) > (60 + (p.seed % 240)) and rng:random(0, 100) < 6 then
    p.last_block_announced = state._t
    local reward = math.max(40, snap.z_per_sec * 30)
    pushEvent(state, "block",
      string.format("⛏  %s found a block — +%s Z", p.name, fmt.zeptons(reward)),
      { 1, 0.95, 0.55 })
  end
end

local function maybeSimAnnounceBuild(state, p, snap)
  if snap.status == "offline" then return end
  local rng = love.math.newRandomGenerator(p.seed + math.floor(state._t / 19))
  if (state._t - p.last_built_announced) > (90 + (p.seed % 240)) and rng:random(0, 100) < 4 then
    p.last_built_announced = state._t
    local level = snap.level
    local choices
    if level < 4 then
      choices = { { kind = "miner", key = "asic_z1" }, { kind = "energy", key = "solar" }, { kind = "energy", key = "wind" } }
    elseif level < 7 then
      choices = { { kind = "miner", key = "gpu_cluster" }, { kind = "miner", key = "quantum_miner" }, { kind = "energy", key = "hydro" }, { kind = "energy", key = "geothermal" } }
    elseif level < 10 then
      choices = { { kind = "miner", key = "quantum_miner" }, { kind = "miner", key = "neural_forge" }, { kind = "energy", key = "fission" } }
    else
      choices = { { kind = "miner", key = "neural_forge" }, { kind = "miner", key = "hyperdrive_rig" }, { kind = "miner", key = "singularity_engine" }, { kind = "energy", key = "fusion" }, { kind = "energy", key = "antimatter" }, { kind = "energy", key = "zeropoint" } }
    end
    local pick = choices[1 + rng:random(0, #choices - 1)]
    local def = (pick.kind == "miner") and minersDb.byKey[pick.key] or energyDb.byKey[pick.key]
    if def then
      pushEvent(state, "build",
        string.format("▦  %s deployed a %s", p.name, def.name),
        def.color)
    end
  end
end

-- ============================================================
-- Public API: new
-- ============================================================

function M.new(facility_seed, playerStats)
  local s = {
    facility_seed = facility_seed,
    mode = "sim",
    sim_players = {},
    realPeers = {},
    peer_memory = {},
    received_flags = {},
    events  = {},
    pool_with = nil,
    pool_started_at = 0,
    interactions = {},
    boostCount = 0,
    _lastStatsBroadcast    = -100,
    _statsInterval         = 8,
    _lastSlugPresence      = -100,
    _slugPresenceInterval  = 30,
    _bootstrapped          = false,
    _hasJoinedRoom         = false,
    _bootstrapAttemptedAt  = 0,
    self_userId   = nil,
    self_handle   = nil,
    self_facility_name = nil,
    _t = 0,
    _lastTick = 0,
    _seenIds = {},
    _profileRequested = {},        -- userId -> requested-at, throttle
    _slugTopUsers = {},            -- list from active.json
    _slugStats = nil,              -- last full active.json
    _surgeUntil = 0,               -- absolute timer.getTime when surge ends
    _surgeMult  = 0.5,             -- 50% bonus during surge
    _lastBroadcast = -100,         -- broadcast emit gate
    _broadcastedBlocks = 0,        -- last block height we broadcast
    _broadcastedHalvings = 0,      -- last halving count we broadcast
    _broadcastedNewTiers = {},     -- "miner:asic_z1" -> true
  }
  for i = 1, PLAYER_COUNT_SIM do
    s.sim_players[i] = makeSimPlayer(facility_seed, i, 0)
  end
  return s
end

-- ============================================================
-- Real-mode: incoming event handler
-- ============================================================

local function ensurePeer(state, evt)
  if not evt.userId then return nil end
  local p = state.realPeers[evt.userId]
  if not p then
    local seedNum = hashUserIdToInt(evt.userId)
    p = {
      id          = evt.userId,
      handle      = evt.handle or "operator",
      facility_name = evt.handle or nameFromSeed(seedNum, 0),
      avatar      = pickAvatar(seedNum),
      joinedAt    = state._t,
      lastUpdate  = state._t,
      z_per_sec   = 0,
      hashrate    = 0,
      z_lifetime  = 0,
      online      = true,
      level       = 0,
    }
    state.realPeers[evt.userId] = p
  end
  if evt.handle and evt.handle ~= "" then p.handle = evt.handle end
  return p
end

local function applyRosterPresence(state)
  -- Roster from net.lua tells us who is currently in the room.
  local seen = {}
  for _, m in ipairs(Net.members or {}) do
    if m.userId and m.userId ~= (state.self_userId or "") then
      local p = state.realPeers[m.userId]
      if not p then
        local seedNum = hashUserIdToInt(m.userId)
        p = {
          id          = m.userId,
          handle      = m.handle or "operator",
          facility_name = m.handle or nameFromSeed(seedNum, 0),
          avatar      = pickAvatar(seedNum),
          joinedAt    = m.joinedAt or state._t,
          lastUpdate  = state._t,
          z_per_sec   = 0,
          hashrate    = 0,
          z_lifetime  = 0,
          online      = true,
          level       = 0,
        }
        state.realPeers[m.userId] = p
      end
      p.online = true
      p.lastSeen = m.lastSeen
      seen[m.userId] = true
    end
  end
  for uid, p in pairs(state.realPeers) do
    if not seen[uid] then
      p.online = false
    end
  end
end

local function onNetEvent(state, evt)
  if not evt then return end
  -- Reserved verbs from portal: "join", "leave", "state"
  if evt.verb == "join" then
    if evt.userId and evt.userId ~= (state.self_userId or "") then
      local p = ensurePeer(state, evt)
      pushEvent(state, "join",
        string.format("◉  %s joined the mesh", p.facility_name),
        { 0.55, 0.95, 0.75 })
    end
    return
  end
  if evt.verb == "leave" then
    if evt.userId and state.realPeers[evt.userId] then
      local p = state.realPeers[evt.userId]
      p.online = false
      pushEvent(state, "leave",
        string.format("◌  %s went offline", p.facility_name),
        { 0.55, 0.55, 0.65 })
    end
    return
  end
  if evt.verb == "state" then
    -- Server-side state mutations — currently no-op (we don't lean on
    -- shared state, only events).
    return
  end
  -- Game-defined verbs follow.
  local payload = evt.payload or {}
  if evt.verb == "stats" then
    local p = ensurePeer(state, evt)
    if p then
      if payload.facility_name then p.facility_name = payload.facility_name end
      p.z_per_sec  = tonumber(payload.z_per_sec) or p.z_per_sec
      p.hashrate   = tonumber(payload.hashrate)  or p.hashrate
      p.z_lifetime = tonumber(payload.z_lifetime) or p.z_lifetime
      p.level      = tonumber(payload.level) or levelFromZ(math.max(1, p.z_lifetime))
      p.lastUpdate = state._t
      p.online     = true
    end
  elseif evt.verb == "block" then
    local who = (evt.handle or "operator")
    if state.realPeers[evt.userId or ""] then
      who = state.realPeers[evt.userId].facility_name
    end
    pushEvent(state, "block",
      string.format("⛏  %s found a block — +%s Z", who, fmt.zeptons(tonumber(payload.reward) or 0)),
      { 1, 0.95, 0.55 })
  elseif evt.verb == "build" then
    local who = (evt.handle or "operator")
    if state.realPeers[evt.userId or ""] then
      who = state.realPeers[evt.userId].facility_name
    end
    local kind = payload.kind
    local key = payload.key
    local def = (kind == "miner") and minersDb.byKey[key] or (kind == "energy") and energyDb.byKey[key] or nil
    if def then
      pushEvent(state, "build",
        string.format("▦  %s deployed a %s", who, def.name),
        def.color)
    end
  elseif evt.verb == "halving" then
    local who = (evt.handle or "operator")
    if state.realPeers[evt.userId or ""] then
      who = state.realPeers[evt.userId].facility_name
    end
    pushEvent(state, "halving",
      string.format("½  %s endured a halving event", who),
      { 0.85, 0.65, 1 })
  elseif evt.verb == "boost" then
    -- Inbound boost. If addressed to me, schedule a thanks reply.
    local target = payload.target or payload.to
    local senderName = (evt.handle or "operator")
    local senderPeer = state.realPeers[evt.userId or ""]
    if senderPeer then senderName = senderPeer.facility_name end
    if target and state.self_userId and target == state.self_userId then
      table.insert(state.interactions, {
        kind = "incoming_boost",
        from_id = evt.userId,
        from_name = senderName,
        paid = tonumber(payload.paid) or 0,
        respond_at = state._t + 30 + love.math.random() * 90,
        responded = false,
      })
      pushEvent(state, "boost_in",
        string.format("⇄  %s boosted YOU — +%s Z incoming", senderName, fmt.zeptons(tonumber(payload.paid) or 0)),
        { 0.55, 0.85, 1 })
    else
      -- Cosmetic chatter
      pushEvent(state, "boost",
        string.format("⇄  %s boosted a peer (%s Z)", senderName, fmt.zeptons(tonumber(payload.paid) or 0)),
        { 0.45, 0.70, 0.95 })
    end
  elseif evt.verb == "thanks" then
    -- Inbound thanks — purely social. No BTC is credited; the boost
    -- you sent earlier was a tip out of your own balance with no
    -- expected return. We just surface a "they say thanks" toast.
    local target = payload.target or payload.to
    if target and state.self_userId and target == state.self_userId then
      local senderName = evt.handle or "operator"
      local senderPeer = state.realPeers[evt.userId or ""]
      if senderPeer then senderName = senderPeer.facility_name end
      pushEvent(state, "thanks",
        string.format("✦  %s says thanks for the boost", senderName),
        { 1, 0.85, 0.45 })
    end
  elseif evt.verb == "pool_request" then
    -- Inbound pool request. We do NOT auto-accept — the player gets
    -- a banner with ACCEPT / DECLINE buttons. shop.lua reads
    -- state.pool_pending_incoming to render the prompt.
    local target = payload.target or payload.to
    if target and state.self_userId and target == state.self_userId then
      local senderName = evt.handle or "operator"
      local senderPeer = state.realPeers[evt.userId or ""]
      if senderPeer then senderName = senderPeer.facility_name end
      state.pool_pending_incoming = {
        from_id = evt.userId,
        from_name = senderName,
        received_at = state._t,
      }
      pushEvent(state, "pool_in",
        string.format("⛓  %s wants to pool with you", senderName),
        { 0.55, 0.85, 0.95 })
    end
  elseif evt.verb == "pool_accept" then
    -- Our request was accepted. Now we're partnered.
    local target = payload.target or payload.to
    if target and state.self_userId and target == state.self_userId
       and state.pool_pending_outgoing
       and state.pool_pending_outgoing.target_id == evt.userId then
      state.pool_with = evt.userId
      state.pool_pending_outgoing = nil
      state.pool_started_at = state._t
      local who = (state.realPeers[evt.userId or ""] and state.realPeers[evt.userId].facility_name)
                  or evt.handle or "operator"
      pushEvent(state, "pool_accept",
        string.format("⛓  %s accepted your pool request", who),
        { 0.55, 1, 0.75 })
    end
  elseif evt.verb == "pool_decline" then
    local target = payload.target or payload.to
    if target and state.self_userId and target == state.self_userId
       and state.pool_pending_outgoing
       and state.pool_pending_outgoing.target_id == evt.userId then
      state.pool_pending_outgoing = nil
      local who = (state.realPeers[evt.userId or ""] and state.realPeers[evt.userId].facility_name)
                  or evt.handle or "operator"
      pushEvent(state, "pool_decline",
        string.format("⛓  %s declined the pool request", who),
        { 1, 0.55, 0.55 })
    end
  elseif evt.verb == "pool_leave" then
    -- The other side ended the pool — clear our side too.
    if state.pool_with == evt.userId then
      state.pool_with = nil
      pushEvent(state, "pool_leave",
        string.format("⛓  %s left the pool", evt.handle or "operator"),
        { 0.85, 0.55, 0.55 })
    end
  elseif evt.verb == "pos" then
    -- Real-time peer position update. Stored on the realPeer record;
    -- world.lua reads this and steers the peer character toward it.
    local p = ensurePeer(state, evt)
    if p then
      p.posX     = tonumber(payload.wx) or p.posX
      p.posY     = tonumber(payload.wy) or p.posY
      p.posVX    = tonumber(payload.vx) or 0
      p.posVY    = tonumber(payload.vy) or 0
      p.posFacing = tonumber(payload.facing) or 0
      p.posUpdatedAt = state._t
    end
  elseif evt.verb == "wave" then
    -- Set a wave indicator on the peer character
    local p = state.realPeers[evt.userId or ""]
    if p then
      p.waveTimer = 1.4
    end
    state.events_pending = state.events_pending or {}
    table.insert(state.events_pending, {
      kind = "peer_wave", userId = evt.userId,
    })
  elseif evt.verb == "flag" then
    -- Stash a peer flag in the visitor ribbon (south of the player's
    -- own pads/miners/energy/wallet). The peer's broadcast wx/wy is
    -- coordinates on THEIR plot — meaningless on ours, and rendering
    -- a peer flag right on top of one of OUR buy pads makes it look
    -- like a peer's pad we can interact with. They live in the
    -- visitor zone, period.
    state.received_flags = state.received_flags or {}
    local seedNum = 0
    for ch = 1, (evt.userId and #evt.userId or 1) do
      seedNum = seedNum + (evt.userId and evt.userId:byte(ch) or 0)
    end
    -- Spread flags across the visitor ribbon's x-axis so multiple
    -- inbound flags don't all land on the same tile.
    local visitorX = 2 + (seedNum % 14)
    local visitorY = 17.0 + ((seedNum % 3) * 0.2)
    table.insert(state.received_flags, {
      userId = evt.userId,
      name   = (payload.name or evt.handle or "operator"),
      wx = visitorX, wy = visitorY,
      receivedAt = state._t,
    })
    while #state.received_flags > 24 do
      table.remove(state.received_flags, 1)
    end
    local who = (evt.handle or payload.name or "operator")
    pushEvent(state, "flag",
      string.format("⚑  %s planted a flag", who),
      { 1, 0.95, 0.55 })
  end
end

-- ============================================================
-- Bootstrapping the room (real mode)
-- ============================================================

local function attemptBootstrap(state)
  if state._bootstrapped then return end
  -- Wait until status appears (i.e., we're on the portal)
  if Net._seenStatusAt == nil then
    -- Even on first call, kick a list/create speculatively. On desktop the
    -- magic-prints simply log; no harm done.
  end
  if state._bootstrapAttemptedAt > 0 and (state._t - state._bootstrapAttemptedAt) < 2.5 then
    return
  end
  state._bootstrapAttemptedAt = state._t

  -- If already in a room (status connected and room snapshot present), done.
  if Net.connected() and Net.room and Net.room.id then
    state._bootstrapped = true
    state._hasJoinedRoom = true
    return
  end

  -- Step 1: ask for the public room list (idempotent)
  if not state._listed then
    Net.list()
    state._listed = true
    return
  end
  -- Step 2: pick a target room from the result if available; otherwise create.
  local lr = Net.lastResult
  if lr and lr.rooms and #lr.rooms > 0 then
    -- Choose the room with most online members under capacity, prefer ours.
    local best
    for _, r in ipairs(lr.rooms) do
      if (r.onlineCount or r.memberCount or 0) < (r.capacity or 8) then
        if not best or (r.onlineCount or 0) > (best.onlineCount or 0) then
          best = r
        end
      end
    end
    if best and best.code then
      Net.join(best.code)
      state._joinAttempted = true
      return
    end
  end
  if not state._createAttempted then
    Net.create("A-TEK Mesh")
    state._createAttempted = true
  end
end

-- ============================================================
-- Update tick
-- ============================================================

local function onSlugEvent(state, evt)
  if not evt then return end
  local payload = evt.payload or {}
  -- Slug events with verbs we already mirror locally are deduplicated by id;
  -- we only show them in the ticker if they're from a different room.
  local fromOurRoom = (Net.room and evt.roomId == Net.room.id)
  if fromOurRoom then return end
  local who = (evt.handle or "operator")
  if state.realPeers[evt.userId or ""] then
    who = state.realPeers[evt.userId].facility_name
  end
  if evt.verb == "block" then
    pushEvent(state, "block",
      string.format("⛏  %s found a block — +%s Z [global]", who,
        fmt.zeptons(tonumber(payload.reward) or 0)),
      { 1, 0.95, 0.55 })
  elseif evt.verb == "halving" then
    pushEvent(state, "halving",
      string.format("½  %s endured a halving event [global]", who),
      { 0.85, 0.65, 1 })
  elseif evt.verb == "tier_unlocked" then
    pushEvent(state, "tier",
      string.format("✦  %s unlocked %s [global]", who, payload.name or "a new tier"),
      { 1, 0.85, 0.45 })
  elseif evt.verb == "surge_started" then
    -- Authoritative: set the local surge timer from the broadcast itself.
    local dur = (tonumber(payload.duration_ms) or 120000) / 1000
    state._surgeUntil = love.timer.getTime() + dur
    state._surgeMult  = tonumber(payload.mult) or 0.5
    pushEvent(state, "surge",
      string.format("⚡  GLOBAL SURGE +%d%% — %ds", math.floor((payload.mult or 0.5) * 100),
                    math.floor((payload.duration_ms or 0) / 1000)),
      { 1, 0.55, 0.30 })
  elseif evt.verb == "join" then
    pushEvent(state, "global_join",
      string.format("◉  %s joined the mesh [global]", who),
      { 0.55, 0.95, 0.75 })
  end
end

local function maybeBroadcastBigEvents(state, playerStats)
  -- Block: broadcast the latest block once.
  local height = playerStats.block_height or 0
  if height > (state._broadcastedBlocks or 0) and (playerStats.z_per_sec or 0) > 0 then
    state._broadcastedBlocks = height
    Net.broadcast("block", {
      reward = math.max(50, (playerStats.z_per_sec or 0) * 30),
      height = height,
    })
  end
  -- Halving: broadcast on transition.
  local h = playerStats._lastHalvingNotice or 0
  if h > (state._broadcastedHalvings or 0) then
    state._broadcastedHalvings = h
    Net.broadcast("halving", { count = h })
  end
  -- New-tier unlock: broadcast first time a kind reaches count 1.
  for _, def in ipairs(minersDb.list) do
    if (playerStats.miners[def.key] or 0) >= 1 and not state._broadcastedNewTiers["miner:" .. def.key] then
      state._broadcastedNewTiers["miner:" .. def.key] = true
      Net.broadcast("tier_unlocked", { kind = "miner", key = def.key, name = def.name, tier = def.tier })
    end
  end
  for _, def in ipairs(energyDb.list) do
    if (playerStats.energy[def.key] or 0) >= 1 and not state._broadcastedNewTiers["energy:" .. def.key] then
      state._broadcastedNewTiers["energy:" .. def.key] = true
      Net.broadcast("tier_unlocked", { kind = "energy", key = def.key, name = def.name, tier = def.tier })
    end
  end
end

-- Surge clock: trust the surge_started broadcast we already receive; only
-- reconcile via slug_state to detect cancellation (surge_until == 0). The
-- previous reconciliation math cancelled itself; this is much simpler.
local function checkSurge(state)
  local sst = Net.slugState
  if not sst or not sst.state then return end
  local until_ms = tonumber(sst.state.surge_until or 0) or 0
  local effectiveNow = (Net.active and Net.active.at) or os.time() * 1000
  if until_ms <= 0 or effectiveNow >= until_ms then
    state._surgeUntil = 0
  end
  -- Otherwise the surge_started broadcast handler set _surgeUntil already.
end

function M.update(state, dt, playerStats)
  state._t = (state._t or 0) + dt
  if state._t - (state._lastTick or 0) < 0.25 then return end
  state._lastTick = state._t

  state.self_facility_name = playerStats.facility_name or state.self_facility_name

  -- Refresh identity FIRST so target-filtering of inbound boost / wave
  -- doesn't race against the first poll batch.
  Net.refreshIdentity()
  if Net.identity and Net.identity.userId then
    state.self_userId = Net.identity.userId
    state.self_handle = Net.identity.handle
  end

  Net.poll(function (evt)
    onNetEvent(state, evt)
  end, function (evt)
    onSlugEvent(state, evt)
  end)

  if Net.identity and Net.identity.userId then
    state.self_userId = Net.identity.userId
    state.self_handle = Net.identity.handle
  end

  state._slugStats = Net.active
  state._slugTopUsers = (Net.active and Net.active.topUsers) or {}
  checkSurge(state)

  -- Try to bootstrap a room
  attemptBootstrap(state)

  -- Mode flip with hysteresis: a single status blip during reconnect
  -- shouldn't blow the snapshot list back to all-sim.
  local connected = Net.connected() and Net.room and Net.room.id
  if connected then
    state._modeMisses = 0
    state.mode = "real"
  else
    state._modeMisses = (state._modeMisses or 0) + 1
    if state._modeMisses >= 2 then
      state.mode = "sim"
    end
  end

  -- Apply roster (mark online/offline among realPeers)
  applyRosterPresence(state)

  -- Detect newly-arrived peers (chime + presence broadcast hook)
  state.newly_joined = {}
  for uid, p in pairs(state.realPeers) do
    if p.online and not state._seenIds[uid] then
      state._seenIds[uid] = true
      table.insert(state.newly_joined, p)
    end
  end

  -- Persist last-known stats so offline peers stay visible
  for uid, p in pairs(state.realPeers) do
    state.peer_memory[uid] = {
      userId      = uid,
      facility_name = p.facility_name,
      handle      = p.handle,
      avatar      = p.avatar,
      z_per_sec   = p.z_per_sec,
      hashrate    = p.hashrate,
      z_lifetime  = p.z_lifetime,
      level       = p.level,
      lastSeen    = (p.lastSeen or state._t),
      lastOnlineFlag = p.online,
    }
  end

  -- Build snapshots
  local totalRate, totalHash = 0, 0
  state._snapshots = {}
  if state.mode == "real" then
    -- Real peers (excluding self) with hysteresis around the AFK gate so
    -- normal 8 s broadcast jitter doesn't flicker the badge.
    for _, p in pairs(state.realPeers) do
      local status
      if p.online then
        local gap = state._t - (p.lastUpdate or state._t)
        if gap > 90 then
          status = "offline"
        elseif gap > 40 then
          status = "afk"
        else
          status = "online"
        end
      else
        status = "offline"
      end
      local effRate = p.z_per_sec
      if status == "offline" then effRate = 0
      elseif status == "afk" then effRate = (p.z_per_sec or 0) * 0.4 end
      table.insert(state._snapshots, {
        id         = p.id,
        name       = p.facility_name,
        avatar     = p.avatar,
        z_per_sec  = effRate,
        hashrate   = p.hashrate or 0,
        z_lifetime = p.z_lifetime or 0,
        status     = status,
        level      = p.level or 0,
        sim        = false,
      })
      totalRate = totalRate + effRate
      totalHash = totalHash + (p.hashrate or 0)
    end
    -- Empty room is empty. We do NOT inject NPCs / demo peers. A solo
    -- operator should see only their own plot until real peers join.
  else
    -- Solo / pre-connect mode: no NPCs. The plot belongs to the player
    -- alone; the network panel shows an empty state with a hint to
    -- invite friends. This matches the user's expectation that a solo
    -- player sees nobody else.
  end
  state.totalRate     = totalRate
  state.totalHashRate = totalHash + (playerStats.hashrate or 0)

  -- Augment snapshots with offline-but-known peers (real mode only)
  if state.mode == "real" then
    local present = {}
    for _, s2 in ipairs(state._snapshots) do present[s2.id] = true end
    for uid, mem in pairs(state.peer_memory) do
      if not present[uid] then
        table.insert(state._snapshots, {
          id         = uid,
          name       = mem.facility_name or mem.handle or "operator",
          avatar     = mem.avatar,
          z_per_sec  = 0,
          hashrate   = 0,
          z_lifetime = mem.z_lifetime or 0,
          status     = "offline",
          level      = mem.level or 0,
          sim        = false,
          offline_known = true,
          lastSeen   = mem.lastSeen,
        })
      end
    end
  end

  -- Periodic per-room stats broadcast
  if state.mode == "real" then
    if (state._t - state._lastStatsBroadcast) >= state._statsInterval then
      state._lastStatsBroadcast = state._t
      Net.send("stats", {
        facility_name = playerStats.facility_name,
        z_per_sec     = playerStats.z_per_sec or 0,
        hashrate      = playerStats.hashrate or 0,
        z_lifetime    = playerStats.z_lifetime or 0,
        level         = levelFromZ(math.max(1, playerStats.z_lifetime or 1)),
        block_height  = playerStats.block_height or 0,
      })
    end
    -- Slug-wide presence refresh (rank by lifetime)
    if (state._t - state._lastSlugPresence) >= state._slugPresenceInterval then
      state._lastSlugPresence = state._t
      Net.slugPresence("z_lifetime", 12)
    end
    -- Real-time position broadcast at ~1 Hz so peers see where YOU are
    -- on the plot in roughly real time. Combined with a portal SSE
    -- delivery of ~750 ms when active this lands at 1.5–2 s effective
    -- update cadence — adequate for "watch them walk" presence.
    if (state._t - (state._lastPosBroadcast or -100)) >= 1.0 then
      state._lastPosBroadcast = state._t
      if playerStats.world and playerStats.world.char then
        local c = playerStats.world.char
        Net.send("pos", {
          wx = c.wx, wy = c.wy,
          vx = c.vx, vy = c.vy,
          facing = c.facing,
        })
      end
    end
    -- Auto-mirror big events to slug
    maybeBroadcastBigEvents(state, playerStats)
    -- Lazily fetch profiles for every roster member we don't have
    for uid, p in pairs(state.realPeers) do
      if not Net.profiles[uid] and (state._profileRequested[uid] or 0) < state._t - 30 then
        state._profileRequested[uid] = state._t
        Net.profile(uid)
      end
    end
    -- Merge slug top-users into peer_memory so offline ranked peers show up
    for _, u in ipairs(state._slugTopUsers) do
      local uid = tostring(u.userId or "")
      if uid ~= "" and uid ~= (state.self_userId or "") and not state.realPeers[uid] then
        local prof = u.profile or {}
        local seedNum = hashUserIdToInt(uid)
        state.peer_memory[uid] = state.peer_memory[uid] or {}
        local mem = state.peer_memory[uid]
        mem.userId        = uid
        mem.handle        = u.handle or mem.handle
        mem.facility_name = prof.facility_name or u.handle or mem.facility_name
        mem.avatar        = mem.avatar or pickAvatar(seedNum)
        mem.z_lifetime    = tonumber(prof.z_lifetime) or mem.z_lifetime or 0
        mem.z_per_sec     = tonumber(prof.z_per_sec) or 0
        mem.hashrate      = tonumber(prof.hashrate) or mem.hashrate or 0
        mem.level         = tonumber(prof.level) or mem.level or 0
        mem.lastSeen      = u.lastSeenAt or mem.lastSeen
        mem.lastOnlineFlag = false
        mem.from_slug     = true
      end
    end
    -- Pull in fetched profile blobs (overrides peer_memory placeholders)
    for uid, prof in pairs(Net.profiles) do
      if uid ~= (state.self_userId or "") and prof.profile then
        local mem = state.peer_memory[uid] or {}
        local p = prof.profile
        mem.userId        = uid
        mem.handle        = mem.handle or prof.handle
        mem.facility_name = p.facility_name or mem.facility_name or prof.handle or "operator"
        mem.avatar        = mem.avatar or pickAvatar(hashUserIdToInt(uid))
        if tonumber(p.z_lifetime) then mem.z_lifetime = tonumber(p.z_lifetime) end
        if tonumber(p.z_per_sec)  then mem.z_per_sec  = tonumber(p.z_per_sec)  end
        if tonumber(p.hashrate)   then mem.hashrate   = tonumber(p.hashrate)   end
        if tonumber(p.level)      then mem.level      = tonumber(p.level)      end
        mem.profile_synced_at = state._t
        state.peer_memory[uid] = mem
      end
    end
  end

  -- Process pending interactions: outbound boosts → schedule local thanks
  -- credit only if the partner is sim (real partner replies via the wire).
  for _, it in ipairs(state.interactions) do
    -- Boost / thanks is now purely SOCIAL — no BTC is transferred or
    -- minted between players. The sender pays a tip out of their own
    -- balance and the recipient sends back a thank-you ping with no
    -- currency attached.
    if it.kind == "outgoing_boost_sim" and not it.responded and state._t >= it.respond_at then
      it.responded = true
      pushEvent(state, "thanks",
        string.format("✦  %s says thanks for the boost", it.target_name or "operator"),
        { 1, 0.85, 0.45 })
    end
    if it.kind == "incoming_boost" and not it.responded and state._t >= it.respond_at then
      it.responded = true
      Net.send("thanks", {}, it.from_id)
    end
  end

  -- Occasional global flavor pulse
  if love.math.random() < 0.005 then
    pushEvent(state, "global",
      string.format("◐  network hash rate  %s", fmt.hashRate(state.totalHashRate or 0)),
      { 0.55, 0.85, 0.95 })
  end
end

-- ============================================================
-- Public accessors
-- ============================================================

function M.snapshots(state)
  return state._snapshots or {}
end

function M.players(state)
  if state.mode == "real" then
    local out = {}
    for _, p in pairs(state.realPeers) do table.insert(out, p) end
    return out
  end
  return state.sim_players or {}
end

function M.events(state, count)
  count = count or 8
  local out = {}
  local n = #state.events
  for i = math.max(1, n - count + 1), n do
    table.insert(out, state.events[i])
  end
  return out
end

function M.statusText(state)
  if state.mode == "real" and Net.connected() then
    if Net.room and Net.room.id then
      local active = (Net.active and Net.active.activeUsers) or 0
      if active > 0 then
        return string.format("ONLINE  ·  %d GLOBAL", active)
      end
      return "ONLINE  ·  ROOM SYNCED"
    end
    return "CONNECTING"
  end
  return "SOLO MODE  ·  SIM MESH"
end

function M.activePeerCount(state)
  if state.mode ~= "real" then return 0 end
  local n = 0
  for _, p in pairs(state.realPeers) do if p.online then n = n + 1 end end
  return n
end

function M.globalActiveUsers(state)
  if state.mode ~= "real" or not Net.active then return 0 end
  return tonumber(Net.active.activeUsers) or 0
end

function M.globalAllTimeUsers(state)
  if state.mode ~= "real" or not Net.active then return 0 end
  return tonumber(Net.active.allTimeUsers) or 0
end

function M.globalLast24h(state)
  if state.mode ~= "real" or not Net.active then return 0 end
  return tonumber(Net.active.last24hUsers) or 0
end

function M.globalTotalRooms(state)
  if state.mode ~= "real" or not Net.active then return 0 end
  return tonumber(Net.active.totalRooms) or 0
end

function M.topUsers(state)
  return state._slugTopUsers or {}
end

function M.surgeRemaining(state)
  local rem = (state._surgeUntil or 0) - love.timer.getTime()
  if rem <= 0 then return 0 end
  return rem
end

function M.surgeMultiplier(state)
  if M.surgeRemaining(state) > 0 then
    return state._surgeMult or 0.5
  end
  return 0
end

function M.popJoined(state)
  local out = state.newly_joined or {}
  state.newly_joined = {}
  return out
end

-- Authoritative slug-state mutator. Players cooperate to push the
-- "all_time_blocks" counter and trigger surge windows when it crosses
-- 100-block thresholds. Last writer wins; conflicts heal next tick.
function M.maybeAdvanceGlobalBlocks(stateNet, blockHeight, tierWeight)
  if stateNet.mode ~= "real" then return end
  local sst = Net.slugState
  if not sst then return end
  local known = tonumber((sst.state or {}).all_time_blocks or 0) or 0
  -- Endgame players' blocks are worth more on the global counter so the
  -- surge cadence keeps pace as the slug's collective tier rises.
  local weight = math.max(1, math.floor(tierWeight or 1))
  if blockHeight > known then
    local next_total = known + weight
    local patch = { all_time_blocks = next_total }
    -- Surge trigger when crossing any 100-block threshold (handles weighted skips)
    local crossedThreshold = math.floor(next_total / 100) > math.floor(known / 100)
    if next_total > 0 and crossedThreshold then
      local startedAt = (Net.active and Net.active.at) or os.time() * 1000
      patch.surge_until = startedAt + 120000
      patch.surge_started_at = startedAt
      patch.surge_mult = 0.5
      Net.broadcast("surge_started", {
        started_at  = startedAt,
        duration_ms = 120000,
        mult        = 0.5,
        global_blocks = next_total,
      })
    end
    Net.setSlugState(patch)
  end
end

-- ============================================================
-- Interactions
-- ============================================================

local function isSimId(id)
  return id and tostring(id):find("ghost-") == 1
end

function M.interact(state, target_id, kind, paid)
  if kind == "boost" then
    state.boostCount = (state.boostCount or 0) + 1
    if state.mode == "real" and not isSimId(target_id) then
      -- Targeted unicast — only the sender + recipient see it
      Net.send("boost", { paid = paid or 0 }, target_id)
    else
      local snap
      for _, sn in ipairs(state._snapshots or {}) do
        if sn.id == target_id then snap = sn; break end
      end
      table.insert(state.interactions, {
        kind = "outgoing_boost_sim",
        target_id = target_id,
        target_name = (snap and snap.name) or "operator",
        paid = paid or 0,
        respond_at = state._t + 30 + love.math.random() * 90,
        responded = false,
      })
    end
  elseif kind == "pool" then
    -- Send a request — the partner accepts or declines. pool_with is
    -- set only when their pool_accept arrives. (For sim ghosts: skip
    -- entirely; you can't pool with NPCs anymore.)
    if state.mode == "real" and not isSimId(target_id) then
      state.pool_pending_outgoing = {
        target_id = target_id,
        sent_at = state._t,
      }
      Net.send("pool_request", {}, target_id)
    end
  elseif kind == "accept_pool" then
    -- Accept an inbound request. Sets us partnered; tells the inviter.
    if state.mode == "real" and state.pool_pending_incoming
       and state.pool_pending_incoming.from_id == target_id then
      state.pool_with = target_id
      state.pool_started_at = state._t
      Net.send("pool_accept", {}, target_id)
      state.pool_pending_incoming = nil
    end
  elseif kind == "decline_pool" then
    if state.mode == "real" and state.pool_pending_incoming
       and state.pool_pending_incoming.from_id == target_id then
      Net.send("pool_decline", {}, target_id)
      state.pool_pending_incoming = nil
    end
  elseif kind == "leave_pool" then
    if state.mode == "real" and state.pool_with and not isSimId(state.pool_with) then
      Net.send("pool_leave", {}, state.pool_with)
    end
    state.pool_with = nil
    state.pool_pending_outgoing = nil
  end
end

-- ============================================================
-- Game-event broadcast helpers
-- ============================================================

function M.notify(state, kind, payload)
  if state.mode ~= "real" then return end
  Net.send(kind, payload or {})
end

-- ============================================================
-- Pool ticking
-- ============================================================

function M.tickPool(state, dt, playerZps)
  -- Pool is now PURELY SOCIAL — no BTC is moved between players. You
  -- can't harvest someone else's currency by syncing to them. The
  -- partnership remains visible (status badges, ticker events, the
  -- ⛓ POOLED w/ name HUD pill) but no currency flows in either
  -- direction. Returns zero outflow and zero payout always.
  return 0, 0
end

function M.collectPendingBonuses(state)
  -- Boost / thanks no longer transfers BTC between players. Returns
  -- zero so M.update never adds to state.z from peer interactions.
  return 0
end

return M
