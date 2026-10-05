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
--   * 每個掛勾本體 ns.Guard——**唯一例外**是無損刷新的兩支（每幀叫，無事路徑不可能拋錯，見那一節）。
--   * 自訂法術／物品放在長條類的條上（rec.noGlow，Modules/Custom.lua 換框時設）：Start 一律不畫，
--     探針照樣武裝（就緒音效、冷卻狀態照常）。
--   * 圖示外觀＝Masque 而且皮是非方形（圓形、六角形）：觸發／閃光換成那個形狀的貼圖、像素與自動施法改畫該形狀的觸發
--     （見下面「發光跟著 Masque 皮的形狀」）。沒交給 Masque 的格子第一行就短路，跟以前完全一樣。
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
--     ⚠ 設成「增益持續中不顯示持續時間」的格（Core/Decorate.lua 的 FeedRealCooldown）這支不會被叫：
--     Decorate 改餵技能自己的 duration 物件，探針走 G.ArmProbe 吃同一個物件（明文確認沒在冷卻／只是 GCD 就不武裝）。
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
-- 資源夠了才亮（glow.ready.requireUsable，條層、預設關；只管 timed／untilUsed，whileReady 本來就看狀態）：冷卻轉好那一刻問 C_Spell.IsSpellUsable，
-- 明文 false（能量／怒氣不夠）就先不亮、記 rec.readyPending，等 SPELL_UPDATE_USABLE／UNIT_POWER_FREQUENT
-- （只在有格子等待中時註冊；處理器只標髒、下一幀掃）可用了才亮。讀不到／秘密值一律當可用（fail-open：
-- 寧可照舊亮，也不要因為讀不到就永遠不亮）。就緒音效不等，照舊在轉好那一刻響。
-- 自訂物品／裝備欄不檢查（物品沒有資源的問題）。等待中又用掉、被藏、停放、換身分 ⇒ 取消等待。
-- 亮 glow.ready.duration 秒（預設 3）後熄；期間技能被用掉（進了新的冷卻）就提早熄（G.CooldownStarted）。
-- glow.ready.mode 三種（玩家回報 2026-10-03：打斷要一直亮；逐法術可蓋 overrides[id].readyGlowMode，
-- 資源檢查同樣可蓋 readyGlowUsable，法術小窗「發光」分頁）：
--   "timed"      上面那樣，亮幾秒
--   "untilUsed"  不排計時，一直亮到 CooldownStarted。
--     ⚠ 只在「轉好那一刻」點燈：/reload、上線時本來就轉好的技能不亮，用過一次才開始。
--     ⚠ 暴雪 item 的回充（rec.probeCharges）收不到 CooldownStarted（下面那條規則），照秒數熄。
--   "whileReady" 不看探針的那一刻，看**狀態**（G.ApplyReadyState）。判斷跟冷卻狀態效果同一支
--     （Decorate.CooldownState／Custom.CooldownState）：GCD 不算冷卻、充能法術還有充能就算就緒；
--     明文：冷卻中 Stop（宿主 alpha 還原 1）、就緒 Start；秘密：發光一直開著、秘密布林交給宿主的
--     SetAlphaFromBoolean（宿主是我們自己的框，之後不讀回）；判不出來＝發光開著、宿主 alpha 0。重算時機：排版（G.Sync）、
--     SetCooldown／Clear 後掛勾、SPELL_UPDATE_COOLDOWN 的批次（Decorate.OnCooldownBatch、Custom.Update）、探針觸發。
--   * 暴雪 item：SetCooldown 後掛勾裡 isOnGCD == false 且 isActive == true（都要明文）。
--     回充不算：暴雪每次 GCD 都會對回充中的格子重設一次充能計時，拿它當訊號會按任何招就熄。
--   * 自訂法術：Custom 的更新裡同一組明文旗標；自訂物品：武裝新的明文冷卻那一刻。
--
-- ── 生效發光（增益）────────────────────────────────────────────────────
-- 暴雪增益格（圖示列、長條、被搬進自訂群組的增益）與自訂光環格在光環生效期間一直亮。開關與繼承跟觸發／就緒
-- 同一套：條層 glow.active.enabled（**預設關**）＋樣式／顏色／線條／粗細，逐法術 overrides[id].activeGlow 蓋開關
-- （玩家多半只在幾個法術上個別打開）。
-- 「生效」讀暴雪 item 自己的 IsActive()（欄位 isActive）：12.1.0.69933 的 CooldownViewer.lua 裡
-- 它是暴雪拿光環 expirationTime 跟 GetTime() 用 Lua 比出來的布林，SetIsActive 寫完就叫
-- OnActiveStateChanged ⇒ 後掛勾那支當訊號。讀不到（秘密／nil）一律當沒生效：暴雪的增益列設成
-- 「沒生效也顯示」時灰圖示不能亮（fail-closed）。
-- 暴雪的冷卻格（核心／輔助，含搬進自訂群組的）也吃同一個逐法術開關（玩家回報 2026-10-03：反魔法護罩使用中要亮）：
-- 「生效」＝暴雪正在倒增益時間。訊號是 Cooldown:SetUseAuraDisplayTime(旗標) 的後掛勾（Decorate 記進 rec.auraFlag，
-- 值變了就叫 G.SyncActive）。實機 log（12.1，戰鬥中）：按下去那一刻 true、增益掉了那一刻 false，都是明文。
--   ⚠ 冷卻格的 IsActive()、item 上的 cooldownUseAuraDisplayTime 欄位、IsExpired() 在 12.1 都沒用：
--     IsActive 跟著整條重排翻、欄位永遠 false、IsExpired 永遠 true（暴雪每次刷新幾乎都是 Clear），只有那支 setter 可靠。
-- 這支只管暴雪 item。自訂光環格（AuraContainer）吃同一個逐法術開關，但發光在 Modules/Custom.lua 的
-- initializeFrame 裡建在引擎按鈕底下（按鈕只在光環存在時顯示），不經過這裡。
-- 飾品欄冷卻格的增益疊層（rec.buffOverlay）也是那一套：開關照冷卻格那一筆的 activeGlow，畫在疊層按鈕底下；
-- 冷卻格自己的觸發／就緒發光照舊走這裡（宿主在 overlay 底下，層級比疊層高），兩邊互不干擾。
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
G.pandemicCalls, G.pandemicChanges = 0, 0   -- /mcdm perf：無損刷新掛勾被叫幾次／狀態真的變了幾次

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

