------------------------------------------------------------
-- 玩家施法條（獨立 HUD，容器 MiliUICDM_Bar_castbar）
--
-- 引擎從套組自己的單位框架施法條改來（單位固定 "player"，拿掉單位框依賴），
-- 另外併入套組本體施法條強化的兩樣：引導刻度（固定跳數表）與延遲條。
--
-- 12.1 鐵律（實戰驗證過的寫法，勿改）：
--   * 秘密模式：起訖時間是秘密值 → UnitCastingDuration 等 duration 物件餵 SetTimerDuration
--     由引擎驅動；不掛每幀 OnUpdate，改 10Hz ticker
--   * GetTotalDuration() 可能回秘密數字，落地前必 issecretvalue 檢查
--   * notInterruptible 是秘密 boolean，永不 if，用 EvaluateColorValueFromBoolean
--   * 圖示：施法中必有圖示，直接 SetTexture(texture)
--   * 偵測施法用 ~= nil（秘密值的 nil-ness 可讀）
--   * 事件處理器只轉手 ns.Defer：UNIT_SPELLCAST_FAILED／SENT 在按鍵的 secure 流程裡同步派送，
--     在那裡跑我們的 Lua 等於把 taint 灌進快捷列
--
-- 材質選單多一項「暴雪施法條」（texture ＝ "blizzard"，只有施法條有）：填充用遊戲內建施法條的圖集
-- UI-CastingBar-Filling-Standard、去飽和，顏色照下面的上色流程（施法／引導／不可打斷／斷法就緒／蓄力
-- 最後都是對填充貼圖 SetVertexColor）。一般施法與引導用同一張，**不依不可打斷換圖**（那是秘密布林）。
--
-- 動畫材質（Core/Media.lua 的 M.FX：彩虹／宇宙星辰／閃電／熔岩／火焰；專注目標施法條 2026-11-06 也接上，見 CB.Fx）：顏色烤在圖裡 ⇒ 選到時底色自動白（不然被施法色染髒），
-- 蓄力／斷法就緒／不可打斷／打斷照舊乘上去；animate 開著再疊「效果層」（見下面，全程引擎跑）。
--
-- 刻度、延遲、蓄力分階都要「明文的時間軸」（開始／結束讀得到）：讀不到就不畫，
-- 條本身照樣由 duration 物件驅動。位置一律用設定算出來的寬度（不讀框的幾何）。
--
-- 暴雪的玩家施法條（hideBlizzard）：只解它的事件（UnregisterAllEvents），跟單位框架已驗證的
-- 做法同一套 —— 不 Hide、不 SetParent、不寫它的欄位。解之前先用 IsEventRegistered 記下
-- 它註冊了哪些，關掉選項時照原樣裝回去（所以不需要 /reload）；
-- 例外：單位框架也在隱藏它時不裝回（見 UnitFramesHidesBlizzard）。
-- 替身 OverlayPlayerCastingBarFrame 只在它掛在覆蓋快捷列上時解，專精／天賦／專業視窗裡的那條留著（見 OnOverrideBar）。
------------------------------------------------------------
local _, ns = ...

-- 關掉貼圖的像素貼齊（Core/Media.lua 的 ns.NoSnap；離線測試沒載 Media 時是空操作）
local function NoSnap(t) if ns.NoSnap then ns.NoSnap(t) end return t end

local L = ns.L

ns.Castbar = {}
local CB = ns.Castbar

local IsSecret = ns.IsSecret
local Eval = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean

local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local FADE_TIME = 0.3
local INTERRUPT_HOLD = 0.4
local PREVIEW_TIME = 10
local PREVIEW_ICON = "Interface\\Icons\\Spell_Nature_TimeStop"
local PREVIEW_LAG = 120           -- 預覽的假延遲（毫秒）
local MAX_MARKS = 24

local function Plain(v)
    if type(v) ~= "number" or IsSecret(v) then return nil end
    return v
end

local function PlainStr(v)
    if type(v) ~= "string" or IsSecret(v) then return nil end
    return v
end

local function Cfg() return ns.DB and ns.DB.ConfigTable("castbar") end
CB.Cfg = Cfg

local function SecretsActive()
    local S = C_Secrets
    if not (S and S.HasSecretRestrictions) then return false end
    local ok, v = pcall(S.HasSecretRestrictions)
    if not ok or IsSecret(v) then return true end      -- 讀不到就當受限（走 duration 物件那條）
    return v and true or false
end
CB.SecretsActive = SecretsActive          -- 專注目標施法條（Modules/FocusCastbar.lua）共用

local function TimerDir(isChannel, isEmpowered)
    if isChannel and not isEmpowered then
        return Enum.StatusBarTimerDirection.RemainingTime
    end
    return Enum.StatusBarTimerDirection.ElapsedTime
end
CB.TimerDir = TimerDir

-- 時間文字（timeFormat）：
--   remainTotal 剩餘/總 0.3/1.5 ｜ elapsedTotal 已唱/總 1.2/1.5 ｜ remain 0.3 ｜ elapsed 1.2
-- 拿不到總長（total=0）時：含總長的格式退化成不含；剩餘算不出來就留白
function CB.FormatTime(fmt, elapsed, total)
    fmt = fmt or "remainTotal"
    if elapsed < 0 then elapsed = 0 end
    if total > 0 then
        if elapsed > total then elapsed = total end
        local remain = total - elapsed
        if fmt == "remainTotal" then return string.format("%.1f/%.1f", remain, total)
        elseif fmt == "elapsedTotal" then return string.format("%.1f/%.1f", elapsed, total)
        elseif fmt == "remain" then return string.format("%.1f", remain)
        else return string.format("%.1f", elapsed) end
    end
    if fmt == "elapsed" or fmt == "elapsedTotal" then
        return string.format("%.1f", elapsed)
    end
    return ""
end
local FormatTime = CB.FormatTime

-- 法術名截字（UTF-8 字元數）。秘密字串原樣回傳（不能取長度也不能切）
function CB.Truncate(s, n)
    n = tonumber(n) or 0
    if n <= 0 then return s end
    local p = PlainStr(s)
    if not p then return s end
    local count, i, len = 0, 1, #p
    while i <= len do
        count = count + 1
        if count > n then return p:sub(1, i - 1) .. "…" end
        local c = p:byte(i)
        i = i + ((c >= 240 and 4) or (c >= 224 and 3) or (c >= 192 and 2) or 1)
    end
    return p
end

------------------------------------------------------------
-- 引導刻度：固定跳數表（spellID → 跳數），天賦會改跳數的幾顆在天賦變動時重算。
-- 查表先用 spellID、再用法術名（覆寫法術 ID 不同但名字一樣）；兩個都只吃明文。
------------------------------------------------------------
local TICKS = {
    -- 術士
    [234153] = 5,  [198590] = 5,  [217979] = 5,  [196447] = 15, [417537] = 3,
    -- 德魯伊
    [740]    = 4,  [391528] = 16,
    -- 牧師
    [64843]  = 4,  [15407]  = 6,  [391403] = 4,  [47540]  = 3,  [64901]  = 5,
    [263165] = 3,  [400169] = 3,
    -- 法師
    [5143]   = 5,  [205021] = 5,  [12051]  = 6,  [198100] = 8,  [382440] = 4,
    -- 武僧
    [117952] = 4,  [115175] = 8,  [443028] = 4,
    -- 喚能師
    [356995] = 3,  [370960] = 5,
    -- 惡魔獵人
    [212084] = 10, [452486] = 10,
    -- 戰士
    [436358] = 3,
    -- 獵人
    [257044] = 7,
}
local tickByID, tickByName = {}, {}

local function IsKnown(id)
    local fn = IsPlayerSpell
    if not fn then return false end
    local ok, v = pcall(fn, id)
    return ok and not IsSecret(v) and v == true
end

function CB.RebuildTicks()
    for k in pairs(tickByID) do tickByID[k] = nil end
    for k in pairs(tickByName) do tickByName[k] = nil end
    for id, n in pairs(TICKS) do tickByID[id] = n end
    local class = ns.playerClass
    if class == "PRIEST" then
        tickByID[47540] = IsKnown(193134) and 4 or 3
    elseif class == "MAGE" then
        tickByID[5143] = IsKnown(236628) and 8 or 5
    elseif class == "DRUID" then
        tickByID[391528] = (IsKnown(391548) or IsKnown(393991) or IsKnown(393414) or IsKnown(393371)) and 12 or 16
    elseif class == "EVOKER" then
        tickByID[356995] = IsKnown(1219723) and 4 or 3
    end
    local getName = C_Spell and C_Spell.GetSpellName
    if getName then
        for id, n in pairs(tickByID) do
            local ok, name = pcall(getName, id)
            name = ok and PlainStr(name)
            if name then tickByName[name] = n end
        end
    end
end

function CB.TickCount(spellID, name)
    local id = Plain(spellID)
    if id and tickByID[id] then return tickByID[id] end
    local nm = PlainStr(name)
    if nm and tickByName[nm] then return tickByName[nm] end
    return 0
end

------------------------------------------------------------
-- 填充材質
------------------------------------------------------------
local BLIZZARD_FILL_ATLAS = "UI-CastingBar-Filling-Standard"
CB.BLIZZARD_TEXTURE = "blizzard"

-- 純函式：材質 token → 填充用的 圖檔路徑, 圖集名（兩者擇一）
function CB.FillTexture(token)
    if token == CB.BLIZZARD_TEXTURE then return nil, BLIZZARD_FILL_ATLAS end
    return ns.Media.Texture(token), nil
