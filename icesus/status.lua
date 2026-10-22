-- Icesus status.lua
--
-- GMCP -> the status area at the bottom of the terminal. Each package
-- is kept as the server last sent it and replaced wholesale on arrival;
-- every arrival redraws every row from that cached state.
--
-- Rows, top to bottom in the full layout (see Icesus.layouts in
-- init.lua):
--   location   room name, area, SAFE / INN, exits
--   action     momentum, casting or busy bar, cooldowns
--   condition  enemies, afflictions, wounds, concealment, karma
--   vitals     pools, guild resources, exp, in-game hour
-- The simple layout is enemies (the fight alone) over vitals.
--
-- A row that does not fit the terminal is first drawn in a shorter
-- form, then cut from the right with an ellipsis, so the things a
-- player watches most sit at the left of each row.
local mod = {}

mod.vitals = {}
mod.status = {}
mod.time = {}
mod.room = {}
mod.casting = {}
mod.resources = {}
mod.cooldowns = {}
mod.cooldowns_at = 0

-- Keys of Char.Vitals that are the core pools. Every other key is a
-- guild scalar (fury, vitae, ...), so one the server adds later shows
-- up without a package update.
local CORE_VITALS = {
  hp = true,
  mana = true,
  moves = true,
  psp = true,
  maxhp = true,
  maxmana = true,
  maxmoves = true,
  maxpsp = true,
}
local SCALAR_COLOURS = { fury = C_RED, vitae = C_MAGENTA }
local BOND_ORDER = { 'air', 'water', 'fire', 'earth' }
local LEVEL_CAP = 100

local EFFECT_COLOURS = {
  ['death sickness'] = C_MAGENTA,
  bleeding = C_BRED,
  stunned = C_BYELLOW,
  poisoned = C_GREEN,
  burning = C_RED,
}
local WOUND_COLOURS = {
  minor = C_WHITE,
  nasty = C_YELLOW,
  bad = C_BYELLOW,
  severe = C_BRED,
  fatal = C_BMAGENTA,
}
local WOUND_RANK = { minor = 1, nasty = 2, bad = 3, severe = 4, fatal = 5 }
local STEALTH_LABELS = {
  ['moving silently'] = 'SILENT',
  ['hiding in shadows'] = 'HIDDEN',
  invisible = 'INVIS',
}

local EXIT_SHORT = {
  north = 'n',
  northeast = 'ne',
  east = 'e',
  southeast = 'se',
  south = 's',
  southwest = 'sw',
  west = 'w',
  northwest = 'nw',
  up = 'u',
  down = 'd',
}
local EXIT_ORDER = {
  'north', 'northeast', 'east', 'southeast', 'south', 'southwest', 'west', 'northwest', 'up', 'down', 'in', 'out',
}

local ELLIPSIS = '…'
local SEP = '  '

-- ---------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------

-- Percentage that doesn't divide by zero. Returns 0 if max is missing
-- or non-positive (happens before the first Char.Vitals arrives, or
-- briefly during reincarnation).
local function pct(current, max)
  current, max = tonumber(current), tonumber(max)
  if not current or not max or max <= 0 then
    return 0
  end
  return math.floor((current / max) * 100)
end

local function colour_for_pct(p)
  if p >= 70 then
    return C_GOOD
  elseif p >= 30 then
    return C_WARN
  end
  return C_CRIT
end

-- 1234567 -> "1,234,567". Exact: an exp or bond reading is never rounded.
local function thousands(n)
  local s = string.format('%d', math.floor(tonumber(n) or 0))
  local sign, digits = s:match('^(-?)(%d+)$')
  digits = digits:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
  return sign .. digits
end

local function capitalise(s)
  s = tostring(s or '')
  return s:sub(1, 1):upper() .. s:sub(2)
end

-- A non-empty table, or nil. FluffOS encodes an empty mapping as [],
-- which decodes to the same empty table as "no block".
local function block(t, key)
  local b = type(t) == 'table' and t[key]
  if type(b) == 'table' and next(b) ~= nil then
    return b
  end
  return nil
end

local function list(t)
  return type(t) == 'table' and t or {}
end

local function width(text)
  return utf8.len(text) or #text
end

local function cut(text, cells)
  if width(text) <= cells then
    return text
  end
  if cells < 1 then
    return ''
  end
  return text:sub(1, utf8.offset(text, cells) - 1) .. ELLIPSIS
