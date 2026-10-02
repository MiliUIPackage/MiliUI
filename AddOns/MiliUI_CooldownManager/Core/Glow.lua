------------------------------------------------------------
-- 發光：觸發發光（接管暴雪的 SpellActivationAlert）、就緒發光、生效發光、無損刷新邊框、
--       戰鬥輔助的下一招醒目標示（開關在 Core/Assist.lua）
--
--   ns.Glow.OwnsProc(barKey, id)                 這格的暴雪觸發發光要不要熄（我們畫）
--   ns.Glow.Sync(owner, rec, barKey)             排版時叫：想要的發光狀態 ↔ 目前狀態對齊
--   ns.Glow.AfterApply(owner, rec, barKey, w, h) Decorate 重套樣式後叫：發光框改尺寸、樣式變了重畫
--   ns.Glow.ArmProbe(rec, durationObject)        自訂法術／物品：探針吃同一個 duration 物件
--   ns.Glow.SetProcActive(rec, on)               自訂法術：SPELL_ACTIVATION_OVERLAY_GLOW_SHOW／HIDE
--
-- 規則
--   * 發光一律畫在**我們自己的框**上：overlay（Decorate 建的，item 的子框）底下一顆「發光宿主」，
--     尺寸由我們給（Relayout 算出來的 w, h），**不從 item 讀尺寸**。暴雪 item 本身一個欄位都不寫。
--   * 引擎用 vendor 的 MiliUIGlow 的 Start 系列（普通框、driver 推動）；發光宿主不在光環按鈕子樹裡，
--     不需要 Attach 系列。
--   * 每個掛勾本體 ns.Guard。
--
-- ── 觸發發光 ────────────────────────────────────────────────────────────
-- 暴雪的冷卻管理器 item 用 ActionButtonSpellAlertManager:ShowAlert(item, skipBirth)／HideAlert(item)
-- 開關自己的 SpellActivationAlert（RefreshOverlayGlow）。後掛勾這兩支：frame 是我們認得的 item
-- （弱鍵表）就記下 rec.procActive，照設定畫自己的、熄暴雪的（alpha 0，不 Hide）。
-- 動作條的按鈕也走同一支 manager —— 查不到 rec 就立刻 return。
-- 自訂法術框沒有經過 manager，改聽 SPELL_ACTIVATION_OVERLAY_GLOW_SHOW／HIDE（spellID 過 canaccessvalue）。
--
-- ── 就緒發光：探針 ─────────────────────────────────────────────────────
-- 「冷卻轉好了」這件事秘密值下讀不到。做法：每個開了就緒發光的格子一顆**自己的** Cooldown 框
-- （畫面外、alpha 0、不畫轉圈與數字），餵跟本尊同一組計時，掛它的 OnCooldownDone 當訊號。
--   * 暴雪 item：它的 Cooldown:SetCooldown(start, duration, modRate) 後掛勾裡把**同一組參數原封
--     不動轉交**給探針（不讀、不算）。⚠ 12.1 的 SetCooldown 是 AllowedWhenUntainted：參數是秘密值
--     時污染端轉交會被拒（pcall 失敗）——這時改拿引擎自己給的 duration 物件
--     （C_Spell.GetSpellCooldownDuration(spellID, true)，回充中改 GetSpellChargeDuration）餵
--     SetCooldownFromDurationObject，秘密值下照樣成立。
--   * 暴雪顯示的是**光環時間**時不武裝：那個結束是光環掉了，不是技能轉好。
--     讀法（2026-09-30 對過 12.1.0.69933 的 Blizzard_CooldownViewer/CooldownViewer.lua）：
--     暴雪在 RefreshSpellCooldownInfo 裡先 cooldownFrame:SetUseAuraDisplayTime(item.cooldownUseAuraDisplayTime)
--     再 CooldownFrame_Set ⇒ 我們的 SetCooldown 後掛勾跑到時，**Cooldown 框自己的 C 端 getter**
--     `GetUseAuraDisplayTime()` 就是這一次的值（第一順位，pcall）；讀不到才退回 item 上暴雪的快取欄位
--     `cooldownUseAuraDisplayTime`（CacheCooldownValues* 寫的，欄位名照原始碼，rawget 只讀）。
--   * 「這次是回充」：item 的 `HasVisualDataSource_Charges()`（暴雪的 getter，回 `wasSetFromCharges`）
--     第一順位（pcall），退路 rawget(item, "wasSetFromCharges")。兩者都過 Plain。
--   * GCD：duration 是明文而且 ≤ 1.5 秒就不算（不動探針，已經武裝的真冷卻照跑）。
--     ⚠ 戰鬥中 duration 是秘密值，這道閘讀不到 ⇒ 再問 C_Spell.GetSpellCooldown 的 isOnGCD／isActive
--     （明文布林）：GCD 或沒在冷卻就不武裝。少了這一道，ignoreGCD 的 duration 物件是零長度、
--     探針被 clearIfZero 清掉卻仍標記「武裝中」，GCD 一結束暴雪 Clear ⇒ OnItemClear 把**每一格**
--     都當成轉好（2026-10-01 回報「幾乎全部發光」）。回充（charges）不問：那次 SetCooldown
--     本來就是充能計時，isOnGCD 會是 true 卻不是 GCD。
--   * 暴雪提早 Clear（冷卻被重置、或到期那一刻它自己先清）而探針還武裝著 ⇒ 當場算就緒。
--   * 多充能：每一次 SetCooldown 都是回充（有充能時是充能計時、0 充能時是技能冷卻），所以
--     **每回一層亮一次**。待實機驗證（README）。
--   * 自訂法術／物品：直接 SetCooldownFromDurationObject 同一個 duration 物件（自訂法術用
--     ignoreGCD 的那一版，GCD 本來就不會進來）。
--   * 就緒音效（Core/Sound.lua）吃同一個訊號：只設了音效、沒開就緒發光也照樣建探針、武裝；
--     觸發時音效與發光各看各的設定。
--   * 冷卻狀態效果（Core/Decorate.lua，rec.style.cdState）也吃同一個訊號：有設就建探針、武裝；
--     觸發（與暴雪 Clear）時先 Decorate.RefreshState 重算 alpha，再看發光／音效。
-- 亮 glow.ready.duration 秒（預設 3）後熄；期間技能被用掉（進了新的冷卻）就提早熄（G.CooldownStarted）：
--   * 暴雪 item：SetCooldown 後掛勾裡 isOnGCD == false 且 isActive == true（都要明文）。
--     回充不算：暴雪每次 GCD 都會對回充中的格子重設一次充能計時，拿它當訊號會按任何招就熄。
--   * 自訂法術：Custom 的更新裡同一組明文旗標；自訂物品：武裝新的明文冷卻那一刻。
--
-- ── 生效發光（增益）────────────────────────────────────────────────────
-- 暴雪增益格（圖示列、長條、被搬進自訂群組的增益）與自訂光環格在光環生效期間一直亮。**只有逐法術開關**
-- （overrides[id].activeGlow，加上可選的 activeGlowColor），條層只給樣式與預設色，沒有統一開。
-- 「生效」讀暴雪 item 自己的 IsActive()（欄位 isActive）：12.1.0.69933 的 CooldownViewer.lua 裡
-- 它是暴雪拿光環 expirationTime 跟 GetTime() 用 Lua 比出來的布林，SetIsActive 寫完就叫
-- OnActiveStateChanged ⇒ 後掛勾那支當訊號。讀不到（秘密／nil）一律當沒生效：暴雪的增益列設成
-- 「沒生效也顯示」時灰圖示不能亮（fail-closed）。
-- 這支只管暴雪 item。自訂光環格（AuraContainer）吃同一個逐法術開關，但發光在 Modules/Custom.lua 的
-- initializeFrame 裡建在引擎按鈕底下（按鈕只在光環存在時顯示），不經過這裡。
-- 層數發光（Core/StackGate.lua，「層數到 N 才亮」）跟它互斥：那一格開了層數發光（rec.stackCfg.glow），
-- SyncActive 一律熄生效發光；層數發光自己的宿主在 StackGate 的裁切框底下，不經過 Start／Stop。
--
-- ── 戰鬥輔助的下一招醒目標示 ────────────────────────────────────────────
-- 第四種發光（which ＝ "assist"），開關與目標由 Core/Assist.lua 決定（G.Start／G.Stop 直接叫）：
-- 它不屬於觸發／就緒／生效的對帳，G.Sync **不碰它**（排版時不熄）；Bars 每輪排版結尾叫
-- Assist.Reapply 重接。停放（OnParked）一律熄。宿主一樣是 overlay 底下自己的框，層級在最上面。
--
-- ── 無損刷新 ────────────────────────────────────────────────────────────
-- 後掛勾 item 的 ShowPandemicStateFrame／HidePandemicStateFrame（暴雪在 OnUpdate 裡每幀叫，
-- 所以狀態沒變就立刻 return）：overlay 邊框換 pandemic.color，長條（pandemic.bars）條身也換；
-- Hide 時換回。暴雪自己的 PandemicIcon 不碰。
------------------------------------------------------------
local _, ns = ...

