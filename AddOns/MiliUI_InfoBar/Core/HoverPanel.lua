------------------------------------------------------------
-- 滑過方塊彈出來的面板：共用的皮、開關節奏、定位、列層
--
-- 資訊列上有四張「滑過方塊就長出來」的面板（坐騎／修裝／確認倒數／戰隊）。
-- 前三張原本各自複製了同一套東西，複製久了就開始分岔：列高 22 對 28、
-- 標題 24 對 26、字級 +1 對 +2、分隔線 8 對 13——同一條資訊列上的面板長得
-- 不一樣，使用者一眼就看出來了。
--
-- 所以**節奏與皮只能有一份**，就是這一支：
--   · 常數（2.1）是唯一真相來源，面板自己的檔案裡一個數字都不留。
--   · 控制器 HP.New（開關節奏、定位、戰鬥紀律）。
--   · 列層 rows（模型驅動、池化、自動套間距、自動量寬）。
-- 戰隊面板是**表格**不是清單，所以它走控制器與定位、**不走列層**
--（一列一個選項的排版套在多欄表格上只會把欄位擠壞）。
--
-- ⚠ 面板一律掛 UIParent、**不掛 bar**：bar 是 secure 按鈕的祖先＝隱式保護框，
--   掛在它底下的框戰鬥中 Show/Hide 不了。
--
-- ⚠⚠ secure = true 的面板（修裝：裡面有 SecureActionButtonTemplate 的按鈕）整張
--   連祖先都是保護框，戰鬥中 Show/Hide/SetPoint/SetSize 全部被封鎖。收面板不能
--   靠事件（延一幀派送，輪到我們時已經鎖上），要讓 secure 環境自己收：
--   SecureHandlerStateTemplate ＋ RegisterStateDriver ＋ _onstate-combat snippet。
--   Lua 這邊每一個會動到框的入口都先問 InCombatLockdown()，OnHide 的收尾延一幀
--   （那支有可能是 snippet 在戰鬥開始那一刻叫出來的，整條流程是暴雪的）。
--   見 .claude/notes/wow-121-addon-code-in-secure-stack.md
------------------------------------------------------------
local _, ns = ...

local W = ns.W
local P = ns.P

local HP = {}
ns.HoverPanel = HP

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 2.1 常數：唯一真相來源
--
-- 水平只有**一張三欄格線**，每一列（標題、項目、說明、設定入口）都用同一組座標：
--   [圖示／打勾 @PAD_X] [文字 @PAD_X+GUTTER] …… [右側標 @-PAD_X]
-- 圖示欄的規則是**整張面板一起決定**：只要有任何一列用到圖示或打勾，每一列都留
-- （只有有圖的列才縮排是業餘感最明顯的破綻）；整張都沒有就一列都不留，
-- 免得文字平白離左緣一截。修裝面板最上面那兩個自動修裝開關就是這樣讓整張
-- （含逐部位耐久那幾列）一起縮排的——那是規則生效，不是跑版。
--
-- 垂直只有**一個間距單位 G**：反白貼圖是整列寬高的，它碰到的不論是標題的髮絲線、
-- 分隔線還是面板邊緣，距離一律 G，滑過去才不會看到反白框忽寬忽窄。
------------------------------------------------------------
HP.TIP_BG  = 0.133           -- 提示皮的底（唯一真相來源是提示插件的 general.background）
HP.G       = 6               -- 間距單位
HP.PAD_X   = 10              -- 左右內距
HP.PAD_Y   = HP.G            -- 上下內距
HP.ROW_H   = 28              -- 內容列
HP.TITLE_H = 26              -- 標題列（髮絲線在底，線後再空 G）
HP.SEP_H   = HP.G * 2 + 1    -- 分隔線列：1px 的線置中 ⇒ 上下各 G
HP.ICON    = 22              -- 圖示邊長
HP.CHECK   = 14              -- 打勾邊長（跟圖示切齊左緣，共用同一個欄）
HP.GUTTER  = 30              -- 圖示欄：22 圖 ＋ 8 空
HP.TAG_GAP = 18              -- 主文字與右側標之間的最小間距
HP.MIN_W   = 220             -- 面板最小寬（三張統一）
HP.MAX_W   = 380             -- 再寬就是一塊擋畫面的板子了；超過就換行／夾住