local WANT_FIELD = { proc = "procGlow", ready = "readyGlow", active = "activeGlow", full = "fullGlow" }

local function Wanted(rec, barKey, which)
    if not barKey then return false end
    return ns.SpellSetting(barKey, rec.cooldownID, WANT_FIELD[which]) and true or false
end

local READY_MODES = { timed = true, untilUsed = true, whileReady = true }
-- rec 給了就先看逐法術覆寫（overrides[id].readyGlowMode，法術小窗的「亮多久」），沒覆寫退回條層
local function ReadyMode(barKey, rec)
    if not barKey then return "timed" end
    local m
    if rec and rec.cooldownID ~= nil then m = ns.SpellSetting(barKey, rec.cooldownID, "readyGlowMode")
    else m = ns.Setting(barKey, "glow.ready.mode") end
    return READY_MODES[m] and m or "timed"
end
G.ReadyMode = ReadyMode

local function Cfg(barKey, which)
    local c = ns.Setting(barKey, "glow." .. which)
    return type(c) == "table" and c or {}
end

-- 生效發光的樣式：跟觸發／就緒同一套，條層（或跟隨主題）的 glow.active。逐法術只開關、不挑樣式
-- （使用者 2026-10-03 改回；舊存檔的 activeGlowColor／activeGlowType 不再讀）
local function ActiveCfg(_, barKey)
    return Cfg(barKey, "active")
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

-- 發光框比宿主高幾層：函式庫預設 ＋8，會蓋過按鍵文字與層數（Text.TEXT_LIFT ＝ overlay＋5、宿主最高 overlay＋3）。
-- 給 0 ⇒ 發光就在宿主那一層（overlay＋1～＋3），文字一律在發光上面
local GLOW_LIFT = 0
G.GLOW_LIFT = GLOW_LIFT

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
local MSQ_SQUARE = { tex = MSQ_LOOP, w = MSQ_CELL, h = MSQ_CELL }
local BLIZ_LOOP = "UI-HUD-ActionBar-Proc-Loop-Flipbook"

local function MasqueSquare()
    local api = C_AddOns and C_AddOns.IsAddOnLoaded
    if not api then return false end
    local ok, loaded = pcall(api, "Masque")
    return ok and loaded and true or false
end
G.MasqueSquare = MasqueSquare

-- 循環圖的格子排法：暴雪圖集與 Masque 內建的都是 6×5／30 格。只有某張皮自己加的循環圖排法不同時才寫，
-- 寫過之後（gridTouched）換回來的路徑才跟著把排法寫回預設（池化框會輪用）
local gridTouched = false
local function SetGrid(fb, rows, cols, frames)
    fb:SetFlipBookRows(rows)
    fb:SetFlipBookColumns(cols)
    fb:SetFlipBookFrames(frames)
end

-- loop：nil ＝ 暴雪圖集；{ tex, w, h[, rows, cols, frames] } ＝ Masque 的循環圖（方形或皮的形狀）
local function SkinProc(h, key, loop)
    local f = h["_ProcGlow" .. key]
    local tex = f and f.ProcLoop
    local fb = f and f.ProcLoopAnim and f.ProcLoopAnim.flipbookRepeat
    if not (tex and fb) then return end
    if loop then
        tex:SetTexture(loop.tex)
        fb:SetFlipBookFrameWidth(loop.w)
        fb:SetFlipBookFrameHeight(loop.h)
    else
        tex:SetAtlas(BLIZ_LOOP)
        fb:SetFlipBookFrameWidth(0)
        fb:SetFlipBookFrameHeight(0)
    end
    if loop and loop.rows then
        gridTouched = true
        SetGrid(fb, loop.rows, loop.cols, loop.frames)
    elseif gridTouched then
        SetGrid(fb, 6, 5, 30)
    end
    -- Start 裡的 Show 已經開播：換了貼圖與格子尺寸要重播才吃得到
    if f.ProcLoopAnim:IsPlaying() then
        f.ProcLoopAnim:Stop()
        f.ProcLoopAnim:Play()
    end
end

-- ── 發光跟著 Masque 皮的形狀 ─────────────────────────────────────────
-- 交給 Masque 的格子、皮是非方形（圓形、六角形…）：從交出去的框上讀回形狀（ns.Masque.ShapeOf，唯一讀 Masque
-- 內部資料的例外，見 Core/Masque.lua 檔頭），再用 Masque 的公開 API 拿那個形狀的貼圖：
--   觸發（proc）          GetSpellAlertFlipBook("Modern", 形狀) 的循環圖（取代方形那張），沒有入場動畫
--   快捷鍵閃光（button）   GetSpellAlert(形狀) 的 Glow／Ants 換掉暴雪的方形 IconAlert／IconAlertAnts
--                         （Masque 只附圓形一組；六角形拿不到 ⇒ 跟像素一樣改用該形狀的觸發）
--   像素、自動施法          沒有形狀可言 ⇒ 改畫該形狀的觸發，顏色沿用原設定
--   API 讀不到             照原樣式（方形，＝現狀）
-- Square／Modern／讀不到形狀 ＝ 方形，完全照現狀。
-- 短路：格子沒交給 Masque（rec.msqSkinned 不是 true——沒裝 Masque 時永遠是這樣）、長條、條是米利模式 ⇒ 第一行就走，
-- 不呼叫 ShapeOf、不建表。換皮（Generation 變了）、群組停用 ⇒ 形狀跟著變、進發光簽章 ⇒ 舊的照記下的樣式停掉、重畫。
local SQUARE_SHAPES = { Square = true, Modern = true }

