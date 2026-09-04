------------------------------------------------------------
-- 光環（buffs / debuffs）：12.1 路線 A —— AuraContainer intrinsic
-- 骨架沿用自己寫過的 12.1 轉接層，實戰驗證過
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

-- ⚠ 要在 FILTER_MODES／MODE_LABELS 之前宣告：那些表在檔案層就求值，
-- 宣告寫在後面會抓到同名的全域 nil，標籤全變空字串而且不報錯
local L = ns.L

local Media = ns.Media

------------------------------------------------------------
-- 篩選模式
--
-- 12.1 讀不到光環內容，所以過濾只能交給引擎。兩個管道：
--   token  filter 字串裡的一段（"HARMFUL|CROWD_CONTROL"），`|` 串接、`!` 否定
--   cand   candidateFilters 表，引擎端求值 —— 有些概念沒有對應的 token，只能走這裡
-- 完整詞彙與六條硬規則見 .claude/notes 的 wow-121-aura-filter-vocabulary。
--
-- ✅ **布林型 candidateFilters 對敵對單位正常運作**（2026-08-28 首領戰實測）：
--    同一個容器，「全部」顯示首領的 4 顆增益，切成「可偷取或驅散」
--    （`{ isStealable = true }`）就變空 —— 差別只有那個 payload，所以引擎確實採用了它，
--    首領的增益本來就沒有可偷取的。**不需要為這幾個模式補身分閘。**
--    ⚠ wow-121-identity-gate-failopen 那篇的 fail-open 只講 `include/excludeSpellIDs`，
--      而且觀察全部來自「友方隊友」情境，不要外推到這裡。
--    ⚠ 還沒驗的是黑名單（`excludeSpellIDs`）在敵對單位的增益列上會不會被靜默忽略。
--
-- ⚠⚠ 這裡刻意設計成**一個模式只對應一個 AuraGroup**。想「多個類別同時顯示」的話：
-- token 不能 OR ⇒ 一類一個 group ⇒ 要手工維護互斥否定鏈（而且只能否定**已啟用**的
-- 類別，否定沒啟用的會吃掉本來該顯示的光環）；再加上跨 group 沒有任何總量 API
-- （maxFrameCount 是每 group 的，SetFlowLayoutMaximumLineSize 是**換行**預算不是上限，
-- 超過只會多疊一列）⇒ 還得自己切預算，切錯就是靜默漏顯示。做完整那一套的實作
-- 動輒上千行，絕大部分都是在付這兩筆帳。
-- 團隊框需要那套（它問的是「這個隊友身上最重要的**那一個**」，天生多類別競爭）；
-- 單位框不需要（它問的是「這個目標身上我在乎的**那一類**」，天生單選）。
-- 單一 group ⇒ maxCount 全額給它，互斥與預算兩個問題都不存在。
--
-- ⚠ `IMPORTANT` 這個 token 沒有定論（有的實作認為它只標 HELPFUL，也有實作拿它配
-- HARMFUL 出貨），所以「重要」走 candidateFilter `isPriorityAura`，兩邊都不得罪。
-- ⚠ 不提供 spellID 黑名單：友方單位的減益禁止 ID 過濾（只有標記 NeverSecret 的
-- 才生效），做出來會是一個「有時有用有時沒用」的功能，比沒有更糟。
------------------------------------------------------------
local FILTER_MODES = {
    all         = {},
    -- 增益
    stealable   = { cand = { isStealable = true } },
    cancelable  = { token = "CANCELABLE" },
    bigdef      = { token = "BIG_DEFENSIVE" },
    extdef      = { token = "EXTERNAL_DEFENSIVE" },
    -- 減益
    dispellable = { token = "RAID_PLAYER_DISPELLABLE" },
    cc          = { token = "CROWD_CONTROL" },
    priority    = { cand = { isPriorityAura = true } },
    bossrole    = { cand = { isBossOrRoleAura = true } },
}

-- 下拉選單的內容與順序（設定面板用）。"all" 一律排第一。
local MODE_ORDER = {
    buffs   = { "all", "stealable", "cancelable", "bigdef", "extdef" },
    debuffs = { "all", "dispellable", "cc", "priority", "bossrole" },
}

