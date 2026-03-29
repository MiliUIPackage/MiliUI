if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

local L = DamageMeterTools_L or function(s) return s end
local T = DamageMeterToolsTheme

local pickerFrame = nil
local clickBlocker = nil
local rowPool = {}
local filteredList = {}
local allItems = {}

local lastSelectedName = nil
local lastOnPick = nil
local lastAnchor = nil
local lastHoverItem = nil

local BUILTIN_GAME_DEFAULT = "GAME_DEFAULT"

local function GetLSM()
    if not LibStub then
        return nil
    end
    return LibStub("LibSharedMedia-3.0", true)
end

local function SafeLower(s)
    return tostring(s or ""):lower()
end

local function ApplyBackdrop(frame, bgKey, borderKey)
    if T and T.ApplyBackdrop then
        T:ApplyBackdrop(frame, bgKey or "panel", borderKey or "border")
        return
    end

    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(0.05, 0.08, 0.12, 0.96)
    frame:SetBackdropBorderColor(0.30, 0.70, 1.00, 0.30)
end

local function SetTextColor(fs, colorKey, r, g, b, a)
    if not fs or not fs.SetTextColor then
        return
    end

    if T and T.GetColor and colorKey then
        fs:SetTextColor(T:GetColor(colorKey))
        return
    end

    fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
end

local function GetFontPath(name)
    local fontName = tostring(name or BUILTIN_GAME_DEFAULT)

    if fontName == BUILTIN_GAME_DEFAULT then
        return STANDARD_TEXT_FONT
    end

    local LSM = GetLSM()
    if LSM then
        local path = LSM:Fetch("font", fontName, true)
        if path and path ~= "" then
            return path
        end
    end

    return STANDARD_TEXT_FONT
end

local function BuildFontList()
    wipe(allItems)

    table.insert(allItems, {
        id = "__HEADER_BUILTIN__",
        isHeader = true,
        display = L("內建") or "內建",
    })

    table.insert(allItems, {
        id = BUILTIN_GAME_DEFAULT,
        display = "Game Default",
        kind = "BUILTIN",
    })

    local LSM = GetLSM()
    local names = {}

    if LSM then
        local hash = LSM:HashTable("font") or {}
        for name in pairs(hash) do
            table.insert(names, name)
        end
        table.sort(names)
    end

    if #names > 0 then
        table.insert(allItems, {
            id = "__HEADER_LSM__",
            isHeader = true,
            display = "SharedMedia",
        })

        for _, name in ipairs(names) do
            table.insert(allItems, {
                id = name,
                display = name,
                kind = "LSM",
            })
        end
    end

    return allItems
end

local function MatchesSearch(item, keyword)
    if item.isHeader then
        return true
    end

    keyword = SafeLower(keyword)
    if keyword == "" then
        return true
    end

    return SafeLower(item.display):find(keyword, 1, true) ~= nil
end

local function RebuildFilteredList(keyword)
    wipe(filteredList)

    local source = BuildFontList()
    local currentHeader = nil
    local bucket = {}

    local function FlushBucket()
        if currentHeader and #bucket > 0 then
            table.insert(filteredList, currentHeader)
            for _, item in ipairs(bucket) do
                table.insert(filteredList, item)
            end
        end
        currentHeader = nil
        wipe(bucket)
    end

    for _, item in ipairs(source) do
        if item.isHeader then
            FlushBucket()
            currentHeader = item
        else
            if MatchesSearch(item, keyword) then
                table.insert(bucket, item)
            end
        end
    end

    FlushBucket()
end

local function HideAllRows()
    for _, row in ipairs(rowPool) do
        row:Hide()
    end
end