-- frame（交給 Masque 的框）在 barKey 這條上的非方形形狀；其餘 nil
local function SkinShape(frame, barKey)
    local M = ns.Masque
    if not (frame and M and M.Available() and M.Mode(barKey) == "masque") then return nil end
    local s = M.ShapeOf(frame)
    if s == nil or SQUARE_SHAPES[s] then return nil end
    return s
end
G.SkinShape = SkinShape

-- 格子（rec）的發光形狀：圖示類、交給了 Masque 的才問
local function GlowShape(rec, barKey)
    if not (rec and rec.msqSkinned == true) or rec.barGeometry then return nil end
    return SkinShape(rec.msqButton, barKey or rec.claimKey or rec.placedBar)
end
G.GlowShape = GlowShape

-- 形狀 × 樣式 → 實際樣式＋貼圖（art）。快取到 Masque 換設定為止（皮可以自己加貼圖組）
local artCache, artGen = {}, nil
local function ShapedStyle(t, shape)
    if not shape then return t, nil end
    local M = ns.Masque
    local g = M.Generation and M.Generation() or 0
    if artGen ~= g then artCache, artGen = {}, g end
    local ck = t .. "|" .. shape
    local hit = artCache[ck]
    if hit == nil then
        hit = false
        if t == "button" then
            local glow, ants = M.SpellAlertOverlay(shape)
            if glow then hit = { t = "button", shape = shape, glow = glow, ants = ants, sig = shape .. ":" .. glow } end
        end
        if not hit then
            local loop = M.SpellAlertLoop(shape)
            if loop then
                hit = { t = "proc", shape = shape, loop = loop,
                    sig = table.concat({ shape, loop.tex, loop.w, loop.h, loop.rows or "-" }, ":") }
            end
        end
        artCache[ck] = hit
    end
    if not hit then return t, nil end
    return hit.t, hit
end
G.ShapedStyle = ShapedStyle

-- 快捷鍵閃光的貼圖（池化框：上次換成哪個形狀記在弱鍵表；換回方形時寫回暴雪的兩張）
local BTN_GLOW = [[Interface\SpellActivationOverlay\IconAlert]]
local BTN_ANTS = [[Interface\SpellActivationOverlay\IconAlertAnts]]
local BTN_GLOW_KEYS = { "spark", "innerGlow", "innerGlowOver", "outerGlow", "outerGlowOver" }
local btnShape = setmetatable({}, { __mode = "k" })
local btnTouched = false       -- 換過任何一顆之後，方形路徑才需要檢查（沒裝 Masque 永遠是 false）
local function SkinButton(h, art)
    local f = h._ButtonGlow
    if not f then return end
    local want = art and art.shape or nil
    if btnShape[f] == want then return end
    local glow, ants = BTN_GLOW, BTN_ANTS
    if art then glow, ants = art.glow, art.ants end
    for _, k in ipairs(BTN_GLOW_KEYS) do
        if f[k] then f[k]:SetTexture(glow) end
    end
    if f.ants then f.ants:SetTexture(ants) end
    btnShape[f] = want
    if art then btnTouched = true end
end

-- 光環按鈕（Modules/Custom.lua 的 AttachGlow，initializeFrame 裡）：Attach 系列建好之後換同一組貼圖。
-- f 是 Attach 剛建的新框，貼圖一定是暴雪的 ⇒ 只在有 art 時寫
function G.SkinAttached(f, art)
    if not (f and art) then return end
    if art.t == "proc" and f.ProcLoop and f.ProcLoopAnim then
        local fb = f.ProcLoopAnim.flipbookRepeat
        f.ProcLoop:SetTexture(art.loop.tex)
        if fb then
            fb:SetFlipBookFrameWidth(art.loop.w)
            fb:SetFlipBookFrameHeight(art.loop.h)
            if art.loop.rows then SetGrid(fb, art.loop.rows, art.loop.cols, art.loop.frames) end
        end
        if f.ProcLoopAnim:IsPlaying() then
            f.ProcLoopAnim:Stop()
            f.ProcLoopAnim:Play()
        end
    elseif art.t == "button" then
        if f.spark then f.spark:SetTexture(art.glow) end
        if f.outerGlow then f.outerGlow:SetTexture(art.glow) end
        if f.ants then f.ants:SetTexture(art.ants) end
    end
end

-- 回傳實際畫上去的樣式（失敗回 nil）。shape：GlowShape 的結果（nil ＝ 方形、現狀）
local function PaintOn(h, c, which, key, startAnim, shape)
    if not (h and LCG) then return nil end
    local t = c.type
    if not STOP[t] then t = "pixel" end
    local art
    if shape then t, art = ShapedStyle(t, shape) end
    local color
    if which == "proc" then color = ColorOf(c.color, 1, 0.85, 0)
    elseif which == "active" then color = ColorOf(c.color, 0.95, 0.95, 0.32)
    elseif which == "assist" then color = ColorOf(c.color, 0.25, 0.75, 1)
    elseif which == "full" then color = ColorOf(c.color, 1, 0.55, 0.2)
    else color = ColorOf(c.color, 0.3, 1, 0.3) end
    local lines = tonumber(c.lines) or 8
    local freq = tonumber(c.frequency) or 0.2
    local ok
    if t == "autocast" then
        ok = pcall(LCG.AutoCastGlow_Start, h, color, lines, freq, 1, 0, 0, key, GLOW_LIFT)
    elseif t == "button" then
        ok = pcall(LCG.ButtonGlow_Start, h, color, freq, GLOW_LIFT)
        if ok and (art or btnTouched) then pcall(SkinButton, h, art) end
    elseif t == "proc" then
        if art then
            ok = pcall(LCG.ProcGlow_Start, h, { color = color, key = key, startAnim = false, duration = 1, frameLevel = GLOW_LIFT })
            if ok then pcall(SkinProc, h, key, art.loop) end
        else
            local square = MasqueSquare()
            ok = pcall(LCG.ProcGlow_Start, h, { color = color, key = key, startAnim = startAnim and not square, duration = 1,
                frameLevel = GLOW_LIFT })
            if ok then pcall(SkinProc, h, key, square and MSQ_SQUARE or nil) end
        end
    else
        ok = pcall(LCG.PixelGlow_Start, h, color, lines, freq, nil, tonumber(c.thickness) or 2, 0, 0, false, key, GLOW_LIFT)
    end
    return ok and t or nil
