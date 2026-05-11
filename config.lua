-- Blightmud configuration script
package.path = blight.config_dir() .. '/?.lua;' .. blight.config_dir() .. '/?/init.lua;' .. package.path

local session = {
  host = store.session_read('cur_host'),
  port = tonumber(store.session_read('cur_port') or '0'),
}

-- Load an optional local override file (e.g. credentials, personal
-- aliases) if the player has dropped one in. Sibling to this file,
-- gitignored so it never reaches the public package repo.
local function load_local_overrides()
  local path = blight.config_dir() .. '/local.lua'
  local f = io.open(path, 'r')
  if f then
    f:close()
    script.load(path)
  end
end

local function load_profile()
  if session.host == 'icesus.org' then
    script.load(blight.config_dir() .. '/icesus/init.lua')
  end
  load_local_overrides()
end

local function reload_all()
  local host = session.host
  local port = session.port

  script.reset()
  timer.clear()

  -- restore state after reset
  session.host = host
  session.port = port

  script.load(blight.config_dir() .. '/config.lua')
end

local function disconnect()
  session.host = nil
  session.port = nil

  store.session_write('cur_host', '')
  store.session_write('cur_port', '')
end

mud.on_connect(function(host, port)
  session.host = host
  session.port = port

  store.session_write('cur_host', host)
  store.session_write('cur_port', tostring(port))

  load_profile()
end)

alias.add('^/reload$', reload_all)

-- auto-load previous profile on startup
if session.host then
  load_profile()
end
