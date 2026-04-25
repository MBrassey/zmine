-- Thin LOVEWEB_NET wrapper. Mirrors the integration guide's reference
-- net.lua: emits magic-print verbs and polls __loveweb__/net/*.json
-- snapshots written by the portal runtime.
--
-- This module is intentionally I/O-only: it exposes raw room/roster/state
-- and a callback-based event poll. Higher-level translation into the
-- in-game peer / event ticker lives in src/network.lua.

local json = require "lib.json"

local M = {
  room      = nil,        -- { id, code, name, capacity, ownerId, ... }
  state     = {},         -- last-seen room state (server-merged)
  members   = {},         -- last-seen roster (NetRosterEntry[])
  status    = "idle",     -- "idle" | "connecting" | "connected" | "disconnected" | "closed"
  watermark = "0",        -- highest event id consumed
  identity  = nil,        -- { signedIn, handle, userId, avatar }
  lastResult = nil,       -- last verb result envelope
  _seenStatusAt = nil,    -- timestamp we first observed any net status
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

function M.create(name, opts)
  local n = name or "room"
  -- The runtime only takes the name in the basic form; visibility/capacity
  -- ride along inside an optional JSON tail (the runtime parses tail tokens
  -- conservatively; safest is the simple form).
  print("[[LOVEWEB_NET]]create " .. n)
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

function M.send(verb, payload)
  if payload then
    local ok, encoded = pcall(json.encode, payload)
    if not ok then return end
    print(string.format("[[LOVEWEB_NET]]send %s %s", verb, encoded))
  else
    print("[[LOVEWEB_NET]]send " .. verb)
  end
end

function M.setState(patch, opts)
  local ok, encoded = pcall(json.encode, patch)
  if not ok then return end
  -- The portal's state verb takes the JSON inline; expectedVersion / replace
  -- can't be expressed in the simple magic-print, but the portal accepts the
  -- bare patch form for shallow merge — sufficient for our needs.
  print("[[LOVEWEB_NET]]state " .. encoded)
end

-- ============================================================
-- Snapshot poll
-- ============================================================

function M.poll(onEvent)
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
    -- Self-userId capture: any envelope that carries a freshly-emitted
    -- event of ours echoes back our userId.
    if lr.event and lr.event.userId then
      M.identity = M.identity or {}
      M.identity.userId = lr.event.userId
      if lr.event.handle then M.identity.handle = lr.event.handle end
    end
    -- Room creation also reveals our userId via room.ownerId.
    if lr.room and lr.room.ownerId then
      M.identity = M.identity or {}
      M.identity.userId = M.identity.userId or lr.room.ownerId
    end
  end

  if not love.filesystem.getInfo("__loveweb__/net/inbox.jsonl") then return end

  for line in love.filesystem.lines("__loveweb__/net/inbox.jsonl") do
    if line and #line > 0 then
      local ok, evt = pcall(json.decode, line)
      if ok and type(evt) == "table" and evt.id then
        if tonumber(evt.id) and tonumber(M.watermark) and tonumber(evt.id) > tonumber(M.watermark) then
          M.watermark = tostring(evt.id)
          if evt.verb == "state" and evt.payload and evt.payload.state then
            M.state = evt.payload.state
          end
          if onEvent then onEvent(evt) end
        end
      end
    end
  end
end

function M.connected()
  return M.status == "connected"
end

function M.refreshIdentity()
  -- Identity is filled from achievements/state messages by the portal;
  -- consumers can read M.identity if it appears.
end

return M
