local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local RefreshStyleCache = CDM.RefreshStyleCache
local GetBaseSpellID = CDM.GetBaseSpellID

local InCombatLockdown = InCombatLockdown

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


local anchorProxy = CreateFrame("Frame")
local RawClearAllPoints = anchorProxy.ClearAllPoints
local RawSetPoint = anchorProxy.SetPoint
CDM.combatDirtyViewers = {}

local d = CDM.defaults
local SIZE_ESS_ROW1 = { w = d.sizeEssRow1.w, h = d.sizeEssRow1.h }
local SIZE_ESS_ROW2 = { w = d.sizeEssRow2.w, h = d.sizeEssRow2.h }
local SIZE_UTILITY = { w = d.sizeUtility.w, h = d.sizeUtility.h }
local SIZE_BUFF = { w = d.sizeBuff.w, h = d.sizeBuff.h }
local SIZE_RACIALS = { w = d.racialsIconWidth, h = d.racialsIconHeight }
local SIZE_DEFENSIVES = { w = d.defensivesIconWidth, h = d.defensivesIconHeight }
local SIZE_TRINKETS = { w = d.trinketsIconWidth, h = d.trinketsIconHeight }
local SIZE_EXTERNALS = { w = d.externalsIconWidth, h = d.externalsIconHeight }
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
CDM.Sizes.SIZE_EXTERNALS = SIZE_EXTERNALS

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
    SIZE_EXTERNALS.w = CDM_C.GetConfigValue("externalsIconWidth", d.externalsIconWidth) or d.externalsIconWidth
    SIZE_EXTERNALS.h = CDM_C.GetConfigValue("externalsIconHeight", d.externalsIconHeight) or d.externalsIconHeight
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
    CDM.Pixel.Update()
    InitConstants()

    local buffContainer = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.BUFF]
    if buffContainer then
        buffContainer:SetSize(CDM.Pixel.SnapEven(400), CDM.Pixel.Snap(SIZE_BUFF.h))
    end

    for _, methodName in ipairs(UPDATE_CONSTANTS_METHODS) do
        local method = CDM[methodName]
        if method then method(CDM) end
    end
end

CDM.anchorContainers = {}
CDM.loadingScreenActive = false
CDM.viewersReady = false
CDM.pendingSpecChange = false
CDM.pendingTalentChange = false
CDM.isEditModeActive = false


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

    CDM:Refresh("STYLE")
end

local function RegisterLSMFontRefreshCallback()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local callbacks = LSM and LSM.callbacks
    if not (callbacks and callbacks.RegisterCallback) then
        return
    end

    callbacks.RegisterCallback(CDM, LSM_MEDIA_EVENT, OnLSMMediaRegistered)
end

local function RegisterPostLoginFontRefresh()
    CDM:RegisterEvent("PLAYER_LOGIN", function()
        CDM.Glow:Initialize()
        C_Timer.After(0, function()
            CDM:Refresh()
        end)
    end)
end

local function RegisterCooldownViewerSettingsVisualRefresh()
    local registry = EventRegistry
    if not (registry and registry.RegisterCallback) then
        return
    end

    local onShowOwner = {}
    local onShowVersion = 0
    registry:RegisterCallback("CooldownViewerSettings.OnShow", function()
        onShowVersion = onShowVersion + 1
        local myVersion = onShowVersion
        C_Timer.After(0, function()
            if onShowVersion ~= myVersion then return end
            CDM:ForceReanchorAll()
        end)
    end, onShowOwner)

    local onHideOwner = {}
    local onHideVersion = 0
    registry:RegisterCallback("CooldownViewerSettings.OnHide", function()
        onHideVersion = onHideVersion + 1
        local myVersion = onHideVersion
        C_Timer.After(0.1, function()
            if onHideVersion ~= myVersion then return end
            CDM:ForceReanchorAll()
        end)
    end, onHideOwner)
end

local function RegisterCooldownViewerOverrideRefresh()
    local version = 0
    CDM:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", function()
        version = version + 1
        local myVersion = version
        C_Timer.After(0, function()
            if version ~= myVersion then return end
            CDM:RefreshBuffGroupData()
            CDM:RefreshCooldownGroupData()
            CDM:RebuildAuraOverlayEnabledMap()
            CDM:ForceReanchorAll()
        end)
    end)
end

function CDM:ForceReanchorAll()
    for _, vName in ipairs(ALL_VIEWER_NAMES) do
        local v = _G[vName]
        if v then self:ForceReanchor(v) end
    end
end

local function InstallScaleLockHook(frame)
    local fd = CDM.GetFrameData(frame)
    if fd.cdmSetScaleHooked then return end
    fd.cdmSetScaleHooked = true
    hooksecurefunc(frame, "SetScale", function(self, scale)
        if scale ~= 1 then
            self:SetScale(1)
        end
    end)
end