end

-- 圖集查得到才用（名字打錯時 SetStatusBarTexture 不報錯、只會畫出缺圖的綠塊）
local function AtlasExists(atlas)
    local fn = C_Texture and C_Texture.GetAtlasInfo
    if not fn then return true end
    local ok, info = pcall(fn, atlas)
    return ok and info ~= nil
end

-- 換填充材質。⚠ 火花錨在填充貼圖上：呼叫端在這之後才下錨點
local function SetFillTexture(bar, token)
    local path, atlas = CB.FillTexture(token)
    if atlas and AtlasExists(atlas) then
        -- SetStatusBarTexture 收圖集名（暴雪自己的施法條就是這樣設）；不收的版本退回貼圖 SetAtlas
        local ok = pcall(bar.SetStatusBarTexture, bar, atlas)
        local tex = bar:GetStatusBarTexture()
        if not ok or not tex then
            bar:SetStatusBarTexture(SOLID)
            tex = bar:GetStatusBarTexture()
            if tex then pcall(tex.SetAtlas, tex, atlas, false) end
        end
        -- 去飽和成灰階漸層，顏色交給 ApplyColor 的 SetVertexColor
        if tex then tex:SetDesaturated(true) end
        NoSnap(bar)
        return
    end
    bar:SetStatusBarTexture(path or SOLID)
    local tex = bar:GetStatusBarTexture()
    if tex then tex:SetDesaturated(false) end
    NoSnap(bar)              -- 填充跟 1px 黑邊相接：不貼齊（換材質後再關一次；專注目標施法條也走這支）
end
CB.SetFillTexture = SetFillTexture

-- 材質 token 是不是動畫材質（判定在 Core/Media.lua；離線測試沒載 Media 時一律不是）
function CB.IsFx(token)
    local M = ns.Media
    return (M and M.IsFx and M.IsFx(token)) and true or false
end

------------------------------------------------------------
-- 框
------------------------------------------------------------
local container, f, ev

-- 施法狀態放在自己的表（不掛在框上）：castState 1 施法、2 引導、3 淡出、4 打斷停留；nil ＝ 閒置
local S = { displayToken = 0, castUnit = "player" }
CB.state = S

local function Width(cfg)
    local w = tonumber(cfg.width) or 0
    if w <= 0 then
        w = ns.Bars and ns.Bars.AutoWidth and ns.Bars.AutoWidth("castbar") or 0
        if w <= 0 then w = 200 end
    end
    return w
end
CB.Width = Width

local function MinSize()
    local cfg = Cfg() or {}
    return Width(cfg), tonumber(cfg.height) or 20
end

-- 一條玩家施法條的零件（圖示、條、效果層、刻度與延遲區、火花、文字、打斷震動）建在框 h 上。畫面上那條（f）與設定頁的
-- 內嵌樣本（CB.CreateSample）各建一份；版面、刻度、上色、名字、火花也都走同一批收 (h, st) 的函式——st 是那一條的施法
-- 狀態表（畫面上那條是 S，樣本是它自己的小表）⇒ 樣本的呼叫順序與疊層跟畫面上的一模一樣，不會各畫各的
local function BuildParts(h)
    h.iconFrame = CreateFrame("Frame", nil, h, "BackdropTemplate")
    h.icon = NoSnap(h.iconFrame:CreateTexture(nil, "ARTWORK"))     -- 圖示、底跟 1px 黑邊相接：不貼齊
    h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    h.barHolder = CreateFrame("Frame", nil, h, "BackdropTemplate")
    h.bgTex = NoSnap(h.barHolder:CreateTexture(nil, "BACKGROUND"))
    h.bgTex:SetTexture(SOLID)
    h.bar = CreateFrame("StatusBar", nil, h.barHolder)
    h.bar:SetStatusBarTexture(SOLID)
    h.bar:SetMinMaxValues(0, 1)
    h.bar:SetValue(0)

    -- 效果層（見「效果層」）：裁切框 → host → 每一層一張貼圖；貼圖是池化的、用到才建，錨點與動畫在 Layout 設
    CB.FxHost(h, h.bar)

    -- 刻度、蓄力分階、延遲區：一層蓋在填充（與效果層）上
    h.marks = CreateFrame("Frame", nil, h.bar)
    h.marks:SetAllPoints(h.bar)
    h.markPool = {}

    -- 火花：只建立、不錨定（錨點要對到填充貼圖，Layout 設完材質才錨）。掛在刻度那一層，才不會被效果層蓋掉半邊
    h.spark = h.marks:CreateTexture(nil, "OVERLAY")
    h.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    h.spark:SetBlendMode("ADD")
    h.spark:Hide()
    h.latency = NoSnap(h.marks:CreateTexture(nil, "OVERLAY", nil, 6))
    h.latency:SetTexture(SOLID)
    h.latency:SetVertexColor(1, 0, 0, 0.5)
    h.latency:Hide()

    h.textFrame = CreateFrame("Frame", nil, h)
    h.textFrame:SetAllPoints(h.barHolder)
    -- ⚠ 先給字型才能 SetText
    h.nameText = h.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(h.nameText, 12, "OUTLINE")
    h.nameText:SetJustifyH("LEFT")
    h.nameText:SetWordWrap(false)
    h.timeText = h.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(h.timeText, 12, "OUTLINE")
    h.timeText:SetJustifyH("RIGHT")
    h.timeText:SetWordWrap(false)

    -- 打斷震動：數值照暴雪自己施法條的 InterruptShakeAnim（停 0.1 秒後每 0.05 秒跳一次，
    -- 四段位移加總歸零）。Translation 只動畫面上的位置，不改錨點
    h.shake = h:CreateAnimationGroup()
    local steps = { { 0, 0, 0.1, 0 }, { -1, 1, 0, 0.05 }, { 1, -2, 0, 0.05 }, { 1, 2, 0, 0.05 }, { -1, -1, 0, 0.05 } }
    for i, s in ipairs(steps) do
        local t = h.shake:CreateAnimation("Translation")
        t:SetOffset(s[1], s[2])
        t:SetDuration(s[3])
        t:SetStartDelay(s[4])
        t:SetOrder(i)
    end
end

local function Build()
    f = CreateFrame("Frame", nil, container)
    f:SetAllPoints(container)
    BuildParts(f)
    f:Hide()
end

local function Mark(h, i)
    local t = h.markPool[i]
    if not t then
        t = NoSnap(h.marks:CreateTexture(nil, "OVERLAY", nil, 7))
        t:SetTexture(SOLID)
        h.markPool[i] = t
    end
    return t
end

local function HideMarks(h, from)
    for i = from or 1, #h.markPool do h.markPool[i]:Hide() end
end

-- 在條上 p（0～1，沿填充方向從起點算）畫一條線
local function PlaceMark(h, st, i, p, r, g, b, a)
    local t = Mark(h, i)
    local x = st.barW * p
    if st.reversed then x = st.barW - x end
    t:ClearAllPoints()
    t:SetSize(ns.P.Pixel(1), st.barH)
    t:SetPoint("CENTER", h.marks, "LEFT", x, 0)
    t:SetVertexColor(r, g, b, a)
    t:Show()
end

------------------------------------------------------------
-- 效果層（材質是動畫材質、animate 開著才用；2026-11-04 彩虹、11-06 改成通用）
--
-- StatusBar 自己管填充貼圖的座標，填充本身動不了 ⇒ 另外疊一層：裁切框 f.flowClip（SetClipsChildren）兩點錨在條的起點與
-- **填充貼圖的前緣**（跟火花同一招——錨在秘密尺寸的貼圖上沒問題，只要不讀幾何），框裡照 Core/Media.lua 的 M.FX[token].layers
-- 由下往上疊貼圖 ⇒ 效果只露出已填的那一截。全程引擎跑，沒有每幀 Lua，秘密模式照常。兩種層：
--   捲動（scroll）  整條寬、REPEAT 平鋪，循環的貼圖座標動畫往填充方向捲一整個週期（反向填充反著捲）；可加明暗來回（twinkle）
--   序列圖（flip）  FlipBook 換格；pause > 0 的在同一個循環裡接一段看不見的停頓（閃電：打一道、停一下）；
--                   overflow 的往條的上緣外多畫一截（火舌），裁切框跟著加高
-- 兩種層各用各的貼圖池（播過 FlipBook 的貼圖，座標不保證還原），序列圖再分「有停頓／連續」兩池（動畫組的組成不同）。
-- 速度：每個動畫的秒數除以 animSpeed（不靠動畫組的速度倍率）。
-- 狀態色要露出來時把這層壓透明，底下的填充貼圖照 ApplyColor 的顏色：不可打斷 → 裁切框的 alpha、斷法就緒 → host 的
-- alpha（兩個布林各管一層，秘密布林餵 SetAlphaFromBoolean、明文直接 SetAlpha）。打斷／失敗／收條時停動畫、藏層。
------------------------------------------------------------
-- 效果層的宿主 h：帶 flowClip／flowHost／fxScroll／fxFlip／fxActive 這幾欄的表。玩家施法條是 f 自己，
-- 設定頁的內嵌樣本（CB.CreateSample）另有一份 ⇒ 下面幾支都收 h，不直接摸 f／S
function CB.FxHost(h, bar)
    h.flowClip = CreateFrame("Frame", nil, bar)
    h.flowClip:SetClipsChildren(true)
    h.flowClip:Hide()
    h.flowHost = CreateFrame("Frame", nil, h.flowClip)
    h.flowHost:SetAllPoints(bar)
    h.fxBar = bar
    h.fxScroll, h.fxFlip = {}, {}
    h.fxActive = {}                     -- 這次版面用到的層（FxPlay／FxStop 走這張）
