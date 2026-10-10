------------------------------------------------------------
-- 常用預設：挑選器「常用預設」那一區的資料（純資料＋純函式，不碰任何 WoW 全域，離線可測）
--
--   ns.Presets.RACIALS     [種族 token] = { spellID, … }        UnitRace 的第二個回傳值（英文 token）
--   ns.Presets.DEFENSIVES  [職業 token] = { spellID, … }        整個職業一張，顯示時用「學了沒」過濾
--   ns.Presets.ITEMS       { { key, items = { 主, 替代, … } }, … } 一組一列；自訂物品帶 alts
--   ns.Presets.AURAS       { { key, ids = { … }, lead }, … }      一組一列；光環格帶多個法術
--
--   Presets.Racials(raceFile, isKnown) / Presets.Defensives(classFile, isKnown)
--        → 過濾後的 spellID 清單（isKnown 由呼叫端注入）
--   Presets.SpellEntry(spellID, barKey) / ItemEntry(def, barKey) / AuraEntry(def, barKey, faction)
--        → 自訂項目的那一筆（Core/DB.lua 的 spells[spec].custom 形狀）
--   Presets.RacialEntry(barKey)                → 動態的種族技能那一筆（kind = "racial"，不帶 ID）
--   Presets.ResolveRacial(raceFile, isKnown)   → 這個種族學了的那個種族技能 ID（解不到 nil）
--   Presets.AuraIDs(def)   這一組的全部法術（「這個專精已經加過了沒」用）
--
-- 名稱與圖示**不寫在這裡**，執行時問 C_Spell／C_Item（官方譯名、換季也跟著變）。
-- ⚠ 這幾張表每季／每次改版要對一次：藥水的物品與增益 ID 每季換一批；種族、防禦技能、
--   嗜血類增益改版時可能增減。每個 ID 收錄前至少兩個來源對過（README「常用預設」一節）。
------------------------------------------------------------
local _, ns = ...

ns.Presets = {}
local P = ns.Presets

------------------------------------------------------------
-- 種族技能（主動的那幾個；同一個種族技能依職業有多個 ID 的全部列上，顯示時只留學了的）
------------------------------------------------------------
P.RACIALS = {
    BloodElf           = { 25046, 28730, 50613, 69179, 80483, 129597, 155145, 202719, 232633 },
    DarkIronDwarf      = { 265221 },
    Dracthyr           = { 357214, 368970 },
    Draenei            = { 28880, 59542, 59543, 59544, 59545, 59547, 59548, 121093, 370626, 416250 },
    Dwarf              = { 20594 },
    EarthenDwarf       = { 436344 },
    Gnome              = { 20589 },
    Goblin             = { 69070 },
    Haranir            = { 1237885 },
    HighmountainTauren = { 255654 },
    Human              = { 59752 },
    KulTiran           = { 287712 },
    LightforgedDraenei = { 255647 },
    MagharOrc          = { 274738 },
    Mechagnome         = { 312924 },
    NightElf           = { 58984 },
    Nightborne         = { 260364 },
    Orc                = { 20572, 33697, 33702 },
    Pandaren           = { 107079 },
    Scourge            = { 7744 },
    Tauren             = { 20549 },
    Troll              = { 26297 },
    VoidElf            = { 256948 },
    Vulpera            = { 312411 },
    Worgen             = { 68992 },
    ZandalariTroll     = { 291944 },
}

------------------------------------------------------------
-- 防禦技能（職業的、各專精的全部攤平在一張；學不到的由呼叫端的「學了沒」濾掉）
------------------------------------------------------------
P.DEFENSIVES = {
    DEATHKNIGHT = { 48707, 48792, 49039, 51052, 55233 },
    DEMONHUNTER = { 196718, 198589, 204021 },
    DRUID       = { 22812, 61336, 102342 },
    EVOKER      = { 363916 },
    HUNTER      = { 109304, 186265, 264735 },
    MAGE        = { 11426, 45438, 235313, 235450, 342245 },
    MONK        = { 115203 },
    PALADIN     = { 498, 642, 31850, 86659 },
    PRIEST      = { 586, 19236, 47585 },
    ROGUE       = { 1966, 5277, 31224, 185311 },
    SHAMAN      = { 108271 },
    WARLOCK     = { 104773, 108416 },
    WARRIOR     = { 871, 23920, 97462, 118038, 184364 },
}

