------------------------------------------------------------
-- MiliUI Enhance: KeystoneLoot 裝備屬性計算
--
-- KeystoneLoot 視窗右上角外側多一顆「裝備屬性計算」按鈕，打開後視窗左邊貼一塊清單面板。
-- 在 KeystoneLoot 的裝備圖示上按右鍵 →「裝備屬性計算 › 加入計算」把那件裝備放進清單；
-- 每一列可以各自切換升級軌道（英雄／神話）與階級（1/6 ～ 6/6），面板底部加總四項次要屬性。
--
-- 掛法（都不改 KeystoneLoot 的介面檔）：
--   · 右鍵選單：包住 KSLMenuUtil.CreateContextMenu（KeystoneLoot 自帶的選單函式庫，不是暴雪的），
--     在它自己的 generator 跑完之後補我們的項目。它的右鍵選單沒有 tag，ModifyMenu 掛不上去。
--   · 按鈕與面板：掛在 UIParent、錨在 KeystoneLootFrame 上，顯示跟著它的 OnShow／OnHide 走。
--     不當它的子框 —— KeystoneLoot 有自己的視窗縮放，子框的 1px 邊與字級會跟著被縮
--     （.claude/notes/wow-1px-border-rules.md 的「框自己縮放」）。
--   · 物品連結：Upgrade:BuildItemLink 只認「目前選的軌道」，所以組連結的那一瞬間把
--     Upgrade.GetCurrentTrack 換成回傳指定階級的版本，組完立刻換回去。這樣最愛裡存的
--     bonusID、寶石附魔、特殊物品的屬性變體都照 KeystoneLoot 自己的規則走，不必抄它的表。
--
-- ⚠ 依賴 KeystoneLoot/modules/api.lua 結尾那一行本地修補（`_G.KeystoneLootNS`）。
--   它的命名空間是私有的，軌道資料與 BuildItemLink 從外面拿不到。上游更新洗掉那行時
--   這支整個靜默不啟用；守門在 .claude/scripts/check_forks.py、
--   重套跑 .claude/patches/KeystoneLoot-expose-namespace.py。
--
-- 存檔：MiliUI_DB.kslGearStats = { open, default = { track, rank }, lists = { ["名字-伺服器"] = { { id, track, rank }, … } } }
------------------------------------------------------------
local _, ns = ...

local W, P = ns.W, ns.P
local S = MiliUI.Style

local KSL       -- KeystoneLoot 的私有命名空間
local Host      -- KeystoneLootFrame

local OWNER = "MiliUI_KSLGearStats"

------------------------------------------------------------
-- 常數
------------------------------------------------------------
local TITLE = "裝備屬性計算"

-- 可以選的軌道（照使用者指定：英雄、神話）。標籤優先用 KeystoneLoot 自己的語系
local TRACKS = { "hero", "myth" }
local TRACK_LABEL = { hero = "英雄", myth = "神話" }
-- 跟 Enhance/TinyInspectRemake_TrackColors.lua 同一組軌道色
local TRACK_COLOR = { hero = "ffa335ee", myth = "ffff8000" }

-- 四項次要屬性，順序＝標籤由左到右。key 是 C_Item.GetItemStats 回傳表的欄位名
local STATS = {
    { key = "ITEM_MOD_VERSATILITY",          tag = "臨", name = STAT_VERSATILITY or "臨機應變",     color = { 0.25, 0.85, 0.80 } },
    { key = "ITEM_MOD_HASTE_RATING_SHORT",   tag = "加", name = STAT_HASTE or "加速",               color = { 1.00, 0.90, 0.10 } },
    { key = "ITEM_MOD_MASTERY_RATING_SHORT", tag = "精", name = STAT_MASTERY or "精通",             color = { 0.30, 0.90, 0.30 } },
    { key = "ITEM_MOD_CRIT_RATING_SHORT",    tag = "致", name = STAT_CRITICAL_STRIKE or "致命一擊", color = { 1.00, 0.42, 0.20 } },
}

