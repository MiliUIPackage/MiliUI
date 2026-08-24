------------------------------------------------------------
-- 設定介面元件庫（白貼圖 backdrop + 1px 硬邊 + 職業 accent 色）
-- 全部自寫，不依賴任何外部 UI 函式庫（避免 scale / 字型互相干擾）
--
-- ⚠ 共用層：這支可以逐字複製到其他 MiliUI 插件，宿主專屬的東西一律走
--   ns.WidgetsEnv（見 Libs/MiliUIWidgets/Env.lua）。改這裡時不要引進新的 ns.* 依賴。
------------------------------------------------------------
local _, ns = ...

local Env = ns.WidgetsEnv
local L, P = Env.L, Env.P
local NS = Env.NAMESPACE

ns.W = {}
local W = ns.W

local WHITE = "Interface\\BUTTONS\\WHITE8X8"

------------------------------------------------------------
-- accent 色（由宿主決定，本插件是玩家職業色）
------------------------------------------------------------
local accent = { r = 0.7, g = 0.7, b = 0.7 }
do
    -- 拿不到就留著灰色預設。少了這道守衛，Env.Accent 沒回值會讓 accent.r 變 nil，
    -- 而爆點會落在很後面的 SetBackdropColor，看不出跟這裡有關。
    local r, g, b = Env.Accent()
    if r then accent.r, accent.g, accent.b = r, g, b end
end
function W.Accent(alpha)
    return accent.r, accent.g, accent.b, alpha or 1
end

------------------------------------------------------------
-- 字型物件
--
-- 名字一定要帶 NS 前綴：CreateFont 撞名會回傳既有物件而不是新的，
-- 兩個插件各帶一份這支卻用同名字型，就會互相蓋掉對方的字級與顏色。
------------------------------------------------------------
local fontNormal = CreateFont(NS .. "_FontNormal")
fontNormal:SetFont(Env.Font(), 13, "")
fontNormal:SetTextColor(1, 1, 1)
fontNormal:SetShadowColor(0, 0, 0)
fontNormal:SetShadowOffset(1, -1)

local fontTitle = CreateFont(NS .. "_FontTitle")
fontTitle:SetFont(Env.Font(), 14, "")
fontTitle:SetTextColor(1, 1, 1)
fontTitle:SetShadowColor(0, 0, 0)
fontTitle:SetShadowOffset(1, -1)

-- ⚠ 目前沒有人用。**不要**把它接回 CreateButton 的 SetDisabledFontObject：
-- 切換 enable 狀態時換字型物件會讓 FontString 重新配置並吃掉最後一個字（實測）。
-- 按鈕的停用灰字是自己 SetTextColor 上的。
local fontDisabled = CreateFont(NS .. "_FontDisabled")
fontDisabled:SetFont(Env.Font(), 13, "")
fontDisabled:SetTextColor(0.4, 0.4, 0.4)

local fontSmall = CreateFont(NS .. "_FontSmall")
fontSmall:SetFont(Env.Font(), 11, "")
fontSmall:SetTextColor(0.8, 0.8, 0.8)
fontSmall:SetShadowColor(0, 0, 0)
fontSmall:SetShadowOffset(1, -1)

W.fontNormal, W.fontTitle, W.fontDisabled, W.fontSmall =
    fontNormal, fontTitle, fontDisabled, fontSmall

------------------------------------------------------------
-- 基礎樣式
------------------------------------------------------------

-- 面板控件的統一填色。原本是同一個 0.115 抄在七個地方，改一次要找七處，所以提成常數。
-- Stylize 只讀不寫（unpack），共用同一張表是安全的。
local WIDGET_FILL = { 0.115, 0.115, 0.115, 1 }

-- 勾選框例外，比其他控件亮一階。它是唯一「沒勾就什麼都沒有」的控件 —— 滑桿有拇指、
-- 輸入框有文字、下拉有箭頭，都還有東西可看；勾選框沒勾的時候，玩家能不能看出「這裡有
-- 一個可以點的方塊」完全靠底色本身。用 WIDGET_FILL 在深色面板上幾乎糊成一片（玩家回報
-- 看不清楚），邊框又是純黑幫不上忙。0.22 對齊按鈕 hover 的 0.23，不會跳出既有色階。
local CHECKBOX_FILL = { 0.28, 0.28, 0.28, 1 }

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
    normal      = { WIDGET_FILL,  { 0.23, 0.23, 0.23, 1 } },
    accent      = { { accent.r, accent.g, accent.b, 0.3 }, { accent.r, accent.g, accent.b, 0.6 } },
    ["accent-hover"] = { WIDGET_FILL, { accent.r, accent.g, accent.b, 0.6 } },
    red         = { { 0.6, 0.1, 0.1, 0.6 }, { 0.6, 0.1, 0.1, 1 } },
    green       = { { 0.1, 0.6, 0.1, 0.6 }, { 0.1, 0.6, 0.1, 1 } },
}

