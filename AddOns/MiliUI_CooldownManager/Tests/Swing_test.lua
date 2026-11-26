------------------------------------------------------------
-- Modules/Resources_Swing.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Swing_test.lua
--
-- 覆蓋：
--   1. 純函式——Accepts（副手、秘密值、壞秒數不收）、Progress／Running、Settle（戰鬥中留著、脫戰才清）、
--      FillValue（兩種填充模式、沒起算是空條）、CostsMana（法力以外的消耗、0 消耗、秘密值都不算）、
--      R.SwingFill／R.FsrOn（永恆版才開）
--   2. 遊戲裡那半用 stub 跑一輪：有揮擊列才註冊 PLAYER_SWING、永恆版有法力列才聽施法事件；
--      揮擊事件起算並掛 OnUpdate、跑完戰鬥中停在滿格、脫戰清空；耗魔法術起算五秒並顯示游標、
--      不耗魔的不起算、秘密的 spellID 略過；列全收掉時事件與 OnUpdate 都卸掉
-- 載進自己的環境表：這支測試一個全域都不寫。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Modules/Resources_Swing.lua"

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
local function near(name, got, want)
    check(name, type(got) == "number" and math.abs(got - want) < 1e-9, "got " .. tostring(got) .. ", want " .. tostring(want))
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

local SECRET = {}                 -- 假的秘密值

------------------------------------------------------------
-- 1. 純函式（沒有任何 WoW 全域也載得起來）
------------------------------------------------------------
do
    local ns = { Resources = {}, IsSecret = function(v) return v == SECRET end }
    Load(setmetatable({}, { __index = _G }), ns)
    local R = ns.Resources
    local SW = R.Swing

    eq("類型常數：主手", SW.SWING_MAIN, 0)
    eq("類型常數：副手", SW.SWING_OFF, 1)
    eq("類型常數：遠程", SW.SWING_RANGED, 2)

    check("收：主手", SW.Accepts(1.863, 0))
    check("收：遠程", SW.Accepts(2.05, 2))
    check("不收：副手", not SW.Accepts(1.5, 1))
    check("不收：秒數是秘密值", not SW.Accepts(SECRET, 0))
    check("不收：類型是秘密值", not SW.Accepts(1.5, SECRET))
    check("不收：秒數 0", not SW.Accepts(0, 0))
    check("不收：秒數不是數字", not SW.Accepts(nil, 0))

    local st = SW.New()
    eq("沒起算：進度 nil", SW.Progress(st, 10), nil)
    check("沒起算：不在跑", not SW.Running(st, 10))
    SW.Start(st, 100, 2, 0)
    near("起算當下 0", SW.Progress(st, 100), 0)
    near("一半", SW.Progress(st, 101), 0.5)
    check("一半：在跑", SW.Running(st, 101))
    near("跑完停在 1", SW.Progress(st, 105), 1)
    check("跑完：不在跑", not SW.Running(st, 102))
    near("時間倒退夾在 0", SW.Progress(st, 99), 0)

    check("還在跑：脫戰也不清", not SW.Settle(st, 101, false))
    check("跑完、戰鬥中：留著", not SW.Settle(st, 105, true))
    near("留著 ⇒ 進度還是 1", SW.Progress(st, 105), 1)
    check("跑完、脫戰：清掉", SW.Settle(st, 105, false))
    eq("清掉 ⇒ 進度 nil", SW.Progress(st, 105), nil)
    check("已經清空：再 Settle 回 false", not SW.Settle(st, 106, false))

    near("填充：已揮的時間", SW.FillValue(0.25, "elapsed"), 0.25)
    near("填充：剩餘時間", SW.FillValue(0.25, "remaining"), 0.75)
    near("填充：沒起算是空條（elapsed）", SW.FillValue(nil, "elapsed"), 0)
    near("填充：沒起算是空條（remaining）", SW.FillValue(nil, "remaining"), 0)

    check("耗魔：有法力消耗", SW.CostsMana({ { type = 0, cost = 25 } }, 0))
    check("耗魔：多種消耗裡有法力", SW.CostsMana({ { type = 3, cost = 40 }, { type = 0, cost = 10 } }, 0))
    check("耗魔：只有能量不算", not SW.CostsMana({ { type = 3, cost = 40 } }, 0))
    check("耗魔：法力 0 不算", not SW.CostsMana({ { type = 0, cost = 0 } }, 0))
    check("耗魔：消耗是秘密值不算", not SW.CostsMana({ { type = 0, cost = SECRET } }, 0))
    check("耗魔：種類是秘密值不算", not SW.CostsMana({ { type = SECRET, cost = 10 } }, 0))
    check("耗魔：空表", not SW.CostsMana({}, 0))
    check("耗魔：nil", not SW.CostsMana(nil, 0))

    eq("填充模式：預設 elapsed", R.SwingFill({}), "elapsed")
    eq("填充模式：remaining", R.SwingFill({ swingFill = "remaining" }), "remaining")
    eq("填充模式：壞值退回 elapsed", R.SwingFill({ swingFill = "x" }), "elapsed")
    eq("填充模式：沒有設定表", R.SwingFill(nil), "elapsed")
    check("游標：正式服不開", not R.FsrOn({}))
    ns.IS_FOREVER = true
    check("游標：永恆版預設開", R.FsrOn({}))
    check("游標：永恆版關掉", not R.FsrOn({ fsrCursor = false }))
