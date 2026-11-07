------------------------------------------------------------
-- 專注目標施法監控
--   * 施法條可在編輯模式拖曳
--   * 三種斷法狀態顏色（可斷／斷法冷卻中／不可中斷）
--   * 條右下角印法術打向誰（職業色）
--   * 暴雪標為重要的法術外框發光
--   * 可以斷的施法整條發光（三款任選）、開唱震動（只震可以斷的／每次都震）
--   * 開始唱法時播一次音效
-- 本模組不依賴任何其他插件。
--
-- 結構（2026-11-08 為了震動的分身改的）：條的零件（圖示、條、火花、文字）由 BuildParts(h) 建在框 h 上，
-- 畫面上那條（barFrame）與震動用的分身（twin）各建一份；畫到條上的東西一律寫成「…On(h, …)」、
-- 外層用 Each 包一次（本尊＋分身顯示中的話也畫到分身）。模組層的 barStatusBar／nameText… 是本尊零件的別名。
------------------------------------------------------------
local _, ns = ...

ns.CastBar = {}
local CastBar = ns.CastBar

----------------------------------------------------------------------
-- 斷法法術對照表
-- ⚠ 每次改版要跟 Platynator/Display/Utilities.lua 對一次（新職業／改法術）
----------------------------------------------------------------------
local interruptMap = {
    ["DEATHKNIGHT"] = { 47528 },
    ["WARRIOR"]     = { 6552 },
    -- 89766 斧頭投擲（惡魔守衛）／19647 法術鎖定（獸僕）／119910、132409 玩家端
    -- 版本（惡魔支配、獻祭語彙）／1276467 12.x 新編號。少了 19647 的話，
    -- 帶獸僕（最常見）的術士整條斷法變色都不亮。
    ["WARLOCK"]     = { 19647, 89766, 119910, 132409, 1276467 },
    ["SHAMAN"]      = { 57994 },
    ["ROGUE"]       = { 1766 },
    ["PRIEST"]      = { 15487 },
    ["PALADIN"]     = { 96231, 31935 },
    ["MONK"]        = { 116705 },
    ["MAGE"]        = { 2139 },
    ["HUNTER"]      = { 147362, 187707 },
    ["EVOKER"]      = { 351338 },
    ["DRUID"]       = { 38675, 78675, 106839 },
    ["DEMONHUNTER"] = { 183752 },
}

-- 12.0「Secrets」：秘密限制生效時，施法起訖時間為秘密值，不能直接運算，
-- 必須改用 UnitCastingDuration + StatusBar:SetTimerDuration 由 StatusBar 內部驅動。
local function SecretsActive()
    return C_Secrets and C_Secrets.HasSecretRestrictions() and true or false
end

-- 12.0.1：pcall 接不到秘密值錯誤，數值存入明文變數前一律先檢查
local issecret = ns.Secret.IsSecret

local function DB()
    return ns.db.cast
end

-- 套組的冷卻管理器（MiliUI_CooldownManager）2026-10-15 起自己有一條專注目標施法條：它開著時這條讓位
-- （只問它的公開 API，不讀它的存檔）。它的開關一變會廣播 FocusCastBarChanged，Init 裡訂閱後重套。
local function TakenOver()
    local api = _G.MiliUI_CooldownManager
    local fn = type(api) == "table" and api.FocusCastBarActive
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn)
    return ok and v == true
end
CastBar.TakenOver = TakenOver

-- 監控開著、而且沒有被冷卻管理器接手
local function Monitoring()
    return DB().monitor and not TakenOver()
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local playerClass = (UnitClassBase and UnitClassBase("player")) or select(2, UnitClass("player"))

local barFrame, twin       -- 畫面上那條、震動用的分身（見「開唱震動」）
local barStatusBar, barIcon, barSpark, nameText, bangText, timeText   -- 本尊零件的別名（BuildParts 建在 barFrame 上）
local targetText           -- 法術打向誰（條右下角、職業色）
local twinOn = false       -- 這次開唱帶著分身（Arm 到 End 之間）
-- 範例條＋可拖曳：編輯模式或本插件設定視窗任一開著就算（isInEditMode＝兩者 OR）
local isInEditMode = false
local editModeOpen, settingsOpen = false, false
local HideBar   -- forward declaration（供 ticker / OnUpdate 引用）

-- 畫到條上的東西：本尊一定畫，分身顯示中也畫
local function Each(fn, ...)
    if not barFrame then return end
    fn(barFrame, ...)
    if twinOn then fn(twin, ...) end
end

-- 打斷顯示：凍結條的顏色與斷法者名字停留秒數
-- （Platynator 名條預設 0.3s，但它有常駐名字；獨立條要讀得到名字，拉長）
local INTERRUPTED_COLOR = { 1, 0.2039215862751007, 0.1450980454683304 }
local INTERRUPT_HOLD    = 1.0

local active               = false   -- 目前是否有專注目標施法在跑
local displayToken         = 0       -- 顯示世代：讓過期的「打斷停留」計時器失效
local castSecret           = false   -- 本次施法是否走秘密模式
local castStart, castEnd   = 0, 0    -- 一般模式：GetTime 起訖（秒）
local castLocalStart       = 0       -- 秘密模式：本地近似起始（僅供時間文字）
local castTotal            = 0       -- 秘密模式：總施法秒數
local castChannel          = false
local castNotInterruptible = false
local colorAccum           = 0
local shakeEnd             = 0       -- 分身震完的時間（動畫組的 OnFinished 不保證派，計時補收）

local currentInterrupt = {}          -- 玩家已學的斷法法術

----------------------------------------------------------------------
-- 斷法可用判斷
----------------------------------------------------------------------
local function RefreshInterruptSpells()
    currentInterrupt = {}
    local spells = interruptMap[playerClass]
    if not spells then return end
    for _, s in ipairs(spells) do
        local known = false
        if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
            known = C_SpellBook.IsSpellKnownOrInSpellBook(s)
                 or C_SpellBook.IsSpellKnownOrInSpellBook(s, Enum.SpellBookSpellBank.Pet)
        else
            known = IsSpellKnown(s) or IsSpellKnown(s, true)
        end
        if known then tinsert(currentInterrupt, s) end
    end
end

local function InterruptReady()
    if #currentInterrupt == 0 then return false end
    for _, spellID in ipairs(currentInterrupt) do
        if C_Spell.GetSpellCooldownDuration then
            local d = C_Spell.GetSpellCooldownDuration(spellID)
            if d and d:IsZero() then return true end
        else
            local cd = C_Spell.GetSpellCooldown(spellID)
            if cd and cd.startTime == 0 then return true end
        end
    end
    return false
end

-- 一般模式（無秘密限制）用：回傳 "ready" | "cd" | "immune"
-- 註：此函式會對 notInterruptible / 冷卻做 Lua 判斷，只能在非秘密模式呼叫。
local function ComputeState(notInterruptible)
    if notInterruptible then return "immune" end
    if InterruptReady() then return "ready" end
    return "cd"
end

local COLOR_KEYS = { ready = "colorReady", cd = "colorCD", immune = "colorImmune" }

local function ColorForState(state)
    return DB()[COLOR_KEYS[state] or "colorCD"]
end

----------------------------------------------------------------------
-- 條上的小寫入（本尊＋分身共用，經 Each）
----------------------------------------------------------------------
local function BarValueOn(h, v)
    h.bar:SetValue(v)
end

local function BarColorOn(h, r, g, b)
    h.bar:SetStatusBarColor(r, g, b)
end

-- dur ＝ duration 物件（可能帶秘密值，原封轉交）
local function BarTimerOn(h, dur, dir)
    h.bar:SetMinMaxValues(0, 1)
    h.bar:SetTimerDuration(dur, nil, dir)