end
G.PaintOn = PaintOn

-- 設定頁的預覽（條預覽的格子、單一法術小窗的圖示）：照這個法術現在的生效發光設定常亮，沒開就熄。
-- 開了層數發光（暴雪增益才有，Core/StackGate.lua）的格照層數發光的樣式常亮（兩者互斥，層數的為準）。
-- 同一個 host 記上次畫的樣式與簽章，沒變不重畫（條預覽每次 Refresh 都會叫）
local previewOn = setmetatable({}, { __mode = "k" })
-- shape：預覽格交給 Masque 時皮的形狀（Glow.GlowShape(cell)；nil ＝ 方形）
function G.PreviewActive(host, barKey, id, shape)
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
            tostring(col.r), tostring(col.g), tostring(col.b), tostring(col.a), tostring(shape) }, "|")
    end
    local cur = previewOn[host]
    if cur and cur.sig == sig then return end
    if cur then
        StopOn(host, cur.t, "active")
        previewOn[host] = nil
    end
    if want then
        local t = PaintOn(host, c, "active", "active", false, shape)
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
    if rec.noGlow then return end                         -- 自訂項目放在長條上：長條不畫發光（Modules/Custom.lua）
    local h = Host(rec, which)
    if not h then return end
    c = c or Cfg(barKey, which)
    local sig = CfgSig(c, rec.glowW, rec.glowH)
    -- 皮的形狀（見「發光跟著 Masque 皮的形狀」）：沒交給 Masque 的格子第一行就回 nil，簽章不變
    local shape = GlowShape(rec, barKey)
    if shape then sig = sig .. "|" .. shape end
    rec.glowOn = rec.glowOn or {}
    rec.glowSig = rec.glowSig or {}
    if rec.glowOn[which] and rec.glowSig[which] == sig then return end
    Stop(rec, which)
    local t = PaintOn(h, c, which, which, which == "proc", shape)
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

-- 就緒發光「等資源」的兩支（定義在下面就緒發光那一段；Sync／OnParked 先用到）
local CancelPending, MarkDirty

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
    -- 暴雪的冷卻格（核心／輔助）：「生效」＝暴雪正在倒增益時間（rec.auraFlag，Decorate 的 SetUseAuraDisplayTime 後掛勾記的）
    local active
    if aura then
        active = owner ~= nil and ReadActive(owner)
    elseif not rec.custom then
        active = rec.auraFlag == true
    end
    -- 層數發光開著（Core/StackGate.lua，rec.stackCfg.glow）：生效發光讓位
    local stackGlow = rec.stackCfg ~= nil and rec.stackCfg.glow ~= nil
    if active and not stackGlow and not Hidden(rec) and Wanted(rec, barKey, "active") and CombatOK(rec, barKey) then
        Start(rec, "active", barKey, ActiveCfg(rec, barKey))
    else
        Stop(rec, "active")
    end
end

------------------------------------------------------------
-- 充能滿了發光（which ＝ "full"）
--
-- 充能技能每一層都回滿時一直亮（EUI 的 Max Stacks Glow 同一套判斷）。開關與繼承跟觸發／就緒同一套：
-- 條層 glow.full（**預設關**）＋樣式，逐法術 overrides[id].fullGlow 蓋開關。
--   * 判斷只讀明文：GetSpellCharges 的 maxCharges > 1（Decorate.IsChargeSpell，秘密值時用上次記的）而且
--     isActive（回充在跑）明文 false。**不讀 currentCharges**（戰鬥中是秘密值）。isActive 讀不到 ⇒ 不亮（fail-closed：
--     寧可不亮，也不要回充中一直亮）。
--   * 法術：暴雪的冷卻格用目錄的基本法術＋當下的覆蓋（C_SpellBook.FindSpellOverrideByID，明文）；
--     自訂法術用 rec.overrideID／spellID。裝備欄、物品、光環不做。
--   * 時機：排版（G.Sync）＋ SPELL_UPDATE_CHARGES（用掉一層、回滿一層都會派）。只有開著的格進 fullWatch，
--     事件也只在 fullWatch 有東西時才註冊。冷卻的 SetCooldown 掛勾不能當訊號：最後一層回滿那一刻暴雪不一定 SetCooldown。
--   * 充能滿音效（Core/Sound.lua）用同一套判斷（G.FullSpellOf／G.ReadFull 的三態），監看表各管各的。
------------------------------------------------------------
local fullWatch = setmetatable({}, { __mode = "k" })   -- rec → owner
local fullEventOn = false

-- 暴雪的冷卻格（目錄資訊）用哪個法術問充能：目錄的基本法術＋當下的覆蓋（明文）；裝備欄 nil
local function CatalogFullSpell(info)
    if not info or type(info.equipSlot) == "number" then return nil end
    local base = info.spellID
    local id = info.overrideSpellID or base
    local find = C_SpellBook and C_SpellBook.FindSpellOverrideByID
    if find and type(base) == "number" then
        local ok, ov = pcall(find, base)
        ov = ok and Plain(ov) or nil
        if type(ov) == "number" and ov > 0 then id = ov end
    end
    return type(id) == "number" and id or nil
end

local function FullSpellOf(rec)
    if rec.custom then
        if rec.kind ~= "spell" then return nil end
        local id = rec.overrideID or rec.spellID
        return type(id) == "number" and id or nil
    end
    local aura = ns.Viewers.AURA_KIND
    if aura and aura[rec.barKey] then return nil end
    return CatalogFullSpell(ns.Catalog.Info(rec.cooldownID))
