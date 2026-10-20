-- TargetAbsorbBar.lua
-- 目标护盾条：只做一件事 —— 显示当前目标身上的吸收盾（数值 + 进度条）
--
-- 【核心写法】照抄 AbsorbTracker/modules/Display.lua 的 NS.UpdateAbsorbBar，只改一处参考值：
--     local absorb = UnitGetTotalAbsorbs(UNIT) or 0
--     bar:SetMinMaxValues(0, maxValue)              -- 条长参考值（见下面 VALUE_MAX，不是目标最大生命）
--     bar:SetValue(absorb)                          -- 原样透传
--     valueText:SetText(AbbreviateNumbers(absorb))  -- 数值交给 C 侧函数处理
--
-- ⚠️ 12.x 的 secret 值规矩（副本里 UnitGetTotalAbsorbs / UnitHealthMax 返回 secret 值，
--    API 文档 Blizzard_APIDocumentationGenerated/UnitDocumentation.lua 标了 SecretReturns = true）：
--      ✅ 可以【原样透传】给 C 侧 UI：StatusBar:SetMinMaxValues / SetValue，
--         以及 AbbreviateNumbers(v) 后交给 FontString:SetText(v)
--      ✅ tostring(v)、v .. "" 也不会报错（只是 secret 会继续"传染"下去）
--      ❌ 不能比较（v > 0）、不能四则运算（maxHealth * 2）、不能 tonumber(v)，
--         更不能进 table.concat（会直接抛 "invalid value (secret)"）
--    → 「这条要不要显示」不能在 Lua 里 if 判断护盾数值（比较 secret 会直接报错），
--      但可以交给客户端判断：bar:SetAlpha(absorb) —— 见 Paint() 里的说明。
--      「显示多少」也交给客户端自己算，插件侧不解释那个数字。
--
-- 【先探一下：这个值到底是不是 secret】把比较包在 pcall 里试一次就知道：
--   能比较 → 是普通数字（野外等不受限的地方）→ 全部走精确逻辑；
--   抛错   → 是 secret（副本里就是这种）→ 只能“透传 + 猜”。
--   代码里就是 CompareAbsorb()，两条路都支持。
--
-- 【条满是多少 = 100% 的那个点】两道门：
--   · MAX_MODE = "peak"（默认）：自动学 —— 护盾刚冒出来那一刻的数值就当满值。
-- 【文字 = 百分比】算不了 absorb / max（secret 不能做四则运算），所以读的是
--   StatusBar 填充 Texture 的【像素宽度】（控件尺寸，不是 secret 值本身）→ 宽度 / 满格宽度。
--   读不到就退回显示原始数值（pcall 接住，不会报错）。
-- 【总开关】控制台右栏「boss1 护盾条」勾选框（存档键 targetAbsorbBarEnabled，**默认关**）。
--   同一个开关管两件事，但两者出现的条件不一样：
--     · 【护盾条本体】勾选 → 就显示（有 boss1 时）；**与控制台开不开无关**，关掉控制台照样显示/刷新。
--     · 【可移动定位框】勾选 **且 控制台打开** 才出现；控制台一关就跟着隐藏（它只是拖位置用的）。
--   ⚠️ 只有显式 true 才算开（nil / false 都算关）—— 新装、老存档、未勾选，一律不显示。
-- 【可移动定位色框】勾着总开关 + 打开控制台才会出现，这时才能拖；
--   松手存档到 DiGuaTimelineAudioHelper.targetAbsorbX / targetAbsorbY。
--   · MAX_MODE = "fixed"：写死一个参考值 VALUE_MAX，条长只反映“这个盾多大”。

local addonName, addonTable = ...

local UNIT = "boss1"            -- 只监控 boss1（想改回当前目标就写 "target"，触发条件会自动跟着换）
local WIDTH, HEIGHT = 260, 32   -- 条的大小（加长加高）
local POS_X, POS_Y = 0, 223     -- 默认位置（相对屏幕中心的偏移）；拖过定位框后以存档为准

-- ═══ 条满（= 条的 100%）怎么定 ═══
--   "keystone"（默认）：★ 按大秘境层数缩放 —— 层数越高，分母越大
--   "peak"  ：自动学。护盾刚出现那一刻的数值就当成满值
--             （⚠️ 副本里学不到，见下面 UNIT_AURA 那段的说明）
--   "fixed" ：写死一个参考值 VALUE_MAX
local MAX_MODE = "keystone"

