local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS
local GetConfigValue = CDM_C.GetConfigValue
local L = CDM.L

local LOCK_FRAME_NAMES = {
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

local function CountActiveItemFrames(systemFrame)
    if not (systemFrame and systemFrame.itemFramePool) then
        return 0
    end
    local count = 0
    for _ in systemFrame.itemFramePool:EnumerateActive() do
        count = count + 1
    end
    return count
end

function CDM:EnsureCooldownViewerLockText(selection)
    if not selection then return end
    local state = GetSelectionState(selection)
    if state.lockText then return end
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
    state.lockText = text
end

function CDM:GetCooldownViewerLockMessage(systemFrame)
    local vName = systemFrame:GetName()
    local df = CDM.defaults or {}
    local twoLine = false

    if vName == VIEWERS.ESSENTIAL then
        local count = CountActiveItemFrames(systemFrame)
        local maxRowEss = GetConfigValue("maxRowEss", df.maxRowEss) or 8

        if count == 0 or count > maxRowEss then
            twoLine = true
        else
            local sizeEssRow1 = GetConfigValue("sizeEssRow1", df.sizeEssRow1) or { h = 40 }
            local sizeEssRow2 = GetConfigValue("sizeEssRow2", df.sizeEssRow2) or sizeEssRow1
            local spacing = GetConfigValue("spacing", df.spacing) or 6
            local twoRowHeight = sizeEssRow1.h + spacing + sizeEssRow2.h

            local height = 0
            local selection = systemFrame.Selection
            if selection then
                height = selection:GetHeight()
            elseif self.anchorContainers and self.anchorContainers[VIEWERS.ESSENTIAL] then
                height = self.anchorContainers[VIEWERS.ESSENTIAL]:GetHeight()
            end

            if height >= (twoRowHeight - 0.5) then
                twoLine = true
            end
        end

    elseif vName == VIEWERS.UTILITY then
        local utilityWrap = GetConfigValue("utilityWrap", df.utilityWrap)
        local maxRowUtil = utilityWrap and GetConfigValue("maxRowUtil", df.maxRowUtil) or 0
        if maxRowUtil > 0 and CountActiveItemFrames(systemFrame) > maxRowUtil then
            twoLine = true
        end
    end

    if twoLine then
        return L["Edit Mode locked"] .. "\n" .. L["use /acdm"]
    end
    return L["Edit Mode locked - use /acdm"]
end

function CDM:SetCooldownViewerLockText(systemFrame, shown)
    if not IsCooldownViewerSystemFrame(systemFrame) then return end
    if InCombatLockdown() then return end
    local selection = systemFrame.Selection
    if not selection then return end

    if not shown then
        local state = selectionState[selection]
        if state then
            if state.lockText then state.lockText:Hide() end
            if state.textOverlay then state.textOverlay:Hide() end
        end
        return
    end

    self:EnsureCooldownViewerLockText(selection)
    local state = GetSelectionState(selection)
    local text = state.lockText
    if state.textOverlay then state.textOverlay:Show() end

    local fontPath = CDM_C.GetBaseFontPath()
    local fontOutline = CDM_C.GetBaseFontOutline() or "OUTLINE"

    text:SetFont(fontPath, CDM.Pixel.FontSize(20), fontOutline)
    text:SetTextColor(0.992, 0.071, 0, 1)

    local maxWidth = selection:GetWidth() - 12
    if maxWidth > 0 then
        text:SetWidth(maxWidth)
    end

    local vName = systemFrame:GetName()
    if vName == VIEWERS.ESSENTIAL or vName == VIEWERS.UTILITY then
        text:SetText(self:GetCooldownViewerLockMessage(systemFrame))
    else
        text:SetText(L["Edit Mode locked - use /acdm"])
    end

    text:Show()
end

function CDM:SetupCooldownViewerLockTextHandlers(systemFrame)
    if not IsCooldownViewerSystemFrame(systemFrame) then return end
    local selection = systemFrame.Selection
    if not selection then return end
    local state = GetSelectionState(selection)
    if state.handlersSet then return end

    state.handlersSet = true
    selection:HookScript("OnMouseDown", function()
        self:SetCooldownViewerLockText(systemFrame, true)
        state.lockTextToken = (state.lockTextToken or 0) + 1
        local token = state.lockTextToken
        C_Timer.After(2, function()
            if state.lockTextToken == token then
                self:SetCooldownViewerLockText(systemFrame, false)
            end
        end)
    end)
    selection:HookScript("OnHide", function()
        self:SetCooldownViewerLockText(systemFrame, false)
    end)
end

local function ShowLockNotice()
    if not CDM.editModeCooldownViewerNoticeShown then
        print("|cffffd200Ayije_CDM:|r " .. L["Cooldown Viewer settings are managed by /acdm."])
        CDM.editModeCooldownViewerNoticeShown = true
    end
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

    self:SetupCooldownViewerLockTextHandlers(viewer)
    self:SetCooldownViewerLockText(viewer, false)
end

function CDM:UpdateEditModeSelectionOverlays()
    for _, vName in ipairs(LOCK_FRAME_NAMES) do
        self:UpdateEditModeSelectionOverlay(vName)
    end
end

function CDM:LockCooldownViewerEditModeFrames()
    for _, name in ipairs(LOCK_FRAME_NAMES) do
        local frame = _G[name]
        if IsCooldownViewerSystemFrame(frame) then
            frame:SetMovable(false)
            local selection = frame.Selection
            if selection then
                selection:SetScript("OnDragStart", nil)
                selection:SetScript("OnDragStop", nil)
            end
            self:SetupCooldownViewerLockTextHandlers(frame)
            self:SetCooldownViewerLockText(frame, false)
        end
    end
end

function CDM:SetupEditModeCooldownViewerLock()
    if self.editModeCooldownViewerLockSetup then return end

    local function TrySetup()
        local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
        if not (EditModeSystemSettingsDialog and Enum and Enum.EditModeSystem) then
            return false
        end

        hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(dialog, systemFrame)
            if not IsCooldownViewerSystemFrame(systemFrame) then return end
            dialog:Hide()
            self:SetupCooldownViewerLockTextHandlers(systemFrame)
            ShowLockNotice()
        end)

        for _, name in ipairs(LOCK_FRAME_NAMES) do
            local frame = _G[name]
            if IsCooldownViewerSystemFrame(frame) then
                hooksecurefunc(frame, "SelectSystem", function(sf)
                    sf:SetMovable(false)
                    if EditModeSystemSettingsDialog.attachedToSystem == sf then
                        EditModeSystemSettingsDialog:Hide()
                    end
                    self:SetupCooldownViewerLockTextHandlers(sf)
                    ShowLockNotice()
                end)

                hooksecurefunc(frame, "HighlightSystem", function(sf)
                    self:SetupCooldownViewerLockTextHandlers(sf)
                end)

                hooksecurefunc(frame, "ClearHighlight", function(sf)
                    self:SetCooldownViewerLockText(sf, false)
                end)
            end
        end

        self.editModeCooldownViewerLockSetup = true
        self:LockCooldownViewerEditModeFrames()
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
