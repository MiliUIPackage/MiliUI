------------------------------------------------------------
-- 戰鬥藥水視窗：喝下戰鬥藥水那一刻起自己計時，暴雪的「戰鬥藥水」增益格沒生效時由我們代畫（Core/Bars.lua、Modules/Custom.lua）
--
-- 為什麼要自己來：暴雪冷卻管理器的戰鬥藥水增益格（物品冷卻類別 4，Catalog 的 SPELL_CATEGORY[4]）**不知道你喝的是哪一瓶**。
--   * 那一格的 spellID 只在 OnCooldownIDSet → RefreshSpellCategoryData → C_Spell.GetLastCategoryCooldownSource(4) 那一刻取得
--     （Blizzard_CooldownViewer/CooldownViewerItemData.lua）。
--   * 增益檢視器（圖示／長條）不註冊 SPELL_UPDATE_COOLDOWN ⇒ 喝下去之後沒有路徑去更新那一格的 spellID；
--     只有整條檢視器重建、或之後某次順手的刷新才會補上。
--   * 實機 2026-10-20（關掉本插件、原版暴雪）：流光藥劑 30 秒，那一格前 23 秒整格不出現（IsActive=false、spellID nil，
--     類別來源早就是流光），脫戰幾秒後才補上、只亮最後 7 秒；戰鬥中類別來源是秘密值。
--   * 插件不能替暴雪重建：叫它的檢視器或資料提供者，整套更新會跑在插件的污染堆疊裡，戰鬥中碰到秘密值就炸（Core/Catalog.lua 檔頭）。
-- 所以照同類插件的做法：收 UNIT_SPELLCAST_SUCCEEDED（player）的 spellID，對上戰鬥藥水就從施放那一刻起算固定秒數
-- （.claude/notes/wow-121-duration-objects.md 的「施放後固定秒數」：起點與秒數都是我們自己的明文數字，任何場合都能畫）。
-- 暴雪那一格自己生效了照舊放暴雪的 item（Core/Bars.lua 判），我們只補它沒生效的那段。
--
-- 規則（刻意簡單：沒有存檔、不讀光環、不猜新藥水）：
--   * 認哪些：Presets.ITEMS 裡不在 ITEM_NO_BUFF（治療／法力藥水、治療石）、也不在 ITEM_NOT_COMBAT（隱形）的組 →
--     同 key 的 Presets.AURAS[].ids。施放事件帶的就是增益 ID（流光藥劑 1295132 實機對過）。每季換藥水改 Presets 就好。
--   * 秒數：Presets.AURAS 那一組的 secs，沒寫＝30。
--   * 同一時間一個視窗（戰鬥藥水共用冷卻）：新的一瓶直接取代、重新起算；50ms 內同一個法術重複派送不算。
--   * 收掉：到期（一個 C_Timer.After(剩餘 + 0.05)＋世代號，不輪詢）、死亡。
--     已知限制：喝到一半 /reload 那一瓶不再代畫（暴雪那格自己補上就照暴雪的）；戰鬥中被取消照計時跑完。
--   * 視窗開、關、換瓶 ⇒ Custom.PotionChanged（代畫格標髒）＋ Bars.RequestAll("membership")（一場一兩次）。
--   * 事件處理器只收參數、下一幀做（施放事件可能在按鍵的 secure 流程裡同步派送；
--     .claude/notes/wow-121-addon-code-in-secure-stack.md）。秘密的 spellID 當場丟掉（只記次數）。
--
-- 純函式（離線可測）：
--   PW.BuildCandidates(P)            → spellID → { key, secs }
--   PW.New() / PW.Reset(st) / PW.Open(st, spellID, now, secs) → true ＝ 狀態變了（重複派送 false）
--   PW.Remaining(st, now) / PW.ActiveAt(st, now)
-- 遊戲裡（檔尾）：
--   PW.State()         → spellID, start, dur（沒有視窗 nil）；Modules/Custom.lua 的 UpdatePotion 讀
--   PW.Active([now])   → 現在有沒有視窗（Core/Bars.lua 的 B.PotionProxyHere 問）
--   PW.DebugLine()     → /mcdm debug 的那一行（字串不進語系檔）
------------------------------------------------------------
local _, ns = ...

ns.PotionWindow = {}
local PW = ns.PotionWindow

PW.DEFAULT_SECS = 30
local DUP_WINDOW = 0.05         -- 同一次施放引擎有時連派兩次（Timers／EchoWindow 同款）

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
local EMPTY = {}

function PW.BuildCandidates(P)
    local cand = {}
    if type(P) ~= "table" or type(P.ITEMS) ~= "table" then return cand end
    local noBuff = type(P.ITEM_NO_BUFF) == "table" and P.ITEM_NO_BUFF or EMPTY
    local notCombat = type(P.ITEM_NOT_COMBAT) == "table" and P.ITEM_NOT_COMBAT or EMPTY
    local combat = {}
    for _, def in ipairs(P.ITEMS) do
        local key = type(def) == "table" and def.key
        if type(key) == "string" and not noBuff[key] and not notCombat[key] then combat[key] = true end
    end
    for _, a in ipairs(type(P.AURAS) == "table" and P.AURAS or EMPTY) do
        if type(a) == "table" and combat[a.key] and type(a.ids) == "table" then
            local secs = type(a.secs) == "number" and a.secs > 0 and a.secs or PW.DEFAULT_SECS
            for _, id in ipairs(a.ids) do
                if type(id) == "number" and cand[id] == nil then cand[id] = { key = a.key, secs = secs } end
            end
        end
    end
    return cand
