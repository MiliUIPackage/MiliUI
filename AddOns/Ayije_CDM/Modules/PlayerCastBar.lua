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

local IsPixelBorderMode = Pixel.IsOneBorderMode

local function EnsureManualPixelBorder(target)
    if not target then return nil, nil end
    if target.cdmManualPixelBorderOverlay and target.cdmManualPixelBorderLines then
        return target.cdmManualPixelBorderOverlay, target.cdmManualPixelBorderLines
    end

    local overlay = CreateFrame("Frame", nil, target)
    overlay:SetAllPoints(target)
    overlay:SetFrameStrata(target:GetFrameStrata())
    overlay:SetFrameLevel((target:GetFrameLevel() or 0) + 4)

    local lines = {}
    for i = 1, 4 do
        lines[i] = Pixel.CreateSolidTexture(overlay, "OVERLAY", 6)
    end

    target.cdmManualPixelBorderOverlay = overlay
    target.cdmManualPixelBorderLines = lines
    return overlay, lines
end

local function HideManualPixelBorder(target)
    if target and target.cdmManualPixelBorderOverlay then
        target.cdmManualPixelBorderOverlay:Hide()
    end
end

local function ApplyManualPixelBorder(target)
    if not target or not target:IsShown() then
        HideManualPixelBorder(target)
        return
    end

    if not IsPixelBorderMode() then
        HideManualPixelBorder(target)
        return
    end

    local overlay, lines = EnsureManualPixelBorder(target)
    if not overlay or not lines then
        return
    end

    overlay:SetAllPoints(target)
    overlay:SetFrameStrata(target:GetFrameStrata())
    overlay:SetFrameLevel((target:GetFrameLevel() or 0) + 4)
    overlay:Show()

    local color = CfgVal("borderColor", { r = 1, g = 1, b = 1, a = 1 })
    local onePx = Pixel.GetSize()
    local px = math.max(1, math.floor((CfgVal("borderSize", 1) or 1) / onePx)) * onePx

    local top = lines[1]
    local bottom = lines[2]
    local left = lines[3]
    local right = lines[4]

    for _, line in ipairs(lines) do
        line:SetVertexColor(color.r, color.g, color.b, color.a or 1)
        line:Show()
    end

    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", overlay, "TOPLEFT", px, 0)
    top:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -px, 0)
    top:SetHeight(px)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", px, 0)
    bottom:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -px, 0)
    bottom:SetHeight(px)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
    left:SetWidth(px)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(px)
end

local function SyncCastBarBorderVisual(target, borderHost)
    if borderHost and borderHost.border then
        borderHost.border:SetShown(not IsPixelBorderMode())
    end
    ApplyManualPixelBorder(target)
end

local function IsCastBarResourceAnchorEnabled()
    return CfgVal("castBarAnchorToResources", false) and CDM.db and CDM.db.resourcesEnabled ~= false
end

local function IsCastBarContainerLocked()
    return IsCastBarResourceAnchorEnabled() or CfgVal("castBarContainerLocked", true)
end

local EMPOWER_WINDUP_DEFAULT = { r = 0.45, g = 0.45, b = 0.55, a = 1 }
local EMPOWER_DEFAULT_COLORS = {
    { r = 0.26, g = 0.65, b = 1.0, a = 1 },   -- Stage 1: Blue
    { r = 0.26, g = 0.90, b = 0.55, a = 1 },   -- Stage 2: Green
    { r = 1.0, g = 0.80, b = 0.0, a = 1 },     -- Stage 3: Gold
    { r = 1.0, g = 0.35, b = 0.0, a = 1 },     -- Stage 4: Orange
}
local EMPOWER_FILL_EPSILON = 0.001
local EMPOWER_BOUNDARY_EPSILON = 0.001

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

    local borderColor = CfgVal("borderColor", { r = 1, g = 1, b = 1, a = 1 })
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

