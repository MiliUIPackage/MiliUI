local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L

local CDM_C = CDM and CDM.CONST or {}
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local CASTBAR_BG_TEXTURE = "Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\blizzcastback"
local ATLAS_CAST = [[UI-CastingBar-Filling-Standard]]
local ATLAS_CHANNEL = [[UI-CastingBar-Filling-Channel]]
local ATLAS_NONBREAKABLE = [[UI-CastingBar-Uninterruptable]]
local SPARK_TEXTURE = "4417031"

local CAST_STATE_NORMAL = 1
local CAST_STATE_CHANNEL = 2
local CAST_STATE_NONBREAKABLE = 3

local GetTime = _G.GetTime
local UnitClass = _G.UnitClass
local UnitCastingDuration = _G.UnitCastingDuration
local UnitChannelDuration = _G.UnitChannelDuration
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local UnitEmpoweredChannelDuration = _G.UnitEmpoweredChannelDuration
local UnitEmpoweredStagePercentages = _G.UnitEmpoweredStagePercentages

local scratchBoundaries = {}

local _empFrame
local _empUseAtlas
local _empLsmTexturePath
local _empBarWidth
local _empBarHeight

local DEFAULT_BORDER_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_BG_COLOR = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 }

local function CfgVal(key, default)
    return CDM_C.GetConfigValue(key, default)
end

local function GetPlayerClassColor()
    local _, classTag = UnitClass("player")
    local classColors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local color = classTag and classColors and classColors[classTag]
    if not color then return nil end
    return color.r, color.g, color.b, color.a or 1
end

local function SyncCastBarBorderVisual(target, borderHost)
    if borderHost and borderHost.border then
        borderHost.border:Show()
    end
end

local CAST_ANCHOR_SCREEN       = "screen"
local CAST_ANCHOR_PLAYER_FRAME = "playerFrame"
local CAST_ANCHOR_ESSENTIAL    = "essential"
local CAST_ANCHOR_UTILITY      = "utility"
local CAST_ANCHOR_RESOURCES    = "resources"

local scratchComponent = {}
local scratchComponentOrder = {}

