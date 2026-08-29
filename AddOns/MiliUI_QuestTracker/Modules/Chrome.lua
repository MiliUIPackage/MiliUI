------------------------------------------------------------
-- 我們自己的框：清單背景 ＋ MiliUI 標題列
--
-- 這裡畫的東西**一個都不是暴雪的框**，全部掛在 UIParent 底下、只用 SetPoint 錨到
-- 追蹤器身上。理由不是潔癖：ObjectiveTrackerFrame 在編輯模式被錨到快捷列時會變成
-- 受保護框，掛在它底下的子框跟著受保護，戰鬥中連自己的東西都動不了。
--
-- 標題列同時是三件事：
--   * 摺疊整份清單的把手（暴雪原生的收合機制不能用——那條路要跑它整串收合程式碼，
--     從插件的執行環境跑一次就會把追蹤器容器的派送迴圈弄髒）
--   * 自動接／交任務開關的固定位置
--   * 背景的上緣。藏掉暴雪的「所有目標」之後那條的版面空間還是留著，我們正好補進去
------------------------------------------------------------
local _, ns = ...

ns.Chrome = {}
local Chrome = ns.Chrome
local T = ns.Tracker
local P = ns.P
local L = ns.L

-- 版面常數。追蹤器的區塊本來就從框緣往內縮，所以背景要往外撐一點才包得住。
-- 這幾個值是看實際畫面調的，不是算出來的 —— 暴雪的內縮量本身就不對稱。
local BAR_H      = 26
local PAD_LEFT   = -10
local PAD_RIGHT  = 10
local BG_BOTTOM_PAD = 10
-- 標題列自己的左右內縮：文字不要貼著背景邊緣
local BAR_INSET  = 6
local CHIP_H     = 16
local CHIP_BOX   = 10

local bar, bg
local chips = {}

local function Cfg()   return ns.db and ns.db.appearance end
local function BarCfg() return ns.db and ns.db.titleBar end

local function Font()
    local a = Cfg()
    return (a and ns.Media.OptionalFont(a.font)) or ns.Media.DEFAULT_FONT
end

local function Outline()
    local a = Cfg()
    return (a and a.outline) and "OUTLINE" or ""
end

-- 開關 chip 的字級是固定的：它是框上的裝飾，不是內容。字型與描邊則跟著設定走 ——
-- 同一條列上的東西描邊不一致看起來會很怪
local CHIP_FONT_SIZE = 11
local function ChipFont(fs)
    fs:SetFont(Font(), CHIP_FONT_SIZE, Outline())
end

------------------------------------------------------------
-- 1px 實線。⚠ 高度要換算成「框架單位」——直接 SetHeight(1) 在非 1.0 的縮放下
-- 會變成 1.3 個實體像素，然後被四捨五入成忽粗忽細的線
------------------------------------------------------------
local function Hairline(parent, layer)
    local tex = parent:CreateTexture(nil, layer or "OVERLAY")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    return tex
end

local function SetHairlineHeight(tex, host)
    local scale = (host and host.GetEffectiveScale and host:GetEffectiveScale()) or 1
    if scale <= 0 then scale = 1 end
    tex:SetHeight(P.GetPixelPerfectScale() / scale)
end