ns.Glow = {}
local G = ns.Glow

-- Decorate 看這個旗標決定要不要熄暴雪的觸發發光（再問 OwnsProc 看這一格）
G.ownsProcAlert = true

local LCG = ns.MiliUIGlow
local GCD_MAX = 1.5
local PARK_X, PARK_Y = -10000, 10000

G.probes = 0               -- 建過幾顆探針（debug）
G.hooked = false
G.readyFired = 0

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

------------------------------------------------------------
-- 設定
------------------------------------------------------------
-- 條層開著 ⇒ 接管（沒開的法術就是不亮）；條層關著但這個法術覆寫成開 ⇒ 也接管
function G.OwnsProc(barKey, id)
    if not barKey then return false end
    if ns.Setting(barKey, "glow.proc.enabled") then return true end
    return ns.SpellSetting(barKey, id, "procGlow") == true
end

local WANT_FIELD = { proc = "procGlow", ready = "readyGlow", active = "activeGlow" }

local function Wanted(rec, barKey, which)
    if not barKey then return false end
    return ns.SpellSetting(barKey, rec.cooldownID, WANT_FIELD[which]) and true or false
end

local function Cfg(barKey, which)
    local c = ns.Setting(barKey, "glow." .. which)
    return type(c) == "table" and c or {}
