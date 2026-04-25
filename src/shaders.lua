local M = {}

-- Radial glow with chromatic feathering. Designed to be drawn on a circle mesh.
-- Inputs: u_color (vec3), u_time
local CORE_GLOW = [[
  extern vec3 u_color;
  extern float u_time;
  extern float u_intensity;
  extern float u_pulse;

  vec4 effect(vec4 _c, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv * 2.0 - 1.0;
    float r = length(p);
    if (r > 1.0) discard;

    float ang = atan(p.y, p.x);
    float swirl = sin(ang * 5.0 + u_time * 1.4) * 0.5 + 0.5;
    float wave  = sin(r * 22.0 - u_time * 4.0) * 0.5 + 0.5;
    float core  = 1.0 - smoothstep(0.0, 0.30 + 0.05 * u_pulse, r);
    float corona = 1.0 - smoothstep(0.30, 1.0 + 0.06 * sin(u_time * 1.7), r);
    corona = pow(corona, 1.7);

    vec3 hot = vec3(1.0) - (vec3(1.0) - u_color) * 0.6;
    vec3 col = mix(u_color, hot, core);
    col += u_color * corona * (0.45 + 0.4 * swirl);
    col += u_color * wave * 0.10 * corona;

    float a = max(core, corona) * (0.85 + 0.15 * sin(u_time * 5.2));
    a *= u_intensity;

    return vec4(col, a);
  }
]]

-- Grid overlay drawn full-screen (post style). Cell-based with subtle drift.
local BG_GRID = [[
  extern vec2 u_size;
  extern float u_time;
  extern vec3 u_tint;

  float gridLine(float v, float thickness) {
    float d = abs(fract(v) - 0.5);
    return smoothstep(thickness, thickness - 0.01, d);
  }

  vec4 effect(vec4 _c, Image tex, vec2 uv, vec2 sc) {
    vec2 p = sc / u_size;
    vec2 q = (sc + vec2(u_time * 6.0, u_time * 3.0)) / 80.0;

    float gx = gridLine(q.x, 0.49);
    float gy = gridLine(q.y, 0.49);
    float g  = max(gx, gy);

    vec2 q2 = (sc + vec2(u_time * 18.0, -u_time * 11.0)) / 320.0;
    float gx2 = gridLine(q2.x, 0.495);
    float gy2 = gridLine(q2.y, 0.495);
    float g2  = max(gx2, gy2);

    // Vignette
    vec2 c = p * 2.0 - 1.0;
    float vig = 1.0 - dot(c, c) * 0.55;
    vig = clamp(vig, 0.2, 1.0);

    vec3 col = u_tint * 0.04;
    col += u_tint * g * 0.06;
    col += u_tint * g2 * 0.18;
    col *= vig;

    // Soft moving wash band
    float band = sin((p.y + u_time * 0.07) * 3.14159 * 2.0) * 0.5 + 0.5;
    col += u_tint * band * 0.025;

    return vec4(col, 1.0);
  }
]]

-- CRT scanlines + slight chromatic offset, used as overlay on canvas.
local CRT = [[
  extern vec2 u_size;
  extern float u_time;
  extern float u_strength;

  vec4 effect(vec4 c, Image tex, vec2 uv, vec2 sc) {
    vec2 px = vec2(1.0 / u_size.x, 1.0 / u_size.y);
    float r = Texel(tex, uv + vec2( px.x * 0.6, 0.0)).r;
    float g = Texel(tex, uv).g;
    float b = Texel(tex, uv - vec2( px.x * 0.6, 0.0)).b;
    vec4 col = vec4(r, g, b, 1.0);

    float scan = 0.92 + 0.08 * sin(uv.y * u_size.y * 3.14159);
    col.rgb *= mix(1.0, scan, u_strength);

    float n = fract(sin(dot(sc.xy, vec2(12.9898, 78.233)) + u_time) * 43758.5453);
    col.rgb += (n - 0.5) * 0.015 * u_strength;
    return col;
  }
]]

-- Soft glow ring for FX rings around the core.
local GLOW_RING = [[
  extern vec3 u_color;
  extern float u_progress;

  vec4 effect(vec4 _c, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv * 2.0 - 1.0;
    float r = length(p);
    float band = exp(-pow((r - u_progress) * 8.0, 2.0));
    float a = band * (1.0 - u_progress);
    return vec4(u_color * (0.8 + band * 0.6), a);
  }
]]

-- Energy bar shader: gradient with flowing band.
local ENERGY_BAR = [[
  extern float u_fill;
  extern float u_time;
  extern vec3 u_color;
  extern vec3 u_bg;

  vec4 effect(vec4 _c, Image tex, vec2 uv, vec2 sc) {
    if (uv.x > u_fill) {
      return vec4(u_bg, 0.6);
    }
    float wave = sin(uv.x * 30.0 - u_time * 4.0) * 0.08;
    float top = smoothstep(0.0, 0.5, uv.y);
    vec3 col = u_color * (0.8 + wave + top * 0.3);
    return vec4(col, 0.95);
  }
]]

local function tryNew(src)
  local ok, sh = pcall(love.graphics.newShader, src)
  if ok then return sh end
  return nil, sh
end

function M.load()
  M.coreGlow  = tryNew(CORE_GLOW)
  M.bgGrid    = tryNew(BG_GRID)
  M.crt       = tryNew(CRT)
  M.glowRing  = tryNew(GLOW_RING)
  M.energyBar = tryNew(ENERGY_BAR)
end

return M