-- ── "keystone" 模式：分母 = 按层数缩放 ──
--   基准层 KEYSTONE_BASE_LEVEL 时，条满 = KEYSTONE_BASE_VALUE 吸收量；
--   每高一层分母 × (1 + KEYSTONE_STEP)，每低一层则反向缩小（指数式，不是线性）。
--   不是大秘境 / 读不到层数 → 直接用基准值。
--   ★ 以后只要改 KEYSTONE_BASE_VALUE：把它设成“你在 12 层看到的那个盾值”就准了。
local KEYSTONE_BASE_LEVEL = 12       -- 基准层数
local KEYSTONE_BASE_VALUE = 5000000  -- 基准层数时“条满（100%）”对应的护盾量
local KEYSTONE_STEP = 0.09           -- 每高一层分母 ×1.09（9%）

-- ── "fixed" 模式：条满 = 这么多吸收量 ──
--   原来用“目标最大生命”当分母：boss 动辄上千万血，而护盾只有几百万 → 条永远只剩一小截，看不清楚。
--   改成固定参考值后，条长只跟吸收量本身挂钩，一眼就能看出“这个盾多大”。
--   · 想恢复“按目标最大生命占比”：把下面改成 local VALUE_MAX = nil（照样是原样透传，不碰 secret）
--   · "peak" 模式下它是“还没学到峰值”时的兜底值（现在只有 MAX_MODE = "peak"/"fixed" 才用得到）。
local VALUE_MAX = 5000000

-- 【峰值只在“真的上盾”时才学】触发信号只有一个：目标身上新出现【有益】光环。
--   （boss 自己吃的盾是有益光环；玩家挂在 boss 身上的 dot 是有害光环、一天到晚在刷新，认了会把峰值刷烂）
--   ⚠️ 曾经把“换目标 / 进战”也当触发，结果开怪那一刻 boss 还没盾、读到 0 就被当成峰值 →
--      条的 100% 变成 0 → 整个条画不出来（只剩文字）。所以现在只认有益光环。
-- 触发后 CAPTURE_WINDOW 秒内，读到什么值就把峰值记成什么值（覆盖式取最后一次）。
local CAPTURE_WINDOW = 0.6
local USE_AURA_TRIGGER = true -- 光环触发不想要就改成 false（那就只剩兜底值了）

-- 没护盾时是不是整条藏起来（连数值文字一起）。
--   普通数字：直接判断，精确。
--   secret   ：靠 bar:SetAlpha(absorb) 让客户端去解释（0 → 全透明，>0 → 夹到 1）。
--              如果实测发现“文字发灰 / 条看不清”，说明 alpha 被原样丢进去了，
--              把这行改成 false 就退化成“一直显示（没盾时是空条）”。
local HIDE_WHEN_NO_SHIELD = true

-- 调试输出（默认关）。这些打印全在 `if DEBUG then` 里，想重新排错就把 false 改成 true
local DEBUG = false

-- 轮询兜底间隔（秒）。
-- 为什么必须有它：实测【目标一直没变、护盾自己出现】时，UNIT_ABSORB_AMOUNT_CHANGED / UNIT_AURA
-- 有时压根不来（吸收值在副本里是 secret，客户端可能就不广播了），于是只有“重新选目标”
-- 才会触发一次重画。挂个 0.2 秒轮询，事件来不来都能及时显示 / 消失。
local POLL_INTERVAL = 0.2

local bar, valueText, percentSign
local peak             -- 学到的峰值（可能是 secret 值：只存着、只透传）
local captureUntil = 0 -- 采集窗口截止时间
local lastSig          -- 调试用：上一次的状态签名
local fullW            -- 标定出来的“满格 = 多少像素”（算百分比用）；nil = 还没标定 / 拿不到
local lastPctOK        -- 上一次是不是成功显示了百分比
local minW, maxW       -- 见过的填充宽度范围（用来判断“读到的宽度靠不靠谱”）
local anchorAllowed = false -- 定位框当前是不是显示着
local lastAlphaInfo    -- 调试用：上一次打印的 alpha 情况
local probeOK = false  -- 探针条可信吗（标定通过：塞满时宽度≈100）

local function StartCapture()
    captureUntil = GetTime() + CAPTURE_WINDOW
end

