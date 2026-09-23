-- MiliUI_AdventureGuideSpecCompare/diffpanel.lua
-- 可拖曳面板：上方下拉選單選「對照天賦」(基準)，下方：
--   * 全系共用：這個職業所有天賦都吃的裝備（獨立區塊，整排寬度，格狀排列）
--   * 其他天賦：每個非基準天賦一欄「橫向並排」，顯示相對基準的 多出 / 少了
--
-- 設計：
-- * baselineSpecID 由下拉選單控制，預設 = 冒險指南目前選的天賦(ns.specID)，換職業時重置。
-- * 面板可拖曳，位置存 db.panelPoint（相對 UIParent）。寬度依天賦欄數自動計算，高度固定。
-- * 物品列為「圖示 + 名稱」，名稱過長自動截斷；hover 看 tooltip、Shift 連結、Ctrl 試穿。

local addonName, ns = ...

local floor, ceil, max = math.floor, math.ceil, math.max

-- ============================================================
-- 常數
-- ============================================================
local COL_W            = 178   -- 每個天賦欄「跨距」（含欄間距）
local COL_PAD          = 3     -- 欄左側內縮
local COL_INNER        = COL_W - 6   -- 欄內元件實際寬度
local ITEM_HEIGHT      = 22
local ICON_SIZE        = 16
local SPEC_HEADER_H    = 24
local SUBHEADER_H      = 18
local SECTION_GAP      = 8
local PANEL_HEIGHT     = 520
local LEFT_PAD         = 8
local SCROLLBAR_PAD    = 18   -- 右側留給細捲軸
local DROPDOWN_ROW_Y   = -28
local SCROLL_TOP_Y     = -54
local MIN_CONTENT_W    = 300

