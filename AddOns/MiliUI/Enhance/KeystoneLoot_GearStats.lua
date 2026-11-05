------------------------------------------------------------
-- MiliUI Enhance: KeystoneLoot 裝備屬性計算
--
-- KeystoneLoot 視窗右上角外側多一顆「裝備屬性計算」按鈕，打開後視窗左邊貼一塊清單面板。
-- 在 KeystoneLoot 的裝備圖示上按右鍵 →「裝備屬性計算 › 加入計算」把那件裝備放進清單；
-- 每一列可以各自切換升級軌道（英雄／神話）與階級（1/6 ～ 6/6）。
--
-- 算的是「拿到這件之後的全身」：基準是身上十六格裝備的次要屬性加總，清單裡每一件
-- 把它要取代的那一格扣掉、再加上自己。面板底部列出目前 → 模擬後、變化量與佔比。
--   · 兩格的部位（戒指、飾品、能雙持時的單手武器）每列有一顆按鈕選要取代哪一格。
--   · 同一格只能有一件算數：點列切換「納入／排除」，納入一件會把撞格的另一件排除。
--   · 雙手武器進主手會連副手一起換下（身上是雙持雙手武器時例外，那時當兩格部位）。
--   · 只比裝備本身的屬性：身上那件的附魔與寶石先從連結裡拿掉再算，兩邊才對等。
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
-- 存檔：MiliUI_DB.kslGearStats = { open, default = { track, rank },
--         lists = { ["名字-伺服器"] = { { id, track, rank, slot, off }, … } } }
--   slot＝兩格部位選的裝備格編號（單格部位不存）；off＝true 是排除在模擬之外
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
for _, stat in ipairs(STATS) do
    stat.hex = string.format("ff%02x%02x%02x", stat.color[1] * 255, stat.color[2] * 255, stat.color[3] * 255)
end

-- 部位 → 可以放進去的裝備格。兩格的讓使用者選要取代哪一格
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 },
}
local MAIN_HAND  = { 16 }
local BOTH_HANDS = { 16, 17 }
local OFF_HAND   = 17
-- 兩格部位的格名（按鈕與選單用）；單格部位直接用暴雪的部位名（_G[equipLoc]）
local SLOT_NAME = { [11] = "戒指1", [12] = "戒指2", [13] = "飾品1", [14] = "飾品2", [16] = "主手", [17] = "副手" }
-- 全身十六格（不含襯衣、外袍），也是平均裝等的分母
local BODY_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }

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
local SLOT_W   = 44     -- 兩格部位的「戒指1」按鈕
local CELL_H   = 18     -- 加總區一列的高
local COLHEAD_H = 14    -- 加總區欄名那一列
local EMPTY_H  = 44     -- 清單是空的時候，提示文字佔的高
local OFF_ALPHA = 0.35  -- 排除在模擬之外的列
local DIM      = 0.65   -- 次要文字的灰階（HUD／設定視窗皮共用值）
-- 加總區各欄的右緣（從面板內容右緣往左量）
local COL_PCT, COL_DELTA, COL_AFTER, COL_ARROW, COL_BEFORE = 0, 44, 104, 160, 178

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
-- 身上的裝備與模擬
------------------------------------------------------------
-- 雙手武器：主手拿著、副手空著時，平均裝等把它算兩次；進主手會把副手換下。
-- 弓是 INVTYPE_RANGED，槍弩與魔杖共用 INVTYPE_RANGEDRIGHT —— 魔杖（子類 19）是單手
local function IsTwoHand(item)
    local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(item)
    if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED" then return true end
    return equipLoc == "INVTYPE_RANGEDRIGHT" and classID == 2 and subClassID ~= 19
end

-- 身上那件的附魔與寶石（物品字串第 2～6 欄）先清掉再問屬性：清單裡的是素的，兩邊要對等
local function BareLink(link)
    return (link:gsub("(item:%d+):[^:|]*:[^:|]*:[^:|]*:[^:|]*:[^:|]*:", "%1::::::", 1))
end

