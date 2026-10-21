------------------------------------------------------------
-- Modules/ProcDeck.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/ProcDeck_test.lua
--
-- 覆蓋：定義表、超幾何機率（含翻完這疊接下一疊）、FormatChance、狀態機（翻牌、視窗內外、同幀重複、觸發先到、
-- 硬讀略過、翻過尾端的觸發算舊的那疊、漂移與重新信任、昇華凍結、Reset）、State／Text／RowText、存檔讀回、
-- 設定解析、Plan、氣漩武器偵測（獲得／花掉／到期／讀不到當 10／花光又疊回／昇華 15 秒／末日之風期間的近戰花費者）。
-- 也檢查前半沒有呼叫任何 WoW API（只靠純 Lua 就載得起來）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Modules/ProcDeck.lua"

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
local function near(name, got, want, eps)
    check(name, math.abs(got - want) <= (eps or 1e-6), "got " .. tostring(got) .. ", want " .. tostring(want))
end

-- 沒有任何遊戲全域：載入只會跑到前半的定義與檔尾的 function 宣告（Init 不叫）
local ns = {}
assert(loadfile(PATH))("MiliUI_CooldownManager", ns)
local PD = ns.ProcDeck
local MSW = PD.MSW

------------------------------------------------------------
-- 1. 定義表
------------------------------------------------------------
local T, DW, SU, DRE = PD.Def("tempest"), PD.Def("doomwinds"), PD.Def("stormunleashed"), PD.Def("dre")
eq("四個牌堆", #PD.DEFS, 4)
eq("順序：暴風雨第一", PD.DEFS[1].key, "tempest")
eq("暴風雨 100 張", T.size, 100)
eq("暴風雨 2 個觸發", T.procs, 2)
eq("暴風雨天賦 454009", T.talent, 454009)
eq("末日之風 600／3", DW.size .. "/" .. DW.procs, "600/3")
eq("風暴釋放 250／5", SU.size .. "/" .. SU.procs, "250/5")
eq("深根元素 333／2", DRE.size .. "/" .. DRE.procs, "333/2")
check("末日之風昇華凍結", DW.freezeInAscendance == true)
check("暴風雨不凍結", not T.freezeInAscendance)
eq("末日之風硬讀 0.5 秒", DW.hardcastWindow, 0.5)
eq("風暴釋放格子退回雷擊", SU.cells[2], 187874)
check("深根元素認兩個訊號", PD.IsTrigger(DRE, 114051, nil) and PD.IsTrigger(DRE, 378270, nil))
check("認 baseSpellID", PD.IsTrigger(T, 1, 454015))
check("別的不認", not PD.IsTrigger(T, 452201, 452201))
eq("增強薩四個", #PD.DefsFor("SHAMAN", 263), 4)
eq("元素薩沒有", #PD.DefsFor("SHAMAN", 262), 0)
eq("別的職業沒有", #PD.DefsFor("MAGE", 263), 0)

------------------------------------------------------------
-- 2. 機率
------------------------------------------------------------
local function C(n, k)
    local r = 1
    for i = 1, k do r = r * (n - k + i) / i end
    return r
end
near("滿牌暴風雨花 10 層 ＝ 1 − C(98,10)/C(100,10)", PD.Chance(100, 2, 0, 0, 10), (1 - C(98, 10) / C(100, 10)) * 100, 1e-9)
near("滿牌暴風雨花 10 層 ≈ 19.1%", PD.Chance(100, 2, 0, 0, 10), 19.09, 0.01)
near("滿牌末日之風花 10 層 ≈ 4.9%", PD.Chance(600, 3, 0, 0, 10), 4.92, 0.01)
eq("滿牌末日之風印 4.9%", PD.FormatChance(PD.Chance(600, 3, 0, 0, 10)), "4.9%")
eq("滿牌暴風雨印 19%", PD.FormatChance(PD.Chance(100, 2, 0, 0, 10)), "19%")
eq("N−K < P ⇒ 100%", PD.Chance(100, 2, 90, 0, 9), 100)
eq("剩 3 張還有 1 個觸發、花 10 層 ⇒ 100%", PD.Chance(100, 2, 97, 1, 10), 100)
near("剩 3 張 0 個觸發、花 10 層 ⇒ 新牌堆翻 7 張", PD.Chance(100, 2, 97, 2, 10), PD.Chance(100, 2, 0, 0, 7), 1e-9)
near("新牌堆翻 7 張 ＝ 1 − C(98,7)/C(100,7)", PD.Chance(100, 2, 0, 0, 7), (1 - C(98, 7) / C(100, 7)) * 100, 1e-9)
eq("觸發用完、這疊還夠 ⇒ 0", PD.Chance(100, 2, 50, 2, 10), 0)
eq("花 0 層 ⇒ 0", PD.Chance(100, 2, 0, 0, 0), 0)
near("剩 1 個觸發：1 − (N−K)/N", PD.Chance(100, 2, 50, 1, 10), 10 / 50 * 100, 1e-9)
check("翻得越多機率越高", PD.Chance(100, 2, 80, 0, 10) > PD.Chance(100, 2, 0, 0, 10))
check("多中了（hit > procs）不出錯", PD.Chance(100, 2, 10, 3, 10) == 0)

eq("FormatChance 4.94", PD.FormatChance(4.94), "4.9%")
eq("FormatChance 12.4", PD.FormatChance(12.4), "12%")
eq("FormatChance 99.96", PD.FormatChance(99.96), "100%")
eq("FormatChance 9.96 不印 10.0%", PD.FormatChance(9.96), "10%")
eq("FormatChance 0", PD.FormatChance(0), "0%")
eq("FormatChance 100", PD.FormatChance(100), "100%")

------------------------------------------------------------
-- 3. 狀態機
------------------------------------------------------------
local st = PD.New()
check("花 10 層：狀態變了", PD.OnSpend(st, T, 10, 1.000, false))
eq("翻了 10 張", st.drawn, 10)
local ok, why = PD.OnTrigger(st, T, 1.000)
check("同一幀的觸發算進去", ok, why)
eq("hit 1", st.hit, 1)
eq("刻度記在花層前的位置", st.ticks[1], 0)
ok, why = PD.OnTrigger(st, T, 1.000)
check("同幀重複不算", not ok)
eq("重複的原因", why, "dup")
eq("hit 還是 1", st.hit, 1)

PD.OnSpend(st, T, 5, 2.000, false)
ok, why = PD.OnTrigger(st, T, 2.010)
check("視窗外（10ms > 5ms）不算", not ok)
eq("視窗外的原因", why, "outside")
eq("hit 還是 1", st.hit, 1)

-- 同一次花層的第二個觸發不算（一次花層最多一個）
local su = PD.New()
PD.OnSpend(su, SU, 5, 3.000, false)
check("風暴釋放：視窗內第一個算", (PD.OnTrigger(su, SU, 3.020)))
check("風暴釋放：同一次花層的第二個不算", not PD.OnTrigger(su, SU, 3.030))
eq("風暴釋放 hit 1", su.hit, 1)
eq("風暴釋放刻度＝花層前 0", su.ticks[1], 0)

-- 觸發比花層先到（同一幀）：記下來，花層到了直接認領
local early = PD.New()
ok, why = PD.OnTrigger(early, T, 5.000)
check("先到：還沒算", not ok)
eq("先到的原因", why, "early")
PD.OnSpend(early, T, 10, 5.000, false)
eq("同一幀的花層認領先到的觸發", early.hit, 1)
eq("先到的刻度＝花層前 0", early.ticks[1], 0)
local early2 = PD.New()
PD.OnTrigger(early2, T, 5.000)
PD.OnSpend(early2, T, 10, 5.016, false)
eq("不同幀的花層不認領", early2.hit, 0)
PD.OnSpend(early2, T, 10, 5.032, false)
eq("認領機會只有下一次花層那一刻", early2.hit, 0)

-- 末日之風：晚到也在 250ms 視窗內；硬讀 0.5 秒內不算
local dw = PD.New()
PD.OnSpend(dw, DW, 8, 10.000, false)
check("末日之風：晚 120ms 還算", (PD.OnTrigger(dw, DW, 10.120)))
eq("末日之風 hit 1", dw.hit, 1)
PD.OnHardcast(dw, 20.000)
PD.OnSpend(dw, DW, 5, 20.050, false)
ok, why = PD.OnTrigger(dw, DW, 20.200)
check("硬讀後 0.5 秒內不算", not ok)
eq("硬讀的原因", why, "hardcast")
PD.OnSpend(dw, DW, 5, 21.000, false)
check("硬讀 0.5 秒之後照算", (PD.OnTrigger(dw, DW, 21.100)))
eq("末日之風 hit 2", dw.hit, 2)
check("晚到超過 250ms 不算", (function()
    PD.OnSpend(dw, DW, 5, 30.000, false)
    return not PD.OnTrigger(dw, DW, 30.300)
end)())

-- 昇華凍結：不翻
local fz = PD.New()
check("凍結：沒變", not PD.OnSpend(fz, DW, 10, 1, true))
eq("凍結：drawn 0", fz.drawn, 0)
check("花 0 層：沒變", not PD.OnSpend(fz, DW, 0, 1, false))

-- 翻過尾端：觸發數對 ⇒ 新的一疊乾淨
local a = PD.New()
a.drawn, a.hit, a.ticks = 95, 2, { 10, 60 }
PD.OnSpend(a, T, 10, 40.000, false)
eq("翻過尾端：殘餘 5 張", a.drawn, 5)
eq("翻過尾端：hit 歸零", a.hit, 0)
eq("翻過尾端：第 2 疊", a.deckNo, 2)
eq("翻過尾端：刻度清空", #a.ticks, 0)
check("觸發數對：不漂移", not a.drift)
-- 這次花層的觸發：舊的那疊沒有缺 ⇒ 算新的一疊，刻度在 0
check("跨疊的觸發算新的一疊", (PD.OnTrigger(a, T, 40.000)))
eq("新的一疊 hit 1", a.hit, 1)
eq("新的一疊刻度 0", a.ticks[1], 0)

-- 翻過尾端：舊的那疊還缺一個 ⇒ 先標漂移；同一次花層的觸發補給舊的那疊 ⇒ 漂移解除、新的一疊 hit 不動
local b = PD.New()
b.drawn, b.hit, b.ticks = 97, 1, { 30 }
PD.OnSpend(b, T, 10, 50.000, false)
check("缺一個：先標漂移", b.drift)
check("跨疊的觸發補給舊的那疊", (PD.OnTrigger(b, T, 50.000)))
check("補完：漂移解除", not b.drift)
eq("補完：新的一疊 hit 還是 0", b.hit, 0)
eq("補完：新的一疊沒有刻度", #b.ticks, 0)

-- 翻過尾端：舊的那疊少了（沒等到觸發）⇒ 新的一疊整疊漂移、文字「?」；再翻完一疊觸發數對 ⇒ 重新信任
local c = PD.New()
c.drawn, c.hit = 95, 0
PD.OnSpend(c, T, 10, 60.000, false)
check("少了：漂移", c.drift)
eq("漂移：State", PD.State(c, T), "drift")
eq("漂移：Text", PD.Text(c, T, "chance", 10), "?")
eq("漂移：RowText", PD.RowText(c, T, "position", 10), "?")
c.hit = 2
c.drawn = 99
PD.OnSpend(c, T, 3, 61.000, false)
check("下一次重洗觸發數對：重新信任", not c.drift)
-- 一疊裡中的比觸發數多 ⇒ 立刻漂移
local d = PD.New()
for i = 1, 3 do
    PD.OnSpend(d, T, 10, 70 + i, false)
    PD.OnTrigger(d, T, 70 + i)
end
eq("多中：hit 3", d.hit, 3)
check("多中：立刻漂移", d.drift)

-- Reset
PD.Reset(d)
eq("Reset：drawn", d.drawn, 0)
eq("Reset：hit", d.hit, 0)
eq("Reset：deckNo", d.deckNo, 1)
check("Reset：沒有漂移", not d.drift)
check("Reset：沒有開著的視窗", d.pendingSpend == nil)

------------------------------------------------------------
-- 4. State／Text
------------------------------------------------------------
local s4 = PD.New()
eq("滿牌", PD.State(s4, T), "full")
s4.hit = 1
eq("用掉一部分", PD.State(s4, T), "partial")
s4.hit = 2
eq("用完", PD.State(s4, T), "spent")
s4.drawn, s4.hit = 37, 1
eq("Text 位置", PD.Text(s4, T, "position", 10), "37/100")
eq("Text 剩餘", PD.Text(s4, T, "left", 10), "1")
eq("Text 機率", PD.Text(s4, T, "chance", 10), PD.FormatChance(PD.Chance(100, 2, 37, 1, 10)))
eq("RowText 位置帶剩餘", PD.RowText(s4, T, "position", 10), "37/100 · 1")
eq("RowText 剩餘", PD.RowText(s4, T, "left", 10), "1")
local N, P = PD.Remaining(s4, T)
eq("Remaining N", N, 63)
eq("Remaining P", P, 1)
s4.ticks = { 20, 50, 80 }
local fr = PD.TickFractions(s4, T)
eq("刻度最多 procs 個", #fr, 2)
near("刻度位置", fr[1], 0.2)

------------------------------------------------------------
-- 5. 存檔讀回
------------------------------------------------------------
local s5 = PD.New()
s5.drawn, s5.hit, s5.deckNo, s5.ticks = 366, 1, 4, { 120 }
local snap = PD.Snapshot(s5)
check("Snapshot：刻度是複本", snap.ticks ~= s5.ticks)
check("Snapshot：沒漂移不存 drift", snap.drift == nil)
local r5 = PD.New()
check("Restore 成功", PD.Restore(r5, DW, snap))
eq("Restore drawn", r5.drawn, 366)
eq("Restore hit", r5.hit, 1)
eq("Restore deckNo", r5.deckNo, 4)
eq("Restore ticks", r5.ticks[1], 120)
check("Restore 不帶視窗", r5.pendingSpend == nil)
check("Restore 壞資料：退回新的一疊", not PD.Restore(r5, T, { drawn = 500, hit = 0 }))
eq("壞資料：drawn 0", r5.drawn, 0)
check("Restore nil", not PD.Restore(r5, T, nil))
PD.Restore(r5, T, { drawn = 10, hit = 3 })
check("讀回 hit > procs：漂移", r5.drift)
PD.Restore(r5, T, { drawn = 10, hit = 0, ticks = { 5, "x", 999 } })
eq("壞刻度丟掉", #r5.ticks, 1)

------------------------------------------------------------
-- 6. 設定
------------------------------------------------------------
local s6 = PD.Setting(nil)
check("預設不勾", not s6.on)
eq("預設疊在格子上", s6.style, "overlay")
eq("預設機率", s6.text, "chance")
eq("預設花 10 層", s6.spend, 10)
eq("預設右上", s6.corner, "TOPRIGHT")
eq("預設下緣", s6.edge, "bottom")
check("預設標刻度", s6.ticks)
eq("預設滿牌綠", s6.colors.full.g, 0.84)
local s6b = PD.Setting({ on = true, style = "row", text = "left", spend = 99, height = 2, textSize = 50,
    colors = { full = { r = 2, g = 0, b = 0 } }, corner = "nope", edge = "top", icon = false })
check("勾了", s6b.on)
eq("row", s6b.style, "row")
eq("spend 夾上限", s6b.spend, 10)
eq("高夾下限", s6b.height, PD.HEIGHT_MIN)
eq("字級夾上限", s6b.textSize, PD.TEXT_SIZE_MAX)
eq("色值夾 0～1", s6b.colors.full.r, 1)
eq("沒存的色用預設", s6b.colors.spent.r, 0.88)
eq("壞的角落退回預設", s6b.corner, "TOPRIGHT")
eq("上緣", s6b.edge, "top")
check("圖示關", not s6b.icon)
eq("Color 漂移是灰", (PD.Color(s6, "drift")), PD.DRIFT_COLOR.r)

local cfg = {}
check("List：沒有不建", PD.List(cfg, 263) == nil)
local e6 = PD.Entry(cfg, 263, "doomwinds", true)
e6.on, e6.style = true, "row"
PD.Entry(cfg, 263, "tempest", true).on = true
local plan = PD.Plan(cfg, "SHAMAN", 263, "row")
eq("Plan row：只有末日之風", #plan, 1)
eq("Plan row：def", plan[1].def.key, "doomwinds")
local planO = PD.Plan(cfg, "SHAMAN", 263, "overlay")
eq("Plan overlay：暴風雨", #planO == 1 and planO[1].def.key, "tempest")
eq("Plan 別的專精", #PD.Plan(cfg, "SHAMAN", 262, "overlay"), 0)

------------------------------------------------------------
-- 7. 氣漩武器偵測
------------------------------------------------------------
local m = MSW.New()
local r = MSW.OnAura(m, true, 3, 1)
eq("獲得", r and r.gained, 3)
eq("層數更新", (MSW.OnAura(m, true, 7, 2)), nil)
eq("層數記住", m.apps, 7)
eq("閃電箭算花費者", MSW.OnCast(m, 188196, 3.0), "spender")
r = MSW.OnAura(m, false, 0, 3.1)
eq("消失＋花費者 ⇒ 花掉 7", r and r.spent, 7)
MSW.OnAura(m, true, 2, 4)
r = MSW.OnAura(m, false, 0, 10)
eq("消失沒花費者 ⇒ 到期", r and r.expired, 2)
-- 花費者太久以前
MSW.OnAura(m, true, 5, 11)
MSW.OnCast(m, 188443, 11.0)
r = MSW.OnAura(m, false, 0, 11.4)
eq("花費者在 0.3 秒外 ⇒ 到期", r and r.expired, 5)
-- 層數讀不到（0）消失 ⇒ 當 10
MSW.OnAura(m, true, 0, 12)
MSW.OnCast(m, 452201, 12.5)
r = MSW.OnAura(m, false, 0, 12.6)
eq("讀不到 ⇒ 花掉 10", r and r.spent, 10)
-- 同一批事件花光又疊回：層數往下掉、有花費者 ⇒ 花掉舊的層數
MSW.OnAura(m, true, 8, 13)
MSW.OnCast(m, 1218090, 13.5)
r = MSW.OnAura(m, true, 1, 13.5)
eq("花光又疊回 ⇒ 花掉 8", r and r.spent, 8)
eq("記一次", m.regainSeen, 1)
-- 層數讀不到時看不出來：只記次數
MSW.OnAura(m, true, 0, 14)
MSW.OnCast(m, 188196, 14.5)
eq("讀不到：看不出來", (MSW.OnAura(m, true, 0, 14.5)), nil)
eq("讀不到：記一次", m.unknownDrops, 1)
-- 一次花費只算一次
MSW.OnAura(m, true, 4, 15)
MSW.OnCast(m, 188196, 15.0)
MSW.OnAura(m, false, 0, 15.05)
MSW.OnAura(m, true, 1, 15.1)
r = MSW.OnAura(m, false, 0, 15.2)
eq("花費者用過一次就不再算", r and r.expired, 1)
-- 近戰三招只在末日之風期間算
eq("末日之風外的風暴打擊不算", MSW.OnCast(m, 17364, 20), nil)
eq("末日之風", MSW.OnCast(m, 384352, 21), "doomwinds")
eq("末日之風期間的風暴打擊算", MSW.OnCast(m, 17364, 22), "spender")
eq("末日之風 10 秒後不算", MSW.OnCast(m, 187874, 31.5), nil)
-- 昇華 15 秒凍結
check("昇華前不凍結", not MSW.Frozen(m, 40))
eq("昇華", MSW.OnCast(m, 114051, 40), "ascendance")
check("昇華中凍結", MSW.Frozen(m, 54.9))
check("15 秒後解凍", not MSW.Frozen(m, 55.1))
MSW.OnCast(m, 114049, 60)
check("昇華增益 ID 也算", MSW.Frozen(m, 61))

------------------------------------------------------------
-- 列的面板只有有牌堆的專精不閒置（Modules/ProcDeckRows.lua 的 Idle：其他專精當它不存在——
-- 不是錨定候選、編輯模式沒有覆蓋層）。載入檔案只定義函式，不碰遊戲全域
------------------------------------------------------------
assert(loadfile(here .. "/../Modules/ProcDeckRows.lua"))("MiliUI_CooldownManager", ns)
local Idle = ns.ProcDeckRows.Idle
ns.playerClass, ns.specID = "SHAMAN", 263
check("增強薩不閒置", not Idle())
ns.specID = 262
check("元素薩閒置", Idle())
ns.playerClass, ns.specID = "PALADIN", 70
check("懲戒騎閒置", Idle())
ns.specID = nil
check("專精還不知道時閒置", Idle())

print(("ProcDeck_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
