local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS

local LCG = LibStub("LibCustomGlow-1.0", true)

local pairs = pairs
local ipairs = ipairs
local type = type

CDM.Glow = CDM.Glow or {}
local Glow = CDM.Glow

local GLOW_KEY = "CDM_SpellAlert"
local PROC_GLOW_FIELD = "_ProcGlow" .. GLOW_KEY
local activeGlowFrames = setmetatable({}, { __mode = "k" })
local pendingHideFrames = setmetatable({}, { __mode = "k" })
local buffHookedFrames = setmetatable({}, { __mode = "k" })
local HideCustomGlow

local PRODUCER_PRIORITY = {
    alert = 1,
    aura  = 2,
    buff  = 2,
    ready = 3,
}

local debounceDrainer = CreateFrame("Frame")
debounceDrainer:Hide()

local function DrainPendingHide()
    debounceDrainer:Hide()
    for frame in pairs(pendingHideFrames) do
        pendingHideFrames[frame] = nil
        Glow:RequestBuffGlow(frame, "alert", false)
        CDM:RefreshFrameVisuals(frame)
    end
end

debounceDrainer:SetScript("OnUpdate", DrainPendingHide)

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

    if frame.cdmViewerName then
        return frame.cdmViewerName
    end
    if frame.cdmViewerNameChecked then
        return nil
    end

    local result
    if frame.GetViewerFrame then
        local viewer = frame:GetViewerFrame()
        if viewer then
            result = viewer:GetName()
        end
    end

    if not result then
        local parent = frame:GetParent()
        while parent do
            local name = parent:GetName()
            if IsSupportedViewerName(name) then
                result = name
                break
            end
            parent = parent:GetParent()
        end
    end

    frame.cdmViewerNameChecked = true
    if result then
        frame.cdmViewerName = result
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
        local f = frame[PROC_GLOW_FIELD]
        if f then
            f:SetScript("OnHide", nil)
        end
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
        local f = frame[PROC_GLOW_FIELD]
        if f then
            if f.ProcStartAnim and f.ProcStartAnim:IsPlaying() then
                f.ProcStartAnim:Stop()
            end
            if f.ProcLoopAnim and f.ProcLoopAnim:IsPlaying() then
                f.ProcLoopAnim:Stop()
            end
        end
        LCG.ProcGlow_Stop(frame, GLOW_KEY)
    end,
}

local function ShowCustomGlow(frame, overrideColor)
    if not LCG then return end

    if frame.cdmGlowActive and frame.cdmGlowType == glowCache.type
       and ColorsMatch(frame.cdmGlowOverrideColor, overrideColor) then
        return
    end

    if frame.cdmGlowActive then
        local stopFn = glowStopFunctions[frame.cdmGlowType]
        if stopFn then stopFn(frame) end
        frame.cdmGlowActive = false
        frame.cdmGlowType = nil
    end

    if not frame:IsRectValid() then
        frame:GetWidth()
    end

    if frame:GetWidth() < 1 or frame:GetHeight() < 1 then
        return
    end

    local fn = glowStartFunctions[glowCache.type]
    if fn then
        fn(frame, 5, overrideColor)
        frame.cdmGlowActive = true
        frame.cdmGlowType = glowCache.type
        frame.cdmGlowOverrideColor = overrideColor
        activeGlowFrames[frame] = true
    end
end

HideCustomGlow = function(frame)
    if not LCG then return end

    if pendingHideFrames[frame] then
        pendingHideFrames[frame] = nil
    end

    if not frame.cdmGlowActive then return end

    local fn = glowStopFunctions[frame.cdmGlowType]
    if fn then
        fn(frame)
    end

    frame.cdmGlowActive = false
    frame.cdmGlowType = nil
    frame.cdmGlowOverrideColor = nil
    activeGlowFrames[frame] = nil
end

local function EnsureBuffGlowHostFrame(frame)
    if not frame then return nil end
    local host = frame.cdmBuffGlowHost
    if host then
        return host
    end

    host = CreateFrame("Frame", nil, frame)
    host:SetClampedToScreen(false)
    frame.cdmBuffGlowHost = host
    frame.cdmBuffGlowHostAnchorTarget = nil
    frame.cdmBuffGlowHostStrata = nil
    frame.cdmBuffGlowHostLevel = nil
    return host
end

local function SyncBuffGlowHostFrame(frame, host)
    if not frame or not host then return end

    if frame.cdmBuffGlowHostAnchorTarget ~= frame then
        host:SetParent(frame)
        host:ClearAllPoints()
        host:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        host:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame.cdmBuffGlowHostAnchorTarget = frame
    end

    local strata = frame:GetFrameStrata()
    if strata and frame.cdmBuffGlowHostStrata ~= strata then
        host:SetFrameStrata(strata)
        frame.cdmBuffGlowHostStrata = strata
    end

    local level = frame:GetFrameLevel()
    if level and frame.cdmBuffGlowHostLevel ~= level then
        host:SetFrameLevel(level)
        frame.cdmBuffGlowHostLevel = level
    end
end

local function DoesGlowSourceMatchID(sourceID, sourceBase, id)
    if not sourceID or not id then return false end
    if id == sourceID or id == sourceBase then
        return true
    end
    local base = CDM.NormalizeToBase(id)
    return base == sourceID or base == sourceBase
end