local function BuildPrimaryComponent(primaryBarKey)
    for k in pairs(scratchComponent) do scratchComponent[k] = nil end
    for i = #scratchComponentOrder, 1, -1 do scratchComponentOrder[i] = nil end

    if not primaryBarKey then return scratchComponent end

    local BAR_KEY_TO_POWER_TYPE = CDM.BAR_KEY_TO_POWER_TYPE
    local resourceBars = CDM.resourceBars
    if not BAR_KEY_TO_POWER_TYPE or not resourceBars then return scratchComponent end

    scratchComponent[primaryBarKey] = true
    scratchComponentOrder[#scratchComponentOrder + 1] = primaryBarKey

    local cur = primaryBarKey
    for _ = 1, 16 do
        local parent = CDM:GetBarSetting(cur, "anchorTo")
        if type(parent) ~= "string" then break end
        if parent == CAST_ANCHOR_SCREEN or parent == CAST_ANCHOR_PLAYER_FRAME
            or parent == CAST_ANCHOR_ESSENTIAL or parent == CAST_ANCHOR_UTILITY then break end
        if scratchComponent[parent] then break end
        local pt = BAR_KEY_TO_POWER_TYPE[parent]
        if not pt or not resourceBars[pt] then break end
        scratchComponent[parent] = true
        scratchComponentOrder[#scratchComponentOrder + 1] = parent
        cur = parent
    end

    local changed = true
    while changed do
        changed = false
        for powerType, bar in pairs(resourceBars) do
            local barKey = bar.barKey
            if barKey and not scratchComponent[barKey] then
                local anchorTo = CDM:GetBarSetting(barKey, "anchorTo")
                if type(anchorTo) == "string" and scratchComponent[anchorTo] then
                    scratchComponent[barKey] = true
                    scratchComponentOrder[#scratchComponentOrder + 1] = barKey
                    changed = true
                end
            end
        end
    end

    return scratchComponent
end

local function ResolveResourcesAnchor(allowHiddenFallback)
    if not CDM.resourceBars then return nil end
    local primaryPT
    if UnitClassBase("player") == "DRUID" and CDM.GetDruidPrimaryPowerType then
        primaryPT = CDM.GetDruidPrimaryPowerType(CDM:GetCurrentSpecID())
    else
        primaryPT = UnitPowerType("player")
    end
    local POWER_TYPE_TO_BAR_KEY = CDM.POWER_TYPE_TO_BAR_KEY
    local BAR_KEY_TO_POWER_TYPE = CDM.BAR_KEY_TO_POWER_TYPE
    if not POWER_TYPE_TO_BAR_KEY or not BAR_KEY_TO_POWER_TYPE then return nil end

    local primaryBarKey = POWER_TYPE_TO_BAR_KEY[primaryPT]
    local primaryBarActive = false
    if primaryBarKey and CDM.activeBarKeys then
        for i = 1, #CDM.activeBarKeys do
            if CDM.activeBarKeys[i] == primaryBarKey then
                primaryBarActive = true
                break
            end
        end
    end
    local primaryBar = primaryBarActive and CDM.resourceBars[primaryPT]

    local component
    if primaryBar then
        component = BuildPrimaryComponent(primaryBarKey)
    else
        for k in pairs(scratchComponent) do scratchComponent[k] = nil end
        for i = #scratchComponentOrder, 1, -1 do scratchComponentOrder[i] = nil end
        for _, bar in pairs(CDM.resourceBars) do
            local barKey = bar.barKey
            if barKey then
                scratchComponent[barKey] = true
                scratchComponentOrder[#scratchComponentOrder + 1] = barKey
            end
        end
        component = scratchComponent
    end

    local topBar, topY
    for barKey in pairs(component) do
        local pt = BAR_KEY_TO_POWER_TYPE[barKey]
        local bar = pt and CDM.resourceBars[pt]
        if bar and bar:IsShown() then
            local top = bar:GetTop()
            if top and (not topY or top > topY) then
                topBar = bar
                topY = top
            end
        end
    end
    if topBar then return topBar end

    if allowHiddenFallback then
        for barKey in pairs(component) do
            local pt = BAR_KEY_TO_POWER_TYPE[barKey]
            local bar = pt and CDM.resourceBars[pt]
            if bar then
                local top = bar:GetTop()
                if top and (not topY or top > topY) then
                    topBar = bar
                    topY = top
                end
            end
        end
    end

    return topBar
end

local function ResolveViewerContainer(vName)
    local containers = CDM.anchorContainers
    local target = containers and vName and containers[vName]
    if target and target:IsShown() then return target end
    return nil
end

local function ResolveCastBarAnchor()
    local mode = CfgVal("castBarAnchor", "resources")
    local aP = CfgVal("castBarAnchorPoint", "BOTTOM")
    local tP = CfgVal("castBarTargetPoint", "TOP")
    local oX = CfgVal("castBarOffsetX", 0)
    local oY = CfgVal("castBarOffsetY", -166)

    if mode == CAST_ANCHOR_SCREEN then
        return UIParent, aP, tP, oX, oY, false
    end

    if mode == CAST_ANCHOR_PLAYER_FRAME then
        return CAST_ANCHOR_PLAYER_FRAME, aP, tP, oX, oY, false
    end

    if mode == CAST_ANCHOR_ESSENTIAL then
        local target = ResolveViewerContainer(CDM_C.VIEWERS and CDM_C.VIEWERS.ESSENTIAL)
        if target then return target, aP, tP, oX, oY, false end
        return UIParent, aP, tP, oX, oY, true
    end

    if mode == CAST_ANCHOR_UTILITY then
        local target = ResolveViewerContainer(CDM_C.VIEWERS and CDM_C.VIEWERS.UTILITY)
        if target then return target, aP, tP, oX, oY, false end
        return UIParent, aP, tP, oX, oY, true
    end

    if mode == CAST_ANCHOR_RESOURCES then
        local resourcesDisabled = CDM.db and CDM.db.resourcesEnabled == false
        local target = not resourcesDisabled and ResolveResourcesAnchor() or nil
        if target then return target, aP, tP, oX, oY, false end
        local essential = ResolveViewerContainer(CDM_C.VIEWERS and CDM_C.VIEWERS.ESSENTIAL)
        if essential then return essential, aP, tP, oX, oY, false end
        return UIParent, aP, tP, oX, oY, true
    end

    return UIParent, aP, tP, oX, oY, false
end

local function IsCastBarPreviewEnabled()
    return CfgVal("castBarPreviewEnabled", false) == true
end

local EMPOWER_WINDUP_DEFAULT = { r = 0.45, g = 0.45, b = 0.55, a = 1 }
local EMPOWER_DEFAULT_COLORS = {
    { r = 0.26, g = 0.65, b = 1.0, a = 1 },   -- Stage 1: Blue
    { r = 0.26, g = 0.90, b = 0.55, a = 1 },   -- Stage 2: Green
    { r = 1.0, g = 0.80, b = 0.0, a = 1 },     -- Stage 3: Gold
    { r = 1.0, g = 0.35, b = 0.0, a = 1 },     -- Stage 4: Orange
}
local EMPOWER_FILL_EPSILON = 0.001

local function GetEmpowerSegmentColor(segmentIndex)
    if segmentIndex <= 1 then
        return CfgVal("castBarEmpowerWindUpColor", EMPOWER_WINDUP_DEFAULT)
    end
    local stageNum = segmentIndex - 1
    local key = "castBarEmpowerStage" .. stageNum .. "Color"
    return CfgVal(key, EMPOWER_DEFAULT_COLORS[stageNum] or EMPOWER_DEFAULT_COLORS[1])
end

local function HideEmpowerPips(frame)
    if not frame.empowerPips then return end
    for _, pip in ipairs(frame.empowerPips) do
        pip:Hide()
    end
end

local function UpdateEmpowerPips(frame, scaledPercentages)
    frame.empowerPips = frame.empowerPips or {}
    local barWidth = frame.cachedWidth or frame:GetWidth()
    local barHeight = frame:GetHeight()

    local borderColor = CfgVal("borderColor", DEFAULT_BORDER_COLOR)
    HideEmpowerPips(frame)

    for i = 1, #scaledPercentages do
        local pip = frame.empowerPips[i]
        if not pip then
            pip = Pixel.CreateSolidTexture(frame.topOverlay, "OVERLAY", 7)
            frame.empowerPips[i] = pip
        end

        local xPos = barWidth * scaledPercentages[i]
        pip:SetSize(Pixel.GetSize(), barHeight)
        pip:ClearAllPoints()
        Pixel.SetPoint(pip, "CENTER", frame.topOverlay, "LEFT", xPos, 0)
        pip:SetVertexColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
        pip:Show()
    end
end

local function HideEmpowerSegments(frame)
    if frame.empowerStageData then
        for _, stage in ipairs(frame.empowerStageData) do
            stage.bar:SetValue(0)
            stage.bar:Hide()
        end
    end
    frame.empowerActiveCount = 0
    HideEmpowerPips(frame)
end

local function ApplyStageTexture(bar)
    if _empUseAtlas then
        bar:SetStatusBarTexture(ATLAS_CAST)
        local tex = bar:GetStatusBarTexture()
        if tex then tex:SetDesaturated(true) end
    else
        if _empLsmTexturePath then
            bar:SetStatusBarTexture(_empLsmTexturePath)
        else
            bar:SetStatusBarTexture(CDM_C.TEX_WHITE8X8)
        end
    end
end

local function ConfigureStage(index, startPct, endPct, color)
    local stage = _empFrame.empowerStageData[index]
    if not stage then
        local bar = CreateFrame("StatusBar", nil, _empFrame.stageFrame)
        bar:SetFrameLevel(_empFrame.stageFrame:GetFrameLevel())
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        stage = { bar = bar }
        _empFrame.empowerStageData[index] = stage
    end

    stage.startPct = startPct
    stage.endPct = endPct
    local onePixel = Pixel.GetSize()
    local fullWidth = math.max(onePixel, Snap((endPct - startPct) * _empBarWidth))

    local bar = stage.bar
    bar:ClearAllPoints()
    Pixel.SetPoint(bar, "TOPLEFT", _empFrame.stageFrame, "TOPLEFT", startPct * _empBarWidth, 0)
    bar:SetSize(fullWidth, _empBarHeight)
    ApplyStageTexture(bar)
    bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    bar:SetValue(0)
    bar:Show()
end

local function SetupEmpowerSegments(frame, numStages, boundaries)
    frame.empowerStageData = frame.empowerStageData or {}
    _empFrame = frame
    _empBarWidth = frame.cachedWidth or frame:GetWidth()
    _empBarHeight = frame:GetHeight()
    _empUseAtlas = CfgVal("castBarUseAtlasTextures", true)
    _empLsmTexturePath = nil
    if not _empUseAtlas then
        local textureName = CfgVal("castBarTexture", "Blizzard")
        _empLsmTexturePath = LSM and LSM:Fetch("statusbar", textureName)
    end

    for s = 1, numStages do
        local startPct = (s == 1) and 0 or boundaries[s - 1]
        ConfigureStage(s, startPct, boundaries[s], GetEmpowerSegmentColor(s))
    end

    local totalSegments = numStages
    local lastBoundary = boundaries[numStages]
    if lastBoundary < 1.0 then
        totalSegments = numStages + 1
        local c = CfgVal("castBarEmpowerStage4Color", EMPOWER_DEFAULT_COLORS[4])
        ConfigureStage(totalSegments, lastBoundary, 1.0, c)
    end

    for i = totalSegments + 1, #frame.empowerStageData do
        frame.empowerStageData[i].bar:SetValue(0)
        frame.empowerStageData[i].bar:Hide()
    end

    frame.empowerActiveCount = totalSegments

    UpdateEmpowerPips(frame, boundaries)
end

local function UpdateEmpowerFill(frame)
    if not frame.empowerStageData then return end

    local count = frame.empowerActiveCount or 0
    if count == 0 then return end
    if not frame.curStartTime or not frame.curEndTime then return end

    local now = GetTime()
    local totalDuration = frame.curEndTime - frame.curStartTime
    if totalDuration <= 0 then return end

    local progress = (now - frame.curStartTime) / totalDuration
    if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end

    for i = 1, count do
        local stage = frame.empowerStageData[i]
        local bar = stage.bar

        if progress >= stage.endPct then
            bar:SetValue(1)
        elseif progress > stage.startPct then
            local stageSpan = stage.endPct - stage.startPct
            if stageSpan < EMPOWER_FILL_EPSILON then
                stageSpan = EMPOWER_FILL_EPSILON
            end
            local fillFrac = (progress - stage.startPct) / stageSpan
            if fillFrac < 0 then fillFrac = 0 elseif fillFrac > 1 then fillFrac = 1 end
            bar:SetValue(fillFrac)
        else
            bar:SetValue(0)
        end
    end
end

local function GetCastBarWidth()
    local w = CfgVal("castBarWidth", 300)
    if w == 0 then
        local source = CfgVal("castBarAutoWidthSource", "essential")
        if source == "utility" and CDM:GetUtilityVisibleCount() > 0 then
            w = CDM:GetUtilityContentWidth()
        end
        if w == 0 and CDM.CalculateEssentialRow1Width then
            w = CDM.CalculateEssentialRow1Width()
        end
    end
    if w == 0 then w = 200 end
    return w
end

local ShowPreview, HidePreview, ApplyBarTexture, OnUpdate

local function FadeOut(self)
    HideEmpowerSegments(self)
    self:Hide()
    self.isEmpowered = false
    self.txtObj:SetShown(self.cdmShowTimer ~= false)
    self.spellName:SetShown(self.cdmShowSpellName ~= false)

    if IsCastBarPreviewEnabled() then
        ShowPreview(self)
    else
        self:SetScript("OnUpdate", nil)
    end
end

ShowPreview = function(frame)
    if not frame or not frame.cdmEnabled then return end
    if not frame:GetScript("OnUpdate") then
        frame:SetScript("OnUpdate", OnUpdate)
    end

    frame.isPreview = true
    frame.curEndTime = nil

    frame.barObj:SetMinMaxValues(0, 1)
    frame.barObj:SetValue(0.7)
    ApplyBarTexture(frame, CAST_STATE_NORMAL)

    if frame.cdmShowSpellName ~= false then
        frame.spellName:SetText(L["Preview Cast"])
        frame.spellName:Show()
    else
        frame.spellName:Hide()
    end
    if frame.cdmShowTimer ~= false then
        frame.txtObj:SetText("1.5")
        frame.txtObj:Show()
    else
        frame.txtObj:Hide()
    end
    if frame.cdmShowSpark ~= false then
        frame.sparkObj:Show()
    end

    if frame.iconFrame and CfgVal("castBarShowIcon", false) then
        frame.iconFrame.texture:SetTexture(134400) -- question mark icon
        frame.iconFrame:Show()
        SyncCastBarBorderVisual(frame.iconFrame, frame.iconFrame.borderFrame)
    end

    HideEmpowerSegments(frame)
    frame:SetAlpha(1)
    frame:Show()
    SyncCastBarBorderVisual(frame, frame.borderFrame)
end

HidePreview = function(frame)
    if not frame or not frame.isPreview then return end
    frame.isPreview = false
    frame.casting = false
    frame.channeling = false
    frame.castID = nil
    frame:Hide()
end

OnUpdate = function(self)
    if self.isPreview then return end

    if not self.casting and not self.channeling then
        FadeOut(self)
        return
    end

    if self.isEmpowered then
        UpdateEmpowerFill(self)
    end

    if self.cdmShowTimer ~= false then
        local durationObject = self.barObj:GetTimerDuration()
        if durationObject then
            local remaining = durationObject:GetRemainingDuration()
            if CDM.IsSafeNumber(remaining) then
                local tenths = math.floor(remaining * 10 + 0.5)
                if tenths ~= self._cdmLastTimerTenths then
                    self._cdmLastTimerTenths = tenths
                    self.txtObj:SetFormattedText("%.1f", tenths * 0.1)
                end
            end
        end
    end
end

local function ReanchorSpark(frame)
    if not frame.sparkObj then return end
    local fillTexture = frame.barObj:GetStatusBarTexture()
    if fillTexture then
        frame.sparkObj:ClearAllPoints()
        frame.sparkObj:SetPoint("CENTER", fillTexture, "RIGHT", 0, 0)
    end
end

ApplyBarTexture = function(frame, castState)
    local useAtlas = CfgVal("castBarUseAtlasTextures", true)

    if useAtlas then
        if castState == CAST_STATE_NONBREAKABLE then
            frame.barObj:SetStatusBarTexture(ATLAS_NONBREAKABLE)
        elseif castState == CAST_STATE_CHANNEL then
            frame.barObj:SetStatusBarTexture(ATLAS_CHANNEL)
        else
            frame.barObj:SetStatusBarTexture(ATLAS_CAST)
        end
        frame.barObj:SetStatusBarColor(1, 1, 1, 1)
    else
        local textureName = CfgVal("castBarTexture", "Blizzard")
        local texturePath = LSM and LSM:Fetch("statusbar", textureName)
        if texturePath then
            frame.barObj:SetStatusBarTexture(texturePath)
        end

        if castState == CAST_STATE_NORMAL and CfgVal("castBarUseClassColor", false) then
            local r, g, b, a = GetPlayerClassColor()
            if r then
                frame.barObj:SetStatusBarColor(r, g, b, a)
                ReanchorSpark(frame)
                return
            end
        end

        local colorKey
        if castState == CAST_STATE_NONBREAKABLE then
            colorKey = "castBarUninterruptibleColor"
        elseif castState == CAST_STATE_CHANNEL then
            colorKey = "castBarChannelColor"
        else
            colorKey = "castBarCastColor"
        end

        local c = CfgVal(colorKey, nil)
        if c then
            frame.barObj:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        end
    end

    ReanchorSpark(frame)
end

local function FinishCast(frame)
    frame.casting = false
    frame.channeling = false
    frame.castID = nil
    FadeOut(frame)
end

local function RefreshEmpowerTiming(frame)
    local name, _, _, startTime, endTime, _, _, _, isEmpowered, numStages = UnitChannelInfo("player")
    if not name then
        FinishCast(frame)
        return
    end

    if isEmpowered and numStages and numStages > 0 then
        endTime = endTime + (GetUnitEmpowerHoldAtMaxTime("player") or 0)
    end

    frame.curStartTime = startTime / 1000
    frame.curEndTime = endTime / 1000

    local duration = UnitEmpoweredChannelDuration("player")
    if duration then
        frame.barObj:SetTimerDuration(
            duration,
            Enum.StatusBarInterpolation.Immediate,
            Enum.StatusBarTimerDirection.ElapsedTime
        )
    end
end

local function RefreshBarData(frame)
    local name, text, texture, startTime, endTime, notInterruptible, castID
    local isChannel, isEmpowered, numStages

    name, text, texture, startTime, endTime, _, _, notInterruptible, _, castID = UnitCastingInfo("player")
    if name then
        isChannel = false
    else
        name, text, texture, startTime, endTime, _, notInterruptible, _, isEmpowered, numStages, castID = UnitChannelInfo("player")
        if name then
            isChannel = true
        end
    end

    if not name then
        FinishCast(frame)
        return
    end

    if not frame:GetScript("OnUpdate") then
        frame:SetScript("OnUpdate", OnUpdate)
    end

    frame.castID = castID

    if frame.iconFrame and CfgVal("castBarShowIcon", false) then
        frame.iconFrame.texture:SetTexture(texture)
        frame.iconFrame:Show()
        SyncCastBarBorderVisual(frame.iconFrame, frame.iconFrame.borderFrame)
    end

    frame.isPreview = false
    frame.casting = not isChannel
    frame.channeling = isChannel or false
    frame._cdmLastTimerTenths = nil
    frame.isEmpowered = isEmpowered or false
    frame.isReverse = isChannel and not frame.isEmpowered

    if isEmpowered and numStages and numStages > 0 then
        local holdAtMax = GetUnitEmpowerHoldAtMaxTime("player") or 0
        endTime = endTime + holdAtMax

        local percentages = UnitEmpoweredStagePercentages("player")
        if percentages then
            local cumulative = 0
            for i = 1, numStages do
                cumulative = cumulative + (percentages[i] or 0)
                scratchBoundaries[i] = cumulative
            end
            for i = numStages + 1, #scratchBoundaries do scratchBoundaries[i] = nil end
            SetupEmpowerSegments(frame, numStages, scratchBoundaries)
        end
    else
        HideEmpowerSegments(frame)
    end

    frame.curStartTime = startTime / 1000
    frame.curEndTime = endTime / 1000
    frame.cachedWidth = frame:GetWidth()

    local totalDuration = frame.curEndTime - frame.curStartTime
    frame.barObj:SetMinMaxValues(0, totalDuration)

    local duration
    if frame.isEmpowered then
        duration = UnitEmpoweredChannelDuration("player")
    elseif isChannel then
        duration = UnitChannelDuration("player")
    else
        duration = UnitCastingDuration("player")
    end
    if duration then
        local direction = frame.isReverse
            and Enum.StatusBarTimerDirection.RemainingTime
            or Enum.StatusBarTimerDirection.ElapsedTime
        frame.barObj:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
    end

    local castState
    if notInterruptible then
        castState = CAST_STATE_NONBREAKABLE
    elseif isChannel and not isEmpowered then
        castState = CAST_STATE_CHANNEL
    else
        castState = CAST_STATE_NORMAL
    end
    ApplyBarTexture(frame, castState)

    if frame.isEmpowered then
        frame.barObj:SetStatusBarColor(0, 0, 0, 0)
    end

    if frame.cdmShowSpellName ~= false then
        local displayName = text or name
        local mc = frame.cdmNameMaxChars
        if mc and mc > 0 and displayName and #displayName > mc then
            displayName = displayName:sub(1, mc) .. "..."
        end
        frame.spellName:SetText(displayName)
        frame.spellName:Show()
    else
        frame.spellName:Hide()
    end

    if frame.cdmShowTimer ~= false then
        frame.txtObj:Show()
    else
        frame.txtObj:Hide()
    end

    frame:SetAlpha(1)
    frame:Show()
    SyncCastBarBorderVisual(frame, frame.borderFrame)

    if frame.isEmpowered then
        UpdateEmpowerFill(frame)
    end
end

local function ApplyCastBarIconLayout(frame)
    if not frame or not frame.iconFrame then return end

    local container = frame:GetParent()
    local showIcon = CfgVal("castBarShowIcon", false)

    if not showIcon then
        frame.iconFrame:Hide()
        frame:ClearAllPoints()
        frame:SetAllPoints(container)
        frame.cachedWidth = container:GetWidth()
        return
    end

    local position = CfgVal("castBarIconPosition", "LEFT")
    local gap = Snap(CfgVal("castBarIconGap", 1))
    local containerW = container:GetWidth()
    local containerH = container:GetHeight()

    local iconSize = containerH
    local barWidth = containerW - iconSize - gap
    if barWidth < 1 then barWidth = 1 end

    local iconFrame = frame.iconFrame
    iconFrame:ClearAllPoints()
    iconFrame:SetSize(iconSize, iconSize)

    frame:ClearAllPoints()

    if position == "RIGHT" then
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -(iconSize + gap), 0)
        iconFrame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    else -- LEFT (default)
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", iconSize + gap, 0)
        frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        iconFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    end

    frame.cachedWidth = barWidth

    iconFrame.texture:ClearAllPoints()
    iconFrame.texture:SetAllPoints()
    iconFrame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    if iconFrame.borderFrame and CDM.BORDER and CDM.BORDER.UpdateBorder then
        CDM.BORDER:UpdateBorder(iconFrame.borderFrame)
    end

    iconFrame:Show()
    SyncCastBarBorderVisual(iconFrame, iconFrame.borderFrame)
end

local function UpdateCastBarFromConfig(frame)
    if not frame then return end

    local w = GetCastBarWidth()
    local h = CfgVal("castBarHeight", 20)

    CDM_C.RefreshBaseFontCache()
    local fontPath = CDM_C.GetBaseFontPath()
    local fontOutline = CDM_C.GetBaseFontOutline()
    local fontSize = Pixel.FontSize(CfgVal("castBarFontSize", 15))

    frame.spellName:SetFont(fontPath, fontSize, fontOutline)
    frame.spellName:ClearAllPoints()
    Pixel.SetPoint(frame.spellName, "LEFT", frame, "LEFT", CfgVal("castBarNameOffsetX", 2), CfgVal("castBarNameOffsetY", 4))

    frame.timeText:SetFont(fontPath, fontSize, fontOutline)
    frame.timeText:ClearAllPoints()
    Pixel.SetPoint(frame.timeText, "RIGHT", frame, "RIGHT", CfgVal("castBarTimerOffsetX", -2), CfgVal("castBarTimerOffsetY", 4))

    local showName = CfgVal("castBarShowSpellName", true)
    frame.cdmShowSpellName = showName
    frame.cdmNameMaxChars = CfgVal("castBarNameMaxChars", 0)
    frame.spellName:SetShown(showName)

    local showTimer = CfgVal("castBarShowTimer", true)
    frame.cdmShowTimer = showTimer
    frame.timeText:SetShown(showTimer)

    local useAtlas = CfgVal("castBarUseAtlasTextures", true)

    local showSpark = CfgVal("castBarShowSpark", true)
    frame.cdmShowSpark = showSpark
    frame.sparkObj:SetShown(showSpark)

    if useAtlas then
        frame.sparkObj:SetTexture(SPARK_TEXTURE)
        frame.sparkObj:SetTexCoord(0.222168, 0.232422, 0.294434, 0.317383)
        frame.sparkObj:SetDesaturated(true)
        frame.sparkObj:SetVertexColor(1, 1, 1, 1)
        frame.sparkObj:SetSize(16, Snap(h * 2.1))
    else
        frame.sparkObj:SetTexture(CDM_C.TEX_WHITE8X8)
        frame.sparkObj:SetTexCoord(0, 1, 0, 1)
        frame.sparkObj:SetDesaturated(false)
        frame.sparkObj:SetVertexColor(1, 1, 1, 0.8)
        frame.sparkObj:SetSize(Snap(2), Snap(h))
    end

    if useAtlas then
        frame.bgTexture:SetTexture(CASTBAR_BG_TEXTURE)
        frame.bgTexture:SetVertexColor(1, 1, 1, 1)
    else
        local bgTextureName = CfgVal("castBarBackgroundTexture", "Blizzard")
        local bgTexturePath = LSM and LSM:Fetch("statusbar", bgTextureName)
        if bgTexturePath then
            frame.bgTexture:SetTexture(bgTexturePath)
        end
        local bgColor = CfgVal("castBarBackgroundColor", DEFAULT_BG_COLOR)
        frame.bgTexture:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.8)
    end

    if frame.borderFrame and CDM.BORDER and CDM.BORDER.UpdateBorder then
        CDM.BORDER:UpdateBorder(frame.borderFrame)
    end

    SyncCastBarBorderVisual(frame, frame.borderFrame)

    ApplyCastBarIconLayout(frame)
end

local function UpdateContainerPosition()
    local container = CDM.castBarContainer
    if not container then return end

    local target, aP, tP, oX, oY, isFallback = ResolveCastBarAnchor()

    container:ClearAllPoints()
    if target == CAST_ANCHOR_PLAYER_FRAME then
        CDM.AnchorToPlayerFrame(container, tP, oX, oY, "PlayerCastBar", true, aP)
        return
    end

    if isFallback then
        aP = "BOTTOM"
        tP = "CENTER"
    end

    if target == UIParent then
        local halfW = Pixel.HalfFloor(container:GetWidth() or 0)
        local leftAP = (aP == "CENTER" and "LEFT")
            or (aP == "TOP" and "TOPLEFT")
            or (aP == "BOTTOM" and "BOTTOMLEFT")
            or aP
        Pixel.SetPoint(container, leftAP, UIParent, tP, oX - halfW, oY)
    else
        Pixel.SetPoint(container, aP, target, tP, oX, oY)
    end
end

local function UpdatePreviewState()
    local frame = CDM.castBarFrame
    if not frame or not frame.cdmEnabled then return end
    if IsCastBarPreviewEnabled() then
        ShowPreview(frame)
    elseif frame.isPreview then
        HidePreview(frame)
    end
end

local castBarEvents = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
}

local blizzardCastBarDisabled = false

local function EnableCastBar(frame)
    for _, event in ipairs(castBarEvents) do
        frame:RegisterUnitEvent(event, "player")
    end
    frame:SetScript("OnUpdate", OnUpdate)
    frame.cdmEnabled = true

    if CDM.castBarContainer then
        CDM.castBarContainer:Show()
    end
end

local function DisableCastBar(frame)
    for _, event in ipairs(castBarEvents) do
        frame:UnregisterEvent(event)
    end
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    frame.casting = false
    frame.channeling = false
    frame.isEmpowered = false
    frame.castID = nil
    HideEmpowerSegments(frame)
    frame.cdmEnabled = false

    if CDM.castBarContainer then
        CDM.castBarContainer:Hide()
    end
end

function CDM:DisableBlizzardPlayerCastBar()
    if blizzardCastBarDisabled then
        return true
    end
    if not CfgVal("hideBlizzardCastBar", false) or not PlayerCastingBarFrame then
        return false
    end

    PlayerCastingBarFrame:UnregisterAllEvents()
    PlayerCastingBarFrame:Hide()

    -- Prevent other addons (oUF, EllesmereUI, etc.) from re-registering events
    hooksecurefunc(PlayerCastingBarFrame, "RegisterEvent", function(self)
        if blizzardCastBarDisabled then
            self:UnregisterAllEvents()
        end
    end)
    hooksecurefunc(PlayerCastingBarFrame, "RegisterUnitEvent", function(self)
        if blizzardCastBarDisabled then
            self:UnregisterAllEvents()
        end
    end)
    hooksecurefunc(PlayerCastingBarFrame, "Show", function(self)
        if blizzardCastBarDisabled then
            self:Hide()
        end
    end)

    blizzardCastBarDisabled = true
    return true
end

function CDM:InitializePlayerCastBar()
    if self.castBarFrame then return end

    local container = CreateFrame("Frame", "Ayije_CDM_CastBarContainer", UIParent)
    container:SetClampedToScreen(true)

    self.castBarContainer = container

    local f = CreateFrame("Frame", "Ayije_CastBar", container)
    f:SetAllPoints(container)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)

    local iconFrame = CreateFrame("Frame", nil, f)
    iconFrame:SetFrameStrata("MEDIUM")
    iconFrame:SetFrameLevel(10)
    iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.texture:SetAllPoints()
    Pixel.DisableTextureSnap(iconFrame.texture)
    iconFrame.borderFrame = CreateFrame("Frame", nil, iconFrame)
    iconFrame.borderFrame:SetAllPoints()
    iconFrame.borderFrame:SetFrameLevel(12)
    if CDM.BORDER and CDM.BORDER.CreateBorder then
        CDM.BORDER:CreateBorder(iconFrame.borderFrame)
    end
    iconFrame:Hide()
    f.iconFrame = iconFrame

    f.bgTexture = f:CreateTexture(nil, "BACKGROUND")
    f.bgTexture:SetAllPoints()
    Pixel.DisableTextureSnap(f.bgTexture)
    f.bgTexture:SetTexture(CASTBAR_BG_TEXTURE)

    f.castBar = CreateFrame("StatusBar", nil, f)
    f.castBar:SetAllPoints()
    f.castBar:SetStatusBarTexture(ATLAS_CAST)
    f.castBar:SetFrameLevel(11)
    f.barObj = f.castBar

    f.stageFrame = CreateFrame("Frame", nil, f)
    f.stageFrame:SetAllPoints()
    f.stageFrame:SetFrameLevel(11)

    f.topOverlay = CreateFrame("Frame", nil, f)
    f.topOverlay:SetAllPoints()
    f.topOverlay:SetFrameLevel(15)

    local fontPath = CDM_C.FONT_PATH
    local fontOutline = CDM_C.FONT_OUTLINE or "OUTLINE"
    local fontSize = Pixel.FontSize(15)

    f.spellName = f.topOverlay:CreateFontString(nil, "OVERLAY")
    f.spellName:SetIgnoreParentScale(true)
    f.spellName:SetFont(fontPath, fontSize, fontOutline)
    f.spellName:SetPoint("LEFT", 4, 0)

    f.timeText = f.topOverlay:CreateFontString(nil, "OVERLAY")
    f.timeText:SetIgnoreParentScale(true)
    f.timeText:SetFont(fontPath, fontSize, fontOutline)
    f.timeText:SetPoint("RIGHT", -4, 0)
    f.txtObj = f.timeText

    f.spark = f.topOverlay:CreateTexture(nil, "ARTWORK")
    f.spark:SetTexture(SPARK_TEXTURE)
    f.spark:SetSize(16, 42)
    f.spark:SetTexCoord(0.222168, 0.232422, 0.294434, 0.317383)
    f.spark:SetDesaturated(true)
    f.spark:SetVertexColor(1, 1, 1, 1)
    f.sparkObj = f.spark

    local fillTexture = f.barObj:GetStatusBarTexture()
    if fillTexture then
        f.sparkObj:SetPoint("CENTER", fillTexture, "RIGHT", 0, 0)
    else
        f.sparkObj:SetPoint("CENTER", f.topOverlay, "LEFT", 0, 0)
    end

    f.borderFrame = CreateFrame("Frame", nil, f)
    f.borderFrame:SetAllPoints()
    f.borderFrame:SetFrameLevel(12)
    if CDM.BORDER and CDM.BORDER.CreateBorder then
        CDM.BORDER:CreateBorder(f.borderFrame)
    end

    f:SetScript("OnEvent", function(frame, event, unit, a, b, c, d, e)
        if event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_EMPOWER_START" then
            RefreshBarData(frame)

        elseif event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            FinishCast(frame)

        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            -- (unit, castGUID, spellID, interruptedBy, castBarID) -> d = castBarID
            if frame.castID and d and frame.castID ~= d then return end
            FinishCast(frame)

        elseif event == "UNIT_SPELLCAST_DELAYED" then
            RefreshBarData(frame)

        elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
            or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
            if frame.isEmpowered then
                RefreshEmpowerTiming(frame)
                UpdateEmpowerFill(frame)
            else
                RefreshBarData(frame)
            end

        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE"
            or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            if frame.curEndTime then
                local isChannel = frame.channeling
                local notInterruptible = (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
                local castState
                if notInterruptible then
                    castState = CAST_STATE_NONBREAKABLE
                elseif isChannel and not frame.isEmpowered then
                    castState = CAST_STATE_CHANNEL
                else
                    castState = CAST_STATE_NORMAL
                end
                ApplyBarTexture(frame, castState)
                if frame.isEmpowered then
                    frame.barObj:SetStatusBarColor(0, 0, 0, 0)
                end
            end
        end
    end)

    self.castBarFrame = f
    f:Hide()

    local w = GetCastBarWidth()
    local h = CfgVal("castBarHeight", 20)
    Pixel.SetSize(container, w, h)
    UpdateContainerPosition()
    UpdateCastBarFromConfig(f)

    if CfgVal("castBarEnabled", true) then
        EnableCastBar(f)
    end

    UpdatePreviewState()
end

function CDM:UpdatePlayerCastBar()
    if not self.castBarFrame then
        if CfgVal("castBarEnabled", true) then
            self:InitializePlayerCastBar()
        end
        if not self.castBarFrame then return end
    end

    local enabled = CfgVal("castBarEnabled", true)
    if enabled and not self.castBarFrame.cdmEnabled then
        EnableCastBar(self.castBarFrame)
    elseif not enabled and self.castBarFrame.cdmEnabled then
        DisableCastBar(self.castBarFrame)
    end

    if not self.castBarFrame.cdmEnabled then return end

    if self.castBarContainer then
        local w = GetCastBarWidth()
        local h = CfgVal("castBarHeight", 20)
        Pixel.SetSize(self.castBarContainer, w, h)
    end

    UpdateCastBarFromConfig(self.castBarFrame)
    UpdateContainerPosition()
    UpdatePreviewState()
end

CDM:RegisterRefreshCallback("playerCastBar", function()
    CDM:UpdatePlayerCastBar()
end, 55, { "STYLE", "LAYOUT" })

CDM.ResolveResourcesAnchor = ResolveResourcesAnchor