-- 位置：存档在 DiGuaTimelineAudioHelper.targetAbsorbX / targetAbsorbY
-- （没存过 → 用文件顶部的 POS_X / POS_Y 默认值）
local function ApplySavedPosition(frame)
    local g = DiGuaTimelineAudioHelper
    local x = (g and g.targetAbsorbX) or POS_X
    local y = (g and g.targetAbsorbY) or POS_Y
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

--- 总开关：控制台右栏「boss1 护盾条」勾选框（存档键 DiGuaTimelineAudioHelper.targetAbsorbBarEnabled）
---   护盾条本体和可移动定位框是【一体】的 —— 一个开关同时管，勾选才一起出现，取消一起消失。
---   **默认关**：只有显式 true 才算开（nil / false 都算关）。
---   每次现读存档，不缓存 → “勾选框是勾着的却还显示 / 没勾却显示”在逻辑上不可能发生。
local function IsEnabled()
    local g = DiGuaTimelineAudioHelper
    return g ~= nil and g.targetAbsorbBarEnabled == true
end

--- 这个吸收值能不能比较？（探一次就知道是不是 secret）
---   返回 true / false = 不是 secret（能精确判断）
---   返回 nil         = 是 secret（比较会被 pcall 接住）
local function CompareAbsorb(v)
    local ok, greater = pcall(function() return v > 0 end)
    if not ok then return nil end
    if greater then return true end
    return false
end

--- 按大秘境层数算“条满 = 多少护盾量”（全是普通数字运算，不碰 secret）
local keystoneLevel, keystoneValue
local function KeystoneMaxValue()
    -- 读层数：全包在 pcall 里，读不到 / 拿到 secret → 退回基准层
    local level = KEYSTONE_BASE_LEVEL
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local ok, l = pcall(function()
            local v = C_ChallengeMode.GetActiveKeystoneInfo()
            if type(v) ~= "number" then return nil end
            if v < 0 then return nil end -- 故意比较一下：v 若是 secret，会在这里抛错被接住
            return v
        end)
        if ok and l and l > 0 then level = l end
    end

    if level ~= keystoneLevel then -- 只在层数变化时重算
        keystoneLevel = level
        -- 复利式缩放（不是线性）：跟游戏内"每层血量/伤害按百分比放大"更接近，而且永远不会缩成负数
        local v = KEYSTONE_BASE_VALUE * (1 + KEYSTONE_STEP) ^ (level - KEYSTONE_BASE_LEVEL)
        if v < 1 then v = 1 end
        keystoneValue = v
    end
    return keystoneValue
end

-- ── 百分比 ──
-- 目标：文字显示“当前填充占整条的百分之几”。
-- 直接算 absorb / maxValue 不行（secret 不能做四则运算），所以换个思路：
--   StatusBar 的填充条就是一个 Texture，它的宽度是客户端根据 secret 值自己算出来的【像素数】；
--   像素数是控件尺寸、不是 secret 值本身 → 大概率能读回来，能读回来就能在 Lua 里算百分比。
--   读不回来（客户端不让读）→ pcall 接住 → 退回显示原始数值，不会报错。
local function CalibrateFullWidth()
    -- 先塞满量一次，拿“满格”的像素宽当分母（这样跟边框 insets、缩放都无关）
    local ok, w = pcall(function()
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        return bar:GetStatusBarTexture():GetWidth()
    end)
    -- 顺手做个合理性检查：满格宽度应该跟条的宽度差不多（防止拿到"还没布局好"的 0 / 离谱值）
    if ok and w and w >= WIDTH * 0.5 and w <= WIDTH + 5 then fullW = w end
end

--- 读一眼填充条当前的像素宽（读不到 / 读回来是 secret → 返回 nil）
local function TryFillWidth()
    local ok, w = pcall(function()
        local width = bar:GetStatusBarTexture():GetWidth()
        if width < 0 then return 0 end -- 故意比较一下：宽度若是 secret，会在这里抛错，被 pcall 接住
        return width
    end)
    if ok and type(w) == "number" then return w end
    return nil
end

-- 记一下见过的宽度范围（都是普通数字，可以比较）
local function TrackWidth(w)
    if not w then return end
    if not minW or w < minW then minW = w end
    if not maxW or w > maxW then maxW = w end
end

