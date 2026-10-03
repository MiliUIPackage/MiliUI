------------------------------------------------------------
-- 目錄：cooldownID → 法術資料，與每一條的有序清單
--
--   ns.Catalog.Bar(barKey)     有序 cooldownID 陣列（已套本專精的 order／groupOf／hidden）
--   ns.Catalog.Info(id)        { spellID, overrideSpellID, icon, name, category, equipSlot,
--                                hasAura, charges, isInvisible, isKnown, effectiveCategory, home }
--   ns.Catalog.Refresh(reason) 重讀；內容（簽章）變了才廣播 "CatalogChanged"
--   ns.Catalog.IsPaused()      暴雪冷卻管理器設定面板開著 ⇒ true（Bars 暫停重排）
--   ns.Catalog.TalentBlocked(id) 逐法術的天賦條件不成立 ⇒ true（正式清單不收；見下面「天賦條件」）
--
-- 自訂項目（spells[spec].custom，id 是 "c:<index>"）也從這裡進清單：Bar(key) 把
-- custom[i].bar == key 的排進去，順序跟其他格一樣走 order 表（光環格也是，可以放在任意位置；
-- 條上有光環格時 Bars 會強制固定格位，位置本來就不動）。
-- Info("c:i") 回同一個形狀的表（多 custom／kind／itemID／filter）。
--
-- 資料來源只有兩個明文 API：`C_CooldownViewer.GetCooldownViewerCategorySet(category, true)`
-- 與 `GetCooldownViewerCooldownInfo(id)`，全部 pcall，欄位過 canaccessvalue 才收。
--
-- 玩家在暴雪面板排的順序與分類覆寫：解碼 `C_CooldownViewer.GetLayoutData()`。
--   格式 "<編碼版本>|<Base64>"，編碼版本目前 1：
--   Base64 → DecodeBase64 → DecompressString(Deflate) → DeserializeCBOR → 表
--     data[1]                          存檔格式版本（目前 5；4 起 data[2] 才是 layoutID）
--     data[2][specTag]                 這個專精作用中的 layoutID
--     data[3][specTag][layoutID][1]    有序 cooldownID（**跨所有類別的一條**）
--     data[3][specTag][layoutID][2]    { [category] = { cooldownID, … } } 分類覆寫
--   specTag = classID × 10 + 專精序號。
--   解不開、版本不認得、這個專精用的是預設版面（沒有存檔）→ 退回類別集合的原始順序，
--   **無感**：不印訊息、不報錯，只在 /mcdm debug 看得到走了哪條（C.source）。
--
-- ⚠ 為什麼自己解碼，不問暴雪的 CooldownViewerSettings:GetDataProvider()：
--   它的 GetOrderedCooldownIDsForCategory 會在第一次呼叫時**建快取並寫回自己的欄位**
--   （displayData）。從插件呼叫就是污染的執行在寫暴雪的表，之後暴雪自己的檢視器讀那份
--   快取時整條執行都帶污染，讀到秘密值就炸（[[wow-121-secret-values]]「暴雪會讀的欄位
--   一個都不能寫」）。自己解碼只讀不寫。
--
-- 條的成員規則（照暴雪 DataProvider 的語意）：
--   * 候選池是八個類別集合串起來的順序：Essential、Utility、TrackedBuff、TrackedBar、
--     EquipSlotEssential、EquipSlotTracked、SpecAgnosticEssential、SpecAgnosticTracked
--     （enum 值執行時從 Enum.CooldownViewerCategory 解析，不寫死數字）。
--   * 每個 id 的**有效類別**＝分類覆寫 > （HideByDefault 旗標 ⇒ 隱藏）> 資料本身的類別。
--   * 條只收有效類別等於自己那一類的 id（essential ← Essential…），而且 isKnown。
--     12.1 新增的四個類別（裝備欄、不分專精）是**候選池**：玩家在暴雪面板把它們拖進
--     核心／輔助／增益之後，覆寫的類別就是那一條，自然併進去；還留在原類別的，暴雪
--     檢視器也不會為它建框，所以不列（列了會變成永遠的空位／占位格）。
------------------------------------------------------------
local _, ns = ...

ns.Catalog = {}
local C = ns.Catalog

local EMPTY = setmetatable({}, { __newindex = function() error("read-only") end })

-- 四條暴雪檢視器對應的條與類別
C.SOURCE_BARS = { "essential", "utility", "buffs", "buffbars" }
local BAR_CATEGORY_NAME = {
    essential = "Essential",
    utility   = "Utility",
    buffs     = "TrackedBuff",
    buffbars  = "TrackedBar",
}
C.BAR_CATEGORY_NAME = BAR_CATEGORY_NAME

-- 候選池的順序＝暴雪 DataProvider 串接類別的順序；home 是「這一類預設歸哪條」（給設定介面分區用）
local POOL = {
    { name = "Essential",             home = "essential" },
    { name = "Utility",               home = "utility" },
    { name = "TrackedBuff",           home = "buffs" },
    { name = "TrackedBar",            home = "buffbars" },
    { name = "EquipSlotEssential",    home = "essential" },
    { name = "EquipSlotTracked",      home = "buffs" },
    { name = "SpecAgnosticEssential", home = "essential" },
    { name = "SpecAgnosticTracked",   home = "buffs" },
}

local HIDE_BY_DEFAULT = 2          -- Enum.CooldownSetSpellFlags.HideByDefault（取不到 Enum 時的退路）
local HIDDEN = "hidden"            -- 有效類別：不在任何檢視器
local SUPPORTED_DATA_VERSION = { [4] = true, [5] = true }
local ENCODING_VERSION = 1

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
-- 明文才收：秘密值、讀不到的一律當沒有
local function Plain(v)
    if v == nil then return nil end
    if ns.IsSecret and ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end
