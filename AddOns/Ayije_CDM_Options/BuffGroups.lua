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
local SaveAndRefresh = Shared.SaveVisualRefresh
local SaveStructuralRefresh = Shared.SaveVisualRefresh
local GetConfiguredBorderColor = Shared.GetConfiguredBorderColor
local ApplyConfiguredBorderColor = Shared.ApplyConfiguredBorderColor
local DestroyFrame = Shared.DestroyFrame
local CreateSlider = Shared.CreateSlider
local LEFT_INSET = Shared.LEFT_INSET
local LEFT_WIDTH = Shared.LEFT_WIDTH
local SCROLL_LEFT_PAD = Shared.SCROLL_LEFT_PAD
local RIGHT_X = Shared.RIGHT_X
local ICON_SIZE = 30
local ROW_HEIGHT = 36
local GROUP_HEADER_H = 28
local ARROW_BTN_SIZE = 29

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
    local si = GetSpecialization()
    local currentSpecID = si and GetSpecializationInfo(si) or nil
    local playerSpecID = currentSpecID

    local selectedGroupIndex = nil
    local selectedSpellID = nil
    local selectedSpellGroupIndex = nil
    local expandedGroups = {}
    local RefreshAll
    local ShowSpellSettings
    local GetCustomBuffEntry
    local IsCustomBuffSpell
    local renameLastClickTime = 0
    local renameLastClickGroup = nil
    local renameActiveGroupIndex = nil
    local renameActiveEditBox = nil
    local suppressPanelRefreshUntil = 0
    local ungroupedSelected = false
    local pickerActiveGroupIndex = nil

    local _helpers = Shared.CreateGroupEditorHelpers({
        dbKey = "buffGroups",
        ungroupedDbKey = "ungroupedBuffOverrides",
        getCurrentSpecID = function() return currentSpecID end,
        setCurrentSpecID = function(v) currentSpecID = v end,
        getPlayerSpecID = function() return playerSpecID end,
        setPlayerSpecID = function(v) playerSpecID = v end,
        normalizeToBase = NormalizeToBase,
        extraCloneFields = { "staticDisplay", "countFontSize", "countColor", "countPosition", "countOffsetX", "countOffsetY" },
    })
    local RefreshCurrentSpecID = _helpers.RefreshCurrentSpecID
    local EnsureBuffGroups = _helpers.EnsureGroups
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

    local function BuildActiveSpellSet()
        if API.BuildActiveSpellSet then
            return API:BuildActiveSpellSet()
        end
        return {}
    end

    local function IsSpellInActiveSet(activeSet, spellID)
        if not activeSet then return false end
        return activeSet[spellID] == true
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
                        Shared.MarkEquivalentSpellIDs(groupedSet, groupedSpellID)
                    end
                end
            end
        end

        for frame in buffViewer.itemFramePool:EnumerateActive() do
            local matchType = API.GetBuffRegistryMatch and API:GetBuffRegistryMatch(frame) or nil
            if not matchType then
                local displayID
                local info = frame.GetCooldownInfo and frame:GetCooldownInfo() or frame.cooldownInfo
                if info then
                    displayID = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
                end
                if not IsSafeNumber(displayID) then
                    displayID = frame.GetBaseSpellID and frame:GetBaseSpellID()
                end
                if not IsSafeNumber(displayID) then
                    displayID = API.GetPreferredBuffGroupSpellID and API:GetPreferredBuffGroupSpellID(frame)
                end
                if not IsSafeNumber(displayID) and API.GetBaseSpellID then
                    displayID = API:GetBaseSpellID(frame)
                end
                local hiddenBuffSet = CDM.resourcesHiddenBuffSet
                if IsSafeNumber(displayID)
                    and not Shared.HasEquivalentSpellID(groupedSet, displayID)
                    and not seen[displayID]
                    and not Shared.HasEquivalentSpellID(hiddenBuffSet, displayID)
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
        return icons
    end

    local QueueLeftPanelRefresh = Shared.CreateQueueLeftPanelRefresh(page, function() return RefreshAll end)

    local RegisterDropTarget, ClearDropTargets, StartDrag, EndDrag, CancelDrag
    do
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
                        Shared.RemoveSpellFromGroupList(srcGroup.spells, spellID)
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
                        local storedSpellID = Shared.AddSpellToGroupList(tgtGroup.spells, spellID) or spellID
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
        RegisterDropTarget = dragDrop.RegisterDropTarget
        ClearDropTargets = dragDrop.ClearDropTargets
        StartDrag = dragDrop.StartDrag
        EndDrag = dragDrop.EndDrag
        CancelDrag = dragDrop.CancelDrag
    end

    local leftScroll = CreateFrame("ScrollFrame", "AyijeCDM_BuffGroupsLeftScroll", page, "ScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", LEFT_INSET - SCROLL_LEFT_PAD, -56)
    leftScroll:SetPoint("BOTTOMLEFT", LEFT_INSET - SCROLL_LEFT_PAD, 20)
    leftScroll:SetWidth(LEFT_WIDTH + SCROLL_LEFT_PAD)

    local leftChild = CreateFrame("Frame", nil, leftScroll)
    leftChild:SetSize(LEFT_WIDTH + SCROLL_LEFT_PAD, 1200)
    leftScroll:SetScrollChild(leftChild)

    local rightPanel = CreateFrame("Frame", nil, page)
    rightPanel:SetPoint("TOPLEFT", RIGHT_X, -40)
    rightPanel:SetPoint("BOTTOMRIGHT", -10, 20)

    local rightPlaceholder = rightPanel:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    rightPlaceholder:SetPoint("TOP", 0, -20)
    rightPlaceholder:SetText(L["Select a group or spell to edit settings"])
    UI.SetTextMuted(rightPlaceholder)

    local rightPanelManager = Shared.CreateRightPanelManager(rightPanel, rightPlaceholder, DestroyFrame)
    local RegisterRightPanelDropdown = rightPanelManager.RegisterDropdown
    local CreateRightScrollContent = rightPanelManager.CreateScrollContent
    local ClearRightPanel = function()
        pickerActiveGroupIndex = nil
        rightPanelManager.Clear()
    end

    local function GetViewerSpellListForSpec(specID)
        if specID == playerSpecID then
            local seen, list = {}, {}
            local ids = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, true)
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
                local candidates = API.GetSpellIDCandidates and API:GetSpellIDCandidates(frame)
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
                    local sid = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
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
                    Shared.MarkEquivalentSpellIDs(assigned, sid)
                end
            end
        end
        local hiddenBuffSet = CDM.resourcesHiddenBuffSet
        local seen = {}
        local result = {}
        for _, spellID in ipairs(allSpells) do
            if not Shared.HasEquivalentSpellID(assigned, spellID)
                and not seen[spellID]
                and not Shared.HasEquivalentSpellID(hiddenBuffSet, spellID)
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
                    Shared.MarkEquivalentSpellIDs(assigned, sid)
                end
            end
        end

        local hiddenBuffSet = CDM.resourcesHiddenBuffSet
        local seen = {}
        local result = {}
        for _, spellID in ipairs(allSpells) do
            if not Shared.HasEquivalentSpellID(assigned, spellID)
                and not seen[spellID]
                and not Shared.HasEquivalentSpellID(hiddenBuffSet, spellID)
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
        if not groups or not groups[groupIndex] then ClearRightPanel(); return end
        local _, rc = CreateRightScrollContent(700)
        Shared.RenderGroupSettingsPanel({
            rc = rc, gd = groups[groupIndex], groupIndex = groupIndex,
            registerDropdown = RegisterRightPanelDropdown,
            saveAndRefresh = SaveAndRefresh, createSlider = CreateSlider, L = L,
            preSpacingSection = function(parent, yOff)
                local cb = UI.CreateModernCheckbox(parent, L["Static Display"] or "Static Display",
                    groups[groupIndex].staticDisplay or false,
                    function(checked) groups[groupIndex].staticDisplay = checked or nil; SaveAndRefresh() end)
                cb:SetPoint("TOPLEFT", 0, yOff)
                return yOff - 36
            end,
            textFields = {
                sizeKey = "countFontSize", colorKey = "countColor",
                posKey = "countPosition", xKey = "countOffsetX", yKey = "countOffsetY",
                sizeDefault = 15, posDefault = "BOTTOMRIGHT",
            },
            anchorTargets = {
                { label = L["Screen"] or "Screen", value = "screen" },
                { label = L["Player Frame"] or "Player Frame", value = "playerFrame" },
                { label = L["Essential Viewer"] or "Essential Viewer", value = "essential" },
                { label = L["Buff Viewer"] or "Buff Viewer", value = "buff" },
            },
            anchorRelLabels = {
                playerFrame = L["Player Frame Point"] or "Player Frame Point",
                buff = L["Buff Viewer Point"] or "Buff Viewer Point",
            },
        })
    end

    local spellIconBorders = {}

    local function BuildOverrideSection(rc, yOff, spellID, groupIndex, existingOv, ensureOv, defaults, placeholderOpts, isCustomBuff)
        yOff = yOff - 10
        local overrideHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        overrideHeader:SetPoint("TOPLEFT", 0, yOff)
        overrideHeader:SetText(L["Per-Spell Overrides"] or "Per-Spell Overrides")
        overrideHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 34

        local hideCdChecked = existingOv and existingOv.hideCooldown or false
        local hideVisualsChecked = existingOv and existingOv.hideVisuals or false
        local hideCdCheckbox, hideVisualsCheckbox

        if not isCustomBuff then
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
                        if hideVisualsCheckbox then hideVisualsCheckbox:SetChecked(false) end
                    end
                    SaveAndRefresh()
                end
            )
            hideCdCheckbox:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 36
        end

        if not isCustomBuff then
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
                        if hideCdCheckbox then hideCdCheckbox:SetChecked(false) end
                    end
                    SaveAndRefresh()
                end
            )
            hideVisualsCheckbox:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 36
        end

        if placeholderOpts and not isCustomBuff then
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

        if not isCustomBuff then
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
        end -- not isCustomBuff (text overrides)

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
        local cbEntry = GetCustomBuffEntry(displaySpellID)
        local tex = (cbEntry and cbEntry.icon) or C_Spell.GetSpellTexture(displaySpellID)
        if tex then iconTex:SetTexture(tex) end
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            CDM.BORDER:CreateBorder(iconContainer)
            if CDM.BORDER.activeBorders then
                CDM.BORDER.activeBorders[iconContainer] = nil
            end
        end

        local existingColor = CDM.GetSpellBorderColor and CDM:GetSpellBorderColor(currentSpecID, spellID)
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
            API:Refresh()
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
                API:Refresh()
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

        local isCustom = IsCustomBuffSpell(spellID)

        if isCustom then
            local cbEntry = GetCustomBuffEntry(spellID)
            if not (cbEntry and cbEntry.triggerType) then
                yOff = yOff - 10

                local sidLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                sidLabel:SetPoint("TOPLEFT", 0, yOff)
                sidLabel:SetText(L["Spell ID:"] or "Spell ID:")

                local sidInput = CreateFrame("EditBox", nil, rc, "InputBoxTemplate")
                sidInput:SetSize(100, 20)
                sidInput:SetPoint("LEFT", sidLabel, "RIGHT", 6, 0)
                sidInput:SetAutoFocus(false)
                sidInput:SetNumeric(true)
                sidInput:SetMaxLetters(10)
                sidInput:SetText(tostring(spellID))
                yOff = yOff - 28

                local durLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                durLabel:SetPoint("TOPLEFT", 0, yOff)
                durLabel:SetText(L["Duration (sec):"] or "Duration (sec):")

                local durInput = CreateFrame("EditBox", nil, rc, "InputBoxTemplate")
                durInput:SetSize(60, 20)
                durInput:SetPoint("LEFT", durLabel, "RIGHT", 6, 0)
                durInput:SetAutoFocus(false)
                durInput:SetNumeric(true)
                durInput:SetMaxLetters(5)
                durInput:SetText(tostring(cbEntry and cbEntry.duration or ""))
                yOff = yOff - 28

                local saveBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
                saveBtn:SetSize(80, 22)
                saveBtn:SetPoint("TOPLEFT", 0, yOff)
                saveBtn:SetText(L["Save"] or "Save")

                local cbStatusText = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
                cbStatusText:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
                cbStatusText:SetText("")
                saveBtn:SetScript("OnClick", function()
                    local newSID = tonumber(sidInput:GetText())
                    local newDur = tonumber(durInput:GetText())
                    if not newSID or newSID <= 0 then
                        cbStatusText:SetText("|cffff4444" .. (L["Invalid spell ID"] or "Invalid spell ID") .. "|r")
                        return
                    end
                    if not newDur or newDur <= 0 then
                        cbStatusText:SetText("|cffff4444" .. (L["Enter a valid duration"] or "Enter a valid duration") .. "|r")
                        return
                    end

                    if newSID ~= spellID then
                        local spellInfo = C_Spell.GetSpellInfo(newSID)
                        if not spellInfo then
                            cbStatusText:SetText("|cffff4444" .. (L["Invalid spell ID"] or "Invalid spell ID") .. "|r")
                            return
                        end
                        API:RemoveCustomBuffSpell(spellID)
                        API:AddCustomBuffSpell(newSID, newDur)
                        if groupIndex then
                            local groups = GetSpecGroups()
                            if groups and groups[groupIndex] and groups[groupIndex].spells then
                                for i, sid in ipairs(groups[groupIndex].spells) do
                                    if sid == spellID then
                                        groups[groupIndex].spells[i] = newSID
                                        break
                                    end
                                end
                            end
                        end
                    else
                        if cbEntry then cbEntry.duration = newDur end
                    end

                    API:MarkSpecDataDirty()
                    API:RefreshSpecData()
                    SaveStructuralRefresh()
                    RefreshLeftPanelIfNeeded()
                    ShowSpellSettings(newSID, groupIndex)
                end)
                yOff = yOff - 30
            end
        end

        if groupIndex then
            local groups = GetSpecGroups()
            local gd = groups and groups[groupIndex]
            if gd then
                yOff = BuildOverrideSection(rc, yOff, spellID, groupIndex,
                    Shared.GetMergedOverrideEntry(gd.spellOverrides, spellID),
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
                    isCustom and nil or { isStatic = gd.staticDisplay or false },
                    isCustom
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
                nil,
                isCustom
            )
        end

        rc:SetHeight(math.abs(yOff) + 20)
    end

    local btnRefs = {}
    local ShowSpellPickerPanel
    local ShowCustomBuffAddPanel

    local headerPool, groupContainerPool, emptyRowPool, spellRowPool =
        Shared.CreateGroupEditorPools(leftChild, {
            highlightAlpha = 0.2,
            resetBorder = function(border) ApplyConfiguredBorderColor(border) end,
        })

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
        if btnRefs.icon then
            btnRefs.icon:SetEnabled(selectedGroupIndex ~= nil)
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
                SaveStructuralRefresh()
                RefreshLeftPanelIfNeeded()
                ShowSpellPickerPanel(groupIndex)
            end,
            onDone = function()
                ShowGroupSettings(groupIndex)
            end,
        })
    end

    GetCustomBuffEntry = function(spellID)
        return CDM.db and CDM.db.customBuffRegistry and CDM.db.customBuffRegistry[spellID]
    end

    IsCustomBuffSpell = function(spellID)
        return GetCustomBuffEntry(spellID) ~= nil
    end

    ShowCustomBuffAddPanel = function(targetGroupIndex)
        pickerActiveGroupIndex = nil
        local _, rc = CreateRightScrollContent(500)
        local yOff = 0

        local headerText
        if targetGroupIndex then
            local groups = GetSpecGroups()
            local gd = groups and groups[targetGroupIndex]
            headerText = (L["Add Custom Buff to:"] or "Add Custom Buff to:") .. " " .. (gd and gd.name or "Group")
        else
            headerText = L["Add Custom Buff"] or "Add Custom Buff"
        end

        local header = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        header:SetPoint("TOPLEFT", 0, yOff)
        header:SetText(headerText)
        header:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 30

        local templates = CDM.CustomBuffTemplates or {}
        if #templates > 0 then
            local quickLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
            quickLabel:SetPoint("TOPLEFT", 0, yOff)
            quickLabel:SetText(L["Quick Add"] or "Quick Add")
            UI.SetTextWhite(quickLabel)
            yOff = yOff - 22

            for _, tmpl in ipairs(templates) do
                local sid = tmpl.spellID
                local dur = tmpl.duration
                local spellName = C_Spell.GetSpellName(sid)
                local spellTex = C_Spell.GetSpellTexture(sid)
                local alreadyExists = CDM.db.customBuffRegistry and CDM.db.customBuffRegistry[sid]

                local tRow = CreateFrame("Frame", nil, rc)
                tRow:SetSize(300, 30)
                tRow:SetPoint("TOPLEFT", 0, yOff)

                local tIcon = tRow:CreateTexture(nil, "ARTWORK")
                tIcon:SetSize(24, 24)
                tIcon:SetPoint("LEFT")
                tIcon:SetTexture(tmpl.icon or spellTex)
                CDM_C.ApplyIconTexCoord(tIcon, CDM_C.GetEffectiveZoomAmount())

                local tName = tRow:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
                tName:SetPoint("LEFT", tIcon, "RIGHT", 6, 0)
                tName:SetText((spellName or tostring(sid)) .. "  |cff888888" .. dur .. "s|r")

                local tAddBtn = CreateFrame("Button", nil, tRow, "UIPanelButtonTemplate")
                tAddBtn:SetSize(50, 20)
                tAddBtn:SetPoint("RIGHT", -4, 0)
                tAddBtn:SetText(L["Add"] or "Add")
                tAddBtn:SetEnabled(not alreadyExists)
                tAddBtn:SetScript("OnClick", function()
                    local ov = (tmpl.icon or tmpl.triggerType) and { icon = tmpl.icon, triggerType = tmpl.triggerType } or nil
                    if not API:AddCustomBuffSpell(sid, dur, ov) then return end
                    if targetGroupIndex then
                        local currentGroups = EnsureBuffGroups()
                        if currentGroups and currentGroups[targetGroupIndex] then
                            if not currentGroups[targetGroupIndex].spells then
                                currentGroups[targetGroupIndex].spells = {}
                            end
                            Shared.AddSpellToGroupList(currentGroups[targetGroupIndex].spells, sid)
                        end
                    end
                    API:MarkSpecDataDirty()
                    API:RefreshSpecData()
                    SaveStructuralRefresh()
                    RefreshLeftPanelIfNeeded()
                    ShowCustomBuffAddPanel(targetGroupIndex)
                end)

                yOff = yOff - 32
            end
        end

        yOff = yOff - 10
        local advLabel = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
        advLabel:SetPoint("TOPLEFT", 0, yOff)
        advLabel:SetText(L["Custom Spell"] or "Custom Spell")
        UI.SetTextWhite(advLabel)
        yOff = yOff - 24

        local sidLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
        sidLabel:SetPoint("TOPLEFT", 0, yOff)
        sidLabel:SetText(L["Spell ID:"] or "Spell ID:")

        local sidInput = CreateFrame("EditBox", nil, rc, "InputBoxTemplate")
        sidInput:SetSize(100, 20)
        sidInput:SetPoint("LEFT", sidLabel, "RIGHT", 6, 0)
        sidInput:SetAutoFocus(false)
        sidInput:SetNumeric(true)
        sidInput:SetMaxLetters(10)
        yOff = yOff - 28

        local durLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
        durLabel:SetPoint("TOPLEFT", 0, yOff)
        durLabel:SetText(L["Duration (sec):"] or "Duration (sec):")

        local durInput = CreateFrame("EditBox", nil, rc, "InputBoxTemplate")
        durInput:SetSize(60, 20)
        durInput:SetPoint("LEFT", durLabel, "RIGHT", 6, 0)
        durInput:SetAutoFocus(false)
        durInput:SetNumeric(true)
        durInput:SetMaxLetters(5)
        durInput:SetText("10")
        yOff = yOff - 28

        local previewText = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
        previewText:SetPoint("TOPLEFT", sidInput, "TOPRIGHT", 8, -3)
        previewText:SetText("")

        sidInput:SetScript("OnTextChanged", function()
            local val = tonumber(sidInput:GetText())
            if val and val > 0 then
                local info = C_Spell.GetSpellInfo(val)
                if info then
                    previewText:SetText("|cff00ff00" .. info.name .. "|r")
                else
                    previewText:SetText("|cffff4444" .. (L["Invalid spell ID"] or "Invalid spell ID") .. "|r")
                end
            else
                previewText:SetText("")
            end
        end)

        local advAddBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
        advAddBtn:SetSize(100, 22)
        advAddBtn:SetPoint("TOPLEFT", 0, yOff)

        local statusText = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
        statusText:SetPoint("LEFT", advAddBtn, "RIGHT", 8, 0)
        statusText:SetText("")
        advAddBtn:SetText(L["Add Spell"] or "Add Spell")
        advAddBtn:SetScript("OnClick", function()
            local sid = tonumber(sidInput:GetText())
            local dur = tonumber(durInput:GetText())
            if not sid or sid <= 0 then
                statusText:SetText("|cffff4444" .. (L["Invalid spell ID"] or "Invalid spell ID") .. "|r")
                return
            end
            if not dur or dur <= 0 then
                statusText:SetText("|cffff4444" .. (L["Enter a valid duration"] or "Enter a valid duration") .. "|r")
                return
            end
            if not API:AddCustomBuffSpell(sid, dur) then
                statusText:SetText("|cffff4444" .. (L["Failed - invalid spell ID"] or "Failed - invalid spell ID") .. "|r")
                return
            end
            if targetGroupIndex then
                local currentGroups = EnsureBuffGroups()
                if currentGroups and currentGroups[targetGroupIndex] then
                    if not currentGroups[targetGroupIndex].spells then
                        currentGroups[targetGroupIndex].spells = {}
                    end
                    Shared.AddSpellToGroupList(currentGroups[targetGroupIndex].spells, sid)
                end
            end
            API:MarkSpecDataDirty()
            API:RefreshSpecData()
            statusText:SetText("|cff00ff00" .. (L["Added!"] or "Added!") .. "|r")
            sidInput:SetText("")
            SaveStructuralRefresh()
            RefreshLeftPanelIfNeeded()
            ShowCustomBuffAddPanel(targetGroupIndex)
        end)
        yOff = yOff - 30

        local backBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
        backBtn:SetSize(80, 22)
        backBtn:SetPoint("TOPRIGHT", rc, "TOPRIGHT", 0, 0)
        backBtn:SetText(L["Back"] or "Back")
        backBtn:SetScript("OnClick", function()
            if targetGroupIndex then
                ShowGroupSettings(targetGroupIndex)
            else
                ClearRightPanel()
            end
        end)

        rc:SetHeight(math.abs(yOff) + 20)
    end
    btnRefs.showAddPanel = ShowCustomBuffAddPanel

    local function AcquireEmptyRow(parent, text)
        return Shared.AcquireEmptyRow(emptyRowPool, parent, text)
    end

    local function ConfigureSpellRow(widget, parent, spellID, sourceGroup, y, isActive, spellIndex, spellCount, tooltipOverrides)
        local row = widget.root
        row:SetParent(parent)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, y)

        local displayID = (tooltipOverrides and tooltipOverrides[spellID]) or spellID
        local iconContainer = widget.iconContainer
        local iconTex = widget.iconTex
        local cbEntry = GetCustomBuffEntry(spellID)
        local tex = (cbEntry and cbEntry.icon) or C_Spell.GetSpellTexture(displayID)
        if tex then
            iconTex:SetTexture(tex)
        end
        CDM_C.ApplyIconTexCoord(iconTex, CDM_C.GetEffectiveZoomAmount())

        if iconContainer.border then
            ApplyConfiguredBorderColor(iconContainer.border)
            spellIconBorders[spellID] = iconContainer.border
        end

        if currentSpecID and CDM.GetSpellBorderColor then
            local color = CDM:GetSpellBorderColor(currentSpecID, spellID)
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
                    Shared.RemoveSpellFromGroupList(spells, spellID)
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
                SaveStructuralRefresh()
                RefreshLeftPanelIfNeeded()
                if pickerActiveGroupIndex then
                    ShowSpellPickerPanel(pickerActiveGroupIndex)
                end
            end)
        end

        local nameText = widget.nameText
        nameText:ClearAllPoints()
        nameText:SetPoint("LEFT", iconContainer, "RIGHT", 6, 0)
        nameText:SetPoint("RIGHT", removeBtn:IsShown() and removeBtn or row, removeBtn:IsShown() and "LEFT" or "RIGHT", removeBtn:IsShown() and -2 or -4, 0)
        local displayName = C_Spell.GetSpellName(displayID) or L["Unknown"]
        local cbEntry = GetCustomBuffEntry(spellID)
        if cbEntry then
            displayName = displayName .. "  |cff888888" .. cbEntry.duration .. "s|r"
        end
        nameText:SetText(displayName)
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
                    SaveStructuralRefresh()
                    RefreshLeftPanelIfNeeded()
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
                    SaveStructuralRefresh()
                    RefreshLeftPanelIfNeeded()
                end
            end)
        end

        widget.clickBtn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if currentSpecID then
                    suppressPanelRefreshUntil = GetTime() + 0.15
                    API:ClearSpellBorderColor(currentSpecID, spellID)
                    API:Refresh()
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

        local isViewingPlayer = currentSpecID == playerSpecID
        local activeSpellSet = isViewingPlayer and BuildActiveSpellSet() or nil

        local tooltipOverrideMap
        if isViewingPlayer and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet then
            tooltipOverrideMap = {}
            local ids = C_CooldownViewer.GetCooldownViewerCategorySet(
                Enum.CooldownViewerCategory.TrackedBuff, true)
            if ids then
                for _, cdID in ipairs(ids) do
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    if info and info.overrideTooltipSpellID
                        and info.overrideTooltipSpellID ~= info.spellID then
                        tooltipOverrideMap[info.spellID] = info.overrideTooltipSpellID
                        if info.overrideSpellID then
                            tooltipOverrideMap[info.overrideSpellID] = info.overrideTooltipSpellID
                        end
                    end
                end
            end
        end

        local yOff = 0

        if not btnRefs.group then
            local addGroupBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            addGroupBtn:SetSize(90, 22)
            addGroupBtn:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_INSET, -8)
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
                SaveStructuralRefresh()
                RefreshLeftPanelIfNeeded()
                ShowGroupSettings(newIndex)
            end)
            btnRefs.group = addGroupBtn
        end

        if not btnRefs.icon then
            local addIconBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            addIconBtn:SetSize(90, 22)
            addIconBtn:SetText(L["Add Icon"])
            addIconBtn:SetScript("OnClick", function()
                if selectedGroupIndex then
                    ShowSpellPickerPanel(selectedGroupIndex)
                end
            end)
            btnRefs.icon = addIconBtn
        end
        btnRefs.icon:SetPoint("LEFT", btnRefs.group, "RIGHT", 6, 0)
        btnRefs.icon:SetEnabled(selectedGroupIndex ~= nil)

        if not btnRefs.customBuff then
            local addCustomBuffBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            addCustomBuffBtn:SetSize(140, 22)
            addCustomBuffBtn:SetText(L["Add Custom Buff"] or "Add Custom Buff")
            addCustomBuffBtn:SetScript("OnClick", function()
                if btnRefs.showAddPanel then btnRefs.showAddPanel(selectedGroupIndex) end
            end)
            btnRefs.customBuff = addCustomBuffBtn
        end
        btnRefs.customBuff:SetPoint("TOPLEFT", btnRefs.group, "BOTTOMLEFT", 0, -4)

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
            local customOrder = CDM:GetUngroupedCustomBuffOrder(currentSpecID)

            local mergedList = {}
            for _, nativeEntry in ipairs(ungrouped) do
                local li = nativeEntry.layoutIndex or 0
                mergedList[#mergedList + 1] = { spellID = nativeEntry.spellID, sortKey = li * 10000, isCustom = false, layoutIndex = li }
            end
            local subCounts = {}
            for _, entry in ipairs(customOrder) do
                local aN = entry.afterNative or 0
                subCounts[aN] = (subCounts[aN] or 0) + 1
                mergedList[#mergedList + 1] = {
                    spellID = entry.spellID,
                    sortKey = aN * 10000 + 5000 + subCounts[aN],
                    isCustom = true,
                    afterNative = aN,
                }
            end
            table.sort(mergedList, function(a, b) return a.sortKey < b.sortKey end)

            local ungroupedY = 0
            local customCount = #customOrder
            for displayIdx, item in ipairs(mergedList) do
                if item.isCustom then
                    local widget = spellRowPool:Acquire(ungroupedContainer)
                    ConfigureSpellRow(widget, ungroupedContainer, item.spellID, nil, ungroupedY, true, nil, nil, tooltipOverrideMap)

                    widget.removeBtn:Show()
                    widget.removeBtn:SetScript("OnClick", function()
                        API:RemoveCustomBuffSpell(item.spellID)
                        API:MarkSpecDataDirty()
                        API:RefreshSpecData()
                        SaveStructuralRefresh()
                        RefreshLeftPanelIfNeeded()
                    end)
                    widget.nameText:SetPoint("RIGHT", widget.removeBtn, "LEFT", -2, 0)

                    widget.btnUp:Show()
                    widget.btnUp:SetEnabled(displayIdx > 1)
                    widget.btnUp:SetScript("OnClick", function()
                        local order = CDM:GetUngroupedCustomBuffOrder(currentSpecID)
                        local myIdx
                        for ci, e in ipairs(order) do
                            if e.spellID == item.spellID then myIdx = ci; break end
                        end
                        if not myIdx then return end

                        local prevItem = mergedList[displayIdx - 1]
                        if prevItem then
                            if prevItem.isCustom and prevItem.afterNative == item.afterNative then
                                local prevIdx
                                for ci, e in ipairs(order) do
                                    if e.spellID == prevItem.spellID then prevIdx = ci; break end
                                end
                                if prevIdx then
                                    order[myIdx], order[prevIdx] = order[prevIdx], order[myIdx]
                                end
                            elseif prevItem.isCustom then
                                order[myIdx].afterNative = prevItem.afterNative
                            else
                                local prevLI = prevItem.layoutIndex or 0
                                order[myIdx].afterNative = math.max(0, prevLI - 1)
                            end
                        end
                        CDM:SetUngroupedCustomBuffOrder(currentSpecID, order)
                        SaveStructuralRefresh()
                        RefreshLeftPanelIfNeeded()
                    end)

                    widget.btnDown:Show()
                    widget.btnDown:SetEnabled(displayIdx < #mergedList)
                    widget.btnDown:SetScript("OnClick", function()
                        local order = CDM:GetUngroupedCustomBuffOrder(currentSpecID)
                        local myIdx
                        for ci, e in ipairs(order) do
                            if e.spellID == item.spellID then myIdx = ci; break end
                        end
                        if not myIdx then return end

                        local nextItem = mergedList[displayIdx + 1]
                        if nextItem then
                            if nextItem.isCustom and nextItem.afterNative == item.afterNative then
                                local nextIdx
                                for ci, e in ipairs(order) do
                                    if e.spellID == nextItem.spellID then nextIdx = ci; break end
                                end
                                if nextIdx then
                                    order[myIdx], order[nextIdx] = order[nextIdx], order[myIdx]
                                end
                            elseif nextItem.isCustom then
                                order[myIdx].afterNative = nextItem.afterNative
                            else
                                order[myIdx].afterNative = nextItem.layoutIndex or 0
                            end
                        end
                        CDM:SetUngroupedCustomBuffOrder(currentSpecID, order)
                        SaveStructuralRefresh()
                        RefreshLeftPanelIfNeeded()
                    end)

                else
                    local active = not isViewingPlayer or IsSpellInActiveSet(activeSpellSet, item.spellID)
                    ConfigureSpellRow(spellRowPool:Acquire(ungroupedContainer), ungroupedContainer, item.spellID, nil, ungroupedY, active, nil, nil, tooltipOverrideMap)
                end
                ungroupedY = ungroupedY - ROW_HEIGHT
            end

            if #mergedList == 0 then
                AcquireEmptyRow(ungroupedContainer, L["No ungrouped buffs"])
                ungroupedY = -ROW_HEIGHT
            end

            ungroupedContainer:SetHeight(math.abs(ungroupedY) + 4)
            yOff = yOff + ungroupedY
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
                    ConfigureSpellRow(spellRowPool:Acquire(ungroupedContainer), ungroupedContainer, spellID, nil, ungroupedY, nil, nil, nil, tooltipOverrideMap)
                    ungroupedY = ungroupedY - ROW_HEIGHT
                end
            end

            ungroupedContainer:SetHeight(math.abs(ungroupedY) + 4)
            yOff = yOff + ungroupedY
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
                                    if currentSpecID == playerSpecID then
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
                        SaveStructuralRefresh()
                        RefreshLeftPanelIfNeeded()
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
                            local active = not isViewingPlayer or IsSpellInActiveSet(activeSpellSet, spellID) or IsCustomBuffSpell(spellID)
                            ConfigureSpellRow(
                                spellRowPool:Acquire(groupContainer),
                                groupContainer,
                                spellID,
                                groupIndex,
                                spellY,
                                active,
                                spellIdx,
                                spellCount,
                                tooltipOverrideMap
                            )
                            spellY = spellY - ROW_HEIGHT
                        end
                    end

                    if not groupData.spells or #groupData.spells == 0 then
                        AcquireEmptyRow(groupContainer, L["Drag spells here"])
                        spellY = -ROW_HEIGHT
                    end

                    groupContainer:SetHeight(math.abs(spellY) + 4)
                    yOff = yOff + spellY
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
    end, 30)

end

API:RegisterConfigTab("buffgroups", L["Buff Groups"], CreateBuffGroupsTab, 8)