------------------------------------------------------------
-- 開關 chip：一個 1px 方框 ＋ 一行字
--
-- 打勾符號刻意不用文字字元：zhTW／zhCN 的內建字型不保證有那個字，缺字會變成
-- 一個豆腐方塊，而且是那種「只有部分玩家看得到」的壞法。方框內填色是同樣的訊號，
-- 而且填色本身就吃強調色，狀態只換明暗、色相不變。
------------------------------------------------------------
local function CreateChip(parent, text, getFn, setFn)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(P.Scale(CHIP_H))
    chip:EnableMouse(true)

    chip.bg = chip:CreateTexture(nil, "BACKGROUND")
    chip.bg:SetAllPoints()
    chip.bg:SetTexture("Interface\\Buttons\\WHITE8X8")

    local box = CreateFrame("Frame", nil, chip)
    box:SetSize(P.Scale(CHIP_BOX), P.Scale(CHIP_BOX))
    box:SetPoint("LEFT", chip, "LEFT", P.Scale(3), 0)
    chip.box = box

    -- 四條邊各一張貼圖：暴雪的 backdrop 邊框在非整數縮放下會糊掉
    box.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = box:CreateTexture(nil, "BORDER")
        e:SetTexture("Interface\\Buttons\\WHITE8X8")
        box.edges[side] = e
    end
    box.fill = box:CreateTexture(nil, "ARTWORK")
    box.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    box.fill:SetPoint("TOPLEFT", box, "TOPLEFT", P.Scale(2), -P.Scale(2))
    box.fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -P.Scale(2), P.Scale(2))

    chip.label = chip:CreateFontString(nil, "OVERLAY")
    chip.label:SetPoint("LEFT", box, "RIGHT", P.Scale(4), 0)
    -- ⚠ 剛建出來的 FontString 沒有字型，這時候 SetText 會丟 "Font not set"。
    --   LayoutChip 稍後還會照設定重設一次，但**建立當下就得先有一個**，
    --   不然這一行就把整個 EnsureFrames 打斷在半路
    ChipFont(chip.label)
    chip.label:SetText(text)

    chip.Get = getFn
    chip.Set = setFn
    chip.hovered = false

    chip:SetScript("OnEnter", function(self) self.hovered = true; Chrome.RefreshChip(self) end)
    chip:SetScript("OnLeave", function(self) self.hovered = false; Chrome.RefreshChip(self) end)
    chip:SetScript("OnMouseUp", function(self, button)
        -- 右鍵在標題列上任何地方都開同一份選單，包含壓在 chip 上的時候。
        -- chip 是 bar 的子框、會先吃到滑鼠，不轉發的話右鍵點到 chip 就沒反應
        if button ~= "LeftButton" then
            ns.ShowTrackerMenu()
            return
        end
        self.Set(not self.Get())
        Chrome.RefreshChip(self)
        ns.Fire("SettingsChanged")
    end)

    chips[#chips + 1] = chip
    return chip
end

-- 三態只換明暗、不換色相：閒置暗、滑過亮一階、開啟填滿
function Chrome.RefreshChip(chip)
    local r, g, b = ns.Media.Accent()
    local on = chip.Get() and true or false
    local hover = chip.hovered

    chip.bg:SetColorTexture(0, 0, 0, hover and 0.55 or 0)
    local edgeA = on and 1 or (hover and 0.8 or 0.45)
    for _, e in pairs(chip.box.edges) do
        e:SetColorTexture(r, g, b, edgeA)
    end
    chip.box.fill:SetColorTexture(r, g, b, on and 1 or 0)
    chip.label:SetTextColor(1, 1, 1, on and 1 or (hover and 0.9 or 0.6))
end

local function LayoutChip(chip)
    local px = P.GetPixelPerfectScale() / ((chip:GetEffectiveScale() or 1))
    local box = chip.box
    local e = box.edges
    e.TOP:ClearAllPoints()
    e.TOP:SetPoint("TOPLEFT");    e.TOP:SetPoint("TOPRIGHT");    e.TOP:SetHeight(px)
    e.BOTTOM:ClearAllPoints()
    e.BOTTOM:SetPoint("BOTTOMLEFT"); e.BOTTOM:SetPoint("BOTTOMRIGHT"); e.BOTTOM:SetHeight(px)
    e.LEFT:ClearAllPoints()
    e.LEFT:SetPoint("TOPLEFT");   e.LEFT:SetPoint("BOTTOMLEFT");  e.LEFT:SetWidth(px)
    e.RIGHT:ClearAllPoints()
    e.RIGHT:SetPoint("TOPRIGHT"); e.RIGHT:SetPoint("BOTTOMRIGHT"); e.RIGHT:SetWidth(px)

    ChipFont(chip.label)
    chip:SetWidth(P.Scale(3 + CHIP_BOX + 4 + 6) + chip.label:GetStringWidth())
end

------------------------------------------------------------
-- 建框
--
-- ⚠ 一路建在 local 上，**全部建完才寫回 bar / bg**。原本是先把 bar 指派出去
--   再往上長零件，結果中途丟一次錯（chip 的 FontString 沒設字型就 SetText）
--   就留下一個「bar 存在但零件是 nil」的半成品——而入口的 `if bar then return end`
--   會認定已經建好，於是那個壞掉的狀態再也修不回來，Layout 每跑一次噴一次。
--   通則：**有 early-out 守衛的建構函式，守衛看的那個變數要最後才寫。**
------------------------------------------------------------
local function EnsureFrames()
    if bar then return end
    local otf = T.OTF()
    if not otf then return end

    ------------------------------------------------------------
    -- 背景：墊在追蹤器後面一層
    ------------------------------------------------------------
    local newBg = CreateFrame("Frame", "MiliUIQuestTrackerBackground", UIParent)
    newBg:SetFrameStrata(otf:GetFrameStrata() or "MEDIUM")
    newBg:SetFrameLevel(math.max(0, (otf:GetFrameLevel() or 1) - 1))
    newBg.tex = newBg:CreateTexture(nil, "BACKGROUND")
    newBg.tex:SetAllPoints()
    newBg.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    newBg:Hide()

    ------------------------------------------------------------
    -- 標題列
    ------------------------------------------------------------
    local newBar = CreateFrame("Button", "MiliUIQuestTrackerTitleBar", UIParent)
    newBar:SetFrameStrata(otf:GetFrameStrata() or "MEDIUM")
    newBar:SetFrameLevel((otf:GetFrameLevel() or 1) + 10)
    newBar:SetHeight(P.Scale(BAR_H))
    newBar:EnableMouse(true)
    newBar:Hide()

    newBar.tex = newBar:CreateTexture(nil, "BACKGROUND")
    newBar.tex:SetAllPoints()
    newBar.tex:SetTexture("Interface\\Buttons\\WHITE8X8")

    newBar.divider = Hairline(newBar, "OVERLAY")
    newBar.divider:SetPoint("BOTTOMLEFT")
    newBar.divider:SetPoint("BOTTOMRIGHT")

    -- 摺疊指示。用暴雪自己的收合按鈕圖，語意剛好對上，而且保證存在；
    -- 去飽和之後才上色，不然圖本身的底色會跟我們的顏色相乘
    newBar.arrow = newBar:CreateTexture(nil, "ARTWORK")
    newBar.arrow:SetSize(P.Scale(14), P.Scale(14))
    newBar.arrow:SetPoint("LEFT", newBar, "LEFT", P.Scale(BAR_INSET), 0)

    newBar.label = newBar:CreateFontString(nil, "OVERLAY")
    newBar.label:SetPoint("LEFT", newBar.arrow, "RIGHT", P.Scale(6), 0)
    newBar.label:SetFont(Font(), Cfg().headerSize, Outline())   -- 理由同 chip.label

    -- 重建時先清空：上一輪如果死在半路，chips 裡會留著孤兒
    wipe(chips)
    newBar.turnIn = CreateChip(newBar, L["Auto turn-in"],
        function() return ns.db.automation.autoTurnIn end,
        function(v) ns.db.automation.autoTurnIn = v end)
    newBar.accept = CreateChip(newBar, L["Auto accept"],
        function() return ns.db.automation.autoAccept end,
        function(v) ns.db.automation.autoAccept = v end)

    newBar:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then
            ns.ShowTrackerMenu()
            return
        end
        if not BarCfg().clickToFold then return end
        ns.Visibility.ToggleManualFold()
    end)
    newBar:SetScript("OnEnter", function(self)
        self.hovered = true
        Chrome.ApplyStyle()
    end)
    newBar:SetScript("OnLeave", function(self)
        self.hovered = false
        Chrome.ApplyStyle()
    end)

    -- 全部建成功了才對外宣告
    bg, bar = newBg, newBar
