local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L
local CDM_C = CDM and CDM.CONST or {}
local IsSafeNumber = API.IsSafeNumber
local UI = ns.ConfigUI
local Shared = ns.GroupEditorShared or {}

local NormalizeToBase = API.NormalizeToBase
local GetDisplaySpellID = Shared.GetDisplaySpellID
local SaveAndRefresh = Shared.SaveVisualRefresh
local SaveStructuralRefresh = Shared.SaveVisualRefresh
local DestroyFrame = Shared.DestroyFrame
local CreateSlider = Shared.CreateSlider
local DOT_OVERRIDE_SPELLS = CDM_C.DOT_OVERRIDE_SPELLS
local LEFT_INSET = Shared.LEFT_INSET
local LEFT_WIDTH = Shared.LEFT_WIDTH
local SCROLL_LEFT_PAD = Shared.SCROLL_LEFT_PAD
local RIGHT_X = Shared.RIGHT_X
local ICON_SIZE = 30
local ROW_HEIGHT = 36
local GROUP_HEADER_H = 28
local ARROW_BTN_SIZE = 29
local GRID_ICON_SIZE = 36
local GRID_ICON_GAP = 4
local GRID_DISPLAY_MAX = 14
local MIN_GRID_ROWS = 2

StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_CD_GROUP"] = {
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local fn = StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_CD_GROUP"]._pendingDelete
        if fn then fn() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateCooldownGroupsPanel(subPage, page)
    local dbKey = "cooldownGroups"
    local tex = subPage:CreateTexture(nil, "ARTWORK")
    tex:SetAtlas("Options_HorizontalDivider", true)
    tex:SetPoint("TOP", subPage, "TOP", 0, 0)

    local si = GetSpecialization()
    local currentSpecID = si and GetSpecializationInfo(si) or nil
    local playerSpecID = currentSpecID

    local selectedGroupIndex = nil
    local selectedSpellID = nil
    local selectedSpellGroupIndex = nil
    local expandedGroups = {}
    local RefreshAll
    local ShowSpellSettings
    local BuildIconGrid
    local renameLastClickTime = 0
    local renameLastClickGroup = nil
    local renameActiveGroupIndex = nil
    local renameActiveEditBox = nil
    local suppressPanelRefreshUntil = 0

    local _helpers = Shared.CreateGroupEditorHelpers({
        dbKey = dbKey,
        ungroupedDbKey = "ungroupedCooldownOverrides",
        getCurrentSpecID = function() return currentSpecID end,
        setCurrentSpecID = function(v) currentSpecID = v end,
        getPlayerSpecID = function() return playerSpecID end,
        setPlayerSpecID = function(v) playerSpecID = v end,
        normalizeToBase = NormalizeToBase,
        extraCloneFields = { "maxPerRow", "chargeFontSize", "chargeColor", "chargePosition", "chargeOffsetX", "chargeOffsetY" },
    })
    local RefreshCurrentSpecID = _helpers.RefreshCurrentSpecID
    local EnsureGroups = _helpers.EnsureGroups
    local GetSpecGroups = _helpers.GetSpecGroups
    local EnsureUngroupedOverrides = _helpers.EnsureUngroupedOverrides
    local GetUngroupedOverride = _helpers.GetUngroupedOverride
    local EnsureResolvedOverrideEntry = _helpers.EnsureResolvedOverrideEntry
    local ExtractMergedOverrideEntry = _helpers.ExtractMergedOverrideEntry
    local StoreMergedOverrideEntry = _helpers.StoreMergedOverrideEntry
    local EnsureSpellOverride = _helpers.EnsureSpellOverride
    local EnsureUngroupedOverrideEntry = _helpers.EnsureUngroupedOverrideEntry
    local CreateLayoutOnlyGroupClone = _helpers.CreateLayoutOnlyGroupClone
    local CopyGroupSettingsToSpec = _helpers.CopyGroupSettingsToSpec
    local DuplicateGroup = _helpers.DuplicateGroup

    local function RefreshLeftPanelIfNeeded()
        if RefreshAll then RefreshAll() end
    end

    local function IsSpellKnown(spellID)
        if not IsSafeNumber(spellID) then return false end
        if IsPlayerSpell(spellID) then return true end
        if NormalizeToBase then
            local baseID = NormalizeToBase(spellID)
            if baseID and baseID ~= spellID and IsPlayerSpell(baseID) then return true end
        end
        return false
    end

    local function BuildCooldownActiveSet()
        local active = {}
        for _, vName in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
            local viewer = _G[vName]
            if viewer and viewer.itemFramePool then
                for frame in viewer.itemFramePool:EnumerateActive() do
                    local id = frame.GetSpellID and frame:GetSpellID()
                    if IsSafeNumber(id) then active[id] = true end
                end
            end
        end
        return active
    end

    local function ExpandGroupedSetWithLinkedSpells(groupedSet)
        if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet
            and C_CooldownViewer.GetCooldownViewerCooldownInfo
            and Enum.CooldownViewerCategory) then
            return
        end
        for _, cat in ipairs({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }) do
            local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
            if cooldownIDs then
                for _, cdID in ipairs(cooldownIDs) do
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    if info and info.linkedSpellIDs then
                        local isGrouped = groupedSet[info.spellID]
                            or (info.overrideSpellID and groupedSet[info.overrideSpellID])
                        if not isGrouped then
                            for _, lid in ipairs(info.linkedSpellIDs) do
                                if groupedSet[lid] then isGrouped = true; break end
                            end
                        end
                        if isGrouped then
                            groupedSet[info.spellID] = true
                            if info.overrideSpellID then groupedSet[info.overrideSpellID] = true end
                            for _, lid in ipairs(info.linkedSpellIDs) do
                                groupedSet[lid] = true
                            end
                        end
                    end
                end
            end
        end
    end

    local QueueLeftPanelRefresh = Shared.CreateQueueLeftPanelRefresh(subPage, function() return RefreshAll end)

    local RegisterDropTarget, ClearDropTargets, StartDrag, EndDrag, CancelDrag
    do
        local dragDrop = Shared.CreateDragDropController({
            onDrop = function(spellID, sourceGroup, targetGroupIndex, hitDropTarget)
                if not spellID or not currentSpecID then return end
                if not hitDropTarget then return end
                if sourceGroup == targetGroupIndex then return end

                local groups = EnsureGroups()
                if not groups then return end

                local srcOvData = nil
                if sourceGroup then
                    local srcGroup = groups[sourceGroup]
                    if srcGroup and srcGroup.spells then Shared.RemoveSpellFromGroupList(srcGroup.spells, spellID) end
                    if srcGroup and srcGroup.spellOverrides then
                        srcOvData = ExtractMergedOverrideEntry(srcGroup.spellOverrides, spellID)
                    end
                else
                    local specOv = EnsureUngroupedOverrides()
                    if specOv then
                        srcOvData = ExtractMergedOverrideEntry(specOv, spellID)
                    end
                end

                if targetGroupIndex then
                    local tgtGroup = groups[targetGroupIndex]
                    if tgtGroup then
                        if not tgtGroup.spells then tgtGroup.spells = {} end
                        local storedSpellID = Shared.AddSpellToGroupList(tgtGroup.spells, spellID) or spellID
                        if srcOvData then
                            if not tgtGroup.spellOverrides then tgtGroup.spellOverrides = {} end
                            StoreMergedOverrideEntry(tgtGroup.spellOverrides, storedSpellID, srcOvData)
                        end
                        spellID = storedSpellID
                    end
                elseif srcOvData then
                    local specOv = EnsureUngroupedOverrides()
                    if specOv then StoreMergedOverrideEntry(specOv, spellID, srcOvData) end
                end

                suppressPanelRefreshUntil = GetTime() + 0.15
                API:MarkSpecDataDirty()
                API:RefreshSpecData()
                SaveStructuralRefresh()
                if spellID == selectedSpellID then
                    selectedSpellGroupIndex = targetGroupIndex
                    ShowSpellSettings(spellID, targetGroupIndex)
                end
                RefreshLeftPanelIfNeeded()
            end,
        })
        RegisterDropTarget = dragDrop.RegisterDropTarget
        ClearDropTargets = dragDrop.ClearDropTargets
        StartDrag = dragDrop.StartDrag
        EndDrag = dragDrop.EndDrag
        CancelDrag = dragDrop.CancelDrag
    end

    local minGridHeight = MIN_GRID_ROWS * (GRID_ICON_SIZE + GRID_ICON_GAP) - GRID_ICON_GAP + 8

    local iconGridFrame = CreateFrame("Frame", nil, subPage)
    iconGridFrame:SetPoint("TOPLEFT", LEFT_INSET, -16)
    iconGridFrame:SetPoint("TOPRIGHT", -200, -16)
    iconGridFrame:SetHeight(minGridHeight)

    iconGridFrame.highlight = iconGridFrame:CreateTexture(nil, "BACKGROUND")
    iconGridFrame.highlight:SetAllPoints()
    iconGridFrame.highlight:SetColorTexture(0.2, 0.6, 0.2, 0.15)
    iconGridFrame.highlight:Hide()

    local gridEmptyText = iconGridFrame:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    gridEmptyText:SetPoint("LEFT", 4, 0)
    gridEmptyText:Hide()

    local gridIcons = {}
    local gridIconsActive = 0

    local function AcquireGridIcon()
        gridIconsActive = gridIconsActive + 1
        local frame = gridIcons[gridIconsActive]
        if not frame then
            frame = CreateFrame("Frame", nil, iconGridFrame)
            frame:SetSize(GRID_ICON_SIZE, GRID_ICON_SIZE)
            local icon = frame:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            frame.icon = icon
            CDM_C.ApplyIconTexCoord(icon, CDM_C.GetEffectiveZoomAmount())
            local overlay = CreateFrame("Button", nil, frame)
            overlay:SetAllPoints()
            overlay:SetFrameLevel(frame:GetFrameLevel() + 2)
            overlay:RegisterForClicks("LeftButtonUp")
            overlay:RegisterForDrag("LeftButton")
            frame.overlay = overlay
            gridIcons[gridIconsActive] = frame
        end
        frame:Show()
        return frame
    end

    local function ReleaseAllGridIcons()
        for i = 1, gridIconsActive do
            gridIcons[i]:Hide()
        end
        gridIconsActive = 0
    end

    local buttonRow = CreateFrame("Frame", nil, subPage)
    buttonRow:SetPoint("TOPLEFT", iconGridFrame, "BOTTOMLEFT", 0, -6)
    buttonRow:SetPoint("TOPRIGHT", subPage, "TOPRIGHT", -10, 0)
    buttonRow:SetHeight(26)

    local function UpdateGridVisibility()
        buttonRow:ClearAllPoints()
        if currentSpecID == playerSpecID then
            iconGridFrame:Show()
            buttonRow:SetPoint("TOPLEFT", iconGridFrame, "BOTTOMLEFT", 0, -6)
            buttonRow:SetPoint("TOPRIGHT", subPage, "TOPRIGHT", -10, 0)
        else
            iconGridFrame:Hide()
            buttonRow:SetPoint("TOPLEFT", subPage, "TOPLEFT", LEFT_INSET, -16)
            buttonRow:SetPoint("TOPRIGHT", subPage, "TOPRIGHT", -10, 0)
        end
    end

    local leftScroll = CreateFrame("ScrollFrame", "AyijeCDM_CDGroups_LeftScroll", subPage, "ScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", buttonRow, "BOTTOMLEFT", -SCROLL_LEFT_PAD, -4)
    leftScroll:SetPoint("BOTTOMLEFT", subPage, "BOTTOMLEFT", LEFT_INSET - SCROLL_LEFT_PAD, 20)
    leftScroll:SetWidth(LEFT_WIDTH + SCROLL_LEFT_PAD)

    local leftChild = CreateFrame("Frame", nil, leftScroll)
    leftChild:SetSize(LEFT_WIDTH + SCROLL_LEFT_PAD, 1200)
    leftScroll:SetScrollChild(leftChild)

    local rightPanel = CreateFrame("Frame", nil, subPage)
    rightPanel:SetPoint("TOPLEFT", buttonRow, "BOTTOMLEFT", RIGHT_X - LEFT_INSET, -4)
    rightPanel:SetPoint("BOTTOMRIGHT", -10, 20)

    local rightPlaceholder = rightPanel:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    rightPlaceholder:SetPoint("TOP", 0, -20)
    rightPlaceholder:SetText(L["Select a group or spell to edit settings"])
    UI.SetTextMuted(rightPlaceholder)

    local RegisterRightPanelDropdown, CreateRightScrollContent, ClearRightPanel
    do
        local rpm = Shared.CreateRightPanelManager(rightPanel, rightPlaceholder, DestroyFrame)
        RegisterRightPanelDropdown = rpm.RegisterDropdown
        CreateRightScrollContent = rpm.CreateScrollContent
        ClearRightPanel = rpm.Clear
    end

    local function ShowGroupSettings(groupIndex)
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then ClearRightPanel(); return end
        local _, rc = CreateRightScrollContent(700)
        Shared.RenderGroupSettingsPanel({
            rc = rc, gd = groups[groupIndex], groupIndex = groupIndex,
            registerDropdown = RegisterRightPanelDropdown,
            saveAndRefresh = SaveAndRefresh, createSlider = CreateSlider, L = L,
            postSizeSection = function(parent, yOff)
                local s = CreateSlider(parent, L["Max Per Row"] or "Max Per Row", 0, 20,
                    groups[groupIndex].maxPerRow or 0,
                    function(v) groups[groupIndex].maxPerRow = v > 0 and v or nil; SaveAndRefresh() end)
                s:SetPoint("TOPLEFT", 0, yOff)
                return yOff - 50
            end,
            textFields = {
                sizeKey = "chargeFontSize", colorKey = "chargeColor",
                posKey = "chargePosition", xKey = "chargeOffsetX", yKey = "chargeOffsetY",
                sizeDefault = 15, posDefault = "BOTTOMRIGHT",
            },
            anchorTargets = {
                { label = L["Screen"] or "Screen", value = "screen" },
                { label = L["Player Frame"] or "Player Frame", value = "playerFrame" },
                { label = L["Essential Viewer"] or "Essential Viewer", value = "essential" },
                { label = L["Utility Viewer"] or "Utility Viewer", value = "utility" },
                { label = L["Buff Viewer"] or "Buff Viewer", value = "buff" },
            },
            anchorRelLabels = {
                playerFrame = L["Player Frame Point"] or "Player Frame Point",
                buff = L["Buff Viewer Point"] or "Buff Viewer Point",
                utility = L["Utility Viewer Point"] or "Utility Viewer Point",
            },
        })
    end

    ShowSpellSettings = function(spellID, groupIndex)
        if not spellID then ClearRightPanel(); return end
        local _, rc = CreateRightScrollContent(400)
        local yOff = 0

        local displayID = GetDisplaySpellID(spellID)
        local name = C_Spell.GetSpellName(displayID) or ("Spell " .. spellID)
        local header = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        header:SetPoint("TOPLEFT", 0, yOff)
        header:SetText(name)
        header:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 40

        local iconContainer = CreateFrame("Frame", nil, rc)
        iconContainer:SetSize(40, 40)
        iconContainer:SetPoint("TOPLEFT", 0, yOff)
        local iconTex = iconContainer:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        local tex = C_Spell.GetSpellTexture(displayID)
        if tex then iconTex:SetTexture(tex) end
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())
        if CDM.BORDER and CDM.BORDER.CreateBorder then
            CDM.BORDER:CreateBorder(iconContainer)
            if CDM.BORDER.activeBorders then CDM.BORDER.activeBorders[iconContainer] = nil end
        end
        yOff = yOff - 54

        do
            local auraOv
            if groupIndex then
                local grps = GetSpecGroups()
                auraOv = Shared.GetMergedOverrideEntry(grps and grps[groupIndex] and grps[groupIndex].spellOverrides, spellID)
            else
                auraOv = GetUngroupedOverride(spellID)
            end

            local isDotDefault = DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[spellID]
            local showAura
            if auraOv and auraOv.showAuraOverlay ~= nil then
                showAura = auraOv.showAuraOverlay
            else
                showAura = isDotDefault or false
            end

            local auraCheckbox = UI.CreateModernCheckbox(
                rc,
                L["Show Aura Overlay"] or "Show Aura Overlay",
                showAura,
                function(checked)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local ov
                    if groupIndex then
                        ov = EnsureSpellOverride(groupIndex, spellID)
                    else
                        ov = EnsureUngroupedOverrideEntry(spellID)
                    end
                    if not ov then return end
                    if checked then
                        ov.showAuraOverlay = isDotDefault and nil or true
                    else
                        ov.showAuraOverlay = false
                    end
                    SaveAndRefresh()
                    ShowSpellSettings(spellID, groupIndex)
                end
            )
            auraCheckbox:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 36

            if showAura then
                if not isDotDefault then
                    local desatValue = auraOv and auraOv.auraDesaturateInactive or false
                    local desatCheckbox = UI.CreateModernCheckbox(
                        rc,
                        L["Desaturate when inactive"] or "Desaturate when inactive",
                        desatValue,
                        function(checked)
                            suppressPanelRefreshUntil = GetTime() + 0.15
                            local ov
                            if groupIndex then
                                ov = EnsureSpellOverride(groupIndex, spellID)
                            else
                                ov = EnsureUngroupedOverrideEntry(spellID)
                            end
                            if not ov then return end
                            ov.auraDesaturateInactive = checked or nil
                            SaveAndRefresh()
                        end
                    )
                    desatCheckbox:SetPoint("TOPLEFT", 20, yOff)
                    yOff = yOff - 30
                end

                local auraGlowEnabled = auraOv and auraOv.auraGlowEnabled or false
                local auraGlowCheckbox = UI.CreateModernCheckbox(
                    rc,
                    L["Aura Glow"] or "Aura Glow",
                    auraGlowEnabled,
                    function(checked)
                        suppressPanelRefreshUntil = GetTime() + 0.15
                        local ov
                        if groupIndex then
                            ov = EnsureSpellOverride(groupIndex, spellID)
                        else
                            ov = EnsureUngroupedOverrideEntry(spellID)
                        end
                        if not ov then return end
                        ov.auraGlowEnabled = checked or nil
                        SaveAndRefresh()
                    end
                )
                auraGlowCheckbox:SetPoint("TOPLEFT", 20, yOff)
                yOff = yOff - 30

                local agcLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                agcLabel:SetText(L["Glow Color:"] or "Glow Color:")
                agcLabel:SetPoint("TOPLEFT", 20, yOff)
                local agcInit = (auraOv and auraOv.auraGlowColor) or { r = 1, g = 1, b = 1 }
                local agcPicker = UI.CreateSimpleColorPicker(rc, agcInit, function(r, g, b)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local ov
                    if groupIndex then
                        ov = EnsureSpellOverride(groupIndex, spellID)
                    else
                        ov = EnsureUngroupedOverrideEntry(spellID)
                    end
                    if not ov then return end
                    ov.auraGlowColor = { r = r, g = g, b = b }
                    SaveAndRefresh()
                end)
                agcPicker:SetPoint("LEFT", agcLabel, "RIGHT", 6, 0)
                yOff = yOff - 30

                local auraBorderEnabled = auraOv and auraOv.auraBorderEnabled or false
                local auraBorderCheckbox = UI.CreateModernCheckbox(
                    rc,
                    L["Aura Border Color"] or "Aura Border Color",
                    auraBorderEnabled,
                    function(checked)
                        suppressPanelRefreshUntil = GetTime() + 0.15
                        local ov
                        if groupIndex then
                            ov = EnsureSpellOverride(groupIndex, spellID)
                        else
                            ov = EnsureUngroupedOverrideEntry(spellID)
                        end
                        if not ov then return end
                        ov.auraBorderEnabled = checked or nil
                        SaveAndRefresh()
                    end
                )
                auraBorderCheckbox:SetPoint("TOPLEFT", 20, yOff)
                yOff = yOff - 30

                local abcLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                abcLabel:SetText(L["Border Color:"] or "Border Color:")
                abcLabel:SetPoint("TOPLEFT", 20, yOff)
                local abcInit = (auraOv and auraOv.auraBorderColor) or { r = 1, g = 1, b = 1 }
                local abcPicker = UI.CreateSimpleColorPicker(rc, abcInit, function(r, g, b)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local ov
                    if groupIndex then
                        ov = EnsureSpellOverride(groupIndex, spellID)
                    else
                        ov = EnsureUngroupedOverrideEntry(spellID)
                    end
                    if not ov then return end
                    ov.auraBorderColor = { r = r, g = g, b = b, a = 1 }
                    SaveAndRefresh()
                end)
                abcPicker:SetPoint("LEFT", abcLabel, "RIGHT", 6, 0)
                yOff = yOff - 30
            end

            local readyGlowEnabled = auraOv and auraOv.readyGlowEnabled or false
            local readyGlowCheckbox = UI.CreateModernCheckbox(
                rc,
                L["Glow When Ready"] or "Glow When Ready",
                readyGlowEnabled,
                function(checked)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local ov
                    if groupIndex then
                        ov = EnsureSpellOverride(groupIndex, spellID)
                    else
                        ov = EnsureUngroupedOverrideEntry(spellID)
                    end
                    if not ov then return end
                    ov.readyGlowEnabled = checked or nil
                    SaveAndRefresh()
                    ShowSpellSettings(spellID, groupIndex)
                end
            )
            readyGlowCheckbox:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 36

            if readyGlowEnabled then
                local rgcLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                rgcLabel:SetText(L["Glow Color:"] or "Glow Color:")
                rgcLabel:SetPoint("TOPLEFT", 20, yOff)
                local rgcInit = (auraOv and auraOv.readyGlowColor) or { r = 1, g = 1, b = 1 }
                local rgcPicker = UI.CreateSimpleColorPicker(rc, rgcInit, function(r, g, b)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local ov
                    if groupIndex then
                        ov = EnsureSpellOverride(groupIndex, spellID)
                    else
                        ov = EnsureUngroupedOverrideEntry(spellID)
                    end
                    if not ov then return end
                    ov.readyGlowColor = { r = r, g = g, b = b }
                    SaveAndRefresh()
                end)
                rgcPicker:SetPoint("LEFT", rgcLabel, "RIGHT", 6, 0)
                yOff = yOff - 30
            end
        end

        if groupIndex then
            local groups = GetSpecGroups()
            local gd = groups and groups[groupIndex]
            if gd then
                local existingOv = Shared.GetMergedOverrideEntry(gd.spellOverrides, spellID)
                local useTextOv = existingOv and existingOv.textOverride

                yOff = yOff - 10
                local ovHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
                ovHeader:SetPoint("TOPLEFT", 0, yOff)
                ovHeader:SetText(L["Text Overrides"] or "Text Overrides")
                ovHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
                yOff = yOff - 34

                local textOverrideCheckbox = UI.CreateModernCheckbox(
                    rc,
                    L["Override Text Settings"] or "Override Text Settings",
                    useTextOv or false,
                    function(checked)
                        suppressPanelRefreshUntil = GetTime() + 0.15
                        local ov = EnsureSpellOverride(groupIndex, spellID)
                        if not ov then return end
                        ov.textOverride = checked or nil
                        SaveAndRefresh()
                        ShowSpellSettings(spellID, groupIndex)
                    end
                )
                textOverrideCheckbox:SetPoint("TOPLEFT", 0, yOff)
                yOff = yOff - 36

                if useTextOv then
                    local ov = existingOv

                    local ovCdFS = CreateSlider(rc, L["Cooldown Size"] or "Cooldown Size", 6, 32,
                        ov.cooldownFontSize or gd.cooldownFontSize or 12,
                        function(v)
                            local o = EnsureSpellOverride(groupIndex, spellID)
                            if o then o.cooldownFontSize = v end; SaveAndRefresh()
                        end)
                    ovCdFS:SetPoint("TOPLEFT", 0, yOff)
                    yOff = yOff - 50

                    local ovCdColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                    ovCdColorLabel:SetText(L["Cooldown Color"] or "Cooldown Color")
                    ovCdColorLabel:SetPoint("TOPLEFT", 0, yOff)
                    local ovCdColorInit = ov.cooldownColor or gd.cooldownColor or { r = 1, g = 1, b = 1 }
                    local ovCdColorPicker = UI.CreateSimpleColorPicker(rc, ovCdColorInit, function(r, g, b)
                        local o = EnsureSpellOverride(groupIndex, spellID)
                        if o then o.cooldownColor = { r = r, g = g, b = b, a = 1 } end; SaveAndRefresh()
                    end)
                    ovCdColorPicker:SetPoint("LEFT", ovCdColorLabel, "RIGHT", 6, 0)
                    yOff = yOff - 30

                    local ovChargeFS = CreateSlider(rc, L["Charge Size"] or "Charge Size", 6, 32,
                        ov.chargeFontSize or gd.chargeFontSize or 15,
                        function(v)
                            local o = EnsureSpellOverride(groupIndex, spellID)
                            if o then o.chargeFontSize = v end; SaveAndRefresh()
                        end)
                    ovChargeFS:SetPoint("TOPLEFT", 0, yOff)
                    yOff = yOff - 50

                    local ovChargeColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                    ovChargeColorLabel:SetText(L["Charge Color"] or "Charge Color")
                    ovChargeColorLabel:SetPoint("TOPLEFT", 0, yOff)
                    local ovChargeColorInit = ov.chargeColor or gd.chargeColor or { r = 1, g = 1, b = 1 }
                    local ovChargeColorPicker = UI.CreateSimpleColorPicker(rc, ovChargeColorInit, function(r, g, b)
                        local o = EnsureSpellOverride(groupIndex, spellID)
                        if o then o.chargeColor = { r = r, g = g, b = b, a = 1 } end; SaveAndRefresh()
                    end)
                    ovChargeColorPicker:SetPoint("LEFT", ovChargeColorLabel, "RIGHT", 6, 0)
                    yOff = yOff - 30

                    local ovChargePosLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                    ovChargePosLabel:SetText(L["Position"])
                    ovChargePosLabel:SetPoint("TOPLEFT", 0, yOff)
                    yOff = yOff - 22
                    local ovChargePosDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
                    ovChargePosDropdown:SetWidth(180)
                    ovChargePosDropdown:SetPoint("TOPLEFT", 0, yOff)
                    ovChargePosDropdown:SetDefaultText(ov.chargePosition or gd.chargePosition or "BOTTOMRIGHT")
                    UI.SetupPositionDropdown(ovChargePosDropdown,
                        function() return ov.chargePosition or gd.chargePosition or "BOTTOMRIGHT" end,
                        function(val)
                            local o = EnsureSpellOverride(groupIndex, spellID)
                            if o then o.chargePosition = val end; SaveAndRefresh()
                        end
                    )
                    yOff = yOff - 40

                    local ovChargeXSlider = CreateSlider(rc, L["X Offset"], -20, 20,
                        ov.chargeOffsetX or gd.chargeOffsetX or 0,
                        function(v)
                            local o = EnsureSpellOverride(groupIndex, spellID)
                            if o then o.chargeOffsetX = v end; SaveAndRefresh()
                        end)
                    ovChargeXSlider:SetPoint("TOPLEFT", 0, yOff)
                    yOff = yOff - 50

                    local ovChargeYSlider = CreateSlider(rc, L["Y Offset"], -20, 20,
                        ov.chargeOffsetY or gd.chargeOffsetY or 0,
                        function(v)
                            local o = EnsureSpellOverride(groupIndex, spellID)
                            if o then o.chargeOffsetY = v end; SaveAndRefresh()
                        end)
                    ovChargeYSlider:SetPoint("TOPLEFT", 0, yOff)
                    yOff = yOff - 50
                end
            end
        else
            local existingOv = GetUngroupedOverride(spellID)
            local useTextOv = existingOv and existingOv.textOverride

            yOff = yOff - 10
            local ovHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
            ovHeader:SetPoint("TOPLEFT", 0, yOff)
            ovHeader:SetText(L["Text Overrides"] or "Text Overrides")
            ovHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
            yOff = yOff - 34

            local textOverrideCheckbox = UI.CreateModernCheckbox(
                rc,
                L["Override Text Settings"] or "Override Text Settings",
                useTextOv or false,
                function(checked)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local ov = EnsureUngroupedOverrideEntry(spellID)
                    if not ov then return end
                    ov.textOverride = checked or nil
                    SaveAndRefresh()
                    ShowSpellSettings(spellID, nil)
                end
            )
            textOverrideCheckbox:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 36

            if useTextOv then
                local ov = existingOv
                local db = CDM.db

                local ovCdFS = CreateSlider(rc, L["Cooldown Size"] or "Cooldown Size", 6, 32,
                    ov.cooldownFontSize or (db and db.cooldownFontSize or 15),
                    function(v)
                        local o = EnsureUngroupedOverrideEntry(spellID)
                        if o then o.cooldownFontSize = v end; SaveAndRefresh()
                    end)
                ovCdFS:SetPoint("TOPLEFT", 0, yOff)
                yOff = yOff - 50

                local ovCdColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                ovCdColorLabel:SetText(L["Cooldown Color"] or "Cooldown Color")
                ovCdColorLabel:SetPoint("TOPLEFT", 0, yOff)
                local ovCdColorInit = ov.cooldownColor or (db and db.cooldownColor) or { r = 1, g = 1, b = 1 }
                local ovCdColorPicker = UI.CreateSimpleColorPicker(rc, ovCdColorInit, function(r, g, b)
                    local o = EnsureUngroupedOverrideEntry(spellID)
                    if o then o.cooldownColor = { r = r, g = g, b = b, a = 1 } end; SaveAndRefresh()
                end)
                ovCdColorPicker:SetPoint("LEFT", ovCdColorLabel, "RIGHT", 6, 0)
                yOff = yOff - 30

                local ovChargeFS = CreateSlider(rc, L["Charge Size"] or "Charge Size", 6, 32,
                    ov.chargeFontSize or (db and db.chargeFontSize or 15),
                    function(v)
                        local o = EnsureUngroupedOverrideEntry(spellID)
                        if o then o.chargeFontSize = v end; SaveAndRefresh()
                    end)
                ovChargeFS:SetPoint("TOPLEFT", 0, yOff)
                yOff = yOff - 50

                local ovChargeColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                ovChargeColorLabel:SetText(L["Charge Color"] or "Charge Color")
                ovChargeColorLabel:SetPoint("TOPLEFT", 0, yOff)
                local ovChargeColorInit = ov.chargeColor or (db and db.chargeColor) or { r = 1, g = 1, b = 1 }
                local ovChargeColorPicker = UI.CreateSimpleColorPicker(rc, ovChargeColorInit, function(r, g, b)
                    local o = EnsureUngroupedOverrideEntry(spellID)
                    if o then o.chargeColor = { r = r, g = g, b = b, a = 1 } end; SaveAndRefresh()
                end)
                ovChargeColorPicker:SetPoint("LEFT", ovChargeColorLabel, "RIGHT", 6, 0)
                yOff = yOff - 30

                local ovChargePosLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                ovChargePosLabel:SetText(L["Position"])
                ovChargePosLabel:SetPoint("TOPLEFT", 0, yOff)
                yOff = yOff - 22
                local ovChargePosDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
                ovChargePosDropdown:SetWidth(180)
                ovChargePosDropdown:SetPoint("TOPLEFT", 0, yOff)
                local curChargePos = ov.chargePosition or (db and db.chargePosition or "BOTTOMRIGHT")
                ovChargePosDropdown:SetDefaultText(curChargePos)
                UI.SetupPositionDropdown(ovChargePosDropdown,
                    function() return ov.chargePosition or (CDM.db and CDM.db.chargePosition or "BOTTOMRIGHT") end,
                    function(val)
                        local o = EnsureUngroupedOverrideEntry(spellID)
                        if o then o.chargePosition = val end; SaveAndRefresh()
                    end
                )
                yOff = yOff - 40

                local ovChargeXSlider = CreateSlider(rc, L["X Offset"], -20, 20,
                    ov.chargeOffsetX or (db and db.chargeOffsetX or 0),
                    function(v)
                        local o = EnsureUngroupedOverrideEntry(spellID)
                        if o then o.chargeOffsetX = v end; SaveAndRefresh()
                    end)
                ovChargeXSlider:SetPoint("TOPLEFT", 0, yOff)
                yOff = yOff - 50

                local ovChargeYSlider = CreateSlider(rc, L["Y Offset"], -20, 20,
                    ov.chargeOffsetY or (db and db.chargeOffsetY or 0),
                    function(v)
                        local o = EnsureUngroupedOverrideEntry(spellID)
                        if o then o.chargeOffsetY = v end; SaveAndRefresh()
                    end)
                ovChargeYSlider:SetPoint("TOPLEFT", 0, yOff)
                yOff = yOff - 50
            end
        end

        rc:SetHeight(math.abs(yOff) + 20)
    end

    local addIconBtnRef = nil
    local ShowSpellPickerPanel

    local headerPool, groupContainerPool, emptyRowPool, spellRowPool =
        Shared.CreateGroupEditorPools(leftChild, {
            highlightAlpha = 0.15,
            resetBorder = function(border)
                local cfgColor = CDM_C.GetConfigValue("borderColor", { r = 0, g = 0, b = 0, a = 1 })
                border:SetBackdropBorderColor(cfgColor.r, cfgColor.g, cfgColor.b, cfgColor.a or 1)
            end,
        })

    local function GetViewerSpellListForSpec(specID)
        local seen, list = {}, {}
        if specID == playerSpecID then
            for _, cat in ipairs({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }) do
                local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
                if ids then
                    for _, id in ipairs(ids) do
                        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
                        if info then
                            local sid = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
                            if sid and not seen[sid] then
                                seen[sid] = true
                                list[#list + 1] = sid
                            end
                        end
                    end
                end
            end
            return list
        end

        for _, accessor in ipairs({ "GetSpecEssentialCache", "GetSpecUtilityCache" }) do
            local cache = API[accessor] and API[accessor](API, specID)
            if cache then
                for _, entry in ipairs(cache) do
                    local sid = entry.spellID
                    if sid and not seen[sid] then
                        seen[sid] = true
                        list[#list + 1] = sid
                    end
                end
            end
        end
        return list
    end

    local function GetUntrackedViewerSpellListForCurrentSpec()
        local activeSet = BuildCooldownActiveSet()
        local seen, list = {}, {}
        for _, cat in ipairs({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }) do
            local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
            if ids then
                for _, id in ipairs(ids) do
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
                    if info then
                        local sid = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
                        if sid and not seen[sid] and not activeSet[sid] then
                            seen[sid] = true
                            list[#list + 1] = sid
                        end
                    end
                end
            end
        end
        return list
    end

    local function HasOtherSpecCooldownPickerCache(specID)
        if specID == playerSpecID then return true end
        local essCache = API.GetSpecEssentialCache and API:GetSpecEssentialCache(specID)
        local utilCache = API.GetSpecUtilityCache and API:GetSpecUtilityCache(specID)
        return essCache ~= nil or utilCache ~= nil
    end

    local function GetAvailableSpellsForPicker(specID)
        local allSpells = (specID == playerSpecID)
            and GetUntrackedViewerSpellListForCurrentSpec()
            or GetViewerSpellListForSpec(specID)
        local assigned = {}
        local groups = CDM.db[dbKey] and CDM.db[dbKey][specID]
        if groups then
            for _, group in ipairs(groups) do
                for _, sid in ipairs(group.spells or {}) do
                    Shared.MarkEquivalentSpellIDs(assigned, sid)
                end
            end
        end
        ExpandGroupedSetWithLinkedSpells(assigned)
        local seen = {}
        local result = {}
        for _, spellID in ipairs(allSpells) do
            if not Shared.HasEquivalentSpellID(assigned, spellID)
                and not seen[spellID]
            then
                seen[spellID] = true
                local pickerDisplayID = GetDisplaySpellID(spellID)
                local spellName = C_Spell.GetSpellName(pickerDisplayID) or ("Spell " .. spellID)
                local icon = C_Spell.GetSpellTexture(pickerDisplayID)
                local isKnown = IsPlayerSpell(spellID)
                result[#result + 1] = { spellID = spellID, name = spellName, icon = icon, isKnown = isKnown }
            end
        end
        table.sort(result, function(a, b) return a.name < b.name end)
        return result
    end

    local function GetUngroupedSpellsFromViewers()
        local groupedSet = {}
        local specGroups = GetSpecGroups()
        if type(specGroups) == "table" then
            for _, groupData in ipairs(specGroups) do
                if type(groupData) == "table" and type(groupData.spells) == "table" then
                    for _, groupedSpellID in ipairs(groupData.spells) do
                        Shared.MarkEquivalentSpellIDs(groupedSet, groupedSpellID)
                    end
                end
            end
        end
        ExpandGroupedSetWithLinkedSpells(groupedSet)

        local seen = {}
        local icons = {}
        local viewerOffset = 0
        for _, vName in ipairs({ CDM_C.VIEWERS.ESSENTIAL, CDM_C.VIEWERS.UTILITY }) do
            local viewer = _G[vName]
            if viewer and viewer.itemFramePool then
                for frame in viewer.itemFramePool:EnumerateActive() do
                    if frame:IsShown() or frame.cooldownInfo then
                        local displayID = API.GetPreferredBuffGroupSpellID and API:GetPreferredBuffGroupSpellID(frame)
                        if not IsSafeNumber(displayID) and API.GetBaseSpellID then
                            displayID = API:GetBaseSpellID(frame)
                        end
                        if IsSafeNumber(displayID)
                            and not Shared.HasEquivalentSpellID(groupedSet, displayID)
                            and not seen[displayID]
                        then
                            seen[displayID] = true
                            local li = frame.layoutIndex
                            local safeLayoutIndex = IsSafeNumber(li) and li or 0
                            icons[#icons + 1] = { spellID = displayID, layoutIndex = safeLayoutIndex, viewerOrder = viewerOffset }
                        end
                    end
                end
            end
            viewerOffset = viewerOffset + 10000
        end
        table.sort(icons, function(a, b)
            if a.viewerOrder ~= b.viewerOrder then return a.viewerOrder < b.viewerOrder end
            if a.layoutIndex ~= b.layoutIndex then return a.layoutIndex < b.layoutIndex end
            return a.spellID < b.spellID
        end)
        local result = {}
        for _, data in ipairs(icons) do result[#result + 1] = data.spellID end
        return result
    end

    ShowSpellPickerPanel = function(groupIndex)
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then return end
        local gd = groups[groupIndex]
        local spells = GetAvailableSpellsForPicker(currentSpecID)
        Shared.RenderSpellPicker({
            createRightScrollContent = CreateRightScrollContent,
            headerText = (L["Add Spell to:"] or "Add Spell to:") .. " " .. (gd.name or "Group"),
            headerColor = CDM_C.GOLD,
            spells = spells,
            currentSpecID = currentSpecID,
            playerSpecID = playerSpecID,
            isCacheMissing = currentSpecID ~= playerSpecID and not HasOtherSpecCooldownPickerCache(currentSpecID),
            cacheMissingText = string.format(L["Log %s to build spell list"] or "Log %s to build spell list", select(2, GetSpecializationInfoByID(currentSpecID)) or "this spec"),
            emptyText = currentSpecID == playerSpecID
                and (L["No untracked cooldown icons available for this spec"] or "No untracked cooldown icons available for this spec")
                or (L["All available icons are assigned to groups"] or "All available icons are assigned to groups"),
            onSelect = function(sid)
                local currentGroups = EnsureGroups()
                if not currentGroups or not currentGroups[groupIndex] then return end
                if not currentGroups[groupIndex].spells then currentGroups[groupIndex].spells = {} end
                Shared.AddSpellToGroupList(currentGroups[groupIndex].spells, sid)
                local specOv = EnsureUngroupedOverrides()
                if specOv then
                    local ovData = ExtractMergedOverrideEntry(specOv, sid)
                    if ovData then
                        if not currentGroups[groupIndex].spellOverrides then
                            currentGroups[groupIndex].spellOverrides = {}
                        end
                        StoreMergedOverrideEntry(currentGroups[groupIndex].spellOverrides, sid, ovData)
                    end
                end
                API:MarkSpecDataDirty()
                API:RefreshSpecData()
                SaveStructuralRefresh(); RefreshLeftPanelIfNeeded()
                ShowSpellPickerPanel(groupIndex)
            end,
            onDone = function()
                ShowGroupSettings(groupIndex)
            end,
        })
    end

    local function AcquireEmptyRow(parent, text)
        return Shared.AcquireEmptyRow(emptyRowPool, parent, text)
    end

    local function ConfigureSpellRow(widget, parent, spellID, sourceGroup, y, isActive, spellIndex, spellCount)
        local row = widget.root
        row:SetParent(parent)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, y)

        local displayID = GetDisplaySpellID(spellID)
        local tex = C_Spell.GetSpellTexture(displayID)
        if tex then widget.iconTex:SetTexture(tex) end
        CDM_C.ApplyIconTexCoord(widget.iconTex, CDM_C.GetEffectiveZoomAmount())

        local cfgColor = CDM_C.GetConfigValue("borderColor", { r = 0, g = 0, b = 0, a = 1 })
        if widget.iconContainer.border then
            widget.iconContainer.border:SetBackdropBorderColor(cfgColor.r, cfgColor.g, cfgColor.b, cfgColor.a or 1)
        end

        if isActive == false then
            widget.iconTex:SetDesaturated(true)
            widget.iconTex:SetAlpha(0.5)
            if widget.iconContainer.border then
                widget.iconContainer.border:SetAlpha(0.5)
                widget.iconContainer.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            end
        else
            widget.iconTex:SetDesaturated(false)
            widget.iconTex:SetAlpha(1)
            if widget.iconContainer.border then widget.iconContainer.border:SetAlpha(1) end
        end

        widget.removeBtn:Hide()
        widget.removeBtn:SetScript("OnClick", nil)
        if sourceGroup then
            widget.removeBtn:Show()
            widget.removeBtn:SetScript("OnClick", function()
                local groups = GetSpecGroups()
                if not groups or not groups[sourceGroup] then return end
                local gd = groups[sourceGroup]
                if gd.spells then Shared.RemoveSpellFromGroupList(gd.spells, spellID) end
                if gd.spellOverrides then
                    local ovData = ExtractMergedOverrideEntry(gd.spellOverrides, spellID)
                    if ovData then
                        local specOv = EnsureUngroupedOverrides()
                        if specOv then StoreMergedOverrideEntry(specOv, spellID, ovData) end
                    end
                end
                if selectedSpellID == spellID then
                    selectedSpellID = nil
                    selectedSpellGroupIndex = nil
                    ClearRightPanel()
                end
                SaveStructuralRefresh(); RefreshLeftPanelIfNeeded()
            end)
        end

        widget.nameText:ClearAllPoints()
        widget.nameText:SetPoint("LEFT", widget.iconContainer, "RIGHT", 6, 0)
        widget.nameText:SetPoint("RIGHT", widget.removeBtn:IsShown() and widget.removeBtn or row, widget.removeBtn:IsShown() and "LEFT" or "RIGHT", widget.removeBtn:IsShown() and -2 or -4, 0)
        widget.nameText:SetText(C_Spell.GetSpellName(displayID) or L["Unknown"])
        if isActive == false then UI.SetTextMuted(widget.nameText)
        elseif selectedSpellID == spellID then UI.SetTextWhite(widget.nameText)
        else UI.SetTextSubtle(widget.nameText) end

        widget.btnUp:Hide()
        widget.btnUp:SetScript("OnClick", nil)
        widget.btnDown:Hide()
        widget.btnDown:SetScript("OnClick", nil)
        if sourceGroup and spellIndex and spellCount then
            widget.btnUp:Show()
            widget.btnUp:SetEnabled(spellIndex ~= 1)
            widget.btnUp:SetScript("OnClick", function()
                local groups = GetSpecGroups()
                if not groups or not groups[sourceGroup] then return end
                local spells = groups[sourceGroup].spells
                if spells and spellIndex > 1 then
                    spells[spellIndex], spells[spellIndex - 1] = spells[spellIndex - 1], spells[spellIndex]
                    SaveStructuralRefresh(); RefreshLeftPanelIfNeeded()
                end
            end)
            widget.btnDown:Show()
            widget.btnDown:SetEnabled(spellIndex ~= spellCount)
            widget.btnDown:SetScript("OnClick", function()
                local groups = GetSpecGroups()
                if not groups or not groups[sourceGroup] then return end
                local spells = groups[sourceGroup].spells
                if spells and spellIndex < #spells then
                    spells[spellIndex], spells[spellIndex + 1] = spells[spellIndex + 1], spells[spellIndex]
                    SaveStructuralRefresh(); RefreshLeftPanelIfNeeded()
                end
            end)
        end

        widget.clickBtn:SetScript("OnClick", function()
            selectedSpellID = spellID
            selectedGroupIndex = nil
            selectedSpellGroupIndex = sourceGroup
            ShowSpellSettings(spellID, sourceGroup)
            RefreshLeftPanelIfNeeded()
        end)
        widget.clickBtn:SetScript("OnDragStart", function() StartDrag(spellID, sourceGroup) end)
        widget.clickBtn:SetScript("OnDragStop", function() EndDrag() end)

        return widget
    end

    BuildIconGrid = function()
        ReleaseAllGridIcons()
        gridEmptyText:Hide()

        local iconGap = CDM.db and CDM.db.spacing or GRID_ICON_GAP
        minGridHeight = MIN_GRID_ROWS * (GRID_ICON_SIZE + iconGap) - iconGap + 8

        UpdateGridVisibility()
        if currentSpecID ~= playerSpecID then return end

        local spells = GetUngroupedSpellsFromViewers()

        if #spells == 0 then
            iconGridFrame:SetHeight(minGridHeight)
            gridEmptyText:SetText(L["All spells are in groups"] or "All spells are in groups")
            gridEmptyText:Show()
            UI.SetTextFaint(gridEmptyText)
            return
        end

        local totalSpells = #spells
        local effectiveMax = GRID_DISPLAY_MAX
        local cfgColor = CDM_C.GetConfigValue("borderColor", { r = 0, g = 0, b = 0, a = 1 })
        local totalRows = math.ceil(totalSpells / effectiveMax)

        for i, spellID in ipairs(spells) do
            local frame = AcquireGridIcon()

            if CDM.BORDER and CDM.BORDER.CreateBorder then
                CDM.BORDER:CreateBorder(frame, { forceUpdate = true })
                if CDM.BORDER.activeBorders then CDM.BORDER.activeBorders[frame] = nil end
            end

            local row = math.floor((i - 1) / effectiveMax)
            local col = (i - 1) % effectiveMax
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", col * (GRID_ICON_SIZE + iconGap), -row * (GRID_ICON_SIZE + iconGap))

            local gridDisplayID = GetDisplaySpellID(spellID)
            local tex = C_Spell.GetSpellTexture(gridDisplayID)
            if tex then frame.icon:SetTexture(tex) end
            frame.icon:SetDesaturated(false)
            frame.icon:SetAlpha(1)

            if frame.border then
                frame.border:SetBackdropBorderColor(cfgColor.r, cfgColor.g, cfgColor.b, cfgColor.a or 1)
            end

            frame.overlay:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:Show()
            end)
            frame.overlay:SetScript("OnLeave", function() GameTooltip:Hide() end)
            frame.overlay:SetScript("OnClick", function()
                selectedSpellID = spellID
                selectedGroupIndex = nil
                selectedSpellGroupIndex = nil
                ShowSpellSettings(spellID, nil)
                RefreshLeftPanelIfNeeded()
            end)
            frame.overlay:SetScript("OnDragStart", function() StartDrag(spellID, nil) end)
            frame.overlay:SetScript("OnDragStop", function() EndDrag() end)
        end

        local gridHeight = totalRows * (GRID_ICON_SIZE + iconGap) - iconGap + 8
        iconGridFrame:SetHeight(math.max(gridHeight, minGridHeight))
    end

    local function BuildGroupsPanel()
        if renameActiveGroupIndex and renameActiveEditBox then
            local newName = renameActiveEditBox:GetText()
            local groups = GetSpecGroups()
            local gd = groups and groups[renameActiveGroupIndex]
            if gd and newName and newName ~= "" then gd.name = newName end
            renameActiveGroupIndex = nil
            renameActiveEditBox = nil
        end

        local lc = leftChild
        headerPool:ReleaseAll()
        groupContainerPool:ReleaseAll()
        spellRowPool:ReleaseAll()
        emptyRowPool:ReleaseAll()
        ClearDropTargets()
        RegisterDropTarget(iconGridFrame, nil)

        local isViewingPlayer = currentSpecID == playerSpecID
        local activeSpellSet = isViewingPlayer and BuildCooldownActiveSet() or nil
        local yOff = 0
        local groups = GetSpecGroups()
        if groups then
            for groupIndex, groupData in ipairs(groups) do
                local isExpanded = expandedGroups[groupIndex] ~= false
                local displayName = groupData.name or ("Group " .. groupIndex)

                local h = headerPool:Acquire(lc)
                Shared.ConfigureExpandableHeader(h, yOff, isExpanded, displayName, selectedGroupIndex == groupIndex)

                if renameActiveGroupIndex == groupIndex then
                    renameActiveEditBox = Shared.SetupRenameEditBox(
                        h.row, h.bgLeft, h.bgRight, h.nameText,
                        displayName,
                        function(newName)
                            groupData.name = newName
                            renameActiveGroupIndex = nil
                            renameActiveEditBox = nil
                            if selectedGroupIndex == groupIndex then ShowGroupSettings(groupIndex) end
                            RefreshLeftPanelIfNeeded()
                        end,
                        function()
                            renameActiveGroupIndex = nil
                            renameActiveEditBox = nil
                            RefreshLeftPanelIfNeeded()
                        end
                    )
                end

                h.deleteBtn:SetScript("OnClick", function()
                    local function DoDelete()
                        local specGroups = EnsureGroups()
                        if specGroups then
                            local gd = specGroups[groupIndex]
                            if gd and gd.spells and gd.spellOverrides then
                                local specOv = EnsureUngroupedOverrides()
                                if specOv then
                                    for _, sid in ipairs(gd.spells) do
                                        local ovData = ExtractMergedOverrideEntry(gd.spellOverrides, sid)
                                        if ovData then StoreMergedOverrideEntry(specOv, sid, ovData) end
                                    end
                                end
                            end
                            table.remove(specGroups, groupIndex)
                        end
                        if selectedGroupIndex == groupIndex then
                            selectedGroupIndex = nil
                            selectedSpellID = nil
                            ClearRightPanel()
                        elseif selectedGroupIndex and selectedGroupIndex > groupIndex then
                            selectedGroupIndex = selectedGroupIndex - 1
                        end
                        if selectedSpellGroupIndex then
                            if selectedSpellGroupIndex == groupIndex then
                                selectedSpellGroupIndex = nil
                                selectedSpellID = nil
                            elseif selectedSpellGroupIndex > groupIndex then
                                selectedSpellGroupIndex = selectedSpellGroupIndex - 1
                            end
                        end
                        local newExpanded = {}
                        for idx, val in pairs(expandedGroups) do
                            if idx < groupIndex then
                                newExpanded[idx] = val
                            elseif idx > groupIndex then
                                newExpanded[idx - 1] = val
                            end
                        end
                        expandedGroups = newExpanded
                        SaveStructuralRefresh(); RefreshLeftPanelIfNeeded()
                    end

                    local spellCount = groupData.spells and #groupData.spells or 0
                    if spellCount > 0 then
                        local dialog = StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_CD_GROUP"]
                        dialog.text = string.format(
                            L["Delete group with %d spell(s)?"] or "Delete group with %d spell(s)?",
                            spellCount
                        )
                        dialog._pendingDelete = DoDelete
                        StaticPopup_Show("AYIJE_CDM_CONFIRM_DELETE_CD_GROUP")
                    else
                        DoDelete()
                    end
                end)

                h.selectBtn:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then
                        MenuUtil.CreateContextMenu(h.selectBtn, function(_, rootDescription)
                            Shared.BuildGroupContextMenu(rootDescription,
                                { rename = L["Rename"] or "Rename", duplicate = L["Duplicate"] or "Duplicate", copyTo = L["Copy to"] or "Copy to" },
                                function()
                                    renameActiveGroupIndex = groupIndex
                                    RefreshLeftPanelIfNeeded()
                                end,
                                function()
                                    local specGroups = EnsureGroups()
                                    if not specGroups then return end
                                    local newIdx = DuplicateGroup(groupData, specGroups)
                                    expandedGroups[newIdx] = true
                                    selectedGroupIndex = newIdx
                                    selectedSpellID = nil
                                    if currentSpecID == playerSpecID then SaveStructuralRefresh() end
                                    ShowGroupSettings(newIdx)
                                    RefreshLeftPanelIfNeeded()
                                end,
                                function(specID)
                                    CopyGroupSettingsToSpec(groupData, specID)
                                    if specID == currentSpecID then RefreshLeftPanelIfNeeded() end
                                    if specID == playerSpecID then SaveStructuralRefresh() end
                                end
                            )
                        end)
                        return
                    end

                    local now = GetTime()
                    if renameLastClickGroup == groupIndex and (now - renameLastClickTime) < 0.4 then
                        renameActiveGroupIndex = groupIndex
                        renameLastClickTime = 0
                        renameLastClickGroup = nil
                        RefreshLeftPanelIfNeeded()
                        return
                    end
                    renameLastClickTime = now
                    renameLastClickGroup = groupIndex
                    selectedGroupIndex = groupIndex
                    selectedSpellID = nil
                    ShowGroupSettings(groupIndex)
                    RefreshLeftPanelIfNeeded()
                end)

                h.expandBtn:SetScript("OnClick", function()
                    expandedGroups[groupIndex] = not isExpanded
                    selectedGroupIndex = groupIndex
                    selectedSpellID = nil
                    ShowGroupSettings(groupIndex)
                    RefreshLeftPanelIfNeeded()
                end)

                yOff = yOff - GROUP_HEADER_H

                if isExpanded then
                    local groupContainerWidget = groupContainerPool:Acquire(lc)
                    local groupContainer = groupContainerWidget.root
                    groupContainer:ClearAllPoints()
                    groupContainer:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)
                    RegisterDropTarget(groupContainer, groupIndex)

                    local spells = groupData.spells
                    local groupY = 0
                    if spells and #spells > 0 then
                        for spellIndex, spellID in ipairs(spells) do
                            local active = not isViewingPlayer or Shared.HasEquivalentSpellID(activeSpellSet, spellID)
                            ConfigureSpellRow(
                                spellRowPool:Acquire(groupContainer),
                                groupContainer,
                                spellID,
                                groupIndex,
                                groupY,
                                active,
                                spellIndex,
                                #spells
                            )
                            groupY = groupY - ROW_HEIGHT
                        end
                    else
                        AcquireEmptyRow(groupContainer, L["Drag spells here"] or "Drag spells here")
                        groupY = -ROW_HEIGHT
                    end
                    groupContainer:SetHeight(math.abs(groupY) + 4)
                    yOff = yOff + groupY
                end
            end
        end

        lc:SetHeight(math.abs(yOff) + 40)
    end

    do
        local addGroupBtn = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
        addGroupBtn:SetSize(90, 22)
        addGroupBtn:SetPoint("LEFT", 0, 0)
        addGroupBtn:SetText(L["Add Group"])
        addGroupBtn:SetScript("OnClick", function()
            local specGroups = EnsureGroups()
            if not specGroups then return end
            local newIndex = #specGroups + 1
            local defs = CDM.defaults or {}
            local defaultSize = defs.sizeEssRow1 or { w = 46, h = 40 }
            specGroups[newIndex] = {
                name = "Group " .. newIndex,
                spells = {},
                grow = "RIGHT",
                spacing = 1,
                iconWidth = defaultSize.w,
                iconHeight = defaultSize.h,
                cooldownFontSize = defs.cooldownFontSize or 15,
                cooldownColor = { r = 1, g = 1, b = 1 },
                chargeFontSize = defs.chargeFontSize or 15,
                chargeColor = { r = 1, g = 1, b = 1, a = 1 },
                chargePosition = "BOTTOMRIGHT",
                chargeOffsetX = 0,
                chargeOffsetY = 0,
                anchorTarget = "screen",
                anchorPoint = "CENTER",
                anchorRelativeTo = "CENTER",
                offsetX = 0,
                offsetY = 0,
            }
            expandedGroups[newIndex] = true
            selectedGroupIndex = newIndex
            selectedSpellID = nil
            SaveStructuralRefresh(); RefreshLeftPanelIfNeeded()
            ShowGroupSettings(newIndex)
        end)

        local addIconBtn = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
        addIconBtn:SetSize(90, 22)
        addIconBtn:SetPoint("LEFT", addGroupBtn, "RIGHT", 6, 0)
        addIconBtn:SetText(L["Add Icon"])
        addIconBtn:SetScript("OnClick", function()
            if selectedGroupIndex then ShowSpellPickerPanel(selectedGroupIndex) end
        end)
        addIconBtnRef = addIconBtn
    end

    RefreshAll = function()
        BuildIconGrid()
        BuildGroupsPanel()
        if addIconBtnRef then addIconBtnRef:SetEnabled(selectedGroupIndex ~= nil) end
    end

    local specDropdown, RefreshSpecDropdownText = Shared.CreateSpecDropdown(page, "TOPRIGHT", -6, -8, {
        getPlayerSpecID = function() return playerSpecID end,
        getCurrentSpecID = function() return currentSpecID end,
        onSelectionChange = function(specID)
            currentSpecID = specID
            selectedGroupIndex = nil
            selectedSpellID = nil
            selectedSpellGroupIndex = nil
            ClearRightPanel()
            RefreshAll()
        end,
    })
    specDropdown:Hide()

    local RegisterViewerCallbacks, UnregisterViewerCallbacks = Shared.CreateViewerSettingsCallbacks(QueueLeftPanelRefresh)

    subPage:HookScript("OnShow", function()
        RegisterViewerCallbacks()
        RefreshCurrentSpecID()
        RefreshAll()
        if selectedGroupIndex then
            ShowGroupSettings(selectedGroupIndex)
        elseif selectedSpellID then
            ShowSpellSettings(selectedSpellID, selectedSpellGroupIndex)
        end
        RefreshSpecDropdownText()
        specDropdown:Show()
    end)

    subPage:HookScript("OnHide", function()
        specDropdown:Hide()
        UnregisterViewerCallbacks()
        if UI and UI.CloseAllDropdownMenus then UI.CloseAllDropdownMenus() end
        CancelDrag()
    end)

    subPage:SetScript("OnMouseUp", function()
        EndDrag()
    end)

    API:RegisterRefreshCallback("cdgroups-spec-refresh", function()
        if not subPage:IsShown() then return end
        if GetTime() < suppressPanelRefreshUntil then return end
        RefreshCurrentSpecID()
        RefreshSpecDropdownText()
        QueueLeftPanelRefresh()
    end, 30)
end

ns._CreateCooldownGroupsPanel = CreateCooldownGroupsPanel