function CDM:SetupViewer(vName)
    local v = _G[vName]
    if not v then return end

    if v.OnAcquireItemFrame then
        hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
            InstallScaleLockHook(itemFrame)
            local fd = CDM.GetFrameData(itemFrame)
            fd.cdmAnchor = nil
            fd.buffCategorySpellID = nil
            fd.cdGroupSpellID = nil
            fd.cdmCooldownInitDone = nil
            fd.cdmLastCooldownStyleVer = nil
            CDM:HideCooldownTextIfFlagged(itemFrame)

            if vName ~= VIEWERS.BUFF_BAR and not fd.cdmSetPointHooked then
                fd.cdmSetPointHooked = true
                hooksecurefunc(itemFrame, "SetPoint", function(frame, point, relativeTo)
                    local fd2 = CDM.GetFrameData(frame)
                    if not fd2 or not fd2.cdmAnchor then return end
                    local a = fd2.cdmAnchor
                    if relativeTo == a[2] then return end
                    RawClearAllPoints(frame)
                    RawSetPoint(frame, a[1], a[2], a[3], a[4], a[5])
                end)
            end

            if (vName == VIEWERS.BUFF or vName == VIEWERS.BUFF_BAR) and not fd.cdmActiveStateHooked then
                fd.cdmActiveStateHooked = true
                local hookVName = vName
                hooksecurefunc(itemFrame, "OnActiveStateChanged", function(frame)
                    if hookVName == VIEWERS.BUFF then
                        CDM:RepositionBuffViewer(_G[hookVName])
                    else
                        CDM:ForceReanchor(_G[hookVName])
                    end
                end)
            end

        end)
    end

    if self.UpdateEditModeSelectionOverlay then
        self:UpdateEditModeSelectionOverlay(vName)
    end

    v:HookScript("OnShow", function()
        if self.UpdateEditModeSelectionOverlay then
            self:UpdateEditModeSelectionOverlay(vName)
        end
    end)

    hooksecurefunc(v, "RefreshLayout", function()
        self:ForceReanchor(v)
    end)

    if vName == VIEWERS.ESSENTIAL or vName == VIEWERS.UTILITY then
        local function SyncViewerToContainer()
            if InCombatLockdown() then
                CDM.combatDirtyViewers[vName] = true
                return
            end
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

    self:ForceReanchor(v)
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
    if CooldownViewerBuffIconItemMixin and CooldownViewerBuffIconItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", function(frame)
            local baseID = CDM.GetBaseSpellID(frame)
            if baseID then
                CDM:NotifyBuffFrameSpellID(frame, baseID)
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
            CDM:ForceReanchorAll()
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
    local pendingPostSpecSetup = false

    local function RunVisualSetup()
        CDM:RefreshSpecData()
        CDM:ForceReanchorAll()

        if not CDM.loginFinished then
            CDM.loginFinished = true
            if CDM.TryOpenQueuedConfig then
                CDM:TryOpenQueuedConfig("login_ready")
            end
            if CDM.ProcessDeferredLogin then CDM:ProcessDeferredLogin() end
        end

        CDM.viewersReady = true
    end

    CDM:RegisterEvent("LOADING_SCREEN_ENABLED", function()
        CDM.loadingScreenActive = true
    end)

    CDM:RegisterEvent("LOADING_SCREEN_DISABLED", function()
        CDM.Pixel.Update()
        CDM.loadingScreenActive = false

        if CDM.pendingSpecChange then
            pendingPostSpecSetup = true
        else
            RunVisualSetup()
        end

        C_Timer.After(0.5, function() CDM:Refresh() end)
    end)

    CDM:RegisterEvent("UI_SCALE_CHANGED", function()
        CDM.Pixel.Update()
        if CDM.UpdateEssentialContainerPosition then
            CDM:UpdateEssentialContainerPosition()
        end
        if CDM.UpdateBuffContainerPosition then
            CDM:UpdateBuffContainerPosition()
        end
        if CDM.UpdateBuffBarContainerPosition then
            CDM:UpdateBuffBarContainerPosition()
        end
        CDM:Refresh()
    end)

    CDM:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
        CDM.viewersReady = false

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
    end)

    function CDM:NotifySpecChangeComplete()
        if pendingPostSpecSetup then
            pendingPostSpecSetup = false
            RunVisualSetup()
        end
    end
end

local function RunProfileAppliedHooks()
    CDM.OnRacialsProfileApplied()
    CDM.OnDefensivesProfileApplied()
    CDM.OnTrinketsProfileApplied()
    CDM.OnResourcesProfileApplied()
    CDM.OnExternalsProfileApplied()
end

CDM.RunProfileAppliedHooks = RunProfileAppliedHooks

local function InitializeModules()
    CDM.ReconcileRacials()
    CDM.ReconcileDefensives()
    CDM.ReconcileTrinkets()
    CDM.ReconcileResources()
    CDM.ReconcileExternals()

    if CDM.InitializeCustomBuffs then
        CDM:InitializeCustomBuffs()
    end

    if CDM.InitializePlayerCastBar and CDM.db.castBarEnabled ~= false then
        CDM:InitializePlayerCastBar()
    end

    CDM.Keybinds:Initialize()
    CDM.Fading:Initialize()
    CDM.RotationAssist:Initialize()
    CDM.PressOverlay:Initialize()