end

-- 生效發光：預設樣式（glow.active，沒有統一設定頁）＋逐法術的樣式與顏色（有設才蓋）
local function ActiveCfg(rec, barKey)
    local c = Cfg(barKey, "active")
    local col = ns.SpellSetting(barKey, rec.cooldownID, "activeGlowColor")
    local typ = ns.SpellSetting(barKey, rec.cooldownID, "activeGlowType")
    if type(col) ~= "table" and type(typ) ~= "string" then return c end
    local t = {}
    for k, v in pairs(c) do t[k] = v end
    if type(col) == "table" then t.color = col end
    if type(typ) == "string" then t.type = typ end
    return t
end
G.ActiveCfg = ActiveCfg

local function ColorOf(c, dr, dg, db)
    if type(c) ~= "table" then return { dr, dg, db, 1 } end
    return { c.r or dr, c.g or dg, c.b or db, c.a or 1 }
end

------------------------------------------------------------
-- 發光宿主：overlay 底下自己的框，尺寸我們給
------------------------------------------------------------
local function Host(rec, which)
    local ov = rec.overlay
    if not ov then return nil end
    rec.glowHosts = rec.glowHosts or {}
    local h = rec.glowHosts[which]
    if not h then
        h = CreateFrame("Frame", nil, ov)
        h:SetPoint("CENTER", ov, "CENTER", 0, 0)
        h:SetSize(rec.glowW or 36, rec.glowH or 36)
        local up = (which == "assist" and 3) or (which == "proc" and 2) or 1
        h:SetFrameLevel((ov:GetFrameLevel() or 1) + up)
        rec.glowHosts[which] = h
    end
    return h
end

local STOP = {
    pixel    = function(h, key) LCG.PixelGlow_Stop(h, key) end,
    autocast = function(h, key) LCG.AutoCastGlow_Stop(h, key) end,
    button   = function(h) LCG.ButtonGlow_Stop(h) end,
    proc     = function(h, key) LCG.ProcGlow_Stop(h, key) end,
}

-- 在任意框上停／畫一種發光（t ＝ 樣式，key ＝ 同一框上分辨 proc／ready 的鍵）。
-- 格子與設定頁的樣本（Options/Specs.lua 的 GlowSampleRow）共用這兩支
local function StopOn(h, t, key)
    if not (h and LCG) then return end
    pcall(STOP[t] or STOP.pixel, h, key)
end
G.StopOn = StopOn

-- ── 觸發樣式的方形版（裝了 Masque 才用）──────────────────────────────
-- 暴雪的觸發循環圖集（UI-HUD-ActionBar-Proc-Loop-Flipbook）是圓角的，套在我們的直角圖示上四角會缺。
-- Masque 自帶一張「方形、Modern」的循環圖（Textures/Square/SpellAlert-Loop-Modern：6×5 共 30 格，
-- 每格 84px，跟它 Core/Regions/SpellAlert.lua 的 FlipBooks 表同一組數字）。Masque 有載入就換成它，
-- 沒有就維持暴雪圖集。只換貼圖與格子尺寸，不碰 Masque 本身、不讀它的設定。
-- 方形版沒有入場動畫（Masque 也是只播循環），所以 startAnim 一律關。
-- 發光框來自池子、會在觸發／就緒／設定頁樣本之間輪用 ⇒ 每次都把兩種狀態寫齊，不留上一次的。
local MSQ_LOOP = [[Interface\AddOns\Masque\Textures\Square\SpellAlert-Loop-Modern]]
local MSQ_CELL = 84
local BLIZ_LOOP = "UI-HUD-ActionBar-Proc-Loop-Flipbook"

