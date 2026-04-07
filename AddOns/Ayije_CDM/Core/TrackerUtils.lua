local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local INVERTED_ANCHORS = {
    TOPLEFT = "BOTTOMLEFT",
    TOPRIGHT = "BOTTOMRIGHT",
    BOTTOMLEFT = "TOPLEFT",
    BOTTOMRIGHT = "TOPRIGHT",
}
local TRACKER_ANCHOR_INVALIDATION_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "LOADING_SCREEN_DISABLED",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED",
}

CDM._cdmCooldowns = CDM._cdmCooldowns or setmetatable({}, { __mode = "k" })

local trackerAnchorCache = setmetatable({}, { __mode = "k" })
local trackerAnchorCacheVersion = 0
local anchorInvalidationInitialized = false

local playerFrameSettled = false

local cachedPlayerFrame = nil
local cachedPlayerFrameVersion = -1
local trackerPositionCallbacks = {}
local positionNotifyPending = false
local positionNotifyTimer = nil
local positionNotifySeq = 0
local trackerVisibleFramesScratch = {}
local trackerWidthsPxScratch = {}
local trackerHeightsPxScratch = {}

local function InvalidateTrackerAnchorCache(container)
    if container then
        trackerAnchorCache[container] = nil
        return
    end
    trackerAnchorCacheVersion = trackerAnchorCacheVersion + 1
end

CDM.InvalidateTrackerAnchorCache = InvalidateTrackerAnchorCache

local GCD_SPELL_ID = CDM_C.GCD_SPELL_ID
local gcdFilterCurve = C_CurveUtil.CreateCurve()
gcdFilterCurve:SetType(Enum.LuaCurveType.Step)
local cachedGCDInfo = nil
local cachedGCDTime = -1
local cachedGCDCurveTime = -1

local function GetGCDInfo()
    local now = GetTime()
    if now ~= cachedGCDTime then
        cachedGCDInfo = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        cachedGCDTime = now
    end
    return cachedGCDInfo
end

function CDM.EvaluateGCDFilteredDesaturation(durObj)
    local gcdInfo = GetGCDInfo()
    if not gcdInfo or not gcdInfo.startTime or not gcdInfo.duration or gcdInfo.duration <= 0 then
        return nil
    end
    local gcdRemaining = math.floor(((gcdInfo.startTime + gcdInfo.duration) - GetTime()) * 1000 + 0.5) / 1000
    if gcdRemaining <= 0.0011 then
        return nil
    end
    if cachedGCDTime ~= cachedGCDCurveTime then
        cachedGCDCurveTime = cachedGCDTime
        gcdFilterCurve:ClearPoints()
        gcdFilterCurve:AddPoint(0,                     0)
        gcdFilterCurve:AddPoint(0.0001,                1)
        gcdFilterCurve:AddPoint(gcdRemaining - 0.001,  0)
        gcdFilterCurve:AddPoint(gcdRemaining + 0.001,  0)
        gcdFilterCurve:AddPoint(gcdRemaining + 0.0011, 1)
    end
    return durObj:EvaluateRemainingDuration(gcdFilterCurve, 0) or 0
end

local function NotifyTrackerPositionCallbacks()
    for _, cb in pairs(trackerPositionCallbacks) do
        cb()
    end
end

local function SchedulePositionNotify()
    if positionNotifyPending then return end
    positionNotifyPending = true
    positionNotifySeq = positionNotifySeq + 1
    local notifySeq = positionNotifySeq
    positionNotifyTimer = C_Timer.NewTimer(0, function()
        if notifySeq ~= positionNotifySeq then
            return
        end
        positionNotifyTimer = nil
        positionNotifyPending = false
        NotifyTrackerPositionCallbacks()
    end)
end

function CDM.ScheduleTrackerPositionRefresh()
    InvalidateTrackerAnchorCache()
    SchedulePositionNotify()
end


local playerFrameRecheckTimer

