------------------------------------------------------------
-- 距離判定
--
-- 沒有「這個單位離我幾碼」的 API，只能反推：拿一個已知射程的東西去問
-- 「打得到嗎」。我們只需要布林（超出距離就淡出），所以不必像那些要顯示實際
-- 碼數的實作那樣去建整座法術／道具階梯再二分逼近——一顆探針技能就夠。
--
-- 三條路，由便宜到貴：
--   1. 自己          永遠在範圍內，不用問
--   2. 隊伍內的友方  UnitInRange 直接給答案（C 端算，最便宜）
--   3. 其他          用職業探針技能問 C_Spell.IsSpellInRange
--
-- 判不出來一律回 nil ＝「當作在範圍內」。失敗方向朝「不要淡出」：把看得到的
-- 東西誤淡掉，比偶爾漏淡一次糟糕得多。
------------------------------------------------------------
local _, ns = ...

ns.Range = {}
local Range = ns.Range

local CLASS = ns.playerClass
local IsSpellInRange = C_Spell and C_Spell.IsSpellInRange
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo

------------------------------------------------------------
-- 探針技能
--
-- ⚠ 每個職業給**一串候選**，不是單一 ID。原因：
--   1. 同一個技能在不同專精是不同 spell ID（薩滿的閃電箭元素／增強就不同號）
--   2. 有些技能只有某個專精有（死騎的凋零纏繞只有邪惡、法師的寒冰箭只有冰法）
--   3. 英雄天賦會替換技能
-- 取第一顆「真的學過」的。全部沒學過就回 nil ＝ 不判定 ＝ 不淡出。
--
-- ⚠⚠ 判斷學沒學過**不能**用 GetSpellInfo：那個對任何有效 ID 都回得出資料，
--    跟你會不會無關。指派到一顆沒學過的技能，IsSpellInRange 會一路回 false，
--    症狀是「距離內卻一直顯示超出距離」（實際踩過）。
------------------------------------------------------------
local HARM = {
    DEATHKNIGHT = { 47541, 49576 },          -- 凋零纏繞（邪惡）／死亡之握
    DEMONHUNTER = { 185123 },                -- 投擲利刃
    DRUID       = { 5176 },                  -- 憤怒
    EVOKER      = { 362969 },                -- 碧藍打擊
    HUNTER      = { 75, 186270 },            -- 自動射擊／猛禽一擊（生存近戰）
    MAGE        = { 116, 133, 30451 },       -- 寒冰箭／火球術／秘法飛彈
    MONK        = { 117952 },                -- 碎玉閃電
    PALADIN     = { 20271 },                 -- 審判
    PRIEST      = { 589 },                   -- 暗言術：痛
    ROGUE       = { 1752, 193315, 53, 1329 },-- 影襲／劈斬／背刺／殘殺（都是近戰距離）
    SHAMAN      = { 188196, 187837, 403 },   -- 閃電箭：元素／增強／基礎
    WARLOCK     = { 234153, 686 },           -- 吸取生命／暗影箭
    WARRIOR     = { 355 },                   -- 嘲諷（30 碼，全專精）
}

------------------------------------------------------------
-- 近戰專精的探針
--
-- 上面那張表對近戰職業太遠：戰士拿的是嘲諷（30 碼），所以要跑到 30 碼外框才會淡出
-- —— 而近戰真正在意的是「我打得到嗎」＝ 5 碼。這個資訊對近戰幾乎等於沒有。
--
-- ⚠ 碼數**不是我憑印象寫的**。標 LRC 的來自本機 Platynator 內嵌的
-- LibRangeCheck-3.0（那個函式庫的全部工作就是維護「哪個技能幾碼」，而且跟著改版更新），
-- 其餘標明出處。**查不到可靠來源的職業就留空**，寧可維持現狀，也不要塞一顆碼數是
-- 腦補的技能 —— 那會變成「明明在範圍內卻一直顯示超出」，而且沒有任何錯誤訊息。
--
-- 沒列的兩個職業是刻意的：
--   ROGUE        上面的 HARM 清單（影襲／劈斬／背刺／殘殺）本來就是近戰距離
--   其餘遠程職業 本來就該用遠距離探針
------------------------------------------------------------
local MELEE_HARM = {
    DRUID       = { 22568 },        -- 凶猛撕咬（近戰）　　　　　LRC
    MONK        = { 100780 },       -- 猛虎掌（近戰）　　　　　　LRC
    PALADIN     = { 35395, 853 },   -- 十字軍打擊（近戰）／制裁之錘 10 碼　LRC
    SHAMAN      = { 73899 },        -- 原始打擊（近戰）　　　　　LRC
    WARRIOR     = { 5246 },         -- 懾服怒吼 8 碼　LRC（武器／狂怒才有，防護會退回嘲諷）
    DEMONHUNTER = { 183752 },       -- 汲取魔法 20 碼　LRC（比投擲利刃的 30 碼近）
    HUNTER      = { 186270 },       -- 猛禽一擊（近戰，生存專精）　本檔 HARM 既有項
    DEATHKNIGHT = { 47528 },        -- 心靈凍結（近戰）　Core/Interrupt.lua 已在用的 ID
}