end

local function SetTimeTextOn(h, text)
    h.timeText:SetText(text)
end

-- 開唱：圖示（施法中必有圖示；勿用 texture or X——會對秘密值做真值判斷 → taint）、右側文字還原白字（打斷顯示會染職業色）
local function PaintIconOn(h, texture)
    h.icon:SetTexture(texture)
    h.timeText:SetTextColor(1, 1, 1)
end

----------------------------------------------------------------------
-- 秘密模式上色：notInterruptible 與斷法冷卻可用性都是秘密布林，
-- 絕不能在 Lua 分支，必須用 C_CurveUtil 把秘密布林餵給引擎選色。
----------------------------------------------------------------------
local Eval = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean

local function ApplySecretColorOn(h)
    if not Eval then return end
    local db = DB()
    local ready, cd, immune = db.colorReady, db.colorCD, db.colorImmune
    -- 由 cd 起底，任一斷法冷卻歸零 → 覆蓋為 ready（多個技能層層 Eval）
    local r, g, b = cd.r, cd.g, cd.b
    if C_Spell.GetSpellCooldownDuration then
        for _, spellID in ipairs(currentInterrupt) do
            local d = C_Spell.GetSpellCooldownDuration(spellID)
            if d then
                local z = d:IsZero()             -- 秘密布林，不分支
                r = Eval(z, ready.r, r)
                g = Eval(z, ready.g, g)
                b = Eval(z, ready.b, b)
            end
        end
    end
    -- 不可中斷 → 覆蓋為 immune
    local ni = castNotInterruptible              -- 秘密布林（或 false）
    r = Eval(ni, immune.r, r)
    g = Eval(ni, immune.g, g)
    b = Eval(ni, immune.b, b)
    local tex = h.bar:GetStatusBarTexture()
    if tex then tex:SetVertexColor(r, g, b) end
end

local function ApplySecretColor()
    Each(ApplySecretColorOn)
end

local WatchShake, EndShake   -- forward declaration（開唱震動那一節）

-- 秘密模式：不掛每幀 OnUpdate，改用單一 10Hz ticker 同時更新「近似時間文字 + 顏色」。
-- （條的填充由引擎的 SetTimerDuration 驅動；斷法冷卻變化也在這裡重算色。）
local displayTicker
local function StopDisplayTicker()
    if displayTicker then displayTicker:Cancel(); displayTicker = nil end
end

local function SecretTick()
    if not (active and castSecret) then StopDisplayTicker(); return end
    if isInEditMode then return end
    local now = GetTime()
    WatchShake(now)
    local elapsed = now - castLocalStart
    if castTotal > 0 then
        if elapsed > castTotal + 0.3 then   -- 保險：STOP 事件若漏掉也會收條
            HideBar()
            return
        end
        local shown = castChannel and (castTotal - elapsed) or elapsed
        if shown < 0 then shown = 0 elseif shown > castTotal then shown = castTotal end
        Each(SetTimeTextOn, string.format("%.1f/%.1f", shown, castTotal))
    else
        -- 拿不到總長：改輪詢施法狀態收條（nil 判斷秘密安全），不猜固定秒數
        if UnitCastingInfo("focus") == nil and UnitChannelInfo("focus") == nil then
            HideBar()
            return
        end
        Each(SetTimeTextOn, "")
    end
    ApplySecretColor()
end

local function StartDisplayTicker()
    if displayTicker then return end
    displayTicker = C_Timer.NewTicker(0.1, SecretTick)
end

-- 一般模式（無秘密限制）：需每幀 SetValue 平滑填充；文字/顏色 20Hz。
local function LegacyOnUpdate(self, dt)
    if isInEditMode then return end
    if not active then HideBar(); return end
    local now = GetTime()
    WatchShake(now)
    local total = castEnd - castStart
    if total <= 0 or now >= castEnd then HideBar(); return end
    local ratio, shown
    if castChannel then
        ratio = (castEnd - now) / total
        shown = castEnd - now
    else
        ratio = (now - castStart) / total
        shown = now - castStart
    end
    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
    Each(BarValueOn, ratio)

    colorAccum = colorAccum + dt
    if colorAccum >= 0.05 then
        colorAccum = 0
        if shown < 0 then shown = 0 elseif shown > total then shown = total end
        Each(SetTimeTextOn, string.format("%.1f/%.1f", shown, total))
        local c = ColorForState(ComputeState(castNotInterruptible))
        Each(BarColorOn, c.r, c.g, c.b)
    end
end

----------------------------------------------------------------------
-- 音效（獨立於施法監控開關）
--
-- 不看斷法狀態，專注目標一開始讀條就播一次。
--
-- 為什麼不能像顏色那樣分三態：上色從頭到尾沒經過 Lua —— 秘密布林交給
-- C_CurveUtil.EvaluateColorValueFromBoolean，引擎挑完直接塗到貼圖上，插件
-- 不知道挑了哪個。音效沒有這種東西：PlaySound 吃明文數字、由 Lua 呼叫，
-- 要在兩個音效之間選就得寫 `if ready then A else B end`，那一行就是在 Lua
-- 讀秘密布林 → taint。整個 *FromBoolean 家族都是 frame/texture 的 setter，
-- 沒有音訊版本。這正是暴雪要封殺的自動斷法輔助，不是我們寫法的問題。
-- 「重要法術才響」同理：IsSpellImportant 回的也是秘密布林，只能畫（發光）不能聽。
----------------------------------------------------------------------
local function HandleSound(castTbl, chanTbl)
    local db = DB()
    if not db.soundEnabled then return end
    castTbl = castTbl or { UnitCastingInfo("focus") }
    chanTbl = chanTbl or { UnitChannelInfo("focus") }
    -- 秘密字串可測 nil-ness（只洩漏有沒有在施法，可知）
    if castTbl[1] == nil and chanTbl[1] == nil then return end
    ns.Media.PlaySoundValue(db.sound)
end

----------------------------------------------------------------------
-- 重要法術發光
--
-- 判定是暴雪的 C_Spell.IsSpellImportant(spellID)，不維護法術清單。受限內容裡
-- spellID 與回傳值都是秘密值，這裡只當傳遞者：發光照開，SetAlphaFromBoolean
-- 交給引擎決定看不看得到，Lua 從頭到尾不讀那個布林。
-- 施法一結束就整個停掉，不讓共用 driver 對看不見的發光空轉。
----------------------------------------------------------------------
local LCG = ns.MiliUIGlow
local IsSpellImportant = C_Spell and C_Spell.IsSpellImportant

-- 樣式：pixel＝條外框跑線、autocast＝條外框閃點、proc＝圖示上的暴雪觸發發光。
-- 發光一律掛在自己的宿主框（h.glowHosts[style]）上，秘密布林只餵給宿主的 SetAlphaFromBoolean：
-- 發光引擎內部會自己 SetAlpha（動畫），掛在宿主上才不會互相蓋掉。亮著哪一種記在 h.glowShownStyle
local GLOW_STYLES = { pixel = true, autocast = true, proc = true }

local function GlowStyle()
    local st = DB().glowStyle
    return GLOW_STYLES[st] and st or "pixel"
end

local function GlowHost(h, style)
    local host = h.glowHosts[style]
    if host then return host end
    local target = (style == "proc") and h.iconBorder or h
    host = CreateFrame("Frame", nil, target)
    host:SetAllPoints(target)
    host:SetFrameLevel(h:GetFrameLevel() + 20)   -- 壓過條、文字疊層
    h.glowHosts[style] = host
    return host
end

