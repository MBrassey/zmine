-- Isometric projection helpers (2:1 dimetric).
-- World coordinates (wx, wy) are in tile units; world z is in vertical units
-- where 1 unit ≈ TILE_H/2 in screen-y. Positive Z goes "up" on screen.

local M = {}

M.TILE_W = 96
M.TILE_H = 48

function M.toScreen(wx, wy, wz)
  wz = wz or 0
  local sx = (wx - wy) * (M.TILE_W * 0.5)
  local sy = (wx + wy) * (M.TILE_H * 0.5) - wz * (M.TILE_H * 0.5)
  return sx, sy
end

function M.fromScreen(sx, sy)
  -- Inverse of toScreen at z=0
  local hw = M.TILE_W * 0.5
  local hh = M.TILE_H * 0.5
  local wx = (sx / hw + sy / hh) * 0.5
  local wy = (sy / hh - sx / hw) * 0.5
  return wx, wy
end

function M.depth(wx, wy, wz)
  wz = wz or 0
  return (wx + wy) * 100 - wz * 50
end

-- Draw a diamond-shaped tile at world (wx, wy)
function M.tilePolygon(wx, wy)
  local sx, sy = M.toScreen(wx, wy, 0)
  local hw = M.TILE_W * 0.5
  local hh = M.TILE_H * 0.5
  return {
    sx,      sy,
    sx + hw, sy + hh,
    sx,      sy + M.TILE_H,
    sx - hw, sy + hh,
  }
end

function M.drawTile(wx, wy, fillR, fillG, fillB, fillA, lineColor)
  local pts = M.tilePolygon(wx, wy)
  if fillA and fillA > 0 then
    love.graphics.setColor(fillR, fillG, fillB, fillA)
    love.graphics.polygon("fill", pts)
  end
  if lineColor then
    love.graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 0.6)
    love.graphics.polygon("line", pts)
  end
end

-- Same as drawTile but at an arbitrary world-z (lifts the diamond up).
function M.drawTileAt(wx, wy, wz, fillR, fillG, fillB, fillA, lineColor)
  local sx, sy = M.toScreen(wx, wy, wz or 0)
  local hw = M.TILE_W * 0.5
  local hh = M.TILE_H * 0.5
  local pts = {
    sx,      sy,
    sx + hw, sy + hh,
    sx,      sy + M.TILE_H,
    sx - hw, sy + hh,
  }
  if fillA and fillA > 0 then
    love.graphics.setColor(fillR, fillG, fillB, fillA)
    love.graphics.polygon("fill", pts)
  end
  if lineColor then
    love.graphics.setColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] or 0.6)
    love.graphics.polygon("line", pts)
  end
end

-- Draw an axis-aligned iso-prism (box) with top/right/left faces.
-- Pivot is at the bottom-center of the prism; w, d are footprint in tiles, h in z-units.
function M.drawBox(wx, wy, w, d, h, faces)
  local hw = M.TILE_W * 0.5
  local hh = M.TILE_H * 0.5
  -- 8 corners in screen space
  local function px(x, y, z)
    return (x - y) * hw, (x + y) * hh - z * hh
  end
  local x0, y0, x1, y1 = wx, wy, wx + w, wy + d
  local b1x, b1y = px(x0, y0, 0)  -- back
  local b2x, b2y = px(x1, y0, 0)  -- right-back
  local b3x, b3y = px(x1, y1, 0)  -- front
  local b4x, b4y = px(x0, y1, 0)  -- left-back
  local t1x, t1y = px(x0, y0, h)
  local t2x, t2y = px(x1, y0, h)
  local t3x, t3y = px(x1, y1, h)
  local t4x, t4y = px(x0, y1, h)

  -- Right face (x = x1)
  if faces.right then
    local c = faces.right
    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
    love.graphics.polygon("fill", b2x, b2y, b3x, b3y, t3x, t3y, t2x, t2y)
  end
  -- Left face (y = y1)
  if faces.left then
    local c = faces.left
    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
    love.graphics.polygon("fill", b4x, b4y, b3x, b3y, t3x, t3y, t4x, t4y)
  end
  -- Top face (z = h)
  if faces.top then
    local c = faces.top
    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
    love.graphics.polygon("fill", t1x, t1y, t2x, t2y, t3x, t3y, t4x, t4y)
  end
  if faces.outline then
    local c = faces.outline
    love.graphics.setColor(c[1], c[2], c[3], c[4] or 0.4)
    love.graphics.setLineWidth(1)
    -- Top edges
    love.graphics.line(t1x, t1y, t2x, t2y)
    love.graphics.line(t2x, t2y, t3x, t3y)
    love.graphics.line(t3x, t3y, t4x, t4y)
    love.graphics.line(t4x, t4y, t1x, t1y)
    -- Vertical edges (only the visible front ones)
    love.graphics.line(b2x, b2y, t2x, t2y)
    love.graphics.line(b3x, b3y, t3x, t3y)
    love.graphics.line(b4x, b4y, t4x, t4y)
  end
end

return M
