------------------------------------------------------------
-- 傳奇鑰石計時面板
--
-- 鑰石開跑時清單摺起來（Visibility 的 mythicPlus 規則），原位放這一塊：
-- 計時（含 +2／+3）、鑰石等級與詞綴、死亡數與損失時間、首領清單與擊殺時間、
-- 敵軍條。版面是慣見的那一種（文字靠右、三段計時條、敵軍條在下），
-- 皮是套組的：純色、直角、1px 邊、跟標題列同一套字型。
--
-- 這一塊**完全不碰暴雪的追蹤器**：暴雪自己的 M+ 區塊住在共用 widget pool 的
-- 場景模組裡（Core/Tracker.lua 規矩 3），我們讀的是它同一組 API，畫的是自己的框。
-- 所以它跟版本的關係只有一件事：
--
-- ⚠ 每季要看一眼的東西（其餘 API 暴雪自己的 M+ 區塊也在用，壞了它也壞）：
--   * +2／+3 的門檻是「時限的 80%／60%」，暴雪只畫 +1，這兩個比例是社群知識；
--   * 「挑戰者的危機」（詞綴 152）把時限加 90 秒，但 +2／+3 要用扣掉那 90 秒的
--     時限去算再加回來 —— 賽季詞綴換了就對這兩段。
--
-- 刻意不做的：
--   * 當前拉怪的敵軍預估 —— 要靠戰鬥記錄配一份自己維護的怪物表，12.x 上那條路已經不準；
--   * 死亡名單 —— 12.1 的 GUID 常是秘密值，名單會缺；死亡數走官方 API 沒問題；
--   * 首領名字去翻 Encounter Journal —— 那要開／藏暴雪面板，會污染；criteria 的
--     description 本來就是名字；
--   * 分段紀錄；自動放鑰石（套組的 AutoSlotKeystone 已經在做）。
------------------------------------------------------------
local _, ns = ...

ns.MythicPlus = {}
local MP = ns.MythicPlus
local T = ns.Tracker
local P = ns.P
local L = ns.L
local IsSecret = ns.Secret.IsSecret

------------------------------------------------------------
-- 常數
------------------------------------------------------------
-- 每季要看的兩個數字（見檔頭）
local PLUS_FRACTIONS = { 1.0, 0.8, 0.6 }
local PERIL_AFFIX_ID  = 152
local PERIL_BONUS_SEC = 90

local PAD      = 8      -- 面板內縮
local GAP_V    = 2      -- 行距
local BAR_GAP  = 4      -- 三段計時條之間
local TEXT_INSET = 2    -- 條上文字離條緣

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- 顏色是使用者挑的（要一眼看得出誰是誰），貼圖一律純色
local C_TEXT      = { 1, 1, 1 }
local C_DIM       = { 0.694, 0.694, 0.694 }   -- B1B1B1：鑰石詞綴
local C_BAR       = { 0.592, 0.592, 0.592 }   -- 979797：計時條
local C_FORCES    = { 0.733, 0.620, 0.133 }   -- BB9E22：敵軍條
local C_DONE      = { 0, 1, 0.141 }           -- 00FF24：完成
local C_EXPIRED   = { 1, 0.165, 0.180 }       -- FF2A2E：超時
local C_SUCCESS   = { 1, 0.827, 0.220 }       -- FFD338：限時內完成
local BAR_BG_ALPHA = 0.5

local function Cfg() return ns.db and ns.db.mythicPlus end

local function Font()
    local a = ns.db and ns.db.appearance
    return (a and ns.Media.OptionalFont(a.font)) or ns.Media.DEFAULT_FONT
end

local function Outline()
    local a = ns.db and ns.db.appearance
    return (a and a.outline) and "OUTLINE" or ""
end

local function Hex(c)
    return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

local function FormatTime(sec)
    sec = math.max(0, math.floor(sec + 0.0001))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

local function FormatMs(ms)
    local m = math.floor(ms / 60000)
    local s = math.floor(ms / 1000 - m * 60)
    local rest = math.floor(ms - m * 60000 - s * 1000)
    return ("%d:%02d.%03d"):format(m, s, rest)
end

-- 秘密值一律當「拿不到」：這裡的每個數字都會拿去做算術
local function Num(v)
    if v == nil or IsSecret(v) then return nil end
    return tonumber(v)
end