function W.CreateButton(parent, text, colorKey, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(b, width or 60, height or 20)
    local colors = BTN_COLORS[colorKey or "normal"] or BTN_COLORS.normal
    b._colors = colors
    W.Stylize(b, colors[1])

    -- ⚠ label 自己建、自己註冊，而且**兩個狀態用同一個字型物件**。
    -- 原本 normal/disabled 給不同物件，結果 SetEnabled 切換的瞬間暴雪會換掉
    -- FontString 的字型物件並重新配置 —— 實測會把最後一個字吃掉（匯入按鈕貼上
    -- 字串變亮那一刻「匯入並重載」變成「匯入並重」）。字型固定、只換顏色就沒事。
    local fs = b:CreateFontString(nil, "OVERLAY")
    -- 只錨 CENTER、不給左右錨點：一來字寬自然（Tab_Unit 的元件切換鈕靠
    -- GetStringWidth() 自適應寬度，夾住就量不準），二來真的太長也只是溢出按鈕、
    -- 不會被切掉
    fs:SetPoint("CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    fs:SetWordWrap(false)
    fs:SetFontObject(fontNormal)
    b:SetFontString(fs)
    b:SetNormalFontObject(fontNormal)
    b:SetDisabledFontObject(fontNormal)
    b:SetText(text or "")
    b:SetPushedTextOffset(0, -1)

    -- 停用的灰字自己上：SetEnabled / Enable / Disable 三條路都要接
    -- （SetEnabled 是 C 端方法，不會呼叫到我們覆寫的 Enable/Disable）
    local function Recolor(self)
        if self:IsEnabled() then
            fs:SetTextColor(1, 1, 1)
        else
            fs:SetTextColor(0.4, 0.4, 0.4)
        end
    end
    local rawSetEnabled, rawEnable, rawDisable = b.SetEnabled, b.Enable, b.Disable
    function b:SetEnabled(on) rawSetEnabled(self, on); Recolor(self) end
    function b:Enable()       rawEnable(self);         Recolor(self) end
    function b:Disable()      rawDisable(self);        Recolor(self) end

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
    -- 18px：14px 配 zhTW 的大字標籤顯得小氣，加大到跟行高平衡
    P.Size(cb, 18, 18)
    W.Stylize(cb, CHECKBOX_FILL)

    cb.label = cb:CreateFontString(nil, "OVERLAY")
    cb.label:SetFontObject(fontNormal)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    cb.label:SetText(label or "")
    -- 點標籤也能勾（Platynator 手法：整列都是點擊區）
    if label and label ~= "" then
        cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 8), 0, 0)
    end

    -- 勾＝職業色、刻意比框大一圈往外溢（暴雪原生勾選框的視覺語言，素材換成
    -- 現代扁平的 checkmark-minimal 細勾），外加 1px 黑描邊跟任何底色分離。
    -- 顏色與形狀分離：底是純白貼圖直接染色（染色是乘法，圖集素材不是純白、
    -- 直接染會比職業色文字暗一階），勾形用圖集的 alpha 當遮罩摳出來。
    -- 描邊＝黑色同形往四個斜角各偏 1px 墊在下層（FontString OUTLINE 的
    -- 土法煉鋼版——貼圖沒有內建描邊）。只墊斜角不墊正向：勾的筆畫是斜的，
    -- 斜角剛好貼著筆畫包；八方向全墊的話軟邊疊加會讓描邊看起來有 2px 粗。
    -- 勾用材質不用字元：中文字型沒有 ✓。
    local atlasInfo = C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo("checkmark-minimal")
    local checkLayers = {}

    if atlasInfo then
        local h = 24
        local w = (atlasInfo.height and atlasInfo.height > 0)
            and h * (atlasInfo.width / atlasInfo.height) or h
        -- 描邊偏移用半像素：P.Scale(0.5) 會被像素對齊進位掉，
        -- 所以取 1px 的實體尺寸自己乘——半像素靠 GPU 混色，出來是髮絲線
        local px = P.Scale(1)
        local function CheckLayer(r, g, b, dx, dy, sub)
            local t = cb:CreateTexture(nil, "OVERLAY", nil, sub)
            t:SetTexture(WHITE)
            t:SetVertexColor(r, g, b)
            P.Size(t, w, h)
            t:SetPoint("CENTER", px * dx, px * dy)
            local m = cb:CreateMaskTexture()
            m:SetAtlas("checkmark-minimal")
            m:SetAllPoints(t)
            t:AddMaskTexture(m)
            t:Hide()
            checkLayers[#checkLayers + 1] = t
            return t
        end
        for _, o in ipairs({ {0.5, 0.5}, {0.5, -0.5}, {-0.5, 0.5}, {-0.5, -0.5} }) do
            CheckLayer(0, 0, 0, o[1], o[2], 1)
        end
        local ar, ag, ab = W.Accent()
        CheckLayer(ar, ag, ab, 0, 0, 2)
    else
        -- 舊素材自帶暗影，描邊夠用
        local t = cb:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        t:SetDesaturated(true)
        t:SetVertexColor(W.Accent(1))
        P.Size(t, 26, 26)
        t:SetPoint("CENTER", 0, 0)
        t:Hide()
        checkLayers[1] = t
    end

    -- 多層貼圖要一起顯隱，SetCheckedTexture 只管得了一張——
    -- 自己包 SetChecked、OnClick 也跟著同步（refreshers 走 SetChecked、玩家走點擊）
    local function UpdateVisual(self)
        local on = self:GetChecked() and true or false
        for _, t in ipairs(checkLayers) do t:SetShown(on) end
    end
    local rawSetChecked = cb.SetChecked
    function cb:SetChecked(v)
        rawSetChecked(self, v)
        UpdateVisual(self)
    end

    cb:SetScript("OnClick", function(self)
        UpdateVisual(self)
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
    W.Stylize(slider, WIDGET_FILL)

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
            eb:SetText(eb.value or 0)       -- 打了不是數字的東西：還原
            eb:SetCursorPosition(0)
            return
        end
        -- 沒變就不重複套用：Enter 之後緊接著失焦會再進來一次，而 onCommit 是
        -- 「整個單位重套設定」等級的工作
        if v == eb.value then
            eb:SetText(v); eb:SetCursorPosition(0); return
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
        Commit(self:GetText())       -- 先提交再放掉焦點（失焦那條也會提交，Commit 會去重）
        self:ClearFocus()
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
        -- ⚠ 失焦＝提交，不是還原。
        -- 一度寫成「還原成實際值，刻意不提交，免得不小心點掉變成套用」——
        -- 那個顧慮站不住腳：在數字框裡打字，意圖是明確的。實際體驗是
        -- 「打完數字點別處 → 值跳回去 → 等於改不了」。
        Commit(self:GetText())
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
    W.Stylize(eb, WIDGET_FILL)
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
    W.Stylize(holder, WIDGET_FILL)

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

    -- ⚠ 多行 EditBox 當 scroll child，高度是**跟著內容長**的：框是空的時候它只有
    -- 一行高，可點擊範圍就只有最上面那一條。點框中間點到的是 ScrollFrame，
    -- EditBox 拿不到焦點 ⇒ Ctrl+V 貼不進去（匯入框空的時候必中）。
    -- 讓整個外框吃滑鼠、把焦點導給 EditBox；順便給個焦點外框，貼之前看得出來有中。
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() eb:SetFocus() end)
    eb:SetScript("OnEditFocusGained", function() holder:SetBackdropBorderColor(W.Accent(1)) end)
    eb:SetScript("OnEditFocusLost", function() holder:SetBackdropBorderColor(0, 0, 0, 1) end)

    holder.editBox = eb
    holder.scroll = scroll
    return holder
end

------------------------------------------------------------
-- 下拉選單（共用選單框）
------------------------------------------------------------
local ITEM_H = 18
local MENU_MAX_ROWS = 14      -- 超過就裁切＋滾輪捲動（字型清單裝了幾個插件就會破百）

-- 下拉的靜置框線：深灰、比控件底色亮一階（跟勾選框底色同值），
-- 職業色只留給 hover 與「展開中」——常駐染色會讓整頁表單太吵
local DD_BORDER = { 0.22, 0.22, 0.22, 1 }

local menuFrame
local function EnsureMenu()
    if menuFrame then return menuFrame end
    menuFrame = CreateFrame("Frame", NS .. "_DropdownMenu", UIParent, "BackdropTemplate")
    menuFrame:SetFrameStrata("TOOLTIP")
    W.Stylize(menuFrame, { 0.1, 0.1, 0.1, 0.97 })
    menuFrame:SetBackdropBorderColor(W.Accent(0.8))   -- 跟下拉本體同一套職業色框
    menuFrame:Hide()
    menuFrame.items = {}
    menuFrame.offset = 0
    -- 內容比視窗高時靠裁切＋位移捲動（不用 ScrollFrame：項目是共用池，
    -- 換 scroll child 的父層會把池子搞複雜，位移錨點單純得多）
    menuFrame:SetClipsChildren(true)
    menuFrame:EnableMouseWheel(true)
    menuFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = (self.contentH or 0) - (self.viewH or 0)
        if maxOffset <= 0 then return end
        local o = self.offset - delta * ITEM_H * 3
        if o < 0 then o = 0 elseif o > maxOffset then o = maxOffset end
        if o == self.offset then return end
        self.offset = o
        if self.Reflow then self:Reflow() end
    end)
    menuFrame:SetScript("OnHide", function(self)
        self:Hide()
        -- 選單收起：owner 的「展開中」職業色框退回深灰（還壓著滑鼠的話
        -- 讓 hover 狀態繼續，之後 OnLeave 會收尾）
        local owner = self.owner
        if owner and owner.SetBackdropBorderColor and not owner:IsMouseOver() then
            owner:SetBackdropBorderColor(unpack(DD_BORDER))
        end
    end)
    return menuFrame