-- 近戰專精。資源條那邊（Elements/ClassPower.lua）已經有一張 specID 表，
-- 這裡同樣用 specID —— 職業層級判斷不了（同一個職業有近戰也有遠程專精）。
local MELEE_SPECS = {
    [71] = true, [72] = true, [73] = true,              -- 戰士 武器／狂怒／防護
    [66] = true, [70] = true,                           -- 聖騎 防護／懲戒（神聖是遠程治療）
    [255] = true,                                       -- 獵人 生存
    [259] = true, [260] = true, [261] = true,           -- 盜賊 全部
    [250] = true, [251] = true, [252] = true,           -- 死騎 全部
    [263] = true,                                       -- 薩滿 增強
    [268] = true, [269] = true,                         -- 武僧 釀酒／踏風（織霧是遠程治療）
    [103] = true, [104] = true,                         -- 德魯伊 野性／守護
    [577] = true, [581] = true, [1480] = true,          -- 惡魔獵人 全部
}

local HELP = {
    DRUID   = { 8936 },      -- 愈合
    EVOKER  = { 355913 },    -- 翡翠之花
    MAGE    = { 1459 },      -- 秘法智慧
    MONK    = { 116670 },    -- 活血術
    PALADIN = { 19750 },     -- 聖光閃現
    PRIEST  = { 2061 },      -- 快速治療
    SHAMAN  = { 8004 },      -- 治療之湧
    WARLOCK = { 5697 },      -- 無盡呼吸
    -- 純近戰職業沒有友方技能可用 → 退回 UnitInRange（只對隊伍成員有效）
}

local harmSpell, helpSpell, meleeSpell, built

-- ⚠⚠ `IsPlayerSpell` 在 **11.2.0 就被移除了**（wiki 明載），這裡原本第一個問的就是它
-- ——那條分支早就是死碼，整個判斷實際上只靠第二個 `IsSpellKnownOrOverridesKnown`
-- （還在，但已標記淘汰）。真的哪天連它也拿掉，探針會全部解不出來，而失敗是靜默的：
-- 超出距離淡出直接不動作，沒有任何錯誤。
--
-- 12.x 正解是 C_SpellBook（本機的 Plumber 就寫 `local IsPlayerSpell = C_SpellBook.IsSpellKnown`，
-- Platynator 與我們自己的 MiliUI/Enhance/FocuserCastBar 用 IsSpellKnownOrInSpellBook）：
--   IsSpellKnownOrInSpellBook  法術書裡的 ＋ 被天賦替換掉的
--   IsSpellKnown               專精授予的
-- 兩個都問過才回 false；舊全域留在最後當備援。
local CSB = C_SpellBook

local function Known(id)
    if CSB then
        if CSB.IsSpellKnownOrInSpellBook and CSB.IsSpellKnownOrInSpellBook(id) then return true end
        if CSB.IsSpellKnown and CSB.IsSpellKnown(id) then return true end
    end
    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id) then return true end
    return false
end

local function FirstKnown(list)
    if not list then return nil end
    for _, id in ipairs(list) do
        if Known(id) then return id end
    end
    return nil
end