local function Bool(v)
    if v == nil or IsSecret(v) then return nil end
    return v and true or false
end

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
local state
local function ResetState()
    state = {
        inChallenge = false,
        completed = false,
        completedOnTime = nil,
        completionMs = nil,
        timerStarted = false,
        timer = 0,
        timeLimit = 0,
        timeLimits = { 0, 0, 0 },
        hasPeril = false,
        level = 0,
        affixes = {},
        deaths = 0,
        timeLost = 0,
        forcesCurrent = 0,        -- number 或 nil（秘密）
        forcesTotal = 0,
        forcesText = nil,         -- 暴雪給的字串，可能是秘密，只拿去 SetText
        forcesDone = false,
        forcesDoneTime = nil,
        objectives = {},          -- { name, done, time }
    }
end
ResetState()

function MP.IsInChallenge()
    return state.inChallenge
end

------------------------------------------------------------
-- 框
------------------------------------------------------------
local panel
local timerBars = {}   -- [1]=+1 [2]=+2 [3]=+3
local forcesBar
local objectiveTexts = {}
local MAX_OBJECTIVES = 10

local function NewText(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Font(), size, Outline())   -- 建立當下就要有字型，SetText 才不會炸
    fs:SetTextColor(color[1], color[2], color[3], 1)
    fs:SetJustifyH(justify or "RIGHT")
    fs:SetNonSpaceWrap(false)
    fs:SetWordWrap(false)
    return fs
end

-- 純色條：黑底 + 1px 黑邊 + 內縮 1px 的填充
local function NewBar(parent, fillColor)
    local f = CreateFrame("Frame", nil, parent)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(WHITE)
    f.bg:SetVertexColor(0, 0, 0, BAR_BG_ALPHA)

    f.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = f:CreateTexture(nil, "BORDER")
        e:SetTexture(WHITE)
        e:SetVertexColor(0, 0, 0, 1)
        f.edges[side] = e
    end

    f.fill = CreateFrame("StatusBar", nil, f)
    f.fill:SetStatusBarTexture(WHITE)
    f.fill:SetStatusBarColor(fillColor[1], fillColor[2], fillColor[3], 1)
    f.fill:SetMinMaxValues(0, 1)
    f.fill:SetValue(0)
    f.fill:SetFrameLevel(f:GetFrameLevel() + 1)

    f.text = NewText(f, 16, C_TEXT, "RIGHT")
    return f
end

local function LayoutBarEdges(f)
    local px = P.GetPixelPerfectScale() / ((f:GetEffectiveScale() > 0) and f:GetEffectiveScale() or 1)
    local e = f.edges
    e.TOP:ClearAllPoints();    e.TOP:SetPoint("TOPLEFT");       e.TOP:SetPoint("TOPRIGHT");       e.TOP:SetHeight(px)
    e.BOTTOM:ClearAllPoints(); e.BOTTOM:SetPoint("BOTTOMLEFT"); e.BOTTOM:SetPoint("BOTTOMRIGHT"); e.BOTTOM:SetHeight(px)
    e.LEFT:ClearAllPoints();   e.LEFT:SetPoint("TOPLEFT");      e.LEFT:SetPoint("BOTTOMLEFT");    e.LEFT:SetWidth(px)
    e.RIGHT:ClearAllPoints();  e.RIGHT:SetPoint("TOPRIGHT");    e.RIGHT:SetPoint("BOTTOMRIGHT");  e.RIGHT:SetWidth(px)
    f.fill:ClearAllPoints()
    f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", px, -px)
    f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -px, px)
end