end

function W.CloseDropdowns()
    if menuFrame then menuFrame:Hide() end
end

function W.CreateDropdown(parent, width, items, onSelect)
    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(dd, width or 120, 20)
    W.Stylize(dd, WIDGET_FILL)
    -- 框線平常深灰，hover 與展開中染職業色；展開中滑鼠移開不退色，
    -- 選單收起（OnHide）或換別的下拉當 owner 時才還原
    dd:SetBackdropBorderColor(unpack(DD_BORDER))
    dd:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(W.Accent(1))
    end)
    dd:SetScript("OnLeave", function(self)
        if not (menuFrame and menuFrame:IsShown() and menuFrame.owner == self) then
            self:SetBackdropBorderColor(unpack(DD_BORDER))
        end
    end)

    dd.text = dd:CreateFontString(nil, "OVERLAY")
    dd.text:SetFontObject(fontNormal)
    dd.text:SetPoint("LEFT", 5, 0)
    dd.text:SetPoint("RIGHT", -16, 0)
    dd.text:SetJustifyH("LEFT")
    dd.text:SetWordWrap(false)

    -- 箭頭用貼圖不用字元：中文字型（blei00d）沒有 ▾ 這類符號，會畫成方框。
    -- 素材本身是金色，去色後染職業色，才不會是整個主題裡唯一不合群的顏色
    local arrow = dd:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetRotation(math.rad(-90))
    P.Size(arrow, 12, 12)
    arrow:SetPoint("RIGHT", -3, 0)
    arrow:SetDesaturated(true)
    arrow:SetVertexColor(W.Accent(1))

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
        -- 換 owner 不會經過 OnHide：舊 owner 的展開色在這裡還原
        if menu.owner and menu.owner ~= self and menu.owner.SetBackdropBorderColor then
            menu.owner:SetBackdropBorderColor(unpack(DD_BORDER))
        end
        menu.owner = self
        menu.offset = 0
        -- 重建項目按鈕
        for _, b in ipairs(menu.items) do b:Hide() end
        local height, widest = 2, 0
        local count = #self.items
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
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -height)
            b.text:SetText(item.text)
            -- 量實際字寬：項目可能比下拉本身長（角色名＋伺服器＋註記），
            -- 不撐開的話字會溢出選單邊界
            local tw = b.text:GetStringWidth() or 0
            if tw > widest then widest = tw end
            b:SetScript("OnClick", function()
                self:SetSelectedValue(item.value)
                menu:Hide()
                if onSelect then onSelect(item.value) end
                if item.onClick then item.onClick(item.value) end
            end)
            b:Show()
            height = height + ITEM_H
        end
        -- 選單至少跟下拉一樣寬，內容更長就跟著撐開（5 左內縮 ＋ 右邊留白）
        local menuW = math.max(self:GetWidth() or 120, widest + 18)
        for i = 1, count do
            local b = menu.items[i]
            if b then P.Size(b, menuW - 4, ITEM_H) end
        end

        -- 高度上限：超過就裁切，靠滾輪捲。沒超過的話 Reflow 是 no-op
        menu.contentH = height + 2
        menu.viewH = math.min(menu.contentH, MENU_MAX_ROWS * ITEM_H + 4)
        function menu:Reflow()
            for i = 1, count do
                local b = self.items[i]
                if b then
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -(2 + (i - 1) * ITEM_H) + self.offset)
                end
            end
        end
        menu:Reflow()

        -- 下面塞不下就往上開。有了高度上限才算得出來要不要翻——沒有上限的話
        -- 長清單無論往哪開都會有一截在畫面外，而裁切之後那一截是**捲不到**的。
        -- （回讀的是設定面板自己的幾何，跟單位框那條「絕不回讀」的規則無關）
        menu:ClearAllPoints()
        local roomBelow = self:GetBottom()
        if roomBelow and roomBelow - menu.viewH - 2 < 0 then
            menu:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
        else
            menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        end
        P.Size(menu, menuW, menu.viewH)
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
    mask.text:SetText(text or L["Can't change settings during combat"])

    mask:Hide()
    parent.combatMask = mask
    return mask