-- 字級相對 db.fontSize（條上的字）。內容比條上大兩級——面板是「停下來看」的表面；
-- 標題仍然比內容**小**一級（階層規則：標題是後設資訊，要退到內容後面）。
-- ⚠ 相對值只寫在這裡，面板的 populate 裡不要再出現任何字級數字。
-- 說明列（note）跟標題同一級：它是補充語，不該跟可點的內容列一樣重。
HP.SZ_TEXT, HP.SZ_TITLE, HP.SZ_TAG, HP.SZ_NOTE = 2, 1, 1, 1

HP.TEXT_MAIN = { 0.92, 0.92, 0.92 }
HP.TEXT_DIM  = { 0.58, 0.58, 0.58 }

-- 開啟的意圖延遲：這些方塊夾在資訊列中間，游標橫掃過去找別顆按鈕時會經過它們，
-- 立刻開的話面板會閃一下。0.15 秒對「停下來看」的人感覺不到，對「路過」的人剛好躲掉。
-- 離開的寬限：斜著從方塊移到面板一定會經過空白，立刻關就永遠點不到裡面的東西。
HP.OPEN_DELAY, HP.CLOSE_DELAY = 0.15, 0.35

-- 本檔內用短名（對外仍然只有上面那一份）
local G, PAD_X, PAD_Y = HP.G, HP.PAD_X, HP.PAD_Y
local ROW_H, TITLE_H, SEP_H = HP.ROW_H, HP.TITLE_H, HP.SEP_H
local ICON, CHECK, GUTTER, TAG_GAP = HP.ICON, HP.CHECK, HP.GUTTER, HP.TAG_GAP
local MIN_W, MAX_W = HP.MIN_W, HP.MAX_W
local SZ_TEXT, SZ_TITLE, SZ_TAG, SZ_NOTE = HP.SZ_TEXT, HP.SZ_TITLE, HP.SZ_TAG, HP.SZ_NOTE
local TEXT_MAIN, TEXT_DIM = HP.TEXT_MAIN, HP.TEXT_DIM
local OPEN_DELAY, CLOSE_DELAY = HP.OPEN_DELAY, HP.CLOSE_DELAY

------------------------------------------------------------
-- 2.2 工具
------------------------------------------------------------
function HP.FontSize()
    return ns.GetDB().fontSize or 12
end

-- 相對字級記在 fontstring 身上（sizeDelta），db.fontSize 一變就靠 ApplyFont 套回去
function HP.MakeText(parent, delta)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs.sizeDelta = delta or 0
    fs:SetFont(ns.LOCALE_FONT, HP.FontSize() + fs.sizeDelta, "")
    fs:SetWordWrap(false)
    return fs
end

function HP.ApplyFont(fs)
    fs:SetFont(ns.LOCALE_FONT, HP.FontSize() + (fs.sizeDelta or 0), "")
end

-- 灰字的行內版本（接在主文字後面的補充語）。色碼直接由 TEXT_DIM 換算，
-- 兩處顏色才不會各走各的
local DIM_HEX = string.format("%02x%02x%02x",
    math.floor(TEXT_DIM[1] * 255 + 0.5),
    math.floor(TEXT_DIM[2] * 255 + 0.5),
    math.floor(TEXT_DIM[3] * 255 + 0.5))

function HP.Dim(str)
    return "|cff" .. DIM_HEX .. str .. "|r"
end

-- 提示皮（.claude/notes/project-miliui-hud-skin.md 的第二種變體）：
-- 0.133 不透明底 ＋ 1px 職業色硬邊 ＋ 白字 ＋ 直角。它是「彈出來給人讀內容」的
-- 表面，底色承載的是「讓字讀得出來」，所以不能透。
function HP.ApplyTipSkin(f)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
    f:SetBackdropColor(HP.TIP_BG, HP.TIP_BG, HP.TIP_BG, 1)
    f:SetBackdropBorderColor(W.Accent(1))
end

-- 面板上的扁平小按鈕：狀態只換明暗（HUD 皮的規則），沒有職業色——
-- 職業色在這些面板上是「邊框＝身分」與「反白＝游標在這」，再給按鈕用就三個語意撞在一起
function HP.SizeFlatButton(b)
    b:SetHeight(TITLE_H - 6)
    b:SetWidth(math.ceil(b.text:GetStringWidth()) + 12)