local function StopGlowOn(h)
    local style = h.glowShownStyle
    if not style then return end
    local host = h.glowHosts[style]
    if style == "pixel" then
        LCG.PixelGlow_Stop(host)
    elseif style == "autocast" then
        LCG.AutoCastGlow_Stop(host)
    else
        LCG.ProcGlow_Stop(host)
    end
    h.glowShownStyle = nil
end

local function StopGlow()
    Each(StopGlowOn)
end

-- important：明文或秘密布林；nil＝不問直接亮（編輯模式／設定視窗的範例）
local function ShowGlowOn(h, important)
    local db = DB()
    if not db.glowImportant then StopGlowOn(h); return end
    local style = GlowStyle()
    if h.glowShownStyle ~= style then
        StopGlowOn(h)
        local host = GlowHost(h, style)
        local c = db.colorGlow
        local color = { c.r, c.g, c.b, 1 }
        if style == "pixel" then
            -- 2px、往外推 1px：蓋住條本身的 1px 黑邊再多出去 1px，1px 貼在黑邊上看不太出來。
            -- border=false：條自己有底，不要引擎再墊一圈
            LCG.PixelGlow_Start(host, color, 8, 0.25, nil, 2, 1, 1, false)
        elseif style == "autocast" then
            LCG.AutoCastGlow_Start(host, color, 6, 0.125, 1.2, 1, 1)
        else
            LCG.ProcGlow_Start(host, { color = color })
        end
        h.glowShownStyle = style
    end
    local host = h.glowHosts[style]
    if important == nil then
        host:SetAlpha(1)
    else
        host:SetAlphaFromBoolean(important, 1, 0)
    end
end

local function ShowGlow(important)
    Each(ShowGlowOn, important)
end

-- spellID 可能是秘密值：只比 nil、原封不動交給 C 端。回傳 nil＝判斷不了（不發光）
local function QueryImportant(spellID)
    if spellID == nil or not IsSpellImportant then return nil end
    local ok, v = pcall(IsSpellImportant, spellID)
    if ok and v ~= nil then return v end
    return nil
end

----------------------------------------------------------------------
-- 法術名稱：important＝明文或秘密布林，nil＝不標（打斷顯示、判斷不了時）
-- name 可能是秘密字串：只串接、只交給 SetText，不比較
----------------------------------------------------------------------
local function SetNameOn(h, name, important)
    h.nameText:SetText(name)
    if important == nil or not DB().bangImportant then
        h.bangText:SetAlpha(0)
        h.nameText:SetAlpha(1)
        return
    end
    local c = DB().colorGlow
    h.bangText:SetText(string.format("|cff%02x%02x%02x!|r ", c.r * 255, c.g * 255, c.b * 255) .. name)
    h.bangText:SetAlphaFromBoolean(important, 1, 0)
    h.nameText:SetAlphaFromBoolean(important, 0, 1)
end

local function SetName(name, important)
    Each(SetNameOn, name, important)
end

----------------------------------------------------------------------
-- 法術打向誰：條右下角、右靠齊、比法術名小一號、職業色
--
-- 12.x 的 UnitSpellTargetName／UnitSpellTargetClass／UnitShouldDisplaySpellTargetName。
-- 受限內容裡名字與職業都可能是秘密字串：名字只交給 SetText；職業交給
-- C_ClassColor.GetClassColor 再把分量餵 SetTextColor（名條插件在正式服就是這樣畫，
-- 分量是秘密數字也收）。「該不該顯示」是布林：明文就 if，秘密就餵 SetAlphaFromBoolean。
----------------------------------------------------------------------
local UnitSpellTargetName_  = UnitSpellTargetName
local UnitSpellTargetClass_ = UnitSpellTargetClass
local UnitShouldDisplaySpellTargetName_ = UnitShouldDisplaySpellTargetName

local function TargetFontSize(h)
    return math.max(8, math.floor((h - 8) * 0.72 + 0.5))
end

local function ClearSpellTargetOn(h)
    h.targetText:SetText("")
    h.targetText:SetAlpha(1)
    h.targetText:SetTextColor(1, 1, 1)
end

local function ClearSpellTarget()
    Each(ClearSpellTargetOn)
end

-- name 可能是秘密字串（只交給 SetText）；class 明文或秘密職業 token（只交給 GetClassColor）或 nil
local function PaintSpellTargetOn(h, name, class)
    h.targetText:SetAlpha(1)
    local r, g, b = 1, 1, 1
    if class ~= nil and DB().targetClassColor then
        local color = C_ClassColor and C_ClassColor.GetClassColor(class)
            or (not issecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        if color then r, g, b = color:GetRGB() end
    end
    h.targetText:SetTextColor(r, g, b)
    h.targetText:SetText(name)
end

local function GateSpellTargetOn(h, show)
    h.targetText:SetAlphaFromBoolean(show, 1, 0)
end

local function SetSpellTarget()
    if not DB().showTarget or not UnitSpellTargetName_ then ClearSpellTarget(); return end
    local name = UnitSpellTargetName_("focus")
    if name == nil then ClearSpellTarget(); return end          -- 秘密字串可測 nil
    local class = UnitSpellTargetClass_ and UnitSpellTargetClass_("focus") or nil
    Each(PaintSpellTargetOn, name, class)
    if UnitShouldDisplaySpellTargetName_ then
        local show = UnitShouldDisplaySpellTargetName_("focus")
        if show ~= nil then
            if issecret(show) then
                Each(GateSpellTargetOn, show)
            elseif not show then
                ClearSpellTarget()
            end
        end
    end
end

----------------------------------------------------------------------
-- 施法條建立（樣式：圖示在左 + 條 + 名稱疊左 / 時間疊右 / 法術目標在條下方右側）
----------------------------------------------------------------------
local GAP = 2

-- 1px 黑框：實體像素（P.Pixel；寫死 1 在 1440p 以上是 2px），圖示／條身的內縮用同一個值。
-- 條在登入（Init）就建，那時 UI 縮放還不一定是最終值 ⇒ 每次開始顯示與 UpdateBarSize 重算、
-- 跟上次一樣就不動（h.borderPx）；框、圖示、條身都關像素貼齊。規則全文：.claude/notes/wow-1px-border-rules.md
local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"

local function SetPixelBackdrop(f, px, a)
    f:SetBackdrop({ bgFile = WHITE8X8, edgeFile = WHITE8X8, edgeSize = px })
    ns.P.NoSnapBackdrop(f)
    f:SetBackdropColor(0, 0, 0, a)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

local function LayoutBorders(h)
    local px = ns.P.Pixel(1)
    if h.borderPx == px then return end
    h.borderPx = px
    local iconBorder, barBorder = h.iconBorder, h.barBorder
    SetPixelBackdrop(iconBorder, px, 1)
    SetPixelBackdrop(barBorder, px, 0.5)
    h.icon:ClearAllPoints()
    h.icon:SetPoint("TOPLEFT",     iconBorder, "TOPLEFT",      px, -px)
    h.icon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -px,  px)
    h.bar:ClearAllPoints()
    h.bar:SetPoint("TOPLEFT",     barBorder, "TOPLEFT",      px, -px)
    h.bar:SetPoint("BOTTOMRIGHT", barBorder, "BOTTOMRIGHT", -px,  px)
end

local function ComputeFrameSize(w, h)
    return w + h + GAP, h
end

local function UpdateBarPosition()
    if not barFrame then return end
    local db = DB()
    barFrame:ClearAllPoints()
    barFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

