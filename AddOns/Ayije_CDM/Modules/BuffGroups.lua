local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local API = CDM.API
local CDM_C = CDM.CONST
local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local LSM = LibStub("LibSharedMedia-3.0")
local IsSafeNumber = CDM.IsSafeNumber

CDM.buffGroupContainers = {}

local containers = CDM.buffGroupContainers

local GCU = CDM.GroupContainerUtils
local BGP = CDM.BuffGroupPlaceholders
local ReleaseGroupPlaceholders = BGP.ReleaseGroup

local function GetContainerForAnchorTarget(anchorTarget)
    local anchorContainers = CDM.anchorContainers
    if not anchorContainers then return nil end
    if anchorTarget == "essential" then
        return anchorContainers[CDM_C.VIEWERS.ESSENTIAL]
    end
    if anchorTarget == "buff" then
        return anchorContainers[CDM_C.VIEWERS.BUFF]
    end
    return nil
end

local bgDescriptor = GCU.CreateDescriptor({
    containers = containers,
    namePrefix = "Ayije_CDM_BuffGroup",
    callbackPrefix = "CDM_BuffGroup_",
    getSets = function() return CDM.BuffGroupSets end,
})

local GetFrameData = CDM.GetFrameData
local NormalizeToBase = CDM.NormalizeToBase
local SV = CDM.SpellVariant
local StoreVariantValue = SV.StoreValue
local ResolveVariantValue = SV.ResolveValue
local layoutCtx = CDM._LayoutCtx
local DeriveSelfPoint = layoutCtx.DeriveSelfPoint
local GetStableFrameSortID = layoutCtx.GetStableFrameSortID

local EnsureAuraNotificationHook

local scratchSpellOrder = {}
local scratchSpellSlot = {}
local scratchActiveSpellIDs = {}
local scratchGroupSpellLookup = {}
local scratchPlaceholderBySpell = {}
local scratchActiveSet = {}
local scratchSlotToRawSpell = {}

local notificationThrottles = {}
local SOUND_THROTTLE = 1
local playerIsDead = false
local hadGroupedBuffGlows = false
local groupedGlowCleanupGeneration = 0
local groupedGlowCleanupActiveGeneration = 0

local function UpdatePlayerDeathState()
    playerIsDead = UnitIsDeadOrGhost("player") and true or false
end

local function AreBuffNotificationsReady()
    if playerIsDead then
        return false
    end
    if not CDM.loginFinished then
        return false
    end
    if CDM.loadingScreenActive then
        return false
    end
    local token = CDM.enterWorldToken or 0
    if token <= 0 then
        return false
    end
    return CDM.visualSetupToken == token
end

local function IsBuffNotificationThrottled(spellID, onHide, channel)
    if not spellID or not channel then
        return true
    end

    local channelBit = (channel == "tts") and 1 or 0
    local key = spellID * 4 + (onHide and 2 or 0) + channelBit
    local now = GetTime()
    local last = notificationThrottles[key]
    if last and now - last < SOUND_THROTTLE then
        return true
    end

    notificationThrottles[key] = now
    return false
end

local function PlayBuffSound(soundName, spellID, onHide)
    if not soundName then return end
    if IsBuffNotificationThrottled(spellID, onHide, "sound") then return end
    local path = LSM:Fetch("sound", soundName)
    if path then PlaySoundFile(path, "Master") end
end

local function PlayBuffTTS(text, spellID, onHide)
    if not text or text == "" then return end
    local voiceType = Enum and Enum.TtsVoiceType and Enum.TtsVoiceType.Standard or 0
    local voiceID = C_TTSSettings and C_TTSSettings.GetVoiceOptionID and C_TTSSettings.GetVoiceOptionID(voiceType)
    if not voiceID then return end
    if IsBuffNotificationThrottled(spellID, onHide, "tts") then return end
    local speechRate = (C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate()) or 0
    local speechVolume = (C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume()) or 100
    pcall(C_VoiceChat.SpeakText, voiceID, text, speechRate, speechVolume, false)