end

------------------------------------------------------------
-- 量出清單最底下那一條內容在哪
--
-- ⚠ 共用 widget pool 的兩支（場景／UI widget）只量**模組框本身**，絕對不進去
--   量它的區塊：那些區塊是從服務工具提示與地圖圖釘的同一個池子借出來的
--   （見 Core/Tracker.lua 規矩 3）。
------------------------------------------------------------
-- ⚠ 一律換算成「螢幕像素」再比較。GetBottom() 回的是該框自己座標系的值，而編輯
--   模式可以單獨縮放任務追蹤器 —— 直接拿追蹤器裡的區塊減我們標題列的座標，在
--   縮放不是 1.0 的時候會算出一個系統性偏掉的高度（背景短一截或多一截，
--   而且玩家越調縮放越明顯）。
local function ScreenBottom(frame)
    local y = frame:GetBottom()
    if not y then return nil end
    return y * (frame:GetEffectiveScale() or 1)
end

local function ScreenTop(frame)
    local y = frame:GetTop()
    if not y then return nil end
    return y * (frame:GetEffectiveScale() or 1)
end

local function LowestContentBottom()
    local lowest
    local function consider(frame)
        if not frame or not frame.GetBottom then return end
        if not (frame.IsShown and frame:IsShown()) then return end
        local y = ScreenBottom(frame)
        if y and (not lowest or y < lowest) then lowest = y end
    end

    T.EachTracker(function(tracker)
        if not (tracker.IsShown and tracker:IsShown()) then return end
        if T.SharesWidgetPool(tracker) then
            consider(tracker)
            return
        end
        T.EachBlock(tracker, consider)
        -- 空的區段會把 Header 留在上一次的位置，跟著量會讓背景拖出一截空白
        if T.TrackerHasContent(tracker) then consider(tracker.Header) end
    end)
    return lowest