local function EnsureAnchorInvalidation()
    if anchorInvalidationInitialized then return end
    anchorInvalidationInitialized = true
    local f = CreateFrame("Frame")
    for _, eventName in ipairs(TRACKER_ANCHOR_INVALIDATION_EVENTS) do
        f:RegisterEvent(eventName)
    end
    f:SetScript("OnEvent", function(_, event)
        InvalidateTrackerAnchorCache()
        SchedulePositionNotify()
        if event == "PLAYER_ENTERING_WORLD" or event == "LOADING_SCREEN_DISABLED" then
            if playerFrameRecheckTimer then
                playerFrameRecheckTimer:Cancel()
            end
            playerFrameRecheckTimer = C_Timer.NewTimer(1, function()
                playerFrameRecheckTimer = nil
                InvalidateTrackerAnchorCache()
                SchedulePositionNotify()
            end)
        end
    end)
end

function CDM.CreateStartupSettleGate(onSettled)
    local settled = false
    local token = 0

    local gate = {}

    function gate:IsSettled()
        return settled
    end

    function gate:Begin()
        settled = false
        token = token + 1
    end

    function gate:Cancel()
        settled = false
        token = token + 1
    end

    function gate:ScheduleSettle(callback)
        local capturedToken = token
        local settleCallback = callback or onSettled
        C_Timer.After(0, function()
            if capturedToken ~= token then
                return
            end
            settled = true
            if settleCallback then
                settleCallback()
            end
        end)
    end

    return gate
end

function CDM.RegisterTrackerPositionCallback(name, callback)
    trackerPositionCallbacks[name] = callback
    EnsureAnchorInvalidation()
end

function CDM.UnregisterTrackerPositionCallback(name)
    trackerPositionCallbacks[name] = nil
end

local PLAYER_FRAME_CANDIDATES = {
    "ElvUF_Player",
    "SUFUnitplayer",
    "UUF_Player",
    "EllesmereUIUnitFrames_Player",
    "MSUF_player",
    "EQOLUFPlayerFrame",
    "oUF_Player",
}

local function ResolvePlayerAnchorFrame()
    if cachedPlayerFrameVersion ~= trackerAnchorCacheVersion then
        playerFrameSettled = false
    end
    if playerFrameSettled then
        if cachedPlayerFrame and cachedPlayerFrame.IsShown and cachedPlayerFrame:IsShown() then
            return cachedPlayerFrame
        end
        playerFrameSettled = false
    end

    for _, name in ipairs(PLAYER_FRAME_CANDIDATES) do
        local frame = _G[name]
        if frame and frame.IsShown and frame:IsShown() then
            cachedPlayerFrame = frame
            cachedPlayerFrameVersion = trackerAnchorCacheVersion
            playerFrameSettled = true
            return cachedPlayerFrame
        end
    end

    local blizzFrame = _G["PlayerFrame"]
    if blizzFrame and blizzFrame.IsShown and blizzFrame:IsShown() then
        cachedPlayerFrame = blizzFrame
        cachedPlayerFrameVersion = trackerAnchorCacheVersion
        -- Settle only if no addon frame candidate exists in the global namespace.
        -- If one exists but isn't shown yet, don't settle so we re-check next call.
        local addonFramePending = false
        for _, name in ipairs(PLAYER_FRAME_CANDIDATES) do
            if _G[name] then
                addonFramePending = true
                break
            end
        end
        playerFrameSettled = not addonFramePending
        return cachedPlayerFrame
    end

    cachedPlayerFrame = nil
    cachedPlayerFrameVersion = trackerAnchorCacheVersion
    return nil
end

