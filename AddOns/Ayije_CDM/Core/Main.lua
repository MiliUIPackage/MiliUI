local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local _G = _G
local ProvisionalPlaceBuffFrame = CDM.ProvisionalPlaceBuffFrame
local CheckIDAgainstRegistry = CDM.CheckIDAgainstRegistry
local RefreshStyleCache = CDM.RefreshStyleCache
local ResetFrameSpellCache = CDM.ResetFrameSpellCache
local GetCachedBaseSpellID = CDM.GetCachedBaseSpellID
local GetSpellIDCandidates = CDM.GetSpellIDCandidates

local VIEWERS = CDM_C.VIEWERS
local ALL_VIEWER_NAMES = {
    VIEWERS.ESSENTIAL,
    VIEWERS.UTILITY,
    VIEWERS.BUFF,
    VIEWERS.BUFF_BAR,
}
local UPDATE_CONSTANTS_METHODS = {
    "UpdateRacials",
    "UpdateDefensives",
    "UpdateTrinkets",
    "UpdateResources",
}
local LSM_MEDIA_EVENT = "LibSharedMedia_Registered"


local CDM_ViewerHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerOnAcquireHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerIconSizeHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerPoolAcquireHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerPoolReleaseHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerOnShowHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerSyncHooked = setmetatable({}, { __mode = "k" })

local function QueueBuffLikeViewerFromItemHooks(name)
    CDM:QueueViewer(name)
end

CDM.combatDirtyViewers = {}

local d = CDM.defaults
local SIZE_ESS_ROW1 = { w = d.sizeEssRow1.w, h = d.sizeEssRow1.h }
local SIZE_ESS_ROW2 = { w = d.sizeEssRow2.w, h = d.sizeEssRow2.h }
local SIZE_UTILITY = { w = d.sizeUtility.w, h = d.sizeUtility.h }
local SIZE_BUFF = { w = d.sizeBuff.w, h = d.sizeBuff.h }
local SIZE_RACIALS = { w = d.racialsIconWidth, h = d.racialsIconHeight }
local SIZE_DEFENSIVES = { w = d.defensivesIconWidth, h = d.defensivesIconHeight }
local SIZE_TRINKETS = { w = d.trinketsIconWidth, h = d.trinketsIconHeight }
local SPACING = d.spacing
local MAX_ROW_ESS = d.maxRowEss
local MAX_ROW_UTIL = d.maxRowUtil
local UTILITY_Y_OFFSET = d.utilityYOffset or 0
local UTILITY_VERTICAL = d.utilityVertical or false
local UTILITY_X_OFFSET = d.utilityXOffset or 0

CDM.Sizes = CDM.Sizes or {}
CDM.Sizes.SIZE_ESS_ROW1 = SIZE_ESS_ROW1
CDM.Sizes.SIZE_ESS_ROW2 = SIZE_ESS_ROW2
CDM.Sizes.SIZE_UTILITY = SIZE_UTILITY
CDM.Sizes.SIZE_BUFF = SIZE_BUFF
CDM.Sizes.SIZE_RACIALS = SIZE_RACIALS
CDM.Sizes.SIZE_DEFENSIVES = SIZE_DEFENSIVES
CDM.Sizes.SIZE_TRINKETS = SIZE_TRINKETS
CDM.Sizes.SPACING = SPACING
CDM.Sizes.MAX_ROW_ESS = MAX_ROW_ESS
CDM.Sizes.MAX_ROW_UTIL = MAX_ROW_UTIL
CDM.Sizes.UTILITY_Y_OFFSET = UTILITY_Y_OFFSET
CDM.Sizes.UTILITY_VERTICAL = UTILITY_VERTICAL
CDM.Sizes.UTILITY_X_OFFSET = UTILITY_X_OFFSET