end

-- 這份設定要畫哪些效果層（不用 ＝ nil）
local function FxWanted(cfg)
    if cfg.animate == false then return nil end
    local M = ns.Media
    return M and M.FxLayers and M.FxLayers(cfg.texture) or nil
end

-- ⚠ CreateAnimation 的型別名是 "TextureCoord"，不是 XML 標籤的 "TextureCoordTranslation"（2026-11-04 實機：
-- 給後者客戶端不報錯、回一個一般 Animation，SetOffset 是 nil）。兩個都試，拿到有 SetOffset 的才算
local function ScrollLayer(h, i)
    local L = h.fxScroll[i]
    if L then return L end
    L = { tex = NoSnap(h.flowHost:CreateTexture(nil, "ARTWORK")) }
    L.group = L.tex:CreateAnimationGroup()
    L.group:SetLooping("REPEAT")
    for _, kind in ipairs({ "TextureCoord", "TextureCoordTranslation" }) do
        local ok, a = pcall(L.group.CreateAnimation, L.group, kind)
        if ok and type(a) == "table" and a.SetOffset then
            L.scroll = a
            break
        end
        pcall(L.group.RemoveAnimations, L.group)
    end
    L.twGroup = L.tex:CreateAnimationGroup()
    L.twGroup:SetLooping("BOUNCE")
    L.twinkle = L.twGroup:CreateAnimation("Alpha")
    L.twinkle:SetSmoothing("IN_OUT")
    h.fxScroll[i] = L
    return L
end

-- 序列圖層：FlipBook 換格；paused 的多兩段 Alpha（播放那段全亮、停頓那段看不見），做法照天空騎術的閃電
local function FlipLayer(h, i, paused)
    local key = (paused and "p" or "c") .. i
    local L = h.fxFlip[key]
    if L then return L end
    L = { tex = NoSnap(h.flowHost:CreateTexture(nil, "ARTWORK")) }
    L.group = L.tex:CreateAnimationGroup()
    L.group:SetLooping("REPEAT")
    L.flip = L.group:CreateAnimation("FlipBook")
    L.flip:SetOrder(1)
    if paused then
        L.lit = L.group:CreateAnimation("Alpha")
        L.lit:SetFromAlpha(1)
        L.lit:SetToAlpha(1)
        L.lit:SetOrder(1)
        L.dark = L.group:CreateAnimation("Alpha")
        L.dark:SetFromAlpha(0)
        L.dark:SetToAlpha(0)
        L.dark:SetOrder(2)
    end
    h.fxFlip[key] = L
    return L
end

local function FxHideAll(h)
    for _, L in pairs(h.fxScroll) do
        L.group:Stop()
        L.twGroup:Stop()
        L.tex:Hide()
    end
    for _, L in pairs(h.fxFlip) do
        L.group:Stop()
        L.tex:Hide()
    end
    for i = #h.fxActive, 1, -1 do h.fxActive[i] = nil end
end

-- 照 layers 把池裡的貼圖設好（不播放）。reversed ＝ 反向填充、barH ＝ 條身的高。
-- 回傳 成功與否, 往上多畫的高度；捲動動畫建不出來（舊客戶端）＝ 失敗、整層不用
local function FxSetup(h, layers, cfg, reversed, barH)
    FxHideAll(h)
    local bar = h.fxBar
    local speed = tonumber(cfg.animSpeed) or 1
    if speed < 0.25 then speed = 0.25 elseif speed > 4 then speed = 4 end
    local dir = reversed and 1 or -1
    local overflow, nScroll, nFlip = 0, 0, 0
    for n, def in ipairs(layers) do
        local L
        if def.kind == "flip" then
            nFlip = nFlip + 1
            local pause = tonumber(def.pause) or 0
            L = FlipLayer(h, nFlip, pause > 0)
            L.tex:SetTexture(def.tex)
            pcall(L.flip.SetFlipBookRows, L.flip, def.rows)
            pcall(L.flip.SetFlipBookColumns, L.flip, def.cols)
            pcall(L.flip.SetFlipBookFrames, L.flip, def.frames)
            pcall(L.flip.SetFlipBookFrameWidth, L.flip, 0)
            pcall(L.flip.SetFlipBookFrameHeight, L.flip, 0)
            L.flip:SetDuration(def.time / speed)
            if L.lit then
                L.lit:SetDuration(def.time / speed)
                L.dark:SetDuration(pause / speed)
            end
            local ov = (tonumber(def.overflow) or 0) * (barH or 0)
            if ov > overflow then overflow = ov end
            L.tex:ClearAllPoints()
            L.tex:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, ov)
            L.tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
            L.tw = false
        else
            nScroll = nScroll + 1
            L = ScrollLayer(h, nScroll)
            if not L.scroll then
                FxHideAll(h)
                return false, 0
            end
            L.tex:SetTexture(def.tex, "REPEAT", "CLAMP")
            L.scroll:SetOffset(dir, 0)
            L.scroll:SetDuration(def.period / speed)
            L.tex:ClearAllPoints()
            L.tex:SetAllPoints(bar)
            L.tw = def.twinkle and true or false
            if L.tw then
                L.twinkle:SetFromAlpha(def.alpha or 1)
                L.twinkle:SetToAlpha(def.twinkle.lo)
                L.twinkle:SetDuration(def.twinkle.period / speed)
            end
        end
        L.tex:SetDrawLayer("ARTWORK", n)
        L.tex:SetBlendMode(def.blend or "BLEND")
        L.tex:SetVertexColor(1, 1, 1, 1)
        L.tex:SetAlpha(def.alpha or 1)        -- alpha 最後寫（貼圖的 SetAlpha 跟頂點色第四個參數是同一個值）
        L.tex:Show()
        h.fxActive[#h.fxActive + 1] = L
    end
    return true, overflow
end

-- 裁切框的前緣錨在填充貼圖 tex 上（換材質後貼圖是新的，跟火花一樣每次版面重下）；
-- 有往上竄的層（火舌）時裁切框的上緣跟著加高 overflow
local function FxAnchor(h, tex, reversed, overflow)
    h.flowClip:ClearAllPoints()
    if reversed then
        h.flowClip:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, overflow)
        h.flowClip:SetPoint("BOTTOMRIGHT", h.fxBar, "BOTTOMRIGHT", 0, 0)
    else
        h.flowClip:SetPoint("TOPLEFT", h.fxBar, "TOPLEFT", 0, overflow)
        h.flowClip:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, 0)
    end
end

local function FxPlay(h)
    h.flowClip:Show()
    for _, L in ipairs(h.fxActive) do
        if not L.group:IsPlaying() then L.group:Play() end
        if L.tw and not L.twGroup:IsPlaying() then L.twGroup:Play() end
    end
end

local function FxStop(h)
    for _, L in ipairs(h.fxActive) do
        L.group:Stop()
        if L.twGroup then L.twGroup:Stop() end
    end
    h.flowClip:Hide()
end

local function StopFlow()
    if not f.flowClip then return end
    FxStop(f)
end

-- 一個旗標（nil／明文／秘密布林）→ 框的 alpha：真 ＝ 0（讓底下的狀態色露出來）、假或沒有 ＝ 1
local function FlowAlpha(frame, flag)
    if flag == nil then frame:SetAlpha(1) return end
    if IsSecret(flag) then
        if not (frame.SetAlphaFromBoolean and pcall(frame.SetAlphaFromBoolean, frame, flag, 0, 1)) then
            frame:SetAlpha(1)
        end
        return
    end
    frame:SetAlpha(flag and 0 or 1)
end

-- 效果層給專注目標施法條（Modules/FocusCastbar.lua）共用：同一套貼圖池、同一套畫法，宿主各一份（CB.FxHost）
CB.Fx = { Wanted = FxWanted, Setup = FxSetup, HideAll = FxHideAll, Anchor = FxAnchor,
          Play = FxPlay, Stop = FxStop, Alpha = FlowAlpha }