local function MasqueSquare()
    local api = C_AddOns and C_AddOns.IsAddOnLoaded
    if not api then return false end
    local ok, loaded = pcall(api, "Masque")
    return ok and loaded and true or false
end
G.MasqueSquare = MasqueSquare

local function SkinProc(h, key, square)
    local f = h["_ProcGlow" .. key]
    local loop = f and f.ProcLoop
    local fb = f and f.ProcLoopAnim and f.ProcLoopAnim.flipbookRepeat
    if not (loop and fb) then return end
    if square then
        loop:SetTexture(MSQ_LOOP)
        fb:SetFlipBookFrameWidth(MSQ_CELL)
        fb:SetFlipBookFrameHeight(MSQ_CELL)
    else
        loop:SetAtlas(BLIZ_LOOP)
        fb:SetFlipBookFrameWidth(0)
        fb:SetFlipBookFrameHeight(0)
    end
    -- Start 裡的 Show 已經開播：換了貼圖與格子尺寸要重播才吃得到
    if f.ProcLoopAnim:IsPlaying() then
        f.ProcLoopAnim:Stop()
        f.ProcLoopAnim:Play()
    end
end

-- 回傳實際畫上去的樣式（失敗回 nil）
local function PaintOn(h, c, which, key, startAnim)
    if not (h and LCG) then return nil end
    local t = c.type
    if not STOP[t] then t = "pixel" end
    local color
    if which == "proc" then color = ColorOf(c.color, 1, 0.85, 0)
    elseif which == "active" then color = ColorOf(c.color, 0.95, 0.95, 0.32)
    elseif which == "assist" then color = ColorOf(c.color, 0.25, 0.75, 1)
    else color = ColorOf(c.color, 0.3, 1, 0.3) end
    local lines = tonumber(c.lines) or 8
    local freq = tonumber(c.frequency) or 0.2
    local ok
    if t == "autocast" then
        ok = pcall(LCG.AutoCastGlow_Start, h, color, lines, freq, 1, 0, 0, key)
    elseif t == "button" then
        ok = pcall(LCG.ButtonGlow_Start, h, color, freq)
    elseif t == "proc" then
        local square = MasqueSquare()
        ok = pcall(LCG.ProcGlow_Start, h, { color = color, key = key, startAnim = startAnim and not square, duration = 1 })
        if ok then pcall(SkinProc, h, key, square) end
    else
        ok = pcall(LCG.PixelGlow_Start, h, color, lines, freq, nil, tonumber(c.thickness) or 2, 0, 0, false, key)
    end
    return ok and t or nil
end
G.PaintOn = PaintOn

-- 設定頁的預覽（條預覽的格子、單一法術小窗的圖示）：照這個法術現在的生效發光設定常亮，沒開就熄。
-- 開了層數發光（暴雪增益才有，Core/StackGate.lua）的格照層數發光的樣式常亮（兩者互斥，層數的為準）。
-- 同一個 host 記上次畫的樣式與簽章，沒變不重畫（條預覽每次 Refresh 都會叫）
local previewOn = setmetatable({}, { __mode = "k" })
function G.PreviewActive(host, barKey, id)
    if not host then return end
    local SG = ns.StackGate
    local stack = id ~= nil and SG and type(id) == "number"
        and SG.Threshold(ns.SpellSetting(barKey, id, "stackGlow")) ~= nil or false
    local want = stack or (id ~= nil and ns.SpellSetting(barKey, id, "activeGlow") and true or false)
    local c, sig
    if want then
        if stack then c = SG.GlowStyle(barKey, id) else c = ActiveCfg({ cooldownID = id }, barKey) end
        local col = type(c.color) == "table" and c.color or {}
        sig = table.concat({ stack and "stack" or "active", tostring(c.type),
            tostring(col.r), tostring(col.g), tostring(col.b), tostring(col.a) }, "|")
    end
    local cur = previewOn[host]
    if cur and cur.sig == sig then return end
    if cur then
        StopOn(host, cur.t, "active")
        previewOn[host] = nil
    end
    if want then
        local t = PaintOn(host, c, "active", "active", false)
        if t then previewOn[host] = { t = t, sig = sig } end
    end
end

local function Stop(rec, which)
    local on = rec.glowOn
    local t = on and on[which]
    if not t then return end
    on[which] = nil
    rec.glowSig = rec.glowSig or {}
    rec.glowSig[which] = nil
    StopOn(rec.glowHosts and rec.glowHosts[which], t, which)
end
G.Stop = Stop

local function CfgSig(c, w, h)
    local col = c.color
    return table.concat({
        tostring(c.type), tostring(c.lines), tostring(c.thickness), tostring(c.frequency),
        type(col) == "table" and string.format("%.3f,%.3f,%.3f,%.3f", col.r or 0, col.g or 0, col.b or 0, col.a or 1) or "-",
        tostring(w), tostring(h),
    }, "|")