end

function HP.MakeFlatButton(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    -- 只收左鍵：這些鈕是「按下去就發生事情」的動作（隨機召喚、發送到隊伍頻道），
    -- 右鍵在面板上是「開選單」的語意，誤按不該當成左鍵
    b:RegisterForClicks("LeftButtonUp")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(1, 1, 1, 0.08)
    b:SetHighlightTexture(WHITE)
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.16)
    local fs = HP.MakeText(b, SZ_TAG)
    fs:SetPoint("CENTER")
    fs:SetTextColor(TEXT_MAIN[1], TEXT_MAIN[2], TEXT_MAIN[3])
    fs:SetText(text or "")
    b.text = fs
    if onClick then b:SetScript("OnClick", onClick) end
    HP.SizeFlatButton(b)
    return b
end

------------------------------------------------------------
-- 定位：先翻面、再平移（四張面板共用）
--
-- 預設往下長；下緣塞不下才翻成往上長（資訊列停在畫面最上面時往上一定撞）。
-- 水平貼齊方塊離畫面中線近的那一邊。翻完還出界才由 W.PlaceClamped 推回。
-- 偏移只有 2px——再多游標就會掉進面板與方塊中間的縫裡，路徑一斷面板就關了。
------------------------------------------------------------
function HP.PlaceBelow(frame, tile)
    if not (frame and tile) then return end
    local cx = tile:GetCenter()
    local ux = UIParent:GetCenter()
    local leftAlign = (cx or 0) <= (ux or 0)

    local pts = leftAlign
        and { "TOPLEFT",  tile, "BOTTOMLEFT",  0, -2 }
        or  { "TOPRIGHT", tile, "BOTTOMRIGHT", 0, -2 }
    frame:ClearAllPoints()
    frame:SetPoint(unpack(pts))

    local b, pb = frame:GetBottom(), UIParent:GetBottom()
    if b and pb and b < pb + W.SCREEN_PAD then
        pts = leftAlign
            and { "BOTTOMLEFT",  tile, "TOPLEFT",  0, 2 }
            or  { "BOTTOMRIGHT", tile, "TOPRIGHT", 0, 2 }
    end
    W.PlaceClamped(frame, pts)
end

------------------------------------------------------------
-- 2.4 列層：模型驅動、池化、自動套節奏、自動量寬
--
-- 呼叫端只組模型（見 rows:Render 上面的清單），座標、字級、間距一律由這裡決定。
------------------------------------------------------------
local function SetColor(fs, c)
    fs:SetTextColor(c[1], c[2], c[3])
end

local function RowEnter(row)
    row.rows.panel:CancelClose()
    if not row.clickable then return end
    row.hl:Show()
    -- 灰字的功能列（設定入口、還沒指定的快捷列）滑過變白：它平常要退到背景，
    -- 但滑上去必須看得出「這是可以點的」
    if row.dimText then row.text:SetTextColor(1, 1, 1) end
end

local function RowLeave(row)
    row.hl:Hide()
    if row.dimText then SetColor(row.text, TEXT_DIM) end
    row.rows.panel:ScheduleClose()
end

local function RowClick(row, button)
    if not row.clickable then return end
    if row.settingsTab then
        row.rows.panel:Hide()
        ns.OpenSettings(row.settingsTab)
        return
    end
    -- 右鍵沒有自己的動作就當左鍵：一列只有一件事可做的時候，按哪顆鍵都該做到
    if button == "RightButton" and row.onRightClick then
        row.onRightClick(row.data, row)
        return
    end
    if row.onClick then row.onClick(row.data, row) end
end

local Rows = {}
Rows.__index = Rows

