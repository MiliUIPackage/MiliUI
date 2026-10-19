------------------------------------------------------------
-- MiliUI_QoL: 角色面板稱號頁的搜尋框（連清單一起自建；2026-10-15 從 MiliUI_Skin 搬來）
--
-- 做法照 EllesmereUI 的角色面板（EllesmereUIBlizzardSkin_CharacterSheet.lua 的稱號頁：
-- 自己的面板 ＋ 頂端搜尋框 ＋ 一次建好、排序、子字串過濾的清單，KNOWN_TITLES_UPDATE
-- 失效重建）。暴雪的清單是 ScrollBox ＋ DataProvider，要在它上面加過濾就得換掉它的
-- DataProvider（寫暴雪的狀態），所以跟 EllesmereUI 一樣：自己畫一份，暴雪那份藏起來照跑。
--
-- 清單內容照暴雪的 `GetKnownTitles`／`PaperDollTitlesPane_Update`（PaperDollFrame.lua:2579-2618）：
--   * 第一列固定是「無稱號」（`PLAYER_TITLE_NONE`），點了 `SetCurrentTitle(-1)`——
--     **-1 才會清掉稱號，0 是 no-op**；
--   * 其餘是 `IsTitleKnown(i)` 的 `GetTitleName(i)`，照名字排序；
--   * 選中態 ＝ `GetCurrentTitle()`（> 0 而且已知才算，否則是「無稱號」）。
--   * 點列 ＝ `SetCurrentTitle(id)` ＋ 同一個音效（`PlayerTitleButton_OnClick`，:2620）。
-- 稱號名字如果帶 `%s`（前綴／後綴的佔位），列上換成玩家名字；排序與搜尋用的是拿掉
-- `%s`、去掉首尾空白之後的字。暴雪自己的清單是直接 `strtrim(name)`。
--
------------------------------------------------------------
-- ## 對暴雪物件的接觸面
--
-- | 物件 | 動作 |
-- |---|---|
-- | PaperDollFrame.TitleManagerPane.ScrollBox / .ScrollBar | `X.Neutralize`（SetAlpha 0）——暴雪的清單照跑、沒人看得到 |
-- | PaperDollFrame.TitleManagerPane | 當我們宿主框的 parent ＋ 左上角的錨點 |
-- | CharacterFrame.InsetRight | 宿主框右下角的錨點（暴雪的捲軸在 pane 右緣**外面**，要蓋到它） |
-- | PaperDollFrame.TitleManagerPane | `GetFrameLevel()`（`X.TargetLevel`）——宿主框的層級 ＝ 它 +10 |
-- | `PaperDollFrame.TitleManagerPane`／`.ScrollBox`／`.ScrollBar`／`CharacterFrame.InsetRight` | 讀 parentKey（pcall 包著，結構查詢） |
--
-- 寫入暴雪欄位：無。hook：無（顯隱跟著 parent 走，用的是**自己框**的 OnShow/OnHide）。
-- 呼叫的 API：GetNumTitles／IsTitleKnown／GetTitleName／GetCurrentTitle／SetCurrentTitle／
-- UnitName("player")／PlaySound——都不是保護函式。
--
-- 宿主框 `EnableMouse(true)` ＋ `EnableMouseWheel(true)`：暴雪 alpha 0 的稱號列與捲軸還在收
-- 滑鼠（點得到、滾得動），我們的框蓋在上面把它們擋掉。層級 +10（不是 +5）：ScrollBox →
-- ScrollTarget → 列、ScrollBar → 拇指，暴雪那邊已經疊了三、四層。
-- 宿主框 `SetIgnoreParentAlpha(true)`：保險——pane 本身沒中和，但跟屬性清單同一套寫法。
------------------------------------------------------------
local _, ns = ...

local X = ns.CharSheet
local C = X.C
local S = ns.Secret
local W = ns.W

local ROW_H    = 22
local ROW_STEP = 23       -- 列與列之間留 1 的縫，一列一塊
local SEARCH_H = 20
local GAP      = 4
local TEXT_PAD = 8
local FONT_ROW = 12

local host, scroll, search, placeholder, clearBtn
local titles = {}          -- { id, name（顯示用）, key（排序／搜尋用，小寫） }
local filtered = {}
local rows = {}

------------------------------------------------------------
-- 資料
------------------------------------------------------------
local function PlayerName()
    return S.PlainText(UnitName("player")) or ""
end

local function Clean(name)
    return strtrim((name:gsub("%%s", "")))
end

