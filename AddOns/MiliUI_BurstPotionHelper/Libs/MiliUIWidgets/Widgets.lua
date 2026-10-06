------------------------------------------------------------
-- 設定介面元件庫（白貼圖 backdrop + 1px 硬邊 + 職業 accent 色）
-- 全部自寫，不依賴任何外部 UI 函式庫（避免 scale / 字型互相干擾）
--
-- ⚠ 共用層：這支可以逐字複製到其他 MiliUI 插件，宿主專屬的東西一律走
--   ns.WidgetsEnv（見 Libs/MiliUIWidgets/Env.lua）。改這裡時不要引進新的 ns.* 依賴。
------------------------------------------------------------
local ADDON, ns = ...

local Env = ns.WidgetsEnv
local L, P = Env.L, Env.P
local NS = Env.NAMESPACE

ns.W = {}
local W = ns.W

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
-- 共用層唯一的資產檔（勾選框的勾）。路徑跟著宿主的資料夾名走，
-- 所以這包一定要放在 <插件>\Libs\MiliUIWidgets\ —— README 的搬家步驟本來就是這樣。
local CHECK_TEX = "Interface\\AddOns\\" .. ADDON .. "\\Libs\\MiliUIWidgets\\Media\\check-outline.tga"

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

-- 強調說明字（「黃字說明」）：適用範圍、注意事項這種要玩家先看到的說明。字級跟 fontSmall 一樣，只換顏色。
-- 全套組通用（使用者 2026-10-03 指定：說「黃字說明」就是這個顏色）；色值另外放 W.EMPHASIS_COLOR，
-- 給沒有走字型物件的地方（|c 色碼、SetTextColor）用同一個值。
W.EMPHASIS_COLOR = { r = 1, g = 0.82, b = 0 }
local fontEmphasis = CreateFont(NS .. "_FontEmphasis")
fontEmphasis:SetFont(Env.Font(), 11, "")
fontEmphasis:SetTextColor(W.EMPHASIS_COLOR.r, W.EMPHASIS_COLOR.g, W.EMPHASIS_COLOR.b)
fontEmphasis:SetShadowColor(0, 0, 0)
fontEmphasis:SetShadowOffset(1, -1)

W.fontNormal, W.fontTitle, W.fontDisabled, W.fontSmall, W.fontEmphasis =
    fontNormal, fontTitle, fontDisabled, fontSmall, fontEmphasis

------------------------------------------------------------
-- 文字量測
------------------------------------------------------------

-- 一段文字換行之後「多出來」的高度（沒換行回 0）。呼叫端拿它去墊列高。
--
-- 一行有多高得當場量：字型與字級是宿主給的（Env.Font），寫死一個數字的話，只要某個
-- 宿主的字型度量差一點，單行的列就會算出 +1，整頁版面跟著變鬆。
-- 只有真的換了行（高度超過一行半）才算數，不然度量的零頭會把每一列都撐高 1px。
-- 版面還沒解析時 GetStringHeight() 回 0 —— 這時回 0＝維持舊行為，不會炸。
--
-- ⚠ 會把 fs 的文字設成 text（量的時候借用同一個 FontString），呼叫端不必再 SetText。
function W.TextExtraHeight(fs, text)
    fs:SetText("A")
    local lineH = fs:GetStringHeight()
    fs:SetText(text or "")
    local total = fs:GetStringHeight()
    if lineH > 0 and total > lineH * 1.5 then
        return math.ceil(total - lineH)
    end
    return 0
end

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
--
-- 配色表的形狀：`{ 平時底, 滑過底 [, 平時邊, 滑過邊] }`。
-- 只有兩格的邊一律黑、停用時維持平時的底（原本的行為）；
-- 有第 3、4 格的（primary）滑過連邊一起換、停用退回中性 —— 停用的按鈕不能看起來像能按。
--
-- ⚠ 要用哪一種，規則在 `.claude/notes/project-miliui-button-variants.md`（全套組共用）：
--   「確認／執行」那一顆 primary，其餘 normal；一個區塊最多一顆 primary。
------------------------------------------------------------

-- primary：跟 MiliUI_Skin 的主按鈕**同一條公式**（MiliUI_Skin/Core/Tokens.lua 的
-- 「按鈕的兩種變體」），套組自己的視窗跟換過皮的暴雪視窗才會是同一顆按鈕。
-- 數字寫死在兩邊、不去讀對方 —— 插件是單體發佈的。**要改就兩邊一起改。**
--
--   平時 底＝保護色 × 0.30、邊＝職業色 × 0.60
--   滑過 底＝保護色、        邊＝職業色
--   保護色＝職業色 × k，k = min(1, 0.40 / 亮度)：白字壓在牧師白、盜賊黃上讀不到，
--   依亮度壓暗；深色職業（死騎、薩滿、惡魔獵人）k = 1、不變。0.40 的由來見 MiliUI_Skin/STYLE.md ②。
-- 職業色不是秘密值（Env.Accent 早就查完表了），這裡是純算術。
local BTN_TEXT_LUM, BTN_IDLE_SCALE, BTN_BORDER_SCALE = 0.40, 0.30, 0.60
local function PrimaryColors()
    local r, g, b = accent.r, accent.g, accent.b
    local lum = 0.299 * r + 0.587 * g + 0.114 * b
    local k = lum > 0 and math.min(1, BTN_TEXT_LUM / lum) or 1
    local i, e = k * BTN_IDLE_SCALE, BTN_BORDER_SCALE
    return {
        { r * i, g * i, b * i, 1 },
        { r * k, g * k, b * k, 1 },
        { r * e, g * e, b * e, 1 },
        { r, g, b, 1 },
    }
end

local BTN_COLORS = {
    normal      = { WIDGET_FILL,  { 0.23, 0.23, 0.23, 1 } },
    primary     = PrimaryColors(),
    accent      = { { accent.r, accent.g, accent.b, 0.3 }, { accent.r, accent.g, accent.b, 0.6 } },
    ["accent-hover"] = { WIDGET_FILL, { accent.r, accent.g, accent.b, 0.6 } },
    red         = { { 0.6, 0.1, 0.1, 0.6 }, { 0.6, 0.1, 0.1, 1 } },
    green       = { { 0.1, 0.6, 0.1, 0.6 }, { 0.1, 0.6, 0.1, 1 } },
}

-- 依目前狀態重畫一顆 W.CreateButton 的底與邊。
--
-- ⚠ 自己 SetScript("OnEnter"/"OnLeave") 的呼叫端（掛提示、列高亮）一律叫這支，
--   不要自己 `unpack(self._colors[2])` —— 那只換得到底，primary 的邊會卡在上一個狀態。
function W.PaintButton(b, hover)
    local c = b._colors
    if not c then return end
    local enabled = b:IsEnabled()
    if not c[3] then
        -- 只有底色的配色：停用時滑過不反白、離開照樣回平時的底（跟原本一模一樣）
        if not hover then
            b:SetBackdropColor(unpack(c[1]))
        elseif enabled then
            b:SetBackdropColor(unpack(c[2]))
        end
        return
    end
    if not enabled then
        b:SetBackdropColor(unpack(WIDGET_FILL))
        b:SetBackdropBorderColor(0, 0, 0, 1)
    elseif hover then
        b:SetBackdropColor(unpack(c[2]))
        b:SetBackdropBorderColor(unpack(c[4]))
    else
        b:SetBackdropColor(unpack(c[1]))
        b:SetBackdropBorderColor(unpack(c[3]))
    end
end

-- 換一顆 W.CreateButton 的配色（"normal"｜"primary"…）並照目前狀態重畫。
-- 給「按鈕本身表達開關狀態」的呼叫端用（例如預覽列：設定有啟用的那幾顆用 primary）；按鈕照樣能按
function W.SetButtonVariant(b, colorKey)
    local colors = BTN_COLORS[colorKey or "normal"] or BTN_COLORS.normal
    if b._colors == colors then return end
    b._colors = colors
    if not colors[3] then b:SetBackdropBorderColor(0, 0, 0, 1) end
    W.PaintButton(b, b:IsMouseOver())
end

