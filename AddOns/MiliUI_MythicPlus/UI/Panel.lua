------------------------------------------------------------
-- 結算面板
--
-- 一場一張表：表頭兩行（鑰石／時間／結果／評分），底下每人一列。
--
-- 版面（欄位是使用者指定的，順序不要自己調）：
--
--   +14 副本名                          [ +14 副本名  9/21 01:14 ▾ ] [×]
--   32:47 / 28:00   超時   19 死亡 (-4:45)              評分 3206 (+12)
--
--       玩家          分數  戰利品      輸出      承傷  可迴避傷害   中斷  驅散  死亡
--   ─────────────────────────────────────────────────────────────────
--   [圖] 名字         3206  [圖][圖]   294.1K   52.10M      4.20M     7     3     4
--
-- ⚠ 顏色的分配（見 miliui-color-states）：
--   * 數字一律白字。輸出最高的那一列不特別上色 —— 排序本身就說明了名次。
--   * 名字用職業色：這裡顏色承載的是「這是誰」，是允許的身分色。
--   * 分數用稀有度色：同理，那是暴雪定義的身分色。
--   * 「+等級」依結果換色（準時綠／超時紅），**只有那一個字換**，副本名維持白字。
--     一個視覺訊號只能有一個語意，整行一起染色的話「白字＝一般資訊」就失效了。
--
-- ⚠ 有標題的小節前面不放收尾隔線：表頭兩行與欄位標題之間只有留白，
--   髮絲線畫在欄位標題**底下**（那條線的語意是「以下是內容」）。
--
-- ⚠ 五列固定建、永不銷毀。WoW 的 frame 刪不掉（Hide 只是藏起來），
--   換場次時只填值不重建。
--
-- ⚠ 這個面板是自己建的非保護框：戰鬥中顯示／隱藏都合法，而且它**完全不碰任何
--   暴雪的框**（不 hook、不寫欄位、不改別人的錨點）。
------------------------------------------------------------
local _, ns = ...

ns.Panel = {}
local Panel = ns.Panel

local S  = ns.Style
local L  = ns.L
local H  = ns.History
local Sec = ns.Secret

------------------------------------------------------------
-- 版面常數：欄位的右緣（距面板左緣）集中在這裡，表頭與資料列共用同一組數字
------------------------------------------------------------
local PANEL_W   = 680
local PAD       = 10
local ROW_H     = 21
local HEAD_H    = 52     -- 表頭兩行那一塊（同時是拖曳把手）
local HEADROW_H = 16     -- 欄位標題列
local MAX_ROWS  = 5      -- 鑰石就是五個人

local ICON_SIZE = 18
local LOOT_MAX  = 2
local LOOT_GAP  = 2

local COL = {
    nameX    = PAD + ICON_SIZE + 6,   -- 名字的左緣
    nameW    = 150,
    scoreR   = 250,
    lootL    = 268,
    dmgR     = 400,
    takenR   = 480,
    avoidR   = 568,
    intR     = 608,
    dispR    = 644,
    deathR   = PANEL_W - PAD,
}

local TITLE_SIZE  = 15
local LINE_SIZE   = 12
local HEAD_SIZE   = 11
local ROW_SIZE    = 12

local panel
local rows = {}
local currentRun

------------------------------------------------------------
-- 數字縮寫
--
-- 走暴雪的 AbbreviateNumbers：那是 C 端函式，連秘密數字都吃得下，自己用
-- math.floor 拆位數的話遇到秘密值就直接爆。東亞客戶端按萬／億分級 ——
-- K/M/B 對他們反而難讀。
------------------------------------------------------------
local CJK = ({
    zhCN = { thousand = "千", wan = "万", yi = "亿" },
    zhTW = { thousand = "千", wan = "萬", yi = "億" },
    koKR = { thousand = "천", wan = "만", yi = "억" },
})[GetLocale()]

local abbrevCfg
do
    local opts
    if CJK then
        opts = {
            { breakpoint = 100000000, abbreviation = CJK.yi,       significandDivisor = 1000000, fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 10000,     abbreviation = CJK.wan,      significandDivisor = 100,     fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 1000,      abbreviation = CJK.thousand, significandDivisor = 100,     fractionDivisor = 10,  abbreviationIsGlobal = false },
            { breakpoint = 1,         abbreviation = "",           significandDivisor = 1,       fractionDivisor = 1,   abbreviationIsGlobal = false },
        }
    else
        opts = {
            { breakpoint = 1000000000, abbreviation = "B", significandDivisor = 10000000, fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 1000000,    abbreviation = "M", significandDivisor = 10000,    fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 1000,       abbreviation = "K", significandDivisor = 100,      fractionDivisor = 10,  abbreviationIsGlobal = false },
            { breakpoint = 1,          abbreviation = "",  significandDivisor = 1,        fractionDivisor = 1,   abbreviationIsGlobal = false },
        }
    end
    if CreateAbbreviateConfig then
        abbrevCfg = { config = CreateAbbreviateConfig(opts) }
    end
