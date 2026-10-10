------------------------------------------------------------
-- Core/Sound.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Sound_test.lua
--
-- 覆蓋：節流（1.5 秒、被擋那次不延長窗口）、讀取畫面中與結束後 2 秒靜音、同一批「消失又出現」
-- 合併抵消（純函式與實際掛勾路徑）、AddAuraSound 對帳（多的撤、少的登、戰鬥中與秘密光環時延後、
-- 進場全部重登）、逐法術覆寫的讀寫與分組（Core/DB.lua 一起載）、主題預設值、LSM 回數字也能播、
-- 層數增加音效（光環格與暴雪增益 item 的 ApplicationsIncreased、法術展開去重、節流 0.3 進簽章、item 換身分才重登）、
-- 充能滿音效（三態轉變、進表只記不響、監看表空時撤事件、換天賦出表；ns.Glow 用假的）、
-- 施放後提醒（時間表、夾範圍、對格子、秘密 spellID、restart、取消時機、事件只在有設時註冊）、
-- 音效的天賦條件（各觸發的閘、光環格對帳時排除、天賦變了重對帳）。
-- 環境表做法同 DB_test.lua：這支本身不寫任何全域。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local DB_PATH = here .. "/../Core/DB.lua"
local SOUND_PATH = here .. "/../Core/Sound.lua"

local unpack = table.unpack or unpack

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- WoW API stub
------------------------------------------------------------
local state = { now = 100, combat = false, secret = false }
local env = setmetatable({}, { __index = _G })
env._G = env
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.InCombatLockdown = function() return state.combat end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.GetTime = function() return state.now end
env.CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    return f
end

-- LibSharedMedia：兩個字串路徑、一個檔案編號
local media = { Ding = "Interface\\AddOns\\X\\ding.ogg", Bell = "Interface\\AddOns\\X\\bell.ogg", Num = 567482 }
local lsm = { Fetch = function(_, kind, name) if kind == "sound" then return media[name] end end }
env.LibStub = function(name) if name == "LibSharedMedia-3.0" then return lsm end end

