------------------------------------------------------------
-- 常用預設：挑選器「常用預設」那一區的資料（純資料＋純函式，不碰任何 WoW 全域，離線可測）
--
--   ns.Presets.RACIALS     [種族 token] = { spellID, … }        UnitRace 的第二個回傳值（英文 token）
--   ns.Presets.DEFENSIVES  [職業 token] = { spellID, … }        整個職業一張，顯示時用「學了沒」過濾
--   ns.Presets.ITEMS       { { key, items = { 主, 替代, … } }, … } 一組一列；自訂物品帶 alts
--   ns.Presets.AURAS       { { key, ids = { … }, lead }, … }      一組一列；光環格帶多個法術
--   ns.Presets.CONTROLS    [職業 token] = { spellID, … }        斷法與控場，同 DEFENSIVES（整個職業一張，濾學了的）
--   ns.Presets.SELF_AURAS  { { key, ids, spec }, … }             個人增益（專精技能、賽季效果、套裝效果）；spec 有寫＝只給那個專精
--
--   Presets.Racials(raceFile, isKnown) / Presets.Defensives(classFile, isKnown)
--        → 過濾後的 spellID 清單（isKnown 由呼叫端注入）
--   Presets.SpellEntry(spellID, barKey) / ItemEntry(def, barKey) / AuraEntry(def, barKey, faction)
--        → 自訂項目的那一筆（Core/DB.lua 的 spells[spec].custom 形狀）
--   Presets.RacialEntry(barKey)                → 動態的種族技能那一筆（kind = "racial"，不帶 ID）
--   Presets.ResolveRacial(raceFile, isKnown)   → 這個種族學了的那個種族技能 ID（解不到 nil）
--   Presets.AuraIDs(def)   這一組的全部法術（「這個專精已經加過了沒」用）
--   Presets.Controls(classFile, isKnown)       → 同 Defensives
--   Presets.SelfAuras(specID)                  → 這個專精看得到的個人增益（沒寫 spec 的＋spec 對得上的）
--   Presets.IsRacial(id) / IsDefensive(id) / IsControl(id)  → 在不在那張表裡（不分種族職業；預覽格的角標用）
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
-- 每個種族的「第二個種族技能」（地精火箭彈幕、不死族食屍、狐狐人紮營／回營地、半龍人翱翔）排在尾巴：
-- ResolveRacial 照順序挑第一個學了的，主要那個人人都會，所以挑不到它們；收進來是給 IsRacial（預覽格的「種族」角標）認的
------------------------------------------------------------
P.RACIALS = {
    BloodElf           = { 25046, 28730, 50613, 69179, 80483, 129597, 155145, 202719, 232633 },
    DarkIronDwarf      = { 265221 },
    Dracthyr           = { 357214, 368970, 369536 },
    Draenei            = { 28880, 59542, 59543, 59544, 59545, 59547, 59548, 121093, 370626, 416250 },
    Dwarf              = { 20594 },
    EarthenDwarf       = { 436344 },
    Gnome              = { 20589 },
    Goblin             = { 69070, 69041 },
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
    Scourge            = { 7744, 20577 },
    Tauren             = { 20549 },
    Troll              = { 26297 },
    VoidElf            = { 256948 },
    Vulpera            = { 312411, 312370, 312372 },
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
    MAGE        = { 11426, 45438, 235313, 235450, 342245, 414658 },     -- 414658 深寒凝冰（天賦取代寒冰屏障）
    MONK        = { 115203 },
    PALADIN     = { 498, 642, 31850, 86659 },
    PRIEST      = { 586, 19236, 47585 },
    ROGUE       = { 1966, 5277, 31224, 185311 },
    SHAMAN      = { 108271 },
    WARLOCK     = { 104773, 108416 },
    WARRIOR     = { 871, 23920, 97462, 118038, 184364 },
}