-- 身上十六格的快照：body[格] = { link, name, ilvl, stats[1..4], twoHand }，空格是 nil。
-- 另帶兩個旗標：dualWield（單手武器可以進副手）、titanGrip（雙手武器當單手拿）
local function ReadEquipped()
    local body = {}
    for _, slot in ipairs(BODY_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local item = { link = link, stats = {} }
            local stats = C_Item.GetItemStats(BareLink(link))
            for i, stat in ipairs(STATS) do
                item.stats[i] = stats and stats[stat.key] or 0
            end
            item.name = C_Item.GetItemInfo(link)
            local ok, ilvl = pcall(C_Item.GetCurrentItemLevel, ItemLocation:CreateFromEquipmentSlot(slot))
            item.ilvl = (ok and ilvl) or C_Item.GetDetailedItemLevelInfo(link) or 0
            item.twoHand = IsTwoHand(link)
            body[slot] = item
        end
    end

    local off = body[OFF_HAND]
    local offIsWeapon = false
    if off then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(off.link)
        offIsWeapon = classID == 2
    end
    body.dualWield = offIsWeapon or (type(CanDualWield) == "function" and CanDualWield()) or false
    body.titanGrip = offIsWeapon and ((off.twoHand or (body[16] and body[16].twoHand)) and true or false)
    return body
end

-- 這件可以放進哪幾格，以及放進主手時會不會連副手一起換下（雙手武器）
local function SlotsFor(itemId, body)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemId)
    local slots = EQUIP_SLOTS[equipLoc]
    if not slots then return nil end
    if equipLoc == "INVTYPE_WEAPON" then
        if not body.dualWield then slots = MAIN_HAND end
    elseif IsTwoHand(itemId) then
        if body.titanGrip then return BOTH_HANDS, false end
        return slots, true
    end
    return slots, false
end

-- 剛加入／剛被點成「納入」／剛換格的那一筆：撞格時它贏，原本佔著那格的被排除
local priority

-- 排出每一筆要取代哪一格、算不算數。回傳 plan[entry] = { slot, slots, clears }（沒有對應裝備格的不在表裡）
--   · 單格部位沒得選；兩格的用存檔裡選的那格，沒選過（或那格現在不合法）就挑還沒被佔走的
--   · 同一格只能有一件算數：priority 先佔，其餘照清單順序先到先得，撞格的寫成 entry.off
local function Plan(list, body)
    local plan, claimed = {}, {}
    for _, entry in ipairs(list) do
        local slots, clears = SlotsFor(entry.id, body)
        if slots then
            local slot
            if #slots == 1 then
                slot, entry.slot = slots[1], nil
            else
                for _, s in ipairs(slots) do
                    if s == entry.slot then slot = s end
                end
                if not slot then entry.slot = nil end
            end
            plan[entry] = { slots = slots, clears = clears, slot = slot }
            if slot and not entry.off then claimed[slot] = true end
        end
    end
    for _, entry in ipairs(list) do
        local p = plan[entry]
        if p and not p.slot then
            p.slot = p.slots[1]
            for _, s in ipairs(p.slots) do
                if not claimed[s] then p.slot = s break end
            end
            entry.slot = p.slot
            if not entry.off then claimed[p.slot] = true end
        end
    end

    local taken = {}
    local function Settle(entry)
        local p = plan[entry]
        if not p or entry.off then return end
        if taken[p.slot] or (p.clears and taken[OFF_HAND]) then
            entry.off = true
            return
        end
        taken[p.slot] = true
        if p.clears then taken[OFF_HAND] = true end
    end
    if priority then Settle(priority) end
    for _, entry in ipairs(list) do
        if entry ~= priority then Settle(entry) end
    end
    priority = nil
    return plan
end

-- 跟暴雪同一條規則的平均裝等：十六格相加除以十六；主手是雙手武器而副手空著時主手算兩次
local function AverageLevel(levels, twoHandMain)
    local sum = 0
    for _, slot in ipairs(BODY_SLOTS) do sum = sum + (levels[slot] or 0) end
    if twoHandMain and not levels[OFF_HAND] then sum = sum + (levels[16] or 0) end
    return sum / #BODY_SLOTS
end

local function SignedNumber(n)
    return (n > 0 and "+" or "-") .. BreakUpLargeNumbers(math.abs(n))
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
    local entry = { id = itemId, track = track, rank = rank }
    table.insert(GetList(), entry)
    priority = entry   -- 新加入的那件算數，同一格原本算數的讓位
end

-- 把這一筆納入模擬（撞格的另一件在下一次 Plan 被排除）
local function Claim(entry)
    entry.off = nil
    priority = entry
end

local body = {}   -- 最近一次 Refresh 讀到的身上裝備

