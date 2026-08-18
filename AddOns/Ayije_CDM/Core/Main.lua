local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local RefreshStyleCache = CDM.RefreshStyleCache

local InCombatLockdown = InCombatLockdown

local VIEWERS = CDM_C.VIEWERS
local ALL_VIEWER_NAMES = CDM_C.ALL_VIEWER_NAMES
local MANAGED_VIEWER_NAMES = CDM_C.MANAGED_VIEWER_NAMES
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

local function UpdateConstants()
    CDM.Pixel.Update()

    local buffContainer = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.BUFF]
    if buffContainer then
        local sizeBuff = CDM_C.GetConfigValue("sizeBuff", CDM.defaults.sizeBuff)
        buffContainer:SetSize(CDM.Pixel.SnapEven(400), CDM.Pixel.Snap(sizeBuff.h))
    end

    for _, methodName in ipairs(UPDATE_CONSTANTS_METHODS) do
        CDM[methodName](CDM)
    end
end

CDM.anchorContainers = {}
CDM.loginFinished = false
CDM.loadingScreenActive = false
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

local function RegisterCooldownViewerSettingsVisualRefresh()
    local panel = _G.CooldownViewerSettings
    if not panel then return end

    local function ReanchorBuffViewers()
        local buffViewer = _G[VIEWERS.BUFF]
        if buffViewer then CDM:ForceReanchor(buffViewer) end
        local buffBarViewer = _G[VIEWERS.BUFF_BAR]
        if buffBarViewer then CDM:ForceReanchor(buffBarViewer) end
    end

    panel:HookScript("OnShow", ReanchorBuffViewers)
    panel:HookScript("OnHide", ReanchorBuffViewers)
end

local function RegisterCooldownViewerTableHotfix()
    CDM:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED", function()
        CDM:MarkSpecDataDirty()
        CDM:RefreshSpecData()
        CDM:ForceReanchorAll()
        CDM:Refresh()
    end)
end

function CDM:ForceReanchorAll()
    for _, vName in ipairs(ALL_VIEWER_NAMES) do
        local v = _G[vName]
        if v then self:ForceReanchor(v) end
    end
end

-- fix from MiliUI: 暴雪編輯模式的「大小」設定是套在 item frame 的 scale 上（實測抓到 0.7：
-- 圖示寬仍是設定的 46、viewer scale 是 1、UIParent 也正常，只有 item frame 自己 0.7）。
-- 原本這道鎖有兩個破口，結果就是「只有那一排縮小、資源條正常、只有 /reload 會好」：
--   1) 只在 OnAcquireItemFrame 掛鎖，插件掛勾之前就已經取出的框架永遠沒被鎖到
--   2) 受保護框架在戰鬥中改不了 scale，而離開戰鬥的還原只處理錨點與尺寸，不管 scale
local scaleDirtyFrames = {}

local function EnsureItemFrameScale(frame)
    if not frame or frame:GetScale() == 1 then return end
    if InCombatLockdown() and frame:IsProtected() then
        scaleDirtyFrames[frame] = true
        return
    end
    scaleDirtyFrames[frame] = nil
    frame:SetScale(1)
end

local function FlushDirtyItemFrameScales()
    if not next(scaleDirtyFrames) then return end
    for frame in pairs(scaleDirtyFrames) do
        scaleDirtyFrames[frame] = nil
        if frame:GetScale() ~= 1 then
            frame:SetScale(1)
        end
    end
end

local function InstallScaleLockHook(frame)
    EnsureItemFrameScale(frame)
    if frame.cdmSetScaleHooked then return end
    frame.cdmSetScaleHooked = true
    hooksecurefunc(frame, "SetScale", function(self, scale)
        if scale ~= 1 then
            EnsureItemFrameScale(self)
        end
    end)
end

local function InstallAnchorSnapBackHook(itemFrame, anchorKey)
    if itemFrame.cdmSetPointHooked then return end
    itemFrame.cdmSetPointHooked = true
    hooksecurefunc(itemFrame, "SetPoint", function(frame, point, relativeTo)
        local a = frame[anchorKey]
        if not a then return end
        if relativeTo == a[2] then return end
        RawClearAllPoints(frame)
        RawSetPoint(frame, a[1], a[2], a[3], a[4], a[5])
    end)
end

local function InstallActiveStateRepositionHook(itemFrame, vName)
    if itemFrame.cdmActiveStateHooked then return end
    itemFrame.cdmActiveStateHooked = true
    local viewer = _G[vName]
    if vName == VIEWERS.BUFF then
        hooksecurefunc(itemFrame, "OnActiveStateChanged", function()
            CDM:RepositionBuffViewer(viewer)
        end)
    else
        hooksecurefunc(itemFrame, "OnActiveStateChanged", function()
            CDM:RepositionBuffBarViewer(viewer)
        end)
    end