end

------------------------------------------------------------
-- 確認彈窗
------------------------------------------------------------
-- 確認彈窗：蓋在整個 parent 上方（獨立 strata，不受分頁/卷軸子層級影響），
-- 背後一層半透明遮罩擋掉點擊
-- 多選項彈窗：choices = { { text=, onClick= }, ... }，按鈕橫排、寬度平分。
-- 跟 CreateConfirmPopup 同一套遮罩／層級，差別只在按鈕數量。
-- 用途：問「這份新設定檔要拿什麼當底」這種沒有「是／否」語意的分岔。
function W.CreateChoicePopup(parent, width, text, choices)
    width = width or 320
    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = WHITE })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    local popup = W.CreateFrame(nil, parent, width, 96)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup.mask = mask
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function() mask:Hide() end)

    local fs = popup:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(fontNormal)
    fs:SetPoint("TOP", 0, -12)
    fs:SetWidth(width - 24)
    fs:SetJustifyH("CENTER")
    fs:SetText(text)
    popup.text = fs

    local n = #choices
    local gap, edge = 6, 12
    local bw = math.floor((width - edge * 2 - gap * (n - 1)) / n)
    for i, c in ipairs(choices) do
        local b = W.CreateButton(popup, c.text, c.color or "accent", bw, 22)
        b:SetPoint("BOTTOMLEFT", edge + (i - 1) * (bw + gap), 12)
        b:SetScript("OnClick", function()
            popup:Hide()
            if c.onClick then c.onClick() end
        end)
    end
    return popup
