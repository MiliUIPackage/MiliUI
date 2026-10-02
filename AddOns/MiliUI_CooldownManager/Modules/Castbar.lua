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
-- 刻度、延遲、蓄力分階都要「明文的時間軸」（開始／結束讀得到）：讀不到就不畫，
-- 條本身照樣由 duration 物件驅動。位置一律用設定算出來的寬度（不讀框的幾何）。
--
-- 暴雪的玩家施法條（hideBlizzard）：只解它的事件（UnregisterAllEvents），跟單位框架已驗證的
-- 做法同一套 —— 不 Hide、不 SetParent、不寫它的欄位。解之前先用 IsEventRegistered 記下
-- 它註冊了哪些，關掉選項時照原樣裝回去（所以不需要 /reload）；
-- 例外：單位框架也在隱藏它時不裝回（見 UnitFramesHidesBlizzard）。
------------------------------------------------------------
local _, ns = ...

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

local function TimerDir(isChannel, isEmpowered)
    if isChannel and not isEmpowered then
        return Enum.StatusBarTimerDirection.RemainingTime
    end
    return Enum.StatusBarTimerDirection.ElapsedTime
end

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
        return
    end
    bar:SetStatusBarTexture(path or SOLID)
    local tex = bar:GetStatusBarTexture()
    if tex then tex:SetDesaturated(false) end
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
        w = ns.Bars and ns.Bars.FirstRowWidth and ns.Bars.FirstRowWidth("essential") or 0
        if w <= 0 then w = 200 end
    end
    return w
end
CB.Width = Width

local function MinSize()
    local cfg = Cfg() or {}
    return Width(cfg), tonumber(cfg.height) or 20
end

local function Build()
    f = CreateFrame("Frame", nil, container)
    f:SetAllPoints(container)

    f.iconFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.barHolder = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.bgTex = f.barHolder:CreateTexture(nil, "BACKGROUND")
    f.bgTex:SetTexture(SOLID)
    f.bar = CreateFrame("StatusBar", nil, f.barHolder)
    f.bar:SetStatusBarTexture(SOLID)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)

    -- 火花：只建立、不錨定（錨點要對到填充貼圖，Layout 設完材質才錨）
    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    f.spark:SetBlendMode("ADD")
    f.spark:Hide()

    -- 刻度、蓄力分階、延遲區：一層蓋在填充上
    f.marks = CreateFrame("Frame", nil, f.bar)
    f.marks:SetAllPoints(f.bar)
    f.markPool = {}
    f.latency = f.marks:CreateTexture(nil, "OVERLAY", nil, 6)
    f.latency:SetTexture(SOLID)
    f.latency:SetVertexColor(1, 0, 0, 0.5)
    f.latency:Hide()

    f.textFrame = CreateFrame("Frame", nil, f)
    f.textFrame:SetAllPoints(f.barHolder)
    -- ⚠ 先給字型才能 SetText
    f.nameText = f.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(f.nameText, 12, "OUTLINE")
    f.nameText:SetJustifyH("LEFT")
    f.nameText:SetWordWrap(false)
    f.timeText = f.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(f.timeText, 12, "OUTLINE")
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetWordWrap(false)
    f:Hide()
end

local function Mark(i)
    local t = f.markPool[i]
    if not t then
        t = f.marks:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(SOLID)
        f.markPool[i] = t
    end
    return t
end

local function HideMarks(from)
    for i = from or 1, #f.markPool do f.markPool[i]:Hide() end
end

-- 在條上 p（0～1，沿填充方向從起點算）畫一條線
local function PlaceMark(i, p, r, g, b, a)
    local t = Mark(i)
    local x = S.barW * p
    if S.reversed then x = S.barW - x end
    t:ClearAllPoints()
    t:SetSize(ns.P.Scale(1), S.barH)
    t:SetPoint("CENTER", f.marks, "LEFT", x, 0)
    t:SetVertexColor(r, g, b, a)
    t:Show()
end