local function IsBuffGlowSourceStillValid(frame, sourceID)
    if not frame then return false end
    if not sourceID then return true end

    local specID = CDM:GetCurrentSpecID()
    if not specID then
        return false
    end
    if not CDM:GetSpellGlowEnabled(specID, sourceID) then
        return false
    end

    local sourceBase = CDM.NormalizeToBase(sourceID)
    if DoesGlowSourceMatchID(sourceID, sourceBase, frame.cdmBuffCategorySpellID) then
        return true
    end

    local candidates = CDM:GetSpellIDCandidates(frame)
    if candidates then
        for _, id in ipairs(candidates) do
            if DoesGlowSourceMatchID(sourceID, sourceBase, id) then
                return true
            end
        end
    end

    return false
end

local function EnsureBuffGlowTargetHooks(frame)
    if not frame or buffHookedFrames[frame] then
        return
    end

    buffHookedFrames[frame] = true

    frame:HookScript("OnShow", function(self)
        if not self.cdmBuffGlowWanted then
            return
        end

        local host = self.cdmBuffGlowHost
        if not host then
            return
        end

        if not IsBuffGlowSourceStillValid(self, self.cdmBuffGlowSourceID) then
            self.cdmGlowProducer = nil
            self.cdmBuffGlowWanted = nil
            self.cdmBuffGlowOverrideColor = nil
            self.cdmBuffGlowSourceID = nil
            HideCustomGlow(host)
            host:Hide()
            return
        end

        SyncBuffGlowHostFrame(self, host)
        host:Show()
        ShowCustomGlow(host, self.cdmBuffGlowOverrideColor)
    end)

    frame:HookScript("OnSizeChanged", function(self)
        local host = self.cdmBuffGlowHost
        if host and self.cdmBuffGlowWanted then
            SyncBuffGlowHostFrame(self, host)
        end
    end)
end

function Glow:StopGlow(frame)
    if frame then
        frame.cdmGlowProducer = nil
        frame.cdmBuffGlowWanted = nil
        frame.cdmBuffGlowSourceID = nil
        frame.cdmBuffGlowOverrideColor = nil

        local host = frame.cdmBuffGlowHost
        if host then
            HideCustomGlow(host)
            host:Hide()
        end
    end

    HideCustomGlow(frame)
end

function Glow:RequestBuffGlow(frame, producerToken, enabled, overrideColor, sourceID)
    if not frame or not LCG then return end

    if enabled then
        local current = frame.cdmGlowProducer
        local currentPri = current and PRODUCER_PRIORITY[current]
        local requestPri = PRODUCER_PRIORITY[producerToken]
        if current and current ~= producerToken
           and currentPri and requestPri and currentPri < requestPri then
            return
        end
        frame.cdmGlowProducer = producerToken
        frame.cdmBuffGlowWanted = true
        frame.cdmBuffGlowOverrideColor = overrideColor
        frame.cdmBuffGlowSourceID = sourceID

        EnsureBuffGlowTargetHooks(frame)
        local host = EnsureBuffGlowHostFrame(frame)
        SyncBuffGlowHostFrame(frame, host)
        if frame:IsShown() then
            host:Show()
            ShowCustomGlow(host, overrideColor)
        end
    else
        if frame.cdmGlowProducer ~= producerToken then
            return
        end
        frame.cdmGlowProducer = nil
        frame.cdmBuffGlowWanted = nil
        frame.cdmBuffGlowOverrideColor = nil
        frame.cdmBuffGlowSourceID = nil

        local host = frame.cdmBuffGlowHost
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

    DrainPendingHide()

    local count = 0
    for frame in pairs(activeGlowFrames) do
        count = count + 1
        activeGlowSnapshot[count] = frame
    end

    for i = 1, count do
        local frame = activeGlowSnapshot[i]
        activeGlowSnapshot[i] = nil
        if frame.cdmGlowActive then
            local stopFn = glowStopFunctions[frame.cdmGlowType]
            if stopFn then stopFn(frame) end
            frame.cdmGlowActive = false
            frame.cdmGlowType = nil
            ShowCustomGlow(frame, frame.cdmGlowOverrideColor)
        else
            activeGlowFrames[frame] = nil
        end
    end
end

function Glow:InstallAcquireResetHook(v)
    hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
        Glow:RequestBuffGlow(itemFrame, "ready", false)
        Glow:RequestBuffGlow(itemFrame, "aura", false)
        Glow:RequestBuffGlow(itemFrame, "alert", false)
        Glow:RequestBuffGlow(itemFrame, "buff", false)
    end)
end

function Glow:HookAlertManager()
    if self.alertManagerHooked then return end

    local alertManager = _G.ActionButtonSpellAlertManager
    if not alertManager then return end

    hooksecurefunc(alertManager, "ShowAlert", function(_, frame)
        if not IsSupportedGlowFrame(frame) then return end

        pendingHideFrames[frame] = nil

        HideBlizzardGlow(frame)
        Glow:RequestBuffGlow(frame, "alert", true, nil, nil)
    end)

    hooksecurefunc(alertManager, "HideAlert", function(_, frame)
        if not IsSupportedGlowFrame(frame) then return end

        HideBlizzardGlow(frame)

        if frame.cdmGlowProducer ~= "alert" then return end

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
    glowCache.pixelBorder = GlowCfg(db, defaults, "glowPixelBorder") and true or false

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
end, 50, { "STYLE" })

