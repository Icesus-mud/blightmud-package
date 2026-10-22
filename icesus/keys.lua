-- Icesus keys.lua
--
-- Two kinds of key:
--   F1-F12     the hotkeys saved on your character. The server sends
--              them on login (Client.Hotkeys) - the same set the web
--              client edits and shows as buttons - and they are bound
--              here as they arrive. Set Icesus.hotkeys.use_server =
--              false in local.lua to keep the F-keys for your own binds.
--   momentum   one key per momentum lane, sending "use <momentum>" for
--              whatever is lit right now, and nothing when nothing is.
local status = require('icesus.status')

local mod = {}

mod.server = {} -- last Client.Hotkeys payload
mod.bound = {} -- f-key -> command we bound from it

-- (Re)bind F1-F12 from the server's hotkeys. A key the server no
-- longer sets is unbound.
function mod.apply()
  for key in pairs(mod.bound) do
    blight.unbind(key)
  end
  mod.bound = {}
  if not Icesus.hotkeys.use_server then
    return
  end
  for name, cmd in pairs(mod.server) do
    local n = tonumber(tostring(name):match('^[Ff](%d+)$'))
    if n and n >= 1 and n <= 12 and type(cmd) == 'string' and cmd ~= '' then
      local key = 'f' .. n
      blight.bind(key, function()
        mud.send(cmd)
      end)
      mod.bound[key] = cmd
    end
  end
end

-- lane 1 is Char.Status.momentum (combat or crafting), lane 2 is
-- special_momentum (combat specials).
function mod.use_momentum(lane)
  local s = status.status
  local m = lane == 2 and s.special_momentum or s.momentum
  if type(m) ~= 'string' or m == '' then
    blight.output(C_BBLACK .. '[Icesus] No momentum to use right now.' .. C_RESET)
    return
  end
  mud.send('use ' .. m)
end

-- Bind a momentum lane to a key, moving it off the key it had. The
-- status row names the key, so rebinding through here keeps the hint
-- right.
function mod.bind_momentum(key, lane)
  local old = Icesus.momentum_keys[lane]
  if old and old ~= key then
    blight.unbind(old)
  end
  Icesus.momentum_keys[lane] = key
  blight.bind(key, function()
    mod.use_momentum(lane)
  end)
  status:update()
end

function mod.init()
  gmcp.on_ready(function()
    gmcp.register('Client.Hotkeys')
  end)
  gmcp.receive('Client.Hotkeys', function(data)
    local ok, obj = pcall(json.decode, data)
    if ok and type(obj) == 'table' then
      mod.server = obj
      mod.apply()
    end
  end)
end

return mod
