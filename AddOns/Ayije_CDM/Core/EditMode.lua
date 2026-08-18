local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS
local GetConfigValue = CDM_C.GetConfigValue
local L = CDM.L

local math_floor = math.floor

-- fix from MiliUI: 這支原本的作用是把四個冷卻檢視器在編輯模式裡「鎖死」—— 系統框
-- SetMovable(false)、把 Selection 的拖曳腳本清成 nil、選到就蓋一行紅字「Edit Mode
-- locked」，位置只能從 /acdm 的 X/Y 滑桿調。這裡改成可以直接在編輯模式拖曳。
--
-- 拖的是 CDM 自己的 anchorContainer（普通框），不是暴雪的 protected 系統框：系統框
-- 仍然維持 SetMovable(false)、繼續被釘在容器上，所以位置不會被寫進暴雪的 Edit Mode
-- layout，也沒有 taint 風險。放開滑鼠後把容器座標換算回 db 原有的欄位，再走原本的
-- reanchor 路徑 —— 拖曳和 /acdm 滑桿因此共用同一份資料，兩邊互通。
local DRAGGABLE_FRAME_NAMES = {
    VIEWERS.ESSENTIAL,
    VIEWERS.UTILITY,
    VIEWERS.BUFF,
    VIEWERS.BUFF_BAR,
}

local selectionState = setmetatable({}, { __mode = "k" })

local function GetSelectionState(selection)
    local state = selectionState[selection]
    if not state then
        state = {}
        selectionState[selection] = state
    end
    return state
end

local function IsCooldownViewerSystemFrame(frame)
    local cooldownSystem = Enum and Enum.EditModeSystem and Enum.EditModeSystem.CooldownViewer
    return cooldownSystem and frame and frame.system == cooldownSystem
end

local function Round(value)
    return math_floor((value or 0) + 0.5)
end

-- UIParent 上某個錨點的螢幕座標。db 存的位置一律是「相對 UIParent 的某個 point」，
-- 拖曳結束後必須用同一個 point 回推偏移量，否則換過 point 的設定檔會整個偏掉。
local function GetUIParentAnchorXY(point)
    local left, bottom = UIParent:GetLeft(), UIParent:GetBottom()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not (left and bottom and width and height) then return nil end

    point = point or "CENTER"

    local x = left
    if point == "CENTER" or point == "TOP" or point == "BOTTOM" then
        x = left + width / 2
    elseif point:find("RIGHT", 1, true) then
        x = left + width
    end

    local y = bottom
    if point == "CENTER" or point == "LEFT" or point == "RIGHT" then
        y = bottom + height / 2
    elseif point:find("TOP", 1, true) then
        y = bottom + height
    end

    return x, y
end

-- 輔助欄的水平偏移只有在「自動換行 + 解鎖輔助欄」都開啟時才會被 GetLayoutConfig 採用
-- （沒開就強制 0），所以沒解鎖時橫向拖曳寫了也會被彈回，那種情況只寫 Y。
local function IsUtilityXUnlocked()
    local df = CDM.defaults or {}
    local utilityWrap = GetConfigValue("utilityWrap", df.utilityWrap)
    if not utilityWrap then return false end
    return GetConfigValue("utilityUnlock", df.utilityUnlock) and true or false
end

-- 主要增益框開了「跟著資源條走」時位置由資源條決定（UpdateBuffContainerPosition 會直接
-- 錨到資源條上），拖了也會被拉回去。判斷條件跟該函式保持一致。
local function IsBuffFollowingResources()
    local db = CDM.db
    if not (db and db.moveBuffsDown and db.resourcesEnabled ~= false) then
        return false
    end

    local fallback = db.moveBuffsDownFallback or "lastResource"
    if CDM.ResolveResourcesAnchor and CDM.ResolveResourcesAnchor(fallback == "lastResource") then
        return true
    end

    if fallback == "essential" then
        local essContainer = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.ESSENTIAL]
        return (essContainer and essContainer:IsShown()) and true or false
    end

    return false
end