local function Collect()
    wipe(titles)
    titles[1] = { id = -1, name = PLAYER_TITLE_NONE or NONE or "None", key = "", none = true }
    local me = PlayerName()
    local list = {}
    for i = 1, (S.PlainNumber(GetNumTitles()) or 0) do
        if IsTitleKnown(i) then
            local name, isTitle = GetTitleName(i)
            name = S.PlainText(name)
            if name and isTitle then
                local key = Clean(name)
                -- ⚠ gsub 回兩個值，第二個（次數）會被 strtrim 當成「要剝的字元」⇒ 括號只取第一個
                local display = name:find("%s", 1, true) and strtrim((name:gsub("%%s", me))) or strtrim(name)
                list[#list + 1] = { id = i, name = display, key = key:lower(), sort = key }
            end
        end
    end
    table.sort(list, function(a, b) return a.sort < b.sort end)
    for _, t in ipairs(list) do titles[#titles + 1] = t end
end

local function CurrentTitle()
    local cur = S.PlainNumber(GetCurrentTitle())
    if cur and cur > 0 and cur <= (S.PlainNumber(GetNumTitles()) or 0) and IsTitleKnown(cur) then
        return cur
    end
    return -1
end

local function Filter()
    wipe(filtered)
    local q = search and search:GetText() or ""
    q = strtrim(q):lower()
    for _, t in ipairs(titles) do
        -- 「無稱號」永遠在第一列（搜尋時也留著：清稱號的唯一入口）
        if t.none or q == "" or t.key:find(q, 1, true) then
            filtered[#filtered + 1] = t
        end
    end
end

------------------------------------------------------------
-- 列：淡底 ＋ 滑過白 8% ＋ 選中＝職業色底與左緣直條（套組清單列的語彙）
------------------------------------------------------------
local function PaintRow(row, selected)
    if selected then
        row.bg:SetColorTexture(X.AccentFill(1))
        row.accent:SetColorTexture(X.Accent())
        row.accent:Show()
    else
        row.bg:SetColorTexture(C.fill[1], C.fill[2], C.fill[3], C.fill[4] or 1)
        row.accent:Hide()
    end
end

local Repaint   -- forward

local function OnRowClick(row)
    local t = row.title
    if not t then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    SetCurrentTitle(t.id)
    -- 選中態先跟著畫一次；伺服器確認後 UNIT_NAME_UPDATE 會再畫一次
    C_Timer.After(0.1, Repaint)
end

local function NewRow(i)
    local row = CreateFrame("Button", nil, scroll.child)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(i - 1) * ROW_STEP)
    row:SetPoint("TOPRIGHT", scroll.child, "TOPRIGHT", 0, -(i - 1) * ROW_STEP)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.accent = row:CreateTexture(nil, "BORDER")
    row.accent:SetPoint("TOPLEFT")
    row.accent:SetPoint("BOTTOMLEFT")
    row.accent:SetWidth(ns.P.Scale(C.rowAccentSize))

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, C.highlightAlpha)

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFont(X.Font(), FONT_ROW, "")
    row.text:SetShadowColor(0, 0, 0, 1)
    row.text:SetShadowOffset(1, -1)
    row.text:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.text:SetPoint("LEFT", row, "LEFT", TEXT_PAD, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -TEXT_PAD, 0)

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", OnRowClick)
    rows[i] = row
    return row
end

-- 只換底色（選中態變了）：不重排、不重設文字
function Repaint()
    local cur = CurrentTitle()
    for i, t in ipairs(filtered) do
        local row = rows[i]
        if row then PaintRow(row, t.id == cur) end
    end
end

local function Render()
    Filter()
    local cur = CurrentTitle()
    for i, t in ipairs(filtered) do
        local row = rows[i] or NewRow(i)
        row.title = t
        row.text:SetText(t.name)
        PaintRow(row, t.id == cur)
        row:Show()
    end
    for i = #filtered + 1, #rows do
        rows[i].title = nil
        rows[i]:Hide()
    end
    scroll:SetContentHeight(#filtered * ROW_STEP)
end

------------------------------------------------------------
-- 搜尋框：共用層 W.CreateEditBox（套組的輸入框：1px 黑邊、焦點時職業色邊、
-- Esc 清焦點、不自動取焦點）＋ 提示字 ＋ 右端的 ×
------------------------------------------------------------
local function SyncSearchDecor()
    local text = search:GetText() or ""
    placeholder:SetShown(text == "" and not search:HasFocus())
    clearBtn:SetShown(text ~= "")
end

local function BuildSearch()
    search = W.CreateEditBox(host, 100, SEARCH_H)
    search:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    search:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
    search:SetHeight(SEARCH_H)
    search:SetBackdropColor(C.fillInset[1], C.fillInset[2], C.fillInset[3], C.fillInset[4] or 1)
    search:SetTextInsets(6, SEARCH_H, 0, 0)
    search:SetFont(X.Font(), FONT_ROW, "")
    search:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

    placeholder = search:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(X.Font(), FONT_ROW, "")
    placeholder:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3], 1)
    placeholder:SetPoint("LEFT", search, "LEFT", 6, 0)
    -- 輸入框的提示字（刪節號在這裡是「請輸入」的語氣，不是按鈕文字）
    placeholder:SetText("搜尋稱號…")

    clearBtn = CreateFrame("Button", nil, search)
    clearBtn:SetSize(SEARCH_H, SEARCH_H)
    clearBtn:SetPoint("RIGHT", search, "RIGHT", 0, 0)
    local lines = {}
    for _, d in ipairs({ { -1, -1, 1, 1 }, { -1, 1, 1, -1 } }) do
        local line = clearBtn:CreateLine(nil, "ARTWORK")
        line:SetThickness(ns.P.Scale(1.5))   -- × 是圖記、跟按鈕一起縮放：P.Scale 不是 P.Pixel（wow-1px-border-rules 第 6 條）
        line:SetColorTexture(1, 1, 1, 1)
        line:SetVertexColor(C.textDim[1], C.textDim[2], C.textDim[3], 1)
        line:SetStartPoint("CENTER", clearBtn, d[1] * 4, d[2] * 4)
        line:SetEndPoint("CENTER", clearBtn, d[3] * 4, d[4] * 4)
        lines[#lines + 1] = line
    end
    local function Tint(c)
        for _, line in ipairs(lines) do line:SetVertexColor(c[1], c[2], c[3], 1) end
    end
    clearBtn:SetScript("OnEnter", function() Tint(C.text) end)
    clearBtn:SetScript("OnLeave", function() Tint(C.textDim) end)
    clearBtn:SetScript("OnClick", function()
        search:SetText("")
        search:ClearFocus()
    end)

    -- 共用層已經設好 OnEscapePressed（清焦點）與焦點時的邊色；這裡只「加」行為
    search:HookScript("OnTextChanged", function()
        SyncSearchDecor()
        Render()
        scroll:ScrollToTop()
    end)
    search:HookScript("OnEditFocusGained", SyncSearchDecor)
    search:HookScript("OnEditFocusLost", SyncSearchDecor)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    SyncSearchDecor()
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
-- KNOWN_TITLES_UPDATE：清單變了。UNIT_NAME_UPDATE（player）：換稱號就是換顯示名，
-- 選中態要重畫；帶 %s 的稱號顯示也跟著名字走 ⇒ 兩個都整份重建（幾百個字串，便宜）。
-- 沒開著就不做：OnShow 本來就會重建。
local function OnEvent()
    if host:IsVisible() then
        Collect()
        Render()
    end
end

local function Build()
    local doll = _G.PaperDollFrame
    local pane, box, bar, inset
    if not (doll and pcall(function() pane = doll.TitleManagerPane end) and pane) then
        X.Missing("PaperDollFrame.TitleManagerPane")
        return
    end
    pcall(function() box = pane.ScrollBox; bar = pane.ScrollBar end)
    pcall(function() inset = CharacterFrame.InsetRight end)

    host = CreateFrame("Frame", nil, pane)
    -- 範圍同屬性欄（CharacterStatsPane 錨在 InsetRight 內縮 3／2，CharacterFrame.xml:199）
    if inset then
        host:SetPoint("TOPLEFT", inset, "TOPLEFT", 3, -3)
        host:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -3, 2)
    else
        host:SetAllPoints(pane)
    end
    host:SetFrameLevel((X.TargetLevel(pane) or 1) + 10)
    host:SetIgnoreParentAlpha(true)
    host:EnableMouse(true)
    host:EnableMouseWheel(true)

    BuildSearch()

    scroll = X.CreateScroll(host, { step = ROW_STEP * 3 })
    scroll:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -GAP)
    scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

    -- 開頁：清空搜尋、重建、回到頂端
    host:SetScript("OnShow", function()
        search:SetText("")
        search:ClearFocus()
        Collect()
        Render()
        scroll:ScrollToTop()
    end)
    host:SetScript("OnHide", function()
        search:ClearFocus()
    end)
    host:RegisterEvent("KNOWN_TITLES_UPDATE")
    host:RegisterUnitEvent("UNIT_NAME_UPDATE", "player")
    host:SetScript("OnEvent", OnEvent)

    X.Neutralize(box, "TitleManagerPane.ScrollBox")
    X.Neutralize(bar, "TitleManagerPane.ScrollBar")

    if host:IsVisible() then
        Collect()
        Render()
    end
end

X.Register("titlesSearch", Build)
