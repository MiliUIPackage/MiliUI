------------------------------------------------------------
-- 內建冷卻計時：暴雪不公開的內建冷卻（目前只有薩滿的自然守護者），自己用 GetTime() 計時，畫成一格自訂格（kind = "timer"）
--
-- 自然守護者（天賦 30884）：血量掉到 35% 以下自動補血，之後 45 秒不能再觸發。這段內建冷卻暴雪沒公開——
-- C_Spell.GetSpellCooldownDuration(30884／31616) 都拿不到東西，所以「追蹤法術冷卻」的自訂格畫不出來。
-- 遊戲只給**觸發訊號**：觸發那一刻 SPELL_UPDATE_COOLDOWN 的參數帶 31616（治療效果的 ID，不是天賦本身）。
-- 收到就從 GetTime() 起算固定秒數：起點與秒數都是我們自己的明文數字，畫圖、算術在任何場合都安全
-- （.claude/notes/wow-121-duration-objects.md 的「施放後固定秒數」那一條路；對外照實標示成「內建冷卻」）。
-- ⚠ 天賦本身的 ID（talent，掃有沒有點）跟觸發時事件帶的那顆（triggers）不一樣，兩個不能互換（同 EchoWindow）。
--
-- 規則：
--   * 50ms 內重複派送的事件不算新的一次；冷卻跑到一半又觸發 ⇒ **重新起算**（不是延長）。
--   * 進場抑制：PLAYER_ENTERING_WORLD 之後 2 秒內的觸發不算——讀取時暴雪會一次派一大串冷卻更新，會誤觸發。
--   * **不清除**：讀取畫面、死亡、換專精都不清。內建冷卻是角色身上的狀態，不會因為這些重置。
--     首領戰開始會不會重置還不知道（README《待實機驗證》），先不處理。
--   * 先知英雄天賦「自然和諧」縮短內建冷卻，縮多少看專精（元素 10、恢復 15；數字待實機驗）。觸發那一刻才問。
--   * 到期：一個 C_Timer.After(剩餘 + 0.05)＋世代號（舊的回呼看到世代號對不上就走），中間不輪詢；
--     冷卻圖本身由格子上的 Cooldown 框自己畫（Modules/Custom.lua 的 UpdateTimer），不需要 ticker。
--   * 存檔：MiliUI_CooldownManager_DB.timers[角色][key] = { s = 起點, d = 秒數 }。角色層、不在 profile：
--     跟 procdeck 一樣是追蹤狀態不是設定。PLAYER_LOGIN（"Loaded"）時讀回；GetTime() 在 /reload 之間連續，
--     重開機會歸零 ⇒ 存檔裡的起點變成「很久以後」，TM.Restore 擋掉（剩餘 ≤ 0 或 > 秒數就丟）。
--   * 起算、到期、天賦變了 ⇒ ns.Custom.TimerChanged(key)：只標那幾格髒，下一幀更新。
--
-- 純函式（時間從參數進來，離線可測）：
--   TM.DEFS                               每一種內建冷卻的資料（職業、天賦、圖示、觸發法術、秒數、縮短）
--   TM.Def(key) / TM.DefsFor(class)       查定義（不認得 nil／空表）
--   TM.Duration(def, reduceKnown, specID) 這一次的秒數（自然和諧點了 ⇒ 扣掉這個專精的量，沒列的專精走 fallback）
--   TM.IsTrigger(def, spellID, baseSpellID)
--   TM.New() / TM.Reset(st)
--   TM.OnTrigger(st, def, now, dur)       觸發 → true ＝ 狀態變了（重複事件 false）
--   TM.Remaining(st, now) / TM.Active(st, now)
--   TM.Snapshot(st) / TM.Restore(st, saved, now, def)
-- 遊戲裡（檔尾）：
--   TM.State(key)        → start, dur（沒在冷卻 nil）；Modules/Custom.lua 的 UpdateTimer 讀
--   TM.TalentKnown(key)  → true／false／nil（讀不到）
--   TM.ProbeReport()     → /mcdm timer 的探針（字串不進語系檔，開發用）
------------------------------------------------------------
local _, ns = ...

ns.Timers = {}
local TM = ns.Timers