function Rows:Get(index)
    local row = self.pool[index]
    if row then return row end

    local frame = self.panel.frame
    row = CreateFrame("Button", nil, frame)
    row.rows = self
    row:RegisterForClicks("AnyUp")

    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(W.Accent())
    row.hl:SetAlpha(0.25)
    row.hl:Hide()

    -- 三欄格線的座標在這裡定死一次，Render 不再逐列 SetPoint——
    -- 那正是好幾種左緣混進來的縫隙
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    -- 圖示邊緣那圈留白裁掉，方形圖示才貼得住 1px 的視覺語彙
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:SetPoint("LEFT", row, "LEFT", PAD_X, 0)

    -- 打勾：純白貼圖染強調色、勾形用圖集的 alpha 當遮罩摳（直接把圖集當貼圖染色會偏暗）。
    -- 圖集被拿掉是靜默失效，退回從古至今都在的 UI-CheckBox-Check（本來就只有勾沒有框）。
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(CHECK, CHECK)
    row.check:SetPoint("LEFT", row, "LEFT", PAD_X, 0)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("checkmark-minimal") then
        row.check:SetTexture(WHITE)
        local mask = row:CreateMaskTexture()
        mask:SetAtlas("checkmark-minimal")
        mask:SetAllPoints(row.check)
        row.check:AddMaskTexture(mask)
    else
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    row.check:Hide()

    row.text = HP.MakeText(row, SZ_TEXT)
    row.text:SetJustifyH("LEFT")
    -- 文字的 x 由 Fill 依「這張面板有沒有圖示欄」決定（row.textX），這裡不錨

    row.tag = HP.MakeText(row, SZ_TAG)
    row.tag:SetJustifyH("RIGHT")
    row.tag:SetPoint("RIGHT", row, "RIGHT", -PAD_X, 0)

    -- 標題底下的髮絲線：標題與內容之間要一條**結構性**的分隔，
    -- 光靠顏色不同還是會被讀成「另一個選項」
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", PAD_X, 0)
    row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -PAD_X, 0)
    row.rule:SetColorTexture(1, 1, 1, 0.10)

    row.sep = row:CreateTexture(nil, "ARTWORK")
    row.sep:SetHeight(1)
    row.sep:SetPoint("LEFT", row, "LEFT", PAD_X, 0)
    row.sep:SetPoint("RIGHT", row, "RIGHT", -PAD_X, 0)
    row.sep:SetColorTexture(1, 1, 1, 0.12)

    -- 標題右側的扁平鈕（例如分類旁的「隨機」）。列是池化的，所以動作查的是
    -- 當下填進去的 row.actionClick，不是建立時捕捉的閉包
    row.action = HP.MakeFlatButton(row, "", function(b)
        local fn = b:GetParent().actionClick
        if fn then fn() end
    end)
    row.action:SetPoint("RIGHT", row, "RIGHT", -PAD_X, 0)
    row.action:SetScript("OnEnter", function(b) RowEnter(b:GetParent()) end)
    row.action:SetScript("OnLeave", function(b) RowLeave(b:GetParent()) end)
    row.action:Hide()

    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)

    self.pool[index] = row
    return row
end

