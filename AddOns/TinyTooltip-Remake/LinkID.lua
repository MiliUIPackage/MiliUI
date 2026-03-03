local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local L = addon.L or {}

local function ParseHyperLink(link)
    local name, value = string.match(link or "", "|?H(%a+):(%d+):")
    if (name and value) then
        return name:gsub("^([a-z])", strupper), value
    end
end

local function ShowId(tooltip, name, value, noBlankLine)
    if (not name or not value) then return end
    if (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() or addon.db.general.alwaysShowIdInfo) then
        local line = addon:FindLine(tooltip, name)
        if (not line) then
            if (not noBlankLine) then tooltip:AddLine(" ") end
            tooltip:AddLine(format("%s: |cffffffff%s|r", name, value), 0, 1, 0.8)
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
    ShowId(tooltip, L["id.spell"] or "Spell ID", spellId)
    local iconId = GetSpellIconId(spellId)
    if (iconId) then
        ShowId(tooltip, L["id.icon"] or "Icon ID", iconId, true)
    end
end

local function ShowItemInfo(tooltip, linkOrId)
    if (not linkOrId) then return end
    local _, itemId = ParseHyperLink(linkOrId)
    ShowId(tooltip, L["id.item"] or "Item ID", itemId)
    local iconId = GetItemIconId(linkOrId)
    if (iconId) then
        ShowId(tooltip, L["id.icon"] or "Icon ID", iconId, true)
    end
    local maxStack = GetItemMaxStack(linkOrId)
    if (maxStack) then
        ShowId(tooltip, L["id.maxStack"] or "Max Stack Count", maxStack, true)
    end
end

local function ShowLinkIdInfo(tooltip, link)
    ShowItemInfo(tooltip, link or select(2,tooltip:GetItem()))
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
        if (self.questID) then ShowId(GameTooltip, "Quest", self.questID) end
    end)
end

-- Achievement UI
local function ShowAchievementId(self)
    if ((IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() or addon.db.general.alwaysShowIdInfo) and self.id) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -32)
        GameTooltip:SetText("|cffffdd22Achievement:|r " .. self.id, 0, 1, 0.8)
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