------------------------------------------------------------
-- 斷法與控場（同防禦技能：職業的、各專精的攤平在一張，學不到的濾掉）
------------------------------------------------------------
P.CONTROLS = {
    DEATHKNIGHT = { 47528, 49576, 207167, 221562, 108199 },
    DEMONHUNTER = { 183752, 179057, 202137, 211881, 217832 },
    DRUID       = { 78675, 106839, 132469 },
    EVOKER      = { 351338, 358385 },
    HUNTER      = { 147362, 187707, 19577, 109248, 187650, 213691 },
    MAGE        = { 2139, 31661, 113724, 157980 },
    MONK        = { 116705, 115078, 116844, 119381 },
    PALADIN     = { 96231, 853, 20066, 115750 },
    PRIEST      = { 15487, 8122, 64044, 88625 },
    ROGUE       = { 1766, 408, 2094 },
    SHAMAN      = { 57994, 51490, 51514, 192058 },
    WARLOCK     = { 89766, 5484, 30283 },
    WARRIOR     = { 6552, 386071, 5246, 46968, 107570 },
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
    { key = "zealotry",        items = { 245900, 245901, 241296, 241297 } },   -- 狂熱藥水
    { key = "alluringNostrum", items = { 274765, 274766, 271889, 271890 } },   -- 誘人靈藥
    { key = "invisibility",    items = { 241302, 241303 } },                   -- 虛空遮蔽酊劑（隱形）
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
    { key = "rampantAbandon",  ids = { 1236998 } },
    { key = "zealotry",        ids = { 1238443 } },
    { key = "alluringNostrum", ids = { 1295015 } },
    { key = "invisibility",    ids = { 1236551 } },                        -- 虛空籠罩
}

------------------------------------------------------------
-- 個人增益：一組＝一格光環格（增益），跟團隊增益同一個形狀，多一個 spec（專精 ID；沒寫＝每個專精都列）。
-- ⚠ 賽季效果與套裝效果的 ID 照 YUI_Halo 的表收（它自己標「候選」），wowhead 只對得到名字，
--   掛在身上的增益是不是同一個 ID 還沒實機驗證（README「常用預設」）；套裝每季換一批
------------------------------------------------------------
P.SELF_AURAS = {
    { key = "dawnlight",        ids = { 431522 },  spec = 70 },     -- 黎明之光（懲戒：自己身上那層，不是目標的效果）
    { key = "windAwoken",       ids = { 1263318 } },                -- 賽季效果：風之甦醒
    { key = "alnscornedEssence", ids = { 1266687 } },               -- 賽季效果：Alnscorned Essence
    -- 套裝效果
    { key = "tierBloodDebt",    ids = { 1310372 }, spec = 250 },
    { key = "tierRelentless",   ids = { 1300369 }, spec = 250 },
    { key = "tierFreezing",     ids = { 1297365 }, spec = 251 },
    { key = "tierAkilzon",      ids = { 1301768 }, spec = 102 },
    { key = "tierHalazzi",      ids = { 1301600 }, spec = 103 },
    { key = "tierMagnified",    ids = { 1297728 }, spec = 1473 },
    { key = "tierCobraFang",    ids = { 1299389 }, spec = 253 },
    { key = "tierCumulative",   ids = { 1296930 }, spec = 62 },
    { key = "tierRefreezing",   ids = { 1310248 }, spec = 64 },
    { key = "tierFlowing",      ids = { 1300219 }, spec = 262 },
    { key = "tierOvercharge",   ids = { 1300222 }, spec = 262 },
    { key = "tierShortCircuit", ids = { 1299991 }, spec = 263 },
    { key = "tierWindingUp",    ids = { 1300670 }, spec = 71 },
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

-- 預覽格的角標（Options/Preview.lua）：這個法術在不在種族／防禦表裡（整張表攤平，不分種族職業；第一次問才建）
local racialSet, defensiveSet
local function SetOf(byKey)
    local set = {}
    for _, ids in pairs(byKey) do
        for _, id in ipairs(ids) do set[id] = true end
    end
    return set
end

function P.IsRacial(spellID)
    racialSet = racialSet or SetOf(P.RACIALS)
    return spellID ~= nil and racialSet[spellID] == true
end

function P.IsDefensive(spellID)
    defensiveSet = defensiveSet or SetOf(P.DEFENSIVES)
    return spellID ~= nil and defensiveSet[spellID] == true
end

local controlSet
function P.IsControl(spellID)
    controlSet = controlSet or SetOf(P.CONTROLS)
    return spellID ~= nil and controlSet[spellID] == true
end

function P.Controls(classFile, isKnown)
    if type(classFile) ~= "string" then return {} end
    return Filter(P.CONTROLS[classFile], isKnown)
end

function P.SelfAuras(specID)
    local out = {}
    for _, def in ipairs(P.SELF_AURAS) do
        if def.spec == nil or def.spec == specID then out[#out + 1] = def end
    end
    return out
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