end

local function PlayBuffOverrideNotification(ov, spellID, onHide)
    if type(ov) ~= "table" or not spellID then
        return false
    end

    if ov.ttsEnabled and ((onHide and ov.ttsOnHideEnabled) or (not onHide and ov.ttsOnShowEnabled)) then
        local text = ov[onHide and "ttsOnHide" or "ttsOnShow"]
        text = (text and text ~= "") and text or C_Spell.GetSpellName(spellID)
        PlayBuffTTS(text, spellID, onHide)
        return true
    end

    if ov.soundEnabled and ((onHide and ov.soundOnHideEnabled ~= false) or (not onHide and ov.soundOnShowEnabled ~= false)) then
        local soundName = ov[onHide and "soundOnHide" or "soundOnShow"]
        if soundName then
            PlayBuffSound(soundName, spellID, onHide)
            return true
        end
    end

    return false
end

local function MarkSafe(set, id)
    if IsSafeNumber(id) then set[id] = true end
end

local function BuildActiveSpellSet()
    table.wipe(scratchActiveSet)
    local buffViewer = _G[CDM_C.VIEWERS.BUFF]
    if buffViewer and buffViewer.itemFramePool then
        for frame in buffViewer.itemFramePool:EnumerateActive() do
            MarkSafe(scratchActiveSet, frame.GetSpellID and frame:GetSpellID())
            local fd = GetFrameData(frame)
            local catID = fd and fd.buffCategorySpellID
            if catID and catID ~= false then MarkSafe(scratchActiveSet, catID) end
            local info = frame.GetCooldownInfo and frame:GetCooldownInfo()
            if info then
                MarkSafe(scratchActiveSet, info.spellID)
                MarkSafe(scratchActiveSet, info.overrideSpellID)
            end
        end
    end
    return scratchActiveSet
end

local function IsSpellActiveInViewer(spellID, cachedSet)
    if IsPlayerSpell(spellID) then return true end
    local baseID = NormalizeToBase(spellID)
    if baseID and baseID ~= spellID and IsPlayerSpell(baseID) then return true end
    if cachedSet then
        return cachedSet[spellID] or (baseID and cachedSet[baseID]) or false
    end
    return false
end

if API then
    rawset(API, "BuildActiveSpellSet", function()
        return BuildActiveSpellSet()
    end)

    rawset(API, "IsSpellActiveInViewer", function(_, spellID, cachedSet)
        return IsSpellActiveInViewer(spellID, cachedSet)
    end)
end

local function ResolveSpellOverrideEntry(overrideMap, spellID)
    return CDM:ResolveBuffOverrideEntry(overrideMap, spellID)
end

local function BuildGroupSpellLookup(spells)
    table.wipe(scratchGroupSpellLookup)
    if type(spells) ~= "table" then
        return scratchGroupSpellLookup
    end

    for _, listedID in ipairs(spells) do
        if listedID then
            StoreVariantValue(scratchGroupSpellLookup, listedID, true, false)
        end
    end

    return scratchGroupSpellLookup
end

local function IsSpellEligible(spellID, groupSpellLookup, activeSpellSet)
    if not spellID then return false end

    local registryMatched = false
    if CDM.CheckIDAgainstRegistry then
        local matchType = CDM.CheckIDAgainstRegistry(spellID)
        if matchType == "buffgroup" then
            registryMatched = true
        end
    end

    if not registryMatched then
        if type(groupSpellLookup) ~= "table" then
            return false
        end

        registryMatched = ResolveVariantValue(groupSpellLookup, spellID) == true
    end

    if not registryMatched then
        return false
    end

    return IsSpellActiveInViewer(spellID, activeSpellSet)
end

local function IsSpellMarkedActive(spellID, activeSpellIDs)
    return ResolveVariantValue(activeSpellIDs, spellID) == true
end

