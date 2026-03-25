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
local CLASS_LIST, CLASS_SPECS
if Shared.GetClassCatalog then
    CLASS_LIST, CLASS_SPECS = Shared.GetClassCatalog()
end
CLASS_LIST = CLASS_LIST or {}
CLASS_SPECS = CLASS_SPECS or {}

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
    local divider = subPage:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", subPage, "TOP", 0, 0)

    local specIndex = GetSpecialization()
    local currentSpecID = specIndex and GetSpecializationInfo(specIndex) or nil
    local playerSpecID = currentSpecID
    local NormalizeToBase = API.NormalizeToBase

    local GetDisplaySpellID = Shared.GetDisplaySpellID

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

    local function IsViewingPlayerSpec()
        return currentSpecID == playerSpecID
    end

    local function RefreshCurrentSpecID()
        local si = GetSpecialization()
        local newPlayerSpec = si and GetSpecializationInfo(si) or nil
        local wasViewingPlayer = (currentSpecID == playerSpecID) or (currentSpecID == nil)
        playerSpecID = newPlayerSpec
        if wasViewingPlayer then currentSpecID = newPlayerSpec end
    end

    local function EnsureGroups()
        if not currentSpecID then return nil end
        if not CDM.db[dbKey] then CDM.db[dbKey] = {} end
        if not CDM.db[dbKey][currentSpecID] then CDM.db[dbKey][currentSpecID] = {} end
        return CDM.db[dbKey][currentSpecID]
    end

    local function GetSpecGroups()
        if not currentSpecID then return nil end
        local bg = CDM.db[dbKey]
        return bg and bg[currentSpecID]
    end

    local SaveAndRefresh = Shared.SaveVisualRefresh
    local SaveStructuralRefresh = Shared.SaveStructuralRefresh

    local function RefreshLeftPanelIfNeeded()
        if RefreshAll then RefreshAll() end
    end

    local function SaveRefreshAndMaybeRebuildLeft()
        SaveStructuralRefresh()
        RefreshLeftPanelIfNeeded()
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

    local GROW_OPTIONS = Shared.GROW_OPTIONS
    local GetGrowLabel = Shared.GetGrowLabel

    local IsUsableSpellID = Shared.IsUsableSpellID

    local function GetUniqueGroupName(groups, baseName)
        return Shared.GetUniqueGroupName(groups, baseName)
    end

    local function CreateLayoutOnlyGroupClone(groups, groupData)
        return {
            name = GetUniqueGroupName(groups, groupData.name or "Group"),
            spells = {},
            grow = groupData.grow,
            spacing = groupData.spacing,
            iconWidth = groupData.iconWidth,
            iconHeight = groupData.iconHeight,
            maxPerRow = groupData.maxPerRow,
            cooldownFontSize = groupData.cooldownFontSize,
            cooldownColor = groupData.cooldownColor and { r = groupData.cooldownColor.r, g = groupData.cooldownColor.g, b = groupData.cooldownColor.b, a = groupData.cooldownColor.a },
            chargeFontSize = groupData.chargeFontSize,
            chargeColor = groupData.chargeColor and { r = groupData.chargeColor.r, g = groupData.chargeColor.g, b = groupData.chargeColor.b, a = groupData.chargeColor.a },
            chargePosition = groupData.chargePosition,
            chargeOffsetX = groupData.chargeOffsetX,
            chargeOffsetY = groupData.chargeOffsetY,
            anchorTarget = groupData.anchorTarget,
            anchorPoint = groupData.anchorPoint,
            anchorRelativeTo = groupData.anchorRelativeTo,
            offsetX = groupData.offsetX,
            offsetY = groupData.offsetY,
        }
    end

    local function CopyGroupSettingsToSpec(groupData, targetSpecID)
        if not CDM.db[dbKey] then CDM.db[dbKey] = {} end
        if not CDM.db[dbKey][targetSpecID] then CDM.db[dbKey][targetSpecID] = {} end
        local targetGroups = CDM.db[dbKey][targetSpecID]
        targetGroups[#targetGroups + 1] = CreateLayoutOnlyGroupClone(targetGroups, groupData)
    end

    local function DuplicateGroup(groupData, specGroups)
        specGroups[#specGroups + 1] = CreateLayoutOnlyGroupClone(specGroups, groupData)
        return #specGroups
    end

    local function MarkEquivalentSpellIDs(targetSet, spellID)
        Shared.MarkEquivalentSpellIDs(targetSet, spellID)
    end

    local function HasEquivalentSpellID(targetSet, spellID)
        return Shared.HasEquivalentSpellID(targetSet, spellID)
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

    local function RemoveSpellFromGroupList(spellList, spellID)
        return Shared.RemoveSpellFromGroupList(spellList, spellID)
    end

    local function AddSpellToGroupList(spellList, spellID)
        return Shared.AddSpellToGroupList(spellList, spellID)
    end

    local function EnsureResolvedOverrideEntry(overrideMap, spellID)
        return Shared.EnsureResolvedOverrideEntry(overrideMap, spellID, NormalizeToBase)
    end

    local function GetMergedOverride(overrideMap, spellID)
        return Shared.GetMergedOverrideEntry(overrideMap, spellID)
    end

    local function ExtractMergedOverrideEntry(overrideMap, spellID)
        return Shared.ExtractMergedOverrideEntry(overrideMap, spellID)
    end

    local function StoreMergedOverrideEntry(overrideMap, spellID, incoming)
        Shared.StoreMergedOverrideEntry(overrideMap, spellID, incoming, NormalizeToBase)
    end

    local function EnsureUngroupedOverrides()
        if not currentSpecID then return nil end
        if not CDM.db.ungroupedCooldownOverrides then CDM.db.ungroupedCooldownOverrides = {} end
        if not CDM.db.ungroupedCooldownOverrides[currentSpecID] then CDM.db.ungroupedCooldownOverrides[currentSpecID] = {} end
        return CDM.db.ungroupedCooldownOverrides[currentSpecID]
    end

    local function EnsureSpellOverride(groupIndex, spellID)
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then return nil end
        local gd = groups[groupIndex]
        if not gd.spellOverrides then gd.spellOverrides = {} end
        return EnsureResolvedOverrideEntry(gd.spellOverrides, spellID)
    end

    local function EnsureUngroupedOverrideEntry(spellID)
        local specOv = EnsureUngroupedOverrides()
        if not specOv then return nil end
        return EnsureResolvedOverrideEntry(specOv, spellID)
    end

    local function GetUngroupedOverride(spellID)
        if not currentSpecID then return nil end
        local specOv = CDM.db.ungroupedCooldownOverrides and CDM.db.ungroupedCooldownOverrides[currentSpecID]
        return GetMergedOverride(specOv, spellID)
    end

    local QueueLeftPanelRefresh = Shared.CreateQueueLeftPanelRefresh(subPage, function() return RefreshAll end)

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
                if srcGroup and srcGroup.spells then RemoveSpellFromGroupList(srcGroup.spells, spellID) end
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
                    local storedSpellID = AddSpellToGroupList(tgtGroup.spells, spellID) or spellID
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
    local RegisterDropTarget = dragDrop.RegisterDropTarget
    local ClearDropTargets = dragDrop.ClearDropTargets
    local StartDrag = dragDrop.StartDrag
    local EndDrag = dragDrop.EndDrag
    local CancelDrag = dragDrop.CancelDrag

    local DestroyFrame = Shared.DestroyFrame

    local GRID_ICON_SIZE = 36
    local GRID_ICON_GAP = 4
    local GRID_DISPLAY_MAX = 14
    local LEFT_INSET = Shared.LEFT_INSET
    local LEFT_WIDTH = Shared.LEFT_WIDTH
    local SCROLL_LEFT_PAD = Shared.SCROLL_LEFT_PAD
    local MIN_GRID_ROWS = 2

    local minGridHeight = MIN_GRID_ROWS * (GRID_ICON_SIZE + GRID_ICON_GAP) - GRID_ICON_GAP + 8

    local iconGridFrame = CreateFrame("Frame", nil, subPage)
    iconGridFrame:SetPoint("TOPLEFT", LEFT_INSET, -16)
    iconGridFrame:SetPoint("TOPRIGHT", -200, -16)
    iconGridFrame:SetHeight(minGridHeight)

    local gridHighlight = iconGridFrame:CreateTexture(nil, "BACKGROUND")
    gridHighlight:SetAllPoints()
    gridHighlight:SetColorTexture(0.2, 0.6, 0.2, 0.15)
    gridHighlight:Hide()
    iconGridFrame.highlight = gridHighlight

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
        if IsViewingPlayerSpec() then
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

    local RIGHT_X = Shared.RIGHT_X
    local rightPanel = CreateFrame("Frame", nil, subPage)
    rightPanel:SetPoint("TOPLEFT", buttonRow, "BOTTOMLEFT", RIGHT_X - LEFT_INSET, -4)
    rightPanel:SetPoint("BOTTOMRIGHT", -10, 20)

    local rightPlaceholder = rightPanel:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    rightPlaceholder:SetPoint("TOP", 0, -20)
    rightPlaceholder:SetText(L["Select a group or spell to edit settings"])
    UI.SetTextMuted(rightPlaceholder)

    local CreateSlider = Shared.CreateSlider

    local rightPanelManager = Shared.CreateRightPanelManager(rightPanel, rightPlaceholder, DestroyFrame)
    local RegisterRightPanelDropdown = rightPanelManager.RegisterDropdown
    local CreateRightScrollContent = rightPanelManager.CreateScrollContent
    local ClearRightPanel = rightPanelManager.Clear

    local DOT_OVERRIDE_SPELLS = CDM_C.DOT_OVERRIDE_SPELLS

    local function ShowGroupSettings(groupIndex)
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then ClearRightPanel(); return end

        local _, rc = CreateRightScrollContent(700)
        local gd = groups[groupIndex]
        local yOff = 0

        local nameHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        nameHeader:SetPoint("TOPLEFT", 0, yOff)
        nameHeader:SetText(gd.name or ("Group " .. groupIndex))
        nameHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 34

        local growLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        growLabel:SetText(L["Grow Direction"])
        growLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22

        local growDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
        growDropdown:SetWidth(180)
        growDropdown:SetPoint("TOPLEFT", 0, yOff)
        growDropdown:SetDefaultText(GetGrowLabel(gd.grow or "RIGHT"))
        UI.SetupValueDropdown(growDropdown, GROW_OPTIONS,
            function() return gd.grow or "RIGHT" end,
            function(val) gd.grow = val; SaveAndRefresh() end
        )
        yOff = yOff - 40

        local spacingSlider = CreateSlider(rc, L["Spacing"], -1, 50, gd.spacing or 4, function(v)
            gd.spacing = v; SaveAndRefresh()
        end)
        spacingSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local widthSlider = CreateSlider(rc, L["Icon Width"], 16, 100, gd.iconWidth or 30, function(v)
            gd.iconWidth = v; SaveAndRefresh()
        end)
        widthSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local heightSlider = CreateSlider(rc, L["Icon Height"], 16, 100, gd.iconHeight or 30, function(v)
            gd.iconHeight = v; SaveAndRefresh()
        end)
        heightSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local maxPerRowSlider = CreateSlider(rc, L["Max Per Row"] or "Max Per Row", 0, 20, gd.maxPerRow or 0, function(v)
            gd.maxPerRow = v > 0 and v or nil; SaveAndRefresh()
        end)
        maxPerRowSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        yOff = yOff - 10
        local textHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        textHeader:SetPoint("TOPLEFT", 0, yOff)
        textHeader:SetText(L["Text"])
        textHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 34

        local cdFSSlider = CreateSlider(rc, L["Cooldown Size"] or "Cooldown Size", 6, 32, gd.cooldownFontSize or 12, function(v)
            gd.cooldownFontSize = v; SaveAndRefresh()
        end)
        cdFSSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local cdColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        cdColorLabel:SetText(L["Color"])
        cdColorLabel:SetPoint("TOPLEFT", 0, yOff)
        local cdColorInit = gd.cooldownColor or { r = 1, g = 1, b = 1 }
        local cdColorPicker = UI.CreateSimpleColorPicker(rc, cdColorInit, function(r, g, b)
            if not gd.cooldownColor then gd.cooldownColor = { r = 1, g = 1, b = 1, a = 1 } end
            gd.cooldownColor.r, gd.cooldownColor.g, gd.cooldownColor.b = r, g, b
            SaveAndRefresh()
        end)
        cdColorPicker:SetPoint("LEFT", cdColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local chargeFSSlider = CreateSlider(rc, L["Charge Size"] or "Charge Size", 6, 32, gd.chargeFontSize or 15, function(v)
            gd.chargeFontSize = v; SaveAndRefresh()
        end)
        chargeFSSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local chargeColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        chargeColorLabel:SetText(L["Color"])
        chargeColorLabel:SetPoint("TOPLEFT", 0, yOff)
        local chargeColorInit = gd.chargeColor or { r = 1, g = 1, b = 1 }
        local chargeColorPicker = UI.CreateSimpleColorPicker(rc, chargeColorInit, function(r, g, b)
            if not gd.chargeColor then gd.chargeColor = { r = 1, g = 1, b = 1, a = 1 } end
            gd.chargeColor.r, gd.chargeColor.g, gd.chargeColor.b = r, g, b
            SaveAndRefresh()
        end)
        chargeColorPicker:SetPoint("LEFT", chargeColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local chargePosLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        chargePosLabel:SetText(L["Position"])
        chargePosLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22

        local chargePosDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
        chargePosDropdown:SetWidth(180)
        chargePosDropdown:SetPoint("TOPLEFT", 0, yOff)
        chargePosDropdown:SetDefaultText(gd.chargePosition or "BOTTOMRIGHT")
        UI.SetupPositionDropdown(chargePosDropdown,
            function() return gd.chargePosition or "BOTTOMRIGHT" end,
            function(val) gd.chargePosition = val; SaveAndRefresh() end
        )
        yOff = yOff - 40

        local chargeXSlider = CreateSlider(rc, L["X Offset"], -20, 20, gd.chargeOffsetX or 0, function(v)
            gd.chargeOffsetX = v; SaveAndRefresh()
        end)
        chargeXSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local chargeYSlider = CreateSlider(rc, L["Y Offset"], -20, 20, gd.chargeOffsetY or 0, function(v)
            gd.chargeOffsetY = v; SaveAndRefresh()
        end)
        chargeYSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        yOff = yOff - 10
        local anchorHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        anchorHeader:SetPoint("TOPLEFT", 0, yOff)
        anchorHeader:SetText(L["Anchor"])
        anchorHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 34

        local anchorTargetLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        anchorTargetLabel:SetText(L["Anchor To"] or "Anchor To")
        anchorTargetLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22

        local UpdateAnchorVisibility
        local anchorTargetDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
        anchorTargetDropdown:SetWidth(180)
        anchorTargetDropdown:SetPoint("TOPLEFT", 0, yOff)
        local currentTarget = gd.anchorTarget or "screen"
        local TARGET_LABELS = {
            screen = L["Screen"] or "Screen",
            playerFrame = L["Player Frame"] or "Player Frame",
            essential = L["Essential Viewer"] or "Essential Viewer",
            utility = L["Utility Viewer"] or "Utility Viewer",
            buff = L["Buff Viewer"] or "Buff Viewer",
        }
        anchorTargetDropdown:SetDefaultText(TARGET_LABELS[currentTarget] or TARGET_LABELS.screen)
        UI.SetupValueDropdown(anchorTargetDropdown,
            {
                { label = TARGET_LABELS.screen, value = "screen" },
                { label = TARGET_LABELS.playerFrame, value = "playerFrame" },
                { label = TARGET_LABELS.essential, value = "essential" },
                { label = TARGET_LABELS.utility, value = "utility" },
                { label = TARGET_LABELS.buff, value = "buff" },
            },
            function() return gd.anchorTarget or "screen" end,
            function(val)
                local prev = gd.anchorTarget or "screen"
                gd.anchorTarget = val
                gd.anchorPoint = gd.anchorPoint or "CENTER"
                gd.anchorRelativeTo = gd.anchorRelativeTo or "CENTER"
                if val ~= prev then
                    gd.offsetX = 0
                    gd.offsetY = 0
                    xSlider:UpdateUIValue(0)
                    ySlider:UpdateUIValue(0)
                end
                SaveAndRefresh()
                UpdateAnchorVisibility()
            end
        )
        yOff = yOff - 40
        local yAfterTarget = yOff

        local anchorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        anchorLabel:SetText(L["Anchor Point"])
        anchorLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22

        local anchorDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
        anchorDropdown:SetWidth(180)
        anchorDropdown:SetPoint("TOPLEFT", 0, yOff)
        anchorDropdown:SetDefaultText(gd.anchorPoint or "CENTER")
        UI.SetupPositionDropdown(anchorDropdown,
            function() return gd.anchorPoint or "CENTER" end,
            function(val) gd.anchorPoint = val; SaveAndRefresh() end
        )
        yOff = yOff - 40

        local relLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        relLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22

        local relDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
        relDropdown:SetWidth(180)
        relDropdown:SetPoint("TOPLEFT", 0, yOff)
        relDropdown:SetDefaultText(gd.anchorRelativeTo or "CENTER")
        UI.SetupPositionDropdown(relDropdown,
            function() return gd.anchorRelativeTo or "CENTER" end,
            function(val) gd.anchorRelativeTo = val; SaveAndRefresh() end
        )
        yOff = yOff - 40
        local yAfterConditional = yOff

        local xSlider = CreateSlider(rc, L["X Offset"], -840, 840, gd.offsetX or 0, function(v)
            gd.offsetX = v; SaveAndRefresh()
        end)
        xSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local ySlider = CreateSlider(rc, L["Y Offset"], -470, 470, gd.offsetY or 0, function(v)
            gd.offsetY = v; SaveAndRefresh()
        end)
        ySlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        UpdateAnchorVisibility = function()
            local isScreen = (gd.anchorTarget or "screen") == "screen"
            anchorLabel:SetShown(not isScreen)
            anchorDropdown:SetShown(not isScreen)
            relLabel:SetShown(not isScreen)
            relDropdown:SetShown(not isScreen)
            if not isScreen then
                local target = gd.anchorTarget
                if target == "playerFrame" then relLabel:SetText(L["Player Frame Point"] or "Player Frame Point")
                elseif target == "buff" then relLabel:SetText(L["Buff Viewer Point"] or "Buff Viewer Point")
                elseif target == "utility" then relLabel:SetText(L["Utility Viewer Point"] or "Utility Viewer Point")
                else relLabel:SetText(L["Essential Viewer Point"] or "Essential Viewer Point") end
                anchorDropdown:SetDefaultText(gd.anchorPoint or "CENTER")
                relDropdown:SetDefaultText(gd.anchorRelativeTo or "CENTER")
            end
            local sliderY = isScreen and yAfterTarget or yAfterConditional
            xSlider:ClearAllPoints(); xSlider:SetPoint("TOPLEFT", 0, sliderY)
            ySlider:ClearAllPoints(); ySlider:SetPoint("TOPLEFT", 0, sliderY - 50)
            rc:SetHeight(math.abs(sliderY - 100) + 20)
        end
        UpdateAnchorVisibility()
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
                auraOv = GetMergedOverride(grps and grps[groupIndex] and grps[groupIndex].spellOverrides, spellID)
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
                local existingOv = GetMergedOverride(gd.spellOverrides, spellID)
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

    local ICON_SIZE = 30
    local ROW_HEIGHT = 36
    local GROUP_HEADER_H = 28
    local ARROW_BTN_SIZE = 29

    local headerPool = Shared.CreateWidgetPool(function(parent)
        local header = Shared.CreateExpandableHeader(parent, 0, false, "", false)
        header.root = header.row
        return header
    end, function(header)
        header.nameText:Show()
        header.selectBtn:SetScript("OnClick", nil)
        header.deleteBtn:SetScript("OnClick", nil)
        header.expandBtn:SetScript("OnClick", nil)
    end)

    local groupContainerPool = Shared.CreateWidgetPool(function(parent)
        local groupContainer = CreateFrame("Frame", nil, parent)
        groupContainer:SetSize(LEFT_WIDTH, 10)
        local highlight = groupContainer:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.2, 0.4, 0.8, 0.15)
        highlight:Hide()
        groupContainer.highlight = highlight
        return { root = groupContainer, highlight = highlight }
    end, function(widget)
        widget.highlight:Hide()
    end)

    local emptyRowPool = Shared.CreateWidgetPool(function(parent)
        local emptyFrame = CreateFrame("Frame", nil, parent)
        emptyFrame:SetSize(LEFT_WIDTH, ROW_HEIGHT)
        local emptyText = emptyFrame:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        emptyText:SetPoint("LEFT", 10, 0)
        return { root = emptyFrame, text = emptyText }
    end, function(widget)
        widget.text:SetText("")
    end)

    local spellRowPool = Shared.CreateWidgetPool(function(parent)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(LEFT_WIDTH - 20, ROW_HEIGHT)

        local btnUp = CreateFrame("Button", nil, row)
        btnUp:SetSize(ARROW_BTN_SIZE, ARROW_BTN_SIZE)
        btnUp:SetPoint("RIGHT", row, "LEFT", -2 - ARROW_BTN_SIZE + 2, 0)
        btnUp:SetNormalAtlas("common-button-collapseExpand-up")
        btnUp:SetPushedAtlas("common-button-collapseExpand-up-pressed")
        btnUp:SetDisabledAtlas("common-button-collapseExpand-up-disabled")
        btnUp:SetHighlightAtlas("common-button-collapseExpand-hover")

        local btnDown = CreateFrame("Button", nil, row)
        btnDown:SetSize(ARROW_BTN_SIZE, ARROW_BTN_SIZE)
        btnDown:SetPoint("RIGHT", row, "LEFT", -2, 0)
        btnDown:SetNormalAtlas("common-button-collapseExpand-down")
        btnDown:SetPushedAtlas("common-button-collapseExpand-down-pressed")
        btnDown:SetDisabledAtlas("common-button-collapseExpand-down-disabled")
        btnDown:SetHighlightAtlas("common-button-collapseExpand-hover")

        local iconContainer = CreateFrame("Frame", nil, row)
        iconContainer:SetSize(ICON_SIZE, ICON_SIZE)
        iconContainer:SetPoint("LEFT", 0, 0)
        local iconTex = iconContainer:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            CDM.BORDER:CreateBorder(iconContainer)
            if CDM.BORDER.activeBorders then
                CDM.BORDER.activeBorders[iconContainer] = nil
            end
        end

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(16, 16)
        removeBtn:SetPoint("RIGHT", -6, 0)
        removeBtn:SetFrameLevel(row:GetFrameLevel() + 2)
        local removeBtnText = removeBtn:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        removeBtnText:SetPoint("CENTER")
        removeBtnText:SetText("|cffff4444X|r")
        removeBtn:SetFontString(removeBtnText)

        local nameText = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
        nameText:SetJustifyH("LEFT")

        local clickBtn = CreateFrame("Button", nil, row)
        clickBtn:SetAllPoints()
        clickBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        clickBtn:RegisterForDrag("LeftButton")

        return {
            root = row,
            btnUp = btnUp,
            btnDown = btnDown,
            iconContainer = iconContainer,
            iconTex = iconTex,
            removeBtn = removeBtn,
            nameText = nameText,
            clickBtn = clickBtn,
        }
    end, function(widget)
        widget.btnUp:Hide()
        widget.btnUp:SetScript("OnClick", nil)
        widget.btnDown:Hide()
        widget.btnDown:SetScript("OnClick", nil)
        widget.removeBtn:Hide()
        widget.removeBtn:SetScript("OnClick", nil)
        widget.clickBtn:SetScript("OnClick", nil)
        widget.clickBtn:SetScript("OnDragStart", nil)
        widget.clickBtn:SetScript("OnDragStop", nil)
        widget.nameText:SetText("")
        widget.iconTex:SetTexture(nil)
        widget.iconTex:SetDesaturated(false)
        widget.iconTex:SetAlpha(1)
        if widget.iconContainer.border then
            widget.iconContainer.border:SetAlpha(1)
            local cfgColor = CDM_C.GetConfigValue("borderColor", { r = 0, g = 0, b = 0, a = 1 })
            widget.iconContainer.border:SetBackdropBorderColor(cfgColor.r, cfgColor.g, cfgColor.b, cfgColor.a or 1)
        end
    end)

    local function GetViewerSpellListForSpec(specID)
        local seen, list = {}, {}
        if specID == playerSpecID then
            for _, cat in ipairs({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }) do
                local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
                if ids then
                    for _, id in ipairs(ids) do
                        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
                        if info then
                            local sid = info.overrideSpellID or info.spellID
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
                        local sid = info.overrideSpellID or info.spellID
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
                    MarkEquivalentSpellIDs(assigned, sid)
                end
            end
        end
        ExpandGroupedSetWithLinkedSpells(assigned)
        local seen = {}
        local result = {}
        for _, spellID in ipairs(allSpells) do
            if not HasEquivalentSpellID(assigned, spellID)
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
                        MarkEquivalentSpellIDs(groupedSet, groupedSpellID)
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
                            and not HasEquivalentSpellID(groupedSet, displayID)
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
                AddSpellToGroupList(currentGroups[groupIndex].spells, sid)
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
                SaveRefreshAndMaybeRebuildLeft()
                ShowSpellPickerPanel(groupIndex)
            end,
            onDone = function()
                ShowGroupSettings(groupIndex)
            end,
        })
    end

    local function AcquireEmptyRow(parent, text)
        local widget = emptyRowPool:Acquire(parent)
        widget.root:SetPoint("TOPLEFT", 0, 0)
        widget.text:SetText(text)
        UI.SetTextFaint(widget.text)
        return widget
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
        if currentSpecID and CDM.SpellRegistry then
            local color = CDM.SpellRegistry:GetColor(currentSpecID, spellID)
            if color and widget.iconContainer.border then
                widget.iconContainer.border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
            end
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
                if gd.spells then RemoveSpellFromGroupList(gd.spells, spellID) end
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
                SaveRefreshAndMaybeRebuildLeft()
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
                    SaveRefreshAndMaybeRebuildLeft()
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
                    SaveRefreshAndMaybeRebuildLeft()
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
        if not IsViewingPlayerSpec() then return end

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

        local isViewingPlayer = IsViewingPlayerSpec()
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
                        SaveRefreshAndMaybeRebuildLeft()
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
                                    if IsViewingPlayerSpec() then SaveStructuralRefresh() end
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
                            local active = not isViewingPlayer or HasEquivalentSpellID(activeSpellSet, spellID)
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
            SaveRefreshAndMaybeRebuildLeft()
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
    end, 30, { "spec_data" })
end

ns._CreateCooldownGroupsPanel = CreateCooldownGroupsPanel
