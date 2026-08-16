------------------------------------------------------------
-- 設定介面元件庫（白貼圖 backdrop + 1px 硬邊 + 職業 accent 色）
-- 全部自寫，不依賴任何外部 UI 函式庫（避免 scale / 字型互相干擾）
------------------------------------------------------------
local _, ns = ...

ns.W = {}
local W = ns.W
local P = ns.P

local WHITE = "Interface\\BUTTONS\\WHITE8X8"

------------------------------------------------------------
-- accent 色 = 玩家職業色（player token 安全）
------------------------------------------------------------
local accent = { r = 0.7, g = 0.7, b = 0.7 }
do
    local c = ns.playerClass and RAID_CLASS_COLORS[ns.playerClass]
    if c then accent.r, accent.g, accent.b = c.r, c.g, c.b end
end
function W.Accent(alpha)
    return accent.r, accent.g, accent.b, alpha or 1
end

------------------------------------------------------------
-- 字型物件
------------------------------------------------------------
local fontNormal = CreateFont("MiliUIUF_FontNormal")
fontNormal:SetFont(ns.Media.Font(), 13, "")
fontNormal:SetTextColor(1, 1, 1)
fontNormal:SetShadowColor(0, 0, 0)
fontNormal:SetShadowOffset(1, -1)

local fontTitle = CreateFont("MiliUIUF_FontTitle")
fontTitle:SetFont(ns.Media.Font(), 14, "")
fontTitle:SetTextColor(1, 1, 1)
fontTitle:SetShadowColor(0, 0, 0)
fontTitle:SetShadowOffset(1, -1)

local fontDisabled = CreateFont("MiliUIUF_FontDisabled")
fontDisabled:SetFont(ns.Media.Font(), 13, "")
fontDisabled:SetTextColor(0.4, 0.4, 0.4)

local fontSmall = CreateFont("MiliUIUF_FontSmall")
fontSmall:SetFont(ns.Media.Font(), 11, "")
fontSmall:SetTextColor(0.8, 0.8, 0.8)
fontSmall:SetShadowColor(0, 0, 0)
fontSmall:SetShadowOffset(1, -1)

W.fontNormal, W.fontTitle, W.fontDisabled, W.fontSmall =
    fontNormal, fontTitle, fontDisabled, fontSmall

------------------------------------------------------------
-- 基礎樣式
------------------------------------------------------------
function W.Stylize(frame, color, borderColor)
    color = color or { 0.1, 0.1, 0.1, 0.9 }
    borderColor = borderColor or { 0, 0, 0, 1 }
    frame:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = P.Scale(1),
    })
    frame:SetBackdropColor(unpack(color))
    frame:SetBackdropBorderColor(unpack(borderColor))
end

function W.CreateFrame(name, parent, width, height, transparent)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    f:EnableMouse(true)
    if not transparent then W.Stylize(f) end
    if width and height then P.Size(f, width, height) end
    return f
end

------------------------------------------------------------
-- 按鈕
------------------------------------------------------------
local BTN_COLORS = {
    normal      = { { 0.115, 0.115, 0.115, 1 },  { 0.23, 0.23, 0.23, 1 } },
    accent      = { { accent.r, accent.g, accent.b, 0.3 }, { accent.r, accent.g, accent.b, 0.6 } },
    ["accent-hover"] = { { 0.115, 0.115, 0.115, 1 }, { accent.r, accent.g, accent.b, 0.6 } },
    red         = { { 0.6, 0.1, 0.1, 0.6 }, { 0.6, 0.1, 0.1, 1 } },
    green       = { { 0.1, 0.6, 0.1, 0.6 }, { 0.1, 0.6, 0.1, 1 } },
}

function W.CreateButton(parent, text, colorKey, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(b, width or 60, height or 20)
    local colors = BTN_COLORS[colorKey or "normal"] or BTN_COLORS.normal
    b._colors = colors
    W.Stylize(b, colors[1])

    b:SetNormalFontObject(fontNormal)
    b:SetDisabledFontObject(fontDisabled)
    b:SetText(text or "")
    b:SetPushedTextOffset(0, -1)

    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self:SetBackdropColor(unpack(self._colors[2])) end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self._colors[1]))
    end)
    return b