-- 兩格部位的「取代哪一格」選單：列出那兩格現在穿的是什麼
local function SlotMenuItems(entry, info)
    local items = { { text = "取代哪一格", isTitle = true } }
    for _, slot in ipairs(info.slots) do
        local worn = body[slot]
        items[#items + 1] = {
            text = string.format("%s：%s", SLOT_NAME[slot] or slot, worn and (worn.name or worn.link) or "空的"),
            value = worn and tostring(worn.ilvl) or nil,
            isActive = info.slot == slot,
            onClick = function()
                entry.slot = slot
                Claim(entry)
                Refresh()
            end,
        }
    end
    return items
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
    GameTooltip:AddLine(" ")
    if info.baseName then
        GameTooltip:AddLine("次要屬性以催化器底材計算：" .. info.baseName, 0.62, 0.36, 0.72, true)
    end

    -- 模擬：取代的是哪一件、四項屬性各差多少
    if not info.slots then
        GameTooltip:AddLine("這件沒有對應的裝備格，不列入模擬", DIM, DIM, DIM, true)
    else
        local slotName = SLOT_NAME[info.slot]
        if #info.slots == 1 then
            local _, _, _, equipLoc = C_Item.GetItemInfoInstant(row.entry.id)
            slotName = _G[equipLoc] or slotName or ""
        end
        local worn = info.replaced
        GameTooltip:AddLine(string.format("取代 %s：%s", slotName,
            worn and string.format("%s %d", worn.link, worn.ilvl) or "空的"), 1, 1, 1)
        if info.alsoRemoved then
            GameTooltip:AddLine(string.format("雙手武器，副手一併換下：%s %d",
                info.alsoRemoved.link, info.alsoRemoved.ilvl), 1, 1, 1)
        end

        if info.delta then
            local parts = {}
            for i, stat in ipairs(STATS) do
                local d = info.delta[i]
                if d ~= 0 then
                    parts[#parts + 1] = string.format("|c%s%s|r |cff%s%s|r", stat.hex, stat.tag,
                        d > 0 and "40ff40" or "ff4040", SignedNumber(d))
                end
            end
            GameTooltip:AddLine(#parts > 0 and table.concat(parts, "　") or "次要屬性沒有變化", DIM, DIM, DIM)
        end

        GameTooltip:AddLine(" ")
        if info.active then
            GameTooltip:AddLine("左鍵：排除，不算進模擬", DIM, DIM, DIM)
        else
            GameTooltip:AddLine("目前沒有算進模擬", 1, 0.82, 0)
            GameTooltip:AddLine("左鍵：納入（同一格的另一件會被排除）", DIM, DIM, DIM)
        end
    end
    GameTooltip:Show()
end

local function SetRowDim(row, dim)
    local alpha = dim and OFF_ALPHA or 1
    for _, tag in ipairs(row.tags) do tag:SetAlpha(alpha) end
    row.level:SetAlpha(alpha)
    row.name:SetAlpha(alpha)
    row.slotBtn:SetAlpha(alpha)
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

    -- 兩格部位才出現：顯示目前要取代哪一格，點它開選單換另一格
    local slotBtn = CreateFrame("Button", nil, row)
    slotBtn:SetSize(SLOT_W, ROW_H - 2)
    slotBtn:SetPoint("RIGHT", remove, "LEFT", -4, 0)
    slotBtn.bg = slotBtn:CreateTexture(nil, "BACKGROUND")
    slotBtn.bg:SetAllPoints()
    slotBtn.bg:SetColorTexture(1, 1, 1, 0.10)
    slotBtn.bg:Hide()
    slotBtn.text = NewText(slotBtn, 11)
    slotBtn.text:SetPoint("CENTER", 0, 0)
    slotBtn.text:SetTextColor(DIM, DIM, DIM)
    slotBtn:SetScript("OnEnter", function(self)
        self.bg:Show()
        self.text:SetTextColor(1, 1, 1)
        RowHover(row)
    end)
    slotBtn:SetScript("OnLeave", function(self)
        self.bg:Hide()
        self.text:SetTextColor(DIM, DIM, DIM)
        RowHover(row)
    end)
    slotBtn:SetScript("OnClick", function(self)
        if row.entry and row.info and row.info.slots then
            W.Menu.Show(SlotMenuItems(row.entry, row.info), self)
        end
    end)
    row.slotBtn = slotBtn

    row.name = NewText(row, 12)
    row.name:SetJustifyH("LEFT")   -- 錨點在 UpdateRow：右邊貼「取代哪一格」按鈕或 ×

    row:SetScript("OnEnter", function(self) RowHover(self); RowTooltip(self) end)
    row:SetScript("OnLeave", function(self) RowHover(self); GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        local entry, info = self.entry, self.info
        if not entry or not info then return end
        if IsModifierKeyDown() then
            -- Shift 貼連結／Ctrl 試穿：要用 GetItemInfo 回來的正式連結，自己組的那串貼不出去
            if info.realLink then HandleModifiedItemClick(info.realLink) end
            return
        end
        if not info.slots then return end
        -- 納入／排除模擬。重刷之後這一列還是同一筆（排序不看這個），提示跟著更新
        if entry.off then Claim(entry) else entry.off = true end
        Refresh()
        if self:IsMouseOver() then RowTooltip(self) end
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

    local multi = info.slots ~= nil and #info.slots > 1
    row.slotBtn:SetShown(multi)
    if multi then row.slotBtn.text:SetText(SLOT_NAME[info.slot] or "") end
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.level, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", multi and row.slotBtn or row.remove, "LEFT", -4, 0)

    SetRowDim(row, not info.active)
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

    -- 加總區：一項次要屬性一列 —— 全身目前的加總 → 模擬後、變化量、模擬後在四項裡的佔比
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetPoint("BOTTOMLEFT", PAD, PAD)
    footer:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    footer:SetHeight(6 + COLHEAD_H + CELL_H * #STATS + 4 + 14)
    panel.footer = footer

    footer.line = NewHairline(footer)
    footer.line:SetPoint("TOPLEFT", 0, 0)
    footer.line:SetPoint("TOPRIGHT", 0, 0)

    local function ColumnHead(text, point, x)
        local fs = NewText(footer, 11)
        fs:SetPoint(point, footer, point, x, -6)
        fs:SetTextColor(DIM, DIM, DIM)
        fs:SetText(text)
        return fs
    end
    ColumnHead("全身裝備", "TOPLEFT", 0)
    ColumnHead("目前", "TOPRIGHT", -COL_BEFORE)
    ColumnHead("模擬後", "TOPRIGHT", -COL_AFTER)
    ColumnHead("變化", "TOPRIGHT", -COL_DELTA)
    ColumnHead("佔比", "TOPRIGHT", -COL_PCT)

    footer.cells = {}
    for i, stat in ipairs(STATS) do
        local cell = CreateFrame("Frame", nil, footer)
        cell:SetHeight(CELL_H)
        cell:SetPoint("TOPLEFT", 0, -6 - COLHEAD_H - (i - 1) * CELL_H)
        cell:SetPoint("TOPRIGHT", 0, -6 - COLHEAD_H - (i - 1) * CELL_H)

        cell.tag = NewTag(cell, stat)
        cell.tag:SetPoint("LEFT", 0, 0)

        cell.name = NewText(cell, 12)
        cell.name:SetPoint("LEFT", cell.tag, "RIGHT", 5, 0)
        cell.name:SetText(stat.name)

        cell.pct = NewText(cell, 11)
        cell.pct:SetPoint("RIGHT", -COL_PCT, 0)
        cell.pct:SetTextColor(DIM, DIM, DIM)

        cell.delta = NewText(cell, 12)
        cell.delta:SetPoint("RIGHT", -COL_DELTA, 0)

        cell.after = NewText(cell, 12)
        cell.after:SetPoint("RIGHT", -COL_AFTER, 0)

        cell.arrow = NewText(cell, 11)
        cell.arrow:SetPoint("RIGHT", -COL_ARROW, 0)
        cell.arrow:SetTextColor(DIM, DIM, DIM)
        cell.arrow:SetText("→")

        cell.before = NewText(cell, 12)
        cell.before:SetPoint("RIGHT", -COL_BEFORE, 0)
        cell.before:SetTextColor(DIM, DIM, DIM)

        footer.cells[i] = cell
    end

    footer.summary = NewText(footer, 11)
    footer.summary:SetPoint("BOTTOMLEFT", 0, 0)
    footer.summary:SetTextColor(DIM, DIM, DIM)

    panel:SetScript("OnShow", function(self)
        W.Stylize(self, S.Dark.panel)   -- 每次顯示重鋪：1px 邊照當下的 UI 縮放換算
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")   -- 基準是身上的裝備，換裝就重算
        Reanchor()
        Refresh()
    end)
    panel:SetScript("OnHide", function(self)
        self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        if W.Menu.Hide then W.Menu.Hide() end
    end)
    panel:SetScript("OnEvent", function(_, event)
        if event ~= "GET_ITEM_INFO_RECEIVED" or waiting then QueueRefresh() end
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

    -- 基準：身上十六格。before＝目前全身的加總，after 從它出發，逐件把「取代的那格」換成清單裡的
    body = ReadEquipped()
    local plan = Plan(list, body)

    local before, after, levels = {}, {}, {}
    for s = 1, #STATS do before[s] = 0 end
    for _, slot in ipairs(BODY_SLOTS) do
        local worn = body[slot]
        if worn then
            levels[slot] = worn.ilvl
            for s = 1, #STATS do before[s] = before[s] + worn.stats[s] end
        end
    end
    for s = 1, #STATS do after[s] = before[s] end
    local twoHandMain = body[16] ~= nil and body[16].twoHand
    local levelBefore = AverageLevel(levels, twoHandMain)

    waiting = false
    local counted = 0
    local y = -(HEADER_H + 4)
    for i, item in ipairs(view) do
        local row = rows[i] or CreateRow(i)
        local entry = item.entry
        local info = Resolve(entry)
        if info.loading then waiting = true end

        local p = plan[entry]
        if p then
            info.slot, info.slots = p.slot, p.slots
            info.replaced = body[p.slot]
            info.alsoRemoved = p.clears and body[OFF_HAND] or nil
            info.active = not entry.off
            if not info.loading then
                info.delta = {}
                for s = 1, #STATS do
                    info.delta[s] = (info.stats[s] or 0)
                        - (info.replaced and info.replaced.stats[s] or 0)
                        - (info.alsoRemoved and info.alsoRemoved.stats[s] or 0)
                end
                if info.active then
                    counted = counted + 1
                    for s = 1, #STATS do after[s] = after[s] + info.delta[s] end
                    levels[p.slot] = info.ilvl
                    if p.clears then levels[OFF_HAND] = nil end
                    if p.slot == 16 then twoHandMain = IsTwoHand(entry.id) end
                end
            end
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, y)
        row:SetPoint("TOPRIGHT", -PAD, y)
        UpdateRow(row, entry, info)
        row:Show()
        y = y - ROW_H
    end
    local levelAfter = AverageLevel(levels, twoHandMain)
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
    panel.clear:SetEnabled(hasItems)
    panel.setAll:SetEnabled(hasItems)

    -- 加總區永遠在（清單是空的也看得到目前全身的數字）
    local sum = 0
    for s = 1, #STATS do sum = sum + after[s] end
    for s, cell in ipairs(panel.footer.cells) do
        local d = after[s] - before[s]
        PaintTag(cell.tag, after[s] > 0)
        cell.before:SetText(BreakUpLargeNumbers(before[s]))
        cell.after:SetText(BreakUpLargeNumbers(after[s]))
        if d ~= 0 then
            cell.delta:SetText(SignedNumber(d))
            if d > 0 then cell.delta:SetTextColor(0.25, 1, 0.25) else cell.delta:SetTextColor(1, 0.25, 0.25) end
        else
            cell.delta:SetText("")
        end
        cell.pct:SetText(sum > 0 and string.format("%d%%", math.floor(after[s] / sum * 100 + 0.5)) or "")
    end

    -- 裝等：顯示的「目前」用暴雪的已裝備平均（跟角色面板同一個數字），變化量用我們自己照同一條規則算的差
    local _, equippedLevel = GetAverageItemLevel()
    equippedLevel = equippedLevel or levelBefore
    local levelText
    if counted > 0 then
        levelText = string.format("裝等 %.1f → %.1f", equippedLevel, equippedLevel + (levelAfter - levelBefore))
    else
        levelText = string.format("裝等 %.1f", equippedLevel)
    end
    if hasItems then
        panel.footer.summary:SetText(string.format("納入 %d／%d 件 · %s", counted, count, levelText))
    else
        panel.footer.summary:SetText(levelText)
    end

    panel:SetHeight(HEADER_H + 4 + (hasItems and count * ROW_H or EMPTY_H) + 6 + panel.footer:GetHeight() + PAD)
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