TM.DEFS = {
    -- talent：天賦本身（30884，掃有沒有點、滑鼠提示）；icon：圖示與名字問哪個法術；
    -- triggers：觸發時 SPELL_UPDATE_COOLDOWN 帶的（31616，治療效果）
    { key = "naturesGuardian", class = "SHAMAN", talent = 30884, icon = 30884,
      triggers = { 31616 }, secs = 45,
      -- 先知英雄天賦「自然和諧」縮短內建冷卻，縮多少看專精（元素 262 ／恢復 264；增強沒有先知，走不到）
      reduce = { talent = 443442, bySpec = { [262] = 10, [264] = 15 }, fallback = 10 } },
}

local byKey = {}
for _, def in ipairs(TM.DEFS) do byKey[def.key] = def end

function TM.Def(key)
    if type(key) ~= "string" then return nil end
    return byKey[key]
end

function TM.DefsFor(class)
    local out = {}
    for _, def in ipairs(TM.DEFS) do
        if def.class == class then out[#out + 1] = def end
    end
    return out
end

function TM.Duration(def, reduceKnown, specID)
    local secs = def.secs
    local r = def.reduce
    if reduceKnown == true and type(r) == "table" then
        local cut = (type(r.bySpec) == "table" and specID ~= nil and r.bySpec[specID]) or r.fallback or 0
        -- 縮到零以下 ＝ 資料寫錯：退回原秒數，不要畫出一段負的冷卻
        if cut > 0 and cut < secs then secs = secs - cut end
    end
    return secs
end

function TM.IsTrigger(def, spellID, baseSpellID)
    for _, id in ipairs(def.triggers) do
        if spellID == id or baseSpellID == id then return true end
    end
    return false
end

-- 同一次觸發，引擎有時連派兩次事件：這麼近的不算新的一次（EchoWindow 的 DUP_WINDOW 同款）
local DUP_WINDOW = 0.05

function TM.New() return { s = nil, d = nil } end

function TM.Reset(st) st.s, st.d = nil, nil end

function TM.OnTrigger(st, def, now, dur)
    if st.s and now >= st.s and now - st.s < DUP_WINDOW then return false end
    -- 跑到一半又觸發：重新起算（內建冷卻從這一次觸發開始算，不是延長）
    st.s = now
    st.d = (type(dur) == "number" and dur > 0) and dur or def.secs
    return true
end

function TM.Remaining(st, now)
    if not (st and st.s and st.d) then return 0 end
    local r = st.s + st.d - now
    return r > 0 and r or 0
end

function TM.Active(st, now) return TM.Remaining(st, now) > 0 end

function TM.Snapshot(st)
    if not (st and st.s and st.d) then return nil end
    return { s = st.s, d = st.d }
end

-- 存檔讀回：形狀不對、已經過期、起點在「現在」之後或剩餘比定義的秒數還長（重開機 GetTime 歸零）⇒ 丟掉。
-- 回 true ＝ 讀回一段還在跑的冷卻
function TM.Restore(st, saved, now, def)
    TM.Reset(st)
    if type(saved) ~= "table" then return false end
    local s, d = saved.s, saved.d
    if type(s) ~= "number" or type(d) ~= "number" or d <= 0 or d > def.secs then return false end
    if s > now then return false end
    local rem = s + d - now
    if rem <= 0 or rem > def.secs then return false end
    st.s, st.d = s, d
    return true
end

------------------------------------------------------------
-- 探針：觸發參數是明文還是秘密、抑制掉幾次、最近幾次起算（/mcdm timer 印）
------------------------------------------------------------
local PROBE_LINES, PROBE_STARTS = 20, 5
TM.probe = { lines = {}, starts = {}, plain = { combat = 0, idle = 0 }, secret = { combat = 0, idle = 0 },
             suppressed = 0 }

local function InCombat()
    local f = _G.InCombatLockdown
    return f and f() and true or false
end

local function Now()
    return _G.GetTime and _G.GetTime() or 0
end

local function ProbeLine(text)
    local p = TM.probe
    p.lines[#p.lines + 1] = ("%.2f %s %s"):format(Now(), InCombat() and "戰鬥" or "脫戰", text)
    while #p.lines > PROBE_LINES do table.remove(p.lines, 1) end
end
TM.ProbeLine = ProbeLine

------------------------------------------------------------
-- 遊戲裡：狀態、存檔、事件
------------------------------------------------------------
local states = {}            -- key → 狀態
local gens = {}              -- key → 到期回呼的世代號
local classDefs = {}         -- 這個職業的定義（Init 時算一次：職業不會變）
local SUPPRESS_SECS = 2
local suppressUntil = 0

local function IsSecret(v) return ns.IsSecret ~= nil and ns.IsSecret(v) and true or false end

function TM.TalentKnown(key)
    local def = TM.Def(key)
    local C = ns.Catalog
    if not (def and C and C.TalentKnown) then return nil end
    return C.TalentKnown(def.talent)
end

-- 縮短內建冷卻的天賦點了沒（true／false／nil）。⚠ 不能寫成 a and f() or nil：false 會被吃成 nil
local function ReduceKnown(def)
    local r, C = def.reduce, ns.Catalog
    if not (type(r) == "table" and C and C.TalentKnown) then return nil end
    return C.TalentKnown(r.talent)
end

function TM.State(key)
    local st = states[key]
    if not (st and TM.Active(st, Now())) then return nil end
    return st.s, st.d
end

local function SaveTable(create)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" then return nil end
    if type(sv.timers) ~= "table" then
        if not create then return nil end
        sv.timers = {}
    end
    local key = ns.DB and ns.DB.CharKey and ns.DB.CharKey()
    if not key then return nil end
    local t = sv.timers[key]
    if type(t) ~= "table" then
        if not create then return nil end
        t = {}
        sv.timers[key] = t
    end
    return t
end

local function Save(def)
    local snap = TM.Snapshot(states[def.key])
    local t = SaveTable(snap ~= nil)
    if t then t[def.key] = snap end
end

local function Notify(key)
    local CU = ns.Custom
    if CU and CU.TimerChanged then CU.TimerChanged(key) end
end

local Schedule               -- 前置宣告（到期回呼裡要重排）

local function Expire(def)
    local st = states[def.key]
    if not (st and st.s) then return end
    if TM.Active(st, Now()) then
        -- 回呼早到了一點（計時器的精度）：再排一次
        Schedule(def)
        return
    end
    TM.Reset(st)
    Save(def)
    ProbeLine("到期 " .. def.key)
    Notify(def.key)
end

Schedule = function(def)
    local key = def.key
    gens[key] = (gens[key] or 0) + 1
    local my = gens[key]
    local rem = TM.Remaining(states[key], Now())
    if rem <= 0 or not (C_Timer and C_Timer.After) then return end
    C_Timer.After(rem + 0.05, function()
        if gens[key] ~= my then return end
        xpcall(Expire, ns.ReportError or print, def)
    end)
end

local function Load()
    local t = SaveTable(false)
    local now = Now()
    for _, def in ipairs(classDefs) do
        local st = states[def.key] or TM.New()
        states[def.key] = st
        local saved = t and t[def.key]
        if TM.Restore(st, saved, now, def) then
            ProbeLine(("讀回存檔 %s 剩 %.1f 秒"):format(def.key, TM.Remaining(st, now)))
            Schedule(def)
        elseif saved ~= nil then
            -- 過期、壞掉或重開機留下的：丟掉
            t[def.key] = nil
        end
        Notify(def.key)
    end
end

local function OnCooldown(spellID, baseSpellID)
    if IsSecret(spellID) or IsSecret(baseSpellID) then
        local p = TM.probe.secret
        if InCombat() then p.combat = p.combat + 1 else p.idle = p.idle + 1 end
        return
    end
    for _, def in ipairs(classDefs) do
        if TM.IsTrigger(def, spellID, baseSpellID) then
            local p = TM.probe.plain
            if InCombat() then p.combat = p.combat + 1 else p.idle = p.idle + 1 end
            local now = Now()
            local talent = TM.TalentKnown(def.key)
            if now < suppressUntil then
                TM.probe.suppressed = TM.probe.suppressed + 1
                ProbeLine(("觸發 %s（進場抑制，略過）"):format(def.key))
            elseif talent == false then
                ProbeLine(("觸發 %s（天賦沒點，略過）"):format(def.key))
            else
                local dur = TM.Duration(def, ReduceKnown(def), ns.specID)
                local st = states[def.key] or TM.New()
                states[def.key] = st
                local wasActive = TM.Active(st, now)
                if TM.OnTrigger(st, def, now, dur) then
                    local starts = TM.probe.starts
                    starts[#starts + 1] = ("%.2f %s %d 秒%s"):format(now, InCombat() and "戰鬥" or "脫戰", dur,
                        wasActive and "（冷卻中又觸發，重新起算）" or "")
                    while #starts > PROBE_STARTS do table.remove(starts, 1) end
                    ProbeLine(("起算 %s %d 秒 spellID=%s base=%s"):format(def.key, dur, tostring(spellID), tostring(baseSpellID)))
                    Save(def)
                    Schedule(def)
                    Notify(def.key)
                else
                    ProbeLine(("觸發 %s（重複，略過）"):format(def.key))
                end
            end
        end
    end
end

-- 天賦點了／點掉、換專精：格子要重判問號（UpdateTimer 讀天賦）。狀態不清
local function TalentsChanged()
    for _, def in ipairs(classDefs) do Notify(def.key) end
end

local inited = false
function TM.Init()
    if inited then return end
    inited = true
    classDefs = TM.DefsFor(ns.playerClass)
    -- 只有用得到的職業才聽（SPELL_UPDATE_COOLDOWN 很頻繁）。跟 EchoWindow 一樣不經過 SpellIndex：
    -- 要的是事件參數本身，不是重算格子
    if #classDefs == 0 or not (ns.Events and ns.Events.Register) then return end
    suppressUntil = Now() + SUPPRESS_SECS
    Load()
    local E = ns.Events
    E.Register("SPELL_UPDATE_COOLDOWN", "timers", function(spellID, baseSpellID)
        if ns.released then return end
        OnCooldown(spellID, baseSpellID)
    end)
    E.Register("PLAYER_ENTERING_WORLD", "timers", function() suppressUntil = Now() + SUPPRESS_SECS end)
    for _, ev in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE" }) do
        E.Register(ev, "timers", TalentsChanged)
    end
    if ns.RegisterCallback then ns.RegisterCallback("SpecChanged", "timers", TalentsChanged) end
end

-- DB.Init 之後（存檔才在）、引擎起來之前：讀回存檔、註冊事件
if ns.RegisterCallback then
    ns.RegisterCallback("Loaded", "timers", function() TM.Init() end)
end

-- /mcdm timer：探針結果（字串不進語系檔，開發用）
function TM.ProbeReport()
    local p = TM.probe
    local now = Now()
    local out = { ("[米利冷卻 timer] 職業=%s 專精=%s 這個職業的內建冷卻=%d 個")
        :format(tostring(ns.playerClass), tostring(ns.specID), #classDefs) }
    for _, def in ipairs(classDefs) do
        local r = def.reduce
        local reduceKnown = ReduceKnown(def)
        out[#out + 1] = ("  %s：天賦 %d=%s  縮短天賦 %s=%s  現在觸發的秒數=%d  剩 %.1f 秒")
            :format(def.key, def.talent, tostring(TM.TalentKnown(def.key)), tostring(r and r.talent or "—"),
                tostring(reduceKnown), TM.Duration(def, reduceKnown, ns.specID), TM.Remaining(states[def.key], now))
    end
    out[#out + 1] = ("  觸發參數是明文：戰鬥中 %d 次、脫戰 %d 次"):format(p.plain.combat, p.plain.idle)
    out[#out + 1] = ("  SPELL_UPDATE_COOLDOWN 參數是秘密值（不分法術）：戰鬥中 %d 次、脫戰 %d 次"):format(p.secret.combat, p.secret.idle)
    out[#out + 1] = ("  進場抑制掉的觸發：%d 次"):format(p.suppressed)
    if p.plain.combat == 0 and p.secret.combat > 0 then
        out[#out + 1] = "  ⚠ 戰鬥中沒看到明文的觸發、但有秘密參數 ⇒ 觸發參數戰鬥中可能是秘密值"
    end
    out[#out + 1] = "  最近起算："
    if #p.starts == 0 then out[#out + 1] = "    （還沒有）" end
    for _, line in ipairs(p.starts) do out[#out + 1] = "    " .. line end
    out[#out + 1] = "  最近的事件："
    if #p.lines == 0 then out[#out + 1] = "    （還沒有）" end
    for _, line in ipairs(p.lines) do out[#out + 1] = "    " .. line end
    return out
end
