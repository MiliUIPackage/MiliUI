------------------------------------------------------------
-- MiliUI Focuser 施法監控
-- 焦點目標施法條 + 唱法音效
--   * 施法條可在編輯模式拖曳（名稱：焦點目標施法）
--   * 三種斷法狀態顏色 / 音效（抄 Platynator 判斷邏輯與預設色）
-- 本模組完全獨立，不依賴 Platynator 或 BloodlustMusic 是否載入。
------------------------------------------------------------
MiliUI_FocusCast = {}

----------------------------------------------------------------------
-- 斷法法術對照表（抄自 Platynator/Display/Utilities.lua，正式服）
----------------------------------------------------------------------
local interruptMap = {
    ["DEATHKNIGHT"] = { 47528 },
    ["WARRIOR"]     = { 6552 },
    ["WARLOCK"]     = { 89766, 119910, 132409 },
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

----------------------------------------------------------------------
-- 預設值（顏色抄自 MiliUI/Config/Luxthos_Platynator.lua 的 autoColors）
--   ready  可斷法（斷法可用）   = interruptReady.ready   金黃
--   cd     可斷法但斷法CD       = cast.cast              橘
--   immune 不可中斷            = uninterruptable        灰
----------------------------------------------------------------------
local DEFAULTS = {
    monitor = true,
    x = 0,
    y = 260,           -- 預設放在 BloodlustMusic 倒數條（y=300）下方一點
    width = 220,
    height = 22,
    colorReady  = { 1,                  0.7411764860153198, 0 },
    colorCD     = { 0.9058824181556702, 0.4235294461250305, 0.2000000178813934 },
    colorImmune = { 0.5294117647058824, 0.5294117647058824, 0.5294117647058824 },
    soundReadyEnabled  = false, soundReady  = nil,
    soundCDEnabled     = false, soundCD     = nil,
    soundImmuneEnabled = false, soundImmune = nil,
}

local function CopyColor(c) return { c[1], c[2], c[3] } end

-- 本地化字型（抄 MiliUI_BloodlustMusic/Config.lua，避免中文顯示成方框）
local LOCALE_FONT
do
    local loc = GetLocale()
    if loc == "koKR" then
        LOCALE_FONT = "Fonts\\2002.TTF"
    elseif loc == "zhCN" then
        LOCALE_FONT = "Fonts\\ARKai_T.ttf"
    elseif loc == "zhTW" then
        LOCALE_FONT = "Fonts\\blei00d.TTF"
    else
        LOCALE_FONT = "Fonts\\FRIZQT__.TTF"
    end
end

-- 12.0「Secrets」：秘密限制生效時，施法起訖時間為秘密值，不能直接運算，
-- 必須改用 UnitCastingDuration + StatusBar:SetTimerDuration 由 StatusBar 內部驅動。
local function SecretsActive()
    return C_Secrets and C_Secrets.HasSecretRestrictions() and true or false
end

-- 12.0.1：pcall 接不到秘密值錯誤，數值存入明文變數前一律先檢查
local issecretvalue = issecretvalue or function() return false end

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.focusCast
    if not db then db = {}; MiliUI_DB.focusCast = db end
    if db.monitor == nil then db.monitor = DEFAULTS.monitor end
    if db.x       == nil then db.x = DEFAULTS.x end
    if db.y       == nil then db.y = DEFAULTS.y end
    if db.width   == nil then db.width = DEFAULTS.width end
    if db.height  == nil then db.height = DEFAULTS.height end
    if not db.colorReady  then db.colorReady  = CopyColor(DEFAULTS.colorReady)  end
    if not db.colorCD     then db.colorCD     = CopyColor(DEFAULTS.colorCD)     end
    if not db.colorImmune then db.colorImmune = CopyColor(DEFAULTS.colorImmune) end
    if db.soundReadyEnabled  == nil then db.soundReadyEnabled  = DEFAULTS.soundReadyEnabled  end
    if db.soundCDEnabled     == nil then db.soundCDEnabled     = DEFAULTS.soundCDEnabled     end
    if db.soundImmuneEnabled == nil then db.soundImmuneEnabled = DEFAULTS.soundImmuneEnabled end
    return db
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local db
local playerClass = (UnitClassBase and UnitClassBase("player")) or select(2, UnitClass("player"))

local barFrame, barStatusBar, barIcon, barSpark, nameText, timeText
local isInEditMode = false
local HideBar   -- forward declaration（供 ticker / OnUpdate 引用）

-- 打斷顯示：凍結條的顏色（抄 Luxthos_Platynator autoColors cast.interrupted 紅）
-- 與斷法者名字停留秒數（Platynator 名條預設 0.3s，但它有常駐名字；獨立條要讀得到名字，拉長）
local INTERRUPTED_COLOR = { 1, 0.2039215862751007, 0.1450980454683304 }
local INTERRUPT_HOLD    = 1.0

local active               = false   -- 目前是否有焦點施法在跑
local displayToken         = 0       -- 顯示世代：讓過期的「打斷停留」計時器失效
local castSecret           = false   -- 本次施法是否走秘密模式
local castStart, castEnd   = 0, 0    -- 一般模式：GetTime 起訖（秒）
local castLocalStart       = 0       -- 秘密模式：本地近似起始（僅供時間文字）
local castTotal            = 0       -- 秘密模式：總施法秒數
local castChannel          = false
local castNotInterruptible = false
local colorAccum           = 0

local currentInterrupt = {}          -- 玩家已學的斷法法術

----------------------------------------------------------------------
-- 斷法可用判斷（抄 Platynator 做法）
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
        if known then table.insert(currentInterrupt, s) end
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

local function ColorForState(state)
    db = db or GetDB()
    if state == "immune" then return db.colorImmune
    elseif state == "ready" then return db.colorReady
    else return db.colorCD end
end

----------------------------------------------------------------------
-- 秘密模式上色：notInterruptible 與斷法冷卻可用性都是秘密布林，
-- 絕不能在 Lua 分支，必須用 C_CurveUtil 把秘密布林餵給引擎選色（抄 Platynator）。
----------------------------------------------------------------------
local Eval = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean

local function ApplySecretColor()
    if not (Eval and barStatusBar) then return end
    db = db or GetDB()
    local ready, cd, immune = db.colorReady, db.colorCD, db.colorImmune
    -- 由 cd 起底，任一斷法冷卻歸零 → 覆蓋為 ready（多個技能層層 Eval）
    local r, g, b = cd[1], cd[2], cd[3]
    if C_Spell.GetSpellCooldownDuration then
        for _, spellID in ipairs(currentInterrupt) do
            local d = C_Spell.GetSpellCooldownDuration(spellID)
            if d then
                local z = d:IsZero()             -- 秘密布林，不分支
                r = Eval(z, ready[1], r)
                g = Eval(z, ready[2], g)
                b = Eval(z, ready[3], b)
            end
        end
    end
    -- 不可中斷 → 覆蓋為 immune
    local ni = castNotInterruptible              -- 秘密布林（或 false）
    r = Eval(ni, immune[1], r)
    g = Eval(ni, immune[2], g)
    b = Eval(ni, immune[3], b)
    local tex = barStatusBar:GetStatusBarTexture()
    if tex then tex:SetVertexColor(r, g, b) end
end

-- 秘密模式：不掛每幀 OnUpdate，改用單一 10Hz ticker 同時更新「近似時間文字 + 顏色」。
-- （條的填充由引擎的 SetTimerDuration 驅動；斷法冷卻變化也在這裡重算色。）
local displayTicker
local function StopDisplayTicker()
    if displayTicker then displayTicker:Cancel(); displayTicker = nil end
end

local function SecretTick()
    if not (active and castSecret) then StopDisplayTicker(); return end
    if isInEditMode then return end
    local elapsed = GetTime() - castLocalStart
    if castTotal > 0 then
        if elapsed > castTotal + 0.3 then   -- 保險：STOP 事件若漏掉也會收條
            HideBar()
            return
        end
        local shown = castChannel and (castTotal - elapsed) or elapsed
        if shown < 0 then shown = 0 elseif shown > castTotal then shown = castTotal end
        timeText:SetText(string.format("%.1f/%.1f", shown, castTotal))
    else
        -- 拿不到總長：改輪詢施法狀態收條（nil 判斷秘密安全），不猜固定秒數
        if UnitCastingInfo("focus") == nil and UnitChannelInfo("focus") == nil then
            HideBar()
            return
        end
        timeText:SetText("")
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
    barStatusBar:SetValue(ratio)

    colorAccum = colorAccum + dt
    if colorAccum >= 0.05 then
        colorAccum = 0
        if shown < 0 then shown = 0 elseif shown > total then shown = total end
        timeText:SetText(string.format("%.1f/%.1f", shown, total))
        local c = ColorForState(ComputeState(castNotInterruptible))
        barStatusBar:SetStatusBarColor(c[1], c[2], c[3])
    end
end

----------------------------------------------------------------------
-- 音效（獨立於施法監控開關）
----------------------------------------------------------------------
local function PlayAnySound(sound)
    if not sound then return end
    local num = tonumber(sound)
    if num then
        PlaySound(num, "Master")
    elseif type(sound) == "string" then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local path = LSM:Fetch("sound", sound)
            if path then PlaySoundFile(path, "Master") end
        end
    end
end

local function HandleSound(castTbl, chanTbl)
    db = db or GetDB()
    -- 秘密限制下 notInterruptible / 斷法冷卻皆為秘密值，無法依狀態挑音效
    -- （挑音效必然要對秘密分支 → taint，也正是暴雪封殺的自動斷法行為），故停用。
    if SecretsActive() then return end
    castTbl = castTbl or { UnitCastingInfo("focus") }
    chanTbl = chanTbl or { UnitChannelInfo("focus") }
    local isCast = castTbl[1] ~= nil
    if not isCast and chanTbl[1] == nil then return end

    -- 非秘密模式：notInterruptible 可讀，可安全判斷
    local notInterruptible
    if isCast then notInterruptible = castTbl[8] else notInterruptible = chanTbl[7] end
    local state = ComputeState(notInterruptible)
    if state == "immune" then
        if db.soundImmuneEnabled then PlayAnySound(db.soundImmune) end
    elseif state == "ready" then
        if db.soundReadyEnabled then PlayAnySound(db.soundReady) end
    else
        if db.soundCDEnabled then PlayAnySound(db.soundCD) end
    end
end

----------------------------------------------------------------------
-- 施法條建立（樣式：圖示在左 + 條 + 名稱疊左 / 時間疊右）
----------------------------------------------------------------------
local GAP = 2
local barTexture = "Interface\\Buttons\\WHITE8X8"
do
    if C_AddOns.IsAddOnLoaded("SharedMedia") then
        barTexture = "Interface\\AddOns\\SharedMedia\\statusbar\\normTex"
    elseif C_AddOns.IsAddOnLoaded("DBM-StatusBarTimers") then
        barTexture = "Interface\\AddOns\\DBM-StatusBarTimers\\textures\\default.blp"
    end
end

local function ComputeFrameSize(w, h)
    return w + h + GAP, h
end

local function UpdateBarPosition()
    if not barFrame then return end
    db = db or GetDB()
    barFrame:ClearAllPoints()
    barFrame:SetPoint("CENTER", UIParent, "CENTER", db.x or DEFAULTS.x, db.y or DEFAULTS.y)
end

local function UpdateBarSize()
    if not barFrame then return end
    db = db or GetDB()
    local w, h = db.width or DEFAULTS.width, db.height or DEFAULTS.height
    local fw, fh = ComputeFrameSize(w, h)
    barFrame:SetSize(fw, fh)
    if barFrame.iconBorder then barFrame.iconBorder:SetSize(h, h) end
    if barSpark then barSpark:SetSize(10, h * 2.2) end
end

local function CreateBarFrame()
    if barFrame then return end
    db = db or GetDB()
    local w, h = db.width or DEFAULTS.width, db.height or DEFAULTS.height
    local fw, fh = ComputeFrameSize(w, h)

    barFrame = CreateFrame("Frame", "MiliUI_FocusCastBar", UIParent)
    barFrame:SetSize(fw, fh)
    barFrame:SetPoint("CENTER", UIParent, "CENTER", db.x or DEFAULTS.x, db.y or DEFAULTS.y)
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetFrameLevel(10)
    barFrame:SetMovable(true)
    barFrame:SetUserPlaced(false)
    barFrame:SetClampedToScreen(true)
    barFrame:Hide()

    -- 圖示 + 1px 邊框
    local iconBorder = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    iconBorder:SetSize(h, h)
    iconBorder:SetPoint("TOPLEFT", barFrame, "TOPLEFT", 0, 0)
    iconBorder:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    iconBorder:SetBackdropColor(0, 0, 0, 1)
    iconBorder:SetBackdropBorderColor(0, 0, 0, 1)
    barIcon = iconBorder:CreateTexture(nil, "ARTWORK")
    barIcon:SetPoint("TOPLEFT",     iconBorder, "TOPLEFT",      1, -1)
    barIcon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -1,  1)
    barIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    barFrame.iconBorder = iconBorder

    -- 條容器 + 1px 邊框
    local barBorder = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    barBorder:SetPoint("TOPLEFT",     iconBorder, "TOPRIGHT",    GAP, 0)
    barBorder:SetPoint("BOTTOMRIGHT", barFrame,   "BOTTOMRIGHT", 0,   0)
    barBorder:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    barBorder:SetBackdropColor(0, 0, 0, 0.5)
    barBorder:SetBackdropBorderColor(0, 0, 0, 1)
    barFrame.barBorder = barBorder

    barStatusBar = CreateFrame("StatusBar", nil, barBorder)
    barStatusBar:SetPoint("TOPLEFT",     barBorder, "TOPLEFT",      1, -1)
    barStatusBar:SetPoint("BOTTOMRIGHT", barBorder, "BOTTOMRIGHT", -1,  1)
    barStatusBar:SetStatusBarTexture(barTexture)
    barStatusBar:SetMinMaxValues(0, 1)
    barStatusBar:SetValue(1)

    barSpark = barStatusBar:CreateTexture(nil, "OVERLAY")
    barSpark:SetSize(10, h * 2.2)
    barSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    barSpark:SetBlendMode("ADD")
    barSpark:SetPoint("CENTER", barStatusBar:GetStatusBarTexture(), "RIGHT", 0, 0)

    -- 文字疊層
    local overlay = CreateFrame("Frame", nil, barBorder)
    overlay:SetAllPoints(barBorder)
    overlay:SetFrameLevel(barBorder:GetFrameLevel() + 5)

    timeText = overlay:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(LOCALE_FONT, 14, "OUTLINE")
    timeText:SetPoint("RIGHT", barBorder, "RIGHT", -5, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(1, 1, 1)

    nameText = overlay:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(LOCALE_FONT, 14, "OUTLINE")
    nameText:SetPoint("LEFT", barBorder, "LEFT", 5, 0)
    nameText:SetPoint("RIGHT", timeText, "LEFT", -4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetTextColor(1, 1, 1)

    -- 拖曳（編輯模式）
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", function(self)
        if self.unlocked then self:StartMoving() end
    end)
    barFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        local cx, cy = UIParent:GetCenter()
        local fx, fy = self:GetCenter()
        db = db or GetDB()
        db.x = math.floor(fx - cx + 0.5)
        db.y = math.floor(fy - cy + 0.5)
    end)

    -- 編輯模式選取框
    local editSelection = CreateFrame("Frame", nil, barFrame, "EditModeSystemSelectionTemplate")
    editSelection:SetAllPoints()
    editSelection:Hide()
    editSelection:RegisterForDrag("LeftButton")
    editSelection:SetScript("OnDragStart", function() barFrame:StartMoving() end)
    editSelection:SetScript("OnDragStop", function()
        barFrame:StopMovingOrSizing()
        barFrame:SetUserPlaced(false)
        local cx, cy = UIParent:GetCenter()
        local fx, fy = barFrame:GetCenter()
        db = db or GetDB()
        db.x = math.floor(fx - cx + 0.5)
        db.y = math.floor(fy - cy + 0.5)
    end)
    editSelection.system = {
        GetSystemName = function() return "焦點目標施法" end,
    }
    barFrame.editSelection = editSelection
    -- OnUpdate 不在此掛：一般模式施法時才掛 LegacyOnUpdate；秘密模式改用 displayTicker。
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
        barFrame:SetScript("OnUpdate", nil)   -- 卸掉一般模式的每幀回呼
        if not isInEditMode then barFrame:Hide() end
    end
