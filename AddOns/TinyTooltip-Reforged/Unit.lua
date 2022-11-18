
local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")
local LibItemInfo = LibStub:GetLibrary("LibItemInfo.7000")

local clientVer, clientBuild, clientDate, clientToc = GetBuildInfo()

local guids, inspecting = {}, false

local AFK = AFK
local DND = DND
local PVP = PVP
local LEVEL = LEVEL
local PSPEC = PSPEC
local OFFLINE = FRIENDS_LIST_OFFLINE
local FACTION_HORDE = FACTION_HORDE
local FACTION_ALLIANCE = FACTION_ALLIANCE

local TOOLTIP_UPDATE_TIME = TOOLTIP_UPDATE_TIME or 0.2

local addon = TinyTooltipReforged

local function strip(text)
    return (text:gsub("%s+([|%x%s]+)<trim>", "%1"))
end

local function ColorBorder(tip, config, raw)
    if (not raw) then return end
    if (config.coloredBorder and addon.colorfunc[config.coloredBorder]) then
        local r, g, b = addon.colorfunc[config.coloredBorder](raw)
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
    elseif (type(config.coloredBorder) == "string" and config.coloredBorder ~= "default") then
        local r, g, b = addon:GetRGBColor(config.coloredBorder)
        if (r and g and b) then
            LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
        end
    else
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    end
end

local function ColorBackground(tip, config, raw)
    if (not raw) then return end
    local bg = config.background
    if not bg then return end
    if (bg.colorfunc == "default" or bg.colorfunc == "" or bg.colorfunc == "inherit") then
        local r, g, b, a = unpack(addon.db.general.background)
        a = bg.alpha or tonumber(a)
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, a)
        return
    end
    if (addon.colorfunc[bg.colorfunc]) then
        local r, g, b = addon.colorfunc[bg.colorfunc](raw)
        local a = bg.alpha or 0.8
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, a)
    end
end

local function GrayForDead(tip, config, unit)
    if (not unit) then return end
    if (config.grayForDead and UnitIsDeadOrGhost(unit)) then
        local line, text
        LibEvent:trigger("tooltip.style.border.color", tip, 0.6, 0.6, 0.6)
        LibEvent:trigger("tooltip.style.background", tip, 0.1, 0.1, 0.1)
        for i = 1, tip:NumLines() do
            line = _G[tip:GetName() .. "TextLeft" .. i]
            text = (line:GetText() or ""):gsub("|cff%x%x%x%x%x%x", "|cffaaaaaa")
            line:SetTextColor(0.7, 0.7, 0.7)
            line:SetText(text)
        end
    end
end

local function ShowBigFactionIcon(tip, config, raw)
    if (not raw) then return end
    if (config.elements.factionBig and config.elements.factionBig.enable and tip.BigFactionIcon and (raw.factionGroup=="Alliance" or raw.factionGroup == "Horde")) then
        tip.BigFactionIcon:Show()
        tip.BigFactionIcon:SetTexture("Interface\\Timer\\".. raw.factionGroup .."-Logo")
        tip:Show()
        tip:SetMinimumWidth(tip:GetWidth() + 20)
    end
end

local function PlayerCharacter(tip, unit, config, raw)
    if (not raw) then return end
    local data = addon:GetUnitData(unit, config.elements, raw)
    addon:HideLines(tip, 2, 3)
    addon:HideLine(tip, "^"..LEVEL)
    addon:HideLine(tip, "^"..FACTION_ALLIANCE)
    addon:HideLine(tip, "^"..FACTION_HORDE)
    addon:HideLine(tip, "^"..PVP)
    for i, v in ipairs(data) do
        addon:GetLine(tip,i):SetText(strip(table.concat(v, " ")))
    end
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    ShowBigFactionIcon(tip, config, raw)
end

local function NonPlayerCharacter(tip, unit, config, raw)
    if (not raw) then return end
    local levelLine = addon:FindLine(tip, "^"..LEVEL)
    if (levelLine or tip:NumLines() > 1) then
        local data = addon:GetUnitData(unit, config.elements, raw)
        local titleLine = addon:GetNpcTitle(tip)
        local increase = 0
        for i, v in ipairs(data) do
            if (i == 1) then
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            end
            if (i == 2) then
                if (config.elements.npcTitle.enable and titleLine) then
                    --titleLine:SetText(addon:FormatData(titleLine:GetText(), config.elements.npcTitle, raw))
                    increase = 1
                end
                i = i + increase
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            elseif ( i > 2) then
                i = i + increase
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            end
        end
    end
    addon:HideLine(tip, "^"..LEVEL)
    addon:HideLine(tip, "^"..PVP)
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    ShowBigFactionIcon(tip, config, raw)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self, data)
    local unit = UnitTokenFromGUID(data.guid)
    local raw = addon:GetUnitInfo(data.guid)
    if (UnitIsPlayer(unit)) then
        PlayerCharacter(GameTooltip, unit, addon.db.unit.player, raw)
    else
        NonPlayerCharacter(GameTooltip, unit, addon.db.unit.npc, raw)
    end
end)

addon.ColorUnitBorder = ColorBorder
addon.ColorUnitBackground = ColorBackground


-- INSPECT --

local function FindLine(tooltip, keyword)
    local line, text
    for i = 2, tooltip:NumLines() do
        line = _G[tooltip:GetName() .. "TextLeft" .. i]
        text = line:GetText() or ""
        if (string.find(text, keyword)) then
            return line, i, _G[tooltip:GetName() .. "TextRight" .. i]
        end
    end
end

local STAT_AVERAGE_ITEM_LEVEL = "ItemLevel"
local SPECIALIZATION = "Specialization"

