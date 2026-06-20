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
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local NormalizeToBase = API.NormalizeToBase

local function SaveAndRefresh()
    Shared.SaveVisualRefresh("BAR_DATA")
end

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
local BAR_TEXT_POSITIONS = { "LEFT", "CENTER", "RIGHT" }

StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_BAR_GROUP"] = {
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local fn = StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_BAR_GROUP"]._pendingDelete
        if fn then fn() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local BAR_GROW_OPTIONS = {
    { value = "DOWN", label = L["Down"] },
    { value = "UP",   label = L["Up"] },
}

local BAR_GROW_OPTIONS_GROUP = {
    { value = "DOWN",         label = L["Down"] },
    { value = "UP",           label = L["Up"] },
    { value = "CENTER_DOWN",  label = L["Centered, Grow Down"] },
    { value = "CENTER_UP",    label = L["Centered, Grow Up"] },
}

local function BarGrowLabel(v)
    for _, o in ipairs(BAR_GROW_OPTIONS_GROUP) do
        if o.value == v then return o.label end
    end
    return v or "Down"
end

local IsCenterGrow = CDM.IsBarCenterGrow

local BAR_FILL_OPTIONS = {
    { value = "LEFT_TO_RIGHT", label = (L["Left to Right"]) },
    { value = "RIGHT_TO_LEFT", label = (L["Right to Left"]) },
}

local BAR_FILL_OPTIONS_WITH_INHERIT = {
    { value = "__inherit__",   label = L["Inherit (group)"] },
    { value = "LEFT_TO_RIGHT", label = (L["Left to Right"]) },
    { value = "RIGHT_TO_LEFT", label = (L["Right to Left"]) },
}

local ICON_POSITION_OPTIONS = {
    { value = "LEFT",   label = L["Left"] },
    { value = "RIGHT",  label = L["Right"] },
    { value = "HIDDEN", label = L["Hidden"] },
}

local ICON_POSITION_OPTIONS_WITH_INHERIT = {
    { value = "__inherit__", label = L["Inherit (group)"] },
    { value = "LEFT",        label = L["Left"] },
    { value = "RIGHT",       label = L["Right"] },
    { value = "HIDDEN",      label = L["Hidden"] },
}

local ANCHOR_TARGET_OPTIONS = {
    { value = "screen",      label = L["Screen"] },
    { value = "playerFrame", label = L["Player Frame"] },
    { value = "essential",   label = L["Essential"] },
    { value = "resources",   label = L["Resources"] },
}

local ANCHOR_POINT_OPTIONS = {
    { value = "TOPLEFT", label = "TOPLEFT" },
    { value = "TOP", label = "TOP" },
    { value = "TOPRIGHT", label = "TOPRIGHT" },
    { value = "LEFT", label = "LEFT" },
    { value = "CENTER", label = "CENTER" },
    { value = "RIGHT", label = "RIGHT" },
    { value = "BOTTOMLEFT", label = "BOTTOMLEFT" },
    { value = "BOTTOM", label = "BOTTOM" },
    { value = "BOTTOMRIGHT", label = "BOTTOMRIGHT" },
}

local function CloneColor(c)
    if type(c) ~= "table" then return nil end
    return { r = c.r or 1, g = c.g or 1, b = c.b or 1, a = c.a or 1 }
end

local function BuildNewBarGroupSnapshot(newIndex)
    local db = CDM.db or {}
    return {
        name = "Group " .. newIndex,
        spells = {},
        spellOverrides = {},
        grow = "DOWN",
        spacing = db.buffBarSpacing or 1,
        barWidth = db.buffBarWidth or 0,
        barHeight = db.buffBarHeight or 20,
        texture = db.buffBarTexture or "Solid",
        barColor = CloneColor(db.buffBarColor) or { r = 0.4, g = 0.6, b = 0.9, a = 1 },
        backgroundColor = CloneColor(db.buffBarBackgroundColor) or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
        iconPosition = db.buffBarIconPosition or "LEFT",
        iconGap = db.buffBarIconGap or 1,
        showName = db.buffBarShowName ~= false,
        nameFontSize = db.buffBarNameFontSize or 15,
        nameColor = CloneColor(db.buffBarNameColor) or { r = 1, g = 1, b = 1, a = 1 },
        nameOffsetX = db.buffBarNameOffsetX or 2,
        nameOffsetY = db.buffBarNameOffsetY or 0,
        nameMaxChars = db.buffBarNameMaxChars or 0,
        showDuration = db.buffBarShowDuration ~= false,
        durationFontSize = db.buffBarDurationFontSize or 15,
        durationColor = CloneColor(db.buffBarDurationColor) or { r = 1, g = 1, b = 1, a = 1 },
        durationPosition = db.buffBarDurationPosition or "RIGHT",
        durationOffsetX = db.buffBarDurationOffsetX or -2,
        durationOffsetY = db.buffBarDurationOffsetY or 0,
        showApplications = db.buffBarShowApplications ~= false,
        applicationsFontSize = db.buffBarApplicationsFontSize or 15,
        applicationsColor = CloneColor(db.buffBarApplicationsColor) or { r = 1, g = 1, b = 1, a = 1 },
        applicationsPosition = db.buffBarApplicationsPosition or "CENTER",
        applicationsOffsetX = db.buffBarApplicationsOffsetX or 0,
        applicationsOffsetY = db.buffBarApplicationsOffsetY or 0,
        anchorTarget = "screen",
        anchorPoint = "TOP",
        anchorRelativeTo = "TOP",
        offsetX = 0,
        offsetY = 0,
        barFillDirection = db.buffBarFillDirection or "LEFT_TO_RIGHT",
    }
end