-- 這個框的拖曳有沒有被別的設定限制住；有的話回傳要顯示在框上的說明。
local function GetDragRestriction(vName)
    if vName == VIEWERS.BUFF and IsBuffFollowingResources() then
        return L["Anchored to resources - see /acdm > Resources"]
    end
    if vName == VIEWERS.UTILITY and not IsUtilityXUnlocked() then
        return L["Vertical only - unlock the utility bar in /acdm"]
    end
    return nil
end

function CDM:EnsureCooldownViewerHintText(selection)
    if not selection then return end
    local state = GetSelectionState(selection)
    if state.hintText then return end
    if not state.textOverlay then
        state.textOverlay = CreateFrame("Frame", nil, UIParent)
        state.textOverlay:SetAllPoints(selection)
        state.textOverlay:SetFrameStrata(CDM_C.STRATA_OVERLAY)
        state.textOverlay:SetFrameLevel(selection:GetFrameLevel() + 5)
    end
    local text = state.textOverlay:CreateFontString(nil, "OVERLAY")
    text:SetIgnoreParentScale(true)
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(true)
    state.hintText = text
end

function CDM:SetCooldownViewerHintText(systemFrame, shown)
    if not IsCooldownViewerSystemFrame(systemFrame) then return end
    if InCombatLockdown() then return end
    local selection = systemFrame.Selection
    if not selection then return end

    local message = shown and GetDragRestriction(systemFrame:GetName()) or nil

    if not message then
        local state = selectionState[selection]
        if state then
            if state.hintText then state.hintText:Hide() end
            if state.textOverlay then state.textOverlay:Hide() end
        end
        return
    end

    self:EnsureCooldownViewerHintText(selection)
    local state = GetSelectionState(selection)
    local text = state.hintText
    if state.textOverlay then state.textOverlay:Show() end

    local fontPath = CDM_C.GetBaseFontPath()
    local fontOutline = CDM_C.GetBaseFontOutline() or "OUTLINE"

    text:SetFont(fontPath, CDM.Pixel.FontSize(14), fontOutline)
    text:SetTextColor(1, 0.82, 0, 1)

    local maxWidth = selection:GetWidth() - 12
    if maxWidth > 0 then
        text:SetWidth(maxWidth)
    end

    text:SetText(message)
    text:Show()
end

-- 拖曳結束後把容器座標換算回 db。每個框的錨點語意都不一樣，換算不能共用一套：
-- 必備欄與增益條錨的是左緣但 x 已經扣掉半寬（等於中心語意），主要增益框錨的是 BOTTOM，
-- 輔助欄則根本不是獨立定位、而是掛在必備欄底下的一組 offset。
local function SavePosition(vName, container)
    local db = CDM.db
    if not db then return end

    local Pixel = CDM.Pixel

    if vName == VIEWERS.UTILITY then
        -- SetUtilityAnchor: TOPLEFT → essContainer BOTTOMLEFT,
        --                   (essHalfW - utilHalfW + utilityXOffset, -spacing + utilityYOffset)
        local essContainer = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.ESSENTIAL]
        if not essContainer then return end

        local df = CDM.defaults or {}
        local spacing = GetConfigValue("spacing", df.spacing) or 1
        db.utilityYOffset = Round(container:GetTop() - essContainer:GetBottom() + spacing)

        if IsUtilityXUnlocked() then
            local essHalfW = Pixel.HalfFloor(essContainer:GetWidth() or 0)
            local utilHalfW = Pixel.HalfFloor(container:GetWidth() or 0)
            db.utilityXOffset = Round(container:GetLeft() - essContainer:GetLeft() - essHalfW + utilHalfW)
        end
        return
    end

    local pos = CDM.GetViewerPositionSettings and CDM:GetViewerPositionSettings(vName)
    if not pos then return end

    local ax, ay = GetUIParentAnchorXY(pos.point)
    if not ax then return end

    if vName == VIEWERS.ESSENTIAL then
        -- AnchorEssentialContainer: TOPLEFT → UIParent pos.point, (x - halfW, y)
        local halfW = Pixel.HalfFloor(container:GetWidth() or 0)
        pos.x = Round(container:GetLeft() + halfW - ax)
        pos.y = Round(container:GetTop() - ay)

    elseif vName == VIEWERS.BUFF then
        -- AnchorBuffContainer: BOTTOM → UIParent pos.point, (x, y)
        local centerX = container:GetCenter()
        if not centerX then return end
        pos.x = Round(centerX - ax)
        pos.y = Round(container:GetBottom() - ay)

    elseif vName == VIEWERS.BUFF_BAR then
        -- UpdateBuffBarContainerPosition: 往下長錨 TOPLEFT、往上長錨 BOTTOMLEFT，
        -- x 一樣扣掉半寬
        local halfW = Pixel.HalfFloor(container:GetWidth() or 0)
        local growDown = (db.buffBarGrowDirection or "DOWN") == "DOWN"
        pos.x = Round(container:GetLeft() + halfW - ax)
        pos.y = Round((growDown and container:GetTop() or container:GetBottom()) - ay)
    end
