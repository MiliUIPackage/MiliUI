local _, Engine = ...

-- luacheck: ignore 542

-- Lua functions
local rawget = rawget

-- WoW API / Variables

local locale = GetLocale()
local L = {}

Engine.L = setmetatable(L, {
    __index = function(t, s) return rawget(t, s) or s end,
})

if locale == 'zhCN' then
L["Dynamic Overall Explosive Orbs"] = "动态总体爆炸物"
L["Explosive Orbs"] = "爆炸物"
L["Hit: "] = "击: "
L["Only Show Hit"] = "仅显示击"
L["Only show the hit of Explosive Orbs, without target."] = "对爆炸物仅显示击，不显示选。"
L["Show how many explosive orbs players target and hit."] = "显示玩家选中与击中不同爆炸物的次数。"
L["Target: "] = "选: "
L["Use Short Text"] = "使用短文本"
L["Use short text for Explosive Orbs."] = "为爆炸物使用短文本，仅显示数字。"

elseif locale == 'zhTW' then
L["Dynamic Overall Explosive Orbs"] = "動態整場炸藥"
L["Explosive Orbs"] = "炸藥"
L["Hit: "] = "擊: "
L["Only Show Hit"] = "僅顯示擊"
L["Only show the hit of Explosive Orbs, without target."] = "對炸藥僅顯示擊，不顯示選。"
L["Show how many explosive orbs players target and hit."] = "顯示玩家選中與擊中不同炸藥的次數。"
L["Target: "] = "選: "
L["Use Short Text"] = "使用短文本"
L["Use short text for Explosive Orbs."] = "為炸藥使用短文本，僅顯示數字。"

end