local plays = {}
env.PlaySoundFile = function(path, channel)
    plays[#plays + 1] = { path = path, channel = channel }
    return true, #plays
end

env.Enum = { UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 } }
local registered, nextID, removedIDs = {}, 0, {}
env.C_UnitAuras = {
    AddAuraSound = function(trigger, info)
        nextID = nextID + 1
        registered[nextID] = { trigger = trigger, info = info }
        return nextID
    end,
    RemoveAuraSound = function(id) registered[id] = nil; removedIDs[#removedIDs + 1] = id end,
}
env.C_Secrets = { ShouldAurasBeSecret = function() return state.secret end }

local hooks = {}
env.hooksecurefunc = function(t, name, fn) hooks[#hooks + 1] = { t = t, name = name, fn = fn } end

-- 下一幀：自己排隊，測試手動 Flush
local deferred = {}
local events = {}
local eventUnits = {}
local customRecs = {}
local ns = {
    playerClass = "PALADIN",
    Events = {
        Register = function(ev, key, fn, unit)
            events[ev] = events[ev] or {}; events[ev][key] = fn
            eventUnits[ev] = unit
        end,
        Unregister = function(ev, key) if events[ev] then events[ev][key] = nil end end,
    },
    Fire = function() end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
    IsSecret = function() return false end,
    Guard = function(fn) return fn end,
    Defer = function(fn, ...) deferred[#deferred + 1] = { fn = fn, n = select("#", ...), ... } end,
    RegisterCallback = function() end,
    Viewers = { AURA_KIND = { buffs = true, buffbars = true }, frames = {} },
    Custom = { Records = function() return customRecs end },
}
function ns.RefreshSpec() ns.specIndex = 1; ns.specID = 61 end
local function Flush()
    local list = deferred
    deferred = {}
    for _, job in ipairs(list) do job.fn(unpack(job, 1, job.n)) end
end
local function FireEvent(ev)
    for _, fn in pairs(events[ev] or {}) do fn() end
end

local function Load(path)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end
Load(DB_PATH)
Load(SOUND_PATH)
local DB, S = ns.DB, ns.Sound
local Logic = S.Logic
ns.RefreshSpec()
DB.Init()
local p = ns.profile

------------------------------------------------------------
-- 1. 節流
------------------------------------------------------------
local th = Logic.NewThrottle(1.5)
check("第一次通過", Logic.Allow(th, "a", 10))
check("1.0 秒後擋", not Logic.Allow(th, "a", 11.0))
check("1.49 秒後擋（被擋那次不延長窗口）", not Logic.Allow(th, "a", 11.49))
check("1.5 秒後通過", Logic.Allow(th, "a", 11.5))
check("別的 key 不受影響", Logic.Allow(th, "b", 11.6))
eq("預設窗口 1.5", Logic.NewThrottle().window, 1.5)

------------------------------------------------------------
-- 2. 讀取畫面靜音
------------------------------------------------------------
local m = Logic.NewMute()
check("一開始不靜音", not Logic.Muted(m, 50))
Logic.OnLoadingStart(m)
check("讀取畫面中靜音", Logic.Muted(m, 1000))
Logic.OnLoadingEnd(m, 60)
check("結束後 1.9 秒仍靜音", Logic.Muted(m, 61.9))
check("結束後 2 秒解除", not Logic.Muted(m, 62))
Logic.OnEnterWorld(m, 70)
check("進場後 2 秒內靜音", Logic.Muted(m, 71))
check("進場後 2 秒解除", not Logic.Muted(m, 72))
Logic.OnEnterWorld(m, 80); Logic.OnLoadingEnd(m, 79)
check("取較晚的那個", Logic.Muted(m, 81.5))

------------------------------------------------------------
-- 3. 合併抵消
------------------------------------------------------------
eq("消失又出現 ⇒ 不響", Logic.Net("lose", "gain"), nil)
eq("出現又消失 ⇒ 不響", Logic.Net("gain", "lose"), nil)
eq("只出現", Logic.Net("gain", "gain"), "gain")
eq("只消失", Logic.Net("lose", "lose"), "lose")
eq("消失、出現、消失 ⇒ 消失", Logic.Net("lose", "lose"), "lose")
local b = Logic.NewBatch()
Logic.Push(b, "x", "lose", 1); Logic.Push(b, "x", "gain", 1)
Logic.Push(b, "y", "gain", 2)
Logic.Push(b, "z", "lose", 3); Logic.Push(b, "z", "gain", 3); Logic.Push(b, "z", "lose", 3)
local out = Logic.Drain(b)
eq("批次：兩筆有淨變化", #out, 2)
eq("批次順序照第一次出現", out[1] and out[1].key, "y")
eq("y 是出現", out[1] and out[1].what, "gain")
eq("z 最後是消失", out[2] and out[2].what, "lose")
eq("Drain 之後清空", #Logic.Drain(b), 0)

------------------------------------------------------------
-- 4. 登記對帳
------------------------------------------------------------
local removes, adds = Logic.Diff({ a = 1, b = 2 }, { b = {}, c = {} })
eq("撤一筆", #removes, 1)
eq("撤 a", removes[1].sig, "a")
eq("撤的 id", removes[1].id, 1)
eq("登一筆", #adds, 1)
eq("登 c", adds[1].sig, "c")
check("路徑型別進簽章（字串 5 與數字 5 不同）", Logic.Sig(0, 1, 5, "Master") ~= Logic.Sig(0, 1, "5", "Master"))
eq("聲道不認得 ⇒ Master", Logic.Channel("Bogus"), "Master")
eq("聲道 SFX", Logic.Channel("SFX"), "SFX")
eq("空字串不是音效名", Logic.Name(""), nil)
eq("false 不是音效名", Logic.Name(false), nil)

------------------------------------------------------------
-- 5. 設定：主題預設、逐法術覆寫、分組
------------------------------------------------------------
eq("主題音效預設開", p.theme.sound.enabled, true)
eq("主題聲道預設 Master", p.theme.sound.channel, "Master")
eq("沒設就緒音效 ⇒ false", ns.SpellSetting("essential", 11, "readySound"), false)
eq("沒設 ⇒ NameOf nil", S.NameOf("essential", 11, "readySound"), nil)
DB.SetOverride(11, "readySound", "Ding")
DB.SetOverride(21, "gainSound", "Bell")
DB.SetOverride(21, "loseSound", "Num")
DB.SetOverride(22, "procGlow", false)
eq("讀回就緒音效", S.NameOf("essential", 11, "readySound"), "Ding")
eq("條不影響（沒有條層值）", S.NameOf("utility", 11, "readySound"), "Ding")
eq("音效分組", DB.OVERRIDE_GROUP.readySound, "sound")
eq("音效節 2 個法術", DB.CountOverrides({ 11, 21, 22 }, "sound"), 2)
eq("效果節不含音效", DB.CountOverrides({ 11, 21, 22 }, "glow"), 1)
DB.ClearOverrides({ 22 }, "glow")
eq("清效果節不動音效", S.NameOf(nil, 21, "gainSound"), "Bell")
DB.SetOverride(31, "readySound", "Ding")
DB.ClearOverrides({ 31 }, "sound")
eq("清音效節", p.spells[61].overrides[31], nil)
-- 生效發光跟觸發／就緒同一組（2026-10-03）：清效果節一起清；音效不動
DB.SetOverride(41, "activeGlow", true)
DB.SetOverride(41, "activeGlowColor", { r = 1, g = 0, b = 0, a = 1 })
DB.SetOverride(41, "procGlow", false)
DB.SetOverride(41, "gainSound", "Bell")
DB.ClearOverrides({ 41 }, "glow")
eq("清效果節清掉生效發光", p.spells[61].overrides[41] and p.spells[61].overrides[41].activeGlow, nil)
eq("清效果節順手清掉舊的生效發光顏色", p.spells[61].overrides[41] and p.spells[61].overrides[41].activeGlowColor, nil)
eq("效果節的觸發發光清掉了", p.spells[61].overrides[41] and p.spells[61].overrides[41].procGlow, nil)
eq("清效果節不動音效（生效發光那格）", p.spells[61].overrides[41] and p.spells[61].overrides[41].gainSound, "Bell")

------------------------------------------------------------
-- 6. 播放：總開關、聲道、節流、靜音
------------------------------------------------------------
S.Init()                         -- 進場：state.now = 100 ⇒ 靜音到 102
local rec = { cooldownID = 11, claimKey = "essential" }
check("WantsReady", S.WantsReady(rec))
S.OnReady(rec)
eq("進場 2 秒內不響", #plays, 0)
state.now = 102.5
S.OnReady(rec)
eq("靜音結束後響", #plays, 1)
eq("播的是 LSM 路徑", plays[1] and plays[1].path, media.Ding)
eq("聲道 Master", plays[1] and plays[1].channel, "Master")
state.now = 103.5
S.OnReady(rec)
eq("1 秒後同一個法術不重複", #plays, 1)
state.now = 104.1
S.OnReady(rec)
eq("1.6 秒後再響", #plays, 2)
p.theme.sound.channel = "SFX"
state.now = 110
S.OnReady(rec)
eq("聲道跟著設定", plays[3] and plays[3].channel, "SFX")
p.theme.sound.enabled = false
state.now = 120
S.OnReady(rec)
eq("總開關關掉不響", #plays, 3)
check("總開關關掉 ⇒ 不要探針", not S.WantsReady(rec))
check("試聽不看總開關", S.Preview("Bell"))
eq("試聽播了", #plays, 4)
p.theme.sound.enabled = true
check("沒設音效的法術不要探針", not S.WantsReady({ cooldownID = 99, claimKey = "essential" }))
FireEvent("LOADING_SCREEN_ENABLED")
state.now = 200
S.OnReady(rec)
eq("讀取畫面中不響", #plays, 4)
FireEvent("LOADING_SCREEN_DISABLED")
state.now = 201.5
S.OnReady(rec)
eq("讀取畫面結束 1.5 秒仍不響", #plays, 4)
state.now = 202.1
S.OnReady(rec)
eq("讀取畫面結束 2 秒後響", #plays, 5)

-- 不屬於任何一格的音效（虛空化身的門檻規則）：同一個出口，key 由呼叫端給
state.now = 210
check("PlayNamed 響", S.PlayNamed("Bell", "meta:time:1"))
eq("PlayNamed 播的是 LSM 路徑", plays[6] and plays[6].path, media.Bell)
state.now = 210.5
check("PlayNamed 同一個 key 節流", not S.PlayNamed("Bell", "meta:time:1"))
check("PlayNamed 別的 key 照響", S.PlayNamed("Bell", "meta:stars:1"))
eq("PlayNamed 記在最近一次", S.last and S.last.why, "meta")
p.theme.sound.enabled = false
state.now = 220
check("PlayNamed 看總開關", not S.PlayNamed("Bell", "meta:time:2"))
p.theme.sound.enabled = true
check("PlayNamed 沒有名字不響", not S.PlayNamed(nil, "meta:time:3"))
eq("PlayNamed 一共響兩次", #plays, 7)

------------------------------------------------------------
-- 7. 增益 item：暴雪警示後掛勾 → 下一幀合併
------------------------------------------------------------
local item = {}
function item:TriggerAuraAppliedAlert() end
function item:TriggerAuraRemovedAlert() end
local irec = { barKey = "buffs", cooldownID = 21 }
ns.Viewers.frames[item] = irec
S.HookItem(item, irec)
local applied, removed
for _, h in ipairs(hooks) do
    if h.t == item and h.name == "TriggerAuraAppliedAlert" then applied = h.fn end
    if h.t == item and h.name == "TriggerAuraRemovedAlert" then removed = h.fn end
end
check("掛上出現", applied ~= nil)
check("掛上消失", removed ~= nil)
eq("掛勾方式 alert", S.hookMode, "alert")
local core = {}
function core:TriggerAuraAppliedAlert() end
function core:TriggerAuraRemovedAlert() end
local nh = #hooks
S.HookItem(core, { barKey = "essential", cooldownID = 5 })
eq("核心技能 item 不掛", #hooks, nh)

state.now = 300
local before = #plays
removed(item); applied(item)
Flush()
eq("同一批消失又出現 ⇒ 不響", #plays, before)
applied(item)
Flush()
eq("出現 ⇒ 響", #plays, before + 1)
eq("出現音效是 Bell", plays[#plays].path, media.Bell)
state.now = 305
removed(item)
Flush()
eq("消失 ⇒ 響（LSM 回數字也能播）", plays[#plays].path, media.Num)
state.now = 310
irec.cooldownID = 77                 -- 沒設音效的法術：不排、不響
local n0 = #plays
applied(item); Flush()
eq("沒設音效不響", #plays, n0)
irec.cooldownID = 21

-- 退路：沒有警示方法時掛 OnActiveStateChanged
local old = {}
local active = false
function old:OnActiveStateChanged() end
function old:IsActive() return active end
local orec = { barKey = "buffbars", cooldownID = 21 }
ns.Viewers.frames[old] = orec
S.HookItem(old, orec)
local onActive
for _, h in ipairs(hooks) do if h.t == old and h.name == "OnActiveStateChanged" then onActive = h.fn end end
check("退路掛上 OnActiveStateChanged", onActive ~= nil)
state.now = 400
n0 = #plays
onActive(old); Flush()
eq("第一次只記狀態", #plays, n0)
active = true; onActive(old); Flush()
eq("退路：出現", #plays, n0 + 1)
state.now = 410
active = false; onActive(old); active = true; onActive(old); Flush()
eq("退路：同一幀消失又出現抵消", #plays, n0 + 1)

------------------------------------------------------------
-- 7b. 暴雪的冷卻格：增益持續時間開始／結束（S.OnAuraFlag）
------------------------------------------------------------
do
    local crec = { barKey = "essential", cooldownID = 21 }
    state.now = 500
    local n = #plays
    S.OnAuraFlag(crec, true); Flush()
    eq("冷卻格：第一次看到（初值）只記不響", #plays, n)
    S.OnAuraFlag(crec, false); Flush()
    eq("冷卻格：增益結束 ⇒ 消失音效", #plays, n + 1)
    eq("消失音效是 Num", plays[#plays].path, media.Num)
    state.now = 510
    S.OnAuraFlag(crec, true); S.OnAuraFlag(crec, true); Flush()
    eq("冷卻格：增益開始 ⇒ 響一次（連叫兩次同值不重響）", #plays, n + 2)
    eq("出現音效是 Bell", plays[#plays].path, media.Bell)
    state.now = 520
    S.OnAuraFlag(crec, nil); Flush()
    eq("秘密值／讀不到 ⇒ 不動", #plays, n + 2)
    crec.cooldownID = 22                 -- 框被回收給別的法術：重新起算
    S.OnAuraFlag(crec, false); Flush()
    eq("換了法術 ⇒ 只記不響", #plays, n + 2)
    local brec = { barKey = "buffs", cooldownID = 21 }
    S.OnAuraFlag(brec, true); S.OnAuraFlag(brec, false); Flush()
    eq("增益格不走這條（有自己的警示掛勾）", #plays, n + 2)
    local cust = { barKey = "essential", cooldownID = "c:9", custom = true }
    S.OnAuraFlag(cust, true); S.OnAuraFlag(cust, false); Flush()
    eq("自訂項目不走這條", #plays, n + 2)
end

------------------------------------------------------------
-- 8. 光環格：AddAuraSound 對帳
------------------------------------------------------------
DB.SetOverride("c:1", "gainSound", "Ding")
DB.SetOverride("c:1", "loseSound", "Num")
customRecs.a = { kind = "aura", placedBar = "buffs", cooldownID = "c:1", spellID = 12345 }
customRecs.s = { kind = "spell", placedBar = "essential", cooldownID = "c:2", spellID = 6 }
deferred = {}
state.combat = true
S.RequestAuraSync(); Flush()
eq("戰鬥中不登記", S.AuraCount(), 0)
check("戰鬥中 ⇒ 待登記", S.auraPending)
check("排了脫戰重試", events.PLAYER_REGEN_ENABLED and events.PLAYER_REGEN_ENABLED.sound_retry ~= nil)
state.combat = false
FireEvent("PLAYER_REGEN_ENABLED"); Flush()
eq("脫戰補登兩筆", S.AuraCount(), 2)
check("不再待登記", not S.auraPending)
check("重試事件撤掉", not (events.PLAYER_REGEN_ENABLED and events.PLAYER_REGEN_ENABLED.sound_retry))
local byTrig = {}
for _, r in pairs(registered) do byTrig[r.trigger] = r.info end
eq("出現登 Added", byTrig[0] and byTrig[0].soundFileName, media.Ding)
eq("消失登 Removed、數字走 soundFileID", byTrig[2] and byTrig[2].soundFileID, media.Num)
eq("unitToken", byTrig[0] and byTrig[0].unitToken, "player")
eq("spellID", byTrig[0] and byTrig[0].spellID, 12345)
eq("節流 1.5", byTrig[0] and byTrig[0].throttleSeconds, 1.5)
eq("聲道", byTrig[0] and byTrig[0].outputChannel, "SFX")

S.RequestAuraSync(); Flush()
eq("沒變就不動", nextID, 2)
DB.SetOverride("c:1", "gainSound", "Bell")
S.RequestAuraSync(); Flush()
eq("換音效：撤一筆登一筆", S.AuraCount(), 2)
eq("登了第三筆", nextID, 3)
eq("撤掉舊的那筆", removedIDs[#removedIDs], 1)

state.secret = true
DB.SetOverride("c:1", "loseSound", nil)
S.RequestAuraSync(); Flush()
eq("秘密光環時不動", S.AuraCount(), 2)
check("秘密光環 ⇒ 待登記", S.auraPending)
state.secret = false
FireEvent("ZONE_CHANGED_NEW_AREA"); Flush()
eq("出副本補撤", S.AuraCount(), 1)

FireEvent("PLAYER_ENTERING_WORLD"); Flush()
eq("進場全部重登（筆數不變）", S.AuraCount(), 1)
eq("進場撤掉舊的再登新的", nextID, 4)

customRecs.a.placedBar = nil
S.RequestAuraSync(); Flush()
eq("收起來的光環格撤掉", S.AuraCount(), 0)
customRecs.a.placedBar = "buffs"
p.theme.sound.enabled = false
S.RequestAuraSync(); Flush()
eq("總開關關掉不登記", S.AuraCount(), 0)
p.theme.sound.enabled = true

-- 多法術的光環格（嗜血那種）：每個法術各登一筆
S.RequestAuraSync(); Flush()
eq("單一法術：一筆（只剩出現音效）", S.AuraCount(), 1)
ns.Custom.AuraIDsOf = function(rec) return rec.ids or { rec.spellID } end
customRecs.a.ids = { 12345, 23456, 34567 }
S.RequestAuraSync(); Flush()
eq("多法術：每個法術各一筆", S.AuraCount(), 3)
do
    local ids = {}
    for _, r in pairs(registered) do ids[#ids + 1] = r.info.spellID end
    table.sort(ids)
    eq("多法術：登記的法術", table.concat(ids, ","), "12345,23456,34567")
end
customRecs.a.ids = nil
S.RequestAuraSync(); Flush()
eq("拿掉多法術：撤回剩一筆", S.AuraCount(), 1)

-- 飾品欄冷卻格的增益疊層（rec.buffOverlay）：疊著時照冷卻格那一筆的 cooldownID 登記、每個增益各一筆
DB.SetOverride("c:3", "gainSound", "Ding")
local ovl = { kind = "aura", placedBar = "essential", cooldownID = "c:3", spellID = 1297761, ids = { 1297761, 1305376 } }
customRecs.t = { kind = "slot", placedBar = "essential", cooldownID = "c:3", slot = 13, buffOverlay = ovl }
S.RequestAuraSync(); Flush()
eq("疊層：每個增益各一筆（加上光環格那一筆）", S.AuraCount(), 3)
do
    local got = {}
    for _, r in pairs(registered) do if r.info.spellID ~= 12345 then got[#got + 1] = r.info.spellID end end
    table.sort(got)
    eq("疊層：登記的是解出來的增益", table.concat(got, ","), "1297761,1305376")
end
ovl.placedBar = nil
S.RequestAuraSync(); Flush()
eq("疊層收起來（不疊）⇒ 撤掉", S.AuraCount(), 1)
customRecs.t = nil
DB.SetOverride("c:3", "gainSound", nil)
ns.Custom.AuraIDsOf = nil

------------------------------------------------------------
-- 8b. 層數增加音效：光環格與暴雪增益 item（ApplicationsIncreased、節流 0.3 進簽章）
------------------------------------------------------------
do
    eq("層數增加音效：SPELL_CONST false", DB.SPELL_CONST.stackSound, false)
    eq("層數增加音效：音效節", DB.OVERRIDE_GROUP.stackSound, "sound")
    eq("充能滿音效：SPELL_CONST false", DB.SPELL_CONST.fullSound, false)
    eq("充能滿音效：音效節", DB.OVERRIDE_GROUP.fullSound, "sound")
    eq("充能滿語音：音效節", DB.OVERRIDE_GROUP.fullSpeak, "sound")
    check("節流值進簽章", Logic.Sig(1, 5, "x", "Master", 0.3) ~= Logic.Sig(1, 5, "x", "Master", 1.5))
    eq("沒給節流 ＝ 預設 1.5 的簽章", Logic.Sig(0, 5, "x", "Master"), Logic.Sig(0, 5, "x", "Master", 1.5))

    S.RequestAuraSync(); Flush()
    local base = S.AuraCount()                       -- 前一段留下的光環格（出現音效一筆）
    local function Count(trig, sid)
        local n = 0
        for _, r in pairs(registered) do
            if r.trigger == trig and (sid == nil or r.info.spellID == sid) then n = n + 1 end
        end
        return n
    end
    -- 光環格：stackSound ⇒ 多一筆 ApplicationsIncreased（trigger 1）、節流 0.3
    DB.SetOverride("c:1", "stackSound", "Ding")
    S.RequestAuraSync(); Flush()
    eq("光環格層數增加：多一筆", S.AuraCount(), base + 1)
    local inc
    for _, r in pairs(registered) do if r.trigger == 1 then inc = r.info end end
    eq("光環格層數增加：法術", inc and inc.spellID, 12345)
    eq("光環格層數增加：節流 0.3", inc and inc.throttleSeconds, 0.3)
    DB.SetOverride("c:1", "stackSound", nil)
    S.RequestAuraSync(); Flush()
    eq("光環格層數增加：拿掉就撤", S.AuraCount(), base)

    -- 暴雪增益 item：目錄 spellID＋overrideTooltipSpellID＋linkedSpellIDs，去重、各一筆
    local items = {
        { {}, { barKey = "buffs", cooldownID = 701 } },
        { {}, { barKey = "buffbars", cooldownID = 702 } },
        { {}, { barKey = "buffs", cooldownID = nil } },          -- 池子裡、還沒身分
        { {}, { barKey = "buffs", cooldownID = 703 } },          -- 沒設層數增加音效
    }
    local infos = {
        [701] = { spellID = 51124, overrideTooltipSpellID = 51124, linkedSpellIDs = { 51124, 53365 } },
        [702] = { spellID = 9001, linkedSpellIDs = { 9002, 9002 } },
        [703] = { spellID = 9100 },
    }
    local origCatalog, origEnum = ns.Catalog, ns.Viewers.EnumerateItems
    ns.Catalog = { Info = function(id) return infos[id] end }
    ns.Viewers.EnumerateItems = function(fn, onlyKey)
        for _, it in ipairs(items) do
            if not onlyKey or it[2].barKey == onlyKey then fn(it[1], it[2]) end
        end
    end
    eq("法術展開：去重", table.concat(S.BuffItemSpells(701), ","), "51124,53365")
    eq("法術展開：linked 重複只算一次", table.concat(S.BuffItemSpells(702), ","), "9001,9002")
    eq("法術展開：沒有目錄資訊 ⇒ 空", #S.BuffItemSpells(999), 0)

    S.RequestAuraSync(); Flush()
    eq("沒設 stackSound ⇒ 暴雪增益 item 不登", S.AuraCount(), base)
    DB.SetOverride(701, "stackSound", "Bell")
    DB.SetOverride(702, "stackSound", "Num")
    S.RequestAuraSync(); Flush()
    eq("暴雪增益 item：每個法術各一筆", S.AuraCount(), base + 4)
    eq("殺戮機器 51124 一筆 ApplicationsIncreased", Count(1, 51124), 1)
    eq("連帶的 53365 一筆", Count(1, 53365), 1)
    eq("702 的兩個法術", Count(1, 9001) + Count(1, 9002), 2)
    eq("沒設的 703 不登", Count(1, 9100), 0)
    do
        local th
        for _, r in pairs(registered) do if r.info.spellID == 53365 then th = r.info.throttleSeconds end end
        eq("暴雪增益 item 節流 0.3", th, 0.3)
    end
    eq("暴雪增益 item 不登出現／消失（那兩種走 Lua 掛勾）", Count(0, 51124) + Count(2, 51124), 0)

    -- item 換身分：前後任一個有設才排對帳
    local n0 = #deferred
    S.OnBuffItemChanged(703, nil)
    eq("沒設層數增加的 item 換身分 ⇒ 不排", #deferred, n0)
    S.OnBuffItemChanged(nil, 701)
    check("有設的 item 換身分 ⇒ 排對帳", #deferred > n0)
    items[1][2].cooldownID = nil                     -- 701 從池子裡收掉
    Flush()
    eq("item 收掉 ⇒ 撤掉它的兩筆", S.AuraCount(), base + 2)
    items[1][2].cooldownID = 701

    -- 戰鬥中不能登：排到脫戰
    state.combat = true
    S.RequestAuraSync(); Flush()
    eq("戰鬥中不動", S.AuraCount(), base + 2)
    state.combat = false
    FireEvent("PLAYER_REGEN_ENABLED"); Flush()
    eq("脫戰補登", S.AuraCount(), base + 4)

    -- 自訂項目的 rec 不算暴雪增益 item
    items[5] = { {}, { barKey = "buffs", cooldownID = 701, custom = true } }
    S.RequestAuraSync(); Flush()
    eq("自訂 rec 不重複登", S.AuraCount(), base + 4)
    items[5] = nil

    DB.SetOverride(701, "stackSound", nil)
    DB.SetOverride(702, "stackSound", nil)
    S.RequestAuraSync(); Flush()
    eq("拿掉 ⇒ 撤乾淨", S.AuraCount(), base)
    ns.Catalog, ns.Viewers.EnumerateItems = origCatalog, origEnum
end

------------------------------------------------------------
-- 8c. 充能滿音效：三態轉變、監看表、事件
------------------------------------------------------------
do
    local FE = Logic.FullEdge
    check("沒滿 → 滿 ⇒ 響", FE(false, true))
    check("讀不到 → 滿 ⇒ 不響", not FE(nil, true))
    check("滿 → 滿 ⇒ 不響", not FE(true, true))
    check("滿 → 沒滿 ⇒ 不響", not FE(true, false))
    check("沒滿 → 讀不到 ⇒ 不響", not FE(false, nil))

    local charge, full = {}, {}                       -- 法術 → 是不是充能技能／三態
    local origGlow = ns.Glow
    ns.Glow = {
        FullSpellOf = function(rec) return rec.spell end,
        ReadFull = function(_, id) return charge[id] == true, full[id] end,
    }
    local function Full() return events.SPELL_UPDATE_CHARGES and events.SPELL_UPDATE_CHARGES.sound_full end
    state.now = 600
    local rec = { cooldownID = 51, claimKey = "essential", spell = 5100 }
    charge[5100], full[5100] = true, true

    S.SyncFull(rec, "essential", false)
    eq("沒設 ⇒ 不進表", S.fullWatch[rec], nil)
    check("表空 ⇒ 不聽事件", not Full())

    DB.SetOverride(51, "fullSound", "Ding")
    local n = #plays
    S.SyncFull(rec, "essential", false)
    check("設了 ⇒ 進表", S.fullWatch[rec] ~= nil)
    check("表不空 ⇒ 聽 SPELL_UPDATE_CHARGES", Full() ~= nil)
    eq("進表當下（滿著）只記不響", #plays, n)

    full[5100] = false; FireEvent("SPELL_UPDATE_CHARGES")
    eq("用掉一層（沒滿）⇒ 不響", #plays, n)
    full[5100] = true; FireEvent("SPELL_UPDATE_CHARGES")
    eq("沒滿 → 滿 ⇒ 響", #plays, n + 1)
    eq("播的是充能滿音效", plays[#plays].path, media.Ding)
    FireEvent("SPELL_UPDATE_CHARGES")
    eq("滿 → 滿 ⇒ 不響", #plays, n + 1)

    state.now = 610
    full[5100] = false; FireEvent("SPELL_UPDATE_CHARGES")
    full[5100] = nil; FireEvent("SPELL_UPDATE_CHARGES")
    full[5100] = true; FireEvent("SPELL_UPDATE_CHARGES")
    eq("沒滿 → 讀不到 → 滿 ⇒ 不響（讀不到把狀態清掉）", #plays, n + 1)
    full[5100] = false; FireEvent("SPELL_UPDATE_CHARGES")
    full[5100] = true; FireEvent("SPELL_UPDATE_CHARGES")
    eq("再一次明確的沒滿 → 滿 ⇒ 響", #plays, n + 2)

    -- 排版時（SyncFull）剛好碰上回滿也算
    state.now = 620
    full[5100] = false; S.SyncFull(rec, "essential", false)
    full[5100] = true; S.SyncFull(rec, "essential", false)
    eq("排版對帳：沒滿 → 滿 ⇒ 響", #plays, n + 3)

    -- 框換了一招（cooldownID 換了）：重新進表、只記不響
    state.now = 630
    full[5100] = false; S.SyncFull(rec, "essential", false)
    rec.cooldownID = 52; DB.SetOverride(52, "fullSound", "Bell")
    full[5100] = true; S.SyncFull(rec, "essential", false)
    eq("換了一招 ⇒ 只記不響", #plays, n + 3)
    rec.cooldownID = 51

    -- 語音播報：只設語音也進表、轉變時念
    local rec2 = { cooldownID = 53, claimKey = "essential", spell = 5300 }
    charge[5300], full[5300] = true, false
    local spoken = {}
    env.C_VoiceChat = { SpeakText = function(_, text) spoken[#spoken + 1] = text end }
    env.C_TTSSettings = { GetVoiceOptionID = function() return 1 end }
    DB.SetOverride(53, "fullSpeak", "滿了")
    S.SyncFull(rec2, "essential", false)
    check("只設語音也進表", S.fullWatch[rec2] ~= nil)
    full[5300] = true; FireEvent("SPELL_UPDATE_CHARGES")
    eq("語音播報念設定的字", spoken[#spoken], "滿了")
    env.C_VoiceChat, env.C_TTSSettings = nil, nil
    DB.SetOverride(53, "fullSpeak", nil)
    S.SyncFull(rec2, "essential", false)
    eq("拿掉語音 ⇒ 出表", S.fullWatch[rec2], nil)

    -- 換天賦不再是充能技能：事件裡發現就出表、表空撤事件
    charge[5100] = false
    FireEvent("SPELL_UPDATE_CHARGES")
    eq("不再是充能技能 ⇒ 出表", S.fullWatch[rec], nil)
    check("表空 ⇒ 撤事件", not Full())

    -- 藏起來／停放／總開關
    charge[5100], full[5100] = true, true
    S.SyncFull(rec, "essential", false)
    check("回到充能技能 ⇒ 再進表", S.fullWatch[rec] ~= nil)
    S.SyncFull(rec, "essential", true)
    eq("藏起來 ⇒ 出表", S.fullWatch[rec], nil)
    S.SyncFull(rec, "essential", false)
    S.UnwatchFull(rec)
    eq("停放 ⇒ 出表", S.fullWatch[rec], nil)
    check("停放後表空 ⇒ 撤事件", not Full())
    p.theme.sound.enabled = false
    S.SyncFull(rec, "essential", false)
    eq("總開關關掉 ⇒ 不進表", S.fullWatch[rec], nil)
    p.theme.sound.enabled = true
    -- 不是充能技能（三態回 nil 且 IsChargeSpell false）：不進表
    local rec3 = { cooldownID = 51, claimKey = "essential", spell = 7777 }
    S.SyncFull(rec3, "essential", false)
    eq("不是充能技能 ⇒ 不進表", S.fullWatch[rec3], nil)
    -- 解不出法術（物品、增益）：不進表
    S.SyncFull({ cooldownID = 51, claimKey = "essential" }, "essential", false)
    check("解不出法術 ⇒ 表還是空的", next(S.fullWatch) == nil)

    DB.SetOverride(51, "fullSound", nil)
    DB.SetOverride(52, "fullSound", nil)
    ns.Glow = origGlow
end

------------------------------------------------------------
-- 自訂語音
------------------------------------------------------------
do
    local N = Logic.NormalizePath
    -- 2026-10-03 起：Interface 之後的相對路徑（不再限定 AddOns）
    eq("路徑：相對路徑照收", N("MyVoice\\kick.ogg"), "MyVoice\\kick.ogg")
    eq("路徑：斜線轉反斜線、去頭尾空白", N("  MyVoice/sub/kick.mp3 "), "MyVoice\\sub\\kick.mp3")
    eq("路徑：去掉 Interface\\、留 AddOns\\", N("Interface\\AddOns\\MyVoice\\kick.ogg"), "AddOns\\MyVoice\\kick.ogg")
    eq("路徑：大小寫不拘", N("interface/addons/MyVoice/kick.OGG"), "addons\\MyVoice\\kick.OGG")
    eq("路徑：AddOns\\ 開頭照收", N("AddOns\\MyVoice\\kick.ogg"), "AddOns\\MyVoice\\kick.ogg")
    eq("路徑：Interface 底下別的資料夾", N("Interface\\Sounds\\kick.ogg"), "Sounds\\kick.ogg")
    eq("路徑：整段絕對路徑", N("\"C:\\Program Files\\World of Warcraft\\_retail_\\Interface\\AddOns\\MyVoice\\kick.ogg\""), "AddOns\\MyVoice\\kick.ogg")
    eq("路徑：名字裡含 interface 的資料夾不當成根", N("MyInterface\\kick.ogg"), "MyInterface\\kick.ogg")
    eq("路徑：重複反斜線收成一個", N("MyVoice\\\\kick.ogg"), "MyVoice\\kick.ogg")
    -- 舊存檔（AddOns 之後）一次性補前綴
    local old = { customSounds = { { id = 1, name = "a", path = "MyVoice\\kick.ogg" } } }
    check("遷移：補 AddOns 前綴", Logic.MigrateRoot(old) and old.customSounds[1].path == "AddOns\\MyVoice\\kick.ogg")
    check("遷移：只做一次", not Logic.MigrateRoot(old) and old.customSounds[1].path == "AddOns\\MyVoice\\kick.ogg")
    local r, why = N("MyVoice\\kick.wav")
    check("路徑：wav 不收", r == nil and why == "ext", why)
    r, why = N("   ")
    check("路徑：空白不收", r == nil and why == "empty", why)
    r, why = N("Interface\\")
    check("路徑：只有前綴不收", r == nil and why == "empty", why)
    eq("預設名字＝檔名去副檔名", Logic.DefaultName("MyVoice\\sub\\kick.ogg"), "kick")
    eq("代號往返", Logic.CustomID(Logic.CustomValue(12)), 12)
    check("LSM 名稱不是代號", Logic.CustomID("Ding") == nil)

    local sv = MiliUI_CooldownManager_DB or env.MiliUI_CooldownManager_DB
    check("帳號層有預設的空清單", type(sv.customSounds) == "table" and #sv.customSounds == 0)
    local a = S.CustomAdd("", "MyVoice/kick.ogg")
    local b = S.CustomAdd("Boom", "Interface\\AddOns\\MyVoice\\boom.mp3")
    check("新增成功", a and b)
    eq("沒取名用檔名", a.name, "kick")
    check("id 不同", a.id ~= b.id)
    local bad, why2 = S.CustomAdd("x", "nope.txt")
    check("不合法的路徑不新增", bad == nil and why2 == "ext" and #S.CustomList() == 2)
    eq("Path：自訂語音解成完整路徑", S.Path(Logic.CustomValue(a.id)), "Interface\\MyVoice\\kick.ogg")
    eq("DisplayName：自訂語音顯示名字", S.DisplayName(Logic.CustomValue(b.id)), "Boom")
    eq("DisplayName：LSM 名稱照舊", S.DisplayName("Ding"), "Ding")
    check("Path：不存在的代號 ＝ nil", S.Path("custom:999") == nil)

    -- 播放：試聽與實際播放都走同一條路
    local before = #plays
    check("試聽自訂語音", S.Preview(Logic.CustomValue(b.id)))
    eq("試聽的路徑", plays[#plays].path, "Interface\\AddOns\\MyVoice\\boom.mp3")
    eq("試聽播一次", #plays, before + 1)

    -- 改名、改路徑：代號不變，指到它的格子跟著變
    DB.SetOverride(5001, "readySound", Logic.CustomValue(a.id))
    check("編輯", S.CustomEdit(1, "Kick!", "AddOns\\MyVoice\\kick2.ogg"))
    eq("編輯後名字", S.CustomList()[1].name, "Kick!")
    eq("編輯後格子解到新路徑", S.Path(S.NameOf("essential", 5001, "readySound")), "Interface\\AddOns\\MyVoice\\kick2.ogg")
    check("編輯不合法的路徑：不動", S.CustomEdit(1, "x", "") == nil and S.CustomList()[1].path == "AddOns\\MyVoice\\kick2.ogg")

    -- 排序
    check("下移", S.CustomMove(1, 1))
    eq("下移後順序", S.CustomList()[1].name, "Boom")
    check("頂到底不能再下移", not S.CustomMove(2, 1))
    check("上移", S.CustomMove(2, -1))
    eq("上移後順序", S.CustomList()[1].name, "Kick!")

    -- 刪除：所有設定檔裡指到它的格子一起清掉，別的值不動
    DB.SetOverride(5001, "gainSound", "Ding")
    sv.profiles.Other = { spells = { [99] = { overrides = { [7] = { loseSound = Logic.CustomValue(a.id) } } } } }
    eq("刪除清掉兩格", S.CustomRemove(1), 2)
    eq("刪除後剩一筆", #S.CustomList(), 1)
    check("本設定檔的格子清掉", ns.SpellSetting("essential", 5001, "readySound") ~= Logic.CustomValue(a.id))
    eq("別的音效不動", ns.SpellSetting("essential", 5001, "gainSound"), "Ding")
    check("別份設定檔的空覆寫整筆拿掉", sv.profiles.Other.spells[99].overrides[7] == nil)
    local c = S.CustomAdd("", "MyVoice\\c.ogg")
    check("刪掉的 id 不重用", c.id ~= a.id and c.id > b.id)
    -- 職業層／戰隊層的自訂項目（P8）：覆寫跟著那一筆走，刪語音時一樣要清
    sv.profiles.Other = {
        customShared = { { kind = "aura", spellID = 2825, uid = 1, overrides = { gainSound = Logic.CustomValue(c.id) } } },
        customClass = { MAGE = { { kind = "spell", spellID = 1, uid = 2,
                                   overrides = { readySound = Logic.CustomValue(c.id), procGlow = false } } } },
    }
    local ci
    for i, x in ipairs(S.CustomList()) do if x.id == c.id then ci = i end end
    eq("寬層：清掉兩格", S.CustomRemove(ci), 2)
    eq("寬層：空覆寫整張拿掉", sv.profiles.Other.customShared[1].overrides, nil)
    eq("寬層：別的覆寫不動", sv.profiles.Other.customClass.MAGE[1].overrides and sv.profiles.Other.customClass.MAGE[1].overrides.procGlow, false)
    sv.profiles.Other = nil
end

------------------------------------------------------------
-- 9. 施放後提醒（H3a／H3b）
------------------------------------------------------------
do
    -- 純函式：夾範圍與時間表
    eq("延遲：nil ＝ 0", Logic.CastDelay(nil), 0)
    eq("延遲：false ＝ 0", Logic.CastDelay(false), 0)
    eq("延遲：上限 60", Logic.CastDelay(99), 60)
    eq("延遲：下限 0", Logic.CastDelay(-3), 0)
    eq("延遲：四捨五入", Logic.CastDelay(4.6), 5)
    eq("倒數上限：延遲 0 ⇒ 0", Logic.CountdownMax(0), 0)
    eq("倒數上限：延遲 1 ⇒ 0", Logic.CountdownMax(1), 0)
    eq("倒數上限：延遲 3 ⇒ 2", Logic.CountdownMax(3), 2)
    eq("倒數上限：延遲 30 ⇒ 5", Logic.CountdownMax(30), 5)
    eq("倒數：延遲不夠就夾", Logic.Countdown(5, 3), 2)
    eq("倒數：false ＝ 0", Logic.Countdown(false, 10), 0)
    eq("倒數：負數 ＝ 0", Logic.Countdown(-1, 10), 0)
    eq("倒數：延遲夠照用", Logic.Countdown(3, 4), 3)
    local st = Logic.CastSteps(10, 3)
    eq("時間表：四筆", #st, 4)
    eq("時間表：第一聲 7 秒念 3", st[1].at .. ":" .. st[1].n, "7:3")
    eq("時間表：最後一聲在到點前 1 秒", st[3].at .. ":" .. st[3].n, "9:1")
    eq("時間表：最後一筆是提醒本身", st[4].at, 10)
    check("時間表：提醒本身沒有數字", st[4].n == nil)
    st = Logic.CastSteps(0, 5)
    eq("時間表：延遲 0 ⇒ 只有提醒、在當下", #st == 1 and st[1].at, 0)
    st = Logic.CastSteps(2, 5)
    eq("時間表：延遲 2 倒數夾成 1", #st, 2)
    eq("CastSpellID：三個參數", Logic.CastSpellID("guid", 123), 123)
    eq("CastSpellID：舊形狀兩個參數", Logic.CastSpellID(456, nil), 456)

    -- 引擎：假的計時器、語音、法術索引
    local timers = {}
    env.C_Timer = { NewTimer = function(d, fn)
        local t = { at = state.now + d, fn = fn }
        function t:Cancel() t.cancelled = true end
        timers[#timers + 1] = t
        return t
    end }
    local function Live()
        local n = 0
        for _, t in ipairs(timers) do if not t.cancelled and not t.done then n = n + 1 end end
        return n
    end
    -- 推進到 to：依時間順序觸發到點的計時器（觸發時排的新計時器也算）
    local function Advance(to)
        while true do
            local best
            for _, t in ipairs(timers) do
                if not t.cancelled and not t.done and t.at <= to and (not best or t.at < best.at) then best = t end
            end
            if not best then break end
            best.done = true
            state.now = best.at
            best.fn()
        end
        state.now = to
    end
    local spoken = {}
    env.C_VoiceChat = { SpeakText = function(_, text) spoken[#spoken + 1] = text end }
    env.C_TTSSettings = { GetVoiceOptionID = function() return 1 end }
    local idx = {}
    local origSI, origCatalog = ns.SpellIndex, ns.Catalog
    ns.SpellIndex = { Lookup = function(sid) return idx[sid] or {} end }
    local known = {}
    ns.Catalog = { Info = function() return { name = "測試法術" } end,
                   TalentKnown = function(tid) return known[tid] end }
    local secretVal = {}
    local origSecret = ns.IsSecret
    ns.IsSecret = function(v) return v == secretVal end

    local bRec = { cooldownID = 501, claimKey = "essential", barKey = "essential" }          -- 暴雪的冷卻格
    local auraRec = { cooldownID = 502, claimKey = "buffs", barKey = "buffs" }               -- 暴雪的增益
    local cRec = { custom = true, kind = "spell", cooldownID = "c:9", spellID = 777 }       -- 自訂法術
    local iRec = { custom = true, kind = "item", cooldownID = "c:10" }                     -- 自訂物品
    idx[100] = { { rec = bRec, key = "essential" } }                                         -- 基底
    idx[101] = { { rec = bRec, key = "essential" } }                                         -- 覆寫法術（同一格）
    idx[200] = { { rec = auraRec, key = "buffs" } }
    idx[777] = { { rec = cRec, key = "mygroup" } }
    idx[888] = { { rec = iRec, key = "mygroup" } }

    check("適用：暴雪冷卻格", S.CastCapable(bRec))
    check("適用：自訂法術", S.CastCapable(cRec))
    check("不適用：暴雪增益", not S.CastCapable(auraRec))
    check("不適用：自訂物品", not S.CastCapable(iRec))
    eq("SPELL_CONST：castSound false", DB.SPELL_CONST.castSound, false)
    eq("SPELL_CONST：castDelay 0", DB.SPELL_CONST.castDelay, 0)
    eq("SPELL_CONST：soundTalent false", DB.SPELL_CONST.soundTalent, false)
    eq("分組：castSound 在音效節", DB.OVERRIDE_GROUP.castSound, "sound")
    eq("分組：soundTalent 在音效節", DB.OVERRIDE_GROUP.soundTalent, "sound")

    -- 沒設 ⇒ 不聽事件
    S.SyncCast()
    check("沒設：不註冊施法事件", not (events.UNIT_SPELLCAST_SUCCEEDED and events.UNIT_SPELLCAST_SUCCEEDED.sound_cast))
    check("沒設：CastListening 假", not S.CastListening())
    -- 設了 ⇒ 註冊、綁 player
    DB.SetOverride(501, "castSound", "Ding")
    DB.SetOverride(501, "castDelay", 10)
    DB.SetOverride(501, "castCountdown", 3)
    S.SyncCast()
    check("設了：註冊施法事件", events.UNIT_SPELLCAST_SUCCEEDED and events.UNIT_SPELLCAST_SUCCEEDED.sound_cast ~= nil)
    eq("綁 player", eventUnits.UNIT_SPELLCAST_SUCCEEDED, "player")
    -- 寬層自訂項目身上的設定也算
    DB.SetOverride(501, "castSound", nil); DB.SetOverride(501, "castCountdown", nil); DB.SetOverride(501, "castDelay", nil)
    p.customShared = { { kind = "spell", spellID = 1, uid = 1, overrides = { castSpeak = true } } }
    S.SyncCast()
    check("寬層的設定也會註冊", S.CastListening())
    p.customShared = nil
    S.SyncCast()
    check("拿掉 ⇒ 撤事件", not S.CastListening())
    DB.SetOverride(501, "castSound", "Ding")
    DB.SetOverride(501, "castDelay", 10)
    DB.SetOverride(501, "castCountdown", 3)
    S.SyncCast()

    state.now = 1000
    local np = #plays
    S.OnCast("player", "guid", 999)
    eq("對不上的法術不排", S.CastPendingCount(), 0)
    S.OnCast("player", "guid", secretVal)
    eq("秘密 spellID 不排", S.CastPendingCount(), 0)
    eq("秘密 spellID 記次數", S.castSecret, 1)
    S.OnCast("player", "guid", 200)
    eq("增益格不排", S.CastPendingCount(), 0)
    S.OnCast("player", "guid", 101)
    eq("覆寫法術對得上那一格", S.CastPendingCount(), 1)
    eq("一次只排一顆計時器", Live(), 1)
    Advance(1006.9)
    eq("7 秒前不念", #spoken, 0)
    Advance(1007)
    eq("7 秒念 3", spoken[#spoken], "3")
    eq("念完只排下一顆", Live(), 1)
    Advance(1009)
    eq("9 秒念 1", spoken[#spoken], "1")
    eq("念了三聲", #spoken, 3)
    eq("提醒前不響", #plays, np)
    Advance(1010)
    eq("10 秒響", #plays, np + 1)
    eq("響的是設定的音效", plays[#plays].path, media.Ding)
    eq("響完清掉", S.CastPendingCount(), 0)
    eq("沒有殘留計時器", Live(), 0)

    -- restart：同一格再施放
    S.OnCast("player", "guid", 100)
    Advance(1015)
    S.OnCast("player", "guid", 100)
    eq("再施放：還是一格", S.CastPendingCount(), 1)
    eq("再施放：舊的取消、只剩一顆", Live(), 1)
    np = #plays
    Advance(1021)
    eq("從第二次施放重算（舊的 1020 不響）", #plays, np)
    Advance(1025)
    eq("第二次施放後 10 秒響", #plays, np + 1)

    -- 取消時機：讀取畫面、換專精、關總開關、拿掉設定
    S.OnCast("player", "guid", 100)
    FireEvent("LOADING_SCREEN_ENABLED")
    eq("讀取畫面：取消", S.CastPendingCount(), 0)
    eq("讀取畫面：計時器停了", Live(), 0)
    FireEvent("LOADING_SCREEN_DISABLED")
    state.now = 1100
    S.OnCast("player", "guid", 100)
    S.CancelAllCasts()                               -- SpecChanged／ProfileChanged 走這支
    eq("全部取消", Live(), 0)
    S.OnCast("player", "guid", 100)
    p.theme.sound.enabled = false
    S.SyncCast()
    eq("總開關關掉：取消", S.CastPendingCount(), 0)
    check("總開關關掉：撤事件", not S.CastListening())
    p.theme.sound.enabled = true
    S.SyncCast()
    S.OnCast("player", "guid", 100)
    DB.SetOverride(501, "castSound", nil); DB.SetOverride(501, "castCountdown", nil)
    S.SyncCast()
    eq("那一格拿掉設定：取消", S.CastPendingCount(), 0)

    -- 延遲 0：施放當下（下一個計時器 tick）響；語音照設定念
    DB.SetOverride(501, "castDelay", 0)
    DB.SetOverride(501, "castSpeak", "好了")
    S.SyncCast()
    state.now = 1200
    S.OnCast("player", "guid", 100)
    Advance(1200)
    eq("延遲 0：當下念", spoken[#spoken], "好了")
    DB.SetOverride(501, "castSpeak", nil); DB.SetOverride(501, "castDelay", nil)

    -- 自訂法術
    DB.SetOverride("c:9", "castSound", "Bell")
    DB.SetOverride("c:9", "castDelay", 2)
    S.SyncCast()
    state.now = 1300
    np = #plays
    S.OnCast("player", "guid", 777)
    Advance(1302)
    eq("自訂法術：2 秒後響", #plays, np + 1)
    eq("自訂法術：響的是它的音效", plays[#plays].path, media.Bell)
    DB.SetOverride("c:9", "castSound", nil); DB.SetOverride("c:9", "castDelay", nil)

    ------------------------------------------------------------
    -- 10. 音效的天賦條件（H3c）
    ------------------------------------------------------------
    eq("天賦條件：false ＝ 不限", Logic.TalentCond(false), nil)
    eq("天賦條件：沒有 ID ＝ 不限", Logic.TalentCond({ need = true }), nil)
    eq("天賦條件：need 不是布林 ＝ 不限", Logic.TalentCond({ id = 5, need = "x" }), nil)
    eq("天賦條件：合法", Logic.TalentCond({ id = 5, need = false }), 5)
    check("有才響：有 ⇒ 過", Logic.TalentPass({ id = 5, need = true }, true))
    check("有才響：沒有 ⇒ 擋", not Logic.TalentPass({ id = 5, need = true }, false))
    check("沒有才響：沒有 ⇒ 過", Logic.TalentPass({ id = 5, need = false }, false))
    check("沒有才響：有 ⇒ 擋", not Logic.TalentPass({ id = 5, need = false }, true))
    check("讀不到 ⇒ 過（fail-open）", Logic.TalentPass({ id = 5, need = true }, nil))

    known[4242] = false
    DB.SetOverride(501, "soundTalent", { id = 4242, need = true })
    check("沒學 ⇒ TalentOK 假", not S.TalentOK(501))
    check("沒設條件的格 ⇒ TalentOK 真", S.TalentOK(502))

    -- 就緒
    state.now = 1400
    DB.SetOverride(501, "readySound", "Ding")
    np = #plays
    S.OnReady({ cooldownID = 501, claimKey = "essential" })
    eq("天賦閘：就緒不響", #plays, np)
    -- 施放後
    DB.SetOverride(501, "castSound", "Ding")
    S.SyncCast()
    S.OnCast("player", "guid", 100)
    eq("天賦閘：施放後不排", S.CastPendingCount(), 0)
    -- 出現／消失（暴雪的冷卻格走同一個批次）
    DB.SetOverride(501, "gainSound", "Ding")
    local fr = { cooldownID = 501, barKey = "essential" }
    S.OnAuraFlag(fr, false); S.OnAuraFlag(fr, true); Flush()
    eq("天賦閘：出現不響", #plays, np)
    -- 快取：觸發時只查快取 ⇒ 改了 API 回答不會馬上生效，要等天賦事件重算
    known[4242] = true
    check("快取：事件前還是舊的", not S.TalentOK(501))
    FireEvent("TRAIT_CONFIG_UPDATED"); Flush()
    check("快取：天賦事件後重算", S.TalentOK(501))
    state.now = 1410
    S.OnReady({ cooldownID = 501, claimKey = "essential" })
    eq("學了 ⇒ 就緒響", #plays, np + 1)
    S.OnCast("player", "guid", 100)
    eq("學了 ⇒ 施放後排了", S.CastPendingCount(), 1)
    S.CancelAllCasts()
    -- 沒有才響
    DB.SetOverride(501, "soundTalent", { id = 4242, need = false })
    check("沒有才響：學了 ⇒ 擋", not S.TalentOK(501))
    DB.SetOverride(501, "soundTalent", nil)
    for _, f in ipairs({ "readySound", "castSound", "gainSound" }) do DB.SetOverride(501, f, nil) end
    S.SyncCast()

    -- 充能滿
    do
        local G = ns.Glow
        local fullState = false
        ns.Glow = { FullSpellOf = function() return 9 end, ReadFull = function() return true, fullState end }
        DB.SetOverride(503, "fullSound", "Ding")
        DB.SetOverride(503, "soundTalent", { id = 4243, need = true })
        known[4243] = false
        local fRec = { cooldownID = 503, claimKey = "essential" }
        S.SyncFull(fRec, "essential", false)
        fullState = true
        np = #plays
        state.now = 1500
        S.OnChargesChanged()
        eq("天賦閘：充能滿不響", #plays, np)
        S.UnwatchFull(fRec)
        DB.SetOverride(503, "fullSound", nil); DB.SetOverride(503, "soundTalent", nil)
        ns.Glow = G
    end

    -- 光環格：對帳時排除；天賦變了重對帳
    for k in pairs(customRecs) do customRecs[k] = nil end
    customRecs.g = { kind = "aura", placedBar = "buffs", cooldownID = "c:20", spellID = 6000 }
    DB.SetOverride("c:20", "gainSound", "Ding")
    DB.SetOverride("c:20", "soundTalent", { id = 4244, need = true })
    known[4244] = false
    S.RequestAuraSync(); Flush()
    eq("光環格：天賦不過不登記", S.AuraCount(), 0)
    known[4244] = true
    FireEvent("PLAYER_TALENT_UPDATE"); Flush(); Flush()
    eq("光環格：學了天賦 ⇒ 重對帳登記", S.AuraCount(), 1)
    known[4244] = false
    FireEvent("SPELLS_CHANGED"); Flush(); Flush()
    eq("光環格：忘了天賦 ⇒ 重對帳撤掉", S.AuraCount(), 0)
    local before = nextID
    FireEvent("SPELLS_CHANGED"); Flush(); Flush()
    eq("天賦沒變：不重對帳", nextID, before)
    DB.SetOverride("c:20", "gainSound", nil); DB.SetOverride("c:20", "soundTalent", nil)
    customRecs.g = nil

    ns.SpellIndex, ns.Catalog, ns.IsSecret = origSI, origCatalog, origSecret
    env.C_Timer, env.C_VoiceChat, env.C_TTSSettings = nil, nil, nil
end

check("DebugLine 是字串", type(S.DebugLine()) == "string")

print(("Sound_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