end

-- /acdm 的位置滑桿要能反映拖曳結果。Options 是另一支插件、不一定載入，這裡只提供掛號處。
local positionRefreshers = {}

function CDM:RegisterPositionRefresher(fn)
    if type(fn) == "function" then
        positionRefreshers[#positionRefreshers + 1] = fn
    end
end

function CDM:RefreshPositionSliders()
    for _, fn in ipairs(positionRefreshers) do
        fn()
    end
end

-- 寫回 db 之後重新套用一次正規錨點：位置對不對立刻看得出來，同時把跟著這個框走的
-- 東西（輔助欄、資源條、施法條）一起帶動。
local function ReapplyPosition(vName)
    if vName == VIEWERS.ESSENTIAL then
        CDM:UpdateEssentialContainerPosition()
    elseif vName == VIEWERS.UTILITY then
        CDM:UpdateUtilityContainerPosition()
    elseif vName == VIEWERS.BUFF then
        CDM:UpdateBuffContainerPosition()
    elseif vName == VIEWERS.BUFF_BAR then
        CDM:UpdateBuffBarContainerPosition()
    end

    if vName == VIEWERS.ESSENTIAL or vName == VIEWERS.UTILITY then
        if CDM.UpdateResources then CDM:UpdateResources() end
        if CDM.UpdatePlayerCastBar then CDM:UpdatePlayerCastBar() end
    end

    -- /acdm 的位置分頁如果開著，讓滑桿顯示拖曳後的新值
    CDM:RefreshPositionSliders()
end

local function BeginDrag(systemFrame, vName)
    if InCombatLockdown() then return end

    local container = CDM.anchorContainers and CDM.anchorContainers[vName]
    if not container then return end

    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:StartMoving()
    CDM.draggingViewer = vName

    CDM:SetCooldownViewerHintText(systemFrame, true)
end

local function EndDrag(systemFrame, vName)
    local container = CDM.anchorContainers and CDM.anchorContainers[vName]
    if not container then return end

    container:StopMovingOrSizing()
    -- 有名字的框被拖過之後會被暴雪的 layout cache 接管，之後我們自己的 SetPoint 會被它
    -- 拉走；每次放開都要清掉。
    container:SetUserPlaced(false)
    CDM.draggingViewer = nil

    -- 戰鬥中不寫入也不重錨（reanchor 那批本來就有 InCombatLockdown 閘），
    -- 出戰鬥後的 ForceReanchorAll 會把框拉回 db 裡的舊位置。
    if InCombatLockdown() then return end

    SavePosition(vName, container)
    ReapplyPosition(vName)
end

local function ShowDragNotice()
    if not CDM.editModeCooldownViewerNoticeShown then
        print("|cffffd200Ayije_CDM:|r " .. L["Drag to move. Other settings are managed by /acdm."])
        CDM.editModeCooldownViewerNoticeShown = true
    end
end

function CDM:SetupCooldownViewerDragHandlers(systemFrame)
    if not IsCooldownViewerSystemFrame(systemFrame) then return end
    local selection = systemFrame.Selection
    if not selection then return end
    local state = GetSelectionState(selection)
    if state.handlersSet then return end

    local vName = systemFrame:GetName()
    state.handlersSet = true

    selection:RegisterForDrag("LeftButton")
    -- SetScript 而不是 HookScript：暴雪原本的 OnDragStart 會去移動系統框自己，
    -- 那條路要整個換掉，不能只是加掛。
    selection:SetScript("OnDragStart", function()
        BeginDrag(systemFrame, vName)
    end)
    selection:SetScript("OnDragStop", function()
        EndDrag(systemFrame, vName)
        state.hintToken = (state.hintToken or 0) + 1
        local token = state.hintToken
        C_Timer.After(2, function()
            if state.hintToken == token then
                self:SetCooldownViewerHintText(systemFrame, false)
            end
        end)
    end)
    selection:HookScript("OnHide", function()
        self:SetCooldownViewerHintText(systemFrame, false)
    end)
end

function CDM:UpdateEditModeSelectionOverlay(vName)
    if not vName then return end
    local viewer = _G[vName]
    if not viewer then return end
    local selection = viewer.Selection
    if not selection then return end
    local container = self.anchorContainers and self.anchorContainers[vName]
    if not container then return end
    if InCombatLockdown() then return end

    selection:ClearAllPoints()
    selection:SetAllPoints(container)
    selection:SetFrameLevel(container:GetFrameLevel() + 2)

    self:SetupCooldownViewerDragHandlers(viewer)
    self:SetCooldownViewerHintText(viewer, false)
end

function CDM:UpdateEditModeSelectionOverlays()
    for _, vName in ipairs(DRAGGABLE_FRAME_NAMES) do
        self:UpdateEditModeSelectionOverlay(vName)
    end
end

function CDM:SetupCooldownViewerDragFrames()
    for _, name in ipairs(DRAGGABLE_FRAME_NAMES) do
        local frame = _G[name]
        if IsCooldownViewerSystemFrame(frame) then
            -- 系統框自己維持不可移動：拖的是 CDM 的容器，系統框只是被釘在容器上
            frame:SetMovable(false)

            local container = self.anchorContainers and self.anchorContainers[name]
            if container then
                container:SetMovable(true)
                container:SetClampedToScreen(true)
            end

            self:SetupCooldownViewerDragHandlers(frame)
            self:SetCooldownViewerHintText(frame, false)
        end
    end
end

function CDM:SetupEditModeCooldownViewerIntegration()
    if self.editModeCooldownViewerSetupDone then return end

    local function TrySetup()
        local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
        if not (EditModeSystemSettingsDialog and Enum and Enum.EditModeSystem) then
            return false
        end

        -- 暴雪那個設定對話框裡的選項跟 CDM 的設定不同步，開了只會誤導，維持攔下來。
        -- 位置改成用拖的，其餘設定仍然走 /acdm。
        hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(dialog, systemFrame)
            if not IsCooldownViewerSystemFrame(systemFrame) then return end
            dialog:Hide()
            self:SetupCooldownViewerDragHandlers(systemFrame)
            ShowDragNotice()
        end)

        for _, name in ipairs(DRAGGABLE_FRAME_NAMES) do
            local frame = _G[name]
            if IsCooldownViewerSystemFrame(frame) then
                hooksecurefunc(frame, "SelectSystem", function(sf)
                    sf:SetMovable(false)
                    if EditModeSystemSettingsDialog.attachedToSystem == sf then
                        EditModeSystemSettingsDialog:Hide()
                    end
                    self:SetupCooldownViewerDragHandlers(sf)
                    ShowDragNotice()
                end)

                hooksecurefunc(frame, "HighlightSystem", function(sf)
                    self:SetupCooldownViewerDragHandlers(sf)
                end)

                hooksecurefunc(frame, "ClearHighlight", function(sf)
                    self:SetCooldownViewerHintText(sf, false)
                end)
            end
        end

        self.editModeCooldownViewerSetupDone = true
        self:SetupCooldownViewerDragFrames()
        return true
    end

    if not TrySetup() then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", function()
            TrySetup()
        end)
    end
