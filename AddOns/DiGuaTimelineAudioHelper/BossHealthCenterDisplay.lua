-- BossHealthCenterDisplay.lua —— 首领转阶段血量百分比
-- 按 JOBS[encounterID] 监测指定单位：血量命中区间时，屏幕中央大字显示其血量百分比。
-- 写法（区间均为 [lo, hi) 含低不含高）：
--   below = 80                              → 血量 <80% 时显示
--   min = 20, max = 25                      → 血量在 20%~25% 之间才显示
--   phaseCount = true（配合 min）           → 转阶段倒计时：数字=血量%-min（66%→0 … 75%→9），窗口默认放宽10%
--   count = 5（配合 phaseCount，可选）      → 自定义倒计时点数：窗口改为 [min, min+count)，数字 0…count-1（如 [66,71)→66%→0 … 70%→4）
--   ranges = { {66,71}, {33,38} }           → 多条区间，命中任一即显示
--   units = { {unit=..,..}, {unit=..,..} }  → 一场盯多个单位，谁命中区间谁显示
-- 12.x secret 安全：读取与区间判断全部交给 CurveObject 曲线（addon 不碰 secret 算术/比较）。
-- 可移动半透明框：控制台(/digua)打开且本开关开启时，可拖动框体并保存坐标（参照其它模块模式）。
local JOBS = {
    -- [3200] = { unit = "boss1", below = 80 }, -- 圣光猎手伊库兹：boss1 <80% 显示
    [3101] = { unit = "boss2", min = 20, max = 29 }, -- 密谋
    [2609] = { units = { -- 红玉1：转阶段 66% 与 33%，各自提前 5% 倒计时
        { unit = "boss1", min = 66, phaseCount = true, count = 5 }, -- 66%→0 … 70%→4（窗口 [66,71)）
        { unit = "boss1", min = 33, phaseCount = true, count = 5 }, -- 33%→0 … 37%→4（窗口 [33,38)）
    } },
    [2623] = { units = { -- 红玉3
        { unit = "boss1", min = 40, max = 46 },
    } },
    [2124] = { units = { -- 神庙1
        { unit = "boss1", min = 40, max = 46 },
        { unit = "boss2", min = 40, max = 46 },
    } },
    -- [3429] = { units = { -- 烈毒7
    --     { unit = "boss1", min = 0, max = 5 },
    --     { unit = "boss2", min = 0, max = 5 },
    -- } },
}

local addonName, addonTable = ...

local function Safe(fn, ...)
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

-- 功能开关（由控制台控制，默认关闭）
local function Enabled()
    return DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.bossHealthCenterEnabled == true
end

local function EncounterID()
    local id = addonTable.GetEncounterID and Safe(addonTable.GetEncounterID)
    return type(id) == "number" and id or 0
end

-- 归一化一个 encounter 的监测列表：
--   单配置 {unit=.., 区间} → 一张；units={...} 或纯数组 → 多张
local function WatchersOf(job)
    if job.units then return job.units end
    if job[1] then return job end
    return { job }
end

local onesCurve
local function OnesDigitCurve()
    if onesCurve then return onesCurve end

    local c = Safe(C_CurveUtil and C_CurveUtil.CreateCurve)
    if c and c.AddPoint then
        -- 让血量显示为 k%（如 22%）时个位映射到 k%10（即 2）。
        -- 边界比整数百分比略左移 0.0001%（k/100 - eps），吸收“22/100 在浮点里
        -- 略小于 0.22”的误差——否则 22% 会掉进 21 的段里显示成 1%。
        c:AddPoint(0.0, 0)
        for k = 1, 99 do
            c:AddPoint(k / 100 - 0.000001, k % 10)
        end
        c:AddPoint(1.0, 0)

        if Enum and Enum.LuaCurveType and c.SetType then
            c:SetType(Enum.LuaCurveType.Step)
        end

        onesCurve = c
    end

    return onesCurve
end

