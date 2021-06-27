WeekKeys = LibStub("AceAddon-3.0"):NewAddon("WeekKeys", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")

WeekKeys.inits = {} -- function table with init functions

function WeekKeys.AddInit(func)
    WeekKeys.inits[#WeekKeys.inits + 1] = func
end