local function InitConstants()
    local sizeEssRow1 = CDM_C.GetConfigValue("sizeEssRow1", d.sizeEssRow1)
    local sizeEssRow2 = CDM_C.GetConfigValue("sizeEssRow2", d.sizeEssRow2)
    local sizeUtility = CDM_C.GetConfigValue("sizeUtility", d.sizeUtility)
    local sizeBuff = CDM_C.GetConfigValue("sizeBuff", d.sizeBuff)

    SIZE_ESS_ROW1.w = sizeEssRow1.w or d.sizeEssRow1.w
    SIZE_ESS_ROW1.h = sizeEssRow1.h or d.sizeEssRow1.h
    SIZE_ESS_ROW2.w = sizeEssRow2.w or d.sizeEssRow2.w
    SIZE_ESS_ROW2.h = sizeEssRow2.h or d.sizeEssRow2.h
    SIZE_UTILITY.w = sizeUtility.w or d.sizeUtility.w
    SIZE_UTILITY.h = sizeUtility.h or d.sizeUtility.h
    SIZE_BUFF.w = sizeBuff.w or d.sizeBuff.w
    SIZE_BUFF.h = sizeBuff.h or d.sizeBuff.h
    SIZE_RACIALS.w = CDM_C.GetConfigValue("racialsIconWidth", d.racialsIconWidth) or d.racialsIconWidth
    SIZE_RACIALS.h = CDM_C.GetConfigValue("racialsIconHeight", d.racialsIconHeight) or d.racialsIconHeight
    SIZE_DEFENSIVES.w = CDM_C.GetConfigValue("defensivesIconWidth", d.defensivesIconWidth) or d.defensivesIconWidth
    SIZE_DEFENSIVES.h = CDM_C.GetConfigValue("defensivesIconHeight", d.defensivesIconHeight) or d.defensivesIconHeight
    SIZE_TRINKETS.w = CDM_C.GetConfigValue("trinketsIconWidth", d.trinketsIconWidth) or d.trinketsIconWidth
    SIZE_TRINKETS.h = CDM_C.GetConfigValue("trinketsIconHeight", d.trinketsIconHeight) or d.trinketsIconHeight
    SPACING = CDM_C.GetConfigValue("spacing", d.spacing) or d.spacing
    MAX_ROW_ESS = CDM_C.GetConfigValue("maxRowEss", d.maxRowEss) or d.maxRowEss
    local utilityWrap = CDM_C.GetConfigValue("utilityWrap", d.utilityWrap)
    if utilityWrap then
        MAX_ROW_UTIL = CDM_C.GetConfigValue("maxRowUtil", d.maxRowUtil) or d.maxRowUtil
    else
        MAX_ROW_UTIL = 0
    end
    UTILITY_Y_OFFSET = CDM_C.GetConfigValue("utilityYOffset", d.utilityYOffset) or d.utilityYOffset

    local utilityUnlock = utilityWrap and CDM_C.GetConfigValue("utilityUnlock", d.utilityUnlock)
    if utilityUnlock then
        UTILITY_VERTICAL = CDM_C.GetConfigValue("utilityVertical", d.utilityVertical)
        UTILITY_X_OFFSET = CDM_C.GetConfigValue("utilityXOffset", d.utilityXOffset) or d.utilityXOffset
    else
        UTILITY_VERTICAL = false
        UTILITY_X_OFFSET = 0
    end

    CDM.Sizes.SPACING = SPACING
    CDM.Sizes.MAX_ROW_ESS = MAX_ROW_ESS
    CDM.Sizes.MAX_ROW_UTIL = MAX_ROW_UTIL
    CDM.Sizes.UTILITY_Y_OFFSET = UTILITY_Y_OFFSET
    CDM.Sizes.UTILITY_VERTICAL = UTILITY_VERTICAL
    CDM.Sizes.UTILITY_X_OFFSET = UTILITY_X_OFFSET
end

local function UpdateConstants()
    InitConstants()

    local buffContainer = CDM.anchorContainers and CDM.anchorContainers["BuffIconCooldownViewer"]
    if buffContainer then
        buffContainer:SetSize(CDM_C.SnapContainerWidth(400, buffContainer), CDM_C.SnapOffsetToPixel(SIZE_BUFF.h, buffContainer))
    end

    for _, methodName in ipairs(UPDATE_CONSTANTS_METHODS) do
        local method = CDM[methodName]
        if method then method(CDM) end
    end
end

CDM.UpdateConstants = UpdateConstants

function CDM:GetConstants()
    return CDM.Sizes
end

CDM.queue = {}
CDM.queueVersion = 0
CDM.anchorContainers = {}
CDM.loadingScreenActive = false
CDM.enterWorldToken = 0
CDM.visualSetupToken = 0
CDM.pendingSpecChange = false
CDM.pendingTalentChange = false
CDM.isEditModeActive = false

local Updater = CreateFrame("Frame")

local function RefreshFrameSpellIdentity(frame)
    if not frame then return end
    ResetFrameSpellCache(CDM, frame)
    return GetCachedBaseSpellID(CDM, frame)
end

