------------------------------------------------------------
-- 光環（buffs / debuffs）：12.1 路線 A —— AuraContainer intrinsic
-- 骨架移植自 Stuf/auracontainer.lua（本地寫的 12.1 轉接層，實戰驗證）
--
-- 鐵律：
--   * 樣式只能在 initializeFrame 內做（之後 AuraButton 變 forbidden）
--   * 絕不從按鈕回讀尺寸（回傳秘密值），尺寸一律來自設定
--   * maximumLineSize 是主軸像素預算 = 顆數 ×（尺寸＋間距）
--   * 容器建好外觀就烘死，設定變更 → 簽章比對 → 重建
--   * 插件永遠拿不回剩餘秒數；倒數顯示全部交出 widget 讓暴雪驅動
--   * 「剩 N 秒才顯示數字」用 ColorCurve alpha 階梯（暴雪端取樣 RemainingDuration）
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media

------------------------------------------------------------
-- 能力偵測
------------------------------------------------------------
local caps = { build = select(4, GetBuildInfo()) or 0 }
local MIN_BUILD = 120100

local function Detect()
    if caps.detected then return caps end
    caps.detected = true
    if caps.build < MIN_BUILD then return caps end
    local ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not frame then return caps end
    frame:Hide()
    caps.auraContainer = type(frame.AddAuraGroup) == "function"
    caps.flowLayout = type(frame.SetFlowLayoutAnchorPoint) == "function"
    return caps
end

------------------------------------------------------------
-- 倒數格式：NumericRule 三段式（DandersFrames/Cell 出貨驗證過的寫法）
--   <91 秒   純數字（"27"）
--   ≥91 秒   "Nm"（分數向上取整，2m32s → "3m"，跟暴雪自己的框架一致）
--   ≥5401 秒 "Nh"
-- 不用 SecondsFormatter：它的三種縮寫在中文全都輸出「秒」，設計上沒有無單位出口
------------------------------------------------------------
local DurationFormatter
do
    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
        local ok, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
        if ok and formatter then
            local R = Enum and Enum.NumericRuleFormatRounding
            local down, up = R and R.Down or nil, R and R.Up or nil
            local added = pcall(function()
                formatter:AddBreakpoint({ threshold = 0, step = 1, rounding = down, min = 1, format = "%d" })
                formatter:AddBreakpoint({ threshold = 91, step = 1, rounding = down, min = 1, format = "%dm",
                                          components = { { div = 60, rounding = up } } })
                formatter:AddBreakpoint({ threshold = 5401, step = 1, rounding = down, min = 1, format = "%dh",
                                          components = { { div = 3600, rounding = up } } })
            end)
            if added then DurationFormatter = formatter end
        end
    end
end

-- 「剩餘低於 threshold 秒才顯示數字」：alpha 階梯 ColorCurve
local function BuildDurationAlphaCurve(threshold, r, g, b)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    r, g, b = r or 1, g or 1, b or 1
    local visible = CreateColor(r, g, b, 1)
    local hidden = CreateColor(r, g, b, 0)
    local added = pcall(function()
        curve:AddPoint(0, visible)
        curve:AddPoint(threshold, visible)
        curve:AddPoint(threshold + 0.01, hidden)
        curve:AddPoint(threshold + 86400, hidden)
    end)
    if not added then return nil end
    return curve
end

------------------------------------------------------------
-- AuraButton 外觀（三層：外框 → 掃描 → 內縮圖示 → 文字）
-- 只能在 initializeFrame 內呼叫
------------------------------------------------------------
local BORDER = 1
local TRACK_COLOR = { 0, 0, 0, 1 }            -- swipe 底下的黑色軌道
local SPENT_COLOR = { 0.18, 0.18, 0.18 }      -- 驅散色外框被灰色吃掉
local BUFF_BORDER_COLOR = { 0, 0.55, 0.15, 1 }