end

local function Start(rec, which, barKey, c)
    if not LCG then return end
    if ns.released and not rec.custom then return end     -- 已還給暴雪（Bars.ReleaseAll）
    local h = Host(rec, which)
    if not h then return end
    c = c or Cfg(barKey, which)
    local sig = CfgSig(c, rec.glowW, rec.glowH)
    rec.glowOn = rec.glowOn or {}
    rec.glowSig = rec.glowSig or {}
    if rec.glowOn[which] and rec.glowSig[which] == sig then return end
    Stop(rec, which)
    local t = PaintOn(h, c, which, which, which == "proc")
    if t then
        rec.glowOn[which] = t
        rec.glowSig[which] = sig
    end
end
G.Start = Start

------------------------------------------------------------
-- 同步：想要的狀態 ↔ 目前狀態（排版、掛勾、設定變了都走這支，冪等）
------------------------------------------------------------
local function Hidden(rec)
    return rec.parked or rec.hidden or false
end

function G.SyncProc(owner, rec, barKey)
    barKey = barKey or rec.claimKey
    if owner and owner.SpellActivationAlert and ns.Decorate then
        ns.Decorate.ApplyProcAlert(owner, rec, barKey)
    end
    if rec.procActive and not Hidden(rec) and Wanted(rec, barKey, "proc") then
        Start(rec, "proc", barKey)
    else
        Stop(rec, "proc")
    end
end

-- 生效發光：暴雪增益 item 才有；讀不到生效狀態＝沒生效
local function ReadActive(item)
    if not item then return false end
    local fn = item.IsActive
    if type(fn) == "function" then
        local ok, v = pcall(fn, item)
        if ok then
            v = Plain(v)
            if v ~= nil then return v == true end
        end
    end
    return Plain(rawget(item, "isActive")) == true
end

-- 戰鬥狀態自己記（PLAYER_REGEN_DISABLED 派送當下 InCombatLockdown 還不一定是真）
local inCombat = false

-- 「脫戰也亮」關掉的增益只在戰鬥中亮
local function CombatOK(rec, barKey)
    if inCombat then return true end
    return ns.SpellSetting(barKey, rec.cooldownID, "activeGlowOutOfCombat") ~= false
end

function G.SyncActive(owner, rec, barKey)
    barKey = barKey or rec.claimKey
    local aura = not rec.custom and ns.Viewers.AURA_KIND and ns.Viewers.AURA_KIND[rec.barKey]
    -- 層數發光開著（Core/StackGate.lua，rec.stackCfg.glow）：生效發光讓位
    local stackGlow = rec.stackCfg ~= nil and rec.stackCfg.glow ~= nil
    if aura and owner and not stackGlow and not Hidden(rec) and Wanted(rec, barKey, "active") and CombatOK(rec, barKey)
        and ReadActive(owner) then
        Start(rec, "active", barKey, ActiveCfg(rec, barKey))
    else
        Stop(rec, "active")
    end
end

-- ⚠ 下一招醒目標示（"assist"）不在這裡對帳：它由 Core/Assist.lua 管，這裡不准熄它
function G.Sync(owner, rec, barKey)
    if not rec then return end
    barKey = barKey or rec.claimKey
    G.SyncProc(owner, rec, barKey)
    G.SyncActive(owner, rec, barKey)
    -- 就緒發光亮著的時候設定變了：照新樣式重畫；被關掉了就熄
    if rec.glowOn and rec.glowOn.ready then
        if Hidden(rec) or not Wanted(rec, barKey, "ready") then
            Stop(rec, "ready")
        else
            Start(rec, "ready", barKey)
        end
    end
    G.ApplyPandemic(owner, rec, barKey)
end

function G.AfterApply(owner, rec, barKey, w, h)
    if not rec then return end
    if w and h and (rec.glowW ~= w or rec.glowH ~= h) then
        rec.glowW, rec.glowH = w, h
        for _, host in pairs(rec.glowHosts or {}) do host:SetSize(w, h) end
    end
    -- 第一次看到這個 item 時它可能早就在發光（登入前、掛勾前）
    if not rec.custom and rec.procActive == nil then
        local mgr = _G.ActionButtonSpellAlertManager
        if mgr and mgr.HasAlert then
            local ok, has = pcall(mgr.HasAlert, mgr, owner)
            if ok then rec.procActive = Plain(has) and true or false end
        end
    end
    G.Sync(owner, rec, barKey)
end

-- 停放（alpha 0、畫面外）：發光一律熄；procActive 留著，重新認領時 Sync 再接回去
function G.OnParked(rec)
    if not rec then return end
    Stop(rec, "proc")
    Stop(rec, "ready")
    Stop(rec, "active")
    Stop(rec, "assist")
    if ns.StackGate then ns.StackGate.OnParked(rec) end