local function HookViewerLayout(viewer, name)
    if CDM_ViewerHooked[viewer] then return end
    CDM_ViewerHooked[viewer] = true

    local isBuffLike = (name == VIEWERS.BUFF or name == VIEWERS.BUFF_BAR)
    local queueOnRefreshLayout = (name == VIEWERS.ESSENTIAL) or (name == VIEWERS.UTILITY)
    local function QueuePostLayoutViewer()
        CDM:QueueViewer(name, true)
    end

    if viewer.RefreshData and isBuffLike then
        hooksecurefunc(viewer, "RefreshData", function()
            CDM:QueueViewer(name, true)
        end)
    end

    if viewer.UpdateLayout then
        hooksecurefunc(viewer, "UpdateLayout", QueuePostLayoutViewer)
    elseif viewer.Layout then
        hooksecurefunc(viewer, "Layout", QueuePostLayoutViewer)
    end

    if viewer.RefreshLayout and queueOnRefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", function()
            CDM:QueueViewer(name, true)
        end)
    end

end

local updaterActive = false

local function GetSelectedTextFontName()
    return CDM_C.GetConfigValue("textFont", "Friz Quadrata TT")
end

local function OnLSMMediaRegistered(_, mediaType, key)
    if mediaType ~= "font" or type(key) ~= "string" then
        return
    end

    if key ~= GetSelectedTextFontName() then
        return
    end

    CDM:RefreshConfig()
end

local function RegisterLSMFontRefreshCallback()
    if CDM._lsmFontCallbackRegistered then
        return
    end

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local callbacks = LSM and LSM.callbacks
    if not (callbacks and callbacks.RegisterCallback) then
        return
    end

    callbacks.RegisterCallback(CDM, LSM_MEDIA_EVENT, OnLSMMediaRegistered)
    CDM._lsmFontCallbackRegistered = true
end

local function RegisterPostLoginFontRefresh()
    if CDM._postLoginFontRefreshRegistered then
        return
    end
    CDM._postLoginFontRefreshRegistered = true

    CDM:RegisterEvent("PLAYER_LOGIN", function()
        C_Timer.After(0, function()
            CDM:RefreshConfig()
        end)
    end)
end

local function QueueCooldownViewerSettingsVisualRefresh()
    CDM:QueueViewer(VIEWERS.ESSENTIAL)
    CDM:QueueViewer(VIEWERS.UTILITY)
    CDM:QueueViewer(VIEWERS.BUFF)
    CDM:QueueViewer(VIEWERS.BUFF_BAR)

end

local function QueueAllViewersAfterSettingsClose()
    C_Timer.After(0.1, function()
        CDM:QueueAllViewers(true)
    end)
end

local function RegisterCooldownViewerSettingsVisualRefresh()
    if CDM._cooldownViewerSettingsVisualRefreshRegistered then
        return
    end

    local registry = EventRegistry
    if not (registry and registry.RegisterCallback) then
        return
    end

    local onShowOwner = {}
    registry:RegisterCallback("CooldownViewerSettings.OnShow", function()
        QueueCooldownViewerSettingsVisualRefresh()
    end, onShowOwner)

    local onHideOwner = {}
    registry:RegisterCallback("CooldownViewerSettings.OnHide", function()
        QueueAllViewersAfterSettingsClose()
    end, onHideOwner)

    CDM._cooldownViewerSettingsVisualRefreshRegistered = true
end

local function QueueProcessor()
    if not next(CDM.queue) then
        updaterActive = false
        Updater:SetScript("OnUpdate", nil)
        return
    end

    if CDM.pendingSpecChange then
        return
    end

    for name, version in pairs(CDM.queue) do
        if version ~= CDM.queueVersion then
            CDM.queue[name] = nil
        else
            local v = _G[name]
            if not v or CDM:ForceReanchor(v) ~= false then
                CDM.queue[name] = nil
                break
            end
        end
    end

    if not next(CDM.queue) then
        updaterActive = false
        Updater:SetScript("OnUpdate", nil)
    end
end

function CDM:QueueViewer(name, immediate, version)
    local qv = version or self.queueVersion or 0

    if immediate and not self.pendingSpecChange then
        local v = _G[name]
        if v then self:ForceReanchor(v) end
        return
    end

    if self.queue[name] == qv then return end

    if name == VIEWERS.BUFF then
        if self.MarkBuffCenteringDirty then self:MarkBuffCenteringDirty() end
    elseif name == VIEWERS.UTILITY and self.InvalidateUtilityVisibleCountCache then
        self:InvalidateUtilityVisibleCountCache()
    end

    self.queue[name] = qv
    if not updaterActive then
        updaterActive = true
        Updater:SetScript("OnUpdate", QueueProcessor)
    end
