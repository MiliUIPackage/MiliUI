local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS

CDM.Fading = CDM.Fading or {}
local Fading = CDM.Fading

local FADE_DURATION = 0.3

local currentAlpha = 1.0
local targetAlpha = 1.0
local animStartTime = 0
local animStartAlpha = 1.0
local animating = false
local isEnabled = false
local inCombat = InCombatLockdown() and true or false
local isMounted = IsMounted() and true or false

local animFrame = CreateFrame("Frame")

local function GetViewerFrames(viewerName)
    local viewer = _G[viewerName]
    if not viewer or not viewer.itemFramePool then return nil end
    return viewer.itemFramePool
end

local function ApplyAlphaToAll(alpha)
    local db = CDM.db
    if not db then return end

    local a = (db.fadingEssential ~= false) and alpha or 1.0
    local pool = GetViewerFrames(VIEWERS.ESSENTIAL)
    if pool then
        for frame in pool:EnumerateActive() do
            frame:SetAlpha(a)
        end
    end

    a = (db.fadingUtility ~= false) and alpha or 1.0
    pool = GetViewerFrames(VIEWERS.UTILITY)
    if pool then
        for frame in pool:EnumerateActive() do
            frame:SetAlpha(a)
        end
    end

    a = (db.fadingBuffs ~= false) and alpha or 1.0
    pool = GetViewerFrames(VIEWERS.BUFF)
    if pool then
        for frame in pool:EnumerateActive() do
            frame:SetAlpha(a)
        end
    end
    if CDM.CustomBuffs and CDM.CustomBuffs.activeBuffs then
        for _, buffData in pairs(CDM.CustomBuffs.activeBuffs) do
            if buffData and buffData.frame then
                buffData.frame:SetAlpha(a)
            end
        end
    end
    if CDM.buffGroupContainers then
        for _, container in pairs(CDM.buffGroupContainers) do
            if container:IsShown() then
                container:SetAlpha(a)
            end
        end
    end

    a = (db.fadingBuffBars ~= false) and alpha or 1.0
    pool = GetViewerFrames(VIEWERS.BUFF_BAR)
    if pool then
        for frame in pool:EnumerateActive() do
            frame:SetAlpha(a)
        end
    end

    a = (db.fadingRacials ~= false) and alpha or 1.0
    local racialsContainer = _G["CDM_RacialsContainer"]
    if racialsContainer then racialsContainer:SetAlpha(a) end

    a = (db.fadingDefensives ~= false) and alpha or 1.0
    local defensivesContainer = _G["CDM_DefensivesContainer"]
    if defensivesContainer then defensivesContainer:SetAlpha(a) end

    a = (db.fadingTrinkets ~= false) and alpha or 1.0
    local trinketMode = CDM.GetTrinketMode and CDM.GetTrinketMode()
    if trinketMode == "essential" then
        local tFrames = CDM.GetTrinketIconFrames and CDM.GetTrinketIconFrames()
        if tFrames then
            for _, frame in ipairs(tFrames) do
                frame:SetAlpha(a)
            end
        end
    else
        local trinketsContainer = _G["CDM_TrinketsContainer"]
        if trinketsContainer then trinketsContainer:SetAlpha(a) end
    end

    a = (db.fadingResources ~= false) and alpha or 1.0
    local rc = CDM.resourceContainer
    if rc then
        rc:SetAlpha(a)
        if rc.separator then rc.separator:SetAlpha(a) end
    end
end

local function StopAnimation()
    animating = false
    animFrame:SetScript("OnUpdate", nil)
end

local function OnAnimUpdate()
    local now = GetTime()
    local t = (now - animStartTime) / FADE_DURATION
    if t >= 1.0 then
        t = 1.0
        StopAnimation()
    end
    currentAlpha = animStartAlpha + (targetAlpha - animStartAlpha) * t
    ApplyAlphaToAll(currentAlpha)
end

function Fading:ShowImmediate()
    StopAnimation()
    currentAlpha = 1.0
    targetAlpha = 1.0
    ApplyAlphaToAll(1.0)
end

function Fading:BeginFadeOut()
    local db = CDM.db
    if not db then return end

    local raw = tonumber(db.fadingOpacity) or 0
    if raw < 0 then raw = 0 elseif raw > 100 then raw = 100 end
    targetAlpha = raw / 100

    if currentAlpha <= targetAlpha then
        StopAnimation()
        currentAlpha = targetAlpha
        ApplyAlphaToAll(currentAlpha)
        return
    end

    animStartTime = GetTime()
    animStartAlpha = currentAlpha
    if not animating then
        animating = true
        animFrame:SetScript("OnUpdate", OnAnimUpdate)
    end
end

function Fading:Evaluate()
    if not isEnabled then return end

    if CDM.isEditModeActive then
        self:ShowImmediate()
        return
    end

    local db = CDM.db
    if not db then return end
    local shouldFade = false

    if db.fadingTriggerNoTarget ~= false and not UnitExists("target") then
        shouldFade = true
    elseif db.fadingTriggerOOC and not inCombat then
        shouldFade = true
    elseif db.fadingTriggerMounted and isMounted then
        shouldFade = true
    end

    if shouldFade then
        self:BeginFadeOut()
    else
        self:ShowImmediate()
    end
end

function Fading:ReapplyCurrent()
    if currentAlpha >= 1.0 and not animating then return end
    ApplyAlphaToAll(currentAlpha)
end

function Fading:GetAlpha(targetKey)
    if not isEnabled then return 1.0 end
    if CDM.db[targetKey] ~= false then
        return currentAlpha
    end
    return 1.0
end

local function OnTargetChanged()
    Fading:Evaluate()
end

local function OnCombatStateChanged(isInCombat)
    inCombat = isInCombat and true or false
    Fading:Evaluate()
end

local function OnMountChanged()
    isMounted = IsMounted() and true or false
    Fading:Evaluate()
end

local function Enable()
    if isEnabled then return end
    isEnabled = true
    CDM:RegisterEvent("PLAYER_TARGET_CHANGED", OnTargetChanged)
    CDM:RegisterInternalCallback("OnCombatStateChanged", OnCombatStateChanged)
    CDM:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", OnMountChanged)
    isMounted = IsMounted() and true or false
    Fading:Evaluate()
end

local function Disable()
    if not isEnabled then return end
    isEnabled = false
    CDM:UnregisterEventHandler("PLAYER_TARGET_CHANGED", OnTargetChanged)
    CDM:UnregisterInternalCallback("OnCombatStateChanged", OnCombatStateChanged)
    CDM:UnregisterEventHandler("PLAYER_MOUNT_DISPLAY_CHANGED", OnMountChanged)
    if currentAlpha < 1.0 or animating then
        Fading:ShowImmediate()
    end
end

function Fading:Initialize()
    CDM:RegisterRefreshCallback("fading", function()
        local db = CDM.db
        if db and db.fadingEnabled then
            Enable()
            Fading:Evaluate()
        else
            Disable()
        end
    end, 80, { "fading", "viewers" })

    if CDM.db and CDM.db.fadingEnabled then
        Enable()
    end
end