local function SetupEmpowerSegments(frame, numStages, boundaries)
    frame.empowerStageData = frame.empowerStageData or {}
    local barWidth = frame.cachedWidth or frame:GetWidth()
    local barHeight = frame:GetHeight()
    local useAtlas = CfgVal("castBarUseAtlasTextures", true)

    local lsmTexturePath
    if not useAtlas then
        local textureName = CfgVal("castBarTexture", "Blizzard")
        lsmTexturePath = LSM and LSM:Fetch("statusbar", textureName)
    end

    local function ApplyStageTexture(bar)
        if useAtlas then
            bar:SetStatusBarTexture(ATLAS_CAST)
            local tex = bar:GetStatusBarTexture()
            if tex then tex:SetDesaturated(true) end
        else
            if lsmTexturePath then
                bar:SetStatusBarTexture(lsmTexturePath)
            else
                bar:SetStatusBarTexture(CDM_C.TEX_WHITE8X8)
            end
        end
    end

    local function ConfigureStage(index, startPct, endPct, color)
        local stage = frame.empowerStageData[index]
        if not stage then
            local bar = CreateFrame("StatusBar", nil, frame.stageFrame)
            bar:SetFrameLevel(frame.stageFrame:GetFrameLevel())
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            stage = { bar = bar }
            frame.empowerStageData[index] = stage
        end

        stage.startPct = startPct
        stage.endPct = endPct
        local onePixel = Pixel.GetSize()
        stage.fullWidth = math.max(onePixel, Snap((endPct - startPct) * barWidth))

        local bar = stage.bar
        bar:ClearAllPoints()
        Pixel.SetPoint(bar, "TOPLEFT", frame.stageFrame, "TOPLEFT", startPct * barWidth, 0)
        bar:SetSize(stage.fullWidth, barHeight)
        ApplyStageTexture(bar)
        bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
        bar:SetValue(0)
        bar:Show()
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

local ShowPreview, HidePreview, ApplyBarTexture

local function FadeOut(self)
    if self.isFading then return end

    self.isFading = true
    self.fadeStart = GetTime()

    HideEmpowerSegments(self)
end

local function UpdateFade(self)
    if not self.isFading then return end

    local elapsed = GetTime() - self.fadeStart

    if elapsed >= 0.2 then
        self:SetAlpha(0)
        self:Hide()
        self.isFading = false
        self.isEmpowered = false
        self:SetAlpha(1)
        self.txtObj:SetShown(self.cdmShowTimer ~= false)
        self.spellName:SetShown(self.cdmShowSpellName ~= false)

        if not IsCastBarContainerLocked() then
            ShowPreview(self)
        else
            self:SetScript("OnUpdate", nil)
        end
        return
    end

    self:SetAlpha(1 - (elapsed / 0.2))
end

ShowPreview = function(frame)
    if not frame or not frame.cdmEnabled then return end
    if not frame:GetScript("OnUpdate") then
        frame:SetScript("OnUpdate", OnUpdate)
    end

    frame.isFading = false

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
    frame.isFading = false
    frame.casting = false
    frame.channeling = false
    frame:Hide()
end

local function OnUpdate(self)
    UpdateFade(self)
    if self.isFading or self.isPreview then return end

    if not self.casting and not self.channeling then
        FadeOut(self)
        return
    end

    local now = GetTime()
    local endTime = self.curEndTime
    if not endTime then return end

    if now >= endTime then
        FadeOut(self)
        return
    end

    local totalDuration = endTime - self.curStartTime
    if totalDuration <= 0 then return end
    local displayValue = self.isReverse and (endTime - now) or (now - self.curStartTime)

    self.barObj:SetValue(displayValue)

    if self.isEmpowered then
        UpdateEmpowerFill(self)
    end

    if self.cdmShowTimer ~= false then
        local remaining = endTime - now
        local displayTenth = remaining > 0 and math.floor(remaining * 10) or 0
        if displayTenth ~= self._lastTimerTenth then
            self._lastTimerTenth = displayTenth
            self.txtObj:SetFormattedText("%.1f", remaining)
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
                frame.currentCastState = castState
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

    frame.currentCastState = castState
    ReanchorSpark(frame)
end

local function FinishCast(frame)
    frame.casting = false
    frame.channeling = false
    frame.currentCastID = nil
    if frame.isFading then return end
    FadeOut(frame)
end

local function IsMatchingCast(frame, castID)
    return frame.currentCastID == nil or castID == frame.currentCastID
end

