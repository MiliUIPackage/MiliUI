------------------------------------------------------------
-- 坐騎：滑過方塊彈出來的面板
--
-- 皮走「提示皮」（.claude/notes/project-miliui-hud-skin.md 的第二種變體）：
-- 0.133 不透明底 ＋ 1px 職業色硬邊 ＋ 白字 ＋ 直角。跟戰隊面板同一套。
--
-- ⚠ 掛 UIParent、**不掛 bar**：bar 是 secure 按鈕的祖先＝隱式保護框，掛在它
--   底下的框在戰鬥中 Show/Hide 不了。這個面板不是保護框，戰鬥開始時直接 Hide
--   是合法的。
--
-- 開關的節奏（滑過開啟的面板最容易做壞的地方）：
--   · 方塊與面板的 OnLeave 都只**排程**關閉（0.35 秒），任一方的 OnEnter 取消。
--     斜著從方塊移到面板一定會經過空白，立刻關就永遠點不到裡面的東西。
--     用世代 token 讓舊排程作廢——做法同共用層 ContextMenu.lua 的 SUB_CLOSE_DELAY。
--   · 面板與方塊之間**不留縫**（偏移 2px 以內），游標不會掉進兩者中間。
--
-- 版面的兩條規矩（2026-09-14 使用者看截圖說「排列凌亂」「反白的上下差距不同」
-- 之後定的，細節見下面兩段常數的註解）：
--   1. 水平只有**一張三欄格線**，每一列都用同一組座標。
--   2. 垂直只有**一個間距單位 G**，反白列碰到的線與邊距離一律相同。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local P = ns.P
local Mounts = ns.Mounts

ns.MountPopup = {}
local Popup = ns.MountPopup

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 版面常數
--
-- ⚠ 這裡刻意**不跟**共用層 ContextMenu.lua 的尺寸（22/21/7）：那是右鍵選單，
-- 點完就走；這張面板是玩家自訂分類、停下來讀的東西，用選單的密度會擠。
-- 2026-09-14 使用者回饋「面板要再大一點」之後整組放大一階。
------------------------------------------------------------
local TIP_BG       = 0.133
local ROW_H        = 28
local TITLE_H      = 26
local ICON         = 22
local MIN_W        = 260
local CLOSE_DELAY  = 0.35

------------------------------------------------------------
-- 水平：整張面板只有**一張三欄格線**
--
--   [圖示 @PAD_X] [名字 @PAD_X+GUTTER] …… [右側標 @-PAD_X]
--
-- 每一列（快捷、坐騎、標題、說明、設定入口）都用同一組座標，所以圖示永遠在
-- 同一欄、名字永遠在同一條線上。⚠ 快捷列曾經自己多一個「左鍵」標籤欄，
-- 於是它的圖示跟底下分類的圖示差了一整個標籤寬——使用者的回饋就是「排列凌亂」。
-- 那一欄現在收進右側標了（跟分類列共用同一組 MOUNT_BIND_* 詞彙）。
------------------------------------------------------------
local PAD_X        = 10      -- 左右內距
local GUTTER       = 30      -- 圖示欄：22px 圖 ＋ 8px 空。**每一列都留**，文字才對齊
local TAG_GAP      = 18      -- 名字與右側小標之間的最小間距

------------------------------------------------------------
-- 垂直：所有「反白 ↔ 線／面板邊」的距離都是 G
--
-- 反白貼圖是整列寬、整列高的，所以一列的上下鄰居只要距離不一致，滑過去就會
-- 看到反白框忽寬忽窄——使用者說的「上下差距不同，有點疙瘩」。
-- 統一成一個常數之後，反白框碰到的不論是標題的髮絲線、分隔線還是面板邊緣，
-- 距離一律 G。（相鄰兩個反白列之間仍然是 0：同一時間只有一列會反白。）
------------------------------------------------------------
local G            = 6
local PAD_Y        = G       -- 面板上下內距
local SEP_H        = G * 2 + 1   -- 分隔線列：1px 的線置中 ⇒ 上下各 G