------------------------------------------------------------
-- 版面（全部來自設定，不讀框的幾何）
------------------------------------------------------------
-- 零件的版面：W／H 是整條的寬高（呼叫端已經換算好）。st.castState 是施法中（1／2）時火花、效果層、刻度與延遲區照著重設
local DrawMarksOn
local function LayoutParts(h, st, cfg, W, H)
    local showIcon = cfg.showIcon ~= false
    local iconW = showIcon and H or 0
    local gap = showIcon and ns.P.Scale(tonumber(cfg.iconGap) or 1) or 0
    local left = cfg.iconSide ~= "RIGHT"
    h.iconFrame:SetShown(showIcon)
    h.iconFrame:ClearAllPoints()
    h.iconFrame:SetSize(iconW > 0 and iconW or 1, H)
    h.iconFrame:SetPoint(left and "TOPLEFT" or "TOPRIGHT", h, left and "TOPLEFT" or "TOPRIGHT", 0, 0)
    local edge = ns.P.Pixel(1)
    h.iconFrame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = edge })
    if ns.NoSnapBackdrop then ns.NoSnapBackdrop(h.iconFrame) end
    h.iconFrame:SetBackdropColor(0, 0, 0, 1)
    h.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
    h.icon:ClearAllPoints()
    h.icon:SetPoint("TOPLEFT", h.iconFrame, "TOPLEFT", edge, -edge)
    h.icon:SetPoint("BOTTOMRIGHT", h.iconFrame, "BOTTOMRIGHT", -edge, edge)

    local barW = W - iconW - gap
    if barW < 4 then barW = 4 end
    h.barHolder:ClearAllPoints()
    h.barHolder:SetSize(barW, H)
    h.barHolder:SetPoint(left and "TOPRIGHT" or "TOPLEFT", h, left and "TOPRIGHT" or "TOPLEFT", 0, 0)
    -- 1px 黑邊畫在外框上；條與底色內縮同一個厚度（見 project-miliui-pixel-snapping）
    local inset = ns.Media.BorderInset(1)
    h.barHolder:SetBackdrop({ edgeFile = SOLID, edgeSize = inset })
    if ns.NoSnapBackdrop then ns.NoSnapBackdrop(h.barHolder) end
    h.barHolder:SetBackdropBorderColor(0, 0, 0, 1)
    h.bgTex:ClearAllPoints()
    h.bgTex:SetPoint("TOPLEFT", h.barHolder, "TOPLEFT", inset, -inset)
    h.bgTex:SetPoint("BOTTOMRIGHT", h.barHolder, "BOTTOMRIGHT", -inset, inset)
    local bg = cfg.bgColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    h.bgTex:SetVertexColor(bg.r or 0.1, bg.g or 0.1, bg.b or 0.1, bg.a or 0.8)
    h.bar:ClearAllPoints()
    h.bar:SetPoint("TOPLEFT", h.barHolder, "TOPLEFT", inset, -inset)
    h.bar:SetPoint("BOTTOMRIGHT", h.barHolder, "BOTTOMRIGHT", -inset, inset)
    SetFillTexture(h.bar, cfg.texture)
    st.reversed = ns.FillReversed(cfg)
    h.bar:SetReverseFill(st.reversed)
    st.barW, st.barH = barW - inset * 2, H - inset * 2

    -- 層級：底 L → 條 L+1 → 效果層 L+2 → 刻度（含火花）L+3 → 文字 L+4；圖示 L+1
    local lvl = h:GetFrameLevel()
    h.barHolder:SetFrameLevel(lvl)
    h.bar:SetFrameLevel(lvl + 1)
    h.flowClip:SetFrameLevel(lvl + 2)
    h.marks:SetFrameLevel(lvl + 3)
    h.textFrame:SetFrameLevel(lvl + 4)
    h.iconFrame:SetFrameLevel(lvl + 1)

    -- 邊緣陰影（Core/Shape.lua）：條身與圖示各一圈；陰影框都是 h 的子框、層級 h − 1 ⇒ 圖示那圈不會蓋到條身的黑邊。
    -- 圖示藏著時只有條身一圈
    local SH = ns.Shape
    if SH then
        local spx, sa = SH.ShadowOf(cfg.shadow, cfg.shadowSize, cfg.shadowAlpha)
        SH.EdgeShadow(h, h.barHolder, spx, sa)
        SH.EdgeShadow(h, h.iconFrame, showIcon and spx or nil, sa)
    end

    -- 名字（font／textSize）與時間（timeFont／timeTextSize）各一組，沒存字型 ＝ 跟隨通用字型
    local general = ns.Setting(nil, "font")
    local outline = ns.Media.ThemeOutline()
    ns.Media.SetFont(h.nameText, tonumber(cfg.textSize) or 12, outline, ns.Media.ElementFont(cfg.font, general))
    ns.Media.SetFont(h.timeText, tonumber(cfg.timeTextSize) or 12, outline, ns.Media.ElementFont(cfg.timeFont, general))
    -- 錨點固定在左右兩緣的垂直中線（y ＝ 0 就是被動置中），位移照設定
    local no = type(cfg.nameOffset) == "table" and cfg.nameOffset or {}
    local to = type(cfg.timeOffset) == "table" and cfg.timeOffset or {}
    h.timeText:ClearAllPoints()
    h.timeText:SetPoint("RIGHT", h.textFrame, "RIGHT", tonumber(to.x) or -4, tonumber(to.y) or 0)
    h.nameText:ClearAllPoints()
    h.nameText:SetPoint("LEFT", h.textFrame, "LEFT", tonumber(no.x) or 4, tonumber(no.y) or 0)
    h.nameText:SetPoint("RIGHT", h.timeText, "LEFT", -4, 0)
    h.nameText:SetShown(cfg.showName ~= false)
    h.timeText:SetShown(cfg.showTime ~= false)

    -- 火花：跟著填充前緣。錨點在 SetStatusBarTexture 之後才下，換材質時要重下
    h.spark:SetSize(10, H * 2.2)
    h.spark:ClearAllPoints()
    local tex = h.bar:GetStatusBarTexture()
    if tex then h.spark:SetPoint("CENTER", tex, st.reversed and "LEFT" or "RIGHT", 0, 0) end
    h.spark:SetShown(cfg.showSpark ~= false and st.castState ~= nil and st.castState ~= 3 and st.castState ~= 4)

    -- 效果層：裁切框的前緣錨在填充貼圖上（換材質後貼圖是新的，跟火花一樣在這裡重下）；
    -- 有往上竄的層（火舌）時裁切框的上緣跟著加高。先停再設：動畫的秒數、方向可能都換了
    FxStop(h)
    local layers = tex and FxWanted(cfg) or nil
    local okFx, overflow = false, 0
    if layers then okFx, overflow = FxSetup(h, layers, cfg, st.reversed, st.barH) else FxHideAll(h) end
    st.flow = okFx
    if st.flow then
        FxAnchor(h, tex, st.reversed, overflow)
        if st.castState == 1 or st.castState == 2 then FxPlay(h) end
    end

    -- 施法中改了尺寸：刻度與延遲區照新寬度重畫
    if st.castState == 1 or st.castState == 2 then DrawMarksOn(h, st) end
end

function CB.Layout()
    if not f then return end
    local cfg = Cfg() or {}
    local W, H = Width(cfg), tonumber(cfg.height) or 20
    W, H = ns.P.Scale(W), ns.P.Scale(H)
    ns.Bars.SetPanelSize("castbar", W, H)
    LayoutParts(f, S, cfg, W, H)
end

------------------------------------------------------------
-- 顏色
------------------------------------------------------------
local function Colors()
    local cfg = Cfg()
    return cfg and cfg.colors or {}
end

local function C(c, dr, dg, db)
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return dr, dg, db
end

-- 蓄力：現在放開會是第幾階（明文時間軸才算得出來；算不出來當第 1 階）
local function EmpowerStage(st)
    local pts = st.stagePoints
    if not (pts and st.tStart) then return 1 end
    local elapsed = GetTime() - st.tStart
    local r = 0
    for i = 1, #pts do
        if elapsed >= pts[i] then r = i else break end
    end
    if r < 1 then r = 1 elseif r > 4 then r = 4 end
    return r
end

-- st ＝ 施法狀態表（畫面上那條是 S；設定頁的樣本是它自己的小表）
local function BaseColor(st)
    local cfg = Cfg() or {}
    local c = Colors()
    if st.castEmpowered then
        return C(c["empowerStage" .. EmpowerStage(st)], 0.35, 0.75, 0.35)
    end
    -- 動畫材質：底色白（施法色／職業色不染），上面的狀態色照舊乘上去
    if CB.IsFx(cfg.texture) then return 1, 1, 1 end
    if cfg.useClassColor then
        local r, g, b = ns.Style.Accent()
        return r, g, b
    end
    if st.castChannel then return C(c.channel, 0.906, 0.424, 0.2) end
    return C(c.cast, 0.906, 0.424, 0.2)
end

local function EvalTriple(cond, col, r, g, b)
    local cr, cg, cb = C(col, r, g, b)
    return Eval(cond, cr, r), Eval(cond, cg, g), Eval(cond, cb, b)
end

-- 曲線串接的保險：第一次被擋就永久放掉斷法就緒色，保住「不可打斷灰」
local chainOK = true

-- **畫面上那條（h ＝ f、st ＝ S）與設定頁的樣本（CB.CreateSample）共用**：樣本不另寫一份上色，餵明文的假狀態走同一條路
-- ⇒ 樣本上看到的就是實際的套用結果（斷法就緒染色、動畫讓位都照演），這裡寫錯兩邊一起錯、看得出來。
-- st 要有 castEmpowered／castChannel／castNotInterruptible／flow
local function PaintColorOn(h, st)
    local tex = h.bar:GetStatusBarTexture()
    if not tex then return end
    local cfg = Cfg() or {}
    local c = Colors()
    local br, bg, bb = BaseColor(st)
    local r, g, b = br, bg, bb
    local tinted = false
    local flowReady                           -- 效果層要讓位的「斷法就緒」旗標（nil ＝ 沒這回事）
    -- 斷法就緒（可能是秘密布林：只餵曲線）
    if cfg.interruptReady and chainOK and ns.Interrupt then
        local ready, has = ns.Interrupt.IsReady()
        if has then
            flowReady = ready
            if IsSecret(ready) then
                if Eval then
                    local ok, rr, gg, b2 = pcall(EvalTriple, ready, c.interruptReady, r, g, b)
                    if ok then r, g, b = rr, gg, b2; tinted = true end
                end
            elseif ready then
                r, g, b = C(c.interruptReady, r, g, b)
            end
        end
    end
    -- 不可打斷（可能是秘密布林：只餵曲線）
    local ni = st.castNotInterruptible
    if ni ~= nil then
        if IsSecret(ni) then
            if Eval then
                local ok, rr, gg, b2 = pcall(EvalTriple, ni, c.uninterruptible, r, g, b)
                if ok then
                    r, g, b = rr, gg, b2
                elseif tinted then
                    chainOK = false
                    r, g, b = EvalTriple(ni, c.uninterruptible, br, bg, bb)
                end
            end
        elseif ni then
            r, g, b = C(c.uninterruptible, 0.529, 0.529, 0.529)
        end
    end
    tex:SetVertexColor(r, g, b, 1)
    -- 效果層：不可打斷／斷法就緒時壓透明，讓上面算好的狀態色露出來
    if st.flow and h.flowClip then
        FlowAlpha(h.flowClip, ni)
        FlowAlpha(h.flowHost, flowReady)
    end