-- 宽度靠不靠谱：得看到它真的变过（否则可能一直是“框宽”而不是“填充宽”）
local function WidthIsTrustworthy()
    return (minW and maxW and (maxW - minW) > 1) and true or false
end

local function TryPercentText(fillW)
    if not fillW or not fullW or fullW <= 0 then return nil end
    local ok, text = pcall(function()
        local p = fillW / fullW * 100
        if p < 0 then p = 0 elseif p > 100 then p = 100 end
        return string.format("%d%%", math.floor(p + 0.5))
    end)
    if ok then return text end
    return nil
end

-- ── 【关键】100px 探针条：把“百分比”变成客户端自己算的一个数 ──
-- 副本里真条的填充宽度是 secret（读出来不能比较/运算），但可以【原样透传】给 C 侧函数。
-- 所以另开一条宽度正好 100px 的隐形探针：
--     探针:SetMinMaxValues(0, 上限); 探针:SetValue(吸收值)
--     → 它的填充宽度 = 100 × 吸收值/上限 = 【百分比本身】（1px = 1%）
--     → AbbreviateNumbers(那个宽度) 得到 secret 字符串 → 直接 SetText
-- 全程不比较、不运算，完全符合 secret 规矩（AbbreviateNumbers 正是给 secret 用的那个 C 侧函数）。
local probe = CreateFrame("StatusBar", nil, UIParent)
probe:SetSize(100, 10)
probe:SetPoint("CENTER", UIParent, "CENTER", 0, -20000) -- 挑到屏幕外，永远看不见
probe:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
probe:SetMinMaxValues(0, 1)
probe:SetValue(0)
probe:SetAlpha(0) -- 双保险：即便位置算错也全透明
probe:Show()      -- 必须处于“显示”状态，控件尺寸才会正常计算

local function CalibrateProbe()
    if probeOK then return end
    -- 先把探针塞满（值 = 1 是普通数字，这时宽度读得回来）→ 宽度应该≈100，证明算路通
    local ok, w = pcall(function()
        probe:SetMinMaxValues(0, 1)
        probe:SetValue(1)
        return probe:GetStatusBarTexture():GetWidth()
    end)
    if ok and w and w > 95 and w < 105 then probeOK = true end
end

-- ── 百分比文字：不要小数 ──
-- AbbreviateNumbers 对小数会原样保留小数位（实测出 "45.23"），所以给它传一套自定义规则：
--   NumberAbbreviationBreakpoint = { breakpoint, abbreviation, abbreviationIsGlobal, significandDivisor, fractionDivisor }
--   · breakpoint = 0        → 0~100 全范围都走这一条
--   · fractionDivisor = 1   → ★ 不带小数位
--   · abbreviation = "" + abbreviationIsGlobal = false → 不加后缀（不带 K/M），也不去查全局字符串
-- 先用【普通数字】自测一次（45.2345 应该格式成 "45"），测通了才敢用在 secret 值上。
local PCT_OPTIONS = {
    breakpointData = {
        {
            breakpoint = 0,
            abbreviation = "",
            abbreviationIsGlobal = false,
            significandDivisor = 1,
            fractionDivisor = 1,
        },
    },
}
local pctFormatOK -- nil = 还没自测过
local function InitPercentFormat()
    if pctFormatOK ~= nil then return end
    pctFormatOK = false
    local ok, sample = pcall(AbbreviateLargeNumbers, 45.2345, PCT_OPTIONS)
    -- 输入是普通数字 → 输出也是普通字符串，可以放心检查有没有小数点/逗号
    if ok and type(sample) == "string" and not sample:find("%.") and not sample:find(",") then
        pctFormatOK = true
    end
end

--- 用探针拿到百分比文字（拿不到就返回 nil → 上层退回显示原始数值）
local function ProbePercentText(absorb, maxValue)
    if not probeOK then return nil end
    InitPercentFormat()
    local ok, text = pcall(function()
        probe:SetMinMaxValues(0, maxValue or 1)
        probe:SetValue(absorb)
        local w = probe:GetStatusBarTexture():GetWidth()
        if pctFormatOK then return AbbreviateLargeNumbers(w, PCT_OPTIONS) end
        return AbbreviateNumbers(w) -- 兜底：可能带小数
    end)
    if ok and type(text) == "string" then return text end
    return nil
end

