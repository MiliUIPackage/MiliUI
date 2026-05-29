-- MiliUI_AdventureGuideSpecCompare/diffpanel.lua
-- 右側面板：依「其他天賦」分組顯示 多出 / 少了 / 共用 三類
--
-- 設計：
-- * 兩層收折：天賦層級（spec header）+ 分類層級（subheader）。
-- * 收折狀態存在 module-level `collapsed` 表，用 specID 當 key，重掃也不會被洗掉
--   （ns.specList 的 spec 物件每次全掃都會被 GetClassSpecs 重建）。
-- * 「共用」分類預設收折。
-- * 收折箭頭用材質（+/- button），因為 zhTW 字型缺 ▶ 字元。
-- * 所有按鈕的 script 在 _built block 一次性設定，讀取 self._xxx 欄位。

local addonName, ns = ...

-- ============================================================
-- 常數
-- ============================================================
local PANEL_WIDTH        = 280
local ITEM_HEIGHT        = 22
local SECTION_GAP        = 8
local SUBHEADER_HEIGHT   = 18
local SPEC_HEADER_HEIGHT = 26
local SCROLL_RIGHT_PAD   = 24

local TEX_EXPANDED  = "Interface\\Buttons\\UI-MinusButton-Up"  -- 已展開（按了會收）
local TEX_COLLAPSED = "Interface\\Buttons\\UI-PlusButton-Up"   -- 已收折（按了會展）

local QUALITY_COLORS = {
    [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd",
    [4] = "ffa335ee", [5] = "ffff8000", [6] = "ffe6cc80", [7] = "ff00ccff",
}

local CATEGORIES = {
    extra   = { label = "多出", color = "ff66ff66" },
    missing = { label = "少了", color = "ffff7777" },
    shared  = { label = "共用", color = "ffaaaaaa" },
}
local CATEGORY_ORDER = { "extra", "missing", "shared" }   -- 共用排最後

-- ============================================================
-- 前向宣告 + 收折狀態
-- ============================================================
local panel
local Refresh

local collapsed = {}   -- ["spec:<id>"] / ["cat:<id>:<category>"] = bool

local function isSpecCollapsed(specID)
    return collapsed["spec:" .. specID] == true
end
local function toggleSpec(specID)
    collapsed["spec:" .. specID] = not isSpecCollapsed(specID)
end

local function isCatCollapsed(specID, category)
    local key = "cat:" .. specID .. ":" .. category
    local v = collapsed[key]
    if v == nil then
        return category == "shared"   -- 共用 預設收折
    end
    return v
end
local function toggleCat(specID, category)
    local key = "cat:" .. specID .. ":" .. category
    collapsed[key] = not isCatCollapsed(specID, category)
end

-- ============================================================
-- 一次性 frame factory
-- ============================================================
local function BuildItemButton(btn)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(ITEM_HEIGHT - 4, ITEM_HEIGHT - 4)
    btn.icon:SetPoint("LEFT", 2, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

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
    f:EnableMouse(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(1, 1, 1, 0.06)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(SPEC_HEADER_HEIGHT - 6, SPEC_HEADER_HEIGHT - 6)
    f.icon:SetPoint("LEFT", 4, 0)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.arrow = f:CreateTexture(nil, "OVERLAY")
    f.arrow:SetSize(16, 16)
    f.arrow:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f.arrow, "RIGHT", 4, 0)

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("RIGHT", -6, 0)

    f:SetScript("OnMouseDown", function(self)
        if not self._specID then return end
        toggleSpec(self._specID)
        Refresh()
    end)
end

local function BuildSubHeader(f)
    f:EnableMouse(true)

    f.arrow = f:CreateTexture(nil, "OVERLAY")
    f.arrow:SetSize(14, 14)
    f.arrow:SetPoint("LEFT", 6, 0)

    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetPoint("LEFT", f.arrow, "RIGHT", 4, 0)

    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetHeight(1)
    f.line:SetPoint("LEFT", f.label, "RIGHT", 6, 0)
    f.line:SetPoint("RIGHT", -4, 0)
    f.line:SetColorTexture(0.5, 0.5, 0.5, 0.4)

    f:SetScript("OnMouseDown", function(self)
        if not self._specID or not self._category then return end
        toggleCat(self._specID, self._category)
        Refresh()
    end)
end

-- ============================================================
-- 建立 Panel
-- ============================================================
local function CreatePanel()
    if panel then return panel end
    if not EncounterJournal then return nil end

    panel = CreateFrame("Frame", "AGSCPanel", EncounterJournal, "BasicFrameTemplate")
    panel:SetSize(PANEL_WIDTH, 500)
    panel:SetPoint("TOPLEFT", EncounterJournal, "TOPRIGHT", 30, -10)
    panel:SetPoint("BOTTOMLEFT", EncounterJournal, "BOTTOMRIGHT", 30, 8)
    panel:SetFrameStrata(EncounterJournal:GetFrameStrata())
    panel:SetFrameLevel(EncounterJournal:GetFrameLevel() + 5)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)

    -- 右上 X：BasicFrameTemplate 的 CloseButton 預設就是 panel:Hide()，不寫 db，
    -- 下次開冒險指南仍會依 db.showPanel 自動跳出。

    if panel.SetTitle then
        panel:SetTitle("天賦差異")
    elseif panel.TitleText then
        panel.TitleText:SetText("天賦差異")
    end

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -28)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLL_RIGHT_PAD, 10)
    panel.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PANEL_WIDTH - SCROLL_RIGHT_PAD - 10, 1)
    scroll:SetScrollChild(content)
    panel.content = content

    panel.itemPool = CreateFramePool("Button", content, nil, function(_, b)
        b:Hide(); b:ClearAllPoints()
    end)
    panel.headerPool = CreateFramePool("Frame", content, nil, function(_, f)
        f:Hide(); f:ClearAllPoints()
    end)
    panel.subHeaderPool = CreateFramePool("Frame", content, nil, function(_, f)
        f:Hide(); f:ClearAllPoints()
    end)

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOP", 0, -40)
    empty:SetWidth(content:GetWidth() - 20)
    empty:SetJustifyH("CENTER")
    panel.empty = empty

    panel:Hide()
    return panel