local function EnsurePanel()
    if panel then return panel end
    local bar = ns.Chrome.GetBar and ns.Chrome.GetBar()
    if not bar then return nil end

    panel = CreateFrame("Frame", "MiliUIQuestTrackerMythicPlus", UIParent)
    panel:SetFrameStrata(bar:GetFrameStrata() or "MEDIUM")
    panel:SetFrameLevel(bar:GetFrameLevel())
    panel:SetPoint("TOPLEFT",  bar, "BOTTOMLEFT",  0, 0)
    panel:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    panel:SetHeight(10)
    panel:Hide()

    panel.deaths  = NewText(panel, 16, C_TEXT)
    panel.timer   = NewText(panel, 34, C_TEXT)
    panel.key     = NewText(panel, 20, C_DIM)
    panel.affixes = NewText(panel, 16, C_DIM)

    for i = 1, 3 do timerBars[i] = NewBar(panel, C_BAR) end
    forcesBar = NewBar(panel, C_FORCES)

    for i = 1, MAX_OBJECTIVES do
        objectiveTexts[i] = NewText(panel, 18, C_TEXT)
    end

    -- 面板寬度跟著標題列，標題列跟著追蹤器：寬一變就重排（三段條是按比例切的）。
    -- ⚠ 只看寬：Layout 自己會 SetHeight，看高就會在 OnSizeChanged 裡自己叫自己
    local lastW
    panel:SetScript("OnSizeChanged", function(self, w)
        if w == lastW then return end
        lastW = w
        if self:IsShown() then MP.Layout() end
    end)

    return panel
end

------------------------------------------------------------
-- 排版：只在顯示、設定變更、寬度變更時跑
------------------------------------------------------------
local function BarFractions()
    -- 三段各自代表的時間跨度佔總時限的比例；沒有危機就是固定的 0.2／0.2／0.6
    if not state.hasPeril or state.timeLimit <= 0 then
        return 0.2, 0.2, 0.6
    end
    local f = {}
    for i = 1, 3 do
        local span = (state.timeLimits[i] or 0) - (state.timeLimits[i + 1] or 0)
        f[i] = span / state.timeLimit
    end
    return f[1], f[2], f[3]
end

function MP.Layout()
    if not panel then return end
    local c = Cfg()
    if not c then return end
    local font, outline = Font(), Outline()
    local W = panel:GetWidth()
    if not W or W <= 0 then return end
    local inner = W - PAD * 2

    local function SetFont(fs, size) fs:SetFont(font, size, outline) end

    local y = PAD

    -- 死亡
    SetFont(panel.deaths, c.textSize)
    panel.deaths:ClearAllPoints()
    panel.deaths:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y)
    panel.deaths:SetWidth(inner)
    y = y + c.textSize + GAP_V

    -- 計時
    SetFont(panel.timer, c.timerSize)
    panel.timer:ClearAllPoints()
    panel.timer:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y)
    panel.timer:SetWidth(inner)
    y = y + c.timerSize + GAP_V

    -- 鑰石：詞綴靠右，等級貼在它左邊
    SetFont(panel.affixes, c.textSize)
    SetFont(panel.key, c.keySize)
    panel.affixes:ClearAllPoints()
    panel.affixes:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y - math.max(0, (c.keySize - c.textSize) / 2))
    -- 等級貼在詞綴左邊、垂直置中對齊它：等級寬度依內容變，所以用錨點串起來
    panel.key:ClearAllPoints()
    panel.key:SetPoint("RIGHT", panel.affixes, "LEFT", -4, 0)
    y = y + math.max(c.keySize, c.textSize) + GAP_V + 4

    -- 三段計時條：+3 在最左（最寬）、+1 在最右。文字坐在條的上緣右側
    local f1, f2, f3 = BarFractions()
    local usable = inner - BAR_GAP * 2
    local w3, w2 = math.floor(usable * f3), math.floor(usable * f2)
    local w1 = usable - w3 - w2
    local textH = c.textSize
    local barTop = y + textH + TEXT_INSET
    local xs = { [3] = 0, [2] = w3 + BAR_GAP, [1] = w3 + BAR_GAP + w2 + BAR_GAP }
    local ws = { [1] = w1, [2] = w2, [3] = w3 }
    for i = 1, 3 do
        local b = timerBars[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + xs[i], -barTop)
        b:SetSize(math.max(1, ws[i]), c.barHeight)
        LayoutBarEdges(b)
        SetFont(b.text, textH)
        b.text:ClearAllPoints()
        b.text:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", -TEXT_INSET, 1)
    end
    y = barTop + c.barHeight + BAR_GAP

    -- 敵軍條：整寬，百分比掛在條的下緣右側
    forcesBar:ClearAllPoints()
    forcesBar:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD, -y)
    forcesBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y)
    forcesBar:SetHeight(c.barHeight)
    LayoutBarEdges(forcesBar)
    SetFont(forcesBar.text, textH)
    forcesBar.text:ClearAllPoints()
    forcesBar.text:SetPoint("TOPRIGHT", forcesBar, "BOTTOMRIGHT", -TEXT_INSET, -1)
    y = y + c.barHeight + TEXT_INSET + textH + GAP_V + 4

    -- 首領
    for i = 1, MAX_OBJECTIVES do
        local fs = objectiveTexts[i]
        SetFont(fs, c.objectiveSize)
        fs:ClearAllPoints()
        fs:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y)
        fs:SetWidth(inner)
        if state.objectives[i] then
            fs:Show()
            y = y + c.objectiveSize + GAP_V
        else
            fs:Hide()
        end
    end

    panel:SetHeight(y + PAD)