-- 一條的零件照設定重排（本尊與分身各叫一次；整條的大小本尊自己設、分身錨滿本尊）
local function UpdateBarSizeOn(h)
    local db = DB()
    local hh = db.height
    LayoutBorders(h)
    h.iconBorder:SetSize(hh, hh)
    h.spark:SetSize(10, hh * 2.2)
    local font = ns.Media.Font()
    h.nameText:SetFont(font, math.max(8, hh - 8), "OUTLINE")
    h.bangText:SetFont(font, math.max(8, hh - 8), "OUTLINE")
    h.timeText:SetFont(font, math.max(8, hh - 8), "OUTLINE")
    h.targetText:SetFont(font, TargetFontSize(hh), "OUTLINE")
    local bb = h.barBorder
    h.targetText:ClearAllPoints()
    h.targetText:SetPoint("TOPRIGHT", bb, "BOTTOMRIGHT", db.targetX or 0, db.targetY or 0)
    h.targetText:SetPoint("TOPLEFT",  bb, "BOTTOMLEFT",  0,                db.targetY or 0)
    h.targetText:SetShown(db.showTarget and true or false)
end

local function UpdateBarSize()
    if not barFrame then return end
    local db = DB()
    barFrame:SetSize(ComputeFrameSize(db.width, db.height))
    UpdateBarSizeOn(barFrame)
    UpdateBarSizeOn(twin)
end

local function SaveDragPosition(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    local cx, cy = UIParent:GetCenter()
    local fx, fy = self:GetCenter()
    local db = DB()
    db.x = math.floor(fx - cx + 0.5)
    db.y = math.floor(fy - cy + 0.5)
    ns.Fire("SettingsChanged")
end

-- 一條施法條的零件建在框 h 上：圖示＋1px 邊框、條容器＋1px 邊框、填充條、火花、文字疊層。
-- 本尊（barFrame）與分身（twin）各建一份 ⇒ 兩條長得一樣
local function BuildParts(h)
    local iconBorder = CreateFrame("Frame", nil, h, "BackdropTemplate")
    iconBorder:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    -- backdrop 與圖示內縮在 LayoutBorders 設（UpdateBarSize 會叫）
    h.icon = ns.P.NoSnap(iconBorder:CreateTexture(nil, "ARTWORK"))
    h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    h.iconBorder = iconBorder

    local barBorder = CreateFrame("Frame", nil, h, "BackdropTemplate")
    barBorder:SetPoint("TOPLEFT",     iconBorder, "TOPRIGHT",    GAP, 0)
    barBorder:SetPoint("BOTTOMRIGHT", h,          "BOTTOMRIGHT", 0,   0)
    -- backdrop 與條身內縮在 LayoutBorders 設
    h.barBorder = barBorder

    h.bar = CreateFrame("StatusBar", nil, barBorder)
    h.bar:SetStatusBarTexture(ns.Media.BarTexture())
    ns.P.NoSnap(h.bar)   -- 填充貼圖跟 1px 框相接，一起不貼齊
    h.bar:SetMinMaxValues(0, 1)
    h.bar:SetValue(1)

    h.spark = h.bar:CreateTexture(nil, "OVERLAY")
    h.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    h.spark:SetBlendMode("ADD")
    h.spark:SetPoint("CENTER", h.bar:GetStatusBarTexture(), "RIGHT", 0, 0)

    -- 文字疊層
    local overlay = CreateFrame("Frame", nil, barBorder)
    overlay:SetAllPoints(barBorder)
    overlay:SetFrameLevel(barBorder:GetFrameLevel() + 5)

    -- 在地化字型：寫死 FRIZQT__ 在中文客戶端會變方框
    local font = ns.Media.Font()
    h.timeText = overlay:CreateFontString(nil, "OVERLAY")
    h.timeText:SetFont(font, 14, "OUTLINE")
    h.timeText:SetPoint("RIGHT", barBorder, "RIGHT", -5, 0)
    h.timeText:SetJustifyH("RIGHT")
    h.timeText:SetTextColor(1, 1, 1)

    h.nameText = overlay:CreateFontString(nil, "OVERLAY")
    h.nameText:SetFont(font, 14, "OUTLINE")
    h.nameText:SetPoint("LEFT", barBorder, "LEFT", 5, 0)
    h.nameText:SetPoint("RIGHT", h.timeText, "LEFT", -4, 0)
    h.nameText:SetJustifyH("LEFT")
    h.nameText:SetWordWrap(false)
    h.nameText:SetTextColor(1, 1, 1)

    -- 重要法術版的名字（前面加「!」），疊在同一個位置。是不是重要是秘密布林，
    -- 不能在 Lua 挑要寫哪段字 —— 兩段都寫好，交給 SetAlphaFromBoolean 二選一
    h.bangText = overlay:CreateFontString(nil, "OVERLAY")
    h.bangText:SetFont(font, 14, "OUTLINE")
    h.bangText:SetAllPoints(h.nameText)
    h.bangText:SetJustifyH("LEFT")
    h.bangText:SetWordWrap(false)
    h.bangText:SetTextColor(1, 1, 1)
    h.bangText:SetAlpha(0)

    -- 法術打向誰：掛在條下方、右靠齊（位置與字級在 UpdateBarSizeOn）
    h.targetText = overlay:CreateFontString(nil, "OVERLAY")
    h.targetText:SetFont(font, 10, "OUTLINE")
    h.targetText:SetJustifyH("RIGHT")
    h.targetText:SetWordWrap(false)
    h.targetText:SetTextColor(1, 1, 1)

    h.glowHosts = {}
end

local MakeShake   -- forward declaration（開唱震動那一節）

local function CreateBarFrame()
    if barFrame then return end
    local db = DB()
    local fw, fh = ComputeFrameSize(db.width, db.height)

    barFrame = CreateFrame("Frame", "MiliUIFocus_CastBar", UIParent)
    barFrame:SetSize(fw, fh)
    barFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetFrameLevel(10)
    barFrame:SetMovable(true)
    barFrame:SetUserPlaced(false)
    barFrame:SetClampedToScreen(true)
    barFrame:Hide()
    BuildParts(barFrame)
    barStatusBar, barIcon, barSpark = barFrame.bar, barFrame.icon, barFrame.spark
    nameText, bangText, timeText, targetText = barFrame.nameText, barFrame.bangText, barFrame.timeText, barFrame.targetText

    -- 震動用的分身：本尊的兄弟框（不是子框：本尊 alpha 0 時分身要看得到）、疊在同一個位置、零件同一支 BuildParts。
    -- 平常藏著，只在開唱後震的那幾秒顯示
    twin = CreateFrame("Frame", nil, UIParent)
    twin:SetAllPoints(barFrame)
    twin:SetFrameStrata("MEDIUM")
    twin:SetFrameLevel(10)
    twin:Hide()
    BuildParts(twin)
    barFrame.shake = MakeShake(barFrame)   -- 本尊自己的：每次都震的模式、施法中途變成可以斷時
    twin.shake = MakeShake(twin)
    twin.shake:SetScript("OnFinished", function() EndShake() end)

    -- 拖曳（編輯模式）
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", function(self)
        if self.unlocked then self:StartMoving() end
    end)
    barFrame:SetScript("OnDragStop", SaveDragPosition)

    -- 編輯模式選取框
    local editSelection = CreateFrame("Frame", nil, barFrame, "EditModeSystemSelectionTemplate")
    -- ⚠⚠ 模板的 XML 綁了 OnMouseDown → EditModeManagerFrame:SelectSystem(self.parent)。
    --   我們不是真的 Edit Mode 系統，點一下不拖曳就讓暴雪帶著本插件的 taint 掃過
    --   每一個已註冊系統（動作條也在內）；當下靜默，戰鬥中動作條被封鎖才爆出來。
    editSelection:SetScript("OnMouseDown", function() end)
    editSelection:SetAllPoints()
    editSelection:Hide()
    editSelection:RegisterForDrag("LeftButton")
    editSelection:SetScript("OnDragStart", function() barFrame:StartMoving() end)
    editSelection:SetScript("OnDragStop", function() SaveDragPosition(barFrame) end)
    editSelection.system = {
        GetSystemName = function() return ns.L["Focus cast bar"] end,
    }
    barFrame.editSelection = editSelection
    UpdateBarSize()
    -- OnUpdate 不在此掛：一般模式施法時才掛 LegacyOnUpdate；秘密模式改用 displayTicker。