end

-- ============================================================
-- 取得 pool 物件並（第一次）build
-- ============================================================
local function acquireItem(parent)
    local b = panel.itemPool:Acquire()
    if not b._built then b._built = true; BuildItemButton(b) end
    b:SetSize(parent:GetWidth() - 4, ITEM_HEIGHT)
    return b
end

local function acquireSpecHeader(parent)
    local f = panel.headerPool:Acquire()
    if not f._built then f._built = true; BuildSpecHeader(f) end
    f:SetSize(parent:GetWidth() - 4, SPEC_HEADER_HEIGHT)
    return f
end

local function acquireSubHeader(parent)
    local f = panel.subHeaderPool:Acquire()
    if not f._built then f._built = true; BuildSubHeader(f) end
    f:SetSize(parent:GetWidth() - 4, SUBHEADER_HEIGHT)
    return f
end

-- ============================================================
-- 計算差異
-- ============================================================
local function sortByName(a, b)
    return (a.name or "") < (b.name or "")
end

local function BuildDiffs()
    local diffs = {}
    if not ns.enabled then return diffs end

    for _, spec in ipairs(ns.specList) do
        if spec.id ~= ns.specID then
            local extra, shared, missing = {}, {}, {}
            for itemID, specMap in pairs(ns.itemSpecMap) do
                local info = ns.itemInfoCache[itemID]
                if info then
                    local inOther   = specMap[spec.id]
                    local inCurrent = specMap[ns.specID]
                    if inOther and inCurrent then
                        tinsert(shared, info)
                    elseif inOther then
                        tinsert(extra, info)
                    elseif inCurrent then
                        tinsert(missing, info)
                    end
                end
            end
            table.sort(extra,   sortByName)
            table.sort(missing, sortByName)
            table.sort(shared,  sortByName)
            tinsert(diffs, { spec = spec, extra = extra, shared = shared, missing = missing })
        end
    end
    return diffs
end

-- ============================================================
-- 重畫
-- ============================================================
local function showEmpty(text)
    panel.empty:SetText(text)
    panel.empty:Show()
    panel.content:SetHeight(1)
end