end

------------------------------------------------------------
-- 渲染：每一段各自從 state 畫
------------------------------------------------------------
local function RenderDeaths()
    if not panel then return end
    if state.deaths <= 0 then
        panel.deaths:SetText(" ")
        return
    end
    local s = (L["%d deaths"]):format(state.deaths)
    if state.timeLost > 0 then
        s = s .. (" (+%s)"):format(state.timeLost < 60 and (state.timeLost .. "s") or FormatTime(state.timeLost))
    end
    panel.deaths:SetText(s)
end

local function RenderKey()
    if not panel then return end
    panel.key:SetText(state.level > 0 and ("[%d]"):format(state.level) or "")
    panel.affixes:SetText(table.concat(state.affixes, " - "))
end

local function RenderTimer()
    if not panel then return end
    local limit = state.timeLimit
    local text
    if state.completed and state.completionMs then
        local col = state.completedOnTime and C_SUCCESS or C_EXPIRED
        text = Hex(col) .. FormatMs(state.completionMs) .. " / " .. FormatTime(limit) .. "|r"
    else
        text = FormatTime(state.timer) .. " / " .. FormatTime(limit)
    end
    panel.timer:SetText(text)

    for i = 1, 3 do
        local b = timerBars[i]
        local barLimit = state.timeLimits[i] or 0
        local remaining = barLimit - state.timer
        local span = barLimit - (state.timeLimits[i + 1] or 0)
        local elapsed = span - remaining
        local value = (span > 0) and math.min(1, math.max(0, elapsed / span)) or 0
        b.fill:SetValue(value)

        local t = FormatTime(math.abs(remaining))
        if not state.completed then
            if remaining < 0 then
                t = (i == 1) and (Hex(C_EXPIRED) .. "-" .. t .. "|r") or ""
            end
        else
            if remaining <= 0 then
                t = Hex(C_EXPIRED) .. "-" .. t .. "|r"
            else
                t = Hex(C_SUCCESS) .. t .. "|r"
            end
        end
        b.text:SetText(t)
    end
end

local function RenderForces()
    if not panel then return end
    local cur, total = state.forcesCurrent, state.forcesTotal
    if cur and total and total > 0 then
        local pct = math.min(1, cur / total)
        forcesBar.fill:SetMinMaxValues(0, 1)
        forcesBar.fill:SetValue(pct)
        local s = ("%.2f%%"):format(pct * 100)
        if state.forcesDone then
            s = Hex(C_DONE) .. s
            if state.forcesDoneTime then s = s .. " " .. FormatTime(state.forcesDoneTime) end
            s = s .. "|r"
        end
        forcesBar.text:SetText(s)
    elseif state.forcesText ~= nil then
        -- 秘密值：算不了百分比，把暴雪給的字串原樣交給文字框，條留空
        forcesBar.fill:SetValue(0)
        forcesBar.text:SetText(state.forcesText)
    else
        forcesBar.fill:SetValue(0)
        forcesBar.text:SetText("")
    end
end

local function RenderObjectives()
    if not panel then return end
    for i = 1, MAX_OBJECTIVES do
        local o = state.objectives[i]
        local fs = objectiveTexts[i]
        if not o then
            fs:SetText("")
        elseif o.done then
            local s = Hex(C_DONE) .. o.name
            if o.time then s = s .. " " .. FormatTime(o.time) end
            fs:SetText(s .. "|r")
        else
            fs:SetText(o.name)
        end
    end
end

local function RenderAll()
    if not panel then return end
    RenderDeaths(); RenderKey(); RenderTimer(); RenderForces(); RenderObjectives()
end

------------------------------------------------------------
-- 讀資料
------------------------------------------------------------
local function ElapsedNow()
    local _, elapsed = GetWorldElapsedTime(1)
    return Num(elapsed) or 0