local function BuildStaticSlotLayout(groupData, activeSpellIDs, activeSpellSet, groupSpellLookup)
    table.wipe(scratchSpellSlot)
    table.wipe(scratchPlaceholderBySpell)
    table.wipe(scratchSlotToRawSpell)
    local nextSlot = 0

    for _, sid in ipairs(groupData.spells or {}) do
        local ov = groupData.spellOverrides
        local spellOv = ov and ResolveSpellOverrideEntry(ov, sid) or nil
        local base = NormalizeToBase(sid)
        local isTracked = activeSpellSet and (activeSpellSet[sid] or (base and activeSpellSet[base])) or false
        local wantPlaceholder = spellOv and spellOv.placeholder and isTracked or false
        scratchPlaceholderBySpell[sid] = wantPlaceholder or nil

        if isTracked then
            scratchSlotToRawSpell[nextSlot] = sid
            StoreVariantValue(scratchSpellSlot, sid, nextSlot, true)
            nextSlot = nextSlot + 1
        end
    end

    return scratchSpellSlot, scratchPlaceholderBySpell, nextSlot
end

local PositionFrameAtSlot = layoutCtx.PositionFrameAtSlot

local OverrideCooldownText = layoutCtx.OverrideCooldownText
local GetCooldownFontRegions = layoutCtx.GetCooldownFontRegions
local OverrideCooldownRegions = layoutCtx.OverrideCooldownRegions

local function GetSpellOverride(groupData, spellID)
    return ResolveSpellOverrideEntry(groupData and groupData.spellOverrides, spellID)
end

local function SetCooldownTextHidden(frame, hidden)
    local cd = frame.Cooldown
    if cd then
        if cd.SetHideCountdownNumbers then
            cd:SetHideCountdownNumbers(hidden)
        end
        local t = cd.Text or cd.text
        if t then
            if hidden then t:Hide(); t:SetAlpha(0) else t:Show(); t:SetAlpha(1) end
        end
        local regions = GetCooldownFontRegions(cd)
        for _, region in ipairs(regions) do
            if hidden then region:Hide(); region:SetAlpha(0) else region:Show(); region:SetAlpha(1) end
        end
    end
    if frame.Time then
        if hidden then frame.Time:Hide(); frame.Time:SetAlpha(0) else frame.Time:Show(); frame.Time:SetAlpha(1) end
    end
    if frame.Duration then
        if hidden then frame.Duration:Hide(); frame.Duration:SetAlpha(0) else frame.Duration:Show(); frame.Duration:SetAlpha(1) end
    end
end

function CDM:RestoreCooldownTextIfHidden(frame)
    local frameData = GetFrameData(frame)
    if frameData.cdmCooldownTextHidden then
        SetCooldownTextHidden(frame, false)
        frameData.cdmCooldownTextHidden = nil
    end
end

function CDM:HideCooldownTextIfFlagged(frame)
    local frameData = GetFrameData(frame)
    if frameData.cdmCooldownTextHidden then
        SetCooldownTextHidden(frame, true)
    end
end

local function HideFrameVisuals(frame, frameData)
    if frame.Icon then frame.Icon:SetAlpha(0) end
    if frame.Cooldown and frame.Cooldown.SetDrawSwipe then
        frame.Cooldown:SetDrawSwipe(false)
    end
    if frameData.borderFrame and frameData.borderFrame.border then
        frameData.borderFrame.border:Hide()
    end
    if frameData.pixelIconBorderFrame then
        frameData.pixelIconBorderFrame:Hide()
    end
    frameData.cdmVisualsHidden = true
end

local function RestoreFrameVisuals(frame, frameData)
    if frame.Icon then frame.Icon:SetAlpha(1) end
    if frame.Cooldown and frame.Cooldown.SetDrawSwipe then
        frame.Cooldown:SetDrawSwipe(true)
    end
    if frameData.borderFrame and frameData.borderFrame.border then
        frameData.borderFrame.border:Show()
    end
    if frameData.pixelIconBorderFrame then
        frameData.pixelIconBorderFrame:Show()
    end
    frameData.cdmVisualsHidden = nil