local function AcquireRow(parent)
    for _, row in ipairs(rowPool) do
        if not row:IsShown() then
            row:SetParent(parent)
            row:Show()
            return row
        end
    end

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(430, 44)

    row.headerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.headerText:SetPoint("LEFT", 4, 0)
    row.headerText:SetWidth(422)
    row.headerText:SetJustifyH("LEFT")

    row.bg = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.bg:SetAllPoints()
    ApplyBackdrop(row.bg, "darkButton", "border")

    row.leftAccent = row.bg:CreateTexture(nil, "ARTWORK")
    row.leftAccent:SetPoint("TOPLEFT", 0, 0)
    row.leftAccent:SetPoint("BOTTOMLEFT", 0, 0)
    row.leftAccent:SetWidth(3)
    row.leftAccent:SetColorTexture(0.30, 0.72, 1.00, 0.20)

    row.previewWrap = CreateFrame("Frame", nil, row.bg, "BackdropTemplate")
    row.previewWrap:SetPoint("LEFT", 10, 0)
    row.previewWrap:SetSize(170, 22)
    ApplyBackdrop(row.previewWrap, "panel", "border")

    row.previewText = row.previewWrap:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.previewText:SetPoint("CENTER", 0, 0)
    row.previewText:SetText("傷害量（總體）")

    row.name = row.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.previewWrap, "RIGHT", 12, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")

    row.kind = row.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.kind:SetPoint("RIGHT", -10, 0)

    row.selectedGlow = row.bg:CreateTexture(nil, "OVERLAY")
    row.selectedGlow:SetPoint("TOPLEFT", 1, -1)
    row.selectedGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    row.selectedGlow:SetColorTexture(0.16, 0.42, 0.72, 0.18)
    row.selectedGlow:Hide()

    function row:SetHeaderMode(enabled)
        self.isHeaderRow = enabled and true or false

        if self.isHeaderRow then
            self.bg:Hide()
            self.headerText:Show()
            self.previewWrap:Hide()
            self.name:Hide()
            self.kind:Hide()
            self.selectedGlow:Hide()
        else
            self.bg:Show()
            self.headerText:Hide()
            self.previewWrap:Show()
            self.name:Show()
            self.kind:Show()
        end
    end

    function row:SetSelected(v)
        self._selected = v and true or false
        if self.isHeaderRow then
            return
        end

        if self._selected then
            self.bg:SetBackdropBorderColor(0.36, 0.78, 1.00, 0.85)
            self.leftAccent:SetColorTexture(0.36, 0.78, 1.00, 0.90)
            self.selectedGlow:Show()
        else
            self.bg:SetBackdropBorderColor(0.22, 0.42, 0.62, 0.18)
            self.leftAccent:SetColorTexture(0.30, 0.72, 1.00, 0.20)
            self.selectedGlow:Hide()
        end
    end

    table.insert(rowPool, row)
    return row
end

local function EnsureClickBlocker()
    if clickBlocker then
        return clickBlocker
    end

    clickBlocker = CreateFrame("Frame", "DamageMeterToolsFontPickerBlocker", UIParent, "BackdropTemplate")
    clickBlocker:SetAllPoints(UIParent)
    clickBlocker:SetFrameStrata("FULLSCREEN_DIALOG")
    clickBlocker:SetFrameLevel(100)
    clickBlocker:EnableMouse(true)
    clickBlocker:Hide()

    clickBlocker:SetScript("OnMouseDown", function()
        if pickerFrame and pickerFrame:IsShown() then
            pickerFrame:Hide()
        end
    end)

    return clickBlocker
end

local function EnsurePicker()
    if pickerFrame then
        return pickerFrame
    end

    local f = CreateFrame("Frame", "DamageMeterToolsFontPickerFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 620)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(110)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    ApplyBackdrop(f, "bg", "borderStrong")
    f:Hide()

    f.header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.header:SetPoint("TOPLEFT", 0, 0)
    f.header:SetPoint("TOPRIGHT", 0, 0)
    f.header:SetHeight(48)
    ApplyBackdrop(f.header, "header", "border")

    f.title = f.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("LEFT", 16, 0)
    f.title:SetText(L("選擇標題字型") or "選擇標題字型")
    SetTextColor(f.title, "text")

    if T and T.CreateButton then
        f.close = T:CreateButton(f.header, "×", 34, 24, function()
            f:Hide()
        end, "DANGER")
        f.close:SetPoint("RIGHT", -8, 0)
    else
        f.close = CreateFrame("Button", nil, f.header, "UIPanelCloseButton")
        f.close:SetPoint("RIGHT", -2, 0)
    end

    f.searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.searchLabel:SetPoint("TOPLEFT", 18, -60)
    f.searchLabel:SetText(L("搜尋") or "搜尋")
    SetTextColor(f.searchLabel, "text")

    f.searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.searchBox:SetSize(220, 22)
    f.searchBox:SetPoint("LEFT", f.searchLabel, "RIGHT", 8, 0)
    f.searchBox:SetAutoFocus(false)

    f.currentText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.currentText:SetPoint("TOPLEFT", 18, -88)
    f.currentText:SetWidth(460)
    f.currentText:SetJustifyH("LEFT")
    SetTextColor(f.currentText, "text2")

    f.previewBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.previewBox:SetPoint("TOPLEFT", 18, -112)
    f.previewBox:SetSize(464, 86)
    ApplyBackdrop(f.previewBox, "panel2", "border")

    f.previewTitle = f.previewBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.previewTitle:SetPoint("TOPLEFT", 12, -10)
    f.previewTitle:SetText(L("預覽") or "預覽")
    SetTextColor(f.previewTitle, "text")

    f.previewName = f.previewBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.previewName:SetPoint("TOPRIGHT", -12, -10)
    f.previewName:SetWidth(240)
    f.previewName:SetJustifyH("RIGHT")
    SetTextColor(f.previewName, "text2")

    f.previewText = f.previewBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.previewText:SetPoint("TOPLEFT", 16, -38)
    f.previewText:SetPoint("TOPRIGHT", -16, -38)
    f.previewText:SetJustifyH("LEFT")
    f.previewText:SetText("傷害量（總體）")
    f.previewText:SetTextColor(1.00, 0.82, 0.20, 1.00)

    f.listTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.listTitle:SetPoint("TOPLEFT", 18, -214)
    f.listTitle:SetText(L("可用字型") or "可用字型")
    SetTextColor(f.listTitle, "text")

    f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 18, -236)
    f.scroll:SetPoint("BOTTOMRIGHT", -32, 18)

    f.child = CreateFrame("Frame", nil, f.scroll)
    f.child:SetSize(440, 1)
    f.scroll:SetScrollChild(f.child)

    if T and T.StyleScrollBar then
        T:StyleScrollBar(f.scroll)
    end

    f.searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)

    f:SetScript("OnHide", function(self)
        self.searchBox:ClearFocus()
        EnsureClickBlocker():Hide()
        lastHoverItem = nil
    end)

    pickerFrame = f
    return f