-- 转阶段倒计时曲线（按 base+count 缓存）：把整数百分比在 [base, base+count) 内映射成 0~(count-1)（值 = 血量% - base）
-- 例：base=66,count=10 → 66%→0 … 75%→9；base=66,count=5 → 66%→0 … 70%→4。
-- 边界同样左移 eps 防浮点抖动；区间外的值因被 VisibilityCurve 隐藏而无实际显示影响，随便给个 0 兜底即可
local phaseCurves = {}
local function PhaseCountdownCurve(base, count)
    base = tonumber(base)
    if not base then return nil end
    count = tonumber(count)
    if not count or count < 2 then count = 10 end
    count = math.min(count, 10) -- 最多 0~9（超过 10 需两位数字，无意义）
    local key = "base" .. base .. "_n" .. count
    if phaseCurves[key] then return phaseCurves[key] end

    local c = Safe(C_CurveUtil and C_CurveUtil.CreateCurve)
    if c and c.AddPoint then
        c:AddPoint(0.0, 0)
        for v = 1, count - 1 do
            c:AddPoint((base + v) / 100 - 0.000001, v)
        end
        c:AddPoint(1.0, 0)

        if Enum and Enum.LuaCurveType and c.SetType then
            c:SetType(Enum.LuaCurveType.Step)
        end

        phaseCurves[key] = c
    end
    return phaseCurves[key]
end