end

function CDM:RestoreVisualsIfHidden(frame)
    local frameData = GetFrameData(frame)
    if frameData.cdmVisualsHidden then
        RestoreFrameVisuals(frame, frameData)
    end
end

local function ApplyGlowForGroupedFrame(frame, specID)
    if not (frame and CDM.Glow) then return end
    local frameData = GetFrameData(frame)
    if not specID then
        CDM.Glow:RequestBuffGlow(frame, false, nil, nil)
        if frameData then
            frameData.cdmGroupedGlowCleanupGeneration = groupedGlowCleanupActiveGeneration
        end
        hadGroupedBuffGlows = false
        return
    end

    local hasBuffGlows = CDM.HasAnySpellGlowConfigured and CDM:HasAnySpellGlowConfigured(specID) or false
    if not hasBuffGlows then
        if hadGroupedBuffGlows then
            groupedGlowCleanupGeneration = groupedGlowCleanupGeneration + 1
            groupedGlowCleanupActiveGeneration = groupedGlowCleanupGeneration
            hadGroupedBuffGlows = false
        end

        if groupedGlowCleanupActiveGeneration ~= 0
            and frameData
            and frameData.cdmGroupedGlowCleanupGeneration ~= groupedGlowCleanupActiveGeneration then
            frameData.cdmGroupedGlowCleanupGeneration = groupedGlowCleanupActiveGeneration
            CDM.Glow:RequestBuffGlow(frame, false, nil, nil)
        end
        return
    end

    hadGroupedBuffGlows = true

    local glowEnabled, glowColor, glowSourceID = false, nil, nil
    if CDM.ResolveBuffGlowState then
        glowEnabled, glowColor, glowSourceID = CDM:ResolveBuffGlowState(frame, specID, true)
    end
    CDM.Glow:RequestBuffGlow(frame, glowEnabled, glowColor, glowSourceID)
end

function CDM:CreateBuffGroupContainer(groupIndex)
    return bgDescriptor:GetOrCreateContainer(groupIndex)
end

function CDM:UpdateBuffGroupContainerPosition(groupIndex)
    local sets = self.BuffGroupSets
    if not sets or not sets.groups then return end
    local groupData = sets.groups[groupIndex]
    if not groupData then return end
    bgDescriptor:UpdateContainerPosition(groupIndex, groupData, GetContainerForAnchorTarget)
end

local scratchBgActiveIndices = {}

function CDM:UpdateAllBuffGroupContainers()
    local sets = self.BuffGroupSets
    if not sets or not sets.groups then
        for idx, container in pairs(containers) do
            container:Hide()
            ReleaseGroupPlaceholders(idx)
        end
        bgDescriptor:SyncCallbacks(GetContainerForAnchorTarget)
        return
    end

    local activeIndices = scratchBgActiveIndices
    table.wipe(activeIndices)
    for groupIndex, groupData in ipairs(sets.groups) do
        local container = bgDescriptor:GetOrCreateContainer(groupIndex)
        bgDescriptor:UpdateContainerPosition(groupIndex, groupData, GetContainerForAnchorTarget)
        local at = groupData.anchorTarget or "screen"
        if not container:IsShown() and at ~= "essential" and at ~= "buff" and at ~= "playerFrame" then
            container:Show()
        end
        activeIndices[groupIndex] = true
    end

    for idx, container in pairs(containers) do
        if not activeIndices[idx] then
            container:Hide()
            ReleaseGroupPlaceholders(idx)
        end
    end

    bgDescriptor:SyncCallbacks(GetContainerForAnchorTarget)
end


