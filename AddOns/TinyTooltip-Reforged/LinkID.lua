local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local clientVer, clientBuild, clientDate, clientToc = GetBuildInfo()
local addon = TinyTooltipReforged
local L = addon.L or {}

local function ParseHyperLink(link)
    local name, value = string.match(link or "", "|?H(%a+):(%d+):")
    if (name and value) then
        return name:gsub("^([a-z])", strupper), value
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

local function ShowId(tooltip, name, value, noBlankLine)
    if (not name or not value) then return end
    if (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local name = format("%s%s", name, " ID")
    if (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() or addon.db.general.alwaysShowIdInfo) then
        local line = addon:FindLine(tooltip, name)
        local idLine = format("%s: |cffffffff%s|r", name, value)
        if (not line) then
            if (not noBlankLine) then tooltip:AddLine(" ") end
            tooltip:AddLine(format(idLine, name, value), 0, 1, 0.8)
            tooltip:Show()
        else
            line:SetText(idLine)
        end
        LibEvent:trigger("tooltip.linkid", tooltip, name, value, noBlankLine) 
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

local function ShowLinkIdInfo(tooltip, data) 
    if (data.type == Enum.TooltipDataType.Item) then
        local itemName, itemLink, itemID = TooltipUtil.GetDisplayedItem(tooltip)
        ShowId(tooltip, ParseHyperLink(itemLink))
        -- icon ID
        ShowId(tooltip, L["id.icon"] or "Icon ID", GetItemIconId(itemID), 1)
    end
end


-- Item
hooksecurefunc(GameTooltip, "SetHyperlink", ShowLinkIdInfo)
hooksecurefunc(ItemRefTooltip, "SetHyperlink", ShowLinkIdInfo)
hooksecurefunc("SetItemRef", function(link) ShowLinkIdInfo(ItemRefTooltip, link) end)
if (clientToc>=100002) then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ShowLinkIdInfo)
else
    GameTooltip:HookScript("OnTooltipSetItem", ShowLinkIdInfo)
    ItemRefTooltip:HookScript("OnTooltipSetItem", ShowLinkIdInfo)
    ShoppingTooltip1:HookScript("OnTooltipSetItem", ShowLinkIdInfo)
    ShoppingTooltip2:HookScript("OnTooltipSetItem", ShowLinkIdInfo)
    ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", ShowLinkIdInfo)
    ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", ShowLinkIdInfo)
end

-- Spell
if (clientToc>=100002) then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(self)
       if not pcall(function() ShowSpellInfo(self, (select(2,self:GetSpell()))) end) then
         return 
       end
    end)
else
    GameTooltip:HookScript("OnTooltipSetSpell", function(self) ShowId(self, "Spell", (select(2,self:GetSpell()))) end)
end
--hooksecurefunc(GameTooltip, "SetUnitAura", function(self, ...) ShowId(self, "Spell", (select(10,C_UnitAuras.UnitAura(...)))) end)
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...) ShowId(self, "Spell", (select(10,C_UnitAuras.UnitBuff(...)))) end)
hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, ...) ShowId(self, "Spell", (select(10,C_UnitAuras.UnitDebuff(...)))) end)
if (GameTooltip.SetArtifactPowerByID) then
    hooksecurefunc(GameTooltip, "SetArtifactPowerByID", function(self, powerID)
        ShowId(self, "Power", powerID)
        ShowId(self, "Spell", C_ArtifactUI.GetPowerInfo(powerID).spellID, 1)
    end)
end

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
