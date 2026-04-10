local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM_C = Runtime and Runtime.CONST or {}
local UI = ns.ConfigUI
local L = Runtime.L

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
    return UI.GetOptionLabel(Shared.GROW_OPTIONS, growValue, growValue or "RIGHT")
end

function Shared.CreateArrowButton(parent, direction, size)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    local prefix = "common-button-collapseExpand-" .. direction
    btn:SetNormalAtlas(prefix)
    btn:SetPushedAtlas(prefix .. "-pressed")
    btn:SetDisabledAtlas(prefix .. "-disabled")
    btn:SetHighlightAtlas("common-button-collapseExpand-hover")
    return btn
end

function Shared.ApplyRemoveButtonText(btn)
    local text = btn:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    text:SetPoint("CENTER")
    text:SetText("|cffff4444X|r")
    btn:SetFontString(text)
    return text
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

local function AreEquivalentSpellIDs(leftSpellID, rightSpellID)
    if not Shared.IsUsableSpellID(leftSpellID) or not Shared.IsUsableSpellID(rightSpellID) then
        return false
    end
    return leftSpellID == rightSpellID
end

function Shared.MarkEquivalentSpellIDs(targetSet, spellID)
    if type(targetSet) ~= "table" or not Shared.IsUsableSpellID(spellID) then return end
    targetSet[spellID] = true
end