end

----------------------------------------------------------------------
-- 可斷法發光（glowKick，2026-11-07）
--
-- 專注目標在唱可以斷的法術時整條亮著：共用發光引擎的 BarGlow 三款（kickGlowStyle：halo 光暈／sweep 流光／
-- pulse 脈衝）。跟重要法術發光同一招：發光掛在自己的宿主框（h.kickGlowHost）上、整段施法都開著，「不可中斷」的布林
-- （受限內容是秘密布林）只餵宿主的 alpha（不可中斷 ⇒ 0），Lua 從頭到尾不讀它；明文的不可中斷連開都不開。
-- 施法中途變可斷／不可斷（事件名稱是明文）重畫一次。被打斷、收條時停。
----------------------------------------------------------------------
local KICK_GLOW_STYLES = { halo = true, sweep = true, pulse = true }

local function KickGlowStyle()
    local st = DB().kickGlowStyle
    return KICK_GLOW_STYLES[st] and st or "halo"
end

-- 在 host 上開可斷法發光（畫面上那條、分身與設定頁的樣本共用這一支）。w／h ＝ host 的大小（發光引擎不讀框的幾何）
local function KickGlowStart(host, w, h)
    local c = DB().colorKickGlow
    LCG.BarGlow_Start(host, KickGlowStyle(), { c.r, c.g, c.b, 1 }, {
        edgeFile = ns.Media.GLOW_EDGE, width = w, height = h, px = ns.P.Pixel(1),
    })
end

local function StopKickGlowOn(h)
    if not h.kickGlowOn then return end
    h.kickGlowOn = false
    LCG.BarGlow_Stop(h.kickGlowHost)
end

local function StopKickGlow()
    Each(StopKickGlowOn)
end

-- ni ＝ 不可中斷：nil（不知道，當可以斷）／明文／秘密布林
local function PaintKickGlowOn(h, ni)
    local db = DB()
    if not db.glowKick then StopKickGlowOn(h); return end
    if ni ~= nil and not issecret(ni) and ni then StopKickGlowOn(h); return end
    local host = h.kickGlowHost
    if not host then
        host = CreateFrame("Frame", nil, h)
        host:SetAllPoints(h)
        host:SetFrameLevel(h:GetFrameLevel() + 19)   -- 比重要法術的宿主（+20）低一層
        h.kickGlowHost = host
    end
    KickGlowStart(host, ComputeFrameSize(db.width, db.height))
    h.kickGlowOn = true
    if issecret(ni) then
        -- 餵不進去就整個關掉：寧可不亮，不能讓不可中斷的施法也亮著
        if not pcall(host.SetAlphaFromBoolean, host, ni, 0, 1) then StopKickGlowOn(h) end
    else
        host:SetAlpha(1)
    end
end

local function PaintKickGlow(ni)
    Each(PaintKickGlowOn, ni)
end

----------------------------------------------------------------------
-- 開唱震動（shakeMode：off／always／kick，預設 kick；秒數 shakeTime，預設 2）
--
-- always：每次開唱直接震本尊（barFrame.shake），不分可不可以斷。以下講的都是 kick（只震可以斷的施法）：
-- 「這個法術可不可以斷」（ni）在受限內容是秘密布林。位移類的 API（Translation:SetOffset、SetPoint、SetScale）
-- 的 SecretArguments 都是 AllowedWhenUntainted ⇒ 插件餵不進秘密值，沒辦法「可斷才位移」；收秘密布林的只有 alpha。
-- 所以：分身（twin，CreateBarFrame 建的）每次開唱都震，本尊不動；兩條的 alpha 餵同一個布林、互補
--   可以斷   ⇒ 本尊 0、分身 1（看到在震的那條）
--   不可中斷 ⇒ 本尊 1、分身 0（看到沒動的那條）
-- 震完分身藏起來、本尊 alpha 設回 1。明文模式（脫戰）走同一條路，只是布林是明文；明文的「不可中斷」連分身都不開。
-- 做法同冷卻管理器的專注目標施法條（那邊 2026-11-08 實機驗過）。
--
-- 三步：
--   ArmShake(ni)   開唱一開始：決定這次帶不帶分身（twinOn）。之後畫到本尊的東西經 Each 也畫到分身
--   GoShake(ni)    開唱畫完：分 alpha、分身顯示、開始震
--   EndShake()     震完／收條／被打斷／下一次開唱：分身收掉、本尊 alpha 回 1。可以重複叫
-- ⚠ 本尊餵過 SetAlphaFromBoolean 之後帶 alpha 面向，GetAlpha 會回秘密值：這個檔不讀條的 alpha（只寫）
-- ⚠ 動畫組在框被藏起來時會停、不保證派 OnFinished ⇒ 另外記到期時間（shakeEnd），每輪計時（WatchShake）補收
--
-- 動畫：每 0.05 秒跳一次、六段一組的位移反覆（Translation 只動畫面上的位置，不改錨點，播完自己歸位）。
-- 秒數可調：動畫組刪不掉也不能增減段數 ⇒ 一次建滿 SHAKE_MAX 秒的段數，PlayShake 照秒數把用到的段配上位移與 0.05 秒、
-- 用不到的設成 0 秒（新建的動畫本來就是 0 秒）
----------------------------------------------------------------------
local SHAKE_PATTERN = { { -2, 1 }, { 3, -2 }, { -2, 2 }, { 2, -2 }, { -2, 1 }, { 1, 0 } }
local SHAKE_STEP, SHAKE_MIN, SHAKE_MAX, SHAKE_DEFAULT = 0.05, 0.1, 3, 2
local SHAKE_SLOTS = math.floor(SHAKE_MAX / SHAKE_STEP + 0.5)
CastBar.SHAKE_MIN, CastBar.SHAKE_MAX, CastBar.SHAKE_DEFAULT = SHAKE_MIN, SHAKE_MAX, SHAKE_DEFAULT

local function ShakeMode()
    local m = DB().shakeMode
    return (m == "always" or m == "kick") and m or "off"
end
CastBar.ShakeMode = ShakeMode

local function ShakeTime()
    local t = tonumber(DB().shakeTime) or SHAKE_DEFAULT
    if t < SHAKE_MIN then t = SHAKE_MIN elseif t > SHAKE_MAX then t = SHAKE_MAX end
    return t
end

function MakeShake(frame)
    local group = frame:CreateAnimationGroup()
    group.steps = {}
    for i = 1, SHAKE_SLOTS do
        local t = group:CreateAnimation("Translation")
        t:SetOrder(i)
        group.steps[i] = t
    end
    return group
end