end

------------------------------------------------------------
-- 排版：每次追蹤器重排、設定變更、摺疊狀態改變都跑一次
------------------------------------------------------------
Chrome.layoutCount = 0

function Chrome.Layout()
    Chrome.layoutCount = Chrome.layoutCount + 1
    EnsureFrames()
    if not bar then return end
    local otf = T.OTF()
    if not otf then return end
    local a, tb = Cfg(), BarCfg()

    ------------------------------------------------------------
    -- 標題列
    ------------------------------------------------------------
    -- 藏掉暴雪的「所有目標」之後，它的版面高度還是被保留著（追蹤器不會為了
    -- 一個隱藏的 header 重新往上收），我們的標題列正好補進那個洞。
    -- 玩家選擇留著暴雪那條的話就往上疊一層，不要互相蓋住。
    local barTop = a.hideBlizzardHeader and 0 or BAR_H
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT",  otf, "TOPLEFT",  P.Scale(PAD_LEFT),  P.Scale(barTop))
    bar:SetPoint("TOPRIGHT", otf, "TOPRIGHT", P.Scale(PAD_RIGHT), P.Scale(barTop))
    bar:SetHeight(P.Scale(BAR_H))
    SetHairlineHeight(bar.divider, bar)

    for _, chip in ipairs(chips) do LayoutChip(chip) end

    -- chip 從右緣往左排：顯示幾顆隨設定變，錨在右緣才不會因為顆數不同而位移
    local anchor, gap = bar, -BAR_INSET
    local au = ns.db.automation
    local order = {
        { chip = bar.turnIn, show = au.showTurnInToggle },
        { chip = bar.accept, show = au.showAcceptToggle },
    }
    for _, entry in ipairs(order) do
        local chip = entry.chip
        chip:ClearAllPoints()
        if entry.show then
            chip:SetPoint("RIGHT", anchor, anchor == bar and "RIGHT" or "LEFT", P.Scale(gap), 0)
            chip:Show()
            Chrome.RefreshChip(chip)
            anchor, gap = chip, -6
        else
            chip:Hide()
        end
    end

    ------------------------------------------------------------
    -- 背景
    ------------------------------------------------------------
    local topAnchor, topPoint, topOfs
    if tb.enabled then
        topAnchor, topPoint, topOfs = bar, "BOTTOM", 0
    else
        topAnchor, topPoint, topOfs = otf, "TOP", 0
    end

    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT",  topAnchor, topPoint .. "LEFT",
        topAnchor == bar and 0 or P.Scale(PAD_LEFT), P.Scale(topOfs))
    bg:SetPoint("TOPRIGHT", topAnchor, topPoint .. "RIGHT",
        topAnchor == bar and 0 or P.Scale(PAD_RIGHT), P.Scale(topOfs))

    local lowest = LowestContentBottom()
    local topY = (topPoint == "BOTTOM") and ScreenBottom(topAnchor) or ScreenTop(topAnchor)
    if lowest and topY then
        -- 螢幕像素 → 背景自己的座標系
        local h = (topY - lowest) / (bg:GetEffectiveScale() or 1) + BG_BOTTOM_PAD
        bg:SetHeight(math.max(P.Scale(1), h))
        bg._lastHeight = h
    elseif bg._lastHeight then
        bg:SetHeight(bg._lastHeight)
    end

    Chrome.ApplyStyle()
    Chrome.UpdateVisibility()
    Chrome.UpdateMoveOverlay()