end

-- 互斥高亮群組（分頁鈕用）
function W.CreateButtonGroup(buttons, onClick)
    local function HighlightOnly(selected)
        for _, b in ipairs(buttons) do
            if b == selected then
                b:SetBackdropColor(W.Accent(0.6))
                b._colors = { { W.Accent(0.6) }, { W.Accent(0.6) } }
            else
                b._colors = BTN_COLORS["accent-hover"]
                b:SetBackdropColor(unpack(b._colors[1]))
            end
        end
    end
    for _, b in ipairs(buttons) do
        b:SetScript("OnClick", function(self)
            HighlightOnly(self)
            onClick(self.id, self)
        end)
    end
    return HighlightOnly
end

------------------------------------------------------------
-- 勾選框
------------------------------------------------------------
function W.CreateCheckButton(parent, label, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    P.Size(cb, 14, 14)
    W.Stylize(cb, { 0.115, 0.115, 0.115, 1 })

    cb.label = cb:CreateFontString(nil, "OVERLAY")
    cb.label:SetFontObject(fontNormal)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    cb.label:SetText(label or "")
    -- 點標籤也能勾（Platynator 手法：整列都是點擊區）
    if label and label ~= "" then
        cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 8), 0, 0)
    end

    local checked = cb:CreateTexture(nil, "ARTWORK")
    checked:SetTexture(WHITE)
    checked:SetVertexColor(W.Accent(0.85))
    checked:SetPoint("TOPLEFT", 2, -2)
    checked:SetPoint("BOTTOMRIGHT", -2, 2)
    cb:SetCheckedTexture(checked)

    cb:SetScript("OnClick", function(self)
        if onChange then onChange(self:GetChecked() and true or false) end
    end)
    cb:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(W.Accent(1)) end)
    cb:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0, 0, 0, 1) end)
    return cb
end

------------------------------------------------------------
-- 滑桿（真 Slider + 1px 軌道 + accent 方塊拇指 + 右側可打字數值框）
-- 拖曳中 onChange（即時）；放開 / 打字 Enter / 滾輪 才 afterChange（套用）
------------------------------------------------------------
local function Quantize(v, low, high, step)
    step = step or 1
    v = math.floor((v - low) / step + 0.5) * step + low
    if v < low then v = low end
    if v > high then v = high end
    return tonumber(string.format("%.2f", v))
end

function W.CreateSlider(parent, low, high, width, step, onChange, afterChange)
    step = step or 1
    local holder = CreateFrame("Frame", nil, parent)
    P.Size(holder, width or 200, 20)

    local slider = CreateFrame("Slider", nil, holder, "BackdropTemplate")
    slider:SetPoint("LEFT", 0, 0)
    P.Size(slider, (width or 200) - 56, 10)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    W.Stylize(slider, { 0.115, 0.115, 0.115, 1 })

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(W.Accent(0.75))
    P.Size(thumb, 8, 8)
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnEnter", function() thumb:SetVertexColor(W.Accent(1)) end)
    slider:SetScript("OnLeave", function() thumb:SetVertexColor(W.Accent(0.75)) end)

    local eb = W.CreateEditBox(holder, 48, 18)
    eb:SetPoint("LEFT", slider, "RIGHT", 6, 0)
    eb:SetJustifyH("CENTER")
    eb:SetFontObject(fontSmall)

    holder.slider, holder.editBox = slider, eb
    holder.low, holder.high, holder.step = low, high, step
    local suppress = false

    local function Display(v)
        eb:SetText(v)
        eb:SetCursorPosition(0)
    end

    function holder:SetValue(v)
        v = Quantize(tonumber(v) or low, low, high, step)
        suppress = true
        slider:SetValue(v)
        suppress = false
        Display(v)
        holder.value = v
    end
    function holder:GetValue() return holder.value end

    slider:SetScript("OnValueChanged", function(_, v, userChanged)
        v = Quantize(v, low, high, step)
        if v == holder.value then return end
        holder.value = v
        Display(v)
        if not suppress and userChanged and onChange then onChange(v) end
    end)
    slider:SetScript("OnMouseUp", function()
        if afterChange then afterChange(holder.value) end
    end)
    -- 刻意不吃滾輪：捲動設定頁時很容易滑過拉桿而誤改數值。
    -- 要微調就用右邊的數字框（可打字、可滾輪）

    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local v = tonumber(self:GetText())
        if v then
            holder:SetValue(v)
            if afterChange then afterChange(holder.value) end
        else
            Display(holder.value)
        end
    end)
    eb:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(W.Accent(1))
        self:HighlightText()
    end)

    holder:SetValue(low)
    return holder
