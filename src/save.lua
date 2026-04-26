local json = require "lib.json"

local M = {}

local SAVE_PATH = "save.json"
local VERSION = 1

function M.load()
  if not love.filesystem.getInfo(SAVE_PATH) then return nil end
  local raw = love.filesystem.read(SAVE_PATH)
  if not raw or #raw == 0 then return nil end
  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then return nil end
  if data.version ~= VERSION then return nil end
  return data
end

function M.save(state)
  local snapshot = {
    version       = VERSION,
    facility_name = state.facility_name,
    facility_seed = state.facility_seed,
    z             = state.z,
    z_lifetime    = state.z_lifetime,
    z_clicked     = state.z_clicked,
    click_count   = state.click_count,
    play_time     = state.play_time,
    miners        = state.miners,
    energy        = state.energy,
    upgrades      = state.upgrades,
    block_height      = state.block_height,
    blocks_found      = state.blocks_found,
    last_block_at     = state.last_block_at,
    cosmetics         = state.cosmetics,
    zeptons           = state.zeptons,
    zeptons_lifetime  = state.zeptons_lifetime,
    monoliths         = state.monoliths,
    miracles_invoked  = state.miracles_invoked,
    _tutSessionCount  = state._tutSessionCount,
    -- active_miracles intentionally NOT saved — they're temporary
    -- and should expire across sessions.
    network       = state.network and {
      pool_with               = state.network.pool_with,
      boostCount              = state.network.boostCount,
      peer_memory             = state.network.peer_memory,
      _broadcastedNewTiers    = state.network._broadcastedNewTiers,
      _broadcastedBlocks      = state.network._broadcastedBlocks,
      _broadcastedHalvings    = state.network._broadcastedHalvings,
    } or nil,
    saved_at      = os.time(),
  }
  local ok, encoded = pcall(json.encode, snapshot)
  if not ok then return false, encoded end
  love.filesystem.write(SAVE_PATH, encoded)
  return true
end

function M.wipe()
  if love.filesystem.getInfo(SAVE_PATH) then
    love.filesystem.remove(SAVE_PATH)
  end
end

return M