end

function PW.New() return {} end

function PW.Reset(st) st.id, st.s, st.d = nil, nil, nil end

function PW.Open(st, spellID, now, secs)
    if st.id == spellID and st.s and now >= st.s and now - st.s < DUP_WINDOW then return false end
    -- 新的一瓶：直接取代、重新起算（戰鬥藥水共用冷卻，不會有兩個同時在跑）
    st.id, st.s, st.d = spellID, now, (type(secs) == "number" and secs > 0) and secs or PW.DEFAULT_SECS
    return true
end

function PW.Remaining(st, now)
    if not (st and st.s and st.d) then return 0 end
    local r = st.s + st.d - now
    return r > 0 and r or 0
end

function PW.ActiveAt(st, now) return PW.Remaining(st, now) > 0 end

------------------------------------------------------------
-- 遊戲裡：狀態、事件
------------------------------------------------------------
local st = PW.New()
local gen = 0                   -- 到期回呼的世代號
local cand = {}
PW.probe = { opened = 0, secret = 0, last = nil, closed = nil }

local function Now() return _G.GetTime and _G.GetTime() or 0 end
local function IsSecret(v) return ns.IsSecret ~= nil and ns.IsSecret(v) and true or false end

function PW.State()
    if not PW.ActiveAt(st, Now()) then return nil end
    return st.id, st.s, st.d
end

function PW.Active(now) return PW.ActiveAt(st, now or Now()) end

local function SpellName(id)
    local api = C_Spell and C_Spell.GetSpellName
    local ok, n = pcall(api or error, id)
    if ok and type(n) == "string" and not IsSecret(n) then return n end
    return "#" .. tostring(id)
end

local function Notify()
    local CU, B = ns.Custom, ns.Bars
    if CU and CU.PotionChanged then CU.PotionChanged() end
    if B and B.RequestAll then B.RequestAll("membership") end
end

local function Close(reason)
    if not st.id then return end
    gen = gen + 1
    PW.probe.closed = ("%.1f %s %s"):format(Now(), SpellName(st.id), reason)
    PW.Reset(st)
    Notify()
end

local function Schedule()
    gen = gen + 1
    local my = gen
    local rem = PW.Remaining(st, Now())
    if rem <= 0 or not (C_Timer and C_Timer.After) then return end
    C_Timer.After(rem + 0.05, function()
        if gen ~= my then return end
        if PW.ActiveAt(st, Now()) then Schedule() else Close("到期") end   -- 早到一點（計時器精度）就再排一次
    end)
end

local function OnCast(spellID, t)
    local c = cand[spellID]
    if not c then return end
    if PW.Open(st, spellID, t, c.secs) then
        PW.probe.opened = PW.probe.opened + 1
        PW.probe.last = ("%.1f %s(%d) %.0f 秒"):format(t, SpellName(spellID), spellID, st.d)
        Schedule()
        Notify()
    end
end

-- 施放事件：(unit, castGUID, spellID)，unit 已由 RegisterUnitEvent 綁 player。參數當場收好（秘密的丟掉），下一幀判
local function OnCastEvent(_, _, spellID)
    if ns.released then return end
    if IsSecret(spellID) then
        PW.probe.secret = PW.probe.secret + 1
        return
    end
    if type(spellID) ~= "number" or not cand[spellID] then return end
    ns.Defer(OnCast, spellID, Now())
end

local inited = false
function PW.Init()
    if inited then return end
    inited = true
    cand = PW.BuildCandidates(ns.Presets)
    local E = ns.Events
    if not (E and E.Register) then return end
    E.Register("UNIT_SPELLCAST_SUCCEEDED", "potion_window", OnCastEvent, "player")
    E.Register("PLAYER_DEAD", "potion_window", function() ns.Defer(Close, "死亡") end)
end

if ns.RegisterCallback then
    ns.RegisterCallback("Loaded", "potion_window", function() PW.Init() end)
end

-- /mcdm debug 的一行（字串不進語系檔，開發用）
function PW.DebugLine()
    local now = Now()
    local p = PW.probe
    local win = "沒有"
    if PW.ActiveAt(st, now) then
        win = ("%s(%d) 剩 %.1f／%.0f 秒"):format(SpellName(st.id), st.id, PW.Remaining(st, now), st.d)
    end
    local placed = 0
    local CU = ns.Custom
    if CU and CU.Records then
        for _, rec in pairs(CU.Records()) do
            if rec.kind == "potion" and rec.placedBar then placed = placed + 1 end
        end
    end
    local n = 0
    for _ in pairs(cand) do n = n + 1 end
    return ("  戰鬥藥水視窗：%s  代畫 %d 格  開過 %d 次  秘密 spellID %d 次  認得 %d 個法術  最近開：%s  最近收：%s")
        :format(win, placed, p.opened, p.secret, n, p.last or "—", p.closed or "—")
end