end

------------------------------------------------------------
-- 微調數字框：小 editbox，滾輪 ±step（Shift ×10），Enter 套用
-- 給座標/尺寸這種要精準到 1px 的欄位（拉桿在 ±300 範圍抓不準）
------------------------------------------------------------
function W.CreateNumberBox(parent, width, step, onCommit)
    step = step or 1
    local eb = W.CreateEditBox(parent, width or 46, 18)
    eb:SetJustifyH("CENTER")
    eb:SetFontObject(fontSmall)
    eb:SetNumeric(false)

    local function Commit(v)
        v = tonumber(v)
        if v == nil then
            eb:SetText(eb.value or 0)
            return
        end
        eb.value = v
        eb:SetText(v)
        eb:SetCursorPosition(0)
        if onCommit then onCommit(v) end
    end

    function eb:SetValue(v)
        eb.value = tonumber(v) or 0
        eb:SetText(eb.value)
        eb:SetCursorPosition(0)
    end
    function eb:GetValue() return eb.value end

    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        Commit(self:GetText())
    end)
    -- 滾輪微調只在「點進去（有焦點）」時才吃：沒焦點時不攔截滾輪事件，
    -- 捲動設定頁滑過數字框既不會誤改數值、也不會卡住捲動
    eb:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(W.Accent(1))
        self:HighlightText()
        self:EnableMouseWheel(true)
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        self:EnableMouseWheel(false)
    end)
    eb:SetScript("OnMouseWheel", function(self, delta)
        if not self:HasFocus() then return end
        local mult = IsShiftKeyDown() and 10 or 1
        Commit((self.value or 0) + delta * step * mult)
    end)
    return eb
end