-- 照設定的秒數配好每一段，從頭播。回傳這次的長度（秒）
local function PlayShake(group)
    local secs = ShakeTime()
    group:Stop()
    if group.secs ~= secs then
        local n = math.floor(secs / SHAKE_STEP + 0.5)
        if n < 1 then n = 1 elseif n > SHAKE_SLOTS then n = SHAKE_SLOTS end
        for i, t in ipairs(group.steps) do
            if i <= n then
                local p = SHAKE_PATTERN[(i - 1) % #SHAKE_PATTERN + 1]
                t:SetOffset(p[1], p[2])
                t:SetDuration(SHAKE_STEP)
            else
                t:SetOffset(0, 0)
                t:SetDuration(0)
            end
        end
        group.secs = secs
    end
    group:Play()
    return secs
end

function EndShake()
    if not twinOn then return end
    twinOn = false
    twin.shake:Stop()
    twin:Hide()
    StopGlowOn(twin)
    StopKickGlowOn(twin)
    barFrame:SetAlpha(1)
end

local function ArmShake(ni)
    if not barFrame then return end
    EndShake()                                            -- 上一次的還沒震完就又開唱
    barFrame.shake:Stop()
    if ShakeMode() ~= "kick" then return end              -- always 不用分身（GoShake 直接震本尊）
    if not issecret(ni) and ni then return end            -- 明文的不可中斷：不震
    twinOn = true
end

local function GoShake(ni)
    if not barFrame then return end
    if not twinOn then
        if ShakeMode() == "always" then PlayShake(barFrame.shake) end      -- 每次開唱都震：本尊自己震
        return
    end
    if issecret(ni) then
        -- 餵不進去（哪一條都算）就整個放掉：寧可不震，不能讓條不見
        if not (pcall(barFrame.SetAlphaFromBoolean, barFrame, ni, 1, 0) and pcall(twin.SetAlphaFromBoolean, twin, ni, 0, 1)) then
            EndShake()
            return
        end
    else
        barFrame:SetAlpha(0)
        twin:SetAlpha(1)
    end
    twin:Show()
    shakeEnd = GetTime() + PlayShake(twin.shake) + 0.1
end

function WatchShake(now)
    if twinOn and now >= shakeEnd then EndShake() end
end

-- 施法中途變成可以斷（UNIT_SPELLCAST_INTERRUPTIBLE，事件名稱是明文）：直接震本尊。分身還在震就不疊
local function Jolt()
    if not barFrame or twinOn or ShakeMode() == "off" then return end
    PlayShake(barFrame.shake)
end

----------------------------------------------------------------------
-- 顯示 / 隱藏
----------------------------------------------------------------------
-- HideBar 已於檔案上方 forward-declare
function HideBar()
    active = false
    displayToken = displayToken + 1           -- 讓待決的打斷停留計時器失效
    StopDisplayTicker()
    if barFrame then
        EndShake()
        barFrame.shake:Stop()
        barFrame:SetScript("OnUpdate", nil)   -- 卸掉一般模式的每幀回呼
        if not isInEditMode then
            StopGlow()
            StopKickGlow()
            ClearSpellTarget()
            barFrame:Hide()
        end
    end
end

----------------------------------------------------------------------
-- 施法被打斷：凍結滿條變紅 + 顯示斷法者名字（職業色），停留後消失
----------------------------------------------------------------------
local function ShowInterrupted(interrupterGUID)
    if not active then return end             -- 沒在顯示這條施法就不處理
    active = false                            -- 停止進度更新，但條保留顯示
    StopDisplayTicker()
    EndShake()                                -- 分身收掉（紅條只畫本尊）
    barFrame.shake:Stop()
    barFrame:SetScript("OnUpdate", nil)
    StopGlow()                                -- 施法已經斷了，紅條不再標重要
    StopKickGlow()                            -- 也沒有東西可以斷了

    barStatusBar:SetMinMaxValues(0, 1)
    barStatusBar:SetValue(1)
    barStatusBar:SetStatusBarColor(INTERRUPTED_COLOR[1], INTERRUPTED_COLOR[2], INTERRUPTED_COLOR[3])
    SetName(ns.L["Interrupted"])
    timeText:SetText("")
    ClearSpellTarget()                        -- 施法斷了，打向誰已經不重要

    -- 斷法者名字 + 職業色（interrupterGUID 只做 ~= nil 檢查，秘密安全）
    if interrupterGUID ~= nil then
        local name, class
        if UnitNameFromGUID then
            name = UnitNameFromGUID(interrupterGUID)
            local _, c = GetPlayerInfoByGUID(interrupterGUID)
            class = c
        elseif UnitTokenFromGUID then
            local u = UnitTokenFromGUID(interrupterGUID)
            if u then name, class = UnitName(u), UnitClassBase(u) end
        end
        if name ~= nil then
            -- ⚠ class 是秘密字串就**不上色**（維持白字），不要硬查表。
            --   兩個各自會炸的點：
            --     1. `RAID_CLASS_COLORS[class]` —— 秘密值不能當 table key，直接硬錯
            --        （"cannot be indexed with secret keys"）。這條備援平常走不到
            --        （12.1 有 C_ClassColor），但 GetClassColor 回 nil 時就會落下來。
            --     2. 就算走 C_ClassColor 那條，回來的分量也是秘密的，而
            --        `FontString:SetTextColor` 不在「吃得下秘密值」的名單裡。
            --   名字本身照樣顯示得出來 —— SetText 收秘密字串是合法的（當傳遞者不當讀取者）。
            local r, g, b = 1, 1, 1
            if class ~= nil and not issecret(class) then
                local color = C_ClassColor and C_ClassColor.GetClassColor(class)
                    or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                if color then r, g, b = color:GetRGB() end
            end
            timeText:SetTextColor(r, g, b)
            timeText:SetText(name)
        end
    end

    -- 停留 INTERRUPT_HOLD 秒後收條；期間若開始新施法（token 改變）則放棄
    displayToken = displayToken + 1
    local tok = displayToken
    C_Timer.After(INTERRUPT_HOLD, function()
        if tok == displayToken then HideBar() end
    end)
end

-- 選 duration 方向（明文旗標，安全）
local function TimerDir(isChannel, isEmpowered)
    if isChannel and not isEmpowered then
        return Enum.StatusBarTimerDirection.RemainingTime
    end
    return Enum.StatusBarTimerDirection.ElapsedTime
end

-- 開始顯示專注目標施法條（不放音效）。castTbl/chanTbl 可由呼叫端預讀後傳入，避免重複讀取。
-- resumed ＝ 不是剛開唱（換專注目標、離開範例條、套用設定時接上正在唱的那一條）：不震
local function StartDisplay(castTbl, chanTbl, resumed)
    if not Monitoring() then return end
    if isInEditMode then return end   -- 範例條顯示中不蓋掉；離開時 RefreshFromFocus 會接回

    -- 用 == nil 偵測（秘密安全）；用「明文 isCast」旗標挑欄位，避免對秘密值分支
    castTbl = castTbl or { UnitCastingInfo("focus") }
    chanTbl = chanTbl or { UnitChannelInfo("focus") }
    local isCast    = castTbl[1] ~= nil
    local isChannel = (not isCast) and (chanTbl[1] ~= nil)
    if not (isCast or isChannel) then HideBar(); return end

    -- 依明文旗標選欄位（值本身可能是秘密，但這裡只是賦值，不分支）
    local name, texture, notInt, s4, s5, isEmpowered, spellID
    if isCast then
        name, texture, notInt = castTbl[1], castTbl[3], castTbl[8]
        s4, s5 = castTbl[4], castTbl[5]
        spellID = castTbl[9]
        isEmpowered = false
    else
        name, texture, notInt = chanTbl[1], chanTbl[3], chanTbl[7]
        s4, s5 = chanTbl[4], chanTbl[5]
        spellID = chanTbl[8]
        isEmpowered = chanTbl[9] and true or false     -- isEmpowered 為法術屬性，非秘密
    end

    CreateBarFrame()
    displayToken         = displayToken + 1   -- 新施法：讓打斷停留計時器失效
    castChannel          = isChannel
    castNotInterruptible = notInt
    colorAccum           = 1        -- 強制首幀更新文字
    -- 從這裡到 GoShake：畫到本尊的東西都經 Each，分身跟著畫
    if resumed then
        EndShake()
        barFrame.shake:Stop()
    else
        ArmShake(notInt)
    end
    barFrame:SetAlpha(1)
    Each(LayoutBorders)             -- 1px 框在顯示時重算（沒變就不動）
    Each(PaintIconOn, texture)

    local important = QueryImportant(spellID)
    SetName(name, important)
    if important == nil then StopGlow() else ShowGlow(important) end
    PaintKickGlow(notInt)
    SetSpellTarget()

    if SecretsActive() then
        -- 秘密模式：起訖時間為秘密值，改用 duration 物件驅動 StatusBar；顏色用 C_CurveUtil
        castSecret     = true
        castLocalStart = GetTime()
        barFrame:SetScript("OnUpdate", nil)   -- 秘密模式不用每幀回呼
        local dur
        if isChannel then
            if isEmpowered and UnitEmpoweredChannelDuration then
                dur = UnitEmpoweredChannelDuration("focus", true)
            elseif UnitChannelDuration then
                dur = UnitChannelDuration("focus")
            end
        elseif UnitCastingDuration then
            dur = UnitCastingDuration("focus")
        end
        if dur and barStatusBar.SetTimerDuration then
            -- GetTotalDuration 可能回秘密數字（不能比較/運算），擋掉改走無數字路徑
            castTotal = 0
            if dur.GetTotalDuration then
                local total = dur:GetTotalDuration()
                if total ~= nil and not issecret(total) then
                    castTotal = total
                end
            end
            Each(BarTimerOn, dur, TimerDir(isChannel, isEmpowered))
        else
            castTotal = 0                 -- 拿不到 duration：滿條、不顯示數字，靠事件收條
            Each(BarValueOn, 1)
        end
        active = true
        ApplySecretColor()                -- 立即上色
        StartDisplayTicker()              -- 10Hz：時間文字 + 顏色（斷法冷卻變化）
        barFrame:Show()
        if not resumed then GoShake(notInt) end
        return
    end

    -- 一般模式：可直接讀起訖時間（秒）並在 Lua 判斷狀態
    castSecret = false
    StopDisplayTicker()
    castStart = (s4 or 0) / 1000
    castEnd   = (s5 or 0) / 1000
    local c = ColorForState(ComputeState(notInt))
    Each(BarColorOn, c.r, c.g, c.b)
    Each(BarValueOn, isChannel and 1 or 0)
    active = true
    barFrame:SetScript("OnUpdate", LegacyOnUpdate)   -- 施法期間才掛每幀回呼
    barFrame:Show()
    if not resumed then GoShake(notInt) end
end

-- 延遲/推條：只重設「計時來源」，不重讀圖示/名稱/位置，避免文字跳動與多餘工作
local function ResyncTiming()
    if not active then return end
    if castSecret then
        local castName = UnitCastingInfo("focus")   -- 秘密字串可 ~=nil
        local dur, isChannel, isEmpowered
        if castName ~= nil then
            isChannel, isEmpowered = false, false
            if UnitCastingDuration then dur = UnitCastingDuration("focus") end
        else
            local chanTbl = { UnitChannelInfo("focus") }
            if chanTbl[1] == nil then return end     -- 沒在施法，交給 STOP 事件收條
            isChannel   = true
            isEmpowered = chanTbl[9] and true or false
            if isEmpowered and UnitEmpoweredChannelDuration then
                dur = UnitEmpoweredChannelDuration("focus", true)
            elseif UnitChannelDuration then
                dur = UnitChannelDuration("focus")
            end
        end
        -- 只重設引擎計時（條保持準確）；castLocalStart 不動，避免近似文字跳回 0
        if dur and barStatusBar.SetTimerDuration then
            Each(BarTimerOn, dur, TimerDir(isChannel, isEmpowered))
        end
    else
        local castName = UnitCastingInfo("focus")
        local s4, s5
        if castName ~= nil then
            s4, s5 = select(4, UnitCastingInfo("focus")), select(5, UnitCastingInfo("focus"))
        else
            local chanTbl = { UnitChannelInfo("focus") }
            if chanTbl[1] == nil then return end
            s4, s5 = chanTbl[4], chanTbl[5]
        end
        castStart = (s4 or 0) / 1000
        castEnd   = (s5 or 0) / 1000
    end
end

-- 專注目標切換 / 重新整理：若專注目標正在施法就顯示（不放音效）
local function RefreshFromFocus()
    if not Monitoring() then HideBar(); return end
    StartDisplay(nil, nil, true)   -- 內部自行判斷是否在施法，未施法會收條
end

----------------------------------------------------------------------
-- 編輯模式（三層 hook）
----------------------------------------------------------------------
local function UpdateEditModeState()
    if not ns.db then return end
    local wasPreview = isInEditMode
    isInEditMode = editModeOpen or settingsOpen
    CreateBarFrame()
    if isInEditMode and Monitoring() then
        -- 進入編輯模式：停掉施法中的每幀回呼/ticker，顯示靜態範例
        active = false
        StopDisplayTicker()
        EndShake()
        barFrame.shake:Stop()
        barFrame:SetScript("OnUpdate", nil)
        barFrame.unlocked = true
        barFrame:EnableMouse(true)
        barIcon:SetTexture(132329)                 -- 範例圖示（隨便一個法術）
        SetName(ns.L["Focus cast bar"], true)     -- 範例條當重要法術，看得到驚嘆號
        timeText:SetText("0.9/1.5")
        if DB().showTarget then
            PaintSpellTargetOn(barFrame, UnitName("player"), playerClass)   -- 範例：打向自己
        else
            ClearSpellTarget()
        end
        barStatusBar:SetMinMaxValues(0, 1)
        barStatusBar:SetValue(0.6)
        local c = ColorForState("ready")
        barStatusBar:SetStatusBarColor(c.r, c.g, c.b)
        ShowGlow()                                 -- 範例條直接亮，看得到發光長相
        PaintKickGlow(false)                       -- 範例條是可以斷的施法
        barFrame.editSelection:ShowHighlighted()
        UpdateBarPosition()
        UpdateBarSize()
        barFrame:Show()
    else
        if not barFrame then return end
        barFrame.unlocked = false
        barFrame:EnableMouse(false)
        barFrame.editSelection:Hide()
        if not active then
            StopGlow()
            StopKickGlow()
            barFrame:Hide()
        end
        -- 剛離開範例：專注目標若正在施法，接回真正的讀條
        if wasPreview then RefreshFromFocus() end
    end
end

local editModeHooked = false
local function HookEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", function() editModeOpen = true;  UpdateEditModeState() end)
    EditModeManagerFrame:HookScript("OnHide", function() editModeOpen = false; UpdateEditModeState() end)
    if EditModeManagerFrame:IsShown() then editModeOpen = true; UpdateEditModeState() end
end

HookEditMode()  -- Tier 1
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)  -- Tier 2
end