end

------------------------------------------------------------
-- 觸發發光：暴雪 item（manager 後掛勾）與自訂法術（事件）
------------------------------------------------------------
local function OnShowAlert(_, frame)
    local rec = frame and ns.Viewers.frames[frame]
    if not rec then return end
    rec.procActive = true
    G.SyncProc(frame, rec)
end

local function OnHideAlert(_, frame)
    local rec = frame and ns.Viewers.frames[frame]
    if not rec then return end
    rec.procActive = false
    G.SyncProc(frame, rec)
end

function G.SetProcActive(rec, on, owner, barKey)
    if not rec then return end
    rec.procActive = on and true or false
    G.SyncProc(owner, rec, barKey)
end

local function InstallAlertHooks()
    if G.hooked then return true end
    local mgr = _G.ActionButtonSpellAlertManager
    if type(mgr) ~= "table" or type(mgr.ShowAlert) ~= "function" or type(mgr.HideAlert) ~= "function" then
        return false
    end
    hooksecurefunc(mgr, "ShowAlert", ns.Guard(OnShowAlert))
    hooksecurefunc(mgr, "HideAlert", ns.Guard(OnHideAlert))
    G.hooked = true
    return true
end

------------------------------------------------------------
-- 就緒發光
------------------------------------------------------------
-- 探針要不要建、要不要武裝：就緒發光或就緒音效（Core/Sound.lua）任一個要就要
local function SoundWanted(rec)
    return ns.Sound and ns.Sound.WantsReady(rec) or false
end

-- 冷卻狀態效果（Core/Decorate.lua）也吃探針：轉好的那一刻要立刻把 alpha 換回來，不等下一次刷新
local function CdStateOn(rec)
    return rec.style ~= nil and rec.style.cdState ~= nil
end

local function ReadyOn(rec)
    local barKey = rec.claimKey
    return barKey and not Hidden(rec) and (Wanted(rec, barKey, "ready") or SoundWanted(rec) or CdStateOn(rec))
end

local function Fire(rec)
    -- 冷卻狀態先重算（不受下面發光／音效的提早 return 影響）
    if ns.Decorate and ns.Decorate.RefreshState then ns.Decorate.RefreshState(rec) end
    if not ReadyOn(rec) then return end
    local barKey = rec.claimKey
    if SoundWanted(rec) then ns.Sound.OnReady(rec) end
    if not Wanted(rec, barKey, "ready") then return end
    G.readyFired = G.readyFired + 1
    Start(rec, "ready", barKey)
    local token = (rec.readyToken or 0) + 1
    rec.readyToken = token
    local dur = tonumber(ns.Setting(barKey, "glow.ready.duration")) or 3
    if dur <= 0 then dur = 3 end
    C_Timer.After(dur, function()
        if rec.readyToken == token then Stop(rec, "ready") end
    end)
end
G.FireReady = Fire

-- 進了新的冷卻（用掉了）：就緒發光不用等滿秒數，當場熄。token 換掉讓計時到期那支什麼都不做
function G.CooldownStarted(rec)
    if not (rec and rec.glowOn and rec.glowOn.ready) then return end
    rec.readyToken = (rec.readyToken or 0) + 1
    Stop(rec, "ready")
end

local function Probe(rec)
    local p = rec.probe
    if p then return p end
    local ok
    ok, p = pcall(CreateFrame, "Cooldown", nil, UIParent, "CooldownFrameTemplate")
    if not ok or not p then return nil end
    p:SetSize(1, 1)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", PARK_X, PARK_Y)
    p:SetAlpha(0)
    if p.SetHideCountdownNumbers then p:SetHideCountdownNumbers(true) end
    if p.SetDrawSwipe then p:SetDrawSwipe(false) end
    if p.SetDrawEdge then p:SetDrawEdge(false) end
    if p.SetDrawBling then p:SetDrawBling(false) end
    p:EnableMouse(false)
    p:HookScript("OnCooldownDone", ns.Guard(function()
        if not rec.probeArmed then return end
        rec.probeArmed = false
        -- 武裝之後 item 換了身分（暴雪回收框給別的法術）：那個計時不是這個法術的
        if rec.probeID ~= rec.cooldownID then return end
        Fire(rec)
    end))
    rec.probe = p
    G.probes = G.probes + 1
    return p
end

-- 暴雪 item 用哪個法術問引擎要 duration 物件（覆寫優先）
local function SpellOf(rec)
    local info = ns.Catalog and ns.Catalog.Info(rec.cooldownID)
    return info and (info.overrideSpellID or info.spellID) or nil
end