function CDM.CreateTrackerIcon(parent, namePrefix, id, opts)
    opts = opts or {}
    local size = opts.size or { w = 40, h = 36 }
    local frameName
    if opts.named ~= false and namePrefix and id ~= nil then
        frameName = namePrefix .. id
    end
    local frame = CreateFrame("Frame", frameName, parent)
    frame:SetSize(size.w, size.h)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    Pixel.DisableTextureSnap(icon)
    frame.Icon = icon

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetReverse(false)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    if cooldown.SetSwipeColor then
        local sc = CDM.db and CDM.db.swipeColor or CDM_C.SWIPE_COLOR
        cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
    end
    CDM._cdmCooldowns[cooldown] = true
    frame.Cooldown = cooldown

    if cooldown.CooldownFlash then
        hooksecurefunc(cooldown.CooldownFlash, "Show", function(self)
            self:Hide()
            if self.FlashAnim then self.FlashAnim:Stop() end
        end)
        if cooldown.CooldownFlash.FlashAnim and cooldown.CooldownFlash.FlashAnim.Play then
            hooksecurefunc(cooldown.CooldownFlash.FlashAnim, "Play", function(self)
                self:Stop()
                cooldown.CooldownFlash:Hide()
            end)
        end
    end

    if not CDM._OnTrackerCooldownDone then
        CDM._OnTrackerCooldownDone = function(self)
            local parentFrame = self and self:GetParent()
            if parentFrame and parentFrame.Icon then
                parentFrame.Icon:SetDesaturation(0)
            end
        end
    end
    cooldown:HookScript("OnCooldownDone", CDM._OnTrackerCooldownDone)

    if opts.showCharges then
        frame.cdmChargeWidgetsEnabled = true
    end

    return frame
end

function CDM.RefreshAllSwipeColors()
    local sc = CDM.db and CDM.db.swipeColor or CDM_C.SWIPE_COLOR
    for cd in pairs(CDM._cdmCooldowns) do
        if cd.SetSwipeColor then
            cd:SetSwipeColor(sc.r, sc.g, sc.b, sc.a)
        end
    end
end

function CDM.EnsureTrackerChargeWidgets(frame)
    if not frame or not frame.cdmChargeWidgetsEnabled then
        return nil
    end

    local chargeCount = frame.ChargeCount
    if chargeCount and chargeCount.Current then
        return chargeCount.Current
    end

    chargeCount = CreateFrame("Frame", nil, frame)
    chargeCount:SetAllPoints()
    chargeCount:SetFrameLevel(frame:GetFrameLevel() + 4)
    chargeCount.Current = chargeCount:CreateFontString(nil, "OVERLAY")
    chargeCount.Current:SetFont(CDM_C.FONT_PATH, 12, CDM_C.FONT_OUTLINE)
    chargeCount.Current:SetDrawLayer("OVERLAY", 7)
    frame.ChargeCount = chargeCount

    return chargeCount.Current
end

local function SetTrackerContainerAnchor(container, anchorPoint, offsetX, offsetY, targetFrame, containerAnchorOverride)
    container:ClearAllPoints()
    local containerAnchor = containerAnchorOverride or INVERTED_ANCHORS[anchorPoint] or anchorPoint
    Pixel.SetPoint(container, containerAnchor, targetFrame, anchorPoint, offsetX, offsetY)
end

