-- Icesus bindings.lua

-- Helper function to bind keys to UI events
local function ui_bind(cmd, event)
  blight.bind(cmd, function()
    blight.ui(event)
  end)
end

-- UI related binds
-- By default home/end are split screen scrolling keys, this configures them
-- to more traditional move cursor to start/end of line
ui_bind('home', 'step_to_start')
ui_bind('end', 'step_to_end')
-- Mouse scroll events
-- Blightmud has mouse_enabled setting (see /help settings)
-- but causes Blightmud to capture all mouse events breaking things like
-- selection.. so easier to just bind the mouse wheel up/down events
ui_bind('\u{1b}oa', 'scroll_up')
ui_bind('\u{1b}ob', 'scroll_down')

-- Momentum: alt-m uses whatever momentum is lit (strike, chase the
-- rich vein, ...), alt-s the special one. The status row shows which
-- key does what. To move one, call this again from local.lua, e.g.
--   Icesus.bind_momentum('f12', 1)
-- (and set Icesus.hotkeys.use_server = false if it is an F-key the
-- server's hotkeys would otherwise take).
Icesus.bind_momentum('alt-m', 1)
Icesus.bind_momentum('alt-s', 2)

-- F1-F12 follow the hotkeys saved on your character (see keys.lua).