----------------------------------------------------------------------
-- 對外（設定面板用）
----------------------------------------------------------------------
-- 設定改完統一走這裡
function CastBar.Apply()
    if not ns.db then return end
    if not Monitoring() then HideBar() end
    CreateBarFrame()
    StopGlow()          -- 換色／關掉發光：拆掉重建，下面的刷新會照新設定再點亮
    StopKickGlow()
    UpdateBarPosition()
    UpdateBarSize()
    UpdateEditModeState()
    RefreshFromFocus()
end

-- 設定視窗開／關：跟編輯模式一樣顯示範例條讓玩家拖
function CastBar.SetSettingsOpen(open)
    settingsOpen = open and true or false
    UpdateEditModeState()
end

-- 設定頁「可斷法的施法」小節的樣本條：一條自己循環填滿的假施法（可以斷、斷法就緒的顏色）。
-- 條身是照畫面上那條的排法另外擺的簡化版（圖示＋條＋名字；畫面上那條的零件是模組層的單例，借不過來），
-- **發光是畫面上那條用的同一支 KickGlowStart、震動是同一支 MakeShake／PlayShake**（每循環一次算一次開唱；
-- 樣本是可以斷的施法，所以 off 以外的模式都震——kick 在畫面上是分身＋互補 alpha，樣本的狀態是明文，直接震自己）。
-- 畫面上那條在設定視窗開著時也會切成範例條、一樣亮著，兩邊對得起來。
--   local s = CastBar.CreateKickSample(parent)   s 是框，位置由呼叫端擺
--   s:Refresh(maxW)                              照目前設定重排重畫（寬放不下縮到 maxW、高夾在 12～24）
local SAMPLE_TIME, SAMPLE_HOLD = 3, 0.6

