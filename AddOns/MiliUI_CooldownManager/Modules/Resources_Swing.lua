------------------------------------------------------------
-- 資源條：自己計時的兩樣東西（TOC 接在 Resources_Rows.lua 之後）
--
--   揮擊列（mode = "swing"，key "Swing"）   下一次普攻／自動射擊的計時條，資源條裡獨立的一列
--   五秒回魔游標（法力列上的一條白線）     花了法力之後五秒內精神回魔暫停，游標掃完＝恢復回魔
--
-- 兩樣都是「訊號一來就從 GetTime() 起算固定秒數」：起點與秒數都是我們自己的明文數字，
-- 畫圖、算術在任何場合都安全（同 Modules/Timers.lua；.claude/notes/wow-121-duration-objects.md）。
--
-- ── 分流（永恆版 vs 正式服）────────────────────────────────
--   揮擊列看**能力**不看版本：客戶端有 PLAYER_SWING 事件才有這一列（R.SwingAvailable，
--     Modules/Resources_Defs.lua）。2026-11-26 的現況：永恆版有；正式服 12.1.5 與 12.1.7 PTR 都沒有
--     （PTR 帶著 Blizzard_SwingTimer 的檔案但 TOC 標 AllowLoadGameType: camelot、API 文件也沒這個事件）。
--     正式服自己算不出來（戰鬥記錄全封，抓不到「揮了一下」）⇒ 等暴雪開放事件，這一列會自己出現，不用改分流。
--   五秒回魔看**版本**：ns.IS_FOREVER。正式服沒有五秒規則這個遊戲機制，不是 API 問題。
--
-- ── 實機查證（永恆 1.60.1.71139，2026-11-26，薩滿 1 級＋獵人 6 級，野外）──────────
--   * PLAYER_SWING(swingDuration, swingType)：秒數與類型戰鬥中都是明文；暴雪自己的揮擊條關掉
--     （CVar showSwingTimer = 0）照樣派 ⇒ 我們不依賴暴雪那條。類型 0 主手、1 副手、2 遠程
--     （Enum.PlayerSwingType）。獵人的自動射擊（2）與近戰（0）會交替出現 ⇒ 只畫一條、最後來的為準。
--   * 第一刀在進戰鬥之前就派（那一刻 InCombatLockdown 還是 false）⇒ 不能用「戰鬥中才聽」當閘。
--   * 施法會拖延下一刀而且沒有事件（1.86 秒的武器，中間讀一發治療波，下一刀隔了 5 秒才來）⇒ 跑完之後
--     停在「可以揮了」的狀態等下一個事件，脫戰才清空。
--   * UNIT_SPELLCAST_SUCCEEDED 的 spellID 戰鬥中是明文，C_Spell.GetSpellPowerCost 查得到耗魔
--     （治療波 25、閃電箭 15、猛禽一擊 10；自動射擊與登入特效回「沒有消耗」）。猛禽一擊這種「下一刀生效」的
--     技能，施法成功事件跟那一刀同時到 ⇒ 起算點就是真正扣魔那一刻。
--   * 法力（UnitPower）永遠是秘密值；GetManaRegen 脫戰明文（基礎 6.251／施法中 0.001）、戰鬥中秘密，
--     而且施法後數字不變 ⇒ 五秒規則的結束**沒有訊號可對時**，只能照固定 5 秒。兩秒一跳的回魔提示不做
--     （法力讀不到，永恆是不是連續回魔也還有爭議）。
--   沒測到：副本／首領戰裡 spellID 會不會變秘密值（變了那一發就不起算，不報錯）、雙持的類型 1。
--
-- ── 已知限制 ─────────────────────────────────────────────
--   * 免費的那一發（節能施法、心靈專注）：事後查到的是原價，會被當成有耗魔而重新起算五秒。
--   * 副手不畫（類型 1 的事件直接略過）。
--
-- 純函式（時間從參數進來，離線可測，Tests/Swing_test.lua）：
--   SW.SWING_MAIN／SWING_OFF／SWING_RANGED   類型常數（讀 Enum.PlayerSwingType，沒有就 0／1／2）
--   SW.New() / SW.Clear(st)                  計時狀態 { start, dur, kind }
--   SW.Accepts(dur, kind)                    這個揮擊事件收不收（秒數是正的明文數字、類型不是副手）
--   SW.Start(st, now, dur, kind)             起算
--   SW.Running(st, now)                      還在跑（沒到終點）
--   SW.Progress(st, now)                     已過的比例 0～1（跑完停在 1；沒起算 nil）
--   SW.Settle(st, now, inCombat)             跑完而且不在戰鬥 ⇒ 清空（回 true ＝ 剛清掉）
--   SW.FillValue(progress, fill)             條的值：elapsed 已揮的時間長出來／remaining 剩餘時間縮短；nil ＝ 空條
--   SW.CostsMana(costs, manaType)            GetSpellPowerCost 的回傳裡有沒有 > 0 的法力消耗（秘密值當沒有）
--   SW.FSR_SECONDS                           5
------------------------------------------------------------
local _, ns = ...

