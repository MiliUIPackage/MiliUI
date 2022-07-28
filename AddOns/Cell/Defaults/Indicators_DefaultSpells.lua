local _, Cell = ...
local L = Cell.L
local I = Cell.iFuncs
local F = Cell.funcs

local debuffBlacklist = {
    8326, -- 鬼魂
    160029, -- 正在复活
    57723, -- 筋疲力尽
    57724, -- 心满意足
    80354, -- 时空错位
    264689, -- 疲倦
    206151, -- 挑战者的负担
    195776, -- 月羽疫病
    352562, -- 起伏机动
    356419, -- 审判灵魂
}

function I:GetDefaultDebuffBlacklist()
    -- local temp = {}
    -- for i, id in pairs(debuffBlacklist) do
    --     temp[i] = GetSpellInfo(id)
    -- end
    -- return temp
    return debuffBlacklist
end

-------------------------------------------------
-- aoeHealings
-------------------------------------------------
local aoeHealings = {
    -- druid
    740, -- 宁静
    145205, -- 百花齐放

    -- monk
    115098, -- 真气波
    123986, -- 真气爆裂
    115310, -- 还魂术
    322118, -- 青龙下凡 (SUMMON)

    -- paladin
    85222, -- 黎明之光
    119952, -- 弧形圣光
    114165, -- 神圣棱镜


    -- priest
    120517, -- 光晕
    34861, -- 圣言术：灵
    596, -- 治疗祷言
    64843, -- 神圣赞美诗
    110744, -- 神圣之星
    204883, -- 治疗之环

    -- shaman
    1064, -- 治疗链
    73920, -- 治疗之雨
    114942, -- 治疗之潮
}

do
    local temp = {}
    for _, id in pairs(aoeHealings) do
        temp[GetSpellInfo(id)] = true
    end
    aoeHealings = temp
end

function I:IsAoEHealing(name)
    if not name then return false end
    return aoeHealings[name]
end

local summonDuration = {
    -- monk
    [322118] = 25, -- 青龙下凡
}

do
    local temp = {}
    for id, duration in pairs(summonDuration) do
        temp[GetSpellInfo(id)] = duration
    end
    summonDuration = temp
end

function I:GetSummonDuration(spellName)
    return summonDuration[spellName]
end

-------------------------------------------------
-- externalCooldowns
-------------------------------------------------
local externalCooldowns = {
    -- death knight
    51052, -- 反魔法领域

    -- demon hunter
    196718, -- 黑暗

    -- druid
    102342, -- 铁木树皮

    -- monk
    116849, -- 作茧缚命

    -- paladin
    1022, -- 保护祝福
    6940, -- 牺牲祝福
    204018, -- 破咒祝福
    31821, -- 光环掌握

    -- priest
    33206, -- 痛苦压制
    47788, -- 守护之魂
    62618, -- 真言术：障

    -- shaman
    98008, -- 灵魂链接图腾

    -- warrior
    97462, -- 集结呐喊
    3411, -- 援护
}

do
    local temp = {}
    for _, id in pairs(externalCooldowns) do
        temp[GetSpellInfo(id)] = true
    end
    externalCooldowns = temp
end

local UnitIsUnit = UnitIsUnit
local bos = GetSpellInfo(6940) -- 牺牲祝福
function I:IsExternalCooldown(name, source, target)
    if name == bos then
        if source and target then
            -- NOTE: hide bos on caster
            return not UnitIsUnit(source, target)
        else
            return true
        end
    else
        return externalCooldowns[name]
    end
end

-------------------------------------------------
-- defensiveCooldowns
-------------------------------------------------
local defensiveCooldowns = {
    -- death knight
    48707, -- 反魔法护罩
    48792, -- 冰封之韧
    49028, -- 符文刃舞
    55233, -- 吸血鬼之血

    -- demon hunter
    196555, -- 虚空行走
    198589, -- 疾影
    187827, -- 恶魔变形

    -- druid
    22812, -- 树皮术
    -- 22842, -- REVIEW:狂暴回复
    61336, -- 生存本能

    -- hunter
    186265, -- 灵龟守护
    264735, -- 优胜劣汰

    -- mage
    45438, -- 寒冰屏障

    -- monk
    115176, -- 禅悟冥想
    115203, -- 壮胆酒
    122278, -- 躯不坏
    122783, -- 散魔功

    -- paladin
    498, -- 圣佑术
    642, -- 圣盾术
    31850, -- 炽热防御者
    212641, -- 远古列王守卫

    -- priest
    47585, -- 消散
    19236, -- 绝望祷言
    586, -- 渐隐术

    -- rogue
    1966, -- 佯攻
    5277, -- 闪避
    31224, -- 暗影斗篷

    -- shaman
    108271, -- 星界转移

    -- warlock
    104773, -- 不灭决心

    -- warrior
    871, -- 盾墙
    12975, -- 破釜沉舟
    23920, -- 法术反射
    118038, -- 剑在人在
    184364, -- 狂怒回复
}