end

local function InstallResourcesHiddenReHideHook(itemFrame)
    if itemFrame.cdmShowHooked then return end
    itemFrame.cdmShowHooked = true
    local function reHideIfResourceHidden(self)
        local hiddenSet = CDM.resourcesHiddenBuffSet
        if not hiddenSet or not next(hiddenSet) then return end
        local id = CDM.GetBaseSpellID(self)
        if id and hiddenSet[id] then
            self:Hide()
        end
    end
    hooksecurefunc(itemFrame, "Show", reHideIfResourceHidden)
    hooksecurefunc(itemFrame, "SetShown", function(self, shown)
        if shown then reHideIfResourceHidden(self) end
    end)
end

local function InstallBuffSpellIDNotifyHook(itemFrame)
    if itemFrame.cdmSpellIDNotifyHooked then return end
    itemFrame.cdmSpellIDNotifyHooked = true
    hooksecurefunc(itemFrame, "SetCooldownID", function(self)
        local baseID = CDM.GetBaseSpellID(self)
        if baseID then
            CDM:NotifyBuffFrameSpellID(self, baseID)
        end
    end)
end

local function InstallEditModeOverlayRefresh(v, vName)
    CDM:UpdateEditModeSelectionOverlay(vName)
    v:HookScript("OnShow", function()
        CDM:UpdateEditModeSelectionOverlay(vName)
    end)
end

local function InstallRefreshLayoutReanchor(v)
    hooksecurefunc(v, "RefreshLayout", function()
        CDM:ForceReanchor(v)
    end)
end

local function InstallContainerSyncHook(v, vName)
    hooksecurefunc(v, "SetPoint", function(_, point, relativeTo)
        if InCombatLockdown() then return end
        local container = CDM.anchorContainers and CDM.anchorContainers[vName]
        if not container or relativeTo == container then return end
        v:ClearAllPoints()
        v:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        v:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    end)
end

function CDM:SetupViewer(vName)
    local v = _G[vName]
    if not v then return end

    local isEssOrUtil = (vName == VIEWERS.ESSENTIAL or vName == VIEWERS.UTILITY)
    local isBuff = (vName == VIEWERS.BUFF)
    local isBuffBar = (vName == VIEWERS.BUFF_BAR)
    local hasAnchorSnapBack = not isBuffBar
    local hasActiveStateHook = isBuff or isBuffBar

    hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
        InstallScaleLockHook(itemFrame)
        CDM:RestoreCooldownTextIfHidden(itemFrame)
        CDM:RestoreVisualsIfHidden(itemFrame)

        if hasAnchorSnapBack then
            InstallAnchorSnapBackHook(itemFrame, "cdmAnchor")
        elseif isBuffBar then
            InstallAnchorSnapBackHook(itemFrame, "cdmBarAnchor")
        end
        if hasActiveStateHook then
            InstallActiveStateRepositionHook(itemFrame, vName)
        end
        if isBuff then
            InstallResourcesHiddenReHideHook(itemFrame)
            InstallBuffSpellIDNotifyHook(itemFrame)
        end
    end)

    -- fix from MiliUI: OnAcquireItemFrame 只對「掛勾之後」取出的框架生效。登入時暴雪的
    -- 冷卻管理器往往比這裡更早取出一批框架，那批永遠不會經過上面的 hook，
    -- 於是編輯模式套下來的 scale 就一直留著（實測 0.7），要進一次編輯模式才會好。
    if v.itemFramePool then
        for itemFrame in v.itemFramePool:EnumerateActive() do
            InstallScaleLockHook(itemFrame)
        end
    end

    CDM.BORDER:InstallAcquireResetHook(v)
    CDM:InstallLayoutAcquireResetHook(v)
    CDM:InstallStyleAcquireResetHook(v)
    CDM:InstallSpellCacheAcquireResetHook(v)
    if isBuff then
        CDM:InstallBuffGroupsAcquireResetHook(v)
    end
    CDM.Glow:InstallAcquireResetHook(v)
    if isEssOrUtil then
        CDM.GlowDirector:InstallAcquireResetHook(v)
    end

    InstallEditModeOverlayRefresh(v, vName)
    InstallRefreshLayoutReanchor(v)
    if isEssOrUtil then
        InstallContainerSyncHook(v, vName)
    end
end

CDM.loginDeferredFullChange = nil

local function InitializeAnchorContainers()
    for _, vName in ipairs(ALL_VIEWER_NAMES) do
        if _G[vName] then
            if vName == VIEWERS.ESSENTIAL then
                CDM:CreateEssentialAnchorContainer()
            elseif vName == VIEWERS.BUFF then
                CDM:CreateBuffAnchorContainer()
            elseif vName == VIEWERS.BUFF_BAR then
                CDM:CreateBuffBarAnchorContainer()
            elseif vName == VIEWERS.UTILITY then
                CDM:CreateUtilityAnchorContainer()
            end
        end
    end