function CDM:PositionBuffGroupFrames(groupIndex, frames, activeSpellSetParam)
    local sets = self.BuffGroupSets
    if not sets or not sets.groups then return end

    local groupData = sets.groups[groupIndex]
    if not groupData then return end

    local container = bgDescriptor:GetOrCreateContainer(groupIndex)

    if not container:IsShown() then
        for _, frame in ipairs(frames) do
            frame:Hide()
        end
        ReleaseGroupPlaceholders(groupIndex)
        return
    end

    local grow = groupData.grow
    if grow ~= "RIGHT" and grow ~= "LEFT" and grow ~= "UP" and grow ~= "DOWN" and grow ~= "CENTER_H" and grow ~= "CENTER_V" then
        grow = "RIGHT"
    end
    local spacing = groupData.spacing or 4
    local iconW = groupData.iconWidth or 30
    local iconH = groupData.iconHeight or 30
    local anchorPoint = groupData.anchorPoint or "CENTER"
    local selfPoint = DeriveSelfPoint(anchorPoint, grow)
    local iconWSnapped = Snap(iconW)
    local iconHSnapped = Snap(iconH)
    local spacingSnapped = Snap(spacing)
    local count = #frames
    local shownCount = 0
    for _, f in ipairs(frames) do
        if f:IsShown() then shownCount = shownCount + 1 end
    end
    local isStatic = groupData.staticDisplay and groupData.spells
    local layoutCount
    if isStatic then
        layoutCount = #groupData.spells
    else
        layoutCount = shownCount > 0 and shownCount or count
    end

    container:SetSize(iconWSnapped, iconHSnapped)

    if count == 0 and not isStatic then
        ReleaseGroupPlaceholders(groupIndex)
        return
    end

    local spellSlot
    local activeSpellSet
    local placeholderBySpell
    if groupData.spells then
        table.wipe(scratchSpellOrder)
        for i, sid in ipairs(groupData.spells) do
            StoreVariantValue(scratchSpellOrder, sid, i, true)
        end
        if count > 1 then
            GCU.AssignGroupSortKeys(frames, scratchSpellOrder, "buffCategorySpellID")
            table.sort(frames, function(a, b)
                local aKey = GetFrameData(a).cdmSortKey
                local bKey = GetFrameData(b).cdmSortKey
                if aKey ~= bKey then return aKey < bKey end
                return GetStableFrameSortID(a) < GetStableFrameSortID(b)
            end)
        end
    end

    if isStatic then
        activeSpellSet = activeSpellSetParam or BuildActiveSpellSet()
        table.wipe(scratchActiveSpellIDs)
        for _, frame in ipairs(frames) do
            if frame:IsShown() then
                local sid = GetFrameData(frame).buffCategorySpellID
                if sid then
                    StoreVariantValue(scratchActiveSpellIDs, sid, true, false)
                end
            end
        end
        local groupSpellLookup = BuildGroupSpellLookup(groupData.spells)
        spellSlot, placeholderBySpell, layoutCount = BuildStaticSlotLayout(groupData, scratchActiveSpellIDs, activeSpellSet, groupSpellLookup)
        if layoutCount <= 0 then
            ReleaseGroupPlaceholders(groupIndex)
            return
        end
    else
        spellSlot = nil
    end


    local countPos = groupData.countPosition or "BOTTOMRIGHT"
    local countOX = groupData.countOffsetX or 0
    local countOY = groupData.countOffsetY or 0
    local countFS = groupData.countFontSize or 15
    local countColor = groupData.countColor or { r = 1, g = 1, b = 1, a = 1 }
    local cdFS = groupData.cooldownFontSize or 12
    local cdColor = groupData.cooldownColor or { r = 1, g = 1, b = 1 }
    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID() or nil

    local shownIdx = 0
    for i, frame in ipairs(frames) do
        EnsureAuraNotificationHook(frame)
        local idx
        local rawSpellID
        if spellSlot then
            local sid = GetFrameData(frame).buffCategorySpellID
            if sid then
                idx = ResolveVariantValue(spellSlot, sid)
                if idx then
                    rawSpellID = scratchSlotToRawSpell[idx]
                end
            end
            if not idx then
                local fInfo = frame.GetCooldownInfo and frame:GetCooldownInfo() or frame.cooldownInfo
                if fInfo and fInfo.linkedSpellIDs then
                    for _, lid in ipairs(fInfo.linkedSpellIDs) do
                        if IsSafeNumber(lid) then
                            local slotIdx = ResolveVariantValue(spellSlot, lid)
                            if slotIdx then
                                idx = slotIdx
                                rawSpellID = scratchSlotToRawSpell[slotIdx]
                                break
                            end
                        end
                    end
                end
            end
            if not idx then
                frame:Hide()
                BGP.SyncGroupedFrameState(frame, nil, nil, nil)
            end
        else
            if frame:IsShown() then
                idx = shownIdx
                shownIdx = shownIdx + 1
            else
                idx = layoutCount + (i - 1)
            end
        end
        if idx then
        self:ApplyStyle(frame, CDM_C.VIEWERS.BUFF)
        frame:ClearAllPoints()
        frame:SetSize(iconWSnapped, iconHSnapped)
        if frame.Icon then
            CDM_C.ApplyIconTexCoord(frame.Icon, CDM_C.GetEffectiveZoomAmount(), iconWSnapped, iconHSnapped)
        end

        PositionFrameAtSlot(frame, container, idx, iconWSnapped, iconHSnapped, spacingSnapped, grow, layoutCount, anchorPoint, selfPoint)

        local frameData = GetFrameData(frame)
        local fSpellID = frameData.buffCategorySpellID
        local spellOv = GetSpellOverride(groupData, fSpellID)
        local useTextOv = spellOv and spellOv.textOverride

        local fCountPos = (useTextOv and spellOv.countPosition) or countPos
        local fCountOX  = (useTextOv and spellOv.countOffsetX)  or countOX
        local fCountOY  = (useTextOv and spellOv.countOffsetY)  or countOY
        local fCountFS  = (useTextOv and spellOv.countFontSize)  or countFS
        local fCountColor = (useTextOv and spellOv.countColor)  or countColor
        local fCdFS     = (useTextOv and spellOv.cooldownFontSize) or cdFS
        local fCdColor  = (useTextOv and spellOv.cooldownColor) or cdColor
        local fCdPixelSize = fCdFS and Pixel.FontSize(fCdFS)

        local countText = frame.Applications and frame.Applications.Applications
        if countText then
            local fCountPixelSize = fCountFS and Pixel.FontSize(fCountFS)
            if frameData.cdmLastCountFS ~= fCountPixelSize
                or frameData.cdmLastCountPos ~= fCountPos
                or frameData.cdmLastCountOX ~= fCountOX
                or frameData.cdmLastCountOY ~= fCountOY
                or frameData.cdmLastCountColorR ~= fCountColor.r
                or frameData.cdmLastCountColorG ~= fCountColor.g
                or frameData.cdmLastCountColorB ~= fCountColor.b then
                if fCountPixelSize then
                    local fontPath, _, fontFlags = countText:GetFont()
                    if fontPath then
                        countText:SetFont(fontPath, fCountPixelSize, fontFlags)
                    end
                end
                if fCountColor then
                    countText:SetTextColor(fCountColor.r, fCountColor.g, fCountColor.b, fCountColor.a or 1)
                end
                countText:ClearAllPoints()
                Pixel.SetPoint(countText, fCountPos, frame, fCountPos, fCountOX, fCountOY)
                frameData.cdmLastCountFS = fCountPixelSize
                frameData.cdmLastCountPos = fCountPos
                frameData.cdmLastCountOX = fCountOX
                frameData.cdmLastCountOY = fCountOY
                frameData.cdmLastCountColorR = fCountColor.r
                frameData.cdmLastCountColorG = fCountColor.g
                frameData.cdmLastCountColorB = fCountColor.b
            end
        end

        local fHideCooldown = spellOv and spellOv.hideCooldown

        if fHideCooldown then
            SetCooldownTextHidden(frame, true)
            frameData.cdmCooldownTextHidden = true
        else
            if frameData.cdmCooldownTextHidden then
                SetCooldownTextHidden(frame, false)
                frameData.cdmCooldownTextHidden = nil
            end
            if fCdFS or fCdColor then
                local cd = frame.Cooldown
                if cd then
                    OverrideCooldownText(cd.Text or cd.text, fCdPixelSize, fCdColor)
                    OverrideCooldownRegions(cd, fCdPixelSize, fCdColor)
                end
                OverrideCooldownText(frame.Time, fCdPixelSize, fCdColor)
                OverrideCooldownText(frame.Duration, fCdPixelSize, fCdColor)
            end
        end

        local fHideVisuals = spellOv and spellOv.hideVisuals

        if fHideVisuals then
            HideFrameVisuals(frame, frameData)
        elseif frameData.cdmVisualsHidden then
            RestoreFrameVisuals(frame, frameData)
        end

        if fHideVisuals then
            if CDM.Glow then CDM.Glow:RequestBuffGlow(frame, false, nil, nil) end
        else
            ApplyGlowForGroupedFrame(frame, specID)
        end

        if isStatic then
            local phEligible = rawSpellID and placeholderBySpell and placeholderBySpell[rawSpellID] and true or false
            BGP.SyncGroupedFrameState(frame, groupIndex, rawSpellID, phEligible)
        else
            BGP.SyncGroupedFrameState(frame, nil, nil, nil)
        end
        end

    end

    if isStatic then
        BGP.ReconcileGroup(groupIndex, {
            spellSlot = spellSlot,
            placeholderBySpell = placeholderBySpell,
            groupData = groupData,
            container = container,
            iconW = iconW,
            iconH = iconH,
            iconWPx = iconWSnapped,
            iconHPx = iconHSnapped,
            spacingPx = spacingSnapped,
            grow = grow,
            layoutCount = layoutCount,
            anchorPoint = anchorPoint,
            selfPoint = selfPoint,
            activeSpellIDs = scratchActiveSpellIDs,
            positionFrameAtSlot = PositionFrameAtSlot,
            isSpellMarkedActive = IsSpellMarkedActive,
        })
    else
        ReleaseGroupPlaceholders(groupIndex)
    end