-- 字級相對 db.fontSize（條上的字）。內容比條上大兩級——面板有空間，而且它是
-- 「停下來看」的表面；標題仍然比內容**小**一級（階層規則沒變：標題要退後）。
-- ⚠ 相對值只寫在這裡，Populate 裡不要再出現任何字級數字。
local SZ_TEXT      = 2       -- 坐騎名、說明列、設定入口列
local SZ_TITLE     = 1       -- 分類標題
local SZ_TAG       = 1       -- 右側小標（左／右）與「隨機」鈕
-- 開啟也要一點意圖延遲：資訊列上這顆方塊夾在耐久與微型選單中間，游標橫掃過去
-- 找別顆按鈕時會經過它，立刻開的話面板會閃一下。0.15 秒對「停下來看」的人
-- 感覺不到，對「路過」的人剛好躲掉。
local OPEN_DELAY   = 0.15

local TEXT_MAIN = { 0.92, 0.92, 0.92 }
local TEXT_DIM  = { 0.58, 0.58, 0.58 }

local FALLBACK_ICON = "Interface\\Icons\\Ability_Mount_RidingHorse"
Popup.FALLBACK_ICON = FALLBACK_ICON

local frame
local rows = {}
local anchorTile
local closeGen = 0
local openGen = 0

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function FontSize()
    return ns.GetDB().fontSize or 12
end

local function MakeText(parent, delta)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.LOCALE_FONT, FontSize() + (delta or 0), "")
    fs:SetWordWrap(false)
    fs.sizeDelta = delta or 0
    return fs
end

local function Dim(str)
    return "|cff949494" .. str .. "|r"
end

local function ApplyTipSkin(f)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
    f:SetBackdropColor(TIP_BG, TIP_BG, TIP_BG, 1)
    f:SetBackdropBorderColor(W.Accent(1))
end

-- 面板上的扁平小按鈕：狀態只換明暗（HUD 皮的規則），沒有職業色
local function MakeFlatButton(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("AnyUp")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(1, 1, 1, 0.08)
    b:SetHighlightTexture(WHITE)
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.16)
    local fs = MakeText(b, SZ_TAG)
    fs:SetPoint("CENTER")
    fs:SetTextColor(TEXT_MAIN[1], TEXT_MAIN[2], TEXT_MAIN[3])
    fs:SetText(text)
    b.text = fs
    b:SetScript("OnClick", onClick)
    return b
end

local function SizeFlatButton(b)
    b:SetHeight(TITLE_H - 6)
    b:SetWidth(math.ceil(b.text:GetStringWidth()) + 12)
end

------------------------------------------------------------
-- 開關（排程 ＋ 世代 token）
------------------------------------------------------------
function Popup.CancelClose()
    closeGen = closeGen + 1
end

function Popup.CancelOpen()
    openGen = openGen + 1
end

function Popup.Hide()
    Popup.CancelClose()
    if frame then frame:Hide() end
end

function Popup.ScheduleClose()
    closeGen = closeGen + 1
    local gen = closeGen
    C_Timer.After(CLOSE_DELAY, function()
        if gen ~= closeGen then return end                  -- 已被新的動作取代
        if not (frame and frame:IsShown()) then return end
        -- 判斷放在**到期時**：游標中途繞進面板（或繞回方塊）也算數
        if frame:IsMouseOver() then return end
        if anchorTile and anchorTile:IsMouseOver() then return end
        frame:Hide()
    end)
end

function Popup.IsOpenFor(tile)
    return frame and frame:IsShown() and anchorTile == tile
end

------------------------------------------------------------
-- 列（池化：frame 刪不掉，一律重用）
------------------------------------------------------------
local function RowEnter(self)
    Popup.CancelClose()
    if not self.clickable then return end
    if self.hl then self.hl:Show() end
    -- 灰字的功能列（最底那條設定入口）滑過變白：它平常要退到背景，
    -- 但滑上去必須看得出「這是可以點的」
    if self.dimText then self.text:SetTextColor(1, 1, 1) end
end