-- 專精／天賦換了會影響學沒學到，所以重算。
-- 第一次查詢時才建，不靠 PLAYER_LOGIN——那樣就不必管檔案載入順序。
-- 目前是不是近戰專精。查不到專精（登入初期、或 API 換過）一律回 false ＝ 走遠程探針，
-- 也就是改動前的行為。
local function IsMeleeSpec()
    local CSI = C_SpecializationInfo
    local idx = (CSI and CSI.GetSpecialization and CSI.GetSpecialization())
        or (GetSpecialization and GetSpecialization())
    if not idx then return false end
    local id = (CSI and CSI.GetSpecializationInfo and CSI.GetSpecializationInfo(idx))
        or (GetSpecializationInfo and GetSpecializationInfo(idx))
    return id ~= nil and MELEE_SPECS[id] == true
end

local function Rebuild()
    harmSpell = FirstKnown(HARM[CLASS])
    helpSpell = FirstKnown(HELP[CLASS])
    meleeSpell = IsMeleeSpec() and FirstKnown(MELEE_HARM[CLASS]) or nil
    built = true
end

-- 給 /muf debug 看：淡出沒反應、或近戰的淡出距離不對時，先確認這幾顆解出來是什麼。
-- melee=nil 有三種可能：不是近戰專精、這個職業沒列近戰探針、列了但這個專精沒學到。
function Range.Probes()
    if not built then Rebuild() end
    return harmSpell, helpSpell, meleeSpell
end

ns.Events.Register("PLAYER_SPECIALIZATION_CHANGED", "range", Rebuild)
ns.Events.Register("PLAYER_TALENT_UPDATE", "range_talent", Rebuild)
ns.Events.Register("SPELLS_CHANGED", "range_spells", Rebuild)

------------------------------------------------------------
-- 查詢
--
-- 同一幀（甚至同一個 metro tick）內會有多個呼叫端問同一個單位，探針不便宜，
-- 所以帶一個極短命的快取。TTL 比輪詢間隔短一點就好，不需要精確。
------------------------------------------------------------
local cache, cacheTime = {}, 0
local TTL = 0.2

-- ⚠ 這個檔問的每一個 API 在受限內容裡都可能回**秘密布林**，而秘密布林不能做
-- 布林測試（連 `v and true or false` 都算）——會直接拋 taint error。
-- 所有回傳一律先過這裡：明文才給答案，秘密與 nil 都回 nil ＝「不判定」。
local function PlainBool(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v and true or false
end

local function Probe(unit)
    if not built then Rebuild() end
    -- token 比對是我們自己的明文字串，先擋掉最常見的情況，連 API 都不用問
    if unit == "player" or unit == "vehicle" then return true end
    if PlainBool(UnitIsUnit(unit, "player")) then return true end

    local canAttack = ns.ToBool(UnitCanAttack("player", unit))

    -- 近戰專精先問近戰探針。答得出來就是答案（那才是「我打得到嗎」）。
    -- ⚠ 答不出來（技能有施放條件、或這個 build 不吃這顆）就往下走一般探針 ——
    -- 失敗方向朝「維持改動前的行為」，不會變成永遠不淡出或永遠淡出。
    if canAttack and meleeSpell and IsSpellInRange then
        local r = PlainBool(IsSpellInRange(meleeSpell, unit))
        if r ~= nil then return r end
    end

    local spell = canAttack and harmSpell or helpSpell
    if spell and IsSpellInRange then
        local r = PlainBool(IsSpellInRange(spell, unit))
        if r ~= nil then return r end
    end

    -- 沒有可用探針時的備援（近戰職業看友方框就是這種情況）。
    -- ⚠ 只對友方用：UnitInRange 是為隊伍成員設計的，對其他單位第二個回傳
    --   不可靠，拿它判敵人會得到錯的答案。
    if not canAttack then
        local inRange, checked = UnitInRange(unit)
        if PlainBool(checked) then return PlainBool(inRange) end
    end
    return nil
end

-- true = 在範圍內、false = 超出、nil = 判不出來
function Range.Check(unit)
    if not unit or not UnitExists(unit) then return nil end
    local now = GetTime()
    if now - cacheTime > TTL then
        wipe(cache)
        cacheTime = now
    end
    local v = cache[unit]
    if v == nil then
        v = Probe(unit)
        cache[unit] = (v == nil) and "?" or v      -- nil 不能當 table 值，用哨兵記住「問過了」
    end
    if v == "?" then return nil end
    return v
end

-- 「確定超出距離」才回 true（判不出來不算）——呼叫端要的是「該不該變淡」
function Range.IsOut(unit)
    return Range.Check(unit) == false
end