local function RefreshBarData(frame, isChannel)
    if not frame:GetScript("OnUpdate") then
        frame:SetScript("OnUpdate", OnUpdate)
    end

    local name, text, texture, startTime, endTime, _, notInterruptible
    local isEmpowered, numStages

    if isChannel then
        name, text, texture, startTime, endTime, _, notInterruptible, _, isEmpowered, numStages = UnitChannelInfo("player")
    else
        name, text, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo("player")
    end

    if not name then return end

    if frame.iconFrame and CfgVal("castBarShowIcon", false) then
        frame.iconFrame.texture:SetTexture(texture)
        frame.iconFrame:Show()
        SyncCastBarBorderVisual(frame.iconFrame, frame.iconFrame.borderFrame)
    end

    frame.isPreview = false
    frame.castSucceeded = false
    frame.casting = not isChannel
    frame.channeling = isChannel or false
    frame.isEmpowered = isEmpowered or false
    frame.isReverse = isChannel and not frame.isEmpowered

    if isEmpowered and numStages and numStages > 0 then
        local holdAtMax = GetUnitEmpowerHoldAtMaxTime("player") or 0
        local stageTotal = 0
        local boundaries = {}
        for i = 0, numStages - 1 do
            local stageDur = GetUnitEmpowerStageDuration("player", i) or 0
            if stageDur < 0 then stageDur = 0 end
            stageTotal = stageTotal + stageDur
            boundaries[i + 1] = stageTotal
        end

        local totalDuration = stageTotal + holdAtMax
        if totalDuration <= 0 then
            totalDuration = (endTime - startTime) + holdAtMax
        end
        if totalDuration <= 0 then
            totalDuration = 1
        end

        local boundaryCount = #boundaries
        for i = 1, boundaryCount do
            local pct = boundaries[i] / totalDuration
            if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end

            local minPct = (i == 1) and 0 or (boundaries[i - 1] + EMPOWER_BOUNDARY_EPSILON)
            local maxPct = 1 - ((boundaryCount - i) * EMPOWER_BOUNDARY_EPSILON)
            if maxPct < minPct then
                maxPct = minPct
            end
            if pct < minPct then
                pct = minPct
            elseif pct > maxPct then
                pct = maxPct
            end
            boundaries[i] = pct
        end

        endTime = startTime + totalDuration
        SetupEmpowerSegments(frame, numStages, boundaries)
    else
        HideEmpowerSegments(frame)
    end

    frame.curStartTime = startTime / 1000
    frame.curEndTime = endTime / 1000
    frame.cachedWidth = frame:GetWidth()

    local totalDuration = frame.curEndTime - frame.curStartTime
    frame.barObj:SetMinMaxValues(0, totalDuration)
    local now = GetTime()
    local initialValue = frame.isReverse and (frame.curEndTime - now) or (now - frame.curStartTime)
    initialValue = math.max(0, math.min(totalDuration, initialValue))
    frame.barObj:SetValue(initialValue)

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

    frame._lastTimerTenth = nil
    frame.isFading = false
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

    local min = CDM_C.ICON_TEXCOORD_MIN or 0.08
    local max = CDM_C.ICON_TEXCOORD_MAX or 0.92
    iconFrame.texture:ClearAllPoints()
    iconFrame.texture:SetAllPoints()
    iconFrame.texture:SetTexCoord(min, max, min, max)

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
        local bgColor = CfgVal("castBarBackgroundColor", { r = 0.15, g = 0.15, b = 0.15, a = 0.8 })
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

    local HalfFloor = Pixel.HalfFloor
    local halfW = HalfFloor(container:GetWidth() or 0)

    local anchorToResources = IsCastBarResourceAnchorEnabled()
    if anchorToResources and CDM.resourceContainer then
        local spacing = CfgVal("castBarResourcesSpacing", 2)
        container:ClearAllPoints()

        if CDM.currentPowerTypes and #CDM.currentPowerTypes > 0 then
            local resHalfW = HalfFloor(CDM.resourceContainer:GetWidth() or 0)
            Pixel.SetPoint(container, "BOTTOMLEFT", CDM.resourceContainer, "TOPLEFT", resHalfW - halfW, spacing)
            return
        end

        Pixel.SetPoint(container, "BOTTOMLEFT", CDM.resourceContainer, "BOTTOMLEFT", HalfFloor(CDM.resourceContainer:GetWidth() or 0) - halfW, 0)
        return
    end

    local offsetX = CfgVal("castBarOffsetX", 0)
    local offsetY = CfgVal("castBarOffsetY", -166)

    container:ClearAllPoints()
    Pixel.SetPoint(container, "BOTTOMLEFT", UIParent, "CENTER", offsetX - halfW, offsetY)
end

local function UpdateContainerLockState()
    local container = CDM.castBarContainer
    if not container then return end

    local locked = IsCastBarContainerLocked()

    container:SetMovable(not locked)
    container:EnableMouse(not locked)

    if container.helperText then
        container.helperText:SetShown(not locked)
    end
    if container.dragOverlay then
        container.dragOverlay:SetShown(not locked)
    end

    local frame = CDM.castBarFrame
    if frame and frame.cdmEnabled then
        if not locked then
            ShowPreview(frame)
        else
            HidePreview(frame)
        end
    end
end

local castBarEvents = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET",
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
    frame.isFading = false
    frame.isEmpowered = false
    frame.castSucceeded = false
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

    -- This is intentionally one-way for the current session; reloading restores Blizzard defaults.
    PlayerCastingBarFrame:UnregisterAllEvents()
    blizzardCastBarDisabled = true
    return true
end

