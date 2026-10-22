-- Icesus package init.lua
--
-- config.lua loads this file on every connect. Everything here
-- registers listeners, so only the first load in a session does the
-- work; /reload starts a fresh session.
if Icesus and Icesus.loaded then
  return
end

package.path = blight.config_dir() .. '/?.lua;' .. package.path

ICESUS_VERSION = '0.2.0'

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
  -- Status rows, top to bottom. At most five; drop any you don't want.
  -- 'location', 'action', 'condition', 'vitals'
  rows = { 'location', 'action', 'condition', 'vitals' },
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