local QUALITY_COLORS = {
    [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd",
    [4] = "ffa335ee", [5] = "ffff8000", [6] = "ffe6cc80", [7] = "ff00ccff",
}

-- ============================================================
-- 狀態 + 前向宣告
-- ============================================================
local panel
local Refresh

local baselineSpecID    -- 目前選的基準天賦
local baselineClassID   -- 上次決定 baseline 時的職業（換職業就重置）

-- ============================================================
-- 樣式（AGSCDB.style）
-- MILI ＝ 這次登入畫的是「米利UI」樣式。第一次建面板時定下（CreatePanel），之後不變——
-- 兩種樣式的框結構不同，換樣式要 /reload（見 core.lua 的 ns.SetStyle）。
-- ============================================================
local MILI = false
local MILI_TITLE_H = 22

-- 米利UI 樣式的色票（套組設定視窗皮，數值同 MiliUI_Skin/Core/Tokens.lua）
local MC = {
    fill             = { 0.115, 0.115, 0.115, 1 },   -- 面板底（不透明）
    titleFill        = { 0.08, 0.08, 0.08, 1 },      -- 標題列：比面板暗一階
    border           = { 0, 0, 0, 1 },               -- 1px 純黑硬邊
    textDim          = { 0.65, 0.65, 0.65 },         -- 欄位標籤、空狀態
    headerFill       = { 0.16, 0.16, 0.16, 1 },      -- 天賦欄標題（比面板亮一階）
    headerSelected   = { 0.21, 0.21, 0.21, 1 },      -- 基準天賦那一欄（再亮一階 ＋ 職業色直條）
    line             = { 0.22, 0.22, 0.22, 1 },      -- 小節標題後的髮絲線
    scrollTrack      = { 0.08, 0.08, 0.08, 1 },
    scrollThumb      = { 0.35, 0.35, 0.35, 1 },
    scrollThumbHover = { 0.5, 0.5, 0.5, 1 },
}

-- 物品名稱的字（米利UI 樣式）。名字的顏色是品質色碼，字型物件只管字型與陰影。
local itemFont
local function ItemFont()
    if not itemFont then
        itemFont = CreateFont("MiliUIAGSC_FontItem")
        itemFont:SetFont(ns.WidgetsEnv.Font(), 12, "")
        itemFont:SetTextColor(1, 1, 1)
        itemFont:SetShadowColor(0, 0, 0)
        itemFont:SetShadowOffset(1, -1)
    end
    return itemFont
end

local function SetPanelTitle(text)
    if not panel then return end
    if panel.titleText then
        panel.titleText:SetText(text)
    elseif panel.SetTitle then
        panel:SetTitle(text)
    elseif panel.TitleText then
        panel.TitleText:SetText(text)
    end
end

-- ============================================================
-- 一次性 frame factory（script 只綁一次）
-- ============================================================
local function BuildItemButton(btn)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.iconBorder = btn:CreateTexture(nil, "BORDER")   -- 1px 黑框
    btn.iconBorder:SetColorTexture(0, 0, 0, 1)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(ICON_SIZE, ICON_SIZE)
    btn.icon:SetPoint("LEFT", 2, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.iconBorder:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", -1, 1)
    btn.iconBorder:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", 1, -1)

    if MILI then
        btn.name = btn:CreateFontString(nil, "OVERLAY")
        btn.name:SetFontObject(ItemFont())
    else
        btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    btn.name:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
    btn.name:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    btn.name:SetJustifyH("LEFT")
    btn.name:SetHeight(ITEM_HEIGHT)
    btn.name:SetWordWrap(false)

    -- 「已取得」骰子（疊在物品圖示右下角往右下挪一點，與 KeystoneLoot 同一個 atlas）
    btn.lootedCheck = btn:CreateTexture(nil, "OVERLAY")
    btn.lootedCheck:SetAtlas("lootroll-toast-icon-need-up")
    btn.lootedCheck:SetSize(14, 14)
    btn.lootedCheck:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", 4, -4)
    btn.lootedCheck:Hide()

    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.hl:SetAllPoints()
    btn.hl:SetColorTexture(1, 1, 1, 0.08)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self._link then
            GameTooltip:SetHyperlink(self._link)
        elseif self._itemID then
            GameTooltip:SetItemByID(self._itemID)
        end
        -- 已取得明細（按難度 / 天賦）
        if self._itemID and ns.Looted then
            local lines = ns.Looted:GetSummaryLines(self._itemID)
            if lines then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff44ff44已取得：|r")
                for _, line in ipairs(lines) do
                    GameTooltip:AddLine("|cff44ff44  " .. line .. "|r")
                end
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then return end
        if IsModifiedClick("CHATLINK") and self._link then
            ChatEdit_InsertLink(self._link)
        elseif IsModifiedClick("DRESSUP") and self._link then
            DressUpItemLink(self._link)
        end
    end)
end

local function BuildSpecHeader(f)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(1, 1, 1, 0.08)

    f.iconBorder = f:CreateTexture(nil, "BORDER")   -- 1px 黑框
    f.iconBorder:SetColorTexture(0, 0, 0, 1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(SPEC_HEADER_H - 6, SPEC_HEADER_H - 6)
    f.icon:SetPoint("LEFT", 3, 0)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.iconBorder:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -1, 1)
    f.iconBorder:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 1, -1)

    if MILI then
        -- 基準天賦那一欄的「選中」訊號：左緣 2px 職業色直條（狀態只換明暗，色相由職業決定）
        f.accentBar = f:CreateTexture(nil, "ARTWORK")
        f.accentBar:SetColorTexture(ns.W.Accent(1))
        f.accentBar:SetPoint("TOPLEFT")
        f.accentBar:SetPoint("BOTTOMLEFT")
        f.accentBar:SetWidth(ns.P.Scale(2))
        f.accentBar:Hide()

        f.title = f:CreateFontString(nil, "OVERLAY")
        f.title:SetFontObject(ns.W.fontNormal)
    else
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
    f.title:SetPoint("RIGHT", f, "RIGHT", -2, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
end

local function BuildSubHeader(f)
    if MILI then
        f.label = f:CreateFontString(nil, "OVERLAY")
        f.label:SetFontObject(ns.W.fontSmall)
    else
        f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    f.label:SetPoint("LEFT", 4, 0)
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetHeight(MILI and ns.P.Scale(1) or 1)
    f.line:SetPoint("LEFT", f.label, "RIGHT", 6, 0)
    f.line:SetPoint("RIGHT", -4, 0)
    if MILI then
        f.line:SetColorTexture(unpack(MC.line))
    else
        f.line:SetColorTexture(0.5, 0.5, 0.5, 0.4)
    end
end

-- ============================================================
-- 位置存取
-- ============================================================
local function SavePosition()
    if not panel then return end
    local point, relativeTo, relPoint, x, y = panel:GetPoint(1)
    if not point then return end
    local relName = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or "UIParent"
    ns.db.panelPoint = { point = point, rel = relName, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition()
    panel:ClearAllPoints()
    local p = ns.db and ns.db.panelPoint
    if p and p.point then
        local relFrame = _G[p.rel] or UIParent
        panel:SetPoint(p.point, relFrame, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        panel:SetPoint("TOPLEFT", EncounterJournal, "TOPRIGHT", 30, -10)
    end
end

-- ============================================================
-- 建立 Panel
--
-- 兩種外觀（AGSCDB.style）只差在「外框＋標題列＋關閉鈕＋下拉＋勾選框＋捲軸長相」，
-- 內容區（ScrollFrame、pool、空狀態）與所有行為是同一份。
--   blizzard：BasicFrameTemplate ＋ WowStyle1DropdownTemplate ＋ UICheckButtonTemplate（原本的樣子，一行沒改）
--   miliui  ：套組設定視窗皮 —— 0.115 不透明底、1px 黑邊、直角、標題列暗一階、線條 ×，
--             下拉與勾選框走共用層 Libs/MiliUIWidgets
-- ============================================================

-- 下拉的「對照天賦」選項變了（換職業／掃描完成）時重建
local function RefreshDropdown()
    local dd = panel and panel.specDropdown
    if not dd then return end
    if MILI then
        local items, found = {}, false
        for _, spec in ipairs(ns.specList) do
            items[#items + 1] = { text = spec.name, value = spec.id }
            if spec.id == baselineSpecID then found = true end
        end
        dd:SetItems(items)
        if found then
            dd:SetSelectedValue(baselineSpecID)
        else
            dd.selected = nil
            dd.text:SetText("選擇天賦")
        end
    else
        dd:GenerateMenu()
    end
end

local function ShowSharedTooltip(self, anchor)
    GameTooltip:SetOwner(self, anchor)
    GameTooltip:AddLine("對照天賦顯示全系共用裝備")
    GameTooltip:AddLine("勾選時，最左邊「對照天賦」欄會一併列出全系共用裝備（預設勾選）。", 1, 1, 1, false)
    GameTooltip:AddLine("取消勾選則排除，避免與上方「全系共用」區塊重複。", 1, 1, 1, false)
    GameTooltip:Show()
end

local function OnSharedChanged(checked)
    if ns.db then ns.db.baselineShowShared = checked and true or false end
    Refresh()
end

-- 拖曳把手（蓋住標題列，但避開右上 X）
local function MakeDrag(height, rightGap)
    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", -rightGap, 0)
    drag:SetHeight(height)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() panel:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        SavePosition()
    end)
    panel.drag = drag
end

-- 暴雪原生樣式（原本的外框，保持原樣）
local function BuildChromeBlizzard()
    -- 以冒險指南為父框架：顯示/隱藏自動跟隨，無需任何 OnShow/OnHide 時序處理
    panel = CreateFrame("Frame", "AGSCPanel", EncounterJournal, "BasicFrameTemplate")

    MakeDrag(22, 26)

    -- 對照天賦下拉選單
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", LEFT_PAD + 2, DROPDOWN_ROW_Y - 4)
    label:SetText("對照天賦：")
    panel.ddLabel = label

    local dd = CreateFrame("DropdownButton", "AGSCSpecDropdown", panel, "WowStyle1DropdownTemplate")
    dd:SetPoint("LEFT", label, "RIGHT", 4, 0)
    dd:SetWidth(130)
    dd:SetDefaultText("選擇天賦")
    dd:SetupMenu(function(_, rootDescription)
        for _, spec in ipairs(ns.specList) do
            rootDescription:CreateRadio(
                spec.name,
                function(id) return baselineSpecID == id end,
                function(id) baselineSpecID = id; Refresh() end,
                spec.id)
        end
    end)
    panel.specDropdown = dd

    -- 「對照天賦顯示全系共用裝備」勾選框（固定右側）
    -- 預設勾選 → 基準欄「全部」清單包含全系共用裝備；
    -- 取消勾選 → 排除全系共用（避免與上方「全系共用」區塊重複）。
    local cb = CreateFrame("CheckButton", "AGSCShowShared", panel, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, DROPDOWN_ROW_Y - 1)
    local cbLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbLabel:SetPoint("RIGHT", cb, "LEFT", -2, 0)
    cbLabel:SetText("對照天賦顯示全系共用裝備")
    cb:SetChecked(ns.db and ns.db.baselineShowShared or false)
    cb:SetScript("OnEnter", function(self) ShowSharedTooltip(self, "ANCHOR_LEFT") end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    cb:SetScript("OnClick", function(self) OnSharedChanged(self:GetChecked()) end)
    panel.showSharedCheck = cb
end

-- 米利UI 樣式：套組設定視窗皮
local function BuildChromeMili()
    local W, P = ns.W, ns.P

    panel = CreateFrame("Frame", "AGSCPanel", EncounterJournal, "BackdropTemplate")
    W.Stylize(panel, MC.fill, MC.border)

    -- 標題列：比面板暗一階，畫在 1px 邊框內側
    local bar = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar:SetColorTexture(unpack(MC.titleFill))
    bar:SetPoint("TOPLEFT", P.Scale(1), -P.Scale(1))
    bar:SetPoint("TOPRIGHT", -P.Scale(1), -P.Scale(1))
    bar:SetHeight(MILI_TITLE_H)
    panel.titleBar = bar

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("LEFT", bar, "LEFT", 8, 0)
    title:SetPoint("RIGHT", bar, "RIGHT", -28, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    panel.titleText = title

    -- 關閉鈕：red（button-variants 判準 7：關閉鈕 ×），× 用兩條線自己畫
    local close = W.CreateButton(panel, "", "red", 16, 16)
    close:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    local th = P.Scale(1)
    for i = 1, 2 do
        local ln = close:CreateLine(nil, "OVERLAY")
        ln:SetColorTexture(1, 1, 1, 1)
        ln:SetThickness(th)
        if i == 1 then
            ln:SetStartPoint("TOPLEFT", 4, -4)
            ln:SetEndPoint("BOTTOMRIGHT", -4, 4)
        else
            ln:SetStartPoint("TOPRIGHT", -4, -4)
            ln:SetEndPoint("BOTTOMLEFT", 4, 4)
        end
    end
    close:SetScript("OnClick", function() panel:Hide() end)
    panel.closeButton = close

    MakeDrag(MILI_TITLE_H + 1, 24)

    -- 對照天賦下拉選單（欄位標籤＝次要灰）
    local label = panel:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(W.fontSmall)
    label:SetTextColor(unpack(MC.textDim))
    label:SetPoint("TOPLEFT", LEFT_PAD + 2, DROPDOWN_ROW_Y - 4)
    label:SetText("對照天賦：")
    panel.ddLabel = label

    local dd = W.CreateDropdown(panel, 130, {}, function(id)
        baselineSpecID = id
        Refresh()
    end)
    dd:SetPoint("LEFT", label, "RIGHT", 4, 0)
    panel.specDropdown = dd

    -- 「對照天賦顯示全系共用裝備」勾選框（固定右側，標籤在框的左邊，跟暴雪樣式同一個版面）
    local cb = W.CreateCheckButton(panel, "", OnSharedChanged)
    cb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, DROPDOWN_ROW_Y - 3)
    local cbLabel = panel:CreateFontString(nil, "OVERLAY")
    cbLabel:SetFontObject(W.fontSmall)
    cbLabel:SetTextColor(unpack(MC.textDim))
    cbLabel:SetPoint("RIGHT", cb, "LEFT", -6, 0)
    cbLabel:SetText("對照天賦顯示全系共用裝備")
    -- 點標籤也能勾：熱區往左延伸到標籤
    cb:SetHitRectInsets(-(cbLabel:GetStringWidth() + 8), 0, 0, 0)
    cb:SetChecked(ns.db and ns.db.baselineShowShared or false)
    cb:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(W.Accent(1))
        ShowSharedTooltip(self, "ANCHOR_LEFT")
    end)
    cb:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip_Hide()
    end)
    panel.showSharedCheck = cb
end

local function CreatePanel()
    if panel then return panel end
    if not EncounterJournal then return nil end

    -- 樣式在第一次建框時定下（之後換要 /reload）。共用層沒載到就退回暴雪樣式。
    MILI = (not ns.db or ns.db.style ~= "blizzard") and ns.W ~= nil and ns.W.Menu ~= nil
    ns.activeStyle = MILI and "miliui" or "blizzard"

    if MILI then BuildChromeMili() else BuildChromeBlizzard() end

    panel:SetSize(MIN_CONTENT_W + LEFT_PAD + SCROLLBAR_PAD, PANEL_HEIGHT)
    panel:SetFrameStrata("HIGH")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    RestorePosition()
    SetPanelTitle("天賦差異")

    -- 內容 scroll（自製細捲軸，無箭頭按鈕；不夠長時自動隱藏）
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", LEFT_PAD, SCROLL_TOP_Y)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_PAD, 10)
    scroll:EnableMouseWheel(true)
    panel.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(MIN_CONTENT_W, 1)
    scroll:SetScrollChild(content)
    panel.content = content

    -- 細捲軸（貼齊右緣，全高）
    -- 米利UI 樣式照套組捲軸：6px 細條、軌道 0.08、拇指 0.35、滑過提亮到 0.5
    local barW = MILI and 6 or 8
    local bar = CreateFrame("Slider", nil, panel)
    bar:SetWidth(barW)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, SCROLL_TOP_Y - 2)
    bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -7, 12)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    if MILI then
        track:SetColorTexture(unpack(MC.scrollTrack))
    else
        track:SetColorTexture(0, 0, 0, 0.30)
    end

    local thumb = bar:CreateTexture(nil, "OVERLAY")
    if MILI then
        thumb:SetColorTexture(unpack(MC.scrollThumb))
    else
        thumb:SetColorTexture(0.55, 0.55, 0.58, 0.85)
    end
    thumb:SetSize(barW, 40)
    bar:SetThumbTexture(thumb)
    bar.thumb = thumb

    if MILI then
        bar:SetScript("OnEnter", function() thumb:SetColorTexture(unpack(MC.scrollThumbHover)) end)
        bar:SetScript("OnLeave", function() thumb:SetColorTexture(unpack(MC.scrollThumb)) end)
    end

    bar:SetScript("OnValueChanged", function(_, value)
        scroll:SetVerticalScroll(value)
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local minV, maxV = bar:GetMinMaxValues()
        local new = bar:GetValue() - delta * 40
        if new < minV then new = minV elseif new > maxV then new = maxV end
        bar:SetValue(new)
    end)
    panel.scrollBar = bar

    panel.itemPool = CreateFramePool("Button", content, nil, function(_, b)
        b:Hide(); b:ClearAllPoints()
    end)
    panel.headerPool = CreateFramePool("Frame", content, nil, function(_, f)
        f:Hide(); f:ClearAllPoints()
    end)
    panel.subPool = CreateFramePool("Frame", content, nil, function(_, f)
        f:Hide(); f:ClearAllPoints()
    end)

    local empty
    if MILI then
        empty = content:CreateFontString(nil, "OVERLAY")
        empty:SetFontObject(ns.W.fontNormal)
        empty:SetTextColor(unpack(MC.textDim))
    else
        empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    end
    empty:SetPoint("TOPLEFT", 10, -10)
    empty:SetWidth(MIN_CONTENT_W - 20)
    empty:SetJustifyH("CENTER")
    panel.empty = empty

    -- 不呼叫 panel:Hide()：面板是 EncounterJournal 的子框架，
    -- 預設可見性跟隨父框架——冒險指南開著就顯示、關著就隱藏。
    return panel