local function CreateBarsTab(page)
    local si = GetSpecialization()
    local currentSpecID = si and GetSpecializationInfo(si) or nil
    local playerSpecID = currentSpecID

    local selectedGroupIndex = nil
    local selectedSpellID = nil
    local selectedSpellGroupIndex = nil
    local expandedGroups = {}
    local RefreshAll
    local ShowSpellSettings
    local ShowGroupSettings
    local renameLastClickTime = 0
    local renameLastClickGroup = nil
    local renameActiveGroupIndex = nil
    local renameActiveEditBox = nil
    local pickerActiveGroupIndex = nil

    local _helpers = Shared.CreateGroupEditorHelpers({
        dbKey = "barGroups",
        ungroupedDbKey = "ungroupedBarOverrides",
        getCurrentSpecID = function() return currentSpecID end,
        setCurrentSpecID = function(v) currentSpecID = v end,
        getPlayerSpecID = function() return playerSpecID end,
        setPlayerSpecID = function(v) playerSpecID = v end,
        normalizeToBase = NormalizeToBase,
        extraCloneFields = {
            "barWidth", "barHeight", "texture", "iconGap",
            "wrapLimit", "hSpacing",
            "showName", "nameFontSize", "nameColor", "nameOffsetX", "nameOffsetY", "nameMaxChars",
            "showDuration", "durationFontSize", "durationColor", "durationPosition", "durationOffsetX", "durationOffsetY",
            "showApplications", "applicationsFontSize", "applicationsColor", "applicationsPosition", "applicationsOffsetX", "applicationsOffsetY",
            "iconPosition", "barColor", "backgroundColor", "barFillDirection",
        },
    })
    local RefreshCurrentSpecID = _helpers.RefreshCurrentSpecID
    local EnsureBarGroups = _helpers.EnsureGroups
    local GetSpecGroups = _helpers.GetSpecGroups
    local EnsureUngroupedOverrides = _helpers.EnsureUngroupedOverrides
    local GetUngroupedOverride = _helpers.GetUngroupedOverride
    local EnsureResolvedOverrideEntry = _helpers.EnsureResolvedOverrideEntry
    local ExtractMergedOverrideEntry = _helpers.ExtractMergedOverrideEntry
    local StoreMergedOverrideEntry = _helpers.StoreMergedOverrideEntry
    local EnsureSpellOverride = _helpers.EnsureSpellOverride
    local EnsureUngroupedOverrideEntry = _helpers.EnsureUngroupedOverrideEntry
    local CopyGroupSettingsToSpec = _helpers.CopyGroupSettingsToSpec
    local DuplicateGroup = _helpers.DuplicateGroup

    local function RefreshLeftPanelIfNeeded()
        if RefreshAll then RefreshAll() end
    end

    local function GetViewerSpellListForSpec(specID)
        if specID ~= playerSpecID then
            local seen, list = {}, {}
            local function AddCached(raw)
                if not raw then return end
                for _, entry in ipairs(raw) do
                    local cdID = entry.cooldownID
                    local sid = entry.spellID
                    if sid and cdID and not seen[cdID] then
                        seen[cdID] = true
                        list[#list + 1] = { cdID = cdID, spellID = sid }
                    end
                end
            end
            AddCached(API:GetSpecBarSpellCache(specID))
            AddCached(API:GetSpecBuffSpellCache(specID))
            return list
        end

        local seen, list = {}, {}
        local function AddByCooldownID(cdID, info)
            if not cdID or seen[cdID] then return end
            info = info or C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
            if not info then return end
            local sid = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
            if not sid then return end
            seen[cdID] = true
            list[#list + 1] = { cdID = cdID, spellID = sid }
        end

        local provider = CooldownViewerSettings and CooldownViewerSettings.GetDataProvider
                         and CooldownViewerSettings:GetDataProvider()
        if provider and provider.GetOrderedCooldownIDs then
            local cats = Enum.CooldownViewerCategory
            local TrackedBuff, TrackedBar, HiddenAura = cats.TrackedBuff, cats.TrackedBar, cats.HiddenAura
            for _, cdID in ipairs(provider:GetOrderedCooldownIDs()) do
                local info = provider:GetCooldownInfoForID(cdID)
                if info and (info.category == TrackedBuff
                          or info.category == TrackedBar
                          or info.category == HiddenAura) then
                    AddByCooldownID(cdID, info)
                end
            end
        else
            for _, cat in ipairs({
                Enum.CooldownViewerCategory.TrackedBar,
                Enum.CooldownViewerCategory.TrackedBuff,
            }) do
                local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
                if ids then
                    for _, cdID in ipairs(ids) do AddByCooldownID(cdID) end
                end
            end
        end

        API:ForEachActiveFrame({ "BuffBarCooldownViewer" }, function(frame)
            AddByCooldownID(frame.cooldownID)
        end)

        return list
    end

    local function GetUntrackedViewerSpellListForCurrentSpec()
        local activeCdIDSet = {}
        API:ForEachActiveFrame({ "BuffBarCooldownViewer" }, function(frame)
            if frame.cooldownID then activeCdIDSet[frame.cooldownID] = true end
        end)
        local all = GetViewerSpellListForSpec(playerSpecID)
        local result = {}
        for _, slot in ipairs(all) do
            if not activeCdIDSet[slot.cdID] then result[#result + 1] = slot end
        end
        return result
    end

    local function GetAvailableSpellsForPicker(specID)
        local allSlots = (specID == playerSpecID)
            and GetUntrackedViewerSpellListForCurrentSpec()
            or GetViewerSpellListForSpec(specID)
        local assigned = {}
        local groups = CDM.db.barGroups and CDM.db.barGroups[specID]
        if groups then
            for _, group in ipairs(groups) do
                for _, sid in ipairs(group.spells or {}) do
                    Shared.MarkEquivalentSpellIDs(assigned, sid)
                end
            end
        end
        local seen = {}
        local result = {}
        for _, slot in ipairs(allSlots) do
            local spellID = slot.spellID
            if not Shared.HasEquivalentSpellID(assigned, spellID) and not seen[slot.cdID] then
                seen[slot.cdID] = true
                local name = C_Spell.GetSpellName(spellID) or ("Spell " .. spellID)
                local icon = C_Spell.GetSpellTexture(spellID)
                local isKnown = IsPlayerSpell(spellID)
                result[#result + 1] = { spellID = spellID, name = name, icon = icon, isKnown = isKnown }
            end
        end
        table.sort(result, function(a, b) return a.name < b.name end)
        return result
    end

    local function MarkSafe(set, id)
        if IsSafeNumber(id) then set[id] = true end
    end

    local function BuildActiveBarSpellSet()
        local set = {}
        API:ForEachActiveFrame({ "BuffBarCooldownViewer" }, function(frame)
            MarkSafe(set, frame.GetSpellID and frame:GetSpellID())
            local catID = frame.cdmBarGroupSpellID
            if catID and catID ~= false then MarkSafe(set, catID) end
            local info = frame.GetCooldownInfo and frame:GetCooldownInfo() or frame.cooldownInfo
            if info then
                MarkSafe(set, info.spellID)
                if info.overrideSpellID and info.overrideSpellID ~= info.spellID then
                    MarkSafe(set, info.overrideSpellID)
                end
                if info.overrideTooltipSpellID then
                    MarkSafe(set, info.overrideTooltipSpellID)
                end
            end
        end)
        return set
    end

    local function IsSpellInActiveSet(activeSet, spellID)
        if not activeSet then return false end
        return activeSet[spellID] == true
    end

    local function GetUngroupedBarSpells()
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
        local list = {}
        if currentSpecID ~= playerSpecID then return list end

        API:ForEachActiveFrame({ "BuffBarCooldownViewer" }, function(frame)
            local matchType = API.GetBarRegistryMatch and API:GetBarRegistryMatch(frame) or nil
            if matchType then return end
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
            if IsSafeNumber(displayID)
                and not Shared.HasEquivalentSpellID(groupedSet, displayID)
                and not seen[displayID]
            then
                seen[displayID] = true
                local li = frame.layoutIndex
                local safeLayoutIndex = IsSafeNumber(li) and li or 0
                list[#list + 1] = { spellID = displayID, layoutIndex = safeLayoutIndex }
            end
        end)
        table.sort(list, function(a, b)
            if a.layoutIndex ~= b.layoutIndex then return a.layoutIndex < b.layoutIndex end
            return a.spellID < b.spellID
        end)
        return list
    end

    local QueueLeftPanelRefresh = Shared.CreateQueueLeftPanelRefresh(page, function() return RefreshAll end)

    local RegisterDropTarget, ClearDropTargets, StartDrag, EndDrag, CancelDrag
    do
        local dragDrop = Shared.CreateDragDropController({
            onDrop = function(spellID, sourceGroup, targetGroupIndex, hitDropTarget)
                if not spellID or not currentSpecID then return end
                if not hitDropTarget then return end
                if sourceGroup == targetGroupIndex then return end

                local groups = EnsureBarGroups()
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
                    local specOv = CDM.db.ungroupedBarOverrides and CDM.db.ungroupedBarOverrides[currentSpecID]
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

                SaveAndRefresh()
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

    local leftScroll = CreateFrame("ScrollFrame", "AyijeCDM_BarGroupsLeftScroll", page, "ScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", LEFT_INSET - SCROLL_LEFT_PAD, -56)
    leftScroll:SetPoint("BOTTOMLEFT", LEFT_INSET - SCROLL_LEFT_PAD, 20)
    leftScroll:SetWidth(LEFT_WIDTH + SCROLL_LEFT_PAD)

    local leftChild = CreateFrame("Frame", nil, leftScroll)
    leftChild:SetSize(LEFT_WIDTH + SCROLL_LEFT_PAD, 1200)
    leftScroll:SetScrollChild(leftChild)

    local PLACEHOLDER_HEIGHT = 60

    local rightPanel = CreateFrame("Frame", nil, page)
    rightPanel:SetPoint("TOPLEFT", RIGHT_X, -40)
    rightPanel:SetPoint("TOPRIGHT", -10, -40)
    rightPanel:SetHeight(PLACEHOLDER_HEIGHT)

    local rightPlaceholder = rightPanel:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    rightPlaceholder:SetPoint("TOP", 0, -20)
    rightPlaceholder:SetText(L["Select a group or spell to edit settings"])
    UI.SetTextMuted(rightPlaceholder)

    local function GetMaxRightPanelHeight()
        local pageH = page:GetHeight()
        if pageH <= 0 then return 600 end
        return math.max(PLACEHOLDER_HEIGHT, pageH - 60)
    end

    local function FitRightPanel(targetHeight)
        local maxH = GetMaxRightPanelHeight()
        local target = targetHeight or 0
        if target < PLACEHOLDER_HEIGHT then target = PLACEHOLDER_HEIGHT end
        if target > maxH then target = maxH end
        rightPanel:SetHeight(target)
    end

    local rightPanelManager = Shared.CreateRightPanelManager(rightPanel, rightPlaceholder, DestroyFrame)
    local RegisterRightPanelDropdown = rightPanelManager.RegisterDropdown
    local CreateRightScrollContent = rightPanelManager.CreateScrollContent
    local ClearRightPanel = function()
        pickerActiveGroupIndex = nil
        rightPanelManager.Clear()
        rightPanel:SetHeight(PLACEHOLDER_HEIGHT)
    end

    local function CreateRenderHelpers(rc)
        local yOff = 0
        local firstSection = true
        local h = {}

        function h.SectionHeader(text)
            if not firstSection then yOff = yOff - 10 end
            firstSection = false
            local fs = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
            fs:SetPoint("TOPLEFT", 0, yOff)
            fs:SetText(text)
            if CDM_C.GOLD then fs:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1) end
            yOff = yOff - 34
            return fs
        end

        function h.Label(text)
            local fs = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            fs:SetText(text)
            fs:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 22
            return fs
        end

        function h.Slider(label, minVal, maxVal, currentVal, onChange)
            local s = CreateSlider(rc, label, minVal, maxVal, currentVal, onChange)
            s:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 50
            return s
        end

        function h.Dropdown(width, defaultLabel)
            local dd = RegisterRightPanelDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
            dd:SetWidth(width or 180)
            dd:SetPoint("TOPLEFT", 0, yOff)
            dd:SetDefaultText(defaultLabel or "")
            yOff = yOff - 40
            return dd
        end

        function h.ColorPicker(initial, onChange)
            local picker = UI.CreateSimpleColorPicker(rc, initial or { r = 1, g = 1, b = 1 }, onChange, true)
            picker:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 30
            return picker
        end

        function h.Checkbox(label, currentVal, onChange)
            local cb = UI.CreateModernCheckbox(rc, label, currentVal and true or false, onChange)
            cb:SetPoint("TOPLEFT", 0, yOff)
            yOff = yOff - 32
            return cb
        end

        function h.GetYOff() return yOff end
        function h.AddYOff(delta) yOff = yOff + delta end
        function h.SetYOff(v) yOff = v end

        function h.GetHeight()
            return -yOff
        end

        return h
    end

    local function RenderBarGroupSettings(rc, gd, groupIndex)
        local h = CreateRenderHelpers(rc)
        h.SectionHeader(gd.name or ("Group " .. groupIndex))

        h.SectionHeader(L["Layout"])

        h.Label(L["Grow Direction"])
        local growDD = h.Dropdown(180, BarGrowLabel(gd.grow))
        UI.SetupValueDropdown(growDD, BAR_GROW_OPTIONS_GROUP,
            function() return gd.grow or "DOWN" end,
            function(v)
                local wasWrap = IsCenterGrow(gd.grow)
                gd.grow = v
                growDD:SetDefaultText(BarGrowLabel(v))
                SaveAndRefresh()
                if wasWrap ~= IsCenterGrow(v) then
                    C_Timer.After(0, function() ShowGroupSettings(groupIndex) end)
                end
            end
        )

        if IsCenterGrow(gd.grow) then
            h.Slider(L["Wrap Limit"], 2, 5, gd.wrapLimit or 2, function(v) gd.wrapLimit = v; SaveAndRefresh() end)
            h.Slider(L["Horizontal Spacing"], -1, 30, gd.hSpacing or 1, function(v) gd.hSpacing = v; SaveAndRefresh() end)
        end

        h.Slider(L["Spacing"], -1, 30, gd.spacing or 1, function(v) gd.spacing = v; SaveAndRefresh() end)
        h.Slider(L["Bar Width (0 = Auto)"], 0, 600, gd.barWidth or 0, function(v) gd.barWidth = v; SaveAndRefresh() end)
        h.Slider(L["Bar Height"], 4, 40, gd.barHeight or 20, function(v) gd.barHeight = v; SaveAndRefresh() end)

        h.SectionHeader(L["Appearance"])

        h.Label(L["Bar Texture:"])
        local texDD = h.Dropdown(220, gd.texture or "Solid")
        UI.SetupMediaDropdown(texDD, "statusbar",
            function() return gd.texture or "Solid" end,
            function(name) gd.texture = name; SaveAndRefresh() end,
            function(name) texDD:SetDefaultText(name or "Solid") end
        )

        h.Label(L["Bar Color"])
        h.ColorPicker(gd.barColor, function(r, g, b, a)
            if not gd.barColor then gd.barColor = {} end
            gd.barColor.r, gd.barColor.g, gd.barColor.b, gd.barColor.a = r, g, b, a or 1
            SaveAndRefresh()
        end)

        h.Label(L["Background Color"])
        h.ColorPicker(gd.backgroundColor, function(r, g, b, a)
            if not gd.backgroundColor then gd.backgroundColor = {} end
            gd.backgroundColor.r, gd.backgroundColor.g, gd.backgroundColor.b, gd.backgroundColor.a = r, g, b, a or 1
            SaveAndRefresh()
        end)

        h.Label(L["Icon Position:"])
        local ipDD = h.Dropdown(180, gd.iconPosition or "LEFT")
        UI.SetupValueDropdown(ipDD, ICON_POSITION_OPTIONS,
            function() return gd.iconPosition or "LEFT" end,
            function(v) gd.iconPosition = v; ipDD:SetDefaultText(v); SaveAndRefresh() end
        )

        h.Label(L["Fill Direction"])
        local fillLabel = gd.barFillDirection == "RIGHT_TO_LEFT" and (L["Right to Left"]) or (L["Left to Right"])
        local fillDD = h.Dropdown(180, fillLabel)
        UI.SetupValueDropdown(fillDD, BAR_FILL_OPTIONS,
            function() return gd.barFillDirection or "LEFT_TO_RIGHT" end,
            function(v)
                gd.barFillDirection = v
                fillDD:SetDefaultText(v == "RIGHT_TO_LEFT" and (L["Right to Left"]) or (L["Left to Right"]))
                SaveAndRefresh()
            end
        )

        h.Slider(L["Icon-Bar Gap"], -1, 20, gd.iconGap or 1, function(v) gd.iconGap = v; SaveAndRefresh() end)

        h.SectionHeader(L["Text"])

        h.Checkbox(L["Show Buff Name"], gd.showName ~= false, function(checked) gd.showName = checked; SaveAndRefresh() end)
        h.Slider(L["Name Font Size"], 6, 32, gd.nameFontSize or 15, function(v) gd.nameFontSize = v; SaveAndRefresh() end)
        h.Label(L["Name Color"])
        h.ColorPicker(gd.nameColor, function(r, g, b, a)
            if not gd.nameColor then gd.nameColor = {} end
            gd.nameColor.r, gd.nameColor.g, gd.nameColor.b, gd.nameColor.a = r, g, b, a or 1
            SaveAndRefresh()
        end)
        h.Slider(L["Name X Offset"], -50, 50, gd.nameOffsetX or 0, function(v) gd.nameOffsetX = v; SaveAndRefresh() end)
        h.Slider(L["Name Y Offset"], -20, 20, gd.nameOffsetY or 0, function(v) gd.nameOffsetY = v; SaveAndRefresh() end)
        h.Slider(L["Max Name Length (0 = Full)"], 0, 30, gd.nameMaxChars or 0, function(v) gd.nameMaxChars = v; SaveAndRefresh() end)

        h.Checkbox(L["Show Duration Text"], gd.showDuration ~= false, function(checked) gd.showDuration = checked; SaveAndRefresh() end)
        h.Slider(L["Duration Font Size"], 6, 32, gd.durationFontSize or 15, function(v) gd.durationFontSize = v; SaveAndRefresh() end)
        h.Label(L["Duration Color"])
        h.ColorPicker(gd.durationColor, function(r, g, b, a)
            if not gd.durationColor then gd.durationColor = {} end
            gd.durationColor.r, gd.durationColor.g, gd.durationColor.b, gd.durationColor.a = r, g, b, a or 1
            SaveAndRefresh()
        end)
        h.Label(L["Duration Position"])
        local durPosDD = h.Dropdown(180, gd.durationPosition or "RIGHT")
        UI.SetupPositionDropdown(durPosDD,
            function() return gd.durationPosition or "RIGHT" end,
            function(v) gd.durationPosition = v; durPosDD:SetDefaultText(v); SaveAndRefresh() end,
            BAR_TEXT_POSITIONS
        )
        h.Slider(L["Duration X Offset"], -50, 50, gd.durationOffsetX or 0, function(v) gd.durationOffsetX = v; SaveAndRefresh() end)
        h.Slider(L["Duration Y Offset"], -20, 20, gd.durationOffsetY or 0, function(v) gd.durationOffsetY = v; SaveAndRefresh() end)

        h.Checkbox(L["Show Stack Count"], gd.showApplications ~= false, function(checked) gd.showApplications = checked; SaveAndRefresh() end)
        h.Slider(L["Applications Font Size"], 6, 32, gd.applicationsFontSize or 15, function(v) gd.applicationsFontSize = v; SaveAndRefresh() end)
        h.Label(L["Applications Color"])
        h.ColorPicker(gd.applicationsColor, function(r, g, b, a)
            if not gd.applicationsColor then gd.applicationsColor = {} end
            gd.applicationsColor.r, gd.applicationsColor.g, gd.applicationsColor.b, gd.applicationsColor.a = r, g, b, a or 1
            SaveAndRefresh()
        end)
        h.Label(L["Applications Position"])
        local appPosDD = h.Dropdown(180, gd.applicationsPosition or "CENTER")
        UI.SetupPositionDropdown(appPosDD,
            function() return gd.applicationsPosition or "CENTER" end,
            function(v) gd.applicationsPosition = v; appPosDD:SetDefaultText(v); SaveAndRefresh() end,
            BAR_TEXT_POSITIONS
        )
        h.Slider(L["Applications X Offset"], -50, 50, gd.applicationsOffsetX or 0, function(v) gd.applicationsOffsetX = v; SaveAndRefresh() end)
        h.Slider(L["Applications Y Offset"], -20, 20, gd.applicationsOffsetY or 0, function(v) gd.applicationsOffsetY = v; SaveAndRefresh() end)

        h.SectionHeader(L["Anchor"])

        local UpdateAnchorVisibility
        local xSlider, ySlider, apLabel, apDD, rpLabel, rpDD

        h.Label(L["Anchor Target"])
        local atDD = h.Dropdown(180, gd.anchorTarget or "screen")
        UI.SetupValueDropdown(atDD, ANCHOR_TARGET_OPTIONS,
            function() return gd.anchorTarget or "screen" end,
            function(v)
                local prev = gd.anchorTarget or "screen"
                gd.anchorTarget = v
                gd.anchorPoint = gd.anchorPoint or "TOP"
                gd.anchorRelativeTo = gd.anchorRelativeTo or "TOP"
                if v ~= prev then
                    gd.offsetX = 0
                    gd.offsetY = 0
                    if xSlider and xSlider.UpdateUIValue then xSlider:UpdateUIValue(0) end
                    if ySlider and ySlider.UpdateUIValue then ySlider:UpdateUIValue(0) end
                end
                atDD:SetDefaultText(v)
                SaveAndRefresh()
                if UpdateAnchorVisibility then UpdateAnchorVisibility() end
            end
        )
        local yAfterTarget = h.GetYOff()

        apLabel = h.Label(L["Anchor Point"])
        apDD = h.Dropdown(180, gd.anchorPoint or "TOP")
        UI.SetupValueDropdown(apDD, ANCHOR_POINT_OPTIONS,
            function() return gd.anchorPoint or "TOP" end,
            function(v) gd.anchorPoint = v; apDD:SetDefaultText(v); SaveAndRefresh() end
        )

        rpLabel = h.Label(L["Relative Point"])
        rpDD = h.Dropdown(180, gd.anchorRelativeTo or "TOP")
        UI.SetupValueDropdown(rpDD, ANCHOR_POINT_OPTIONS,
            function() return gd.anchorRelativeTo or "TOP" end,
            function(v) gd.anchorRelativeTo = v; rpDD:SetDefaultText(v); SaveAndRefresh() end
        )
        local yAfterConditional = h.GetYOff()

        xSlider = h.Slider(L["X Offset"], -1000, 1000, gd.offsetX or 0, function(v) gd.offsetX = v; SaveAndRefresh() end)
        ySlider = h.Slider(L["Y Offset"], -1000, 1000, gd.offsetY or 0, function(v) gd.offsetY = v; SaveAndRefresh() end)

        UpdateAnchorVisibility = function()
            local isScreen = (gd.anchorTarget or "screen") == "screen"
            apLabel:SetShown(not isScreen)
            apDD:SetShown(not isScreen)
            rpLabel:SetShown(not isScreen)
            rpDD:SetShown(not isScreen)
            local sliderY = isScreen and yAfterTarget or yAfterConditional
            xSlider:ClearAllPoints(); xSlider:SetPoint("TOPLEFT", 0, sliderY)
            ySlider:ClearAllPoints(); ySlider:SetPoint("TOPLEFT", 0, sliderY - 50)

            local effectiveRcHeight = -(sliderY - 100) + 20
            if rc.SetHeight then rc:SetHeight(effectiveRcHeight) end
            FitRightPanel(effectiveRcHeight + 20)
        end
        UpdateAnchorVisibility()

        return h.GetHeight() + 20
    end

    local function RenderUngroupedSettings(rc)
        local h = CreateRenderHelpers(rc)
        local db = CDM.db

        h.SectionHeader(L["Ungrouped Bar Settings"])

        h.SectionHeader(L["Layout"])

        h.Label(L["Grow Direction"])
        local growDD = h.Dropdown(180, db.buffBarGrowDirection or "DOWN")
        UI.SetupValueDropdown(growDD, BAR_GROW_OPTIONS,
            function() return db.buffBarGrowDirection or "DOWN" end,
            function(v) db.buffBarGrowDirection = v; growDD:SetDefaultText(v == "UP" and (L["Up"]) or (L["Down"])); SaveAndRefresh() end
        )

        h.Slider(L["Bar Width (0 = Auto)"], 0, 600, db.buffBarWidth or 0, function(v) db.buffBarWidth = v; SaveAndRefresh() end)
        h.Slider(L["Bar Height"], 4, 40, db.buffBarHeight or 20, function(v) db.buffBarHeight = v; SaveAndRefresh() end)
        h.Slider(L["Bar Spacing"], -1, 20, db.buffBarSpacing or 2, function(v) db.buffBarSpacing = v; SaveAndRefresh() end)

        h.SectionHeader(L["Appearance"])

        h.Label(L["Bar Texture:"])
        local texDD = h.Dropdown(220, db.buffBarTexture or "Solid")
        UI.SetupMediaDropdown(texDD, "statusbar",
            function() return db.buffBarTexture or "Solid" end,
            function(name) db.buffBarTexture = name; SaveAndRefresh() end,
            function(name) texDD:SetDefaultText(name or "Solid") end
        )

        h.Label(L["Bar Color"])
        h.ColorPicker(db.buffBarColor, function(r, g, b, a)
            db.buffBarColor = { r = r, g = g, b = b, a = a or 1 }
            SaveAndRefresh()
        end)

        h.Label(L["Background Color"])
        h.ColorPicker(db.buffBarBackgroundColor, function(r, g, b, a)
            db.buffBarBackgroundColor = { r = r, g = g, b = b, a = a or 1 }
            SaveAndRefresh()
        end)

        h.Label(L["Fill Direction"])
        local fillLabel = db.buffBarFillDirection == "RIGHT_TO_LEFT" and (L["Right to Left"]) or (L["Left to Right"])
        local fillDD = h.Dropdown(180, fillLabel)
        UI.SetupValueDropdown(fillDD, BAR_FILL_OPTIONS,
            function() return db.buffBarFillDirection or "LEFT_TO_RIGHT" end,
            function(v)
                db.buffBarFillDirection = v
                fillDD:SetDefaultText(v == "RIGHT_TO_LEFT" and (L["Right to Left"]) or (L["Left to Right"]))
                SaveAndRefresh()
            end
        )

        h.SectionHeader(L["Icon"])

        h.Label(L["Icon Position:"])
        local ipDD = h.Dropdown(180, db.buffBarIconPosition or "LEFT")
        UI.SetupValueDropdown(ipDD, ICON_POSITION_OPTIONS,
            function() return db.buffBarIconPosition or "LEFT" end,
            function(v) db.buffBarIconPosition = v; ipDD:SetDefaultText(v); SaveAndRefresh() end
        )

        h.Slider(L["Icon-Bar Gap"], -1, 20, db.buffBarIconGap or 2, function(v) db.buffBarIconGap = v; SaveAndRefresh() end)

        h.SectionHeader(L["Visibility"])

        h.Checkbox(L["Show Buff Name"], db.buffBarShowName ~= false, function(checked) db.buffBarShowName = checked; SaveAndRefresh() end)
        h.Slider(L["Max Name Length (0 = Full)"], 0, 30, db.buffBarNameMaxChars or 0, function(v) db.buffBarNameMaxChars = v; SaveAndRefresh() end)
        h.Checkbox(L["Show Duration Text"], db.buffBarShowDuration ~= false, function(checked) db.buffBarShowDuration = checked; SaveAndRefresh() end)
        h.Checkbox(L["Show Stack Count"], db.buffBarShowApplications ~= false, function(checked) db.buffBarShowApplications = checked; SaveAndRefresh() end)

        return h.GetHeight() + 20
    end

    ShowGroupSettings = function(groupIndex)
        pickerActiveGroupIndex = nil
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then ClearRightPanel(); return end
        local _, rc = CreateRightScrollContent(1600)
        RenderBarGroupSettings(rc, groups[groupIndex], groupIndex)
    end

    local ShowUngroupedSettings = function()
        pickerActiveGroupIndex = nil
        selectedGroupIndex = nil
        selectedSpellID = nil
        selectedSpellGroupIndex = nil
        local _, rc = CreateRightScrollContent(900)
        local height = RenderUngroupedSettings(rc)
        if rc.SetHeight then rc:SetHeight(height + 40) end
        FitRightPanel(height + 40)
    end

    local function RenderSpellOverrideSettings(rc, gd, groupIndex, spellID)
        local h = CreateRenderHelpers(rc)

        local spellName = C_Spell.GetSpellName(spellID) or ("Spell " .. spellID)
        h.SectionHeader(spellName)

        local function GetOverride()
            if groupIndex then
                local groups = CDM.db.barGroups and CDM.db.barGroups[currentSpecID]
                local groupData = groups and groups[groupIndex]
                if not groupData then return nil end
                if not groupData.spellOverrides then return nil end
                return API:ResolveBarOverrideEntry(groupData.spellOverrides, spellID)
            else
                local specOv = CDM.db.ungroupedBarOverrides and CDM.db.ungroupedBarOverrides[currentSpecID]
                if not specOv then return nil end
                return API:ResolveBarOverrideEntry(specOv, spellID)
            end
        end

        local function EnsureOverride()
            if groupIndex then
                return EnsureSpellOverride(groupIndex, spellID)
            else
                return EnsureUngroupedOverrideEntry(spellID)
            end
        end

        local ov = GetOverride()

        local barColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        barColorLabel:SetText(L["Bar Color (override)"])
        barColorLabel:SetPoint("TOPLEFT", 0, h.GetYOff())
        local barColorVal = (ov and ov.barColor) or { r = 1, g = 1, b = 1, a = 1 }
        local picker = UI.CreateSimpleColorPicker(rc, barColorVal, function(r, g, b, a)
            local entry = EnsureOverride()
            if not entry then return end
            entry.barColor = { r = r, g = g, b = b, a = a or 1 }
            SaveAndRefresh()
        end, true)
        picker:SetPoint("LEFT", barColorLabel, "RIGHT", 6, 0)
        local clearBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
        clearBtn:SetSize(80, 22)
        clearBtn:SetText(L["Clear"])
        clearBtn:SetPoint("LEFT", picker, "RIGHT", 6, 0)
        clearBtn:SetScript("OnClick", function()
            local entry = EnsureOverride()
            if entry then entry.barColor = nil; SaveAndRefresh(); ShowSpellSettings(spellID, groupIndex) end
        end)
        h.AddYOff(-36)

        local bgColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        bgColorLabel:SetText(L["Background Color (override)"])
        bgColorLabel:SetPoint("TOPLEFT", 0, h.GetYOff())
        local bgColorVal = (ov and ov.backgroundColor) or { r = 1, g = 1, b = 1, a = 1 }
        local bgPicker = UI.CreateSimpleColorPicker(rc, bgColorVal, function(r, g, b, a)
            local entry = EnsureOverride()
            if not entry then return end
            entry.backgroundColor = { r = r, g = g, b = b, a = a or 1 }
            SaveAndRefresh()
        end, true)
        bgPicker:SetPoint("LEFT", bgColorLabel, "RIGHT", 6, 0)
        local bgClearBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
        bgClearBtn:SetSize(80, 22)
        bgClearBtn:SetText(L["Clear"])
        bgClearBtn:SetPoint("LEFT", bgPicker, "RIGHT", 6, 0)
        bgClearBtn:SetScript("OnClick", function()
            local entry = EnsureOverride()
            if entry then entry.backgroundColor = nil; SaveAndRefresh(); ShowSpellSettings(spellID, groupIndex) end
        end)
        h.AddYOff(-36)

        h.Label(L["Icon Position (override)"])
        local ipVal = (ov and ov.iconPosition) or "__inherit__"
        local ipLabel = ipVal == "__inherit__" and (L["Inherit (group)"]) or ipVal
        local ipDD = h.Dropdown(180, ipLabel)
        UI.SetupValueDropdown(ipDD, ICON_POSITION_OPTIONS_WITH_INHERIT,
            function()
                local cur = GetOverride()
                return (cur and cur.iconPosition) or "__inherit__"
            end,
            function(v)
                local entry = EnsureOverride()
                if not entry then return end
                if v == "__inherit__" then entry.iconPosition = nil else entry.iconPosition = v end
                ipDD:SetDefaultText(v == "__inherit__" and (L["Inherit (group)"]) or v)
                SaveAndRefresh()
            end
        )

        h.Label(L["Fill Direction (override)"])
        local fdVal = (ov and ov.barFillDirection) or "__inherit__"
        local fdLabel = fdVal == "__inherit__" and (L["Inherit (group)"]) or fdVal
        local fdDD = h.Dropdown(180, fdLabel)
        UI.SetupValueDropdown(fdDD, BAR_FILL_OPTIONS_WITH_INHERIT,
            function()
                local cur = GetOverride()
                return (cur and cur.barFillDirection) or "__inherit__"
            end,
            function(v)
                local entry = EnsureOverride()
                if not entry then return end
                if v == "__inherit__" then entry.barFillDirection = nil else entry.barFillDirection = v end
                fdDD:SetDefaultText(v == "__inherit__" and (L["Inherit (group)"]) or v)
                SaveAndRefresh()
            end
        )

        h.Checkbox(L["Hide Name"], (ov and ov.nameHidden) == true, function(checked)
            local entry = EnsureOverride()
            if not entry then return end
            entry.nameHidden = checked or nil
            SaveAndRefresh()
        end)

        h.Checkbox(L["Hide Duration"], (ov and ov.durationHidden) == true, function(checked)
            local entry = EnsureOverride()
            if not entry then return end
            entry.durationHidden = checked or nil
            SaveAndRefresh()
        end)

        h.Slider(L["Bar Height (0 = Inherit)"], 0, 40, (ov and ov.barHeight) or 0, function(v)
            local entry = EnsureOverride()
            if not entry then return end
            entry.barHeight = (v and v > 0) and v or nil
            SaveAndRefresh()
        end)

        h.Label(L["Custom Name (override)"])
        local nameBox = CreateFrame("EditBox", nil, rc, "InputBoxTemplate")
        nameBox:SetHeight(22)
        nameBox:SetPoint("TOPLEFT", 8, h.GetYOff())
        nameBox:SetPoint("RIGHT", rc, "RIGHT", -8, 0)
        nameBox:SetFontObject("AyijeCDM_Font14")
        nameBox:SetAutoFocus(false)
        nameBox:SetMaxLetters(60)
        nameBox:SetText((ov and ov.customName) or "")
        nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nameBox:SetScript("OnEscapePressed", function(self)
            self:SetText((GetOverride() and GetOverride().customName) or "")
            self:ClearFocus()
        end)
        nameBox:SetScript("OnEditFocusLost", function(self)
            local txt = self:GetText()
            if txt == "" then txt = nil end
            local entry = EnsureOverride()
            if not entry then return end
            if entry.customName ~= txt then
                entry.customName = txt
                SaveAndRefresh()
            end
        end)
        h.AddYOff(-26)
        local hint = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font12")
        hint:SetText(L["(empty = real spell name)"])
        UI.SetTextMuted(hint)
        hint:SetPoint("TOPLEFT", 0, h.GetYOff())
        h.AddYOff(-18)

        return h.GetHeight() + 20
    end

    ShowSpellSettings = function(spellID, groupIndex)
        pickerActiveGroupIndex = nil
        selectedSpellID = spellID
        selectedSpellGroupIndex = groupIndex
        local _, rc = CreateRightScrollContent(500)
        local h = RenderSpellOverrideSettings(rc, nil, groupIndex, spellID)
        if rc.SetHeight then rc:SetHeight(h + 40) end
        FitRightPanel(h + 40)
    end

    local function ShowSpellPickerPanel(groupIndex)
        pickerActiveGroupIndex = groupIndex
        local spells = GetAvailableSpellsForPicker(currentSpecID)
        local pickerRc = Shared.RenderSpellPicker({
            createRightScrollContent = function(h) return CreateRightScrollContent(h) end,
            minHeight = 700,
            headerText = L["Add Spell"],
            headerColor = CDM_C.GOLD or { r = 1, g = 0.82, b = 0 },
            spells = spells,
            emptyText = L["No more bar-trackable spells available for this spec."],
            cacheMissingText = L["Spell cache missing for this spec."],
            isCacheMissing = currentSpecID ~= playerSpecID
                and not API:GetSpecBarSpellCache(currentSpecID)
                and not API:GetSpecBuffSpellCache(currentSpecID),
            currentSpecID = currentSpecID,
            playerSpecID = playerSpecID,
            doneText = L["Back"],
            onSelect = function(spellID)
                local groups = EnsureBarGroups()
                if not groups then return end
                if groupIndex then
                    local gd = groups[groupIndex]
                    if gd then
                        if not gd.spells then gd.spells = {} end
                        Shared.AddSpellToGroupList(gd.spells, spellID)
                    end
                end
                SaveAndRefresh()
                RefreshLeftPanelIfNeeded()
                ShowSpellSettings(spellID, groupIndex)
            end,
            onDone = function()
                if groupIndex then ShowGroupSettings(groupIndex) else ClearRightPanel() end
            end,
        })
        if pickerRc and pickerRc.GetHeight then FitRightPanel(pickerRc:GetHeight() + 40) end
    end

    local headerPool, groupContainerPool, emptyRowPool =
        Shared.CreateGroupEditorPools(leftChild, {
            iconSize = ICON_SIZE,
            rowHeight = ROW_HEIGHT,
            highlightAlpha = 0.2,
        })
    local spellRowPool = Shared.CreateBarRowPool(leftChild, {
        rowHeight = ROW_HEIGHT,
        barHeight = ICON_SIZE,
        iconSize = ICON_SIZE,
    })

    local ungroupedHeader = UI.CreateHeader(leftChild, L["Ungrouped Bars"])

    local ungroupedContainer = CreateFrame("Frame", nil, leftChild)
    ungroupedContainer:SetSize(LEFT_WIDTH, 10)
    local ungroupedHighlight = ungroupedContainer:CreateTexture(nil, "BACKGROUND")
    ungroupedHighlight:SetAllPoints()
    ungroupedHighlight:SetColorTexture(0.2, 0.6, 0.2, 0.2)
    ungroupedHighlight:Hide()
    ungroupedContainer.highlight = ungroupedHighlight

    local btnRefs = {}

    local function ConfigureHeaderRow(widget, groupIndex, groupData, isExpanded, isSelected, yOff)
        Shared.ConfigureExpandableHeader(widget, yOff, isExpanded, groupData.name or ("Group " .. groupIndex), isSelected)

        widget.expandBtn:SetScript("OnClick", function()
            expandedGroups[groupIndex] = not isExpanded
            RefreshAll()
        end)

        widget.selectBtn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                MenuUtil.CreateContextMenu(widget.selectBtn, function(_, rootDescription)
                    Shared.BuildGroupContextMenu(rootDescription,
                        { rename = L["Rename"], duplicate = L["Duplicate"], copyTo = L["Copy to"] },
                        function()
                            renameActiveGroupIndex = groupIndex
                            renameActiveEditBox = Shared.SetupRenameEditBox(widget.row, widget.bgLeft, widget.bgRight, widget.nameText,
                                groupData.name or ("Group " .. groupIndex),
                                function(newName)
                                    groupData.name = newName
                                    renameActiveEditBox = nil
                                    renameActiveGroupIndex = nil
                                    SaveAndRefresh()
                                    RefreshAll()
                                end,
                                function()
                                    renameActiveEditBox = nil
                                    renameActiveGroupIndex = nil
                                    widget.nameText:Show()
                                end
                            )
                        end,
                        function()
                            local specGroups = EnsureBarGroups()
                            if not specGroups then return end
                            local newIdx = DuplicateGroup(groupData, specGroups)
                            expandedGroups[newIdx] = true
                            selectedGroupIndex = newIdx
                            selectedSpellID = nil
                            selectedSpellGroupIndex = nil
                            SaveAndRefresh()
                            ShowGroupSettings(newIdx)
                            RefreshAll()
                        end,
                        function(specID)
                            CopyGroupSettingsToSpec(groupData, specID)
                            if specID == currentSpecID then RefreshAll() end
                            if specID == playerSpecID then SaveAndRefresh() end
                        end
                    )
                end)
                return
            end
            if button == "LeftButton" then
                local now = GetTime()
                if renameLastClickGroup == groupIndex and (now - renameLastClickTime) < 0.4 then
                    renameLastClickTime = 0
                    renameLastClickGroup = nil
                    renameActiveGroupIndex = groupIndex
                    renameActiveEditBox = Shared.SetupRenameEditBox(widget.row, widget.bgLeft, widget.bgRight, widget.nameText,
                        groupData.name or ("Group " .. groupIndex),
                        function(newName)
                            groupData.name = newName
                            renameActiveEditBox = nil
                            renameActiveGroupIndex = nil
                            SaveAndRefresh()
                            RefreshAll()
                        end,
                        function()
                            renameActiveEditBox = nil
                            renameActiveGroupIndex = nil
                            widget.nameText:Show()
                        end
                    )
                    return
                end
                renameLastClickTime = now
                renameLastClickGroup = groupIndex

                selectedGroupIndex = groupIndex
                selectedSpellID = nil
                selectedSpellGroupIndex = nil
                ShowGroupSettings(groupIndex)
                RefreshAll()
            end
        end)

        widget.deleteBtn:SetScript("OnClick", function()
            StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_BAR_GROUP"].text = string.format(
                L["Delete bar group '%s'?"],
                groupData.name or ("Group " .. groupIndex))
            StaticPopupDialogs["AYIJE_CDM_CONFIRM_DELETE_BAR_GROUP"]._pendingDelete = function()
                local needReshow = false
                local g = EnsureBarGroups()
                if g then
                    local gd = g[groupIndex]
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
                    table.remove(g, groupIndex)
                end
                if selectedGroupIndex == groupIndex then
                    selectedGroupIndex = nil
                    selectedSpellID = nil
                    ClearRightPanel()
                elseif selectedGroupIndex and selectedGroupIndex > groupIndex then
                    selectedGroupIndex = selectedGroupIndex - 1
                    needReshow = true
                end
                if selectedSpellGroupIndex then
                    if selectedSpellGroupIndex == groupIndex then
                        selectedSpellGroupIndex = nil
                        selectedSpellID = nil
                    elseif selectedSpellGroupIndex > groupIndex then
                        selectedSpellGroupIndex = selectedSpellGroupIndex - 1
                        needReshow = true
                    end
                end
                if pickerActiveGroupIndex then
                    if pickerActiveGroupIndex == groupIndex then
                        pickerActiveGroupIndex = nil
                        ClearRightPanel()
                    elseif pickerActiveGroupIndex > groupIndex then
                        pickerActiveGroupIndex = pickerActiveGroupIndex - 1
                        needReshow = true
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
                SaveAndRefresh()
                RefreshAll()
                if needReshow then
                    if pickerActiveGroupIndex then
                        ShowSpellPickerPanel(pickerActiveGroupIndex)
                    elseif selectedSpellID then
                        ShowSpellSettings(selectedSpellID, selectedSpellGroupIndex)
                    elseif selectedGroupIndex then
                        ShowGroupSettings(selectedGroupIndex)
                    end
                end
            end
            StaticPopup_Show("AYIJE_CDM_CONFIRM_DELETE_BAR_GROUP")
        end)
    end

    local DEFAULT_BAR_COLOR = { r = 0.4, g = 0.6, b = 0.9, a = 1 }
    local DEFAULT_BG_COLOR = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    local FALLBACK_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

    local function ResolveBarPreviewStyle(gd, sid)
        local db = CDM.db or {}
        local ov
        if gd then
            if gd.spellOverrides and sid then
                ov = API:ResolveBarOverrideEntry(gd.spellOverrides, sid)
            end
        else
            local specOv = db.ungroupedBarOverrides and db.ungroupedBarOverrides[currentSpecID]
            if specOv and sid then
                ov = API:ResolveBarOverrideEntry(specOv, sid)
            end
        end

        local textureName = (gd and gd.texture) or db.buffBarTexture or "Solid"
        local barColor = (ov and ov.barColor) or (gd and gd.barColor) or db.buffBarColor or DEFAULT_BAR_COLOR
        local bgColor = (ov and ov.backgroundColor) or (gd and gd.backgroundColor) or db.buffBarBackgroundColor or DEFAULT_BG_COLOR
        local texture = (LSM and LSM:Fetch("statusbar", textureName)) or FALLBACK_TEXTURE
        return texture, barColor, bgColor
    end

    local function ConfigureSpellRow(widget, parent, sid, groupIndex, yOff, isSelected, spellIndex, spellCount, tooltipOverrideMap, isActive)
        widget.root:SetParent(parent)
        widget.root:ClearAllPoints()
        widget.root:SetPoint("TOPLEFT", 8, yOff)
        widget.root:Show()

        local displayID = (tooltipOverrideMap and tooltipOverrideMap[sid]) or sid
        widget.iconTex:SetTexture(C_Spell.GetSpellTexture(displayID))
        widget.nameText:SetText(C_Spell.GetSpellName(displayID) or ("Spell " .. sid))

        local gd
        if groupIndex then
            local specGroups = GetSpecGroups()
            gd = specGroups and specGroups[groupIndex] or nil
        end
        local texture, barColor, bgColor = ResolveBarPreviewStyle(gd, sid)
        widget.bar:SetStatusBarTexture(texture)
        widget.bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)
        widget.bar:SetValue(1)
        widget.barBg:SetTexture(texture)
        widget.barBg:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 1)

        UI.SetTextWhite(widget.nameText)

        local inactive = (isActive == false)
        local alpha
        if inactive then alpha = 0.4
        elseif isSelected then alpha = 1.0
        else alpha = 0.7 end
        widget.iconTex:SetDesaturated(inactive)
        widget.iconTex:SetAlpha(alpha)
        widget.bar:SetAlpha(alpha)
        widget.barBg:SetAlpha(alpha)

        widget.clickBtn:SetScript("OnClick", function()
            selectedGroupIndex = groupIndex
            selectedSpellID = sid
            selectedSpellGroupIndex = groupIndex
            ShowSpellSettings(sid, groupIndex)
            RefreshAll()
        end)

        widget.clickBtn:SetScript("OnDragStart", function()
            StartDrag(sid, groupIndex)
        end)
        widget.clickBtn:SetScript("OnDragStop", function()
            EndDrag()
        end)

        widget.btnUp:Hide()
        widget.btnUp:SetScript("OnClick", nil)
        widget.btnDown:Hide()
        widget.btnDown:SetScript("OnClick", nil)
        if groupIndex and spellIndex and spellCount then
            widget.btnUp:Show()
            widget.btnUp:SetEnabled(spellIndex ~= 1)
            widget.btnUp:SetScript("OnClick", function()
                local groups = GetSpecGroups()
                if not groups or not groups[groupIndex] then return end
                local spells = groups[groupIndex].spells
                if spells and spellIndex > 1 then
                    spells[spellIndex], spells[spellIndex - 1] = spells[spellIndex - 1], spells[spellIndex]
                    SaveAndRefresh()
                    RefreshAll()
                end
            end)

            widget.btnDown:Show()
            widget.btnDown:SetEnabled(spellIndex ~= spellCount)
            widget.btnDown:SetScript("OnClick", function()
                local groups = GetSpecGroups()
                if not groups or not groups[groupIndex] then return end
                local spells = groups[groupIndex].spells
                if spells and spellIndex < #spells then
                    spells[spellIndex], spells[spellIndex + 1] = spells[spellIndex + 1], spells[spellIndex]
                    SaveAndRefresh()
                    RefreshAll()
                end
            end)
        end

        if groupIndex then
            widget.removeBtn:Show()
            widget.removeBtn:SetScript("OnClick", function()
                local groups = GetSpecGroups()
                local gd = groups and groups[groupIndex]
                if not gd then return end
                if gd.spells then
                    Shared.RemoveSpellFromGroupList(gd.spells, sid)
                end
                local srcOvData
                if gd.spellOverrides then
                    srcOvData = ExtractMergedOverrideEntry(gd.spellOverrides, sid)
                end
                if srcOvData then
                    local specOv = EnsureUngroupedOverrides()
                    if specOv then
                        StoreMergedOverrideEntry(specOv, sid, srcOvData)
                    end
                end
                if selectedSpellID == sid and selectedSpellGroupIndex == groupIndex then
                    selectedSpellID = nil
                    selectedSpellGroupIndex = nil
                    ClearRightPanel()
                end
                SaveAndRefresh()
                RefreshAll()
            end)
        else
            widget.removeBtn:Hide()
        end
    end

    local function ClearAllRows()
        headerPool:ReleaseAll()
        groupContainerPool:ReleaseAll()
        spellRowPool:ReleaseAll()
        emptyRowPool:ReleaseAll()
        ClearDropTargets()
        if renameActiveEditBox then
            renameActiveEditBox:Hide()
            renameActiveEditBox = nil
            renameActiveGroupIndex = nil
        end
    end

    RefreshAll = function()
        ClearAllRows()
        RefreshCurrentSpecID()
        local groups = GetSpecGroups() or {}

        local isViewingPlayer = currentSpecID == playerSpecID
        local activeSpellSet = isViewingPlayer and BuildActiveBarSpellSet() or nil

        local tooltipOverrideMap
        if currentSpecID == playerSpecID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet then
            tooltipOverrideMap = {}
            local ids = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBar, true)
            if ids then
                for _, cdID in ipairs(ids) do
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    if info and info.overrideTooltipSpellID and info.overrideTooltipSpellID ~= info.spellID then
                        tooltipOverrideMap[info.spellID] = info.overrideTooltipSpellID
                        if info.overrideSpellID then
                            tooltipOverrideMap[info.overrideSpellID] = info.overrideTooltipSpellID
                        end
                    end
                end
            end
        end

        local yOff = 0

        ungroupedHeader:ClearAllPoints()
        ungroupedHeader:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)
        ungroupedHeader:Show()

        if not btnRefs.ungroupedSettings then
            local ugBtn = CreateFrame("Button", nil, leftChild, "UIPanelButtonTemplate")
            ugBtn:SetSize(90, 22)
            ugBtn:SetText(L["Settings"])
            ugBtn:SetScript("OnClick", function()
                ShowUngroupedSettings()
                RefreshLeftPanelIfNeeded()
            end)
            btnRefs.ungroupedSettings = ugBtn
        end
        btnRefs.ungroupedSettings:ClearAllPoints()
        btnRefs.ungroupedSettings:SetPoint("LEFT", ungroupedHeader, "RIGHT", 6, 0)
        btnRefs.ungroupedSettings:Show()

        yOff = yOff - GROUP_HEADER_H - 2

        ungroupedContainer:ClearAllPoints()
        ungroupedContainer:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)
        ungroupedContainer:Show()
        RegisterDropTarget(ungroupedContainer, nil)

        local ungrouped = GetUngroupedBarSpells()
        local ungroupedHeight = 0
        if #ungrouped == 0 then
            local emptyRow = Shared.AcquireEmptyRow(emptyRowPool, ungroupedContainer,
                L["No ungrouped bars."])
            emptyRow.root:ClearAllPoints()
            emptyRow.root:SetPoint("TOPLEFT", 16, 0)
            ungroupedHeight = ROW_HEIGHT
        else
            local localY = 0
            for _, entry in ipairs(ungrouped) do
                local sid = entry.spellID
                local rowSelected = (selectedSpellID == sid) and (selectedSpellGroupIndex == nil)
                local row = spellRowPool:Acquire(ungroupedContainer)
                local isActive = not isViewingPlayer or IsSpellInActiveSet(activeSpellSet, sid)
                ConfigureSpellRow(row, ungroupedContainer, sid, nil, localY, rowSelected, nil, nil, tooltipOverrideMap, isActive)
                localY = localY - ROW_HEIGHT
            end
            ungroupedHeight = -localY
        end
        ungroupedContainer:SetHeight(math.max(ungroupedHeight, 10))
        yOff = yOff - ungroupedHeight

        for groupIndex, groupData in ipairs(groups) do
            local isExpanded = expandedGroups[groupIndex] ~= false
            local isSelected = (selectedGroupIndex == groupIndex) and (not selectedSpellID)

            local widget = headerPool:Acquire(leftChild)
            ConfigureHeaderRow(widget, groupIndex, groupData, isExpanded, isSelected, yOff)
            RegisterDropTarget(widget.row, groupIndex)
            yOff = yOff - GROUP_HEADER_H - 2

            if isExpanded then
                local groupContainerWidget = groupContainerPool:Acquire(leftChild)
                local groupContainer = groupContainerWidget.root
                groupContainer:ClearAllPoints()
                groupContainer:SetPoint("TOPLEFT", SCROLL_LEFT_PAD, yOff)
                RegisterDropTarget(groupContainer, groupIndex)

                local localY = 0
                if groupData.spells and #groupData.spells > 0 then
                    local spellCount = #groupData.spells
                    for spellIdx, sid in ipairs(groupData.spells) do
                        local rowSelected = (selectedSpellID == sid) and (selectedSpellGroupIndex == groupIndex)
                        local row = spellRowPool:Acquire(groupContainer)
                        local isActive = not isViewingPlayer or IsSpellInActiveSet(activeSpellSet, sid)
                        ConfigureSpellRow(row, groupContainer, sid, groupIndex, localY, rowSelected, spellIdx, spellCount, tooltipOverrideMap, isActive)
                        localY = localY - ROW_HEIGHT
                    end
                else
                    local emptyRow = Shared.AcquireEmptyRow(emptyRowPool, groupContainer,
                        L["Drag spells here"])
                    emptyRow.root:ClearAllPoints()
                    emptyRow.root:SetPoint("TOPLEFT", 16, 0)
                    localY = -ROW_HEIGHT
                end
                groupContainer:SetHeight(math.max(-localY, 10))
                yOff = yOff + localY
            end
        end

        if not btnRefs.group then
            local addGroupBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            addGroupBtn:SetSize(110, 22)
            addGroupBtn:SetPoint("TOPLEFT", LEFT_INSET, -22)
            addGroupBtn:SetText(L["Add Group"])
            addGroupBtn:SetScript("OnClick", function()
                local specGroups = EnsureBarGroups()
                if not specGroups then return end
                local newIndex = #specGroups + 1
                specGroups[newIndex] = BuildNewBarGroupSnapshot(newIndex)
                expandedGroups[newIndex] = true
                selectedGroupIndex = newIndex
                selectedSpellID = nil
                SaveAndRefresh()
                RefreshLeftPanelIfNeeded()
                ShowGroupSettings(newIndex)
            end)
            btnRefs.group = addGroupBtn
        end

        if not btnRefs.spell then
            local addSpellBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            addSpellBtn:SetSize(110, 22)
            addSpellBtn:SetText(L["Add Spell"])
            addSpellBtn:SetScript("OnClick", function()
                if selectedGroupIndex then
                    ShowSpellPickerPanel(selectedGroupIndex)
                end
            end)
            btnRefs.spell = addSpellBtn
        end
        btnRefs.spell:SetPoint("LEFT", btnRefs.group, "RIGHT", 6, 0)
        btnRefs.spell:SetEnabled(selectedGroupIndex ~= nil)

        leftChild:SetHeight(math.max(800, -yOff + 40))
    end

    Shared.CreateSpecDropdown(page, "TOPRIGHT", -6, -8, {
        getCurrentSpecID = function() return currentSpecID end,
        getPlayerSpecID = function() return playerSpecID end,
        onSelectionChange = function(specID)
            currentSpecID = specID
            selectedGroupIndex = nil
            selectedSpellID = nil
            ClearRightPanel()
            RefreshAll()
        end,
    })

    page:SetScript("OnMouseUp", function()
        EndDrag()
    end)

    local RegisterViewerCb, UnregisterViewerCb = Shared.CreateViewerSettingsCallbacks(function(d) QueueLeftPanelRefresh(d) end)
    page:HookScript("OnShow", function()
        RefreshCurrentSpecID()
        RegisterViewerCb()
        if RefreshAll then RefreshAll() end
    end)
    page:HookScript("OnHide", function()
        CancelDrag()
        UnregisterViewerCb()
        ClearRightPanel()
    end)

    CDM:RegisterRefreshCallback("optionsBarGroupsList", function()
        QueueLeftPanelRefresh(0)
    end, 30, { "BAR_DATA" })

    RefreshAll()
end

API:RegisterConfigTab("bars", L["Bars"], CreateBarsTab, 8)