end

local function ActivateEditMode()
    CDM.isEditModeActive = true
    CDM:SetupCooldownViewerDragFrames()
    CDM:UpdateEditModeSelectionOverlays()
    CDM.Fading:ShowImmediate()
end

local function SetupEditModeIntegration()
    EventRegistry:RegisterCallback("EditMode.Enter", ActivateEditMode, CDM)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        CDM.isEditModeActive = false
        -- fix from MiliUI: 滑鼠在遊戲視窗外放開時 OnDragStop 不一定會進來，
        -- 標記卡住的話之後所有 reanchor 都會被擋掉，離開編輯模式一律清乾淨
        CDM.draggingViewer = nil
        CDM:ForceReanchorAll()
        CDM.Fading:Evaluate()
    end, CDM)

    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then
        ActivateEditMode()
    end

    CDM:SetupEditModeCooldownViewerIntegration()
end

local function SetupLoadingAndSpecCoordination()
    local pendingPostSpecSetup = false
    local initialSetupDone = false

    local function RunVisualSetup()
        CDM.Pixel.Update()
        CDM:RefreshSpecData()
        CDM:ForceReanchorAll()
        CDM:Refresh()
    end

    EventUtil.ContinueAfterAllEvents(function()
        CDM.loginFinished = true
        if CDM.pendingSpecChange then
            pendingPostSpecSetup = true
        else
            RunVisualSetup()
        end
        initialSetupDone = true
        CDM:TryOpenQueuedConfig("login_ready")
        CDM:ProcessDeferredLogin()
    end, "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD",
       "COOLDOWN_VIEWER_DATA_LOADED", "LOADING_SCREEN_DISABLED")

    CDM:RegisterEvent("LOADING_SCREEN_ENABLED", function()
        CDM.loadingScreenActive = true
    end)

    CDM:RegisterEvent("LOADING_SCREEN_DISABLED", function()
        CDM.loadingScreenActive = false
        if not initialSetupDone then return end

        if CDM.pendingSpecChange then
            pendingPostSpecSetup = true
        else
            RunVisualSetup()
        end
    end)

    function CDM:NotifySpecChangeComplete()
        if pendingPostSpecSetup then
            pendingPostSpecSetup = false
            RunVisualSetup()
        end
    end
end

local function RegisterUIScaleEvent()
    CDM:RegisterEvent("UI_SCALE_CHANGED", function()
        CDM.Pixel.Update()
        CDM:UpdateEssentialContainerPosition()
        CDM:UpdateBuffContainerPosition()
        CDM:UpdateBuffBarContainerPosition()
        CDM:Refresh()
    end)
end

-- fix from MiliUI: 模組初始化/套用設定檔也要逐一隔離。這兩串是裸的循序呼叫，
-- 在 12.1 只要前面一支拋錯（例如在首領戰中 /reload，光環是秘密值），
-- 後面的模組就整組不會初始化，畫面看起來像「插件只做了一半」。
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return end
    return xpcall(fn, geterrorhandler(), ...)
end

local function RunProfileAppliedHooks()
    SafeCall(CDM.OnRacialsProfileApplied)
    SafeCall(CDM.OnDefensivesProfileApplied)
    SafeCall(CDM.OnTrinketsProfileApplied)
    SafeCall(CDM.OnResourcesProfileApplied)
    SafeCall(CDM.OnExternalsProfileApplied)
end

CDM.RunProfileAppliedHooks = RunProfileAppliedHooks

local function InitializeModules()
    SafeCall(CDM.ReconcileRacials)
    SafeCall(CDM.ReconcileDefensives)
    SafeCall(CDM.ReconcileTrinkets)
    SafeCall(CDM.ReconcileResources)
    SafeCall(CDM.ReconcileExternals)

    SafeCall(CDM.InitializeCustomBuffs, CDM)

    if CDM.db.castBarEnabled ~= false then
        SafeCall(CDM.CreatePlayerCastBar, CDM)
    end

    SafeCall(CDM.BuffGroups and CDM.BuffGroups.Initialize, CDM.BuffGroups)
    SafeCall(CDM.BuffGroupPlaceholders and CDM.BuffGroupPlaceholders.Initialize, CDM.BuffGroupPlaceholders)
    SafeCall(CDM.Glow and CDM.Glow.Initialize, CDM.Glow)
    SafeCall(CDM.Keybinds and CDM.Keybinds.Initialize, CDM.Keybinds)
    SafeCall(CDM.Fading and CDM.Fading.Initialize, CDM.Fading)
    SafeCall(CDM.RotationAssist and CDM.RotationAssist.Initialize, CDM.RotationAssist)
    SafeCall(CDM.PressOverlay and CDM.PressOverlay.Initialize, CDM.PressOverlay)
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