function W.CreateButton(parent, text, colorKey, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(b, width or 60, height or 20)
    local colors = BTN_COLORS[colorKey or "normal"] or BTN_COLORS.normal
    b._colors = colors
    W.Stylize(b, colors[1], colors[3])

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
    --
    -- 有邊色的配色（primary）連底與邊一起換：停用中的按鈕預設收不到 OnEnter/OnLeave，
    -- 滑過時被停用、移開、再啟用，只靠滑鼠腳本的話會卡在滑過的顏色上。
    local function Recolor(self)
        if self:IsEnabled() then
            fs:SetTextColor(1, 1, 1)
        else
            fs:SetTextColor(0.4, 0.4, 0.4)
        end
        if self._colors and self._colors[3] then
            W.PaintButton(self, self:IsVisible() and self:IsMouseOver())
        end
    end
    local rawSetEnabled, rawEnable, rawDisable = b.SetEnabled, b.Enable, b.Disable
    function b:SetEnabled(on) rawSetEnabled(self, on); Recolor(self) end
    function b:Enable()       rawEnable(self);         Recolor(self) end
    function b:Disable()      rawDisable(self);        Recolor(self) end

    b:SetScript("OnEnter", function(self) W.PaintButton(self, true) end)
    b:SetScript("OnLeave", function(self) W.PaintButton(self, false) end)
    return b
end

-- 按鈕字左右各留一半。撐寬時用它，一排按鈕的內距才會一致
W.BTN_TEXT_PAD = 20

-- 字太長就把按鈕撐開（opt-in）。
--
-- 按鈕的字只錨 CENTER、不換行、也不截 —— 太長就直接溢出邊框，歐語譯文常常這樣。
-- 但**預設不能撐**：呼叫端的版面有一半是絕對座標排的，撐寬會把「字溢出」換成
-- 「蓋到隔壁控件」，連點擊區一起蓋，那更糟。所以由知道右邊還有沒有空間的人自己叫。
--
-- 放得下就一個位元都不動（尺寸、錨點、熱區全部維持原樣），一排按鈕才不會只有一顆特別寬。
-- 回傳實際寬度，讓呼叫端接著排右邊的東西。
--
-- 可以重複呼叫：之後才 SetText 的（讀數型的按鈕）換完字再叫一次就好。
-- 刻意不去 hook SetText —— 那會讓每次刷新讀數都偷偷改版面，而按鈕多半排在一列裡。
function W.FitButton(b, minW, height)
    minW = minW or b.width or b:GetWidth() or 0
    local fs = b:GetFontString()
    if not fs then return minW end
    local need = math.ceil(fs:GetStringWidth() or 0) + W.BTN_TEXT_PAD
    if need <= minW then return minW end
    P.Size(b, need, height or b.height or b:GetHeight())
    return need
end

-- 字太長就讓按鈕的字換行、按鈕往下長高（opt-in）。
--
-- 這是 FitButton 的另一半：**右邊沒有空間可以撐寬**的時候（固定寬的直排清單，右邊
-- 緊接著分隔線與表單），只剩「往下長」這條路可走。呼叫端拿回傳的高度去排下一顆。
--
-- 放得下就一個位元都不動 —— 判準是「自然寬 ≤ width」，貼著邊框但還沒溢出的那幾顆
-- （中韓的譯名多半是這樣）不會因為多了這支而變成兩行。內距只有換行時才留：
-- 拿來當判準的話那幾顆會當場多一行，等於偷偷改了中韓的版面。
--
-- ⚠ 一定要**先量自然寬再 SetWidth**：夾住之後 GetStringWidth() 量到的是夾過的寬度。
--   CreateButton 的字刻意不夾寬（見上面的註解），就是為了讓呼叫端量得準。
--   所以每次都先把上一輪的夾寬**拆掉**再量 —— 這也讓它可以重複呼叫（換了字、換了
--   字型、或第一次是在還沒顯示的框上量的，再叫一次就好，結果不會累加）。
--   ⚠ 重複呼叫時 width／minH 要傳跟第一次**一樣的值**：省略參數會去讀 b.width /
--   b.height，而那已經是上一輪換行後的高度了。
W.BTN_WRAP_PAD = 8      -- 換行時文字左右各留一半

function W.WrapButton(b, width, minH, pad)
    width = width or b.width or b:GetWidth() or 0
    minH = minH or b.height or b:GetHeight() or 0
    local fs = b:GetFontString()
    if not fs or width <= 0 then return minH end
    local text = b:GetText()
    if not text or text == "" then return minH end

    -- 退回 CreateButton 的原始狀態再量。SetWidth(0) 是 FontString 的「取消定寬」
    -- 寫法（不是把它縮成 0 寬）
    fs:SetWidth(0)
    fs:SetWordWrap(false)
    local textW = fs:GetStringWidth() or 0
    if textW <= 0 or math.ceil(textW) <= width then
        P.Size(b, width, minH)
        return minH
    end

    fs:SetWidth(width - (pad or W.BTN_WRAP_PAD))
    fs:SetWordWrap(true)
    fs:SetNonSpaceWrap(true)        -- 沒有空白可斷的複合字寧可斷在字中，也不要橫著溢出
    fs:SetJustifyH("CENTER")
    local extra = W.TextExtraHeight(fs, text)
    if extra <= 0 then
        -- 量不到高度（版面還沒解析，GetStringHeight() 回 0）⇒ 整個收手退回原樣。
        -- 「換了行卻沒長高」比字溢出更糟：第二行會畫到下一顆按鈕身上，而那一顆
        -- 還在原來的位置（呼叫端拿到的是 minH）。
        fs:SetWidth(0)
        fs:SetWordWrap(false)
        P.Size(b, width, minH)
        return minH
    end
    P.Size(b, width, minH + extra)
    return minH + extra
end

------------------------------------------------------------
-- 一排按鈕的換排排版（opt-in）
--
-- 一排 chip 用「第一顆錨 parent 的 TOPLEFT、其餘一路 LEFT→RIGHT 串接」排成一行是
-- 最省事的寫法，但那排字是會被翻譯的：中文剛好卡邊的一排，俄文展開有兩倍半寬，
-- 直接衝出視窗右緣（而且溢出去的那截點得到、看不到）。
--
-- 這兩支只排版、不建立東西，而且**單排時的錨點與原本的串接寫法逐位元相同** ——
-- 放得下的語系一個像素都不會變。
------------------------------------------------------------

-- place(b, rowIndex, prevInRow) 給 nil 就只數排數（不動版面）
local function FlowWalk(buttons, maxW, gapX, place, includeHidden)
    -- 量不到可用寬就當成無限寬＝維持單排的舊行為。退成「每顆一排」的話，
    -- 版面解析前跑一次就會把整排炸開成十一排。
    if type(maxW) ~= "number" or maxW <= 0 then maxW = math.huge end
    local rows, x, prev = 1, 0, nil
    for _, b in ipairs(buttons) do
        if includeHidden or b:IsShown() then
            local w = b:GetWidth() or 0
            if prev and x + gapX + w > maxW then
                rows, x, prev = rows + 1, 0, nil
            end
            if place then place(b, rows, prev) end
            x = prev and (x + gapX + w) or w
            prev = b
        end
    end
    return rows
end

-- 把**可見的**按鈕從左排到右，超過 maxW 就換到下一排。回傳排數與總高度。
function W.FlowLayout(parent, buttons, maxW, gapX, gapY, rowH)
    gapX, gapY, rowH = gapX or 0, gapY or 0, rowH or 0
    local rows = FlowWalk(buttons, maxW, gapX, function(b, row, prev)
        b:ClearAllPoints()
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", gapX, 0)
        else
            b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(row - 1) * (rowH + gapY))
        end
    end)
    return rows, rows * rowH + (rows - 1) * gapY
end

-- 只數排數、不動版面，而且**每一顆都算**（不管現在顯不顯示）。
-- 給「容器高度要一次留給最壞情況」的呼叫端用：清單內容會變的那種列，高度跟著內容
-- 跳的話，底下的東西每換一次就上下彈一次 —— 穩定比緊湊重要。
function W.FlowRows(buttons, maxW, gapX)
    return FlowWalk(buttons, maxW, gapX or 0, nil, true)
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
-- 分頁卡片：一排分頁鈕＋底下一張卡片（像資料夾的分頁）
--
-- 用在「頁面裡的一段有好幾種選擇」的子分頁：卡片包住那個分頁的全部列，
-- 一眼看得出分頁鈕管到哪裡為止。整頁的頂層分頁不需要（卡片會包住整頁，沒有資訊）。
--
--   卡片    底＝CARD_FILL（比面板 0.1 亮一階的不透明純色）、1px 邊＝職業色 × BTN_BORDER_SCALE
--           （primary 平時的邊，同一條公式）、直角
--   選中鈕  底＝卡片底、邊＝卡片邊、**底邊打通**（跟卡片連成一塊）；滑過不變（點了也不做事）
--   未選中  normal 按鈕原樣
--   狀態只換明暗：選中＝跟卡片一樣亮、閒置＝WIDGET_FILL、滑過＝normal 的滑過；色相只有職業色一個
--
-- ⚠ 卡片是畫在 **parent 上的貼圖**（BACKGROUND／BORDER 層），不是一個 frame：
--   子 frame 永遠蓋過父層貼圖，所以 parent 底下的列（控件、遮罩、右鍵接收框）不管 frame level
--   多少都在卡片上面，不用排層級。parent 自己的字（OVERLAY）也照樣在上面。
--   代價是 parent 上不能再有別的 BACKGROUND 貼圖蓋在同一塊（backdrop 的底在 -8 子層，不受影響）。
--
-- 座標一律是 parent 的 TOPLEFT 起算（y 往下是負的），跟 Controls.Build 回傳的 rows 同一套 ——
-- 表單排完之後直接拿 rows[i].bottom 當卡片的底。
--
-- 分頁鈕放不下就換排（同 W.FlowLayout 的規則）。換了排而選中的鈕不在最後一排時，
-- 它跟卡片之間隔著別排的鈕，打通不了 ⇒ 那一顆只換底與邊（卡片上緣整條畫滿）。
--
-- opts.help（字串，或回傳字串的函式）：最後一顆分頁鈕後面多一個「!」小方塊，滑過顯示這段說明
-- （講這幾個分頁各管什麼；字由呼叫端給，共用層不帶語系）。放不下就跟著換排。
------------------------------------------------------------
local CARD_FILL = { 0.15, 0.15, 0.15, 1 }
W.CARD_FILL = CARD_FILL
W.TAB_CARD_PAD = 4      -- 卡片內距的建議值（分頁鈕列底下到第一列、最後一列到卡片底）

