------------------------------------------------------------
-- Modules/EchoWindow.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/EchoWindow_test.lua
--
-- 覆蓋：沸點的狀態機——觸發開一段、重複事件不重開、發光亮起排下一段（重複 SHOW 不重排）、
-- 時間到接續或結束、接續那一刻的回聲事件不重開、Reset、Remaining、IsTrigger 認 base。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Modules/EchoWindow.lua"

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

local ns = {}
assert(loadfile(PATH))("MiliUI_CooldownManager", ns)
local EW = ns.EchoWindow
local def = EW.DEFS[1]
eq("沸點：血液沸騰", def.spell, 50842)
eq("沸點：3 秒", def.secs, 3)
check("認 spellID", EW.IsTrigger(def, 1265982, nil))
check("認 baseSpellID", EW.IsTrigger(def, 999, 1265982))
check("別的不認", not EW.IsTrigger(def, 50842, 50842))

local st = EW.New()
check("觸發：開一段", EW.OnTrigger(st, def, 10))
eq("開始時間", st.startAt, 10)
eq("結束時間", st.endAt, 13)
check("同一次的重複事件不重開", not EW.OnTrigger(st, def, 10.02))
eq("剩餘", EW.Remaining(st, 11.5), 1.5)
check("時間還沒到：沒變", not EW.Tick(st, def, 12.9))

-- 沒有排下一段：時間到結束
check("時間到：變了", EW.Tick(st, def, 13.01))
check("時間到：結束", not st.active)
eq("結束後剩餘 0", EW.Remaining(st, 13.5), 0)

-- 進行中又觸發強化（發光亮起）⇒ 這段結束接下一段
st = EW.New()
EW.OnTrigger(st, def, 20)
EW.OnGlow(st, true)
check("發光亮起：排下一段", st.pending)
EW.OnGlow(st, false)
EW.OnGlow(st, true)
check("熄了再亮仍然只排一段", st.pending)
check("時間到：接續", EW.Tick(st, def, 23.02))
check("接續：還在進行", st.active)
eq("接續：從上一段結束算起", st.startAt, 23)
eq("接續：結束時間", st.endAt, 26)
check("接續：排程用掉", not st.pending)
check("接續那一刻的回聲事件不重開", not EW.OnTrigger(st, def, 23.1))
eq("回聲事件沒動到開始時間", st.startAt, 23)
check("過了確認窗口的新觸發照開", EW.OnTrigger(st, def, 24))
eq("新觸發：重算", st.endAt, 27)

-- 排了下一段但 Tick 太晚（超過整整一段）⇒ 不接續、直接結束
st = EW.New()
EW.OnTrigger(st, def, 30)
EW.OnGlow(st, true)
EW.OnGlow(st, false)   -- 熄掉
check("太晚：結束", EW.Tick(st, def, 37) and not st.active)

-- 沒在進行時發光亮起：不排
st = EW.New()
EW.OnGlow(st, true)
check("閒置時發光不排程", not st.pending)
check("重複 SHOW 不算亮起", (function() EW.OnTrigger(st, def, 40); EW.OnGlow(st, true); return not st.pending end)())

EW.Reset(st)
check("Reset：全清", not st.active and not st.pending and not st.glowOn and st.endAt == 0)

-- 探針行數上限
for i = 1, 40 do EW.ProbeLine("x" .. i) end
eq("探針最多 30 行", #EW.probe.lines, 30)

print(("EchoWindow_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