-- 清單照部位排，同部位照加入順序
local SLOT_ORDER = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 4,
    INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WRIST = 6, INVTYPE_HAND = 7,
    INVTYPE_WAIST = 8, INVTYPE_LEGS = 9, INVTYPE_FEET = 10, INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13, INVTYPE_2HWEAPON = 13,
    INVTYPE_WEAPONMAINHAND = 13, INVTYPE_RANGED = 13, INVTYPE_RANGEDRIGHT = 13,
    INVTYPE_WEAPONOFFHAND = 14, INVTYPE_HOLDABLE = 14, INVTYPE_SHIELD = 14,
}

-- 版面
local PANEL_W  = 400
local PAD      = 8
local HEADER_H = 32
local ROW_H    = 20
local TAG      = 16     -- 屬性標籤方塊邊長
local TAG_GAP  = 2
local LEVEL_W  = 96     -- 「321 英雄 6/6」那一段
local CELL_H   = 20     -- 加總區一格的高
local DIM      = 0.65   -- 次要文字的灰階（HUD／設定視窗皮共用值）

------------------------------------------------------------
-- 存檔
------------------------------------------------------------
local charKey

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.kslGearStats
    if type(db) ~= "table" then
        db = {}
        MiliUI_DB.kslGearStats = db
    end
    if type(db.lists) ~= "table" then db.lists = {} end
    return db
end

local function GetList()
    local db = GetDB()
    if not charKey then
        local name, realm = UnitFullName("player")
        charKey = (name or "?") .. "-" .. (realm or GetRealmName() or "?")
    end
    if type(db.lists[charKey]) ~= "table" then db.lists[charKey] = {} end
    return db.lists[charKey]
end

------------------------------------------------------------
-- 軌道資料（全部來自 KeystoneLoot，換季不用改這裡）
------------------------------------------------------------
local function Ranks(track)
    local data = KSL.UpgradeTrackData and KSL.UpgradeTrackData[track]
    return data and data.ranks
end

local function TrackLabel(track)
    local label = KSL.Upgrade.GetTrackLabel and KSL.Upgrade:GetTrackLabel(track)
    return label or TRACK_LABEL[track] or track
end

-- 把一筆存檔的軌道／階級夾回合法範圍（換季後階級數變了、手改壞了存檔）
local function Normalize(entry)
    if not Ranks(entry.track) then entry.track = TRACKS[1] end
    local n = #Ranks(entry.track)
    local rank = tonumber(entry.rank) or n
    entry.rank = math.max(1, math.min(n, math.floor(rank)))
    return entry
end

-- 新加入的裝備用哪個軌道／階級：KeystoneLoot 裝等下拉目前選的（是英雄或神話的話）
-- → 上次「全部設為」選的 → 英雄滿階
local function DefaultTrackRank()
    local ok, current = pcall(KSL.Upgrade.GetCurrentTrack, KSL.Upgrade)
    if ok and type(current) == "table" and current.bonusId then
        for _, track in ipairs(TRACKS) do
            for rank, data in ipairs(Ranks(track) or {}) do
                if data.bonusId == current.bonusId then return track, rank end
            end
        end
    end
    local def = GetDB().default
    if type(def) == "table" and Ranks(def.track) then
        local e = Normalize({ track = def.track, rank = def.rank })
        return e.track, e.rank
    end
    return TRACKS[1], #Ranks(TRACKS[1])
end

------------------------------------------------------------
-- 物品連結與屬性
------------------------------------------------------------
-- 指定軌道／階級的物品連結。見檔頭：借 KeystoneLoot 的 BuildItemLink，只把「目前軌道」換掉
local function BuildLink(itemId, track, rank)
    local ranks = Ranks(track)
    local rankData = ranks and ranks[rank]
    if not rankData then return nil end

    local Upgrade = KSL.Upgrade
    local original = Upgrade.GetCurrentTrack
    Upgrade.GetCurrentTrack = function() return rankData end
    local ok, link = pcall(Upgrade.BuildItemLink, Upgrade, itemId)
    Upgrade.GetCurrentTrack = original

    return ok and link or nil
end