end

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
    -- 開出來：有些確認訊息要看當下狀況才決定怎麼寫（例如換設定檔要不要重載），
    -- 而彈窗是建一次就重用的，不能把文字烘死在建立那一刻
    popup.text = fs

    local yes = W.CreateButton(popup, L["Okay"], "green", 80, 22)
    yes:SetPoint("BOTTOMLEFT", 26, 12)
    yes:SetScript("OnClick", function()
        popup:Hide()
        if onAccept then onAccept() end
    end)
    local no = W.CreateButton(popup, L["Cancel"], "red", 80, 22)
    no:SetPoint("BOTTOMRIGHT", -26, 12)
    no:SetScript("OnClick", function() popup:Hide() end)

    -- ⚠ 一定要關掉再回傳：CreateFrame 建出來預設是**顯示**的。
    -- 兩個實際踩到的後果：
    --   1. 「建好但先不開」的用法（在分頁 Init 就先建好、按鈕按下去才 Show）
    --      會讓確認視窗一進分頁就自己跳出來。
    --   2. 就算是「建完馬上 Show」的用法也壞：對一個已經顯示的框呼叫 Show()
    --      **不會觸發 OnShow**，所以第一次按下去時背後那層遮罩不會出現。
    popup:Hide()
    return popup
end

------------------------------------------------------------
-- 唯讀複製框
--
-- 內容是程式產生的（巨集內文、指令字串），玩家改了沒有意義，但又必須能整段選起來
-- Ctrl+C。所以不是 SetEnabled(false) —— 停用的輸入框連選取都做不到；改成「一被
-- 輸入就還原」，看得到、選得到、改不掉。
--   getText()    → 目前該顯示的文字（每次 Refresh 重新問一次，內容會變的照樣對）
--   selectLabel  選填。給了才長「全選」按鈕，字串由宿主在地化（共用層不吃這個 key）
-- 回傳 holder：holder.editBox / holder.button / holder.totalHeight / holder:Refresh()
------------------------------------------------------------
function W.CreateCopyBox(parent, width, height, getText, selectLabel)
    width, height = width or 300, height or 44
    local box = W.CreateScrollEditBox(parent, width, height)
    local eb = box.editBox

    -- 複製框的內容是宿主產生的、高度也由宿主配好，捲軸永遠用不到——
    -- 留著只會剩一顆神祕的箭頭飾件掛在右上角，還吃掉 22px 寬度。
    -- 藏掉（OnShow 再壓一次：範圍更新可能把它叫回來），寬度還給文字。
    local bar = box.scroll.ScrollBar
    if bar then
        bar:Hide()
        bar:HookScript("OnShow", function(s) s:Hide() end)
    end
    box.scroll:SetPoint("BOTTOMRIGHT", -4, 4)
    eb:SetWidth(width - 12)

    function box:Refresh()
        eb:SetText((getText and getText()) or "")
        eb:SetCursorPosition(0)
    end
    box:Refresh()

    -- userInput 才還原：程式自己 SetText 也會觸發這個事件，不分辨的話會無限遞迴
    eb:SetScript("OnTextChanged", function(_, userInput)
        if userInput then box:Refresh() end
    end)

    box.totalHeight = height
    if selectLabel then
        local btn = W.CreateButton(parent, selectLabel, "normal", 80, 22)
        btn:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
        btn:SetScript("OnClick", function()
            box:Refresh()
            eb:SetFocus()
            eb:HighlightText()
        end)
        box.button = btn
        box.totalHeight = height + 28
    end
    return box
