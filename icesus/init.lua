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

blight.output(C_GOOD .. '[Icesus] package v' .. ICESUS_VERSION .. ' loaded.' .. C_RESET)
