------------------------------------------------------------
-- Core/Sound.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Sound_test.lua
--
-- 覆蓋：節流（1.5 秒、被擋那次不延長窗口）、讀取畫面中與結束後 2 秒靜音、同一批「消失又出現」
-- 合併抵消（純函式與實際掛勾路徑）、AddAuraSound 對帳（多的撤、少的登、戰鬥中與秘密光環時延後、
-- 進場全部重登）、逐法術覆寫的讀寫與分組（Core/DB.lua 一起載）、主題預設值、LSM 回數字也能播。
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
local customRecs = {}
local ns = {
    playerClass = "PALADIN",
    Events = {
        Register = function(ev, key, fn) events[ev] = events[ev] or {}; events[ev][key] = fn end,
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
ns.Custom.AuraIDsOf = nil

------------------------------------------------------------
-- 自訂語音
------------------------------------------------------------
do
    local N = Logic.NormalizePath
    eq("路徑：相對路徑照收", N("MyVoice\\kick.ogg"), "MyVoice\\kick.ogg")
    eq("路徑：斜線轉反斜線、去頭尾空白", N("  MyVoice/sub/kick.mp3 "), "MyVoice\\sub\\kick.mp3")
    eq("路徑：去掉 Interface\\AddOns\\", N("Interface\\AddOns\\MyVoice\\kick.ogg"), "MyVoice\\kick.ogg")
    eq("路徑：大小寫不拘", N("interface/addons/MyVoice/kick.OGG"), "MyVoice\\kick.OGG")
    eq("路徑：AddOns\\ 開頭", N("AddOns\\MyVoice\\kick.ogg"), "MyVoice\\kick.ogg")
    eq("路徑：整段絕對路徑", N("\"C:\\Program Files\\World of Warcraft\\_retail_\\Interface\\AddOns\\MyVoice\\kick.ogg\""), "MyVoice\\kick.ogg")
    eq("路徑：重複反斜線收成一個", N("MyVoice\\\\kick.ogg"), "MyVoice\\kick.ogg")
    local r, why = N("MyVoice\\kick.wav")
    check("路徑：wav 不收", r == nil and why == "ext", why)
    r, why = N("   ")
    check("路徑：空白不收", r == nil and why == "empty", why)
    r, why = N("Interface\\AddOns\\")
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
    eq("Path：自訂語音解成完整路徑", S.Path(Logic.CustomValue(a.id)), "Interface\\AddOns\\MyVoice\\kick.ogg")
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
    check("編輯", S.CustomEdit(1, "Kick!", "MyVoice\\kick2.ogg"))
    eq("編輯後名字", S.CustomList()[1].name, "Kick!")
    eq("編輯後格子解到新路徑", S.Path(S.NameOf("essential", 5001, "readySound")), "Interface\\AddOns\\MyVoice\\kick2.ogg")
    check("編輯不合法的路徑：不動", S.CustomEdit(1, "x", "") == nil and S.CustomList()[1].path == "MyVoice\\kick2.ogg")

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
    sv.profiles.Other = nil
end

check("DebugLine 是字串", type(S.DebugLine()) == "string")

print(("Sound_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