-- 填一列並回傳它「要多寬」。高度記在列身上，第二趟才不用再判斷一次 kind。
-- gutter 是這張面板這一次的圖示欄寬（GUTTER 或 0），文字起點跟著它走。
function Rows:Fill(row, item, gutter)
    HP.ApplyFont(row.text)
    HP.ApplyFont(row.tag)
    HP.ApplyFont(row.action.text)

    -- 欄寬沒變就不重錨：SetPoint 不便宜，而重畫很頻繁
    local textX = PAD_X + gutter
    if row.textX ~= textX then
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row, "LEFT", textX, 0)
        row.textX = textX
    end

    row.data = item.data
    row.onClick = item.onClick
    row.onRightClick = item.onRightClick
    row.settingsTab = nil
    row.actionClick = nil
    row.clickable = false
    row.dimText = nil
    row.hl:Hide()
    row.rule:Hide()
    row.sep:Hide()
    row.icon:Hide()
    row.check:Hide()
    row.tag:Hide()
    row.action:Hide()
    row.text:SetText("")
    row:EnableMouse(false)
    row.h = ROW_H

    local kind = item.kind
    local need = 0

    if kind == "sep" then
        row.h = SEP_H
        row.sep:Show()

    elseif kind == "title" then
        -- 標題比內容**弱**：灰、小一級、底下一條髮絲線
        row.h = TITLE_H
        row.text:SetFont(ns.LOCALE_FONT, HP.FontSize() + SZ_TITLE, "")
        row.text:SetText(item.text)
        SetColor(row.text, TEXT_DIM)
        row.rule:Show()
        need = textX + row.text:GetStringWidth() + PAD_X
        if item.action then
            row.action.text:SetText(item.action.text)
            HP.SizeFlatButton(row.action)
            row.actionClick = item.action.onClick
            row.action:Show()
            need = need + TAG_GAP + row.action:GetWidth()
        end

    elseif kind == "note" then
        row.text:SetFont(ns.LOCALE_FONT, HP.FontSize() + SZ_NOTE, "")
        row.text:SetText(item.text)
        SetColor(row.text, TEXT_DIM)
        need = textX + row.text:GetStringWidth() + PAD_X

    elseif kind == "settings" then
        -- 最底下的功能列：灰字、整列可點、滑過變白。
        -- 「這些東西在哪裡改」是玩家第一天就會問的問題，用一行可點的列回答
        row:EnableMouse(true)
        row.clickable = true
        row.dimText = true
        row.settingsTab = item.tab
        row.text:SetText(item.text)
        SetColor(row.text, TEXT_DIM)
        need = textX + row.text:GetStringWidth() + PAD_X

    else   -- item
        if item.onClick or item.onRightClick then
            row:EnableMouse(true)
            row.clickable = true
        end
        if item.icon then
            row.icon:SetTexture(item.icon)
            row.icon:Show()
        end

        local text = item.text or ""
        if item.suffix then text = text .. " " .. HP.Dim(item.suffix) end
        row.text:SetText(text)

        if item.check then
            -- 開著＝強調色字＋打勾：顏色以外還有圖示這第二個訊號（顏色那層最不可靠）
            row.check:SetVertexColor(W.Accent())
            row.check:Show()
            row.text:SetTextColor(W.Accent())
        elseif item.dim then
            row.dimText = true
            SetColor(row.text, TEXT_DIM)
        else
            SetColor(row.text, TEXT_MAIN)
        end

        need = textX + row.text:GetStringWidth() + PAD_X
        if item.tag then
            -- 右側標預設灰色：它是**狀態讀數**（這一列歸哪顆鍵、剩多少耐久），
            -- 不是「這一列被選中了」。要換顏色的（耐久百分比）自己帶 tagColor
            row.tag:SetText(item.tag)
            local c = item.tagColor or TEXT_DIM
            row.tag:SetTextColor(c[1], c[2], c[3])
            row.tag:Show()
            need = need + TAG_GAP + row.tag:GetStringWidth()
        end
    end

    return need
end

------------------------------------------------------------
-- rows:Render(model)：兩趟排版
--
-- 模型的項目：
--   { kind = "title",    text = "…", action = { text = "…", onClick = fn } }
--   { kind = "item",     icon = tex, check = bool, text = "…", suffix = "…",
--                        tag = "…", tagColor = {r,g,b}, dim = bool,
--                        onClick = fn, onRightClick = fn, data = any }
--   { kind = "sep" }
--   { kind = "note",     text = "灰字說明" }
--   { kind = "settings", text = "…", tab = "分頁 id" }
--   { kind = "custom",   measure = function() return minW end,
--                        layout  = function(frame, y, width) return h end }
--
-- 為什麼要兩趟：寬度要等所有項目都量完才知道，而 custom（例如會換行的圖示排）
-- 得先知道最終寬度才擺得出來。第一趟量、第二趟擺。
------------------------------------------------------------
function Rows:Render(model)
    local panel = self.panel
    local frame = panel.frame
    local width = MIN_W
    local used = 0

    -- 圖示欄整張一起決定：有任何一列帶圖示或打勾（含沒勾的開關列）才留
    local gutter = 0
    for _, item in ipairs(model) do
        if item.kind == "item" and (item.icon or item.check ~= nil) then
            gutter = GUTTER
            break
        end
    end

    for _, item in ipairs(model) do
        if item.kind == "custom" then
            -- custom 自己決定要多寬（該夾 MAX_W 的在它自己的 measure 裡夾）
            local need = item.measure and item.measure() or 0
            if need > width then width = math.ceil(need) end
        else
            used = used + 1
            local row = self:Get(used)
            item.row = row
            local need = self:Fill(row, item, gutter)
            if need > MAX_W then need = MAX_W end
            if need > width then width = math.ceil(need) end
        end
    end

    local y = PAD_Y
    for i, item in ipairs(model) do
        if item.kind == "custom" then
            -- custom 前後不加東西：間距由它的 layout 自己決定（回傳的高度含它留的白）
            y = y + (item.layout and item.layout(frame, y, width) or 0)
        else
            -- 區段之間的留白：標題**前面**留 G，第一個項目不用（面板上緣已經有 PAD_Y）
            if item.kind == "title" and i > 1 then y = y + G end
            local row = item.row
            row:SetHeight(row.h)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -y)
            row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -y)
            row:Show()
            -- 游標正停在這列上時重畫（按了開關型項目），滑過狀態要接回來
            if row.clickable and row:IsMouseOver() then RowEnter(row) end
            y = y + row.h
            -- 標題的髮絲線畫在它自己的下緣：線之後空 G，第一列的反白才不會貼著線
            if item.kind == "title" then y = y + G end
        end
    end

    for i = used + 1, #self.pool do self.pool[i]:Hide() end
    -- +2 ＝ 列左右各內縮 1px 讓出邊框的那兩格
    frame:SetSize(width + 2, y + PAD_Y)