end

local function HasCooldownViewerEditModeApis()
    return C_EditMode
        and C_EditMode.GetLayouts
        and C_EditMode.SaveLayouts
        and Enum
        and Enum.EditModeSystem
        and Enum.EditModeSystem.CooldownViewer
        and Enum.EditModeCooldownViewerSystemIndices
        and Enum.EditModeCooldownViewerSetting
        and Enum.CooldownViewerVisibleSetting
        and Enum.CooldownViewerBarContent
        and Enum.EditModeLayoutType
end

local function GetActiveLayout(layoutInfo)
    if type(layoutInfo) ~= "table" then
        return nil
    end

    local layouts = layoutInfo.layouts
    local activeIndex = layoutInfo.activeLayout
    if type(layouts) ~= "table" or type(activeIndex) ~= "number" then
        return nil
    end

    local activeLayout = layouts[activeIndex]
    if type(activeLayout) ~= "table" or type(activeLayout.systems) ~= "table" then
        return nil
    end

    return activeLayout
end

local function NormalizeLayoutInfo(layoutInfo)
    if type(layoutInfo) ~= "table" or type(layoutInfo.layouts) ~= "table" then
        return nil
    end

    if type(layoutInfo.activeLayout) ~= "number" then
        return layoutInfo
    end

    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
        local presetLayouts = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
        if type(presetLayouts) == "table" then
            tAppendAll(presetLayouts, layoutInfo.layouts)
            layoutInfo.layouts = presetLayouts
        end
    end

    return layoutInfo