end
G.FullSpellOf = FullSpellOf                                         -- Core/Sound.lua 的充能滿音效同一套

-- 同一套、從 cooldownID 解（設定介面沒有 rec：Options/SpellPopover.lua 判「這招現在有沒有充能」）。
-- 自訂法術用目錄的覆蓋／基本法術；暴雪的增益兩條、物品、裝備欄、光環格 nil
function G.FullSpellOfID(cooldownID)
    local info = cooldownID ~= nil and ns.Catalog.Info(cooldownID) or nil
    if not info then return nil end
    if info.custom then
        if info.kind ~= "spell" then return nil end
        local id = info.overrideSpellID or info.spellID
        return type(id) == "number" and id or nil
    end
    local src = ns.Catalog.SourceOf and ns.Catalog.SourceOf(cooldownID)
    local aura = ns.Viewers.AURA_KIND
    if src and aura and aura[src] then return nil end
    return CatalogFullSpell(info)
end

-- 這一刻滿不滿（三態）→ isCharge, state：
--   isCharge ＝ 現在是不是充能技能（false ⇒ 不用看著）；state ＝ true 滿／false 沒滿／nil 讀不到（秘密值、API 不在）。
-- 發光要 fail-closed（讀不到＝不亮，見 FullState）；音效要「明確的沒滿 → 明確的滿」才響，讀不到不能當沒滿（Core/Sound.lua）
local function ReadFull(rec, id)
    local D = ns.Decorate
    if not (D and D.IsChargeSpell and D.IsChargeSpell(rec, id, true)) then return false, nil end
    local fn = C_Spell and C_Spell.GetSpellCharges
    if not fn then return true, nil end
    local ok, info = pcall(fn, id)
    if not ok or type(info) ~= "table" then return true, nil end
    local okA, a = pcall(function() return info.isActive end)
    if not okA then return true, nil end
    a = Plain(a)                                    -- ⚠ 不寫 okA and Plain(a) or nil：明文 false（＝滿）會變 nil
    if type(a) ~= "boolean" then return true, nil end
    return true, not a
end
G.ReadFull = ReadFull                                               -- Core/Sound.lua 用

-- 這一刻是不是滿的：nil ＝ 不是充能技能（不用看著）、true／false ＝ 滿／沒滿（讀不到算沒滿）
local function FullState(rec, id)
    local isCharge, state = ReadFull(rec, id)
    if not isCharge then return nil end
    return state == true
end
G.FullState = FullState                                             -- 測試用

local function OnChargesChanged()
    for rec, owner in pairs(fullWatch) do G.SyncFull(owner, rec) end
end

local function WatchFull(rec, owner, on)
    if on then fullWatch[rec] = owner or fullWatch[rec] or false else fullWatch[rec] = nil end
    local any = next(fullWatch) ~= nil
    if any ~= fullEventOn then
        fullEventOn = any
        if any then ns.Events.Register("SPELL_UPDATE_CHARGES", "glow_full", OnChargesChanged)
        else ns.Events.Unregister("SPELL_UPDATE_CHARGES", "glow_full") end
    end
end

function G.SyncFull(owner, rec, barKey)
    barKey = barKey or rec.claimKey or rec.placedBar
    local id = (not Hidden(rec) and Wanted(rec, barKey, "full")) and FullSpellOf(rec) or nil
    -- ⚠ 不寫 id and FullState(…) or nil：沒滿（false）會變成 nil ＝ 被當成不是充能技能、不看了
    local full = nil
    if id then full = FullState(rec, id) end
    WatchFull(rec, owner, full ~= nil)
    if full then
        Start(rec, "full", barKey)
    else
        Stop(rec, "full")
    end
    -- 充能滿音效（Core/Sound.lua）：自己的監看表，發光沒開也要能響；同一個時機對帳
    if ns.Sound and ns.Sound.SyncFull then ns.Sound.SyncFull(rec, barKey, Hidden(rec)) end
end

-- ⚠ 下一招醒目標示（"assist"）不在這裡對帳：它由 Core/Assist.lua 管，這裡不准熄它
function G.Sync(owner, rec, barKey)
    if not rec then return end
    barKey = barKey or rec.claimKey
    G.SyncProc(owner, rec, barKey)
    G.SyncActive(owner, rec, barKey)
    G.SyncFull(owner, rec, barKey)
    -- 等資源中：被藏了、就緒發光被關掉就取消；資源設定可能剛被關掉 ⇒ 下一幀重掃一次
    if rec.readyPending then
        if Hidden(rec) or not Wanted(rec, barKey, "ready") then CancelPending(rec) else MarkDirty() end
    end
    -- 就緒時一直亮：狀態對帳（模式切走了也在這裡收）
    if rec.readyWhile or (barKey and ReadyMode(barKey, rec) == "whileReady") then
        G.ApplyReadyState(rec, owner)
    -- 就緒發光亮著的時候設定變了：照新樣式重畫；被關掉了就熄
    elseif rec.glowOn and rec.glowOn.ready then
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
    -- 冷卻事件的全掃清單（Core/Decorate.lua 的 D.cdWork）：停放的不再算
    local D = ns.Decorate
    if D and D.cdWork then D.cdWork[rec] = nil end
    Stop(rec, "proc")
    Stop(rec, "ready")
    Stop(rec, "active")
    Stop(rec, "full")
    Stop(rec, "assist")
    WatchFull(rec, nil, false)
    if ns.Sound and ns.Sound.UnwatchFull then ns.Sound.UnwatchFull(rec) end
    CancelPending(rec)
    if ns.StackGate then ns.StackGate.OnParked(rec) end
    -- 按鍵鏡射（Core/Keybinds.lua）：撤銷格號登記、收掉閃光
    if ns.Keybinds and ns.Keybinds.OnParked then ns.Keybinds.OnParked(rec) end
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