end

------------------------------------------------------------
-- 2.3 面板控制器
--
--   local panel = HP.New({ name = "…", secure = false, allowCombat = false,
--                          build = fn, beforeOpen = fn, populate = fn,
--                          onOpen = fn, onHide = fn, keepOpen = fn })
--   panel:ScheduleOpen(tile) / CancelOpen() / Open(tile)
--   panel:ScheduleClose()    / CancelClose() / Hide()
--   panel:IsOpenFor(tile)    / Refresh()     / panel.frame
--
-- secure      = 面板裡有 secure 按鈕（修裝）⇒ state driver 收面板、每個入口先問
--               InCombatLockdown、onHide 延一幀
-- allowCombat = 戰鬥中照樣開得起來、也不自動收（戰隊表格：純讀的資料）
-- beforeOpen  = Build 之後、Populate 之前跑一次（「開啟」這件事專屬的前置）
-- keepOpen    = 回 true 就延後這一輪的關閉（面板上開著自己的選單時）
------------------------------------------------------------
local Panel = {}
Panel.__index = Panel

-- 戰鬥中動得了框嗎？只有 secure 面板要問（它是保護框）
local function Locked(self)
    return self.spec.secure and InCombatLockdown()
end

function Panel:Build()
    if self.frame then return self.frame end
    local spec = self.spec

    local f = CreateFrame("Frame", spec.name, UIParent,
        spec.secure and "SecureHandlerStateTemplate,BackdropTemplate" or "BackdropTemplate")
    self.frame = f          -- 先掛上：spec.build 可能要用 panel.frame
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    HP.ApplyTipSkin(f)
    W.CloseOnEscape(f)

    if spec.secure then
        -- ⚠ 進戰鬥由 secure 環境自己收（檔頭說明）。屬性要在註冊 driver **之前**
        --   寫好，driver 一註冊就會立刻推一次目前的狀態。
        f:SetAttribute("_onstate-combat", [[
            if newstate == "1" then
                self:Hide()
            end
        ]])
        RegisterStateDriver(f, "combat", "[combat] 1; 0")
    end

    f:SetScript("OnEnter", function() self:CancelClose() end)
    f:SetScript("OnLeave", function() self:ScheduleClose() end)
    f:SetScript("OnHide", function()
        self.anchorTile = nil       -- 純 Lua 指派，沒有引擎呼叫，當場做沒問題
        local onHide = spec.onHide
        if not onHide then return end
        if spec.secure then
            -- ⚠⚠ 這支**有可能是上面那個 secure snippet 叫出來的**（戰鬥開始那一刻）。
            --   那時整條執行流程是暴雪的——在裡面碰 GameTooltip、退訂事件，等於把
            --   taint 注進那條流程，之後暴雪自己做的每件事都算在資訊列頭上。
            ns.NextFrame(spec.name, function()
                -- 同一幀內又被 Open 回來的話，這裡拆的就是新開那次剛掛上的東西
                if f:IsShown() then return end
                onHide(f)
            end)
        else
            onHide(f)
        end
    end)

    f:Hide()
    if spec.build then spec.build(f) end
    return f
end

function Panel:Populate()
    if Locked(self) then return end     -- 重畫會寫 secure 屬性，戰鬥中一律不跑
    self.spec.populate(self.rows, self.frame)
end

