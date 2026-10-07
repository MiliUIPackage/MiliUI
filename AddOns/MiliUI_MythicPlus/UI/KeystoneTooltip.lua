------------------------------------------------------------
-- 鑰石的滑鼠提示：加兩行「首領／小怪 生命 +X%、傷害 +Y%」
--
-- 基礎加成是官方的 C_ChallengeMode.GetPowerLevelDamageHealthMod(層數)（回百分比），
-- 再疊上這把鑰石帶的暴君／強悍：兩者相乘，不是相加。
-- 詞綴從鑰石連結讀（keystone:物品ID:mapID:層數:詞綴…），連結裡只有這個層數生效的詞綴，
-- 所以不用自己維護「第幾層開哪個詞綴」的表。背包裡的鑰石提示拿不到 keystone 連結時，
-- 去背包掃那顆鑰石的連結。
--
-- ⚠ 每季要看一眼：暴君／強悍的加成比例是社群知識，暴雪沒有 API（數字同 AdvancedMythicTracker）。
------------------------------------------------------------
local _, ns = ...

ns.KeystoneTooltip = {}
local KT = ns.KeystoneTooltip

local L = ns.L
local Sec = ns.Secret

local TYRANNICAL_ID, FORTIFIED_ID = 9, 10
local TYRANNICAL_BOSS_HEALTH, TYRANNICAL_BOSS_DAMAGE   = 0.25, 0.15
local FORTIFIED_TRASH_HEALTH, FORTIFIED_TRASH_DAMAGE   = 0.20, 0.20

local function Enabled()
    local c = ns.db and ns.db.keystone
    return c and c.tooltipScaling and true or false
end

-- base 是百分比，extra 是比例；回整數百分比
local function Combine(base, extra)
    return math.floor(((1 + base / 100) * (1 + extra) - 1) * 100 + 0.5)
end

-- "keystone:物品ID:mapID:層數:詞綴…" → 層數, { [詞綴ID] = true }
local function ParseLink(link)
    link = Sec.PlainText(link)
    local body = link and link:match("keystone:([%d:]+)")
    if not body then return end
    local fields = { strsplit(":", body) }
    local level = tonumber(fields[3])
    if not level or level <= 0 then return end
    local affixes = {}
    for i = 4, #fields do
        local id = tonumber(fields[i])
        if id and id > 0 then affixes[id] = true end
    end
    return level, affixes
end

local function BagKeystoneLink()
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and C_Item.IsItemKeystoneByID(id) then
                return C_Container.GetContainerItemLink(bag, slot)
            end
        end
    end
end

local function OnItemTooltip(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    if not Enabled() then return end
    if not (C_ChallengeMode and C_ChallengeMode.GetPowerLevelDamageHealthMod) then return end

    local id = data and Sec.PlainNumber(data.id)
    if not (id and C_Item.IsItemKeystoneByID(id)) then return end

    local level, affixes = ParseLink(data.hyperlink)
    if not level then
        local _, link = tt:GetItem()
        level, affixes = ParseLink(link)
    end
    if not level then level, affixes = ParseLink(BagKeystoneLink()) end
    if not level then return end

    local damage, health = C_ChallengeMode.GetPowerLevelDamageHealthMod(level)
    damage, health = Sec.PlainNumber(damage), Sec.PlainNumber(health)
    if not (damage and health) then return end

    local tyr, fort = affixes[TYRANNICAL_ID], affixes[FORTIFIED_ID]
    tt:AddLine(" ")
    tt:AddLine(L["Bosses: +%d%% health, +%d%% damage"]:format(
        Combine(health, tyr and TYRANNICAL_BOSS_HEALTH or 0),
        Combine(damage, tyr and TYRANNICAL_BOSS_DAMAGE or 0)), 1, 1, 1)
    tt:AddLine(L["Trash: +%d%% health, +%d%% damage"]:format(
        Combine(health, fort and FORTIFIED_TRASH_HEALTH or 0),
        Combine(damage, fort and FORTIFIED_TRASH_DAMAGE or 0)), 1, 1, 1)
end

function KT.Init()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            ns.Guard(OnItemTooltip, tt, data)
        end)
    end
end
