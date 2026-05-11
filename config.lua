-- Blightmud configuration script
package.path = blight.config_dir() .. '/?.lua;' .. blight.config_dir() .. '/?/init.lua;' .. package.path

-- Bootstrap RON files into Blightmud's data dir on first run.
-- Blightmud 5.x reads servers.ron and settings.ron from
-- ~/.local/share/blightmud/data/ (XDG_DATA_HOME), but this package
-- keeps the editable copies alongside config.lua so they live in git.
-- Symlink them across so /connect <Server> just works after install,
-- without forcing every player to remember the data-dir dance.
local function bootstrap_data_dir()
  local home = os.getenv('HOME')
  local xdg_data = os.getenv('XDG_DATA_HOME')
  local data_dir = (xdg_data and (xdg_data .. '/blightmud/data'))
                or (home and (home .. '/.local/share/blightmud/data'))
  if not data_dir then return end

  os.execute('mkdir -p "' .. data_dir .. '"')

  for _, name in ipairs({ 'servers.ron', 'settings.ron' }) do
    local src = blight.config_dir() .. '/' .. name
    local dst = data_dir .. '/' .. name

    local f_src = io.open(src, 'r')
    if f_src then
      f_src:close()
      local f_dst = io.open(dst, 'r')
      if not f_dst then
        os.execute(string.format('ln -sf "%s" "%s"', src, dst))
        blight.output('[Icesus] Linked ' .. name
          .. ' into Blightmud data dir. Restart Blightmud to use it.')
      else
        f_dst:close()
      end
    end
  end
end

bootstrap_data_dir()

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
