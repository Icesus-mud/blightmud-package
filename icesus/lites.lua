-- Icesus lites.lua

-- Helper function to define lite triggers
local function lite(pattern, colour)
  trigger.add(pattern, {}, function(matches, line)
    local raw = line:line()
    line:replace(colour .. raw .. C_RESET)
  end)
end

lite([=[^.+ looks better as (?:his|its|her) head stops spinning\.$]=], C_WARN)