------------------------------------------------------------
-- 顏色選擇（swatch + 暴雪 ColorPickerFrame）
------------------------------------------------------------
function W.CreateColorPicker(parent, label, hasAlpha, onConfirm)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(b, 14, 14)
    W.Stylize(b, { 1, 1, 1, 1 })

    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFontObject(fontNormal)
    b.label:SetPoint("LEFT", b, "RIGHT", 5, 0)
    b.label:SetText(label or "")

    b.color = { r = 1, g = 1, b = 1, a = 1 }

    function b:SetColor(c)
        if not c then return end
        b.color = { r = c.r or 1, g = c.g or 1, b = c.b or 1, a = c.a or 1 }
        b:SetBackdropColor(b.color.r, b.color.g, b.color.b, 1)
    end

    b:SetScript("OnClick", function()
        local c = b.color
        local info = {
            r = c.r, g = c.g, b = c.b, opacity = c.a, hasOpacity = hasAlpha,
            swatchFunc = function()
                local r, g, bl = ColorPickerFrame:GetColorRGB()
                local a = hasAlpha and ColorPickerFrame:GetColorAlpha() or c.a
                b:SetColor({ r = r, g = g, b = bl, a = a })
                if onConfirm then onConfirm(r, g, bl, a) end
            end,
            opacityFunc = function()
                local r, g, bl = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                b:SetColor({ r = r, g = g, b = bl, a = a })
                if onConfirm then onConfirm(r, g, bl, a) end
            end,
            cancelFunc = function(prev)
                if prev then
                    b:SetColor({ r = prev.r, g = prev.g, b = prev.b, a = prev.opacity })
                    if onConfirm then onConfirm(prev.r, prev.g, prev.b, prev.opacity) end
                end
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    return b
end

------------------------------------------------------------
-- 文字輸入框
------------------------------------------------------------
function W.CreateEditBox(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    P.Size(eb, width or 120, height or 20)
    W.Stylize(eb, { 0.115, 0.115, 0.115, 1 })
    eb:SetFontObject(fontNormal)
    eb:SetTextInsets(4, 4, 0, 0)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(W.Accent(1)) end)
    eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(0, 0, 0, 1) end)
    return eb
end

-- 多行卷軸輸入框（匯入匯出用）
function W.CreateScrollEditBox(parent, width, height, onTextChanged)
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    P.Size(holder, width or 300, height or 150)
    W.Stylize(holder, { 0.115, 0.115, 0.115, 1 })

    local scroll = CreateFrame("ScrollFrame", nil, holder, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -22, 4)

    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetFontObject(fontNormal)
    eb:SetWidth((width or 300) - 30)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if onTextChanged then
        eb:SetScript("OnTextChanged", function(self, userChanged)
            onTextChanged(self, userChanged)
        end)
    end
    scroll:SetScrollChild(eb)
    holder.editBox = eb
    holder.scroll = scroll
    return holder
end

------------------------------------------------------------
-- 下拉選單（共用選單框）
------------------------------------------------------------
local menuFrame
local function EnsureMenu()
    if menuFrame then return menuFrame end
    menuFrame = CreateFrame("Frame", "MiliUIUF_DropdownMenu", UIParent, "BackdropTemplate")
    menuFrame:SetFrameStrata("TOOLTIP")
    W.Stylize(menuFrame, { 0.1, 0.1, 0.1, 0.97 })
    menuFrame:Hide()
    menuFrame.items = {}
    menuFrame:SetScript("OnHide", function(self) self:Hide() end)
    return menuFrame
end

function W.CloseDropdowns()
    if menuFrame then menuFrame:Hide() end
end

function W.CreateDropdown(parent, width, items, onSelect)
    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(dd, width or 120, 20)
    W.Stylize(dd, { 0.115, 0.115, 0.115, 1 })

    dd.text = dd:CreateFontString(nil, "OVERLAY")
    dd.text:SetFontObject(fontNormal)
    dd.text:SetPoint("LEFT", 5, 0)
    dd.text:SetPoint("RIGHT", -16, 0)
    dd.text:SetJustifyH("LEFT")
    dd.text:SetWordWrap(false)

    -- 箭頭用貼圖不用字元：中文字型（blei00d）沒有 ▾ 這類符號，會畫成方框
    local arrow = dd:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetRotation(math.rad(-90))
    P.Size(arrow, 12, 12)
    arrow:SetPoint("RIGHT", -3, 0)
    arrow:SetVertexColor(0.8, 0.8, 0.8)

    dd.items = items or {}
    dd.selected = nil

    function dd:SetItems(newItems) dd.items = newItems end
    function dd:SetSelectedValue(value)
        dd.selected = value
        for _, item in ipairs(dd.items) do
            if item.value == value then
                dd.text:SetText(item.text)
                return
            end
        end
        dd.text:SetText(value ~= nil and tostring(value) or "")
    end
    function dd:GetSelected() return dd.selected end

    dd:SetScript("OnClick", function(self)
        local menu = EnsureMenu()
        if menu:IsShown() and menu.owner == self then menu:Hide(); return end
        menu.owner = self
        -- 重建項目按鈕
        for _, b in ipairs(menu.items) do b:Hide() end
        local height = 2
        for i, item in ipairs(self.items) do
            local b = menu.items[i]
            if not b then
                b = CreateFrame("Button", nil, menu, "BackdropTemplate")
                b.text = b:CreateFontString(nil, "OVERLAY")
                b.text:SetFontObject(fontNormal)
                b.text:SetPoint("LEFT", 5, 0)
                b.text:SetJustifyH("LEFT")
                b:SetScript("OnEnter", function(bb) bb:SetBackdropColor(W.Accent(0.4)) end)
                b:SetScript("OnLeave", function(bb) bb:SetBackdropColor(0, 0, 0, 0) end)
                menu.items[i] = b
            end
            b:SetBackdrop({ bgFile = WHITE })
            b:SetBackdropColor(0, 0, 0, 0)
            P.Size(b, (self:GetWidth() or 120) - 4, 18)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -height)
            b.text:SetText(item.text)
            b:SetScript("OnClick", function()
                self:SetSelectedValue(item.value)
                menu:Hide()
                if onSelect then onSelect(item.value) end
                if item.onClick then item.onClick(item.value) end
            end)
            b:Show()
            height = height + 18
        end
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        P.Size(menu, self:GetWidth(), height + 2)
        menu:Show()
    end)
    return dd