------------------------------------------------------------
-- 藥水與治療石：一組＝一格自訂物品，items[1] 是主（身分），其餘是替代品。
-- 格子每次照順序挑第一個包包裡有的（Modules/Custom.lua 的 PickItem）；短效的排前面先用掉。
------------------------------------------------------------
P.ITEMS = {
    { key = "healthPotion",    items = { 241304, 241305, 271884, 271883 } },
    { key = "healthstone",     items = { 5512, 224464 } },
    { key = "manaPotion",      items = { 245916, 245917, 241300, 241301 } },
    { key = "lightsPotential", items = { 245897, 245898, 241308, 241309 } },
    { key = "recklessness",    items = { 245902, 245903, 241288, 241289 } },
    { key = "rampantAbandon",  items = { 245910, 245911, 241292, 241293 } },
    { key = "liquidLuster",    items = { 274763, 274764, 271886, 271887 } },
}
-- 喝了身上不會有可追蹤增益的那幾組（治療／法力是立即回復）：藥水格不疊增益按鈕（Core/Catalog.lua 的 ItemUseBuffIDs）。
-- 其餘組照 AURAS 同 key 的增益 ID＋物品的使用法術（C_Item.GetItemSpell）
P.ITEM_NO_BUFF = { healthPotion = true, healthstone = true, manaPotion = true }

------------------------------------------------------------
-- 團隊增益：一組＝一格光環格（增益），ids 全部進 includeSpellIDs，引擎畫真實的增益與剩餘時間。
-- lead：依陣營換主 ID（名字與占位圖示用主的），沒寫就是 ids[1]
------------------------------------------------------------
P.AURAS = {
    { key = "bloodlust",
      ids = { 2825, 32182, 80353, 90355, 264667, 390386, 466904,          -- 職業的
              292686, 309658, 381301, 444257, 1243972 },                  -- 戰鼓
      lead = { Alliance = 32182 } },
    { key = "timeSpiral",
      ids = { 375234, 375226, 375229, 375230, 375238, 375240, 375252,
              375253, 375254, 375255, 375256, 375257, 375258 } },
    { key = "powerInfusion",   ids = { 10060 } },                         -- 灌注（牧師給的外部增益）
    { key = "innervate",       ids = { 29166 } },                         -- 激活（德魯伊給的外部增益）
    { key = "lightsPotential", ids = { 1236616 } },
    { key = "recklessness",    ids = { 1236994 } },
    { key = "liquidLuster",    ids = { 1295132 } },
}

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
local function Filter(list, isKnown)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, id in ipairs(list) do
        if type(isKnown) ~= "function" or isKnown(id) then out[#out + 1] = id end
    end
    return out
end

function P.Racials(raceFile, isKnown)
    if type(raceFile) ~= "string" then return {} end
    return Filter(P.RACIALS[raceFile], isKnown)
end

-- 種族技能（動態的那一筆 kind = "racial"，Core/DB.lua 的 CustomView）：這個種族學了的第一個 ID；
-- 一個都沒學（或種族不認得、不是字串）⇒ nil。isKnown 回 false 才算沒學（nil ＝ 讀不到，當學了）
function P.ResolveRacial(raceFile, isKnown)
    if type(raceFile) ~= "string" then return nil end
    local list = P.RACIALS[raceFile]
    if type(list) ~= "table" then return nil end
    for _, id in ipairs(list) do
        if type(isKnown) ~= "function" or isKnown(id) ~= false then return id end
    end
    return nil
end

-- 種族技能那一筆（不帶 spellID：每個角色登入時照自己的種族解析）
function P.RacialEntry(barKey)
    return { kind = "racial", bar = barKey }
end

function P.Defensives(classFile, isKnown)
    if type(classFile) ~= "string" then return {} end
    return Filter(P.DEFENSIVES[classFile], isKnown)
end

function P.SpellEntry(spellID, barKey)
    return { kind = "spell", spellID = spellID, bar = barKey }
end

function P.ItemEntry(def, barKey)
    local items = type(def) == "table" and def.items
    if type(items) ~= "table" or items[1] == nil then return nil end
    local e = { kind = "item", itemID = items[1], bar = barKey }
    if #items > 1 then
        e.alts = {}
        for i = 2, #items do e.alts[#e.alts + 1] = items[i] end
    end
    return e
end

-- 主 ID：照陣營挑（lead 裡有、而且真的在 ids 裡才算），否則 ids[1]
local function LeadOf(def, faction)
    local ids = def.ids
    local want = type(def.lead) == "table" and type(faction) == "string" and def.lead[faction] or nil
    if want ~= nil then
        for _, id in ipairs(ids) do
            if id == want then return want end
        end
    end
    return ids[1]
end

function P.AuraEntry(def, barKey, faction)
    local ids = type(def) == "table" and def.ids
    if type(ids) ~= "table" or ids[1] == nil then return nil end
    local main = LeadOf(def, faction)
    local e = { kind = "aura", spellID = main, filter = "HELPFUL", placeholder = true, bar = barKey }
    local rest = {}
    for _, id in ipairs(ids) do
        if id ~= main then rest[#rest + 1] = id end
    end
    if #rest > 0 then e.spellIDs = rest end
    return e
end

function P.AuraIDs(def)
    local out = {}
    for _, id in ipairs(type(def) == "table" and type(def.ids) == "table" and def.ids or {}) do out[#out + 1] = id end
    return out
end
