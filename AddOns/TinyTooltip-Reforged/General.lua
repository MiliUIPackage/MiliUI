
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local DEAD = DEAD
local CopyTable = CopyTable

TinyTooltipReforgedDB = {}
TinyTooltipReforgedCharacterDB = {}

local clientVer, clientBuild, clientDate, clientToc = GetBuildInfo()
local addon = TinyTooltipReforged

local function ColorStatusBar(self, value)
    -- Disabled by user request
end

local function IsTableEmpty(table)
    return (next(table) == nil)
end

local function UpdateHealthBar(self, hp)
    -- Disabled by user request
    if (self.Hide) then self:Hide() end
    if (self.TextString) then self.TextString:Hide() end
end

LibEvent:attachEvent("VARIABLES_LOADED", function()
    --CloseButton
    if (ItemRefCloseButton and not IsAddOnLoaded("ElvUI")) then
        ItemRefCloseButton:SetSize(14, 14)
        ItemRefCloseButton:SetPoint("TOPRIGHT", -4, -4)
        ItemRefCloseButton:SetNormalTexture("Interface\\\Buttons\\UI-StopButton")
        ItemRefCloseButton:SetPushedTexture("Interface\\\Buttons\\UI-StopButton")
        ItemRefCloseButton:GetNormalTexture():SetVertexColor(0.9, 0.6, 0)
    end
    --StatusBar
    local bar = GameTooltipStatusBar
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(1, 1, 1)
    bar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.2)
    bar.TextString = bar:CreateFontString(nil, "OVERLAY")
    bar.TextString:SetPoint("CENTER")
    bar.TextString:SetFont(NumberFontNormal:GetFont(), 11, "THINOUTLINE")
    bar.capNumericDisplay = true
    bar.lockShow = 1
    if (not addon.db.general.statusbarEnabled) then GameTooltipStatusBar:Hide() end
    if (not addon.db.general.statusbarText) then GameTooltipStatusBar.TextString:Hide() end
    bar:HookScript("OnShow", function(self)
        ColorStatusBar(self)
    end)
    bar:HookScript("OnValueChanged", function(self, hp)
        UpdateHealthBar(self, hp)
        ColorStatusBar(self, hp)
    end)
    bar:HookScript("OnShow", function(self)
        if (addon.db.general.statusbarHeight == 0) then
            self:Hide()
        end        
    end)
    --Variables
    if (IsTableEmpty(TinyTooltipReforgedDB) or 
        (addon.db.general.SavedVariablesPerCharacter and IsTableEmpty(TinyTooltipReforgedCharacterDB)) ) then
        print(addon.L["|cFF00FFFF[TinyTooltipReforged]|r |cffFFE4E1Settings have been reset|r"])
        TinyTooltipReforgedDB = addon.db
        TinyTooltipReforgedCharacterDB = addon.db
    end    
    if (addon.db.general.SavedVariablesPerCharacter) then
        addon.db = TinyTooltipReforgedCharacterDB
    else
        addon.db = TinyTooltipReforgedDB
    end
    LibEvent:trigger("tooltip:variables:loaded")
    --Init
    LibEvent:trigger("TINYTOOLTIP_REFORGED_GENERAL_INIT")
    --ShadowText
    GameTooltipHeaderText:SetShadowOffset(1, -1)
    GameTooltipHeaderText:SetShadowColor(0, 0, 0, 0.9)
    GameTooltipText:SetShadowOffset(1, -1)
    GameTooltipText:SetShadowColor(0, 0, 0, 0.9)
    Tooltip_Small:SetShadowOffset(1, -1)
    Tooltip_Small:SetShadowColor(0, 0, 0, 0.9)
end)

LibEvent:attachTrigger("tooltip:cleared, tooltip:hide", function(self, tip)
    LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    LibEvent:trigger("tooltip.style.background", tip, unpack(addon.db.general.background))
    if (tip.BigFactionIcon) then tip.BigFactionIcon:Hide() end
    if (tip.SetBackdrop) then tip:SetBackdrop(nil) end
    if (tip.NineSlice) then tip.NineSlice:Hide() end
end)

LibEvent:attachTrigger("tooltip:show", function(self, tip)
    if (tip ~= GameTooltip) then return end
    if (GameTooltipStatusBar) then GameTooltipStatusBar:Hide() end
    -- LibEvent:trigger("tooltip.statusbar.position", addon.db.general.statusbarPosition, addon.db.general.statusbarOffsetX, addon.db.general.statusbarOffsetY)
end)