-- 暴雪的布林：getter 優先（pcall），讀不到退回欄位（rawget，只讀）；秘密／讀不到＝nil
local function ReadFlag(obj, getter, field)
    if not obj then return nil end
    local fn = getter and obj[getter]
    if type(fn) == "function" then
        local ok, v = pcall(fn, obj)
        if ok then
            v = Plain(v)                  -- ⚠ 不能寫成 ok and Plain(v) or nil：false 會被吃掉
            if type(v) == "boolean" then return v end
        end
    end
    if field then
        local v = Plain(rawget(obj, field))
        if type(v) == "boolean" then return v end
    end
    return nil
end

local function UsesAuraTime(item, cd)
    local v = ReadFlag(cd or item.Cooldown, "GetUseAuraDisplayTime", nil)
    if v ~= nil then return v end
    return ReadFlag(item, nil, "cooldownUseAuraDisplayTime") == true
end

local function FromCharges(item)
    return ReadFlag(item, "HasVisualDataSource_Charges", "wasSetFromCharges") == true
end

-- 暴雪 item 的 Cooldown:SetCooldown 後掛勾（Decorate 轉過來；cd 是被呼叫的那顆 Cooldown）
function G.OnItemSetCooldown(item, rec, start, duration, modRate, cd)
    if not ReadyOn(rec) then return end
    -- 暴雪正在顯示光環時間：那個結束不是技能轉好
    if UsesAuraTime(item, cd) then return end
    local d = Plain(duration)
    if d ~= nil and (type(d) ~= "number" or d <= GCD_MAX) then return end
    local spellID = SpellOf(rec)
    local charges = FromCharges(item)
    -- 戰鬥中 duration 是秘密值、上面那道 GCD 閘形同虛設：暴雪每次 GCD 都對**每一格**
    -- SetCooldown（RefreshCooldownOnly），沒在冷卻的法術也一樣。改問引擎的明文旗標
    -- （isActive／isOnGCD 不是秘密值）：只是 GCD、或根本沒在冷卻 ⇒ 這次不是「要等它轉好」
    if not charges and spellID then
        local okInfo, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if okInfo and type(info) == "table" then
            local gcd, active = Plain(info.isOnGCD), Plain(info.isActive)
            if gcd == true or active == false then return end
            -- 明文確認進了新的冷卻（技能用掉了）⇒ 還亮著的就緒發光收掉
            if gcd == false and active == true then G.CooldownStarted(rec) end
        end
    end
    local p = Probe(rec)
    if not p then return end
    local ok = pcall(p.SetCooldown, p, start, duration, modRate or 1)
    if not ok then
        -- 參數是秘密值：污染端轉交被拒 ⇒ 改拿引擎給的 duration 物件
        if not spellID then return end
        local api = charges and C_Spell.GetSpellChargeDuration
            or function(id) return C_Spell.GetSpellCooldownDuration(id, true) end
        local ok2, dur = pcall(api, spellID)
        if not (ok2 and dur) then return end
        ok = pcall(p.SetCooldownFromDurationObject, p, dur, true)
        if not ok then return end
    end
    rec.probeArmed, rec.probeID = true, rec.cooldownID
end

-- 暴雪清掉冷卻（到期那一刻它自己清、或冷卻被重置）而探針還武裝著 ⇒ 就是轉好了
function G.OnItemClear(item, rec)
    -- 冷卻狀態：暴雪清掉冷卻（到期或被重置）＝現在可能轉好了，先照現況重算 alpha。
    -- 暴雪對沒在冷卻的格子每次 GCD 也會 Clear ⇒ 這裡不排 0.1 秒的補算（探針觸發的 Fire 才排）
    if ns.Decorate and ns.Decorate.RefreshState then ns.Decorate.RefreshState(rec, true) end
    if not rec.probeArmed then return end
    rec.probeArmed = false
    if rec.probe then pcall(rec.probe.Clear, rec.probe) end
    if rec.probeID ~= rec.cooldownID then return end
    Fire(rec)
end

-- 自訂法術／物品：吃同一個 duration 物件（零長度會被 clearIfZero 清掉，不會誤觸）
function G.ArmProbe(rec, dur)
    if not dur then return end
    if not ReadyOn(rec) then
        if rec.probe and rec.probeArmed then
            rec.probeArmed = false
            pcall(rec.probe.Clear, rec.probe)
        end
        return
    end
    local p = Probe(rec)
    if not p then return end
    if pcall(p.SetCooldownFromDurationObject, p, dur, true) then rec.probeArmed, rec.probeID = true, rec.cooldownID end
end

