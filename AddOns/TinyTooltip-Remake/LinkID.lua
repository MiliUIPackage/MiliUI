local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local L = addon.L or {}

local function ParseHyperLink(link)
    local name, value = string.match(link or "", "|?H(%a+):(%d+):")
    if (name and value) then
        return name:gsub("^([a-z])", strupper), value
    end
end

local function ShowId(tooltip, name, value, noBlankLine, forceShow)
    if (not name or not value) then return end
    if (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if (forceShow or IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) then
        local line = addon:FindLine(tooltip, name)
        if (not line) then
            if (not noBlankLine) then tooltip:AddLine(" ") end
            tooltip:AddLine(format("%s: |cffffffff%s|r", name, value), 1, 0.82, 0)
            tooltip:Show()
        end
        LibEvent:trigger("tooltip.linkid", tooltip, name, value, noBlankLine)
    end
end

local function GetSpellIconId(spellId)
    if (not spellId or not C_Spell or not C_Spell.GetSpellTexture) then return end
    local icon = C_Spell.GetSpellTexture(spellId)
    if (type(icon) == "number") then
        return icon
    end
end

local function GetItemIconId(linkOrId)
    if (not linkOrId) then return end
    local _, _, _, _, _, _, _, maxStack, _, icon = GetItemInfo(linkOrId)
    if (type(icon) == "number") then
        return icon
    end
end

local function GetItemMaxStack(linkOrId)
    if (not linkOrId) then return end
    local _, _, _, _, _, _, _, maxStack = GetItemInfo(linkOrId)
    if (type(maxStack) == "number" and maxStack > 0) then
        return maxStack
    end
end

local function ShowSpellInfo(tooltip, spellId)
    if (not spellId) then return end
    local isModifierDown = IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
    local showAllByModifier = addon.db.spell.modifierShowAll
    local showSpellId = addon.db.spell.showSpellId ~= false
    local showSpellIconId = addon.db.spell.showSpellIconId ~= false
    if (isModifierDown and showAllByModifier) then
        showSpellId = true
        showSpellIconId = true
    end
    if (showSpellId) then
        ShowId(tooltip, L["id.spell"], spellId, nil, true)
    end
    local iconId = GetSpellIconId(spellId)
    if (iconId and showSpellIconId) then
        ShowId(tooltip, L["id.icon"], iconId, true, true)
    end
end

local function ShowItemInfo(tooltip, linkOrId)
    if (not linkOrId) then return end
    local isModifierDown = IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
    local itemSettings = addon.db.item
    local showAllByModifier = itemSettings.modifierShowAll
    local showItemId = itemSettings.showItemId ~= false
    local showItemBonusId = itemSettings.showItemBonusId ~= false
    local showItemEnhancementId = itemSettings.showItemEnhancementId ~= false
    local showItemGemId = itemSettings.showItemGemId ~= false
    local showItemMaxStack = itemSettings.showItemMaxStack ~= false
    local showItemIconId = itemSettings.showItemIconId ~= false
    if (isModifierDown and showAllByModifier) then
        showItemId = true
        showItemBonusId = true
        showItemEnhancementId = true
        showItemGemId = true
        showItemMaxStack = true
        showItemIconId = true
    end
    local _, itemId = ParseHyperLink(linkOrId)
    local isEquippable = IsEquippableItem and IsEquippableItem(linkOrId)
    local itemEnhancementId = L["id.na"]
    local itemBonusId = L["id.na"]
    local itemGemId = L["id.na"]
    if (type(linkOrId) == "string") then
        local itemString = linkOrId:match("|?Hitem:([^|]+)") or linkOrId:match("^item:([^|]+)")
        if (itemString and itemString ~= "") then
            local segments = {}
            for value in (itemString .. ":"):gmatch("(.-):") do
                tinsert(segments, value)
            end
            local enhancementId = segments[2]
            if (enhancementId and enhancementId ~= "" and enhancementId ~= "0") then
                itemEnhancementId = enhancementId
            end
            local gemIds = {}
            for i = 3, 6 do
                local gemId = segments[i]
                if (gemId and gemId ~= "" and gemId ~= "0") then
                    tinsert(gemIds, gemId)
                end
            end
            if (#gemIds > 0) then
                itemGemId = table.concat(gemIds, ", ")
            end
            local bonusCount = tonumber(segments[14] or "")
            if (bonusCount and bonusCount > 0) then
                local bonusIds = {}
                for i = 1, bonusCount do
                    local bonusId = segments[14 + i]
                    if (bonusId and bonusId ~= "") then
                        tinsert(bonusIds, bonusId)
                    end
                end
                if (#bonusIds > 0) then
                    local bonusLabel = L["id.bonus"]
                    local bonusIndent = string.rep(" ", string.len(bonusLabel) + 2)
                    local formattedBonus = {}
                    for i, bonusId in ipairs(bonusIds) do
                        tinsert(formattedBonus, bonusId)
                        if (i < #bonusIds) then
                            if (i % 4 == 0) then
                                tinsert(formattedBonus, ",\n" .. bonusIndent)
                            else
                                tinsert(formattedBonus, ", ")
                            end
                        end
                    end
                    itemBonusId = table.concat(formattedBonus)
                end
            end
        end
    end
    if (showItemId) then
        local hasExpansionLine = addon:FindLine(tooltip, L["id.expansion"])
        ShowId(tooltip, L["id.item"], itemId, hasExpansionLine and true or false, true)
    end
    if (showItemBonusId and isEquippable) then
        ShowId(tooltip, L["id.bonus"], itemBonusId, true, true)
    end
    if (showItemEnhancementId and isEquippable) then
        ShowId(tooltip, L["id.enhancement"], itemEnhancementId, true, true)
    end
    if (showItemGemId and isEquippable) then
        ShowId(tooltip, L["id.gem"], itemGemId, true, true)
    end
    local iconId = GetItemIconId(linkOrId)
    if (iconId and showItemIconId) then
        ShowId(tooltip, L["id.icon"], iconId, true, true)
    end
    local maxStack = GetItemMaxStack(linkOrId)
    if (maxStack and showItemMaxStack) then
        ShowId(tooltip, L["id.maxStack"], maxStack, true, true)
    end
end

local function ShowLinkIdInfo(tooltip, link)
    local itemLink = link
    if (not itemLink and tooltip and tooltip.GetItem) then
        _, _, itemLink = pcall(tooltip.GetItem, tooltip)
    end
    ShowItemInfo(tooltip, itemLink)
end

local function GetSpellIdFromTooltip(tip)
    if (not tip or not tip.GetSpell) then return end
    local ok, _, spellId = pcall(tip.GetSpell, tip)
    if (ok and type(spellId) == "number") then
        return spellId
    end
end

local function GetAuraSpellId(unit, index, filter)
    if (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        if (aura and aura.spellId) then
            return aura.spellId
        end
    end
end

local function GetAuraSpellIdByInstance(unit, auraInstanceID)
    if (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then
        local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
        if (aura and aura.spellId) then
            return aura.spellId
        end
    end
end



LibEvent:attachTrigger("tooltip:item", function(self, tip, link)
    ShowLinkIdInfo(tip, link)
end)

LibEvent:attachTrigger("tooltip:spell", function(self, tip, spellId)
    ShowSpellInfo(tip, spellId or GetSpellIdFromTooltip(tip))
end)

LibEvent:attachTrigger("tooltip:aura", function(self, tip, args)
    local spellId = (args and args[2] and args[2].intVal) or GetSpellIdFromTooltip(tip)
    ShowSpellInfo(tip, spellId)
end)

local function HookAuraSetter(fnName, resolver)
    if (GameTooltip and GameTooltip[fnName]) then
        hooksecurefunc(GameTooltip, fnName, function(tip, ...)
            local spellId = resolver(...)
            ShowSpellInfo(tip, spellId)
        end)
    end
end

HookAuraSetter("SetUnitAura", function(unit, index, filter)
    return GetAuraSpellId(unit, index, filter)
end)

HookAuraSetter("SetUnitBuff", function(unit, index, filter)
    return GetAuraSpellId(unit, index, filter)
end)

HookAuraSetter("SetUnitDebuff", function(unit, index, filter)
    return GetAuraSpellId(unit, index, filter)
end)

HookAuraSetter("SetUnitAuraByAuraInstanceID", function(unit, auraInstanceID)
    return GetAuraSpellIdByInstance(unit, auraInstanceID)
end)

HookAuraSetter("SetUnitBuffByAuraInstanceID", function(unit, auraInstanceID)
    return GetAuraSpellIdByInstance(unit, auraInstanceID)
end)

HookAuraSetter("SetUnitDebuffByAuraInstanceID", function(unit, auraInstanceID)
    return GetAuraSpellIdByInstance(unit, auraInstanceID)
end)

-- Quest
if (QuestMapLogTitleButton_OnEnter) then
    hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(self)
        if (self.questID and addon.db.quest.showQuestId ~= false) then
            ShowId(GameTooltip, L["id.quest"], self.questID, nil, true)
        end
    end)
end

-- Achievement UI
local function ShowAchievementId(self)
    if ((IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) and self.id) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -32)
        GameTooltip:SetText(format("|cffffdd22%s:|r %s", L["Achievement"], self.id), 0, 1, 0.8)
        GameTooltip:Show()
    end
end

if (HybridScrollFrame_CreateButtons) then
    hooksecurefunc("HybridScrollFrame_CreateButtons", function(self, buttonTemplate)
        if (buttonTemplate == "StatTemplate") then
            for _, button in pairs(self.buttons) do
                button:HookScript("OnEnter", ShowAchievementId)
            end
        elseif (buttonTemplate == "AchievementTemplate") then
            for _, button in pairs(self.buttons) do
                button:HookScript("OnEnter", ShowAchievementId)
                button:HookScript("OnLeave", GameTooltip_Hide)
            end
        end
    end)
end
