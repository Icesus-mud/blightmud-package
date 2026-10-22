-- Icesus commands.lua
--
--   /icesus         version, keys, and what the status rows show
--   /icesus guild   bonds, souls, charm abilities and devotion
local status = require('icesus.status')
local keys = require('icesus.keys')

local BOND_ORDER = { 'air', 'water', 'fire', 'earth' }
-- The nine, in the order the server's piety daemon lists them.
local PIETY_ORDER = {
  'earth', 'water', 'fire', 'air', 'nameless king', 'nether', 'ancestors', 'spirits', 'aetheria',
}
local INDENT = '             '

local function out(text)
  blight.output(text .. C_RESET)
end

local function block(t, key)
  local b = type(t) == 'table' and t[key]
  if type(b) == 'table' and next(b) ~= nil then
    return b
  end
  return nil
end

local function num(n)
  return string.format('%d', math.floor(tonumber(n) or 0))
end

-- "name value" pairs wrapped to lines of about 70 columns.
local function wrap_pairs(items)
  local lines, line, used = {}, '', 0
  for _, it in ipairs(items) do
    local piece = it.key .. ' ' .. (it.dim and C_BBLACK or C_BWHITE) .. it.val .. C_RESET
    local cells = utf8.len(it.key .. ' ' .. it.val) or 0
    if line ~= '' and used + cells + 3 > 70 then
      lines[#lines + 1] = line
      line, used = '', 0
    end
    if line ~= '' then
      line, used = line .. '   ', used + 3
    end
    line, used = line .. piece, used + cells
  end
  if line ~= '' then
    lines[#lines + 1] = line
  end
  return lines
end

local function print_guild()
  local r = status.resources
  local any = false
  out(C_CYAN .. 'Icesus guild resources')

  -- Same columns and words as the bond table in the guild item.
  local bonds = block(r, 'bonds')
  if bonds then
    any = true
    out('  ' .. C_YELLOW .. 'Bonds' .. C_RESET .. '      ' .. C_BBLACK .. 'element      strength    load   drain')
    for _, el in ipairs(BOND_ORDER) do
      local b = bonds[el]
      if type(b) == 'table' then
        local drain = tonumber(b.drain) or 0
        local colour = drain > 0 and C_GREEN or (drain < 0 and C_RED or C_BBLACK)
        out(string.format(
          INDENT .. '%-12s %8s  %6s   %s%s%s',
          el,
          num(b.strength),
          num(b.load),
          colour,
          drain > 0 and '+' or '',
          num(drain)
        ))
      end
    end
    out(INDENT .. C_BBLACK .. 'drain is the net change each ten-second tick: positive fills the bond')
  end

  local souls = block(r, 'souls')
  if souls then
    any = true
    local items = {}
    for k, v in pairs(souls) do
      items[#items + 1] = { key = tostring(k), val = num(v), n = tonumber(v) or 0 }
    end
    table.sort(items, function(a, b)
      if a.n ~= b.n then
        return a.n > b.n
      end
      return a.key < b.key
    end)
    out(string.format(
      '  %sSouls%s      %s%d kind%s, largest first',
      C_YELLOW,
      C_RESET,
      C_BBLACK,
      #items,
      #items == 1 and '' or 's'
    ))
    for _, line in ipairs(wrap_pairs(items)) do
      out(INDENT .. line)
    end
  end

  local charms = block(r, 'charms')
  if charms then
    local desc = type(charms.desc) == 'string' and charms.desc or ''
    local abil = block(charms, 'abilities')
    if desc ~= '' or abil then
      any = true
      out('  ' .. C_YELLOW .. 'Charm' .. C_RESET .. '      ' .. C_BWHITE .. (desc ~= '' and desc or 'active'))
      if abil then
        local items = {}
        for k, v in pairs(abil) do
          items[#items + 1] = { key = tostring(k), val = num(v) }
        end
        table.sort(items, function(a, b)
          return a.key < b.key
        end)
        for _, line in ipairs(wrap_pairs(items)) do
          out(INDENT .. line)
        end
      end
    end
  end

  local piety = block(r, 'piety')
  if piety then
    any = true
    local items, seen = {}, {}
    local function add(k)
      local v = tonumber(piety[k]) or 0
      items[#items + 1] = { key = k, val = num(v), dim = v == 0 }
      seen[k] = true
    end
    for _, k in ipairs(PIETY_ORDER) do
      if piety[k] ~= nil then
        add(k)
      end
    end
    local rest = {}
    for k in pairs(piety) do
      if not seen[k] then
        rest[#rest + 1] = tostring(k)
      end
    end
    table.sort(rest)
    for _, k in ipairs(rest) do
      add(k)
    end
    out('  ' .. C_YELLOW .. 'Devotion' .. C_RESET .. '   ' .. C_BBLACK .. 'your standing with the nine')
    for _, line in ipairs(wrap_pairs(items)) do
      out(INDENT .. line)
    end
  end

  if not any then
    out('  ' .. C_BBLACK .. 'Nothing to show: your character carries no guild resources or devotion right now.')
  end
end

-- Ask the server for a fresh copy first. It answers at once, but print
-- what is cached if the answer has not arrived in two seconds.
local function guild()
  local printed = false
  local function once()
    if not printed then
      printed = true
      print_guild()
    end
  end
  status.on_resources = once
  gmcp.send('Char.Resources')
  timer.add(2, 1, function()
    status.on_resources = nil
    once()
  end)
end

local function help()
  out(C_GOOD .. '[Icesus] package v' .. Icesus.version)
  out('  ' .. C_YELLOW .. 'Momentum' .. C_RESET .. '   ' .. (Icesus.momentum_keys[1] or 'unbound') .. ' uses your momentum, '
    .. (Icesus.momentum_keys[2] or 'unbound') .. ' your special momentum')
  local fkeys = {}
  for i = 1, 12 do
    local cmd = keys.bound['f' .. i]
    if cmd then
      fkeys[#fkeys + 1] = { key = 'F' .. i, val = cmd }
    end
  end
  if #fkeys > 0 then
    out('  ' .. C_YELLOW .. 'Hotkeys' .. C_RESET .. '    ' .. C_BBLACK .. 'saved on your character; edit them in the web client')
    for _, line in ipairs(wrap_pairs(fkeys)) do
      out(INDENT .. line)
    end
  elseif not Icesus.hotkeys.use_server then
    out('  ' .. C_YELLOW .. 'Hotkeys' .. C_RESET .. '    ' .. C_BBLACK .. 'off (Icesus.hotkeys.use_server = false)')
  end
  out('  ' .. C_YELLOW .. 'Rows' .. C_RESET .. '       ' .. table.concat(Icesus.rows, ', '))
  out('  ' .. C_YELLOW .. 'Commands' .. C_RESET .. '   /icesus guild    bonds, souls, charm abilities, devotion')
  out(INDENT .. '/reload          re-read the whole config after an edit')
end

alias.add([=[^/icesus(?:\s+(\S+))?\s*$]=], function(matches)
  local sub = matches[2] or ''
  if sub == 'guild' then
    guild()
  elseif sub == '' or sub == 'help' then
    help()
  else
    out(C_BRED .. '[Icesus] Unknown: /icesus ' .. sub .. '. Try /icesus or /icesus guild.')
  end
end)