end

local function LoadKeyDetails()
    local mapId = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapId then return end
    local level, affixIDs = C_ChallengeMode.GetActiveKeystoneInfo()
    level = Num(level)
    if not level or level <= 0 then return end

    state.level = level
    state.affixes = {}
    state.hasPeril = false
    for i, id in ipairs(affixIDs or {}) do
        local name = C_ChallengeMode.GetAffixInfo(id)
        if type(name) == "string" and not IsSecret(name) then
            state.affixes[#state.affixes + 1] = name
        end
        if id == PERIL_AFFIX_ID then state.hasPeril = true end
    end

    local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapId)
    timeLimit = Num(timeLimit) or 0
    state.timeLimit = timeLimit
    if state.hasPeril then
        local base = timeLimit - PERIL_BONUS_SEC
        state.timeLimits = { timeLimit, base * PLUS_FRACTIONS[2] + PERIL_BONUS_SEC, base * PLUS_FRACTIONS[3] + PERIL_BONUS_SEC }
    else
        state.timeLimits = { timeLimit, timeLimit * PLUS_FRACTIONS[2], timeLimit * PLUS_FRACTIONS[3] }
    end
end

local function LoadDeaths()
    local count, lost = C_ChallengeMode.GetDeathCount()
    state.deaths = Num(count) or 0
    state.timeLost = Num(lost) or 0
end

local function UpdateObjectives()
    local _, _, stepCount = C_Scenario.GetStepInfo()
    stepCount = Num(stepCount)
    if not stepCount or stepCount <= 0 then return end

    local structureChanged = false
    local n = 0
    for i = 1, MAX_OBJECTIVES do
        if i > stepCount then
            if state.objectives[i] then structureChanged = true end
            state.objectives[i] = nil
        else
            local info = C_ScenarioInfo.GetCriteriaInfo(i)
            if not info then
                if state.objectives[i] then structureChanged = true end
                state.objectives[i] = nil
            elseif Bool(info.isWeightedProgress) then
                -- 敵軍
                if state.objectives[i] then structureChanged = true end
                state.objectives[i] = nil
                local total = Num(info.totalQuantity)
                local cur = Num(info.quantity)
                if cur == nil and type(info.quantityString) == "string" and not IsSecret(info.quantityString) then
                    cur = tonumber(info.quantityString:match("%d+"))
                end
                state.forcesText = info.quantityString
                if total then state.forcesTotal = total end
                -- 只准往上：結束前 API 會短暫回 0
                if cur and (cur >= (state.forcesCurrent or 0)) then state.forcesCurrent = cur end
                if cur and total and total > 0 and cur >= total and not state.forcesDone then
                    state.forcesDone = true
                    state.forcesDoneTime = ElapsedNow() - (Num(info.elapsed) or 0)
                end
            else
                local name = info.description
                if type(name) ~= "string" or IsSecret(name) then name = "?" end
                local o = state.objectives[i]
                if not o or o.name ~= name then
                    o = { name = name, done = false, time = nil }
                    state.objectives[i] = o
                    structureChanged = true
                end
                if not o.done and Bool(info.completed) then
                    o.done = true
                    o.time = ElapsedNow() - (Num(info.elapsed) or 0)
                end
            end
            n = n + 1
        end
    end

    if structureChanged then MP.Layout() end
    RenderForces()
    RenderObjectives()
end