function Shared.HasEquivalentSpellID(targetSet, spellID)
    if type(targetSet) ~= "table" or not Shared.IsUsableSpellID(spellID) then
        return false
    end
    return targetSet[spellID] or false
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
            local cachedScale = UIParent:GetEffectiveScale()
            df:SetScript("OnUpdate", function()
                local x, y = GetCursorPosition()
                df:ClearAllPoints()
                df:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / cachedScale, y / cachedScale)
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
            local cdID = entry.cdID
            row:SetScript("OnClick", function()
                config.onSelect(sid, cdID)
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

function Shared.SaveVisualRefresh(scope)
    API:Refresh(scope)
end

function Shared.BuildTextOverrideWidgets(rc, yOff, cfg)
    local CreateSlider = Shared.CreateSlider
    local existingOv = cfg.existingOv
    local ensureOv = cfg.ensureOv
    local save = cfg.save
    local f = cfg.fields
    local d = cfg.defaults

    if cfg.showHeader then
        yOff = yOff - 10
        local ovHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
        ovHeader:SetPoint("TOPLEFT", 0, yOff)
        ovHeader:SetText(L["Text Overrides"])
        ovHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        yOff = yOff - 34
    end

    local useTextOv = existingOv and existingOv.textOverride
    local textOvCheckbox = UI.CreateModernCheckbox(rc,
        L["Override Text Settings"],
        useTextOv or false,
        function(checked)
            local ov = ensureOv()
            if not ov then return end
            ov.textOverride = checked or nil
            save()
            if cfg.onToggle then cfg.onToggle(checked) end
        end
    )
    textOvCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 36

    if useTextOv then
        local ov = existingOv or {}
        local function write(key, value)
            local o = ensureOv()
            if o then o[key] = value end
            save()
        end
        local function writeColor(key, r, g, b)
            local o = ensureOv()
            if o then o[key] = cfg.colorAlpha and { r = r, g = g, b = b, a = 1 } or { r = r, g = g, b = b } end
            save()
        end

        local cdFS = CreateSlider(rc, L["Cooldown Size"], 6, 32,
            ov[f.cdSize] or d[f.cdSize], function(v) write(f.cdSize, v) end)
        cdFS:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local cdColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        cdColorLabel:SetText(L["Cooldown Color"])
        cdColorLabel:SetPoint("TOPLEFT", 0, yOff)
        local cdColorPicker = UI.CreateSimpleColorPicker(rc,
            ov[f.cdColor] or d[f.cdColor] or { r = 1, g = 1, b = 1 },
            function(r, g, b) writeColor(f.cdColor, r, g, b) end)
        cdColorPicker:SetPoint("LEFT", cdColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local chargeFS = CreateSlider(rc, L["Charge Size"], 6, 32,
            ov[f.chargeSize] or d[f.chargeSize], function(v) write(f.chargeSize, v) end)
        chargeFS:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local chargeColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        chargeColorLabel:SetText(L["Charge Color"])
        chargeColorLabel:SetPoint("TOPLEFT", 0, yOff)
        local chargeColorPicker = UI.CreateSimpleColorPicker(rc,
            ov[f.chargeColor] or d[f.chargeColor] or { r = 1, g = 1, b = 1 },
            function(r, g, b) writeColor(f.chargeColor, r, g, b) end)
        chargeColorPicker:SetPoint("LEFT", chargeColorLabel, "RIGHT", 6, 0)
        yOff = yOff - 30

        local posLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        posLabel:SetText(L["Position"])
        posLabel:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 22
        local posDropdown = cfg.createDropdown(rc)
        posDropdown:SetWidth(180)
        posDropdown:SetPoint("TOPLEFT", 0, yOff)
        posDropdown:SetDefaultText(ov[f.chargePos] or d[f.chargePos] or "BOTTOMRIGHT")
        UI.SetupPositionDropdown(posDropdown,
            function() return ov[f.chargePos] or d[f.chargePos] or "BOTTOMRIGHT" end,
            function(val) write(f.chargePos, val) end
        )
        yOff = yOff - 40

        local xSlider = CreateSlider(rc, L["X Offset"], -20, 20,
            ov[f.chargeX] or d[f.chargeX] or 0, function(v) write(f.chargeX, v) end)
        xSlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50

        local ySlider = CreateSlider(rc, L["Y Offset"], -20, 20,
            ov[f.chargeY] or d[f.chargeY] or 0, function(v) write(f.chargeY, v) end)
        ySlider:SetPoint("TOPLEFT", 0, yOff)
        yOff = yOff - 50
    end

    return yOff
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
        if cur == config.getPlayerSpecID() then return L["Current Spec"] end
        if cur then return GetSpecLabel(cur) or L["Current Spec"] end
        return L["Current Spec"]
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
        rootDescription:CreateRadio(L["Current Spec"], function()
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

function Shared.CreateGroupEditorPools(parent, config)
    local CDM = Runtime
    local leftWidth = Shared.LEFT_WIDTH
    local iconSize = config and config.iconSize or 30
    local rowHeight = config and config.rowHeight or 36
    local arrowSize = config and config.arrowSize or 29
    local highlightAlpha = config and config.highlightAlpha or 0.2
    local resetBorder = config and config.resetBorder

    local headerPool = Shared.CreateWidgetPool(function(p)
        local header = Shared.CreateExpandableHeader(p, 0, false, "", false)
        header.root = header.row
        return header
    end, function(header)
        header.nameText:Show()
        header.selectBtn:SetScript("OnClick", nil)
        header.deleteBtn:SetScript("OnClick", nil)
        header.expandBtn:SetScript("OnClick", nil)
    end)

    local groupContainerPool = Shared.CreateWidgetPool(function(p)
        local gc = CreateFrame("Frame", nil, p)
        gc:SetSize(leftWidth, 10)
        local hl = gc:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(0.2, 0.4, 0.8, highlightAlpha)
        hl:Hide()
        gc.highlight = hl
        return { root = gc, highlight = hl }
    end, function(widget)
        widget.highlight:Hide()
    end)

    local emptyRowPool = Shared.CreateWidgetPool(function(p)
        local f = CreateFrame("Frame", nil, p)
        f:SetSize(leftWidth, rowHeight)
        local t = f:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        t:SetPoint("LEFT", 10, 0)
        return { root = f, text = t }
    end, function(widget)
        widget.text:SetText("")
    end)

    local spellRowPool = Shared.CreateWidgetPool(function(p)
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(leftWidth - 20, rowHeight)

        local btnUp = Shared.CreateArrowButton(row, "up", arrowSize)
        btnUp:SetPoint("RIGHT", row, "LEFT", -2 - arrowSize + 2, 0)

        local btnDown = Shared.CreateArrowButton(row, "down", arrowSize)
        btnDown:SetPoint("RIGHT", row, "LEFT", -2, 0)

        local iconContainer = CreateFrame("Frame", nil, row)
        iconContainer:SetSize(iconSize, iconSize)
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
        local removeBtnText = Shared.ApplyRemoveButtonText(removeBtn)

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
            if resetBorder then
                resetBorder(widget.iconContainer.border)
            end
        end
    end)

    return headerPool, groupContainerPool, emptyRowPool, spellRowPool
end

function Shared.AcquireEmptyRow(pool, parent, text)
    local widget = pool:Acquire(parent)
    widget.root:SetPoint("TOPLEFT", 0, 0)
    widget.text:SetText(text)
    UI.SetTextFaint(widget.text)
    return widget
end

function Shared.CreateGroupEditorHelpers(config)
    local CDM = Runtime
    local dbKey = config.dbKey
    local ungroupedDbKey = config.ungroupedDbKey
    local getCurrentSpecID = config.getCurrentSpecID
    local setCurrentSpecID = config.setCurrentSpecID
    local getPlayerSpecID = config.getPlayerSpecID
    local setPlayerSpecID = config.setPlayerSpecID
    local normalizeToBase = config.normalizeToBase
    local extraCloneFields = config.extraCloneFields

    local function RefreshCurrentSpecID()
        local si = GetSpecialization()
        local newPlayerSpec = si and GetSpecializationInfo(si) or nil
        local wasViewingPlayer = (getCurrentSpecID() == getPlayerSpecID()) or (getCurrentSpecID() == nil)
        setPlayerSpecID(newPlayerSpec)
        if wasViewingPlayer then setCurrentSpecID(newPlayerSpec) end
    end

    local function EnsureGroups()
        local specID = getCurrentSpecID()
        if not specID then return nil end
        if not CDM.db[dbKey] then CDM.db[dbKey] = {} end
        if not CDM.db[dbKey][specID] then CDM.db[dbKey][specID] = {} end
        return CDM.db[dbKey][specID]
    end

    local function GetSpecGroups()
        local specID = getCurrentSpecID()
        if not specID then return nil end
        local tbl = CDM.db[dbKey]
        return tbl and tbl[specID]
    end

    local function EnsureUngroupedOverrides()
        local specID = getCurrentSpecID()
        if not specID then return nil end
        if not CDM.db[ungroupedDbKey] then CDM.db[ungroupedDbKey] = {} end
        if not CDM.db[ungroupedDbKey][specID] then CDM.db[ungroupedDbKey][specID] = {} end
        return CDM.db[ungroupedDbKey][specID]
    end

    local function GetUngroupedOverride(spellID)
        local specID = getCurrentSpecID()
        if not specID then return nil end
        local specOv = CDM.db[ungroupedDbKey] and CDM.db[ungroupedDbKey][specID]
        return Shared.GetMergedOverrideEntry(specOv, spellID)
    end

    local function HelpersEnsureResolvedOverrideEntry(overrideMap, spellID)
        return Shared.EnsureResolvedOverrideEntry(overrideMap, spellID, normalizeToBase)
    end

    local function HelpersExtractMergedOverrideEntry(overrideMap, spellID)
        return Shared.ExtractMergedOverrideEntry(overrideMap, spellID)
    end

    local function HelpersStoreMergedOverrideEntry(overrideMap, spellID, incoming)
        Shared.StoreMergedOverrideEntry(overrideMap, spellID, incoming, normalizeToBase)
    end

    local function HelpersEnsureSpellOverride(groupIndex, spellID)
        local groups = GetSpecGroups()
        if not groups or not groups[groupIndex] then return nil end
        local gd = groups[groupIndex]
        if not gd.spellOverrides then gd.spellOverrides = {} end
        return HelpersEnsureResolvedOverrideEntry(gd.spellOverrides, spellID)
    end

    local function HelpersEnsureUngroupedOverrideEntry(spellID)
        local specOv = EnsureUngroupedOverrides()
        if not specOv then return nil end
        return HelpersEnsureResolvedOverrideEntry(specOv, spellID)
    end

    local function HelpersCreateLayoutOnlyGroupClone(groups, groupData)
        local clone = {
            name = Shared.GetUniqueGroupName(groups, groupData.name or "Group"),
            spells = {},
            grow = groupData.grow,
            spacing = groupData.spacing,
            iconWidth = groupData.iconWidth,
            iconHeight = groupData.iconHeight,
            cooldownFontSize = groupData.cooldownFontSize,
            anchorTarget = groupData.anchorTarget,
            anchorPoint = groupData.anchorPoint,
            anchorRelativeTo = groupData.anchorRelativeTo,
            offsetX = groupData.offsetX,
            offsetY = groupData.offsetY,
        }
        if groupData.cooldownColor then
            clone.cooldownColor = { r = groupData.cooldownColor.r, g = groupData.cooldownColor.g, b = groupData.cooldownColor.b, a = groupData.cooldownColor.a }
        end
        if extraCloneFields then
            for _, key in ipairs(extraCloneFields) do
                local val = groupData[key]
                if type(val) == "table" and val.r ~= nil then
                    clone[key] = { r = val.r, g = val.g, b = val.b, a = val.a }
                else
                    clone[key] = val
                end
            end
        end
        return clone
    end

    local function HelpersCopyGroupSettingsToSpec(groupData, targetSpecID)
        if not CDM.db[dbKey] then CDM.db[dbKey] = {} end
        if not CDM.db[dbKey][targetSpecID] then CDM.db[dbKey][targetSpecID] = {} end
        local targetGroups = CDM.db[dbKey][targetSpecID]
        targetGroups[#targetGroups + 1] = HelpersCreateLayoutOnlyGroupClone(targetGroups, groupData)
    end

    local function HelpersDuplicateGroup(groupData, specGroups)
        specGroups[#specGroups + 1] = HelpersCreateLayoutOnlyGroupClone(specGroups, groupData)
        return #specGroups
    end

    return {
        RefreshCurrentSpecID = RefreshCurrentSpecID,
        EnsureGroups = EnsureGroups,
        GetSpecGroups = GetSpecGroups,
        EnsureUngroupedOverrides = EnsureUngroupedOverrides,
        GetUngroupedOverride = GetUngroupedOverride,
        EnsureResolvedOverrideEntry = HelpersEnsureResolvedOverrideEntry,
        ExtractMergedOverrideEntry = HelpersExtractMergedOverrideEntry,
        StoreMergedOverrideEntry = HelpersStoreMergedOverrideEntry,
        EnsureSpellOverride = HelpersEnsureSpellOverride,
        EnsureUngroupedOverrideEntry = HelpersEnsureUngroupedOverrideEntry,
        CreateLayoutOnlyGroupClone = HelpersCreateLayoutOnlyGroupClone,
        CopyGroupSettingsToSpec = HelpersCopyGroupSettingsToSpec,
        DuplicateGroup = HelpersDuplicateGroup,
    }
end

function Shared.RenderGroupSettingsPanel(config)
    local rc = config.rc
    local gd = config.gd
    local groupIndex = config.groupIndex
    local registerDropdown = config.registerDropdown
    local save = config.saveAndRefresh
    local slider = config.createSlider
    local L = config.L
    local tf = config.textFields
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

    local growDropdown = registerDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
    growDropdown:SetWidth(180)
    growDropdown:SetPoint("TOPLEFT", 0, yOff)
    growDropdown:SetDefaultText(Shared.GetGrowLabel(gd.grow or "RIGHT"))
    UI.SetupValueDropdown(growDropdown, Shared.GROW_OPTIONS,
        function() return gd.grow or "RIGHT" end,
        function(val) gd.grow = val; save() end
    )
    yOff = yOff - 40

    if config.preSpacingSection then
        yOff = config.preSpacingSection(rc, yOff)
    end

    local spacingSlider = slider(rc, L["Spacing"], -1, 50, gd.spacing or 4, function(v)
        gd.spacing = v; save()
    end)
    spacingSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local widthSlider = slider(rc, L["Icon Width"], 16, 100, gd.iconWidth or 30, function(v)
        gd.iconWidth = v; save()
    end)
    widthSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local heightSlider = slider(rc, L["Icon Height"], 16, 100, gd.iconHeight or 30, function(v)
        gd.iconHeight = v; save()
    end)
    heightSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    if config.postSizeSection then
        yOff = config.postSizeSection(rc, yOff)
    end

    yOff = yOff - 10
    local textHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
    textHeader:SetPoint("TOPLEFT", 0, yOff)
    textHeader:SetText(L["Text"])
    textHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
    yOff = yOff - 34

    local cdFSSlider = slider(rc, L["Cooldown Size"], 6, 32, gd.cooldownFontSize or 12, function(v)
        gd.cooldownFontSize = v; save()
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
        save()
    end)
    cdColorPicker:SetPoint("LEFT", cdColorLabel, "RIGHT", 6, 0)
    yOff = yOff - 30

    local secFSSlider = slider(rc, L["Charge Size"], 6, 32, gd[tf.sizeKey] or tf.sizeDefault, function(v)
        gd[tf.sizeKey] = v; save()
    end)
    secFSSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local secColorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    secColorLabel:SetText(L["Color"])
    secColorLabel:SetPoint("TOPLEFT", 0, yOff)
    local secColorInit = gd[tf.colorKey] or { r = 1, g = 1, b = 1 }
    local secColorPicker = UI.CreateSimpleColorPicker(rc, secColorInit, function(r, g, b)
        if not gd[tf.colorKey] then gd[tf.colorKey] = { r = 1, g = 1, b = 1, a = 1 } end
        gd[tf.colorKey].r, gd[tf.colorKey].g, gd[tf.colorKey].b = r, g, b
        save()
    end)
    secColorPicker:SetPoint("LEFT", secColorLabel, "RIGHT", 6, 0)
    yOff = yOff - 30

    local secPosLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    secPosLabel:SetText(L["Position"])
    secPosLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local secPosDropdown = registerDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
    secPosDropdown:SetWidth(180)
    secPosDropdown:SetPoint("TOPLEFT", 0, yOff)
    secPosDropdown:SetDefaultText(gd[tf.posKey] or tf.posDefault)
    UI.SetupPositionDropdown(secPosDropdown,
        function() return gd[tf.posKey] or tf.posDefault end,
        function(val) gd[tf.posKey] = val; save() end
    )
    yOff = yOff - 40

    local secXSlider = slider(rc, L["X Offset"], -20, 20, gd[tf.xKey] or 0, function(v)
        gd[tf.xKey] = v; save()
    end)
    secXSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local secYSlider = slider(rc, L["Y Offset"], -20, 20, gd[tf.yKey] or 0, function(v)
        gd[tf.yKey] = v; save()
    end)
    secYSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    yOff = yOff - 10
    local anchorHeader = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font18")
    anchorHeader:SetPoint("TOPLEFT", 0, yOff)
    anchorHeader:SetText(L["Anchor"])
    anchorHeader:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
    yOff = yOff - 34

    local anchorTargetLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    anchorTargetLabel:SetText(L["Anchor To"])
    anchorTargetLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local UpdateAnchorVisibility
    local xSlider, ySlider
    local anchorTargetDropdown = registerDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
    anchorTargetDropdown:SetWidth(180)
    anchorTargetDropdown:SetPoint("TOPLEFT", 0, yOff)
    local currentTarget = gd.anchorTarget or "screen"
    local anchorTargets = config.anchorTargets
    local targetLabelMap = {}
    for _, entry in ipairs(anchorTargets) do
        targetLabelMap[entry.value] = entry.label
    end
    anchorTargetDropdown:SetDefaultText(targetLabelMap[currentTarget] or targetLabelMap.screen or "Screen")
    UI.SetupValueDropdown(anchorTargetDropdown, anchorTargets,
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
            save()
            UpdateAnchorVisibility()
        end
    )
    yOff = yOff - 40
    local yAfterTarget = yOff

    local anchorLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    anchorLabel:SetText(L["Anchor Point"])
    anchorLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local anchorDropdown = registerDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
    anchorDropdown:SetWidth(180)
    anchorDropdown:SetPoint("TOPLEFT", 0, yOff)
    anchorDropdown:SetDefaultText(gd.anchorPoint or "CENTER")
    UI.SetupPositionDropdown(anchorDropdown,
        function() return gd.anchorPoint or "CENTER" end,
        function(val) gd.anchorPoint = val; save() end
    )
    yOff = yOff - 40

    local relLabel = rc:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
    relLabel:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 22

    local relDropdown = registerDropdown(CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate"))
    relDropdown:SetWidth(180)
    relDropdown:SetPoint("TOPLEFT", 0, yOff)
    relDropdown:SetDefaultText(gd.anchorRelativeTo or "CENTER")
    UI.SetupPositionDropdown(relDropdown,
        function() return gd.anchorRelativeTo or "CENTER" end,
        function(val) gd.anchorRelativeTo = val; save() end
    )
    yOff = yOff - 40
    local yAfterConditional = yOff

    xSlider = slider(rc, L["X Offset"], -840, 840, gd.offsetX or 0, function(v)
        gd.offsetX = v; save()
    end)
    xSlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    ySlider = slider(rc, L["Y Offset"], -470, 470, gd.offsetY or 0, function(v)
        gd.offsetY = v; save()
    end)
    ySlider:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    local anchorRelLabels = config.anchorRelLabels or {}
    UpdateAnchorVisibility = function()
        local isScreen = (gd.anchorTarget or "screen") == "screen"
        anchorLabel:SetShown(not isScreen)
        anchorDropdown:SetShown(not isScreen)
        relLabel:SetShown(not isScreen)
        relDropdown:SetShown(not isScreen)
        if not isScreen then
            local target = gd.anchorTarget
            relLabel:SetText(anchorRelLabels[target] or (L["Essential Viewer Point"]))
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