local function InitAuraButton(auraButton, style, sizeW, sizeH)
    sizeH = sizeH or sizeW
    auraButton:SetIgnoringChildrenForBounds(true)
    auraButton:SetSize(sizeW, sizeH)
    auraButton:SetMouseClickEnabled(false)

    -- 底層外框
    local borderTex = auraButton:CreateTexture(nil, "BACKGROUND")
    borderTex:SetAllPoints(auraButton)
    auraButton.Border = borderTex

    if style.dispelBorder and auraButton.SetAuraBorder then
        -- 驅散色在底框，掃描用灰色由上吃掉（SetSwipeColor 給不了逐光環的驅散色，
        -- 兩層對調繞過限制）
        borderTex:SetColorTexture(1, 1, 1, 1)
        auraButton:SetAuraBorder(borderTex, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle
                and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or nil,
            showIcon = false,
            showAlways = true,
        })
    else
        local c = style.borderColor or TRACK_COLOR
        borderTex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end

    -- 中層：Cooldown 交給暴雪驅動
    local cooldown
    if auraButton.SetDurationCooldown then
        cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        cooldown:SetAllPoints(auraButton)
        cooldown:SetSwipeTexture(Media.WHITE8X8)
        if style.dispelBorder then
            cooldown:SetSwipeColor(SPENT_COLOR[1], SPENT_COLOR[2], SPENT_COLOR[3])
            cooldown:SetReverse(true)
        else
            local c = style.swipeColor or style.borderColor or { 1, 1, 1, 1 }
            cooldown:SetSwipeColor(c[1], c[2], c[3])
        end
        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetDrawSwipe(true)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown.noCooldownCount = true
        auraButton.Cooldown = cooldown
        auraButton:SetDurationCooldown(cooldown)
    end

    -- 上層：內縮圖示
    local iconFrame = CreateFrame("Frame", nil, auraButton)
    iconFrame:SetPoint("TOPLEFT", auraButton, "TOPLEFT", BORDER, -BORDER)
    iconFrame:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -BORDER, BORDER)
    if cooldown then
        iconFrame:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    end
    auraButton.IconFrame = iconFrame

    local textFrame = CreateFrame("Frame", nil, auraButton)
    textFrame:SetAllPoints(auraButton)
    textFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 1)
    auraButton.TextFrame = textFrame

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconFrame)
    icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    auraButton.Icon = icon
    auraButton:SetIcon(icon)

    -- 倒數文字
    if style.showDuration then
        local duration = textFrame:CreateFontString(nil, "OVERLAY")
        local fsize = style.durationFontSize or math.max(8, math.floor(sizeH * 0.55))
        duration:SetFont(Media.Font(ns.db.global.font), fsize, "OUTLINE")
        duration:SetTextColor(1, 1, 1)
        duration:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        auraButton.Duration = duration
        if auraButton.SetDurationText then
            local formatter = DurationFormatter
            local options = formatter and { textFormatter = formatter } or {}
            if style.durationThreshold and Enum and Enum.DurationTextBindingProperty then
                local curve = BuildDurationAlphaCurve(style.durationThreshold, 1, 1, 1)
                if curve then
                    options.textColor = {
                        curve = curve,
                        property = Enum.DurationTextBindingProperty.RemainingDuration,
                    }
                end
            end
            if not pcall(auraButton.SetDurationText, auraButton, duration,
                         next(options) and options or nil) then
                auraButton:SetDurationText(duration)
            end
        end
    end

    -- 層數（絕不傳 formatter —— 暴雪會在 Lua 對秘密層數跑 FormatNumber 炸掉整個容器）
    if style.showStack then
        local stack = textFrame:CreateFontString(nil, "OVERLAY")
        stack:SetFont(Media.Font(ns.db.global.font), style.stackFontSize or 10, "OUTLINE")
        stack:SetTextColor(1, 1, 1)
        stack:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", 2, -2)
        auraButton.Count = stack
        if auraButton.SetApplicationCount then
            auraButton:SetApplicationCount(stack)
        end
    end
end

------------------------------------------------------------
-- growth 字串 → flow layout 方向
------------------------------------------------------------
local GROWTH = {
    LRTB = { vertical = false, growLeft = false, growUp = false },
    LRBT = { vertical = false, growLeft = false, growUp = true },
    RLTB = { vertical = false, growLeft = true,  growUp = false },
    RLBT = { vertical = false, growLeft = true,  growUp = true },
    TBLR = { vertical = true,  growLeft = false, growUp = false },
    TBRL = { vertical = true,  growLeft = true,  growUp = false },
    BTLR = { vertical = true,  growLeft = false, growUp = true },
    BTRL = { vertical = true,  growLeft = true,  growUp = true },
}

local function ApplyFlowLayout(container, spec)
    if container.SetFlowLayoutAnchorPoint then
        local vertical = spec.growUp and "BOTTOM" or "TOP"
        local horizontal = spec.growLeft and "RIGHT" or "LEFT"
        container:SetFlowLayoutAnchorPoint(vertical .. horizontal)
    end
    if container.SetFlowLayoutAxis and AnchorUtil and AnchorUtil.FlowLayoutAxis then
        container:SetFlowLayoutAxis(spec.vertical
            and AnchorUtil.FlowLayoutAxis.Vertical
            or AnchorUtil.FlowLayoutAxis.Horizontal)
    end
    if container.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
        local dir = AnchorUtil.FlowDirection
        container:SetFlowLayoutGrowthDirection(
            spec.growLeft and dir.Left or dir.Right,
            spec.growUp and dir.Up or dir.Down)
    end
    if container.SetFlowLayoutMaximumLineSize and spec.perLine then
        local step = spec.size + spec.spacing
        container:SetFlowLayoutMaximumLineSize(spec.perLine * step)
    end
end