local LevelLabel = STAT_AVERAGE_ITEM_LEVEL .. ": "
local SpecLabel = SPECIALIZATION .. ": "

local function AppendToGameTooltip(guid, ilevel, spec, weaponLevel, isArtifact)
    spec = spec or ""
    if (addon.db.unit.player.showIlevelAndSpecialization) then
        local _, unit = GameTooltip:GetUnit()
        if (not unit or UnitGUID(unit) ~= guid) then return end
        local ilvlLine, _, lineRight = FindLine(GameTooltip, LevelLabel)
        local ilvlText = format("%s|cffffffff%s|r", LevelLabel, ilevel)
        local specText = format("|cffffffff%s|r", spec)
        --local specText = format("|cffb8b8b8%s|r", spec)
        if (ilvlLine) then
            ilvlLine:SetText(ilvlText)
            lineRight:SetText(specText)
        else            
            GameTooltip:AddDoubleLine(ilvlText, specText)
        end
	if (not GameTooltip:IsShown()) then
            GameTooltip:Show()
	end
    end
end

hooksecurefunc("NotifyInspect", function(unit)
    if (addon.db.unit.player.showIlevelAndSpecialization) then
      local guid = UnitGUID(unit)
      if (not guid) then return end
      local data = guids[guid]
      if (data) then
          data.unit = unit
          data.name, data.realm = UnitName(unit)
      else
          data = {
              unit   = unit,
              guid   = guid,
              class  = select(2, UnitClass(unit)),
              level  = UnitLevel(unit),
              ilevel = -1,
              spec   = nil,
              hp     = UnitHealthMax(unit),
              timer  = time(),
          }
          data.name, data.realm = UnitName(unit)
          guids[guid] = data
      end
      if (not data.realm) then
          data.realm = GetRealmName()
      end
      data.expired = time() + 5
      inspecting = data
      LibEvent:trigger("UNIT_INSPECT_STARTED", data)
  end
end)

function GetInspecting()
    if (InspectFrame and InspectFrame.unit) then
        local guid = UnitGUID(InspectFrame.unit)
        return guids[guid] or { inuse = true }
    end
    if (inspecting and inspecting.expired > time()) then
        return inspecting
    end
end

function GetInspectInfo(unit, timelimit, checkhp)
    local guid = UnitGUID(unit)
    if (not guid or not guids[guid]) then return end
    if (checkhp and UnitHealthMax(unit) ~= guids[guid].hp) then return end
    if (not timelimit or timelimit == 0) then
        return guids[guid]
    end
    if (guids[guid].timer > time()-timelimit) then
        return guids[guid]
    end
end

function GetInspectSpec(unit)
    local specID, specName
    if (unit == "player") then
        specID = GetSpecialization()
        specName = select(2, GetSpecializationInfo(specID))
    else
        specID = GetInspectSpecialization(unit)
        if (specID and specID > 0) then
            specName = select(2, GetSpecializationInfoByID(specID))
        end
    end
    return specName or ""
end

hooksecurefunc("ClearInspectPlayer", function()
    inspecting = false
end)

LibEvent:attachEvent("INSPECT_READY", function(self, guid)
    if (not guids[guid]) then return end
    LibSchedule:AddTask({
        identity  = guid,
        timer     = 0.5,
        elasped   = 0.8,
        expired   = GetTime() + 4,
        data      = guids[guid],
        onTimeout = function(self) inspecting = false end,
        onExecute = function(self) 
            local count, ilevel, _, weaponLevel, isArtifact, maxLevel = LibItemInfo:GetUnitItemLevel(self.data.unit)
            if (ilevel <= 0) then return true end
            if (count == 0 and ilevel > 0) then
                self.data.timer = time()
                self.data.name = UnitName(self.data.unit)
                self.data.class = select(2, UnitClass(self.data.unit))
                self.data.ilevel = ilevel
                self.data.maxLevel = maxLevel
                self.data.spec = GetInspectSpec(self.data.unit)
                self.data.hp = UnitHealthMax(self.data.unit)
                self.data.weaponLevel = weaponLevel
                self.data.isArtifact = isArtifact
                LibEvent:trigger("UNIT_INSPECT_READY", self.data)
                inspecting = false
                return true
            end
        end,
    })
end)

LibEvent:attachTrigger("UNIT_INSPECT_READY", function(self, data) 
    if (data.guid == UnitGUID("mouseover")) then
        AppendToGameTooltip(data.guid, floor(data.ilevel), data.spec, data.weaponLevel, data.isArtifact)
    end
end)

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self, data)
    local unit = UnitTokenFromGUID(data.guid)
    if (not UnitIsPlayer(unit)) then return end
    if (addon.db and addon.db.unit.player.showIlevelAndSpecialization and clientToc >= 70100) then
        local _, unit = self:GetUnit()
        if (not unit) then return end
        local guid = UnitGUID(unit)
        if (not guid) then return end
        local hp = UnitHealthMax(unit)
        local data = GetInspectInfo(unit)
        if (data and data.hp == hp and data.ilevel > 0) then
            return AppendToGameTooltip(guid, floor(data.ilevel), data.spec, data.weaponLevel, data.isArtifact)
        end
        if (not CanInspect(unit) or not UnitIsVisible(unit)) then return end
        local inspecting = GetInspecting()
        if (inspecting) then
            if (inspecting.guid ~= guid) then
                return AppendToGameTooltip(guid, "n/a")
            else
                return AppendToGameTooltip(guid, "....")
            end
        end
        ClearInspectPlayer()
        NotifyInspect(unit)
        AppendToGameTooltip(guid, "...")
    end
end)