end

-- ============================================================
-- pool 取件（首次 build script）
-- ============================================================
local function acquireItem(width)
    local b = panel.itemPool:Acquire()
    if not b._built then b._built = true; BuildItemButton(b) end
    b:SetSize(width, ITEM_HEIGHT)
    return b
end

local function acquireSpecHeader(width)
    local f = panel.headerPool:Acquire()
    if not f._built then f._built = true; BuildSpecHeader(f) end
    f:SetSize(width, SPEC_HEADER_H)
    return f
end

local function acquireSub(width)
    local f = panel.subPool:Acquire()
    if not f._built then f._built = true; BuildSubHeader(f) end
    f:SetSize(width, SUBHEADER_H)
    return f
end

local function fillItem(b, info)
    b.icon:SetTexture(info.icon or 134400)
    b.name:SetText(string.format("|c%s%s|r",
        QUALITY_COLORS[info.quality or 1] or "ffffffff",
        info.name or ("item:" .. info.itemID)))
    b._link   = info.link
    b._itemID = info.itemID

    -- 「已取得」骰子（資料來自 KeystoneLoot）
    if b.lootedCheck then
        local show = ns.db and ns.db.showLooted ~= false and ns.Looted
                     and ns.Looted:HasAny(info.itemID)
        b.lootedCheck:SetShown(show and true or false)
    end

    b:Show()