end

------------------------------------------------------------
-- 2. 遊戲裡那半（stub）
------------------------------------------------------------
local function NewWidget()
    local w = { shown = true, scripts = {}, events = {} }
    function w:SetAllPoints() end
    function w:SetPoint() end
    function w:ClearAllPoints() end
    function w:SetWidth(v) self.width = v end
    function w:SetTexture() end
    function w:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function w:SetStatusBarTexture() end
    function w:GetStatusBarTexture()
        self.fill = self.fill or NewWidget()
        return self.fill
    end
    function w:SetMinMaxValues(a, b) self.min, self.max = a, b end
    function w:SetValue(v) self.value = v end
    function w:SetReverseFill(v) self.reverse = v end
    function w:SetFrameLevel(v) self.level = v end
    function w:GetFrameLevel() return self.level or 1 end
    function w:CreateTexture() return NewWidget() end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:SetScript(k, fn) self.scripts[k] = fn end
    function w:RegisterEvent(e) self.events[e] = true end
    function w:RegisterUnitEvent(e, u) self.events[e] = u end
    function w:UnregisterEvent(e) self.events[e] = nil end
    function w:SetText() end
    return w
end

local function Game(forever, swingEvent)
    local g = { now = 1000, combat = false, frames = {}, costs = {}, editing = false, callbacks = {} }
    local env = setmetatable({}, { __index = _G })
    env.GetTime = function() return g.now end
    env.InCombatLockdown = function() return g.combat end
    env.CreateFrame = function()
        local f = NewWidget()
        g.frames[#g.frames + 1] = f
        return f
    end
    env.Enum = { PowerType = { Mana = 0 }, PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } }
    env.C_Spell = { GetSpellPowerCost = function(id) return g.costs[id] end }
    local R = {
        RESOURCES = { Swing = { mode = "swing", swing = true }, Mana = { mode = "bar", mana = true },
                      Rage = { mode = "bar" } },
        SwingAvailable = function() return swingEvent end,
        StyleFor = function(cfg) return cfg end,
        ResolveColor = function() return { r = 1, g = 1, b = 1 } end,
        TimerBg = function() return { 0, 0, 0, 0.6 } end,
    }
    local ns = {
        Resources = R, IS_FOREVER = forever or nil,
        IsSecret = function(v) return v == SECRET end,
        FillReversed = function(cfg) return cfg.fillDirection == "rtl" end,
        P = { Scale = function(v) return v end },
        Media = { PaintBar = function(t, _, r, gg, b, a) t.color = { r, gg, b, a } end },
        EditMode = { Editing = function() return g.editing end },
        RegisterCallback = function(ev, _, fn) g.callbacks[ev] = fn end,
    }
    Load(env, ns)
    g.R, g.SW, g.ns = R, R.Swing, ns
    function g.Row(key)
        local row = NewWidget()
        row.key, row.mode = key, R.RESOURCES[key].mode
        row.bar, row.barBG, row.text = NewWidget(), NewWidget(), NewWidget()
        return row
    end
    -- 驅動框與事件框：SetSwingDriver 第一次要用時才建（順序：driver、events）
    function g.Driver() for _, f in ipairs(g.frames) do if f.isDriver then return f end end end
    function g.Find(pred) for _, f in ipairs(g.frames) do if pred(f) then return f end end end
    function g.Events() return g.Find(function(f) return f.scripts.OnEvent ~= nil end) end
    function g.Ticker() return g.Find(function(f) return f.scripts.OnUpdate ~= nil end) end
    function g.Fire(event, ...) g.Events().scripts.OnEvent(g.Events(), event, ...) end
    function g.Tick() local t = g.Ticker(); if t then t.scripts.OnUpdate(t, 0.016) end end
    return g
end