end

local function FlushCombatDirtyViewers()
    local dirty = CDM.combatDirtyViewers
    if not next(dirty) then return end
    for vName in pairs(dirty) do
        local v = _G[vName]
        if v then CDM:ForceReanchor(v) end
    end
    wipe(dirty)
end

local function ForceRestyleAll()
    if RefreshStyleCache then RefreshStyleCache() end
    for _, vName in ipairs(ALL_VIEWER_NAMES) do
        if vName ~= VIEWERS.BUFF_BAR then
            local viewer = _G[vName]
            if viewer and viewer.itemFramePool then
                for frame in viewer.itemFramePool:EnumerateActive() do
                    CDM:ApplyStyle(frame, vName, true)
                    if vName == VIEWERS.BUFF then
                        CDM:RestoreCooldownTextIfHidden(frame)
                        CDM:RestoreVisualsIfHidden(frame)
                        CDM:ApplyUngroupedBuffOverrides(frame)
                    end
                end
            end
        end
    end
    local CB = CDM.CustomBuffs
    if CB and CB.activeBuffs then
        for _, buffData in pairs(CB.activeBuffs) do
            local frame = buffData.frame
            if frame then
                CDM:ApplyStyle(frame, VIEWERS.BUFF, true)
                CDM:ApplyUngroupedBuffOverrides(frame)
            end
        end
    end
    if CDM.ApplyGroupStyleOverrides then
        CDM:ApplyGroupStyleOverrides()
    end
    local bbViewer = _G[VIEWERS.BUFF_BAR]
    if bbViewer then CDM:ForceReanchor(bbViewer) end
    if CDM.RefreshAllSwipeColors then
        CDM.RefreshAllSwipeColors()
    end
    if CDM.Fading then CDM.Fading:ReapplyCurrent() end
end

local function RegisterRefreshCallbacks()
    CDM:RegisterRefreshCallback("styleCache", function()
        CDM.styleCacheVersion = (CDM.styleCacheVersion or 0) + 1
        if RefreshStyleCache then
            RefreshStyleCache()
        end
        if CDM.InvalidateEssentialRow1WidthCache then
            CDM:InvalidateEssentialRow1WidthCache()
        end
    end, 10)

    CDM:RegisterRefreshCallback("constants", function()
        if CDM.InvalidateEssentialRow1WidthCache then
            CDM:InvalidateEssentialRow1WidthCache()
        end
        if CDM.InvalidateUtilityVisibleCountCache then
            CDM:InvalidateUtilityVisibleCountCache()
        end
        UpdateConstants()
    end, 20)

    CDM:RegisterRefreshCallback("specData", function()
        CDM:RefreshSpecData()
    end, 30, { "BUFF_DATA", "CD_DATA" })

    CDM:RegisterRefreshCallback("viewers_layout", function()
        CDM:ForceReanchorAll()
    end, 40, { "LAYOUT", "BUFF_DATA", "CD_DATA" })

    CDM:RegisterRefreshCallback("viewers_style", ForceRestyleAll, 45, { "STYLE", "BUFF_DATA", "CD_DATA" })

    CDM:RegisterRefreshCallback("trackerModules", function()
        CDM.ReconcileDefensives()
        CDM.ReconcileRacials()
        CDM.ReconcileTrinkets()
        CDM.ReconcileExternals()
    end, 50, { "TRACKERS" })

    CDM:RegisterRefreshCallback("resources", function()
        CDM.ReconcileResources()
    end, 50, { "RESOURCES" })

    CDM:RegisterRefreshCallback("essentialPosition", function()
        CDM:UpdateEssentialContainerPosition()
    end, 35, { "LAYOUT" })

    CDM:RegisterRefreshCallback("buffPosition", function()
        CDM:UpdateBuffContainerPosition()
    end, 60, { "LAYOUT" })

    CDM:RegisterRefreshCallback("buffBars", function()
        CDM:UpdateBuffBarContainerPosition()
    end, 65, { "LAYOUT", "TRACKERS" })

    CDM:RegisterRefreshCallback("containerLocks", function()
        CDM:UpdateContainerDragOverlays()
    end, 70, { "LAYOUT" })
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
    for _, vName in ipairs(ALL_VIEWER_NAMES) do
        self:SetupViewer(vName)
    end
    SetupEditModeIntegration()
    SetupZoneTransitionEvents()
    self:InitializeSpecChangeSystem()
    InitializeModules()
    RefreshStyleCache()
    RegisterRefreshCallbacks()
    RegisterLSMFontRefreshCallback()
    RegisterPostLoginFontRefresh()
    RegisterCooldownViewerSettingsVisualRefresh()
    RegisterCooldownViewerOverrideRefresh()
    if self.DisableBlizzardPlayerCastBar then
        self:DisableBlizzardPlayerCastBar()
    end

    self:RegisterCombatStateHandler(function(isInCombat)
        if isInCombat then
            return
        end
        FlushCombatDirtyViewers()
    end)
end