-- 套裝部位（催化器欄那一排）：KeystoneLoot 的提示寫得很清楚——用套裝代幣換的吃套裝件自己的
-- 次要屬性，用催化器轉的吃「底材」的。使用者有把某件標成「催化器」時，那個部位就照底材算。
local function CatalystBase(itemId)
    local catalyst = KSL.CatalystDatabase and KSL.CatalystDatabase[itemId]
    if not catalyst or not KSL.Favorites or not KSL.Favorites.GetCatalystItemForSlot then return nil end
    local ok, baseId = pcall(KSL.Favorites.GetCatalystItemForSlot, KSL.Favorites, catalyst.slotId)
    return ok and baseId or nil
end

local function IsCached(itemId)
    if C_Item.IsItemDataCachedByID(itemId) then return true end
    C_Item.RequestLoadItemDataByID(itemId)
    return false
end

-- 一筆清單項目 → 顯示與加總要用的資料。物品資料還沒到貨時 loading = true，
-- 之後 GET_ITEM_INFO_RECEIVED 會再刷一次
local function Resolve(entry)
    local info = { stats = {} }
    local ranks = Ranks(entry.track)
    info.ilvl = ranks[entry.rank].ilvl

    if not IsCached(entry.id) then
        info.loading = true
        return info
    end

    local link = BuildLink(entry.id, entry.track, entry.rank)
    if not link then
        info.loading = true
        return info
    end
    info.link = link

    local name, realLink, quality = C_Item.GetItemInfo(link)
    info.name, info.realLink, info.quality = name, realLink, quality
    if not name then info.loading = true end

    -- 自訂物品（從 keystoneloot.io 匯入的）不吃軌道，裝等以連結實際算出來的為準
    local actual = C_Item.GetDetailedItemLevelInfo(link)
    if actual and actual > 0 then info.ilvl = actual end

    local statsLink = link
    local baseId = CatalystBase(entry.id)
    if baseId and baseId ~= entry.id then
        if IsCached(baseId) then
            statsLink = BuildLink(baseId, entry.track, entry.rank) or link
            info.baseName = C_Item.GetItemInfo(baseId)
        else
            info.loading = true
        end
    end

    local stats = C_Item.GetItemStats(statsLink)
    if stats then
        for i, stat in ipairs(STATS) do
            info.stats[i] = stats[stat.key] or 0
        end
    end
    return info
end

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function NewText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(S.Font, size or 12, "")   -- 先給字型才能 SetText
    fs:SetShadowColor(0, 0, 0)
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(1, 1, 1)
    fs:SetWordWrap(false)
    return fs
end

-- 髮絲線：粗細在排版時才換算（P.Pixel），貼圖關掉像素貼齊
local function NewHairline(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 0.12)
    P.NoSnap(t)
    return t
end

-- 屬性標籤方塊。on = 這件有這項屬性：屬性色的字＋1px 屬性色邊＋壓暗的同色底；
-- 沒有就只剩一個暗灰的字（不畫框），四格位置固定，一眼掃得出哪一欄是空的
local function NewTag(parent, stat)
    local tag = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tag:SetSize(TAG, TAG)
    tag.stat = stat
    tag.text = NewText(tag, 11)
    tag.text:SetPoint("CENTER", 0, 0)
    tag.text:SetText(stat.tag)
    return tag
end

local function PaintTag(tag, on)
    local px = P.Pixel(1)
    if tag._px ~= px then          -- UI 縮放變了才重鋪 backdrop
        tag._px = px
        W.Stylize(tag)
    end
    local r, g, b = unpack(tag.stat.color)
    if on then
        tag:SetBackdropColor(r * 0.22, g * 0.22, b * 0.22, 1)
        tag:SetBackdropBorderColor(r, g, b, 1)
        tag.text:SetTextColor(r, g, b)
    else
        tag:SetBackdropColor(0, 0, 0, 0)
        tag:SetBackdropBorderColor(0, 0, 0, 0)
        tag.text:SetTextColor(0.28, 0.28, 0.28)
    end
end

------------------------------------------------------------
-- 清單操作
------------------------------------------------------------
local panel, toggle
local Refresh, SetOpen   -- 前置宣告

local function FindIndex(itemId)
    for i, entry in ipairs(GetList()) do
        if entry.id == itemId then return i end
    end
end