-- 排一個分類區塊（subheader + 視收折狀態決定要不要排 items）
local function placeSection(content, list, category, specID, y)
    if #list == 0 then return y end
    local meta = CATEGORIES[category]
    local catCollapsed = isCatCollapsed(specID, category)

    local h = acquireSubHeader(content)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
    h.label:SetText(string.format("|c%s%s (%d)|r", meta.color, meta.label, #list))
    h.arrow:SetTexture(catCollapsed and TEX_COLLAPSED or TEX_EXPANDED)
    h._specID = specID
    h._category = category
    h:Show()
    y = y - SUBHEADER_HEIGHT

    if not catCollapsed then
        for _, info in ipairs(list) do
            local btn = acquireItem(content)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
            btn.icon:SetTexture(info.icon or 134400)
            btn.name:SetText(string.format("|c%s%s|r",
                             QUALITY_COLORS[info.quality or 1] or "ffffffff",
                             info.name or ("item:" .. info.itemID)))
            btn._link   = info.link
            btn._itemID = info.itemID
            btn:Show()
            y = y - ITEM_HEIGHT
        end
    end
    return y
end

Refresh = function()
    if not panel then return end
    panel.itemPool:ReleaseAll()
    panel.headerPool:ReleaseAll()
    panel.subHeaderPool:ReleaseAll()

    if not ns.enabled then
        showEmpty("請在冒險指南選擇「職業 + 具體天賦」開始比較")
        return
    end

    local diffs = BuildDiffs()
    if #diffs == 0 then
        showEmpty("此職業只有一個天賦，沒有可比較對象")
        return
    end
    panel.empty:Hide()

    local content = panel.content
    local y = -4

    for _, d in ipairs(diffs) do
        local specID = d.spec.id
        local total = #d.extra + #d.shared + #d.missing
        local specCollapsed = isSpecCollapsed(specID)

        local header = acquireSpecHeader(content)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
        header.icon:SetTexture(d.spec.icon)
        header.title:SetText(d.spec.name)
        header.count:SetText(total .. " 件")
        header.arrow:SetTexture(specCollapsed and TEX_COLLAPSED or TEX_EXPANDED)
        header._specID = specID
        header:Show()
        y = y - SPEC_HEADER_HEIGHT - 2

        if not specCollapsed then
            for _, key in ipairs(CATEGORY_ORDER) do
                y = placeSection(content, d[key], key, specID, y)
            end
            y = y - SECTION_GAP
        end
    end

    content:SetHeight(math.max(1, -y + 10))
end
ns.RefreshPanel = Refresh

-- ============================================================
-- Toggle
-- ============================================================
-- 只在「這次」切換顯示；不寫 db，下次開冒險指南仍會強制顯示
function ns.TogglePanel()
    if not panel then panel = CreatePanel() end
    if not panel then return end
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
        Refresh()
    end
end

-- ============================================================
-- 註冊
-- ============================================================
ns.RegisterOnEJLoaded(function()
    if ns._panelInited then return end
    ns._panelInited = true

    CreatePanel()

    -- toggle 按鈕（EJ 標題列右上）
    local toggle = CreateFrame("Button", "AGSCToggle", EncounterJournal, "UIPanelButtonTemplate")
    toggle:SetSize(80, 22)
    toggle:SetText("天賦差異")
    toggle:SetFrameLevel(EncounterJournal:GetFrameLevel() + 10)
    local closeBtn = EncounterJournal.CloseButton or _G["EncounterJournalCloseButton"]
    if closeBtn then
        toggle:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    else
        toggle:SetPoint("TOPRIGHT", EncounterJournal, "TOPRIGHT", -30, -4)
    end
    toggle:SetScript("OnClick", ns.TogglePanel)
    ns.toggle = toggle

    -- EJ 顯示時強制顯示面板；EJ 隱藏時跟著收
    EncounterJournal:HookScript("OnShow", function()
        if panel then
            panel:Show()
            Refresh()
        end
    end)
    EncounterJournal:HookScript("OnHide", function()
        if panel then panel:Hide() end
    end)

    -- reload 情境：EJ 已開啟就馬上顯示
    if EncounterJournal:IsShown() and panel then
        panel:Show()
        Refresh()
    end
end)

ns.RegisterOnScanned(function()
    if panel and panel:IsShown() then Refresh() end
end)