local function Paint()
    if not bar then return end
    local absorb = UnitGetTotalAbsorbs(UNIT) or 0
    local hasShield = CompareAbsorb(absorb) -- true / false / nil(=secret)

    -- 峰值怎么学（两种世界分开处理）：
    --   普通数字：直接比大小，精确；盾没了就把峰值清掉
    --   secret  ：只能在“刚出现有益光环”打开的采集窗口里猜（见 UNIT_AURA 分支）
    if hasShield == false then
        peak = nil -- 盾真的没了 → 峰值作废，下一个盾重新学
    elseif hasShield == true then
        if peak == nil then
            peak = absorb
        else
            local ok, bigger = pcall(function() return absorb > peak end)
            if ok and bigger then peak = absorb end
        end
    elseif captureUntil > GetTime() then
        peak = absorb -- secret：窗口内取最后一次读到的值当峰值
    end

    -- 分母优先级："peak" 模式学到的峰值 > 按层数缩放 > 固定值 > 目标最大生命
    local maxValue
    if MAX_MODE == "peak" and peak then
        maxValue = peak
    elseif MAX_MODE == "keystone" then
        maxValue = KeystoneMaxValue()
    else
        maxValue = VALUE_MAX or UnitHealthMax(UNIT)
    end

    -- 只透传：不比较、不运算、不 tonumber、不拼接
    -- （标定要在写真实值之前做，不然会把“塞满”的宽度当成当前比例）
    if not fullW then CalibrateFullWidth() end
    bar:SetMinMaxValues(0, maxValue or 1)
    bar:SetValue(absorb)

    -- 读一次填充像素宽：既用来算百分比，也用来判断“到底有没有盾”
    local fillW = TryFillWidth()
    TrackWidth(fillW)

    -- 文字：优先【探针百分比】（副本里也能用），其次真条宽度换算，最后退回原始数值
    if not probeOK then CalibrateProbe() end
    local pctText = ProbePercentText(absorb, maxValue)
    if not pctText then pctText = TryPercentText(fillW) end
    if pctText then
        valueText:SetText(pctText)
        if percentSign then percentSign:Show() end
        lastPctOK = true
    else
        valueText:SetText(AbbreviateNumbers(absorb))
        if percentSign then percentSign:Hide() end
        lastPctOK = false
    end

    -- 【有护盾才显示】三选一：
    --   普通数字 → 直接用 0 / 1，精确
    --   secret   → 把【吸收值本身】当 alpha 塞进去，由客户端解释
    --        absorb = 0 → alpha = 0 → 整条 + 数值文字一起全透明
    --        absorb > 0 → alpha 被夹到 1 → 正常显示
    --   依据：客户端文档 SimpleRegionAPIDocumentation.lua 里 SetAlpha 的参数标了
    --     SecretArgumentsAddAspect = { Enum.SecretAspect.Alpha } + "AllowedWhenTainted"
    --     （和 SetAlphaFromBoolean 是同一套机制；那个要求参数是 bool，而我们手上是数字）
    if not HIDE_WHEN_NO_SHIELD then
        bar:SetAlpha(1)
    elseif hasShield == true then
        bar:SetAlpha(1)
    elseif hasShield == false then
        bar:SetAlpha(0)
    elseif fillW and WidthIsTrustworthy() then
        -- secret，但“填充宽度”确实会跟着变 → 直接拿宽度当“有没有盾”（宽度≈0 = 没盾）
        if fillW > 0.5 then bar:SetAlpha(1) else bar:SetAlpha(0) end
    else
        bar:SetAlpha(absorb)
    end

    -- 调试：只在状态变化时打一行（不涉及 secret 值本身的运算）
    if DEBUG then
        local sig = tostring(hasShield) .. "|" .. tostring(peak ~= nil)
            .. "|" .. (captureUntil > GetTime() and "cap" or "-")
            .. "|" .. tostring(lastPctOK) .. "|" .. tostring(fullW)
            .. "|" .. tostring(WidthIsTrustworthy())
        if sig ~= lastSig then
            lastSig = sig
            print("[护盾条] 值类型=" .. (hasShield == nil and "secret" or "普通数字")
                .. "，有盾=" .. tostring(hasShield)
                .. "，学到峰值=" .. tostring(peak ~= nil)
                .. "，采集窗口=" .. (captureUntil > GetTime() and "开" or "关")
                .. "，上限来源=" .. ((MAX_MODE == "peak" and peak) and "峰值" or "兜底")
                .. "，百分比=" .. (lastPctOK and "可用" or "不可用")
                .. "，满格像素=" .. tostring(fullW)
                .. "，当前填充=" .. tostring(fillW)
                .. "，宽度可信=" .. tostring(WidthIsTrustworthy())
                .. "，探针=" .. (probeOK and "可用" or "不可用"))
        end

        -- 单独一条：看看 SetAlpha(secret) 到底被客户端解析成了什么。
        -- 没盾的时候应该看到 0.00；若一直不是 0，那就是“条藏不住”的真因。
        local alphaInfo
        local okA, a = pcall(function()
            local alpha = bar:GetAlpha()
            if alpha < 0 then return 0 end -- 故意比较：alpha 若是 secret，会在这里抛错被接住
            return string.format("%.2f", alpha)
        end)
        alphaInfo = (okA and a) or "secret/读不到"
        if alphaInfo ~= lastAlphaInfo then
            lastAlphaInfo = alphaInfo
            print("[护盾条] alpha=" .. alphaInfo
                .. "（护盾值=" .. (hasShield == nil and "secret" or tostring(hasShield))
                .. "，填充宽=" .. tostring(fillW) .. "）")
        end
    end