------------------------------------------------------------
-- 無損刷新
------------------------------------------------------------
function G.ApplyPandemic(owner, rec, barKey)
    if not rec then return end
    barKey = barKey or rec.claimKey
    local on = rec.pandemic and barKey and not Hidden(rec) and ns.Setting(barKey, "pandemic.enabled") ~= false
    if on then
        local c = ns.Setting(barKey, "pandemic.color")
        if ns.Decorate then ns.Decorate.RecolorBorder(rec, c) end
        local b = owner and owner.Bar
        if b and b.GetStatusBarTexture and ns.Setting(barKey, "pandemic.bars") then
            local tex = b:GetStatusBarTexture()
            if tex and type(c) == "table" then tex:SetVertexColor(c.r or 1, c.g or 0.5, c.b or 0, c.a or 1) end
            rec.pandemicBar = true
        end
        rec.pandemicShown = true
    elseif rec.pandemicShown then
        rec.pandemicShown = false
        if ns.Decorate then ns.Decorate.RestoreBorder(rec) end
        if rec.pandemicBar then
            rec.pandemicBar = false
            local b = owner and owner.Bar
            local tex = b and b.GetStatusBarTexture and b:GetStatusBarTexture()
            local c = barKey and ns.Setting(barKey, "bar.color")
            if tex then
                if type(c) == "table" then tex:SetVertexColor(c.r or 0.4, c.g or 0.6, c.b or 0.9, c.a or 1)
                else tex:SetVertexColor(0.4, 0.6, 0.9, 1) end
            end
            -- 層數換色那一層在條身底下、暴雪的填充要維持透明（Core/StackGate.lua）
            if ns.StackGate then ns.StackGate.Reconceal(owner, rec) end
        end
    end
end

local function OnShowPandemic(item)
    local rec = ns.Viewers.frames[item]
    if not rec or rec.pandemic then return end      -- 暴雪每幀叫：狀態沒變就走
    rec.pandemic = true
    G.ApplyPandemic(item, rec)
end

local function OnHidePandemic(item)
    local rec = ns.Viewers.frames[item]
    if not rec or not rec.pandemic then return end
    rec.pandemic = false
    G.ApplyPandemic(item, rec)
end

local function OnActiveStateChanged(item)
    local rec = ns.Viewers.frames[item]
    if not rec then return end
    G.SyncActive(item, rec)
end

-- Decorate.HookItem 叫（每框一次）
function G.HookItem(item, rec)
    if rec.glowHooked then return end
    rec.glowHooked = true
    if item.OnActiveStateChanged then
        hooksecurefunc(item, "OnActiveStateChanged", ns.Guard(OnActiveStateChanged))
    end
    if item.ShowPandemicStateFrame then
        hooksecurefunc(item, "ShowPandemicStateFrame", ns.Guard(OnShowPandemic))
    end
    if item.HidePandemicStateFrame then
        hooksecurefunc(item, "HidePandemicStateFrame", ns.Guard(OnHidePandemic))
    end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function G.Counts()
    local proc, ready, pandemic, active, assist = 0, 0, 0, 0, 0
    local function Count(rec)
        if rec.glowOn and rec.glowOn.active then active = active + 1 end
        if rec.glowOn and rec.glowOn.assist then assist = assist + 1 end
        if rec.glowOn and rec.glowOn.proc then proc = proc + 1 end
        if rec.glowOn and rec.glowOn.ready then ready = ready + 1 end
        if rec.pandemicShown then pandemic = pandemic + 1 end
    end
    for _, rec in pairs(ns.Viewers.frames) do Count(rec) end
    if ns.Custom and ns.Custom.Records then
        for _, rec in pairs(ns.Custom.Records()) do Count(rec) end
    end
    return proc, ready, pandemic, active, assist
end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local initialized = false
-- 進出戰鬥：增益兩條的 item 全部重對一次生效發光（只碰我們自己的發光宿主）
local function OnCombatChanged(on)
    inCombat = on
    if not (ns.Viewers and ns.Viewers.EnumerateItems) then return end
    for key in pairs(ns.Viewers.AURA_KIND or {}) do
        ns.Viewers.EnumerateItems(function(item, rec) G.SyncActive(item, rec) end, key)
    end
end

function G.Init()
    if initialized then return end
    initialized = true
    inCombat = InCombatLockdown() and true or false
    ns.Events.Register("PLAYER_REGEN_DISABLED", "glow_combat", function() OnCombatChanged(true) end)
    ns.Events.Register("PLAYER_REGEN_ENABLED", "glow_combat", function() OnCombatChanged(false) end)
    if not InstallAlertHooks() then
        -- 動作條那一包理論上一定在；萬一比我們晚，等登入完成再試一次
        ns.Events.Register("PLAYER_ENTERING_WORLD", "glow_hooks", function()
            if InstallAlertHooks() then ns.Events.Unregister("PLAYER_ENTERING_WORLD", "glow_hooks") end
        end)
    end
end
