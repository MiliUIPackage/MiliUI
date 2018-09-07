-- Power plugin
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

local CheckSpec = Engine.CheckSpec
local PixelPerfect = Engine.PixelPerfect
local DefaultBoolean = Engine.DefaultBoolean
local GetColor = Engine.GetColor

local plugin = Engine:NewPlugin("POWER")

-- own methods

function plugin:UpdateVisibility(event)
    --
    local inCombat = true
    if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
        inCombat = true
    else
        inCombat = false
    end
    --
    if (self.settings.autohide == false or inCombat) and CheckSpec(self.settings.specs) then
        --self:UpdateMaxValue()
        self:UpdateValue()
        --
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function plugin:UpdateValue(event, unit, powerType)
    local full, partial = math.modf(UnitPower("player", self.settings.powerType, true) / UnitPowerDisplayMod(self.settings.powerType))
--    print("UnitPower with true: " .. UnitPower("player", self.settings.powerType, true) .. "Mod: " .. UnitPowerDisplayMod(self.settings.powerType))
    local display_count = full
    if partial > 0 then
        display_count = display_count + 1
    end
    --	print(full, partial, display_count)
    if self.settings.borderRemind == true then
        if display_count and display_count > 0 then
            for i = 1, full do self.points[i].status:SetValue(10) end
            if partial > 0 then self.points[full + 1].status:SetValue(partial * 10) end
            for i = 1, display_count do self.points[i].status:Show() end
            for i = display_count + 1, self.count do self.points[i].status:Hide() end
        else
            for i = 1, self.count do self.points[i].status:Hide() end
        end
    else
        if display_count and display_count > 0 then
            for i = 1, full do self.points[i].status:SetValue(10) end
            if partial > 0 then self.points[full + 1].status:SetValue(partial * 10) end
            for i = 1, display_count do self.points[i]:Show() end
            for i = display_count + 1, self.count do self.points[i]:Hide() end
        else
            for i = 1, self.count do self.points[i]:Hide() end
        end
    end
end

function plugin:SetCounts()
    local maxValue = UnitPowerMax("player", self.settings.powerType)
    --	print("Max: "..maxValue)
    if maxValue and maxValue ~= self.maxValue then
        self.count = maxValue

        self:UpdateGraphics()
    end
end

function plugin:UpdatePointGraphics(index, width, height, spacing)
    local point = self.points[index]
    if not point then
        point = CreateFrame("Frame", nil, self.frame)
        point:SetTemplate()
        point:SetFrameStrata("BACKGROUND")
        --		point:Hide()
        if not self.settings.borderRemind == true then point:Hide() end
        self.points[index] = point
    end
    point:Size(width, height)
    point:ClearAllPoints()
    if self.settings.reverse == true then
        if index == 1 then
            point:Point("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
        else
            point:Point("RIGHT", self.points[index - 1], "LEFT", -spacing, 0)
        end
    else
        if index == 1 then
            point:Point("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        else
            point:Point("LEFT", self.points[index - 1], "RIGHT", spacing, 0)
        end
    end
    if not point.status then
        point.status = CreateFrame("StatusBar", nil, point)
        point.status:SetStatusBarTexture(UI.NormTex)
        point.status:SetFrameLevel(6)
        point.status:SetMinMaxValues(0, 10)
        point.status:SetInside()
    end

    local color = self:GetColor(self.settings.color)
    point.status:SetStatusBarColor(unpack(color))
    point:SetBackdropBorderColor(unpack(UI.BorderColor))

    if self.settings.filled == true then
        point.status:Show()
    else
        point.status:Hide()
    end
end

function plugin:UpdateGraphics()
    -- Create a frame including every points
    local frame = self.frame
    if not frame then
        frame = CreateFrame("Frame", self.name, UI.PetBattleHider)
        frame:Hide()
        self.frame = frame
    end
    local frameWidth = self:GetWidth()
    local height = self:GetHeight()
    frame:ClearAllPoints()
    frame:Point(unpack(self:GetAnchor()))
    frame:Size(frameWidth, height)
    -- Create points
    local width, spacing = PixelPerfect(frameWidth, self.count)
    --	print(width, spacing)
    self.points = self.points or {}
    for i = 1, self.count do
        self:UpdatePointGraphics(i, width, height, spacing)
    end
end

-- overridden methods
function plugin:Initialize()
    -- set defaults
    self.settings.filled = DefaultBoolean(self.settings.filled, false)
    self.settings.borderRemind = DefaultBoolean(self.settings.borderRemind, false)
    self.settings.powerType = self.settings.powerType or Enum.PowerType.HolyPower
    self.settings.customcolor = DefaultBoolean(self.settings.customcolor, false)
    self.settings.color = self.settings.color or UI.PowerColor(self.settings.powerType) or UI.ClassColor()

    self:SetCounts()
end

function plugin:Enable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibility)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibility)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibility)
    self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateVisibility)

    self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player", plugin.UpdateValue)
    self:RegisterUnitEvent("UNIT_MAXPOWER", "player", plugin.SetCounts)
end

function plugin:Disable()
    --
    self:UnregisterAllEvents()
    --
    self.frame:Hide()
end

function plugin:SettingsModified()
    --
    self:Disable()
    --
    self:UpdateGraphics()
    --
    if self:IsEnabled() then
        self:Enable()
        self:UpdateVisibility()
    end
end