function W.CreateTabCard(parent, opts)
    opts = opts or {}
    local tabH   = opts.tabHeight or 20
    local minW   = opts.tabMinWidth or 56
    local gapX   = opts.tabGap or 2
    local gapY   = opts.rowGap or 2
    local inset  = opts.inset or 6
    local border = BTN_COLORS.primary[3]
    local selColors = { CARD_FILL, CARD_FILL, border, border }

    local tc = { buttons = {}, byId = {} }
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(1, tabH)
    tc.strip = strip

    -- 說明「!」：跟分頁鈕同一列、緊接在最後一顆後面（LayoutTabs 排）
    local helpMark
    if opts.help then
        local m = CreateFrame("Frame", nil, strip, "BackdropTemplate")
        local sz = tabH - 4
        P.Size(m, sz, sz)
        W.Stylize(m, { 0.1, 0.1, 0.1, 0.9 }, { 0.4, 0.4, 0.4, 1 })
        local q = m:CreateFontString(nil, "OVERLAY")
        q:SetFontObject(W.fontSmall)
        q:SetPoint("CENTER", m, "CENTER", 0, 0)
        q:SetText("!")
        q:SetTextColor(0.6, 0.6, 0.6)
        m:EnableMouse(true)
        m:SetScript("OnEnter", function(self)
            q:SetTextColor(1, 1, 1)
            local text = opts.help
            if type(text) == "function" then text = text() end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tostring(text or ""), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function()
            q:SetTextColor(0.6, 0.6, 0.6)
            GameTooltip:Hide()
        end)
        helpMark = m
        tc.help = m
    end

    -- 卡片：底＋四邊（上緣分左右兩段，中間留給選中的那顆鈕）
    local function Tex(layer)
        local t = parent:CreateTexture(nil, layer, nil, 1)
        t:SetTexture(WHITE)
        t:Hide()
        return t
    end
    local bg = Tex("BACKGROUND")
    bg:SetVertexColor(unpack(CARD_FILL))
    local edges = {}
    for _, k in ipairs({ "left", "right", "bottom", "topL", "topR" }) do
        edges[k] = Tex("BORDER")
        edges[k]:SetVertexColor(unpack(border))
    end

    local placed, shown = false, true
    local cardX, cardW, cardTop, cardBottom = 0, 0, 0, nil
    local stripX, stripY, lastRow = 0, 0, 1
    local selected

    local function Bar(t, x, y, w, h)
        if w <= 0 or h <= 0 then t:Hide() return end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        t:SetSize(w, h)
        t:Show()
    end

    local function DrawCard()
        local on = shown and placed and cardBottom ~= nil and cardTop - cardBottom > 0
        if not on then
            bg:Hide()
            for _, t in pairs(edges) do t:Hide() end
            return
        end
        local px = P.Scale(1)
        local h = cardTop - cardBottom
        Bar(bg, cardX, cardTop, cardW, h)
        Bar(edges.left, cardX, cardTop, px, h)
        Bar(edges.right, cardX + cardW - px, cardTop, px, h)
        Bar(edges.bottom, cardX, cardBottom + px, cardW, px)
        -- 選中的鈕在最後一排 ⇒ 上緣在它底下斷開（左右各多蓋 1px，接住鈕的左右邊，轉角才是連著的）
        local b = selected
        if b and b:IsShown() and b._tcRow == lastRow then
            local bx = stripX + b._tcX
            Bar(edges.topL, cardX, cardTop, bx + px - cardX, px)
            local rx = bx + b:GetWidth() - px
            Bar(edges.topR, rx, cardTop, cardX + cardW - rx, px)
        else
            Bar(edges.topL, cardX, cardTop, cardW, px)
            edges.topR:Hide()
        end
    end

    local function Paint()
        for _, b in ipairs(tc.buttons) do
            local sel = b == selected
            if sel then
                b._colors = selColors
            else
                b._colors = BTN_COLORS.normal
                b:SetBackdropBorderColor(0, 0, 0, 1)
            end
            W.PaintButton(b, b:IsVisible() and b:IsMouseOver())
            b._tcBridge:SetShown(sel and b._tcRow == lastRow)
        end
        DrawCard()
    end

    -- 分頁鈕排版（自己走一次換排，順便記下每顆在第幾排、離列首多遠：卡片上緣要照它斷開）
    local function LayoutTabs()
        local maxW = strip:GetWidth()
        if type(maxW) ~= "number" or maxW <= 0 then maxW = math.huge end
        local row, x, prev = 1, 0, nil
        for _, b in ipairs(tc.buttons) do
            if b:IsShown() then
                local w = b:GetWidth() or 0
                if prev and x + gapX + w > maxW then row, x, prev = row + 1, 0, nil end
                if prev then x = x + gapX end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", strip, "TOPLEFT", x, -(row - 1) * (tabH + gapY))
                b._tcRow, b._tcX = row, x
                x = x + w
                prev = b
            end
        end
        lastRow = row
        if helpMark then
            local w = helpMark:GetWidth() or tabH
            local gap = gapX + 4
            if prev and x + gap + w > maxW then row, x, prev = row + 1, 0, nil; gap = 0 end
            helpMark:ClearAllPoints()
            helpMark:SetPoint("LEFT", strip, "TOPLEFT", x + (prev and gap or 0), -(row - 1) * (tabH + gapY) - tabH / 2)
        end
        local h = row * tabH + (row - 1) * gapY
        strip:SetHeight(h)
        return h
    end

    for i, d in ipairs(opts.tabs or {}) do
        local b = W.CreateButton(strip, d.label, "normal", minW, tabH)
        W.FitButton(b, minW, tabH)
        b.id = d.id
        -- 底邊打通：用卡片底蓋掉鈕的下邊框（左右邊框留著）。ARTWORK 層在 backdrop 的邊之上、字之下
        local bridge = b:CreateTexture(nil, "ARTWORK")
        bridge:SetTexture(WHITE)
        bridge:SetVertexColor(unpack(CARD_FILL))
        bridge:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", P.Scale(1), 0)
        bridge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -P.Scale(1), 0)
        bridge:SetHeight(P.Scale(1))
        bridge:Hide()
        b._tcBridge = bridge
        b:SetScript("OnClick", function(self)
            if self == selected then return end
            tc:Select(self.id)
            if opts.onSelect then opts.onSelect(self.id, self) end
        end)
        tc.buttons[i], tc.byId[d.id] = b, b
    end

    -- 分頁鈕列的左上角放在 parent 的 (x, y)，卡片的左右邊＝x～x + width（鈕列內縮 inset、放不下換排）。
    -- 回傳鈕列高；卡片上緣＝y − 鈕列高
    function tc:Place(x, y, width)
        cardX, cardW = x, width
        stripX, stripY = x + inset, y
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", parent, "TOPLEFT", stripX, y)
        strip:SetWidth(math.max(1, width - inset * 2))
        local h = LayoutTabs()
        cardTop = y - h
        placed = true
        Paint()
        return h
    end

    -- 卡片底緣（parent 座標；表單用 rows[i].bottom − 內距）
    function tc:SetBottom(y)
        cardBottom = y
        DrawCard()
    end

    -- 卡片高（從鈕列底緣往下；自由版面用）
    function tc:SetCardHeight(h)
        cardBottom = cardTop - (h or 0)
        DrawCard()
    end

    -- 只顯示 ids 裡的鈕（nil＝全部），重排；回傳鈕列高（卡片上緣跟著動，底緣不動）
    function tc:SetTabs(ids)
        local has
        if ids then
            has = {}
            for _, id in ipairs(ids) do has[id] = true end
        end
        for _, b in ipairs(self.buttons) do b:SetShown(not has or has[b.id] == true) end
        local h = LayoutTabs()
        if placed then cardTop = stripY - h end
        Paint()
        return h
    end

    -- 高亮 id 那顆（不叫 onSelect）
    function tc:Select(id)
        selected = self.byId[id] or selected
        Paint()
    end

    function tc:GetSelected() return selected and selected.id end
    function tc:GetCardTop() return cardTop end

    function tc:SetShown(on)
        shown = on and true or false
        strip:SetShown(shown)
        DrawCard()
    end
    function tc:Show() self:SetShown(true) end
    function tc:Hide() self:SetShown(false) end

    if opts.selected then selected = tc.byId[opts.selected] end
    selected = selected or tc.buttons[1]
    return tc