local function AddItem(itemId)
    if FindIndex(itemId) then return end
    local track, rank = DefaultTrackRank()
    table.insert(GetList(), { id = itemId, track = track, rank = rank })
end

local function RemoveItem(itemId)
    local index = FindIndex(itemId)
    if index then table.remove(GetList(), index) end
end

-- 軌道選單的項目。isActive(track, rank) 決定哪一格打勾（「全部設為」不打勾）
local function TrackMenuItems(isActive, onPick)
    local items = {}
    for _, track in ipairs(TRACKS) do
        local ranks = Ranks(track)
        if ranks then
            items[#items + 1] = { text = TrackLabel(track), isTitle = true }
            for rank, data in ipairs(ranks) do
                items[#items + 1] = {
                    text = string.format("%d/%d", rank, #ranks),
                    value = tostring(data.ilvl),
                    isActive = isActive and isActive(track, rank) or false,
                    onClick = function() onPick(track, rank) end,
                }
            end
        end
    end
    return items
end

------------------------------------------------------------
-- 列
------------------------------------------------------------
local rows = {}

local function RowHover(row)
    row.hl:SetShown(row:IsMouseOver())
end

local function RowTooltip(row)
    local info = row.info
    if not info or not info.link then return end
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPRIGHT", row, "TOPLEFT", -(PAD + 4), 0)
    GameTooltip:SetHyperlink(info.link)
    if info.baseName then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("次要屬性以催化器底材計算：" .. info.baseName, 0.62, 0.36, 0.72, true)
    end
    GameTooltip:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_H)

    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 1, 1, 0.06)
    row.hl:Hide()

    row.tags = {}
    for i, stat in ipairs(STATS) do
        local tag = NewTag(row, stat)
        tag:SetPoint("LEFT", (i - 1) * (TAG + TAG_GAP), 0)
        row.tags[i] = tag
    end
    local tagsW = #STATS * TAG + (#STATS - 1) * TAG_GAP

    -- 裝等＋軌道：點它開選單換軌道／階級
    local level = CreateFrame("Button", nil, row)
    level:SetSize(LEVEL_W, ROW_H - 2)
    level:SetPoint("LEFT", tagsW + 6, 0)
    level.bg = level:CreateTexture(nil, "BACKGROUND")
    level.bg:SetAllPoints()
    level.bg:SetColorTexture(1, 1, 1, 0.10)
    level.bg:Hide()
    level.text = NewText(level, 12)
    level.text:SetPoint("LEFT", 3, 0)
    level:SetScript("OnEnter", function(self) self.bg:Show(); RowHover(row) end)
    level:SetScript("OnLeave", function(self) self.bg:Hide(); RowHover(row) end)
    level:SetScript("OnClick", function(self)
        local entry = row.entry
        if not entry then return end
        W.Menu.Show(TrackMenuItems(
            function(track, rank) return entry.track == track and entry.rank == rank end,
            function(track, rank)
                entry.track, entry.rank = track, rank
                Refresh()
            end), self)
    end)
    row.level = level

    -- 移除
    local remove = CreateFrame("Button", nil, row)
    remove:SetSize(16, 16)
    remove:SetPoint("RIGHT", 0, 0)
    remove.text = NewText(remove, 14)
    remove.text:SetPoint("CENTER", 0, 0)
    remove.text:SetText("×")
    remove.text:SetTextColor(DIM, DIM, DIM)
    remove:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.3, 0.3); RowHover(row) end)
    remove:SetScript("OnLeave", function(self) self.text:SetTextColor(DIM, DIM, DIM); RowHover(row) end)
    remove:SetScript("OnClick", function()
        if row.entry then
            RemoveItem(row.entry.id)
            Refresh()
        end
    end)
    row.remove = remove

    row.name = NewText(row, 12)
    row.name:SetPoint("LEFT", level, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", remove, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function(self) RowHover(self); RowTooltip(self) end)
    row:SetScript("OnLeave", function(self) RowHover(self); GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        -- Shift 貼連結／Ctrl 試穿：要用 GetItemInfo 回來的正式連結，自己組的那串貼不出去
        local info = self.info
        if info and info.realLink and IsModifierKeyDown() then
            HandleModifiedItemClick(info.realLink)
        end
    end)

    rows[index] = row
    return row
end

local function UpdateRow(row, entry, info)
    row.entry, row.info = entry, info

    for i, tag in ipairs(row.tags) do
        PaintTag(tag, (info.stats[i] or 0) > 0)
    end

    row.level.text:SetText(string.format("%d |c%s%s %d/%d|r",
        info.ilvl, TRACK_COLOR[entry.track] or "ffffffff", TrackLabel(entry.track),
        entry.rank, #Ranks(entry.track)))

    if info.name then
        local color = ITEM_QUALITY_COLORS[info.quality or 4] or ITEM_QUALITY_COLORS[4]
        row.name:SetText(string.format("[%s]", info.name))
        row.name:SetTextColor(color.r, color.g, color.b)
    else
        row.name:SetText("載入中")
        row.name:SetTextColor(DIM, DIM, DIM)
    end
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
local waiting = false    -- 還有物品資料沒到貨
local refreshQueued = false

local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.1, function()
        refreshQueued = false
        if panel and panel:IsShown() then Refresh() end
    end)
end

-- KeystoneLoot 左邊本來就可能貼著一塊「自訂物品」面板（有匯入才出現），有的話排在它外側
local function Reanchor()
    if not panel then return end
    panel:ClearAllPoints()
    local custom = Host.CustomItemFrame
    if custom and custom:IsShown() then
        -- 它在視窗頂邊往下 40（KeystoneLoot 的單位）；換算成我們的單位把頂邊對回視窗頂
        local ratio = Host:GetEffectiveScale() / panel:GetEffectiveScale()
        panel:SetPoint("TOPRIGHT", custom, "TOPLEFT", -2, 40 * ratio)
    else
        panel:SetPoint("TOPRIGHT", Host, "TOPLEFT", -2, 0)
    end
end

local function CreatePanel()
    panel = W.CreateFrame(nil, UIParent, PANEL_W, 100, true)
    panel:SetFrameStrata(Host:GetFrameStrata())
    panel:SetClampedToScreen(false)
    panel:Hide()

    panel.title = NewText(panel, 14)
    panel.title:SetPoint("TOPLEFT", PAD, -9)
    panel.title:SetText(TITLE)

    -- 清空是破壞性動作 → red；全部設為會開選單 → normal（按鈕上色規則第 5、7 條）
    panel.clear = W.CreateButton(panel, "清空", "red", 44, 20)
    panel.clear:SetPoint("TOPRIGHT", -PAD, -6)
    panel.clear:SetScript("OnClick", function()
        wipe(GetList())
        Refresh()
    end)

    panel.setAll = W.CreateButton(panel, "全部設為", "normal", 70, 20)
    panel.setAll:SetPoint("RIGHT", panel.clear, "LEFT", -4, 0)
    panel.setAll:SetScript("OnClick", function(self)
        W.Menu.Show(TrackMenuItems(nil, function(track, rank)
            for _, entry in ipairs(GetList()) do
                entry.track, entry.rank = track, rank
            end
            GetDB().default = { track = track, rank = rank }
            Refresh()
        end), self)
    end)

    panel.headerLine = NewHairline(panel)
    panel.headerLine:SetPoint("TOPLEFT", PAD, -HEADER_H)
    panel.headerLine:SetPoint("TOPRIGHT", -PAD, -HEADER_H)

    panel.empty = NewText(panel, 12)
    panel.empty:SetPoint("TOP", 0, -(HEADER_H + 18))
    panel.empty:SetTextColor(DIM, DIM, DIM)
    panel.empty:SetText("在右側的裝備圖示上按右鍵 →「加入計算」")

    -- 加總區：2×2 四格，各一項次要屬性
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetPoint("BOTTOMLEFT", PAD, PAD)
    footer:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    footer:SetHeight(6 + CELL_H * 2 + 4 + 14)
    panel.footer = footer

    footer.line = NewHairline(footer)
    footer.line:SetPoint("TOPLEFT", 0, 0)
    footer.line:SetPoint("TOPRIGHT", 0, 0)

    local cellW = (PANEL_W - PAD * 2) / 2
    footer.cells = {}
    for i, stat in ipairs(STATS) do
        local cell = CreateFrame("Frame", nil, footer)
        cell:SetSize(cellW, CELL_H)
        cell:SetPoint("TOPLEFT", ((i - 1) % 2) * cellW, -6 - math.floor((i - 1) / 2) * CELL_H)

        cell.tag = NewTag(cell, stat)
        cell.tag:SetPoint("LEFT", 0, 0)

        cell.name = NewText(cell, 12)
        cell.name:SetPoint("LEFT", cell.tag, "RIGHT", 5, 0)
        cell.name:SetText(stat.name)

        cell.pct = NewText(cell, 11)
        cell.pct:SetPoint("RIGHT", -10, 0)
        cell.pct:SetJustifyH("RIGHT")
        cell.pct:SetTextColor(DIM, DIM, DIM)

        cell.value = NewText(cell, 12)
        cell.value:SetPoint("RIGHT", -44, 0)
        cell.value:SetJustifyH("RIGHT")

        footer.cells[i] = cell
    end

    footer.summary = NewText(footer, 11)
    footer.summary:SetPoint("BOTTOMLEFT", 0, 0)
    footer.summary:SetTextColor(DIM, DIM, DIM)

    panel:SetScript("OnShow", function(self)
        W.Stylize(self, S.Dark.panel)   -- 每次顯示重鋪：1px 邊照當下的 UI 縮放換算
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        Reanchor()
        Refresh()
    end)
    panel:SetScript("OnHide", function(self)
        self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        if W.Menu.Hide then W.Menu.Hide() end
    end)
    panel:SetScript("OnEvent", function()
        if waiting then QueueRefresh() end
    end)

    local custom = Host.CustomItemFrame
    if custom then
        custom:HookScript("OnShow", Reanchor)
        custom:HookScript("OnHide", Reanchor)
    end
end

Refresh = function()
    if not panel or not panel:IsShown() then return end

    local list = GetList()
    local view = {}
    for index, entry in ipairs(list) do
        Normalize(entry)
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(entry.id)
        view[#view + 1] = { entry = entry, index = index, order = SLOT_ORDER[equipLoc] or 99 }
    end
    table.sort(view, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)

    waiting = false
    local totals, levelSum = {}, 0
    for i = 1, #STATS do totals[i] = 0 end

    local y = -(HEADER_H + 4)
    for i, item in ipairs(view) do
        local row = rows[i] or CreateRow(i)
        local info = Resolve(item.entry)
        if info.loading then waiting = true end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, y)
        row:SetPoint("TOPRIGHT", -PAD, y)
        UpdateRow(row, item.entry, info)
        row:Show()
        y = y - ROW_H

        levelSum = levelSum + info.ilvl
        for s = 1, #STATS do totals[s] = totals[s] + (info.stats[s] or 0) end
    end
    for i = #view + 1, #rows do
        rows[i]:Hide()
        rows[i].entry, rows[i].info = nil, nil
    end

    local px = P.Pixel(1)
    panel.headerLine:SetHeight(px)
    panel.footer.line:SetHeight(px)

    local count = #view
    local hasItems = count > 0
    panel.empty:SetShown(not hasItems)
    panel.footer:SetShown(hasItems)
    panel.clear:SetEnabled(hasItems)
    panel.setAll:SetEnabled(hasItems)

    if hasItems then
        local sum = 0
        for s = 1, #STATS do sum = sum + totals[s] end
        for s, cell in ipairs(panel.footer.cells) do
            PaintTag(cell.tag, totals[s] > 0)
            cell.value:SetText(BreakUpLargeNumbers(totals[s]))
            cell.pct:SetText(sum > 0 and string.format("%d%%", math.floor(totals[s] / sum * 100 + 0.5)) or "")
        end
        panel.footer.summary:SetText(string.format("%d 件 · 平均裝等 %.1f", count, levelSum / count))
        panel:SetHeight(HEADER_H + 4 + count * ROW_H + 6 + panel.footer:GetHeight() + PAD)
    else
        panel:SetHeight(HEADER_H + 52)
    end
end

------------------------------------------------------------
-- 開關按鈕（KeystoneLoot 視窗右上角外側）
------------------------------------------------------------
SetOpen = function(open)
    GetDB().open = open and true or false
    if not panel then
        if not open then return end
        CreatePanel()
    end
    panel:SetShown(open and Host:IsShown())
    -- 開關型單顆按鈕：開＝primary、關＝normal
    if toggle then W.SetButtonVariant(toggle, open and "primary" or "normal") end
end

local function CreateToggle()
    toggle = W.CreateButton(UIParent, TITLE, "normal", 100, 22)
    W.FitButton(toggle, 100, 22)
    toggle:SetFrameStrata(Host:GetFrameStrata())
    toggle:SetPoint("BOTTOMRIGHT", Host, "TOPRIGHT", -2, 3)
    toggle:SetScript("OnClick", function()
        SetOpen(not GetDB().open)
    end)
    toggle:Hide()
end

local function OnHostShow()
    if not toggle then CreateToggle() end
    toggle:Show()
    SetOpen(GetDB().open)
end

local function OnHostHide()
    if toggle then toggle:Hide() end
    if panel then panel:Hide() end
end

------------------------------------------------------------
-- KeystoneLoot 右鍵選單：補「裝備屬性計算 › 加入計算」
------------------------------------------------------------
local function AddMenuEntries(owner, root)
    local itemId = owner.itemId
    if type(itemId) ~= "number" or itemId == 0 then return end
    if not KSL.Upgrade:IsUpgradeable(itemId) then return end   -- 造型、非裝備沒有屬性可算

    root:CreateDivider()
    root:CreateTitle(TITLE)
    root:CreateCheckbox("加入計算",
        function() return FindIndex(itemId) ~= nil end,
        function()
            if FindIndex(itemId) then
                RemoveItem(itemId)
            else
                AddItem(itemId)
                SetOpen(true)   -- 加進去就把清單打開，不然勾了看不到結果
            end
            Refresh()
        end)
end

local function HookContextMenu()
    local original = KSLMenuUtil.CreateContextMenu
    KSLMenuUtil.CreateContextMenu = function(owner, generator, ...)
        -- 只認裝備圖示（KeystoneLootLootIconButtonMixin）開的選單，其他呼叫原樣放行
        if type(owner) == "table" and owner.itemId and owner.UpdateVoidcoreIcon
            and type(generator) == "function" then
            local inner = generator
            generator = function(region, root, ...)
                inner(region, root, ...)
                local ok, err = pcall(AddMenuEntries, region, root)
                if not ok and ns.ReportError then ns.ReportError(err) end
            end
        end
        return original(owner, generator, ...)
    end
end

------------------------------------------------------------
-- 啟動
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if not C_AddOns.IsAddOnLoaded("KeystoneLoot") then return end

    KSL = _G.KeystoneLootNS
    Host = _G.KeystoneLootFrame
    -- 命名空間那行修補被洗掉、或上游改了這幾個接點：整支不啟用（不報錯、不留半套 UI）
    if type(KSL) ~= "table" or not Host or type(KSLMenuUtil) ~= "table"
        or type(KSLMenuUtil.CreateContextMenu) ~= "function"
        or type(KSL.Upgrade) ~= "table"
        or type(KSL.Upgrade.BuildItemLink) ~= "function"
        or type(KSL.Upgrade.GetCurrentTrack) ~= "function"
        or type(KSL.Upgrade.IsUpgradeable) ~= "function"
        or type(KSL.UpgradeTrackData) ~= "table"
        or not Ranks(TRACKS[1]) then
        KSL, Host = nil, nil
        return
    end

    HookContextMenu()
    Host:HookScript("OnShow", OnHostShow)
    Host:HookScript("OnHide", OnHostHide)
    if Host:IsShown() then OnHostShow() end

    -- 最愛變了（換催化器底材、匯入帶 bonusID 的清單）屬性可能跟著變
    if KeystoneLootAPI and KeystoneLootAPI.RegisterCallback then
        KeystoneLootAPI:RegisterCallback("FAVORITES_CHANGED", QueueRefresh, OWNER)
    end
end)