end

function CDM:QueueAllViewers(immediate, version)
    for _, vName in ipairs(ALL_VIEWER_NAMES) do
        self:QueueViewer(vName, immediate, version)
    end
end

function CDM:SetupViewer(vName)
    local v = _G[vName]
    if not v then return end

    HookViewerLayout(v, vName)

    if v.OnAcquireItemFrame and not CDM_ViewerOnAcquireHooked[v] then
        CDM_ViewerOnAcquireHooked[v] = true
        hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
            if itemFrame and itemFrame.SetScale then
                itemFrame:SetScale(1)
            end
            local fd = CDM.GetFrameData(itemFrame)
            if fd and fd.cdmCooldownTextHidden and itemFrame.Cooldown and itemFrame.Cooldown.SetHideCountdownNumbers then
                itemFrame.Cooldown:SetHideCountdownNumbers(true)
            end
            RefreshFrameSpellIdentity(itemFrame)
            self:QueueViewer(vName)
        end)
    end

    if v.UpdateSystemSettingIconSize and not CDM_ViewerIconSizeHooked[v] then
        CDM_ViewerIconSizeHooked[v] = true
        hooksecurefunc(v, "UpdateSystemSettingIconSize", function()
            self:EnforceCooldownViewerScale(v)
        end)
    end

    self:EnforceCooldownViewerScale(v)
    if self.UpdateEditModeSelectionOverlay then
        self:UpdateEditModeSelectionOverlay(vName)
    end

    if v.itemFramePool then
        if not v.OnAcquireItemFrame and not CDM_ViewerPoolAcquireHooked[v] then
            CDM_ViewerPoolAcquireHooked[v] = true
            hooksecurefunc(v.itemFramePool, "Acquire", function()
                self:EnforceCooldownViewerScale(v)
                self:QueueViewer(vName)
            end)
        end

        if (vName == VIEWERS.BUFF or vName == VIEWERS.BUFF_BAR or vName == VIEWERS.UTILITY) and not CDM_ViewerPoolReleaseHooked[v] then
            CDM_ViewerPoolReleaseHooked[v] = true
            hooksecurefunc(v.itemFramePool, "Release", function()
                local immediate = (vName == VIEWERS.BUFF or vName == VIEWERS.BUFF_BAR)
                self:QueueViewer(vName, immediate)
            end)
        end
    end

    if not CDM_ViewerOnShowHooked[v] then
        CDM_ViewerOnShowHooked[v] = true
        v:HookScript("OnShow", function()
            self:EnforceCooldownViewerScale(v)
            if self.UpdateEditModeSelectionOverlay then
                self:UpdateEditModeSelectionOverlay(vName)
            end
            self:QueueViewer(vName)
        end)
    end

    if (vName == VIEWERS.ESSENTIAL or vName == VIEWERS.UTILITY) and not CDM_ViewerSyncHooked[v] then
        CDM_ViewerSyncHooked[v] = true

        local function SyncViewerToContainer()
            if InCombatLockdown() then return end
            local container = CDM.anchorContainers and CDM.anchorContainers[vName]
            if container then
                v:ClearAllPoints()
                v:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
                v:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
            end
        end

        hooksecurefunc(v, "Layout", SyncViewerToContainer)

        hooksecurefunc(v, "SetPoint", function(_, point, relativeTo)
            if InCombatLockdown() then return end
            local container = CDM.anchorContainers and CDM.anchorContainers[vName]
            if relativeTo == container then return end
            SyncViewerToContainer()
        end)
    end

    self:QueueViewer(vName)
end


function CDM:EnforceCooldownViewerScale(viewer)
    if not viewer then return end
    -- Never write viewer.iconScale (taints Blizzard table in WoW 12.0+)
    if viewer.itemFramePool then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame and frame.SetScale then
                frame:SetScale(1)
            end
        end
    end
end

CDM.loginFinished = false
CDM.loginDeferredFullChange = nil

local function CreateBuffContainers()
    local mainBuffs = _G[VIEWERS.BUFF]
    if mainBuffs then
        CDM:GetOrCreateAnchorContainer(mainBuffs)
    end

    local buffBar = _G[VIEWERS.BUFF_BAR]
    if buffBar then
        CDM:GetOrCreateAnchorContainer(buffBar)
        CDM:UpdateBuffBarContainerPosition()
    end
end

