------------------------------------------------------------
-- 目錄：cooldownID → 法術資料，與每一條的有序清單
--
--   ns.Catalog.Bar(barKey)     有序 cooldownID 陣列（已套本專精的 order／groupOf／hidden，再套格數上限＋溢出）
--   ns.Catalog.BarBase(barKey) 同上但不套溢出（設定頁的 withHidden 路徑、溢出的輸入）
--   ns.Catalog.Overflow()      這一輪的溢出結果（Core/Overflow.lua 的 Resolve；沒有任何一條成立 ⇒ nil）
--   ns.Catalog.Info(id)        { spellID, overrideSpellID, icon, name, category, equipSlot,
--                                hasAura, charges, isInvisible, isKnown, effectiveCategory, home }
--   ns.Catalog.Refresh(reason) 重讀；內容（簽章）變了才廣播 "CatalogChanged"
--   ns.Catalog.IsPaused()      暴雪冷卻管理器設定面板開著 ⇒ true（Bars 暫停重排）
--   ns.Catalog.TalentBlocked(id) 逐法術的天賦條件不成立 ⇒ true（正式清單不收；見下面「天賦條件」）
--   ns.Catalog.HideReason(barKey, id) 沒有物品時隱藏／被動飾品不顯示 ⇒ "noItem"｜"passive"（只讀判準；讓位在 Core/Bars.lua）
--   ns.Catalog.Replacements()  以增益取代：byA（A → B）、byB（B → A）；B 不進任何一條的清單（見那一節）
--
-- 自訂項目（三層：戰隊 "w:<uid>"／職業 "k:<uid>"／專精 "c:<index>"，合併規則在 Core/DB.lua 的
-- EffectiveCustom）也從這裡進清單：Bar(key) 把生效清單裡 bar == key 的排進去，順序跟其他格一樣走 order 表
-- （光環格也是，可以放在任意位置；條上有光環格時 Bars 會強制固定格位，位置本來就不動）。
-- Info(id) 回同一個形狀的表（多 custom／kind／itemID／filter／scope）。
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
C.layoutOverrides = {}     -- [cooldownID] = 暴雪面板的分類覆寫（解碼版面得來；C.Explain 用）
C.sig        = nil         -- 內容簽章（版面字串＋專精＋每條的清單）
C.layoutString = nil       -- 上次讀到的 GetLayoutData 原字串
C.source     = "none"      -- 順序從哪來：layout | fallback:<原因>
C.builds     = 0           -- 實際重建次數（debug／測試用）
C.buildGen   = 0           -- C.info／C.placed 換了就 +1（Build 成功、Adopt 收養）：Replacements 的 memo 作廢點
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
    -- 名字／圖示照暴雪設定面板的靜態路徑（CooldownViewerItemDataMixin:GetSpellID／GetSpellTexture，
    -- layout manager 不吃光環資料）：overrideTooltipSpellID 優先。增益類常靠它指到真正追蹤的光環，
    -- 例如鮮血女王的精華的 spellID 是吸血鬼打擊、tooltip 那個才是精華；只看 spellID 會在預覽／挑選器
    -- 顯示成技能本身，玩家認不出是哪一格。法術索引、冷卻比對照舊用 spellID／overrideSpellID，不看這裡
    local shown      = tipID or overrideID or spellID
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
    -- 職業層／戰隊層的自訂項目：覆寫跟著那一筆走（Core/DB.lua 的 OverrideTable）
    local DB = ns.DB
    local scope = DB and DB.ParseCustomID and DB.ParseCustomID(id)
    if scope == "class" or scope == "shared" then
        local o = DB.OverrideTable(id, false)
        return type(o) == "table" and o.talentCond or nil
    end
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
    local out = {}
    for id in pairs(all or EMPTY) do
        if Blocked(sp, id) then out[#out + 1] = tostring(id) end
    end
    -- 寬層的自訂項目：條件存在那一筆身上（不在 spells[spec].overrides 裡）
    local DB = ns.DB
    if DB and DB.EffectiveCustom then
        for _, it in ipairs(DB.EffectiveCustom()) do
            if it.scope ~= "spec" and Blocked(sp, it.id) then out[#out + 1] = it.id end
        end
    end
    if #out == 0 then return "" end
    table.sort(out)
    return table.concat(out, ",")
end

-- 簽章用：這個專精生效的自訂項目（窄蓋寬、寬層「沒學就不列」的結果變了 ⇒ 清單變了 ⇒ 要重排）
local function CustomSig()
    local DB = ns.DB
    if not (DB and DB.EffectiveCustom) then return "" end
    local out = {}
    for _, it in ipairs(DB.EffectiveCustom()) do
        if it.scope ~= "spec" then
            local e = it.entry
            out[#out + 1] = it.id .. "=" .. tostring(type(e) == "table" and e.spellID or "")
        end
    end
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
    C.layoutOverrides = overrides
    -- 法術索引讀 C.info 的 spellID／overrideSpellID；覆寫不在下面的簽章裡，簽章沒變也可能換了 ⇒ 一律標髒
    if ns.SpellIndex then ns.SpellIndex.dirty = true end
    -- 哪些 id 已經排在某條檢視器的清單上（C.Adopt 用）
    local placed = {}
    for _, bar in ipairs(C.SOURCE_BARS) do
        for _, id in ipairs(lists[bar]) do placed[id] = true end
    end
    C.placed = placed
    C.adopted = 0
    C.buildGen = C.buildGen + 1         -- C.info／C.lists／C.placed 都換了新表

    -- 簽章：版面原字串＋專精＋每條清單（天賦改變 isKnown 也會反映在清單上）＋天賦條件的結果
    -- ＋寬層自訂項目的生效結果（學會／忘掉技能讓職業層的防禦技出現／消失、種族技能解析成哪一個）
    local parts = { str or "", tostring(tag), TalentSig(), CustomSig() }
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
    -- 戰鬥中不輪詢：版面字串只會在暴雪設定面板裡改（面板戰鬥中鎖著；關掉時 OnSettingsHide 會重讀）、
    -- 專精只會在戰鬥外換（事件會來 ⇒ 走上面的 dirty）。戰鬥中每秒讀一次整份版面字串是白做
    local icl = _G.InCombatLockdown
    if icl and icl() then return false end
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
                    C.buildGen = C.buildGen + 1     -- C.placed／C.info 原地改了（Replacements 的 memo）
                    n = n + 1
                    if ns.SpellIndex then ns.SpellIndex.dirty = true end      -- C.info 多了一筆
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
-- slotbuff：飾品欄增益（{ slot = 13|14, buff = N }，N ＝ 暴雪的 buffSlot、不設上限、缺 ＝ 1）：只在那件飾品的
-- 第 N 個增益生效時出現的光環格（Modules/Custom.lua 當光環格畫，認的法術由 C.SlotBuffIDs 照現在裝的飾品解）
local CUSTOM_KINDS = { aura = true, spell = true, item = true, slot = true, slotbuff = true }
C.CUSTOM_SLOT_ORDER = { 13, 14, 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 16, 17 }
local CUSTOM_SLOTS = {}
for _, slot in ipairs(C.CUSTOM_SLOT_ORDER) do CUSTOM_SLOTS[slot] = true end
C.CUSTOM_SLOTS = CUSTOM_SLOTS
-- 飾品欄增益只收兩格飾品（暴雪的 EquipSlotTracked 也只為飾品帶增益）
C.SLOTBUFF_SLOT_ORDER = { 13, 14 }
local SLOTBUFF_SLOTS = { [13] = true, [14] = true }
C.SLOTBUFF_SLOTS = SLOTBUFF_SLOTS

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

------------------------------------------------------------
-- 裝備欄的增益法術（飾品用掉之後身上的那個增益）
--
--   ns.Catalog.SlotBuffIDs(slot, buffIndex)  → { spellID… }, sig    buffIndex：第幾個增益（暴雪的 buffSlot，正整數、不設上限）；
--                                                                 nil ＝ 全部合併去重
--   ns.Catalog.SlotBuffIndices(slot)         → { buffIndex… }（排序；解得出增益的那幾個）
--   ns.Catalog.SlotUseBuffIDs(slot)          → { spellID… }, sig    冷卻格（使用效果）認的增益（暴雪 EquipSlotEssential 那一筆）
--   ns.Catalog.SlotOverlayIDs(barKey, id, slot) → ids, sig ｜ nil   冷卻格要不要疊增益按鈕（Modules/Custom.lua）
--   ns.Catalog.InvalidateSlotBuffs()         作廢快取（換裝、暴雪資料重載／熱修正、進場）
--
-- 來源：EquipSlotTracked 類別裡 equipSlot == slot 的那幾筆的 linkedSpellIDs（暴雪從現在裝的物品帶出來的增益，
-- 第 buffSlot 個）。暴雪沒給框的時候照樣讀得到。讀不到（一筆都沒有、或 linkedSpellIDs 空）時 buffIndex 為 nil 或 1
-- 退回 C_Item.GetItemSpell 的使用效果（只當第 1 個）。那一格沒裝東西 ⇒ 空。
-- 只問 C_CooldownViewer 的兩支明文 API（pcall、每個值過 Plain），**不讀任何光環**：增益在不在、剩幾秒全交給
-- AuraContainer 的 includeSpellIDs（插件端零讀取）。
-- 回傳的表是快取本身，呼叫端不准改。
------------------------------------------------------------
local function PositiveInt(v)
    return type(v) == "number" and v > 0 and v == math.floor(v)
end

-- 簽章：排序後串起來（跟 Custom.AuraIDSig 同一個寫法；Catalog 先載入，不依賴它）
local function IDSig(ids)
    local t = {}
    for i, id in ipairs(ids) do t[i] = id end
    table.sort(t)
    for i, id in ipairs(t) do t[i] = tostring(id) end
    return table.concat(t, ",")
end

-- 純函式（離線可測）：infos ＝ { { equipSlot, buffSlot, linkedSpellIDs = { … } }, … }（已過 Plain），
-- itemSpell ＝ 那一格物品的使用效果法術（退路；nil ＝ 沒有）。buffSlot 不是正整數當第 1 個。
-- 順序：照 buffSlot、同一個 buffSlot 照 linkedSpellIDs 的順序；去重
function C.SlotBuffIDsFrom(infos, slot, buffIndex, itemSpell)
    local picked = {}
    for i, it in ipairs(type(infos) == "table" and infos or {}) do
        if type(it) == "table" and it.equipSlot == slot then
            local n = PositiveInt(it.buffSlot) and it.buffSlot or 1
            if buffIndex == nil or n == buffIndex then
                picked[#picked + 1] = { n = n, i = i, ids = it.linkedSpellIDs }
            end
        end
    end
    table.sort(picked, function(a, b)
        if a.n ~= b.n then return a.n < b.n end
        return a.i < b.i
    end)
    local out, seen = {}, {}
    for _, p in ipairs(picked) do
        for _, id in ipairs(type(p.ids) == "table" and p.ids or {}) do
            if PositiveInt(id) and not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    if #out == 0 and (buffIndex == nil or buffIndex == 1) and PositiveInt(itemSpell) then out[1] = itemSpell end
    return out, IDSig(out)
end

-- 純函式：這一格解得出增益的 buffSlot（排序）；暴雪那邊一筆都解不出、但有使用效果 ⇒ { 1 }
function C.SlotBuffIndicesFrom(infos, slot, itemSpell)
    local set, out = {}, {}
    for _, it in ipairs(type(infos) == "table" and infos or {}) do
        if type(it) == "table" and it.equipSlot == slot and type(it.linkedSpellIDs) == "table" then
            local n = PositiveInt(it.buffSlot) and it.buffSlot or 1
            for _, id in ipairs(it.linkedSpellIDs) do
                if PositiveInt(id) then set[n] = true break end
            end
        end
    end
    for n in pairs(set) do out[#out + 1] = n end
    table.sort(out)
    if #out == 0 and PositiveInt(itemSpell) then out[1] = 1 end
    return out
end

local equipScan = {}                -- 類別名 → 掃一次的結果（infos 形狀）；沒有 ＝ 要重掃
local slotBuffCache = {}           -- "slot|buffIndex" → { ids, sig }
local NO_IDS = setmetatable({}, { __newindex = function() error("read-only") end })

-- catName：EquipSlotTracked（增益那幾筆，預設）｜EquipSlotEssential（冷卻那一筆：暴雪「使用增益時間」認的增益）
local function ScanEquipBuffs(catName)
    catName = catName or "EquipSlotTracked"
    if equipScan[catName] then return equipScan[catName] end
    local out = {}
    local CV = C_CooldownViewer
    local cat = EnumCategory(catName)
    if cat and CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo then
        local ok, set = pcall(CV.GetCooldownViewerCategorySet, cat, true)
        if ok and type(set) == "table" then
            for _, raw in ipairs(set) do
                local id = Plain(raw)
                local ok2, info = false, nil
                if id ~= nil then ok2, info = pcall(CV.GetCooldownViewerCooldownInfo, id) end
                if ok2 and type(info) == "table" then
                    local linked = {}
                    if type(info.linkedSpellIDs) == "table" then
                        for _, v in ipairs(info.linkedSpellIDs) do
                            local s = Plain(v)
                            if s ~= nil then linked[#linked + 1] = s end
                        end
                    end
                    out[#out + 1] = { cooldownID = id, equipSlot = Plain(info.equipSlot), buffSlot = Plain(info.buffSlot),
                                      linkedSpellIDs = linked }
                end
            end
        end
    end
    equipScan[catName] = out
    return out
end

-- 那一格物品的使用效果法術（明文；C_Item.GetItemSpell 回 名字, spellID）
local function SlotItemSpell(itemID)
    local api = C_Item and C_Item.GetItemSpell
    if not (api and itemID) then return nil end
    local ok, _, spellID = pcall(api, itemID)
    spellID = ok and Plain(spellID) or nil
    return type(spellID) == "number" and spellID or nil
end

function C.SlotBuffIDs(slot, buffIndex)
    if not (CUSTOM_SLOTS[slot] and (buffIndex == nil or PositiveInt(buffIndex))) then return NO_IDS, "" end
    local key = slot .. "|" .. tostring(buffIndex)
    local hit = slotBuffCache[key]
    if hit then return hit.ids, hit.sig end
    local itemID = C.SlotItemID(slot)
    if not itemID then return NO_IDS, "" end          -- 空格：不快取（裝上去時 PLAYER_EQUIPMENT_CHANGED 會作廢）
    local ids, sig = C.SlotBuffIDsFrom(ScanEquipBuffs(), slot, buffIndex, SlotItemSpell(itemID))
    -- 解不出來不快取：剛登入物品資料還沒到時下一次再問（掃描本身照樣快取，只多一次 GetItemSpell）
    if #ids > 0 then slotBuffCache[key] = { ids = ids, sig = sig } end
    return ids, sig
end

function C.SlotBuffIndices(slot)
    local itemID = CUSTOM_SLOTS[slot] and C.SlotItemID(slot) or nil
    if not itemID then return {} end
    return C.SlotBuffIndicesFrom(ScanEquipBuffs(), slot, SlotItemSpell(itemID))
end

C.slotBuffStale = false            -- 作廢過、還沒要求重排（Init 的 Later 下一幀消化）
function C.InvalidateSlotBuffs()
    for k in pairs(equipScan) do equipScan[k] = nil end
    for k in pairs(slotBuffCache) do slotBuffCache[k] = nil end
    C.slotBuffStale = true
end

-- 冷卻格（使用效果）認的增益：跟暴雪自己的飾品冷卻格一樣，照 EquipSlotEssential 那一筆（equipSlot == slot）的
-- linkedSpellIDs——**不是**這一格全部的增益：第 2 個以後常是被動觸發，蓋在冷卻格上會讓人以為是用掉了。
-- 那一筆解不出來 ⇒ 退第 1 個增益（SlotBuffIDs(slot, 1)，再退使用效果）
function C.SlotUseBuffIDs(slot)
    if not CUSTOM_SLOTS[slot] then return NO_IDS, "" end
    local key = slot .. "|use"
    local hit = slotBuffCache[key]
    if hit then return hit.ids, hit.sig end
    if not C.SlotItemID(slot) then return NO_IDS, "" end
    local ids, sig = C.SlotBuffIDsFrom(ScanEquipBuffs("EquipSlotEssential"), slot, nil, nil)
    if #ids == 0 then ids, sig = C.SlotBuffIDs(slot, 1) end
    if #ids > 0 then slotBuffCache[key] = { ids = ids, sig = sig } end
    return ids, sig
end

-- 飾品欄冷卻格要不要疊增益按鈕：條層／逐法術的「增益持續中顯示持續時間」沒關、而且解得出增益 ⇒ ids, sig
-- （Modules/Custom.lua 的疊層與下面的 BarHasAuraSlot 同一個判準）
function C.SlotOverlayIDs(barKey, id, slot)
    if id == nil or not CUSTOM_SLOTS[slot] then return nil end
    if ns.SpellSetting and ns.SpellSetting(barKey, id, "showAuraTime") == false then return nil end
    local ids, sig = C.SlotUseBuffIDs(slot)
    if #ids == 0 then return nil end
    return ids, sig
end

------------------------------------------------------------
-- 飾品欄增益的名字與滑鼠提示（挑選器的增益鈕、逐法術面板、預覽格共用一支）
--
--   ns.Catalog.SlotBuffName(itemName, buff)          → 「飾品名（增益 N）」
--   ns.Catalog.SlotBuffLabel(buff)                   → 「增益 N」（暴雪自己的字串讀得到就用它的）
--   ns.Catalog.SlotBuffTooltip(tooltip, slot, buff [, refresh])
--       照暴雪飾品增益格的提示寫：標題＝飾品名（品質色）；buff 那個增益的每個法術一段：圖示＋法術名＋「增益 N」＋
--       照這件裝備等級算過的效果說明（Spell:GetSpellDescriptionForItemLocation）。buff 為 nil ＝ 這一格全部的增益，
--       各段標自己的「增益 N」。空格 ⇒ 欄位名＋「（空的）」；解不出增益 ⇒ 紅字「這件飾品沒有可追蹤的增益」。
--       法術資料還沒載入：先畫標題、ContinueOnSpellLoad 載完叫 refresh()——只在提示還開著、擁有者沒換、
--       中間沒有別的呼叫蓋過（序號）時才叫。refresh 省略 ＝ 不等。
--   ⚠ tooltip 是暴雪的框：只呼叫方法，不寫任何欄位（序號記在自己的表，以擁有者為鍵、弱參照）
------------------------------------------------------------
local function TryCall(fn, ...)
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

-- 語系表：Catalog 比 Locales 晚載入，但離線測試沒有 ns.L ⇒ 查不到就回 key（跟 Locales/Locale.lua 同一個退路）
local L = setmetatable({}, { __index = function(_, k)
    local t = ns.L
    return (t and t[k]) or k
end })

function C.SlotBuffLabel(buff)
    local fmt = GlobalText("COOLDOWN_VIEWER_TRINKET_AURA_TOOLTIP_LABEL")
    if fmt and fmt:find("%d", 1, true) then
        local ok, txt = pcall(string.format, fmt, buff)
        if ok then return txt end
    end
    return L["Buff %d"]:format(buff)
end

function C.SlotBuffName(itemName, buff)
    return L["%s (buff %d)"]:format(tostring(itemName), PositiveInt(buff) and buff or 1)
end

local tipSerial = 0
local tipOwnerSerial = setmetatable({}, { __mode = "k" })

-- 這一段（第 buff 個增益）要畫的法術：{ { id, buff }, … }
local function TooltipSpells(slot, buff)
    local out = {}
    if buff then
        for _, id in ipairs((C.SlotBuffIDs(slot, buff))) do out[#out + 1] = { id = id, buff = buff } end
        return out
    end
    for _, n in ipairs(C.SlotBuffIndices(slot)) do
        for _, id in ipairs((C.SlotBuffIDs(slot, n))) do out[#out + 1] = { id = id, buff = n } end
    end
    return out
end

function C.SlotBuffTooltip(tooltip, slot, buff, refresh)
    if not (tooltip and tooltip.SetText) then return end
    tipSerial = tipSerial + 1
    local serial = tipSerial
    local owner = tooltip.GetOwner and tooltip:GetOwner() or nil
    if owner then tipOwnerSerial[owner] = serial end
    local itemID = C.SlotItemID(slot)
    if not itemID then
        tooltip:SetText(C.SlotName(slot) or ("#" .. tostring(slot)))
        tooltip:AddLine(L["(empty)"], 0.8, 0.8, 0.8)
        return
    end
    -- 標題：飾品名（品質色）
    local I = C_Item
    local name = Plain(TryCall(I and I.GetItemNameByID, itemID)) or C.SlotName(slot) or ("#" .. tostring(itemID))
    local r, g, b = 1, 1, 1
    local quality = Plain(TryCall(I and I.GetItemQualityByID, itemID))
    if type(quality) == "number" and I and I.GetItemQualityColor then
        local qr, qg, qb = TryCall(I.GetItemQualityColor, quality)
        qr, qg, qb = Plain(qr), Plain(qg), Plain(qb)
        if type(qr) == "number" and type(qg) == "number" and type(qb) == "number" then r, g, b = qr, qg, qb end
    end
    tooltip:SetText(name, r, g, b)
    local spells = TooltipSpells(slot, buff)
    if #spells == 0 then
        tooltip:AddLine(L["This trinket has no buff to track."], 1, 0.3, 0.3, true)
        return
    end
    -- 法術資料沒載入：照暴雪的做法先只畫標題，載完再整個重畫
    local SpellObj = _G.Spell
    local pending = {}
    if SpellObj and SpellObj.CreateFromSpellID then
        for _, sp in ipairs(spells) do
            local ok, obj = pcall(SpellObj.CreateFromSpellID, SpellObj, sp.id)
            sp.obj = ok and obj or nil
            if sp.obj and sp.obj.IsSpellDataCached then
                local okc, cached = pcall(sp.obj.IsSpellDataCached, sp.obj)
                if okc and cached == false then pending[#pending + 1] = sp.obj end
            end
        end
    end
    if #pending > 0 then
        if refresh and owner then
            local function Again()
                if tipOwnerSerial[owner] ~= serial then return end           -- 中間換過內容（同一顆鈕重開也算）
                if not (tooltip:IsShown() and tooltip:GetOwner() == owner) then return end
                refresh()
            end
            for _, obj in ipairs(pending) do
                if obj.ContinueOnSpellLoad then pcall(obj.ContinueOnSpellLoad, obj, Again) end
            end
        end
        return
    end
    local loc
    if _G.ItemLocation and ItemLocation.CreateFromEquipmentSlot then
        local ok, l = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
        if ok then loc = l end
    end
    for i, sp in ipairs(spells) do
        if i > 1 then tooltip:AddLine(" ") end
        local spellName = Plain(TryCall(C_Spell and C_Spell.GetSpellName, sp.id)) or ("#" .. tostring(sp.id))
        tooltip:AddLine(spellName, 1, 1, 1)
        local tex = Plain(TryCall(C_Spell and C_Spell.GetSpellTexture, sp.id))
        if tex and tooltip.AddTexture then
            -- 跟暴雪同一個擺法：32×32 貼在這一行左邊、往下佔兩行（設定表不收就退回行內小圖示）
            local okT = pcall(tooltip.AddTexture, tooltip, tex, {
                width = 32, height = 32,
                region = Enum and Enum.TooltipTextureRelativeRegion and Enum.TooltipTextureRelativeRegion.LeftLine,
                anchor = Enum and Enum.TooltipTextureAnchor and Enum.TooltipTextureAnchor.LeftTop,
                margin = { left = 0, right = 8, top = 0, bottom = -20 },
            })
            if not okT then pcall(tooltip.AddTexture, tooltip, tex) end
        end
        tooltip:AddLine(C.SlotBuffLabel(sp.buff), 1, 1, 1, false, 40)
        local desc
        if sp.obj and loc and sp.obj.GetSpellDescriptionForItemLocation then
            local ok, d = pcall(sp.obj.GetSpellDescriptionForItemLocation, sp.obj, loc)
            if ok then desc = d end
        end
        if desc == nil and C_Spell and C_Spell.GetSpellDescription then desc = TryCall(C_Spell.GetSpellDescription, sp.id) end
        if desc ~= nil and (ns.IsSecret(desc) or desc ~= "") then
            tooltip:AddLine(" ")
            tooltip:AddLine(desc, 0.1, 1, 0.1, true)          -- 說明照暴雪的綠字（秘密值原樣交給提示畫）
        end
    end
end

SpellsTable = function()
    local p = ns.profile
    local spec = ns.specID
    local sp = p and type(p.spells) == "table" and spec and p.spells[spec]
    return type(sp) == "table" and sp or nil
end

-- 這個專精實際生效的自訂項目（三層合併、窄蓋寬，Core/DB.lua 的 EffectiveCustom）：{ { id, key, entry, raw, scope }, … }
local function Effective()
    local DB = ns.DB
    if DB and DB.EffectiveCustom then return DB.EffectiveCustom() end
    return EMPTY
end

-- id 解析一律走 DB.ParseCustomID（"c:"／"k:"／"w:"）
local function Parse(id)
    local DB = ns.DB
    if DB and DB.ParseCustomID then return DB.ParseCustomID(id) end
    return nil
end

-- "c:3" → 3（專精層的陣列位置）；寬層與非自訂 id 回 nil
function C.CustomIndex(id)
    local scope, n = Parse(id)
    if scope == "spec" then return n end
    return nil
end

function C.IsCustom(id) return Parse(id) ~= nil end

-- 這一筆的形狀對不對（匯入的字串、舊版存檔都可能帶來壞資料；壞的一律當不存在）
-- 選用欄位壞掉不算整筆壞：物品的 alts、光環格的 spellIDs 不是表就當沒有（Modules/Custom.lua 讀的時候濾）
local function ValidCustom(e)
    if type(e) ~= "table" or not CUSTOM_KINDS[e.kind] then return false end
    if e.kind == "item" then return type(e.itemID) == "number" end
    if e.kind == "slot" then return CUSTOM_SLOTS[e.slot] == true end
    if e.kind == "slotbuff" then
        return SLOTBUFF_SLOTS[e.slot] == true and (e.buff == nil or PositiveInt(e.buff))
    end
    return type(e.spellID) == "number"
end
C.ValidCustom = ValidCustom

-- 光環格形狀的種類（光環格、飾品欄增益）：條上有它 ⇒ 持有框是保護框、固定格位強制打開
local function AuraShaped(kind) return kind == "aura" or kind == "slotbuff" end
C.AuraShaped = AuraShaped

-- 生效清單的 id → 那一項（同一個 id 只留第一個，跟原本「線性掃到第一個就回」同語意）。
-- 跟著 EffectiveCustom 的 memo 走：它回同一張表 ⇒ 這張也不重建（換幀、customGen 變了它回新表，這裡跟著重建）
local byIDList, byID = nil, {}
local function EffectiveByID()
    local list = Effective()
    if list ~= byIDList then
        byID = {}
        for _, it in ipairs(list) do
            if byID[it.id] == nil then byID[it.id] = it end
        end
        byIDList = list
    end
    return byID
end

-- 生效的那一筆（種族技能是解析後的視圖）、編號（陣列位置／uid）、範圍；被窄層蓋掉、用不到、壞資料 ⇒ nil
function C.CustomEntry(id)
    if not Parse(id) then return nil end
    local it = EffectiveByID()[id]
    if it and ValidCustom(it.entry) then return it.entry, it.key, it.scope end
    return nil
end

function C.IsAuraSlot(id)
    local e = C.CustomEntry(id)
    return e ~= nil and AuraShaped(e.kind)
end

-- 這條上有沒有保護框（有的話固定格位被強制打開）：光環格（含飾品欄增益），**或**會疊增益按鈕的飾品欄（C.SlotOverlayIDs；
-- 疊層的持有框跟光環格一樣是條容器底下的保護框）。名字沿用，設定頁的黃字原因同一句。
-- 暴雪的裝備欄冷卻格（C.ProxySlotOf 成立的）也算：暴雪沒給框時由我們代畫（Core/Bars.lua），代畫格就是飾品欄、
-- 一樣會疊增益。**不管這一輪暴雪有沒有給框**（保守：給框時固定格位多開不會壞；跟著框的有無翻來翻去反而會在
-- 戰鬥中改格位）。清單用 BarBase（不套溢出）：BarHasAuraSlot ← Bars.Occupancy ← Overflow 的佔位判斷，
-- 這裡再走 C.Bar／C.Overflow 會繞回自己。
-- 溢出：接收條算「有」——只要有一條成立的來源條上有（保守：不管這一輪有沒有真的溢過來）。
-- 持有框是保護框，溢過來之後也不能在戰鬥中移，所以接收條同樣要固定格位、不能跟著游標
function C.BarHasAuraSlot(barKey)
    -- 先看有沒有任何一筆暴雪的裝備欄冷卻格排在條上：沒有就不必為每條重算 BarBase
    local proxyCandidate = nil
    local function AnyProxyCandidate()
        if proxyCandidate == nil then
            proxyCandidate = false
            EnsureBuilt()
            for _, list in pairs(C.lists or EMPTY) do
                for _, id in ipairs(list) do
                    if C.ProxySlotOf(id) then proxyCandidate = true break end
                end
                if proxyCandidate then break end
            end
        end
        return proxyCandidate
    end
    local function Has(k)
        for _, it in ipairs(Effective()) do
            local e = it.entry
            if ValidCustom(e) and e.bar == k then
                if AuraShaped(e.kind) then return true end
                if e.kind == "slot" and C.SlotOverlayIDs(k, it.id, e.slot) then return true end
            end
        end
        if AnyProxyCandidate() then
            for _, id in ipairs((C.BarBase(k))) do
                local slot = C.ProxySlotOf(id)
                if slot and C.SlotOverlayIDs(k, id, slot) then return true end
            end
        end
        return false
    end
    if Has(barKey) then return true end
    local ov = C.OverflowPairs and C.OverflowPairs()
    if ov then
        for _, pr in ipairs(ov) do
            if pr.dst == barKey and Has(pr.src) then return true end
        end
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

-- memo（效能修整 E2）：DB.customGen、GetTime() 戳記、專精、設定檔四樣都相同才回上一次的表（一輪排版同一格會問好幾次）。
-- 讀的東西（裝在欄位上的物品、包包裡的替代品、學了沒、覆寫法術、圖示與名字）同一幀內不會變；
-- 自訂項目本身的寫入走 customGen（Core/DB.lua「寫入世代」）。讀不到 GetTime（離線測試）⇒ 不 memo。
-- ⚠ 回傳的表呼叫端不准改（同一幀的其他呼叫拿到的是同一張）
local infoMemo, infoKey = {}, { gen = -1 }
local BuildCustomInfo
local function CustomInfo(id)
    local now = _G.GetTime and _G.GetTime() or nil
    if now == nil then return BuildCustomInfo(id) end
    local DB, k = ns.DB, infoKey
    local gen = DB and DB.customGen or 0
    if k.at ~= now or k.gen ~= gen or k.spec ~= ns.specID or k.profile ~= ns.profile then
        infoMemo = {}
        k.at, k.gen, k.spec, k.profile = now, gen, ns.specID, ns.profile
    end
    local v = infoMemo[id]
    if v == nil then
        v = BuildCustomInfo(id) or false
        infoMemo[id] = v
    end
    return v or nil
end

BuildCustomInfo = function(id)
    local e, i, scope = C.CustomEntry(id)
    if not e then return nil end
    local info = {
        cooldownID = id, custom = true, index = i, kind = e.kind, bar = e.bar,
        spellID = e.spellID, itemID = e.itemID, filter = e.filter, slot = e.slot, isKnown = true,
        -- 範圍（"shared"｜"class"｜"spec"）；種族技能那一筆（解析成這個角色的那一個）多 racial
        scope = scope, racial = e.racial and true or nil,
    }
    if e.kind == "slotbuff" then
        -- 飾品欄增益：引擎當光環格畫（kind 回 "aura"，設定頁的光環格路徑照走），多 slotBuff。
        -- 圖示用飾品圖示（占位也是）、名字「飾品名（增益 N）」；解不出增益（空格、沒有可追蹤的增益、
        -- 存了第 3 個而這件只有 1 個）⇒ isKnown false、問號格（提示寫原因，C.SlotBuffTooltip）
        local buff = PositiveInt(e.buff) and e.buff or 1
        local ids = C.SlotBuffIDs(e.slot, buff)
        local itemID = C.SlotItemID(e.slot)
        info.kind, info.filter, info.buff = "aura", "HELPFUL", buff
        info.slotBuff = { slot = e.slot, buff = buff }
        info.itemID, info.spellID = itemID, ids[1]
        info.slotName = C.SlotName(e.slot)
        info.isKnown = #ids > 0
        local I = C_Item
        local itemName = itemID and Plain(Try(I and I.GetItemNameByID, itemID)) or nil
        info.name = C.SlotBuffName(itemName or info.slotName or ("#" .. tostring(e.slot)), buff)
        if info.isKnown then
            info.icon = itemID and Plain(Try(I and I.GetItemIconByID, itemID)) or nil
            if info.icon == nil then info.icon = Plain(Try(C_Spell and C_Spell.GetSpellTexture, ids[1])) end
        else
            info.icon = QUESTION
        end
    elseif e.kind == "slot" then
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

-- 暴雪的裝備欄冷卻格（飾品、武器的使用效果）：暴雪沒給框時可以由我們代畫（Core/Bars.lua、Modules/Custom.lua 的
-- Custom.Proxy）。成立 ⇒ 那一格的裝備欄位（C.CUSTOM_SLOTS 認得的），其餘 nil：
--   * 暴雪的數字 cooldownID（自訂項目不算）、資料帶 equipSlot；
--   * 來源條是冷卻類（核心／輔助）——增益類不在時本來就可能沒有框，而且那是增益不是冷卻。
-- 只讀目錄（C.Info 已過 Plain），不問暴雪的框
local AURA_SOURCE = { buffs = true, buffbars = true }       -- ns.Viewers.AURA_KIND 還沒載入時的退路（同值）
function C.ProxySlotOf(id)
    if type(id) ~= "number" then return nil end
    local info = C.Info(id)
    local slot = info and info.equipSlot
    if type(slot) ~= "number" or not CUSTOM_SLOTS[slot] then return nil end
    local src = info.bar
    local aura = (ns.Viewers and ns.Viewers.AURA_KIND) or AURA_SOURCE
    if src == nil or aura[src] then return nil end
    return slot
end

------------------------------------------------------------
-- 沒有物品時隱藏／被動飾品不顯示（使用者 2026-10-05 拍板）
--
--   ns.Catalog.ItemsGone(ids, countOf)            純函式：每一件 countOf(id) 都是明文 0 ⇒ true；
--                                                   任一件讀不到（nil／秘密／不是數字）或 > 0、或清單是空的 ⇒ false
--   ns.Catalog.PassiveOf(itemID, cached, useSpell) 純函式 → "passive"｜"pending"｜nil
--       沒裝東西 ⇒ nil（空格照舊畫空格圖，不屬於這條）；物品資料還沒載入（cached == false）⇒ "pending"；
--       載入了（cached == true）而且沒有使用效果（useSpell == nil）⇒ "passive"；判不出來（cached 讀不到）⇒ nil
--   ns.Catalog.HideReason(barKey, id)  → reason, watch
--       reason  這一格現在要不要收："noItem"｜"passive"｜nil
--       watch   要聽什麼才知道它會變："bag"（包包數量，BAG_UPDATE_DELAYED）｜"info"（物品資料還沒到，
--               GET_ITEM_INFO_RECEIVED）｜nil（換裝走 PLAYER_EQUIPMENT_CHANGED，本來就會全部重排）
--       設定照 barKey 那一條讀（逐法術覆寫 > 條層 > 主題；ns.SpellSetting 的 hideNoItem／hidePassiveTrinket）。
--       適用：自訂物品（kind "item"：主＋替代品全都沒有才收）；飾品欄（kind "slot"）與代畫格（暴雪的數字 id、
--       C.ProxySlotOf 成立——呼叫端自己確認那一格這一輪真的是代畫）。其餘（暴雪的格、光環格、飾品欄增益）一律 nil。
-- 規則：只用明文判斷，讀不到一律不收（寧可多顯示）。收掉之後怎麼排（讓位／固定格位留空格）是 Core/Bars.lua 的事：
-- 數量在戰鬥中也會變，固定格位要看條，所以判準放在這裡（純讀），排法跟 Occupancy 放在 Bars（同一支 B.HideMode）。
--
-- ⚠ 暴雪自己的消耗品格（帶 spellCategoryID 的那類：戰鬥藥水、治療藥水、治療石）**不做**：暴雪的格子本身沒有
-- 「這一類有哪些物品」的清單，只記最後一次用掉的那件（C_Spell.GetLastCategoryCooldownSource，用過才有）與兩個
-- 寫死在它檔案裡的治療石預設物品；藥水類連預設都沒有。插件讀不到「包包裡還有沒有這一類的任何一件」，
-- 拿「最後用掉的那件數量是 0」當判準會在換了別種藥水時把格子誤收，所以不做（README 有記）。
------------------------------------------------------------
local function ItemCountOf(itemID)
    local api = C_Item and C_Item.GetItemCount
    if not (api and type(itemID) == "number") then return nil end
    local ok, n = pcall(api, itemID, false, true)
    if not ok then return nil end
    n = Plain(n)
    return type(n) == "number" and n or nil
end

function C.ItemsGone(ids, countOf)
    if type(ids) ~= "table" or #ids == 0 or type(countOf) ~= "function" then return false end
    for _, id in ipairs(ids) do
        local n = countOf(id)
        if type(n) ~= "number" or n > 0 then return false end
    end
    return true
end

function C.PassiveOf(itemID, cached, useSpell)
    if type(itemID) ~= "number" then return nil end
    if cached == false then return "pending" end
    if cached ~= true then return nil end
    if useSpell == nil then return "passive" end
    return nil
end

-- 物品資料還沒到的：要一次（到了派 GET_ITEM_INFO_RECEIVED，Core/Bars.lua 聽著就重排）
local loadRequested = {}
local function SlotPassive(slot)
    local itemID = C.SlotItemID(slot)
    if not itemID then return nil end
    local I = C_Item
    local cached = Plain(Try(I and I.IsItemDataCachedByID, itemID))
    if type(cached) ~= "boolean" then cached = nil end
    local st = C.PassiveOf(itemID, cached, cached and SlotItemSpell(itemID) or nil)
    if st == "pending" then
        if not loadRequested[itemID] and I and I.RequestLoadItemDataByID then
            loadRequested[itemID] = true
            pcall(I.RequestLoadItemDataByID, itemID)
        end
    else
        loadRequested[itemID] = nil
    end
    return st
end

function C.HideReason(barKey, id)
    local SS = ns.SpellSetting
    if id == nil or not SS then return nil end
    local kind, slot, e
    if type(id) == "number" then
        slot = C.ProxySlotOf(id)
        if not slot then return nil end
        kind = "slot"
    else
        e = C.CustomEntry(id)
        if not e then return nil end
        kind, slot = e.kind, e.slot
    end
    if kind == "item" then
        if SS(barKey, id, "hideNoItem") ~= true then return nil end
        local CU = ns.Custom
        local ids = (CU and CU.ItemIDs) and CU.ItemIDs(e) or { e.itemID }
        return C.ItemsGone(ids, ItemCountOf) and "noItem" or nil, "bag"
    elseif kind == "slot" then
        if SS(barKey, id, "hidePassiveTrinket") ~= true then return nil end
        local st = SlotPassive(slot)
        if st == "pending" then return nil, "info" end
        return st, nil
    end
    return nil
end

-- 探針：「清單上有、暴雪沒給框」的那一格，暴雪自己是怎麼看的（只讀，給 [missing] 與 /mcdm debug 用）
--   API      ＝ 現在問 C_CooldownViewer 的 isKnown（新鮮的）
--   暴雪快取 ＝ 暴雪設定資料提供者快取裡的 isKnown（檢視器排版與面板灰不灰都看這份；只在它標髒的事件才重建）
--   兩者不同 ⇒ 暴雪的快取過期了；都是 false ⇒ 暴雪本身就認為沒學會。裝備欄項目另外印那一格的物品與使用效果
-- ⚠ 只能直接讀欄位，不能呼叫資料提供者的方法：GetCooldownInfoForID 標髒時會就地重建快取，從插件跑等於污染整份
function C.KnownProbe(id)
    local CV = C_CooldownViewer
    local api, cat, slot, linked, buffSlot = "?", "?", nil, "—", nil
    if CV and CV.GetCooldownViewerCooldownInfo then
        local ok, raw = pcall(CV.GetCooldownViewerCooldownInfo, id)
        if ok and type(raw) == "table" then
            api, cat, slot = tostring(Plain(raw.isKnown)), tostring(Plain(raw.category)), Plain(raw.equipSlot)
            buffSlot = Plain(raw.buffSlot)
            -- 裝備欄增益項目：暴雪從現在裝的物品帶出來的增益法術（第 buffSlot 個）
            if type(raw.linkedSpellIDs) == "table" then
                local t = {}
                for i, v in ipairs(raw.linkedSpellIDs) do t[i] = tostring(Plain(v)) end
                if #t > 0 then linked = table.concat(t, "/") end
            end
        elseif ok then
            api = "無資料"
        end
    end
    local cache, dirty = "?", "?"
    local settings = _G.CooldownViewerSettings
    local dp = type(settings) == "table" and rawget(settings, "dataProvider")
    if type(dp) == "table" then
        dirty = tostring(Plain(rawget(dp, "displayDataDirty")))
        local dd = rawget(dp, "displayData")
        local byID = type(dd) == "table" and rawget(dd, "cooldownInfoByID")
        local ci = type(byID) == "table" and byID[id]
        cache = type(ci) == "table" and tostring(Plain(ci.isKnown)) or "不在快取"
    end
    local rec = C.info and C.info[id]
    local s = ("%s API=%s 暴雪快取=%s（髒=%s） 我們=%s 類別=%s"):format(tostring(id), api, cache, dirty,
        rec and tostring(rec.isKnown) or "—", cat)
    if type(slot) == "number" then
        local item, spell, cached = nil, nil, nil
        if GetInventoryItemID then
            local ok, v = pcall(GetInventoryItemID, "player", slot)
            item = ok and Plain(v) or nil
        end
        if type(item) == "number" and C_Item then
            if C_Item.GetItemSpell then
                local ok, _, v = pcall(C_Item.GetItemSpell, item)
                spell = ok and Plain(v) or nil
            end
            if C_Item.IsItemDataCachedByID then
                local ok, v = pcall(C_Item.IsItemDataCachedByID, item)
                cached = ok and Plain(v) or nil
            end
        end
        s = s .. ("  槽%d 物品=%s 使用效果=%s 物品快取=%s 增益=%s（第%s個）"):format(slot, tostring(item), tostring(spell),
            tostring(cached), linked, tostring(buffSlot))
    end
    return s
end

------------------------------------------------------------
-- 以增益取代（spells[spec].overrides[A].replaceWith = B）
--
-- A ＝ 核心／輔助技能的 cooldownID（暴雪 item；自訂項目不開放），B ＝ 增益圖示列的 cooldownID。
-- B 生效期間 A 那一格改放 B 的 item（Core/Bars.lua 的 Relayout），所以 B 從**每一條**的清單拿掉
-- （它的位置就是 A 那一格；被移除清單也不列）。
--
-- 只有「兩邊現在都真的在」才成立，其餘一律當沒設（設定留著，條件回來自動生效）：
--   * A 在某條檢視器的清單上（學會了、暴雪會給框）、沒被玩家移除（hidden）、來源是核心或輔助
--   * B 在增益圖示列的清單上（天賦沒點 ⇒ 不在 ⇒ 退回 A 本身，B 也不會被拿掉）
--   * A、B 都沒被逐法術的天賦條件擋掉（Blocked；A 被擋 ⇒ 沒有那一格，B 不能跟著消失；
--     B 被擋 ⇒ 玩家本來就不要它出現）
--   * 同一個 B 只給一個 A（設定頁會擋；擋不住的舊資料取 cooldownID 小的那個，結果固定）
-- memo（效能修整 E2）：鍵是 DB.overrideGen（覆寫與專精表的寫入出口，含 hidden）、C.buildGen（C.info／C.placed 換了）、
-- GetTime() 戳記（天賦條件 Blocked 的結果每幀重算）、這個專精的表本身（換專精／設定檔）。讀不到 GetTime ⇒ 不 memo。
-- ⚠ 回傳的 byA／byB **呼叫端不准改**（同一幀的其他呼叫拿到的是同一張；目前的呼叫端都只讀）。
-- 在掛勾的訊號路徑上（GroupTargets）也會叫，所以**不重建目錄**，只讀上次建好的 C.info／C.placed。
------------------------------------------------------------
local REPLACE_FROM = { essential = true, utility = true }
local REPLACE_TO   = "buffs"
C.REPLACE_FROM, C.REPLACE_TO = REPLACE_FROM, REPLACE_TO

-- 回傳 byA（A → B）、byB（B → A）
local replMemo = { og = -1 }
local BuildReplacements
function C.Replacements()
    local now = _G.GetTime and _G.GetTime() or nil
    if now == nil then return BuildReplacements(SpellsTable()) end
    local sp = SpellsTable()
    local DB = ns.DB
    local og = DB and DB.overrideGen or 0
    local m = replMemo
    if m.at == now and m.og == og and m.bg == C.buildGen and m.sp == sp then
        return m.byA, m.byB
    end
    local byA, byB = BuildReplacements(sp)
    m.at, m.og, m.bg, m.sp, m.byA, m.byB = now, og, C.buildGen, sp, byA, byB
    return byA, byB
end

BuildReplacements = function(sp)
    local byA, byB = {}, {}
    local all = sp and type(sp.overrides) == "table" and sp.overrides
    if not all then return byA, byB end
    local hidden = type(sp.hidden) == "table" and sp.hidden or EMPTY
    local placed = type(C.placed) == "table" and C.placed or EMPTY
    local as = {}
    for a, o in pairs(all) do
        if type(a) == "number" and type(o) == "table" and type(o.replaceWith) == "number" then
            as[#as + 1] = a
        end
    end
    table.sort(as)
    for _, a in ipairs(as) do
        local b = all[a].replaceWith
        local ra, rb = C.info[a], C.info[b]
        if b ~= a and byB[b] == nil and placed[a] and placed[b] and not hidden[a]
            and not Blocked(sp, a) and not Blocked(sp, b)
            and ra and REPLACE_FROM[ra.bar] and rb and rb.bar == REPLACE_TO then
            byA[a], byB[b] = b, a
        end
    end
    return byA, byB
end

-- 某條暴雪檢視器自己的清單（還沒套我們的 order／groupOf／hidden，也還沒拿掉取代目標）；新表。
-- 設定頁「以增益取代」的候選用（被移除的、拉去別條的、已經被拿去取代的都要列得到）
function C.SourceIDs(src)
    EnsureBuilt()
    local out = {}
    for _, id in ipairs(C.lists[src] or EMPTY) do out[#out + 1] = id end
    return out
end

-- 被當成取代目標的 B 的集合（B → A）
function C.ReplacedSet()
    local _, byB = C.Replacements()
    return byB
end

-- A 現在設了、而且成立的取代目標（不成立回 nil）
function C.ReplaceTarget(a)
    if type(a) ~= "number" then return nil end
    local byA = C.Replacements()
    return byA[a]
end

-- 這一格要不要改放 B（純函式；Bars 的 Relayout 叫）：
--   b ＝ { item = B 有沒有框, free = 還沒被別條認領, shown = 顯示中（讀不到當顯示）, active = IsActive 的值 }
-- active 只認明文 true：秘密值、nil、讀不到一律當沒生效 ⇒ 顯示 A（副本戰鬥中可能整場都是 A）
function C.ReplaceNow(b)
    if type(b) ~= "table" or not b.item or not b.free or not b.shown then return false end
    local v = b.active
    if v == nil or (ns.IsSecret and ns.IsSecret(v)) then return false end
    return v == true
end

-- 條的有序清單（已套 order／groupOf／hidden；**還沒套溢出**）。回傳的是新表，呼叫端可以自由改。
-- withHidden = true 時多回一張「本來在這條、但被藏起來」的清單（設定頁的預覽排在尾端用），
-- 同樣照 order 排。
function C.BarBase(barKey, withHidden)
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
    -- 以增益取代的 B：它的位置是 A 那一格（Core/Bars.lua），任何一條都不列、被移除清單也不列
    local replaced = C.ReplacedSet()

    -- 天賦條件不成立：正式清單不收；設定頁（withHidden）照樣收進第一張，預覽畫暗（C.TalentBlocked）
    local function Allowed(id)
        return withHidden or not Blocked(sp, id)
    end

    local function Add(id)
        if autoHide and autoHide(id) then return end
        if replaced[id] ~= nil then return end
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

    -- 自訂項目（圖示類、長條類的條都收：放在長條上時 Modules/Custom.lua 換成長條框）。三層合併後的
    -- 生效清單（戰隊 → 職業 → 專精；被窄層蓋掉的、這個角色用不到的不在裡面）。
    -- hidden 對它無效：自己加的項目「移除」就是整筆刪掉，沒有「藏著」這種狀態
    for _, it in ipairs(Effective()) do
        local e = it.entry
        if ValidCustom(e) and e.bar == barKey then
            if Allowed(it.id) then out[#out + 1] = it.id end
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

------------------------------------------------------------
-- 格數上限＋溢出到別條（規則在 Core/Overflow.lua）
--
-- C.Bar(key) ＝ C.BarBase(key) 套溢出：來源條截掉最後幾顆、接收條尾端接上溢來的。
-- withHidden（設定頁）照舊只回 base——預覽自己用 C.OverflowStatic() 畫記號與溢來的格。
--
-- 佔位判斷（occ）由 Core/Bars.lua 在每輪 Flush 建好索引之後交進來（C.SetOccupancy）：收合中不在的增益、
-- 暴雪沒給框的不算顆數。沒交（離線測試、引擎還沒起來）⇒ 每一顆都算。
--
-- memo：一輪 Flush 算一次。鍵 ＝ GetTime() 戳記＋Bars.flushes＋DB.overrideGen（order／groupOf／hidden 的寫入出口）
-- ＋DB.customGen＋C.buildGen＋occ 的代號（Bars 每輪換一張索引表）＋設定檔表＋這個專精的表。
-- 上限／目標本身是條層設定：寫入之後設定頁一定 ApplyEngine → RequestAll → 下一輪 Flush（flushes 換了）。
-- 讀不到 GetTime（離線測試）⇒ 不 memo。⚠ 回傳的表**呼叫端不准改**（C.Bar 回的是複本）。
------------------------------------------------------------
local occFn, occToken = nil, nil
function C.SetOccupancy(fn, token)
    occFn, occToken = fn, token
end

local function BarKeys()
    local p = ns.profile
    local bars = p and type(p.bars) == "table" and p.bars
    if not bars then return EMPTY end
    local keys, seen = {}, {}
    for _, k in ipairs(type(p.barOrder) == "table" and p.barOrder or EMPTY) do
        if type(bars[k]) == "table" and not seen[k] then seen[k] = true; keys[#keys + 1] = k end
    end
    local rest = {}
    for k, b in pairs(bars) do
        if type(b) == "table" and not seen[k] then rest[#rest + 1] = k end
    end
    table.sort(rest, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(rest) do keys[#keys + 1] = k end
    return keys
end
C.BarKeys = BarKeys

local function CfgOf(k)
    local p = ns.profile
    local bars = p and type(p.bars) == "table" and p.bars
    local b = bars and bars[k]
    return type(b) == "table" and b or nil
end
C.BarCfgOf = CfgOf

local function BaseOf(k) return (C.BarBase(k)) end

local function ResolveOverflow(occ)
    local O = ns.Overflow
    if not O then return nil end
    return O.Resolve(BarKeys(), BaseOf, CfgOf, occ)
end

local ovMemo = { flushes = -1 }
function C.Overflow()
    local now = _G.GetTime and _G.GetTime() or nil
    if now == nil then return ResolveOverflow(occFn) end
    local DB = ns.DB
    local m = ovMemo
    local fl = ns.Bars and ns.Bars.flushes or 0
    local og, cg = DB and DB.overrideGen or 0, DB and DB.customGen or 0
    local prof, sp = ns.profile, SpellsTable()
    if m.at == now and m.flushes == fl and m.og == og and m.cg == cg and m.bg == C.buildGen
        and m.occ == occToken and m.prof == prof and m.sp == sp then
        return m.res
    end
    local res = ResolveOverflow(occFn)
    m.at, m.flushes, m.og, m.cg, m.bg, m.occ, m.prof, m.sp, m.res = now, fl, og, cg, C.buildGen, occToken, prof, sp, res
    return res
end

-- 設定頁：每一顆都算顆數（預覽每格都畫），不 memo
function C.OverflowStatic()
    return ResolveOverflow(nil)
end

function C.Bar(barKey, withHidden)
    if withHidden then return C.BarBase(barKey, true) end
    local res = C.Overflow()
    local list = res and res.out[barKey]
    if not list then return C.BarBase(barKey) end
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    return out, nil
end

-- 成立的溢出對（只看設定，不算清單）：{ { src, dst }… } 或 nil
function C.OverflowPairs()
    local O = ns.Overflow
    if not O then return nil end
    return O.Pairs(BarKeys(), CfgOf)
end

-- 從暴雪某條檢視器拉法術出去的條（本專精 groupOf 指到、而且真的存在的條），加進 out[key] = true。
-- Bars.RequestSource 用：那條檢視器有動靜時，只有這些條（跟來源條自己）的清單可能變。
-- 在掛勾的訊號路徑上叫，**不重建目錄**（只讀上次建好的 C.info）；讀不到來源的 id 一律算進去。
-- 以增益取代：B 在這條檢視器上 ⇒ A 所在的條也算（B 生效／結束時 A 那一格要換人）。
-- A 所在的條 ＝ groupOf[A] 指到、而且存在的群組；否則來源是 A 那條檢視器的條。
function C.GroupTargets(sourceKey, out)
    out = out or {}
    local sp = SpellsTable()
    local groupOf = sp and type(sp.groupOf) == "table" and sp.groupOf or EMPTY
    local bars = ns.profile and ns.profile.bars
    if type(bars) ~= "table" then return out end
    for id, g in pairs(groupOf) do
        if g ~= sourceKey and type(bars[g]) == "table" and not out[g] then
            local rec = C.info[id]
            if not rec or rec.bar == nil or rec.bar == sourceKey then out[g] = true end
        end
    end
    local byA = C.Replacements()
    for a, b in pairs(byA) do
        local rb = C.info[b]
        if not rb or rb.bar == nil or rb.bar == sourceKey then
            local g = groupOf[a]
            if g ~= nil and type(bars[g]) == "table" then
                out[g] = true
            else
                local ra = C.info[a]
                local src = ra and ra.bar
                for key, bar in pairs(bars) do
                    if type(bar) == "table" and src ~= nil and bar.source == src then out[key] = true end
                end
            end
        end
    end
    -- 溢出：來源條會受影響（它自己、它的 source 是這條檢視器、或上面已經算進去）⇒ 接收條也要重排
    -- （溢出去的那幾顆跟著來源條的清單變；Flush 只放掉「這一輪要排的條」的認領）。排在取代那一段後面：
    -- A 在來源條、B 生效時 A 那一格可能在接收條上
    local ov = C.OverflowPairs()
    if ov then
        for _, pr in ipairs(ov) do
            local sb = bars[pr.src]
            if out[pr.src] or pr.src == sourceKey or (type(sb) == "table" and sb.source == sourceKey) then
                out[pr.dst] = true
            end
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
-- 診斷（/mcdm debug）：某幾條暴雪檢視器的每個 id 最後落在哪條、沒落地的話是哪一關擋掉的。
-- 「暴雪面板加了、我們這邊不顯示」的回報靠這段定位，關卡順序照 Build → BarBase → 溢出：
--   有效類別（分類覆寫 > HideByDefault > 資料類別）→ isKnown → 隱形項目 →
--   征戰聖擊列自動藏 → 以增益取代 → groupOf → 玩家移除（hidden）→ 天賦條件
-- 有效類別是「不顯示」、而且沒有分類覆寫的（暴雪預設就不顯示、玩家也沒拖過）大多是無關的法術，
-- 只收成一行 id 清單，不逐筆展開。回傳行（不帶色碼）。
------------------------------------------------------------
function C.Explain(sources)
    EnsureBuilt()
    local want = {}
    for _, k in ipairs(sources) do want[k] = true end
    local catName = {}
    local E = Enum and Enum.CooldownViewerCategory
    for name, v in pairs(E or EMPTY) do catName[v] = name end
    local function Cat(v)
        if v == HIDDEN then return "不顯示" end
        return v ~= nil and (catName[v] or tostring(v)) or "?"
    end

    -- 最後落在哪幾條（已套溢出）
    local where = {}
    local p = ns.profile
    local bars = p and type(p.bars) == "table" and p.bars or EMPTY
    local function BarName(k)
        local b = bars[k]
        return (type(b) == "table" and type(b.name) == "string" and b.name ~= "") and (k .. "「" .. b.name .. "」") or tostring(k)
    end
    for _, k in ipairs(BarKeys()) do
        for _, id in ipairs(C.Bar(k)) do
            where[id] = where[id] and (where[id] .. "," .. BarName(k)) or BarName(k)
        end
    end

    local sp = SpellsTable()
    local groupOf = sp and type(sp.groupOf) == "table" and sp.groupOf or EMPTY
    local hidden  = sp and type(sp.hidden) == "table" and sp.hidden or EMPTY
    local autoHide = ns.Resources and ns.Resources.HidesTrackedBar
    local replacedBy = C.ReplacedSet()
    local ov = C.Overflow and C.Overflow()
    local ovFrom = {}
    for dst, m in pairs(ov and ov.from or EMPTY) do
        for id, src in pairs(m) do ovFrom[id] = tostring(src) .. "→" .. tostring(dst) end
    end
    local hideInvisible = _G.CDM_HIDE_INVISIBLE_ITEMS == true
    local layoutOv = C.layoutOverrides or EMPTY

    local out, quiet = {}, {}
    for _, id in ipairs(C.ordered) do
        local rec = C.info[id]
        if rec and (want[rec.home] or want[rec.bar]) then
            local eff = rec.effectiveCategory
            if eff == HIDDEN and layoutOv[id] == nil then
                quiet[#quiet + 1] = tostring(id)
            else
                local why
                if where[id] then
                    why = "在 " .. where[id] .. (ovFrom[id] and ("（溢出 " .. ovFrom[id] .. "）") or "")
                elseif not rec.bar then
                    why = (eff == HIDDEN) and "暴雪面板放在「不顯示」" or "有效類別不屬於四條檢視器（還在候選池）"
                elseif not rec.isKnown then
                    why = "暴雪回報沒學會（isKnown=false）"
                elseif hideInvisible and rec.isInvisible then
                    why = "隱形項目（CDM_HIDE_INVISIBLE_ITEMS）"
                elseif autoHide and autoHide(id) then
                    why = "資源條的征戰聖擊列顯示中，自動藏起"
                elseif replacedBy[id] ~= nil then
                    why = "被 " .. tostring(replacedBy[id]) .. " 拿去取代"
                elseif hidden[id] then
                    why = "玩家在本插件移除（hidden）"
                elseif Blocked(sp, id) then
                    why = "天賦條件不成立"
                else
                    why = "原因不明"
                end
                -- BarBase 先分條（groupOf）再過上面那幾關：拉去別條的另外註明，原因照樣是上面那個
                local g = groupOf[id]
                if not where[id] and rec.bar and g ~= nil and g ~= rec.bar then
                    why = "拉去 " .. BarName(g) .. (type(bars[g]) == "table" and "，" or "（那條不存在，留在原條），") .. why
                end
                out[#out + 1] = ("    %s %s %s(%s/%s/%s) 類別 %s→%s%s 學會=%s：%s"):format(
                    where[id] and "✓" or "✕", tostring(id), tostring(rec.name or "?"),
                    tostring(rec.spellID), tostring(rec.overrideSpellID), tostring(rec.overrideTooltipSpellID),
                    Cat(rec.category), Cat(eff), layoutOv[id] ~= nil and "（面板覆寫）" or "",
                    tostring(rec.isKnown), why)
            end
        end
    end
    if #quiet > 0 then
        out[#out + 1] = ("    暴雪預設不顯示、沒拖過的 %d 個：%s"):format(#quiet, table.concat(quiet, ","))
    end
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
            -- 裝備欄增益的快取作廢過：清單內容不一定變（CatalogChanged 不一定來），飾品欄的疊層要重放一次
            if C.slotBuffStale then
                C.slotBuffStale = false
                if ns.Bars and ns.Bars.RequestAll then ns.Bars.RequestAll("layout") end
            end
        end)
    end

    local E = ns.Events
    -- 裝備欄增益（C.SlotBuffIDs）的快取：作廢只清我們自己的表，可以在派送當下做；重排照樣走 Later
    E.Register("COOLDOWN_VIEWER_DATA_LOADED", "catalog", function() C.InvalidateSlotBuffs(); Later("data") end)
    E.Register("COOLDOWN_VIEWER_TABLE_HOTFIXED", "catalog", function() C.InvalidateSlotBuffs(); Later("hotfix") end)
    E.Register("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", "catalog", function() Later("override") end)
    E.Register("PLAYER_SPECIALIZATION_CHANGED", "catalog", function() Later("spec") end, "player")
    -- 學會／忘掉技能、換裝備：暴雪那邊也會重建清單（isKnown 會變）
    E.Register("SPELLS_CHANGED", "catalog", function() Later("spells") end)
    E.Register("PLAYER_EQUIPMENT_CHANGED", "catalog", function() C.InvalidateSlotBuffs(); Later("equipment") end)
    E.Register("TRAIT_CONFIG_UPDATED", "catalog", function() Later("talents") end)
    E.Register("PLAYER_TALENT_UPDATE", "catalog", function() Later("talents") end)
    E.Register("ACTIVE_TALENT_GROUP_CHANGED", "catalog", function() Later("talentgroup") end)
    -- 進場：讀取畫面期間 API 回的東西不一定是最後的樣子，進來之後再對一次
    E.Register("PLAYER_ENTERING_WORLD", "catalog", function() C.InvalidateSlotBuffs(); Later("world") end)

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