end

local function GetLayoutInfo()
    if not (C_EditMode and C_EditMode.GetLayouts) then
        return nil
    end

    local layoutInfo = C_EditMode.GetLayouts()
    return NormalizeLayoutInfo(layoutInfo)
end

local function GetSettingValue(settings, settingEnum)
    if type(settings) ~= "table" then
        return nil
    end

    for _, settingInfo in ipairs(settings) do
        if settingInfo.setting == settingEnum then
            return settingInfo.value
        end
    end

    return nil
end

local function UpsertSetting(settings, settingEnum, desiredValue)
    if type(settings) ~= "table" then
        return false
    end

    for _, settingInfo in ipairs(settings) do
        if settingInfo.setting == settingEnum then
            if settingInfo.value ~= desiredValue then
                settingInfo.value = desiredValue
                return true
            end
            return false
        end
    end

    settings[#settings + 1] = {
        setting = settingEnum,
        value = desiredValue,
    }
    return true
end

local POLICIES
local function GetPolicies()
    if POLICIES then return POLICIES end
    local SI = Enum.EditModeCooldownViewerSystemIndices
    local ESS, UTIL, BICON, BBAR = SI.Essential, SI.Utility, SI.BuffIcon, SI.BuffBar
    POLICIES = {
        {
            id = "alwaysVisible",
            labelKey = "Always Visible",
            systemIndices = { ESS, UTIL, BICON, BBAR },
            setting = Enum.EditModeCooldownViewerSetting.VisibleSetting,
            recommendedValue = Enum.CooldownViewerVisibleSetting.Always,
        },
        {
            id = "showTimer",
            labelKey = "Show Timer",
            systemIndices = { ESS, UTIL, BICON, BBAR },
            setting = Enum.EditModeCooldownViewerSetting.ShowTimer,
            recommendedValue = 1,
        },
        {
            id = "hideBuffsWhenInactive",
            labelKey = "Hide Buffs When Inactive",
            systemIndices = { BICON, BBAR },
            setting = Enum.EditModeCooldownViewerSetting.HideWhenInactive,
            recommendedValue = 1,
        },
        {
            id = "fullOpacity",
            labelKey = "Full Opacity",
            systemIndices = { ESS, UTIL, BICON, BBAR },
            setting = Enum.EditModeCooldownViewerSetting.Opacity,
            recommendedValue = 100,
        },
        {
            id = "barIconAndName",
            labelKey = "Bar Content: Icon & Name",
            systemIndices = { BBAR },
            setting = Enum.EditModeCooldownViewerSetting.BarContent,
            recommendedValue = Enum.CooldownViewerBarContent.IconAndName,
        },
        {
            id = "hideTooltips",
            labelKey = "Hide Tooltips",
            systemIndices = { ESS, UTIL, BICON, BBAR },
            setting = Enum.EditModeCooldownViewerSetting.ShowTooltips,
            recommendedValue = 0,
        },
    }
    for _, policy in ipairs(POLICIES) do
        local set = {}
        for _, idx in ipairs(policy.systemIndices) do
            set[idx] = true
        end
        policy.systemIndexSet = set
    end
    return POLICIES
