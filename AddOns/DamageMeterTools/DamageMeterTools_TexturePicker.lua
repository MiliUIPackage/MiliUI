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
local lastOptions = nil
local lastHoverItem = nil

local BUILTIN_ID = "__DMT_BUILTIN_MATERIALS__"
local BUILTIN_NONE_ID = "__DMT_BUILTIN_NONE__"

local function GetLSM()
    if not LibStub then
        return nil
    end
    return LibStub("LibSharedMedia-3.0", true)
end

local function SafeLower(s)
    s = tostring(s or "")
    return string.lower(s)
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

local function GetTextureList(includeBuiltIn)
    wipe(allItems)

    if includeBuiltIn then
        table.insert(allItems, {
            id = "__HEADER_BUILTIN__",
            isHeader = true,
            display = L("內建") or "內建",
        })

        table.insert(allItems, {
            id = BUILTIN_ID,
            display = L("內建材質") or "內建材質",
            texture = "Interface\\AddOns\\DamageMeterTools\\Materials.tga",
            kind = "BUILTIN",
        })

        table.insert(allItems, {
            id = BUILTIN_NONE_ID,
            display = L("透明（無材質）") or "透明（無材質）",
            texture = "",
            kind = "BUILTIN_NONE",
        })
    end

    local LSM = GetLSM()
    local names = {}

    if DamageMeterTools_GetLSMStatusbarList then
        names = DamageMeterTools_GetLSMStatusbarList()
    elseif LSM then
        local hash = LSM:HashTable("statusbar") or {}
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
            local path = LSM and LSM:Fetch("statusbar", name, true)
            table.insert(allItems, {
                id = name,
                display = name,
                texture = path,
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

    local source = GetTextureList(lastOptions and lastOptions.includeBuiltIn)
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
    row:SetSize(430, 40)

    row.headerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.headerText:SetPoint("LEFT", 4, 0)
    row.headerText:SetJustifyH("LEFT")
    row.headerText:SetWidth(422)

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
    row.previewWrap:SetSize(132, 16)
    ApplyBackdrop(row.previewWrap, "panel", "border")

    row.preview = row.previewWrap:CreateTexture(nil, "ARTWORK")
    row.preview:SetPoint("TOPLEFT", 1, -1)
    row.preview:SetPoint("BOTTOMRIGHT", -1, 1)

    row.name = row.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.previewWrap, "RIGHT", 12, 0)
    row.name:SetWidth(200)
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

    clickBlocker = CreateFrame("Frame", "DamageMeterToolsTexturePickerBlocker", UIParent, "BackdropTemplate")
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

    local f = CreateFrame("Frame", "DamageMeterToolsTexturePickerFrame", UIParent, "BackdropTemplate")
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
    f.title:SetText(L("選擇材質") or "選擇材質")
    SetTextColor(f.title, "text")

    -- 自訂 X 按鈕，避免 UIPanelCloseButton 顯示異常
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
    f.previewBox:SetSize(464, 72)
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

    f.previewBarWrap = CreateFrame("Frame", nil, f.previewBox, "BackdropTemplate")
    f.previewBarWrap:SetPoint("TOPLEFT", 12, -34)
    f.previewBarWrap:SetPoint("TOPRIGHT", -12, -34)
    f.previewBarWrap:SetHeight(18)
    ApplyBackdrop(f.previewBarWrap, "panel", "border")

    f.previewBar = f.previewBarWrap:CreateTexture(nil, "ARTWORK")
    f.previewBar:SetPoint("TOPLEFT", 1, -1)
    f.previewBar:SetPoint("BOTTOMRIGHT", -1, 1)

    f.listTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.listTitle:SetPoint("TOPLEFT", 18, -196)
    f.listTitle:SetText(L("可用材質") or "可用材質")
    SetTextColor(f.listTitle, "text")

    f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 18, -218)
    f.scroll:SetPoint("BOTTOMRIGHT", -32, 18)

    f.child = CreateFrame("Frame", nil, f.scroll)
    f.child:SetSize(440, 1)
    f.scroll:SetScrollChild(f.child)

    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel", function(self, delta)
        local sb = self.ScrollBar
        if not sb then return end
        local current = self:GetVerticalScroll()
        local minVal, maxVal = sb:GetMinMaxValues()
        local step = 40
        local newVal = current - delta * step
        if newVal < minVal then newVal = minVal end
        if newVal > maxVal then newVal = maxVal end
        self:SetVerticalScroll(newVal)
    end)

    if T and T.StyleScrollBar then
        T:StyleScrollBar(f.scroll)
    end

    f.searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if pickerFrame then
            pickerFrame:Hide()
        end
    end)

    f:SetScript("OnHide", function(self)
        self.searchBox:ClearFocus()
        local blocker = EnsureClickBlocker()
        blocker:Hide()
        lastHoverItem = nil
    end)

    pickerFrame = f
    return pickerFrame
