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

    btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.name:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
    btn.name:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
    btn.name:SetJustifyH("LEFT")
    btn.name:SetHeight(ITEM_HEIGHT)
    btn.name:SetWordWrap(false)

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

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
    f.title:SetPoint("RIGHT", f, "RIGHT", -2, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
end

local function BuildSubHeader(f)
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetPoint("LEFT", 4, 0)
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetHeight(1)
    f.line:SetPoint("LEFT", f.label, "RIGHT", 6, 0)
    f.line:SetPoint("RIGHT", -4, 0)
    f.line:SetColorTexture(0.5, 0.5, 0.5, 0.4)
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
-- ============================================================
local function CreatePanel()
    if panel then return panel end
    if not EncounterJournal then return nil end

    -- 以冒險指南為父框架：顯示/隱藏自動跟隨，無需任何 OnShow/OnHide 時序處理
    panel = CreateFrame("Frame", "AGSCPanel", EncounterJournal, "BasicFrameTemplate")
    panel:SetSize(MIN_CONTENT_W + LEFT_PAD + SCROLLBAR_PAD, PANEL_HEIGHT)
    panel:SetFrameStrata("HIGH")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    RestorePosition()

    if panel.SetTitle then
        panel:SetTitle("天賦差異")
    elseif panel.TitleText then
        panel.TitleText:SetText("天賦差異")
    end

    -- 拖曳把手（蓋住標題列，但避開右上 X）
    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", -26, 0)
    drag:SetHeight(22)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() panel:StartMoving() end)
    drag:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        SavePosition()
    end)
    panel.drag = drag

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
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("對照天賦顯示全系共用裝備")
        GameTooltip:AddLine("勾選時，最左邊「對照天賦」欄會一併列出全系共用裝備（預設勾選）。", 1, 1, 1, false)
        GameTooltip:AddLine("取消勾選則排除，避免與上方「全系共用」區塊重複。", 1, 1, 1, false)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    cb:SetScript("OnClick", function(self)
        if ns.db then ns.db.baselineShowShared = self:GetChecked() and true or false end
        Refresh()
    end)
    panel.showSharedCheck = cb

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
    local bar = CreateFrame("Slider", nil, panel)
    bar:SetWidth(8)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, SCROLL_TOP_Y - 2)
    bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -7, 12)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.30)

    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.55, 0.55, 0.58, 0.85)
    thumb:SetSize(8, 40)
    bar:SetThumbTexture(thumb)
    bar.thumb = thumb

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

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
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
        h.label:SetText(string.format("|cffffd200全系共用 (%d)|r", #view.universal))
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
        hd.bg:SetColorTexture(1, 0.82, 0, 0.2)
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
        hd.bg:SetColorTexture(1, 1, 1, 0.08)
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
-- 註冊
-- ============================================================
ns.RegisterOnEJLoaded(function()
    if ns._panelInited then return end
    ns._panelInited = true

    CreatePanel()

    -- 主開關按鈕（MiliUI 風格，錨在冒險指南右上角上方）
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

    -- 依主開關狀態套用面板顯示
    local function ApplyFeatureState()
        UpdateToggleAppearance()
        if not panel then return end
        if ns.db and ns.db.featureEnabled and EncounterJournal:IsShown() then
            SyncBaseline()
            panel:Show()
            if panel.specDropdown then panel.specDropdown:GenerateMenu() end
            Refresh()
        else
            panel:Hide()
        end
    end
    ns.ApplyFeatureState = ApplyFeatureState

    btn:SetScript("OnClick", function()
        if ns.db then ns.db.featureEnabled = not ns.db.featureEnabled end
        ApplyFeatureState()
    end)
    btn:SetScript("OnEnter", function(self)
        btn:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        GameTooltip:SetText("天賦裝備比對", 1, 1, 1)
        GameTooltip:AddLine("由 MiliUI 提供。", 0.7, 0.7, 0.7, false)
        GameTooltip:AddLine("在冒險指南右側顯示同職業各天賦的裝備差異。", 0.7, 0.7, 0.7, false)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        UpdateToggleAppearance()
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
        if panel.specDropdown then panel.specDropdown:GenerateMenu() end
        Refresh()
    end)

    -- 初始套用（含 EJ 已開著的情況）
    ApplyFeatureState()
end)

-- 每次掃描完成：更新內容（面板已顯示時）
ns.RegisterOnScanned(function()
    SyncBaseline()
    if panel and panel:IsShown() then
        if panel.specDropdown then panel.specDropdown:GenerateMenu() end
        Refresh()
    end
end)