local R = ns.Resources
local SW = {}
R.Swing = SW

local PST = (Enum and Enum.PlayerSwingType) or {}
SW.SWING_MAIN   = PST.MainHand or 0
SW.SWING_OFF    = PST.OffHand or 1
SW.SWING_RANGED = PST.Ranged or 2
SW.FSR_SECONDS  = 5
SW.PREVIEW_SWING = 2          -- 預覽（設定視窗開著／編輯模式中、而且沒在計時）跑的假揮擊秒數

local function IsSecret(v) return ns.IsSecret ~= nil and ns.IsSecret(v) or false end

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
function SW.New() return { start = nil, dur = nil, kind = nil } end

function SW.Clear(st)
    st.start, st.dur, st.kind = nil, nil, nil
end

function SW.Accepts(dur, kind)
    if IsSecret(dur) or IsSecret(kind) then return false end
    if type(dur) ~= "number" or dur <= 0 then return false end
    if kind == SW.SWING_OFF then return false end
    return true
end

function SW.Start(st, now, dur, kind)
    st.start, st.dur, st.kind = now, dur, kind
end

function SW.Running(st, now)
    return st.start ~= nil and (now - st.start) < st.dur
end

function SW.Progress(st, now)
    if st.start == nil then return nil end
    local p = (now - st.start) / st.dur
    if p < 0 then return 0 end
    if p > 1 then return 1 end
    return p
end

function SW.Settle(st, now, inCombat)
    if st.start == nil or inCombat then return false end
    if SW.Running(st, now) then return false end
    SW.Clear(st)
    return true
end

function SW.FillValue(progress, fill)
    if progress == nil then return 0 end
    if fill == "remaining" then return 1 - progress end
    return progress
end

function SW.CostsMana(costs, manaType)
    if type(costs) ~= "table" then return false end
    for i = 1, #costs do
        local c = costs[i]
        if type(c) == "table" then
            local t, cost = c.type, c.cost
            if not IsSecret(t) and not IsSecret(cost) and t == manaType and type(cost) == "number" and cost > 0 then
                return true
            end
        end
    end
    return false
end

-- 揮擊列的填充模式：elapsed 已揮的時間長出來（預設，同征戰聖擊列）／remaining 剩餘時間縮短
function R.SwingFill(cfg)
    local v = type(cfg) == "table" and cfg.swingFill
    if v == "remaining" then return v end
    return "elapsed"
end

-- 五秒回魔游標開不開（只有永恆版有；預設開）
function R.FsrOn(cfg)
    return ns.IS_FOREVER == true and not (type(cfg) == "table" and cfg.fsrCursor == false)
end

------------------------------------------------------------
-- 以下要框架：離線測試載到這裡為止
------------------------------------------------------------
if not CreateFrame then return end

local SOLID = "Interface\\Buttons\\WHITE8x8"
local MANA_TYPE = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

local function Now() return GetTime() end
local function Previewing()
    return ns.EditMode and ns.EditMode.Editing and ns.EditMode.Editing() or false
end
local function InCombat() return InCombatLockdown() and true or false end

local swing = SW.New()           -- 揮擊
local fsr = SW.New()             -- 五秒回魔（dur 固定 SW.FSR_SECONDS，kind 不用）
SW.swing, SW.fsr = swing, fsr    -- /mcdm debug、測試

local rowsRef, rowCount = nil, 0
local swingAny, fsrRow = false, nil
local driver, events
local ticking = false
local swingEvOn, castEvOn, regenEvOn = false, false, false
SW.ticks = 0                     -- /mcdm perf：OnUpdate 跑了幾幀

------------------------------------------------------------
-- 揮擊列的畫法
------------------------------------------------------------
-- 上色與填充方向（LayoutRow 叫；列是池化重用的，每次排版都重上）。值是我們自己的明文 0～1：
-- 填充＝主色、背景＝底色，不必像征戰聖擊列那樣把兩層的角色對調
function R.PaintSwing(row, key, cfg, reversed)
    local cc = R.ResolveColor(cfg, key, "color")
    local t = row.bar:GetStatusBarTexture()
    if t then ns.Media.PaintBar(t, cfg.texture, cc.r, cc.g, cc.b, 1) end
    local bg = R.TimerBg(cfg, key, cc)
    row.barBG:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    row.bar:SetReverseFill(reversed)
    row.bar:SetMinMaxValues(0, 1)
    row.swingFill = R.SwingFill(cfg)
    R.SwingRow(row)