end

CDM:RegisterRefreshCallback("buffGroups", function()
    table.wipe(notificationThrottles)
    BGP.ReleaseAll()
    CDM:MarkSpecDataDirty()
    CDM:RefreshSpecData()
    CDM:UpdateAllBuffGroupContainers()
end, 29, { "spec_data", "viewers", "trackers_layout" })

CDM:RegisterRefreshCallback("buffGroups_postViewer", function()
    CDM:UpdateAllBuffGroupContainers()
end, 45, { "viewers" })

UpdatePlayerDeathState()
CDM:RegisterEvent("PLAYER_ENTERING_WORLD", UpdatePlayerDeathState)
CDM:RegisterEvent("PLAYER_ENTERING_WORLD", function() table.wipe(notificationThrottles) end)
CDM:RegisterEvent("PLAYER_DEAD", UpdatePlayerDeathState)
CDM:RegisterEvent("PLAYER_ALIVE", UpdatePlayerDeathState)
CDM:RegisterEvent("PLAYER_UNGHOST", UpdatePlayerDeathState)

function CDM:GetUngroupedBuffOverride(spellID)
    if not spellID then return nil end
    local specID = self.GetCurrentSpecID and self:GetCurrentSpecID()
    if not specID then return nil end
    local db = self.db
    if not db or not db.ungroupedBuffOverrides then return nil end
    local specOv = db.ungroupedBuffOverrides[specID]
    if not specOv then return nil end
    return ResolveSpellOverrideEntry(specOv, spellID)