end

------------------------------------------------------------
-- 可捲動的列表（列走池子重複利用）
--
-- 給「一列一筆資料」的清單：藥水清單、曲目清單、頻道開關…。捲軸、列高、內容高度
-- 都由這裡管，宿主只負責裝飾一列（buildRow）與填一列（updateRow）。
--   buildRow(row, list)            新建一列時呼叫一次，在 row 上建控件
--   list:Update(items, updateRow)  updateRow(row, item, index)，每次刷新都跑
--
-- ⚠ 列是回收再用的：updateRow 必須把每一格都重設，**包含 OnClick 的 closure**。
--   少設一格的症狀是顯示上一筆的殘留值，而且只在筆數變動後才看得出來。
------------------------------------------------------------
function W.CreateRowList(parent, width, height, rowHeight, buildRow)
    local holder = CreateFrame("Frame", nil, parent)
    P.Size(holder, width or 300, height or 200)

    local scroll = W.CreateScrollFrame(holder)
    local rows = {}
    holder.scroll, holder.rows = scroll, rows

    -- 列高先量成實體像素，位移也用同一個值累加。兩邊單位不一致的話，列與列之間
    -- 會依螢幕縮放露出縫或互相疊到。
    local rh = P.Scale(rowHeight or 24)

    function holder:Update(items, updateRow)
        local y = 0
        for i, item in ipairs(items) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, scroll.child)
                row:SetHeight(rh)
                -- 斑馬紋：一列只有一行字，沒有底色的話捲到第 20 列就對不到自己那行
                row.stripe = row:CreateTexture(nil, "BACKGROUND")
                row.stripe:SetAllPoints()
                row.stripe:SetTexture(WHITE)
                row.stripe:SetVertexColor(1, 1, 1, 0.03)
                rows[i] = row
                if buildRow then buildRow(row, holder) end
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -y)
            row.stripe:SetShown(i % 2 == 0)
            row:Show()
            if updateRow then updateRow(row, item, i) end
            y = y + rh
        end
        for i = #items + 1, #rows do rows[i]:Hide() end
        scroll:SetContentHeight(y)
    end

    return holder
end