end

local function Abbrev(n)
    if n == nil then return "0" end
    if AbbreviateNumbers then return AbbreviateNumbers(n, abbrevCfg) or "0" end
    -- 備援：只有在 AbbreviateNumbers 不存在的客戶端才走得到
    local v = tonumber(n)
    if not v then return "?" end
    return ("%d"):format(v)
end
Panel.Abbrev = Abbrev

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local CLASS_SPRITE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

-- 專精圖示優先，沒有就退職業 sprite，再沒有就不畫。
-- **不要畫一個猜出來的職業圖** —— 錯的圖比空白更糟。
local function ApplyIcon(tex, player)
    local icon = tonumber(player.specIcon)
    if icon and icon ~= 0 then
        tex:SetTexture(icon)
        tex:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        tex:Show()
        return
    end
    local cls = player.class
    local co = cls and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
    if co then
        tex:SetTexture(CLASS_SPRITE)
        tex:SetTexCoord(co[1], co[2], co[3], co[4])
        tex:Show()
        return
    end
    tex:Hide()
end

local function ScoreColorHex(score)
    if not score or not (C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor) then
        return nil
    end
    local c = Sec.SafeCall(C_ChallengeMode.GetDungeonScoreRarityColor, score)
    if type(c) ~= "table" then return nil end
    local r, g, b = Sec.PlainNumber(c.r), Sec.PlainNumber(c.g), Sec.PlainNumber(c.b)
    if not (r and g and b) then return nil end
    return S.Hex(r, g, b)
end