end
local function ApplyColor() PaintColorOn(f, S) end

------------------------------------------------------------
-- 刻度／蓄力分階／延遲區
------------------------------------------------------------
function DrawMarksOn(h, st)
    if not st.barW then return end
    local cfg = Cfg() or {}
    local n = 0
    -- 引導刻度：剩餘時間 t 的那一跳畫在 t / 總長（引導條從滿往空退）
    if cfg.ticks ~= false and st.tickTimes and st.tickDur and st.tickDur > 0 then
        for i = 1, #st.tickTimes do
            local r = st.tickTimes[i] / st.tickDur
            if r > 0.001 and r < 0.999 and n < MAX_MARKS then
                n = n + 1
                PlaceMark(h, st, n, r, 1, 1, 1, 0.6)
            end
        end
    end
    -- 蓄力分階：每一階的終點
    if st.stagePoints and st.stageTotal and st.stageTotal > 0 then
        for i = 1, #st.stagePoints do
            local p = st.stagePoints[i] / st.stageTotal
            if p > 0.001 and p < 0.999 and n < MAX_MARKS then
                n = n + 1
                PlaceMark(h, st, n, p, 1, 1, 1, 0.8)
            end
        end
    end
    HideMarks(h, n + 1)
    -- 延遲區：施法的終點端（施法在右、引導在左；反向填充時對調）。只在明文時間軸下畫
    local lag = st.lag or 0
    if cfg.latency ~= false and lag > 0 and (st.total or 0) > 0 and not st.castEmpowered then
        local frac = (lag / 1000) / st.total
        if frac > 0.3 then frac = 0.3 end
        local w = st.barW * frac
        if w < 2 then w = 2 end
        local atLeft = st.castChannel
        if st.reversed then atLeft = not atLeft end
        h.latency:ClearAllPoints()
        h.latency:SetSize(w, st.barH)
        h.latency:SetPoint(atLeft and "LEFT" or "RIGHT", h.marks, atLeft and "LEFT" or "RIGHT", 0, 0)
        h.latency:Show()
    else
        h.latency:Hide()
    end
end
function CB.DrawMarks()
    if f then DrawMarksOn(f, S) end
end

local function ClearMarks()
    S.tickTimes, S.tickDur, S.tickTime = nil, nil, nil
    S.stagePoints, S.stageTotal = nil, nil
    HideMarks(f, 1)
    f.latency:Hide()
end

local function SetupTicks(spellID, name)
    local cfg = Cfg() or {}
    if cfg.ticks == false or not S.castChannel or S.castEmpowered then return end
    local count = CB.TickCount(spellID, name)
    if count <= 0 then return end
    -- 明文總長 → 用秒；讀不到 → 平均分（刻度只看比例，不必知道總長）
    local dur = (S.total and S.total > 0) and S.total or 1
    local tickTime = dur / count
    local t = {}
    for i = 1, count do t[i] = dur - (i - 1) * tickTime end
    S.tickTimes, S.tickDur, S.tickTime = t, dur, tickTime
    S.tickEnd = S.tEnd
end

