local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM_C = Runtime and Runtime.CONST or {}
local UI = ns.ConfigUI

ns.GroupEditorShared = ns.GroupEditorShared or {}
local Shared = ns.GroupEditorShared

local EMPTY_KEYS = {}
local CLASS_LIST = {}
local CLASS_SPECS = {}

for i = 1, GetNumClasses() do
    local className, classTag, classID = GetClassInfo(i)
    if classTag then
        local color = RAID_CLASS_COLORS[classTag]
        CLASS_LIST[#CLASS_LIST + 1] = {
            classTag = classTag,
            className = className,
            classID = classID,
            r = color and color.r or 1,
            g = color and color.g or 1,
            b = color and color.b or 1,
        }
        local specs = {}
        for j = 1, GetNumSpecializationsForClassID(classID) do
            local specID, specName = GetSpecializationInfoForClassID(classID, j)
            if specID then
                specs[#specs + 1] = { specID = specID, specName = specName }
            end
        end
        CLASS_SPECS[classTag] = specs
    end
end

table.sort(CLASS_LIST, function(a, b) return a.className < b.className end)

function Shared.GetClassCatalog()
    return CLASS_LIST, CLASS_SPECS
end

local function GetSpecLabel(specID)
    for _, classInfo in ipairs(CLASS_LIST) do
        local specs = CLASS_SPECS[classInfo.classTag]
        if specs then
            for _, specInfo in ipairs(specs) do
                if specInfo.specID == specID then
                    return classInfo.className .. " - " .. specInfo.specName
                end
            end
        end
    end
    return nil
end

Shared.GROW_OPTIONS = {
    { label = "Right", value = "RIGHT" },
    { label = "Left", value = "LEFT" },
    { label = "Up", value = "UP" },
    { label = "Down", value = "DOWN" },
    { label = "Center Horizontal", value = "CENTER_H" },
    { label = "Center Vertical", value = "CENTER_V" },
}

function Shared.GetGrowLabel(growValue)
    for _, option in ipairs(Shared.GROW_OPTIONS) do
        if option.value == growValue then return option.label end
    end
    return growValue or "RIGHT"
end

function Shared.IsUsableSpellID(spellID)
    return API.IsSafeNumber(spellID) and spellID > 0 and spellID == math.floor(spellID)
end

function Shared.GetDisplaySpellID(spellID)
    if C_Spell.GetSpellTexture(spellID) then return spellID end
    local base = API.NormalizeToBase and API.NormalizeToBase(spellID)
    if base and base ~= spellID then return base end
    return spellID
end

function Shared.GetUniqueGroupName(groups, baseName)
    if not groups then return baseName end
    local nameSet = {}
    for _, group in ipairs(groups) do
        if group.name then
            nameSet[group.name] = true
        end
    end
    if not nameSet[baseName] then return baseName end
    for i = 1, 99 do
        local candidate = baseName .. " (" .. i .. ")"
        if not nameSet[candidate] then
            return candidate
        end
    end
    return baseName .. " (" .. time() .. ")"
end

local function BuildOverrideKeyCandidates(spellID, candidateCache)
    if not Shared.IsUsableSpellID(spellID) then
        return EMPTY_KEYS
    end
    if candidateCache and candidateCache[spellID] then
        return candidateCache[spellID]
    end
    local keys = API.GetBuffGroupMatchCandidates and API:GetBuffGroupMatchCandidates(spellID) or EMPTY_KEYS
    if type(keys) ~= "table" then
        keys = EMPTY_KEYS
    end
    if candidateCache then
        candidateCache[spellID] = keys
    end
    return keys
end

local function AreEquivalentSpellIDs(leftSpellID, rightSpellID)
    if not Shared.IsUsableSpellID(leftSpellID) or not Shared.IsUsableSpellID(rightSpellID) then
        return false
    end
    if API.AreBuffGroupSpellIDsEquivalent then
        return API:AreBuffGroupSpellIDsEquivalent(leftSpellID, rightSpellID)
    end
    return leftSpellID == rightSpellID
end

function Shared.MarkEquivalentSpellIDs(targetSet, spellID, candidateCache)
    if type(targetSet) ~= "table" or not Shared.IsUsableSpellID(spellID) then return end
    local candidates = BuildOverrideKeyCandidates(spellID, candidateCache)
    if #candidates == 0 then
        targetSet[spellID] = true
        return
    end
    for _, candidateID in ipairs(candidates) do
        targetSet[candidateID] = true
    end
end

function Shared.HasEquivalentSpellID(targetSet, spellID, candidateCache)
    if type(targetSet) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return false
    end
    local candidates = BuildOverrideKeyCandidates(spellID, candidateCache)
    if #candidates == 0 then
        return targetSet[spellID] or false
    end
    for _, candidateID in ipairs(candidates) do
        if targetSet[candidateID] then
            return true
        end
    end
    return false
end

function Shared.RemoveSpellFromGroupList(spellList, spellID)
    if type(spellList) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return nil
    end
    for i = #spellList, 1, -1 do
        if AreEquivalentSpellIDs(spellList[i], spellID) then
            return table.remove(spellList, i)
        end
    end
    return nil
end

function Shared.AddSpellToGroupList(spellList, spellID)
    if type(spellList) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return nil
    end
    Shared.RemoveSpellFromGroupList(spellList, spellID)
    spellList[#spellList + 1] = spellID
    return spellID
end

local function GetOverrideStorageKey(spellID, normalizeToBase)
    if API.GetBuffOverrideStorageKey then
        return API:GetBuffOverrideStorageKey(spellID)
    end
    if not Shared.IsUsableSpellID(spellID) then
        return nil
    end
    local baseID = normalizeToBase and normalizeToBase(spellID)
    return Shared.IsUsableSpellID(baseID) and baseID or spellID
end

function Shared.EnsureResolvedOverrideEntry(overrideMap, spellID, normalizeToBase)
    if type(overrideMap) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return nil
    end
    if API.EnsureBuffOverrideEntry then
        return API:EnsureBuffOverrideEntry(overrideMap, spellID)
    end
    local storageKey = GetOverrideStorageKey(spellID, normalizeToBase)
    if not Shared.IsUsableSpellID(storageKey) then
        return nil
    end
    if type(overrideMap[storageKey]) ~= "table" then
        overrideMap[storageKey] = {}
    end
    return overrideMap[storageKey]
end

function Shared.GetMergedOverrideEntry(overrideMap, spellID)
    if API.GetMergedBuffOverrideEntry then
        return API:GetMergedBuffOverrideEntry(overrideMap, spellID)
    end
    return nil
end

function Shared.ExtractMergedOverrideEntry(overrideMap, spellID)
    if API.ExtractMergedBuffOverrideEntry then
        return API:ExtractMergedBuffOverrideEntry(overrideMap, spellID)
    end
    return nil
end

function Shared.StoreMergedOverrideEntry(overrideMap, spellID, incoming, normalizeToBase)
    if type(overrideMap) ~= "table" or type(incoming) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return
    end
    if API.StoreMergedBuffOverrideEntry then
        API:StoreMergedBuffOverrideEntry(overrideMap, spellID, incoming)
        return
    end
    local storageKey = GetOverrideStorageKey(spellID, normalizeToBase)
    if Shared.IsUsableSpellID(storageKey) then
        overrideMap[storageKey] = incoming
    end
end

function Shared.CreateRightPanelManager(rightPanel, placeholder, destroyFrame)
    local rightContentFrame = nil
    local rightScrollFrame = nil
    local rightPanelDropdowns = {}

    local function CloseDropdownMenus()
        if UI and UI.CloseAllDropdownMenus then
            UI.CloseAllDropdownMenus()
        end
        for _, dropdown in ipairs(rightPanelDropdowns) do
            if dropdown and dropdown.CloseMenu then
                dropdown:CloseMenu()
            end
        end
    end

    local function Reset(showPlaceholder)
        CloseDropdownMenus()
        table.wipe(rightPanelDropdowns)
        if rightContentFrame then
            destroyFrame(rightContentFrame)
            rightContentFrame = nil
        end
        if rightScrollFrame then
            destroyFrame(rightScrollFrame)
            rightScrollFrame = nil
        end
        placeholder:SetShown(showPlaceholder)
    end

    return {
        RegisterDropdown = function(dropdown)
            if dropdown then
                rightPanelDropdowns[#rightPanelDropdowns + 1] = dropdown
            end
            return dropdown
        end,
        CreateScrollContent = function(minHeight)
            Reset(false)

            local sf = CreateFrame("ScrollFrame", nil, rightPanel, "ScrollFrameTemplate")
            sf:SetAllPoints()
            sf:Show()
            sf:HookScript("OnVerticalScroll", CloseDropdownMenus)
            sf:HookScript("OnHide", CloseDropdownMenus)
            rightScrollFrame = sf

            local rc = CreateFrame("Frame", nil, sf)
            rc:SetWidth(sf:GetWidth() > 0 and sf:GetWidth() - 20 or 400)
            rc:SetHeight(minHeight or 400)
            sf:SetScrollChild(rc)
            rc:Show()
            rightContentFrame = rc
            return sf, rc
        end,
        Clear = function()
            Reset(true)
        end,
        CloseDropdownMenus = CloseDropdownMenus,
    }
end

function Shared.CreateDragDropController(config)
    local dragState = {
        active = false,
        spellID = nil,
        sourceGroup = nil,
        dragFrame = nil,
    }
    local dropTargets = {}
    local dragFrameCache = nil

    local function HideHighlights()
        for _, target in ipairs(dropTargets) do
            if target.frame.highlight then
                target.frame.highlight:Hide()
            end
        end
    end

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
        local tex = C_Spell.GetSpellTexture(Shared.GetDisplaySpellID(spellID))
        if tex then
            dragFrameCache.icon:SetTexture(tex)
        else
            dragFrameCache.icon:SetColorTexture(0.3, 0.3, 0.3)
        end
        CDM_C.ApplyIconTexCoord(dragFrameCache.icon, CDM_C.GetEffectiveZoomAmount())
        return dragFrameCache
    end

    return {
        RegisterDropTarget = function(frame, groupIndex)
            dropTargets[#dropTargets + 1] = { frame = frame, groupIndex = groupIndex }
        end,
        ClearDropTargets = function()
            table.wipe(dropTargets)
        end,
        StartDrag = function(spellID, sourceGroup)
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
                        target.frame.highlight:SetShown(target.frame:IsMouseOver())
                    end
                end
            end)
        end,
        EndDrag = function()
            if not dragState.active then return end

            local spellID = dragState.spellID
            local sourceGroup = dragState.sourceGroup

            if dragState.dragFrame then
                dragState.dragFrame:SetScript("OnUpdate", nil)
                dragState.dragFrame:Hide()
                dragState.dragFrame = nil
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

            HideHighlights()

            dragState.active = false
            dragState.spellID = nil
            dragState.sourceGroup = nil

            if config and config.onDrop then
                config.onDrop(spellID, sourceGroup, targetGroupIndex, hitDropTarget)
            end
        end,
        CancelDrag = function()
            if not dragState.active then return end
            if dragState.dragFrame then
                dragState.dragFrame:SetScript("OnUpdate", nil)
                dragState.dragFrame:Hide()
                dragState.dragFrame = nil
            end
            HideHighlights()
            dragState.active = false
            dragState.spellID = nil
            dragState.sourceGroup = nil
        end,
    }
end

local HEADER_SCROLL_LEFT_PAD = 54
local HEADER_VISIBLE_W = 226
local HEADER_GROUP_H = 28
local HEADER_DELETE_BTN_SIZE = 24
local HEADER_ATLAS_W = 198

function Shared.CreateExpandableHeader(parent, yOff, isExpanded, displayName, isSelected)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(HEADER_VISIBLE_W, HEADER_GROUP_H)
    row:SetPoint("TOPLEFT", HEADER_SCROLL_LEFT_PAD, yOff)

    local bgLeft = row:CreateTexture(nil, "BACKGROUND")
    bgLeft:SetAtlas("Options_ListExpand_Left", true)
    bgLeft:SetPoint("TOPLEFT", 0, 0)

    local bgRight = row:CreateTexture(nil, "BACKGROUND")
    if isExpanded then
        bgRight:SetAtlas("Options_ListExpand_Right_Expanded", true)
    else
        bgRight:SetAtlas("Options_ListExpand_Right", true)
    end
    bgRight:SetPoint("LEFT", bgLeft, "LEFT", HEADER_ATLAS_W - bgRight:GetWidth(), 0)

    local leftW = bgLeft:GetWidth()
    local leftH = bgLeft:GetHeight()
    local bgMiddle = row:CreateTexture(nil, "BACKGROUND")
    bgMiddle:SetAtlas("_Options_ListExpand_Middle")
    local midW = math.max(1, HEADER_ATLAS_W - leftW - bgRight:GetWidth())
    bgMiddle:SetSize(midW, leftH)
    bgMiddle:SetPoint("TOPLEFT", bgLeft, "TOPRIGHT", 0, 0)

    local nameText = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    nameText:SetPoint("LEFT", bgLeft, "LEFT", 8, 0)
    nameText:SetPoint("RIGHT", bgRight, "LEFT", -4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(displayName)
    if isSelected then
        UI.SetTextWhite(nameText)
    else
        UI.SetTextMuted(nameText)
    end

    local deleteBtn = CreateFrame("Button", nil, row)
    deleteBtn:SetSize(HEADER_DELETE_BTN_SIZE, HEADER_DELETE_BTN_SIZE)
    deleteBtn:SetPoint("RIGHT", 0, 1)
    deleteBtn:SetFrameLevel(row:GetFrameLevel() + 2)
    deleteBtn:SetNormalAtlas("128-RedButton-Exit")
    deleteBtn:SetPushedAtlas("128-RedButton-Exit-Pressed")
    deleteBtn:SetHighlightAtlas("128-RedButton-Exit-Highlight")

    local selectBtn = CreateFrame("Button", nil, row)
    selectBtn:SetPoint("TOPLEFT", 0, 0)
    selectBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", HEADER_ATLAS_W - bgRight:GetWidth(), 0)
    selectBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local expandBtn = CreateFrame("Button", nil, row)
    expandBtn:SetPoint("TOPLEFT", bgRight, "TOPLEFT", 0, 0)
    expandBtn:SetPoint("BOTTOMRIGHT", bgRight, "BOTTOMRIGHT", 0, 0)
    expandBtn:SetFrameLevel(row:GetFrameLevel() + 1)

    return {
        row = row,
        bgLeft = bgLeft,
        bgRight = bgRight,
        bgMiddle = bgMiddle,
        nameText = nameText,
        deleteBtn = deleteBtn,
        selectBtn = selectBtn,
        expandBtn = expandBtn,
    }
end

function Shared.ConfigureExpandableHeader(header, yOff, isExpanded, displayName, isSelected)
    if not header then return end

    header.row:SetSize(HEADER_VISIBLE_W, HEADER_GROUP_H)
    header.row:ClearAllPoints()
    header.row:SetPoint("TOPLEFT", HEADER_SCROLL_LEFT_PAD, yOff)

    header.bgLeft:SetAtlas("Options_ListExpand_Left", true)
    header.bgLeft:ClearAllPoints()
    header.bgLeft:SetPoint("TOPLEFT", 0, 0)

    if isExpanded then
        header.bgRight:SetAtlas("Options_ListExpand_Right_Expanded", true)
    else
        header.bgRight:SetAtlas("Options_ListExpand_Right", true)
    end
    header.bgRight:ClearAllPoints()
    header.bgRight:SetPoint("LEFT", header.bgLeft, "LEFT", HEADER_ATLAS_W - header.bgRight:GetWidth(), 0)

    local leftW = header.bgLeft:GetWidth()
    local leftH = header.bgLeft:GetHeight()
    local midW = math.max(1, HEADER_ATLAS_W - leftW - header.bgRight:GetWidth())
    header.bgMiddle:SetSize(midW, leftH)
    header.bgMiddle:ClearAllPoints()
    header.bgMiddle:SetPoint("TOPLEFT", header.bgLeft, "TOPRIGHT", 0, 0)

    header.nameText:Show()
    header.nameText:SetText(displayName)
    if isSelected then
        UI.SetTextWhite(header.nameText)
    else
        UI.SetTextMuted(header.nameText)
    end

    header.deleteBtn:Show()
    header.selectBtn:Show()
    header.expandBtn:Show()
end

function Shared.SetupRenameEditBox(headerRow, bgLeft, bgRight, nameText, currentName, onCommit, onCancel)
    nameText:Hide()
    local editBox = CreateFrame("EditBox", nil, headerRow, "BackdropTemplate")
    editBox:SetFontObject("AyijeCDM_Font14")
    editBox:SetPoint("LEFT", bgLeft, "LEFT", 4, 0)
    editBox:SetPoint("RIGHT", bgRight, "LEFT", -4, 0)
    editBox:SetHeight(18)
    editBox:SetJustifyH("LEFT")
    editBox:SetTextInsets(2, 2, 0, 0)
    editBox:SetBackdrop({ bgFile = CDM_C.TEX_WHITE8X8, edgeFile = CDM_C.TEX_WHITE8X8, edgeSize = 1 })
    editBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    editBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    editBox:SetText(currentName)
    editBox:SetAutoFocus(true)
    editBox:HighlightText()
    editBox:SetFrameLevel(headerRow:GetFrameLevel() + 3)

    local committed = false
    local function DoCommit(self)
        if committed then return end
        committed = true
        local newName = self:GetText()
        self:SetScript("OnEditFocusLost", nil)
        self:Hide()
        if newName and newName ~= "" then
            onCommit(newName)
        else
            onCancel()
        end
    end
    editBox:SetScript("OnEnterPressed", DoCommit)
    editBox:SetScript("OnEscapePressed", function(self)
        if committed then return end
        committed = true
        self:SetScript("OnEditFocusLost", nil)
        self:Hide()
        onCancel()
    end)
    editBox:SetScript("OnEditFocusLost", DoCommit)
    return editBox
end

function Shared.BuildGroupContextMenu(rootDescription, labels, onRename, onDuplicate, onCopyToSpec)
    rootDescription:CreateButton(labels.rename, onRename)
    rootDescription:CreateButton(labels.duplicate, onDuplicate)
    local copyMenu = rootDescription:CreateButton(labels.copyTo)
    for _, classInfo in ipairs(CLASS_LIST) do
        local color = RAID_CLASS_COLORS[classInfo.classTag]
        local coloredName = color and color:WrapTextInColorCode(classInfo.className) or classInfo.className
        local classMenu = copyMenu:CreateButton(coloredName)
        local specs = CLASS_SPECS[classInfo.classTag]
        if specs then
            for _, specInfo in ipairs(specs) do
                classMenu:CreateButton(specInfo.specName, function()
                    onCopyToSpec(specInfo.specID)
                end)
            end
        end
    end
end

local HIDE_BY_DEFAULT_FLAG = Enum.CooldownSetSpellFlags and Enum.CooldownSetSpellFlags.HideByDefault

function Shared.IsHiddenByDefault(info)
    return info and info.flags and HIDE_BY_DEFAULT_FLAG and FlagsUtil and FlagsUtil.IsSet
        and FlagsUtil.IsSet(info.flags, HIDE_BY_DEFAULT_FLAG) or false
end

function Shared.GetConfiguredBorderColor()
    if Runtime.GetConfiguredBorderColor then
        return Runtime.GetConfiguredBorderColor()
    end
    return 0, 0, 0, 1
end

function Shared.ApplyConfiguredBorderColor(borderFrame)
    if not (borderFrame and borderFrame.SetBackdropBorderColor) then return end
    local r, g, b, a = Shared.GetConfiguredBorderColor()
    borderFrame:SetBackdropBorderColor(r, g, b, a)
end

function Shared.RenderSpellPicker(config)
    local _, rc = config.createRightScrollContent(config.minHeight or 400)

    local header = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText(config.headerText)
    header:SetTextColor(config.headerColor.r, config.headerColor.g, config.headerColor.b, 1)

    if config.isCacheMissing then
        local msg = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        msg:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -20)
        msg:SetText(config.cacheMissingText)
        UI.SetTextMuted(msg)
    elseif #(config.spells or EMPTY_KEYS) == 0 then
        local msg = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        msg:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -20)
        msg:SetText(config.emptyText)
        UI.SetTextMuted(msg)
    else
        local yOff = -34
        for _, entry in ipairs(config.spells) do
            local row = CreateFrame("Button", nil, rc)
            row:SetSize(300, 30)
            row:SetPoint("TOPLEFT", 0, yOff)

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(24, 24)
            iconTex:SetPoint("LEFT", 0, 0)
            if entry.icon then
                iconTex:SetTexture(entry.icon)
            end

            local label = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
            label:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
            label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            label:SetJustifyH("LEFT")
            if config.currentSpecID == config.playerSpecID and entry.isKnown == false then
                label:SetTextColor(0.5, 0.5, 0.5, 1)
            end
            label:SetText(entry.name)

            local sid = entry.spellID
            row:SetScript("OnClick", function()
                config.onSelect(sid)
            end)

            yOff = yOff - 30
        end

        rc:SetHeight(math.abs(yOff) + 10)
    end

    local doneBtn = CreateFrame("Button", nil, rc, "UIPanelButtonTemplate")
    doneBtn:SetSize(80, 22)
    doneBtn:SetPoint("TOPRIGHT", rc, "TOPRIGHT", 0, 0)
    doneBtn:SetText(config.doneText or "Back")
    doneBtn:SetScript("OnClick", config.onDone)

    return rc
end

Shared.LEFT_INSET = 35
Shared.LEFT_WIDTH = 240
Shared.SCROLL_LEFT_PAD = 54
Shared.RIGHT_X = 35 + 240 + 40
Shared.SLIDER_LABEL_W = 120
Shared.SLIDER_W = 200

function Shared.DestroyFrame(frame)
    if not frame then return end
    frame:Hide()
    frame:SetParent(nil)
end

function Shared.CreateSlider(parent, label, minVal, maxVal, currentVal, onChange)
    return UI.CreateModernSlider(parent, label, minVal, maxVal, currentVal, onChange, Shared.SLIDER_LABEL_W, Shared.SLIDER_W)
end

local GROUP_VISUAL_REFRESH_SCOPES = { "viewers", "trackers_layout" }
local GROUP_STRUCTURAL_REFRESH_SCOPES = { "spec_data", "viewers", "trackers_layout" }

local function TriggerGroupRefresh(scopeNames)
    if API.RefreshScopes then
        API:RefreshScopes(scopeNames)
        return
    end
    API:RefreshConfig()
end

function Shared.SaveVisualRefresh()
    TriggerGroupRefresh(GROUP_VISUAL_REFRESH_SCOPES)
end

function Shared.SaveStructuralRefresh()
    TriggerGroupRefresh(GROUP_STRUCTURAL_REFRESH_SCOPES)
end

function Shared.CreateQueueLeftPanelRefresh(containerFrame, getRefreshAllFn)
    local queued = false
    return function(delay)
        if queued then return end
        queued = true
        C_Timer.After(delay or 0.1, function()
            queued = false
            if containerFrame:IsShown() and getRefreshAllFn() then
                getRefreshAllFn()()
            end
        end)
    end
end

local function ResolveWidgetRoot(widget)
    if type(widget) ~= "table" then
        return widget
    end
    return widget.root or widget.row or widget.frame
end

function Shared.CreateWidgetPool(factory, reset)
    local active = {}
    local inactive = {}

    local function ReleaseInternal(widget)
        if not widget then return end
        if reset then
            reset(widget)
        end
        local root = ResolveWidgetRoot(widget)
        if root then
            root:Hide()
            root:ClearAllPoints()
        end
        inactive[#inactive + 1] = widget
    end

    return {
        Acquire = function(_, parent)
            local widget = table.remove(inactive)
            if not widget then
                widget = factory(parent)
            end

            local root = ResolveWidgetRoot(widget)
            if root and root:GetParent() ~= parent then
                root:SetParent(parent)
            end
            if root then
                root:Show()
            end

            active[#active + 1] = widget
            return widget
        end,
        ReleaseAll = function(_)
            for i = #active, 1, -1 do
                local widget = active[i]
                active[i] = nil
                ReleaseInternal(widget)
            end
        end,
    }
end

function Shared.CreateViewerSettingsCallbacks(queueFn)
    local owners = {}
    local evRegistry = EventRegistry

    local function Register()
        if not (evRegistry and evRegistry.RegisterCallback) then return end
        if owners[1] then return end
        local o1, o2, o3, o4 = {}, {}, {}, {}
        owners[1], owners[2], owners[3], owners[4] = o1, o2, o3, o4
        evRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function() queueFn(0.2) end, o1)
        evRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function() queueFn(0.2) end, o2)
        evRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function() queueFn(0.2) end, o3)
        evRegistry:RegisterCallback("CooldownViewerSettings.OnPendingChanges", function() queueFn(0.3) end, o4)
    end

    local function Unregister()
        if not (evRegistry and evRegistry.UnregisterCallback) then return end
        if not owners[1] then return end
        evRegistry:UnregisterCallback("CooldownViewerSettings.OnShow", owners[1])
        evRegistry:UnregisterCallback("CooldownViewerSettings.OnHide", owners[2])
        evRegistry:UnregisterCallback("CooldownViewerSettings.OnDataChanged", owners[3])
        evRegistry:UnregisterCallback("CooldownViewerSettings.OnPendingChanges", owners[4])
        table.wipe(owners)
    end

    return Register, Unregister
end

function Shared.CreateSpecDropdown(parent, anchorPoint, anchorX, anchorY, config)
    local L = Runtime.L

    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(200)
    dropdown:SetPoint(anchorPoint, parent, anchorPoint, anchorX, anchorY)

    local function GetText()
        local cur = config.getCurrentSpecID()
        if cur == config.getPlayerSpecID() then return L["Current Spec"] or "Current Spec" end
        if cur then return GetSpecLabel(cur) or L["Current Spec"] or "Current Spec" end
        return L["Current Spec"] or "Current Spec"
    end

    local function SetSelection(specID)
        C_Timer.After(0, function()
            if not parent:IsShown() then return end
            config.onSelectionChange(specID)
            dropdown:OverrideText(GetText())
        end)
    end

    local function RefreshText()
        dropdown:OverrideText(GetText())
    end

    dropdown:SetDefaultText(GetText())
    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio(L["Current Spec"] or "Current Spec", function()
            return config.getCurrentSpecID() == config.getPlayerSpecID()
        end, function()
            SetSelection(config.getPlayerSpecID())
        end)
        rootDescription:CreateDivider()
        for _, classInfo in ipairs(CLASS_LIST) do
            local color = RAID_CLASS_COLORS[classInfo.classTag]
            local coloredName = color and color:WrapTextInColorCode(classInfo.className) or classInfo.className
            local submenu = rootDescription:CreateButton(coloredName)
            local specs = CLASS_SPECS[classInfo.classTag]
            if specs then
                for _, specInfo in ipairs(specs) do
                    submenu:CreateRadio(specInfo.specName, function()
                        return config.getCurrentSpecID() == specInfo.specID
                    end, function()
                        SetSelection(specInfo.specID)
                    end)
                end
            end
        end
    end)

    return dropdown, RefreshText
end
