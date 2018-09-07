-- Dot Plugin, written to Ildyria (edited by SinaC)
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

local _, _, _, toc = GetBuildInfo()

local CheckSpec = Engine.CheckSpec
local DefaultBoolean = Engine.DefaultBoolean
local GetColor = Engine.GetColor
local FormatNumber = Engine.FormatNumber

--
local plugin = Engine:NewPlugin("DOT")

local DefaultColors = {
    { 255 / 255, 165 / 255, 0, 1 }, -- orange
    { 255 / 255, 255 / 255, 0, 1 }, -- yellow
    { 127 / 255, 255 / 255, 0, 1 } -- green
}

--[[
		local name, duration, expirationTime, _, value1, value2, value3, _

if toc > 80000 then
		name, _, _, _, duration, expTime, _, _, _, _, _, _, value1, value2, value3 = AuraUtil.FindAuraByName(self.auraName, "target", "PLAYER|HARMFUL")  -- 8.0
elseif toc > 50001 then
		name, _, _, _, _, duration, expTime, _, _, _, _, _, _, _, value1, value2, value3 = UnitAura("target", self.auraName, nil, "PLAYER|HARMFUL") -- 5.1
else
		name, _, _, _, _, duration, expTime, _, _, _, _, _, _, value1, value2, value3 = UnitAura("target", self.auraName, nil, "PLAYER|HARMFUL") -- 5.0
end
value1 gives current dot value
--]]

-- own methods
function plugin:Update(elapsed)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
    if self.timeSinceLastUpdate > 0.1 and self.auraName then
        --print("DMG:"..tostring(self.dmg))
        local name, duration, expTime, value1, _
        name, _, _, _, duration, expTime, _, _, _, _, _, _, _, _, value1 = AuraUtil.FindAuraByName(self.auraName, "target", "PLAYER|HARMFUL") -- 8.0
        if not name or not duration then
            self:UnregisterUpdate()
            --
            self.bar:Hide()
            self.dmg = 0
        else
            if value1 and type(value1) == "number" then
                self.dmg = value1
            end
            local remainTime = (expTime or 0) - GetTime()
            --            local color
            --            if self.settings.latency == true and remainTime <= 0.4 then
            --                color = { 1, 0, 0, 1 } -- red
            --            else
            --                if self.settings.threshold == 0 then
            --                    color = GetColor(self.settings.colors, 1, DefaultColors[1]) -- bad: orange
            --                elseif self.settings.threshold * .75 >= self.dmg then
            --                    color = GetColor(self.settings.colors, 1, DefaultColors[1]) -- bad: orange
            --                elseif self.settings.threshold >= self.dmg then
            --                    color = GetColor(self.settings.colors, 2, DefaultColors[2]) -- 0,75% -- yellow
            --                else
            --                    color = GetColor(self.settings.colors, 3, DefaultColors[3]) -- > 100% GO -- green
            --                end
            --            end
            local color = self:GetColor(self.settings.color)
            self.bar.status:SetStatusBarColor(unpack(color))
            self.bar.status:SetMinMaxValues(0, duration or 1)
            self.bar.status:SetValue(remainTime)
            self.bar.text:SetText(Engine.ToClock(remainTime))
        end
        self.timeSinceLastUpdate = 0
    end
end

function plugin:UpdateVisibility(event)
    --print("UpdateVisibility:"..tostring(event))
    local visible = false
    if CheckSpec(self.settings.specs) and self.auraName then
        local name, _, _, _, duration, expTime = AuraUtil.FindAuraByName(self.auraName, "target", "PLAYER|HARMFUL")
        --print("--->"..tostring(name).."  "..tostring(expTime).."  "..tostring(duration).."  "..tostring(self.auraName).."  "..tostring(self.dmg))
        --		local name, duration, expirationTime, _, value1, value2, value3, _
        -- name, _, _, _, duration, expTime, _, _, _, _, _, _, value1, value2, value3 = AuraUtil.FindAuraByName(self.auraName, "target", "PLAYER|HARMFUL")
        --print("--->"..tostring(name).."  "..tostring(expTime).."  "..tostring(duration).."  "..tostring(self.auraName).."  "..tostring(value1).."  "..tostring(value2).."  "..tostring(value3))
        if expTime ~= nil then
            local remainTime = expTime - GetTime()
            if remainTime > 0 then
                visible = true
            end
        end
    end
    if visible then
        --print("VISIBLE:"..tostring(self.auraName).."  "..tostring(self.dmg))
        self.timeSinceLastUpdate = GetTime()
        self:RegisterUpdate(plugin.Update)
        --
        self.bar:Show()
    else
        --print("NOT VISIBLE:"..tostring(self.auraName))
        self:UnregisterUpdate()
        --
        self.bar:Hide()
        self.dmg = 0
    end