end

-- Cooldown or remaining time: 18s, 4:05, 1h02.
local function fmt_time(secs)
  secs = math.max(0, math.floor(secs))
  if secs < 60 then
    return secs .. 's'
  elseif secs < 3600 then
    return string.format('%d:%02d', secs // 60, secs % 60)
  end
  return string.format('%dh%02d', secs // 3600, (secs % 3600) // 60)
end

-- ---------------------------------------------------------------
-- Segments: a row is a list of segments, a segment a list of
-- { text, colour } parts drawn without a gap. Segments are joined
-- with two spaces and dropped whole when the row runs out of room.
-- ---------------------------------------------------------------

local function seg(...)
  local args = { ... }
  local parts = {}
  for i = 1, #args, 2 do
    parts[#parts + 1] = { tostring(args[i]), args[i + 1] }
  end
  return parts
end

local function seg_width(s)
  local w = 0
  for _, p in ipairs(s) do
    w = w + width(p[1])
  end
  return w
end

local function row_width(segs)
  local w = 0
  for i, s in ipairs(segs) do
    w = w + seg_width(s) + (i > 1 and #SEP or 0)
  end
  return w
end

local function draw(segs, room)
  local out = {}
  local used = 0
  for i, s in ipairs(segs) do
    local w = seg_width(s) + (i > 1 and #SEP or 0)
    if used + w > room then
      out[#out + 1] = C_BBLACK .. (i > 1 and ' ' or '') .. ELLIPSIS .. C_RESET
      break
    end
    out[#out + 1] = i > 1 and SEP or ''
    for _, p in ipairs(s) do
      out[#out + 1] = p[2] and (p[2] .. p[1] .. C_RESET) or p[1]
    end
    used = used + w
  end
  return table.concat(out)
end

-- ---------------------------------------------------------------
-- Rows. Each builder takes a compaction level: 0 is the full form,
-- higher levels are shorter. A builder returns nil for a level it
-- has no shorter form for.
-- ---------------------------------------------------------------

local rows = {}

function rows.location(self, level)
  local r = self.room
  if type(r.name) ~= 'string' then
    return {}
  end
  if level > 2 then
    return nil
  end
  -- Shorter forms give up the area, then length of the room name,
  -- before the exits.
  local segs = {}
  local name = level == 0 and r.name or cut(r.name, level == 1 and 30 or 18)
  if level == 0 and type(r.area) == 'string' and r.area ~= '' then
    segs[1] = seg(name, C_BWHITE, ' · ' .. r.area, C_BBLACK)
  else
    segs[1] = seg(name, C_BWHITE)
  end
  if tonumber(r.safe) == 1 then
    segs[#segs + 1] = seg('SAFE', C_BGREEN)
  end
  if tonumber(r.inn) == 1 then
    segs[#segs + 1] = seg('INN', C_BBLUE)
  end

  -- Room.Info v2 sends exits as direction -> destination; v1 sent a
  -- list of directions. Read either.
  local dirs, seen = {}, {}
  for k, v in pairs(list(r.exits)) do
    local dir = type(k) == 'number' and v or k
    if type(dir) == 'string' and not seen[dir] then
      seen[dir] = true
    end
  end
  for _, dir in ipairs(EXIT_ORDER) do
    if seen[dir] then
      dirs[#dirs + 1] = EXIT_SHORT[dir] or dir
      seen[dir] = nil
    end
  end
  local others = {}
  for dir in pairs(seen) do
    others[#others + 1] = dir
  end
  table.sort(others)
  for _, dir in ipairs(others) do
    dirs[#dirs + 1] = dir
  end
  if #dirs > 0 then
    segs[#segs + 1] = seg('exits ', C_BBLACK, table.concat(dirs, ' '), C_CYAN)
  elseif r.id ~= '' then
    segs[#segs + 1] = seg('no obvious exits', C_BBLACK)
  end
  return segs
end

local function momentum_seg(name, source, key, level)
  local label = name:upper()
  if level == 0 and type(source) == 'string' and source ~= '' and source ~= 'combat' then
    label = source .. ': ' .. label
  end
  local s = seg('» ' .. label, C_BOLD .. C_BYELLOW)
  if key and level < 2 then
    s[#s + 1] = { ' ' .. key, C_BBLACK }
  end
  return s
end

local function cast_bar(p, cells)
  local filled = math.floor(p * cells / 100 + 0.5)
  return string.rep('█', filled), string.rep('░', cells - filled)
end

function rows.action(self, level)
  if level > 2 then
    return nil
  end
  local s, keys = self.status, Icesus.momentum_keys or {}
  local segs = {}

  if type(s.momentum) == 'string' and s.momentum ~= '' then
    segs[#segs + 1] = momentum_seg(s.momentum, s.momentum_source, keys[1], level)
  end
  if type(s.special_momentum) == 'string' and s.special_momentum ~= '' then
    segs[#segs + 1] = momentum_seg(s.special_momentum, nil, keys[2], level)
  end

  local c = self.casting
  if tonumber(c.active) == 1 and tonumber(s.casting) ~= 0 then
    local p = math.max(0, math.min(100, tonumber(c.progress) or 0))
    local done, todo = cast_bar(p, level == 0 and 12 or 6)
    segs[#segs + 1] = seg(
      (c.spell or 'Casting') .. ' ',
      C_BWHITE,
      done,
      C_BMAGENTA,
      todo,
      C_BBLACK,
      string.format(' %d%%', p),
      C_BMAGENTA
    )
  elseif tonumber(s.busy) == 1 and type(s.activity) == 'string' and s.activity ~= '' then
    segs[#segs + 1] = seg('⋯ ' .. s.activity, C_YELLOW)
  end

  local elapsed = os.time() - self.cooldowns_at
  local cds = {}
  for _, cd in ipairs(self.cooldowns) do
    local left = (tonumber(cd.remaining) or 0) - elapsed
    if left > 0 then
      local total = tonumber(cd.total) or 0
      local colour = C_CYAN
      if total > 0 and left / total > 0.5 then
        colour = C_RED
      elseif total > 0 and left / total <= 0.15 then
        colour = C_GREEN
      end
      local name = tostring(cd.name or '?')
      if level >= 2 then
        name = cut(name, 8)
      end
      cds[#cds + 1] = { name, left, colour }
    end
  end
  if #cds > 0 then
    if level >= 1 then
      -- One segment for the lot, so a long list loses its tail
      -- rather than every cooldown after the first one that misses.
      local parts = seg('cd ', C_BBLACK)
      for i, cd in ipairs(cds) do
        parts[#parts + 1] = { (i > 1 and ' ' or '') .. cd[1] .. ' ', C_WHITE }
        parts[#parts + 1] = { fmt_time(cd[2]), cd[3] }
      end
      segs[#segs + 1] = parts
    else
      for i, cd in ipairs(cds) do
        segs[#segs + 1] = seg(i == 1 and 'cd ' or '', C_BBLACK, cd[1] .. ' ', C_WHITE, fmt_time(cd[2]), cd[3])
      end
    end
  end
  return segs
end

-- Server-aligned shape buckets (see GMCP spec, Char.Status.enemies):
-- 100, 99, 90, 80, 70, 60, 50, 40, 30, 20, 10, 5. The colour bands
-- map to the shape words consider would tell you.
local function colour_for_enemy_hp(hp)
  if hp >= 70 then
    return C_GOOD -- excellent / good / slightly hurt
  elseif hp >= 40 then
    return C_WARN -- moderately hurt / not good / severely hurt
  elseif hp >= 20 then
    return C_BAD -- bad / very bad / extremely bad
  end
  return C_NOTGOOD -- gravely wounded / almost dead / dead meat
end

local function enemy_name(name)
  name = tostring(name or '')
  name = name:gsub('^[Aa]n? ', ''):gsub('^[Tt]he ', '')
  return cut(name, 16)
end

-- Every enemy as one segment: names and HP, or HP alone at level 1+.
local function enemies_seg(self, level)
  local enemies = list(self.status.enemies)
  if #enemies == 0 then
    return nil
  end
  local parts = seg('vs ', C_BBLACK)
  for i, e in ipairs(enemies) do
    local hp = tonumber(e.hp) or 0
    if i > 1 then
      parts[#parts + 1] = { level == 0 and ', ' or ' ', nil }
    end
    if level == 0 then
      parts[#parts + 1] = { enemy_name(e.name) .. ' ', nil }
    end
    parts[#parts + 1] = { hp .. '%', colour_for_enemy_hp(hp) }
  end
  return parts
end

-- The simple layout's top row: the fight and nothing else.
function rows.enemies(self, level)
  if level > 1 then
    return nil
  end
  return { enemies_seg(self, level) }
end

function rows.condition(self, level)
  if level > 2 then
    return nil
  end
  local s = self.status
  local segs = { enemies_seg(self, level) }

  local wounds = list(s.wounds)
  for _, fx in ipairs(list(s.effects)) do
    -- The wounds below say where the bleeding is; skip the bare badge.
    if not (fx == 'bleeding' and #wounds > 0) then
      segs[#segs + 1] = seg(tostring(fx):upper(), EFFECT_COLOURS[fx] or C_BRED)
    end
  end

  if #wounds > 0 then
    if level == 0 then
      for _, w in ipairs(wounds) do
        local sev = tostring(w.severity or 'minor')
        segs[#segs + 1] = seg(tostring(w.slot or 'wound'):upper() .. ' ' .. sev, WOUND_COLOURS[sev] or C_BRED)
      end
    else
      local worst = 'minor'
      for _, w in ipairs(wounds) do
        if (WOUND_RANK[w.severity] or 0) > (WOUND_RANK[worst] or 0) then
          worst = w.severity
        end
      end
      segs[#segs + 1] = seg('BLEEDING ×' .. #wounds, WOUND_COLOURS[worst] or C_BRED)
    end
  end

  for _, st in ipairs(list(s.stealth)) do
    segs[#segs + 1] = seg(STEALTH_LABELS[st] or tostring(st):upper(), C_BCYAN)
  end

  local karmas = list(s.karmas)
  if #karmas > 0 then
    local names = {}
    for _, k in ipairs(karmas) do
      names[#names + 1] = tostring(k):upper()
    end
    segs[#segs + 1] = seg('☯ ' .. table.concat(names, ' '), C_YELLOW)
  end
  return segs
end

local function pool_seg(label, current, max)
  local p = pct(current, max)
  return seg(label .. ' ' .. p .. '%', colour_for_pct(p))
end

local function exp_seg(s, level)
  local atcap = (tonumber(s.level) or 0) >= LEVEL_CAP
  local denom = tonumber(atcap and s.tna or s.tnl)
  local exp = tonumber(s.exp)
  if not exp then
    return nil
  end
  local label = atcap and 'AP ' or 'Exp '
  local amount = level < 2 and (thousands(exp) .. ' ') or ''
  if not denom or denom <= 0 then
    return seg(label .. amount, C_WHITE)
  end
  local p = math.floor(exp / denom * 100)
  if p >= 100 then
    return seg(label .. amount, C_WHITE, '100%+', C_BGREEN)
  end
  return seg(label .. amount, C_WHITE, p .. '%', C_BWHITE)
end

function rows.vitals(self, level)
  if level > 3 then
    return nil
  end
  local v, s = self.vitals, self.status
  if not v.maxhp then
    return {}
  end
  local segs = {
    pool_seg('Hp', v.hp, v.maxhp),
    pool_seg('Sp', v.mana, v.maxmana),
    pool_seg('Ep', v.moves, v.maxmoves),
  }
  if tonumber(s.psp_on) == 1 then
    segs[#segs + 1] = pool_seg('Psp', v.psp, v.maxpsp)
  end

  -- Guild readings are exact numbers, never percentages: none of them
  -- has a maximum to fill against.
  local scalars = {}
  for k, val in pairs(v) do
    if not CORE_VITALS[k] and tonumber(val) then
      scalars[#scalars + 1] = k
    end
  end
  table.sort(scalars)
  for _, k in ipairs(scalars) do
    segs[#segs + 1] = seg(capitalise(k) .. ' ', SCALAR_COLOURS[k] or C_CYAN, thousands(v[k]), C_BWHITE)
  end

  local bonds = block(self.resources, 'bonds')
  if bonds then
    for _, el in ipairs(BOND_ORDER) do
      local b = bonds[el]
      local drain = type(b) == 'table' and tonumber(b.drain) or 0
      -- A bond with no strength that is not filling is one the
      -- character has not formed; it would only take room.
      if type(b) == 'table' and ((tonumber(b.strength) or 0) > 0 or drain ~= 0) then
        local label = level >= 1 and el:sub(1, 1):upper() or capitalise(el)
        local parts = seg(label .. ' ', C_CYAN, thousands(b.strength), C_BWHITE)
        if drain > 0 then
          parts[#parts + 1] = { '▲', C_GREEN }
        elseif drain < 0 then
          parts[#parts + 1] = { '▼', C_RED }
        end
        segs[#segs + 1] = parts
      end
    end
  end

  local charms = block(self.resources, 'charms')
  if charms and level < 2 then
    local desc = type(charms.desc) == 'string' and charms.desc ~= '' and charms.desc or 'active'
    segs[#segs + 1] = seg('Charm ', C_CYAN, level >= 1 and cut(desc, 8) or desc, C_BWHITE)
  end

  segs[#segs + 1] = exp_seg(s, level)

  if level < 3 and type(self.time.hour_name) == 'string' then
    segs[#segs + 1] = seg(self.time.hour_name, C_BBLACK)
  end
  return segs
end

-- ---------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------

-- Blightmud draws the first and last status lines inside the bars
-- that frame the status area ("━ text ━━━"), which costs them a few
-- columns; the lines between get the full width.
local BAR_COST = 4

function mod:render_row(name, index, count)
  local build = rows[name]
  if not build then
    return C_BRED .. 'unknown status row: ' .. tostring(name) .. C_RESET
  end
  local w = blight.terminal_dimensions()
  local room = (w or 80) - ((index == 0 or index == count - 1) and BAR_COST or 1)
  local segs, level = build(self, 0), 1
  while row_width(segs) > room do
    local shorter = build(self, level)
    if not shorter then
      break
    end
    segs, level = shorter, level + 1
  end
  return draw(segs, room)
end

function mod:update()
  local names = Icesus.rows
  for i, name in ipairs(names) do
    blight.status_line(i - 1, self:render_row(name, i - 1, #names))
  end
end

function mod:layout()
  blight.status_height(#Icesus.rows)
  self:update()
end

-- What is cached from one connection means nothing on the next.
function mod:clear()
  self.vitals, self.status, self.room, self.casting = {}, {}, {}, {}
  self.resources, self.cooldowns, self.time = {}, {}, {}
  self:update()
end

-- ---------------------------------------------------------------
-- GMCP
-- ---------------------------------------------------------------

local function decode(data)
  local ok, obj = pcall(json.decode, data)
  if ok and type(obj) == 'table' then
    return obj
  end
  return nil
end

-- Package name -> function(self, payload). Each replaces what it owns.
local HANDLERS = {
  ['Char.Vitals'] = function(self, d)
    self.vitals = d
  end,
  ['Char.Status'] = function(self, d)
    -- In combat the server leaves out money, bank and dfavor; keep
    -- the last values so anything reading them still has them.
    for _, k in ipairs({ 'money', 'bank', 'dfavor' }) do
      if d[k] == nil then
        d[k] = self.status[k]
      end
    end
    self.status = d
  end,
  ['Char.Casting'] = function(self, d)
    self.casting = d
  end,
  ['Char.Cooldowns'] = function(self, d)
    self.cooldowns = list(d.cooldowns)
    self.cooldowns_at = os.time()
  end,
  ['Char.Resources'] = function(self, d)
    self.resources = d
    if self.on_resources then
      local cb = self.on_resources
      self.on_resources = nil
      cb()
    end
  end,
  ['Room.Info'] = function(self, d)
    self.room = d
  end,
  ['World.Time'] = function(self, d)
    self.time = d
  end,
}

mod.packages = {
  'Char.Vitals',
  'Char.Status',
  'Char.Casting',
  'Char.Cooldowns',
  'Char.Resources',
  'Room.Info',
  'World.Time',
}

function mod:init()
  self:layout()
  -- on_ready fires again on every new connection, so the subscriptions
  -- go out each time.
  gmcp.on_ready(function()
    for _, name in ipairs(self.packages) do
      gmcp.register(name)
    end
  end)
  for name, handler in pairs(HANDLERS) do
    gmcp.receive(name, function(data)
      local obj = decode(data)
      if obj then
        handler(self, obj)
        self:update()
      end
    end)
  end
  mud.on_disconnect(function()
    self:clear()
  end)
  -- Cooldowns count down between the server's ten-second updates.
  timer.add(1, 0, function()
    if #self.cooldowns > 0 then
      self:update()
    end
  end)
end

return mod
