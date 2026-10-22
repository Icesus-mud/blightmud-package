-- Blightmud configuration script
package.path = blight.config_dir() .. '/?.lua;' .. blight.config_dir() .. '/?/init.lua;' .. package.path

-- Blightmud (3.0 and later) reads servers.ron and settings.ron from
-- this directory. Package versions before 0.2.2 also symlinked them
-- into ~/.local/share/blightmud/data/, believing Blightmud read them
-- there; it doesn't, and it warns "Can't migrate servers.ron" about
-- those links on every start. Remove them, and only links that point
-- back at this directory.
local function remove_old_data_links()
  local home = os.getenv('HOME')
  local xdg_data = os.getenv('XDG_DATA_HOME')
  local data_dir = (xdg_data and (xdg_data .. '/blightmud/data')) or (home and (home .. '/.local/share/blightmud/data'))
  if not data_dir then
    return
  end
  for _, name in ipairs({ 'servers.ron', 'settings.ron' }) do
    local link = data_dir .. '/' .. name
    local target = blight.config_dir() .. '/' .. name
    os.execute(string.format('[ -L "%s" ] && [ "$(readlink "%s")" = "%s" ] && rm -f "%s"', link, link, target, link))
  end
end

remove_old_data_links()

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