function CDM:InitializePlayerCastBar()
    if self.castBarFrame then return end

    local container = CreateFrame("Frame", "Ayije_CDM_CastBarContainer", UIParent)
    container:SetClampedToScreen(true)
    container:RegisterForDrag("LeftButton")

    container:SetScript("OnDragStart", function(c)
        local locked = IsCastBarContainerLocked()
        if not InCombatLockdown() and not locked then
            c:StartMoving()
        end
    end)

    container:SetScript("OnDragStop", function(c)
        c:StopMovingOrSizing()

        local cx, cy = c:GetCenter()
        local ux, uy = UIParent:GetCenter()
        local halfH = c:GetHeight() / 2
        if cx and ux then
            local db = CDM.db
            if db then
                db.castBarOffsetX = math.floor(cx - ux + 0.5)
                db.castBarOffsetY = math.floor(cy - halfH - uy + 0.5)
                CDM:NotifyCastBarSliderUpdate(db.castBarOffsetX, db.castBarOffsetY)
            end
        end

        UpdateContainerPosition()
    end)

    local helperText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helperText:SetPoint("BOTTOM", container, "TOP", 0, 8)
    helperText:SetText(L["Click and drag to move - /cdm > Cast Bar to lock"])
    helperText:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
    CDM_C.ApplyShadow(helperText)
    helperText:Hide()
    container.helperText = helperText

    local overlay = CreateFrame("Frame", nil, container, "NineSliceCodeTemplate")
    overlay:SetAllPoints(container)
    overlay:SetFrameStrata("MEDIUM")
    overlay:SetFrameLevel(100)
    overlay:EnableMouse(false)

    if NineSliceUtil and NineSliceUtil.ApplyLayout then
        local overlayLayout = {
            ["TopRightCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
            ["TopLeftCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
            ["BottomLeftCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
            ["BottomRightCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
            ["TopEdge"] = { atlas = "_%s-NineSlice-EdgeTop" },
            ["BottomEdge"] = { atlas = "_%s-NineSlice-EdgeBottom" },
            ["LeftEdge"] = { atlas = "!%s-NineSlice-EdgeLeft" },
            ["RightEdge"] = { atlas = "!%s-NineSlice-EdgeRight" },
            ["Center"] = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
        }
        NineSliceUtil.ApplyLayout(overlay, overlayLayout, "editmode-actionbar-highlight")
        local regions = { overlay:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region.SetBlendMode then region:SetBlendMode("ADD") end
        end
        overlay:SetAlpha(0.4)
    end

    overlay:Hide()
    container.dragOverlay = overlay

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
    iconFrame.borderFrame = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
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

    f.borderFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.borderFrame:SetAllPoints()
    f.borderFrame:SetFrameLevel(12)
    if CDM.BORDER and CDM.BORDER.CreateBorder then
        CDM.BORDER:CreateBorder(f.borderFrame)
    end

    f:SetScript("OnEvent", function(frame, event, unit, castID, spellID, arg4)
        if event == "UNIT_SPELLCAST_START" then
            frame.currentCastID = castID
            RefreshBarData(frame, false)

        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if IsMatchingCast(frame, castID) then
                frame.castSucceeded = true
            end

        elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
            frame.currentCastID = castID
            RefreshBarData(frame, true)

        elseif event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            if IsMatchingCast(frame, castID) then
                FinishCast(frame)
            end

        elseif event == "UNIT_SPELLCAST_FAILED" then
            if frame.casting and not frame.castSucceeded and IsMatchingCast(frame, castID) then
                FinishCast(frame)
            end

        elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
            if frame.casting and not frame.castSucceeded and IsMatchingCast(frame, castID) then
                if not UnitCastingInfo("player") and not UnitChannelInfo("player") then
                    FinishCast(frame)
                end
            end

        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            if IsMatchingCast(frame, castID) then
                FinishCast(frame)
            end

        elseif event == "UNIT_SPELLCAST_DELAYED" then
            RefreshBarData(frame, false)

        elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
            or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
            if frame.isEmpowered then
                UpdateEmpowerFill(frame)
            else
                RefreshBarData(frame, true)
            end

        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE"
            or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
                    if not frame.isFading and frame.curEndTime then
                local isChannel = frame.channeling
                local notInterruptible = (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
                local castState
                if notInterruptible then
                    castState = CAST_STATE_NONBREAKABLE
                elseif isChannel then
                    castState = CAST_STATE_CHANNEL
                else
                    castState = CAST_STATE_NORMAL
                end
                ApplyBarTexture(frame, castState)
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

    UpdateContainerLockState()
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
    UpdateContainerLockState()
end

CDM:RegisterRefreshCallback("playerCastBar", function()
    CDM:UpdatePlayerCastBar()
end, 55, { "castbar_visuals", "resources_visuals", "trackers_layout", "viewers" })