end

------------------------------------------------------------
-- 視窗拖曳把手 ／ 標題列
--
-- 設定視窗沒有暴雪那種厚標題列，所以「哪裡可以抓」完全沒有訊號。九個插件本來
-- 各自複製同一段「分頁鈕兼把手」的程式 —— 但那個把手是**隱形**的：分頁鈕的視覺
-- 語言講的是「切換頁面」，沒人會想到它同時能拖。實際回報就是「這視窗不能移動」。
--
-- 兩層解法：
--   W.MakeDragHandle  把任何區域變成把手（分頁鈕沿用，行為不變）
--   W.CreateTitleBar  視窗上緣外側的標題列：看得見的把手 chip ＋ 標題文字，整條都能拖
--
-- ⚠ 不用 RegisterForDrag：滑鼠稍微一抖就被判定成拖曳，那一下 OnClick 會被吃掉
--   （分頁「點了沒反應」，觸控板最明顯）。改成自己量位移＋最短按住時間。
------------------------------------------------------------
local DRAG_THRESHOLD = 12       -- 位移超過幾 px 才算拖曳（GetCursorPosition 的單位，不隨 UI 縮放）
local DRAG_DELAY     = 0.12     -- 按住幾秒之後才算拖曳

local function FinishDrag(handle)
    handle:SetScript("OnUpdate", nil)
    if not handle._dragging then return end
    handle._dragging = false
    handle._dragTarget:StopMovingOrSizing()
    -- 位置一律走插件自己的 SV，不要讓暴雪的版面存檔接手
    handle._dragTarget:SetUserPlaced(false)
    if handle._onMoved then handle._onMoved() end
end

-- handle 要收得到滑鼠（Button 天生有，純 Frame 記得 EnableMouse(true)）
function W.MakeDragHandle(handle, target, onMoved)
    handle._dragTarget, handle._onMoved = target, onMoved

    handle:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not target:IsMovable() then return end
        local sx, sy = GetCursorPosition()
        local downAt = GetTime()
        self._dragging = false
        self:SetScript("OnUpdate", function(s)
            -- 放開的那一下如果落在把手外面（拖到螢幕邊緣被 clamp 住時會發生），
            -- OnMouseUp 收不到 —— 沒有這道自檢，視窗就黏在游標上了
            if not IsMouseButtonDown("LeftButton") then return FinishDrag(s) end
            if s._dragging then return end
            local px, py = GetCursorPosition()
            if (math.abs(px - sx) > DRAG_THRESHOLD or math.abs(py - sy) > DRAG_THRESHOLD)
                and GetTime() - downAt >= DRAG_DELAY then
                s._dragging = true
                target:StartMoving()
            end
        end)
    end)

    handle:HookScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        FinishDrag(self)
    end)

    return handle
end

------------------------------------------------------------
-- 拖曳提示的文案
--
-- ⚠ 這是共用層唯一**自帶**的字串。契約本來是「文案由宿主傳進來」（README 的
--   「L 只需要四個 key」），這裡破例：這是共用層自己長出來的元件，九個宿主 ×
--   最多十個語系去補 key，補完必然漂移。宿主真要改就傳 opts.label / opts.tip*。
------------------------------------------------------------
local DRAG_TEXT = {
    enUS = { "Drag to move", "Move this window",
             "Hold the left mouse button and drag.",
             "Right-click: back to the centre of the screen" },
    zhTW = { "拖曳移動", "移動這個視窗",
             "按住左鍵拖曳。",
             "右鍵：回到畫面正中央" },
    zhCN = { "拖动移动", "移动这个窗口",
             "按住左键拖动。",
             "右键：回到屏幕正中央" },
    koKR = { "드래그해서 이동", "창 이동",
             "왼쪽 버튼을 누른 채 끌어 주세요.",
             "우클릭: 화면 중앙으로" },
    deDE = { "Verschieben", "Fenster verschieben",
             "Halte die linke Maustaste gedrückt und ziehe.",
             "Rechtsklick: zurück zur Bildschirmmitte" },
    frFR = { "Déplacer", "Déplacer la fenêtre",
             "Maintenez le bouton gauche et faites glisser.",
             "Clic droit : au centre de l'écran" },
    esES = { "Mover", "Mover la ventana",
             "Mantén pulsado el botón izquierdo y arrastra.",
             "Clic derecho: volver al centro de la pantalla" },
    itIT = { "Sposta", "Sposta la finestra",
             "Tieni premuto il tasto sinistro e trascina.",
             "Clic destro: torna al centro dello schermo" },
    ptBR = { "Mover", "Mover a janela",
             "Segure o botão esquerdo e arraste.",
             "Clique direito: voltar ao centro da tela" },
    ruRU = { "Переместить", "Переместить окно",
             "Удерживайте левую кнопку мыши и перетащите.",
             "Правый клик: вернуть в центр экрана" },
}
DRAG_TEXT.esMX = DRAG_TEXT.esES
DRAG_TEXT.ptPT = DRAG_TEXT.ptBR

local dragText = DRAG_TEXT[GetLocale()] or DRAG_TEXT.enUS

------------------------------------------------------------
-- 標題列
--
-- 版面：`[⠿ 拖曳移動] 插件名稱 v1.2.3`，掛在面板上緣外側、分頁列的上面一層。
-- 整條（含標題文字）都是拖曳區，右鍵把視窗叫回畫面中央。
--
-- 為什麼把手是一個**有底有邊的 chip**、而不是光禿禿六個點：標題列在面板**外側**，
-- 背後是會動的遊戲畫面，灰點在亮色地圖上等於不存在。chip 到哪都讀得到，而且跟
-- 底下的分頁鈕同一套視覺語言（WIDGET_FILL 底、hover 換 accent），一看就知道能按。
--
-- 寬度只包到標題文字結束，不整條拉滿：右半邊有些插件放搜尋框（Options/Search.lua
-- 的退回位置），而且「滑過空白處跳出工具提示」本身也怪。
------------------------------------------------------------
local BAR_H     = 21     -- 標題列高
local BAR_Y     = 24     -- 標題列底緣離面板上緣多高（分頁鈕高 22，剛好讓開）
local CHIP_H    = 18
local GRIP_X    = 7      -- ⠿ 距 chip 左緣
local GRIP_W    = 5      -- ⠿ 佔的寬（兩欄點 + 欄距）
local GRIP_GAP  = 5      -- ⠿ 與提示字之間
local CHIP_PAD  = 8      -- chip 右內距