-- 觸發中的法術（我們自己從事件認到的，rec.procEventID）是不是還在發光：明文 true 才算
local function StillOverlayed(rec)
    local id = rec.procEventID
    if not id then return false end
    local api = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
    if not api then return false end
    local ok, on = pcall(api, id)
    if ok and Plain(on) == true then return true end
    rec.procEventID = nil
    return false
end

local function OnHideAlert(_, frame)
    local rec = frame and ns.Viewers.frames[frame]
    if not rec then return end
    -- 暴雪每次 RefreshData 都 RefreshOverlayGlow：減益鎖住 GetSpellID 時拿減益的 id 去問 ⇒ 誤判熄掉（見 OnOverlayEvent）
    if StillOverlayed(rec) then return end
    rec.procActive = false
    G.SyncProc(frame, rec)
end

-- 暴雪冷卻格的觸發事件自己也聽一份。
-- 暴雪的 NeedSpellActivationUpdate 拿事件的 spellID 比 item:GetSpellID()，而 GetSpellID 在
-- PreferAuraDataOverSpellData 成立時回的是光環的 id：主動施放的格只要目標身上有它追蹤的減益就成立
-- ⇒ 事件被丟掉、ShowAlert 不叫，要等之後哪次刷新剛好問對才亮（血魄心臟打擊的緩速掛著時，
-- 薩萊因的吸血鬼打擊觸發發光晚 3～5 秒才出現，快捷列是立刻，2026-10-05；暴雪內建一樣）。
-- 比對用這一格的基本法術／目錄的覆蓋法術／當下的覆蓋法術（C_SpellBook.FindSpellOverrideByID，明文）。
-- 認到的 id 記在 rec.procEventID：熄的時候覆蓋可能已經換回去了，靠它認；暴雪誤判的 HideAlert 也靠它擋。
-- 只改 rec.procActive ⇒ 我們接管的發光；沒接管（暴雪自己的 SpellActivationAlert）不碰——要它亮得叫暴雪的
-- manager 在它的框上建欄位，會污染。
local function CellMatches(rec, id)
    if rec.procEventID == id then return true end
    local info = ns.Catalog.Info(rec.cooldownID)
    if not info or type(info.equipSlot) == "number" then return false end
    local base = info.spellID
    if id == base or id == info.overrideSpellID then return true end
    local find = C_SpellBook and C_SpellBook.FindSpellOverrideByID
    if find and type(base) == "number" then
        local ok, ov = pcall(find, base)
        if ok and Plain(ov) == id then return true end
    end
    return false
end

local function OnOverlayEvent(show, id)
    id = Plain(id)
    if type(id) ~= "number" or ns.released then return end
    local aura = ns.Viewers.AURA_KIND
    ns.Viewers.EnumerateItems(function(item, rec)
        if rec.custom or rec.cooldownID == nil or (aura and aura[rec.barKey]) then return end
        if not CellMatches(rec, id) then return end
        if show then
            rec.procEventID = id
            if rec.procActive ~= true then
                rec.procActive = true
                G.SyncProc(item, rec)
            end
        else
            rec.procEventID = nil
            if rec.procActive ~= false then
                rec.procActive = false
                G.SyncProc(item, rec)
            end
        end
    end)
end
G.OnOverlayEvent = OnOverlayEvent                                   -- 測試用
G.OnHideAlert = OnHideAlert                                         -- 測試用

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

-- 「要不要現在亮」（純函式，離線可測）：usable 是已經過 Plain 的明文（讀不到＝nil）。
-- 只有「開了資源檢查、而且明文確定不可用」才等；其餘一律現在亮（讀不到 fail-open）
function G.ReadyGate(requireUsable, usable)
    if requireUsable and usable == false then return "wait" end
    return "now"
end

-- 暴雪 item 用哪個法術問引擎要 duration 物件／問資源夠不夠（覆寫優先）
local function SpellOf(rec)
    local info = ns.Catalog and ns.Catalog.Info(rec.cooldownID)
    return info and (info.overrideSpellID or info.spellID) or nil
end

-- 問資源用哪個法術：暴雪 item 照 SpellOf；自訂法術用它自己的；自訂物品／裝備欄不問
local function UsableSpellOf(rec)
    if rec.custom then
        if rec.kind ~= "spell" then return nil end
        return rec.overrideID or rec.spellID
    end
    return SpellOf(rec)
end

-- 明文布林或 nil（秘密值、API 不在、pcall 失敗都是 nil ⇒ ReadyGate 當可用）
local function ReadUsable(rec)
    local id = UsableSpellOf(rec)
    local api = C_Spell and C_Spell.IsSpellUsable
    if not (id and api) then return nil end
    local ok, usable = pcall(api, id)
    if not ok then return nil end
    usable = Plain(usable)
    if type(usable) == "boolean" then return usable end
    return nil
end

-- 資源檢查開關：逐法術覆寫（overrides[id].readyGlowUsable）優先，沒覆寫退回條層 glow.ready.requireUsable
local function RequireUsable(rec, barKey)
    return ns.SpellSetting(barKey, rec.cooldownID, "readyGlowUsable") and true or false
end

-- 亮＋排計時熄（冷卻轉好當下、或等資源等到了）
local function Light(rec, barKey)
    G.readyFired = G.readyFired + 1
    local mode = ReadyMode(barKey, rec)
    if mode == "whileReady" then
        -- 狀態模式：照現況重算；探針與本尊的到期可能差幾毫秒，過一下再對一次
        G.ApplyReadyState(rec)
        C_Timer.After(0.1, function() G.ApplyReadyState(rec) end)
        return
    end
    Start(rec, "ready", barKey)
    local token = (rec.readyToken or 0) + 1
    rec.readyToken = token
    -- 亮到用掉為止：不排計時，熄燈只靠 CooldownStarted。回充那條收不到「用掉了」（見檔頭），照秒數熄
    if mode == "untilUsed" and not rec.probeCharges then return end
    local dur = tonumber(ns.Setting(barKey, "glow.ready.duration")) or 3
    if dur <= 0 then dur = 3 end
    C_Timer.After(dur, function()
        if rec.readyToken == token then Stop(rec, "ready") end
    end)
