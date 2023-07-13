local _, Engine = ...

-- Lua functions
local rawget = rawget

-- WoW API / Variables

local locale = GetLocale()
local L = {}

Engine.L = setmetatable(L, {
    __index = function(t, s) return rawget(t, s) or s end,
})

if locale == 'zhCN' then
L["Avoidable Damage Taken"] = "可避免的伤害"
L["Avoidable Abilities Taken"] = "可避免的法术"
L["Show how much avoidable damage was taken."] = "显示承受了多少可避免的伤害。"
L["Show how many avoidable abilities hit players."] = "显示被击中了多少可避免的法术。"

elseif locale == 'zhTW' then
L["Avoidable Abilities Taken"] = "可避免的法術"
L["Avoidable Damage Taken"] = "可避免的傷害"
L["Show how many avoidable abilities hit players."] = "顯示被擊中了多少可避免的法術。"
L["Show how much avoidable damage was taken."] = "顯示承受了多少可避免的傷害。"

end