------------------------------------------------------------
-- 一列
------------------------------------------------------------
local function NewRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)   -- 真正的 y 由 Layout 決定
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    row:EnableMouse(true)
    row.index = index

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", PAD, 0)

    row.name  = S.NewText(row, ROW_SIZE, S.TEXT, "LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", COL.nameX, 0)
    row.name:SetWidth(COL.nameW)

    local function RightText(rightEdge)
        local fs = S.NewText(row, ROW_SIZE, S.TEXT, "RIGHT")
        fs:SetPoint("RIGHT", row, "LEFT", rightEdge, 0)
        return fs
    end

    row.score  = RightText(COL.scoreR)
    row.dmg    = RightText(COL.dmgR)
    row.taken  = RightText(COL.takenR)
    row.avoid  = RightText(COL.avoidR)
    row.inter  = RightText(COL.intR)
    row.disp   = RightText(COL.dispR)
    row.deaths = RightText(COL.deathR)

    ------------------------------------------------------------
    -- 戰利品格
    --
    -- ⚠ 子框會搶走父框的滑鼠焦點：游標移到圖示上時，**列本身會收到 OnLeave**。
    --   所以圖示的提示要自己處理，不能指望列的 OnEnter 幫忙。
    ------------------------------------------------------------
    row.loot = {}
    for i = 1, LOOT_MAX do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(ICON_SIZE, ICON_SIZE)
        b:SetPoint("LEFT", row, "LEFT", COL.lootL + (i - 1) * (ICON_SIZE + LOOT_GAP), 0)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        b:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        row.loot[i] = b
    end

    -- 滑過整列：把沒放進表格的那幾項補上
    row:SetScript("OnEnter", function(self)
        local p = self.player
        if not p then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(p.name or "?", 1, 1, 1)
        -- ⚠ 這兩條用的是**跟欄位標題不同的 key**：欄位標題那一欄顯示的是每秒值
        --   （「輸出」），這裡是總量。同一個 key 兩個意思，翻譯就只能二選一
        GameTooltip:AddDoubleLine(L["Total damage"], Abbrev(p.dmg), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Total healing"],
            ("%s (%s)"):format(Abbrev(p.heal), Abbrev(p.hps)), 0.8, 0.8, 0.8, 1, 1, 1)
        local run = currentRun
        if run and run.combatSec then
            GameTooltip:AddDoubleLine(L["Time in combat"], H.FormatSec(run.combatSec), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

local function FillRow(row, player)
    row.player = player
    if not player then
        row:Hide()
        return
    end

    ApplyIcon(row.icon, player)

    local r, g, b = S.ClassColor(player.class)
    if r then row.name:SetTextColor(r, g, b) else row.name:SetTextColor(1, 1, 1) end
    row.name:SetText(player.name or "?")

    if player.score then
        local hex = ScoreColorHex(player.score)
        row.score:SetText(hex and (hex .. player.score .. "|r") or tostring(player.score))
    else
        row.score:SetText("")
    end

    row.dmg:SetText(Abbrev(player.dps))
    row.taken:SetText(Abbrev(player.taken))
    row.avoid:SetText(Abbrev(player.avoidable))
    row.inter:SetText(("%d"):format(player.interrupts or 0))
    row.disp:SetText(("%d"):format(player.dispels or 0))
    row.deaths:SetText(("%d"):format(player.deaths or 0))

    local loot = player.loot
    for i = 1, LOOT_MAX do
        local b = row.loot[i]
        local link = loot and loot[i]
        if link then
            b.link = link
            local icon = select(5, Sec.SafeCall(C_Item.GetItemInfoInstant, link))
            b.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            b:Show()
        else
            b.link = nil
            b:Hide()
        end
    end

    row:Show()
end

------------------------------------------------------------
-- 表頭
------------------------------------------------------------
local function RenderHeader(run)
    if not run then return end

    -- 第一行：「+等級」依結果上色，副本名維持白字
    local col = run.onTime and S.ON_TIME or S.OVER
    panel.title:SetText(("%s+%d|r %s"):format(
        S.Hex(col[1], col[2], col[3]), tonumber(run.level) or 0, H.MapName(run)))

    -- 第二行左：時間 / 時限、結果、死亡與罰時
    local parts = {}
    parts[#parts + 1] = ("%s / %s"):format(H.FormatMs(run.timeMs), H.FormatSec(run.limitSec))
    parts[#parts + 1] = H.ResultText(run)
    if run.practiceRun then parts[#parts + 1] = L["Practice run"] end
    local deaths = tonumber(run.deaths) or 0
    if deaths > 0 then
        local penalty = tonumber(run.deathPenaltySec) or 0
        if penalty > 0 then
            parts[#parts + 1] = (L["%d deaths (-%s)"]):format(deaths, H.FormatSec(penalty))
        else
            parts[#parts + 1] = (L["%d deaths"]):format(deaths)
        end
    end
    if run.isMapRecord then parts[#parts + 1] = "|cffffd200" .. L["Best time"] .. "|r" end
    panel.subtitle:SetText(table.concat(parts, "   "))

    -- 第二行右：自己的總分變化
    local newScore, oldScore = tonumber(run.newScore), tonumber(run.oldScore)
    if newScore then
        local text = (L["Rating %d"]):format(newScore)
        if oldScore and newScore > oldScore then
            text = text .. (" |cff40ff40(+%d)|r"):format(newScore - oldScore)
        end
        panel.rating:SetText(text)
    else
        panel.rating:SetText("")
    end

    panel.historyBtn:SetText(H.Label(run))
end

------------------------------------------------------------
-- 統計來源的說明標記
--
-- 只有「統計不是乾淨的整趟」時才出現。⚠ 用 `?` 不用 `ⓘ`：中文字型沒有那個字元，
-- 畫出來是方框（同樣的理由讓選單的打勾一律走材質）。
------------------------------------------------------------
local function RenderNotice(run)
    local flags = (run and type(run.statsFlags) == "table") and run.statsFlags or {}
    local lines = {}

    if run and run.statsSource == "overall" then
        lines[#lines + 1] = L["These numbers come from the overall session, not from this run alone."]
    end
    if flags.truncated then
        lines[#lines + 1] = L["The game had already dropped the earliest combat segments of this run."]
    end
    if flags.resetDuringRun then
        lines[#lines + 1] = L["The combat statistics were reset partway through the run."]
    end
    if flags.partialStart then
        lines[#lines + 1] = L["Recording started after the run had already begun."]
    end
    if flags.incompleteRoster then
        lines[#lines + 1] = L["Some of the party never became readable, so a line may be missing."]
    end
    if flags.secretGaveUp then
        lines[#lines + 1] = L["The game never handed out readable combat statistics for this run."]
    end

    panel.notice.lines = lines
    panel.notice:SetShown(#lines > 0)

    local noStats = (run ~= nil) and (run.statsSource == nil)
    panel.empty:SetShown(noStats)
end

------------------------------------------------------------
-- 填一整場
------------------------------------------------------------
function Panel.SetRun(run)
    Panel.EnsureFrame()
    currentRun = run
    if not run then
        panel.title:SetText(L["No runs recorded yet"])
        panel.subtitle:SetText("")
        panel.rating:SetText("")
        panel.historyBtn:SetText(L["History"])
        panel.notice:Hide()
        panel.empty:Hide()
        for i = 1, MAX_ROWS do FillRow(rows[i], nil) end
        return
    end

    RenderHeader(run)
    RenderNotice(run)

    local players = type(run.players) == "table" and run.players or {}
    for i = 1, MAX_ROWS do
        FillRow(rows[i], players[i])
    end
end

function Panel.CurrentRun()
    return currentRun
end

-- 戰利品是在存檔之後才進來的，面板開著就把那一場重畫
function Panel.OnLootAdded(run)
    if not panel or not panel:IsShown() then return end
    if run ~= currentRun then return end
    local players = type(run.players) == "table" and run.players or {}
    for i = 1, MAX_ROWS do
        FillRow(rows[i], players[i])
    end
end

------------------------------------------------------------
-- 位置與縮放
------------------------------------------------------------
local function SavePosition()
    if not panel or not ns.db then return end
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    if not (cx and fx) then return end
    ns.db.panel.point.x = math.floor(fx - cx + 0.5)
    ns.db.panel.point.y = math.floor(fy - cy + 0.5)
end

function Panel.ApplySettings()
    if not panel or not ns.db then return end
    panel:SetScale(tonumber(ns.db.panel.scale) or 1)
    local pt = ns.db.panel.point
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", pt.x or 0, pt.y or 0)
end

function Panel.ResetPosition()
    if not ns.db then return end
    ns.db.panel.point.x, ns.db.panel.point.y = 0, 0
    Panel.ApplySettings()
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
function Panel.EnsureFrame()
    if panel then return panel end

    local W = ns.W

    panel = CreateFrame("Frame", "MiliUIMythicPlus_Panel", UIParent, "BackdropTemplate")
    panel:Hide()
    -- ⚠ 版面的尺寸與欄位偏移**一律用同一種單位**（未縮放的框架單位）。
    --   只有 1px 邊框走 P.Scale（那是為了對齊實體像素，見 Core/Style.lua）——
    --   兩種單位混著用的話，欄位的右緣會跟面板右緣差一點點，而且差多少隨 UI 縮放變
    panel:SetSize(PANEL_W, HEAD_H + 240)
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    S.ApplyPanel(panel)

    -- ESC 關閉。⚠ 不要自己 EnableKeyboard 抓 ESC —— 鍵盤獨佔會把**所有**快捷鍵
    --   吃掉，症狀是「面板開著的時候什麼按鍵都沒反應」
    W.CloseOnEscape(panel)

    ------------------------------------------------------------
    -- 表頭區（同時是拖曳把手）
    ------------------------------------------------------------
    local head = CreateFrame("Frame", nil, panel)
    head:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    head:SetHeight(HEAD_H)
    head:EnableMouse(true)
    panel.head = head

    -- ⚠ 右鍵回中央要用 SetScript **先**設好，再叫 MakeDragHandle（那支走 HookScript）。
    --   順序反過來的話，SetScript 會把它掛的處理器整個蓋掉，拖曳就失效了
    head:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then Panel.ResetPosition() end
    end)
    W.MakeDragHandle(head, panel, SavePosition)

    panel.title = S.NewText(head, TITLE_SIZE, S.TEXT, "LEFT")
    panel.title:SetPoint("TOPLEFT", head, "TOPLEFT", PAD, -PAD)

    panel.subtitle = S.NewText(head, LINE_SIZE, S.TEXT, "LEFT")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -6)

    panel.rating = S.NewText(head, LINE_SIZE, S.TEXT, "RIGHT")
    panel.rating:SetPoint("TOPRIGHT", head, "TOPRIGHT", -PAD, -(PAD + TITLE_SIZE + 8))

    ------------------------------------------------------------
    -- 右上角的兩顆鈕
    --
    -- ⚠ **層級要明確墊高。** 這兩顆坐在 head 的範圍內，而 head 是整片收滑鼠的
    --   拖曳把手；同層的兩個框誰吃到點擊是不保證的。症狀會是「關閉鈕有時候點不到」
    --   —— 偶發、難重現，所以不要賭，直接指定
    ------------------------------------------------------------
    local BTN_LEVEL = head:GetFrameLevel() + 5

    local close = W.CreateButton(panel, "", "red", 18, 18)
    close:SetFrameLevel(BTN_LEVEL)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -PAD + 2)
    local closeX = close:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(11, 11)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    close:SetScript("OnClick", function() Panel.Hide() end)

    -- 歷史下拉：顯示目前這一場，點開列出最近的場次
    local hist = W.CreateButton(panel, L["History"], "accent-hover", 220, 18)
    hist:SetFrameLevel(BTN_LEVEL)
    hist:SetPoint("RIGHT", close, "LEFT", -4, 0)
    hist:SetScript("OnClick", function(self) ns.HistoryMenu.Toggle(self) end)
    panel.historyBtn = hist

    ------------------------------------------------------------
    -- 欄位標題列 ＋ 底下的髮絲線
    --
    -- ⚠ 標題前面**不放**收尾隔線：標題底下這一條就是分界，上面再補一條會變成
    --   兩條線夾一行灰字。小節之間只靠留白。
    ------------------------------------------------------------
    local headerRow = CreateFrame("Frame", nil, panel)
    headerRow:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
    headerRow:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -6)
    headerRow:SetHeight(HEADROW_H)
    panel.headerRow = headerRow

    local function HeadText(text, rightEdge)
        local fs = S.NewText(headerRow, HEAD_SIZE, S.TEXT_DIM, "RIGHT")
        fs:SetPoint("RIGHT", headerRow, "LEFT", rightEdge, 0)
        fs:SetText(text)
        return fs
    end

    local hName = S.NewText(headerRow, HEAD_SIZE, S.TEXT_DIM, "LEFT")
    hName:SetPoint("LEFT", headerRow, "LEFT", COL.nameX, 0)
    hName:SetText(L["Player"])

    HeadText(L["Score"], COL.scoreR)
    local hLoot = S.NewText(headerRow, HEAD_SIZE, S.TEXT_DIM, "LEFT")
    hLoot:SetPoint("LEFT", headerRow, "LEFT", COL.lootL)
    hLoot:SetText(L["Loot"])
    HeadText(L["Damage"], COL.dmgR)
    HeadText(L["Damage taken"], COL.takenR)
    HeadText(L["Avoidable damage taken"], COL.avoidR)
    HeadText(L["Interrupts"], COL.intR)
    HeadText(L["Dispels"], COL.dispR)
    HeadText(L["Deaths"], COL.deathR)

    local line = S.NewHairline(panel)
    line:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", PAD, -2)
    line:SetPoint("TOPRIGHT", headerRow, "BOTTOMRIGHT", -PAD, -2)

    -- 統計來源的說明標記。位置挑在欄位標題列最左邊那一格（資料列的圖示欄，
    -- 標題列本來就空著）—— 它說的是「底下這張表的來源」，貼著表頭最合理，
    -- 而且不必為它擠掉任何一欄
    local notice = CreateFrame("Button", nil, panel)
    notice:SetSize(14, 14)
    notice:SetPoint("LEFT", headerRow, "LEFT", PAD + 2, 0)
    notice.text = S.NewText(notice, HEAD_SIZE, S.TEXT_DIM, "CENTER")
    notice.text:SetPoint("CENTER")
    notice.text:SetText("?")
    notice:SetScript("OnEnter", function(self)
        if not self.lines or #self.lines == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["About these numbers"], 1, 1, 1)
        for _, l in ipairs(self.lines) do
            GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    notice:SetScript("OnLeave", function() GameTooltip:Hide() end)
    notice:Hide()
    panel.notice = notice

    ------------------------------------------------------------
    -- 五列固定建，永不銷毀
    ------------------------------------------------------------
    local top = 0
    for i = 1, MAX_ROWS do
        local row = NewRow(panel, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -(top + 4))
        row:SetPoint("TOPRIGHT", headerRow, "BOTTOMRIGHT", 0, -(top + 4))
        row:Hide()
        rows[i] = row
        top = top + ROW_H
    end

    -- 沒讀到統計時蓋在表格區的那一行灰字
    panel.empty = S.NewText(panel, ROW_SIZE, S.TEXT_DIM, "CENTER")
    panel.empty:SetPoint("TOP", headerRow, "BOTTOM", 0, -18)
    panel.empty:SetText(L["No combat statistics were recorded for this run."])
    panel.empty:Hide()

    panel:SetHeight(HEAD_H + 6 + HEADROW_H + 4 + MAX_ROWS * ROW_H + PAD)

    panel:SetScript("OnHide", function() ns.HistoryMenu.Close() end)

    Panel.ApplySettings()
    return panel
end

------------------------------------------------------------
-- 開關
------------------------------------------------------------
function Panel.Show()
    Panel.EnsureFrame()
    if currentRun == nil then Panel.SetRun(H.Latest()) end
    Panel.ApplySettings()
    panel:Show()
    panel:Raise()
end

function Panel.Hide()
    if panel then panel:Hide() end
end

function Panel.Toggle()
    Panel.EnsureFrame()
    if panel:IsShown() then Panel.Hide() else Panel.Show() end
end

function Panel.IsShown()
    return panel and panel:IsShown() or false
end