end

-- ============================================================
-- 計算檢視資料
-- universal = 所有天賦都吃；columns[i] = { spec, extra, missing } 相對 baseline
-- ============================================================
local function sortByName(a, b)
    return (a.name or "") < (b.name or "")
end

local function BuildView()
    if not ns.enabled or not baselineSpecID then return nil end
    local specs = ns.specList
    local base  = baselineSpecID

    -- 找出基準天賦物件
    local baseSpec
    for _, spec in ipairs(specs) do
        if spec.id == base then baseSpec = spec; break end
    end

    local universal = {}
    local baseAll = {}     -- 基準天賦的「全部」清單（受 checkbox 影響是否含共用）
    local totals  = {}     -- [specID] = 該天賦總裝備數（不受 checkbox 影響）
    local columns = {}
    for _, spec in ipairs(specs) do
        if spec.id ~= base then
            tinsert(columns, { spec = spec, extra = {}, missing = {} })
        end
    end

    local showShared = ns.db and ns.db.baselineShowShared

    for itemID, specMap in pairs(ns.itemSpecMap) do
        local info = ns.itemInfoCache[itemID]
        if info then
            local baseHas = specMap[base]

            -- 是否全系通用
            local usedByAll = true
            for _, spec in ipairs(specs) do
                if not specMap[spec.id] then usedByAll = false; break end
            end

            -- 每個天賦的總裝備數（純計數，永遠包含全系共用）
            for _, spec in ipairs(specs) do
                if specMap[spec.id] then
                    totals[spec.id] = (totals[spec.id] or 0) + 1
                end
            end

            -- 基準天賦「全部」清單：勾選才列出全系共用，否則只列非共用
            if baseHas and (not usedByAll or showShared) then
                tinsert(baseAll, info)
            end

            if usedByAll then
                tinsert(universal, info)
            else
                for _, c in ipairs(columns) do
                    local otherHas = specMap[c.spec.id]
                    if otherHas and not baseHas then
                        tinsert(c.extra, info)
                    elseif baseHas and not otherHas then
                        tinsert(c.missing, info)
                    end
                end
            end
        end
    end

    table.sort(universal, sortByName)
    table.sort(baseAll, sortByName)
    for _, c in ipairs(columns) do
        table.sort(c.extra, sortByName)
        table.sort(c.missing, sortByName)
        c.total = totals[c.spec.id] or 0
    end
    return {
        universal = universal,
        baseline  = baseSpec and { spec = baseSpec, all = baseAll, total = totals[base] or 0 } or nil,
        columns   = columns,
    }