function Panel:Place()
    if not (self.frame and self.anchorTile) then return end
    if Locked(self) then return end     -- 保護框，戰鬥中 SetPoint 會被擋
    HP.PlaceBelow(self.frame, self.anchorTile)
end

-- 開著的期間資料變了就重畫；高度變了翻面結果可能不同，所以要再定位一次
function Panel:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    if Locked(self) then return end
    self:Populate()
    self:Place()
end

function Panel:CancelClose()
    self.closeGen = self.closeGen + 1
end

function Panel:CancelOpen()
    self.openGen = self.openGen + 1
end

function Panel:IsOpenFor(tile)
    return self.frame and self.frame:IsShown() and self.anchorTile == tile
end

function Panel:Hide()
    self:CancelClose()
    if not (self.frame and self.frame:IsShown()) then return end
    -- 戰鬥中 state driver 已經把它收掉了，這裡再叫一次只會換來一則 ADDON_ACTION_BLOCKED
    if Locked(self) then return end
    self.frame:Hide()
end

function Panel:Open(tile)
    -- 戰鬥中一律不開：三張滑過面板的內容（召喚、修裝、開怪倒數）戰鬥中不是用不了
    -- 就是只會擋畫面，方塊那邊會退回純顯示的提示。
    -- 例外 allowCombat：戰隊表格是純讀的資料（鑰石、寶庫進度），戰鬥中看它沒有
    -- 任何壞處，而且它掛 UIParent、不是保護框，Show/Hide 都合法。
    if not self.spec.allowCombat and InCombatLockdown() then return end
    self:Build()
    self:CancelClose()
    self.anchorTile = tile
    -- beforeOpen 是「Populate 之前只做一次」的位置（戰隊面板在這裡刷新自己那筆
    -- 記錄）。放進 populate 的話，開著期間每次 listener 重畫都會再刷一次，
    -- 而刷新本身又會發通知——繞回來就是一圈。
    if self.spec.beforeOpen then self.spec.beforeOpen(self.frame) end
    self:Populate()
    self.frame:Show()
    self:Place()
    if self.spec.onOpen then self.spec.onOpen(self.frame) end
end

function Panel:ScheduleClose()
    self.closeGen = self.closeGen + 1
    local gen = self.closeGen
    C_Timer.After(CLOSE_DELAY, function()
        if gen ~= self.closeGen then return end             -- 已被新的動作取代
        local f = self.frame
        if not (f and f:IsShown()) then return end
        if Locked(self) then return end
        -- 判斷放在**到期時**：游標中途繞進面板（或繞回方塊）也算數
        if f:IsMouseOver() then return end
        if self.anchorTile and self.anchorTile:IsMouseOver() then return end
        -- keepOpen：面板上開著自己的選單時游標必然在面板**外**，而選單一關之後
        -- 不會再有任何 OnLeave 把我們叫回來 ⇒ 不能只是「這次不關」，要自己再排
        -- 一次，下一輪到期時選單已經關了就正常收掉
        if self.spec.keepOpen and self.spec.keepOpen() then
            self:ScheduleClose()
            return
        end
        f:Hide()
    end)
end

-- 方塊的 OnEnter 走這支：已經為這顆開著就只是取消關閉；否則等意圖延遲到期、
-- 游標還在方塊上才真的開
function Panel:ScheduleOpen(tile)
    if self:IsOpenFor(tile) then
        self:CancelClose()
        return
    end
    self.openGen = self.openGen + 1
    local gen = self.openGen
    C_Timer.After(OPEN_DELAY, function()
        if gen ~= self.openGen then return end
        if not tile:IsMouseOver() then return end
        self:Open(tile)
    end)
end

function HP.New(spec)
    local panel = setmetatable({ spec = spec, closeGen = 0, openGen = 0 }, Panel)
    panel.rows = setmetatable({ panel = panel, pool = {} }, Rows)
    -- 非 secure 的面板進戰鬥直接收（它不是保護框，Hide 合法）。
    -- secure 的那張由 _onstate-combat snippet 收，不能走事件——事件延一幀派送，
    -- 輪到我們的時候已經鎖上了。
    -- allowCombat 的那張兩邊都不收：戰鬥中開著看資料是它既有的行為。
    if not (spec.secure or spec.allowCombat) then
        ns.Events.Register("PLAYER_REGEN_DISABLED", spec.name, function() panel:Hide() end)
    end
    return panel
end