end

local function Refresh()
    if not bar then return end
    -- 【护盾条本体】只看总开关（勾选框）—— 与控制台开不开【无关】：
    --   勾选后即使关掉控制台，这条也照常显示 / 刷新。
    if not IsEnabled() then
        bar:Hide()
        return
    end
    if UnitExists(UNIT) then
        bar:Show()
        Paint()
    else
        bar:Hide() -- 没有 boss1（主城 / 野外）→ 没有护盾数据，自然不显示
    end
end

local function BuildBar()
    bar = CreateFrame("StatusBar", "DiGuaTargetAbsorbBar", UIParent, "BackdropTemplate")
    bar:SetSize(WIDTH, HEIGHT)
    ApplySavedPosition(bar)                 -- 有存档用存档，没存档用 POS_X / POS_Y 默认值
    bar:SetFrameStrata("MEDIUM")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8") -- 纯色块（不用材质/渐变）
    bar:SetStatusBarColor(0.34, 0.62, 0.80) -- 天蓝色（在上一版基础上再提亮一档）
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    -- 边框回来了（黑灰色）。
    -- ⚠️ 老教训：只要给了 edgeFile，边框就会画出来，而且颜色默认是纯白不透明 (1,1,1,1)
    --    —— 所以 SetBackdropBorderColor 必须【显式】写，不能靠“注释掉”来去掉白边。
    -- insets 让填充内缩 1px，不然填充会把 1px 的边框盖掉。
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bar:SetBackdropColor(0, 0, 0, 0.35)    -- 黑色底，半透明
    bar:SetBackdropBorderColor(0, 0, 0, 0.7) -- 黑色边框，半透明

    valueText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    valueText:SetTextColor(1, 1, 1)
    valueText:SetShadowColor(0, 0, 0, 1)
    valueText:SetShadowOffset(1, -1)

    -- “%”单独一个 FontString，跟在数字右边（因为数字本身是 secret 字符串，不能拼接）
    percentSign = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    percentSign:SetPoint("LEFT", valueText, "RIGHT", 1, 0)
    percentSign:SetText("%")
    percentSign:SetTextColor(1, 1, 1)
    percentSign:SetShadowColor(0, 0, 0, 1)
    percentSign:SetShadowOffset(1, -1)
    percentSign:Hide()

    -- CreateFrame 出来默认是显示的，先藏起来（免得登录 / 重载瞬间闪一下）
    bar:Hide()
    return bar
end