end

------------------------------------------------------------
-- 上色與字型
------------------------------------------------------------
function Chrome.ApplyStyle()
    if not bar then return end
    local a = Cfg()
    local r, g, b = ns.Media.Accent()

    -- 標題列的底跟清單**同一階**，不自己加重。
    -- （試過傷害統計那種「標題實心、內容半透」，在追蹤器上讀起來太重 —— 那邊的
    --  標題列是視窗的一部分，這裡的標題列是浮在地形上的一條，份量不能一樣。）
    -- 關掉背景時標題列也跟著沒有底，只留下面那條 1px 線；結構仍然讀得出來。
    --
    -- 滑過一定要看得到，所以給一個不透明度下限，再往白色插值提亮。
    -- 插值而不是加常數：玩家把底色調成非灰階時色相才不會偏
    -- （[[feedback-ui-visual-style]] 的「狀態只換明暗」）。
    local hovered = bar.hovered and BarCfg().clickToFold
    local baseA = a.background and a.bgAlpha or 0
    local alpha = hovered and math.max(baseA, 0.45) or baseA
    local lift  = hovered and 0.10 or 0
    local function Lighten(c) return c + (1 - c) * lift end
    bar.tex:SetColorTexture(Lighten(a.bgColor.r), Lighten(a.bgColor.g), Lighten(a.bgColor.b), alpha)
    bar.divider:SetShown(a.dividers)
    bar.divider:SetColorTexture(r, g, b, 1)

    local folded = ns.Visibility and ns.Visibility.IsFolded()
    bar.arrow:SetAtlas(folded and "ui-questtrackerbutton-secondary-expand"
                              or "ui-questtrackerbutton-secondary-collapse")
    if bar.arrow.SetDesaturated then bar.arrow:SetDesaturated(true) end
    bar.arrow:SetVertexColor(r, g, b)

    bar.label:SetFont(Font(), a.headerSize, Outline())
    bar.label:SetTextColor(1, 1, 1, hovered and 1 or 0.85)
    Chrome.UpdateLabel()

    if bg then
        bg.tex:SetColorTexture(a.bgColor.r, a.bgColor.g, a.bgColor.b, a.bgAlpha)
    end

    for _, chip in ipairs(chips) do Chrome.RefreshChip(chip) end
end

------------------------------------------------------------
-- 標題文字：「任務」或「任務 (3)」
--
-- 數量只數**被追蹤的**任務，不是任務日誌總數 —— 標題列講的是底下這份清單。
------------------------------------------------------------
function Chrome.UpdateLabel()
    if not bar then return end
    local text = L["Quests"]
    if BarCfg().showCount then
        local n = C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetNumQuestWatches() or 0
        if n > 0 then text = text .. "  " .. n end
    end
    bar.label:SetText(text)
end

------------------------------------------------------------
-- 顯示與隱藏
--
-- 背景跟著「追蹤器現在真的看得見而且有內容」走；標題列跟著「有內容」走
-- （摺疊時追蹤器是看不見的，但標題列要留著，不然就沒有東西可以點開）。
------------------------------------------------------------
local function HasAnyContent()
    local found = false
    T.EachTracker(function(tracker)
        if found then return end
        if not (tracker.IsShown and tracker:IsShown()) then return end
        if T.TrackerHasContent(tracker) then found = true end
    end)
    return found
end

function Chrome.UpdateVisibility()
    if not bar then return end
    local content = HasAnyContent()
    local folded = ns.Visibility and ns.Visibility.IsFolded()

    bar:SetShown(BarCfg().enabled and content)
    bg:SetShown(Cfg().background and content and not folded and T.IsVisible())
end