-- 引導延長（CHANNEL_UPDATE）：刻度往後推，最後一跳超過一跳的間隔就補一跳。只在明文時間軸下做
local function ExtendTicks()
    if not (S.tickTimes and S.tickTime and S.tEnd and S.tickEnd and S.total and S.total > 0) then return end
    if S.tEnd <= S.tickEnd then return end
    local extra = S.total - S.tickDur
    local t = S.tickTimes
    for i = 1, #t do t[i] = t[i] + extra end
    while #t < MAX_MARKS and t[#t] > S.tickTime do
        t[#t + 1] = t[#t] - S.tickTime
    end
    S.tickDur, S.tickEnd = S.total, S.tEnd
end

local function SetupStages(unit, numStages)
    local n = Plain(numStages)
    if not (S.castEmpowered and n and n > 0) then return end
    local getStage = GetUnitEmpowerStageDuration
    local getHold = GetUnitEmpowerHoldAtMaxTime
    if not getStage then return end
    local pts, sum = {}, 0
    for i = 1, n do
        local ok, d = pcall(getStage, unit, i - 1)
        d = ok and Plain(d)
        if not d then return end              -- 讀不到（秘密值）就整段不畫、顏色停在第 1 階
        if d > 0 then
            sum = sum + d / 1000
            pts[#pts + 1] = sum
        end
    end
    local hold = 0
    if getHold then
        local ok, h = pcall(getHold, unit)
        hold = (ok and Plain(h) or 0) / 1000
    end
    S.stagePoints, S.stageTotal = pts, sum + hold
end

------------------------------------------------------------
-- 顯示流程
------------------------------------------------------------
local function SetTimeText(text)
    if S.lastTime == text then return end
    S.lastTime = text
    f.timeText:SetText(text)
end

-- 開唱（真的或預覽）時的前緣效果：火花，加上效果層
local function ShowSparkOn(h, st)
    local cfg = Cfg() or {}
    h.spark:SetShown(cfg.showSpark ~= false)
    if st.flow then FxPlay(h) end
end
local function ShowSpark() ShowSparkOn(f, S) end

-- 沒在施法：關掉「沒在施法時隱藏」的話留一條空條，否則整條藏起來（容器的 alpha 由 Visibility 管）
local function HideBar()
    local wasPreview = S.preview
    S.active = false
    S.castState = nil
    S.preview = false
    S.castSpellID = nil
    S.displayToken = S.displayToken + 1
    if S.ticker then S.ticker:Cancel(); S.ticker = nil end
    f:SetScript("OnUpdate", nil)
    ClearMarks()
    f.spark:Hide()
    StopFlow()
    f.shake:Stop()
    f:SetAlpha(1)
    S.lastTime = nil
    S.tStart, S.tEnd, S.total, S.lag = nil, nil, 0, 0
    S.castChannel, S.castEmpowered, S.castSecret, S.castNotInterruptible = false, false, false, nil
    local cfg = Cfg() or {}
    if cfg.hideWhenNotCasting ~= false then
        f:Hide()
    else
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(0)
        f.nameText:SetText("")
        f.timeText:SetText("")
        f.icon:SetTexture(nil)
        f:Show()
    end
    if ns.Visibility then ns.Visibility.Apply("castbar") end
    if wasPreview and ns.Fire then ns.Fire("CastbarPreview", false) end
end
CB.HideBar = function() if f then HideBar() end end

local function FadeOnUpdate(self)
    local t = GetTime() - (S.fadeStart or 0)
    if t >= FADE_TIME then
        HideBar()
    else
        self:SetAlpha(1 - t / FADE_TIME)
    end
end

local function EndFade(color, label)
    S.active = false
    S.castState = 3
    S.fadeStart = GetTime()
    S.displayToken = S.displayToken + 1
    if S.ticker then S.ticker:Cancel(); S.ticker = nil end
    f.spark:Hide()
    StopFlow()
    f.latency:Hide()
    if color then
        local tex = f.bar:GetStatusBarTexture()
        if tex then tex:SetVertexColor(color.r, color.g, color.b, 1) end
    end
    if label then f.nameText:SetText(label) end
    f.timeText:SetText("")
    f:SetScript("OnUpdate", FadeOnUpdate)
    f:Show()
end

-- 被打斷、施法失敗都震（跟暴雪自己的施法條一樣）
local function Shake()
    if (Cfg() or {}).interruptShake ~= false then f.shake:Restart() end
end

local function ShowInterrupted()
    S.active = false
    S.castState = 4                       -- 停留中：還算「在施法」（不讓容器當場被藏）
    if S.ticker then S.ticker:Cancel(); S.ticker = nil end
    f:SetScript("OnUpdate", nil)
    ClearMarks()
    f.spark:Hide()
    StopFlow()
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(1)
    local c = Colors().interrupted
    local tex = f.bar:GetStatusBarTexture()
    if tex then tex:SetVertexColor(C(c, 1, 0.204, 0.145)) end
    f.nameText:SetText(L["Interrupted"])
    f.timeText:SetText("")
    Shake()
    S.displayToken = S.displayToken + 1
    local tok = S.displayToken
    C_Timer.After(INTERRUPT_HOLD, function()
        if tok ~= S.displayToken then return end
        EndFade()
    end)
end

local function Elapsed(now)
    if S.tStart then return now - S.tStart end
    return now - (S.localStart or now)
end

local function SecretTick()
    if not (S.active and S.castSecret) then
        if S.ticker then S.ticker:Cancel(); S.ticker = nil end
        return
    end
    local now = GetTime()
    local elapsed = Elapsed(now)
    if S.total > 0 then
        if elapsed > S.total + 0.3 then HideBar() return end      -- STOP 事件漏掉也會收條
    else
        local u = S.castUnit or "player"
        if UnitCastingInfo(u) == nil and UnitChannelInfo(u) == nil then HideBar() return end
    end
    SetTimeText(FormatTime((Cfg() or {}).timeFormat, elapsed, S.total))
    ApplyColor()
end

local function PlainOnUpdate(self, dt)
    if not S.active then HideBar() return end
    local now = GetTime()
    local total = (S.tEnd or 0) - (S.tStart or 0)
    if total <= 0 or now >= S.tEnd then
        if S.preview then EndFade() else HideBar() end
        return
    end
    local ratio
    if S.castChannel and not S.castEmpowered then
        ratio = (S.tEnd - now) / total
    else
        ratio = (now - S.tStart) / total
    end
    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
    self.bar:SetValue(ratio)
    S.textAccum = (S.textAccum or 1) + (dt or 0)
    if S.textAccum >= 0.05 then
        S.textAccum = 0
        SetTimeText(FormatTime((Cfg() or {}).timeFormat, now - S.tStart, total))
        local cfg = Cfg() or {}
        if cfg.interruptReady or S.castEmpowered then ApplyColor() end
    end
end

local function PaintNameOn(h, name)
    local cfg = Cfg() or {}
    -- 秘密字串照樣餵 SetText（C 端吃得下），只是不截字
    h.nameText:SetText(CB.Truncate(name, cfg.nameMaxChars) or "")
end
local function SetName(name) PaintNameOn(f, name) end

local function StartDisplay()
    local cfg = Cfg()
    if not cfg or cfg.enabled == false then return end
    local unit = S.castUnit or "player"
    local cName, _, cTex, cS4, cS5, _, cCastID, cNotInt, cSpellID = UnitCastingInfo(unit)
    local isCast = cName ~= nil
    local hName, hTex, hS4, hS5, hNotInt, hSpellID, hEmp, hStages
    if not isCast then
        local n, _, tex, s4, s5, _, ni, sid, emp, stages = UnitChannelInfo(unit)
        hName, hTex, hS4, hS5, hNotInt, hSpellID, hEmp, hStages = n, tex, s4, s5, ni, sid, emp, stages
    end
    local isChannel = (not isCast) and (hName ~= nil)
    if not (isCast or isChannel) then
        if not S.preview then HideBar() end
        return
    end

    local name, texture, notInt, s4, s5, isEmpowered, spellID
    if isCast then
        name, texture, notInt, s4, s5, spellID, isEmpowered = cName, cTex, cNotInt, cS4, cS5, cSpellID, false
    else
        name, texture, notInt, s4, s5, spellID = hName, hTex, hNotInt, hS4, hS5, hSpellID
        -- 蓄力旗標可能是秘密布林：只有明文 true 才算（讀不到就當一般引導，顏色照引導色）
        isEmpowered = (hEmp ~= nil and not IsSecret(hEmp) and hEmp) and true or false
    end

    local wasPreview = S.preview
    S.preview = false
    S.displayToken = S.displayToken + 1
    S.castChannel = isChannel
    S.castEmpowered = isEmpowered
    S.castSpellID = spellID
    S.castState = isChannel and 2 or 1
    S.castGUID = isCast and cCastID or nil
    S.castNotInterruptible = notInt
    S.lastTime = nil
    f:SetScript("OnUpdate", nil)
    f:SetAlpha(1)
    f.icon:SetTexture(texture)
    SetName(name)
    f.timeText:SetText("")

    -- 明文時間軸（刻度、延遲、蓄力分階、時間文字用）
    local ps, pe = Plain(s4), Plain(s5)
    S.tStart = ps and ps / 1000 or nil
    S.tEnd = pe and pe / 1000 or nil
    if isEmpowered and S.tEnd and GetUnitEmpowerHoldAtMaxTime then
        local ok, h = pcall(GetUnitEmpowerHoldAtMaxTime, unit)
        h = ok and Plain(h)
        if h then S.tEnd = S.tEnd + h / 1000 end
    end
    S.total = (S.tStart and S.tEnd) and (S.tEnd - S.tStart) or 0
    ClearMarks()
    SetupTicks(spellID, name)
    SetupStages(unit, hStages)

    if SecretsActive() then
        S.castSecret = true
        S.localStart = GetTime()
        local dur
        if isChannel then
            if isEmpowered and UnitEmpoweredChannelDuration then
                dur = UnitEmpoweredChannelDuration(unit, true)
            elseif UnitChannelDuration then
                dur = UnitChannelDuration(unit)
            end
        elseif UnitCastingDuration then
            dur = UnitCastingDuration(unit)
        end
        f.bar:SetMinMaxValues(0, 1)
        if dur and f.bar.SetTimerDuration then
            if S.total <= 0 and dur.GetTotalDuration then
                local ok, total = pcall(dur.GetTotalDuration, dur)
                if ok and Plain(total) then S.total = total end
            end
            f.bar:SetTimerDuration(dur, nil, TimerDir(isChannel, isEmpowered))
        else
            f.bar:SetValue(1)
        end
        S.active = true
        ApplyColor()
        if not S.ticker then
            S.ticker = C_Timer.NewTicker(0.1, SecretTick)
        end
    else
        S.castSecret = false
        if S.ticker then S.ticker:Cancel(); S.ticker = nil end
        if not (S.tStart and S.tEnd) then
            -- 明文模式卻讀不到時間（不該發生）：保底收條
            HideBar()
            return
        end
        ApplyColor()
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(isChannel and not isEmpowered and 1 or 0)
        S.textAccum = 1
        S.active = true
        f:SetScript("OnUpdate", PlainOnUpdate)
    end
    CB.DrawMarks()
    ShowSpark()
    f:Show()
    if ns.Visibility then ns.Visibility.Apply("castbar") end
    if wasPreview and ns.Fire then ns.Fire("CastbarPreview", false) end
end

local function ResyncTiming()
    if not S.active then return end
    local unit = S.castUnit or "player"
    local s4, s5
    if S.castSecret then
        local castName = UnitCastingInfo(unit)
        local dur, isChannel, isEmpowered
        if castName ~= nil then
            isChannel, isEmpowered = false, false
            if UnitCastingDuration then dur = UnitCastingDuration(unit) end
            local _, _, _, a, b = UnitCastingInfo(unit)
            s4, s5 = a, b
        else
            local c1, _, _, c4, c5, _, _, _, c9 = UnitChannelInfo(unit)
            if c1 == nil then return end
            s4, s5 = c4, c5
            isChannel = true
            isEmpowered = (c9 ~= nil and not IsSecret(c9) and c9) and true or false
            if isEmpowered and UnitEmpoweredChannelDuration then
                dur = UnitEmpoweredChannelDuration(unit, true)
            elseif UnitChannelDuration then
                dur = UnitChannelDuration(unit)
            end
        end
        S.castEmpowered = isEmpowered
        if dur and f.bar.SetTimerDuration then
            f.bar:SetTimerDuration(dur, nil, TimerDir(isChannel, isEmpowered))
        end
    else
        local castName, _, _, cs4, cs5 = UnitCastingInfo(unit)
        if castName ~= nil then
            s4, s5 = cs4, cs5
        else
            local c1, _, _, c4, c5 = UnitChannelInfo(unit)
            if c1 == nil then return end
            s4, s5 = c4, c5
        end
    end
    local ps, pe = Plain(s4), Plain(s5)
    if ps and pe then
        S.tStart, S.tEnd = ps / 1000, pe / 1000
        if S.castEmpowered and S.stageTotal and GetUnitEmpowerHoldAtMaxTime then
            local ok, h = pcall(GetUnitEmpowerHoldAtMaxTime, unit)
            h = ok and Plain(h)
            if h then S.tEnd = S.tEnd + h / 1000 end
        end
        S.total = S.tEnd - S.tStart
    end
    ExtendTicks()
    CB.DrawMarks()
end

local function ApplyInterruptState(notInt)
    S.castNotInterruptible = notInt
    ApplyColor()
end

------------------------------------------------------------
-- 預覽（設定頁的按鈕）：十秒的假施法，走明文路徑
------------------------------------------------------------
function CB.StartPreview()
    if not f then return false end
    local cfg = Cfg()
    if not cfg or cfg.enabled == false then return false end
    if S.castState == 1 or S.castState == 2 then return false end    -- 真的在施法
    local now = GetTime()
    S.preview = true
    S.displayToken = S.displayToken + 1
    S.castChannel, S.castEmpowered, S.castSecret = false, false, false
    S.castSpellID, S.castGUID, S.castNotInterruptible = nil, nil, false
    S.castState = 1
    S.tStart, S.tEnd, S.total = now, now + PREVIEW_TIME, PREVIEW_TIME
    S.lag = PREVIEW_LAG
    S.lastTime = nil
    f:SetAlpha(1)
    f.icon:SetTexture(PREVIEW_ICON)
    SetName(L["Preview cast"])
    f.timeText:SetText("")
    ClearMarks()
    ApplyColor()
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)
    S.textAccum = 1
    S.active = true
    f:SetScript("OnUpdate", PlainOnUpdate)
    CB.DrawMarks()
    ShowSpark()
    f:Show()
    if ns.Visibility then ns.Visibility.Apply("castbar") end
    if ns.Fire then ns.Fire("CastbarPreview", true) end
    return true
end

function CB.StopPreview()
    if f and S.preview then HideBar() end
end

function CB.IsPreviewing() return f and S.preview or false end

------------------------------------------------------------
-- 設定頁的內嵌樣本（Options/Tab_Castbar.lua「材質」上方那一列）：一條自己循環填滿的假施法條，
-- 換材質／動畫當場看得到，不用去畫面上找那條真的。
--
-- **跟畫面上那條是同一批函式、同一個呼叫順序、同一套疊層**（使用者 2026-11-06 指定：樣式的套用方式要跟實際一模一樣，
-- 才能順便拿它看樣式或上色有沒有錯）：零件 BuildParts、版面 LayoutParts（層級、錨點、效果層、火花、刻度與延遲區都在裡面）、
-- 名字 PaintNameOn、上色 PaintColorOn、延遲區 DrawMarksOn、火花 ShowSparkOn——樣本只是另一個框 h ＋ 另一張狀態表 st，
-- st 餵的就是頁首預覽（CB.StartPreview）餵給 S 的那幾格：一般的可打斷施法、帶假延遲。Refresh 照「CB.Apply → CB.Layout，
-- 接著 StartPreview」的順序叫，每幀照 PlainOnUpdate。**要改畫法就改那批共用函式，不要在這裡另外寫。**
-- 所以實際會發生的事樣本也照演：「斷法就緒時染色」開著、斷法又就緒時染色且動畫讓位；改任何設定時動畫從頭播
-- （畫面上那條施法中改設定也是這樣）。
-- 不碰玩家施法條的狀態（S）與任何施法 API。跟畫面上不一樣的只有兩樣：寬放不下縮到 maxW、高上限 CB.SAMPLE_MAX_H
-- （設定頁那一列的高是固定的）；以及它是循環的（SAMPLE_TIME 秒一輪、滿了停 SAMPLE_HOLD 秒，那一下火花收掉）。
--   local s = CB.CreateSample(parent)   s 是框，位置由呼叫端擺；s:Refresh(maxW) 照目前設定重畫
------------------------------------------------------------
local SAMPLE_TIME, SAMPLE_HOLD = 3, 0.6
CB.SAMPLE_MAX_H = 24

function CB.CreateSample(parent)
    local s = CreateFrame("Frame", nil, parent)
    BuildParts(s)
    local st = { castState = 1, castChannel = false, castEmpowered = false, castNotInterruptible = false,
                 total = SAMPLE_TIME, lag = PREVIEW_LAG }
    s.st = st

    local t, acc, lastTime = 0, 1, nil
    s:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        if t >= SAMPLE_TIME + SAMPLE_HOLD then
            t = t % (SAMPLE_TIME + SAMPLE_HOLD)
            ShowSparkOn(self, st)                        -- 新的一輪開唱
        end
        local filling = t < SAMPLE_TIME
        self.bar:SetValue(filling and t / SAMPLE_TIME or 1)
        if not filling then self.spark:Hide() end
        acc = acc + dt
        if acc < 0.05 then return end
        acc = 0
        local cfg = Cfg() or {}
        local text = FormatTime(cfg.timeFormat, filling and t or SAMPLE_TIME, SAMPLE_TIME)
        if text ~= lastTime then
            lastTime = text
            self.timeText:SetText(text)
        end
        if cfg.interruptReady or st.castEmpowered then PaintColorOn(self, st) end
    end)

    function s:Refresh(maxW)
        local cfg = Cfg() or {}
        local W, H = ns.P.Scale(Width(cfg)), ns.P.Scale(tonumber(cfg.height) or 20)
        if maxW and W > maxW then W = maxW end
        if W < 80 then W = 80 end
        if H > CB.SAMPLE_MAX_H then H = CB.SAMPLE_MAX_H elseif H < 6 then H = 6 end
        self:SetSize(W, H)
        -- 設定改了：CB.Apply → CB.Layout（st 是施法中 ⇒ 火花、效果層、刻度與延遲區都在裡面照著重設）
        LayoutParts(self, st, cfg, W, H)
        -- 開唱：CB.StartPreview 的順序
        self.icon:SetTexture(PREVIEW_ICON)
        PaintNameOn(self, L["Preview cast"])
        lastTime = nil
        self.timeText:SetText("")
        PaintColorOn(self, st)
        self.bar:SetMinMaxValues(0, 1)
        DrawMarksOn(self, st)
        ShowSparkOn(self, st)
    end
    -- 框藏起來時動畫組會停（換頁、換表單、關視窗）：重新顯示時接著播
    s:SetScript("OnShow", function(self)
        if st.flow then FxPlay(self) end
    end)
    return s