local function SetupMixinHooks()
    local function GetViewerFromItemFrame(frame, expectedViewerName)
        if not frame then return nil end

        local viewer = frame.viewerFrame
        if not viewer and frame.GetViewerFrame and type(frame.GetViewerFrame) == "function" then
            viewer = frame:GetViewerFrame()
        end
        if not viewer and frame.GetParent and type(frame.GetParent) == "function" then
            viewer = frame:GetParent()
        end

        if not viewer or not viewer.GetName then return nil end
        if viewer:GetName() ~= expectedViewerName then return nil end
        return viewer
    end

    local function GetBuffViewerFromItemFrame(frame)
        return GetViewerFromItemFrame(frame, VIEWERS.BUFF)
    end

    local function HandleFixedLayoutViewerSpellUpdate(frame, viewerName)
        if not frame then return end

        local baseSpellID = RefreshFrameSpellIdentity(frame)

        local frameData = CDM.GetFrameData and CDM.GetFrameData(frame)
        local hiddenSet = CDM.defensivesHiddenSet
        local isHiddenByDefensives = baseSpellID and hiddenSet and hiddenSet[baseSpellID] or false
        local wasHiddenByDefensives = frameData and frameData.cdmHiddenByDefensives

        if frameData then
            frameData.cdmHiddenByDefensives = isHiddenByDefensives
        end

        if wasHiddenByDefensives ~= nil and wasHiddenByDefensives ~= isHiddenByDefensives then
            CDM:QueueViewer(viewerName)
            return
        end
        if isHiddenByDefensives and frame.IsShown and frame:IsShown() then
            CDM:QueueViewer(viewerName)
            return
        end

        if frame.IsShown and not frame:IsShown() then
            return
        end

        if frame.SetScale then
            frame:SetScale(1)
        end
        if CDM.ApplyStyle then
            CDM:ApplyStyle(frame, viewerName)
        end
        CDM:QueueViewer(viewerName)
    end

    local function QueueBuffViewerFromFrame(frame, tryProvisional)
        local viewer = GetBuffViewerFromItemFrame(frame)
        if not viewer then return end

        local buffContainer = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.BUFF]
        if not buffContainer and CDM.GetOrCreateAnchorContainer then
            buffContainer = CDM:GetOrCreateAnchorContainer(viewer)
        end

        if tryProvisional and frame and buffContainer then
            local matchType
            if GetSpellIDCandidates then
                local candidates = GetSpellIDCandidates(CDM, frame, true)
                for _, id in ipairs(candidates) do
                    matchType = CheckIDAgainstRegistry(id)
                    if matchType then break end
                end
            end

            if matchType ~= "buffgroup" then
                CDM:RestoreCooldownTextIfHidden(frame)
                CDM:RestoreVisualsIfHidden(frame)
                CDM:ApplyStyle(frame, VIEWERS.BUFF)
                CDM:ProcessBuffViewerOverrides(frame)
                if CDM.ApplyUngroupedBuffOverrides then
                    CDM:ApplyUngroupedBuffOverrides(frame)
                end
            end
            ProvisionalPlaceBuffFrame(CDM, frame, viewer, matchType, buffContainer)
        end

        QueueBuffLikeViewerFromItemHooks(VIEWERS.BUFF)
    end

    if CooldownViewerBuffIconItemMixin and CooldownViewerBuffIconItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", function(frame)
            local viewer = GetBuffViewerFromItemFrame(frame)
            if not viewer then return end

            RefreshFrameSpellIdentity(frame)

            if CDM.NotifyBuffFrameSpellID then
                local baseID = CDM.GetBaseSpellID(frame)
                if baseID then
                    CDM:NotifyBuffFrameSpellID(frame, baseID)
                end
            end

            QueueBuffViewerFromFrame(frame, true)
        end)
    end

    if CooldownViewerBuffIconItemMixin and CooldownViewerBuffIconItemMixin.OnActiveStateChanged then
        hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnActiveStateChanged", function(frame)
            RefreshFrameSpellIdentity(frame)

            if CDM.NotifyBuffFrameSpellID then
                local baseID = CDM.GetBaseSpellID(frame)
                if baseID then
                    CDM:NotifyBuffFrameSpellID(frame, baseID)
                end
            end

            QueueBuffViewerFromFrame(frame, true)
        end)
    end

    if CooldownViewerEssentialItemMixin and CooldownViewerEssentialItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerEssentialItemMixin, "OnCooldownIDSet", function(frame)
            HandleFixedLayoutViewerSpellUpdate(frame, VIEWERS.ESSENTIAL)
        end)
    end
    if CooldownViewerEssentialItemMixin and CooldownViewerEssentialItemMixin.OnActiveStateChanged then
        hooksecurefunc(CooldownViewerEssentialItemMixin, "OnActiveStateChanged", function(frame)
            HandleFixedLayoutViewerSpellUpdate(frame, VIEWERS.ESSENTIAL)
        end)
    end

    if CooldownViewerUtilityItemMixin and CooldownViewerUtilityItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerUtilityItemMixin, "OnCooldownIDSet", function(frame)
            HandleFixedLayoutViewerSpellUpdate(frame, VIEWERS.UTILITY)
        end)
    end
    if CooldownViewerUtilityItemMixin and CooldownViewerUtilityItemMixin.OnActiveStateChanged then
        hooksecurefunc(CooldownViewerUtilityItemMixin, "OnActiveStateChanged", function(frame)
            HandleFixedLayoutViewerSpellUpdate(frame, VIEWERS.UTILITY)
        end)
    end

    CDM:SetupViewer(VIEWERS.BUFF_BAR)

    if CooldownViewerBuffBarItemMixin and CooldownViewerBuffBarItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffBarItemMixin, "OnCooldownIDSet", function(frame)
            local viewer = GetViewerFromItemFrame(frame, VIEWERS.BUFF_BAR)
            if not viewer then return end
            RefreshFrameSpellIdentity(frame)
            if frame and frame.SetScale then
                frame:SetScale(1)
            end
            CDM:ApplyBarStyle(frame, VIEWERS.BUFF_BAR)
            QueueBuffLikeViewerFromItemHooks(VIEWERS.BUFF_BAR)
        end)
    end

    if CooldownViewerBuffBarItemMixin and CooldownViewerBuffBarItemMixin.OnActiveStateChanged then
        hooksecurefunc(CooldownViewerBuffBarItemMixin, "OnActiveStateChanged", function(frame)
            local viewer = GetViewerFromItemFrame(frame, VIEWERS.BUFF_BAR)
            if viewer then
                QueueBuffLikeViewerFromItemHooks(VIEWERS.BUFF_BAR)
            end
        end)
    end