function CDM.PositionTrackerIcons(container, frames, size, spacing, anchorPoint)
    local growLeft = (anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT")
    local visibleFrames = trackerVisibleFramesScratch
    local widths = trackerWidthsPxScratch
    local heights = trackerHeightsPxScratch
    local prevVisibleCount = #visibleFrames
    local prevWidthsCount = #widths
    local visibleCount = 0

    for _, frame in ipairs(frames) do
        if frame and frame:IsShown() then
            visibleCount = visibleCount + 1
            visibleFrames[visibleCount] = frame
        end
    end
    for i = visibleCount + 1, prevVisibleCount do
        visibleFrames[i] = nil
    end

    local gap = Snap(spacing or 0)

    if visibleCount <= 0 then
        for i = 1, prevWidthsCount do
            widths[i] = nil
        end
        container:SetSize(0, Snap(size and size.h or 0))
        return
    end

    local totalWidth = 0
    local maxHeight = 0

    for i, frame in ipairs(visibleFrames) do
        local rawW = (frame.GetWidth and frame:GetWidth()) or 0
        local rawH = (frame.GetHeight and frame:GetHeight()) or 0
        local w = Snap(rawW > 0 and rawW or (size and size.w or 0))
        local h = Snap(rawH > 0 and rawH or (size and size.h or 0))
        if w < Pixel.GetSize() then w = Pixel.GetSize() end
        if h < Pixel.GetSize() then h = Pixel.GetSize() end
        widths[i] = w
        heights[i] = h
        totalWidth = totalWidth + w
        if i > 1 then
            totalWidth = totalWidth + gap
        end
        if h > maxHeight then
            maxHeight = h
        end
    end
    for i = visibleCount + 1, prevWidthsCount do
        widths[i] = nil
        heights[i] = nil
    end

    container:SetSize(totalWidth, maxHeight)

    local cursor = 0
    for i, frame in ipairs(visibleFrames) do
        frame:SetSize(widths[i], heights[i])
        frame:ClearAllPoints()
        if growLeft then
            Pixel.SetPoint(frame, "TOPRIGHT", container, "TOPRIGHT", -cursor, 0)
        else
            Pixel.SetPoint(frame, "TOPLEFT", container, "TOPLEFT", cursor, 0)
        end
        cursor = cursor + widths[i] + gap
    end
end

function CDM.AnchorToPlayerFrame(container, anchorPoint, offsetX, offsetY, moduleName, forceRefresh, containerAnchor)
    if not container then
        return
    end

    EnsureAnchorInvalidation()

    if forceRefresh then
        InvalidateTrackerAnchorCache(container)
    end

    local cached = trackerAnchorCache[container]
    local cacheCurrent = cached and cached.version == trackerAnchorCacheVersion

    if cacheCurrent and cached.targetFrame then
        local tf = cached.targetFrame
        if not (tf.IsShown and tf:IsShown()) then
            trackerAnchorCache[container] = nil
        else
            if cached.requestAnchorPoint == anchorPoint and cached.requestOffsetX == offsetX and cached.requestOffsetY == offsetY and cached.requestContainerAnchor == containerAnchor then
                return
            end
            SetTrackerContainerAnchor(container, anchorPoint, offsetX, offsetY, tf, containerAnchor)
            cached.requestAnchorPoint = anchorPoint
            cached.requestOffsetX = offsetX
            cached.requestOffsetY = offsetY
            cached.requestContainerAnchor = containerAnchor
            return
        end
    end

    local playerFrame = ResolvePlayerAnchorFrame()

    if playerFrame then
        if not container:IsShown() then
            container:Show()
        end
        SetTrackerContainerAnchor(container, anchorPoint, offsetX, offsetY, playerFrame, containerAnchor)
    else
        if not playerFrameRecheckTimer and container:IsShown() then
            container:Hide()
        end
        return
    end

    local entry = trackerAnchorCache[container]
    if not entry then
        entry = {}
        trackerAnchorCache[container] = entry
    else
        table.wipe(entry)
    end
    entry.version = trackerAnchorCacheVersion
    entry.targetFrame = playerFrame
    entry.requestAnchorPoint = anchorPoint
    entry.requestOffsetX = offsetX
    entry.requestOffsetY = offsetY
    entry.requestContainerAnchor = containerAnchor
end

function CDM.CreateTrackerUpdater(events, handler)
    local updater = CreateFrame("Frame")
    for _, event in ipairs(events) do
        updater:RegisterEvent(event)
    end
    updater:SetScript("OnEvent", handler)
    return updater
end

function CDM.CreateTrackerContainer(name)
    local c = CreateFrame("Frame", name, UIParent)
    c:SetSize(400, 40)
    c:SetFrameStrata(CDM_C.STRATA_MAIN)
    c:SetFrameLevel(10)
    return c
end

function CDM.GetTrackerSpacing()
    return CDM.db and CDM.db.spacing or 6
end

local trackerIconSizeCache = { w = 40, h = 36 }
function CDM.GetTrackerIconSize(widthKey, heightKey)
    local db = CDM.db
    trackerIconSizeCache.w = (db and db[widthKey]) or 40
    trackerIconSizeCache.h = (db and db[heightKey]) or 36
    return trackerIconSizeCache
end

function CDM.PositionTrackerIconsFromDB(container, iconFrames, widthKey, heightKey, spacingKey, anchorKey)
    local db = CDM.db
    local size = CDM.GetTrackerIconSize(widthKey, heightKey)
    local spacing = (db and db[spacingKey]) or 2
    local anchor = (db and db[anchorKey]) or "TOPLEFT"
    CDM.PositionTrackerIcons(container, iconFrames, size, spacing, anchor)
end

function CDM.AcquireFromTrackerPool(pool, container, namePrefix, id, opts)
    local frame = table.remove(pool)
    if frame then
        frame:SetParent(container)
        frame:ClearAllPoints()
        local size = opts and opts.size
        if size then
            frame:SetSize(size.w, size.h)
        end
        if frame.Cooldown then
            frame.Cooldown:Clear()
        end
        if frame.ChargeCount and frame.ChargeCount.Current then
            frame.ChargeCount.Current:Hide()
        end
        return frame, false
    end

    frame = CDM.CreateTrackerIcon(container, namePrefix, id, opts)
    return frame, true
end

function CDM.ReleaseToTrackerPool(pool, frame, extraCleanup)
    frame:Hide()
    frame:ClearAllPoints()
    if frame.Cooldown then
        frame.Cooldown:Clear()
    end
    if frame.ChargeCount and frame.ChargeCount.Current then
        frame.ChargeCount.Current:Hide()
    end
    frame.cdmTrackerStyleVersion = nil
    frame.cdmTrackerStyledW = nil
    frame.cdmTrackerStyledH = nil
    frame.cdmTrackerLastStyledVName = nil
    if extraCleanup then
        extraCleanup(frame)
    end
    pool[#pool + 1] = frame
end

function CDM.TrimTrackerPool(pool, activeCount)
    local maxPool = activeCount + 2
    while #pool > maxPool do
        local excess = table.remove(pool)
        if excess then
            excess:SetParent(nil)
            excess:Hide()
        end
    end
end

function CDM.ClearTrackerPool(pool)
    while #pool > 0 do
        local frame = table.remove(pool)
        if frame then
            frame:SetParent(nil)
            frame:Hide()
        end
    end
end

function CDM.RefreshChargeStyleCache(target, prefix)
    CDM_C.RefreshBaseFontCache()
    target.fontPath = CDM_C.GetBaseFontPath()
    target.fontOutline = CDM_C.GetBaseFontOutline()

    local db = CDM.db
    local defaults = CDM.defaults or {}
    target.chargeFontSize = db and db[prefix .. "ChargeFontSize"] or 10
    target.chargePosition = db and db[prefix .. "ChargePosition"] or "BOTTOMRIGHT"
    target.chargeOffsetX = db and db[prefix .. "ChargeOffsetX"] or 0
    target.chargeOffsetY = db and db[prefix .. "ChargeOffsetY"] or 0

    local srcColor = (db and db[prefix .. "ChargeColor"])
        or (db and db.chargeColor)
        or defaults.chargeColor
        or { r = 1, g = 1, b = 1, a = 1 }
    target.chargeColor.r = srcColor.r or 1
    target.chargeColor.g = srcColor.g or 1
    target.chargeColor.b = srcColor.b or 1
    target.chargeColor.a = srcColor.a or 1
end

function CDM.StyleChargeText(chargeText, frame, cachedStyles)
    chargeText:SetIgnoreParentScale(true)
    chargeText:ClearAllPoints()
    chargeText:SetPoint(cachedStyles.chargePosition, frame, cachedStyles.chargePosition, cachedStyles.chargeOffsetX, cachedStyles.chargeOffsetY)
    chargeText:SetFont(cachedStyles.fontPath, Pixel.FontSize(cachedStyles.chargeFontSize), cachedStyles.fontOutline)
    chargeText:SetTextColor(cachedStyles.chargeColor.r, cachedStyles.chargeColor.g, cachedStyles.chargeColor.b)
    chargeText:SetDrawLayer("OVERLAY", 7)
    chargeText:SetShadowOffset(0, 0)
    chargeText:Show()
end
