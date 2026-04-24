local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS

local GetTime = GetTime
local ipairs = ipairs
local pairs = pairs

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

local DRUID_TRAVEL_FORM_IDS = {[3] = true, [4] = true, [27] = true, [29] = true}

local animFrame = CreateFrame("Frame")
local eventFrame = CreateFrame("Frame")

local viewerTargets = {
    { dbKey = "fadingEssential", viewer = VIEWERS.ESSENTIAL },
    { dbKey = "fadingUtility",   viewer = VIEWERS.UTILITY },
    { dbKey = "fadingBuffs",     viewer = VIEWERS.BUFF },
    { dbKey = "fadingBuffBars",  viewer = VIEWERS.BUFF_BAR },
}

local extraTargets = {}

function Fading:RegisterTarget(dbKey, applyFn)
    extraTargets[#extraTargets + 1] = { dbKey = dbKey, apply = applyFn }
end

Fading:RegisterTarget("fadingBuffs", function(a)
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
end)

Fading:RegisterTarget("fadingRacials", function(a)
    local c = _G["CDM_RacialsContainer"]
    if c then c:SetAlpha(a) end
end)

Fading:RegisterTarget("fadingDefensives", function(a)
    local c = _G["CDM_DefensivesContainer"]
    if c then c:SetAlpha(a) end
end)

Fading:RegisterTarget("fadingTrinkets", function(a)
    local trinketMode = CDM.GetTrinketMode and CDM.GetTrinketMode()
    if trinketMode == "essential" then
        local tFrames = CDM.GetTrinketIconFrames and CDM.GetTrinketIconFrames()
        if tFrames then
            for _, frame in ipairs(tFrames) do
                frame:SetAlpha(a)
            end
        end
    else
        local c = _G["CDM_TrinketsContainer"]
        if c then c:SetAlpha(a) end
    end
end)

Fading:RegisterTarget("fadingResources", function(a)
    if CDM.resourceBars then
        for _, bar in pairs(CDM.resourceBars) do
            if bar:IsShown() then
                bar:SetAlpha(a)
            end
        end
    end
    if CDM.resourceUnifiedHosts then
        for _, entry in ipairs(CDM.resourceUnifiedHosts) do
            if entry.host and entry.host:IsShown() then
                entry.host:SetAlpha(a)
            end
            if entry.hSeparators then
                for _, sep in ipairs(entry.hSeparators) do
                    sep:SetAlpha(a)
                end
            end
        end
    end
end)

local function ApplyAlphaToAll(alpha)
    local db = CDM.db
    if not db then return end

    for _, entry in ipairs(viewerTargets) do
        local a = (db[entry.dbKey] ~= false) and alpha or 1.0
        local viewer = _G[entry.viewer]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                frame:SetAlpha(a)
            end
        end
    end

    for _, target in ipairs(extraTargets) do
        local a = (db[target.dbKey] ~= false) and alpha or 1.0
        target.apply(a)
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
    isMounted = IsMounted() or DRUID_TRAVEL_FORM_IDS[GetShapeshiftFormID()] or false
    Fading:Evaluate()
end

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_TARGET_CHANGED" then
        OnTargetChanged()
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "UPDATE_SHAPESHIFT_FORM" then
        OnMountChanged()
    end
end)

local function Enable()
    if isEnabled then return end
    isEnabled = true
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    CDM:RegisterCombatStateHandler(OnCombatStateChanged)
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    isMounted = IsMounted() or DRUID_TRAVEL_FORM_IDS[GetShapeshiftFormID()] or false
    Fading:Evaluate()
end

local function Disable()
    if not isEnabled then return end
    isEnabled = false
    eventFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
    CDM:UnregisterCombatStateHandler(OnCombatStateChanged)
    eventFrame:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
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
    end, 80, { "STYLE" })

    if CDM.db and CDM.db.fadingEnabled then
        Enable()
    end
end