end

local function FindItemByID(id)
    for _, item in ipairs(filteredList) do
        if not item.isHeader and item.id == id then
            return item
        end
    end
    for _, item in ipairs(allItems) do
        if not item.isHeader and item.id == id then
            return item
        end
    end
    return nil
end

local function ApplyPreviewFont(fs, fontName, size)
    if not fs or not fs.SetFont then
        return
    end

    local path = GetFontPath(fontName)
    local ok = pcall(fs.SetFont, fs, path, size or 16, "OUTLINE")
    if not ok then
        pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size or 16, "OUTLINE")
    end
end

local function UpdatePreview(item)
    local picker = EnsurePicker()

    if not item or item.isHeader then
        picker.currentText:SetText("")
        picker.previewName:SetText("")
        ApplyPreviewFont(picker.previewText, BUILTIN_GAME_DEFAULT, 18)
        return
    end

    picker.currentText:SetText((L("目前選中：") or "目前選中：") .. tostring(item.display or ""))
    picker.previewName:SetText(item.kind == "BUILTIN" and (L("內建") or "內建") or "SharedMedia")
    ApplyPreviewFont(picker.previewText, item.id, 18)
end

local function RefreshRows()
    local picker = EnsurePicker()
    HideAllRows()

    local y = -2
    for _, item in ipairs(filteredList) do
        local row = AcquireRow(picker.child)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)

        if item.isHeader then
            row:SetHeight(24)
            row:SetHeaderMode(true)
            row.headerText:SetText(item.display or "")
            SetTextColor(row.headerText, "accent")
            y = y - 24
        else
            row:SetHeight(44)
            row:SetHeaderMode(false)

            row.name:SetText(item.display or "")
            row.kind:SetText(item.kind == "BUILTIN" and (L("內建") or "內建") or "LSM")
            SetTextColor(row.name, "text")
            SetTextColor(row.kind, "text2")

            ApplyPreviewFont(row.previewText, item.id, 12)
            row.previewText:SetText("傷害量（總體）")

            row:SetSelected(item.id == lastSelectedName)

            row:SetScript("OnEnter", function(self)
                if not self._selected then
                    self.bg:SetBackdropBorderColor(0.36, 0.78, 1.00, 0.50)
                    self.leftAccent:SetColorTexture(0.36, 0.78, 1.00, 0.50)
                end
                lastHoverItem = item
                UpdatePreview(item)
            end)

            row:SetScript("OnLeave", function(self)
                self:SetSelected(self._selected)
                UpdatePreview(FindItemByID(lastSelectedName))
            end)

            row:SetScript("OnClick", function()
                lastSelectedName = item.id
                if lastOnPick then
                    lastOnPick(item.id)
                end
                picker:Hide()
            end)

            y = y - 46
        end
    end

    picker.child:SetHeight(math.max(1, -y + 8))
end

local function PositionPicker(anchorFrame)
    local picker = EnsurePicker()
    picker:ClearAllPoints()

    if anchorFrame and anchorFrame.GetCenter then
        picker:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -6)
    else
        picker:SetPoint("CENTER")
    end
end

function DamageMeterTools_OpenFontPicker(anchorFrame, selectedName, onPick)
    local picker = EnsurePicker()
    EnsureClickBlocker()

    lastSelectedName = selectedName or BUILTIN_GAME_DEFAULT
    lastOnPick = onPick
    lastAnchor = anchorFrame
    lastHoverItem = nil

    picker.searchBox:SetText("")
    picker.scroll:SetVerticalScroll(0)

    RebuildFilteredList("")
    RefreshRows()
    UpdatePreview(FindItemByID(lastSelectedName))
    PositionPicker(anchorFrame)

    picker.searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        RebuildFilteredList(text)
        RefreshRows()
        UpdatePreview(lastHoverItem or FindItemByID(lastSelectedName))
    end)

    EnsureClickBlocker():Show()
    picker:Show()
    picker:Raise()
end