-- 多带通 Step 曲线（按区间表缓存）：血量分数 x 命中任一区间 [lo/100, hi/100) → 1(显示)，其余 → 0(隐藏)
-- 支持三种写法：below / min+max / ranges（多条，命中任一即显示）；自动排序合并重叠/相邻区间
local visCurves = {}
local function VisibilityCurve(job)
    -- 归一化为若干 [lo, hi)（百分比）
    local list = {}
    if job.phaseCount and job.min then
        -- phaseCount（转阶段倒计时）模式：由 min 作为 0 点，窗口 [min, min+count)；count 缺省 10
        list[#list + 1] = { lo = job.min, hi = job.min + (tonumber(job.count) or 10) }
    elseif job.ranges then
        for _, r in ipairs(job.ranges) do
            local lo, hi = r[1], r[2]
            if lo and hi and lo < hi then list[#list + 1] = { lo = lo, hi = hi } end
        end
    else
        local lo = job.min or 0
        local hi = job.max or job.below
        if lo and hi and lo < hi then list[#list + 1] = { lo = lo, hi = hi } end
    end
    if #list == 0 then return nil end

    -- 排序并合并重叠/相邻区间
    table.sort(list, function(a, b) return a.lo < b.lo end)
    local merged = {}
    for _, r in ipairs(list) do
        local last = merged[#merged]
        if last and r.lo <= last.hi then
            if r.hi > last.hi then last.hi = r.hi end
        else
            merged[#merged + 1] = { lo = r.lo, hi = r.hi }
        end
    end

    local parts = {}
    for _, r in ipairs(merged) do parts[#parts + 1] = r.lo .. "_" .. r.hi end
    local key = table.concat(parts, ";")

    if not visCurves[key] and C_CurveUtil and C_CurveUtil.CreateCurve then
        local c = C_CurveUtil.CreateCurve()
        if merged[1].lo == 0 then
            c:AddPoint(0.0, 1)
        else
            c:AddPoint(0.0, 0)
            c:AddPoint(merged[1].lo / 100, 1) -- ≥首个 lo% 进入显示带
        end
        for i, r in ipairs(merged) do
            c:AddPoint(r.hi / 100, 0) -- ≥hi% 离开显示带
            local next = merged[i + 1]
            if next then c:AddPoint(next.lo / 100, 1) end -- 命中下一区间
        end
        if Enum and Enum.LuaCurveType and c.SetType then c:SetType(Enum.LuaCurveType.Step) end
        visCurves[key] = c
    end
    return visCurves[key]
end

-- ===== UI：可移动宿主框（控制台打开+开关开时显示半透明底并允许拖动） =====
local HostFrame = CreateFrame("Frame", nil, UIParent)
HostFrame:SetSize(105, 65)
HostFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
HostFrame:SetClampedToScreen(true)
HostFrame:EnableMouse(false)
HostFrame:SetMovable(false)

HostFrame.bg = HostFrame:CreateTexture(nil, "BACKGROUND")
HostFrame.bg:SetAllPoints()
HostFrame.bg:SetColorTexture(0.95, 0.45, 0.45, 0.25) -- 淡红色半透明底（拖动/编辑时可见）
HostFrame.bg:Hide()

HostFrame.text = HostFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HostFrame.text:SetPoint("CENTER")
HostFrame.text:SetText("首領\n轉階段\n血量%")
HostFrame.text:SetTextColor(1, 1, 1, 0.95)
HostFrame.text:SetJustifyH("CENTER")
HostFrame.text:SetSpacing(2)
HostFrame.text:Hide()

-- 血量大字池（每个监测单位各一张，默认隐藏；同场多单位时各自显隐互不干扰）
-- 注意：勿 SetAllPoints 限定宽高，否则大数字会被省略成 ".."；锚宿主中心自动撑开即可
local Labels = {}
for _ = 1, 4 do
    local l = HostFrame:CreateFontString(nil, "OVERLAY")
    l:SetPoint("CENTER")
    l:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 40, "OUTLINE")
    l:SetTextColor(1, 1, 1, 1) -- 白色
    l:SetShadowOffset(2, -2)
    l:SetShadowColor(0, 0, 0, 0.85) -- 阴影
    l:SetJustifyH("CENTER")
    l:Hide()
    Labels[#Labels + 1] = l
end

-- “转阶段”小字池：每张大字配一张，贴在其正上方，跟随数字一起显隐
local Captions = {}
for i = 1, #Labels do
    local c = HostFrame:CreateFontString(nil, "OVERLAY")
    c:SetPoint("BOTTOM", Labels[i], "TOP", 0, 3)
    c:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 40, "OUTLINE")
    c:SetText("轉階段")
    c:SetTextColor(1, 0.82, 0, 1) -- 金色
    c:SetShadowOffset(1, -1)
    c:SetShadowColor(0, 0, 0, 0.85)
    c:SetJustifyH("CENTER")
    c:Hide()
    Captions[i] = c
end

local function HideLabels()
    for i = 1, #Labels do
        Labels[i]:Hide()
        if Captions[i] then Captions[i]:Hide() end
    end
end

-- 拖动：仅当控制台打开且开关开启（可移动）时生效
HostFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and self:IsMovable() then
        self:StartMoving()
        self.moving = true
    end
end)
HostFrame:SetScript("OnMouseUp", function(self)
    if not self.moving then return end
    self:StopMovingOrSizing()
    self.moving = false
    local _, _, _, x, y = self:GetPoint()
    DiGuaTimelineAudioHelper = DiGuaTimelineAudioHelper or {}
    DiGuaTimelineAudioHelper.bossHealthPctX, DiGuaTimelineAudioHelper.bossHealthPctY = x, y
    print(string.format("|cff00ff00[DiGua]|r 首領轉階段血量百分比新位置已保存 (X: %d, Y: %d)", x, y))
end)

-- 控制台打开 + 开关开启 → 显示半透明可拖动框；否则点击穿透
function addonTable.RefreshBossHealthPctAnchor(isConsoleShown)
    if not DiGuaTimelineAudioHelper then return end
    local edit = isConsoleShown and DiGuaTimelineAudioHelper.bossHealthCenterEnabled == true
    HostFrame.bg:SetShown(edit)
    HostFrame.text:SetShown(edit)
    HostFrame:EnableMouse(edit)
    HostFrame:SetMovable(edit)
    if edit then HideLabels() end -- 编辑态隐藏大字，避免盖住提示名
end

-- ============================================================
-- 首领战门控：只有进入 JOBS 对应的首领战才挂 OnUpdate 轮询，平时零开销
-- ============================================================
local active = false        -- 当前是否处于 JOBS 里的首领战
local curJobId = nil        -- 当前命中的 encounterID
local curWatchers = {}      -- 当前命中 encounter 的监测列表 [{unit=.., ..区间}]
local suppressUntil = 0     -- 联动屏蔽（光明灌注）：到此刻为止都不显示（GetTime 秒）
local elapsed = 0
local PollTick

local function DetachPolling()
    HostFrame:SetScript("OnUpdate", nil)
    HideLabels()
end

local function AttachPolling()
    if not active or not Enabled() then return end
    HostFrame:SetScript("OnUpdate", PollTick)
end

-- 进入 JOBS 首领战：记录其监测列表并激活轮询
local function StartJob(encounterID)
    local job = JOBS[encounterID]
    curJobId = job and encounterID or nil
    curWatchers = job and WatchersOf(job) or {}
    active = curJobId ~= nil and #curWatchers > 0
    suppressUntil = 0
    AttachPolling()
end

-- 事件门控：ENCOUNTER_START 命中 JOBS → 开轮询；ENCOUNTER_END → 停轮询并清屏
-- 2623 停显：直接在轮询里读 addonTable.Boss2623EngageCount（INSTANCE_ENCOUNTER_ENGAGE_UNIT.lua 维护）
local mon = CreateFrame("Frame")
mon:RegisterEvent("ENCOUNTER_START")
mon:RegisterEvent("ENCOUNTER_END")
mon:SetScript("OnEvent", function(_, event, encounterID)
    if event == "ENCOUNTER_START" then
        StartJob(encounterID)
    else -- ENCOUNTER_END
        active = false
        curJobId = nil
        curWatchers = {}
        suppressUntil = 0
        DetachPolling()
    end
end)

-- 战斗中轮询（≤0.1s/次）：显隐与文字全走客户端曲线，addon 不碰 secret 运算
PollTick = function(_, d)
    elapsed = elapsed + d
    if elapsed < 0.1 then return end
    elapsed = 0

    if not active or not Enabled() then
        HideLabels()
        return
    end
    -- 编辑态（可拖动）不画大字
    if HostFrame:IsMovable() then
        HideLabels()
        return
    end
    -- 联动屏蔽期（光明灌注生效后 5 秒）不显示
    if GetTime() < suppressUntil then
        HideLabels()
        return
    end
    -- 2623：Boss2623EngageCount ≥3（第 3 次 INSTANCE_ENCOUNTER_ENGAGE_UNIT）→ 本场停显
    if curJobId == 2623 and (addonTable.Boss2623EngageCount or 0) >= 3 then
        HideLabels()
        return
    end

    -- 每个监测单位各占一张大字：谁命中区间谁显示（单位不存在/无区间 → 隐藏）
    local watchers = curWatchers
    for i, w in ipairs(watchers) do
        local l = Labels[i]
        local cap = Captions[i]
        if not l then break end -- 超出大字池容量则忽略
        if not UnitExists(w.unit) then
            l:Hide()
            if cap then cap:Hide() end
        else
            -- 显隐：多带通 Step 曲线输出 alpha（命中任一区间 → 1 显示，否则 → 0 隐藏）
            local vc = VisibilityCurve(w)
            local a = vc and Safe(UnitHealthPercent, w.unit, true, vc)
            -- 文字曲线：默认映射个位（75% → 5%）；phaseCount 模式则映射 血量%-min（66%→0 … 75%→9）
            local digitCurve = (w.phaseCount and w.min and PhaseCountdownCurve(w.min, w.count)) or OnesDigitCurve()
            local d = digitCurve and Safe(UnitHealthPercent, w.unit, true, digitCurve)
            if not vc or a == nil or not digitCurve or d == nil then
                l:Hide()
                if cap then cap:Hide() end
            else
                -- 勿在此用 Lua 比较 secret；alpha 直接进授权通道 SetAlpha 决定显隐
                l:SetFormattedText("%d%%", d)
                l:SetAlpha(a)
                l:Show()
                if cap then
                    cap:SetAlpha(a)
                    cap:Show()
                end
            end
        end
    end
    -- 隐藏本次未用到的多余大字（连同其上方小字）
    for i = #watchers + 1, #Labels do
        Labels[i]:Hide()
        if Captions[i] then Captions[i]:Hide() end
    end
end

-- 联动入口（EncounterWarning.lua 光明灌注命中时调用）：屏蔽显示 N 秒
function addonTable.SuppressBossHealthDisplay(seconds)
    suppressUntil = GetTime() + (seconds or 5)
    HideLabels()
end

-- 开关（控制台勾选时调用；默认关闭）
function addonTable.SetBossHealthEnabled(enabled)
    DiGuaTimelineAudioHelper = DiGuaTimelineAudioHelper or {}
    DiGuaTimelineAudioHelper.bossHealthCenterEnabled = (enabled == true)
    if enabled then
        AttachPolling()
    else
        DetachPolling()
    end
    local shown = DiGuaTimelineMainFrame and DiGuaTimelineMainFrame:IsShown() or false
    addonTable.RefreshBossHealthPctAnchor(shown)
end

-- PLAYER_LOGIN：恢复保存位置并同步可拖动状态
local evt = CreateFrame("Frame")
evt:RegisterEvent("PLAYER_LOGIN")
evt:SetScript("OnEvent", function()
    local db = DiGuaTimelineAudioHelper
    if db and type(db.bossHealthPctX) == "number" and type(db.bossHealthPctY) == "number" then
        HostFrame:ClearAllPoints()
        HostFrame:SetPoint("CENTER", UIParent, "CENTER", db.bossHealthPctX, db.bossHealthPctY)
    end
    addonTable.RefreshBossHealthPctAnchor(DiGuaTimelineMainFrame and DiGuaTimelineMainFrame:IsShown() or false)
    -- 战斗中 /reload 兜底：若已处于 JOBS 首领战，恢复轮询
    if not active and Enabled() then
        local id = addonTable.GetEncounterID and Safe(addonTable.GetEncounterID) or 0
        if JOBS[id] then StartJob(id) end
    end
end)