------------------------------------------------------------
-- 容器生命週期
------------------------------------------------------------
local function BuildSignature(edb)
    return table.concat({
        tostring(edb.x), tostring(edb.y), tostring(edb.w), tostring(edb.h),
        tostring(edb.maxCount), tostring(edb.perRow), tostring(edb.growth),
        tostring(edb.spacing), tostring(edb.showStack), tostring(edb.stackSize),
        tostring(edb.durationText), tostring(edb.durationThreshold),
        tostring(edb.onlyMine), tostring(ns.db.global.font),
    }, "|")
end

local function CreateContainer(uf, elementName, edb, filter, style)
    -- 容器掛中介 holder（不直接依附會被 Hide 的東西；也墊高層級蓋過血條）
    local holder = uf.auraHost
    if not holder then
        holder = CreateFrame("Frame", nil, uf)
        holder:SetAllPoints(uf)
        holder:SetFrameLevel(12)
        uf.auraHost = holder
    end

    local g = GROWTH[edb.growth or "LRTB"] or GROWTH.LRTB
    local spec = {
        vertical = g.vertical, growLeft = g.growLeft, growUp = g.growUp,
        size = g.vertical and (edb.h or 20) or (edb.w or 20),
        spacing = edb.spacing or 0,
        perLine = edb.perRow or 8,
    }

    local container = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    container:SetSize(1, 1)
    container:SetFrameLevel(holder:GetFrameLevel() + 1)
    -- 錨點角依生長方向：往上長要用 BOTTOM 邊釘原點
    local anchorPoint = (g.growUp and "BOTTOM" or "TOP") .. (g.growLeft and "RIGHT" or "LEFT")
    container:SetPoint(anchorPoint, uf, "TOPLEFT", edb.x or 0, edb.y or 0)
    container:SetUnit(uf.unit)
    ApplyFlowLayout(container, spec)

    container:AddAuraGroup("main", filter, {
        maxFrameCount = edb.maxCount or 16,
        layout = {
            elementWidth = edb.w or 20,
            elementHeight = edb.h or 20,
            elementSpacing = edb.spacing or 0,
            lineSpacing = edb.spacing or 0,
        },
        initializeFrame = function(auraButton)
            InitAuraButton(auraButton, style, edb.w or 20, edb.h or 20)
        end,
    })

    -- SetEnabled gate 光環事件註冊（Cell 教訓 4：不可見時註冊不上，
    -- OnShow 再 kick 一次）
    if container.SetEnabled then
        pcall(container.SetEnabled, container, true)
        container:HookScript("OnShow", function(self)
            if not self.__kicked then
                self.__kicked = true
                pcall(self.SetEnabled, self, true)
            end
        end)
    end
    return container
end

local function BuildStyle(elementName, edb)
    if elementName == "debuffs" then
        return {
            dispelBorder = true,
            showDuration = edb.durationText and true or false,
            showStack = edb.showStack and true or false,
            stackFontSize = edb.stackSize or 10,
            durationThreshold = edb.durationThreshold,
        }
    end
    return {
        borderColor = BUFF_BORDER_COLOR,
        showDuration = edb.durationText and true or false,
        showStack = edb.showStack and true or false,
        stackFontSize = edb.stackSize or 10,
        durationThreshold = edb.durationThreshold,
    }
end

local function MakeElement(elementName, baseFilter)
    local function Build(uf, edb)
        if not Detect().auraContainer then return end
        if uf.isPreview then return end     -- 預覽用靜態假圖示（Preview 模組）

        uf.auraContainers = uf.auraContainers or {}
        local entry = uf.auraContainers[elementName]
        local signature = BuildSignature(edb)
        local filter = baseFilter
        if edb.onlyMine then filter = filter .. "|PLAYER" end

        if entry and entry.signature == signature then
            entry.container:Show()
            return
        end
        if entry then
            -- 外觀烘死在 AuraButton 裡，簽章變了只能重建（frame 無法銷毀，舊的藏起來）
            entry.container:Hide()
            uf.auraContainers[elementName] = nil
        end

        local ok, container = pcall(CreateContainer, uf, elementName, edb, filter,
                                    BuildStyle(elementName, edb))
        if not ok or not container then
            ns.aurasLastError = tostring(container)
            return
        end
        uf.auraContainers[elementName] = { container = container, signature = signature }
        uf.elements[elementName] = container
        container:Show()
    end

    local function Update(uf, edb, bucket)
        -- identity：換單位（target 換人）→ 容器指到新單位並全量重掃（R5）
        local entry = uf.auraContainers and uf.auraContainers[elementName]
        if not entry then return end
        local c = entry.container
        pcall(c.SetUnit, c, uf.unit)
        if c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
    end

    local function Disable(uf)
        local entry = uf.auraContainers and uf.auraContainers[elementName]
        if entry then entry.container:Hide() end
    end

    ns.RegisterElement{
        name = elementName,
        order = elementName == "buffs" and 60 or 61,
        buckets = {},        -- 容器自驅動；identity 全量刷新時換單位
        build = Build,
        update = Update,
        disable = Disable,
    }
end

MakeElement("buffs", "HELPFUL")
MakeElement("debuffs", "HARMFUL")