------------------------------------------------------------
-- 版面（全部來自設定，不讀框的幾何）
------------------------------------------------------------
function CB.Layout()
    if not f then return end
    local cfg = Cfg() or {}
    local W, H = Width(cfg), tonumber(cfg.height) or 20
    W, H = ns.P.Scale(W), ns.P.Scale(H)
    ns.Bars.SetPanelSize("castbar", W, H)

    local showIcon = cfg.showIcon ~= false
    local iconW = showIcon and H or 0
    local gap = showIcon and ns.P.Scale(tonumber(cfg.iconGap) or 1) or 0
    local left = cfg.iconSide ~= "RIGHT"
    f.iconFrame:SetShown(showIcon)
    f.iconFrame:ClearAllPoints()
    f.iconFrame:SetSize(iconW > 0 and iconW or 1, H)
    f.iconFrame:SetPoint(left and "TOPLEFT" or "TOPRIGHT", f, left and "TOPLEFT" or "TOPRIGHT", 0, 0)
    local edge = ns.P.Scale(1)
    f.iconFrame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, edgeSize = edge })
    f.iconFrame:SetBackdropColor(0, 0, 0, 1)
    f.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", f.iconFrame, "TOPLEFT", edge, -edge)
    f.icon:SetPoint("BOTTOMRIGHT", f.iconFrame, "BOTTOMRIGHT", -edge, edge)

    local barW = W - iconW - gap
    if barW < 4 then barW = 4 end
    f.barHolder:ClearAllPoints()
    f.barHolder:SetSize(barW, H)
    f.barHolder:SetPoint(left and "TOPRIGHT" or "TOPLEFT", f, left and "TOPRIGHT" or "TOPLEFT", 0, 0)
    -- 1px 黑邊畫在外框上；條與底色內縮同一個厚度（見 project-miliui-pixel-snapping）
    local inset = ns.Media.BorderInset(1)
    f.barHolder:SetBackdrop({ edgeFile = SOLID, edgeSize = inset })
    f.barHolder:SetBackdropBorderColor(0, 0, 0, 1)
    f.bgTex:ClearAllPoints()
    f.bgTex:SetPoint("TOPLEFT", f.barHolder, "TOPLEFT", inset, -inset)
    f.bgTex:SetPoint("BOTTOMRIGHT", f.barHolder, "BOTTOMRIGHT", -inset, inset)
    local bg = cfg.bgColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    f.bgTex:SetVertexColor(bg.r or 0.1, bg.g or 0.1, bg.b or 0.1, bg.a or 0.8)
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f.barHolder, "TOPLEFT", inset, -inset)
    f.bar:SetPoint("BOTTOMRIGHT", f.barHolder, "BOTTOMRIGHT", -inset, inset)
    SetFillTexture(f.bar, cfg.texture)
    S.reversed = ns.FillReversed(cfg)
    f.bar:SetReverseFill(S.reversed)
    S.barW, S.barH = barW - inset * 2, H - inset * 2

    -- 層級：底 L → 條 L+1 → 刻度 L+2 → 文字 L+3；圖示 L+1
    local lvl = f:GetFrameLevel()
    f.barHolder:SetFrameLevel(lvl)
    f.bar:SetFrameLevel(lvl + 1)
    f.marks:SetFrameLevel(lvl + 2)
    f.textFrame:SetFrameLevel(lvl + 3)
    f.iconFrame:SetFrameLevel(lvl + 1)

    local font = ns.Media.ElementFont(cfg.font, ns.Setting(nil, "font"))
    local size = tonumber(cfg.textSize) or 12
    ns.Media.SetFont(f.nameText, size, "OUTLINE", font)
    ns.Media.SetFont(f.timeText, size, "OUTLINE", font)
    f.timeText:ClearAllPoints()
    f.timeText:SetPoint("RIGHT", f.textFrame, "RIGHT", -4, 0)
    f.nameText:ClearAllPoints()
    f.nameText:SetPoint("LEFT", f.textFrame, "LEFT", 4, 0)
    f.nameText:SetPoint("RIGHT", f.timeText, "LEFT", -4, 0)
    f.nameText:SetShown(cfg.showName ~= false)
    f.timeText:SetShown(cfg.showTime ~= false)

    -- 火花：跟著填充前緣。錨點在 SetStatusBarTexture 之後才下，換材質時要重下
    f.spark:SetSize(10, H * 2.2)
    f.spark:ClearAllPoints()
    local tex = f.bar:GetStatusBarTexture()
    if tex then f.spark:SetPoint("CENTER", tex, S.reversed and "LEFT" or "RIGHT", 0, 0) end
    f.spark:SetShown(cfg.showSpark ~= false and S.castState ~= nil and S.castState ~= 3 and S.castState ~= 4)

    -- 施法中改了尺寸：刻度與延遲區照新寬度重畫
    if S.castState == 1 or S.castState == 2 then CB.DrawMarks() end
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
local function EmpowerStage()
    local pts = S.stagePoints
    if not (pts and S.tStart) then return 1 end
    local elapsed = GetTime() - S.tStart
    local r = 0
    for i = 1, #pts do
        if elapsed >= pts[i] then r = i else break end
    end
    if r < 1 then r = 1 elseif r > 4 then r = 4 end
    return r