end

-- 這一刻的值。預覽（設定視窗開著／編輯模式中、沒在計時）跑一個假的循環，讓玩家看得到顏色與方向
local function SwingProgress(now)
    local p = SW.Progress(swing, now)
    if p == nil and Previewing() then
        return (now % SW.PREVIEW_SWING) / SW.PREVIEW_SWING
    end
    return p
end

function R.SwingRow(row)
    row.bar:SetValue(SW.FillValue(SwingProgress(Now()), row.swingFill))
end

------------------------------------------------------------
-- 五秒回魔游標：法力列上疊一顆自己的 StatusBar（填充透明），游標貼在填充的前緣
--   * 值是我們自己的明文 ⇒ 錨在這顆的填充貼圖上沒有秘密幾何的問題。法力列本身的 row.bar 餵過秘密值，
--     不錨它、不讀它（Modules/Resources.lua 開頭的規矩）。
--   * 每幀只 SetValue，不 SetPoint。
------------------------------------------------------------
local CURSOR_LEVEL = 3           -- 在列的 bar（+1）、吸收盾（+2）之上，數值文字（+20）之下
local CURSOR_PX = 2

local function EnsureCursor(row)
    if row.fsr then return row.fsr end
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetAllPoints(row)
    bar:SetStatusBarTexture(SOLID)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetVertexColor(1, 1, 1, 0) end
    local line = bar:CreateTexture(nil, "OVERLAY")
    line:SetTexture(SOLID)
    if ns.NoSnap then ns.NoSnap(line) end
    bar.line = line
    bar:Hide()
    row.fsr = bar
    return bar
end

local function LayoutCursor(row, cfg)
    local bar = EnsureCursor(row)
    local reversed = ns.FillReversed(cfg)
    bar:SetFrameLevel((row:GetFrameLevel() or 1) + CURSOR_LEVEL)
    bar:SetReverseFill(reversed)
    local fill = bar:GetStatusBarTexture()
    local line = bar.line
    line:ClearAllPoints()
    if fill then
        -- 游標貼在填充的前緣：左到右是填充的右緣，右到左是左緣
        local edge = reversed and "LEFT" or "RIGHT"
        line:SetPoint("TOP", fill, "TOP" .. edge, 0, 0)
        line:SetPoint("BOTTOM", fill, "BOTTOM" .. edge, 0, 0)
    end
    line:SetWidth(ns.P.Scale(CURSOR_PX))
    local c = R.ResolveColor(cfg, "Mana", "fsrColor")
    line:SetVertexColor(c.r, c.g, c.b, 1)
end

local function FsrProgress(now)
    if SW.Running(fsr, now) then return SW.Progress(fsr, now) end
    if Previewing() then return (now % SW.FSR_SECONDS) / SW.FSR_SECONDS end
    return nil
end

local function PaintCursor(now)
    local bar = fsrRow and fsrRow.fsr
    if not bar then return end
    local p = FsrProgress(now)
    if p == nil then
        bar:Hide()
        return
    end
    bar:SetValue(p)
    bar:Show()
end

------------------------------------------------------------
-- 驅動：有東西在跑才掛 OnUpdate
------------------------------------------------------------
local Tick

local function NeedsTick(now)
    if swingAny and (SW.Running(swing, now) or Previewing()) then return true end
    if fsrRow and (SW.Running(fsr, now) or Previewing()) then return true end
    return false
end

local function PaintAll(now)
    if swingAny then
        local v
        for i = 1, rowCount do
            local row = rowsRef[i]
            if row and row.mode == "swing" then
                v = SW.FillValue(SwingProgress(now), row.swingFill)
                row.bar:SetValue(v)
            end
        end
    end
    PaintCursor(now)
end

local function Arm()
    if not driver then return end
    local now = Now()
    local want = NeedsTick(now)
    if want ~= ticking then
        ticking = want
        driver:SetScript("OnUpdate", want and Tick or nil)
    end
    -- 停下來的那一刻補畫一次終點（揮擊停在「可以揮了」、游標收掉）
    PaintAll(now)
end