C.Plain = Plain

local function EnumCategory(name)
    local E = Enum and Enum.CooldownViewerCategory
    local v = E and E[name]
    return type(v) == "number" and v or nil
end

local function HideByDefaultFlag()
    local E = Enum and Enum.CooldownSetSpellFlags
    local v = E and E.HideByDefault
    return type(v) == "number" and v or HIDE_BY_DEFAULT
end

-- 位元測試不靠 bit 函式庫（離線測試也跑得動）
local function HasFlag(flags, flag)
    if type(flags) ~= "number" or type(flag) ~= "number" or flag <= 0 then return false end
    return (flags % (flag * 2)) >= flag
end
C.HasFlag = HasFlag

-- CBOR 解回來的表，鍵有可能是數字也可能是字串；兩種都試
local function Get(t, k)
    if type(t) ~= "table" or k == nil then return nil end
    local v = t[k]
    if v == nil then v = t[tostring(k)] end
    if v == nil and type(k) == "string" then v = t[tonumber(k)] end
    return v
end

function C.SpecTag()
    local classID = select(3, UnitClass("player"))
    local idx = ns.specIndex
    if idx == nil then
        local fn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
        idx = fn and fn() or nil
    end
    classID, idx = Plain(classID), Plain(idx)
    if type(classID) ~= "number" or type(idx) ~= "number" or idx <= 0 then return nil end
    return classID * 10 + idx
end

------------------------------------------------------------
-- 版面字串解碼（純邏輯，WoW 端只用到 C_EncodingUtil 與 Enum.CompressionMethod）
--
-- 回傳 data 表，或 nil, 原因字串。原因只給 debug 看。
------------------------------------------------------------
function C.DecodeLayoutString(str)
    if type(str) ~= "string" or Plain(str) == nil then return nil, "not-string" end
    if str == "" then return nil, "empty" end
    local sep = str:find("|", 1, true)
    if not sep then return nil, "no-version" end
    local ver = tonumber(str:sub(1, sep - 1))
    if ver ~= ENCODING_VERSION then return nil, "encoding-" .. tostring(ver) end
    local payload = str:sub(sep + 1)
    if payload == "" then return nil, "no-payload" end

    local EU = C_EncodingUtil
    if not (EU and EU.DecodeBase64 and EU.DecompressString and EU.DeserializeCBOR) then
        return nil, "no-encodingutil"
    end
    local ok, decoded = pcall(EU.DecodeBase64, payload)
    if not ok or type(decoded) ~= "string" then return nil, "base64" end
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local inflated
    ok, inflated = pcall(EU.DecompressString, decoded, method)
    if not ok or type(inflated) ~= "string" then return nil, "inflate" end
    local data
    ok, data = pcall(EU.DeserializeCBOR, inflated)
    if not ok or type(data) ~= "table" then return nil, "cbor" end
    local dataVersion = Get(data, 1)
    if not SUPPORTED_DATA_VERSION[dataVersion] then return nil, "data-" .. tostring(dataVersion) end
    return data
end

