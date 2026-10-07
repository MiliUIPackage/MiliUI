------------------------------------------------------------
-- 依施放推算每一層的倒數（目前只有鐵鬃）
--
-- 鐵鬃每施放一次是獨立的一層、各自倒數；遊戲把它們併成一顆光環＋層數，每一層的時間插件讀不到（秘密值）。
-- **層數照用引擎寫的**（資源條的 auraBar，永遠對）；這裡只算「每一層還剩多久」，畫成每格上的暗色遮罩
--（Modules/Resources.lua 的 RenderCastTimers）。兩邊對不起來時（例如天賦讓一次施放多疊一層）：
-- 多出來的那層沒有遮罩、整格亮著；推算多出來的遮罩落在沒亮的格子上（暗上加暗，看不出來）——不會畫錯層數。
--
-- 時間：基礎 7 秒，學了 Ursoc's Endurance（393611）是 9 秒；Guardian of Elune（155578）：搗擊（33917）之後
-- 15 秒內的下一發鐵鬃 +3 秒，狂暴恢復（22842）會把它用掉。死亡、換型態清空。
--
--   CS.OnSpellcast(spellID, now)   UNIT_SPELLCAST_SUCCEEDED（player）；回傳 true ＝ 這一層的清單變了
--   CS.Reset()                     死亡、換型態
--   CS.Sorted(now, out)            還沒到期的層，剩餘時間由長到短（第 1 格＝最晚到期；最後一個亮著的格子最先到期）
--   CS.NextExpiry(now)             最近一個到期的時間（排下一次重畫）；沒有 ⇒ nil
--
-- 純邏輯：時間從參數進來、天賦查詢可以換（CS.known），離線測得到。
------------------------------------------------------------
local _, ns = ...

ns.CastStacks = {}
local CS = ns.CastStacks

CS.IRONFUR = 192081
local URSOCS_ENDURANCE = 393611
local GUARDIAN_OF_ELUNE = 155578
local MANGLE = 33917
local FRENZIED_REGEN = 22842
local BASE, LONG, GOE_BONUS, GOE_WINDOW = 7, 9, 3, 15
local MAX_ENTRIES = 30          -- 防呆：清單不無限長（正常不會超過 10）

local entries = {}              -- { start, dur, expire }
local goeUntil = 0              -- Guardian of Elune：這個時間之前的下一發鐵鬃 +3 秒
CS.entries = entries

-- 天賦查詢（測試換掉）
function CS.known(id)
    local fn = C_SpellBook and C_SpellBook.IsSpellKnown
    if not fn then return false end
    local ok, v = pcall(fn, id)
    if not ok or (ns.IsSecret and ns.IsSecret(v)) then return false end
    return v and true or false
end

local function Prune(now)
    local w = 1
    for r = 1, #entries do
        local e = entries[r]
        if e.expire > now then
            entries[w] = e
            w = w + 1
        end
    end
    for i = #entries, w, -1 do entries[i] = nil end
end

function CS.Reset()
    for i = #entries, 1, -1 do entries[i] = nil end
    goeUntil = 0
end

function CS.OnSpellcast(spellID, now)
    if type(spellID) ~= "number" or (ns.IsSecret and ns.IsSecret(spellID)) then return false end
    now = now or GetTime()
    if spellID == MANGLE then
        if CS.known(GUARDIAN_OF_ELUNE) then goeUntil = now + GOE_WINDOW end
        return false
    end
    if spellID == FRENZIED_REGEN then
        goeUntil = 0
        return false
    end
    if spellID ~= CS.IRONFUR then return false end
    Prune(now)
    local dur = CS.known(URSOCS_ENDURANCE) and LONG or BASE
    if now < goeUntil then
        dur = dur + GOE_BONUS
        goeUntil = 0
    end
    if #entries >= MAX_ENTRIES then table.remove(entries, 1) end
    entries[#entries + 1] = { start = now, dur = dur, expire = now + dur }
    return true
end

local function ByRemaining(a, b) return a.expire > b.expire end

function CS.Sorted(now, out)
    out = out or {}
    for i = #out, 1, -1 do out[i] = nil end
    Prune(now or GetTime())
    for i = 1, #entries do out[i] = entries[i] end
    table.sort(out, ByRemaining)
    return out
end

function CS.NextExpiry(now)
    Prune(now or GetTime())
    local nearest
    for i = 1, #entries do
        local t = entries[i].expire
        if not nearest or t < nearest then nearest = t end
    end
    return nearest
end