------------------------------------------------------------
-- /mquest debug 的現況快照
--
-- 「改了設定但畫面沒動」有兩種完全不同的病因，看起來一模一樣：
--   * Apply 根本沒走到這裡（layoutCount 不會漲）
--   * 走到了，但 hasContent／folded 之類的閘把顯示擋掉了
-- 不先分開就只能亂試，所以把兩邊的狀態一起印出來。
------------------------------------------------------------
function Chrome.Diagnose()
    local out = {}
    out[#out + 1] = ("layouts=%d  bar=%s/%s  bg=%s/%s"):format(
        Chrome.layoutCount,
        tostring(bar ~= nil), tostring(bar and bar:IsShown()),
        tostring(bg ~= nil),  tostring(bg and bg:IsShown()))
    out[#out + 1] = ("hasContent=%s  trackerVisible=%s  folded=%s"):format(
        tostring(HasAnyContent()), tostring(T.IsVisible()),
        tostring(ns.Visibility and ns.Visibility.IsFolded()))

    local parts = {}
    T.EachTracker(function(tracker)
        local name = tracker.GetName and tracker:GetName() or "?"
        parts[#parts + 1] = ("%s[%s/%s]"):format(
            (name:gsub("ObjectiveTracker", "")),
            tostring(tracker.IsShown and tracker:IsShown()),
            tostring(T.TrackerHasContent(tracker)))
    end)
    out[#out + 1] = table.concat(parts, " ")
    return out
end

------------------------------------------------------------
-- 設定視窗開著時的「搬家遮罩」
--
-- 照 MiliUI_Minimap／MiliUI_InfoBar 的約定：開設定多半就是要調位置，直接在
-- 目標上蓋一層職業色遮罩，左鍵拖、右鍵放手。
--
-- ⚠ 這裡拖的是**暴雪的編輯模式系統**，不是我們自己的框。位置一旦拖過就由
--   Modules/Position.lua 接管，而那是一場持續的拉鋸（編輯模式會在套用版面時
--   把它貼回去，我們再貼回來）。代價與收尾規則寫在那支的檔頭。
--   右鍵＝放手，把位置整個交還給編輯模式。
local moveOverlay

local function EnsureMoveOverlay()
    if moveOverlay or not bar then return end
    local o = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    o:SetFrameStrata(bar:GetFrameStrata() or "MEDIUM")
    o:SetFrameLevel((bar:GetFrameLevel() or 1) + 20)
    o:EnableMouse(true)
    o:RegisterForDrag("LeftButton")
    o:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = P.Scale(1),
    })

    -- 遮罩上的字**一律描邊**，不跟著設定走：它壓在會動的遊戲畫面上，
    -- 沒描邊在亮的地形會讀不出來。這不是漏掉，不要「修正」成 Outline()
    o.label = o:CreateFontString(nil, "OVERLAY")
    o.label:SetPoint("CENTER", o, "CENTER", 0, P.Scale(8))
    o.label:SetFont(Font(), 14, "OUTLINE")

    o.hint = o:CreateFontString(nil, "OVERLAY")
    o.hint:SetPoint("TOP", o.label, "BOTTOM", 0, P.Scale(-4))
    o.hint:SetFont(Font(), 11, "OUTLINE")
    o.hint:SetTextColor(1, 1, 1, 0.7)

    o:SetScript("OnDragStart", function() ns.Position.BeginDrag() end)
    o:SetScript("OnDragStop",  function() ns.Position.EndDrag() end)
    o:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then ns.Position.Reset() end
    end)
    o:Hide()
    moveOverlay = o
end