------------------------------------------------------------
-- 輸入彈窗：一到多個單行欄位 ＋ 確定／取消
--
-- 「新增一筆」「改名」這種要先問字串才能動作的對話框。跟確認彈窗同一套遮罩與層級，
-- 差別只在中間多了輸入欄。
--   fields = { { key = , label = , hint = , maxLetters = }, ... }
--   popup:Open(values, onAccept, title)
--       values           { [key] = 初值 }，nil 就是空的
--       onAccept(values) 回傳 false ＝ 內容不合法，彈窗不關（讓玩家改）
--       title            選填，同一個彈窗要當「新增／編輯」兩用時覆蓋標題
-- 欄位物件開在 popup.boxes[key]，宿主要塞值進去（例如 Shift+點擊帶入）從那裡拿。
------------------------------------------------------------
function W.CreateInputPopup(parent, width, title, fields)
    width = width or 360

    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = WHITE })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    local popup = W.CreateFrame(nil, parent, width, 100)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup.mask = mask
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function() mask:Hide() end)
    popup:Hide()

    local titleFS = popup:CreateFontString(nil, "OVERLAY")
    titleFS:SetFontObject(fontTitle)
    titleFS:SetPoint("TOP", 0, -12)
    titleFS:SetWidth(width - 24)
    titleFS:SetJustifyH("CENTER")
    titleFS:SetText(title or "")
    popup.title = titleFS

    local function Accept()
        local out = {}
        for _, f in ipairs(fields) do
            out[f.key] = strtrim(popup.boxes[f.key]:GetText() or "")
        end
        if popup._onAccept and popup._onAccept(out) == false then return end
        popup:Hide()
    end

    popup.boxes = {}
    local order = {}
    local y = -36
    for i, f in ipairs(fields) do
        local lb = popup:CreateFontString(nil, "OVERLAY")
        lb:SetFontObject(fontSmall)
        lb:SetPoint("TOPLEFT", 14, y)
        lb:SetText(f.label or "")
        y = y - 16

        local eb = W.CreateEditBox(popup, width - 28, 20)
        eb:SetPoint("TOPLEFT", 14, y)
        if f.maxLetters then eb:SetMaxLetters(f.maxLetters) end
        popup.boxes[f.key] = eb
        order[i] = eb
        y = y - 26

        if f.hint then
            local hint = popup:CreateFontString(nil, "OVERLAY")
            hint:SetFontObject(fontSmall)
            hint:SetTextColor(1, 0.82, 0)
            hint:SetPoint("TOPLEFT", 14, y)
            hint:SetWidth(width - 28)
            hint:SetJustifyH("LEFT")
            hint:SetSpacing(2)
            hint:SetText(f.hint)
            -- 下限一行：GetStringHeight 在版面還沒解算時可能回 0，沒有下限的話
            -- 彈窗會算得太矮，說明文字直接壓在按鈕上
            y = y - (math.max(hint:GetStringHeight(), 14) + 10)
        end
    end

    for i, eb in ipairs(order) do
        local nextBox = order[i + 1]
        eb:SetScript("OnTabPressed", function() (nextBox or order[1]):SetFocus() end)
        eb:SetScript("OnEnterPressed", function()
            if nextBox then nextBox:SetFocus() else Accept() end
        end)
        -- HookScript：CreateEditBox 自己的 OnEscapePressed 負責 ClearFocus，
        -- SetScript 會蓋掉它，焦點就卡在關掉的彈窗上（下一次打字全被吃掉）
        eb:HookScript("OnEscapePressed", function() popup:Hide() end)
    end

    local ok = W.CreateButton(popup, L["Okay"], "green", 80, 22)
    ok:SetPoint("BOTTOMLEFT", 26, 12)
    ok:SetScript("OnClick", Accept)
    local cancel = W.CreateButton(popup, L["Cancel"], "red", 80, 22)
    cancel:SetPoint("BOTTOMRIGHT", -26, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)

    P.Height(popup, -y + 12 + 22 + 12)

    function popup:Open(values, onAccept, newTitle)
        if newTitle then titleFS:SetText(newTitle) end
        for _, f in ipairs(fields) do
            local eb = popup.boxes[f.key]
            eb:SetText(tostring((values and values[f.key]) or ""))
            eb:SetCursorPosition(0)
        end
        popup._onAccept = onAccept
        popup:Show()
        -- 刻意不 Raise：層級固定在 410（遮罩 400 之上、戰鬥遮罩 500 之下），
        -- Raise 會把它抬到 strata 頂端，戰鬥中就變成浮在戰鬥遮罩上面還能按
        if order[1] then order[1]:SetFocus() end
    end

    return popup
end