local MODE_LABELS = {
    all         = L["All"],
    stealable   = L["Stealable or purgeable"],
    cancelable  = L["Cancelable by right-click"],
    bigdef      = L["Major defensives"],
    extdef      = L["External defensives"],
    dispellable = L["Dispellable by me"],
    cc          = L["Crowd control"],
    priority    = L["Important"],
    bossrole    = L["Boss and role auras"],
}

-- 設定面板呼叫（Options/Tab_Unit.lua）。模式清單只有這裡一份。
function ns.AuraFilterItems(elementName)
    local items = {}
    for _, key in ipairs(MODE_ORDER[elementName] or MODE_ORDER.buffs) do
        items[#items + 1] = { text = MODE_LABELS[key] or key, value = key }
    end
    return items
end

------------------------------------------------------------
-- filter 字串組裝
--
-- ⚠ 被客戶端拒絕的 filter 字串是**靜默全空** —— 容器建得起來、事件也收得到，
-- 就是一顆光環都不進來，看起來跟「插件壞了」一模一樣。所以兩件事缺一不可：
--   ① 記下被拒的字串（/muf debug 印得出來）
--   ② 逐級退回，絕不整組放棄（少顯示看得見，全空看不見）
------------------------------------------------------------
ns.auraRejectedFilters = {}

local function ValidFilter(f)
    -- 沒有這支 API 的話別擋（讓引擎自己決定），只有明確說「不合法」才算數
    if not (AuraUtil and AuraUtil.IsValidFilterString) then return true end
    local ok, valid = pcall(AuraUtil.IsValidFilterString, f)
    if ok and valid then return true end
    ns.auraRejectedFilters[f] = (ns.auraRejectedFilters[f] or 0) + 1
    return false
end

------------------------------------------------------------
-- 黑名單 → candidateFilters.excludeSpellIDs
--
-- 插件端讀不到光環內容，所以「不要顯示這幾顆」只能把法術 ID 交給引擎。
-- ⚠ 引擎對「友方單位的**減益**」禁止 ID 過濾（反自動化），所以黑名單在
-- 玩家／隊友的減益那一欄是無效的 —— 增益、以及敵方身上的減益都可以。
-- 設定面板那邊有寫清楚，這裡不另外擋（送過去被忽略而已，不會壞）。
------------------------------------------------------------
local function WithBlacklist(cand, edb)
    local bl = edb.blacklist
    if type(bl) ~= "table" or next(bl) == nil then return cand end
    -- ⚠ 不能直接往 mode.cand 上加：那是 FILTER_MODES 裡的共用常數表，
    -- 改下去會污染每一個用到同一個模式的單位。一律複製一份新的。
    local out = {}
    if cand then
        for k, v in pairs(cand) do out[k] = v end
    end
    out.excludeSpellIDs = bl        -- 格式跟我們存的一樣：[spellID] = true
    return out
end

-- 回傳 filter 字串 ＋ candidateFilters（可能是 nil）
--
-- 模式與「只顯示我上的」是**可以疊的**（`HARMFUL|CROWD_CONTROL|PLAYER` 仍然是
-- 一個 group）。onlyMine 保留成獨立勾選而不是併進模式清單，除了能疊之外，
-- 也讓既有設定檔不必遷移。
local function BuildFilter(baseFilter, edb)
    local mode = FILTER_MODES[edb.filterMode or "all"] or FILTER_MODES.all
    local f = baseFilter
    if mode.token then f = f .. "|" .. mode.token end
    if edb.onlyMine then f = f .. "|PLAYER" end
    if ValidFilter(f) then return f, WithBlacklist(mode.cand, edb) end

    -- 退回階梯。模式的 token 被拒 ⇒ 那個模式整個做不到，cand 那一半也不送
    -- （兩半是同一個概念，只送一半會得到一個沒人要求過的結果）。
    -- 黑名單跟模式無關，兩層退回都要帶著。
    if edb.onlyMine then
        local withPlayer = baseFilter .. "|PLAYER"
        if ValidFilter(withPlayer) then return withPlayer, WithBlacklist(nil, edb) end
    end
    return baseFilter, WithBlacklist(nil, edb)
end

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
-- 倒數格式：NumericRule 四段式（出貨插件驗證過的寫法）
--   <1 秒    小數（"0.4"）—— 少了這段，秒段的 min=1 會讓最後一整秒都卡在 "1"
--   <91 秒   純數字（"27"）
--   ≥91 秒   "Nm"（分數向上取整，2m32s → "3m"，跟暴雪自己的框架一致）
--   ≥5401 秒 "Nh"
-- 不用 SecondsFormatter：它的三種縮寫在中文全都輸出「秒」，設計上沒有無單位出口
-- 小數段的 step 0.1 ＋ "%.1f" 抄自 Platynator 的施法時間與 Ayije_CDM 的冷卻文字；
-- 沿用 Down 取整（跟秒段一致），所以最後一格是 "0.0"，不會先跳一下 "1.0"
------------------------------------------------------------
local DurationFormatter
do
    local R = Enum and Enum.NumericRuleFormatRounding
    local down, up = R and R.Down or nil, R and R.Up or nil

    -- 整包重建：斷點加進去就收不回來，要退掉小數段只能換一顆新的 formatter
    local function Build(tenths)
        local f = C_StringUtil.CreateNumericRuleFormatter()
        if tenths then
            f:AddBreakpoint({ threshold = 0, step = 0.1, rounding = down, format = "%.1f" })
        end
        f:AddBreakpoint({ threshold = tenths and 1 or 0, step = 1, rounding = down, min = 1, format = "%d" })
        f:AddBreakpoint({ threshold = 91, step = 1, rounding = down, min = 1, format = "%dm",
                          components = { { div = 60, rounding = up } } })
        f:AddBreakpoint({ threshold = 5401, step = 1, rounding = down, min = 1, format = "%dh",
                          components = { { div = 3600, rounding = up } } })
        return f
    end

    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
        local ok, formatter = pcall(Build, true)
        -- 客戶端要是不吃 0.1 的 step，退回整秒；整顆 formatter 掉了會換成暴雪自己那套
        -- 帶單位的格式，那個更難看
        if not ok or not formatter then ok, formatter = pcall(Build, false) end
        if ok and formatter then DurationFormatter = formatter end
    end
end

-- 「剩餘低於 threshold 秒才顯示數字」：alpha 階梯 ColorCurve
--
-- ⚠⚠ 這個**絕對不能在 initializeFrame 裡呼叫**。那個 callback 跑在暴雪
-- Blizzard_AuraContainerFrameProviders 的 CreateFrame 裡（securecallfunction 內），
-- 執行流程一定是被我們污染的，而 `CreateColor()` 會走到
-- `ColorMixin:OnLoad` → `self:SetRGBA(...)`：
--
--   Blizzard_SharedXMLBase/Color.lua:10: attempted to index a table that cannot be
--   accessed while tainted (execution tainted by 'MiliUI_UnitFrames')
--
-- 所以做兩件事：
--   1. **快取**。曲線只跟 (threshold, r, g, b) 有關，同一個設定全部按鈕共用一顆。
--   2. 由呼叫端在容器建立時（正常的插件路徑，不在暴雪的 frame 建立堆疊裡）先
--      WarmDurationAlphaCurve 一次；初始化裡就只是查表，一次 CreateColor 都不做。
-- 兩顆 CreateColor 另外包 pcall：哪天暴雪把更多表鎖起來，代價是「沒有淡出效果」，
-- 不是整顆按鈕建到一半斷掉。
local curveCache = {}

local function BuildDurationAlphaCurve(threshold, r, g, b)
    r, g, b = r or 1, g or 1, b or 1
    local key = ("%s/%s/%s/%s"):format(threshold, r, g, b)
    local hit = curveCache[key]
    if hit ~= nil then return hit or nil end          -- false = 建過但失敗，不要重試

    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then
        curveCache[key] = false
        return nil
    end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then
        curveCache[key] = false
        return nil
    end
    local okColor, visible, hidden = pcall(function()
        return CreateColor(r, g, b, 1), CreateColor(r, g, b, 0)
    end)
    if not okColor or not visible or not hidden then
        curveCache[key] = false
        return nil
    end
    local added = pcall(function()
        curve:AddPoint(0, visible)
        curve:AddPoint(threshold, visible)
        curve:AddPoint(threshold + 0.01, hidden)
        curve:AddPoint(threshold + 86400, hidden)
    end)
    if not added then
        curveCache[key] = false
        return nil
    end
    curveCache[key] = curve
    return curve
end

-- 在乾淨的插件路徑上先把曲線建好放進快取，讓 initializeFrame 只需要查表
local function WarmDurationAlphaCurve(style)
    if style and style.showDuration and style.durationThreshold then
        BuildDurationAlphaCurve(style.durationThreshold, 1, 1, 1)
    end
end

------------------------------------------------------------
-- AuraButton 外觀（三層：外框 → 掃描 → 內縮圖示 → 文字）
-- 只能在 initializeFrame 內呼叫
------------------------------------------------------------
local BORDER = 1                              -- 版面單位；實際用 ns.P.Scale 對齊實體像素
local TRACK_COLOR = { 0, 0, 0, 1 }            -- swipe 底下的黑色軌道
local SPENT_COLOR = { 0.18, 0.18, 0.18 }      -- 驅散色外框被灰色吃掉
local BUFF_BORDER_COLOR = { 0, 0, 0, 1 }      -- 1px 黑框（增益不靠顏色分類，跟減益的驅散色區隔）

local function InitAuraButton(auraButton, style, sizeW, sizeH)
    sizeH = sizeH or sizeW
    auraButton:SetIgnoringChildrenForBounds(true)
    auraButton:SetSize(sizeW, sizeH)
    auraButton:SetMouseClickEnabled(false)
    -- 滑鼠提示：光環內容是秘密值，插件畫不出提示——開啟 motion 讓 AuraButton
    -- 自己顯示暴雪的光環提示（12.1 build 68914 的按鈕 API）
    if style.tooltips ~= false then
        pcall(auraButton.SetMouseMotionEnabled, auraButton, true)
        if auraButton.SetHideTooltipInCombat then
            pcall(auraButton.SetHideTooltipInCombat, auraButton, false)
        end
        if auraButton.SetTooltipAnchorPoint then
            pcall(auraButton.SetTooltipAnchorPoint, auraButton, "ANCHOR_RIGHT")
        end
    else
        pcall(auraButton.SetMouseMotionEnabled, auraButton, false)
    end

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

    -- 上層：內縮圖示（露出底下那層當外框；內縮量對齊實體像素，邊寬才會每邊一致）
    local b = ns.P.Scale(BORDER)
    local iconFrame = CreateFrame("Frame", nil, auraButton)
    iconFrame:SetPoint("TOPLEFT", auraButton, "TOPLEFT", b, -b)
    iconFrame:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -b, b)
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
            -- ⚠ 備援也要包 pcall。這裡是 initializeFrame，整段跑在暴雪
            -- Blizzard_AuraContainerFrameProviders 的 CreateFrame 裡面（樣式只能在
            -- 這裡做，之後 AuraButton 就 forbidden 了），所以執行流程一定是被我們
            -- 污染的 —— 而 SetDurationText 內部會走到 CreateColor()，12.1 的
            -- ColorMixin 是「被污染時不給存取」的表：
            --
            --   Blizzard_SharedXMLBase/Color.lua:10: attempted to index a table that
            --   cannot be accessed while tainted (execution tainted by 'MiliUI_UnitFrames')
            --
            -- 主要路徑本來就有 pcall，備援卻是裸的 ⇒ 它一炸就把整個 InitAuraButton
            -- 從中間截斷，後面的層數文字完全沒建（錯誤 locals 裡沒有 Count 就是指紋）。
            -- 備援的意義是「主要的壞了還能撐住」，它自己不設防等於白做。
            -- 兩條都失敗就是沒有倒數文字 —— 難看，但至少按鈕是完整的。
            if not pcall(auraButton.SetDurationText, auraButton, duration,
                         next(options) and options or nil) then
                pcall(auraButton.SetDurationText, auraButton, duration)
            end
        end
    end

    -- 層數（絕不傳 formatter —— 暴雪會在 Lua 對秘密層數跑 FormatNumber 炸掉整個容器）
    if style.showStack then
        local stack = textFrame:CreateFontString(nil, "OVERLAY")
        stack:SetFont(Media.Font(ns.db.global.font), style.stackFontSize or 10, "OUTLINE")
        stack:SetTextColor(1, 1, 1)
        -- 位置可調。錨點是「文字的哪一角貼到按鈕的同一角」，所以偏移的正負方向
        -- 會隨錨點改變（TOPLEFT 要往右下推 = x 正、y 負；BOTTOMRIGHT 反之）。
        -- 備援值要跟 DB 預設一致，否則哪天真的漏了鍵，會安靜地退回舊版面
        local a = style.stackAnchor or "TOP"
        stack:SetPoint(a, auraButton, a, style.stackX or 0, style.stackY or 4)
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
-- ⚠ x / y **刻意不在簽章裡**：位置是用 container:SetPoint 套的，可以就地重下。
-- 簽章不符就得重建整顆容器，而暴雪的 frame 刪不掉（舊的只是被 Hide、永久留著）——
-- 把位置放進來等於「挪一格就永久多一顆容器 ＋ maxCount 顆 AuraButton」。
-- 其餘欄位是在 AddAuraGroup / initializeFrame 當下烘死的，沒有 setter，只能重建。
-- 黑名單的指紋。
-- ⚠ 一定要排序：pairs 的順序不保證，同一份名單每次算出來的字串可能不同
-- ⇒ 每次套設定都白重建一顆容器（而重建的舊容器刪不掉，只是被藏起來）。
local blScratch = {}
local function BlacklistKey(edb)
    local bl = edb.blacklist
    if type(bl) ~= "table" then return "" end
    wipe(blScratch)
    for id, on in pairs(bl) do
        if on then blScratch[#blScratch + 1] = id end
    end
    table.sort(blScratch)
    return table.concat(blScratch, ",")
end

local function BuildSignature(edb)
    return table.concat({
        tostring(edb.w), tostring(edb.h),
        tostring(edb.maxCount), tostring(edb.perRow), tostring(edb.growth),
        tostring(edb.spacing), tostring(edb.showStack), tostring(edb.stackSize),
        tostring(edb.durationText), tostring(edb.durationThreshold),
        -- ⚠ 層數的位置也要在簽章裡：它是在 initializeFrame 裡 SetPoint 的，
        -- 之後整棵子樹就碰不得了 ⇒ 只能整顆容器重建。漏了這三個鍵的症狀是
        -- 「改了層數位置沒反應，動別的設定才一起生效」（跟 filterMode 同一個坑）
        tostring(edb.stackAnchor), tostring(edb.stackX), tostring(edb.stackY),
        -- ⚠ filterMode 一定要在簽章裡：filter 字串在 AddAuraGroup 宣告時就固定、
        -- 沒有 setter，只能換整顆容器。漏了這個鍵的症狀是「改了下拉沒反應，
        -- 動別的設定才一起生效」。
        tostring(edb.onlyMine), tostring(edb.filterMode), tostring(ns.db.global.font),
        -- 黑名單走 candidateFilters，同樣是宣告時就固定、沒有 setter（見 filterMode）
        BlacklistKey(edb),
    }, "|")
end

------------------------------------------------------------
-- 換人重掃
--
-- 動態 token（target / focus / bossN）在框架保持顯示的情況下換人，容器不會自己重解析。
-- ⚠ 從插件端呼叫 `UpdateAllAuras` **只設得到髒旗標，推不動私有端的處理器**
-- （實測結論）——真正跨得過分界的是 Hide/Show：
-- intrinsic 的 OnShow 跑在安全端，會從那裡重掃一次。
-- 戰鬥中不彈（受保護的 intrinsic 擋 Hide），先設髒旗標記下來，脫戰再補彈一次。
------------------------------------------------------------
local pendingBounce = {}
local pendingHide = {}

local function HideShow(c) c:Hide(); c:Show() end

local function Kick(c)
    pcall(HideShow, c)      -- 現成函式：Kick 落在每次換目標上，別在這裡現配 closure
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
end

-- tag 由呼叫端在建容器時算一次存起來（見 entry.tag），這裡不再現串字串——
-- Bounce 落在每次換目標上，只為了 /muf debug 的一行紀錄而每次組字串不划算。
-- how 也一律用常數，不做串接。
local function Bounce(c, tag)
    if not c then return end
    pendingHide[c] = nil    -- 要彈就不會是要收，兩張延後表不能同時記著同一個容器
    local how
    if InCombatLockdown() then
        pendingBounce[c] = true
        local dirty = c.UpdateAllAuras and pcall(c.UpdateAllAuras, c) or false
        how = dirty and "combat/dirty" or "combat/nodirty"
    else
        pendingBounce[c] = nil
        Kick(c)
        how = "bounce"
    end
    if tag then
        ns.auraPokeLog = ns.auraPokeLog or {}
        ns.auraPokeLog[tag] = how
    end
end

------------------------------------------------------------
-- 「這個元件現在該不該在畫面上」的唯一真相
--
-- ⚠ 容器有好幾條 Show 的路（換目標、進出載具、框重新顯示、脫戰補彈）**全部繞過
-- ns.Refresh 的 enabled 閘門** —— 那些是直接掛的事件與 script handler。少一道判斷，
-- 取消勾選之後只要任何一條路跑過一次，Bounce 的 Show() 就把容器放回來，
-- 而且從此每次都復活 ⇒ 這個元件再也關不掉。所以每一條路都要過這裡。
------------------------------------------------------------
local function IsEnabled(uf, elementName)
    local edb = uf.db and uf.db.elements and uf.db.elements[elementName]
    return edb ~= nil and edb.enabled ~= false
end

-- 收掉容器。
-- ⚠ 戰鬥中不能對 intrinsic 下 Hide：會被判成「Blizzard UI 專屬動作」跳封鎖視窗，
-- 而且那不是 Lua error、pcall 攔不住。所以跟 Bounce 一樣先記下來、脫戰再收。
-- 順手清掉 pendingBounce 是必要的——不清的話脫戰時的補彈會把剛關掉的容器又放回來。
local function Quiet(c)
    if not c then return end
    pendingBounce[c] = nil
    if InCombatLockdown() then
        pendingHide[c] = true
    else
        pendingHide[c] = nil
        pcall(c.Hide, c)
    end
end

ns.Events.Register("PLAYER_REGEN_ENABLED", "auras_bounce_replay", function()
    -- 先收後彈：兩張表互斥（見 Bounce / Quiet），順序只是保險
    for c in pairs(pendingHide) do
        pendingHide[c] = nil
        pcall(c.Hide, c)
    end
    for c in pairs(pendingBounce) do
        pendingBounce[c] = nil
        Kick(c)
    end
end)

-- 容器定位：錨點角依生長方向（往上長要用 BOTTOM 邊釘原點）。
-- 建立時與「簽章相符但位置變了」時共用同一支，兩邊算法不會走鐘。
local function AnchorContainer(container, uf, edb)
    local g = GROWTH[edb.growth or "LRTB"] or GROWTH.LRTB
    local point = (g.growUp and "BOTTOM" or "TOP") .. (g.growLeft and "RIGHT" or "LEFT")
    pcall(container.ClearAllPoints, container)
    pcall(container.SetPoint, container, point, uf, "TOPLEFT", edb.x or 0, edb.y or 0)
end

local function CreateContainer(uf, elementName, edb, filter, cand, style)
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
    AnchorContainer(container, uf, edb)
    -- 建立順序：SetUnit 在 AddAuraGroup 之前、SetEnabled 最後。這是在這台機器上實跑過的。
    -- （別處看到的「unit last」順序是配合分階段建構器的，照搬到這裡會壞。）
    container:SetUnit(uf.unit)
    ApplyFlowLayout(container, spec)

    -- ⚠ 曲線一定要在這裡先建好。initializeFrame 裡呼叫 CreateColor 會撞上
    -- 「被污染時不給存取」的 ColorMixin —— 見 BuildDurationAlphaCurve 上面那段。
    WarmDurationAlphaCurve(style)

    container:AddAuraGroup("main", filter, {
        maxFrameCount = edb.maxCount or 16,
        -- 有些篩選概念沒有對應的 filter token，只能走這裡（引擎端求值，不必讀秘密值）。
        -- nil 就是不過濾，所以模式是 "all" 時直接傳 nil 沒問題。
        candidateFilters = cand,
        layout = {
            elementWidth = edb.w or 20,
            elementHeight = edb.h or 20,
            elementSpacing = edb.spacing or 0,
            lineSpacing = edb.spacing or 0,
        },
        initializeFrame = function(auraButton)
            -- ⚠ 整段要隔離。這個 callback 跑在暴雪 Blizzard_AuraContainerFrameProviders
            -- 的 CreateFrame → CreateFrameBatch 裡面，錯誤逃出去會把**整批** frame 的
            -- 建立一起打斷，不是只有這一顆按鈕。而 12.1 一直在追加「被污染時不給存取」
            -- 的表（ColorMixin 就是一張），初始化裡每個裸的暴雪 API 呼叫都是一顆地雷 ——
            -- InitAuraButton 裡的 SetAuraBorder / SetDurationCooldown / SetIcon /
            -- SetApplicationCount 都還是裸的。
            -- 這道閘的代價是「那顆按鈕外觀不完整」，比「整批光環不出來」便宜太多。
            xpcall(InitAuraButton, ns.ReportError, auraButton, style, edb.w or 20, edb.h or 20)
        end,
    })

    -- ⚠ 絕對不要對 container 掛 script handler：AuraContainer 是 forbidden intrinsic，
    -- `HookScript` 直接丟「cannot replace a forbidden script handler」，而這裡包在 pcall
    -- 裡 ⇒ 整個容器建立失敗、外面看起來只是「光環沒出來」。重新可見時要重下 SetEnabled，
    -- 改掛在 holder（我們自己建的普通 Frame）上。
    if container.SetEnabled then
        pcall(container.SetEnabled, container, true)
    end
    if not holder.__kickHooked then
        holder.__kickHooked = true
        local function OnHolderShow()
            -- 容器建立時框架若還沒可見，SetEnabled 註冊不到光環事件，
            -- 之後就永遠空白 → 真的顯示出來時補踢一次。
            -- ⚠ 一定要走 Bounce 不能直接 Kick：這個 OnShow 是 RegisterUnitWatch 從
            -- **安全端**觸發的，戰鬥中換目標就會在戰鬥中跑到這裡；對 intrinsic 下 Hide()
            -- 會被判成「Blizzard UI 專屬動作」跳封鎖視窗（而且 pcall 攔不住，那不是
            -- Lua error）。Bounce 有戰鬥閘，會改成設髒旗標、脫戰再補彈。
            -- ⚠ 這個 OnShow 落在**每次換目標**上：既不現配空表，也不現串字串。
            -- e.tag 在建容器時就算好了（見 Bounce 上面的說明），直接用。
            if uf.auraContainers then
                -- 表的 key 就是元件名，直接拿來問 DB。這條路是「框重新顯示」
                -- （顯示條件重算、關預覽、/reload），關掉的元件不能跟著被放回來。
                for name, e in pairs(uf.auraContainers) do
                    if IsEnabled(uf, name) then
                        Bounce(e.container, e.tag)
                    else
                        Quiet(e.container)
                    end
                end
            end
        end
        -- 掛勾裡只記帳：OnShow 是從安全端來的，工作丟到下一幀（ns.Defer）
        holder:HookScript("OnShow", function() ns.Defer(OnHolderShow) end)
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
            stackAnchor = edb.stackAnchor, stackX = edb.stackX, stackY = edb.stackY,
            durationThreshold = edb.durationThreshold,
        }
    end
    return {
        borderColor = BUFF_BORDER_COLOR,
        showDuration = edb.durationText and true or false,
        showStack = edb.showStack and true or false,
        stackFontSize = edb.stackSize or 10,
        stackAnchor = edb.stackAnchor, stackX = edb.stackX, stackY = edb.stackY,
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
        local filter, cand = BuildFilter(baseFilter, edb)

        if entry and entry.signature == signature then
            -- 位置不在簽章裡，就地重下（見 BuildSignature 上面的說明）。
            -- ApplySettings 本身有戰鬥閘，所以這裡不會在戰鬥中對 intrinsic 動手。
            AnchorContainer(entry.container, uf, edb)
            entry.container:Show()
            return
        end
        if entry then
            -- 外觀烘死在 AuraButton 裡，簽章變了只能重建（frame 無法銷毀，舊的藏起來）
            entry.container:Hide()
            uf.auraContainers[elementName] = nil
        end

        local ok, container = pcall(CreateContainer, uf, elementName, edb, filter, cand,
                                    BuildStyle(elementName, edb))
        if not ok or not container then
            ns.aurasLastError = tostring(container)
            return
        end
        -- tag 在這裡算一次就好，Bounce 每次換目標都要用（見 Bounce 的說明）
        uf.auraContainers[elementName] = { container = container, signature = signature,
                                           filter = filter, hasCand = cand ~= nil,
                                           tag = uf.unit .. "/" .. elementName }
        uf.elements[elementName] = container
        container:Show()
    end

    -- 換單位主動彈一次（見上面 Bounce 的說明）
    local function Repoke(uf)
        local entry = uf.auraContainers and uf.auraContainers[elementName]
        if not entry then return end
        -- ⚠ 下面四個事件是**直接掛的**，繞過 ns.Refresh 的 enabled 閘門（見 IsEnabled）
        if not IsEnabled(uf, elementName) then
            Quiet(entry.container)      -- 順手自癒：漏網的那次顯示在這裡收掉
            return
        end
        Bounce(entry.container, entry.tag)
    end

    local function Update(uf, edb, bucket)
        Repoke(uf)
    end

    -- 直接掛事件，不只靠 identity 桶派發（框架剛顯示那一瞬間 IsVisible 可能還是 false，
    -- 派發會被閘門擋掉，光環就停在上一個單位）
    ns.Events.Register("PLAYER_TARGET_CHANGED", "auras_" .. elementName .. "_t", function()
        local uf = ns.frames.target
        if uf then Repoke(uf) end
        local tot = ns.frames.targettarget
        if tot then Repoke(tot) end
    end)
    ns.Events.Register("PLAYER_FOCUS_CHANGED", "auras_" .. elementName .. "_f", function()
        local uf = ns.frames.focus
        if uf then Repoke(uf) end
        local ft = ns.frames.focustarget
        if ft then Repoke(ft) end
    end)
    ns.Events.Register("UNIT_TARGET", "auras_" .. elementName .. "_ut", function(unit)
        if unit == "target" and ns.frames.targettarget then Repoke(ns.frames.targettarget) end
        if unit == "focus" and ns.frames.focustarget then Repoke(ns.frames.focustarget) end
    end)
    ns.Events.Register("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "auras_" .. elementName .. "_b", function()
        for i = 1, 5 do
            local uf = ns.frames["boss" .. i]
            if uf then Repoke(uf) end
        end
    end)

    local function Disable(uf)
        local entry = uf.auraContainers and uf.auraContainers[elementName]
        if entry then Quiet(entry.container) end
    end

    -- 容器建立時就綁死了單位（CreateContainer 的 SetUnit），換載具時要重綁。
    -- tag 也一起重算——它是給 /muf debug 認框用的，換了單位要跟著變。
    local function SetUnit(uf, unit)
        local entry = uf.auraContainers and uf.auraContainers[elementName]
        if not entry then return end
        -- 單位照樣重綁（關掉的元件之後重新勾選才會接到正確的單位），但不要彈出來
        pcall(entry.container.SetUnit, entry.container, unit)
        entry.tag = unit .. "/" .. elementName
        if not IsEnabled(uf, elementName) then
            Quiet(entry.container)
            return
        end
        Bounce(entry.container, entry.tag)
    end

    ns.RegisterElement{
        name = elementName,
        order = elementName == "buffs" and 60 or 61,
        buckets = {},        -- 容器自驅動；unitchanged 時換單位
        build = Build,
        update = Update,
        disable = Disable,
        setunit = SetUnit,
    }
end

MakeElement("buffs", "HELPFUL")
MakeElement("debuffs", "HARMFUL")
