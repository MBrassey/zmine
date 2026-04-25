local M = {}

local SUFFIXES = {
  "", "K", "M", "B", "T",
  "Qa", "Qi", "Sx", "Sp", "Oc", "No",
  "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NDc",
  "Vg", "UVg", "DVg", "TVg",
}

local function trimZero(s)
  s = s:gsub("0+$", "")
  s = s:gsub("%.$", "")
  return s
end

function M.zeptons(n)
  if n ~= n or n == math.huge or n == -math.huge then return "∞" end
  local sign = ""
  if n < 0 then sign = "-"; n = -n end
  if n < 1 then
    if n == 0 then return "0" end
    return sign .. string.format("%.2f", n)
  end
  if n < 1000 then
    return sign .. string.format("%d", math.floor(n + 0.5))
  end
  local exp = math.floor(math.log(n) / math.log(1000))
  if exp < 1 then exp = 1 end
  if exp > #SUFFIXES - 1 then exp = #SUFFIXES - 1 end
  local mant = n / (1000 ^ exp)
  local s
  if mant < 10 then
    s = string.format("%.2f", mant)
  elseif mant < 100 then
    s = string.format("%.1f", mant)
  else
    s = string.format("%d", math.floor(mant))
  end
  return sign .. trimZero(s) .. SUFFIXES[exp + 1]
end

function M.rate(n)
  return M.zeptons(n) .. "/s"
end

function M.energy(n)
  if n ~= n or n == math.huge then return "∞" end
  if n < 1000 then return string.format("%d", math.floor(n + 0.5)) end
  return M.zeptons(n)
end

function M.percent(p)
  return string.format("%d%%", math.floor(p * 100 + 0.5))
end

function M.time(seconds)
  if seconds < 60 then
    return string.format("%ds", math.floor(seconds))
  elseif seconds < 3600 then
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds - m * 60)
    return string.format("%d:%02d", m, s)
  else
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds - h * 3600) / 60)
    local s = math.floor(seconds - h * 3600 - m * 60)
    return string.format("%d:%02d:%02d", h, m, s)
  end
end

local HRATE_SUFFIX = { "H/s", "kH/s", "MH/s", "GH/s", "TH/s", "PH/s", "EH/s", "ZH/s", "YH/s" }

function M.hashRate(hPerSec)
  if hPerSec ~= hPerSec or hPerSec <= 0 then return "0 H/s" end
  if hPerSec >= 1e30 then return "≫ YH/s" end
  local exp = math.floor(math.log(hPerSec) / math.log(1000))
  if exp < 0 then exp = 0 end
  if exp > #HRATE_SUFFIX - 1 then exp = #HRATE_SUFFIX - 1 end
  local mant = hPerSec / (1000 ^ exp)
  local s
  if mant < 10 then s = string.format("%.2f", mant)
  elseif mant < 100 then s = string.format("%.1f", mant)
  else s = string.format("%d", math.floor(mant)) end
  return s .. " " .. HRATE_SUFFIX[exp + 1]
end

function M.shortTime(seconds)
  if seconds < 60 then
    return string.format("%ds", math.floor(seconds))
  elseif seconds < 3600 then
    return string.format("%dm", math.floor(seconds / 60))
  elseif seconds < 86400 then
    return string.format("%.1fh", seconds / 3600)
  else
    return string.format("%.1fd", seconds / 86400)
  end
end

return M
