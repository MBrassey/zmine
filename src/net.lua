-- Thin LOVEWEB_NET wrapper. Mirrors the integration guide: emits
-- magic-print verbs and reads __loveweb__/{identity,net,slug,profiles}/*
-- snapshots written by the portal runtime.
--
-- This module is intentionally I/O-only: higher-level translation
-- (peers, ticker text, surge handling) lives in src/network.lua.

local json = require "lib.json"

local M = {
  identity   = nil,        -- { signedIn, userId, handle, avatar }
  -- Per-room state
  room       = nil,        -- { id, code, name, capacity, ownerId, ... }
  state      = {},
  members    = {},
  status     = "idle",
  watermark  = "0",
  lastResult = nil,
  -- Slug-wide layer
  active     = nil,        -- contents of __loveweb__/slug/active.json
  slugState  = nil,        -- contents of __loveweb__/slug/state.json
  slugWatermark = "0",
  profiles   = {},         -- userId -> last fetched public_profile envelope
  _seenStatusAt = nil,
}

local function readJson(path)
  if not love.filesystem.getInfo(path) then return nil end
  local raw = love.filesystem.read(path)
  if not raw or #raw == 0 then return nil end
  local ok, data = pcall(json.decode, raw)
  if not ok then return nil end
  return data
end

-- ============================================================
-- Verb emission
-- ============================================================

function M.create(name)
  print("[[LOVEWEB_NET]]create " .. (name or "room"))
end

function M.join(codeOrId)
  print("[[LOVEWEB_NET]]join " .. (codeOrId or ""))
end

function M.leave()
  print("[[LOVEWEB_NET]]leave")
end

function M.list()
  print("[[LOVEWEB_NET]]list")
end

-- send(verb, payload?, target?) — when target is set we use the
-- --target=<userId> unicast form documented in the integration guide.
function M.send(verb, payload, target)
  local body
  if payload then
    local ok, encoded = pcall(json.encode, payload)
    if not ok then return end
    body = encoded
  end
  if target then
    if body then
      print(string.format("[[LOVEWEB_NET]]send %s --target=%s %s", verb, target, body))
    else
      print(string.format("[[LOVEWEB_NET]]send %s --target=%s", verb, target))
    end
  else
    if body then
      print(string.format("[[LOVEWEB_NET]]send %s %s", verb, body))
    else
      print("[[LOVEWEB_NET]]send " .. verb)
    end
  end
end

function M.setState(patch)
  local ok, encoded = pcall(json.encode, patch)
  if not ok then return end
  print("[[LOVEWEB_NET]]state " .. encoded)
end

-- Slug-wide broadcast. Mirrors to __loveweb__/slug/global_inbox.jsonl.
-- Rate-limited at ~6/s burst, 12/s sustained — caller should throttle.
function M.broadcast(verb, payload)
  if payload then
    local ok, encoded = pcall(json.encode, payload)
    if not ok then return end
    print(string.format("[[LOVEWEB_NET]]broadcast %s %s", verb, encoded))
  else
    print("[[LOVEWEB_NET]]broadcast " .. verb)
  end
end

-- Persistent slug-scoped JSONB blob. Shallow merge.
-- Note: writes to the verb; the parsed file content lives at M.slugState.
function M.setSlugState(patch)
  local ok, encoded = pcall(json.encode, patch)
  if not ok then return end
  print("[[LOVEWEB_NET]]slug_state " .. encoded)
end

-- Refresh slug presence with optional ranking. rankBy is a top-level
-- numeric field of public_profile.json (e.g., "z_lifetime"). Result
-- lands at __loveweb__/slug/active.json.
function M.slugPresence(rankBy, limit)
  local parts = { "[[LOVEWEB_NET]]slug_presence" }
  if rankBy and rankBy ~= "" then
    parts[#parts + 1] = rankBy
    parts[#parts + 1] = tostring(limit or 12)
  end
  print(table.concat(parts, " "))
end

-- Fetch a peer's public_profile.json. Result lands at
-- __loveweb__/profiles/<userId>.json.
function M.profile(userId)
  if not userId or userId == "" then return end
  print("[[LOVEWEB_NET]]profile " .. tostring(userId))
end

-- ============================================================
-- Snapshot poll
-- ============================================================

function M.poll(onEvent, onSlugEvent)
  -- Identity (written before love.load, then on auth changes)
  local ident = readJson("__loveweb__/identity.json")
  if ident then M.identity = ident end

  local roster = readJson("__loveweb__/net/roster.json")
  if roster then M.members = roster.members or {} end

  local room = readJson("__loveweb__/net/room.json")
  if room then
    M.room = M.room or {}
    M.room.id           = room.roomId
    M.room.mode         = room.mode
    M.room.stateVersion = room.stateVersion
    if room.state then M.state = room.state end
  end

  local status = readJson("__loveweb__/net/status.json")
  if status and status.status then
    M.status = status.status
    if not M._seenStatusAt then
      M._seenStatusAt = love.timer.getTime()
    end
  end

  local lr = readJson("__loveweb__/net/last_result.json")
  if lr then
    M.lastResult = lr
    -- Self-userId fallback if identity.json wasn't written yet
    if (not M.identity or not M.identity.userId) and lr.event and lr.event.userId then
      M.identity = M.identity or {}
      M.identity.userId = lr.event.userId
      if lr.event.handle then M.identity.handle = lr.event.handle end
    end
    if lr.room and lr.room.ownerId and (not M.identity or not M.identity.userId) then
      M.identity = M.identity or {}
      M.identity.userId = lr.room.ownerId
    end
  end

  -- Slug-wide active snapshot (refreshed every ~8 s by the portal)
  local active = readJson("__loveweb__/slug/active.json")
  if active then M.active = active end

  -- Slug-wide persistent state
  local sst = readJson("__loveweb__/slug/state.json")
  if sst then M.slugState = sst end

  -- Room inbox events
  if love.filesystem.getInfo("__loveweb__/net/inbox.jsonl") then
    for line in love.filesystem.lines("__loveweb__/net/inbox.jsonl") do
      if line and #line > 0 then
        local ok, evt = pcall(json.decode, line)
        if ok and type(evt) == "table" and evt.id then
          if tonumber(evt.id) and tonumber(M.watermark) and tonumber(evt.id) > tonumber(M.watermark) then
            M.watermark = tostring(evt.id)
            if onEvent then onEvent(evt) end
          end
        end
      end
    end
  end

  -- Slug-wide inbox events (mirrored room broadcasts + explicit broadcasts)
  if love.filesystem.getInfo("__loveweb__/slug/global_inbox.jsonl") then
    for line in love.filesystem.lines("__loveweb__/slug/global_inbox.jsonl") do
      if line and #line > 0 then
        local ok, evt = pcall(json.decode, line)
        if ok and type(evt) == "table" and evt.id then
          if tonumber(evt.id) and tonumber(M.slugWatermark) and tonumber(evt.id) > tonumber(M.slugWatermark) then
            M.slugWatermark = tostring(evt.id)
            if onSlugEvent then onSlugEvent(evt) end
          end
        end
      end
    end
  end
end

-- Read a previously-fetched peer profile from disk.
function M.readProfile(userId)
  if not userId or userId == "" then return nil end
  if M.profiles[userId] then return M.profiles[userId] end
  local p = readJson("__loveweb__/profiles/" .. userId .. ".json")
  if p then M.profiles[userId] = p end
  return p
end

function M.connected()
  return M.status == "connected"
end

function M.refreshIdentity()
  local ident = readJson("__loveweb__/identity.json")
  if ident then M.identity = ident end
  return M.identity
end

return M