end

----------------------------------------------------------------------
-- 施法被打斷：凍結滿條變紅 + 顯示斷法者名字（職業色），停留後消失
-- 抄 Platynator：CastBarMixin:ApplyInterrupt（SetMinMax+SetValue 可蓋掉
-- SetTimerDuration）與 CastInterrupterTextMixin:UpdateFromGUID（GUID→名字/職業色）
----------------------------------------------------------------------
local function ShowInterrupted(interrupterGUID)
    if not active then return end             -- 沒在顯示這條施法就不處理
    active = false                            -- 停止進度更新，但條保留顯示
    StopDisplayTicker()
    barFrame:SetScript("OnUpdate", nil)

    barStatusBar:SetMinMaxValues(0, 1)
    barStatusBar:SetValue(1)
    barStatusBar:SetStatusBarColor(INTERRUPTED_COLOR[1], INTERRUPTED_COLOR[2], INTERRUPTED_COLOR[3])
    nameText:SetText("已打斷")
    timeText:SetText("")

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
            local r, g, b = 1, 1, 1
            if class ~= nil then
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

-- 開始顯示焦點施法條（不放音效）。castTbl/chanTbl 可由呼叫端預讀後傳入，避免重複讀取。
local function StartDisplay(castTbl, chanTbl)
    db = db or GetDB()
    if not db.monitor then return end

    -- 用 == nil 偵測（秘密安全）；用「明文 isCast」旗標挑欄位，避免對秘密值分支
    castTbl = castTbl or { UnitCastingInfo("focus") }
    chanTbl = chanTbl or { UnitChannelInfo("focus") }
    local isCast    = castTbl[1] ~= nil
    local isChannel = (not isCast) and (chanTbl[1] ~= nil)
    if not (isCast or isChannel) then HideBar(); return end

    -- 依明文旗標選欄位（值本身可能是秘密，但這裡只是賦值，不分支）
    local name, texture, notInt, s4, s5, isEmpowered
    if isCast then
        name, texture, notInt = castTbl[1], castTbl[3], castTbl[8]
        s4, s5 = castTbl[4], castTbl[5]
        isEmpowered = false
    else
        name, texture, notInt = chanTbl[1], chanTbl[3], chanTbl[7]
        s4, s5 = chanTbl[4], chanTbl[5]
        isEmpowered = chanTbl[9] and true or false     -- isEmpowered 為法術屬性，非秘密
    end

    CreateBarFrame()
    displayToken         = displayToken + 1   -- 新施法：讓打斷停留計時器失效
    castChannel          = isChannel
    castNotInterruptible = notInt
    colorAccum           = 1        -- 強制首幀更新文字
    barIcon:SetTexture(texture)     -- 施法中必有圖示；勿用 texture or X（會對秘密值做真值判斷 → taint）
    nameText:SetText(name)
    timeText:SetTextColor(1, 1, 1)  -- 打斷顯示會把右側文字染職業色，這裡還原
    -- 位置/大小只在建立與設定變更時套用，不在每次施法重算（見 UpdateBarPosition/Size 呼叫點）

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
                if total ~= nil and not issecretvalue(total) then
                    castTotal = total
                end
            end
            barStatusBar:SetMinMaxValues(0, 1)
            barStatusBar:SetTimerDuration(dur, nil, TimerDir(isChannel, isEmpowered))
        else
            castTotal = 0                 -- 拿不到 duration：滿條、不顯示數字，靠事件收條
            barStatusBar:SetMinMaxValues(0, 1)
            barStatusBar:SetValue(1)
        end
        active = true
        ApplySecretColor()                -- 立即上色
        StartDisplayTicker()              -- 10Hz：時間文字 + 顏色（斷法冷卻變化）
        barFrame:Show()
        return
    end

    -- 一般模式：可直接讀起訖時間（秒）並在 Lua 判斷狀態
    castSecret = false
    StopDisplayTicker()
    castStart = (s4 or 0) / 1000
    castEnd   = (s5 or 0) / 1000
    local c = ColorForState(ComputeState(notInt))
    barStatusBar:SetStatusBarColor(c[1], c[2], c[3])
    barStatusBar:SetValue(isChannel and 1 or 0)
    active = true
    barFrame:SetScript("OnUpdate", LegacyOnUpdate)   -- 施法期間才掛每幀回呼
    barFrame:Show()
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
            barStatusBar:SetTimerDuration(dur, nil, TimerDir(isChannel, isEmpowered))
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