local function RowLeave(self)
    if self.hl then self.hl:Hide() end
    if self.dimText then self.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3]) end
    Popup.ScheduleClose()
end

-- 右鍵選單：把它錨在游標上而不是這一列。列會隨著面板關掉而消失，
-- 選單卻是掛 UIParent 的共用框——錨在會消失的東西上，位置就不可信。
local function ShowRowMenu(spellID)
    local items = {
        { isTitle = true, text = Mounts.Name(spellID) },
        {
            text = L["MOUNT_SET_LEFT"],
            isActive = (Mounts.Profile().left == spellID),
            onClick = function() Mounts.SetAssigned("left", spellID) end,
        },
        {
            text = L["MOUNT_SET_RIGHT"],
            isActive = (Mounts.Profile().right == spellID),
            onClick = function() Mounts.SetAssigned("right", spellID) end,
        },
        { isSeparator = true },
        {
            text = L["MOUNT_MENU_SETTINGS"],
            onClick = function() ns.OpenSettings("mounts") end,
        },
    }
    Popup.Hide()
    W.Menu.Show(items)
end

local function RowClick(self, button)
    if not self.clickable then return end
    if button == "RightButton" then
        if self.spellID then ShowRowMenu(self.spellID) end
        return
    end
    if self.spellID then
        Popup.Hide()
        Mounts.Summon(self.spellID)
    else
        -- 這顆鍵還沒有坐騎：帶玩家去設定，而不是安靜地什麼都沒發生
        Popup.Hide()
        ns.OpenSettings("mounts")
    end
end

local function GetRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame("Button", nil, frame)
    row:RegisterForClicks("AnyUp")

    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(W.Accent())
    row.hl:SetAlpha(0.25)
    row.hl:Hide()

    -- 三欄格線的座標在這裡定死一次，Populate 不再逐列 SetPoint——
    -- 那正是三種左緣混進來的縫隙
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    -- 圖示邊緣那圈留白裁掉，方形圖示才貼得住 1px 的視覺語彙
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:SetPoint("LEFT", row, "LEFT", PAD_X, 0)

    row.text = MakeText(row, SZ_TEXT)
    row.text:SetJustifyH("LEFT")
    row.text:SetPoint("LEFT", row, "LEFT", PAD_X + GUTTER, 0)

    row.tag = MakeText(row, SZ_TAG)
    row.tag:SetPoint("RIGHT", row, "RIGHT", -PAD_X, 0)
    row.tag:SetJustifyH("RIGHT")

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

    row.random = MakeFlatButton(row, L["MOUNT_RANDOM"], function(self)
        local i = self:GetParent().catIndex
        if i then
            Popup.Hide()
            Mounts.RandomIn(i)
        end
    end)
    row.random:SetPoint("RIGHT", row, "RIGHT", -PAD_X, 0)
    row.random:SetScript("OnEnter", RowEnter)
    row.random:SetScript("OnLeave", RowLeave)

    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)

    rows[index] = row
    return row
end