function W.CreateTitleBar(panel, titleText, onMoved, opts)
    opts = opts or {}

    -- 有標題列的就是一扇設定視窗 ⇒ 開 toplevel。
    -- ⚠ 各插件的視窗都是 DIALOG／level 100，只靠開啟時 panel:Raise() 排前後；
    -- Raise 只抬面板自己，裡面自己 SetFrameLevel 過的子框留在原地 ⇒ 同時開兩扇
    -- 時兩邊的控件照 level 大小交錯著畫（A 的分頁鈕疊在 B 的內容上）。
    -- toplevel 隱含 render layer flattening：整扇視窗連子孫併成一層、照面板自己的
    -- level 畫，視窗之間只剩整扇的前後；點一下也會自動拉到最前。
    -- 代價是子孫的 strata 在繪製上失效 —— 視窗裡的彈窗／戰鬥遮罩靠的是 level
    -- 400～520 所以照樣在內容之上；下拉與右鍵選單掛 UIParent，不受影響。
    -- 要浮到別的視窗上面的東西別掛在面板底下。
    panel:SetToplevel(true)

    local bar = CreateFrame("Frame", nil, panel)
    bar:EnableMouse(true)
    bar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, opts.y or BAR_Y)

    local chip = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    W.Stylize(chip, WIDGET_FILL)
    chip:SetPoint("LEFT", 0, 0)

    -- ⠿：兩欄 × 三列的 2px 點。chip 不 EnableMouse，滑鼠一路落到 bar 上，
    -- 所以三個元件（chip／點／提示字）的 hover 都由 bar 統一驅動
    local dots = {}
    for col = 0, 1 do
        for row = 0, 2 do
            local d = chip:CreateTexture(nil, "ARTWORK")
            d:SetTexture(WHITE)
            d:SetSize(P.Scale(2), P.Scale(2))
            d:SetPoint("CENTER", chip, "LEFT", P.Scale(GRIP_X + col * 3 + 1), P.Scale(3 - row * 3))
            dots[#dots + 1] = d
        end
    end

    local hint = chip:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(fontSmall)
    hint:SetPoint("LEFT", chip, "LEFT", P.Scale(GRIP_X + GRIP_W + GRIP_GAP), 0)
    hint:SetText(opts.label or dragText[1])
    -- 量字寬要在 SetText 之後。這裡跟分頁鈕一樣把 GetStringWidth 當「想要的 px」
    -- 餵進 P.Size，讓 PixelPerfect 在 UI 縮放變動時能自己重算
    local chipW = GRIP_X + GRIP_W + GRIP_GAP + math.ceil(hint:GetStringWidth()) + CHIP_PAD
    P.Size(chip, chipW, CHIP_H)

    local barW = chipW
    local title
    if titleText and titleText ~= "" then
        title = bar:CreateFontString(nil, "OVERLAY")
        title:SetFontObject(fontTitle)
        title:SetPoint("LEFT", chip, "RIGHT", P.Scale(8), 0)
        title:SetText(titleText)
        barW = barW + 8 + math.ceil(title:GetStringWidth()) + 6
    end
    P.Size(bar, barW, BAR_H)

    -- hover：只換明暗不換色相（見 miliui-color-states），階梯直接沿用按鈕那組
    local function SetHot(hot)
        if hot then
            chip:SetBackdropColor(W.Accent(0.6))
            hint:SetTextColor(1, 1, 1)
        else
            chip:SetBackdropColor(unpack(WIDGET_FILL))
            hint:SetTextColor(0.8, 0.8, 0.8)
        end
        for _, d in ipairs(dots) do
            d:SetVertexColor(hot and 1 or 0.6, hot and 1 or 0.6, hot and 1 or 0.6, 1)
        end
    end
    SetHot(false)

    bar:SetScript("OnEnter", function()
        SetHot(true)
        GameTooltip:SetOwner(bar, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        -- 優先擺在上方；視窗貼到螢幕頂端時改擺下方（三行約需 70px）。
        -- 螢幕左右邊界交給 GameTooltip 自己的 clamp
        local top = bar:GetTop()
        if top and (UIParent:GetTop() - top) > 70 then
            GameTooltip:SetPoint("BOTTOMLEFT", chip, "TOPLEFT", 0, 6)
        else
            GameTooltip:SetPoint("TOPLEFT", chip, "BOTTOMLEFT", 0, -6)
        end
        GameTooltip:AddLine(opts.tipTitle or dragText[2])
        GameTooltip:AddLine(opts.tipBody or dragText[3], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(opts.tipReset or dragText[4], 0.55, 0.55, 0.55, true)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function()
        SetHot(false)
        GameTooltip:Hide()
    end)

    -- 右鍵：把視窗叫回畫面中央。存到看不見的地方是拖曳一定會發生的意外，
    -- 而「關掉再開」不會救回來（位置有存檔）—— 沒有這條就只能重灌設定。
    -- ⚠ 一定要排在 MakeDragHandle **之前**：那支走 HookScript，
    --   反過來的話這行 SetScript 會把它的 OnMouseUp 整個蓋掉
    bar:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" then return end
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        panel:SetUserPlaced(false)
        if onMoved then onMoved() end
    end)

    W.MakeDragHandle(bar, panel, onMoved)

    bar.chip, bar.title = chip, title
    return bar
end

------------------------------------------------------------
-- 勾選框
------------------------------------------------------------
function W.CreateCheckButton(parent, label, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    -- 18px：14px 配 zhTW 的大字標籤顯得小氣，加大到跟行高平衡
    P.Size(cb, 18, 18)
    W.Stylize(cb, CHECKBOX_FILL)

    cb.labelGap = 6                -- 標籤離框幾 px（呼叫端算可用寬度時要扣掉）
    cb.label = cb:CreateFontString(nil, "OVERLAY")
    cb.label:SetFontObject(fontNormal)
    cb.label:SetPoint("LEFT", cb, "RIGHT", cb.labelGap, 0)
    cb.label:SetText(label or "")
    -- 點標籤也能勾（Platynator 手法：整列都是點擊區）
    if label and label ~= "" then
        cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 8), 0, 0)
    end

    -- 把標籤夾在 maxW 裡換行（opt-in），回傳換行多出來的高度（沒換行回 0）。
    --
    -- 標籤預設沒設寬也不換行：短的「顯示邊框」沒問題，長的說明句就一路衝出視窗右緣，
    -- **而且點擊熱區跟著字寬延伸**——看不見的那截照樣吃滑鼠，蓋到右邊的控件。
    -- 只有知道「這一列右邊還剩多少」的呼叫端說得出 maxW，所以做成 opt-in。
    --
    -- 放得下就完全不動（不設寬、不換行、熱區與原本逐位元相同）；量字寬一定要在
    -- SetWidth 之前，換行之後 GetStringWidth 的語意就不是「整串有多寬」了。
    function cb:SetLabelMaxWidth(maxW)
        local fs = cb.label
        local text = fs:GetText()
        if not maxW or maxW <= 0 or not text or text == "" then return 0 end
        local textW = fs:GetStringWidth() or 0
        if textW <= 0 then return 0 end          -- 量不到（版面未解析）就當沒這回事
        -- 熱區只延伸到文字真正佔到的寬度：換行之後文字不會比 maxW 寬，
        -- 再照原本的字寬算會在右邊留一塊看不見的點擊區
        cb:SetHitRectInsets(0, -(math.min(textW, maxW) + 8), 0, 0)
        if textW <= maxW then return 0 end
        fs:SetWidth(maxW)
        fs:SetJustifyH("LEFT")                   -- 定寬之後才輪得到對齊（預設是置中）
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(true)                 -- 德文複合字沒空白可斷，寧可斷在字中
        -- 整塊文字仍然垂直置中於勾選框（JustifyV 預設 MIDDLE），
        -- 呼叫端把多出來的高度墊進列高就不會蓋到上下列
        return W.TextExtraHeight(fs, text)
    end

    -- 勾＝職業色、刻意比框大一圈往外溢（暴雪原生勾選框的視覺語言，形狀是
    -- 現代扁平的 checkmark-minimal 細勾），外加 1px 黑框跟任何底色分離。
    -- 素材是自帶的「白勾＋黑框」64×64 貼圖（跟 MiliUI_Skin 的勾同一張），
    -- 染色是乘法 ⇒ 白的變職業色、黑框維持黑。勾用材質不用字元：中文字型沒有 ✓。
    --
    -- 2026-09-22 之前是 checkmark-minimal 圖集當遮罩摳純白貼圖，再墊四張往斜角
    -- 錯開半像素的黑勾當描邊。圖集只有 30×29，放大到 24 高再經雙線性取樣就糊了，
    -- 半像素描邊也只是一圈灰霧 —— 跟 Skin 的勾擺在同一個畫面裡差很多。
    --
    -- 勾（含黑框）在貼圖裡約佔 64 格的 0.64 ⇒ 貼圖邊長 ＝ 24 ÷ 0.64，看得到的勾才是 24 高
    -- （同 MiliUI_Skin 的 T.checkGlyphHeight／T.checkOutlineGlyphFrac，改一邊要改兩邊）。
    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetTexture(CHECK_TEX)
    check:SetVertexColor(W.Accent())
    P.Size(check, 24 / 0.64, 24 / 0.64)
    check:SetPoint("CENTER", 0, 0)
    check:Hide()

    -- 顯隱自己管、不交給 SetCheckedTexture：原本是多層貼圖要一起顯隱才這樣做，
    -- 改成一張之後沿用，停用／點擊的行為跟之前完全相同。
    -- 自己包 SetChecked、OnClick 也跟著同步（refreshers 走 SetChecked、玩家走點擊）
    local function UpdateVisual(self)
        check:SetShown(self:GetChecked() and true or false)
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
    W.CloseOnEscape(menuFrame, true)
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

------------------------------------------------------------
-- 貼齊螢幕
--
-- 任何「浮在畫面上、貼著某個東西彈出來」的面板都該過這裡：右鍵選單、子選單、
-- 下拉清單。起因是玩家把統計視窗擺在畫面右下角，右鍵選單整片開到畫面外面 ——
-- 那不只是難看，是**點不到**（被裁掉的那一截沒有任何辦法捲到）。
--
-- 兩段式，順序不能倒過來：
--   1. **翻面** —— 裝不下就改貼錨點的另一側（往下開改成往上開）。呼叫端自己決定，
--      因為只有它知道「另一側」在哪、翻過去合不合理。
--   2. **平移**（`W.PlaceClamped`）—— 翻完還是出界才把整個面板推回畫面內。
--
-- 先平移的話面板會蓋住開它的那顆按鈕（在螢幕下緣特別明顯，因為它正好往上疊在
-- 按鈕身上）；翻面則永遠貼著錨點，讀起來還是「從這裡長出來的」。
------------------------------------------------------------
W.SCREEN_PAD = 4

-- 面板超出畫面多少 → 回傳要補的位移 (dx, dy)。四個邊都看。
-- ⚠ 比對 UIParent 自己的四邊，不要寫死 0 與 GetWidth/GetHeight。
-- 一個方向塞不下時**保左上**（面板是從上往下、從左往右讀的，要截也截讀最後那端）。
function W.ScreenNudge(f)
    local pl, pr = UIParent:GetLeft(), UIParent:GetRight()
    local pb, pt = UIParent:GetBottom(), UIParent:GetTop()
    local l, r = f:GetLeft(), f:GetRight()
    local b, t = f:GetBottom(), f:GetTop()
    if not (pl and pr and pb and pt and l and r and b and t) then return 0, 0 end
    local pad = W.SCREEN_PAD
    local dx, dy = 0, 0
    if r > pr - pad then dx = (pr - pad) - r end
    if l + dx < pl + pad then dx = (pl + pad) - l end
    if b < pb + pad then dy = (pb + pad) - b end
    if t + dy > pt - pad then dy = (pt - pad) - t end
    return dx, dy
end

-- 貼上錨點，再把超出畫面的部分推回來。**面板要先有正確的尺寸並且已經 Show**，
-- 否則量到的矩形是舊的。
--
-- pts 是 `{ point, relativeTo, relativePoint, x, y }`，**會被就地改寫成推回後的
-- 偏移** —— 呼叫端把它存起來重貼時（例如選單的開關項目要原地重畫）才會回到同一
-- 個位置，不然按一下就自己跳回出界的地方。
function W.PlaceClamped(f, pts)
    f:ClearAllPoints()
    f:SetPoint(unpack(pts))
    local dx, dy = W.ScreenNudge(f)
    if dx ~= 0 or dy ~= 0 then
        pts[4] = (pts[4] or 0) + dx
        pts[5] = (pts[5] or 0) + dy
        f:ClearAllPoints()
        f:SetPoint(unpack(pts))
    end
end

------------------------------------------------------------
-- ESC 關閉
--
-- 走暴雪的 `UISpecialFrames`，**絕對不要自己 EnableKeyboard 擷取按鍵** ——
-- 鍵盤啟用又不轉發的框會擋掉**全部**快捷鍵（連 ESC 本身都會失效），
-- 症狀是「視窗關不掉」。見 notes/wow-keyboard-capture-blocks-bindings。
--
-- ⚠ 兩個限制，決定了它只適合哪些東西：
--   1. 它吃的是**全域名稱**，所以框必須具名（沒名字就掛一個到 _G）。
--   2. 註冊之後**不會移除**，那張表只會長不會縮。
--   → 只給「一個插件建不了幾個」的東西用：設定視窗、下拉選單、彈窗。
--      **不要在迴圈或每次開啟時呼叫**，建立時叫一次就好。
--
-- 開暴雪面板不關（預設）：ShowUIPanel 開「中間那格」的面板（天賦／法術書、全螢幕地圖…）時，
-- 也會呼叫同一支 CloseSpecialWindows 把整張表收掉 —— 暴雪那邊 ESC 跟「換面板」是同一條路。
-- 設定視窗與彈窗不該跟著關（要從法術書 Shift 點法術填 ID），所以分辨兩條路：
--   同一幀裡「被 CloseSpecialWindows 收掉」而且「接著 ShowUIPanel 跑完」→ 換面板，叫回來；
--   ESC（ToggleGameMenu → CloseAllWindows）不經過 ShowUIPanel → 照常關。
-- 「被收掉」的時間由一個空的子框的 OnHide 記（不用框本身的腳本：呼叫端之後 SetScript 會蓋掉 HookScript）。
-- 兩支都是 hooksecurefunc 後掛勾，只對自己的框 Show，不寫暴雪任何東西。
-- ⚠ 自己的程式先關視窗、同一幀再 ShowUIPanel 開中間面板，視窗會被叫回來；要那樣做就延一幀再開。
-- closeWithPanels ＝ true：維持舊行為（下拉選單、右鍵選單這種開面板時收掉才對的）。
------------------------------------------------------------
local escSeq = 0
local keepers = {}          -- 框 → 最後一次被收掉的 GetTime()
local reopen = {}           -- 框 → 被 CloseSpecialWindows 收掉的那一幀
local panelHooked = false

local function HookPanels()
    if panelHooked then return end
    panelHooked = true
    if type(CloseSpecialWindows) ~= "function" or type(ShowUIPanel) ~= "function" then return end
    hooksecurefunc("CloseSpecialWindows", function()
        local now = GetTime()
        for f, t in pairs(keepers) do
            if t == now and not f:IsShown() then reopen[f] = now end
        end
    end)
    hooksecurefunc("ShowUIPanel", function()
        if not next(reopen) then return end
        local now = GetTime()
        for f, t in pairs(reopen) do
            reopen[f] = nil
            if t == now and not f:IsShown() then f:Show() end
        end
    end)
end

function W.CloseOnEscape(frame, closeWithPanels)
    local name = frame:GetName()
    if not name then
        escSeq = escSeq + 1
        name = NS .. "_EscFrame" .. escSeq
        _G[name] = frame        -- UISpecialFrames 是靠 _G[name] 反查框的
    end
    tinsert(UISpecialFrames, name)
    if closeWithPanels then return end
    HookPanels()
    keepers[frame] = false
    local probe = CreateFrame("Frame", nil, frame)
    probe:SetScript("OnHide", function() keepers[frame] = GetTime() end)
end

function W.CloseDropdowns()
    if menuFrame then menuFrame:Hide() end
end

-- 選中的文字是被切掉的嗎。IsTruncated 是 FontString 自己的判斷（含「…」那種）；
-- 拿不到就退回「整串字寬有沒有超過 FontString 的寬度」。兩個錨點夾出來的寬度在版面
-- 解析前量到 0，那時一律當成沒截斷 —— 寧可少一次提示，也不要每顆下拉都跳提示。
local function TextTruncated(fs)
    if not fs then return false end
    if fs.IsTruncated then return fs:IsTruncated() and true or false end
    local avail = fs:GetWidth() or 0
    return avail > 0 and (fs:GetStringWidth() or 0) > avail
end

-- 提示是借 GameTooltip 顯示的（共用框），收尾前先確認它還是我們掛上去的那一份，
-- 免得把別人剛開的提示關掉
local function HideDropdownTip(owner)
    if GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
end

function W.CreateDropdown(parent, width, items, onSelect)
    local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
    local baseW = width or 120
    P.Size(dd, baseW, 20)
    W.Stylize(dd, WIDGET_FILL)
    -- 框線平常深灰，hover 與展開中染職業色；展開中滑鼠移開不退色，
    -- 選單收起（OnHide）或換別的下拉當 owner 時才還原
    dd:SetBackdropBorderColor(unpack(DD_BORDER))
    dd:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(W.Accent(1))
        -- 保底：撐到上限還是放不下、或呼叫端根本沒 opt-in 撐寬的，
        -- 這是玩家唯一看得到全文的地方（選單裡的項目本來就會撐開，但要點開才看得到）
        if TextTruncated(self.text) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.text:GetText() or "", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    dd:SetScript("OnLeave", function(self)
        if not (menuFrame and menuFrame:IsShown() and menuFrame.owner == self) then
            self:SetBackdropBorderColor(unpack(DD_BORDER))
        end
        HideDropdownTip(self)
    end)

    -- ⚠ 展開中的選單是掛在 UIParent 上的**共用框**，不是這顆下拉的子物件，所以
    -- 下拉被藏起來時它不會跟著消失 —— 切分頁／切單位／切元件／關掉整個視窗，
    -- 都會留下一張浮在畫面上、還吃滑鼠與滾輪的選單（看起來就是「選單卡住」）。
    -- 讓擁有者自己收尾，就不必在每一個切換點都記得呼叫 CloseDropdowns，
    -- 之後新增的分頁與清單也自動免疫。
    -- 用 HookScript：這支的 OnHide 目前沒別人用，但不要把位置佔死。
    dd:HookScript("OnHide", function(self)
        if menuFrame and menuFrame.owner == self then
            menuFrame:Hide()      -- 選單的 OnHide 會把 owner 的展開色還原
        end
        -- 切分頁時滑鼠可能正停在某顆下拉上，OnLeave 不會來（框是直接被藏掉的），
        -- 提示就會留在畫面上
        HideDropdownTip(self)
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

    -- 選中的文字夾在左右錨點之間、又不換行（20px 高的按鈕塞不下第二行）⇒ 超過
    -- 「寬度 − 21」就被截成「…」。opt-in 的自動撐寬：只有知道這一列右邊還剩多少的
    -- 呼叫端說得出上限，預設就撐的話，跟別的控件並排在同一列的下拉會直接蓋過去。
    --
    -- 量的是**最寬的那一項**，不是當下選的那一項：寬度一次定好，選一次跳一次很難看。
    -- 借 dd.text 自己量（同一個字型物件，才量得準），量完把原本的文字放回去。
    local function FitWidth()
        local maxW = dd.maxW
        if not maxW or maxW <= baseW then return end
        local keep = dd.text:GetText()
        local widest = 0
        for _, item in ipairs(dd.items or {}) do
            dd.text:SetText(item.text or "")
            local w = dd.text:GetStringWidth() or 0
            if w > widest then widest = w end
        end
        dd.text:SetText(keep or "")
        -- 21 = 左內縮 5 ＋ 右邊讓給箭頭的 16（同 dd.text 的兩個錨點）
        local need = math.ceil(widest) + 21
        if need < baseW then need = baseW elseif need > maxW then need = maxW end
        if need ~= dd.width then P.Size(dd, need, 20) end
    end

    -- 撐寬的上限（不叫就永遠維持建立時的寬度）。之後每次 SetItems 會照新清單重算。
    function dd:SetMaxWidth(maxW)
        dd.maxW = maxW
        FitWidth()
    end

    function dd:SetItems(newItems)
        dd.items = newItems
        FitWidth()
    end
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
        local roomBelow = self:GetBottom()
        local pts
        if roomBelow and roomBelow - menu.viewH - 2 < 0 then
            pts = { "BOTTOMLEFT", self, "TOPLEFT", 0, 2 }
        else
            pts = { "TOPLEFT", self, "BOTTOMLEFT", 0, -2 }
        end
        -- 先給尺寸再 Show 再定位：W.PlaceClamped 要量矩形，順序反了就量到舊的
        P.Size(menu, menuW, menu.viewH)
        menu:Show()
        -- 翻上去之後頂端還是可能出界（設定視窗貼著畫面上緣時），推回來
        W.PlaceClamped(menu, pts)
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

-- 訊息長到撞上按鈕時把彈窗加高。
--
-- 彈窗的高度原本是寫死的（84／96），只夠兩三行；歐語的確認訊息換完行有四行，
-- 後面那兩行直接蓋在「確定／取消」上面 —— 而那正是玩家非按不可的地方。
-- ⚠ 一定要在 OnShow 算：訊息是**重用的彈窗在 Show 之前才填的**（換設定檔要不要
-- 重載那種），建立時算死等於量到空字串。
-- 撞不到按鈕就一個位元都不動，中文那幾行的彈窗維持原本的高度。
local function GrowPopupForText(popup, fs, baseH, btnH, btnPad, textTop)
    local textH = fs:GetStringHeight() or 0
    if textH <= 0 then return end                     -- 版面未解析，維持原高
    local overlap = (textTop + textH) - (baseH - btnPad - btnH)
    P.Height(popup, overlap > 0 and (baseH + overlap + 6) or baseH)
end

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
    W.CloseOnEscape(popup)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup.mask = mask

    local fs = popup:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(fontNormal)
    fs:SetPoint("TOP", 0, -12)
    fs:SetWidth(width - 24)
    fs:SetJustifyH("CENTER")
    fs:SetText(text)
    popup.text = fs

    -- 高度貼著字長：上緣 12＋字高＋字與按鈕間距 14＋按鈕 22＋下緣 12（固定 96 的話一行字中間空一大塊）
    popup:SetScript("OnShow", function(self)
        mask:Show()
        local textH = fs:GetStringHeight() or 0
        if textH > 0 then P.Height(self, 12 + textH + 14 + 22 + 12) end
    end)
    popup:SetScript("OnHide", function() mask:Hide() end)

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

    -- 建完先關掉，理由同 CreateConfirmPopup 結尾那段註解
    popup:Hide()
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
    W.CloseOnEscape(popup)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup.mask = mask

    local fs = popup:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(fontNormal)
    fs:SetPoint("TOP", 0, -14)
    fs:SetWidth((width or 240) - 24)
    fs:SetJustifyH("CENTER")
    fs:SetText(text)
    -- 開出來：有些確認訊息要看當下狀況才決定怎麼寫（例如換設定檔要不要重載），
    -- 而彈窗是建一次就重用的，不能把文字烘死在建立那一刻
    popup.text = fs

    popup:SetScript("OnShow", function(self)
        mask:Show()
        GrowPopupForText(self, fs, 84, 22, 12, 14)
    end)
    popup:SetScript("OnHide", function() mask:Hide() end)

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
    W.CloseOnEscape(popup)
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

------------------------------------------------------------
-- 格線開關（opt-in）：設定視窗右上角的「格線: ON／OFF」，滑過時上方浮出間距滑桿
--
--   local grid = W.CreateGridToggle(panel, {
--       db = function() return ns.sv.optionsWindow end,  -- 存 grid（布林）／gridSpacing（數字）
--       onChange = function(shown, spacing) end,         -- 選用：開關或間距變了
--   })
--   grid:Active()   -- 格線此刻畫在畫面上 ⇒ 間距；否則 nil（宿主的拖曳吸附讀這個）
--   grid.width      -- 按鈕寬（固定）：分頁列右側還要排東西的宿主拿去扣
--
-- 用途：設定視窗開著就能拖的插件（冷卻管理器之類），給玩家一張對齊用的格線。
-- 只在面板開著時畫；開關與間距存宿主的 db（帳號層那張），跟著視窗位置一起走。
--
-- 格線跟暴雪編輯模式的格線同一種畫法：從畫面中心往外、UIParent 座標、中心兩條較亮。
-- 所以吸附的原點一律是 UIParent:GetCenter()，跟暴雪那套換算一致。
--
-- ⚠ 畫格線的框是**全套組共用一張**（_G 具名），不是每份 vendor 各畫一張：兩支插件的
--   面板同時開著格線時，兩套線交錯在一起就是 wow-editmode-blizzard-grid 那次的「格線好亂」。
--   誰最後開／改間距就照誰的間距畫。名字帶版號：哪天畫法改了換名字，不要去改舊框。
-- ⚠ 暴雪編輯模式的格線看得到時，我們的整張讓位（同理，兩套線不要疊）。不掛暴雪框的
--   腳本（post-hook 會讓我們的 Lua 跑進進出編輯模式的執行堆疊），改成開著時 0.2 秒看一次。
------------------------------------------------------------
local GRID_TEXT = {
    enUS = { "Grid", "Spacing" },
    zhTW = { "格線", "間距" },
    zhCN = { "网格", "间距" },
    koKR = { "격자", "간격" },
    deDE = { "Raster", "Abstand" },
    frFR = { "Grille", "Espacement" },
    esES = { "Cuadrícula", "Espaciado" },
    itIT = { "Griglia", "Spaziatura" },
    ptBR = { "Grade", "Espaçamento" },
    ruRU = { "Сетка", "Шаг" },
}
GRID_TEXT.esMX = GRID_TEXT.esES
GRID_TEXT.ptPT = GRID_TEXT.ptBR
local gridText = GRID_TEXT[GetLocale()] or GRID_TEXT.enUS

local GRID_MIN, GRID_MAX, GRID_STEP, GRID_DEFAULT = 10, 200, 2, 40
local GRID_OVERLAY_NAME = "MiliUIWidgetsGridOverlay1"

local function GridOverlay()
    local ov = _G[GRID_OVERLAY_NAME]
    if ov then return ov end

    ov = CreateFrame("Frame", GRID_OVERLAY_NAME, UIParent)
    ov:SetAllPoints(UIParent)
    ov:SetFrameStrata("BACKGROUND")
    ov:SetFrameLevel(0)
    ov:EnableMouse(false)
    ov:Hide()
    ov.owners, ov.order, ov.lines, ov.used = {}, {}, {}, 0

    local function Line(i)
        local t = ov.lines[i]
        if not t then
            t = ov:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(WHITE)
            ov.lines[i] = t
        end
        t:ClearAllPoints()
        t:Show()
        return t
    end

    -- 線池只長不丟（貼圖刪不掉）；間距變大時多的藏起來
    function ov:Redraw()
        local spacing = self.spacing
        local w, h = self:GetSize()
        if not (spacing and w and h and w > 0 and h > 0) then return end
        -- 1 個實體像素在這張框上是多少 UI 單位
        local px = (768 / select(2, GetPhysicalScreenSize())) / self:GetEffectiveScale()
        local ar, ag, ab = W.Accent()
        local n = 0
        local cx, cy = w / 2, h / 2
        local function V(x, center)
            n = n + 1
            local t = Line(n)
            t:SetPoint("TOPLEFT", self, "TOPLEFT", x - px / 2, 0)
            t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x - px / 2, 0)
            t:SetWidth(px)
            if center then t:SetVertexColor(ar, ag, ab, 0.7) else t:SetVertexColor(0.6, 0.6, 0.6, 0.35) end
        end
        local function H(y, center)
            n = n + 1
            local t = Line(n)
            t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, y - px / 2)
            t:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, y - px / 2)
            t:SetHeight(px)
            if center then t:SetVertexColor(ar, ag, ab, 0.7) else t:SetVertexColor(0.6, 0.6, 0.6, 0.35) end
        end
        for k = 1, math.floor(cx / spacing) do V(cx - k * spacing); V(cx + k * spacing) end
        for k = 1, math.floor(cy / spacing) do H(cy - k * spacing); H(cy + k * spacing) end
        -- 中心兩條最後畫，蓋在一般線上面
        V(cx, true)
        H(cy, true)
        for i = n + 1, self.used do self.lines[i]:Hide() end
        self.used = n
    end

    -- 暴雪編輯模式的格線看得到 ⇒ 我們讓位
    -- ⚠ 要問 IsVisible 不是 IsShown：玩家在編輯模式勾過「顯示格線」的話，暴雪載入設定時就
    --   Grid:SetShown(true)，沒進編輯模式時 Grid 自己的旗標照樣是 true（只是父框藏著）
    --   ⇒ 問 IsShown 會永遠讓位、一條線都不畫
    local function BlizzGridShown()
        local g = EditModeManagerFrame and EditModeManagerFrame.Grid
        if not (g and g.IsVisible) then return false end
        local ok, v = pcall(g.IsVisible, g)
        return ok and v == true
    end
    ov.BlizzGridShown = BlizzGridShown

    function ov:Update()
        local top = self.order[#self.order]
        if not top then
            self:Hide()
            self.spacing = nil
            return
        end
        self.spacing = self.owners[top]
        local show = not BlizzGridShown()
        self:SetShown(show)
        if show then self:Redraw() end
    end

    -- owner 開著格線就給間距，關掉給 nil。最後動的那個排到最後（照它的間距畫）
    function ov:SetOwner(owner, spacing)
        for i = #self.order, 1, -1 do
            if self.order[i] == owner then table.remove(self.order, i) end
        end
        self.owners[owner] = spacing
        if spacing then self.order[#self.order + 1] = owner end
        self:Update()
    end

    -- 可見與否：自己藏起來的時候 OnUpdate 也停，所以讓位的檢查掛在另一張常駐的小框上
    local watch = CreateFrame("Frame")
    local acc = 0
    watch:SetScript("OnUpdate", function(_, elapsed)
        if #ov.order == 0 then return end
        acc = acc + elapsed
        if acc < 0.2 then return end
        acc = 0
        local want = not BlizzGridShown()
        if want ~= ov:IsShown() then
            ov:SetShown(want)
            if want then ov:Redraw() end
        end
    end)

    ov:SetScript("OnSizeChanged", function(self) if self:IsShown() then self:Redraw() end end)
    ov:RegisterEvent("UI_SCALE_CHANGED")
    ov:RegisterEvent("DISPLAY_SIZE_CHANGED")
    ov:SetScript("OnEvent", function(self) if self:IsShown() then self:Redraw() end end)
    return ov
end

local GRID_BTN_H = 22
local GRID_POP_W, GRID_POP_H = 230, 30

function W.CreateGridToggle(panel, opts)
    opts = opts or {}
    local function DB()
        local d = opts.db
        if type(d) == "function" then d = d() end
        return d
    end
    local function Spacing()
        local d = DB()
        local v = d and tonumber(d.gridSpacing) or GRID_DEFAULT
        if v < GRID_MIN then v = GRID_MIN elseif v > GRID_MAX then v = GRID_MAX end
        return v
    end
    local function On()
        local d = DB()
        return d and d.grid == true or false
    end

    local btn = W.CreateButton(panel, "", "normal", 74, GRID_BTN_H)
    -- 跟左邊的分頁鈕同一排：面板上緣外側、靠右
    btn:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 1)

    -- 浮出的間距滑桿：按鈕正上方、右緣對齊（標題列在左邊，不會撞）
    -- 層級壓過面板裡的一切（關閉鈕 +200、標題列那排的搜尋框）：浮窗只在滑過時出現，蓋住是對的
    local pop = W.CreateFrame(nil, btn, GRID_POP_W, GRID_POP_H)
    pop:SetPoint("BOTTOMRIGHT", btn, "TOPRIGHT", 0, 2)
    pop:SetFrameLevel(panel:GetFrameLevel() + 300)
    pop:SetBackdropBorderColor(W.Accent(0.8))
    pop:EnableMouse(true)
    pop:Hide()

    local label = pop:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(fontSmall)
    label:SetPoint("LEFT", pop, "LEFT", 8, 0)
    label:SetText(gridText[2])

    local toggle = { button = btn, popup = pop }
    local ov

    local function Push()
        ov = ov or GridOverlay()
        ov:SetOwner(toggle, (On() and panel:IsShown()) and Spacing() or nil)
    end

    local function Paint()
        local on = On()
        btn:SetText(gridText[1] .. ": " .. (on and "ON" or "OFF"))
        W.SetButtonVariant(btn, on and "primary" or "normal")
    end

    -- 寬度照 ON／OFF 比較寬的那個一次定死：切換時按鈕不跟著伸縮（左邊有分頁或搜尋框在排）
    local fs = btn:GetFontString()
    local btnW = 74
    for _, v in ipairs({ "ON", "OFF" }) do
        btn:SetText(gridText[1] .. ": " .. v)
        btnW = math.max(btnW, math.ceil(fs:GetStringWidth()) + W.BTN_TEXT_PAD)
    end
    P.Size(btn, btnW, GRID_BTN_H)
    toggle.width = btnW     -- 宿主排分頁列右側空間時扣掉這段

    local slider = W.CreateSlider(pop, GRID_MIN, GRID_MAX,
        GRID_POP_W - 16 - math.ceil(label:GetStringWidth()) - 8, GRID_STEP,
        function(v)
            local d = DB()
            if d then d.gridSpacing = v end
            -- 調間距就是想看格線：關著的話順手打開
            if d and not d.grid then d.grid = true; Paint() end
            Push()
            if opts.onChange then opts.onChange(On(), v) end
        end,
        function(v)
            local d = DB()
            if d then d.gridSpacing = v end
            Push()
            if opts.onChange then opts.onChange(On(), v) end
        end)
    slider:SetPoint("LEFT", label, "RIGHT", 8, 0)

    -- 滑鼠離開按鈕＋浮窗、而且沒在拖拉桿／打數字，0.3 秒後收起來
    -- （中間要跨過 2px 的縫，不能一離開就關）
    -- 拖拉桿時游標常常滑出浮窗，按著左鍵的期間不收（放開落在外面也照樣收得到：輪詢按鍵狀態）
    local away, dragging = 0, false
    slider.slider:HookScript("OnMouseDown", function() dragging = true end)
    pop:SetScript("OnUpdate", function(self, elapsed)
        if dragging and not IsMouseButtonDown("LeftButton") then dragging = false end
        local busy = dragging or btn:IsMouseOver() or self:IsMouseOver() or slider.editBox:HasFocus()
        if busy then away = 0 return end
        away = away + elapsed
        if away > 0.3 then self:Hide() end
    end)

    btn:SetScript("OnEnter", function(self)
        W.PaintButton(self, true)
        away = 0
        slider:SetValue(Spacing())
        pop:Show()
    end)
    btn:SetScript("OnLeave", function(self) W.PaintButton(self, false) end)
    btn:SetScript("OnClick", function()
        local d = DB()
        if not d then return end
        d.grid = not On()
        Paint()
        Push()
        if opts.onChange then opts.onChange(On(), Spacing()) end
    end)

    panel:HookScript("OnShow", function() Paint(); Push() end)
    panel:HookScript("OnHide", function() pop:Hide(); Push() end)

    function toggle:Active()
        if not (ov and ov.owners[self] and ov:IsShown()) then return nil end
        return ov.spacing
    end
    function toggle:Refresh() Paint(); Push() end

    Paint()
    if panel:IsShown() then Push() end
    return toggle
end