end

-- ============================================================
-- 重畫
-- ============================================================
-- 依內容高度更新捲軸範圍，不夠長就隱藏
local function UpdateScroll()
    local scroll, content, bar = panel.scroll, panel.content, panel.scrollBar
    if not bar then return end
    local shown = scroll:GetHeight()
    local total = content:GetHeight()
    local range = total - shown
    if not shown or shown <= 0 or range < 1 then
        bar:SetMinMaxValues(0, 0)
        bar:SetValue(0)
        bar:Hide()
        scroll:SetVerticalScroll(0)
    else
        bar:SetMinMaxValues(0, range)
        if bar:GetValue() > range then bar:SetValue(range) end
        bar.thumb:SetHeight(max(24, shown * shown / total))
        bar:Show()
    end
end

-- 標題＝「{副本名稱} 天賦裝備比對」，隨目前檢視的副本變動
local function UpdateTitle()
    if not panel then return end
    local name = EJ_GetInstanceInfo and EJ_GetInstanceInfo()
    local title = (name and name ~= "") and (name .. " 天賦裝備比對") or "天賦裝備比對"
    SetPanelTitle(title)
end

local function showEmpty(text)
    panel.empty:SetText(text)
    panel.empty:Show()
    panel.content:SetHeight(1)
    UpdateScroll()
