local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local RefreshStyleCache = CDM.RefreshStyleCache
local ResetFrameSpellCache = CDM.ResetFrameSpellCache
local GetBaseSpellID = CDM.GetBaseSpellID

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
local CDM_ViewerPoolAcquireHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerOnShowHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerSyncHooked = setmetatable({}, { __mode = "k" })
local CDM_FrameActiveStateHooked = setmetatable({}, { __mode = "k" })
local CDM_FrameSetPointHooked = setmetatable({}, { __mode = "k" })
local CDM_ViewerRefreshLayoutHooked = setmetatable({}, { __mode = "k" })

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

CDM.queue = {}
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
    return GetBaseSpellID(frame)
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
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local callbacks = LSM and LSM.callbacks
    if not (callbacks and callbacks.RegisterCallback) then
        return
    end

    callbacks.RegisterCallback(CDM, LSM_MEDIA_EVENT, OnLSMMediaRegistered)
end

local function RegisterPostLoginFontRefresh()
    CDM:RegisterEvent("PLAYER_LOGIN", function()
        C_Timer.After(0, function()
            CDM:RefreshConfig()
        end)
    end)
end

local function RegisterCooldownViewerSettingsVisualRefresh()
    local registry = EventRegistry
    if not (registry and registry.RegisterCallback) then
        return
    end

    local onShowOwner = {}
    registry:RegisterCallback("CooldownViewerSettings.OnShow", function()
        CDM:QueueAllViewers()
    end, onShowOwner)

    local onHideOwner = {}
    registry:RegisterCallback("CooldownViewerSettings.OnHide", function()
        C_Timer.After(0.1, function()
            CDM:QueueAllViewers(true)
        end)
    end, onHideOwner)
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

    for _, name in ipairs(ALL_VIEWER_NAMES) do
        if CDM.queue[name] then
            CDM.queue[name] = nil
            local v = _G[name]
            if v then CDM:ForceReanchor(v) end
        end
    end

    if CDM.Fading then
        CDM.Fading:ReapplyCurrent()
    end

    if not next(CDM.queue) then
        updaterActive = false
        Updater:SetScript("OnUpdate", nil)
    end
end

function CDM:QueueViewer(name, immediate)
    if immediate and not self.pendingSpecChange then
        local v = _G[name]
        if v then self:ForceReanchor(v) end
        if CDM.Fading then
            CDM.Fading:ReapplyCurrent()
        end
        return
    end

    if self.queue[name] then return end

    if name == VIEWERS.UTILITY and self.InvalidateUtilityVisibleCountCache then
        self:InvalidateUtilityVisibleCountCache()
    end

    self.queue[name] = true
    if not updaterActive then
        updaterActive = true
        Updater:SetScript("OnUpdate", QueueProcessor)
    end
end

function CDM:QueueAllViewers(immediate)
    for _, vName in ipairs(ALL_VIEWER_NAMES) do
        self:QueueViewer(vName, immediate)
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

local function InstallScaleLockHooksOnViewer(viewer)
    if not viewer or not viewer.itemFramePool then return end
    for frame in viewer.itemFramePool:EnumerateActive() do
        if frame then InstallScaleLockHook(frame) end
    end
end

