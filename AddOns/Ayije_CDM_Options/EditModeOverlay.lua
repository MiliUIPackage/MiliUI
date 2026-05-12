local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L
local CDM_C = CDM.CONST

local VIEWER_LABELS = {
    [Enum.EditModeCooldownViewerSystemIndices.Essential] = "Essential",
    [Enum.EditModeCooldownViewerSystemIndices.Utility]   = "Utility",
    [Enum.EditModeCooldownViewerSystemIndices.BuffIcon]  = "Buff Icons",
    [Enum.EditModeCooldownViewerSystemIndices.BuffBar]   = "Buff Bars",
}

local VIEWER_ORDER = {
    Enum.EditModeCooldownViewerSystemIndices.Essential,
    Enum.EditModeCooldownViewerSystemIndices.Utility,
    Enum.EditModeCooldownViewerSystemIndices.BuffIcon,
    Enum.EditModeCooldownViewerSystemIndices.BuffBar,
}

local COLOR_COMPLIANT  = { 0.20, 0.75, 0.30, 1.0 }
local COLOR_MISMATCH   = { 0.90, 0.20, 0.20, 1.0 }
local COLOR_NA         = { 0.35, 0.35, 0.35, 1.0 }

local ICON_SIZE = 14
local ICON_GAP  = 6
local ICON_COLUMN_PITCH = ICON_SIZE + ICON_GAP
local ICON_CLUSTER_WIDTH = ICON_SIZE * #VIEWER_ORDER + ICON_GAP * (#VIEWER_ORDER - 1)

local CHECKBOX_SIZE     = 24
local LABEL_CHECKBOX_GAP = 4
local LABEL_ICONS_GAP   = 8
local ICONS_RIGHT_INSET = 2

local ROW_HEIGHT  = 30
local ROW_SPACING = 6

local TITLE_TEXT_HEIGHT   = 14
local HEADER_HEIGHT       = 14
local HEADER_TO_ROWS_GAP  = 4

local BUTTON_HEIGHT        = 24
local APPLY_WIDTH          = 100
local APPLY_DISCLAIMER_WIDTH = 200
local CANCEL_WIDTH         = 100
local BUTTONS_GAP          = 8
local BUTTON_BOTTOM_MARGIN = 8
local BANNER_TO_BUTTONS_GAP = 6

local function GetIndicatorState(policyState, systemIndex)
    if not policyState.systemIndexSet[systemIndex] then
        return "na"
    end
    if policyState.currentByViewer[systemIndex] == policyState.recommendedValue then
        return "compliant"
    end
    return "mismatch"
end

local function CreateMiniIcon(parent, viewerName)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:EnableMouse(true)

    local tex = icon:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    icon.tex = tex
    icon.viewerName = viewerName
    icon.state = "na"

    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local statusKey
        if self.state == "compliant" then
            statusKey = L["Compliant"]
        elseif self.state == "mismatch" then
            statusKey = L["Mismatched"]
        else
            statusKey = L["N/A"]
        end
        GameTooltip:SetText(L[self.viewerName] .. ": " .. statusKey)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return icon
end

local function SetMiniIconState(icon, state)
    icon.state = state
    local color
    if state == "compliant" then
        color = COLOR_COMPLIANT
    elseif state == "mismatch" then
        color = COLOR_MISMATCH
    else
        color = COLOR_NA
    end
    icon.tex:SetColorTexture(color[1], color[2], color[3], color[4])
end

local function CreatePolicyRow(parent, contentWidth)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(contentWidth, ROW_HEIGHT)

    local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    checkbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    checkbox:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.checkbox = checkbox

    local label = row:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    label:SetPoint("LEFT", checkbox, "RIGHT", LABEL_CHECKBOX_GAP, 0)
    label:SetJustifyH("LEFT")
    row.label = label

    local iconCluster = CreateFrame("Frame", nil, row)
    iconCluster:SetSize(ICON_CLUSTER_WIDTH, ICON_SIZE)
    iconCluster:SetPoint("RIGHT", row, "RIGHT", -ICONS_RIGHT_INSET, 0)
    row.iconCluster = iconCluster

    row.icons = {}
    local prev
    for i, systemIndex in ipairs(VIEWER_ORDER) do
        local icon = CreateMiniIcon(iconCluster, VIEWER_LABELS[systemIndex])
        if prev then
            icon:SetPoint("LEFT", prev, "RIGHT", ICON_GAP, 0)
        else
            icon:SetPoint("LEFT", iconCluster, "LEFT", 0, 0)
        end
        row.icons[systemIndex] = icon
        prev = icon
    end

    label:SetPoint("RIGHT", iconCluster, "LEFT", -LABEL_ICONS_GAP, 0)

    return row
end

