------------------------------------------------------------
-- 冷卻狀態效果（Core/Decorate.lua）與法術索引（Core/SpellIndex.lua）的離線自我測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/CooldownState_test.lua
--
-- 覆蓋：模式 × 狀態 → 兩個 alpha（StateAlphas）、預覽格的 alpha、適用的模式、
-- 「真的在冷卻」的判斷順序（明文旗標 → 秘密布林 → 類別項目的欄位；裝備欄另一條）、
-- ApplyItemAlpha（明文／秘密／判不出來／編輯模式／沒設）、提示的 stateHidden、
-- 法術索引的建表與查詢、事件參數的分類（精準 vs 全掃）、同一幀合併、
-- SPELL_UPDATE_COOLDOWN 的精準重算只跑命中的那幾格、自訂框的 ApplyState 與精準標髒。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

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
local function near(name, got, want)
    check(name, type(got) == "number" and math.abs(got - want) < 1e-9, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- 秘密值的替身：一張帶記號的表（IsSecret 認得它；Plain 讀不到）
------------------------------------------------------------
local function Secret(v) return { __secret = true, v = v } end
local function IsSecret(v) return type(v) == "table" and v.__secret == true end

------------------------------------------------------------
-- WoW API stub
------------------------------------------------------------
local env = setmetatable({}, { __index = _G })
env._G = env
local cooldowns = {}        -- spellID → { isActive, isOnGCD }
local durZero = {}          -- spellID → IsZero 的回傳（可以是 Secret(...)）
local timers = {}
env.C_Spell = {
    GetSpellCooldown = function(id) return cooldowns[id] end,
    GetSpellCooldownDuration = function(id)
        if durZero[id] == nil then return nil end
        return { IsZero = function() return durZero[id] end }
    end,
}
env.C_Timer = { After = function(t, fn) timers[#timers + 1] = fn end }
env.GetTime = function() return 100 end
env.hooksecurefunc = function() end
env.CreateFrame = function() return {} end

local handlers = {}
local callbacks = {}
local infos = {}            -- cooldownID → info
local claimed = {}          -- key → { { item, rec }, … }
local placed = {}           -- 自訂框 { frame, rec, key }
local ns = {
    IsSecret = IsSecret,
    Events = { Register = function(ev, key, fn) handlers[ev .. "|" .. key] = fn end },
    Defer = function(fn, ...) fn(...) end,
    Fire = function() end,
    RegisterCallback = function(ev, key, fn) callbacks[ev .. "|" .. key] = fn end,
    ReportError = function(err) print("ReportError: " .. tostring(err)) end,
    Catalog = { Info = function(id) return infos[id] end },
    Viewers = { frames = setmetatable({}, { __mode = "k" }), AURA_KIND = { buffs = true, buffbars = true } },
    Bars = {
        ForEachClaimed = function(key, fn)
            for _, e in ipairs(claimed[key] or {}) do fn(e[1], e[2]) end
        end,
    },
    EditMode = { active = false },
    Visibility = { Current = function() return 0.8 end },
}
ns.profile = { bars = { essential = {}, utility = {} } }

local function Load(rel)
    local path = here .. "/../" .. rel
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
Load("Core/SpellIndex.lua")
Load("Core/Decorate.lua")
local D, SI = ns.Decorate, ns.SpellIndex

-- 假的 item：記下最後一次 alpha 寫入
local function Item()
    local it = { log = {} }
    function it:SetAlpha(a) self.alpha = a; self.fromBool = nil; self.log[#self.log + 1] = a end
    function it:SetAlphaFromBoolean(b, t, f) self.fromBool = { b, t, f }; self.alpha = nil end
    return it
end

------------------------------------------------------------
-- 1. 模式 × 狀態 → 兩個 alpha
------------------------------------------------------------
do
    local cd, ready = D.StateAlphas("dim", 0.4, 1)
    near("dim：冷卻中 ＝ x", cd, 0.4); near("dim：轉好 ＝ 條", ready, 1)
    cd, ready = D.StateAlphas("dim", 0.5, 0.6)
    near("dim × 淡出 ＝ 相乘", cd, 0.3); near("dim 轉好 ＝ 條的 alpha", ready, 0.6)
    cd, ready = D.StateAlphas("dim", nil, 1)
    near("dim 沒給透明度 ＝ 0.4", cd, 0.4)
    cd = D.StateAlphas("dim", 2, 1)
    near("dim 透明度超過 1 夾回 1", cd, 1)
    cd = D.StateAlphas("dim", -1, 1)
    near("dim 透明度小於 0 夾回 0", cd, 0)
    cd, ready = D.StateAlphas("hideOnCD", 0.4, 0.7)
    eq("hideOnCD：冷卻中 0", cd, 0); near("hideOnCD：轉好 ＝ 條", ready, 0.7)
    cd, ready = D.StateAlphas("hideReady", 0.4, 0.7)
    near("hideReady：冷卻中 ＝ 條", cd, 0.7); eq("hideReady：轉好 0", ready, 0)
    eq("none 不適用", D.StateAlphas("none", 0.4, 1), nil)
    eq("未知值不適用", D.StateAlphas("blink", 0.4, 1), nil)
    eq("條的 alpha 沒給當 1", select(2, D.StateAlphas("hideOnCD", 0.4, nil)), 1)
end

------------------------------------------------------------
-- 2. 預覽格、適用的模式
------------------------------------------------------------
near("預覽 dim 冷卻中", D.PreviewStateAlpha("dim", 0.3, true), 0.3)
eq("預覽 dim 轉好", D.PreviewStateAlpha("dim", 0.3, false), 1)
eq("預覽 hideOnCD 冷卻中畫 0.25", D.PreviewStateAlpha("hideOnCD", 0.4, true), 0.25)
eq("預覽 hideOnCD 轉好", D.PreviewStateAlpha("hideOnCD", 0.4, false), 1)
eq("預覽 hideReady 冷卻中", D.PreviewStateAlpha("hideReady", 0.4, true), 1)
eq("預覽 hideReady 轉好畫 0.25", D.PreviewStateAlpha("hideReady", 0.4, false), 0.25)
eq("預覽 none", D.PreviewStateAlpha(nil, 0.4, true), 1)
eq("StateMode none ＝ nil", D.StateMode("none"), nil)
eq("StateMode nil", D.StateMode(nil), nil)
eq("StateMode dim", D.StateMode("dim"), "dim")
eq("StateMode false", D.StateMode(false), nil)

------------------------------------------------------------
-- 3. 「真的在冷卻」
------------------------------------------------------------
infos[1] = { spellID = 100 }
infos[2] = { spellID = 200, overrideSpellID = 201 }
infos[3] = {}                                   -- 類別項目（沒有法術）
local rec1, rec2, rec3 = { cooldownID = 1 }, { cooldownID = 2 }, { cooldownID = 3 }
cooldowns[100] = { isActive = true, isOnGCD = false }
local k, v = D.CooldownState({}, rec1)
eq("明文：真冷卻", k, "plain"); eq("明文：真冷卻 onCD", v, true)
cooldowns[100] = { isActive = true, isOnGCD = true }
k, v = D.CooldownState({}, rec1)
eq("明文：只是 GCD ⇒ 不算", v, false)
cooldowns[100] = { isActive = false, isOnGCD = false }
eq("明文：沒在冷卻（含還有充能）", select(2, D.CooldownState({}, rec1)), false)
-- 覆寫法術優先
cooldowns[201] = { isActive = true, isOnGCD = false }
cooldowns[200] = { isActive = false, isOnGCD = false }
eq("問覆寫後的法術", select(2, D.CooldownState({}, rec2)), true)
-- 旗標讀不到 ⇒ 秘密布林
cooldowns[100] = { isActive = Secret(true), isOnGCD = Secret(false) }
local z = Secret(true)
durZero[100] = z
k, v = D.CooldownState({}, rec1)
eq("秘密：走 duration", k, "secret"); check("秘密：原封轉交", v == z)
durZero[100] = false
k, v = D.CooldownState({}, rec1)
eq("duration 明文 ⇒ plain", k, "plain"); eq("IsZero false ⇒ 冷卻中", v, true)
durZero[100] = nil
eq("都讀不到 ⇒ nil", D.CooldownState({}, rec1), nil)
-- 類別項目：暴雪的明文欄位
k, v = D.CooldownState({ isOnActualCooldown = true }, rec3)
eq("類別項目：欄位", k, "plain"); eq("類別項目：值", v, true)
eq("類別項目：欄位是秘密 ⇒ nil", D.CooldownState({ isOnActualCooldown = Secret(true) }, rec3), nil)
eq("類別項目：沒欄位 ⇒ nil", D.CooldownState({}, rec3), nil)
eq("沒有 info ⇒ nil", D.CooldownState({}, { cooldownID = 999 }), nil)

------------------------------------------------------------
-- 4. ApplyItemAlpha
------------------------------------------------------------
do
    local it = Item()
    local r = { cooldownID = 1, claimKey = "essential", style = { cdState = "dim", cdAlpha = 0.5 } }
    cooldowns[100] = { isActive = true, isOnGCD = false }
    D.ApplyItemAlpha(it, r, 0.8)
    near("dim 冷卻中 ＝ 0.8 × 0.5", it.alpha, 0.4)
    eq("dim 不算藏", r.stateHidden, false)
    cooldowns[100] = { isActive = false, isOnGCD = false }
    D.ApplyItemAlpha(it, r, 0.8)
    near("dim 轉好 ＝ 條", it.alpha, 0.8)
    r.style.cdState = "hideOnCD"
    cooldowns[100] = { isActive = true, isOnGCD = false }
    D.ApplyItemAlpha(it, r, 1)
    eq("hideOnCD 冷卻中 0", it.alpha, 0)
    eq("hideOnCD 冷卻中 ⇒ stateHidden", r.stateHidden, true)
    -- 秘密值
    cooldowns[100] = { isActive = Secret(true), isOnGCD = Secret(false) }
    local zz = Secret(false)
    durZero[100] = zz
    D.ApplyItemAlpha(it, r, 1)
    check("秘密：SetAlphaFromBoolean", it.fromBool ~= nil)
    check("秘密：布林原封轉交", it.fromBool and it.fromBool[1] == zz)
    eq("秘密：真（冷卻是零）⇒ 轉好的 alpha", it.fromBool and it.fromBool[2], 1)
    eq("秘密：假 ⇒ 冷卻中的 alpha", it.fromBool and it.fromBool[3], 0)
    eq("秘密：不知道藏了沒", r.stateHidden, nil)
    eq("秘密：記下不讀回", r.alphaSecret, true)
    -- 判不出來 ⇒ 條的 alpha
    durZero[100] = nil
    D.ApplyItemAlpha(it, r, 0.7)
    near("判不出來 ⇒ 條", it.alpha, 0.7)
    -- 編輯模式全亮（只跟條）
    cooldowns[100] = { isActive = true, isOnGCD = false }
    ns.EditMode.active = true
    D.ApplyItemAlpha(it, r, 1)
    eq("編輯模式中不套", it.alpha, 1)
    eq("編輯模式中不算藏", r.stateHidden, nil)
    ns.EditMode.active = false
    -- 沒設
    r.style.cdState = nil
    D.ApplyItemAlpha(it, r, 0.5)
    eq("沒設 ⇒ 條的 alpha", it.alpha, 0.5)
    -- barAlpha 沒給 ⇒ Visibility.Current
    D.ApplyItemAlpha(it, r)
    near("沒給 ⇒ 條現在的 alpha", it.alpha, 0.8)
    -- 沒有 SetAlphaFromBoolean 的退路
    r.style.cdState = "hideReady"
    cooldowns[100] = { isActive = Secret(true), isOnGCD = Secret(false) }
    durZero[100] = Secret(true)
    local plain = Item(); plain.SetAlphaFromBoolean = nil
    D.ApplyItemAlpha(plain, r, 0.9)
    near("沒有 SetAlphaFromBoolean ⇒ 條", plain.alpha, 0.9)
    -- hideReady 轉好（明文）
    cooldowns[100] = { isActive = false, isOnGCD = false }
    D.ApplyItemAlpha(it, r, 1)
    eq("hideReady 轉好 0", it.alpha, 0)
    eq("hideReady 轉好 ⇒ stateHidden", r.stateHidden, true)
end

------------------------------------------------------------
-- 5. 法術索引
------------------------------------------------------------
do
    local A, B, C = { n = "A" }, { n = "B" }, { n = "C" }
    local idx = SI.Build({
        { ids = { 10, 11 }, owner = "ia", rec = A, key = "essential" },
        { ids = { 10, 10, nil }, owner = "ib", rec = B, key = "utility" },
        { ids = { 20, "x", 20.5 }, owner = "ic", rec = C, key = "g1" },
    })
    eq("10 有兩格", #(idx[10] or {}), 2)
    eq("11 有一格", #(idx[11] or {}), 1)
    eq("同一格同 ID 不重複", idx[10][2].rec, B)
    eq("非數字不收", idx["x"], nil)
    eq("小數照收（明文數字）", #(idx[20.5] or {}), 1)
    local function lk(id) return idx[id] end
    -- 分類
    eq("spellID nil ⇒ 全掃", SI.Classify(lk, IsSecret, nil), nil)
    eq("spellID 秘密 ⇒ 全掃", SI.Classify(lk, IsSecret, Secret(10)), nil)
    eq("baseSpellID 秘密 ⇒ 全掃", SI.Classify(lk, IsSecret, 10, Secret(10)), nil)
    eq("帶 category ⇒ 全掃", SI.Classify(lk, IsSecret, 10, nil, 5), nil)
    eq("帶 GCD 類別 ⇒ 全掃", SI.Classify(lk, IsSecret, 10, nil, nil, 133), nil)
    eq("帶 itemID ⇒ 全掃", SI.Classify(lk, IsSecret, 10, nil, nil, nil, 5512), nil)
    eq("查不到 ⇒ 全掃", SI.Classify(lk, IsSecret, 99), nil)
    eq("spellID 不是數字 ⇒ 全掃", SI.Classify(lk, IsSecret, "10"), nil)
    local hits = SI.Classify(lk, IsSecret, 10)
    eq("命中兩格", hits and #hits, 2)
    hits = SI.Classify(lk, IsSecret, 99, 11)
    eq("覆寫查不到、基底查得到", hits and #hits, 1)
    hits = SI.Classify(lk, IsSecret, 11, 10)
    eq("覆寫＋基底合併去重", hits and #hits, 2)
    -- 合併
    local batch = SI.NewBatch()
    SI.Add(batch, lk, IsSecret, 11)
    SI.Add(batch, lk, IsSecret, 20)
    local all, set = SI.Take(batch)
    eq("兩次精準 ⇒ 不全掃", all, false)
    local n = 0; for _ in pairs(set) do n = n + 1 end
    eq("兩次精準 ⇒ 兩格", n, 2)
    SI.Add(batch, lk, IsSecret, 11)
    SI.Add(batch, lk, IsSecret, nil)
    SI.Add(batch, lk, IsSecret, 20)
    all, set = SI.Take(batch)
    eq("任何一次全掃 ⇒ 全掃", all, true)
    check("全掃時不帶清單", next(set) == nil)
    all = SI.Take(batch)
    eq("Take 之後清空", all, false)
    -- Lookup 的空表
    eq("Lookup 非數字 ⇒ 空表", #SI.Lookup(nil), 0)
    check("空表唯讀", not pcall(function() SI.Lookup(nil)[1] = 1 end))
end

-- Rebuild：暴雪 item（spellID＋override）與自訂法術（spellID＋overrideID），只收認領中／放好的
do
    local itA, itB = Item(), Item()
    local rA = { cooldownID = 1, claimKey = "essential", style = { cdState = "hideOnCD", cdAlpha = 0.4 } }
    local rB = { cooldownID = 2, claimKey = "utility", style = { hideGCD = false } }
    ns.Viewers.frames[itA], ns.Viewers.frames[itB] = rA, rB
    claimed.essential = { { itA, rA } }
    claimed.utility = { { itB, rB } }
    local cf = Item()
    local crec = { custom = true, kind = "spell", spellID = 300, overrideID = 301, placedBar = "essential" }
    ns.Custom = { ForEachPlaced = function(fn) fn(cf, crec, "essential") end }
    -- SI.dirty（效能 #6）：剛載入是髒的（第一輪一定建）；Rebuild 清掉；外部標髒後再建又清
    eq("SI.dirty：剛載入是髒的", SI.dirty, true)
    local rb0 = SI.rebuilds
    SI.Rebuild()
    eq("SI.dirty：Rebuild 清掉", SI.dirty, false)
    eq("Rebuild 計數 +1", SI.rebuilds, rb0 + 1)
    SI.dirty = true               -- 目錄重建／自訂法術換覆寫會這樣標
    SI.Rebuild()
    eq("Rebuild：暴雪 spellID", SI.Lookup(100)[1].rec, rA)
    eq("Rebuild：暴雪 override", SI.Lookup(201)[1].rec, rB)
    eq("Rebuild：暴雪基底也收", SI.Lookup(200)[1].rec, rB)
    eq("Rebuild：自訂 spellID", SI.Lookup(300)[1].rec, crec)
    eq("Rebuild：自訂 override", SI.Lookup(301)[1].owner, cf)
    eq("Rebuild：別的沒有", #SI.Lookup(555), 0)
    eq("SI.dirty：再建一次又清掉", SI.dirty, false)

    -- SPELL_UPDATE_COOLDOWN：唯一的處理器在 SpellIndex（E3 #8）；精準只跑命中的那一格、全掃只走 D.cdWork
    local h = handlers["SPELL_UPDATE_COOLDOWN|spellindex"]
    check("SpellIndex 有註冊冷卻事件", type(h) == "function")
    check("Decorate 不再自己註冊", handlers["SPELL_UPDATE_COOLDOWN|decorate_gcd"] == nil)
    -- 全掃清單：rA 設了冷卻狀態（D.Apply 會存 cdNeed，這裡直接給）、rB 什麼都沒設
    rA.cdNeed, rB.cdNeed = true, false
    D.CdWorkSync(rA, itA)
    D.CdWorkSync(rB, itB)
    eq("cdWork：設了冷卻狀態的格收進來", D.cdWork[rA], itA)
    eq("cdWork：什麼都沒設的不收", D.cdWork[rB], nil)
    cooldowns[100] = { isActive = true, isOnGCD = false }
    itA.log = {}; itB.log = {}
    local full0, prec0 = SI.full, SI.precise
    h(201)             -- 命中 rB（沒設冷卻狀態也沒隱藏 GCD ⇒ 什麼都不做）
    eq("精準：一次", SI.precise, prec0 + 1)
    eq("精準：沒命中的格不動", #itA.log, 0)
    h(100)
    eq("精準：命中的格重算", itA.alpha, 0)
    h(nil)
    eq("全掃：一次", SI.full, full0 + 1)
    eq("全掃：設了冷卻狀態的格重算", #itA.log, 2)
    eq("全掃：沒設的格不動", #itB.log, 0)
    -- 停放的不碰
    rA.parked = true
    h(100)
    eq("停放的格不動", #itA.log, 2)
    rA.parked = false

    -- RefreshState：探針只拿得到 rec ⇒ 要先經過一次 Apply 記下 item（這裡直接驗退路：沒記 ⇒ 不動、不報錯）
    timers = {}
    D.RefreshState(rA)
    eq("沒記過 item ⇒ 不動", #itA.log, 2)
    eq("排一次補算", #timers, 1)
    timers[1]()
    eq("補算不再排", #timers, 1)
    D.RefreshState({ style = {} })           -- 沒設 ⇒ 什麼都不做
    eq("沒設不排補算", #timers, 1)
end

------------------------------------------------------------
-- 6. 自訂框：ApplyState 與精準標髒
------------------------------------------------------------
env.UIParent = {}
Load("Modules/Custom.lua")
local CU = ns.Custom
do
    local f = Item()
    local rec = { kind = "spell", spellID = 400, frame = f, placedBar = "essential", known = true,
                  style = { cdState = "dim", cdAlpha = 0.3 } }
    cooldowns[400] = { isActive = true, isOnGCD = false }
    CU.ApplyState(rec)
    near("自訂法術 dim 冷卻中（容器帶淡出 ⇒ 條當 1）", f.alpha, 0.3)
    cooldowns[400] = { isActive = true, isOnGCD = true }
    CU.ApplyState(rec)
    eq("自訂法術 GCD 不算", f.alpha, 1)
    rec.known = false
    cooldowns[400] = { isActive = true, isOnGCD = false }
    CU.ApplyState(rec)
    eq("未學會不套", f.alpha, 1)
    rec.known = true
    cooldowns[400] = { isActive = Secret(true), isOnGCD = Secret(false) }
    local zz = Secret(true)
    rec.dur = { IsZero = function() return zz end }
    CU.ApplyState(rec)
    check("自訂法術秘密 ⇒ SetAlphaFromBoolean", f.fromBool and f.fromBool[1] == zz)
    near("自訂法術秘密：轉好 alpha 1", f.fromBool and f.fromBool[2], 1)
    near("自訂法術秘密：冷卻中 alpha 0.3", f.fromBool and f.fromBool[3], 0.3)
    rec.dur = nil
    CU.ApplyState(rec)
    eq("自訂法術判不出來 ⇒ 1", f.alpha, 1)
    -- 物品
    local g = Item()
    local irec = { kind = "item", itemID = 5512, frame = g, placedBar = "essential",
                   style = { cdState = "hideReady", cdAlpha = 0.4 }, cdOnCD = false }
    CU.ApplyState(irec)
    eq("自訂物品 hideReady 轉好 0", g.alpha, 0)
    eq("自訂物品藏了", irec.stateHidden, true)
    irec.cdOnCD = true
    CU.ApplyState(irec)
    eq("自訂物品 hideReady 冷卻中 1", g.alpha, 1)
    irec.cdOnCD = nil
    CU.ApplyState(irec)
    eq("空的飾品欄（沒有 onCD）⇒ 1", g.alpha, 1)
    ns.EditMode.active = true
    irec.cdOnCD = false
    CU.ApplyState(irec)
    eq("自訂物品編輯模式中 1", g.alpha, 1)
    ns.EditMode.active = false
    irec.style.cdState = nil
    CU.ApplyState(irec)
    eq("自訂物品沒設 ⇒ 1", g.alpha, 1)
    eq("光環格不碰", CU.ApplyState({ kind = "aura", frame = Item(), style = { cdState = "dim" } }), nil)

    -- 精準標髒：只標命中的那一筆自訂法術；讀不懂就全標（records 裡沒東西時不報錯）
    local hitRec = { custom = true, kind = "spell" }
    local otherRec = { custom = true, kind = "spell" }
    local blizzRec = {}
    local saved = SI.Lookup
    SI.Lookup = function(id)
        if id == 777 then return { { rec = hitRec }, { rec = blizzRec } } end
        return SI.EMPTY
    end
    local b = SI.NewBatch()
    SI.Add(b, SI.Lookup, IsSecret, 777)
    local all, set = SI.Take(b)
    CU.OnCooldownBatch(all, set)
    eq("精準：命中的自訂法術標髒", hitRec.dirty, true)
    eq("精準：沒命中的不標", otherRec.dirty, nil)
    eq("精準：暴雪 item 不歸 Custom 管", blizzRec.dirty, nil)
    check("全掃不報錯", pcall(CU.OnCooldownBatch, true, {}))
    SI.Lookup = saved
end

------------------------------------------------------------
-- 7. Decorate.Apply 的前置鍵（效能修整 E2 #3）：八欄逐一變動都 miss；rec.decorated 被清掉（強制重套）也 miss
------------------------------------------------------------
do
    local base = { 3, 7, 101, 40, 36, nil, "essential", false }
    local function Args(i, v)
        local a = { base[1], base[2], base[3], base[4], base[5], base[6], base[7], base[8] }
        if i then a[i] = v end
        return a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]
    end
    local rec = { decorated = "sig" }
    D.PreKeyStore(rec, Args())
    check("前置鍵：八欄全等 ⇒ 中", D.PreKeyMatch(rec, Args()))
    local changes = {
        { 1, 4,           "條層樣式世代（styleGen）" },
        { 2, 8,           "覆寫世代（overrideGen）" },
        { 3, 102,         "cooldownID" },
        { 4, 41,          "寬" },
        { 5, 37,          "高" },
        { 6, 555,         "頂著的 A（replacing）" },
        { 7, "utility",   "barKey" },
        { 8, true,        "Masque 作用中" },
    }
    for _, c in ipairs(changes) do
        check("前置鍵：" .. c[3] .. " 變了 ⇒ 不中", not D.PreKeyMatch(rec, Args(c[1], c[2])))
    end
    -- nil ↔ 值也算變（cooldownID、replacing 會是 nil）
    D.PreKeyStore(rec, Args(6, 555))
    check("前置鍵：replacing 值 → nil ⇒ 不中", not D.PreKeyMatch(rec, Args()))
    D.PreKeyStore(rec, Args())
    rec.decorated = nil
    check("前置鍵：rec.decorated 被清掉（強制重套）⇒ 不中", not D.PreKeyMatch(rec, Args()))
    check("前置鍵：從沒存過 ⇒ 不中", not D.PreKeyMatch({ decorated = "sig" }, Args()))
end

------------------------------------------------------------
-- 效果不在時變暗（dimNoAura）：條的 alpha 乘上變暗透明度，冷卻狀態照常疊上去
------------------------------------------------------------
do
    eq("auraMissing 不是冷卻狀態的模式", D.StateMode("auraMissing"), nil)
    local it = Item()
    local r = { cooldownID = 1, claimKey = "essential", style = { dimNoAura = true, cdAlpha = 0.5 } }
    cooldowns[100] = { isActive = true, isOnGCD = false }
    D.ApplyItemAlpha(it, r, 1)
    near("沒旗標 ⇒ 變暗", it.alpha, 0.5)
    r.auraFlag = true
    D.ApplyItemAlpha(it, r, 1)
    near("旗標在 ⇒ 全亮（冷卻中也一樣）", it.alpha, 1)
    r.auraFlag = false
    D.ApplyItemAlpha(it, r, 0.8)
    near("旗標掉了 ⇒ 條 × 透明度", it.alpha, 0.4)
    -- 跟冷卻中變暗疊：0.8 × 0.5（效果不在）× 0.5（冷卻中）
    r.style.cdState = "dim"
    D.ApplyItemAlpha(it, r, 0.8)
    near("兩個都開 ⇒ 相乘", it.alpha, 0.2)
    cooldowns[100] = { isActive = false, isOnGCD = false }
    D.ApplyItemAlpha(it, r, 0.8)
    near("轉好但效果不在 ⇒ 只乘一次", it.alpha, 0.4)
    r.style.cdState = nil
    ns.EditMode.active = true
    D.ApplyItemAlpha(it, r, 1)
    eq("編輯模式中不套", it.alpha, 1)
    ns.EditMode.active = false
end

------------------------------------------------------------
-- 8. 效能修整 E3 #8：SI.Subscribe 派送、沒事做時不排批次、GCD 開始的精準分類（SI.ClassifyGCD）、cdWork 的維護
------------------------------------------------------------
do
    local idx = SI.Build({
        { ids = { 10 }, owner = "ia", rec = { n = "A" }, key = "essential" },
        { ids = { 11 }, owner = "ib", rec = { n = "B" }, key = "utility" },
    })
    local function lk(id) return idx[id] end
    -- ClassifyGCD（純函式）
    eq("GCD：沒帶 startRecoveryCategory ⇒ 不是 GCD 事件", SI.ClassifyGCD(lk, IsSecret, 10), nil)
    local g = SI.ClassifyGCD(lk, IsSecret, 10, nil, nil, 133)
    eq("GCD：明文 spellID ⇒ 命中那一格", g and #g, 1)
    g = SI.ClassifyGCD(lk, IsSecret, 99, nil, nil, 133)
    check("GCD：查不到 ⇒ 空清單（不是全掃）", type(g) == "table" and #g == 0)
    eq("GCD：帶 category ⇒ 全掃", SI.ClassifyGCD(lk, IsSecret, 10, nil, 5, 133), nil)
    eq("GCD：帶 itemID ⇒ 全掃", SI.ClassifyGCD(lk, IsSecret, 10, nil, nil, 133, 5512), nil)
    eq("GCD：spellID nil ⇒ 全掃", SI.ClassifyGCD(lk, IsSecret, nil, nil, nil, 133), nil)
    eq("GCD：GCD 類別是秘密值 ⇒ 全掃", SI.ClassifyGCD(lk, IsSecret, 10, nil, nil, Secret(133)), nil)
    eq("GCD：spellID 秘密 ⇒ 全掃", SI.ClassifyGCD(lk, IsSecret, Secret(10), nil, nil, 133), nil)
    g = SI.ClassifyGCD(lk, IsSecret, 11, 10, nil, 133)
    eq("GCD：覆寫＋基底合併", g and #g, 2)
    -- 批次：GCD_PRECISE 開著 ⇒ 不全掃、帶 gcd；關掉 ⇒ 全掃
    eq("GCD_PRECISE 預設開", SI.GCD_PRECISE, true)
    local b = SI.NewBatch()
    SI.Add(b, lk, IsSecret, 99, nil, nil, 133)
    local all, set, gcd = SI.Take(b)
    eq("批次 GCD：不全掃", all, false)
    eq("批次 GCD：gcd 旗標", gcd, true)
    check("批次 GCD：沒命中 ⇒ 沒有格", next(set) == nil)
    SI.Add(b, lk, IsSecret, 10, nil, nil, 133)
    SI.Add(b, lk, IsSecret, 11)
    all, set, gcd = SI.Take(b)
    local n = 0; for _ in pairs(set) do n = n + 1 end
    eq("批次 GCD＋精準合併：兩格", n, 2)
    eq("批次 GCD＋精準合併：gcd", gcd, true)
    SI.Add(b, lk, IsSecret, 10, nil, nil, 133)
    SI.Add(b, lk, IsSecret, nil)
    all, set, gcd = SI.Take(b)
    eq("GCD 之後來一次全掃 ⇒ 全掃", all, true)
    eq("全掃時 gcd 恆 false", gcd, false)
    all, set, gcd = SI.Take(b)
    eq("Take 之後 gcd 清掉", gcd, false)
    SI.GCD_PRECISE = false
    SI.Add(b, lk, IsSecret, 10, nil, nil, 133)
    all = SI.Take(b)
    eq("GCD_PRECISE 關掉 ⇒ GCD 事件全掃", all, true)
    SI.GCD_PRECISE = true

    -- Subscribe 派送：每個消費者拿到同一份 (all, entries, gcd)；一個拋錯不連坐
    local got = {}
    local spyWants = false
    SI.Subscribe(function(a, e, gc) got[#got + 1] = { a, e, gc } end, function() return spyWants end)
    SI.Subscribe(function() error("boom") end, function() return false end)
    -- 清空 cdWork：Decorate 沒事做、spy 也沒事做 ⇒ 連批次都不排
    for rec in pairs(D.cdWork) do D.cdWork[rec] = nil end
    eq("AnyWants：全部沒事做", SI.AnyWants(), false)
    local f0, p0 = SI.full, SI.precise
    handlers["SPELL_UPDATE_COOLDOWN|spellindex"](nil)
    eq("沒事做：不派送", #got, 0)
    eq("沒事做：計數不動", SI.full + SI.precise, f0 + p0)
    spyWants = true
    local saveReport = ns.ReportError
    local reported = 0
    ns.ReportError = function() reported = reported + 1 end
    handlers["SPELL_UPDATE_COOLDOWN|spellindex"](nil)
    eq("有事做：派送一次", #got, 1)
    eq("有事做：全掃", got[1] and got[1][1], true)
    eq("有事做：全掃計數", SI.full, f0 + 1)
    eq("拋錯的消費者被隔離（ReportError 一次）", reported, 1)
    ns.ReportError = saveReport
    spyWants = false

    -- cdWork 的維護（CdWorkSync）：認領中、沒停放、需要（cdNeed 或 readyWhile）才收；自訂框不收
    local it = Item()
    local r = { cooldownID = 77, claimKey = "essential", cdNeed = false }
    ns.Viewers.frames[it] = r
    D.CdWorkSync(r, it)
    eq("cdWork：不需要 ⇒ 不收", D.cdWork[r], nil)
    r.readyWhile = true
    D.CdWorkSync(r, it)
    eq("cdWork：readyWhile ⇒ 收", D.cdWork[r], it)
    r.readyWhile = nil
    D.CdWorkSync(r)
    eq("cdWork：readyWhile 熄掉 ⇒ 移除（item 從表裡取）", D.cdWork[r], nil)
    r.cdNeed = true
    D.CdWorkSync(r, it)
    eq("cdWork：cdNeed ⇒ 收", D.cdWork[r], it)
    r.parked = true
    D.CdWorkSync(r)
    eq("cdWork：停放 ⇒ 移除", D.cdWork[r], nil)
    r.parked = false
    D.CdWorkSync(r, it)
    r.claimKey = nil
    D.CdWorkSync(r)
    eq("cdWork：沒認領 ⇒ 移除", D.cdWork[r], nil)
    r.claimKey = "essential"
    local cr = { custom = true, claimKey = "essential", cdNeed = true }
    D.CdWorkSync(cr, Item())
    eq("cdWork：自訂框不收", D.cdWork[cr], nil)

    -- Decorate 消費者：GCD 開始 ⇒ 命中的格整套重算，其餘只有開了隱藏 GCD 的格重算 GCD 轉圈
    local gcdCalls, alphaCalls = {}, {}
    local saveG, saveA = D.ApplyGCDAlpha, D.ApplyItemAlpha
    D.ApplyGCDAlpha = function(item, rec) gcdCalls[rec] = (gcdCalls[rec] or 0) + 1 end
    D.ApplyItemAlpha = function(item, rec) alphaCalls[rec] = (alphaCalls[rec] or 0) + 1 end
    local iH, iG, iS = Item(), Item(), Item()
    local rH = { cooldownID = 81, claimKey = "essential", cdNeed = true, cdReady = false, style = { hideGCD = true, cdState = "dim" } }
    local rG = { cooldownID = 82, claimKey = "essential", cdNeed = true, cdReady = false, style = { hideGCD = true } }
    local rS = { cooldownID = 83, claimKey = "essential", cdNeed = true, cdReady = false, style = { cdState = "dim" } }
    for i, pr in ipairs({ { iH, rH }, { iG, rG }, { iS, rS } }) do
        ns.Viewers.frames[pr[1]] = pr[2]
        D.CdWorkSync(pr[2], pr[1])
    end
    local entry = { owner = iH, rec = rH }
    D.OnCooldownBatch(false, { [entry] = true }, true)
    eq("GCD：命中的格重算 GCD 轉圈一次（不重複）", gcdCalls[rH], 1)
    eq("GCD：命中的格重算冷卻狀態", alphaCalls[rH], 1)
    eq("GCD：沒命中、隱藏 GCD 的格只重算 GCD 轉圈", gcdCalls[rG], 1)
    eq("GCD：沒命中、只有冷卻狀態的格不動", alphaCalls[rS], nil)
    gcdCalls, alphaCalls = {}, {}
    D.OnCooldownBatch(false, { [entry] = true }, false)
    eq("非 GCD 的精準：沒命中的不動", gcdCalls[rG], nil)
    D.OnCooldownBatch(true, {}, false)
    eq("全掃：cdWork 每一格（隱藏 GCD）", gcdCalls[rG], 1)
    eq("全掃：cdWork 每一格（冷卻狀態）", alphaCalls[rS], 1)
    rS.parked = true
    alphaCalls = {}
    D.OnCooldownBatch(true, {}, false)
    eq("全掃：停放的格（表裡殘留也不跑）", alphaCalls[rS], nil)
    D.ApplyGCDAlpha, D.ApplyItemAlpha = saveG, saveA
end

print(("CooldownState_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
