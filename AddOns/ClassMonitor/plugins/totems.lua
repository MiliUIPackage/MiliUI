-- Totem plugin, credits to Ildyria and Tukz
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

if UI.MyClass ~= "SHAMAN" and UI.MyClass ~= "DRUID" and UI.MyClass ~= "WARLOCK" and UI.MyClass ~= "PALADIN" then return end

local ToClock = Engine.ToClock
local CheckSpec = Engine.CheckSpec
local PixelPerfect = Engine.PixelPerfect
local DefaultBoolean = Engine.DefaultBoolean
local GetColor = Engine.GetColor

--
local plugin = Engine:NewPlugin("TOTEMS")

-- own methods
local function UpdateTotem(self, elapsed)
    -- update one totem
    if not self.expirationTime then return end
    self.expirationTime = self.expirationTime - elapsed

    local timeLeft = self.expirationTime
    if timeLeft > 0 then
        self.status:SetValue(timeLeft)
        if self.plugin.settings.text == true then
            self.text:SetText(ToClock(timeLeft))
        end
    else
        self:SetScript("OnUpdate", nil)
        if self.plugin.settings.text == true then
            self.text:SetText("")
        end
    end
end

function plugin:Update()
    for i = 1, self.settings.count do
        local totem = self.totems[i]
        local up, name, start, duration = GetTotemInfo(i)
        if up then
            local timeLeft = (start + duration) - GetTime()
            totem.duration = duration
            totem.expirationTime = timeLeft
            totem.status:SetMinMaxValues(0, duration)
            totem:SetScript("OnUpdate", UpdateTotem)
            totem:Show()
        else
            totem.status:SetValue(0)
            totem:SetScript("OnUpdate", nil)
            totem:Hide()
        end
    end
end

function plugin:UpdateVisibility(event)
    --print("TOTEMS:UpdateVisibility")
    local inCombat = true
    if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
        inCombat = true
    else
        inCombat = false
    end
    if (self.settings.autohide == false or inCombat) and CheckSpec(self.settings.specs) then
        self:RegisterEvent("PLAYER_TOTEM_UPDATE", plugin.Update)
        self:Update() -- at least one update
        self.frame:Show()
    else
        self:UnregisterEvent("PLAYER_TOTEM_UPDATE")
        self.frame:Hide()
    end
end

function plugin:UpdateGraphics()
    -- Create a frame including every totems
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
    -- Create totems
    local width, spacing = PixelPerfect(frameWidth, self.settings.count)
    self.totems = self.totems or {}
    for i = 1, self.settings.count do
        local totem = self.totems[i]
        if not totem then
            totem = CreateFrame("Frame", nil, self.frame)
            totem:SetTemplate()
            totem:SetFrameStrata("BACKGROUND")
            totem:Hide()
            self.totems[i] = totem
            -- keep a link to plugin for UpdateTotem method
            totem.plugin = self
        end
        totem:Size(width, height)
        totem:ClearAllPoints()
        if i == 1 then
            totem:Point("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        else
            totem:Point("LEFT", self.totems[i - 1], "RIGHT", spacing, 0)
        end
        if not totem.status then
            totem.status = CreateFrame("StatusBar", nil, totem)
            totem.status:SetStatusBarTexture(UI.NormTex)
            totem.status:SetFrameLevel(6)
            totem.status:SetInside()
            totem.status:GetStatusBarTexture():SetHorizTile(false)
        end
        --        local color = GetColor(self.settings.colors, i, UI.ClassColor())
        local color = self:GetColor(self.settings.color)
        totem.status:SetStatusBarColor(unpack(color))
        totem.status:SetMinMaxValues(0, 300)
        totem.status:SetValue(0)

        if self.settings.text == true and not totem.text then
            totem.text = UI.SetFontString(totem.status, 12)
            totem.text:Point("CENTER", totem.status)
        end
        if totem.text then totem.text:SetText("") end
    end
    -- totem remapping
    if self.settings.map then
        for i = 1, self.settings.count do
            local index = self.settings.map[i]
            local totem = self.totems[index]
            if i == 1 then
                totem:ClearAllPoints()
                totem:Point("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
            else
                local previousIndex = self.settings.map[i - 1]
                totem:ClearAllPoints()
                totem:Point("LEFT", self.totems[previousIndex], "RIGHT", spacing, 0)
            end
        end
    end
end

-- overridden methods
function plugin:Initialize()
    -- set defaults
    self.settings.count = self.settings.count or 3
    self.settings.text = DefaultBoolean(self.settings.text, false)
    -- no default for self.settings.map
    --    self.settings.colors = self.settings.colors or self.settings.color or UI.ClassColor() -- or CreateColorArray(color, self.settings.count)
    self.settings.customcolor = DefaultBoolean(self.settings.customcolor, false)
    self.settings.color = self.settings.color or UI.ClassColor()
    --
    self:UpdateGraphics()
end

function plugin:Enable()
    self:RegisterEvent("PLAYER_TOTEM_UPDATE", plugin.UpdateVisibility)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibility)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibility)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibility)
    self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateVisibility)
end

function plugin:Disable()
    --
    self:UnregisterAllEvents()
    --
    for i = 1, self.settings.count do -- disable each plugin
        local totem = self.totems[i]
        totem.status:SetValue(0)
        totem:SetScript("OnUpdate", nil)
        totem:Hide()
    end
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