end

-- ── 等資源的格子 ─────────────────────────────────────────────────────────
-- 弱鍵表：rec 被回收也不會卡在這裡。事件只在至少有一格等待中時註冊，最後一格清掉就解除
local pending = setmetatable({}, { __mode = "k" })
local watching, scanArmed = false, false
local ScanPending

MarkDirty = function()
    if scanArmed then return end
    scanArmed = true
    ns.Defer(ScanPending)
end

local function Watch(on)
    if watching == on then return end
    watching = on
    local E = ns.Events
    if on then
        E.Register("SPELL_UPDATE_USABLE", "glow_ready_wait", MarkDirty)
        E.Register("UNIT_POWER_FREQUENT", "glow_ready_wait", MarkDirty, "player")
    else
        E.Unregister("SPELL_UPDATE_USABLE", "glow_ready_wait")
        E.Unregister("UNIT_POWER_FREQUENT", "glow_ready_wait")
    end
end

CancelPending = function(rec)
    if not (rec and rec.readyPending) then return end
    rec.readyPending = nil
    pending[rec] = nil
    if next(pending) == nil then Watch(false) end
end
G.CancelPending = CancelPending

-- readyPending 存的是等待開始時的 cooldownID：暴雪回收框給別的法術（身分換了）就不算數
local function StillPending(rec)
    return rec.readyPending ~= nil and rec.readyPending == rec.cooldownID and ReadyOn(rec)
        and Wanted(rec, rec.claimKey, "ready")
end

ScanPending = function()
    scanArmed = false
    for rec in pairs(pending) do
        if not StillPending(rec) then
            CancelPending(rec)
        else
            local barKey = rec.claimKey
            if G.ReadyGate(RequireUsable(rec, barKey), ReadUsable(rec)) == "now" then
                CancelPending(rec)
                Light(rec, barKey)
            end
        end
    end
end
G.ScanPending = ScanPending

function G.PendingCount()
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    return n
end

local function Fire(rec)
    -- 冷卻狀態先重算（不受下面發光／音效的提早 return 影響）
    if ns.Decorate and ns.Decorate.RefreshState then ns.Decorate.RefreshState(rec) end
    if not ReadyOn(rec) then return end
    local barKey = rec.claimKey
    -- 音效在轉好那一刻響，不看資源
    if SoundWanted(rec) then ns.Sound.OnReady(rec) end
    if not Wanted(rec, barKey, "ready") then return end
    CancelPending(rec)
    -- 資源檢查只管「亮幾秒」「亮到用掉」：「就緒時一直亮」是狀態模式（ApplyReadyState），不等
    local req = ReadyMode(barKey, rec) ~= "whileReady" and RequireUsable(rec, barKey) and true or false
    local usable = nil                    -- ⚠ 不能寫成 req and ReadUsable(rec) or nil：false 會被吃掉
    if req then usable = ReadUsable(rec) end
    if G.ReadyGate(req, usable) == "wait" then
        rec.readyPending = rec.cooldownID
        pending[rec] = true
        Watch(true)
        return
    end
    Light(rec, barKey)
end
G.FireReady = Fire

-- 進了新的冷卻（用掉了）：就緒發光不用等滿秒數，當場熄。token 換掉讓計時到期那支什麼都不做。
-- 還在等資源的也取消（等的那一次冷卻已經不算數了）
function G.CooldownStarted(rec)
    CancelPending(rec)
    if not (rec and rec.glowOn and rec.glowOn.ready) then return end
    if rec.readyWhile then G.ApplyReadyState(rec) return end      -- 狀態模式不熄，換宿主 alpha
    rec.readyToken = (rec.readyToken or 0) + 1
    Stop(rec, "ready")
end

-- 就緒時一直亮（mode "whileReady"）：發光開著，宿主 alpha 跟「在不在冷卻」。冪等，高頻呼叫（每次 GCD）。
-- 不適用（模式不是、沒開、停放、隱藏、增益類、未學會）⇒ 這一格之前是狀態模式點的燈就收掉、宿主 alpha 還原。
local function CooldownStateOf(rec, owner)
    if rec.custom then
        if rec.kind == "spell" and rec.known == false then return nil end
        return ns.Custom and ns.Custom.CooldownState and ns.Custom.CooldownState(rec)
    end
    local D = ns.Decorate
    if not (D and D.CooldownState) then return nil end
    return D.CooldownState(owner or (D.ItemOf and D.ItemOf(rec)), rec)
end

function G.ApplyReadyState(rec, owner)
    if not rec then return end
    local barKey = rec.claimKey or rec.placedBar
    local aura = not rec.custom and ns.Viewers.AURA_KIND and ns.Viewers.AURA_KIND[rec.barKey]
    local want = barKey and not aura and not Hidden(rec) and not (ns.released and not rec.custom)
        and ReadyMode(barKey, rec) == "whileReady" and Wanted(rec, barKey, "ready")
    local D = ns.Decorate
    if not want then
        if rec.readyWhile then
            rec.readyWhile = nil
            if D and D.CdWorkSync then D.CdWorkSync(rec, owner) end     -- 冷卻事件的全掃清單跟著重判
            Stop(rec, "ready")
            local h = rec.glowHosts and rec.glowHosts.ready
            if h then h:SetAlpha(1) end
        end
        return
    end
    if not rec.readyWhile then
        rec.readyWhile = true
        if D and D.CdWorkSync then D.CdWorkSync(rec, owner) end
    end
    rec.readyToken = (rec.readyToken or 0) + 1        -- 計時模式留下的熄燈計時作廢
    local kind, v = CooldownStateOf(rec, owner)
    -- 明文（效能修整 E3 #12）：冷卻中直接 Stop、宿主 alpha 還原 1；就緒才 Start（有簽章去重，重複呼叫便宜）。
    -- 以前冷卻中是「發光照開、宿主 alpha 0」——MiliUIGlow 的共用 driver 對 alpha 0 的框照樣每幀算。
    -- rec.readyWhile 仍是 true（＝這格開著就緒時一直亮，不是「正在亮」）。
    -- 秘密分支不動：Lua 不知道亮不亮，只能發光一直開著、交給宿主的 SetAlphaFromBoolean
    if kind == "plain" then
        local h = rec.glowHosts and rec.glowHosts.ready
        if v then
            Stop(rec, "ready")
            if h then h:SetAlpha(1) end
        else
            Start(rec, "ready", barKey)
            h = rec.glowHosts and rec.glowHosts.ready
            if h then h:SetAlpha(1) end
        end
        return
    end
    Start(rec, "ready", barKey)
    local h = rec.glowHosts and rec.glowHosts.ready
    if not h then return end
    if not (kind == "secret" and h.SetAlphaFromBoolean and pcall(h.SetAlphaFromBoolean, h, v, 1, 0)) then
        h:SetAlpha(0)                                  -- 判不出來＝不亮
    end
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
    rec.probeArmed, rec.probeID, rec.probeCharges = true, rec.cooldownID, charges
