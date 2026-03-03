
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local DEAD = DEAD
local CopyTable = CopyTable
local GetMouseFocus = GetMouseFocus or GetMouseFoci

local addon = TinyTooltip

TinyTooltipRemakeDB = {}
TinyTooltipRemakeCharacterDB = {}
addon.defaults = CopyTable(addon.db)

local function GetStatusbarUnit()
    local unit = "mouseover"
    local focus = GetMouseFocus()
    if (focus and focus.unit) then
        unit = focus.unit
    end
    return unit
end

local function ColorStatusBar(self, value)
    if (addon.db.general.statusbarColor == "auto") then
        local unit = GetStatusbarUnit()
        local r, g, b
        if (UnitIsPlayer(unit)) then
            r, g, b = GetClassColor(select(2,UnitClass(unit)))
        else
            r, g, b = GameTooltip_UnitColor(unit)
            if (g == 0.6) then g = 0.9 end
            if (r==1 and g==1 and b==1) then r, g, b = 0, 0.9, 0.1 end
        end
        self:SetStatusBarColor(r, g, b)
    elseif (value and addon.db.general.statusbarColor == "smooth") then
        HealthBar_OnValueChanged(self, value, true)
    end
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
    bar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
    bar.TextString = bar:CreateFontString(nil, "OVERLAY")
    bar.TextString:SetPoint("CENTER")
    bar.TextString:SetFont(NumberFontNormal:GetFont(), 11, "THINOUTLINE")
    bar.capNumericDisplay = true
    bar.lockShow = 1
    bar:HookScript("OnShow", function(self)
        ColorStatusBar(self)
    end)
    bar:HookScript("OnValueChanged", function(self, hp)
        local unit = GetStatusbarUnit()
        local showText = addon.db.general.statusbarText
        local showPercent = addon.db.general.statusbarPercent
        local shouldShow = showText or showPercent
        if (UnitIsDeadOrGhost(unit)) then
            if (self.TextString) then
                if (showText) then
                    local max = UnitHealthMax(unit) or 1
                    self.TextString:SetFormattedText("|cff999999%s|r |cffffcc33<%s>|r", AbbreviateLargeNumbers(max), DEAD)
                elseif (showPercent) then
                    self.TextString:SetFormattedText("|cffffcc33<%s>|r", DEAD)
                else
                    self.TextString:SetText("")
                end
            end
        elseif (shouldShow and not self.forceHideText) then
            local cur = UnitHealth(unit) or 1
            local max = UnitHealthMax(unit) or 1
            if (self.TextString) then
                if (showText and showPercent) then
                    local percent
                    if (UnitHealthPercent) then
                        local ok, p = pcall(function()
                            return UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100)
                        end)
                        percent = (ok and type(p) == "number") and p or nil
                    end
                    if (percent) then
                        self.TextString:SetText(AbbreviateLargeNumbers(cur) .. " / " .. AbbreviateLargeNumbers(max) .. " (" .. string.format("%.0f%%", percent) .. ")")
                    else
                        self.TextString:SetText(AbbreviateLargeNumbers(cur) .. " / " .. AbbreviateLargeNumbers(max))
                    end
                elseif (showText) then
                    self.TextString:SetText(AbbreviateLargeNumbers(cur) .. " / " .. AbbreviateLargeNumbers(max))
                else
                    local percent
                    if (UnitHealthPercent) then
                        local ok, p = pcall(function()
                            return UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100)
                        end)
                        percent = (ok and type(p) == "number") and p or nil
                    end
                    if (percent) then
                        self.TextString:SetText(string.format("%.0f%%", percent))
                    else
                        self.TextString:SetText("")
                    end
                end
            end
        else
            if (self.TextString) then
                self.TextString:SetText("")
            end
        end
        ColorStatusBar(self)
    end)
    bar:HookScript("OnShow", function(self)
        if (addon.db.general.statusbarHeight == 0 or addon.db.general.statusbarHide) then
            self:Hide()
        end
    end)
    --Variable
    addon.db = addon:MergeVariable(addon.db, TinyTooltipRemakeDB)
    if (addon.db.general.SavedVariablesPerCharacter) then
        local db = CopyTable(addon.db)
        addon.db = addon:MergeVariable(db, TinyTooltipRemakeCharacterDB)
    end
    LibEvent:trigger("tooltip:variables:loaded")
    --Init
    LibEvent:trigger("TINYTOOLTIP_GENERAL_INIT")
    --ShadowText
    GameTooltipHeaderText:SetShadowOffset(1, -1)
    GameTooltipHeaderText:SetShadowColor(0, 0, 0, 0.9)
    GameTooltipText:SetShadowOffset(1, -1)
    GameTooltipText:SetShadowColor(0, 0, 0, 0.9)
    Tooltip_Small:SetShadowOffset(1, -1)
    Tooltip_Small:SetShadowColor(0, 0, 0, 0.9)
end)

LibEvent:attachTrigger("tooltip:cleared, tooltip:hide", function(self, tip)
    if (addon.db and addon.db.general) then
        LibEvent:trigger("tooltip.style.bgfile", tip, addon.db.general.bgfile)
    end
    LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    LibEvent:trigger("tooltip.style.background", tip, unpack(addon.db.general.background))
    if (tip.BigFactionIcon) then tip.BigFactionIcon:Hide() end
end)

LibEvent:attachTrigger("tooltip:show", function(self, tip)
    if (tip ~= GameTooltip) then return end
    LibEvent:trigger("tooltip.statusbar.position", addon.db.general.statusbarPosition, addon.db.general.statusbarOffsetX, addon.db.general.statusbarOffsetY)    -- In modern clients some UI getters may return restricted/secret values; avoid arithmetic on them.
    local text = GameTooltipStatusBar and GameTooltipStatusBar.TextString
    if (not text) then return end

    -- Prefer string width; it is less likely to be protected than frame width.
    local tw = (text.GetStringWidth and text:GetStringWidth()) or (text.GetWidth and text:GetWidth())
    local tipW = tip and tip.GetWidth and tip:GetWidth()

    -- Compute widths defensively: secret values can masquerade as numbers but still error on arithmetic/compare.
    local okW, w = pcall(function() return tw + 10 end)
    if (not okW or type(w) ~= "number") then return end

    local okMin, minW = pcall(function() return w + 2 end)
    if (not okMin or type(minW) ~= "number") then return end

    if (GameTooltipStatusBar:IsShown()) then
        local okCmp, bigger = pcall(function() return (type(tipW) == "number") and (w > tipW) end)
        if (okCmp and bigger) then
            tip:SetMinimumWidth(minW)
            tip:Show()
        end
    end
end)