------------------------------------------------------------
-- 計時迴圈：只在面板顯示時跑，每 0.1 秒讀一次
------------------------------------------------------------
local acc = 0
local function OnTick(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    if state.completed then return end
    state.timer = ElapsedNow()
    if state.timer > 0 and not state.timerStarted then
        state.timerStarted = true
    end
    RenderTimer()
end

------------------------------------------------------------
-- 顯示與隱藏：清單摺起來、鑰石進行中、選項開著，三個都成立才顯示
------------------------------------------------------------
function MP.UpdateVisibility()
    local c = Cfg()
    local want = c and c.enabled and state.inChallenge and T.IsHidden()
    if want then
        if not EnsurePanel() then return end
        if not panel:IsShown() then
            panel:Show()
            panel:SetScript("OnUpdate", OnTick)
            MP.Layout()
            RenderAll()
        end
    elseif panel and panel:IsShown() then
        panel:SetScript("OnUpdate", nil)
        panel:Hide()
    end
end

------------------------------------------------------------
-- 鑰石開始／結束
------------------------------------------------------------
local challengeEvents = {
    "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_DEATH_COUNT_UPDATED", "WORLD_STATE_TIMER_START",
    "SCENARIO_CRITERIA_UPDATE", "SCENARIO_POI_UPDATE",
}
local evt

local function Enable()
    ResetState()
    state.inChallenge = true
    for _, e in ipairs(challengeEvents) do evt:RegisterEvent(e) end
    LoadKeyDetails()
    LoadDeaths()
    UpdateObjectives()
    state.timer = ElapsedNow()
    if ns.Visibility then ns.Visibility.Evaluate() end
    MP.UpdateVisibility()
    MP.Layout()
    RenderAll()
end

local function Disable()
    if not state.inChallenge then return end
    for _, e in ipairs(challengeEvents) do evt:UnregisterEvent(e) end
    ResetState()
    MP.UpdateVisibility()
    if ns.Visibility then ns.Visibility.Evaluate() end
end

local function Complete()
    state.completed = true
    local info = C_ChallengeMode.GetChallengeCompletionInfo()
    if type(info) == "table" then
        state.completionMs = Num(info.time)
        state.completedOnTime = Bool(info.onTime)
    end
    -- 最後一個目標把鑰石打完時可能收不到它的完成時間，用計時器補
    for _, o in pairs(state.objectives) do
        if not o.done then o.done = true; o.time = state.timer end
    end
    if not state.forcesDone then
        state.forcesDone = true
        state.forcesCurrent = state.forcesTotal
        state.forcesDoneTime = state.timer
    end
    RenderAll()
end

-- 難度 8 = 傳奇鑰石。IsChallengeModeActive 在打完之後就回 false，
-- 但面板要留到離開副本，所以改用副本資訊判斷
local function Check()
    local _, itype, difficulty = GetInstanceInfo()
    local now = (difficulty == 8 and itype == "party") and true or false
    if now == state.inChallenge then return end
    if now then Enable() else Disable() end
end

------------------------------------------------------------
-- 滑鼠提示：目標怪的敵軍數（官方 API，不需要 MDT）
------------------------------------------------------------
local function TooltipCount(tt)
    if tt ~= GameTooltip then return end
    local c = Cfg()
    if not (c and c.enabled and c.tooltipCount and state.inChallenge) then return end
    if not (C_ScenarioInfo and C_ScenarioInfo.GetUnitCriteriaProgressValues) then return end
    local count, _, percent = C_ScenarioInfo.GetUnitCriteriaProgressValues("mouseover")
    if count == nil then return end
    local nc, np = Num(count), Num(percent)
    if nc and np then
        GameTooltip:AddDoubleLine(L["Enemy forces"], ("+%d (%.2f%%)"):format(nc, np), 1, 1, 1, 1, 1, 1)
    else
        -- 秘密值只能原樣交給文字框
        GameTooltip:AddDoubleLine(L["Enemy forces"], percent or count, 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
ns.RegisterCallback("Init", "mythicPlus", function()
    evt = CreateFrame("Frame")
    for _, e in ipairs({
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
        "PLAYER_DIFFICULTY_CHANGED", "CHALLENGE_MODE_START",
    }) do
        evt:RegisterEvent(e)
    end
    evt:SetScript("OnEvent", function(_, event)
        if event == "CHALLENGE_MODE_START" then
            -- 放鑰石後的 10 秒倒數就會收到；重新開始也走這裡
            Enable()
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            Complete()
        elseif event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED" then
            LoadDeaths(); RenderDeaths()
        elseif event == "WORLD_STATE_TIMER_START" then
            state.timerStarted = true
            RenderTimer()
        elseif event == "SCENARIO_CRITERIA_UPDATE" or event == "SCENARIO_POI_UPDATE" then
            UpdateObjectives()
        else
            Check()
        end
    end)

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, TooltipCount)
    end

    Check()
end)

-- 清單摺起來／展開、設定變更：面板跟著進退
ns.RegisterCallback("TrackerHiddenChanged", "mythicPlus", function() MP.UpdateVisibility() end)
ns.RegisterCallback("Apply", "mythicPlus", function()
    MP.UpdateVisibility()
    if panel and panel:IsShown() then MP.Layout(); RenderAll() end
end)