end

-- 暴雪清掉冷卻（到期那一刻它自己清、或冷卻被重置）而探針還武裝著 ⇒ 就是轉好了
function G.OnItemClear(item, rec)
    -- 冷卻狀態：暴雪清掉冷卻（到期或被重置）＝現在可能轉好了，先照現況重算 alpha。
    -- 暴雪對沒在冷卻的格子每次 GCD 也會 Clear ⇒ 這裡不排 0.1 秒的補算（探針觸發的 Fire 才排）
    if ns.Decorate and ns.Decorate.RefreshState then ns.Decorate.RefreshState(rec, true) end
    if rec.readyWhile then G.ApplyReadyState(rec, item) end
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
            if tex and type(c) == "table" then
                ns.Decorate.PaintFill(tex, nil, { r = c.r or 1, g = c.g or 0.5, b = c.b or 0, a = c.a or 1 })
            end
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
            -- 還原成條的單色或漸層（F8a；同 ApplyBarLook 的那支）
            if tex then ns.Decorate.PaintFill(tex, barKey and ns.Setting(barKey, "bar") or nil) end
            -- 層數換色那一層在條身底下、暴雪的填充要維持透明（Core/StackGate.lua）
            if ns.StackGate then ns.StackGate.Reconceal(owner, rec) end
        end
    end
end

-- ⚠ 這兩支是「後掛勾本體一律 ns.Guard」的**唯一例外**（效能修整 E3 #13）：暴雪在 item 的 OnUpdate 裡每幀叫
-- Show／HidePandemicStateFrame，以前每次都經過 ns.Guard 的 xpcall＋geterrorhandler()。無事路徑只有
-- 一次弱鍵表查詢（frames[item]，item 是框不是秘密值）＋一個布林比對＋計數，不可能拋錯 ⇒ 不包；
-- 狀態真的變了才進 Guard 包著的 ApplyPandemicGuarded（那裡會碰設定、邊框、條身材質，可能拋錯）。
-- 改這兩支時別往無事路徑加任何東西。
local frames = ns.Viewers and ns.Viewers.frames or {} -- Core/Viewers.lua 在本檔之前載入；HookItem 再對一次（表本身不換）
local function ApplyPandemicState(item, rec, on)
    rec.pandemic = on
    G.ApplyPandemic(item, rec)
end
local ApplyPandemicGuarded = ns.Guard and ns.Guard(ApplyPandemicState) or ApplyPandemicState

local function OnShowPandemic(item)
    G.pandemicCalls = G.pandemicCalls + 1
    local rec = frames[item]
    if not rec or rec.pandemic then return end      -- 暴雪每幀叫：狀態沒變就走
    G.pandemicChanges = G.pandemicChanges + 1
    ApplyPandemicGuarded(item, rec, true)
end

local function OnHidePandemic(item)
    G.pandemicCalls = G.pandemicCalls + 1
    local rec = frames[item]
    if not rec or not rec.pandemic then return end
    G.pandemicChanges = G.pandemicChanges + 1
    ApplyPandemicGuarded(item, rec, false)
end
G.OnShowPandemic, G.OnHidePandemic = OnShowPandemic, OnHidePandemic   -- 測試用

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
    -- 無損刷新：不包 Guard（見 OnShowPandemic 上面的說明；Apply 那段自己包）
    frames = ns.Viewers.frames
    if item.ShowPandemicStateFrame then
        hooksecurefunc(item, "ShowPandemicStateFrame", OnShowPandemic)
    end
    if item.HidePandemicStateFrame then
        hooksecurefunc(item, "HidePandemicStateFrame", OnHidePandemic)
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
    -- 四條全掃：冷卻格也有生效發光（倒增益時間那段，「脫戰也亮」關著時要跟著切）
    ns.Viewers.EnumerateItems(function(item, rec) G.SyncActive(item, rec) end)
end

function G.Init()
    if initialized then return end
    initialized = true
    inCombat = InCombatLockdown() and true or false
    ns.Events.Register("PLAYER_REGEN_DISABLED", "glow_combat", function() OnCombatChanged(true) end)
    ns.Events.Register("PLAYER_REGEN_ENABLED", "glow_combat", function() OnCombatChanged(false) end)
    ns.Events.Register("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "glow_proc", function(id) OnOverlayEvent(true, id) end)
    ns.Events.Register("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "glow_proc", function(id) OnOverlayEvent(false, id) end)
    if not InstallAlertHooks() then
        -- 動作條那一包理論上一定在；萬一比我們晚，等登入完成再試一次
        ns.Events.Register("PLAYER_ENTERING_WORLD", "glow_hooks", function()
            if InstallAlertHooks() then ns.Events.Unregister("PLAYER_ENTERING_WORLD", "glow_hooks") end
        end)
    end
end