-- ══════════════════════════════════════════════════════════════
-- 可移动的定位色框（约定同 FocusInterrupt.lua 的施法条定位框 / Utils.lua 的圆环定位框）
--   · 和护盾条是【一体】的，共用同一个总开关；平时完全隐藏，只有【勾选着】且【控制台打开】才出现、才能拖
--   · 松手自动规整锚点并存档（DiGuaTimelineAudioHelper.targetAbsorbX / targetAbsorbY）
--   · 为什么需要它：护盾条没盾时是全透明的，没盾的时候根本看不见、也就没地方拖
-- ══════════════════════════════════════════════════════════════
local moveFrame = CreateFrame("Frame", "DiGuaTargetAbsorbMoveFrame", UIParent, "BackdropTemplate")
moveFrame:SetSize(WIDTH, HEIGHT)
moveFrame:SetClampedToScreen(true)
moveFrame:EnableMouse(false)
moveFrame:SetMovable(false)
-- 和其他定位框统一：纯色、不要边框（照抄 FocusInterrupt.lua 的 MoveFrame）
moveFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
moveFrame:SetBackdropColor(0.25, 0.65, 1, 0.4) -- 淡蓝色底（跟焦点施法条定位框完全一致）
moveFrame.text = moveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
moveFrame.text:SetPoint("CENTER")
moveFrame.text:SetText("boss1 護盾條")
moveFrame.text:SetTextColor(1, 1, 1, 0.9)
moveFrame.text:SetJustifyH("CENTER")
ApplySavedPosition(moveFrame)
moveFrame:Hide()

moveFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and self:IsMovable() then
        self:StartMoving()
        self.isMoving = true
    end
end)
moveFrame:SetScript("OnMouseUp", function(self)
    if not self.isMoving then return end
    self:StopMovingOrSizing()
    self.isMoving = false
    -- 先规整锚点再存（否则拖到靠边时 x,y 语义变了，下次登录位置会跑回中间）
    local x, y = self:GetLeft() or 0, self:GetTop() or 0
    if addonTable.NormalizeFrameToUIParentCenter then
        x, y = addonTable.NormalizeFrameToUIParentCenter(self)
    end
    local g = DiGuaTimelineAudioHelper
    if g then g.targetAbsorbX, g.targetAbsorbY = x, y end
    if bar then ApplySavedPosition(bar) end
    print(string.format("|cff00ff00[DiGua]|r boss1 護盾條新位置已保存 (X: %d, Y: %d)", x, y))
end)

--- 定位框该不该显示？ —— 只看两件事，范式同 FocusInterrupt.lua 的 RefreshFocusCastBarState：
---   ① 控制台打开（isConsoleShown 参数；不传就现读 DiGuaTimelineMainFrame:IsShown()）
---   ② 总开关（勾选框）勾着
--- ⚠️ 护盾条本体【不】经过这里 —— 它只由总开关决定，控制台关着照样显示（见 Refresh）。
--- 返回 on（原因仅用于 DEBUG 输出）
local function ShouldShowAnchor(isConsoleShown)
    if isConsoleShown == nil then
        isConsoleShown = (DiGuaTimelineMainFrame and DiGuaTimelineMainFrame:IsShown()) and true or false
    end
    if isConsoleShown ~= true then return false, "控制台沒打開" end
    if not IsEnabled() then return false, "總開關關著" end
    return true, "控制台開著 + 總開關勾著"
end

--- 把定位框的显隐对齐到“现在到底该不该显示”。只在状态真的变化时才动它（不折腾控件）。
---   参数 isConsoleShown 由 Core.lua 的 OnShow/OnHide 传入（同其他定位框）；
---   OnUpdate 里每 0.2 秒再无参调一次（现读控制台状态）—— 控制台一关就会被收回。
local function ApplyAnchorVisibility(isConsoleShown)
    local on, reason = ShouldShowAnchor(isConsoleShown)
    if on == anchorAllowed and moveFrame:IsShown() == on then return end
    anchorAllowed = on
    moveFrame:EnableMouse(on)
    moveFrame:SetMovable(on)
    if on then moveFrame:Show() else moveFrame:Hide() end
    if DEBUG then print("[护盾条] 定位框=" .. (on and "显示" or "隐藏") .. "（" .. reason .. "）") end
end

--- 控制台开/关 + 勾选状态变化时调用（约定同 addonTable.RefreshFocusCastBarState）
---   ⚠️ 只管【定位框】：护盾条本体的显隐不依赖控制台。
function addonTable.RefreshTargetAbsorbAnchor(isConsoleShown)
    ApplyAnchorVisibility(isConsoleShown)
end

--- 总开关（控制台右栏「boss1 护盾条」）被点动时调用 —— 一个开关同时管条 + 定位框：
---   on = true  → 目标在就显示条（不在就保持隐藏）；定位框按“控制台开着 + 勾着”自己算出来
---   on = false → 条立刻藏掉，峰值一并作废（下次开重新学）；定位框也会被立刻收回
function addonTable.SetTargetAbsorbBarEnabled(on)
    if on then
        Refresh()
    else
        if bar then bar:Hide() end
        peak = nil -- 关掉时把学到的峰值作废，下次开重新学
    end
    ApplyAnchorVisibility()