end

------------------------------------------------------------
-- 卷軸容器
------------------------------------------------------------
function W.CreateScrollFrame(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -20, 0)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.child = child

    function scroll:SetContentHeight(h)
        child:SetHeight(h)
        child:SetWidth(scroll:GetWidth())
    end
    scroll:SetScript("OnSizeChanged", function(self)
        child:SetWidth(self:GetWidth())
    end)
    return scroll
end

------------------------------------------------------------
-- 標題列 / 分隔線（accent 線 + 1px 黑影）
------------------------------------------------------------
function W.CreateSectionTitle(parent, text, width)
    local holder = CreateFrame("Frame", nil, parent)
    P.Size(holder, width or 200, 22)
    local fs = holder:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(fontTitle)
    fs:SetPoint("BOTTOMLEFT", 0, 5)
    fs:SetText(text)
    local shadow = holder:CreateTexture(nil, "ARTWORK", nil, -1)
    shadow:SetTexture(WHITE)
    shadow:SetVertexColor(0, 0, 0, 1)
    shadow:SetPoint("BOTTOMLEFT", 1, -1)
    shadow:SetPoint("BOTTOMRIGHT", 1, -1)
    shadow:SetHeight(P.Scale(1))
    local line = holder:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetVertexColor(W.Accent(0.777))
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetHeight(P.Scale(1))
    holder.text = fs
    return holder
end

-- 小節標題（元件面板裡的分組：位置 / 顏色 / 顯示…），比 SectionTitle 低調
function W.CreateGroupLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(fontSmall)
    fs:SetTextColor(W.Accent(1))
    fs:SetText(text)
    return fs
end

------------------------------------------------------------
-- 戰鬥遮罩
------------------------------------------------------------
-- 戰鬥中蓋住整個設定區。EnableMouse + EnableMouseWheel 兩個都要開——
-- 只調 alpha 或只擋 mouse 的話，點擊／滾輪照樣穿透到底下的控制項。
-- strata 要壓過確認彈窗（FULLSCREEN_DIALOG 400/410），不然彈窗會浮在遮罩上面還能按。
function W.CreateCombatMask(parent, text)
    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(500)
    mask:EnableMouse(true)
    mask:EnableMouseWheel(true)
    mask:SetBackdrop({ bgFile = WHITE })
    mask:SetBackdropColor(0.17, 0.15, 0.15, 0.8)

    mask.text = mask:CreateFontString(nil, "OVERLAY")
    mask.text:SetFontObject(fontTitle)
    mask.text:SetTextColor(1, 0.2, 0.2)
    mask.text:SetPoint("LEFT", 5, 0)
    mask.text:SetPoint("RIGHT", -5, 0)
    mask.text:SetJustifyH("CENTER")
    mask.text:SetText(text or "無法在戰鬥中更改設定")

    mask:Hide()
    parent.combatMask = mask
    return mask
end

------------------------------------------------------------
-- 確認彈窗
------------------------------------------------------------
-- 確認彈窗：蓋在整個 parent 上方（獨立 strata，不受分頁/卷軸子層級影響），
-- 背後一層半透明遮罩擋掉點擊
function W.CreateConfirmPopup(parent, width, text, onAccept)
    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = WHITE })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    local popup = W.CreateFrame(nil, parent, width or 240, 84)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup.mask = mask
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function() mask:Hide() end)

    local fs = popup:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(fontNormal)
    fs:SetPoint("TOP", 0, -14)
    fs:SetWidth((width or 240) - 24)
    fs:SetJustifyH("CENTER")
    fs:SetText(text)

    local yes = W.CreateButton(popup, "確定", "green", 80, 22)
    yes:SetPoint("BOTTOMLEFT", 26, 12)
    yes:SetScript("OnClick", function()
        popup:Hide()
        if onAccept then onAccept() end
    end)
    local no = W.CreateButton(popup, "取消", "red", 80, 22)
    no:SetPoint("BOTTOMRIGHT", -26, 12)
    no:SetScript("OnClick", function() popup:Hide() end)
    return popup
end
