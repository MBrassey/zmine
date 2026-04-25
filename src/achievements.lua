local json = require "lib.json"

local M = {}

function M.loadCatalog()
  if not love.filesystem.getInfo("achievements.json") then return {} end
  local raw = love.filesystem.read("achievements.json")
  if not raw then return {} end
  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then return {} end
  return data.achievements or {}
end

function M.loadUnlocks()
  local p = "__loveweb__/achievements.json"
  if not love.filesystem.getInfo(p) then return {} end
  local raw = love.filesystem.read(p)
  if not raw then return {} end
  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= "table" then return {} end
  local byKey = {}
  for _, u in ipairs(data.unlocks or {}) do byKey[u.key] = u end
  return byKey
end

function M.unlock(key, meta)
  if meta then
    local ok, encoded = pcall(json.encode, meta)
    if ok then
      print(string.format("[[LOVEWEB_ACH]]unlock %s %s", key, encoded))
      return
    end
  end
  print("[[LOVEWEB_ACH]]unlock " .. key)
end

return M
