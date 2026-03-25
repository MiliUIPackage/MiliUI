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

StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_GROUP"] = {
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local fn = StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_GROUP"]._pendingDelete
        if fn then fn() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateBuffGroupsTab(page)
    local specIndex = GetSpecialization()
    local currentSpecID = specIndex and GetSpecializationInfo(specIndex) or nil
    local playerSpecID = currentSpecID

    local NormalizeToBase = API.NormalizeToBase

    local selectedGroupIndex = nil
    local selectedSpellID = nil
    local selectedSpellGroupIndex = nil
    local expandedGroups = {}
    local RefreshAll
    local ShowSpellSettings
    local renameLastClickTime = 0
    local renameLastClickGroup = nil
    local renameActiveGroupIndex = nil
    local renameActiveEditBox = nil
    local suppressPanelRefreshUntil = 0
    local ungroupedSelected = false
    local pickerActiveGroupIndex = nil

    local function IsViewingPlayerSpec()
        return currentSpecID == playerSpecID
    end

    local function RefreshCurrentSpecID()
        local si = GetSpecialization()
        local newPlayerSpec = si and GetSpecializationInfo(si) or nil
        local wasViewingPlayer = (currentSpecID == playerSpecID) or (currentSpecID == nil)
        playerSpecID = newPlayerSpec
        if wasViewingPlayer then
            currentSpecID = newPlayerSpec
        end
    end

    local function EnsureBuffGroups()
        if not currentSpecID then return nil end
        if not CDM.db.buffGroups then
            CDM.db.buffGroups = {}
        end
        if not CDM.db.buffGroups[currentSpecID] then
            CDM.db.buffGroups[currentSpecID] = {}
        end
        return CDM.db.buffGroups[currentSpecID]
    end

    local function GetSpecGroups()
        if not currentSpecID then return nil end
        local bg = CDM.db.buffGroups
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

    local GetConfiguredBorderColor = Shared.GetConfiguredBorderColor
    local ApplyConfiguredBorderColor = Shared.ApplyConfiguredBorderColor

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
            staticDisplay = groupData.staticDisplay,
            cooldownFontSize = groupData.cooldownFontSize,
            cooldownColor = groupData.cooldownColor and { r = groupData.cooldownColor.r, g = groupData.cooldownColor.g, b = groupData.cooldownColor.b, a = groupData.cooldownColor.a },
            countFontSize = groupData.countFontSize,
            countColor = groupData.countColor and { r = groupData.countColor.r, g = groupData.countColor.g, b = groupData.countColor.b, a = groupData.countColor.a },
            countPosition = groupData.countPosition,
            countOffsetX = groupData.countOffsetX,
            countOffsetY = groupData.countOffsetY,
            anchorTarget = groupData.anchorTarget,
            anchorPoint = groupData.anchorPoint,
            anchorRelativeTo = groupData.anchorRelativeTo,
            offsetX = groupData.offsetX,
            offsetY = groupData.offsetY,
        }
    end

    local function CopyGroupSettingsToSpec(groupData, targetSpecID)
        if not CDM.db.buffGroups then CDM.db.buffGroups = {} end
        if not CDM.db.buffGroups[targetSpecID] then CDM.db.buffGroups[targetSpecID] = {} end
        local targetGroups = CDM.db.buffGroups[targetSpecID]
        local newGroup = CreateLayoutOnlyGroupClone(targetGroups, groupData)
        targetGroups[#targetGroups + 1] = newGroup
    end

    local function DuplicateGroup(groupData, specGroups)
        local newGroup = CreateLayoutOnlyGroupClone(specGroups, groupData)
        specGroups[#specGroups + 1] = newGroup
        return #specGroups
    end

    local function GetMergedOverride(overrideMap, spellID)
        return Shared.GetMergedOverrideEntry(overrideMap, spellID)
    end

    local function EnsureResolvedOverrideEntry(overrideMap, spellID)
        return Shared.EnsureResolvedOverrideEntry(overrideMap, spellID, NormalizeToBase)
    end

    local function ExtractMergedOverrideEntry(overrideMap, spellID)
        return Shared.ExtractMergedOverrideEntry(overrideMap, spellID)
    end

    local function StoreMergedOverrideEntry(overrideMap, spellID, incoming)
        Shared.StoreMergedOverrideEntry(overrideMap, spellID, incoming, NormalizeToBase)
    end

    local function EnsureSpellOverride(groupIndex, spellID)
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then return nil end
        local gd = groups[groupIndex]
        if not gd.spellOverrides then gd.spellOverrides = {} end
        return EnsureResolvedOverrideEntry(gd.spellOverrides, spellID)
    end

    local function EnsureUngroupedOverrides()
        if not currentSpecID then return nil end
        if not CDM.db.ungroupedBuffOverrides then
            CDM.db.ungroupedBuffOverrides = {}
        end
        if not CDM.db.ungroupedBuffOverrides[currentSpecID] then
            CDM.db.ungroupedBuffOverrides[currentSpecID] = {}
        end
        return CDM.db.ungroupedBuffOverrides[currentSpecID]
    end

    local function EnsureUngroupedOverrideEntry(spellID)
        local specOv = EnsureUngroupedOverrides()
        if not specOv then return nil end
        return EnsureResolvedOverrideEntry(specOv, spellID)
    end

    local function GetUngroupedOverride(spellID)
        if not currentSpecID then return nil end
        local specOv = CDM.db.ungroupedBuffOverrides and CDM.db.ungroupedBuffOverrides[currentSpecID]
        return GetMergedOverride(specOv, spellID)
    end

    local function BuildActiveSpellSet()
        if API.BuildActiveSpellSet then
            return API:BuildActiveSpellSet()
        end
        return {}
    end

    local function IsSpellActiveInViewer(spellID, cachedSet)
        if API.IsSpellActiveInViewer then
            return API:IsSpellActiveInViewer(spellID, cachedSet)
        end
        return false
    end

    local function MarkEquivalentSpellIDs(targetSet, spellID)
        Shared.MarkEquivalentSpellIDs(targetSet, spellID)
    end

    local function HasEquivalentSpellID(targetSet, spellID)
        return Shared.HasEquivalentSpellID(targetSet, spellID)
    end

    local function RemoveSpellFromGroupList(spellList, spellID)
        return Shared.RemoveSpellFromGroupList(spellList, spellID)
    end

    local function AddSpellToGroupList(spellList, spellID)
        return Shared.AddSpellToGroupList(spellList, spellID)
    end

    local function GetUngroupedBuffSpells()
        local buffViewer = _G["BuffIconCooldownViewer"]
        if not buffViewer or not buffViewer.itemFramePool then return {} end

        local icons = {}
        local seen = {}
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

        for frame in buffViewer.itemFramePool:EnumerateActive() do
            local matchType = API.GetBuffRegistryMatch and API:GetBuffRegistryMatch(frame) or nil
            if not matchType then
                local displayID = API.GetPreferredBuffGroupSpellID and API:GetPreferredBuffGroupSpellID(frame)
                if not IsSafeNumber(displayID) and API.GetBaseSpellID then
                    displayID = API:GetBaseSpellID(frame)
                end
                local hiddenBuffSet = CDM.resourcesHiddenBuffSet
                if IsSafeNumber(displayID)
                    and not HasEquivalentSpellID(groupedSet, displayID)
                    and not seen[displayID]
                    and not HasEquivalentSpellID(hiddenBuffSet, displayID)
                then
                    seen[displayID] = true
                    local li = frame.layoutIndex
                    local safeLayoutIndex = IsSafeNumber(li) and li or 0
                    icons[#icons + 1] = { spellID = displayID, layoutIndex = safeLayoutIndex }
                end
            end
        end
        table.sort(icons, function(a, b)
            if a.layoutIndex ~= b.layoutIndex then return a.layoutIndex < b.layoutIndex end
            return a.spellID < b.spellID
        end)
        local result = {}
        for _, data in ipairs(icons) do
            result[#result + 1] = data.spellID
        end
        return result
    end

    local QueueLeftPanelRefresh = Shared.CreateQueueLeftPanelRefresh(page, function() return RefreshAll end)

    local dragDrop = Shared.CreateDragDropController({
        onDrop = function(spellID, sourceGroup, targetGroupIndex, hitDropTarget)
            if not spellID or not currentSpecID then return end
            if not hitDropTarget then return end
            if sourceGroup == targetGroupIndex then return end

            local groups = EnsureBuffGroups()
            if not groups then return end

            local srcOvData = nil
            if sourceGroup then
                local srcGroup = groups[sourceGroup]
                if srcGroup and srcGroup.spells then
                    RemoveSpellFromGroupList(srcGroup.spells, spellID)
                end
                if srcGroup and srcGroup.spellOverrides then
                    srcOvData = ExtractMergedOverrideEntry(srcGroup.spellOverrides, spellID)
                end
            else
                local specOv = CDM.db.ungroupedBuffOverrides and CDM.db.ungroupedBuffOverrides[currentSpecID]
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
                if specOv then
                    StoreMergedOverrideEntry(specOv, spellID, srcOvData)
                end
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

    local LEFT_INSET = Shared.LEFT_INSET
    local LEFT_WIDTH = Shared.LEFT_WIDTH
    local SCROLL_LEFT_PAD = Shared.SCROLL_LEFT_PAD

    local leftScroll = CreateFrame("ScrollFrame", "AyijeCDM_BuffGroupsLeftScroll", page, "ScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", LEFT_INSET - SCROLL_LEFT_PAD, -40)
    leftScroll:SetPoint("BOTTOMLEFT", LEFT_INSET - SCROLL_LEFT_PAD, 20)
    leftScroll:SetWidth(LEFT_WIDTH + SCROLL_LEFT_PAD)

    local leftChild = CreateFrame("Frame", nil, leftScroll)
    leftChild:SetSize(LEFT_WIDTH + SCROLL_LEFT_PAD, 1200)
    leftScroll:SetScrollChild(leftChild)

    local RIGHT_X = Shared.RIGHT_X

    local rightPanel = CreateFrame("Frame", nil, page)
    rightPanel:SetPoint("TOPLEFT", RIGHT_X, -40)
    rightPanel:SetPoint("BOTTOMRIGHT", -10, 20)

    local rightPlaceholder = rightPanel:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    rightPlaceholder:SetPoint("TOP", 0, -20)
    rightPlaceholder:SetText(L["Select a group or spell to edit settings"])
    UI.SetTextMuted(rightPlaceholder)

    local CreateSlider = Shared.CreateSlider

    local rightPanelManager = Shared.CreateRightPanelManager(rightPanel, rightPlaceholder, DestroyFrame)
    local RegisterRightPanelDropdown = rightPanelManager.RegisterDropdown
    local CreateRightScrollContent = rightPanelManager.CreateScrollContent
    local _baseClear = rightPanelManager.Clear
    local ClearRightPanel = function()
        pickerActiveGroupIndex = nil
        _baseClear()
    end

    local function GetViewerSpellListForSpec(specID)
        if specID == playerSpecID then
            local seen, list = {}, {}
            local ids = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, true)
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
            return list
        else
            local raw = API:GetSpecBuffSpellCache(specID)
            if not raw then return {} end
            local seen, list = {}, {}
            for _, entry in ipairs(raw) do
                local sid = entry.spellID
                if sid and not seen[sid] then
                    seen[sid] = true
                    list[#list + 1] = sid
                end
            end
            return list
        end
    end

    local function GetUntrackedViewerSpellListForCurrentSpec()
        local activeSet = {}
        local viewer = _G[CDM_C.VIEWERS.BUFF]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                local candidates = API.GetSpellIDCandidates and API:GetSpellIDCandidates(frame, true)
                if candidates then
                    for _, id in ipairs(candidates) do
                        activeSet[id] = true
                    end
                end
            end
        end
        local seen, list = {}, {}
        local ids = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, true)
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
        return list
    end

    local function GetAvailableSpellsForPicker(specID)
        local allSpells = (specID == playerSpecID)
            and GetUntrackedViewerSpellListForCurrentSpec()
            or GetViewerSpellListForSpec(specID)
        local assigned = {}
        local groups = CDM.db.buffGroups and CDM.db.buffGroups[specID]
        if groups then
            for _, group in ipairs(groups) do
                for _, sid in ipairs(group.spells or {}) do
                    MarkEquivalentSpellIDs(assigned, sid)
                end
            end
        end
        local hiddenBuffSet = CDM.resourcesHiddenBuffSet
        local seen = {}
        local result = {}
        for _, spellID in ipairs(allSpells) do
            if not HasEquivalentSpellID(assigned, spellID)
                and not seen[spellID]
                and not HasEquivalentSpellID(hiddenBuffSet, spellID)
            then
                seen[spellID] = true
                local name = C_Spell.GetSpellName(spellID) or ("Spell " .. spellID)
                local icon = C_Spell.GetSpellTexture(spellID)
                local isKnown = IsPlayerSpell(spellID)
                result[#result + 1] = { spellID = spellID, name = name, icon = icon, isKnown = isKnown }
            end
        end
        table.sort(result, function(a, b) return a.name < b.name end)
        return result
    end

    local function GetUngroupedBuffSpellsFromCache(specID)
        local rawCache = API:GetSpecBuffSpellCache(specID)
        if not rawCache then return nil end
        local allSpells = {}
        for _, entry in ipairs(rawCache) do
            if entry.spellID then allSpells[#allSpells + 1] = entry.spellID end
        end
        if #allSpells == 0 then return nil end

        local assigned = {}
        local groups = CDM.db.buffGroups and CDM.db.buffGroups[specID]
        if groups then
            for _, group in ipairs(groups) do
                for _, sid in ipairs(group.spells or {}) do
                    MarkEquivalentSpellIDs(assigned, sid)
                end
            end
        end

        local hiddenBuffSet = CDM.resourcesHiddenBuffSet
        local seen = {}
        local result = {}
        for _, spellID in ipairs(allSpells) do
            if not HasEquivalentSpellID(assigned, spellID)
                and not seen[spellID]
                and not HasEquivalentSpellID(hiddenBuffSet, spellID)
            then
                seen[spellID] = true
                local name = C_Spell.GetSpellName(spellID) or ("Spell " .. spellID)
                result[#result + 1] = { spellID = spellID, name = name }
            end
        end
        table.sort(result, function(a, b) return a.name < b.name end)

        local sorted = {}
        for i, entry in ipairs(result) do sorted[i] = entry.spellID end
        return sorted
    end

    local function ShowUngroupedSettings()
        pickerActiveGroupIndex = nil
        local _, rc = CreateRightScrollContent(400)

        local yOff = 0

        local textHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        textHeader:SetPoint("TOPLEFT", 0, yOff)
        textHeader:SetText(L["Text"])
        textHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 34

        local cdFSSlider = CreateSlider(rc, L["Cooldown Size"] or "Cooldown Size", 6, 32, CDM.db.buffCooldownFontSize or 15, function(v)
            CDM.db.buffCooldownFontSize = v; SaveAndRefresh()
        end)
        cdFSSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local cdColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        cdColorLabel:SetText(L["Color"])
        cdColorLabel:SetPoint("TOPLEFT", 0, yOff)

        local cdColorInit = CDM.db.buffCooldownColor or { r = 1, g = 1, b = 1 }
        local cdColorPicker = UI.CreateSimpleColorPicker(rc, cdColorInit, function(r, g, b)
            local cur = CDM.db.buffCooldownColor or { r = 1, g = 1, b = 1, a = 1 }
            CDM.db.buffCooldownColor = { r = r, g = g, b = b, a = cur.a }
            SaveAndRefresh()
        end)
        cdColorPicker:SetPoint("LEFT", cdColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local countFSSlider = CreateSlider(rc, L["Charge Size"] or "Charge Size", 6, 32, CDM.db.countFontSize or 15, function(v)
            CDM.db.countFontSize = v; SaveAndRefresh()
        end)
        countFSSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local countColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        countColorLabel:SetText(L["Color"])
        countColorLabel:SetPoint("TOPLEFT", 0, yOff)

        local countColorInit = CDM.db.countColor or { r = 1, g = 1, b = 1 }
        local countColorPicker = UI.CreateSimpleColorPicker(rc, countColorInit, function(r, g, b)
            local cur = CDM.db.countColor or { r = 1, g = 1, b = 1, a = 1 }
            CDM.db.countColor = { r = r, g = g, b = b, a = cur.a }
            SaveAndRefresh()
        end)
        countColorPicker:SetPoint("LEFT", countColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local countPosLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        countPosLabel:SetText(L["Position"])
        countPosLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22

        local countPosDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
        countPosDropdown:SetWidth(180)
        countPosDropdown:SetPoint("TOPLEFT", 0, yOff)
        countPosDropdown:SetDefaultText(CDM.db.countPositionMain or "TOP")
        UI.SetupPositionDropdown(countPosDropdown,
            function() return CDM.db.countPositionMain or "TOP" end,
            function(val) CDM.db.countPositionMain = val; SaveAndRefresh() end
        )
        yOff = yOff - 40

        local countXSlider = CreateSlider(rc, L["X Offset"], -20, 20, CDM.db.countOffsetXMain or 0, function(v)
            CDM.db.countOffsetXMain = v; SaveAndRefresh()
        end)
        countXSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local countYSlider = CreateSlider(rc, L["Y Offset"], -20, 20, CDM.db.countOffsetYMain or 0, function(v)
            CDM.db.countOffsetYMain = v; SaveAndRefresh()
        end)
        countYSlider:SetPoint("TOPLEFT", 0, yOff)
    end

    local function ShowGroupSettings(groupIndex)
        pickerActiveGroupIndex = nil
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then
            ClearRightPanel()
            return
        end

        local _, rc = CreateRightScrollContent(700)

        local gd = groups[groupIndex]
        local yOff = 0

        local currentGrow = gd.grow or "RIGHT"

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
        growDropdown:SetDefaultText(GetGrowLabel(currentGrow))
        yOff = yOff - 40

        UI.SetupValueDropdown(growDropdown,
            GROW_OPTIONS,
            function() return gd.grow or "RIGHT" end,
            function(val) gd.grow = val; SaveAndRefresh() end
        )

        local staticCheckbox = UI.CreateModernCheckbox(
            rc,
            L["Static Display"] or "Static Display",
            gd.staticDisplay or false,
            function(checked)
                gd.staticDisplay = checked or nil
                SaveAndRefresh()
            end
        )
        staticCheckbox:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 36

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

        local countFSSlider = CreateSlider(rc, L["Charge Size"] or "Charge Size", 6, 32, gd.countFontSize or 15, function(v)
            gd.countFontSize = v; SaveAndRefresh()
        end)
        countFSSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local countColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        countColorLabel:SetText(L["Color"])
        countColorLabel:SetPoint("TOPLEFT", 0, yOff)

        local countColorInit = gd.countColor or { r = 1, g = 1, b = 1 }
        local countColorPicker = UI.CreateSimpleColorPicker(rc, countColorInit, function(r, g, b)
            if not gd.countColor then gd.countColor = { r = 1, g = 1, b = 1, a = 1 } end
            gd.countColor.r, gd.countColor.g, gd.countColor.b = r, g, b
            SaveAndRefresh()
        end)
        countColorPicker:SetPoint("LEFT", countColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local countPosLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        countPosLabel:SetText(L["Position"])
        countPosLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22

        local countPosDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
        countPosDropdown:SetWidth(180)
        countPosDropdown:SetPoint("TOPLEFT", 0, yOff)
        countPosDropdown:SetDefaultText(gd.countPosition or "BOTTOMRIGHT")
        UI.SetupPositionDropdown(countPosDropdown,
            function() return gd.countPosition or "BOTTOMRIGHT" end,
            function(val) gd.countPosition = val; SaveAndRefresh() end
        )
        yOff = yOff - 40

        local countXSlider = CreateSlider(rc, L["X Offset"], -20, 20, gd.countOffsetX or 0, function(v)
            gd.countOffsetX = v; SaveAndRefresh()
        end)
        countXSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local countYSlider = CreateSlider(rc, L["Y Offset"], -20, 20, gd.countOffsetY or 0, function(v)
            gd.countOffsetY = v; SaveAndRefresh()
        end)
        countYSlider:SetPoint("TOPLEFT", 0, yOff)
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
        local xSlider, ySlider
        local anchorTargetDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
        anchorTargetDropdown:SetWidth(180)
        anchorTargetDropdown:SetPoint("TOPLEFT", 0, yOff)
        local currentTarget = gd.anchorTarget or "screen"
        local TARGET_LABELS = {
            screen = L["Screen"] or "Screen",
            playerFrame = L["Player Frame"] or "Player Frame",
            essential = L["Essential Viewer"] or "Essential Viewer",
            buff = L["Buff Viewer"] or "Buff Viewer",
        }
        anchorTargetDropdown:SetDefaultText(TARGET_LABELS[currentTarget] or TARGET_LABELS.screen)
        UI.SetupValueDropdown(anchorTargetDropdown,
            {
                { label = TARGET_LABELS.screen, value = "screen" },
                { label = TARGET_LABELS.playerFrame, value = "playerFrame" },
                { label = TARGET_LABELS.essential, value = "essential" },
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
            function(val)
                gd.anchorPoint = val
                SaveAndRefresh()
            end
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
            function(val)
                gd.anchorRelativeTo = val
                SaveAndRefresh()
            end
        )
        yOff = yOff - 40
        local yAfterConditional = yOff

        xSlider = CreateSlider(rc, L["X Offset"], -840, 840, gd.offsetX or 0, function(v)
            gd.offsetX = v; SaveAndRefresh()
        end)
        xSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        ySlider = CreateSlider(rc, L["Y Offset"], -470, 470, gd.offsetY or 0, function(v)
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
                if target == "playerFrame" then
                    relLabel:SetText(L["Player Frame Point"] or "Player Frame Point")
                elseif target == "buff" then
                    relLabel:SetText(L["Buff Viewer Point"] or "Buff Viewer Point")
                else
                    relLabel:SetText(L["Essential Viewer Point"] or "Essential Viewer Point")
                end
                anchorDropdown:SetDefaultText(gd.anchorPoint or "CENTER")
                relDropdown:SetDefaultText(gd.anchorRelativeTo or "CENTER")
            end

            local sliderY = isScreen and yAfterTarget or yAfterConditional
            xSlider:ClearAllPoints()
            xSlider:SetPoint("TOPLEFT", 0, sliderY)
            ySlider:ClearAllPoints()
            ySlider:SetPoint("TOPLEFT", 0, sliderY - 50)
            rc:SetHeight(math.abs(sliderY - 100) + 20)
        end
        UpdateAnchorVisibility()
    end

    local spellIconBorders = {}

    local function BuildOverrideSection(rc, yOff, spellID, groupIndex, existingOv, ensureOv, defaults, placeholderOpts)
        yOff = yOff - 10
        local overrideHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        overrideHeader:SetPoint("TOPLEFT", 0, yOff)
        overrideHeader:SetText(L["Per-Spell Overrides"] or "Per-Spell Overrides")
        overrideHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 34

        local hideCdChecked = existingOv and existingOv.hideCooldown or false
        local hideVisualsChecked = existingOv and existingOv.hideVisuals or false
        local hideCdCheckbox, hideVisualsCheckbox

        hideCdCheckbox = UI.CreateModernCheckbox(
            rc,
            L["Hide Cooldown Timer"] or "Hide Cooldown Timer",
            hideCdChecked,
            function(checked)
                suppressPanelRefreshUntil = GetTime() + 0.15
                local ov = ensureOv()
                if not ov then return end
                ov.hideCooldown = checked or nil
                if checked then
                    ov.hideVisuals = nil
                    hideVisualsCheckbox:SetChecked(false)
                end
                SaveAndRefresh()
            end
        )
        hideCdCheckbox:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 36

        hideVisualsCheckbox = UI.CreateModernCheckbox(
            rc,
            L["Hide Icon"] or "Hide Icon",
            hideVisualsChecked,
            function(checked)
                suppressPanelRefreshUntil = GetTime() + 0.15
                local ov = ensureOv()
                if not ov then return end
                ov.hideVisuals = checked or nil
                if checked then
                    ov.hideCooldown = nil
                    hideCdCheckbox:SetChecked(false)
                end
                SaveAndRefresh()
            end
        )
        hideVisualsCheckbox:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 36

        if placeholderOpts then
            local placeholderChecked = existingOv and existingOv.placeholder or false
            local placeholderCheckbox = UI.CreateModernCheckbox(
                rc,
                L["Show Placeholder"] or "Show Placeholder",
                placeholderChecked,
                function(checked)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local ov = ensureOv()
                    if not ov then return end
                    ov.placeholder = checked or nil
                    SaveAndRefresh()
                end
            )
            placeholderCheckbox:SetPoint("TOPLEFT", 0, yOff)
            if not placeholderOpts.isStatic then
                placeholderCheckbox.checkbox:Disable()
                placeholderCheckbox.label:SetTextColor(0.5, 0.5, 0.5)
            end
            yOff = yOff - 36
        end

        local soundChecked = existingOv and existingOv.soundEnabled or false
        local soundCheckbox = UI.CreateModernCheckbox(
            rc,
            L["Play Sound"] or "Play Sound",
            soundChecked,
            function(checked)
                suppressPanelRefreshUntil = GetTime() + 0.15
                local ov = ensureOv()
                if not ov then return end
                ov.soundEnabled = checked or nil
                if checked then
                    ov.ttsEnabled = nil
                    ov.ttsOnShow = nil
                    ov.ttsOnHide = nil
                    ov.ttsOnShowEnabled = nil
                    ov.ttsOnHideEnabled = nil
                    if not ov.soundOnShowEnabled and not ov.soundOnHideEnabled then
                        ov.soundOnShowEnabled = true
                    end
                else
                    ov.soundOnShow = nil
                    ov.soundOnHide = nil
                    ov.soundOnShowEnabled = nil
                    ov.soundOnHideEnabled = nil
                end
                SaveAndRefresh()
                ShowSpellSettings(spellID, groupIndex)
            end
        )
        soundCheckbox:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 36

        if soundChecked then
            local ov = existingOv or {}

            local soundOnShowEnabled = ov.soundOnShowEnabled or false
            local soundOnShowCheckbox
            soundOnShowCheckbox = UI.CreateModernCheckbox(rc, L["On Show"] or "On Show", soundOnShowEnabled,
                function(checked)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if not o then return end
                    if not checked and o.soundOnHideEnabled == false then
                        soundOnShowCheckbox:SetChecked(true)
                        return
                    end
                    o.soundOnShowEnabled = checked
                    if not checked then o.soundOnShow = nil end
                    SaveAndRefresh()
                    ShowSpellSettings(spellID, groupIndex)
                end
            )
            soundOnShowCheckbox:SetPoint("TOPLEFT", 20, yOff)
            yOff = yOff - 30

            if soundOnShowEnabled then
                local showDropdown = RegisterRightPanelDropdown(
                    CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
                )
                showDropdown:SetWidth(220)
                showDropdown:SetPoint("TOPLEFT", 26, yOff)
                showDropdown:SetDefaultText(ov.soundOnShow or "None")
                UI.SetupMediaDropdown(showDropdown, "sound",
                    function() return ov.soundOnShow or "None" end,
                    function(name)
                        suppressPanelRefreshUntil = GetTime() + 0.15
                        local o = ensureOv()
                        local val = (name ~= "None") and name or nil
                        if o then o.soundOnShow = val end
                        ov.soundOnShow = val
                        showDropdown:SetDefaultText(name)
                        SaveAndRefresh()
                    end
                )
                yOff = yOff - 40
            end

            local soundOnHideEnabled = ov.soundOnHideEnabled or false
            local soundOnHideCheckbox
            soundOnHideCheckbox = UI.CreateModernCheckbox(rc, L["On Hide"] or "On Hide", soundOnHideEnabled,
                function(checked)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if not o then return end
                    if not checked and o.soundOnShowEnabled == false then
                        soundOnHideCheckbox:SetChecked(true)
                        return
                    end
                    o.soundOnHideEnabled = checked
                    if not checked then o.soundOnHide = nil end
                    SaveAndRefresh()
                    ShowSpellSettings(spellID, groupIndex)
                end
            )
            soundOnHideCheckbox:SetPoint("TOPLEFT", 20, yOff)
            yOff = yOff - 30

            if soundOnHideEnabled then
                local hideDropdown = RegisterRightPanelDropdown(
                    CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
                )
                hideDropdown:SetWidth(220)
                hideDropdown:SetPoint("TOPLEFT", 26, yOff)
                hideDropdown:SetDefaultText(ov.soundOnHide or "None")
                UI.SetupMediaDropdown(hideDropdown, "sound",
                    function() return ov.soundOnHide or "None" end,
                    function(name)
                        suppressPanelRefreshUntil = GetTime() + 0.15
                        local o = ensureOv()
                        local val = (name ~= "None") and name or nil
                        if o then o.soundOnHide = val end
                        ov.soundOnHide = val
                        hideDropdown:SetDefaultText(name)
                        SaveAndRefresh()
                    end
                )
                yOff = yOff - 40
            end
        end

        local ttsChecked = existingOv and existingOv.ttsEnabled or false
        local ttsCheckbox = UI.CreateModernCheckbox(
            rc,
            L["Text to Speech"] or "Text to Speech",
            ttsChecked,
            function(checked)
                suppressPanelRefreshUntil = GetTime() + 0.15
                local ov = ensureOv()
                if not ov then return end
                ov.ttsEnabled = checked or nil
                if checked then
                    ov.soundEnabled = nil
                    ov.soundOnShow = nil
                    ov.soundOnHide = nil
                    ov.soundOnShowEnabled = nil
                    ov.soundOnHideEnabled = nil
                    if not ov.ttsOnShowEnabled and not ov.ttsOnHideEnabled then
                        ov.ttsOnShowEnabled = true
                    end
                else
                    ov.ttsOnShow = nil
                    ov.ttsOnHide = nil
                    ov.ttsOnShowEnabled = nil
                    ov.ttsOnHideEnabled = nil
                end
                SaveAndRefresh()
                ShowSpellSettings(spellID, groupIndex)
            end
        )
        ttsCheckbox:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 36

        if ttsChecked then
            local ov = existingOv or {}

            local voiceBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
            voiceBtn:SetSize(120, 22)
            voiceBtn:SetText(L["Voice Settings"] or "Voice Settings")
            voiceBtn:SetPoint("LEFT", ttsCheckbox, "LEFT", 200, 0)
            voiceBtn:SetScript("OnClick", function()
                if ChatConfigFrame then
                    ChatConfigFrame:Show()
                    if ChatConfigFrameChatTabManager and VOICE_WINDOW_ID then
                        ChatConfigFrameChatTabManager:UpdateSelection(VOICE_WINDOW_ID)
                    end
                end
            end)

            local ttsOnShowEnabled = ov.ttsOnShowEnabled or false
            local ttsOnShowCheckbox
            ttsOnShowCheckbox = UI.CreateModernCheckbox(rc, L["On Show"] or "On Show", ttsOnShowEnabled,
                function(checked)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if not o then return end
                    if not checked and not o.ttsOnHideEnabled then
                        ttsOnShowCheckbox:SetChecked(true)
                        return
                    end
                    o.ttsOnShowEnabled = checked or nil
                    if not checked then o.ttsOnShow = nil end
                    SaveAndRefresh()
                    ShowSpellSettings(spellID, groupIndex)
                end
            )
            ttsOnShowCheckbox:SetPoint("TOPLEFT", 20, yOff)
            yOff = yOff - 30

            if ttsOnShowEnabled then
                local ttsShowBox = CreateFrame("EditBox", nil, rc, "InputBoxTemplate")
                ttsShowBox:SetSize(140, 22)
                ttsShowBox:SetPoint("TOPLEFT", 26, yOff)
                ttsShowBox:SetFontObject("AyijeCDM_Font14")
                ttsShowBox:SetAutoFocus(false)
                ttsShowBox:SetMaxLetters(200)
                ttsShowBox:SetText(ov.ttsOnShow or "")
                ttsShowBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                ttsShowBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                ttsShowBox:SetScript("OnEditFocusLost", function(self)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    local val = self:GetText()
                    val = (val ~= "") and val or nil
                    if o then o.ttsOnShow = val end
                    ov.ttsOnShow = val
                    SaveAndRefresh()
                end)
                local ttsShowHint = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
                ttsShowHint:SetText(L["(empty = spell name)"] or "(empty = spell name)")
                UI.SetTextMuted(ttsShowHint)
                ttsShowHint:SetPoint("LEFT", ttsShowBox, "RIGHT", 6, 0)
                yOff = yOff - 28
            end

            local ttsOnHideEnabled = ov.ttsOnHideEnabled or false
            local ttsOnHideCheckbox
            ttsOnHideCheckbox = UI.CreateModernCheckbox(rc, L["On Hide"] or "On Hide", ttsOnHideEnabled,
                function(checked)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if not o then return end
                    if not checked and not o.ttsOnShowEnabled then
                        ttsOnHideCheckbox:SetChecked(true)
                        return
                    end
                    o.ttsOnHideEnabled = checked or nil
                    if not checked then o.ttsOnHide = nil end
                    SaveAndRefresh()
                    ShowSpellSettings(spellID, groupIndex)
                end
            )
            ttsOnHideCheckbox:SetPoint("TOPLEFT", 20, yOff)
            yOff = yOff - 30

            if ttsOnHideEnabled then
                local ttsHideBox = CreateFrame("EditBox", nil, rc, "InputBoxTemplate")
                ttsHideBox:SetSize(140, 22)
                ttsHideBox:SetPoint("TOPLEFT", 26, yOff)
                ttsHideBox:SetFontObject("AyijeCDM_Font14")
                ttsHideBox:SetAutoFocus(false)
                ttsHideBox:SetMaxLetters(200)
                ttsHideBox:SetText(ov.ttsOnHide or "")
                ttsHideBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                ttsHideBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                ttsHideBox:SetScript("OnEditFocusLost", function(self)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    local val = self:GetText()
                    val = (val ~= "") and val or nil
                    if o then o.ttsOnHide = val end
                    ov.ttsOnHide = val
                    SaveAndRefresh()
                end)
                local ttsHideHint = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
                ttsHideHint:SetText(L["(empty = spell name)"] or "(empty = spell name)")
                UI.SetTextMuted(ttsHideHint)
                ttsHideHint:SetPoint("LEFT", ttsHideBox, "RIGHT", 6, 0)
                yOff = yOff - 28
            end
        end

        local textOvChecked = existingOv and existingOv.textOverride or false
        local textOvCheckbox = UI.CreateModernCheckbox(
            rc,
            L["Override Text Settings"] or "Override Text Settings",
            textOvChecked,
            function(checked)
                suppressPanelRefreshUntil = GetTime() + 0.15
                local ov = ensureOv()
                if not ov then return end
                ov.textOverride = checked or nil
                SaveAndRefresh()
                ShowSpellSettings(spellID, groupIndex)
            end
        )
        textOvCheckbox:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 36

        if textOvChecked then
            local ov = existingOv or {}

            local ovCdFS = CreateSlider(rc, L["Cooldown Size"] or "Cooldown Size", 6, 32,
                ov.cooldownFontSize or defaults.cooldownFontSize,
                function(v)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if o then o.cooldownFontSize = v end
                    SaveAndRefresh()
                end
            )
            ovCdFS:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 50

            local ovCdColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            ovCdColorLabel:SetText(L["Cooldown Color"] or "Cooldown Color")
            ovCdColorLabel:SetPoint("TOPLEFT", 0, yOff)

            local cdColorInit = ov.cooldownColor or defaults.cooldownColor or { r = 1, g = 1, b = 1 }
            local ovCdColorPicker = UI.CreateSimpleColorPicker(rc, cdColorInit, function(r, g, b)
                suppressPanelRefreshUntil = GetTime() + 0.15
                local o = ensureOv()
                if o then o.cooldownColor = { r = r, g = g, b = b } end
                SaveAndRefresh()
            end)
            ovCdColorPicker:SetPoint("LEFT", ovCdColorLabel, "RIGHT", 6, 0)
            yOff = yOff - 30

            local ovCountFS = CreateSlider(rc, L["Charge Size"] or "Charge Size", 6, 32,
                ov.countFontSize or defaults.countFontSize,
                function(v)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if o then o.countFontSize = v end
                    SaveAndRefresh()
                end
            )
            ovCountFS:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 50

            local ovCountColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            ovCountColorLabel:SetText(L["Charge Color"] or "Charge Color")
            ovCountColorLabel:SetPoint("TOPLEFT", 0, yOff)

            local countColorInit = ov.countColor or defaults.countColor or { r = 1, g = 1, b = 1 }
            local ovCountColorPicker = UI.CreateSimpleColorPicker(rc, countColorInit, function(r, g, b)
                suppressPanelRefreshUntil = GetTime() + 0.15
                local o = ensureOv()
                if o then o.countColor = { r = r, g = g, b = b } end
                SaveAndRefresh()
            end)
            ovCountColorPicker:SetPoint("LEFT", ovCountColorLabel, "RIGHT", 6, 0)
            yOff = yOff - 30

            local ovCountPosLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            ovCountPosLabel:SetText(L["Charge Position"] or "Charge Position")
            ovCountPosLabel:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 22

            local ovCountPosDropdown = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
            ovCountPosDropdown:SetWidth(180)
            ovCountPosDropdown:SetPoint("TOPLEFT", 0, yOff)
            ovCountPosDropdown:SetDefaultText(ov.countPosition or defaults.countPosition)
            UI.SetupPositionDropdown(ovCountPosDropdown,
                function() return ov.countPosition or defaults.countPosition end,
                function(val)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if o then o.countPosition = val end
                    ov.countPosition = val
                    ovCountPosDropdown:SetDefaultText(val)
                    SaveAndRefresh()
                end
            )
            yOff = yOff - 40

            local ovCountXSlider = CreateSlider(rc, L["Charge X Offset"] or "Charge X Offset", -20, 20,
                ov.countOffsetX or defaults.countOffsetX,
                function(v)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if o then o.countOffsetX = v end
                    SaveAndRefresh()
                end
            )
            ovCountXSlider:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 50

            local ovCountYSlider = CreateSlider(rc, L["Charge Y Offset"] or "Charge Y Offset", -20, 20,
                ov.countOffsetY or defaults.countOffsetY,
                function(v)
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    local o = ensureOv()
                    if o then o.countOffsetY = v end
                    SaveAndRefresh()
                end
            )
            ovCountYSlider:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 50
        end

        return yOff
    end

    ShowSpellSettings = function(spellID, groupIndex)
        pickerActiveGroupIndex = nil
        if not spellID or not currentSpecID then
            ClearRightPanel()
            return
        end

        local displaySpellID = spellID

        local _, rc = CreateRightScrollContent(700)

        local yOff = 0

        local iconContainer = CreateFrame("Frame", nil, rc)
        iconContainer:SetSize(28, 28)
        iconContainer:SetPoint("TOPLEFT", 0, yOff)

        local iconTex = iconContainer:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        local tex = C_Spell.GetSpellTexture(displaySpellID)
        if tex then iconTex:SetTexture(tex) end
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            CDM.BORDER:CreateBorder(iconContainer)
            if CDM.BORDER.activeBorders then
                CDM.BORDER.activeBorders[iconContainer] = nil
            end
        end

        local existingColor = CDM.SpellRegistry and CDM.SpellRegistry:GetColor(currentSpecID, spellID)
        if existingColor and iconContainer.border then
            iconContainer.border:SetBackdropBorderColor(existingColor.r, existingColor.g, existingColor.b, 1)
        end

        local spellName = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        spellName:SetPoint("LEFT", iconContainer, "RIGHT", 8, 0)
        spellName:SetText(C_Spell.GetSpellName(displaySpellID) or L["Unknown"])
        spellName:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 40

        local borderLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        borderLabel:SetText(L["Border:"])
        borderLabel:SetPoint("TOPLEFT", 0, yOff)

        local configR, configG, configB = GetConfiguredBorderColor()
        local colorInit = existingColor and
            { r = existingColor.r or configR, g = existingColor.g or configG, b = existingColor.b or configB }
            or { r = configR, g = configG, b = configB }
        local borderColorPicker = UI.CreateSimpleColorPicker(rc, colorInit, function(r, g, b)
            suppressPanelRefreshUntil = GetTime() + 0.15
            API:SaveSpell(currentSpecID, spellID, { r = r, g = g, b = b, a = 1 })
            API:RefreshConfig()
            if iconContainer.border then
                iconContainer.border:SetBackdropBorderColor(r, g, b, 1)
            end
            local leftBorder = spellIconBorders[spellID]
            if leftBorder then
                leftBorder:SetBackdropBorderColor(r, g, b, 1)
            end
        end)
        borderColorPicker:SetPoint("LEFT", borderLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local resetHint = rc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        resetHint:SetPoint("TOPLEFT", 0, yOff)
        resetHint:SetText(L["Right-click icon to reset border color"])
        UI.SetTextFaint(resetHint)
        yOff = yOff - 24

        iconContainer:EnableMouse(true)
        iconContainer:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                suppressPanelRefreshUntil = GetTime() + 0.15
                API:ClearSpellBorderColor(currentSpecID, spellID)
                API:RefreshConfig()
                ApplyConfiguredBorderColor(iconContainer.border)
                local leftBorder = spellIconBorders[spellID]
                if leftBorder then
                    ApplyConfiguredBorderColor(leftBorder)
                end
                ShowSpellSettings(spellID, groupIndex)
            end
        end)

        local glowEnabled = API:GetSpellGlowEnabled(currentSpecID, spellID)
        local glowCheckbox = UI.CreateModernCheckbox(
            rc,
            L["Enable Glow"],
            glowEnabled,
            function(checked)
                suppressPanelRefreshUntil = GetTime() + 0.15
                API:SetSpellGlowEnabled(currentSpecID, spellID, checked or nil)
            end
        )
        glowCheckbox:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 36

        local glowColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        glowColorLabel:SetText(L["Glow Color:"])
        glowColorLabel:SetPoint("TOPLEFT", 0, yOff)

        local existingGlowColor = API:GetSpellGlowColor(currentSpecID, spellID) or { r = 1, g = 1, b = 1 }
        local glowColorPicker = UI.CreateSimpleColorPicker(rc, existingGlowColor, function(r, g, b)
            suppressPanelRefreshUntil = GetTime() + 0.15
            API:SetSpellGlowColor(currentSpecID, spellID, { r = r, g = g, b = b })
        end)
        glowColorPicker:SetPoint("LEFT", glowColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        if groupIndex then
            local groups = GetSpecGroups()
            local gd = groups and groups[groupIndex]
            if gd then
                yOff = BuildOverrideSection(rc, yOff, spellID, groupIndex,
                    GetMergedOverride(gd.spellOverrides, spellID),
                    function() return EnsureSpellOverride(groupIndex, spellID) end,
                    {
                        cooldownFontSize = gd.cooldownFontSize or 12,
                        cooldownColor = gd.cooldownColor,
                        countFontSize = gd.countFontSize or 15,
                        countColor = gd.countColor,
                        countPosition = gd.countPosition or "BOTTOMRIGHT",
                        countOffsetX = gd.countOffsetX or 0,
                        countOffsetY = gd.countOffsetY or 0,
                    },
                    { isStatic = gd.staticDisplay or false }
                )
            end
        end

        if not groupIndex then
            yOff = BuildOverrideSection(rc, yOff, spellID, groupIndex,
                GetUngroupedOverride(spellID),
                function() return EnsureUngroupedOverrideEntry(spellID) end,
                {
                    cooldownFontSize = CDM.db.buffCooldownFontSize or 12,
                    cooldownColor = CDM.db.buffCooldownColor,
                    countFontSize = CDM.db.countFontSize or 15,
                    countColor = CDM.db.countColor,
                    countPosition = CDM.db.countPositionMain or "TOP",
                    countOffsetX = CDM.db.countOffsetXMain or 0,
                    countOffsetY = CDM.db.countOffsetYMain or 0,
                },
                nil
            )
        end

        rc:SetHeight(math.abs(yOff) + 20)
    end

    local addGroupBtnRef = nil
    local addIconBtnRef = nil
    local ShowSpellPickerPanel
    local ICON_SIZE = 30
    local ROW_HEIGHT = 36
    local SECTION_GAP = 0
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
        highlight:SetColorTexture(0.2, 0.4, 0.8, 0.2)
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
        return {
            root = emptyFrame,
            text = emptyText,
        }
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
            removeBtnText = removeBtnText,
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
            ApplyConfiguredBorderColor(widget.iconContainer.border)
        end
    end)

    local ungroupedHeader = UI.CreateHeader(leftChild, L["Ungrouped Buffs"])
    local ungroupedSettingsBtn = CreateFrame("Button", nil, leftChild)
    ungroupedSettingsBtn:SetSize(27, 27)
    ungroupedSettingsBtn:SetNormalAtlas("common-dropdown-a-button-settings-shadowless")
    ungroupedSettingsBtn:SetHighlightAtlas("common-dropdown-a-button-settings-hover-shadowless")
    ungroupedSettingsBtn:SetPushedAtlas("common-dropdown-a-button-settings-pressed-shadowless")
    ungroupedSettingsBtn:SetScript("OnClick", function()
        ungroupedSelected = true
        selectedGroupIndex = nil
        selectedSpellID = nil
        ShowUngroupedSettings()
        RefreshLeftPanelIfNeeded()
    end)

    local ungroupedContainer = CreateFrame("Frame", nil, leftChild)
    ungroupedContainer:SetSize(LEFT_WIDTH, 10)
    local ungroupedHighlight = ungroupedContainer:CreateTexture(nil, "BACKGROUND")
    ungroupedHighlight:SetAllPoints()
    ungroupedHighlight:SetColorTexture(0.2, 0.6, 0.2, 0.2)
    ungroupedHighlight:Hide()
    ungroupedContainer.highlight = ungroupedHighlight

    local ungroupedCacheMessage = leftChild:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    UI.SetTextFaint(ungroupedCacheMessage)
    ungroupedCacheMessage:Hide()

    local function UpdateAddIconButtonState()
        if addIconBtnRef then
            addIconBtnRef:SetEnabled(selectedGroupIndex ~= nil)
        end
    end

    ShowSpellPickerPanel = function(groupIndex)
        pickerActiveGroupIndex = groupIndex
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
            isCacheMissing = currentSpecID ~= playerSpecID and not API:GetSpecBuffSpellCache(currentSpecID),
            cacheMissingText = string.format(L["Log %s to build spell list"] or "Log %s to build spell list", select(2, GetSpecializationInfoByID(currentSpecID)) or "this spec"),
            emptyText = currentSpecID == playerSpecID
                and (L["No untracked buff icons available for this spec"] or "No untracked buff icons available for this spec")
                or (L["All available icons are assigned to groups"] or "All available icons are assigned to groups"),
            onSelect = function(sid)
                local currentGroups = EnsureBuffGroups()
                if not currentGroups or not currentGroups[groupIndex] then return end
                if not currentGroups[groupIndex].spells then
                    currentGroups[groupIndex].spells = {}
                end
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

        local iconContainer = widget.iconContainer
        local iconTex = widget.iconTex
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then
            iconTex:SetTexture(tex)
        end
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())

        if iconContainer.border then
            ApplyConfiguredBorderColor(iconContainer.border)
            spellIconBorders[spellID] = iconContainer.border
        end

        if currentSpecID and CDM.SpellRegistry then
            local color = CDM.SpellRegistry:GetColor(currentSpecID, spellID)
            if color and iconContainer.border then
                iconContainer.border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
            end
        end

        if isActive == false then
            iconTex:SetDesaturated(true)
            iconTex:SetAlpha(0.5)
            if iconContainer.border then
                iconContainer.border:SetAlpha(0.5)
                iconContainer.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            end
        else
            iconTex:SetDesaturated(false)
            iconTex:SetAlpha(1)
            if iconContainer.border then
                iconContainer.border:SetAlpha(1)
            end
        end

        local removeBtn = widget.removeBtn
        removeBtn:Hide()
        removeBtn:SetScript("OnClick", nil)
        if sourceGroup then
            removeBtn:Show()
            removeBtn:SetScript("OnClick", function()
                local groups = GetSpecGroups()
                if not groups or not groups[sourceGroup] then return end
                local srcGroup = groups[sourceGroup]
                local spells = srcGroup.spells
                if spells then
                    RemoveSpellFromGroupList(spells, spellID)
                end
                local srcOvData
                if srcGroup.spellOverrides then
                    srcOvData = ExtractMergedOverrideEntry(srcGroup.spellOverrides, spellID)
                end
                if srcOvData then
                    local specOv = EnsureUngroupedOverrides()
                    if specOv then
                        StoreMergedOverrideEntry(specOv, spellID, srcOvData)
                    end
                end
                if selectedSpellID == spellID then
                    selectedSpellID = nil
                    selectedSpellGroupIndex = nil
                    ClearRightPanel()
                end
                SaveRefreshAndMaybeRebuildLeft()
                if pickerActiveGroupIndex then
                    ShowSpellPickerPanel(pickerActiveGroupIndex)
                end
            end)
        end

        local nameText = widget.nameText
        nameText:ClearAllPoints()
        nameText:SetPoint("LEFT", iconContainer, "RIGHT", 6, 0)
        nameText:SetPoint("RIGHT", removeBtn:IsShown() and removeBtn or row, removeBtn:IsShown() and "LEFT" or "RIGHT", removeBtn:IsShown() and -2 or -4, 0)
        nameText:SetText(C_Spell.GetSpellName(spellID) or L["Unknown"])
        if isActive == false then
            UI.SetTextMuted(nameText)
        elseif selectedSpellID == spellID then
            UI.SetTextWhite(nameText)
        else
            UI.SetTextSubtle(nameText)
        end

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

        widget.clickBtn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if currentSpecID then
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    API:ClearSpellBorderColor(currentSpecID, spellID)
                    API:RefreshConfig()
                end
                if iconContainer.border then
                    ApplyConfiguredBorderColor(iconContainer.border)
                end
                if selectedSpellID == spellID then
                    ShowSpellSettings(spellID, sourceGroup)
                end
                RefreshLeftPanelIfNeeded()
                return
            end
            selectedSpellID = spellID
            selectedGroupIndex = nil
            selectedSpellGroupIndex = sourceGroup
            ungroupedSelected = false
            ShowSpellSettings(spellID, sourceGroup)
            RefreshLeftPanelIfNeeded()
        end)
        widget.clickBtn:SetScript("OnDragStart", function()
            StartDrag(spellID, sourceGroup)
        end)
        widget.clickBtn:SetScript("OnDragStop", function()
            EndDrag()
        end)

        return widget
    end

    local function BuildLeftPanel()
        if renameActiveGroupIndex and renameActiveEditBox then
            local newName = renameActiveEditBox:GetText()
            local groups = GetSpecGroups()
            local gd = groups and groups[renameActiveGroupIndex]
            if gd and newName and newName ~= "" then
                gd.name = newName
            end
            renameActiveGroupIndex = nil
            renameActiveEditBox = nil
        end

        table.wipe(spellIconBorders)
        local lc = leftChild
        headerPool:ReleaseAll()
        groupContainerPool:ReleaseAll()
        spellRowPool:ReleaseAll()
        emptyRowPool:ReleaseAll()
        ClearDropTargets()
        ungroupedHighlight:Hide()
        ungroupedCacheMessage:Hide()

        local isViewingPlayer = IsViewingPlayerSpec()
        local activeSpellSet = isViewingPlayer and BuildActiveSpellSet() or nil

        local yOff = 0

        if not addGroupBtnRef then
            local addGroupBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            addGroupBtn:SetSize(90, 22)
            addGroupBtn:SetPoint("BOTTOMLEFT", leftScroll, "TOPLEFT", SCROLL_LEFT_PAD, 8)
            addGroupBtn:SetText(L["Add Group"])
            addGroupBtn:SetScript("OnClick", function()
                local specGroups = EnsureBuffGroups()
                if not specGroups then return end

                local newIndex = #specGroups + 1
                local defs = CDM.defaults or {}
                local sizeBuff = defs.sizeBuff or { w = 40, h = 36 }
                specGroups[newIndex] = {
                    name = "Group " .. newIndex,
                    spells = {},
                    grow = "CENTER_H",
                    spacing = 1,
                    iconWidth = sizeBuff.w,
                    iconHeight = sizeBuff.h,
                    cooldownFontSize = defs.buffCooldownFontSize or 15,
                    cooldownColor = { r = 1, g = 1, b = 1 },
                    countFontSize = defs.countFontSize or 15,
                    countColor = { r = 1, g = 1, b = 1, a = 1 },
                    countPosition = "BOTTOMRIGHT",
                    countOffsetX = 0,
                    countOffsetY = 0,
                    anchorTarget = "screen",
                    anchorPoint = "CENTER",
                    anchorRelativeTo = "CENTER",
                    offsetX = 0,
                    offsetY = 0,
                }
                expandedGroups[newIndex] = true
                selectedGroupIndex = newIndex
                selectedSpellID = nil
                ungroupedSelected = false
                SaveRefreshAndMaybeRebuildLeft()
                ShowGroupSettings(newIndex)
            end)
            addGroupBtnRef = addGroupBtn
        end

        if not addIconBtnRef then
            local addIconBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            addIconBtn:SetSize(90, 22)
            addIconBtn:SetText(L["Add Icon"])
            addIconBtn:SetScript("OnClick", function()
                if selectedGroupIndex then
                    ShowSpellPickerPanel(selectedGroupIndex)
                end
            end)
            addIconBtnRef = addIconBtn
        end
        addIconBtnRef:SetPoint("LEFT", addGroupBtnRef, "RIGHT", 6, 0)
        addIconBtnRef:SetEnabled(selectedGroupIndex ~= nil)

        ungroupedHeader:ClearAllPoints()
        ungroupedHeader:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)
        if isViewingPlayer then
            if ungroupedSelected then
                ungroupedHeader:SetTextColor(1, 1, 1, 1)
            else
                ungroupedHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
            end
            ungroupedSettingsBtn:Show()
            ungroupedSettingsBtn:ClearAllPoints()
            ungroupedSettingsBtn:SetPoint("LEFT", ungroupedHeader, "RIGHT", 6, -4)

            yOff = yOff - 24
            ungroupedContainer:ClearAllPoints()
            ungroupedContainer:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)
            RegisterDropTarget(ungroupedContainer, nil)

            local ungrouped = GetUngroupedBuffSpells()
            local ungroupedY = 0
            for _, spellID in ipairs(ungrouped) do
                local active = not isViewingPlayer or HasEquivalentSpellID(activeSpellSet, spellID)
                ConfigureSpellRow(spellRowPool:Acquire(ungroupedContainer), ungroupedContainer, spellID, nil, ungroupedY, active)
                ungroupedY = ungroupedY - ROW_HEIGHT
            end

            if #ungrouped == 0 then
                AcquireEmptyRow(ungroupedContainer, L["No ungrouped buffs"])
                ungroupedY = -ROW_HEIGHT
            end

            ungroupedContainer:SetHeight(math.abs(ungroupedY) + 4)
            yOff = yOff + ungroupedY - SECTION_GAP
        else
            UI.SetTextMuted(ungroupedHeader)
            ungroupedSettingsBtn:Hide()
            yOff = yOff - 24
            ungroupedContainer:ClearAllPoints()
            ungroupedContainer:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)
            RegisterDropTarget(ungroupedContainer, nil)

            local cachedSpells = GetUngroupedBuffSpellsFromCache(currentSpecID)
            local ungroupedY = 0
            if cachedSpells == nil then
                ungroupedCacheMessage:ClearAllPoints()
                ungroupedCacheMessage:SetPoint("TOPLEFT", SCROLL_LEFT_PAD + 8, yOff)
                local _, specName = GetSpecializationInfoByID(currentSpecID)
                ungroupedCacheMessage:SetText(string.format(L["Log %s to build spell list"] or "Log %s to build spell list", specName or "this spec"))
                ungroupedCacheMessage:Show()
                ungroupedY = -ROW_HEIGHT
            elseif #cachedSpells == 0 then
                AcquireEmptyRow(ungroupedContainer, L["No ungrouped buffs"])
                ungroupedY = -ROW_HEIGHT
            else
                for _, spellID in ipairs(cachedSpells) do
                    ConfigureSpellRow(spellRowPool:Acquire(ungroupedContainer), ungroupedContainer, spellID, nil, ungroupedY, nil)
                    ungroupedY = ungroupedY - ROW_HEIGHT
                end
            end

            ungroupedContainer:SetHeight(math.abs(ungroupedY) + 4)
            yOff = yOff + ungroupedY - SECTION_GAP
        end

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

                h.selectBtn:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then
                        MenuUtil.CreateContextMenu(h.selectBtn, function(_, rootDescription)
                            Shared.BuildGroupContextMenu(rootDescription,
                                { rename = L["Rename"], duplicate = L["Duplicate"], copyTo = L["Copy to"] },
                                function()
                                    renameActiveGroupIndex = groupIndex
                                    RefreshLeftPanelIfNeeded()
                                end,
                                function()
                                    local specGroups = EnsureBuffGroups()
                                    if not specGroups then return end
                                    local newIdx = DuplicateGroup(groupData, specGroups)
                                    expandedGroups[newIdx] = true
                                    selectedGroupIndex = newIdx
                                    selectedSpellID = nil
                                    ungroupedSelected = false
                                    if IsViewingPlayerSpec() then
                                        SaveStructuralRefresh()
                                    end
                                    ShowGroupSettings(newIdx)
                                    RefreshLeftPanelIfNeeded()
                                end,
                                function(specID)
                                    CopyGroupSettingsToSpec(groupData, specID)
                                    if specID == currentSpecID then
                                        RefreshLeftPanelIfNeeded()
                                    end
                                    if specID == playerSpecID then
                                        SaveStructuralRefresh()
                                    end
                                end
                            )
                        end)
                        return
                    end
                    local now = GetTime()
                    if renameLastClickGroup == groupIndex and (now - renameLastClickTime) < 0.4 then
                        renameLastClickTime = 0
                        renameLastClickGroup = nil
                        renameActiveGroupIndex = groupIndex
                        RefreshLeftPanelIfNeeded()
                        return
                    end
                    renameLastClickTime = now
                    renameLastClickGroup = groupIndex
                    selectedGroupIndex = groupIndex
                    selectedSpellID = nil
                    ungroupedSelected = false
                    ShowGroupSettings(groupIndex)
                    RefreshLeftPanelIfNeeded()
                end)

                h.expandBtn:SetScript("OnClick", function()
                    expandedGroups[groupIndex] = not isExpanded
                    selectedGroupIndex = groupIndex
                    selectedSpellID = nil
                    ungroupedSelected = false
                    ShowGroupSettings(groupIndex)
                    RefreshLeftPanelIfNeeded()
                end)

                h.deleteBtn:SetScript("OnClick", function()
                    local function DoDelete()
                        local specGroups = EnsureBuffGroups()
                        if specGroups then
                            local gd = specGroups[groupIndex]
                            if gd and gd.spells and gd.spellOverrides then
                                local specOv = EnsureUngroupedOverrides()
                                if specOv then
                                    for _, sid in ipairs(gd.spells) do
                                        local ovData = ExtractMergedOverrideEntry(gd.spellOverrides, sid)
                                        if ovData then
                                            StoreMergedOverrideEntry(specOv, sid, ovData)
                                        end
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
                        local dialog = StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_GROUP"]
                        dialog.text = string.format(
                            L["Delete group with %d spell(s)?"] or "Delete group with %d spell(s)?",
                            spellCount
                        )
                        dialog._pendingDelete = DoDelete
                        StaticPopup_Show("AYIJE_CDM_CONFIRM_DELETE_GROUP")
                    else
                        DoDelete()
                    end
                end)

                yOff = yOff - GROUP_HEADER_H

                if isExpanded then
                    local groupContainerWidget = groupContainerPool:Acquire(lc)
                    local groupContainer = groupContainerWidget.root
                    groupContainer:ClearAllPoints()
                    groupContainer:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)
                    RegisterDropTarget(groupContainer, groupIndex)
                    local spellY = 0
                    if groupData.spells then
                        local spellCount = #groupData.spells
                        for spellIdx, spellID in ipairs(groupData.spells) do
                            local active = not isViewingPlayer or HasEquivalentSpellID(activeSpellSet, spellID)
                            ConfigureSpellRow(
                                spellRowPool:Acquire(groupContainer),
                                groupContainer,
                                spellID,
                                groupIndex,
                                spellY,
                                active,
                                spellIdx,
                                spellCount
                            )
                            spellY = spellY - ROW_HEIGHT
                        end
                    end

                    if not groupData.spells or #groupData.spells == 0 then
                        AcquireEmptyRow(groupContainer, L["Drag spells here"])
                        spellY = -ROW_HEIGHT
                    end

                    groupContainer:SetHeight(math.abs(spellY) + 4)
                    yOff = yOff + spellY - SECTION_GAP
                end
            end
        end

        lc:SetHeight(math.abs(yOff) + 4)
        UpdateAddIconButtonState()
    end

    RefreshAll = function()
        BuildLeftPanel()
    end

    local specDropdown, RefreshSpecDropdownText = Shared.CreateSpecDropdown(page, "TOPRIGHT", -6, -8, {
        getPlayerSpecID = function() return playerSpecID end,
        getCurrentSpecID = function() return currentSpecID end,
        onSelectionChange = function(specID)
            currentSpecID = specID
            selectedGroupIndex = nil
            selectedSpellID = nil
            selectedSpellGroupIndex = nil
            ungroupedSelected = false
            ClearRightPanel()
            BuildLeftPanel()
        end,
    })

    local RegisterViewerCallbacks, UnregisterViewerCallbacks = Shared.CreateViewerSettingsCallbacks(QueueLeftPanelRefresh)

    page:SetScript("OnMouseUp", function()
        EndDrag()
    end)

    page:HookScript("OnHide", function()
        rightPanelManager.CloseDropdownMenus()
        CancelDrag()
        UnregisterViewerCallbacks()
    end)

    page:HookScript("OnShow", function()
        local si = GetSpecialization()
        local prevSpecID = currentSpecID
        playerSpecID = si and GetSpecializationInfo(si) or nil
        currentSpecID = playerSpecID
        RefreshSpecDropdownText()
        RegisterViewerCallbacks()
        if currentSpecID ~= prevSpecID then
            selectedGroupIndex = nil
            selectedSpellGroupIndex = nil
            selectedSpellID = nil
            ungroupedSelected = false
            ClearRightPanel()
        end
        BuildLeftPanel()
        if ungroupedSelected then
            ShowUngroupedSettings()
        elseif selectedGroupIndex then
            ShowGroupSettings(selectedGroupIndex)
        elseif selectedSpellID then
            ShowSpellSettings(selectedSpellID, selectedSpellGroupIndex)
        end
    end)

    API:RegisterRefreshCallback("buffgroups-spec-refresh", function()
        if not page:IsShown() then return end
        if GetTime() < suppressPanelRefreshUntil then return end
        RefreshCurrentSpecID()
        QueueLeftPanelRefresh(0)
    end, 30, { "spec_data", "trackers_layout", "viewers" })

end

API:RegisterConfigTab("buffgroups", L["Buff Groups"], CreateBuffGroupsTab, 8)
