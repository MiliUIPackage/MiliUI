------------------------------------------------------------
-- Modules/Timers.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Timers_test.lua
--
-- 覆蓋：純函式——Duration（有沒有自然和諧 × 三個專精、沒列的專精走 fallback）、OnTrigger（第一次、50ms 內的重複、
-- 跑到一半再觸發要重新起算）、Remaining／Active、Snapshot／Restore（正常、已經過期、剩餘比秒數還長、存檔壞掉）；
-- 遊戲裡那半（事件、存檔、到期）用 stub 跑一輪：讀回存檔、進場抑制、天賦沒點不起算、秘密參數只記數、
-- 重新起算寫存檔、舊的到期回呼看世代號作廢、到期清存檔並通知。
-- 載進自己的環境表：這支測試一個全域都不寫。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Modules/Timers.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then passed = passed + 1 else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

local function Load(env, ns)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(PATH)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(PATH, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end

------------------------------------------------------------
-- 1. 純函式（沒有任何 WoW 全域也載得起來）
------------------------------------------------------------
local ns = {}
Load(setmetatable({}, { __index = _G }), ns)
local TM = ns.Timers
local ng = TM.Def("naturesGuardian")
check("定義：自然守護者", ng ~= nil and ng.class == "SHAMAN")
eq("定義：天賦 30884", ng.talent, 30884)
eq("定義：45 秒", ng.secs, 45)
check("定義：觸發認 31616（治療效果），不認天賦本身", TM.IsTrigger(ng, 31616, nil) and not TM.IsTrigger(ng, 30884, 30884))
check("定義：觸發也認 baseSpellID", TM.IsTrigger(ng, 999, 31616))
eq("Def：不認得 ⇒ nil", TM.Def("nope"), nil)
eq("Def：不是字串 ⇒ nil", TM.Def(nil), nil)
eq("DefsFor：薩滿一個", #TM.DefsFor("SHAMAN"), 1)
eq("DefsFor：別的職業空", #TM.DefsFor("PALADIN"), 0)

-- Duration：自然和諧 × 專精
eq("沒有自然和諧：45", TM.Duration(ng, false, 262), 45)
eq("自然和諧讀不到（nil）：45", TM.Duration(ng, nil, 264), 45)
eq("元素＋自然和諧：35", TM.Duration(ng, true, 262), 35)
eq("恢復＋自然和諧：30", TM.Duration(ng, true, 264), 30)
eq("增強＋自然和諧（沒列）：走 fallback 35", TM.Duration(ng, true, 263), 35)
eq("專精讀不到＋自然和諧：fallback 35", TM.Duration(ng, true, nil), 35)
eq("沒有 reduce 的定義：原秒數", TM.Duration({ secs = 20 }, true, 262), 20)
eq("縮過頭（資料寫錯）：退回原秒數", TM.Duration({ secs = 5, reduce = { fallback = 10 } }, true, 1), 5)

-- OnTrigger／Remaining／Active
local st = TM.New()
eq("新狀態：剩 0", TM.Remaining(st, 10), 0)
check("新狀態：不在冷卻", not TM.Active(st, 10))
check("第一次觸發：變了", TM.OnTrigger(st, ng, 10, 45))
eq("起點", st.s, 10)
eq("秒數", st.d, 45)
check("50ms 內的重複：不算", not TM.OnTrigger(st, ng, 10.04, 45))
eq("重複沒動到起點", st.s, 10)
eq("剩餘", TM.Remaining(st, 20), 35)
check("冷卻中", TM.Active(st, 20))
check("跑到一半又觸發：重新起算", TM.OnTrigger(st, ng, 30, 30))
eq("重新起算：起點換了", st.s, 30)
eq("重新起算：秒數照這一次的", st.d, 30)
eq("重新起算：剩餘從頭算（不是延長）", TM.Remaining(st, 31), 29)
eq("到期：剩 0", TM.Remaining(st, 60), 0)
check("到期：不在冷卻", not TM.Active(st, 60))
local st2 = TM.New()
TM.OnTrigger(st2, ng, 5, nil)
eq("沒給秒數 ⇒ 定義的秒數", st2.d, 45)
TM.Reset(st2)
check("Reset：清空", st2.s == nil and st2.d == nil)
eq("Remaining 收 nil 狀態", TM.Remaining(nil, 1), 0)

-- Snapshot／Restore
eq("Snapshot：沒在跑 ⇒ nil", TM.Snapshot(TM.New()), nil)
local snap = TM.Snapshot(st)
check("Snapshot：起點與秒數", snap and snap.s == 30 and snap.d == 30)
check("Snapshot：是新表（不跟狀態共用）", snap ~= st)
local r = TM.New()
check("Restore：正常讀回", TM.Restore(r, { s = 100, d = 45 }, 120, ng))
check("Restore：值讀進來", r.s == 100 and r.d == 45)
eq("Restore：剩餘", TM.Remaining(r, 120), 25)
check("Restore：已經過期 ⇒ 丟掉", not TM.Restore(r, { s = 100, d = 45 }, 146, ng) and r.s == nil)
check("Restore：剛好到期 ⇒ 丟掉", not TM.Restore(r, { s = 100, d = 45 }, 145, ng))
check("Restore：起點在現在之後（重開機 GetTime 歸零）⇒ 丟掉", not TM.Restore(r, { s = 5000, d = 45 }, 30, ng) and r.s == nil)
check("Restore：秒數比定義長 ⇒ 丟掉", not TM.Restore(r, { s = 100, d = 90 }, 101, ng))
check("Restore：不是表 ⇒ 丟掉", not TM.Restore(r, "x", 100, ng))
check("Restore：nil ⇒ 丟掉", not TM.Restore(r, nil, 100, ng))
check("Restore：欄位壞掉 ⇒ 丟掉", not TM.Restore(r, { s = "a", d = 45 }, 100, ng))
check("Restore：秒數 0 ⇒ 丟掉", not TM.Restore(r, { s = 100, d = 0 }, 100, ng))
TM.OnTrigger(r, ng, 1, 45)
TM.Restore(r, nil, 2, ng)
check("Restore 失敗也會清掉舊狀態", r.s == nil)

------------------------------------------------------------
-- 2. 遊戲裡那半：事件、存檔、到期（stub）
------------------------------------------------------------
do
    local now = 100
    local timers = {}
    local SECRET = {}
    local CHAR = "米利 - 世界之樹"
    local env = setmetatable({
        GetTime = function() return now end,
        InCombatLockdown = function() return false end,
        C_Timer = { After = function(d, fn) timers[#timers + 1] = { at = now + d, fn = fn } end },
        MiliUI_CooldownManager_DB = { timers = { [CHAR] = { naturesGuardian = { s = 95, d = 45 }, gone = { s = 1, d = 1 } } } },
    }, { __index = _G })
    env._G = env
    local handlers, callbacks, changed = {}, {}, {}
    local talents = { [30884] = true, [443442] = true }
    local g = {
        playerClass = "SHAMAN", specID = 264,
        IsSecret = function(v) return v == SECRET end,
        Events = { Register = function(ev, key, fn) handlers[ev] = fn end },
        RegisterCallback = function(ev, key, fn) callbacks[ev] = fn end,
        Catalog = { TalentKnown = function(id) return talents[id] end },
        DB = { CharKey = function() return CHAR end },
        Custom = { TimerChanged = function(key) changed[#changed + 1] = key end },
        ReportError = function(err) print("ReportError: " .. tostring(err)) end,
    }
    Load(env, g)
    local T = g.Timers
    check("載入時掛 Loaded 回呼（不在檔案層就註冊事件）", callbacks.Loaded ~= nil and handlers.SPELL_UPDATE_COOLDOWN == nil)
    callbacks.Loaded()
    check("Init：註冊冷卻事件", handlers.SPELL_UPDATE_COOLDOWN ~= nil)
    check("Init：註冊進場事件", handlers.PLAYER_ENTERING_WORLD ~= nil)
    check("Init：天賦事件也聽（重判問號格）", handlers.TRAIT_CONFIG_UPDATED ~= nil)
    check("Init：換專精重判", callbacks.SpecChanged ~= nil)
    local s, d = T.State("naturesGuardian")
    check("讀回存檔：接著倒數", s == 95 and d == 45)
    eq("讀回存檔：通知格子", changed[1], "naturesGuardian")
    eq("讀回存檔：排了到期", #timers, 1)
    eq("讀回存檔：不認得的 key 原樣留著（不屬於這個職業的定義不碰）",
        env.MiliUI_CooldownManager_DB.timers[CHAR].gone ~= nil, true)

    -- 進場抑制：登入（Init）後 2 秒內的觸發不算
    now = 101
    handlers.SPELL_UPDATE_COOLDOWN(31616, 31616)
    eq("進場抑制：不起算", (T.State("naturesGuardian")), 95)
    eq("進場抑制：記數", T.probe.suppressed, 1)
    eq("進場抑制：明文觸發照記", T.probe.plain.idle, 1)

    -- 秘密參數：只記數就走
    handlers.SPELL_UPDATE_COOLDOWN(SECRET, nil)
    eq("秘密參數：記數", T.probe.secret.idle, 1)

    -- 正式觸發（恢復＋自然和諧 ⇒ 30 秒）：冷卻中又觸發 ⇒ 重新起算
    now = 103
    local before = #changed
    handlers.SPELL_UPDATE_COOLDOWN(31616, nil)
    s, d = T.State("naturesGuardian")
    check("觸發：重新起算 30 秒", s == 103 and d == 30)
    eq("觸發：通知格子", changed[before + 1], "naturesGuardian")
    local saved = env.MiliUI_CooldownManager_DB.timers[CHAR].naturesGuardian
    check("觸發：寫存檔", saved and saved.s == 103 and saved.d == 30)
    eq("觸發：最近起算記一筆", #T.probe.starts, 1)
    now = 103.02
    handlers.SPELL_UPDATE_COOLDOWN(31616, nil)
    eq("50ms 內的重複：不重算", (T.State("naturesGuardian")), 103)
    handlers.SPELL_UPDATE_COOLDOWN(12345, nil)
    eq("別的法術：不理", (T.State("naturesGuardian")), 103)

    -- 天賦沒點：不起算
    talents[30884] = false
    now = 110
    handlers.SPELL_UPDATE_COOLDOWN(31616, nil)
    eq("天賦沒點：不起算", (T.State("naturesGuardian")), 103)
    eq("TalentKnown：問天賦本身", T.TalentKnown("naturesGuardian"), false)
    talents[30884] = true

    -- 到期：讀回存檔時排的那個回呼世代號舊了 ⇒ 什麼都不做；新的那個清狀態、清存檔、通知
    now = 133.1
    before = #changed
    for _, t in ipairs(timers) do if t.at <= now then t.fn() end end
    eq("到期：狀態清掉", T.State("naturesGuardian"), nil)
    eq("到期：存檔清掉", env.MiliUI_CooldownManager_DB.timers[CHAR].naturesGuardian, nil)
    eq("到期：通知一次（舊的回呼作廢）", #changed - before, 1)

    -- 回呼早到（計時器精度）：再排一次，不清
    now = 200
    handlers.SPELL_UPDATE_COOLDOWN(31616, nil)
    local n = #timers
    now = 229                                      -- 還剩 1 秒時回呼跑了
    timers[n].fn()
    check("早到：狀態還在", T.State("naturesGuardian") == 200)
    eq("早到：再排一次", #timers, n + 1)

    -- 進場（讀取畫面）：不清狀態、只開抑制
    handlers.PLAYER_ENTERING_WORLD()
    check("讀取畫面：不清", T.State("naturesGuardian") == 200)
    now = 229.5
    handlers.SPELL_UPDATE_COOLDOWN(31616, nil)
    eq("讀取畫面後 2 秒內：抑制", (T.State("naturesGuardian")), 200)

    -- 探針報告跑得起來
    local lines = T.ProbeReport()
    check("探針報告：有內容", type(lines) == "table" and #lines > 5)
end

print(("Timers_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