end

local function ActivateEditMode()
    CDM.isEditModeActive = true
    if CDM.LockCooldownViewerEditModeFrames then
        CDM:LockCooldownViewerEditModeFrames()
    end
    if CDM.UpdateEditModeSelectionOverlays then
        CDM:UpdateEditModeSelectionOverlays()
    end
    if CDM.UpdateContainerDragOverlays then
        CDM:UpdateContainerDragOverlays()
    end
    if CDM.Fading then
        CDM.Fading:ShowImmediate()
    end
end

local function SetupEditModeIntegration()
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "Show", ActivateEditMode)

        hooksecurefunc(EditModeManagerFrame, "Hide", function()
            CDM.isEditModeActive = false
            if CDM.UpdateContainerDragOverlays then
                CDM:UpdateContainerDragOverlays()
            end
            CDM:QueueAllViewers(true)
            if CDM.Fading then
                CDM.Fading:Evaluate()
            end
        end)

        if EditModeManagerFrame:IsShown() then
            ActivateEditMode()
        end
    end

    if CDM.SetupEditModeCooldownViewerLock then
        CDM:SetupEditModeCooldownViewerLock()
    end

end

local function SetupZoneTransitionEvents()
    local maxVisualSetupRetries = 5
    local postLoadSpellbookRecheckPending = false
    local postLoadSpellbookRecheckToken = nil
    local postLoadSpellbookRecheckDoneToken = nil

    local function ProcessLoginQueue()
        if CDM.ProcessDeferredLogin then
            CDM:ProcessDeferredLogin()
        end
    end

    local function QueuePostLoadSpellbookRecheck(token)
        if not token then return end
        if postLoadSpellbookRecheckDoneToken == token then
            return
        end
        if postLoadSpellbookRecheckPending and postLoadSpellbookRecheckToken == token then
            return
        end

        postLoadSpellbookRecheckPending = true
        postLoadSpellbookRecheckToken = token
        C_Timer.After(0, function()
            if postLoadSpellbookRecheckToken ~= token then
                return
            end
            postLoadSpellbookRecheckPending = false
            postLoadSpellbookRecheckToken = nil

            if token ~= CDM.enterWorldToken then
                return
            end
            if postLoadSpellbookRecheckDoneToken == token then
                return
            end
            postLoadSpellbookRecheckDoneToken = token

            -- Spellbook may not be ready until after the loading screen;
            -- re-evaluate modules that rely on C_SpellBook.IsSpellInSpellBook.
            if CDM.UpdateDefensives and CDM.db and CDM.db.defensivesEnabled ~= false then CDM:UpdateDefensives() end
            if CDM.UpdateRacials and CDM.db and CDM.db.racialsEnabled ~= false then CDM:UpdateRacials() end
        end)
    end

    local function RunVisualSetup(token, _reason, attempt)
        if token ~= CDM.enterWorldToken then
            return
        end

        attempt = attempt or 1

        local missingViewer = false
        for _, n in ipairs(ALL_VIEWER_NAMES) do
            if not _G[n] then
                missingViewer = true
            end
        end

        local alreadySetup = CDM.visualSetupToken == token and not missingViewer

        if not alreadySetup then
            for _, n in ipairs(ALL_VIEWER_NAMES) do
                local v = _G[n]
                if not v or not CDM_ViewerHooked[v] then
                    CDM:SetupViewer(n)
                end
            end

        end

        CDM:QueueAllViewers()

        if not CDM.loginFinished and (not missingViewer or attempt >= maxVisualSetupRetries) then
            CDM.loginFinished = true
            if CDM.TryOpenQueuedConfig then
                CDM:TryOpenQueuedConfig("login_ready")
            end
            ProcessLoginQueue()
        end

        if not missingViewer or attempt >= maxVisualSetupRetries then
            CDM.visualSetupToken = token
        end

        if missingViewer and attempt < maxVisualSetupRetries then
            C_Timer.After(0.1, function()
                RunVisualSetup(token, _reason, attempt + 1)
            end)
        end
    end

    CDM:RegisterEvent("LOADING_SCREEN_ENABLED", function()
        CDM.loadingScreenActive = true
    end)

    CDM:RegisterEvent("LOADING_SCREEN_DISABLED", function()
        CDM.loadingScreenActive = false
        local token = CDM.enterWorldToken or 0
        RunVisualSetup(token, "loading_screen_disabled", 1)
        QueuePostLoadSpellbookRecheck(token)

        if not CDM._pixelSettleRefreshDone then
            CDM._pixelSettleRefreshDone = true
            C_Timer.After(0.5, function()
                if token ~= CDM.enterWorldToken then return end
                CDM:RefreshConfig()
            end)
        end
    end)

    CDM:RegisterEvent("UI_SCALE_CHANGED", function()
        if CDM.UpdateEssentialContainerPosition then
            CDM:UpdateEssentialContainerPosition()
        end
        if CDM.UpdateBuffContainerPosition then
            CDM:UpdateBuffContainerPosition()
        end
        if CDM.UpdateBuffBarContainerPosition then
            CDM:UpdateBuffBarContainerPosition()
        end
        CDM:QueueAllViewers(true)
        -- Trackers (defensives/trinkets/racials/resources) are not viewer-backed and
        -- depend on pixel-perfect border/layout math. Refresh them after scale settles.
        CDM:RefreshConfig()
    end)

    CDM:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
        CDM._pixelSettleRefreshDone = nil
        CDM.enterWorldToken = (CDM.enterWorldToken or 0) + 1
        local token = CDM.enterWorldToken
        CDM:RefreshSpecData()

        if isInitialLogin or isReloadingUi then
            CDM.anchorContainers = {}
            if _G[VIEWERS.BUFF] then
                CDM:GetOrCreateAnchorContainer(_G[VIEWERS.BUFF])
                CDM:UpdateBuffContainerPosition()
            end
            if _G[VIEWERS.BUFF_BAR] then
                CDM:GetOrCreateAnchorContainer(_G[VIEWERS.BUFF_BAR])
            end
        end

        if not CDM.loadingScreenActive and not isInitialLogin then
            C_Timer.After(0, function()
                RunVisualSetup(token, "entering_world_fallback", 1)
            end)
        end
    end)