end

local function SetPreviewTexture(textureObject, path)
    if not textureObject then
        return
    end

    if path and path ~= "" then
        textureObject:SetTexture(path)
        textureObject:SetVertexColor(1, 1, 1, 1)
    else
        textureObject:SetTexture("Interface\\Buttons\\WHITE8X8")
        textureObject:SetVertexColor(0.35, 0.35, 0.35, 1)
    end
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

local function UpdatePreview(item)
    local picker = EnsurePicker()

    if not item or item.isHeader then
        picker.currentText:SetText("")
        picker.previewName:SetText("")
        SetPreviewTexture(picker.previewBar, nil)
        return
    end

    picker.currentText:SetText((L("目前選中：") or "目前選中：") .. tostring(item.display or ""))
    if item.kind == "BUILTIN" then
        picker.previewName:SetText(L("內建") or "內建")
    elseif item.kind == "BUILTIN_NONE" then
        picker.previewName:SetText(L("透明") or "透明")
    else
        picker.previewName:SetText("SharedMedia")
    end

    SetPreviewTexture(picker.previewBar, item.texture)
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
            row:SetHeight(40)
            row:SetHeaderMode(false)

            row.name:SetText(item.display or "")
            if item.kind == "BUILTIN" then
                row.kind:SetText(L("內建") or "內建")
            elseif item.kind == "BUILTIN_NONE" then
                row.kind:SetText(L("透明") or "透明")
            else
                row.kind:SetText("LSM")
            end

            SetTextColor(row.name, "text")
            SetTextColor(row.kind, "text2")

            if item.texture and item.texture ~= "" then
                row.preview:SetTexture(item.texture)
                row.preview:SetVertexColor(1, 1, 1, 1)
            else
                row.preview:SetTexture("Interface\\Buttons\\WHITE8X8")
                row.preview:SetVertexColor(0.35, 0.35, 0.35, 1)
            end

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
                local selectedItem = FindItemByID(lastSelectedName)
                UpdatePreview(selectedItem)
            end)

            row:SetScript("OnClick", function()
                lastSelectedName = item.id
                if lastOnPick then
                    lastOnPick(item.id)
                end
                picker:Hide()
            end)

            y = y - 42
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

    C_Timer.After(0, function()
        if not picker or not picker:IsShown() then
            return
        end

        local left = picker:GetLeft()
        local right = picker:GetRight()
        local top = picker:GetTop()
        local bottom = picker:GetBottom()

        if not left or not right or not top or not bottom then
            return
        end

        local screenLeft = 0
        local screenRight = UIParent:GetWidth()
        local screenTop = UIParent:GetHeight()
        local screenBottom = 0

        local dx, dy = 0, 0

        if right > screenRight then
            dx = screenRight - right - 10
        elseif left < screenLeft then
            dx = screenLeft - left + 10
        end

        if bottom < screenBottom then
            dy = screenBottom - bottom + 10
        elseif top > screenTop then
            dy = screenTop - top - 10
        end

        if dx ~= 0 or dy ~= 0 then
            local point, relativeTo, relativePoint, xOfs, yOfs = picker:GetPoint(1)
            picker:ClearAllPoints()
            picker:SetPoint(point, relativeTo, relativePoint, xOfs + dx, yOfs + dy)
        end
    end)
end

function DamageMeterTools_OpenTexturePicker(anchorFrame, selectedName, onPick, options)
    local picker = EnsurePicker()
    EnsureClickBlocker()

    lastSelectedName = selectedName or "Blizzard"
    lastOnPick = onPick
    lastAnchor = anchorFrame
    lastOptions = options or {}
    lastHoverItem = nil

    picker.title:SetText(lastOptions.title or (L("選擇材質") or "選擇材質"))
    picker.searchBox:SetText("")
    picker.scroll:SetVerticalScroll(0)

    RebuildFilteredList("")
    RefreshRows()

    local selectedItem = FindItemByID(lastSelectedName)
    UpdatePreview(selectedItem)

    picker.searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        RebuildFilteredList(text)
        RefreshRows()

        local selected = FindItemByID(lastSelectedName)
        if lastHoverItem and MatchesSearch(lastHoverItem, text) then
            UpdatePreview(lastHoverItem)
        else
            UpdatePreview(selected)
        end
    end)

    PositionPicker(anchorFrame)

    local blocker = EnsureClickBlocker()
    blocker:Show()

    picker:Show()
    picker:Raise()
end