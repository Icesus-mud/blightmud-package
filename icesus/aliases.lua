-- Icesus aliases.lua

-- Helper: send a command to the MUD. By default the input is gagged
-- (not echoed in the main window) so multi-step aliases stay clean.
-- Pass show_sent=true when you want the player to see what was sent.
local function msend(msg, show_sent)
  mud.send(msg, { gag = not show_sent })
end

-- Example alias kept deliberately verbose to show the pattern.
-- 'deposit' on its own deposits silver/gold/platinum; 'deposit X'
-- is forwarded verbatim and echoed.
alias.add([=[^deposit ?(.+)?]=], function(matches)
  if not matches[2] or matches[2] == '' then
    msend('deposit silver,gold,platinum')
  else
    msend('deposit ' .. matches[2], true)
  end
end)

-- 'dg' digs your grave and loots in one step.
alias.add([=[^dg$]=], function()
  msend('dig grave')
  msend('get all money')
  msend('get all treasure')
  msend('get all heart')
end)
