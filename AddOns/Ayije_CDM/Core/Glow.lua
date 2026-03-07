local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS

local LCG = LibStub("LibCustomGlow-1.0", true)

CDM.Glow = CDM.Glow or {}
local Glow = CDM.Glow

local GLOW_KEY = "CDM_SpellAlert"
local activeGlowFrames = setmetatable({}, { __mode = "k" })
local pendingHideFrames = setmetatable({}, { __mode = "k" })
local buffPendingStopFrames = setmetatable({}, { __mode = "k" })
local buffHookedFrames = setmetatable({}, { __mode = "k" })
local HideCustomGlow

local BUFF_GLOW_HIDE_GRACE = 0

local debounceDrainer = CreateFrame("Frame")
debounceDrainer:Hide()
debounceDrainer:SetScript("OnUpdate", function(self)
    self:Hide()
    for frame in pairs(pendingHideFrames) do
        pendingHideFrames[frame] = nil
        HideCustomGlow(frame)
    end
end)

local buffStopDrainer = CreateFrame("Frame")
buffStopDrainer:Hide()

local function IsSupportedViewerName(name)
    return name == VIEWERS.ESSENTIAL or name == VIEWERS.UTILITY
end

local function ColorsMatch(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return a.r == b.r and a.g == b.g and a.b == b.b
end

local glowCache = {
    type = "proc",
    useCustomColor = false,
    color = nil,
    pixelLines = 8,
    pixelFrequency = 0.2,
    pixelLength = 0,
    pixelThickness = 2,
    pixelXOffset = 0,
    pixelYOffset = 0,
    pixelBorder = false,
    autocastParticles = 4,
    autocastFrequency = 0.2,
    autocastScale = 1,
    autocastXOffset = 0,
    autocastYOffset = 0,
    buttonFrequency = 0,
    procDuration = 1,
    procXOffset = 0,
    procYOffset = 0,
}

local glowColorArrayCache = setmetatable({}, { __mode = "k" })

local function GetCachedGlowColorArray(color)
    if type(color) ~= "table" then
        return nil
    end

    local arr = glowColorArrayCache[color]
    if not arr then
        arr = { 1, 1, 1, 1 }
        glowColorArrayCache[color] = arr
    end

    arr[1] = color.r or 1
    arr[2] = color.g or 1
    arr[3] = color.b or 1
    arr[4] = color.a or 1
    return arr
end

local function GetViewerName(frame)
    if not frame then return nil end

    local frameData = CDM.GetFrameData(frame)
    if frameData.cdmViewerName then
        return frameData.cdmViewerName
    end
    if frameData.cdmViewerNameChecked then
        return nil
    end

    local result
    if frame.GetViewerFrame then
        local viewer = frame:GetViewerFrame()
        if viewer and viewer.GetName then
            result = viewer:GetName()
        end
    end

    if not result then
        local parent = frame.GetParent and frame:GetParent()
        while parent do
            if parent.GetName then
                local name = parent:GetName()
                if IsSupportedViewerName(name) then
                    result = name
                    break
                end
            end
            parent = parent.GetParent and parent:GetParent()
        end
    end

    frameData.cdmViewerNameChecked = true
    if result then
        frameData.cdmViewerName = result
    end
    return result
end

local function IsSupportedGlowFrame(frame)
    local viewerName = GetViewerName(frame)
    return IsSupportedViewerName(viewerName)
end

local function HideBlizzardGlow(frame)
    if not frame then return end
    local alert = frame.SpellActivationAlert
    if not alert then return end
    alert:SetAlpha(0)
    alert:Hide()
end

local function GetGlowColor(overrideColor)
    if overrideColor then
        return GetCachedGlowColorArray(overrideColor)
    end
    if glowCache.useCustomColor and glowCache.color then
        return GetCachedGlowColorArray(glowCache.color)
    end
    return nil
end

local procGlowOpts = {
    color = nil,
    startAnim = false,
    duration = 1,
    xOffset = 0,
    yOffset = 0,
    key = GLOW_KEY,
    frameLevel = 0,
}

local activeGlowSnapshot = {}

local glowStartFunctions = {
    pixel = function(frame, frameLevel, overrideColor)
        local color = GetGlowColor(overrideColor)
        local length = glowCache.pixelLength
        if length == 0 then length = nil end
        LCG.PixelGlow_Start(
            frame,
            color,
            glowCache.pixelLines,
            glowCache.pixelFrequency,
            length,
            glowCache.pixelThickness,
            glowCache.pixelXOffset,
            glowCache.pixelYOffset,
            glowCache.pixelBorder,
            GLOW_KEY,
            frameLevel
        )
    end,

    autocast = function(frame, frameLevel, overrideColor)
        local color = GetGlowColor(overrideColor)
        LCG.AutoCastGlow_Start(
            frame,
            color,
            glowCache.autocastParticles,
            glowCache.autocastFrequency,
            glowCache.autocastScale,
            glowCache.autocastXOffset,
            glowCache.autocastYOffset,
            GLOW_KEY,
            frameLevel
        )
    end,

    button = function(frame, frameLevel, overrideColor)
        local color = GetGlowColor(overrideColor)
        local freq = glowCache.buttonFrequency
        if freq == 0 then freq = nil end
        LCG.ButtonGlow_Start(
            frame,
            color,
            freq,
            frameLevel
        )
    end,

    proc = function(frame, frameLevel, overrideColor)
        local color = GetGlowColor(overrideColor)
        procGlowOpts.color = color
        procGlowOpts.duration = glowCache.procDuration
        procGlowOpts.xOffset = glowCache.procXOffset
        procGlowOpts.yOffset = glowCache.procYOffset
        procGlowOpts.frameLevel = frameLevel
        LCG.ProcGlow_Start(frame, procGlowOpts)
    end,
}

local glowStopFunctions = {
    pixel = function(frame)
        LCG.PixelGlow_Stop(frame, GLOW_KEY)
    end,

    autocast = function(frame)
        LCG.AutoCastGlow_Stop(frame, GLOW_KEY)
    end,

    button = function(frame)
        LCG.ButtonGlow_Stop(frame)
    end,

    proc = function(frame)
        LCG.ProcGlow_Stop(frame, GLOW_KEY)
    end,
}

local function ShowCustomGlow(frame, overrideColor)
    if not LCG then return end

    local frameData = CDM.GetFrameData(frame)

    if frameData.cdmGlowActive and frameData.cdmGlowType == glowCache.type
       and ColorsMatch(frameData.cdmGlowOverrideColor, overrideColor) then
        return
    end

    if frameData.cdmGlowActive then
        local stopFn = glowStopFunctions[frameData.cdmGlowType]
        if stopFn then stopFn(frame) end
        frameData.cdmGlowActive = false
        frameData.cdmGlowType = nil
    end

    if frame:GetWidth() < 1 or frame:GetHeight() < 1 then
        return
    end

    if frame.IsRectValid and not frame:IsRectValid() then
        frame:GetWidth()
    end

    local fn = glowStartFunctions[glowCache.type]
    if fn then
        local frameLevel = frame:GetFrameLevel() + 5
        fn(frame, frameLevel, overrideColor)
        frameData.cdmGlowActive = true
        frameData.cdmGlowType = glowCache.type
        frameData.cdmGlowOverrideColor = overrideColor
        activeGlowFrames[frame] = true
    end
end

HideCustomGlow = function(frame)
    if not LCG then return end

    pendingHideFrames[frame] = nil

    local frameData = CDM.GetFrameData(frame)
    if not frameData.cdmGlowActive then return end

    local fn = glowStopFunctions[frameData.cdmGlowType]
    if fn then
        fn(frame)
    end

    frameData.cdmGlowActive = false
    frameData.cdmGlowType = nil
    frameData.cdmGlowOverrideColor = nil
    activeGlowFrames[frame] = nil
end

local function EnsureBuffGlowHostFrame(frame)
    if not frame then return nil end
    local frameData = CDM.GetFrameData(frame)
    local host = frameData.cdmBuffGlowHost
    if host then
        return host
    end

    host = CreateFrame("Frame", nil, UIParent)
    host:SetClampedToScreen(false)
    frameData.cdmBuffGlowHost = host
    frameData.cdmBuffGlowHostAnchorTarget = nil
    frameData.cdmBuffGlowHostStrata = nil
    frameData.cdmBuffGlowHostLevel = nil
    return host
end

local function SyncBuffGlowHostFrame(frame, host)
    if not frame or not host then return end

    local frameData = CDM.GetFrameData(frame)

    if frameData.cdmBuffGlowHostAnchorTarget ~= frame then
        host:ClearAllPoints()
        host:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        host:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frameData.cdmBuffGlowHostAnchorTarget = frame
    end

    if frame.GetFrameStrata and host.SetFrameStrata then
        local strata = frame:GetFrameStrata()
        if strata and frameData.cdmBuffGlowHostStrata ~= strata then
            host:SetFrameStrata(strata)
            frameData.cdmBuffGlowHostStrata = strata
        end
    end

    if frame.GetFrameLevel and host.SetFrameLevel then
        local level = frame:GetFrameLevel()
        if level and frameData.cdmBuffGlowHostLevel ~= level then
            host:SetFrameLevel(level)
            frameData.cdmBuffGlowHostLevel = level
        end
    end
end

local function DoesGlowSourceMatchID(sourceID, sourceBase, id)
    if not sourceID or not id then return false end
    if id == sourceID or id == sourceBase then
        return true
    end
    if not CDM.NormalizeToBase then
        return false
    end
    local base = CDM.NormalizeToBase(id)
    return base == sourceID or base == sourceBase
end

local function IsBuffGlowSourceStillValid(frame, sourceID)
    if not frame then return false end
    if not sourceID then return true end
    if not (CDM.GetCurrentSpecID and CDM.GetSpellGlowEnabled) then return true end

    local specID = CDM:GetCurrentSpecID()
    if not specID then
        return false
    end
    if not CDM:GetSpellGlowEnabled(specID, sourceID) then
        return false
    end

    local sourceBase = CDM.NormalizeToBase and CDM.NormalizeToBase(sourceID) or sourceID
    local frameData = CDM.GetFrameData(frame)
    if DoesGlowSourceMatchID(sourceID, sourceBase, frameData.buffCategorySpellID) then
        return true
    end

    local candidates = CDM.GetSpellIDCandidates and CDM:GetSpellIDCandidates(frame, true) or nil
    if candidates then
        for _, id in ipairs(candidates) do
            if DoesGlowSourceMatchID(sourceID, sourceBase, id) then
                return true
            end
        end
    end

    return false
end

local function CancelBuffGlowStop(frame)
    if not frame then return end
    buffPendingStopFrames[frame] = nil

    local frameData = CDM.GetFrameData(frame)
    frameData.cdmBuffGlowPendingStopUntil = nil

    if not next(buffPendingStopFrames) then
        buffStopDrainer:Hide()
    end
end

local function ScheduleBuffGlowStop(frame, delaySeconds)
    if not frame then return end

    local frameData = CDM.GetFrameData(frame)
    frameData.cdmBuffGlowPendingStopUntil = GetTime() + (delaySeconds or BUFF_GLOW_HIDE_GRACE)

    buffPendingStopFrames[frame] = true
    buffStopDrainer:Show()
end

local function ProcessPendingBuffGlowStops(forceStop)
    local now = GetTime()

    for frame in pairs(buffPendingStopFrames) do
        local frameData = CDM.GetFrameData(frame)
        local pendingUntil = frameData.cdmBuffGlowPendingStopUntil
        local isShown = frame.IsShown and frame:IsShown()
        if not pendingUntil then
            buffPendingStopFrames[frame] = nil
        elseif frameData.cdmBuffGlowWanted and isShown then
            CancelBuffGlowStop(frame)
        elseif forceStop or now >= pendingUntil then
            frameData.cdmBuffGlowPendingStopUntil = nil
            buffPendingStopFrames[frame] = nil

            local host = frameData.cdmBuffGlowHost
            if host then
                HideCustomGlow(host)
                host:Hide()
            else
                HideCustomGlow(frame)
            end
        end
    end

    if not next(buffPendingStopFrames) then
        buffStopDrainer:Hide()
    end
end

local function EnsureBuffGlowTargetHooks(frame)
    if not frame or buffHookedFrames[frame] then
        return
    end
    if not frame.HookScript then
        return
    end

    buffHookedFrames[frame] = true

    frame:HookScript("OnHide", function(self)
        local frameData = CDM.GetFrameData(self)
        if frameData.cdmBuffGlowWanted then
            ScheduleBuffGlowStop(self, BUFF_GLOW_HIDE_GRACE)
        end
    end)

    frame:HookScript("OnShow", function(self)
        local frameData = CDM.GetFrameData(self)
        if not frameData.cdmBuffGlowWanted then
            return
        end

        local host = frameData.cdmBuffGlowHost
        if not host then
            return
        end

        if not IsBuffGlowSourceStillValid(self, frameData.cdmBuffGlowSourceID) then
            frameData.cdmBuffGlowWanted = nil
            frameData.cdmBuffGlowOverrideColor = nil
            frameData.cdmBuffGlowSourceID = nil
            CancelBuffGlowStop(self)
            HideCustomGlow(host)
            host:Hide()
            return
        end

        CancelBuffGlowStop(self)

        SyncBuffGlowHostFrame(self, host)
        host:Show()
        ShowCustomGlow(host, frameData.cdmBuffGlowOverrideColor)
    end)

    frame:HookScript("OnSizeChanged", function(self)
        local frameData = CDM.GetFrameData(self)
        local host = frameData.cdmBuffGlowHost
        if host and frameData.cdmBuffGlowWanted then
            SyncBuffGlowHostFrame(self, host)
        end
    end)
end

buffStopDrainer:SetScript("OnUpdate", function(self)
    ProcessPendingBuffGlowStops(false)
    if not next(buffPendingStopFrames) then
        self:Hide()
    end
end)

function Glow:StartGlow(frame, overrideColor)
    ShowCustomGlow(frame, overrideColor)
end

function Glow:StopGlow(frame)
    if frame then
        local frameData = CDM.GetFrameData(frame)
        frameData.cdmBuffGlowWanted = nil
        frameData.cdmBuffGlowSourceID = nil
        frameData.cdmBuffGlowOverrideColor = nil
        CancelBuffGlowStop(frame)

        local host = frameData.cdmBuffGlowHost
        if host then
            HideCustomGlow(host)
            host:Hide()
        end
    end

    HideCustomGlow(frame)
end

function Glow:RequestBuffGlow(frame, enabled, overrideColor, sourceID)
    if not frame or not LCG then return end

    local frameData = CDM.GetFrameData(frame)
    frameData.cdmBuffGlowWanted = enabled and true or false
    frameData.cdmBuffGlowOverrideColor = overrideColor
    frameData.cdmBuffGlowSourceID = sourceID

    EnsureBuffGlowTargetHooks(frame)

    if enabled then
        CancelBuffGlowStop(frame)

        local host = EnsureBuffGlowHostFrame(frame)
        SyncBuffGlowHostFrame(frame, host)
        host:Show()
        ShowCustomGlow(host, overrideColor)
    else
        CancelBuffGlowStop(frame)

        local host = frameData.cdmBuffGlowHost
        if host then
            HideCustomGlow(host)
            host:Hide()
        else
            HideCustomGlow(frame)
        end
    end
end

function Glow:HideBlizzardGlow(frame)
    HideBlizzardGlow(frame)
end

function Glow:RefreshActiveGlows()
    if not LCG then return end

    ProcessPendingBuffGlowStops(true)

    for frame in pairs(pendingHideFrames) do
        pendingHideFrames[frame] = nil
        HideCustomGlow(frame)
    end
    debounceDrainer:Hide()

    local count = 0
    for frame in pairs(activeGlowFrames) do
        count = count + 1
        activeGlowSnapshot[count] = frame
    end

    for i = 1, count do
        local frame = activeGlowSnapshot[i]
        activeGlowSnapshot[i] = nil
        local frameData = CDM.GetFrameData(frame)
        if frameData.cdmGlowActive then
            ShowCustomGlow(frame, frameData.cdmGlowOverrideColor)
        else
            activeGlowFrames[frame] = nil
        end
    end
end

function Glow:HookAlertManager()
    if self.alertManagerHooked then return end

    local alertManager = _G.ActionButtonSpellAlertManager
    if not alertManager then return end

    hooksecurefunc(alertManager, "ShowAlert", function(_, frame)
        if not IsSupportedGlowFrame(frame) then return end

        pendingHideFrames[frame] = nil

        HideBlizzardGlow(frame)
        local frameData = CDM.GetFrameData(frame)
        if frameData.cdmGlowActive and frameData.cdmGlowType == glowCache.type then
            return
        end
        ShowCustomGlow(frame)
    end)

    hooksecurefunc(alertManager, "HideAlert", function(_, frame)
        if not IsSupportedGlowFrame(frame) then return end

        HideBlizzardGlow(frame)

        local frameData = CDM.GetFrameData(frame)
        if not frameData.cdmGlowActive then return end

        pendingHideFrames[frame] = true
        debounceDrainer:Show()
    end)

    self.alertManagerHooked = true
end

local function GlowCfg(db, defaults, key)
    if db[key] ~= nil then return db[key] end
    return defaults[key]
end

function Glow:RefreshCache()
    local db = CDM.db or {}
    local defaults = CDM.defaults or {}

    glowCache.type = GlowCfg(db, defaults, "glowType") or "proc"
    glowCache.useCustomColor = GlowCfg(db, defaults, "glowUseCustomColor")
    glowCache.color = GlowCfg(db, defaults, "glowColor")

    glowCache.pixelLines = GlowCfg(db, defaults, "glowPixelLines")
    glowCache.pixelFrequency = GlowCfg(db, defaults, "glowPixelFrequency")
    glowCache.pixelLength = GlowCfg(db, defaults, "glowPixelLength")
    glowCache.pixelThickness = GlowCfg(db, defaults, "glowPixelThickness")
    glowCache.pixelXOffset = GlowCfg(db, defaults, "glowPixelXOffset")
    glowCache.pixelYOffset = GlowCfg(db, defaults, "glowPixelYOffset")
    glowCache.pixelBorder = false

    glowCache.autocastParticles = GlowCfg(db, defaults, "glowAutocastParticles")
    glowCache.autocastFrequency = GlowCfg(db, defaults, "glowAutocastFrequency")
    glowCache.autocastScale = GlowCfg(db, defaults, "glowAutocastScale")
    glowCache.autocastXOffset = GlowCfg(db, defaults, "glowAutocastXOffset")
    glowCache.autocastYOffset = GlowCfg(db, defaults, "glowAutocastYOffset")

    glowCache.buttonFrequency = GlowCfg(db, defaults, "glowButtonFrequency")

    glowCache.procDuration = GlowCfg(db, defaults, "glowProcDuration")
    glowCache.procXOffset = GlowCfg(db, defaults, "glowProcXOffset")
    glowCache.procYOffset = GlowCfg(db, defaults, "glowProcYOffset")

    if not glowStartFunctions[glowCache.type] then
        glowCache.type = "proc"
    end

    self:RefreshActiveGlows()
end

function Glow:Initialize()
    self:RefreshCache()
    self:HookAlertManager()
end

CDM:RegisterRefreshCallback("glow", function()
    Glow:RefreshCache()
end, 50, { "glow", "viewers" })

CDM:RegisterEvent("PLAYER_LOGIN", function()
    Glow:Initialize()
end)