function Chrome.UpdateMoveOverlay()
    EnsureMoveOverlay()
    if not moveOverlay then return end

    local wanted = Chrome.optionsOpen and bar and bar:IsShown()
    -- 編輯模式自己開著的時候讓位。遮罩會吃滑鼠，蓋著就等於把編輯模式裡的
    -- 拖曳整個擋掉 —— 那是「編輯模式裡拖不動追蹤器」的成因
    if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() then
        wanted = false
    end
    if not wanted then
        moveOverlay:Hide()
        return
    end

    -- 蓋住「標題列頂 → 清單底」這一整塊視覺範圍，不是追蹤器的框 ——
    -- 追蹤器的框高度是編輯模式設的，通常比實際內容高一大截。
    --
    -- ⚠ 錨 bg 的時候**不要看它顯不顯示**。Layout 是無條件把 bg 的錨點與高度算好的，
    --   顯示與否是後面 UpdateVisibility 才決定的事，而隱藏的框矩形照樣解得出來。
    --   之前寫成「bg 顯示中才用它」，結果背景關掉時遮罩退回只蓋標題列那一條。
    local bottomRef = bg or bar
    moveOverlay:ClearAllPoints()
    moveOverlay:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    moveOverlay:SetPoint("BOTTOMRIGHT", bottomRef, "BOTTOMRIGHT", 0, 0)

    -- 底色用**壓暗過的**強調色而不是原色淡淡一層：遮罩底下是會動的地形，
    -- 0.18 的原色在亮的地方等於沒有，字也讀不出來。壓暗到 0.35 再拉高不透明度，
    -- 白字壓上去在任何背景都看得清楚，而色相仍然是玩家的職業色。
    -- 邊框保持原色全亮，這樣「暗面 ＋ 亮邊」的對比也把範圍講清楚了。
    local r, g, b = ns.Media.Accent()
    moveOverlay:SetBackdropColor(r * 0.35, g * 0.35, b * 0.35, 0.85)
    moveOverlay:SetBackdropBorderColor(r, g, b, 1)
    moveOverlay.label:SetFont(Font(), 14, "OUTLINE")
    moveOverlay.label:SetText(L["Drag to move"])
    moveOverlay.hint:SetFont(Font(), 11, "OUTLINE")
    -- 提示只在「我們真的接管了位置」的時候出現：沒接管的時候右鍵沒有東西可以還
    moveOverlay.hint:SetText(ns.Position.IsOverridden()
        and L["Right-click: hand the position back to Edit Mode"] or "")
    moveOverlay:Show()
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
ns.RegisterCallback("Init", "chrome", function()
    EnsureFrames()
    Chrome.Layout()

    -- 追蹤器每次重排都要重量一次背景高度。掛在事件上而不是每幀輪詢：
    -- 這些事件本來就是暴雪自己重排追蹤器的時機
    local evt = CreateFrame("Frame")
    for _, e in ipairs({
        "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "TRACKED_ACHIEVEMENT_LIST_CHANGED", "TRACKED_RECIPE_UPDATE",
        "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE",
        "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
    }) do
        evt:RegisterEvent(e)
    end
    evt:SetScript("OnEvent", function()
        T.Defer("chromeLayout", Chrome.Layout, 0.05)
    end)
end)

ns.RegisterCallback("Apply", "chrome", function()
    T.Defer("chromeLayout", Chrome.Layout, 0)
end)

-- 遮罩會吃滑鼠，所以編輯模式一開就得讓開，不然玩家在編輯模式裡拖不動追蹤器
-- （我們的遮罩蓋在上面把拖曳吃掉了）。
--
-- ⚠ 這裡刻意用**輪詢**而不是掛編輯模式的鉤子：HookScript 會把我們的程式塞進
--   EditModeManagerFrame 的執行路徑，而 EventRegistry 的回呼要寫進共用訂閱表
--   —— 那兩樣正是這支插件從頭到尾在避開的東西（見 Core/Tracker.lua 規矩 5）。
--   0.25 秒讀一次 IsShown() 是純唯讀，而且只在設定視窗開著的時候跑。
local overlayPoller

ns.RegisterCallback("OptionsShown", "chrome", function(shown)
    Chrome.optionsOpen = shown and true or false

    if not overlayPoller then
        overlayPoller = CreateFrame("Frame")
        local acc = 0
        overlayPoller:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 0.25 then return end
            acc = 0
            Chrome.UpdateMoveOverlay()
        end)
        overlayPoller:Hide()
    end
    overlayPoller:SetShown(Chrome.optionsOpen)

    Chrome.UpdateMoveOverlay()
end)

ns.RegisterCallback("PositionChanged", "chrome", function()
    Chrome.UpdateMoveOverlay()
end)

ns.RegisterCallback("FoldChanged", "chrome", function()
    Chrome.ApplyStyle()
    Chrome.UpdateVisibility()
end)