-- isTitle 是這一列唯一會換字級的地方（標題比內容小一級）。其餘的相對值都在
-- 建立時的 sizeDelta 裡，這裡只是把 db.fontSize 的變動套回去。
local function ApplyRowFont(row, isTitle)
    local size = FontSize()
    for _, fs in ipairs({ row.text, row.tag, row.random.text }) do
        fs:SetFont(ns.LOCALE_FONT, size + fs.sizeDelta, "")
    end
    if isTitle then
        row.text:SetFont(ns.LOCALE_FONT, size + SZ_TITLE, "")
    end
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
local function BuildModel()
    local model = {}

    -- 快捷區＝跟分類**一模一樣**的一個區段（標題 ＋ 兩列），差別只有沒有隨機鈕。
    -- 區段之間靠「留白 ＋ 標題的髮絲線」就分得開了，所以這裡**不畫分隔線**——
    -- 分隔線只留給「內容」與最底下那條功能列之間。
    model[#model + 1] = { kind = "title", text = L["MOUNT_SECTION_SHORTCUTS"] }
    for _, side in ipairs({ "left", "right" }) do
        model[#model + 1] = {
            kind    = "shortcut",
            side    = side,
            spellID = Mounts.Assigned(side),
            auto    = Mounts.IsAuto(side),
        }
    end

    local any = false
    for index, cat in ipairs(Mounts.Categories()) do
        local list = {}
        for _, spellID in ipairs(cat.spells or {}) do
            local info = Mounts.Info(spellID)
            -- 判準是 available 不是 collected：未收藏的不列（面板是拿來用的，
            -- 不是拿來看目標的），另一個陣營的版本也不列——不然同一隻長毛象
            -- 會在修裝分類裡出現兩次，而其中一隻點了只會跳訊息
            if info and info.available then list[#list + 1] = info end
        end
        if #list > 0 then
            model[#model + 1] = {
                kind     = "title",
                text     = Mounts.CategoryName(cat),
                catIndex = index,
                random   = #list >= 2,       -- 只有一隻的話「隨機」沒有意義
                gap      = true,             -- 跟上一個區段（至少有快捷區）隔開
            }
            any = true
            for _, info in ipairs(list) do
                model[#model + 1] = { kind = "mount", info = info }
            end
        end
    end

    if not any then
        model[#model + 1] = { kind = "note", text = L["MOUNT_EMPTY"], gap = true }
        model[#model + 1] = { kind = "note", text = L["MOUNT_EMPTY_SUB"] }
    end

    -- 設定入口永遠在最底下。空清單時最需要它——「我的坐騎清單在哪裡改」
    -- 正是使用者第一天就問的問題。
    model[#model + 1] = { kind = "sep" }
    model[#model + 1] = { kind = "settings", text = L["MOUNT_POPUP_SETTINGS"] }
    return model
end

local BOUND_LABEL = {
    left  = "MOUNT_BIND_LEFT",
    right = "MOUNT_BIND_RIGHT",
    both  = "MOUNT_BIND_BOTH",
}

local function Populate()
    local model = BuildModel()

    local width = MIN_W
    local y = PAD_Y

    for i, item in ipairs(model) do
        if item.gap then y = y + G end        -- 區段之間
        local row = GetRow(i)
        ApplyRowFont(row, item.kind == "title")
        row.catIndex = item.catIndex
        row.spellID = nil
        row.clickable = false
        row.dimText = nil
        row.hl:Hide()
        row.rule:Hide()
        row.sep:Hide()
        row.icon:Hide()
        row.tag:Hide()
        row.random:Hide()

        local h = ROW_H
        local need = 0

        if item.kind == "sep" then
            h = SEP_H
            row.text:SetText("")
            row.sep:Show()
            row:EnableMouse(false)

        elseif item.kind == "note" then
            row.text:SetText(item.text)
            row.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
            row:EnableMouse(false)
            need = PAD_X + GUTTER + row.text:GetStringWidth() + PAD_X

        elseif item.kind == "settings" then
            -- 最底下的功能列：灰字、整列可點、滑過變白（同設定頁「＋ 新增坐騎…」）。
            -- spellID 留 nil，RowClick 就會走「開設定」那條路
            row:EnableMouse(true)
            row.clickable = true
            row.dimText = true
            row.text:SetText(item.text)
            row.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
            need = PAD_X + GUTTER + row.text:GetStringWidth() + PAD_X

        elseif item.kind == "title" then
            -- 標題比內容**弱**：灰、小一級、底下一條髮絲線（選單設計標準）
            h = TITLE_H
            row.text:SetText(item.text)
            row.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
            row.rule:Show()
            row:EnableMouse(false)
            need = PAD_X + GUTTER + row.text:GetStringWidth() + PAD_X
            if item.random then
                SizeFlatButton(row.random)
                row.random:Show()
                need = need + TAG_GAP + row.random:GetWidth()
            end

        else
            -- 快捷列與坐騎列走**同一段**排版：兩者的差別只有「名字從哪來」與
            -- 右側標寫什麼，位置一個字都不用改
            row:EnableMouse(true)
            row.clickable = true
            local info, name, iconTex, tag

            if item.kind == "shortcut" then
                info = item.spellID and Mounts.Info(item.spellID) or nil
                if info then
                    name = (info.name or "?") .. (item.auto and (" " .. Dim(L["MOUNT_AUTO"])) or "")
                    iconTex = info.icon
                else
                    name = Dim(L["MOUNT_UNSET"])
                    iconTex = FALLBACK_ICON
                end
                tag = L[item.side == "left" and "MOUNT_BIND_LEFT" or "MOUNT_BIND_RIGHT"]
            else
                info = item.info
                name = info.name or "?"
                iconTex = info.icon
                local bound = Mounts.BoundSide(info.spellID)
                if bound then tag = L[BOUND_LABEL[bound]] end
            end

            if tag then
                -- 灰色：它是狀態讀數（這一列歸哪顆鍵），不是「這一列被選中了」
                row.tag:SetText(tag)
                row.tag:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
                row.tag:Show()
            end

            row.spellID = info and info.spellID or nil
            row.icon:SetTexture(iconTex or FALLBACK_ICON)
            row.icon:Show()
            row.text:SetText(name)
            row.text:SetTextColor(TEXT_MAIN[1], TEXT_MAIN[2], TEXT_MAIN[3])

            need = PAD_X + GUTTER + row.text:GetStringWidth() + PAD_X
            if row.tag:IsShown() then
                need = need + TAG_GAP + row.tag:GetStringWidth()
            end
        end

        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -y)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -y)
        row:Show()
        y = y + h
        -- 標題的髮絲線畫在它自己的下緣：線之後空 G，第一列的反白才不會貼著線
        if item.kind == "title" then y = y + G end
        if need > width then width = math.ceil(need) end
    end

    for i = #model + 1, #rows do rows[i]:Hide() end
    -- +2 ＝ 列左右各內縮 1px 讓出邊框的那兩格
    frame:SetSize(width + 2, y + PAD_Y)
end

------------------------------------------------------------
-- 建框
------------------------------------------------------------
local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "MiliUIInfoBar_MountPopup", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    ApplyTipSkin(frame)
    W.CloseOnEscape(frame)
    frame:SetScript("OnEnter", function() Popup.CancelClose() end)
    frame:SetScript("OnLeave", function() Popup.ScheduleClose() end)
    frame:SetScript("OnHide", function()
        anchorTile = nil
        Mounts.RemoveListener("popup")
    end)
    frame:Hide()
    return frame
end

------------------------------------------------------------
-- 定位：先翻面、再平移（同 Core/WarbandPopup.lua）
--
-- 預設往下長；下緣塞不下才翻成往上長（資訊列停在畫面最上面時往上一定撞）。
-- 水平貼齊方塊離畫面中線近的那一邊。偏移只有 2px——再多游標就會掉進縫裡。
------------------------------------------------------------
local function Place()
    local tile = anchorTile
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
-- 對外
------------------------------------------------------------
function Popup.Open(tile)
    if InCombatLockdown() then return end       -- 戰鬥中召喚不了，開了也只是擋畫面
    Build()
    Popup.CancelClose()
    anchorTile = tile
    Populate()
    frame:Show()
    Place()

    -- 開著的期間資料變了就重畫；高度變了翻面結果可能不同，所以要再定位一次
    Mounts.AddListener("popup", function()
        if not frame:IsShown() then return end
        Populate()
        Place()
    end)
end

-- 方塊的 OnEnter 走這支：已經為這顆開著就只是取消關閉；否則等意圖延遲到期、
-- 游標還在方塊上才真的開
function Popup.ScheduleOpen(tile)
    if Popup.IsOpenFor(tile) then
        Popup.CancelClose()
        return
    end
    openGen = openGen + 1
    local gen = openGen
    C_Timer.After(OPEN_DELAY, function()
        if gen ~= openGen then return end
        if not tile:IsMouseOver() then return end
        Popup.Open(tile)
    end)
end

ns.Events.Register("PLAYER_REGEN_DISABLED", "mount-popup", Popup.Hide)