end

local function BaseColor()
    local cfg = Cfg() or {}
    local c = Colors()
    if S.castEmpowered then
        return C(c["empowerStage" .. EmpowerStage()], 0.35, 0.75, 0.35)
    end
    if cfg.useClassColor then
        local r, g, b = ns.Style.Accent()
        return r, g, b
    end
    if S.castChannel then return C(c.channel, 0.906, 0.424, 0.2) end
    return C(c.cast, 0.906, 0.424, 0.2)
end

local function EvalTriple(cond, col, r, g, b)
    local cr, cg, cb = C(col, r, g, b)
    return Eval(cond, cr, r), Eval(cond, cg, g), Eval(cond, cb, b)
end

-- 曲線串接的保險：第一次被擋就永久放掉斷法就緒色，保住「不可打斷灰」
local chainOK = true

local function ApplyColor()
    local tex = f.bar:GetStatusBarTexture()
    if not tex then return end
    local cfg = Cfg() or {}
    local c = Colors()
    local br, bg, bb = BaseColor()
    local r, g, b = br, bg, bb
    local tinted = false
    -- 斷法就緒（可能是秘密布林：只餵曲線）
    if cfg.interruptReady and chainOK and ns.Interrupt then
        local ready, has = ns.Interrupt.IsReady()
        if has then
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
    local ni = S.castNotInterruptible
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
end

------------------------------------------------------------
-- 刻度／蓄力分階／延遲區
------------------------------------------------------------
function CB.DrawMarks()
    if not (f and S.barW) then return end
    local cfg = Cfg() or {}
    local n = 0
    -- 引導刻度：剩餘時間 t 的那一跳畫在 t / 總長（引導條從滿往空退）
    if cfg.ticks ~= false and S.tickTimes and S.tickDur and S.tickDur > 0 then
        for i = 1, #S.tickTimes do
            local r = S.tickTimes[i] / S.tickDur
            if r > 0.001 and r < 0.999 and n < MAX_MARKS then
                n = n + 1
                PlaceMark(n, r, 1, 1, 1, 0.6)
            end
        end
    end
    -- 蓄力分階：每一階的終點
    if S.stagePoints and S.stageTotal and S.stageTotal > 0 then
        for i = 1, #S.stagePoints do
            local p = S.stagePoints[i] / S.stageTotal
            if p > 0.001 and p < 0.999 and n < MAX_MARKS then
                n = n + 1
                PlaceMark(n, p, 1, 1, 1, 0.8)
            end
        end
    end
    HideMarks(n + 1)
    -- 延遲區：施法的終點端（施法在右、引導在左；反向填充時對調）。只在明文時間軸下畫
    local lag = S.lag or 0
    if cfg.latency ~= false and lag > 0 and (S.total or 0) > 0 and not S.castEmpowered then
        local frac = (lag / 1000) / S.total
        if frac > 0.3 then frac = 0.3 end
        local w = S.barW * frac
        if w < 2 then w = 2 end
        local atLeft = S.castChannel
        if S.reversed then atLeft = not atLeft end
        f.latency:ClearAllPoints()
        f.latency:SetSize(w, S.barH)
        f.latency:SetPoint(atLeft and "LEFT" or "RIGHT", f.marks, atLeft and "LEFT" or "RIGHT", 0, 0)
        f.latency:Show()
    else
        f.latency:Hide()
    end