function CDM:SetupViewer(vName)
    local v = _G[vName]
    if not v then return end

    CDM_ViewerHooked[v] = true

    if v.OnAcquireItemFrame and not CDM_ViewerOnAcquireHooked[v] then
        CDM_ViewerOnAcquireHooked[v] = true
        hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
            InstallScaleLockHook(itemFrame)
            local fd = CDM.GetFrameData(itemFrame)
            fd.cdmAnchor = nil
            CDM:HideCooldownTextIfFlagged(itemFrame)
            self:QueueViewer(vName)

            if vName ~= VIEWERS.BUFF_BAR and not CDM_FrameSetPointHooked[itemFrame] then
                CDM_FrameSetPointHooked[itemFrame] = true
                hooksecurefunc(itemFrame, "SetPoint", function(frame, point, relativeTo)
                    local fd2 = CDM.GetFrameData(frame)
                    if not fd2 or not fd2.cdmAnchor then return end
                    local a = fd2.cdmAnchor
                    if relativeTo == a[2] then return end
                    RawClearAllPoints(frame)
                    RawSetPoint(frame, a[1], a[2], a[3], a[4], a[5])
                end)
            end

            if (vName == VIEWERS.BUFF or vName == VIEWERS.BUFF_BAR) and not CDM_FrameActiveStateHooked[itemFrame] then
                CDM_FrameActiveStateHooked[itemFrame] = true
                local hookVName = vName
                hooksecurefunc(itemFrame, "OnActiveStateChanged", function(frame)
                    if hookVName == VIEWERS.BUFF then
                        local baseID = CDM.GetBaseSpellID(frame)
                        if baseID then
                            CDM:NotifyBuffFrameSpellID(frame, baseID)
                        end
                    end

                    CDM:QueueViewer(hookVName)
                end)
            end

        end)
    end

    InstallScaleLockHooksOnViewer(v)
    if self.UpdateEditModeSelectionOverlay then
        self:UpdateEditModeSelectionOverlay(vName)
    end

    if v.itemFramePool then
        if not v.OnAcquireItemFrame and not CDM_ViewerPoolAcquireHooked[v] then
            CDM_ViewerPoolAcquireHooked[v] = true
            hooksecurefunc(v.itemFramePool, "Acquire", function()
                InstallScaleLockHooksOnViewer(v)
                self:QueueViewer(vName)
            end)
        end

    end

    if not CDM_ViewerOnShowHooked[v] then
        CDM_ViewerOnShowHooked[v] = true
        v:HookScript("OnShow", function()
            if self.UpdateEditModeSelectionOverlay then
                self:UpdateEditModeSelectionOverlay(vName)
            end
            self:QueueViewer(vName)
        end)
    end

    if not CDM_ViewerRefreshLayoutHooked[v] then
        CDM_ViewerRefreshLayoutHooked[v] = true
        if vName ~= VIEWERS.BUFF_BAR then
            hooksecurefunc(v, "RefreshLayout", function()
                self.queue[vName] = nil
                self:ForceReanchor(v)
            end)
        end
    end

    if (vName == VIEWERS.ESSENTIAL or vName == VIEWERS.UTILITY) and not CDM_ViewerSyncHooked[v] then
        CDM_ViewerSyncHooked[v] = true

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

    self:QueueViewer(vName)
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

        RefreshFrameSpellIdentity(frame)
        CDM:QueueViewer(viewerName)
    end

    local function QueueBuffViewerFromFrame(frame)
        local viewer = GetBuffViewerFromItemFrame(frame)
        if not viewer then return end

        local hiddenBuffSet = CDM.resourcesHiddenBuffSet
        if hiddenBuffSet then
            local baseID = GetBaseSpellID(frame)
            if baseID and hiddenBuffSet[baseID] then
                frame:Hide()
            end
        end

        CDM:QueueViewer(VIEWERS.BUFF)
    end

    if CooldownViewerBuffIconItemMixin and CooldownViewerBuffIconItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", function(frame)
            local viewer = GetBuffViewerFromItemFrame(frame)
            if not viewer then return end

            RefreshFrameSpellIdentity(frame)

            local baseID = CDM.GetBaseSpellID(frame)
            if baseID then
                CDM:NotifyBuffFrameSpellID(frame, baseID)
            end

            QueueBuffViewerFromFrame(frame)
        end)
    end

    if CooldownViewerEssentialItemMixin and CooldownViewerEssentialItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerEssentialItemMixin, "OnCooldownIDSet", function(frame)
            HandleFixedLayoutViewerSpellUpdate(frame, VIEWERS.ESSENTIAL)
        end)
    end
    if CooldownViewerUtilityItemMixin and CooldownViewerUtilityItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerUtilityItemMixin, "OnCooldownIDSet", function(frame)
            HandleFixedLayoutViewerSpellUpdate(frame, VIEWERS.UTILITY)
        end)
    end
    CDM:SetupViewer(VIEWERS.BUFF_BAR)

    if CooldownViewerBuffBarItemMixin and CooldownViewerBuffBarItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffBarItemMixin, "OnCooldownIDSet", function(frame)
            local viewer = GetViewerFromItemFrame(frame, VIEWERS.BUFF_BAR)
            if not viewer then return end
            RefreshFrameSpellIdentity(frame)
            CDM:QueueViewer(VIEWERS.BUFF_BAR)
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
    local postLoadSpellbookRecheckToken = nil
    local postLoadSpellbookRecheckDoneToken = nil
    local pendingPostSpecSetup = false

    local function QueuePostLoadSpellbookRecheck(token)
        if not token then return end
        if postLoadSpellbookRecheckDoneToken == token then
            return
        end
        if postLoadSpellbookRecheckToken == token then
            return
        end

        postLoadSpellbookRecheckToken = token
        C_Timer.After(0, function()
            if postLoadSpellbookRecheckToken ~= token then
                return
            end
            postLoadSpellbookRecheckToken = nil

            if token ~= CDM.enterWorldToken then
                return
            end
            if postLoadSpellbookRecheckDoneToken == token then
                return
            end
            postLoadSpellbookRecheckDoneToken = token

            if CDM.UpdateDefensives and CDM.db and CDM.db.defensivesEnabled ~= false then CDM:UpdateDefensives() end
            if CDM.UpdateRacials and CDM.db and CDM.db.racialsEnabled ~= false then CDM:UpdateRacials() end
        end)
    end

    local function RunVisualSetup(token)
        if token ~= CDM.enterWorldToken then
            return
        end

        if CDM.visualSetupToken ~= token then
            for _, n in ipairs(ALL_VIEWER_NAMES) do
                local v = _G[n]
                if not v or not CDM_ViewerHooked[v] then
                    CDM:SetupViewer(n)
                end
            end
        end

        CDM:QueueAllViewers()

        if not CDM.loginFinished then
            CDM.loginFinished = true
            if CDM.TryOpenQueuedConfig then
                CDM:TryOpenQueuedConfig("login_ready")
            end
            if CDM.ProcessDeferredLogin then CDM:ProcessDeferredLogin() end
        end

        CDM.visualSetupToken = token
    end

    CDM:RegisterEvent("LOADING_SCREEN_ENABLED", function()
        CDM.loadingScreenActive = true
    end)

    CDM:RegisterEvent("LOADING_SCREEN_DISABLED", function()
        CDM.Pixel.Update()
        CDM.loadingScreenActive = false
        local token = CDM.enterWorldToken

        if CDM.pendingSpecChange then
            pendingPostSpecSetup = true
        else
            RunVisualSetup(token)
        end

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
        CDM:RefreshConfig()
    end)

    CDM:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
        CDM.Pixel.Update()
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
                RunVisualSetup(token)
            end)
        end
    end)

    function CDM:NotifySpecChangeComplete()
        if pendingPostSpecSetup then
            pendingPostSpecSetup = false
            local token = self.enterWorldToken or 0
            RunVisualSetup(token)
        end
    end
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
    local startupModules = { "racials", "defensives", "trinkets", "resources", "externals" }
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

    CDM.Keybinds:Initialize()
    CDM.Fading:Initialize()
    CDM.RotationAssist:Initialize()
    CDM.PressOverlay:Initialize()