end

local function OnBuffAuraNotification(frame, onHide)
    if not AreBuffNotificationsReady() then return end
    local candidates = CDM.GetSpellIDCandidates and CDM:GetSpellIDCandidates(frame, true)
    if not candidates then return end

    for _, id in ipairs(candidates) do
        local matchType, matchID, groupIdx = CDM.CheckIDAgainstRegistry(id)
        if matchType == "buffgroup" and groupIdx then
            local sets = CDM.BuffGroupSets
            local groupData = sets and sets.groups and sets.groups[groupIdx]
            local ov = GetSpellOverride(groupData, matchID)
            PlayBuffOverrideNotification(ov, matchID, onHide)
            return
        end
    end

    for _, id in ipairs(candidates) do
        local ov = CDM:GetUngroupedBuffOverride(id)
        if ov then
            PlayBuffOverrideNotification(ov, id, onHide)
            return
        end
    end
end

local auraHookedFrames = setmetatable({}, { __mode = "k" })

EnsureAuraNotificationHook = function(frame)
    if auraHookedFrames[frame] then return end
    auraHookedFrames[frame] = true
    if frame.TriggerAuraAppliedAlert then
        hooksecurefunc(frame, "TriggerAuraAppliedAlert", function(f)
            OnBuffAuraNotification(f, false)
        end)
    end
    if frame.TriggerAuraRemovedAlert then
        hooksecurefunc(frame, "TriggerAuraRemovedAlert", function(f)
            OnBuffAuraNotification(f, true)
        end)
    end