end

local function resizePanel(contentW)
    contentW = max(MIN_CONTENT_W, contentW)
    panel.content:SetWidth(contentW)
    panel:SetWidth(contentW + LEFT_PAD + SCROLLBAR_PAD)
    panel.empty:SetWidth(contentW - 20)
    return contentW
end

-- 在某欄 (x 起點) 放一個分類（subheader + items），回傳新的 y。
-- countOverride：標題括號內的數字（預設用 #list；「全部」用真實總數）。
local function placeColSection(content, list, label, color, x, y, countOverride)
    local h = acquireSub(COL_INNER)
    h:SetParent(content)
    h:SetPoint("TOPLEFT", content, "TOPLEFT", x + COL_PAD, y)
    h.label:SetText(string.format("|c%s%s (%d)|r", color, label, countOverride or #list))
    h:Show()
    y = y - SUBHEADER_H
    for _, info in ipairs(list) do
        local b = acquireItem(COL_INNER)
        b:SetParent(content)
        b:SetPoint("TOPLEFT", content, "TOPLEFT", x + COL_PAD, y)
        fillItem(b, info)
        y = y - ITEM_HEIGHT
    end
    return y
end

Refresh = function()
    if not panel then return end
    UpdateTitle()
    panel.itemPool:ReleaseAll()
    panel.headerPool:ReleaseAll()
    panel.subPool:ReleaseAll()

    if not ns.enabled then
        resizePanel(MIN_CONTENT_W)
        showEmpty("請在冒險指南左上角\n選擇一個「職業」開始比較\n（天賦可維持「所有」）")
        return
    end

    local view = BuildView()
    if not view or #view.columns == 0 then
        resizePanel(MIN_CONTENT_W)
        showEmpty("此職業只有一個天賦\n沒有可比較對象")
        return
    end
    panel.empty:Hide()

    local numCols  = 1 + #view.columns   -- 第 1 欄是基準天賦
    local contentW = resizePanel(numCols * COL_W)
    local content  = panel.content
    local y = -4

    -- 全系共用（整排寬度，格狀排列）
    if #view.universal > 0 then
        local h = acquireSub(contentW)
        h:SetParent(content)
        h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        -- 米利UI 樣式：小節標題白字（金色是暴雪的標題色，不是資訊）
        h.label:SetText(string.format(MILI and "|cffffffff全系共用 (%d)|r" or "|cffffd200全系共用 (%d)|r",
            #view.universal))
        h:Show()
        y = y - SUBHEADER_H

        for i, info in ipairs(view.universal) do
            local col  = (i - 1) % numCols
            local rowi = floor((i - 1) / numCols)
            local b = acquireItem(COL_INNER)
            b:SetParent(content)
            b:SetPoint("TOPLEFT", content, "TOPLEFT", col * COL_W + COL_PAD, y - rowi * ITEM_HEIGHT)
            fillItem(b, info)
        end
        y = y - ceil(#view.universal / numCols) * ITEM_HEIGHT - SECTION_GAP
    end

    -- 天賦欄位（橫向並排）：第 1 欄 = 基準天賦(全部)，其餘 = 多出/少了
    local columnsTop = y
    local minY = columnsTop

    -- 基準天賦欄（最左，金色標示）：全部 (總數) + 清單
    if view.baseline then
        local cy = columnsTop
        local hd = acquireSpecHeader(COL_INNER)
        hd:SetParent(content)
        hd:SetPoint("TOPLEFT", content, "TOPLEFT", COL_PAD, cy)
        if MILI then
            hd.bg:SetColorTexture(unpack(MC.headerSelected))
            hd.accentBar:Show()
        else
            hd.bg:SetColorTexture(1, 0.82, 0, 0.2)
        end
        hd.icon:SetTexture(view.baseline.spec.icon)
        hd.title:SetText(view.baseline.spec.name)
        hd:Show()
        cy = cy - SPEC_HEADER_H - 2

        -- 「全部 (總數)」：數字為真實總裝備數，不受 checkbox 影響
        cy = placeColSection(content, view.baseline.all, "全部", "ffffd200", 0, cy, view.baseline.total)
        if cy < minY then minY = cy end
    end

    -- 其他天賦欄（從第 2 欄起）：全部 (總數) 計數列 + 多出 + 少了
    for j, c in ipairs(view.columns) do
        local x  = j * COL_W
        local cy = columnsTop

        local hd = acquireSpecHeader(COL_INNER)
        hd:SetParent(content)
        hd:SetPoint("TOPLEFT", content, "TOPLEFT", x + COL_PAD, cy)
        if MILI then
            hd.bg:SetColorTexture(unpack(MC.headerFill))
            hd.accentBar:Hide()
        else
            hd.bg:SetColorTexture(1, 1, 1, 0.08)
        end
        hd.icon:SetTexture(c.spec.icon)
        hd.title:SetText(c.spec.name)
        hd:Show()
        cy = cy - SPEC_HEADER_H - 2

        -- 「全部 (總數)」純計數列（無清單），方便一眼比較各天賦總件數
        cy = placeColSection(content, {}, "全部", "ffffd200", x, cy, c.total)
        cy = placeColSection(content, c.extra,   "多出", "ff66ff66", x, cy)
        cy = placeColSection(content, c.missing, "少了", "ffff7777", x, cy)

        if cy < minY then minY = cy end
    end

    content:SetHeight(max(1, -minY + 10))
    UpdateScroll()
end
ns.RefreshPanel = Refresh

-- ============================================================
-- baseline 同步（換職業重置，否則沿用使用者選擇）
-- ============================================================
-- 預設基準天賦：
--   1. 冒險指南有選具體天賦 → 用它
--   2. 否則若冒險指南職業 = 玩家職業 → 用玩家當前天賦
--   3. 否則 → 該職業第一個天賦
local function PickDefaultBaseline()
    if ns.specID and ns.specID > 0 then return ns.specID end

    local _, _, playerClassID = UnitClass("player")
    if playerClassID == ns.classID and GetSpecialization then
        local idx = GetSpecialization()
        if idx then
            local sid = GetSpecializationInfo(idx)
            if sid then return sid end
        end
    end

    return ns.specList[1] and ns.specList[1].id or nil
end

local function specInList(specID)
    for _, s in ipairs(ns.specList) do
        if s.id == specID then return true end
    end
    return false
end

local function SyncBaseline()
    if not ns.enabled then return end
    if baselineClassID ~= ns.classID then
        baselineClassID = ns.classID
        baselineSpecID  = PickDefaultBaseline()
    elseif not specInList(baselineSpecID) then
        baselineSpecID  = PickDefaultBaseline()
    end
end

-- ============================================================
-- Toggle
-- ============================================================
-- 切換主開關（與右上按鈕同一個狀態）
function ns.TogglePanel()
    if ns.db then ns.db.featureEnabled = not ns.db.featureEnabled end
    if ns.ApplyFeatureState then
        ns.ApplyFeatureState()
    elseif panel then
        -- EJ 尚未載入過、按鈕還沒建立時的後備
        if ns.db and ns.db.featureEnabled then panel:Show() else panel:Hide() end
    end
end

-- ============================================================
-- 主開關按鈕（兩種樣式）＋ 樣式選單
-- 兩個建構函式都回傳 btn, UpdateToggleAppearance(hover)
-- ============================================================

-- 暴雪原生樣式：原本的暗金框按鈕（保持原樣）
local function CreateToggleBlizzard()
    local btn = CreateFrame("Button", "AGSCToggle", EncounterJournal, "BackdropTemplate")
    btn:SetSize(150, 26)
    btn:SetPoint("BOTTOMRIGHT", EncounterJournal, "TOPRIGHT", -6, 2)
    btn:SetFrameStrata(EncounterJournal:GetFrameStrata())
    btn:SetFrameLevel(EncounterJournal:GetFrameLevel() + 10)
    btn:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("CENTER", 0, 0)
    btn.text = btnText

    local function UpdateToggleAppearance()
        if ns.db and ns.db.featureEnabled then
            btnText:SetText("|cffffd200天賦裝備比對：開|r")
            btn:SetBackdropColor(0.15, 0.12, 0.05, 0.95)
            btn:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.9)
        else
            btnText:SetText("|cff999999天賦裝備比對：關|r")
            btn:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        end
    end
    return btn, UpdateToggleAppearance
end

-- 米利UI 樣式：套組按鈕。它是「開關」不是動作 ⇒ 不用 primary（button-variants 判準 3），
-- 關＝normal（0.115 底、黑邊）；開＝選中態：底是壓暗的職業色（保護色 × 0.30，同 primary
-- 的平時底，白字在淺色職業上也讀得到）＋ 邊框全亮職業色。滑過只提亮底，色相不變。
-- 文字一律白，開／關寫在字上。
local function ToggleColors()
    local r, g, b = ns.W.Accent()
    local lum = 0.299 * r + 0.587 * g + 0.114 * b
    local k = lum > 0 and math.min(1, 0.40 / lum) or 1   -- 保護色係數（同 Widgets.lua 的 BTN_TEXT_LUM）
    local on = {
        { r * k * 0.30, g * k * 0.30, b * k * 0.30, 1 },  -- 平時底
        { r * k * 0.50, g * k * 0.50, b * k * 0.50, 1 },  -- 滑過底
        { r, g, b, 1 },                                   -- 平時邊
        { r, g, b, 1 },                                   -- 滑過邊
    }
    -- 四格：切回「關」時邊框才會一起退回黑色（兩格的配色不換邊）
    local off = {
        { 0.115, 0.115, 0.115, 1 },
        { 0.23, 0.23, 0.23, 1 },
        { 0, 0, 0, 1 },
        { 0, 0, 0, 1 },
    }
    return on, off
end

local function CreateToggleMili()
    local W = ns.W
    local btn = W.CreateButton(EncounterJournal, "", "normal", 150, 22)
    btn:SetPoint("BOTTOMRIGHT", EncounterJournal, "TOPRIGHT", -6, 2)
    btn:SetFrameStrata(EncounterJournal:GetFrameStrata())
    btn:SetFrameLevel(EncounterJournal:GetFrameLevel() + 10)

    local on, off = ToggleColors()
    local function UpdateToggleAppearance(hover)
        if ns.db and ns.db.featureEnabled then
            btn:SetText("天賦裝備比對：開")
            btn._colors = on
        else
            btn:SetText("天賦裝備比對：關")
            btn._colors = off
        end
        if hover == nil then hover = btn:IsVisible() and btn:IsMouseOver() end
        W.PaintButton(btn, hover)
    end
    return btn, UpdateToggleAppearance
end

-- 右鍵選單：選樣式（存 AGSCDB.style，/reload 生效）
local function ShowStyleMenu(owner)
    local cur = ns.db and ns.db.style or "miliui"
    local pending = cur ~= ns.activeStyle
    if MILI then
        local Menu = ns.W.Menu
        if Menu.IsOpenFor(owner) then Menu.Hide() return end
        GameTooltip_Hide()
        local items = {
            { text = "面板樣式", isTitle = true },
            { text = ns.STYLE_NAMES.miliui,   isActive = cur == "miliui",
              onClick = function() ns.SetStyle("miliui") end },
            { text = ns.STYLE_NAMES.blizzard, isActive = cur == "blizzard",
              onClick = function() ns.SetStyle("blizzard") end },
        }
        if pending then
            items[#items + 1] = { isSeparator = true }
            items[#items + 1] = { text = "重新載入介面以套用", onClick = function() ReloadUI() end }
        end
        Menu.Show(items, owner)
    else
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateTitle("面板樣式")
            for _, style in ipairs({ "miliui", "blizzard" }) do
                root:CreateRadio(ns.STYLE_NAMES[style],
                    function() return (ns.db and ns.db.style) == style end,
                    function() ns.SetStyle(style) end)
            end
            if pending then
                root:CreateDivider()
                root:CreateButton("重新載入介面以套用", function() ReloadUI() end)
            end
        end)
    end
end

-- ============================================================
-- 註冊
-- ============================================================
ns.RegisterOnEJLoaded(function()
    if ns._panelInited then return end
    ns._panelInited = true

    CreatePanel()

    -- 主開關按鈕（錨在冒險指南右上角上方）
    local btn, UpdateToggleAppearance
    if MILI then
        btn, UpdateToggleAppearance = CreateToggleMili()
    else
        btn, UpdateToggleAppearance = CreateToggleBlizzard()
    end

    -- 依主開關狀態套用面板顯示
    local function ApplyFeatureState()
        UpdateToggleAppearance()
        if not panel then return end
        if ns.db and ns.db.featureEnabled and EncounterJournal:IsShown() then
            SyncBaseline()
            panel:Show()
            RefreshDropdown()
            Refresh()
        else
            panel:Hide()
        end
    end
    ns.ApplyFeatureState = ApplyFeatureState

    -- 左鍵＝開關；右鍵＝樣式選單
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ShowStyleMenu(self)
            return
        end
        if ns.db then ns.db.featureEnabled = not ns.db.featureEnabled end
        ApplyFeatureState()
    end)
    btn:SetScript("OnEnter", function(self)
        if MILI then
            ns.W.PaintButton(self, true)
            -- 選單開著時不疊提示
            if ns.W.Menu.IsOpenFor(self) then return end
        else
            btn:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        GameTooltip:SetText("天賦裝備比對", 1, 1, 1)
        GameTooltip:AddLine("由 MiliUI 提供。", 0.7, 0.7, 0.7, false)
        GameTooltip:AddLine("在冒險指南右側顯示同職業各天賦的裝備差異。", 0.7, 0.7, 0.7, false)
        GameTooltip:AddLine("右鍵：切換面板樣式（米利UI／暴雪原生）", 0.7, 0.7, 0.7, false)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        UpdateToggleAppearance(false)
        GameTooltip_Hide()
    end)
    ns.toggle = btn

    -- EJ 顯示時，依主開關決定是否顯示面板（面板為子框架，關閉 EJ 自動隱藏）
    EncounterJournal:HookScript("OnShow", function()
        if not panel then return end
        if ns.db and ns.db.featureEnabled == false then
            panel:Hide()
            return
        end
        SyncBaseline()
        panel:Show()
        RefreshDropdown()
        Refresh()
    end)

    -- 初始套用（含 EJ 已開著的情況）
    ApplyFeatureState()
end)

-- 每次掃描完成：更新內容（面板已顯示時）
ns.RegisterOnScanned(function()
    SyncBaseline()
    if panel and panel:IsShown() then
        RefreshDropdown()
        Refresh()
    end
end)