local function CreateEditModeOverlay()
    local overlay = UI.CreateModalOverlay()
    local window = overlay.window

    local paddingX = 18
    local paddingY = 14
    local titleOffset = 28
    local windowWidth = 460
    local windowHeight = 360

    window:SetSize(windowWidth, windowHeight)

    local contentWidth = windowWidth - paddingX * 2

    local titleText = window:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    titleText:SetText(L["Edit Mode Settings"])
    titleText:SetPoint("TOPLEFT", window, "TOPLEFT", paddingX, -(paddingY + 16))
    titleText:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)

    local rowContainer = CreateFrame("Frame", nil, window)
    rowContainer:SetPoint(
        "TOPLEFT", window, "TOPLEFT",
        paddingX,
        -(paddingY + titleOffset + TITLE_TEXT_HEIGHT + HEADER_HEIGHT + HEADER_TO_ROWS_GAP)
    )
    rowContainer:SetSize(contentWidth, 220)

    local headerCluster = CreateFrame("Frame", nil, rowContainer)
    headerCluster:SetSize(ICON_CLUSTER_WIDTH, HEADER_HEIGHT)
    headerCluster:SetPoint("BOTTOMRIGHT", rowContainer, "TOPRIGHT", -ICONS_RIGHT_INSET, HEADER_TO_ROWS_GAP)

    local headerLetters = { "E", "U", "B", "Bb" }
    for i, letter in ipairs(headerLetters) do
        local fs = headerCluster:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        fs:SetText(letter)
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        local centerX = (ICON_SIZE / 2) + (i - 1) * ICON_COLUMN_PITCH
        fs:SetPoint("CENTER", headerCluster, "LEFT", centerX, 0)
    end

    local rows = {}

    local function BuildRows(policies, onCheckboxClick)
        for _, row in ipairs(rows) do row:Hide() end

        local y = 0
        for i, policyState in ipairs(policies) do
            local row = rows[i]
            if not row then
                row = CreatePolicyRow(rowContainer, contentWidth)
                row.checkbox:SetScript("OnClick", onCheckboxClick)
                rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rowContainer, "TOPLEFT", 0, -y)
            row:Show()
            row.label:SetText(L[policyState.labelKey])
            row.policyId = policyState.id
            row.checkbox:SetChecked(not policyState.isCompliant)
            for _, systemIndex in ipairs(VIEWER_ORDER) do
                local icon = row.icons[systemIndex]
                SetMiniIconState(icon, GetIndicatorState(policyState, systemIndex))
            end
            y = y + ROW_HEIGHT + ROW_SPACING
        end
    end

    local bannerY = paddingY + BUTTON_BOTTOM_MARGIN + BUTTON_HEIGHT + BANNER_TO_BUTTONS_GAP

    local presetBanner = window:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    presetBanner:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", paddingX, bannerY)
    presetBanner:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -paddingX, bannerY)
    presetBanner:SetJustifyH("LEFT")
    presetBanner:SetWordWrap(true)
    presetBanner:SetTextColor(0.992, 0.071, 0, 1)
    presetBanner:SetText(L["Active layout is a preset. Switch to or create a custom layout to save changes."])
    presetBanner:Hide()

    local disclaimerPending = false

    local applyBtn = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    applyBtn:SetSize(APPLY_WIDTH, BUTTON_HEIGHT)
    applyBtn:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -paddingX, paddingY + BUTTON_BOTTOM_MARGIN)
    applyBtn:SetText(L["Apply"])

    local cancelBtn = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    cancelBtn:SetSize(CANCEL_WIDTH, BUTTON_HEIGHT)
    cancelBtn:SetPoint("RIGHT", applyBtn, "LEFT", -BUTTONS_GAP, 0)
    cancelBtn:SetText(L["Cancel"])

    local function ResetApplyButton()
        if disclaimerPending then
            disclaimerPending = false
        end
        applyBtn:SetText(L["Apply"])
        applyBtn:SetWidth(APPLY_WIDTH)
    end

    local function CountChecked()
        local count = 0
        for _, row in ipairs(rows) do
            if row:IsShown() and row.checkbox:GetChecked() then
                count = count + 1
            end
        end
        return count
    end

    local currentIsPreset = false

    local function UpdateApplyEnabled()
        if currentIsPreset or CountChecked() == 0 then
            applyBtn:Disable()
        else
            applyBtn:Enable()
        end
    end

    local function Refresh()
        if not CDM.GetCooldownViewerEditModePolicies then return end
        ResetApplyButton()
        local data = CDM:GetCooldownViewerEditModePolicies()
        currentIsPreset = data.isPresetLayout and true or false
        presetBanner:SetShown(currentIsPreset)
        BuildRows(data.policies, UpdateApplyEnabled)
        UpdateApplyEnabled()
    end

    overlay:HookScript("OnShow", Refresh)

    local layoutEventFrame = CreateFrame("Frame", nil, overlay)
    layoutEventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    layoutEventFrame:SetScript("OnEvent", function()
        if overlay:IsShown() then
            Refresh()
        end
    end)

    applyBtn:SetScript("OnClick", function()
        if not applyBtn:IsEnabled() then return end
        if not CDM.ApplyCooldownViewerEditModeRecommendedSettings then return end

        local checkedIds = {}
        for _, row in ipairs(rows) do
            if row:IsShown() and row.checkbox:GetChecked() and row.policyId then
                checkedIds[#checkedIds + 1] = row.policyId
            end
        end

        local result = CDM:ApplyCooldownViewerEditModeRecommendedSettings(checkedIds)

        if result == "applied" then
            overlay:Hide()
            return
        end

        if result == "noop" then
            disclaimerPending = true
            applyBtn:SetText(L["All settings are correct"])
            applyBtn:SetWidth(APPLY_DISCLAIMER_WIDTH)
            applyBtn:Disable()
            C_Timer.After(2, function()
                if not disclaimerPending then return end
                disclaimerPending = false
                applyBtn:SetText(L["Apply"])
                applyBtn:SetWidth(APPLY_WIDTH)
                UpdateApplyEnabled()
            end)
        end
    end)

    cancelBtn:SetScript("OnClick", function() overlay:Hide() end)

    return overlay
end

ns.CreateEditModeOverlay = CreateEditModeOverlay
