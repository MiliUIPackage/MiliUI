local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L
local CDM_C = CDM and CDM.CONST or {}
local IsSafeNumber = API.IsSafeNumber
local UI = ns.ConfigUI

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

    local NormalizeToBase = API.NormalizeToBase

    local selectedGroupIndex = nil
    local selectedSpellID = nil
    local selectedSpellGroupIndex = nil
    local expandedGroups = {}
    local EMPTY_OVERRIDE_KEYS = {}
    local overrideKeyCandidateCache = {}
    local RefreshAll
    local ShowSpellSettings
    local leftPanelRefreshQueued = false
    local renameLastClickTime = 0
    local renameLastClickGroup = nil
    local renameActiveGroupIndex = nil
    local renameActiveEditBox = nil
    local suppressPanelRefreshUntil = 0
    local ungroupedSelected = false

    local function RefreshCurrentSpecID()
        local si = GetSpecialization()
        if si then
            currentSpecID = GetSpecializationInfo(si)
        else
            currentSpecID = nil
        end
        table.wipe(overrideKeyCandidateCache)
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

    local function SaveAndRefresh()
        API:RefreshConfig()
    end

    local function RefreshLeftPanelIfNeeded()
        if RefreshAll then RefreshAll() end
    end

    local function SaveRefreshAndMaybeRebuildLeft()
        SaveAndRefresh()
        RefreshLeftPanelIfNeeded()
    end

    local function GetConfiguredBorderColor()
        if API.GetConfiguredBorderColor then
            return API:GetConfiguredBorderColor()
        end
        return 0, 0, 0, 1
    end

    local function ApplyConfiguredBorderColor(borderFrame)
        if not (borderFrame and borderFrame.SetBackdropBorderColor) then return end
        local r, g, b, a = GetConfiguredBorderColor()
        borderFrame:SetBackdropBorderColor(r, g, b, a)
    end

    local GROW_OPTIONS = {
        { label = "Right", value = "RIGHT" },
        { label = "Left", value = "LEFT" },
        { label = "Up", value = "UP" },
        { label = "Down", value = "DOWN" },
        { label = "Center Horizontal", value = "CENTER_H" },
        { label = "Center Vertical", value = "CENTER_V" },
    }

    local function GetGrowLabel(growValue)
        for _, option in ipairs(GROW_OPTIONS) do
            if option.value == growValue then
                return option.label
            end
        end
        return growValue or "RIGHT"
    end

    local function IsUsableSpellID(spellID)
        return IsSafeNumber(spellID) and spellID > 0 and spellID == math.floor(spellID)
    end

    local function CopyShallowTable(src)
        if type(src) ~= "table" then return src end
        local out = {}
        for k, v in pairs(src) do
            if type(v) == "table" then
                local sub = {}
                for sk, sv in pairs(v) do
                    sub[sk] = sv
                end
                out[k] = sub
            else
                out[k] = v
            end
        end
        return out
    end

    local function MergeMissingFields(dst, src)
        if type(dst) ~= "table" or type(src) ~= "table" then return end
        for k, v in pairs(src) do
            if dst[k] == nil then
                dst[k] = CopyShallowTable(v)
            end
        end
    end

    local function BuildOverrideKeyCandidates(spellID)
        if not IsUsableSpellID(spellID) then return EMPTY_OVERRIDE_KEYS end
        local cached = overrideKeyCandidateCache[spellID]
        if cached then
            return cached
        end

        local keys = {}
        local seen = {}
        local function Add(id)
            if not IsUsableSpellID(id) or seen[id] then return end
            seen[id] = true
            keys[#keys + 1] = id
        end

        Add(spellID)
        local baseID = NormalizeToBase(spellID)
        Add(baseID)
        if C_Spell and C_Spell.GetOverrideSpell then
            Add(C_Spell.GetOverrideSpell(spellID))
            if IsUsableSpellID(baseID) then
                Add(C_Spell.GetOverrideSpell(baseID))
            end
        end

        local idx = 1
        while idx <= #keys do
            Add(NormalizeToBase(keys[idx]))
            idx = idx + 1
        end

        overrideKeyCandidateCache[spellID] = keys
        return keys
    end

    local function GetOverrideStorageKey(spellID)
        if not IsUsableSpellID(spellID) then return spellID end
        local baseID = NormalizeToBase(spellID)
        if IsUsableSpellID(baseID) then
            return baseID
        end
        return spellID
    end

    local function CollectMergedOverrideEntry(overrideMap, spellID, removeEntries)
        if type(overrideMap) ~= "table" or not IsUsableSpellID(spellID) then return nil, EMPTY_OVERRIDE_KEYS end
        local keys = BuildOverrideKeyCandidates(spellID)
        local merged = nil
        for _, key in ipairs(keys) do
            local entry = overrideMap[key]
            if type(entry) == "table" then
                if not merged then
                    merged = CopyShallowTable(entry)
                else
                    MergeMissingFields(merged, entry)
                end
                if removeEntries then
                    overrideMap[key] = nil
                end
            end
        end
        return merged, keys
    end

    local function GetMergedOverride(overrideMap, spellID)
        local merged = CollectMergedOverrideEntry(overrideMap, spellID, false)
        return merged
    end

    local function EnsureResolvedOverrideEntry(overrideMap, spellID)
        if type(overrideMap) ~= "table" or not IsUsableSpellID(spellID) then return nil end

        local target, keys = CollectMergedOverrideEntry(overrideMap, spellID, false)
        local storageKey = GetOverrideStorageKey(spellID)

        if not target then
            target = {}
        end

        overrideMap[storageKey] = target
        for _, key in ipairs(keys) do
            if key ~= storageKey then
                overrideMap[key] = nil
            end
        end
        return target
    end

    local function ExtractMergedOverrideEntry(overrideMap, spellID)
        local extracted = CollectMergedOverrideEntry(overrideMap, spellID, true)
        return extracted
    end

    local function StoreMergedOverrideEntry(overrideMap, spellID, incoming)
        if type(overrideMap) ~= "table" or type(incoming) ~= "table" or not IsUsableSpellID(spellID) then return end
        local storageKey = GetOverrideStorageKey(spellID)
        if not IsUsableSpellID(storageKey) then return end
        local keys = BuildOverrideKeyCandidates(spellID)
        for _, key in ipairs(keys) do
            if key ~= storageKey then
                overrideMap[key] = nil
            end
        end
        overrideMap[storageKey] = CopyShallowTable(incoming)
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

    local function GetUngroupedBuffSpells()
        local buffViewer = _G["BuffIconCooldownViewer"]
        if not buffViewer or not buffViewer.itemFramePool then return {} end

        local icons = {}
        local seen = {}
        for frame in buffViewer.itemFramePool:EnumerateActive() do
            local matchType = API.GetBuffRegistryMatch and API:GetBuffRegistryMatch(frame) or nil
            if not matchType then
                local displayID = frame.GetSpellID and frame:GetSpellID()
                if not IsSafeNumber(displayID) then
                    displayID = frame.GetBaseSpellID and frame:GetBaseSpellID()
                end
                if not IsSafeNumber(displayID) and API.GetCachedBaseSpellID then
                    displayID = API:GetCachedBaseSpellID(frame)
                end
                if IsSafeNumber(displayID) and not seen[displayID] then
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

    local function QueueLeftPanelRefresh(delay)
        if leftPanelRefreshQueued then return end
        leftPanelRefreshQueued = true
        C_Timer.After(delay or 0.1, function()
            leftPanelRefreshQueued = false
            if page:IsShown() and RefreshAll then
                RefreshAll()
            end
        end)
    end

    local dragState = {
        active = false,
        spellID = nil,
        sourceGroup = nil,
        dragFrame = nil,
    }

    local dropTargets = {}

    local function RegisterDropTarget(frame, groupIndex)
        dropTargets[#dropTargets + 1] = { frame = frame, groupIndex = groupIndex }
    end

    local function ClearDropTargets()
        table.wipe(dropTargets)
    end

    local dragFrameCache = nil
    local function GetOrCreateDragFrame(spellID)
        if not dragFrameCache then
            dragFrameCache = CreateFrame("Frame", nil, UIParent)
            dragFrameCache:SetSize(28, 28)
            dragFrameCache:SetFrameStrata("TOOLTIP")
            local icon = dragFrameCache:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            dragFrameCache.icon = icon
            dragFrameCache:SetAlpha(0.8)
        end
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then
            dragFrameCache.icon:SetTexture(tex)
        else
            dragFrameCache.icon:SetColorTexture(0.3, 0.3, 0.3)
        end
        CDM_C.ApplyIconTexCoord(dragFrameCache.icon, true)
        return dragFrameCache
    end

    local function StartDrag(spellID, sourceGroup)
        if dragState.active then return end
        dragState.active = true
        dragState.spellID = spellID
        dragState.sourceGroup = sourceGroup

        local df = GetOrCreateDragFrame(spellID)
        dragState.dragFrame = df
        df:Show()

        df:SetScript("OnUpdate", function()
            local scale = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            df:ClearAllPoints()
            df:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

            for _, target in ipairs(dropTargets) do
                if target.frame.highlight then
                    if target.frame:IsMouseOver() then
                        target.frame.highlight:Show()
                    else
                        target.frame.highlight:Hide()
                    end
                end
            end
        end)
    end

    local function EndDrag()
        if not dragState.active then return end

        local spellID = dragState.spellID
        local sourceGroup = dragState.sourceGroup

        if dragState.dragFrame then
            dragState.dragFrame:SetScript("OnUpdate", nil)
            dragState.dragFrame:Hide()
            dragState.dragFrame = nil
        end

        for _, target in ipairs(dropTargets) do
            if target.frame.highlight then
                target.frame.highlight:Hide()
            end
        end

        local targetGroupIndex = nil
        local hitDropTarget = false
        for _, target in ipairs(dropTargets) do
            if target.frame:IsMouseOver() then
                targetGroupIndex = target.groupIndex
                hitDropTarget = true
                break
            end
        end

        dragState.active = false
        dragState.spellID = nil
        dragState.sourceGroup = nil

        if not spellID or not currentSpecID then return end
        if not hitDropTarget then return end
        if sourceGroup == targetGroupIndex then return end

        local groups = EnsureBuffGroups()
        if not groups then return end

        local srcOvData = nil
        if sourceGroup then
            local srcGroup = groups[sourceGroup]
            if srcGroup and srcGroup.spells then
                for i, id in ipairs(srcGroup.spells) do
                    if id == spellID then
                        table.remove(srcGroup.spells, i)
                        break
                    end
                end
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
                tgtGroup.spells[#tgtGroup.spells + 1] = spellID
                if srcOvData then
                    if not tgtGroup.spellOverrides then tgtGroup.spellOverrides = {} end
                    StoreMergedOverrideEntry(tgtGroup.spellOverrides, spellID, srcOvData)
                end
            end
        else
            if srcOvData then
                local specOv = EnsureUngroupedOverrides()
                if specOv then
                    StoreMergedOverrideEntry(specOv, spellID, srcOvData)
                end
            end
        end

        suppressPanelRefreshUntil = GetTime() + 0.15
        API:MarkSpecDataDirty()
        API:RefreshSpecData()
        SaveAndRefresh()
        if spellID == selectedSpellID then
            selectedSpellGroupIndex = targetGroupIndex
            ShowSpellSettings(spellID, targetGroupIndex)
        end
        RefreshLeftPanelIfNeeded()
    end

    local function CancelDrag()
        if not dragState.active then return end
        if dragState.dragFrame then
            dragState.dragFrame:SetScript("OnUpdate", nil)
            dragState.dragFrame:Hide()
            dragState.dragFrame = nil
        end
        for _, target in ipairs(dropTargets) do
            if target.frame.highlight then
                target.frame.highlight:Hide()
            end
        end
        dragState.active = false
        dragState.spellID = nil
        dragState.sourceGroup = nil
    end

    local function DestroyFrame(frame)
        if not frame then return end
        frame:Hide()
        frame:SetParent(nil)
    end

    local LEFT_INSET = 35
    local LEFT_WIDTH = 240
    local SCROLL_LEFT_PAD = 54

    local leftScroll = CreateFrame("ScrollFrame", "AyijeCDM_BuffGroupsLeftScroll", page, "ScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", LEFT_INSET - SCROLL_LEFT_PAD, -40)
    leftScroll:SetPoint("BOTTOMLEFT", LEFT_INSET - SCROLL_LEFT_PAD, 20)
    leftScroll:SetWidth(LEFT_WIDTH + SCROLL_LEFT_PAD)

    local leftChild = nil

    local function RecreateLeftChild()
        if leftChild then
            DestroyFrame(leftChild)
        end
        leftChild = CreateFrame("Frame", nil, leftScroll)
        leftChild:SetSize(LEFT_WIDTH + SCROLL_LEFT_PAD, 1200)
        leftScroll:SetScrollChild(leftChild)
        return leftChild
    end

    local RIGHT_X = LEFT_INSET + LEFT_WIDTH + 40
    local SLIDER_LABEL_W = 120
    local SLIDER_W = 200

    local rightPanel = CreateFrame("Frame", nil, page)
    rightPanel:SetPoint("TOPLEFT", RIGHT_X, -40)
    rightPanel:SetPoint("BOTTOMRIGHT", -10, 20)

    local rightPlaceholder = rightPanel:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    rightPlaceholder:SetPoint("TOP", 0, -20)
    rightPlaceholder:SetText(L["Select a group or spell to edit settings"])
    UI.SetTextMuted(rightPlaceholder)

    local rightContentFrame = nil
    local rightPanelDropdowns = {}

    local function CreateSlider(parent, label, minVal, maxVal, currentVal, onChange)
        return UI.CreateModernSlider(parent, label, minVal, maxVal, currentVal, onChange, SLIDER_LABEL_W, SLIDER_W)
    end

    local rightScrollFrame = nil

    local function RegisterRightPanelDropdown(dropdown)
        if dropdown then
            table.insert(rightPanelDropdowns, dropdown)
        end
        return dropdown
    end

    local function CloseRightPanelDropdownMenus()
        if UI and UI.CloseAllDropdownMenus then
            UI.CloseAllDropdownMenus()
        end
        for _, dropdown in ipairs(rightPanelDropdowns) do
            if dropdown and dropdown.CloseMenu then
                dropdown:CloseMenu()
            end
        end
    end

    local function ResetRightPanel(showPlaceholder)
        CloseRightPanelDropdownMenus()
        table.wipe(rightPanelDropdowns)
        if rightContentFrame then
            DestroyFrame(rightContentFrame)
            rightContentFrame = nil
        end
        if rightScrollFrame then
            DestroyFrame(rightScrollFrame)
            rightScrollFrame = nil
        end
        if showPlaceholder then
            rightPlaceholder:Show()
        else
            rightPlaceholder:Hide()
        end
    end

    local function CreateRightScrollContent(minHeight)
        ResetRightPanel(false)

        local sf = CreateFrame("ScrollFrame", nil, rightPanel, "ScrollFrameTemplate")
        sf:SetAllPoints()
        sf:Show()
        sf:HookScript("OnVerticalScroll", function()
            CloseRightPanelDropdownMenus()
        end)
        sf:HookScript("OnHide", function()
            CloseRightPanelDropdownMenus()
        end)
        rightScrollFrame = sf

        local rc = CreateFrame("Frame", nil, sf)
        rc:SetWidth(sf:GetWidth() > 0 and sf:GetWidth() - 20 or 400)
        rc:SetHeight(minHeight or 400)
        sf:SetScrollChild(rc)
        rc:Show()
        rightContentFrame = rc
        return sf, rc
    end

    local function ClearRightPanel()
        ResetRightPanel(true)
    end

    local function ShowUngroupedSettings()
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
            if not CDM.db.buffCooldownColor then CDM.db.buffCooldownColor = { r = 1, g = 1, b = 1, a = 1 } end
            CDM.db.buffCooldownColor.r, CDM.db.buffCooldownColor.g, CDM.db.buffCooldownColor.b = r, g, b
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
            if not CDM.db.countColor then CDM.db.countColor = { r = 1, g = 1, b = 1, a = 1 } end
            CDM.db.countColor.r, CDM.db.countColor.g, CDM.db.countColor.b = r, g, b
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

        local widthSlider = CreateSlider(rc, L["Icon Width"], 16, 80, gd.iconWidth or 30, function(v)
            gd.iconWidth = v; SaveAndRefresh()
        end)
        widthSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local heightSlider = CreateSlider(rc, L["Icon Height"], 16, 80, gd.iconHeight or 30, function(v)
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
                gd.anchorTarget = val
                if val == "screen" then
                    gd.anchorPoint = "CENTER"
                    gd.anchorRelativeTo = "CENTER"
                else
                    gd.anchorPoint = gd.anchorPoint or "CENTER"
                    gd.anchorRelativeTo = gd.anchorRelativeTo or "CENTER"
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
        if not spellID or not currentSpecID then
            ClearRightPanel()
            return
        end

        local _, rc = CreateRightScrollContent(700)

        local yOff = 0

        local iconContainer = CreateFrame("Frame", nil, rc)
        iconContainer:SetSize(28, 28)
        iconContainer:SetPoint("TOPLEFT", 0, yOff)

        local iconTex = iconContainer:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then iconTex:SetTexture(tex) end
        CDM_C.ApplyIconTexCoord(iconTex, true)

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
        spellName:SetText(C_Spell.GetSpellName(spellID) or L["Unknown"])
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

    local arrowContainers = {}
    local addGroupBtnRef = nil

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
        for _, ac in ipairs(arrowContainers) do
            ac:Hide()
            ac:SetParent(nil)
        end
        table.wipe(arrowContainers)
        local lc = RecreateLeftChild()
        ClearDropTargets()

        local activeSpellSet = BuildActiveSpellSet()

        local yOff = 0
        local ICON_SIZE = 30
        local ROW_HEIGHT = 36
        local SECTION_GAP = 0
        local GROUP_HEADER_H = 28

        local ARROW_BTN_SIZE = 29

        if not addGroupBtnRef then
            local addGroupBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            addGroupBtn:SetSize(90, 22)
            addGroupBtn:SetPoint("BOTTOMLEFT", leftScroll, "TOPLEFT", 12, 8)
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
                SaveAndRefresh()
                ShowGroupSettings(newIndex)
                RefreshLeftPanelIfNeeded()
            end)
            addGroupBtnRef = addGroupBtn
        end

        local function CreateEmptyListRow(parent, text)
            local emptyFrame = CreateFrame("Frame", nil, parent)
            emptyFrame:SetSize(LEFT_WIDTH, ROW_HEIGHT)
            emptyFrame:SetPoint("TOPLEFT", 0, 0)
            local emptyText = emptyFrame:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            emptyText:SetPoint("LEFT", 10, 0)
            emptyText:SetText(text)
            UI.SetTextFaint(emptyText)
        end

        local function CreateSpellRow(parent, spellID, sourceGroup, y, isActive, spellIndex, spellCount)
            local row = CreateFrame("Frame", nil, parent)
            row:SetSize(LEFT_WIDTH - 20, ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 8, y)

            if sourceGroup and spellIndex and spellCount then
                local btnUp = CreateFrame("Button", nil, parent)
                btnUp:SetSize(ARROW_BTN_SIZE, ARROW_BTN_SIZE)
                btnUp:SetPoint("RIGHT", row, "LEFT", -2 - ARROW_BTN_SIZE + 2, 0)
                btnUp:SetNormalAtlas("common-button-collapseExpand-up")
                btnUp:SetPushedAtlas("common-button-collapseExpand-up-pressed")
                btnUp:SetDisabledAtlas("common-button-collapseExpand-up-disabled")
                btnUp:SetHighlightAtlas("common-button-collapseExpand-hover")
                if spellIndex == 1 then btnUp:SetEnabled(false) end
                arrowContainers[#arrowContainers + 1] = btnUp

                btnUp:SetScript("OnClick", function()
                    local groups = GetSpecGroups()
                    if not groups or not groups[sourceGroup] then return end
                    local spells = groups[sourceGroup].spells
                    if spells and spellIndex > 1 then
                        spells[spellIndex], spells[spellIndex - 1] = spells[spellIndex - 1], spells[spellIndex]
                        SaveRefreshAndMaybeRebuildLeft()
                    end
                end)

                local btnDown = CreateFrame("Button", nil, parent)
                btnDown:SetSize(ARROW_BTN_SIZE, ARROW_BTN_SIZE)
                btnDown:SetPoint("RIGHT", row, "LEFT", -2, 0)
                btnDown:SetNormalAtlas("common-button-collapseExpand-down")
                btnDown:SetPushedAtlas("common-button-collapseExpand-down-pressed")
                btnDown:SetDisabledAtlas("common-button-collapseExpand-down-disabled")
                btnDown:SetHighlightAtlas("common-button-collapseExpand-hover")
                if spellIndex == spellCount then btnDown:SetEnabled(false) end
                arrowContainers[#arrowContainers + 1] = btnDown

                btnDown:SetScript("OnClick", function()
                    local groups = GetSpecGroups()
                    if not groups or not groups[sourceGroup] then return end
                    local spells = groups[sourceGroup].spells
                    if spells and spellIndex < #spells then
                        spells[spellIndex], spells[spellIndex + 1] = spells[spellIndex + 1], spells[spellIndex]
                        SaveRefreshAndMaybeRebuildLeft()
                    end
                end)
            end

            local iconContainer = CreateFrame("Frame", nil, row)
            iconContainer:SetSize(ICON_SIZE, ICON_SIZE)
            iconContainer:SetPoint("LEFT", 0, 0)

            local iconTex = iconContainer:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints()
            local tex = C_Spell.GetSpellTexture(spellID)
            if tex then iconTex:SetTexture(tex) end
            CDM_C.ApplyIconTexCoord(iconTex, true)

            if CDM.BORDER and CDM.BORDER.CreateBorder then
                CDM.BORDER:CreateBorder(iconContainer)
                if CDM.BORDER.activeBorders then
                    CDM.BORDER.activeBorders[iconContainer] = nil
                end
            end

            if iconContainer.border then
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
            end

            local removeBtn
            if sourceGroup then
                removeBtn = CreateFrame("Button", nil, row)
                removeBtn:SetSize(16, 16)
                removeBtn:SetPoint("RIGHT", -6, 0)
                removeBtn:SetFrameLevel(row:GetFrameLevel() + 2)
                local removeBtnText = removeBtn:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                removeBtnText:SetPoint("CENTER")
                removeBtnText:SetText("|cffff4444X|r")
                removeBtn:SetFontString(removeBtnText)
                removeBtn:SetScript("OnClick", function()
                    local groups = GetSpecGroups()
                    if not groups or not groups[sourceGroup] then return end
                    local srcGroup = groups[sourceGroup]
                    local spells = srcGroup.spells
                    if spells then
                        for i = #spells, 1, -1 do
                            if spells[i] == spellID then
                                table.remove(spells, i)
                                break
                            end
                        end
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
                end)
            end

            local nameText = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
            nameText:SetPoint("LEFT", iconContainer, "RIGHT", 6, 0)
            nameText:SetPoint("RIGHT", removeBtn or row, removeBtn and "LEFT" or "RIGHT", removeBtn and -2 or -4, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(C_Spell.GetSpellName(spellID) or L["Unknown"])

            if isActive == false then
                UI.SetTextMuted(nameText)
            elseif selectedSpellID == spellID then
                UI.SetTextWhite(nameText)
            else
                UI.SetTextSubtle(nameText)
            end

            local clickBtn = CreateFrame("Button", nil, row)
            clickBtn:SetAllPoints()
            clickBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            clickBtn:RegisterForDrag("LeftButton")

            clickBtn:SetScript("OnClick", function(_, button)
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

            clickBtn:SetScript("OnDragStart", function()
                StartDrag(spellID, sourceGroup)
            end)
            clickBtn:SetScript("OnDragStop", function()
                EndDrag()
            end)

            return row
        end

        local ungroupedHeader = UI.CreateHeader(lc, L["Ungrouped Buffs"])
        ungroupedHeader:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)

        if ungroupedSelected then
            ungroupedHeader:SetTextColor(1, 1, 1, 1)
        end

        local settingsBtn = CreateFrame("Button", nil, lc)
        settingsBtn:SetSize(27, 27)
        settingsBtn:SetPoint("LEFT", ungroupedHeader, "RIGHT", 6, -4)
        settingsBtn:SetNormalAtlas("common-dropdown-a-button-settings-shadowless")
        settingsBtn:SetHighlightAtlas("common-dropdown-a-button-settings-hover-shadowless")
        settingsBtn:SetPushedAtlas("common-dropdown-a-button-settings-pressed-shadowless")
        settingsBtn:SetScript("OnClick", function()
            ungroupedSelected = true
            selectedGroupIndex = nil
            selectedSpellID = nil
            ShowUngroupedSettings()
            RefreshLeftPanelIfNeeded()
        end)

        yOff = yOff - 24

        local ungroupedContainer = CreateFrame("Frame", nil, lc)
        ungroupedContainer:SetSize(LEFT_WIDTH, 10)
        ungroupedContainer:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)

        local highlight = ungroupedContainer:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.2, 0.6, 0.2, 0.2)
        highlight:Hide()
        ungroupedContainer.highlight = highlight

        RegisterDropTarget(ungroupedContainer, nil)

        local ungrouped = GetUngroupedBuffSpells()
        local ungroupedY = 0
        for _, spellID in ipairs(ungrouped) do
            CreateSpellRow(ungroupedContainer, spellID, nil, ungroupedY, true)
            ungroupedY = ungroupedY - ROW_HEIGHT
        end

        if #ungrouped == 0 then
            CreateEmptyListRow(ungroupedContainer, L["No ungrouped buffs"])
            ungroupedY = -ROW_HEIGHT
        end

        ungroupedContainer:SetHeight(math.abs(ungroupedY) + 4)
        yOff = yOff + ungroupedY - SECTION_GAP

        local groups = GetSpecGroups()
        if groups then
            for groupIndex, groupData in ipairs(groups) do
                local isExpanded = expandedGroups[groupIndex] ~= false

                local DELETE_BTN_SIZE = 24
                local VISIBLE_W = LEFT_WIDTH - 14
                local ATLAS_W = VISIBLE_W - DELETE_BTN_SIZE - 4

                local headerRow = CreateFrame("Frame", nil, lc)
                headerRow:SetSize(VISIBLE_W, GROUP_HEADER_H)
                headerRow:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)

                local hBgLeft = headerRow:CreateTexture(nil, "BACKGROUND")
                hBgLeft:SetAtlas("Options_ListExpand_Left", true)
                hBgLeft:SetPoint("TOPLEFT", 0, 0)

                local hBgRight = headerRow:CreateTexture(nil, "BACKGROUND")
                if isExpanded then
                    hBgRight:SetAtlas("Options_ListExpand_Right_Expanded", true)
                else
                    hBgRight:SetAtlas("Options_ListExpand_Right", true)
                end
                hBgRight:SetPoint("LEFT", hBgLeft, "LEFT", ATLAS_W - hBgRight:GetWidth(), 0)

                local hLeftW = hBgLeft:GetWidth()
                local hLeftH = hBgLeft:GetHeight()

                local hBgMiddle = headerRow:CreateTexture(nil, "BACKGROUND")
                hBgMiddle:SetAtlas("_Options_ListExpand_Middle")
                local midW = math.max(1, ATLAS_W - hLeftW - hBgRight:GetWidth())
                hBgMiddle:SetSize(midW, hLeftH)
                hBgMiddle:SetPoint("TOPLEFT", hBgLeft, "TOPRIGHT", 0, 0)

                local groupName = headerRow:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
                groupName:SetPoint("LEFT", hBgLeft, "LEFT", 8, 0)
                groupName:SetPoint("RIGHT", hBgRight, "LEFT", -4, 0)
                groupName:SetJustifyH("LEFT")

                if renameActiveGroupIndex == groupIndex then
                    groupName:Hide()
                    local editBox = CreateFrame("EditBox", nil, headerRow, "BackdropTemplate")
                    editBox:SetFontObject("AyijeCDM_Font14")
                    editBox:SetPoint("LEFT", hBgLeft, "LEFT", 4, 0)
                    editBox:SetPoint("RIGHT", hBgRight, "LEFT", -4, 0)
                    editBox:SetHeight(18)
                    editBox:SetJustifyH("LEFT")
                    editBox:SetTextInsets(2, 2, 0, 0)
                    editBox:SetBackdrop({ bgFile = CDM_C.TEX_WHITE8X8, edgeFile = CDM_C.TEX_WHITE8X8, edgeSize = 1 })
                    editBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                    editBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
                    editBox:SetText(groupData.name or ("Group " .. groupIndex))
                    editBox:SetAutoFocus(true)
                    editBox:HighlightText()
                    editBox:SetFrameLevel(headerRow:GetFrameLevel() + 3)
                    renameActiveEditBox = editBox

                    local committed = false
                    local function CommitRename(self)
                        if committed then return end
                        committed = true
                        local newName = self:GetText()
                        if newName and newName ~= "" then
                            groupData.name = newName
                        end
                        renameActiveGroupIndex = nil
                        renameActiveEditBox = nil
                        self:SetScript("OnEditFocusLost", nil)
                        if selectedGroupIndex == groupIndex then
                            ShowGroupSettings(groupIndex)
                        end
                        RefreshLeftPanelIfNeeded()
                    end

                    editBox:SetScript("OnEnterPressed", CommitRename)
                    editBox:SetScript("OnEscapePressed", function(self)
                        if committed then return end
                        committed = true
                        renameActiveGroupIndex = nil
                        renameActiveEditBox = nil
                        self:SetScript("OnEditFocusLost", nil)
                        RefreshLeftPanelIfNeeded()
                    end)
                    editBox:SetScript("OnEditFocusLost", CommitRename)
                else
                    groupName:SetText(groupData.name or ("Group " .. groupIndex))
                    if selectedGroupIndex == groupIndex then
                        UI.SetTextWhite(groupName)
                    else
                        UI.SetTextMuted(groupName)
                    end
                end

                local selectBtn = CreateFrame("Button", nil, headerRow)
                selectBtn:SetPoint("TOPLEFT", 0, 0)
                selectBtn:SetPoint("BOTTOMRIGHT", headerRow, "BOTTOMLEFT", ATLAS_W - hBgRight:GetWidth(), 0)
                selectBtn:SetScript("OnClick", function()
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

                local expandBtn = CreateFrame("Button", nil, headerRow)
                expandBtn:SetPoint("TOPLEFT", hBgRight, "TOPLEFT", 0, 0)
                expandBtn:SetPoint("BOTTOMRIGHT", hBgRight, "BOTTOMRIGHT", 0, 0)
                expandBtn:SetFrameLevel(headerRow:GetFrameLevel() + 1)
                expandBtn:SetScript("OnClick", function()
                    expandedGroups[groupIndex] = not isExpanded
                    selectedGroupIndex = groupIndex
                    selectedSpellID = nil
                    ungroupedSelected = false
                    ShowGroupSettings(groupIndex)
                    RefreshLeftPanelIfNeeded()
                end)

                local deleteBtn = CreateFrame("Button", nil, headerRow)
                deleteBtn:SetSize(DELETE_BTN_SIZE, DELETE_BTN_SIZE)
                deleteBtn:SetPoint("RIGHT", 0, 1)
                deleteBtn:SetFrameLevel(headerRow:GetFrameLevel() + 2)
                deleteBtn:SetNormalAtlas("128-RedButton-Exit")
                deleteBtn:SetPushedAtlas("128-RedButton-Exit-Pressed")
                deleteBtn:SetHighlightAtlas("128-RedButton-Exit-Highlight")
                deleteBtn:SetScript("OnClick", function()
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

                local groupContainer = CreateFrame("Frame", nil, lc)
                groupContainer:SetSize(LEFT_WIDTH, 10)
                groupContainer:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)

                local gHighlight = groupContainer:CreateTexture(nil, "BACKGROUND")
                gHighlight:SetAllPoints()
                gHighlight:SetColorTexture(0.2, 0.4, 0.8, 0.2)
                gHighlight:Hide()
                groupContainer.highlight = gHighlight

                if isExpanded then
                    RegisterDropTarget(groupContainer, groupIndex)
                    local spellY = 0
                    if groupData.spells then
                        local spellCount = #groupData.spells
                        for spellIdx, spellID in ipairs(groupData.spells) do
                            local active = IsSpellActiveInViewer(spellID, activeSpellSet)
                            CreateSpellRow(groupContainer, spellID, groupIndex, spellY, active, spellIdx, spellCount)
                            spellY = spellY - ROW_HEIGHT
                        end
                    end

                    if not groupData.spells or #groupData.spells == 0 then
                        CreateEmptyListRow(groupContainer, L["Drag spells here"])
                        spellY = -ROW_HEIGHT
                    end

                    groupContainer:SetHeight(math.abs(spellY) + 4)
                    yOff = yOff + spellY - SECTION_GAP
                else
                    groupContainer:Hide()
                    yOff = yOff - SECTION_GAP
                end
            end
        end

        lc:SetHeight(math.abs(yOff) + 4)
    end

    RefreshAll = function()
        BuildLeftPanel()
    end

    page:SetScript("OnMouseUp", function()
        if dragState.active then
            EndDrag()
        end
    end)

    local evRegistry = EventRegistry
    local bgOwners = {}

    local function RegisterBGEventCallbacks()
        if not (evRegistry and evRegistry.RegisterCallback) then return end
        if bgOwners[1] then return end
        local o1, o2, o3, o4 = {}, {}, {}, {}
        bgOwners[1], bgOwners[2], bgOwners[3], bgOwners[4] = o1, o2, o3, o4
        evRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
            QueueLeftPanelRefresh(0.2)
        end, o1)
        evRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function()
            QueueLeftPanelRefresh(0.2)
        end, o2)
        evRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
            QueueLeftPanelRefresh(0.2)
        end, o3)
        evRegistry:RegisterCallback("CooldownViewerSettings.OnPendingChanges", function()
            QueueLeftPanelRefresh(0.3)
        end, o4)
    end

    local function UnregisterBGEventCallbacks()
        if not (evRegistry and evRegistry.UnregisterCallback) then return end
        if not bgOwners[1] then return end
        evRegistry:UnregisterCallback("CooldownViewerSettings.OnShow", bgOwners[1])
        evRegistry:UnregisterCallback("CooldownViewerSettings.OnHide", bgOwners[2])
        evRegistry:UnregisterCallback("CooldownViewerSettings.OnDataChanged", bgOwners[3])
        evRegistry:UnregisterCallback("CooldownViewerSettings.OnPendingChanges", bgOwners[4])
        table.wipe(bgOwners)
    end

    page:HookScript("OnHide", function()
        CloseRightPanelDropdownMenus()
        CancelDrag()
        UnregisterBGEventCallbacks()
    end)

    page:HookScript("OnShow", function()
        local prevSpecID = currentSpecID
        RefreshCurrentSpecID()
        RegisterBGEventCallbacks()
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

    RegisterBGEventCallbacks()
    BuildLeftPanel()
end

API:RegisterConfigTab("buffgroups", L["Buff Groups"], CreateBuffGroupsTab, 8)

