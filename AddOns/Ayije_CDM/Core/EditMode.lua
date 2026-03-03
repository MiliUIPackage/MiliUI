local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS
local L = CDM.L

local LOCK_FRAME_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
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
    local sizes = self.Sizes or {}
    local twoLine = false

    if vName == VIEWERS.ESSENTIAL then
        local count = CountActiveItemFrames(systemFrame)
        local maxRowEss = sizes.MAX_ROW_ESS or 8

        if count == 0 or count > maxRowEss then
            twoLine = true
        else
            local sizeEssRow1 = sizes.SIZE_ESS_ROW1 or { h = 40 }
            local sizeEssRow2 = sizes.SIZE_ESS_ROW2 or sizeEssRow1
            local spacing = sizes.SPACING or 6
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
        local maxRowUtil = sizes.MAX_ROW_UTIL or 0
        if maxRowUtil > 0 and CountActiveItemFrames(systemFrame) > maxRowUtil then
            twoLine = true
        end
    end

    if twoLine then
        return L["Edit Mode locked"] .. "\n" .. L["use /cdm"]
    end
    return L["Edit Mode locked - use /cdm"]
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
    local fontOutline = CDM_C.GetBaseFontOutline()
    if fontOutline == "NONE" or fontOutline == "" then
        fontOutline = "OUTLINE"
    end

    text:SetFont(fontPath, CDM_C.GetPixelFontSize(20), fontOutline)
    text:SetTextColor(0.992, 0.071, 0, 1)

    local maxWidth = selection:GetWidth() - 12
    if maxWidth > 0 then
        text:SetWidth(maxWidth)
    end

    local vName = systemFrame:GetName()
    if vName == VIEWERS.ESSENTIAL or vName == VIEWERS.UTILITY then
        text:SetText(self:GetCooldownViewerLockMessage(systemFrame))
    else
        text:SetText(L["Edit Mode locked - use /cdm"])
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

local EDITMODE_VIEWERS = {
    VIEWERS.ESSENTIAL,
    VIEWERS.UTILITY,
    VIEWERS.BUFF,
    VIEWERS.BUFF_BAR,
}

local function ShowLockNotice()
    if not CDM.editModeCooldownViewerNoticeShown then
        print("|cffffd200Ayije_CDM:|r " .. L["Cooldown Viewer settings are managed by /cdm. Edit Mode changes are disabled to avoid taint."])
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
    selection:SetFrameStrata("MEDIUM")
    selection:SetFrameLevel(container:GetFrameLevel() + 2)

    self:SetupCooldownViewerLockTextHandlers(viewer)
    self:SetCooldownViewerLockText(viewer, false)
end

function CDM:UpdateEditModeSelectionOverlays()
    for _, vName in ipairs(EDITMODE_VIEWERS) do
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