-- 焦點切換 / 重新整理：若焦點正在施法就顯示（不放音效）
local function RefreshFromFocus()
    db = db or GetDB()
    if not db.monitor then HideBar(); return end
    StartDisplay()   -- 內部自行判斷是否在施法，未施法會收條
end

----------------------------------------------------------------------
-- 編輯模式（三層 hook，抄 BloodlustMusic 做法）
----------------------------------------------------------------------
local function UpdateEditModeState()
    db = db or GetDB()
    CreateBarFrame()
    if isInEditMode and db.monitor then
        -- 進入編輯模式：停掉施法中的每幀回呼/ticker，顯示靜態範例
        active = false
        StopDisplayTicker()
        barFrame:SetScript("OnUpdate", nil)
        barFrame.unlocked = true
        barFrame:EnableMouse(true)
        barIcon:SetTexture(132329)                 -- 範例圖示（隨便一個法術）
        nameText:SetText("焦點目標施法")
        timeText:SetText("0.9/1.5")
        barStatusBar:SetMinMaxValues(0, 1)
        barStatusBar:SetValue(0.6)
        local c = ColorForState("ready")
        barStatusBar:SetStatusBarColor(c[1], c[2], c[3])
        barFrame.editSelection:ShowHighlighted()
        UpdateBarPosition()
        UpdateBarSize()
        barFrame:Show()
    else
        if not barFrame then return end
        barFrame.unlocked = false
        barFrame:EnableMouse(false)
        barFrame.editSelection:Hide()
        if not active then barFrame:Hide() end
    end
