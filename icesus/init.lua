-- Icesus package init.lua
--
-- config.lua loads this file on every connect. Everything here
-- registers listeners, so only the first load in a session does the
-- work; /reload starts a fresh session.
if Icesus and Icesus.loaded then
  return
end

package.path = blight.config_dir() .. '/?.lua;' .. package.path

ICESUS_VERSION = '0.2.2'

C_WARN = C_BYELLOW
C_CRIT = C_BRED
C_GOOD = C_BGREEN
C_BAD = C_BRED
C_NOTGOOD = C_BMAGENTA

-- Settings you can change from local.lua, which loads after this file.
-- Call Icesus.layout() after changing rows.
Icesus = {
  loaded = true,
  version = ICESUS_VERSION,
  -- The two layouts /icesus full and /icesus simple switch between.
  -- Row names: 'location', 'action', 'condition', 'enemies', 'vitals'.
  layouts = {
    full = { 'location', 'action', 'condition', 'vitals' },
    simple = { 'enemies', 'vitals' },
  },
  -- Status rows in use, top to bottom, at most five. Set from the
  -- layout last chosen below; set your own here from local.lua.
  rows = nil,
  hotkeys = {
    -- Bind F1-F12 to the hotkeys saved on your character.
    use_server = true,
  },
  -- Filled in by bind_momentum() in bindings.lua.
  momentum_keys = {},
}

local status = require('icesus.status')
local keys = require('icesus.keys')

function Icesus.layout()
  status:layout()
end

-- Switch to a named layout and remember it across sessions.
function Icesus.set_layout(name)
  local rows = Icesus.layouts[name]
  if not rows then
    return false
  end
  Icesus.layout_name = name
  Icesus.rows = { table.unpack(rows) }
  store.disk_write('icesus_layout', name)
  status:layout()
  return true
end

local saved = store.disk_read('icesus_layout')
Icesus.layout_name = Icesus.layouts[saved or ''] and saved or 'full'
Icesus.rows = { table.unpack(Icesus.layouts[Icesus.layout_name]) }

-- Turn server hotkeys on or off after changing Icesus.hotkeys.use_server.
Icesus.apply_hotkeys = keys.apply
Icesus.use_momentum = keys.use_momentum
Icesus.bind_momentum = keys.bind_momentum

status:init()
keys.init()
require('icesus.bindings')
require('icesus.lites')
require('icesus.aliases')
require('icesus.commands')

-- Dim echoed user input. Blightmud renders typed input in bright yellow
-- by default, which competes with the actual MUD output. This gags the
-- default echo (display-only — does NOT touch what's sent to the MUD)
-- and re-injects a grey copy via blight.output, so room descriptions
-- and combat lines stay the loud thing on screen. Only acts on
-- user-typed lines; script-sent lines keep their existing gag handling.
mud.add_input_listener(function(line)
  if line:source() == 'user' then
    line:gag(true)
    blight.output(C_BBLACK .. '[>>] ' .. line:line() .. C_RESET)
  end
  return line
end)

blight.output(C_GOOD .. '[Icesus] package v' .. ICESUS_VERSION .. ' loaded. Type /icesus for keys and commands.' .. C_RESET)
