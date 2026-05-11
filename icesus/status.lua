-- Icesus status.lua
local mod = {}

mod.status = {}
mod.vitals = {}
mod.time = {}
mod.exp_mode = 'tna' -- 'tna' = exp to next adv point, 'tnl' = exp to next level

-- Percentage that doesn't divide by zero. Returns 0 if max is missing
-- or non-positive (happens before the first Char.Vitals arrives, or
-- briefly during reincarnation).
local function pct(current, max)
  if not current or not max or max <= 0 then
    return 0
  end
  return math.floor((current / max) * 100)
end

-- Colour selector for hp/sp/ep/psp pools
local function colour_for_ratio(current, max)
  local p = pct(current, max)
  if p >= 70 then
    return C_GOOD
  elseif p >= 30 then
    return C_WARN
  end
  return C_CRIT
end

-- Format pool value as percentage out of 100
local function fmt_pct(current, max)
  return string.format('%3d/100', pct(current, max))
end

-- HP/SP/EP/PSP segment formatter
local function fmt_pool(label, current, max)
  return string.format('%s%s: %s%s', colour_for_ratio(current, max), label, fmt_pct(current, max), C_RESET)
end

-- Exp progress
local function fmt_exp(exp, remaining)
  if remaining == nil then
    return string.format('Exp: %s (??%%)', exp or '0')
  end

  if remaining <= 0 then
    return string.format('Exp: %s (inf)', exp or '0')
  end

  local p = math.floor((exp / remaining) * 100)
  return string.format('Exp: %s (%d%%)', exp or '0', p)
end

-- Join non-empty status parts with separators
local function join(parts)
  local out = {}

  for _, part in ipairs(parts) do
    if part and part ~= '' then
      out[#out + 1] = part
    end
  end

  return table.concat(out, '  ')
end

-- Server-aligned shape buckets (see GMCP spec, Char.Status.enemies):
-- 100, 99, 90, 80, 70, 60, 50, 40, 30, 20, 10, 5. The colour bands
-- map to the shape words consider would tell you.
local function colour_for_enemy_hp(hp)
  if hp >= 70 then
    return C_GOOD       -- excellent / good / slightly hurt
  elseif hp >= 40 then
    return C_WARN       -- moderately hurt / not good / severely hurt
  elseif hp >= 20 then
    return C_BAD        -- bad / very bad / extremely bad
  end
  return C_NOTGOOD      -- gravely wounded / almost dead / dead meat
end

function mod:handle_status(data)
  if type(data) ~= 'table' then
    return
  end
  self.status = data
  self:update()
end

function mod:handle_vitals(data)
  if type(data) ~= 'table' then
    return
  end
  self.vitals = data
  self:update()
end

function mod:handle_time(data)
  if type(data) ~= 'table' then
    return
  end
  self.time = data
  self:update()
end

function mod:init()
  blight.status_height(2)
  gmcp.on_ready(function()
    blight.output('[Icesus] Registering GMCP')
    -- Subscribe to the specific sub-packages we read so client intent
    -- is visible on the wire and survives any future server-side gating.
    gmcp.register('Char.Vitals')
    gmcp.register('Char.Status')
    gmcp.register('World.Time')
    gmcp.receive('Char.Vitals', function(data)
      local obj = json.decode(data)
      mod:handle_vitals(obj)
    end)
    gmcp.receive('Char.Status', function(data)
      local obj = json.decode(data)
      mod:handle_status(obj)
    end)
    gmcp.receive('World.Time', function(data)
      local obj = json.decode(data)
      mod:handle_time(obj)
    end)
  end)
end

function mod:fmt_status()
  if not self.status or not self.vitals or not self.time then
    return 'GMCP data missing'
  end
  local parts = {}
  -- HP/SP/EP/PSP
  parts[#parts + 1] = fmt_pool('Hp', self.vitals.hp, self.vitals.maxhp)
  parts[#parts + 1] = fmt_pool('Sp', self.vitals.mana, self.vitals.maxmana)
  parts[#parts + 1] = fmt_pool('Ep', self.vitals.moves, self.vitals.maxmoves)
  if self.status.psp_on == 1 then
    parts[#parts + 1] = fmt_pool('Psp', self.vitals.psp, self.vitals.maxpsp)
  end

  -- Exp
  if self.exp_mode == 'tna' then
    parts[#parts + 1] = fmt_exp(self.status.exp, self.status.tna)
  else
    parts[#parts + 1] = fmt_exp(self.status.exp, self.status.tnl)
  end

  -- Time
  parts[#parts + 1] = self.time.hour_name
  return join(parts)
end

function mod:fmt_enemies()
  local parts = {}
  if self.status and self.status.enemies and type(self.status.enemies) == 'table' then
    for _, e in pairs(self.status.enemies) do
      local hp = e.hp or 0
      table.insert(parts, string.format('%s%3d%s%%', colour_for_enemy_hp(hp), hp, C_RESET))
    end
  end
  return join(parts)
end

function mod:update()
  blight.status_line(0, self:fmt_enemies())
  blight.status_line(1, self:fmt_status())
end

return mod