end

local editModeHooked = false
local function HookEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", function() isInEditMode = true;  UpdateEditModeState() end)
    EditModeManagerFrame:HookScript("OnHide", function() isInEditMode = false; UpdateEditModeState() end)
    if EditModeManagerFrame:IsShown() then isInEditMode = true; UpdateEditModeState() end
end

HookEditMode()  -- Tier 1
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)  -- Tier 2
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
-- 施法事件 payload：(unit, castGUID, spellID[, interrupterGUID])；EMPOWER_STOP 多一個
-- complete 參數，interrupterGUID 在第 5 位（參數位置抄 Platynator/Display/Cache.lua）
ev:SetScript("OnEvent", function(self, event, unit, arg2, arg3, arg4, arg5)
    if event == "PLAYER_LOGIN" then
        db = GetDB()
        RefreshInterruptSpells()
        CreateBarFrame()
        HookEditMode()  -- Tier 3

        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_FOCUS_CHANGED")
        self:RegisterUnitEvent("UNIT_SPELLCAST_START",          "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START",  "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START",  "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_STOP",           "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP",   "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP",   "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED",    "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED",         "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED",        "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "focus")
        self:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "focus")
        return

    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
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
        HandleSound(castTbl, chanTbl)           -- 音效（不受監控開關左右；秘密模式自動略過）
        StartDisplay(castTbl, chanTbl)

    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        ResyncTiming()                          -- 延遲/推條：只重設計時，不重讀圖示/名稱/位置

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

----------------------------------------------------------------------
-- 公開 API（給 Settings.lua 用）
----------------------------------------------------------------------
local COLOR_KEYS = { ready = "colorReady", cd = "colorCD", immune = "colorImmune" }
local SOUND_EN_KEYS = { ready = "soundReadyEnabled", cd = "soundCDEnabled", immune = "soundImmuneEnabled" }
local SOUND_KEYS = { ready = "soundReady", cd = "soundCD", immune = "soundImmune" }
local DEFAULT_COLOR = { ready = DEFAULTS.colorReady, cd = DEFAULTS.colorCD, immune = DEFAULTS.colorImmune }

function MiliUI_FocusCast.IsMonitorEnabled()
    return GetDB().monitor
end

function MiliUI_FocusCast.SetMonitorEnabled(v)
    local d = GetDB()
    d.monitor = v and true or false
    if not d.monitor then HideBar() end
    UpdateEditModeState()
    RefreshFromFocus()
end

function MiliUI_FocusCast.GetColor(which)
    local c = GetDB()[COLOR_KEYS[which]]
    return c[1], c[2], c[3]
end

function MiliUI_FocusCast.SetColor(which, r, g, b)
    GetDB()[COLOR_KEYS[which]] = { r, g, b }
end

function MiliUI_FocusCast.GetDefaultColor(which)
    local c = DEFAULT_COLOR[which]
    return c[1], c[2], c[3]
end

function MiliUI_FocusCast.GetSoundEnabled(which)
    return GetDB()[SOUND_EN_KEYS[which]]
end

function MiliUI_FocusCast.SetSoundEnabled(which, v)
    GetDB()[SOUND_EN_KEYS[which]] = v and true or false
end

function MiliUI_FocusCast.GetSound(which)
    return GetDB()[SOUND_KEYS[which]]
end

function MiliUI_FocusCast.SetSound(which, val)
    GetDB()[SOUND_KEYS[which]] = val
end

function MiliUI_FocusCast.PreviewSound(which)
    PlayAnySound(GetDB()[SOUND_KEYS[which]])
end

-- 給「複製斷法巨集」用：回傳玩家目前已學的第一個斷法法術名稱（無則 nil）
function MiliUI_FocusCast.GetInterruptSpellName()
    if #currentInterrupt == 0 then RefreshInterruptSpells() end
    local id = currentInterrupt[1]
    if id then return C_Spell.GetSpellName(id) end
    return nil
end