end

function CDM:GetCooldownViewerEditModePolicies()
    local result = {
        isReady = false,
        isPresetLayout = false,
        policies = {},
    }

    if not HasCooldownViewerEditModeApis() then
        return result
    end

    for _, policy in ipairs(GetPolicies()) do
        result.policies[#result.policies + 1] = {
            id = policy.id,
            labelKey = policy.labelKey,
            systemIndices = policy.systemIndices,
            systemIndexSet = policy.systemIndexSet,
            setting = policy.setting,
            recommendedValue = policy.recommendedValue,
            currentByViewer = {},
            isCompliant = true,
        }
    end

    local layoutInfo = GetLayoutInfo()
    local activeLayout = GetActiveLayout(layoutInfo)
    if not activeLayout then
        return result
    end

    result.isPresetLayout = (activeLayout.layoutType == Enum.EditModeLayoutType.Preset)

    local cooldownSystem = Enum.EditModeSystem.CooldownViewer
    local cooldownSystemsSeen = 0
    for _, systemInfo in ipairs(activeLayout.systems) do
        if systemInfo.system == cooldownSystem and type(systemInfo.settings) == "table" then
            cooldownSystemsSeen = cooldownSystemsSeen + 1
            for i, policy in ipairs(GetPolicies()) do
                if policy.systemIndexSet[systemInfo.systemIndex] then
                    local currentValue = GetSettingValue(systemInfo.settings, policy.setting)
                    local policyState = result.policies[i]
                    policyState.currentByViewer[systemInfo.systemIndex] = currentValue
                    if currentValue ~= policy.recommendedValue then
                        policyState.isCompliant = false
                    end
                end
            end
        end
    end

    if cooldownSystemsSeen > 0 then
        result.isReady = true
    else
        for _, policyState in ipairs(result.policies) do
            policyState.isCompliant = true
            policyState.currentByViewer = {}
        end
    end

    return result
end

function CDM:ApplyCooldownViewerEditModeRecommendedSettings(policyIds)
    if self._isApplyingCooldownViewerPolicy then
        return "noop"
    end

    if not HasCooldownViewerEditModeApis() then
        return "not_ready"
    end

    if InCombatLockdown() then
        return "in_combat"
    end

    local layoutInfo = GetLayoutInfo()
    local activeLayout = GetActiveLayout(layoutInfo)
    if not activeLayout then
        return "not_ready"
    end

    if activeLayout.layoutType == Enum.EditModeLayoutType.Preset then
        return "preset_layout"
    end

    local selectedSet = {}
    if type(policyIds) == "table" and #policyIds > 0 then
        for _, id in ipairs(policyIds) do
            selectedSet[id] = true
        end
    else
        for _, policy in ipairs(GetPolicies()) do
            selectedSet[policy.id] = true
        end
    end

    local changed = false
    local cooldownSystem = Enum.EditModeSystem.CooldownViewer
    for _, systemInfo in ipairs(activeLayout.systems) do
        if systemInfo.system == cooldownSystem and type(systemInfo.settings) == "table" then
            for _, policy in ipairs(GetPolicies()) do
                if selectedSet[policy.id]
                    and policy.systemIndexSet[systemInfo.systemIndex]
                then
                    if UpsertSetting(systemInfo.settings, policy.setting, policy.recommendedValue) then
                        changed = true
                    end
                end
            end
        end
    end

    if not changed then
        return "noop"
    end

    self._isApplyingCooldownViewerPolicy = true
    C_EditMode.SaveLayouts(layoutInfo)

    if EditModeManagerFrame then
        EditModeManagerFrame:Show()
        EditModeManagerFrame:Hide()
    end

    self._isApplyingCooldownViewerPolicy = nil

    return "applied"
end