function CastBar.CreateKickSample(parent)
    local s = CreateFrame("Frame", nil, parent)
    local iconBorder = CreateFrame("Frame", nil, s, "BackdropTemplate")
    iconBorder:SetPoint("TOPLEFT", s, "TOPLEFT", 0, 0)
    local icon = ns.P.NoSnap(iconBorder:CreateTexture(nil, "ARTWORK"))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(132329)
    local barBorder = CreateFrame("Frame", nil, s, "BackdropTemplate")
    barBorder:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", GAP, 0)
    barBorder:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", 0, 0)
    local bar = CreateFrame("StatusBar", nil, barBorder)
    bar:SetStatusBarTexture(ns.Media.BarTexture())
    ns.P.NoSnap(bar)
    bar:SetMinMaxValues(0, 1)
    local overlay = CreateFrame("Frame", nil, barBorder)
    overlay:SetAllPoints(barBorder)
    overlay:SetFrameLevel(barBorder:GetFrameLevel() + 5)
    local name = overlay:CreateFontString(nil, "OVERLAY")
    name:SetFont(ns.Media.Font(), 12, "OUTLINE")
    name:SetPoint("LEFT", barBorder, "LEFT", 5, 0)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1, 1, 1)
    name:SetText(ns.L["Focus cast bar"])
    local glowHost = CreateFrame("Frame", nil, s)
    glowHost:SetAllPoints(s)
    glowHost:SetFrameLevel(s:GetFrameLevel() + 19)
    local shake = MakeShake(s)

    local t = 0
    s:SetScript("OnUpdate", function(_, dt)
        t = t + dt
        if t >= SAMPLE_TIME + SAMPLE_HOLD then
            t = t % (SAMPLE_TIME + SAMPLE_HOLD)
            if ShakeMode() ~= "off" then PlayShake(shake) end     -- 循環回到開頭 ＝ 又一次開唱
        end
        bar:SetValue(t < SAMPLE_TIME and t / SAMPLE_TIME or 1)
    end)

    function s:Refresh(maxW)
        local db = DB()
        local h = math.max(12, math.min(24, db.height))
        local w = ComputeFrameSize(db.width, h)
        if maxW and w > maxW then w = maxW end
        self:SetSize(w, h)
        local px = ns.P.Pixel(1)
        iconBorder:SetSize(h, h)
        SetPixelBackdrop(iconBorder, px, 1)
        SetPixelBackdrop(barBorder, px, 0.5)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", iconBorder, "TOPLEFT", px, -px)
        icon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -px, px)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", barBorder, "TOPLEFT", px, -px)
        bar:SetPoint("BOTTOMRIGHT", barBorder, "BOTTOMRIGHT", -px, px)
        local c = ColorForState("ready")
        bar:SetStatusBarColor(c.r, c.g, c.b)
        name:SetFont(ns.Media.Font(), math.max(8, h - 8), "OUTLINE")
        if db.glowKick then
            KickGlowStart(glowHost, w, h)
            glowHost:SetAlpha(1)
        else
            LCG.BarGlow_Stop(glowHost)
        end
    end
    return s
end

function CastBar.PreviewSound()
    ns.Media.PlaySoundValue(DB().sound)
end

-- 給「複製斷法巨集」用：回傳玩家目前已學的第一個斷法法術名稱（無則 nil）
function CastBar.GetInterruptSpellName()
    if #currentInterrupt == 0 then RefreshInterruptSpells() end
    local id = currentInterrupt[1]
    if id then return C_Spell.GetSpellName(id) end
    return nil
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
-- 施法事件 payload：(unit, castGUID, spellID[, interrupterGUID])；EMPOWER_STOP 多一個
-- complete 參數，interrupterGUID 在第 5 位
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(self, event, unit, arg2, arg3, arg4, arg5)
    if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD"
       or event == "UNIT_PET" then      -- 術士換惡魔＝換斷法，寵物 bank 的答案跟著變
        RefreshInterruptSpells()
        return

    elseif event == "PLAYER_FOCUS_CHANGED" then
        RefreshFromFocus()
        return
    end

    -- 以下皆為 focus 單位施法事件
    if unit ~= "focus" then return end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
       or event == "UNIT_SPELLCAST_EMPOWER_START" then
        -- 只讀一次，音效與顯示共用，避免重複呼叫 UnitCastingInfo/UnitChannelInfo
        local castTbl = { UnitCastingInfo("focus") }
        local chanTbl = { UnitChannelInfo("focus") }
        HandleSound(castTbl, chanTbl)           -- 音效（不受監控開關左右）
        StartDisplay(castTbl, chanTbl)

    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        ResyncTiming()                          -- 延遲/推條：只重設計時

    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        -- 施法中途變可斷／不可斷：值從事件名稱拿（明文），不回頭讀 UnitCastingInfo（受限內容是秘密布林）
        if active then
            castNotInterruptible = (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
            if castSecret then ApplySecretColor() end        -- 一般模式由 LegacyOnUpdate 每 0.05 秒重算
            PaintKickGlow(castNotInterruptible)
            if event == "UNIT_SPELLCAST_INTERRUPTIBLE" then Jolt() end   -- 變成可以斷：也算一次提醒
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        ShowInterrupted(arg4)                   -- 讀條被打斷：顯示斷法者後收條

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if arg4 ~= nil then                     -- 通道被打斷才帶 interrupterGUID
            ShowInterrupted(arg4)
        else
            HideBar()
        end

    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if arg5 ~= nil then                     -- 蓄力被打斷：GUID 在第 5 位
            ShowInterrupted(arg5)
        else
            HideBar()
        end

    else  -- STOP / FAILED
        HideBar()
    end
end)

ns.RegisterCallback("Init", "castbar", function()
    RefreshInterruptSpells()
    CreateBarFrame()
    HookEditMode()  -- Tier 3
    -- 冷卻管理器的專注目標施法條開關變了：重套（讓位／接回）。它比我們早載入，API 這時一定在（沒有就是沒裝）
    local api = _G.MiliUI_CooldownManager
    if type(api) == "table" and type(api.RegisterCallback) == "function" then
        pcall(api.RegisterCallback, "FocusCastBarChanged", "MiliUI_Focus", function() CastBar.Apply() end)
    end

    ev:RegisterEvent("SPELLS_CHANGED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterUnitEvent("UNIT_PET", "player")
    ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_START",          "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START",  "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START",  "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP",           "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP",   "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP",   "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED",    "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED",         "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED",        "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE",     "focus")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "focus")
end)
