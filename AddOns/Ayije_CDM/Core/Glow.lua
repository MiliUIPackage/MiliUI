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
local HideCustomGlow

local debounceDrainer = CreateFrame("Frame")
debounceDrainer:Hide()
debounceDrainer:SetScript("OnUpdate", function(self)
    self:Hide()
    for frame in pairs(pendingHideFrames) do
        pendingHideFrames[frame] = nil
        HideCustomGlow(frame)
    end
end)

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

function Glow:StartGlow(frame, overrideColor)
    ShowCustomGlow(frame, overrideColor)
end

function Glow:StopGlow(frame)
    HideCustomGlow(frame)
end

function Glow:HideBlizzardGlow(frame)
    HideBlizzardGlow(frame)
end

function Glow:RefreshActiveGlows()
    if not LCG then return end

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
            local savedColor = frameData.cdmGlowOverrideColor
            HideCustomGlow(frame)
            ShowCustomGlow(frame, savedColor)
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
end, 50)

CDM:RegisterEvent("PLAYER_LOGIN", function()
    Glow:Initialize()
end)
