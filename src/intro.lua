local M = {}

local DESIGN_W, DESIGN_H = 1920, 1080
local MAX_NAME = 28

function M.new(opts)
  local s = {
    name = "",
    cursor = 0,
    onSubmit = opts.onSubmit,
    fonts = opts.fonts,
    suggestions = {
      "STARGATE MINING CO.",
      "AUREUS DEEP",
      "PHOTON FORGE",
      "BLACKBOX REFINERY",
      "GLEAM CONSORTIUM",
      "WATTSPRING WORKS",
      "PALE GREEN HORIZON",
      "FUNDAMENTAL CORE",
      "ZX-9 INSTALLATION",
      "RIVERHEART CRYO",
      "VOID HARVEST CO.",
    },
    pickedSuggestion = nil,
  }
  return s
end

function M.update(s, dt, t)
  s.cursor = s.cursor + dt
end

local function field(x, y, w, h)
  return { x = x, y = y, w = w, h = h }
end

local function inRect(mx, my, r)
  return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

function M.draw(s, t)
  local cx = DESIGN_W / 2
  local cy = DESIGN_H / 2

  -- Subtle radial gradient backdrop drawn as concentric circles
  for i = 30, 0, -1 do
    local k = i / 30
    local a = (1 - k) * 0.05
    love.graphics.setColor(0.15 + k * 0.05, 0.6 + k * 0.3, 0.4 + k * 0.3, a)
    love.graphics.circle("fill", cx, cy + 60, 80 + i * 32)
  end

  -- Marketing/ATEK header
  love.graphics.setFont(s.fonts.giant)
  local title = "A-TEK INDUSTRIES"
  local tw = s.fonts.giant:getWidth(title)
  love.graphics.setColor(0.2, 1.0, 0.55, 1)
  love.graphics.print(title, cx - tw / 2, 220)
  love.graphics.setColor(0.5, 1.0, 0.7, 0.5)
  love.graphics.print(title, cx - tw / 2 + 3, 223)

  love.graphics.setFont(s.fonts.medium)
  love.graphics.setColor(0.55, 0.85, 0.7, 0.85)
  local sub = "/// FINANCIAL ENERGY DIVISION  ::  ZEPTON OPERATIONS"
  local sw = s.fonts.medium:getWidth(sub)
  love.graphics.print(sub, cx - sw / 2, 320)

  -- Body lines
  love.graphics.setFont(s.fonts.large)
  love.graphics.setColor(0.85, 1, 0.9, 1)
  local body1 = "FACILITY OPERATOR — INTAKE FORM 04-Z"
  local b1w = s.fonts.large:getWidth(body1)
  love.graphics.print(body1, cx - b1w / 2, 410)

  love.graphics.setFont(s.fonts.medium)
  love.graphics.setColor(0.7, 0.85, 0.75, 0.9)
  local body2 = "Christen your installation. The grid awaits a name."
  local b2w = s.fonts.medium:getWidth(body2)
  love.graphics.print(body2, cx - b2w / 2, 470)

  -- Input field
  local fx, fy, fw, fh = cx - 480, 540, 960, 110
  -- Frame
  love.graphics.setColor(0.04, 0.08, 0.06, 1)
  love.graphics.rectangle("fill", fx, fy, fw, fh, 8, 8)
  love.graphics.setColor(0.25, 1, 0.55, 0.85)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", fx, fy, fw, fh, 8, 8)
  -- Inner glow corners
  love.graphics.setColor(0.3, 1, 0.6, 0.3)
  love.graphics.setLineWidth(1)
  for i = 1, 6 do
    love.graphics.rectangle("line", fx - i, fy - i, fw + i * 2, fh + i * 2, 8 + i, 8 + i)
  end
  love.graphics.setLineWidth(1)

  -- Text content
  love.graphics.setFont(s.fonts.giant)
  local display = s.name
  if display == "" then display = "" end
  local textW = s.fonts.giant:getWidth(display)
  love.graphics.setColor(0.7, 1, 0.85, 1)
  love.graphics.print(display, fx + 30, fy + 18)

  -- Caret
  local blink = (math.floor(s.cursor * 2.4) % 2 == 0) and 1 or 0
  if blink == 1 then
    love.graphics.setColor(0.4, 1, 0.7, 0.95)
    love.graphics.rectangle("fill", fx + 30 + textW + 4, fy + 26, 4, 64)
  end

  -- Hint placeholder when empty
  if s.name == "" then
    love.graphics.setFont(s.fonts.medium)
    love.graphics.setColor(0.4, 0.6, 0.5, 0.6)
    love.graphics.print("// type a facility name and press ENTER", fx + 30, fy + 42)
  end

  -- Char counter
  love.graphics.setFont(s.fonts.small)
  love.graphics.setColor(0.4, 0.7, 0.55, 0.7)
  love.graphics.printf(string.format("%d / %d", #s.name, MAX_NAME), fx, fy + fh - 26, fw - 12, "right")

  -- Suggestions row
  love.graphics.setFont(s.fonts.medium)
  love.graphics.setColor(0.55, 0.85, 0.7, 0.7)
  local sugLabel = "SUGGESTIONS  ››"
  love.graphics.print(sugLabel, cx - 480, 690)

  -- Suggestion chips
  love.graphics.setFont(s.fonts.small)
  s._chipRects = {}
  local cx0 = cx - 480
  local cy0 = 730
  local x = cx0
  local y = cy0
  local maxW = 960
  for i, sug in ipairs(s.suggestions) do
    local pad = 16
    local w = s.fonts.small:getWidth(sug) + pad * 2
    local h = 38
    if x + w > cx0 + maxW then
      x = cx0
      y = y + h + 12
    end
    -- Hover hilite
    local mx, my = love.mouse.getPosition()
    local sw, sh = love.graphics.getDimensions()
    local sc = math.min(sw / DESIGN_W, sh / DESIGN_H)
    local dx = (sw - DESIGN_W * sc) * 0.5
    local dy = (sh - DESIGN_H * sc) * 0.5
    local lmx = (mx - dx) / sc
    local lmy = (my - dy) / sc
    local r = field(x, y, w, h)
    local hover = inRect(lmx, lmy, r)
    if hover then
      love.graphics.setColor(0.15, 0.45, 0.30, 0.85)
    else
      love.graphics.setColor(0.05, 0.18, 0.10, 0.85)
    end
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.35, 0.85, 0.55, hover and 1 or 0.5)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setColor(0.85, 1, 0.9, hover and 1 or 0.85)
    love.graphics.print(sug, x + pad, y + 9)
    s._chipRects[i] = r
    x = x + w + 8
  end

  -- Submit hint
  local canSubmit = #s.name > 0
  love.graphics.setFont(s.fonts.medium)
  if canSubmit then
    local pulse = (math.sin(t * 3) * 0.5 + 0.5) * 0.4 + 0.6
    love.graphics.setColor(0.3, 1, 0.55, pulse)
    local msg = "PRESS  [ENTER]  TO CONTINUE"
    local mw = s.fonts.medium:getWidth(msg)
    love.graphics.print(msg, cx - mw / 2, DESIGN_H - 110)
  else
    love.graphics.setColor(0.4, 0.6, 0.5, 0.6)
    local msg = "Awaiting designation..."
    local mw = s.fonts.medium:getWidth(msg)
    love.graphics.print(msg, cx - mw / 2, DESIGN_H - 110)
  end

  -- Footer brand
  love.graphics.setFont(s.fonts.small)
  love.graphics.setColor(0.3, 0.5, 0.4, 0.5)
  love.graphics.print("A-TEK / ZEPTON OPS / FORM 04-Z / REV. 12", 30, DESIGN_H - 40)
  love.graphics.printf("BUILD 1.0 — STAGE: PROVISIONAL", 0, DESIGN_H - 40, DESIGN_W - 30, "right")
end

function M.textinput(s, text)
  if #s.name >= MAX_NAME then return end
  -- Filter to printable ASCII-ish for display reliability with default font
  for i = 1, #text do
    local b = text:byte(i)
    if b >= 32 and b <= 126 then
      s.name = s.name .. text:sub(i, i)
    end
  end
end

function M.keypressed(s, key)
  if key == "backspace" then
    if #s.name > 0 then
      s.name = s.name:sub(1, -2)
    end
  elseif key == "return" or key == "kpenter" then
    if #s.name > 0 and s.onSubmit then
      s.onSubmit(s.name)
    end
  elseif key == "escape" then
    if #s.name > 0 then s.name = "" end
  end
end

function M.mousepressed(s, lx, ly, button)
  if button ~= 1 then return end
  if not s._chipRects then return end
  for i, r in ipairs(s._chipRects) do
    if inRect(lx, ly, r) then
      s.name = s.suggestions[i]
      s.pickedSuggestion = i
      return
    end
  end
end

return M