end

-- 施法中、淡出中、打斷停留中、預覽中都算
function CB.IsActive()
    return (f and S.castState ~= nil) and true or false
end

------------------------------------------------------------
-- 事件
--
-- 載具期間 player 與 vehicle 兩個 token 都可能送（哪個技能走哪個 token 是暴雪決定的）：
-- 開唱事件兩個都認、記下這次是誰在施法；其餘事件只認「正在畫的那個」。
------------------------------------------------------------
local START_EVENTS = {
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_EMPOWER_START = true,
}

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local function InVehicle()
    local fn = UnitHasVehicleUI
    if not fn then return false end
    local ok, v = pcall(fn, "player")
    return ok and not IsSecret(v) and v == true
end

local function Accept(event, evUnit)
    local unit = (type(evUnit) == "string" and not IsSecret(evUnit)) and evUnit or "player"
    if not InVehicle() then
        if unit ~= "player" then return false end
        S.castUnit = "player"
        return true
    end
    if START_EVENTS[event] then
        S.castUnit = unit
        return true
    end
    return unit == (S.castUnit or "player")
end

-- 延遲（毫秒）：UNIT_SPELLCAST_SENT → 開唱的時間差，量不到或不合理就退回 GetNetStats 的世界延遲。
--
-- 兩個戳記都在**事件派送當下**取（OnEvent 裡，不是 Defer 之後）：SENT 只記一個 upvalue、不進佇列；
-- 開唱事件把「自己的戳記」和「當下的 sentAt」一起帶進 Defer。
-- ⚠ GetTime() 整幀凍結（見 wow-gettime-stamp-multipacket）：按鍵與伺服器回應在同一個渲染幀裡
-- 處理完時兩個戳記相等，相減是 0 —— 那不是「零延遲」，是量不到 ⇒ 退回 GetNetStats（明文）。
-- lagSource 記這次用的是哪一個（/mcdm debug 印）。
local sentAt = 0

local function NetLag()
    local ok, _, _, home, world = pcall(GetNetStats)
    if not ok then return 0 end
    home, world = Plain(home) or 0, Plain(world) or 0
    return (world > 0 and world) or (home > 0 and home) or 0
end

local function MeasureLag(t, sent)
    local net = NetLag()
    if sent and sent > 0 and t and t > sent then
        local measured = (t - sent) * 1000
        local threshold = math.max(net * 3, 150)
        if measured <= threshold then
            S.lagSource = "measured"
            return measured
        end
    end
    S.lagSource = "net"
    return net
end
CB.MeasureLag = MeasureLag          -- 冒煙測試用