do
    local temp = {}
    for _, id in pairs(defensiveCooldowns) do
        temp[GetSpellInfo(id)] = true
    end
    defensiveCooldowns = temp
end

function I:IsDefensiveCooldown(name)
    return defensiveCooldowns[name]
end

-------------------------------------------------
-- tankActiveMitigation
-------------------------------------------------
local tankActiveMitigations = {
    -- death knight
    77535, -- 鲜血护盾
    195181, -- 白骨之盾

    -- demon hunter
    203720, -- 恶魔尖刺

    -- druid
    192081, -- 铁鬃

    -- monk
    215479, -- 铁骨酒

    -- paladin
    132403, -- 正义盾击

    -- warrior
    2565, -- 盾牌格挡
}

local tankActiveMitigationNames = {
    -- death knight
    F:GetClassColorStr("DEATHKNIGHT")..GetSpellInfo(77535).."|r", -- 鲜血护盾
    F:GetClassColorStr("DEATHKNIGHT")..GetSpellInfo(195181).."|r", -- 白骨之盾

    -- demon hunter
    F:GetClassColorStr("DEMONHUNTER")..GetSpellInfo(203720).."|r", -- 恶魔尖刺

    -- druid
    F:GetClassColorStr("DRUID")..GetSpellInfo(192081).."|r", -- 铁鬃

    -- monk
    F:GetClassColorStr("MONK")..GetSpellInfo(215479).."|r", -- 铁骨酒

    -- paladin
    F:GetClassColorStr("PALADIN")..GetSpellInfo(132403).."|r", -- 正义盾击

    -- warrior
    F:GetClassColorStr("WARRIOR")..GetSpellInfo(2565).."|r", -- 盾牌格挡
}

do
    local temp = {}
    for _, id in pairs(tankActiveMitigations) do
        temp[GetSpellInfo(id)] = true
    end
    tankActiveMitigations = temp
end

function I:IsTankActiveMitigation(name)
    return tankActiveMitigations[name]
end

function I:GetTankActiveMitigationString()
    return table.concat(tankActiveMitigationNames, ", ").."."
end

-------------------------------------------------
-- dispels
-------------------------------------------------
local dispellable = {
    -- DRUID ----------------
        -- 102 - Balance
        [102] = {["Curse"] = true, ["Poison"] = true},
        -- 103 - Feral
        [103] = {["Curse"] = true, ["Poison"] = true},
        -- 104 - Guardian
        [104] = {["Curse"] = true, ["Poison"] = true},
        -- Restoration
        [105] = {["Curse"] = true, ["Magic"] = true, ["Poison"] = true},
        -------------------------
        
        -- MAGE -----------------
        -- 62 - Arcane
        [62] = {["Curse"] = true},
        -- 63 - Fire
        [63] = {["Curse"] = true},
        -- 64 - Frost
        [64] = {["Curse"] = true},
        -------------------------
        
        -- MONK -----------------
        -- 268 - Brewmaster
        [268] = {["Disease"] = true, ["Poison"] = true},
        -- 269 - Windwalker
        [269] = {["Disease"] = true, ["Poison"] = true},
        -- 270 - Mistweaver
        [270] = {["Disease"] = true, ["Magic"] = true, ["Poison"] = true},
    -------------------------

    -- PALADIN --------------
        -- 65 - Holy
        [65] = {["Disease"] = true, ["Magic"] = true, ["Poison"] = true},
        -- 66 - Protection
        [66] = {["Disease"] = true, ["Poison"] = true},
        -- 70 - Retribution
        [70] = {["Disease"] = true, ["Poison"] = true},
    -------------------------
    
    -- PRIEST ---------------
        -- 256 - Discipline
        [256] = {["Disease"] = true, ["Magic"] = true},
        -- 257 - Holy
        [257] = {["Disease"] = true, ["Magic"] = true},
        -- 258 - Shadow
        [258] = {["Disease"] = true, ["Magic"] = true},
    -------------------------

    -- SHAMAN ---------------
        -- 262 - Elemental
        [262] = {["Curse"] = true},
        -- 263 - Enhancement
        [263] = {["Curse"] = true},
        -- 264 - Restoration
        [264] = {["Curse"] = true, ["Magic"] = true},
    -------------------------

    -- WARLOCK --------------
        -- 265 - Affliction
        [265] = {["Magic"] = true},
        -- 266 - Demonology
        [266] = {["Magic"] = true},
        -- 267 - Destruction
        [267] = {["Magic"] = true},
    -------------------------
}