end

-- 事件：护盾变化 / 光环变化 / 最大生命变化 / 过图 / 进战脱战 / 换 boss
--   —— 全部只触发重画或“重开采集窗口”，依旧不做任何数值判断
local f = CreateFrame("Frame")
f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", UNIT) -- 单元事件由客户端过滤，省一层自己判断
f:RegisterUnitEvent("UNIT_MAXHEALTH", UNIT)
if MAX_MODE == "peak" then                             -- UNIT_AURA 只给“自动学峰值”用
    f:RegisterUnitEvent("UNIT_AURA", UNIT)             -- （副本里 payload 是 secret，学不了，只有野外能学）
end
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGIN")                        -- 登录后再对齐一次位置（那时存档已就绪）
f:RegisterEvent("PLAYER_REGEN_DISABLED")               -- 进战（只重画，峰值不再在这里学）
f:RegisterEvent("PLAYER_REGEN_ENABLED")                -- 脱战 = 峰值作废，下一轮重新学
f:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")      -- boss 令牌换人（换 boss / 新一场）
if UNIT == "target" or UNIT == "focus" then            -- 只有监视“当前目标/焦点”时才需要关心换目标
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
end

-- ⚠️ 事件不一定会来（实测：目标不变、护盾自己出现时可能一个事件都没有），
--    所以再挂一个 0.2 秒的轮询兜底 —— 事件不来也能在 0.2 秒内显示出来。
--    ⚠️ OnUpdate 只在【已显示】的框体上跑； CreateFrame 出来的框体默认就是显示的，
--       这里显式 Show() 一下，免得哪天改成默认隐藏了还不知道为啥不刷。
f:Show()

local pollAcc = 0
f:SetScript("OnUpdate", function(_, elapsed)
    pollAcc = pollAcc + elapsed
    if pollAcc < POLL_INTERVAL then return end
    pollAcc = 0
    Refresh()
    -- 定位框：每 0.2 秒【现算】一次该不该显示（读的是勾选框自己的状态），
    -- 就算别的地方误 Show 了，也会立刻被收回去
    ApplyAnchorVisibility()
end)

f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        ApplySavedPosition(moveFrame)
        if bar then ApplySavedPosition(bar) end
        return
    end

    if not bar then BuildBar() end

    -- UNIT_AURA：arg2 是 AuraUpdateInfo，只看【新加上去】的光环，且只认有益光环
    --
    -- ⚠️ 实战教训（BugSack 抓到的真错误，2026-10-10）：
    --   副本里整张 AuraUpdateInfo 都是【secret】：addedAuras 是 secret table、isFullUpdate 是 secret boolean，
    --   直接 ipairs(arg2.addedAuras) 会抛 “bad argument #1 to 'ipairs' (table expected, got secret)” ——
    --   而这个错会把整个 OnEvent 打断，后面的 Refresh() 都跑不到。
    --   → 整段包进 pcall：野外（不是 secret）照常工作；副本里静默跳过。
    if event == "UNIT_AURA" then
        if USE_AURA_TRIGGER and MAX_MODE == "peak" then
            local ok, hasHelpful = pcall(function()
                for _, aura in ipairs(arg2.addedAuras) do
                    if aura.isHelpful then return true end
                end
                return false
            end)
            if ok and hasHelpful then
                StartCapture()
                -- 立刻重画：让“就是这个值”当场变成满值（要不然要等下一次数值变化才生效）
                Refresh()
            end
        end
        return
    end

    -- 新的一轮（脱战 / 换 boss）：峰值作废，等下一次上盾重新学
    -- （不清的话，新 boss 上个小盾会被旧 boss 的大峰值压得只剩一小截）
    if event == "PLAYER_REGEN_ENABLED" or event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        peak = nil
        Refresh()
        return
    end

    -- ⚠️ 进战 / 换目标【不再】重开采集窗口 —— 那一刻 boss 身上往往还没盾，
    --    读到 0 会被当成“护盾初始值”（条的 100% 变成 0，整个条就画不出来了）。
    --    峰值现在只由“新出现有益光环”来学（上面的 UNIT_AURA 分支）。

    Refresh()
end)