-- data（已解碼）＋ specTag → 有序 id 陣列（可能是 nil）、分類覆寫 { [id] = category }、原因
function C.ExtractSpecLayout(data, specTag)
    if type(data) ~= "table" or not specTag then return nil, {}, "no-data" end
    local layoutID = Get(Get(data, 2), specTag)
    if layoutID == nil then return nil, {}, "no-active-layout" end
    local layout = Get(Get(Get(data, 3), specTag), layoutID)
    if type(layout) ~= "table" then return nil, {}, "default-layout" end

    local order
    local rawOrder = Get(layout, 1)
    if type(rawOrder) == "table" then
        order = {}
        local seen = {}
        for i = 1, #rawOrder do
            local id = tonumber(rawOrder[i])
            if id and not seen[id] then
                seen[id] = true
                order[#order + 1] = id
            end
        end
    end

    local overrides = {}
    local rawCats = Get(layout, 2)
    if type(rawCats) == "table" then
        for cat, ids in pairs(rawCats) do
            local c = tonumber(cat)
            if c and type(ids) == "table" then
                for _, id in pairs(ids) do
                    id = tonumber(id)
                    if id then overrides[id] = c end
                end
            end
        end
    end
    return order, overrides, "layout"
end

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
C.info       = {}          -- [cooldownID] = info
C.ordered    = {}          -- 完整的有效順序（跨類別）
C.lists      = {}          -- [sourceBar] = { cooldownID… }（還沒套我們的覆寫）
C.pool       = {}          -- [homeBar] = 還在候選池（沒被拖進任何檢視器）的 id
C.sig        = nil         -- 內容簽章（版面字串＋專精＋每條的清單）
C.layoutString = nil       -- 上次讀到的 GetLayoutData 原字串
C.source     = "none"      -- 順序從哪來：layout | fallback:<原因>
C.builds     = 0           -- 實際重建次數（debug／測試用）
local dirty  = true
local paused = false

local function ReadLayoutString()
    local api = C_CooldownViewer and C_CooldownViewer.GetLayoutData
    if not api then return nil end
    local ok, s = pcall(api)
    if not ok then return nil end
    s = Plain(s)
    return type(s) == "string" and s or nil
end
C.ReadLayoutString = ReadLayoutString

-- 沒有 spellID 的兩種項目，圖示與名字另外找（不然清單上是一排問號）：
--   * 物品冷卻類別（spellCategoryID）：戰鬥藥水、治療藥水、治療石這種「哪一瓶都算」的共用冷卻。
--     暴雪自己也是寫死一張「類別 → 圖示／標題」的表（CooldownViewerItemData.lua），這裡照同一組值。
--   * 裝備欄（equipSlot）：那一格有裝備就用裝備的圖示與名字；空的用空格圖與欄位名。
local SPELL_CATEGORY = {
    [4]    = { icon = "Interface\\Icons\\INV_Potion_114",        title = "COOLDOWN_VIEWER_TOOLTIP_POTION_COMBAT_TITLE" },
    [30]   = { icon = "Interface\\Icons\\INV_Potion_54",         title = "COOLDOWN_VIEWER_TOOLTIP_POTION_HEALTH_TITLE" },
    [1711] = { icon = "Interface\\Icons\\Warlock_ Healthstone",  title = "COOLDOWN_VIEWER_TOOLTIP_POTION_HEALTHSTONE_TITLE" },
    [2566] = { icon = "Interface\\Icons\\Warlock_ Bloodstone",   title = "COOLDOWN_VIEWER_TOOLTIP_POTION_DEMONIC_HEALTHSTONE_TITLE" },
}
local EQUIP_SLOT_NAME = {
    [1] = "HEADSLOT", [2] = "NECKSLOT", [3] = "SHOULDERSLOT", [5] = "CHESTSLOT", [6] = "WAISTSLOT",
    [7] = "LEGSSLOT", [8] = "FEETSLOT", [9] = "WRISTSLOT", [10] = "HANDSSLOT",
    [11] = "FINGER0SLOT", [12] = "FINGER1SLOT", [13] = "TRINKET0SLOT", [14] = "TRINKET1SLOT",
    [15] = "BACKSLOT", [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT",
}
C.EQUIP_SLOT_NAME = EQUIP_SLOT_NAME

local function GlobalText(name)
    local s = name and _G[name]
    s = Plain(s)
    return type(s) == "string" and s ~= "" and s or nil
end

local function ReadInfo(id)
    local api = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
    if not api then return nil end
    local ok, raw = pcall(api, id)
    if not ok or type(raw) ~= "table" then return nil end
    local spellID    = Plain(raw.spellID)
    local overrideID = Plain(raw.overrideSpellID)
    local tipID      = Plain(raw.overrideTooltipSpellID)
    local shown      = overrideID or spellID
    local icon, name
    if shown and C_Spell then
        if C_Spell.GetSpellTexture then
            local ok2, tex = pcall(C_Spell.GetSpellTexture, shown)
            if ok2 then icon = Plain(tex) end
        end
        if C_Spell.GetSpellName then
            local ok3, nm = pcall(C_Spell.GetSpellName, shown)
            if ok3 then name = Plain(nm) end
        end
    end
    -- 裝備欄的項目（暴雪面板「不顯示：物品」那一區的飾品／武器）有的沒有 spellID：
    -- 圖示與名字改從身上那格裝備拿（都是明文）
    local equipSlot = Plain(raw.equipSlot)
    if type(equipSlot) == "number" and (icon == nil or name == nil) then
        if icon == nil and GetInventoryItemTexture then
            local ok4, tex = pcall(GetInventoryItemTexture, "player", equipSlot)
            if ok4 then icon = Plain(tex) end
        end
        if name == nil and GetInventoryItemID and C_Item and C_Item.GetItemNameByID then
            local ok5, itemID = pcall(GetInventoryItemID, "player", equipSlot)
            itemID = ok5 and Plain(itemID) or nil
            if itemID then
                local ok6, nm = pcall(C_Item.GetItemNameByID, itemID)
                if ok6 then name = Plain(nm) end
            end
        end
    end
    -- 裝備欄是空的：空格圖與欄位名
    local slotToken = type(equipSlot) == "number" and EQUIP_SLOT_NAME[equipSlot] or nil
    if slotToken then
        if icon == nil and _G.GetInventorySlotInfo then
            local ok7, _, tex = pcall(_G.GetInventorySlotInfo, slotToken)
            if ok7 then icon = Plain(tex) end
        end
        if name == nil then name = GlobalText(slotToken) end
    end
    -- 物品冷卻類別：圖示固定用類別的（跟暴雪一樣，優先於法術圖示），名字沒有才用類別標題
    local spellCategoryID = Plain(raw.spellCategoryID)
    local catDef = type(spellCategoryID) == "number" and SPELL_CATEGORY[spellCategoryID] or nil
    if catDef then
        icon = catDef.icon
        if name == nil then name = GlobalText(catDef.title) end
    end
    local isKnown = Plain(raw.isKnown)
    return {
        cooldownID      = id,
        spellID         = spellID,
        overrideSpellID = overrideID,
        overrideTooltipSpellID = tipID,
        icon            = icon,
        name            = name,
        category        = Plain(raw.category),
        equipSlot       = equipSlot,
        spellCategoryID = spellCategoryID,
        hasAura         = Plain(raw.hasAura) and true or false,
        charges         = Plain(raw.charges) and true or false,
        isInvisible     = Plain(raw.isInvisible) and true or false,
        isKnown         = isKnown ~= false,       -- 讀不到當作學了（寧可多一格空位也不要少）
        flags           = Plain(raw.flags),
    }
end

------------------------------------------------------------
-- 天賦條件（逐法術覆寫 overrides[id].talentCond = { spellID, mode = "known"｜"unknown" }）
--
-- 同一個專精換天賦時不用手動藏格子／加回來：「學了天賦 X 才顯示」「沒學 Y 才顯示」。
--   C.TalentCondPass(cond, isKnown)  純函式；isKnown(spellID) → true／false／nil（讀不到）
--   C.TalentKnown(spellID)           遊戲裡的 isKnown
--   C.TalentBlocked(id)              這一格目前被天賦條件擋掉（設定頁預覽畫暗用）
-- 規則：
--   * 沒存、壞資料（spellID 不是正整數、mode 不認得）＝沒有條件。
--   * 讀不到（秘密值、API 不在、pcall 失敗）＝條件成立（fail-open：不要因為讀不到就把格子藏掉）。
--   * 條件不成立的 id 不進 C.Bar 的正式清單（排版看不到）；withHidden（設定頁）照樣放進第一張，
--     玩家才點得到、改得回來。
--   * 換天賦會派 SPELLS_CHANGED／TRAIT_CONFIG_UPDATED ⇒ Later 重建；簽章帶著每個條件的結果，
--     結果變了才廣播 CatalogChanged（Bars 收到就整套 membership 重排）。
------------------------------------------------------------
local TALENT_MODES = { known = true, unknown = true }

-- 合法的條件 ⇒ spellID, mode；其餘 nil
local function ValidTalentCond(cond)
    if type(cond) ~= "table" then return nil end
    local id, mode = cond.spellID, cond.mode
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    if not TALENT_MODES[mode] then return nil end
    return id, mode
end
C.ValidTalentCond = ValidTalentCond

function C.TalentCondPass(cond, isKnown)
    local id, mode = ValidTalentCond(cond)
    if not id then return true end
    local known = isKnown and isKnown(id)
    if type(known) ~= "boolean" then return true end      -- 讀不到：當成立
    if mode == "known" then return known end
    return not known
end

-- 天賦學了沒：C_SpellBook.IsSpellKnown 與 IsPlayerSpell 都問（天賦被動只有 IsPlayerSpell 準），
-- 任一個明文 true 就算學了；兩個都明文 false 才算沒學；有一個讀不到又沒有 true ⇒ nil（fail-open）
local function TalentKnown(spellID)
    local unsure, asked = false, false
    local book = C_SpellBook
    for _, fn in ipairs({ book and book.IsSpellKnown or false, _G.IsPlayerSpell or false }) do
        if fn then
            asked = true
            local ok, v = pcall(fn, spellID)
            if ok then v = Plain(v) else v = nil end     -- ⚠ 不能寫成 ok and Plain(v) or nil：false 會被吃掉
            if v == true then return true end
            if v ~= false then unsure = true end
        end
    end
    if unsure or not asked then return nil end
    return false
end
C.TalentKnown = TalentKnown

-- 這一格的條件（目前專精的覆寫；SpellsTable 定義在下面，用前置宣告）
local SpellsTable
local function TalentCondOf(sp, id)
    local all = sp and type(sp.overrides) == "table" and sp.overrides
    local o = all and id ~= nil and all[id]
    return type(o) == "table" and o.talentCond or nil
end

local function Blocked(sp, id)
    local cond = TalentCondOf(sp, id)
    return cond ~= nil and not C.TalentCondPass(cond, C.TalentKnown)
end

function C.TalentBlocked(id)
    return Blocked(SpellsTable(), id)
end

-- 簽章用：目前被擋掉的 id（排序後串起來）
local function TalentSig()
    local sp = SpellsTable()
    local all = sp and type(sp.overrides) == "table" and sp.overrides
    if not all then return "" end
    local out = {}
    for id in pairs(all) do
        if Blocked(sp, id) then out[#out + 1] = tostring(id) end
    end
    table.sort(out)
    return table.concat(out, ",")
end

------------------------------------------------------------
-- 重建
------------------------------------------------------------
local function Build()
    C.builds = C.builds + 1
    local info, defaultOrder = {}, {}
    local homeOf = {}
    local setAPI = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet

    for _, p in ipairs(POOL) do
        local cat = EnumCategory(p.name)
        if cat ~= nil and setAPI then
            local ok, ids = pcall(setAPI, cat, true)
            if ok and type(ids) == "table" then
                for i = 1, #ids do
                    local id = Plain(ids[i])
                    if type(id) == "number" and not info[id] then
                        local rec = ReadInfo(id)
                        if rec then
                            if rec.category == nil then rec.category = cat end
                            rec.home = p.home
                            info[id] = rec
                            homeOf[id] = p.home
                            defaultOrder[#defaultOrder + 1] = id
                        end
                    end
                end
            end
        end
    end

    -- 玩家順序：存檔順序（去掉已不存在的）＋ 新出現的接在後面
    local str = ReadLayoutString()
    C.layoutString = str
    local tag = C.SpecTag()
    C.specTag = tag
    local data, why = C.DecodeLayoutString(str)
    local order, overrides, why2
    if data then
        order, overrides, why2 = C.ExtractSpecLayout(data, tag)
    else
        overrides = {}
    end
    if order then
        C.source = "layout"
    else
        C.source = "fallback:" .. tostring(why2 or why)
    end

    local ordered, seen = {}, {}
    if order then
        for _, id in ipairs(order) do
            if info[id] and not seen[id] then
                seen[id] = true
                ordered[#ordered + 1] = id
            end
        end
    end
    for _, id in ipairs(defaultOrder) do
        if not seen[id] then
            seen[id] = true
            ordered[#ordered + 1] = id
        end
    end

    -- 有效類別 → 分條
    local hideFlag = HideByDefaultFlag()
    local catToBar = {}
    for bar, name in pairs(BAR_CATEGORY_NAME) do
        local v = EnumCategory(name)
        if v ~= nil then catToBar[v] = bar end
    end
    local hideInvisible = _G.CDM_HIDE_INVISIBLE_ITEMS == true

    local lists, pool = {}, {}
    for _, bar in ipairs(C.SOURCE_BARS) do lists[bar] = {}; pool[bar] = {} end
    for _, id in ipairs(ordered) do
        local rec = info[id]
        local eff
        if overrides[id] ~= nil then
            eff = overrides[id]
        elseif HasFlag(rec.flags, hideFlag) then
            eff = HIDDEN
        else
            eff = rec.category
        end
        rec.effectiveCategory = eff
        local bar = catToBar[eff]
        rec.bar = bar
        if bar and rec.isKnown and not (hideInvisible and rec.isInvisible) then
            local l = lists[bar]
            l[#l + 1] = id
        elseif not bar and eff ~= HIDDEN and rec.home and pool[rec.home] then
            local l = pool[rec.home]
            l[#l + 1] = id
        end
    end

    C.info, C.ordered, C.lists, C.pool = info, ordered, lists, pool
    -- 哪些 id 已經排在某條檢視器的清單上（C.Adopt 用）
    local placed = {}
    for _, bar in ipairs(C.SOURCE_BARS) do
        for _, id in ipairs(lists[bar]) do placed[id] = true end
    end
    C.placed = placed
    C.adopted = 0

    -- 簽章：版面原字串＋專精＋每條清單（天賦改變 isKnown 也會反映在清單上）＋天賦條件的結果
    local parts = { str or "", tostring(tag), TalentSig() }
    for _, bar in ipairs(C.SOURCE_BARS) do
        parts[#parts + 1] = table.concat(lists[bar], ",")
    end
    local sig = table.concat(parts, "#")
    local changed = sig ~= C.sig
    C.sig = sig
    dirty = false
    return changed
end

local function EnsureBuilt()
    if dirty then
        local ok, changed = pcall(Build)
        if not ok then
            dirty = false
            if ns.ReportError then ns.ReportError(changed) end
            return false
        end
        -- 從另一支插件匯入的設定：這個專精還掛著 spellID 的群組／覆寫，用剛建好的目錄對表
        -- （Core/Import.lua）。換到了就當成內容有變，呼叫端會廣播 CatalogChanged → 重排
        local Import = ns.Import
        if Import and Import.ResolvePending and ns.specID then
            local ok2, resolved = pcall(Import.ResolvePending, ns.specID)
            if not ok2 then
                if ns.ReportError then ns.ReportError(resolved) end
            elseif resolved then
                changed = true
            end
        end
        return changed
    end
    return false
end

function C.MarkDirty() dirty = true end
function C.IsDirty() return dirty end

-- 重讀；內容變了回 true 並廣播 "CatalogChanged"
function C.Refresh(reason)
    dirty = true
    local changed = EnsureBuilt()
    if changed and ns.Fire then ns.Fire("CatalogChanged", reason) end
    return changed
end

-- 便宜的新鮮度檢查（Bars 每次排版前叫）：暴雪換專精／存版面是在它自己的下一幀做的，
-- 不一定有事件接得到；版面字串或專精跟上次建置時不同就重讀。
-- GetLayoutData 回的是整份版面字串（每個專精都在裡面），增益上下時每 0.1 秒排一次版，
-- 每次都讀太浪費 ⇒ 輪詢最多每 FRESH_INTERVAL 秒一次。事件路徑（Later → dirty）不受限。
local FRESH_INTERVAL = 1
local lastFresh = nil
function C.CheckFresh()
    if dirty then
        local changed = EnsureBuilt()
        if changed and ns.Fire then ns.Fire("CatalogChanged", "dirty") end
        return changed
    end
    local now = _G.GetTime and _G.GetTime() or nil
    if now then
        if lastFresh and now - lastFresh < FRESH_INTERVAL then return false end
        lastFresh = now
    end
    if ReadLayoutString() ~= C.layoutString or C.SpecTag() ~= C.specTag then
        return C.Refresh("stale")
    end
    return false
end

------------------------------------------------------------
-- 收養：暴雪檢視器上正在顯示、我們的清單卻沒有的 id
--
-- 清單是我們照 C_CooldownViewer 的 API 自己重建的（暴雪的資料提供者也是讀同一組 API，但各讀各的、
-- 時間點不同）。進副本、被系統換專精（排隨機隊伍自動換成補師專精）、天賦切換的那幾幀，API 回的
-- 可能還是上一個專精的東西、或某幾個 id 暫時查不到資訊；那一刻建出來的清單就會漏。之後如果沒有
-- 任何一個我們聽的事件再來，漏掉的 id 對應的 item 沒人認領 ⇒ 被停到畫面外，整條看起來是空的。
--
-- 暴雪只替「已學會、屬於那個類別」的 id 取出 item 並設 cooldownID
-- （CooldownViewerMixin:RefreshData ← GetOrderedCooldownIDsForCategory），所以**作用中、有 cooldownID 的
-- item 就是暴雪正在顯示的東西**。清單漏了的，直接收進那條檢視器的清單尾端（照暴雪的順序），
-- 順序頂多暫時不對，不會整格不見；玩家在我們這邊藏掉／拉去別條的照舊生效（那是 C.Bar 的事）。
--
--   C.Adopt(live)  live[來源條] = { id, … }（暴雪的順序）。回傳這次新收的 id 數。
--
-- 每次重建（Build）清單都是重來的，所以 Bars 每次排版前都叫；有收養就代表清單過期了，
-- 排幾次重讀（0.5／1.5／3 秒），乾淨的一輪之後額度還原。
------------------------------------------------------------
local RETRY_DELAYS = { 0.5, 1.5, 3 }
local retryStep, retryArmed = 0, false

local function ArmRetry()
    if retryArmed or retryStep >= #RETRY_DELAYS then return end
    local timer = _G.C_Timer
    if not (timer and timer.After) then return end
    retryStep = retryStep + 1
    retryArmed = true
    timer.After(RETRY_DELAYS[retryStep], function()
        retryArmed = false
        C.Refresh("adopt-retry")
        -- 清單內容沒變也要再排一輪：讓下一次排版重新檢查還有沒有漏的
        if ns.Bars and ns.Bars.RequestAll then ns.Bars.RequestAll("membership") end
    end)
end

function C.Adopt(live)
    EnsureBuilt()
    if type(live) ~= "table" then return 0 end
    local placed = C.placed
    if type(placed) ~= "table" then return 0 end
    local n, notes = 0, nil
    for _, bar in ipairs(C.SOURCE_BARS) do
        local ids = live[bar]
        local list = C.lists[bar]
        if type(ids) == "table" and list then
            for i = 1, #ids do
                local id = ids[i]
                if type(id) == "number" and not placed[id] then
                    local rec = C.info[id] or ReadInfo(id) or { cooldownID = id, isKnown = true }
                    if C.info[id] == nil then
                        C.info[id] = rec
                        C.ordered[#C.ordered + 1] = id
                    end
                    rec.home = rec.home or bar
                    rec.bar = bar
                    rec.effectiveCategory = EnumCategory(BAR_CATEGORY_NAME[bar])
                    rec.adopted = true
                    list[#list + 1] = id
                    placed[id] = true
                    n = n + 1
                    notes = notes or {}
                    notes[bar] = (notes[bar] and (notes[bar] .. ",") or "") .. tostring(id)
                end
            end
        end
    end
    if n > 0 then
        C.adopted = (C.adopted or 0) + n
        if ns.Diag then
            local parts = {}
            for _, bar in ipairs(C.SOURCE_BARS) do
                if notes[bar] then parts[#parts + 1] = bar .. " ← " .. notes[bar] end
            end
            ns.Diag.Note("adopt", ("清單漏了暴雪正在顯示的 %d 個（specTag %s，來源 %s）：%s")
                :format(n, tostring(C.specTag), tostring(C.source), table.concat(parts, "；")))
        end
        ArmRetry()
    elseif (C.adopted or 0) == 0 and not retryArmed then
        retryStep = 0            -- 乾淨的一輪：額度還原
    end
    return n
end

------------------------------------------------------------
-- 自訂項目
------------------------------------------------------------
local QUESTION = 134400
-- slot：裝備欄位，追蹤「現在裝在那一格的物品」，換裝自動跟上；不經過暴雪的冷卻管理器
-- 挑選清單的順序：會用的多半是飾品，兩格排最前面，其餘照角色面板（襯衣、外袍不收）
local CUSTOM_KINDS = { aura = true, spell = true, item = true, slot = true }
C.CUSTOM_SLOT_ORDER = { 13, 14, 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 16, 17 }
local CUSTOM_SLOTS = {}
for _, slot in ipairs(C.CUSTOM_SLOT_ORDER) do CUSTOM_SLOTS[slot] = true end
C.CUSTOM_SLOTS = CUSTOM_SLOTS

-- 欄位名：有編號版（「手指 1」「飾品 2」）用編號版，兩格同名才分得出來
function C.SlotName(slot)
    local token = EQUIP_SLOT_NAME[slot]
    return token and (GlobalText(token .. "_UNIQUE") or GlobalText(token)) or nil
end

-- 那一格現在裝的物品（明文 itemID 或 nil）
function C.SlotItemID(slot)
    if not (GetInventoryItemID and type(slot) == "number") then return nil end
    local ok, id = pcall(GetInventoryItemID, "player", slot)
    id = ok and Plain(id) or nil
    return type(id) == "number" and id or nil
end

SpellsTable = function()
    local p = ns.profile
    local spec = ns.specID
    local sp = p and type(p.spells) == "table" and spec and p.spells[spec]
    return type(sp) == "table" and sp or nil
end

local function CustomList()
    local sp = SpellsTable()
    local list = sp and sp.custom
    return type(list) == "table" and list or EMPTY
end

function C.CustomIndex(id)
    if type(id) ~= "string" then return nil end
    local n = id:match("^c:(%d+)$")
    return n and tonumber(n) or nil
end

function C.IsCustom(id) return C.CustomIndex(id) ~= nil end

-- 這一筆的形狀對不對（匯入的字串、舊版存檔都可能帶來壞資料；壞的一律當不存在）
-- 選用欄位壞掉不算整筆壞：物品的 alts、光環格的 spellIDs 不是表就當沒有（Modules/Custom.lua 讀的時候濾）
local function ValidCustom(e)
    if type(e) ~= "table" or not CUSTOM_KINDS[e.kind] then return false end
    if e.kind == "item" then return type(e.itemID) == "number" end
    if e.kind == "slot" then return CUSTOM_SLOTS[e.slot] == true end
    return type(e.spellID) == "number"
end
C.ValidCustom = ValidCustom

function C.CustomEntry(id)
    local i = C.CustomIndex(id)
    local e = i and CustomList()[i]
    if ValidCustom(e) then return e, i end
    return nil
end

function C.IsAuraSlot(id)
    local e = C.CustomEntry(id)
    return e ~= nil and e.kind == "aura"
end

-- 這條上有沒有光環格（有的話固定格位被強制打開）
function C.BarHasAuraSlot(barKey)
    for _, e in ipairs(CustomList()) do
        if ValidCustom(e) and e.kind == "aura" and e.bar == barKey then return true end
    end
    return false
end

local function Try(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

-- 法術學了沒（讀不到當學了；光環格不問）
local function SpellKnown(spellID)
    local book = C_SpellBook
    if book and book.IsSpellKnown then
        local v = Plain(Try(book.IsSpellKnown, spellID))
        if v ~= nil then return v and true or false end
    end
    if _G.IsPlayerSpell then
        local v = Plain(Try(_G.IsPlayerSpell, spellID))
        if v ~= nil then return v and true or false end
    end
    return true
end
C.SpellKnown = SpellKnown

local function CustomInfo(id)
    local e, i = C.CustomEntry(id)
    if not e then return nil end
    local info = {
        cooldownID = id, custom = true, index = i, kind = e.kind, bar = e.bar,
        spellID = e.spellID, itemID = e.itemID, filter = e.filter, slot = e.slot, isKnown = true,
    }
    if e.kind == "slot" then
        -- 裝備欄位：圖示與名字照現在裝的物品；空格用空格圖與欄位名
        local itemID = C.SlotItemID(e.slot)
        info.itemID = itemID
        local I = C_Item
        if itemID then
            info.icon = Plain(Try(I and I.GetItemIconByID, itemID))
            info.name = Plain(Try(I and I.GetItemNameByID, itemID))
        end
        local token = EQUIP_SLOT_NAME[e.slot]
        if info.icon == nil and token and _G.GetInventorySlotInfo then
            local ok, _, tex = pcall(_G.GetInventorySlotInfo, token)
            if ok then info.icon = Plain(tex) end
        end
        info.slotName = C.SlotName(e.slot)
        if info.name == nil then info.name = info.slotName end
    elseif e.kind == "item" then
        -- 帶替代品的（e.alts）：圖示與名字照現在包包裡有的那件（Modules/Custom.lua 的 ResolveItem）；
        -- 沒有替代品就是主的
        local CU = ns.Custom
        local itemID = (CU and CU.ResolveItem and CU.ResolveItem(e)) or e.itemID
        info.itemID, info.mainItemID = itemID, e.itemID
        local I = C_Item
        info.icon = Plain(Try(I and I.GetItemIconByID, itemID))
        if not info.icon then info.icon = Plain(select(5, Try(I and I.GetItemInfoInstant, itemID))) end
        info.name = Plain(Try(I and I.GetItemNameByID, itemID))
    else
        local shown = e.spellID
        if e.kind == "spell" then
            info.isKnown = SpellKnown(e.spellID)
            local ov = Plain(Try(C_Spell and C_Spell.GetOverrideSpell, e.spellID))
            if type(ov) == "number" and ov ~= e.spellID then
                info.overrideSpellID = ov
                shown = ov
            end
        end
        info.icon = Plain(Try(C_Spell and C_Spell.GetSpellTexture, shown))
        info.name = Plain(Try(C_Spell and C_Spell.GetSpellName, shown))
        if not info.isKnown then info.icon = QUESTION end
    end
    info.icon = info.icon or QUESTION
    info.name = info.name or ("#" .. tostring(e.spellID or e.itemID or e.slot))
    return info
end

------------------------------------------------------------
-- 對外查詢
------------------------------------------------------------
function C.Info(id)
    if C.IsCustom(id) then return CustomInfo(id) end
    EnsureBuilt()
    if id == nil then return nil end
    return C.info[id]
end

-- 這個 id 目前在哪一條暴雪檢視器（有效類別）；不在任何一條回 nil
-- 自訂項目回它放在哪一條
function C.SourceOf(id)
    if C.IsCustom(id) then
        local e = C.CustomEntry(id)
        return e and e.bar or nil
    end
    EnsureBuilt()
    local rec = id ~= nil and C.info[id]
    return rec and rec.bar or nil
end

-- 條的有序清單（已套 order／groupOf／hidden）。回傳的是新表，呼叫端可以自由改。
-- withHidden = true 時多回一張「本來在這條、但被藏起來」的清單（設定頁的預覽排在尾端用），
-- 同樣照 order 排。
function C.Bar(barKey, withHidden)
    EnsureBuilt()
    local out, hid = {}, withHidden and {} or nil
    local p = ns.profile
    local bars = p and p.bars
    local bar = type(bars) == "table" and bars[barKey]
    if type(bar) ~= "table" then return out, hid end

    local sp = SpellsTable()
    local groupOf = sp and type(sp.groupOf) == "table" and sp.groupOf or EMPTY
    local hidden  = sp and type(sp.hidden) == "table" and sp.hidden or EMPTY

    -- 資源條的征戰聖擊列顯示時，增益長條上那條同一件事的整個拿掉（不進 hid：不是玩家藏的）
    local autoHide = ns.Resources and ns.Resources.HidesTrackedBar

    -- 天賦條件不成立：正式清單不收；設定頁（withHidden）照樣收進第一張，預覽畫暗（C.TalentBlocked）
    local function Allowed(id)
        return withHidden or not Blocked(sp, id)
    end

    local function Add(id)
        if autoHide and autoHide(id) then return end
        if not hidden[id] then
            if Allowed(id) then out[#out + 1] = id end
        elseif hid then
            hid[#hid + 1] = id
        end
    end

    -- 拉進自訂群組：目標群組要真的存在，否則留在原本那條（群組被刪掉不會讓法術憑空消失）
    local function RoutedTo(id)
        local g = groupOf[id]
        if g ~= nil and g ~= barKey and type(bars[g]) == "table" then return g end
        return nil
    end

    local src = bar.source
    if BAR_CATEGORY_NAME[src] then
        for _, id in ipairs(C.lists[src] or EMPTY) do
            if RoutedTo(id) == nil then Add(id) end
        end
        -- 別的檢視器被指名拉到「這一條」的（例如把核心技能拉回輔助）
        for _, other in ipairs(C.SOURCE_BARS) do
            if other ~= src then
                for _, id in ipairs(C.lists[other] or EMPTY) do
                    if groupOf[id] == barKey then Add(id) end
                end
            end
        end
    else
        -- 自訂群組：照完整順序收被拉進來的
        for _, id in ipairs(C.ordered) do
            local rec = C.info[id]
            if rec and rec.bar and groupOf[id] == barKey then
                local list = C.lists[rec.bar]
                -- 只收真的在某條檢視器清單上的（isKnown 等條件已在那裡過濾）
                for i = 1, #list do
                    if list[i] == id then Add(id); break end
                end
            end
        end
    end

    -- 自訂項目（圖示類、長條類的條都收：放在長條上時 Modules/Custom.lua 換成長條框）。
    -- hidden 對它無效：自己加的項目「移除」就是整筆刪掉，沒有「藏著」這種狀態
    for i, e in ipairs(CustomList()) do
        if ValidCustom(e) and e.bar == barKey then
            local id = "c:" .. i
            if Allowed(id) then out[#out + 1] = id end
        end
    end

    -- 我們自己的順序覆寫：列到的照列的順序排在前面，沒列到的照原順序接在後面
    local ord = sp and type(sp.order) == "table" and sp.order[barKey]
    if type(ord) == "table" and #ord > 0 then
        local function Sort(list)
            local present = {}
            for _, id in ipairs(list) do present[id] = true end
            local sorted, used = {}, {}
            for _, id in ipairs(ord) do
                if present[id] and not used[id] then
                    used[id] = true
                    sorted[#sorted + 1] = id
                end
            end
            for _, id in ipairs(list) do
                if not used[id] then sorted[#sorted + 1] = id end
            end
            return sorted
        end
        out = Sort(out)
        if hid then hid = Sort(hid) end
    end
    return out, hid
end

-- 從暴雪某條檢視器拉法術出去的條（本專精 groupOf 指到、而且真的存在的條），加進 out[key] = true。
-- Bars.RequestSource 用：那條檢視器有動靜時，只有這些條（跟來源條自己）的清單可能變。
-- 在掛勾的訊號路徑上叫，**不重建目錄**（只讀上次建好的 C.info）；讀不到來源的 id 一律算進去。
function C.GroupTargets(sourceKey, out)
    out = out or {}
    local sp = SpellsTable()
    local groupOf = sp and type(sp.groupOf) == "table" and sp.groupOf
    local bars = ns.profile and ns.profile.bars
    if not groupOf or type(bars) ~= "table" then return out end
    for id, g in pairs(groupOf) do
        if g ~= sourceKey and type(bars[g]) == "table" and not out[g] then
            local rec = C.info[id]
            if not rec or rec.bar == nil or rec.bar == sourceKey then out[g] = true end
        end
    end
    return out
end

-- 還在候選池（沒被拖進任何檢視器）的 id，給設定介面的「要先去暴雪面板加」用
function C.Pool(homeBar)
    EnsureBuilt()
    local out = {}
    for _, id in ipairs(C.pool[homeBar] or EMPTY) do out[#out + 1] = id end
    return out
end

------------------------------------------------------------
-- 暴雪設定面板開關：開著時暫停重排，關掉時版面字串變了才重讀
------------------------------------------------------------
function C.IsPaused() return paused end

function C.OnSettingsShow()
    paused = true
    if ns.Fire then ns.Fire("CatalogPaused") end
end

function C.OnSettingsHide()
    paused = false
    local str = ReadLayoutString()
    if str ~= C.layoutString then
        C.Refresh("settings")
    end
    if ns.Fire then ns.Fire("CatalogResumed") end
end

------------------------------------------------------------
-- 初始化（登入流程叫一次）
------------------------------------------------------------
local initialized = false
function C.Init()
    if initialized then return end
    initialized = true

    -- 事件處理器只做「標髒＋下一幀重讀」：事件可能在暴雪的 secure 流程裡同步派送，
    -- 在那裡跑我們的 Lua 會染到它（見 wow-121-addon-code-in-secure-stack）
    local pendingReason
    local function Later(reason)
        dirty = true
        if pendingReason then return end
        pendingReason = reason
        ns.Defer(function()
            local r = pendingReason
            pendingReason = nil
            C.Refresh(r)
        end)
    end

    local E = ns.Events
    E.Register("COOLDOWN_VIEWER_DATA_LOADED", "catalog", function() Later("data") end)
    E.Register("COOLDOWN_VIEWER_TABLE_HOTFIXED", "catalog", function() Later("hotfix") end)
    E.Register("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", "catalog", function() Later("override") end)
    E.Register("PLAYER_SPECIALIZATION_CHANGED", "catalog", function() Later("spec") end, "player")
    -- 學會／忘掉技能、換裝備：暴雪那邊也會重建清單（isKnown 會變）
    E.Register("SPELLS_CHANGED", "catalog", function() Later("spells") end)
    E.Register("PLAYER_EQUIPMENT_CHANGED", "catalog", function() Later("equipment") end)
    E.Register("TRAIT_CONFIG_UPDATED", "catalog", function() Later("talents") end)
    E.Register("PLAYER_TALENT_UPDATE", "catalog", function() Later("talents") end)
    E.Register("ACTIVE_TALENT_GROUP_CHANGED", "catalog", function() Later("talentgroup") end)
    -- 進場：讀取畫面期間 API 回的東西不一定是最後的樣子，進來之後再對一次
    E.Register("PLAYER_ENTERING_WORLD", "catalog", function() Later("world") end)

    if EventRegistry and EventRegistry.RegisterCallback then
        local owner = {}
        pcall(EventRegistry.RegisterCallback, EventRegistry, "CooldownViewerSettings.OnShow",
            function() ns.Defer(C.OnSettingsShow) end, owner)
        pcall(EventRegistry.RegisterCallback, EventRegistry, "CooldownViewerSettings.OnHide",
            function() ns.Defer(C.OnSettingsHide) end, owner)
    end

    -- 登入當下面板就開著（極少見）也要對得上
    local settings = _G.CooldownViewerSettings
    if settings and settings.IsShown then
        local ok, shown = pcall(settings.IsShown, settings)
        if ok and Plain(shown) then paused = true end
    end

    C.Refresh("init")
end