end

local function InitializeModules()
    local moduleManager = CDM.ModuleManager
    if not (moduleManager and moduleManager.ReconcileModule) then
        local startupErr = "ModuleManager is not available during startup module initialization"
        print("|cffff0000[CDM]|r " .. startupErr)
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(startupErr)
        end
        return
    end

    local startupFailures
    local startupModules = { "racials", "defensives", "trinkets", "resources" }
    for _, moduleId in ipairs(startupModules) do
        local ok, err = moduleManager:ReconcileModule(moduleId)
        if not ok then
            startupFailures = startupFailures or {}
            startupFailures[#startupFailures + 1] = string.format("%s (%s)", tostring(moduleId), tostring(err))
        end
    end
    if startupFailures and #startupFailures > 0 then
        local startupErr = "Startup module reconcile failed: " .. table.concat(startupFailures, "; ")
        print("|cffff0000[CDM]|r " .. startupErr)
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(startupErr)
        end
    end

    if CDM.InitializeCustomBuffs then
        CDM:InitializeCustomBuffs()
    end

    if CDM.InitializePlayerCastBar and CDM.db.castBarEnabled ~= false then
        CDM:InitializePlayerCastBar()
    end

    if CDM.Keybinds and CDM.Keybinds.Initialize then
        CDM.Keybinds:Initialize()
    end

    if CDM.Fading and CDM.Fading.Initialize then
        CDM.Fading:Initialize()
    end

    if CDM.RotationAssist and CDM.RotationAssist.Initialize then
        CDM.RotationAssist:Initialize()
    end

    if CDM.PressOverlay and CDM.PressOverlay.Initialize then
        CDM.PressOverlay:Initialize()
    end
end

local function RegisterRefreshCallbacks()
    local VISUAL_STYLE_SCOPES = {
        "castbar_visuals",
        "resources_visuals",
        "text_visuals",
        "trackers_layout",
        "glow",
        "viewers",
    }

    CDM:RegisterRefreshCallback("styleCache", function()
        CDM.styleCacheVersion = (CDM.styleCacheVersion or 0) + 1
        if RefreshStyleCache then
            RefreshStyleCache()
        end
        if CDM.InvalidateEssentialRow1WidthCache then
            CDM:InvalidateEssentialRow1WidthCache()
        end
    end, 10, VISUAL_STYLE_SCOPES)

    CDM:RegisterRefreshCallback("constants", function()
        if CDM.InvalidateEssentialRow1WidthCache then
            CDM:InvalidateEssentialRow1WidthCache()
        end
        if CDM.InvalidateUtilityVisibleCountCache then
            CDM:InvalidateUtilityVisibleCountCache()
        end
        UpdateConstants()
    end, 20, {
        "castbar_visuals",
        "resources_visuals",
        "text_visuals",
        "trackers_layout",
        "viewers",
    })

    CDM:RegisterRefreshCallback("specData", function()
        CDM:RefreshSpecData()
    end, 30, { "spec_data" })

    CDM:RegisterRefreshCallback("viewers", function()
        CDM:QueueAllViewers(true)
    end, 40, { "viewers" })

    CDM:RegisterRefreshCallback("essentialPosition", function()
        CDM:UpdateEssentialContainerPosition()
    -- Must run before "viewers": essential layout snaps the rendered top-left after
    -- resize for pixel-perfect icon placement. If we re-anchor the container after
    -- layout, we can undo that snap and leave 1px drift/gap artifacts until another
    -- reanchor (e.g. /reload) happens.
    end, 35, { "trackers_layout" })

    CDM:RegisterRefreshCallback("buffPosition", function()
        CDM:UpdateBuffContainerPosition()
    end, 60, { "trackers_layout" })

    CDM:RegisterRefreshCallback("buffBars", function()
        CDM:UpdateBuffBarContainerPosition()
        CDM:QueueViewer(VIEWERS.BUFF_BAR, true)
    end, 65, { "trackers_layout", "viewers" })

    CDM:RegisterRefreshCallback("containerLocks", function()
        CDM:UpdateContainerDragOverlays()
    end, 70, { "trackers_layout" })
end

function CDM:OnEnable()
    SLASH_AYIJECDM1 = "/cdm"
    SLASH_AYIJECDM2 = "/acdm"
    SlashCmdList["AYIJECDM"] = function()
        CDM:RequestConfigOpen("slash", nil)
    end

    InitConstants()

    CreateBuffContainers()
    SetupMixinHooks()
    SetupEditModeIntegration()
    SetupZoneTransitionEvents()
    self:InitializeSpecChangeSystem()
    InitializeModules()
    RefreshStyleCache()
    RegisterRefreshCallbacks()
    RegisterLSMFontRefreshCallback()
    RegisterPostLoginFontRefresh()
    RegisterCooldownViewerSettingsVisualRefresh()

    local function FlushCombatDirtyViewers()
        local dirty = CDM.combatDirtyViewers
        if not next(dirty) then return end
        for vName in pairs(dirty) do
            CDM:QueueViewer(vName)
        end
        wipe(dirty)
    end

    self:RegisterInternalCallback("OnCombatStateChanged", function(isInCombat)
        if isInCombat then
            return
        end
        FlushCombatDirtyViewers()
    end)
end