local function LiftManagedViewerStrata()
    if InCombatLockdown() then
        CDM.combatDirtyStrata = true
        return
    end
    for _, vName in ipairs(MANAGED_VIEWER_NAMES) do
        local v = _G[vName]
        if v then
            v:SetFrameStrata("MEDIUM")
            if v.SetFixedFrameStrata then
                v:SetFixedFrameStrata(true)
            end
        end
    end
    CDM.combatDirtyStrata = nil
end

local function ForceRestyleAll()
    RefreshStyleCache()
    CDM:ForEachActiveFrame({ VIEWERS.ESSENTIAL, VIEWERS.UTILITY, VIEWERS.BUFF }, function(frame, vName)
        CDM:ApplyStyle(frame, vName, true)
        if vName == VIEWERS.BUFF then
            CDM:RestoreCooldownTextIfHidden(frame)
            CDM:RestoreVisualsIfHidden(frame)
            CDM:ApplyUngroupedBuffOverrides(frame)
        end
    end)
    for _, buffData in pairs(CDM.CustomBuffs.activeBuffs) do
        local frame = buffData.frame
        if frame then
            CDM:ApplyStyle(frame, VIEWERS.BUFF, true)
            CDM:ApplyUngroupedBuffOverrides(frame)
        end
    end
    CDM:ApplyGroupStyleOverrides()
    local bbViewer = _G[VIEWERS.BUFF_BAR]
    if bbViewer then CDM:ForceReanchor(bbViewer) end
    CDM.RefreshAllSwipeColors()
    CDM.Fading:ReapplyCurrent()
end

local function RegisterRefreshCallbacks()
    CDM:RegisterRefreshCallback("styleCache", function()
        CDM.styleCacheVersion = (CDM.styleCacheVersion or 0) + 1
        RefreshStyleCache()
    end, 10)

    CDM:RegisterRefreshCallback("constants", function()
        CDM:InvalidateUtilityVisibleCountCache()
        UpdateConstants()
    end, 20)

    CDM:RegisterRefreshCallback("specData", function()
        CDM:RefreshSpecData()
    end, 30, { "BUFF_DATA", "BAR_DATA", "CD_DATA" })

    CDM:RegisterRefreshCallback("essentialPosition", function()
        CDM:UpdateEssentialContainerPosition()
    end, 35, { "LAYOUT" })

    CDM:RegisterRefreshCallback("viewers_layout", function()
        CDM:ForceReanchorAll()
    end, 40, { "LAYOUT", "BUFF_DATA", "BAR_DATA", "CD_DATA" })

    CDM:RegisterRefreshCallback("viewers_style", ForceRestyleAll, 45, { "STYLE", "BUFF_DATA", "BAR_DATA", "CD_DATA" })

    CDM:RegisterRefreshCallback("trackerModules", function()
        CDM.ReconcileDefensives()
        CDM.ReconcileRacials()
        CDM.ReconcileTrinkets()
        CDM.ReconcileExternals()
    end, 50, { "TRACKERS" })

    CDM:RegisterRefreshCallback("resources", function()
        CDM.ReconcileResources()
    end, 50, { "RESOURCES" })

    CDM:RegisterRefreshCallback("buffPosition", function()
        CDM:UpdateBuffContainerPosition()
    end, 60, { "LAYOUT" })

    CDM:RegisterRefreshCallback("buffBars", function()
        CDM:UpdateBuffBarContainerPosition()
    end, 65, { "LAYOUT", "TRACKERS" })
end

function CDM:OnEnable()
    SLASH_AYIJECDM1 = "/acdm"
    SLASH_AYIJECDM2 = "/cdm"
    SlashCmdList["AYIJECDM"] = function()
        CDM:RequestConfigOpen("slash", nil)
    end

    InitializeAnchorContainers()
    for _, vName in ipairs(ALL_VIEWER_NAMES) do
        self:SetupViewer(vName)
    end
    LiftManagedViewerStrata()
    SetupEditModeIntegration()
    self:InitializeConfigEvents()
    SetupLoadingAndSpecCoordination()
    RegisterUIScaleEvent()
    self:InitializeSpecChangeSystem()
    RefreshStyleCache()
    InitializeModules()
    RegisterRefreshCallbacks()
    RegisterLSMFontRefreshCallback()
    RegisterCooldownViewerSettingsVisualRefresh()
    RegisterCooldownViewerTableHotfix()
    self:DisableBlizzardPlayerCastBar()

    self:RegisterCombatStateHandler(function(isInCombat)
        if isInCombat then
            return
        end
        if CDM.combatDirtyStrata then
            LiftManagedViewerStrata()
        end
        FlushCombatDirtyViewers()
        FlushDirtyItemFrameScales()  -- fix from MiliUI: 戰鬥中改不了的 scale 這時補回 1
    end)
end