-- 揮擊列（永恆、盜賊：沒有法力列）
do
    local g = Game(true, true)
    local cfg = {}
    local swing, energy = g.Row("Swing"), g.Row("Rage")
    g.R.PaintSwing(swing, "Swing", cfg, false)
    eq("上色：填充模式記在列上", swing.swingFill, "elapsed")
    near("上色：沒起算是空條", swing.bar.value, 0)
    eq("上色：填充白色", swing.bar:GetStatusBarTexture().color[1], 1)
    near("上色：底色 alpha", swing.barBG.color[4], 0.6)

    g.R.SetSwingDriver({ swing, energy }, 2, cfg)
    local ev = g.Events()
    check("有揮擊列：註冊 PLAYER_SWING", ev.events.PLAYER_SWING == true)
    check("有揮擊列：聽脫戰", ev.events.PLAYER_REGEN_ENABLED == true)
    check("沒有法力列：不聽施法事件", ev.events.UNIT_SPELLCAST_SUCCEEDED == nil)
    check("閒著：不掛 OnUpdate", g.Ticker() == nil)

    g.combat = true
    g.Fire("PLAYER_SWING", 2, 0)
    check("揮擊：掛上 OnUpdate", g.Ticker() ~= nil)
    g.now = 1001
    g.Tick()
    near("揮擊：一半", swing.bar.value, 0.5)
    g.Fire("PLAYER_SWING", 1.5, 1)
    near("副手的事件略過（還是原本那一刀）", g.SW.Progress(g.SW.swing, g.now), 0.5)
    g.Fire("PLAYER_SWING", SECRET, 0)
    near("秘密秒數略過", g.SW.Progress(g.SW.swing, g.now), 0.5)
    g.now = 1002.5
    g.Tick()
    near("跑完、戰鬥中：停在滿格", swing.bar.value, 1)
    check("跑完：卸掉 OnUpdate", g.Ticker() == nil)
    g.combat = false
    g.Fire("PLAYER_REGEN_ENABLED")
    near("脫戰：清空", swing.bar.value, 0)

    -- 剩餘時間模式、遠程
    cfg.swingFill = "remaining"
    g.R.PaintSwing(swing, "Swing", cfg, true)
    eq("右到左：反向填充", swing.bar.reverse, true)
    g.Fire("PLAYER_SWING", 2, 2)
    g.now = g.now + 0.5
    g.Tick()
    near("剩餘時間模式：四分之三", swing.bar.value, 0.75)
    eq("遠程：類型記下", g.SW.swing.kind, 2)
    g.now = g.now + 5
    g.Tick()
    near("脫戰跑完：自己清空", swing.bar.value, 0)
    check("清空後卸掉 OnUpdate", g.Ticker() == nil)

    -- 預覽：設定視窗開著時跑假的循環
    g.editing = true
    g.callbacks.OptionsShown()
    check("預覽：掛上 OnUpdate", g.Ticker() ~= nil)
    g.editing = false
    g.callbacks.OptionsHidden()
    check("預覽結束：卸掉 OnUpdate", g.Ticker() == nil)
    near("預覽結束：空條", swing.bar.value, 0)

    -- 列全收掉
    g.Fire("PLAYER_SWING", 2, 0)
    g.R.SetSwingDriver({ swing, energy }, 0, cfg)
    check("列收掉：取消 PLAYER_SWING", ev.events.PLAYER_SWING == nil)
    check("列收掉：卸掉 OnUpdate", g.Ticker() == nil)
end

-- 五秒回魔游標（永恆、有法力列、沒有揮擊列）
do
    local g = Game(true, true)
    local cfg = {}
    local mana = g.Row("Mana")
    g.costs[331] = { { type = 0, cost = 25 } }       -- 治療波
    g.costs[75] = nil                                -- 自動射擊：沒有消耗
    g.costs[2098] = { { type = 3, cost = 35 } }      -- 能量
    g.R.SetSwingDriver({ mana }, 1, cfg)
    local ev = g.Events()
    eq("法力列：聽玩家的施法事件", ev.events.UNIT_SPELLCAST_SUCCEEDED, "player")
    check("沒有揮擊列：不註冊 PLAYER_SWING", ev.events.PLAYER_SWING == nil)
    check("游標建好、先藏著", mana.fsr ~= nil and mana.fsr.shown == false)
    eq("游標的層級在列之上", mana.fsr.level, 4)

    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 75)
    check("不耗魔：不起算", g.Ticker() == nil and mana.fsr.shown == false)
    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 2098)
    check("耗能量：不起算", g.Ticker() == nil)
    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", SECRET)
    check("秘密的 spellID：略過", g.Ticker() == nil)

    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 331)
    check("耗魔：游標出現", mana.fsr.shown == true and g.Ticker() ~= nil)
    g.now = g.now + 2.5
    g.Tick()
    near("耗魔：掃到一半", mana.fsr.value, 0.5)
    g.now = g.now + 1
    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", 331)   -- 舊的兩參數形狀
    g.Tick()
    near("五秒內再施法：重新起算", mana.fsr.value, 0)
    g.now = g.now + 5.1
    g.Tick()
    check("五秒到：游標收掉", mana.fsr.shown == false)
    check("五秒到：卸掉 OnUpdate", g.Ticker() == nil)

    -- 關掉游標
    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 331)
    cfg.fsrCursor = false
    g.R.SetSwingDriver({ mana }, 1, cfg)
    check("關掉：游標藏起來", mana.fsr.shown == false)
    check("關掉：不聽施法事件", ev.events.UNIT_SPELLCAST_SUCCEEDED == nil)
end

-- 正式服：有法力列也沒有游標；沒有揮擊事件就不註冊
do
    local g = Game(false, false)
    local mana, swing = g.Row("Mana"), g.Row("Swing")
    g.R.SetSwingDriver({ mana }, 1, {})
    check("正式服：不建游標、不建事件框", mana.fsr == nil and g.Events() == nil)
    g.R.SetSwingDriver({ swing }, 1, {})
    check("沒有揮擊事件：不註冊 PLAYER_SWING", g.Events().events.PLAYER_SWING == nil)
end

print(("Swing_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