end

local function FlushCombatDirtyViewers()
    local dirty = CDM.combatDirtyViewers
    if not next(dirty) then return end
    for vName in pairs(dirty) do
        CDM:QueueViewer(vName)
    end
    wipe(dirty)
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
        local buffViewer = _G[VIEWERS.BUFF]
        if buffViewer and buffViewer.itemFramePool then
            for frame in buffViewer.itemFramePool:EnumerateActive() do
                if frame then CDM:ApplyStyle(frame, VIEWERS.BUFF, true) end
            end
        end
        local barViewer = _G[VIEWERS.BUFF_BAR]
        if barViewer and barViewer.itemFramePool then
            for frame in barViewer.itemFramePool:EnumerateActive() do
                if frame then CDM:ApplyBarStyle(frame, VIEWERS.BUFF_BAR) end
            end
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
    end, 35, { "trackers_layout" })

    CDM:RegisterRefreshCallback("buffPosition", function()
        CDM:UpdateBuffContainerPosition()
    end, 60, { "trackers_layout" })

    CDM:RegisterRefreshCallback("buffBars", function()
        CDM:UpdateBuffBarContainerPosition()
    end, 65, { "trackers_layout" })

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
    if self.DisableBlizzardPlayerCastBar then
        self:DisableBlizzardPlayerCastBar()
    end

    self:RegisterInternalCallback("OnCombatStateChanged", function(isInCombat)
        if isInCombat then
            return
        end
        FlushCombatDirtyViewers()
    end)
end
