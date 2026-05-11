-- Icesus package init.lua
package.path = blight.config_dir() .. '/?.lua;' .. package.path

ICESUS_VERSION = '0.1.0'

C_WARN = C_BYELLOW
C_CRIT = C_BRED
C_GOOD = C_BGREEN
C_BAD = C_BRED
C_NOTGOOD = C_BMAGENTA

require('icesus.bindings')
require('icesus.lites')
local icesus_status = require('icesus.status')
icesus_status:init()
require('icesus.aliases')

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

blight.output(C_GOOD .. '[Icesus] package v' .. ICESUS_VERSION .. ' loaded.' .. C_RESET)