local function OnCastEvent(t, sent, event, evUnit, arg2, arg3, arg4, arg5)
    local cfg = Cfg()
    if not (f and cfg and cfg.enabled ~= false) then return end
    if not Accept(event, evUnit) then return end
    if START_EVENTS[event] then
        S.lag = MeasureLag(t, sent)
        StartDisplay()
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        ResyncTiming()
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        -- 值從事件名稱拿（明文），不回頭讀 UnitCastingInfo（受限內容是秘密布林）
        if S.castState == 1 or S.castState == 2 then
            ApplyInterruptState(event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if S.castState == 1 or S.castState == 2 then ShowInterrupted() end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if S.castState ~= 2 then return end
        -- 第 4 個參數是打斷者（有值＝被打斷）；只比 nil，不讀值
        if arg4 ~= nil then ShowInterrupted() else EndFade() end
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if S.castState ~= 2 then return end
        -- 聚能的結束是玩家自己放開鍵，不像一般施法要等條跑完：打出去就當場收條、不淡出
        -- （淡出時條凍在放開那一階，看起來像還在蓄）。第 4 個參數是「有沒有打出去」
        -- （放開太早連第一階都沒到＝false）、第 5 個是打斷者；兩個都只在明文時讀
        local failed = arg4 ~= nil and not IsSecret(arg4) and arg4 == false
        if arg5 ~= nil or failed then ShowInterrupted() else HideBar() end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        -- FAILED 也會為「不是目前這條」的施法而發（引導中另外按技能失敗）：
        -- 只在施法中、castGUID 相符（都讀得到明文時）才理會
        if S.castState ~= 1 then return end
        local mine = true
        if arg2 ~= nil and S.castGUID ~= nil and not IsSecret(arg2) and not IsSecret(S.castGUID) then
            mine = (arg2 == S.castGUID)
        end
        if mine then
            EndFade(Colors().interrupted)
            Shake()
        end
    else    -- UNIT_SPELLCAST_STOP
        if S.castState ~= 1 then return end
        EndFade()
    end
end

local function RegisterEvents()
    if ev then return end
    ev = CreateFrame("Frame")
    for _, event in ipairs(CAST_EVENTS) do ev:RegisterUnitEvent(event, "player", "vehicle") end
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    ev:SetScript("OnEvent", function(_, event, ...)
        -- ⚠ 只轉手：戳記在派送當下取（延遲要量 SENT → START 的差）。SENT 只記戳記、不進佇列
        local now = GetTime()
        if event == "UNIT_SPELLCAST_SENT" then
            sentAt = now
            return
        end
        local sent = 0
        if START_EVENTS[event] then sent, sentAt = sentAt, 0 end
        ns.Defer(OnCastEvent, now, sent, event, ...)
    end)
end

------------------------------------------------------------
-- 暴雪的玩家施法條
------------------------------------------------------------
local BLIZZ_EVENTS = {
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_SENT", "PLAYER_ENTERING_WORLD",
}
-- 框 → 解之前它註冊著的事件：{ { event, unit1, unit2 }, … }；沒有這個框的 key ＝ 沒動過
local blizzSaved = {}

-- 除了本體 PlayerCastingBarFrame 之外還有一條替身 OverlayPlayerCastingBarFrame：暴雪拿它在別的框上
-- 「代班」玩家施法條（StartReplacingPlayerBarAt），OnLoad 就自己以 "player" 註冊了全套施法事件。
-- 宿主有兩種，要分開看：
--   * 覆蓋快捷列（載具、變身、寵物控制）：OverrideActionBar 停用本體、讓替身畫在自己上方 —— 代的就是
--     玩家施法條，我們的條已經在畫 ⇒ 跟本體一起解（只解本體的話，祖阿曼箱子世界任務的神靈變身一出來
--     暴雪條又跑出來）
--   * 專精頁（切換專精）、天賦頁（套用天賦）、專業視窗（製作）：視窗自己的內容觸發的施法，進度條畫在
--     視窗裡；視窗蓋住畫面中央，我們的條在它底下看不到 ⇒ 不能解（2026-10-08 兩種一起解掉，
--     2026-10-21 玩家回報轉專精的施法條不見了）
-- 宿主換手時暴雪呼叫 Start／EndReplacingPlayerBar：後置勾只排程（跑在 OverrideActionBar 的 OnShow／
-- OnHide 裡），下一幀照替身現在的父框（GetParent，只讀）對帳。慢一幀的代價：上載具那一幀剛好在唱的
-- 施法，替身會把這一條畫完（它的 OnUpdate 自己會收）
local function OnOverrideBar(bf)
    local host = _G.OverrideActionBar
    if not host then return false end
    local ok, parent = pcall(bf.GetParent, bf)
    return ok and parent == host
end

-- 單位框架（MiliUI_UnitFrames）也把暴雪施法條的事件解掉了嗎？它的隱藏是單向的（沒有還原），
-- 這時我們取消勾選若照原樣裝回，等於把它藏起來的條又叫回來 ⇒ 不裝回，只把帳清掉。
-- 走它的公開 API（HidesPlayerCastBar），不讀它的存檔
local function UnitFramesHidesBlizzard()
    local api = _G.MiliUI_UnitFrames
    local fn = type(api) == "table" and api.HidesPlayerCastBar
    if type(fn) ~= "function" then return false end
    local ok, hides = pcall(fn)
    return ok and hides == true
end

-- 已經解過的框被別人裝回去了嗎（任一施法事件又註冊著）
local function Reregistered(frame)
    for _, e in ipairs(BLIZZ_EVENTS) do
        local ok, reg = pcall(frame.IsEventRegistered, frame, e)
        if ok and reg == true then return true end
    end
    return false
end

local function UnregisterBar(bf)
    ns.Write(bf, function(frame)
        if blizzSaved[frame] then
            -- 解過了但被別的插件裝回（NDui 等 oUF 系：玩家施法條關著時，PLAYER_LOGIN 生成框架走 oUF 的
            -- Castbar Disable，把暴雪條的事件整套註冊回去；它比我們晚載入 ⇒ 重載後暴雪條又出現）：
            -- 再解一次，帳照舊（還原時裝回的是我們第一次解之前的那一份）
            if Reregistered(frame) then pcall(frame.UnregisterAllEvents, frame) end
            return
        end
        local saved = {}
        for _, e in ipairs(BLIZZ_EVENTS) do
            local ok, reg, u1, u2 = pcall(frame.IsEventRegistered, frame, e)
            if ok and reg == true then saved[#saved + 1] = { e, u1, u2 } end
        end
        pcall(frame.UnregisterAllEvents, frame)
        blizzSaved[frame] = saved
    end, "cdm_castbar")
end

local function RestoreBar(bf)
    ns.Write(bf, function(frame)
        local saved = blizzSaved[frame]
        if not saved then return end
        blizzSaved[frame] = nil
        -- 替身的去留只看宿主，單位框架那邊也照同一條規則裝回 ⇒ 只有本體要問它
        if frame == _G.PlayerCastingBarFrame and UnitFramesHidesBlizzard() then return end
        for _, e in ipairs(saved) do
            if type(e[2]) == "string" then
                if type(e[3]) == "string" then
                    pcall(frame.RegisterUnitEvent, frame, e[1], e[2], e[3])
                else
                    pcall(frame.RegisterUnitEvent, frame, e[1], e[2])
                end
            else
                pcall(frame.RegisterEvent, frame, e[1])
            end
        end
    end, "cdm_castbar")
end

local function Reconcile(bf, hide)
    if not bf then return end
    if hide then
        UnregisterBar(bf)
    elseif blizzSaved[bf] then
        RestoreBar(bf)
    end
end

function CB.ApplyBlizzard()
    local cfg = Cfg() or {}
    local want = cfg.enabled ~= false and cfg.hideBlizzard == true
    Reconcile(_G.PlayerCastingBarFrame, want)
    -- 替身掛在覆蓋快捷列上時，單位框架也在藏施法條的話一樣不能裝回：帳留著，宿主換走才裝
    -- （它那邊同一條規則，只有宿主換走時才裝回自己記的那份）
    local ov = _G.OverlayPlayerCastingBarFrame
    Reconcile(ov, ov ~= nil and OnOverrideBar(ov) and (want or UnitFramesHidesBlizzard()))
end

-- 替身換宿主就重新對帳（見 OnOverrideBar 上面那段）。⚠ 後置勾只排程
local function HookOverlay()
    local ov = _G.OverlayPlayerCastingBarFrame
    if not ov then return end
    local later = ns.Guard(function() ns.Defer(CB.ApplyBlizzard) end)
    for _, method in ipairs({ "StartReplacingPlayerBarAt", "EndReplacingPlayerBar" }) do
        if type(ov[method]) == "function" then hooksecurefunc(ov, method, later) end
    end
end

local function SavedCount()
    local frames, events = 0, 0
    for _, saved in pairs(blizzSaved) do frames, events = frames + 1, events + #saved end
    return frames, events
end

function CB.BlizzardHidden() return next(blizzSaved) ~= nil end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Bars 之後）
------------------------------------------------------------
function CB.Init()
    if container then return end
    container = ns.Bars.RegisterPanel("castbar", {
        anchorPoint = "CENTER",
        minSize     = MinSize,
        relayout    = function() CB.Layout() end,
    })
    Build()
    CB.RebuildTicks()
    CB.Layout()
    RegisterEvents()
    HookOverlay()
    CB.ApplyBlizzard()
    -- 每次讀完畫面（延一幀：別的插件的 PLAYER_LOGIN／PLAYER_ENTERING_WORLD 都跑完了）再對一次帳：
    -- 被別人裝回的事件再解掉（UnregisterBar 的「解過了但被裝回」）
    ns.Events.Register("PLAYER_ENTERING_WORLD", "castbar_blizzard", function() ns.Defer(CB.ApplyBlizzard) end)
    HideBar()
    local function Later() ns.Defer(CB.RebuildTicks) end
    ns.Events.Register("PLAYER_TALENT_UPDATE", "castbar_ticks", Later)
    ns.Events.Register("TRAIT_CONFIG_UPDATED", "castbar_ticks", Later)
    ns.RegisterCallback("SpecChanged", "castbar", Later)
    ns.RegisterCallback("FirstRowWidthChanged", "castbar", function()
        local cfg = Cfg()
        if cfg and (tonumber(cfg.width) or 0) <= 0 then CB.Layout() end
    end)
    ns.RegisterCallback("ProfileChanged", "castbar", function() CB.Apply() end)
end

-- 設定頁改了值：版面、暴雪施法條、結構、alpha
function CB.Apply()
    if not f then return end
    CB.Layout()
    CB.ApplyBlizzard()
    local cfg = Cfg() or {}
    if cfg.enabled == false then
        HideBar()
    elseif not CB.IsActive() then
        HideBar()                  -- 「沒在施法時隱藏」切換：空條出現／消失
    else
        ApplyColor()
    end
    if InCombatLockdown() then ns.Bars.Request("castbar", "structure") else ns.Bars.ApplyStructure("castbar") end
    if ns.Visibility then ns.Visibility.Apply("castbar") end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
local STATE_NAME = { [1] = "施法", [2] = "引導", [3] = "淡出", [4] = "打斷停留" }

function CB.DebugLines()
    local out = {}
    if not f then
        out[1] = "  施法條：沒有初始化"
        return out
    end
    local cfg = Cfg() or {}
    out[#out + 1] = ("  施法條：%s  狀態 %s%s  秘密模式 %s  蓄力 %s  明文時間軸 %s（總長 %.2f）  延遲 %sms  刻度 %d  分階 %d  暴雪施法條已解事件 %s  alpha %s")
        :format(cfg.enabled ~= false and "開" or "關", STATE_NAME[S.castState] or "閒置",
                S.preview and "（預覽）" or "", S.castSecret and "是" or "否", S.castEmpowered and "是" or "否",
                S.tStart and "有" or "無", S.total or 0, math.floor(S.lag or 0)
                    .. (S.lagSource == "measured" and "" or S.lagSource == "net" and "（GetNetStats）" or ""),
                S.tickTimes and #S.tickTimes or 0, S.stagePoints and #S.stagePoints or 0,
                (next(blizzSaved) and ("是（%d 條、%d 個）"):format(SavedCount()) or "否")
                    .. (UnitFramesHidesBlizzard() and "（單位框架也在隱藏）" or ""),
                tostring(ns.Visibility and ns.Visibility.Current("castbar")))
    return out
end