end

function CDM:ApplyUngroupedBuffOverrides(frame)
    if not frame then return end
    EnsureAuraNotificationHook(frame)
    local frameData = GetFrameData(frame)
    local ov
    local matchedSpellID
    if self.GetSpellIDCandidates then
        local candidates = self:GetSpellIDCandidates(frame, true)
        for _, candidateID in ipairs(candidates) do
            ov = self:GetUngroupedBuffOverride(candidateID)
            if ov then
                matchedSpellID = candidateID
                break
            end
        end
    end

    if not ov then return end
    matchedSpellID = NormalizeToBase(matchedSpellID) or matchedSpellID

    local db = self.db

    if ov.hideCooldown then
        SetCooldownTextHidden(frame, true)
        frameData.cdmCooldownTextHidden = true
    end

    if ov.hideVisuals then
        HideFrameVisuals(frame, frameData)
        if CDM.Glow then CDM.Glow:RequestBuffGlow(frame, false, nil, nil) end
    end

    local useTextOv = ov.textOverride

    if not ov.hideCooldown then
        local cdFS = (useTextOv and ov.cooldownFontSize) or (db and db.buffCooldownFontSize or 12)
        local cdColor = (useTextOv and ov.cooldownColor) or (db and db.buffCooldownColor)
        local cdPixelSize = cdFS and Pixel.FontSize(cdFS)
        local cd = frame.Cooldown
        if cd then
            OverrideCooldownText(cd.Text or cd.text, cdPixelSize, cdColor)
            OverrideCooldownRegions(cd, cdPixelSize, cdColor)
        end
        OverrideCooldownText(frame.Time, cdPixelSize, cdColor)
        OverrideCooldownText(frame.Duration, cdPixelSize, cdColor)
    end

    local countText = frame.Applications and frame.Applications.Applications
    if countText then
        local countFS = (useTextOv and ov.countFontSize) or (db and db.countFontSize or 15)
        local countColor = (useTextOv and ov.countColor) or (db and db.countColor)
        local countPos = (useTextOv and ov.countPosition) or (db and db.countPositionMain or "TOP")
        local countOX = (useTextOv and ov.countOffsetX) or (db and db.countOffsetXMain or 0)
        local countOY = (useTextOv and ov.countOffsetY) or (db and db.countOffsetYMain or 0)
        if countFS then
            local fontPath, _, fontFlags = countText:GetFont()
            if fontPath then
                countText:SetFont(fontPath, Pixel.FontSize(countFS), fontFlags)
            end
        end
        if countColor then
            countText:SetTextColor(countColor.r, countColor.g, countColor.b, countColor.a or 1)
        end
        countText:ClearAllPoints()
        Pixel.SetPoint(countText, countPos, frame, countPos, countOX, countOY)
    end
end