Tick = function()
    SW.ticks = SW.ticks + 1
    local now = Now()
    -- 揮擊跑完而且不在戰鬥：清空（戰鬥中留著「可以揮了」的狀態，施法拖延下一刀時不會閃一下空條）
    SW.Settle(swing, now, InCombat())
    PaintAll(now)
    if not NeedsTick(now) then
        ticking = false
        driver:SetScript("OnUpdate", nil)
    end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local function OnSwing(dur, kind)
    if not SW.Accepts(dur, kind) then return end
    SW.Start(swing, Now(), dur, kind)
    Arm()
end

-- (unit, castGUID, spellID)／(unit, spellID) 兩種形狀（同 Core/Sound.lua 的 Logic.CastSpellID）
local function OnCast(a2, a3)
    local spellID = a3
    if not IsSecret(a2) and type(a2) == "number" then spellID = a2 end
    if IsSecret(spellID) or type(spellID) ~= "number" then return end
    local fn = C_Spell and C_Spell.GetSpellPowerCost
    if not fn then return end
    local ok, costs = pcall(fn, spellID)
    if not ok or not SW.CostsMana(costs, MANA_TYPE) then return end
    SW.Start(fsr, Now(), SW.FSR_SECONDS, nil)
    Arm()
end

local function OnEvent(_, event, a1, a2, a3)
    if event == "PLAYER_SWING" then
        OnSwing(a1, a2)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnCast(a2, a3)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 脫戰：跑完的揮擊清空（還在跑的讓它跑完，Tick 會收）
        if SW.Settle(swing, Now(), false) then Arm() end
    end
end

local function SetEvent(name, on, was, unit)
    if on == was then return on end
    if on then
        if unit then events:RegisterUnitEvent(name, unit) else events:RegisterEvent(name) end
    else
        events:UnregisterEvent(name)
    end
    return on
end

local hooked = false
local function HookPreview()
    if hooked or not ns.RegisterCallback then return end
    hooked = true
    -- 預覽的進出：設定視窗開關、暴雪編輯模式進出
    ns.RegisterCallback("OptionsShown", "resources_swing", Arm)
    ns.RegisterCallback("OptionsHidden", "resources_swing", Arm)
    ns.RegisterCallback("EditModeChanged", "resources_swing", Arm)
end

-- Relayout 結尾、整條關掉時叫（同 R.SetMirrorDriver）：對齊「畫面上有沒有揮擊列／法力列上要不要游標」
function R.SetSwingDriver(list, count, cfg)
    rowsRef, rowCount = list, count
    swingAny, fsrRow = false, nil
    local fsrOn = count > 0 and R.FsrOn(cfg)
    for i = 1, count do
        local row = list[i]
        if row then
            local def = row.key and R.RESOURCES[row.key]
            if row.mode == "swing" then swingAny = true end
            if fsrOn and not fsrRow and def and def.mana and row.mode == "bar" then
                fsrRow = row
                LayoutCursor(row, R.StyleFor(cfg, row.key))
            elseif row.fsr then
                row.fsr:Hide()              -- 池化的列換成別的資源、或游標關了
            end
        end
    end
    if not (swingAny or fsrRow) then
        if driver then
            ticking = false
            driver:SetScript("OnUpdate", nil)
            swingEvOn = SetEvent("PLAYER_SWING", false, swingEvOn)
            castEvOn = SetEvent("UNIT_SPELLCAST_SUCCEEDED", false, castEvOn)
            regenEvOn = SetEvent("PLAYER_REGEN_ENABLED", false, regenEvOn)
        end
        return
    end
    if not driver then
        driver = CreateFrame("Frame")
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    HookPreview()
    swingEvOn = SetEvent("PLAYER_SWING", swingAny and R.SwingAvailable(), swingEvOn)
    regenEvOn = SetEvent("PLAYER_REGEN_ENABLED", swingAny, regenEvOn)
    castEvOn = SetEvent("UNIT_SPELLCAST_SUCCEEDED", fsrRow ~= nil, castEvOn, "player")
    Arm()
end

-- /mcdm debug
function SW.DebugLines(add)
    local now = Now()
    add(("  揮擊：事件存在 %s  已註冊 %s  列在畫面上 %s  進度 %s  類型 %s  秒數 %s"):format(
        tostring(R.SwingAvailable()), tostring(swingEvOn), tostring(swingAny),
        tostring(SW.Progress(swing, now)), tostring(swing.kind), tostring(swing.dur)))
    add(("  五秒回魔：永恆 %s  游標列 %s  已註冊 %s  進度 %s  OnUpdate %s（累計 %d 幀）"):format(
        tostring(ns.IS_FOREVER == true), tostring(fsrRow ~= nil), tostring(castEvOn),
        tostring(SW.Running(fsr, now) and SW.Progress(fsr, now) or nil), tostring(ticking), SW.ticks))
end