function I:CanDispel(dispelType)
    if dispellable[Cell.vars.playerSpecID] then
        return dispellable[Cell.vars.playerSpecID][dispelType]
    else
        return
    end
end

-------------------------------------------------
-- drinking
-------------------------------------------------
local drinks = {
    170906, -- 食物和饮水
    167152, -- 进食饮水
    430, -- 喝水
    43182, -- 饮水
    172786, -- 饮料
    308433, -- 食物和饮料
}

do
    local temp = {}
    for _, id in pairs(drinks) do
        temp[GetSpellInfo(id)] = true
    end
    drinks = temp
end

function I:IsDrinking(name)
    return drinks[name]
end

-------------------------------------------------
-- healer 
-------------------------------------------------
local spells =  {
    -- druid
    774, -- 回春术
    155777, -- 回春术（萌芽）
    8936, -- 愈合
    33763, -- 生命绽放
    188550, -- 生命绽放
    48438, -- 野性成长
    102351, -- 塞纳里奥结界
    102352, -- 塞纳里奥结界
    -- monk
    119611, -- 复苏之雾
    124682, -- 氤氲之雾
    191840, -- 精华之泉
    -- paladin
    53563, -- 圣光道标
    156910, -- 信仰道标
    223306, -- 赋予信仰
    325966, -- 圣光闪烁
    200025, -- 美德道标
    -- priest
    139, -- 恢复
    41635, -- 愈合祷言
    17, -- 真言术：盾
    194384, -- 救赎
    -- shaman
    974, -- 大地之盾
    61295, -- 激流
}

function F:FirstRun()
    local icons = "\n\n"
    for i, id in pairs(spells) do
        local icon = select(3, GetSpellInfo(id))
        icons = icons .. "|T"..icon..":0|t"
        if i % 11 == 0 then
            icons = icons .. "\n"    
        end
    end

    local popup = Cell:CreateConfirmPopup(Cell.frames.anchorFrame, 200, L["Would you like Cell to create a \"Healers\" indicator (icons)?"]..icons, function(self)
        local currentLayoutTable = Cell.vars.currentLayoutTable

        local last = #currentLayoutTable["indicators"]
        if currentLayoutTable["indicators"][last]["type"] == "built-in" then
            indicatorName = "indicator"..(last+1)
        else
            indicatorName = "indicator"..(tonumber(strmatch(currentLayoutTable["indicators"][last]["indicatorName"], "%d+"))+1)
        end
        
        tinsert(currentLayoutTable["indicators"], {
            ["name"] = "Healers",
            ["indicatorName"] = indicatorName,
            ["type"] = "icons",
            ["enabled"] = true,
            ["position"] = {"TOPRIGHT", "TOPRIGHT", 0, 3},
            ["frameLevel"] = 5,
            ["size"] = {13, 13},
            ["num"] = 5,
            ["orientation"] = "right-to-left",
            ["font"] = {"Cell ".._G.DEFAULT, 11, "Outline", 2, 1},
            ["showDuration"] = false,
            ["auraType"] = "buff",
            ["castByMe"] = true,
            ["auras"] = spells,
        })
        Cell:Fire("UpdateIndicators", Cell.vars.currentLayout, indicatorName, "create", currentLayoutTable["indicators"][last+1])
        CellDB["firstRun"] = false
    end, function()
        CellDB["firstRun"] = false
    end)
    popup:SetPoint("TOPLEFT")
    popup:Show()
end