end

local function ClearMarks()
    S.tickTimes, S.tickDur, S.tickTime = nil, nil, nil
    S.stagePoints, S.stageTotal = nil, nil
    HideMarks(1)
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

local function ShowSpark()
    local cfg = Cfg() or {}
    f.spark:SetShown(cfg.showSpark ~= false)
end

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

local function ShowInterrupted()
    S.active = false
    S.castState = 4                       -- 停留中：還算「在施法」（不讓容器當場被藏）
    if S.ticker then S.ticker:Cancel(); S.ticker = nil end
    f:SetScript("OnUpdate", nil)
    ClearMarks()
    f.spark:Hide()
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(1)
    local c = Colors().interrupted
    local tex = f.bar:GetStatusBarTexture()
    if tex then tex:SetVertexColor(C(c, 1, 0.204, 0.145)) end
    f.nameText:SetText(L["Interrupted"])
    f.timeText:SetText("")
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

local function SetName(name)
    local cfg = Cfg() or {}
    -- 秘密字串照樣餵 SetText（C 端吃得下），只是不截字
    f.nameText:SetText(CB.Truncate(name, cfg.nameMaxChars) or "")
end

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
        if arg5 ~= nil then ShowInterrupted() else EndFade() end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        -- FAILED 也會為「不是目前這條」的施法而發（引導中另外按技能失敗）：
        -- 只在施法中、castGUID 相符（都讀得到明文時）才理會
        if S.castState ~= 1 then return end
        local mine = true
        if arg2 ~= nil and S.castGUID ~= nil and not IsSecret(arg2) and not IsSecret(S.castGUID) then
            mine = (arg2 == S.castGUID)
        end
        if mine then EndFade(Colors().interrupted) end
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
local blizzSaved          -- 解之前它註冊著的事件：{ { event, unit1, unit2 }, … }；nil ＝ 沒動過

local function BlizzBar() return _G.PlayerCastingBarFrame end

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

function CB.ApplyBlizzard()
    local bf = BlizzBar()
    if not bf then return end
    local cfg = Cfg() or {}
    local want = cfg.enabled ~= false and cfg.hideBlizzard == true
    if want and not blizzSaved then
        ns.Write(bf, function(frame)
            if blizzSaved then return end
            local saved = {}
            for _, e in ipairs(BLIZZ_EVENTS) do
                local ok, reg, u1, u2 = pcall(frame.IsEventRegistered, frame, e)
                if ok and reg == true then saved[#saved + 1] = { e, u1, u2 } end
            end
            pcall(frame.UnregisterAllEvents, frame)
            blizzSaved = saved
        end, "cdm_castbar")
    elseif not want and blizzSaved then
        ns.Write(bf, function(frame)
            local saved = blizzSaved
            if not saved then return end
            blizzSaved = nil
            if UnitFramesHidesBlizzard() then return end
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
end

function CB.BlizzardHidden() return blizzSaved ~= nil end

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
    CB.ApplyBlizzard()
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
                (blizzSaved and ("是（" .. #blizzSaved .. " 個）") or "否")
                    .. (UnitFramesHidesBlizzard() and "（單位框架也在隱藏）" or ""),
                tostring(ns.Visibility and ns.Visibility.Current("castbar")))
    return out
end