end

function plugin:UpdateDamage(_, _, eventType, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, _, _, amount)
    local targetGUID = UnitGUID("target")
    --print("UPDATEDAMAGE:"..tostring(eventType).." "..tostring(spellID).."  "..tostring(amount))
    if sourceGUID == self.playerGUID and destGUID == targetGUID and spellID and type(spellID) == "number" and spellID == self.settings.spellID and string.find(eventType, "_DAMAGE") then
        --print("UpdateDamage:"..tostring(amount))
        self.dmg = amount
        self:UpdateVisibility()
    end
end

-- function plugin:UpdateDamage(_, _, ...)
-- for index = 1, select('#', ...) do
-- local param = select(index, ...)
-- if index == 1 and not string.find(param, "DAMAGE") and not string.find(param, "AURA") then return end
-- print("UpdateDamage:"..tostring(index).."  "..tostring(param))
-- end
-- end

function plugin:UpdateGraphics()
    local bar = self.bar
    if not bar then
        bar = CreateFrame("Frame", self.name, UI.PetBattleHider)
        bar:SetTemplate()
        bar:SetFrameStrata("BACKGROUND")
        bar:Hide()
        self.bar = bar
    end
    bar:ClearAllPoints()
    bar:Point(unpack(self:GetAnchor()))
    bar:Size(self:GetWidth(), self:GetHeight())

    if not bar.status then
        bar.status = CreateFrame("StatusBar", nil, bar)
        bar.status:SetStatusBarTexture(UI.NormTex)
        bar.status:SetFrameLevel(6)
        bar.status:SetInside()
        bar.status:SetMinMaxValues(0, 1) -- dummy value
    end

    if not bar.text then
        bar.text = UI.SetFontString(bar.status, 12)
        bar.text:Point("CENTER", bar.status)
    end
    bar.text:SetText("")
end

-- overridden methods
function plugin:Initialize()
    -- set defaults
    self.settings.customcolor = DefaultBoolean(self.settings.customcolor, false)
    self.settings.color = self.settings.color or UI.ClassColor()
    --    self.settings.colors = self.settings.colors or DefaultColors
    self.settings.latency = DefaultBoolean(self.settings.latency, false)
    self.settings.threshold = self.settings.threshold or 0
    if type(self.settings.threshold) ~= "number" then self.settings.threshold = 0 end
    -- no default for spellID
    --
    self.dmg = 0
    self.playerGUID = UnitGUID("player")
    self.auraName = GetSpellInfo(self.settings.spellID)
    --
    self:UpdateGraphics()
end

function plugin:Enable()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibility)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibility)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibility)
    self:RegisterEvent("PLAYER_TARGET_CHANGED", plugin.UpdateVisibility)
    self:RegisterUnitEvent("UNIT_AURA", "target", plugin.UpdateVisibility)

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", plugin.UpdateDamage)
end

function plugin:Disable()
    --
    self:UnregisterAllEvents()
    self:UnregisterUpdate()
    --
    self.bar:Hide()
end

function plugin:SettingsModified()
    --
    self:Disable()
    --
    self.auraName = GetSpellInfo(self.settings.spellID)
    --
    self:UpdateGraphics()
    --
    if self:IsEnabled() then
        self:Enable()
        self:UpdateVisibility()
    end
end