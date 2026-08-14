------------------------------------------------------------
-- Stuf: buffgroup / debuffgroup 的 AuraContainer 實作
--
-- 12.1 起，以 index / slot / auraInstanceID 取光環的 API 在 auras 為 secret 時
-- 一律 Lua error，所以 aura.lua 那套「自己掃光環再畫圖示」在戰鬥中會凍結。
-- 這裡改用 AuraContainer：由暴雪自行過濾、排序、建立與排版 AuraButton，插件
-- 完全碰不到底層資料，所以在舊 API 全掛的情況下仍能運作。
--
-- 前半是跟版面無關的部分（能力偵測、AuraButton 外觀、flow layout、倒數格式），
-- 後半把 Stuf 的群組設定翻成它要的形狀。
--
-- 容器是在 aura.lua 的 CreateAuraGroup 裡建的 —— 那正是「群組建好／設定改過」
-- 的時刻，不用從外面猜。原本這是 MiliUI 的兩支掛勾，只能靠輪詢 Stuf.units、
-- 延遲重掃、hook UpdateElementLook 來推測時機，那些全部不需要了。
--
-- /scab           診斷
-- /scab reset     還原 Stuf 原生圖示並停用至下次 /reload
------------------------------------------------------------

local Core = {}
Stuf.AuraCore = Core

local MIN_BUILD = 120100

Core.BORDER_SIZE = 1
Core.TRACK_COLOR = { 0, 0, 0, 1 }
-- 驅散色外框的「消耗色」：掃描用這個顏色由上蓋過彩色底框，看起來就是彩色在減少
Core.SPENT_COLOR = { 0.35, 0.35, 0.35, 1 }
Core.WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
-- 層數預設貼在圖示正上方、水平置中，文字中線壓在上緣所以一半露在圖示外 ——
-- 這樣不會蓋到圖示內容，一眼就看得到。
Core.STACK_ANCHOR = { "CENTER", "TOP", 0, 0 }
-- 倒數數字一律置中：插件的字型設定通常預設在角落（那是給層數用的），
-- 套到倒數上會靠邊，讀起來不直覺。
Core.DURATION_ANCHOR = "CENTER"

------------------------------------------------------------
-- 能力偵測
------------------------------------------------------------
-- AuraContainer / AuraButton 在 12.1 的八個 PTR build 之間改過名也移除過 API，
-- 所以不假設任何呼叫存在：缺一個就讓轉接層整組停用並印一行說明，而不是讓每顆
-- unit frame 各噴一次錯。

local caps = {
    build = select(4, GetBuildInfo()) or 0,
    auraContainer = false,
    addAuraGroup = false,
    addAuraSlot = false,
    flowLayout = false,
    flowAxis = false,
    flowGrowth = false,
}
Core.caps = caps

function Core.Detect()
    if caps.detected then return caps end
    caps.detected = true
    if caps.build < MIN_BUILD then return caps end

    -- CreateFrame 遇到不存在的 intrinsic 會直接 error，所以用 pcall 探一次
    local ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not frame then return caps end

    frame:Hide()
    caps.auraContainer = true
    caps.addAuraGroup = type(frame.AddAuraGroup) == "function"
    caps.addAuraSlot = type(frame.AddAuraSlot) == "function"
    caps.flowLayout = type(frame.SetFlowLayoutAnchorPoint) == "function"
        and type(frame.SetFlowLayoutMaximumLineSize) == "function"
    caps.flowAxis = type(frame.SetFlowLayoutAxis) == "function"
        and type(AnchorUtil) == "table" and type(AnchorUtil.FlowLayoutAxis) == "table"
    caps.flowGrowth = type(frame.SetFlowLayoutGrowthDirection) == "function"
        and type(AnchorUtil) == "table" and type(AnchorUtil.FlowDirection) == "table"
    return caps
end

function Core.Failure()
    if caps.build < MIN_BUILD then
        return ("需要 build %d 以上（目前 %d）"):format(MIN_BUILD, caps.build)
    end
    if not caps.auraContainer then
        return "CreateFrame(\"AuraContainer\", ...) 失敗 —— intrinsic 不存在"
    end
    if not caps.addAuraGroup then
        return "AuraContainer:AddAuraGroup 不存在 —— group API 已改名或移除"
    end
    return nil
end

------------------------------------------------------------
-- 倒數格式
------------------------------------------------------------
-- 預設走 SecondsFormatter，而它的 Enum.SecondsFormatterAbbreviation 只有
-- None / Truncate / OneLetter，三種在中文全都輸出「秒」—— 設計上沒有無單位的
-- 出口。改用 NumericRuleFormatter，它的 breakpoint 支援 step + rounding：
--   step=1       取整到 1 的倍數（剩餘秒數是浮點數，不取整畫面會一直跳）
--   rounding=Up  倒數慣例：還剩 0.3 秒要顯示 1 而不是 0
--   format="%d"  純數字，沒有任何單位
local DurationFormatter
do
    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
        local ok, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
        if ok and formatter then
            local R = Enum and Enum.NumericRuleFormatRounding
            local added = pcall(formatter.AddBreakpoint, formatter, {
                threshold = 0,
                step = 1,
                rounding = R and R.Up or nil,
                format = "%d",
            })
            if added then DurationFormatter = formatter end
        end
    end
end
Core.DurationFormatter = DurationFormatter

-- 時間縮寫版：長效光環顯示 3326 秒沒有意義，用暴雪的 SecondsFormatter 讓它
-- 變成「55分」這種。代價是會帶單位（中文的 OneLetter 就是「分」「秒」），
-- 但對頭像上那種動輒數十分鐘的光環，帶單位反而好讀。
local AbbrevDurationFormatter
if C_StringUtil and C_StringUtil.CreateSecondsFormatter then
    local ok, formatter = pcall(C_StringUtil.CreateSecondsFormatter)
    if ok and formatter then
        local A = Enum and Enum.SecondsFormatterAbbreviation
        if A and A.OneLetter and formatter.SetDefaultAbbreviation then
            pcall(formatter.SetDefaultAbbreviation, formatter, A.OneLetter)
        end
        local R = Enum and Enum.SecondsFormatterRounding
        if R and R.Truncate and formatter.SetRounding then
            pcall(formatter.SetRounding, formatter, R.Truncate)
        end
        -- 只留一個單位。預設會輸出兩段（「1分30秒」），在小圖示上太長 ——
        -- 設成 1 之後大的顯示「49分」、小的顯示「31秒」。
        if formatter.SetDesiredUnitCount then
            pcall(formatter.SetDesiredUnitCount, formatter, 1)
        end
        AbbrevDurationFormatter = formatter
    end
end
Core.AbbrevDurationFormatter = AbbrevDurationFormatter

------------------------------------------------------------
-- 倒數顯示門檻
------------------------------------------------------------
-- 「剩餘時間低於 N 秒才顯示秒數」在 Lua 裡做不到 —— 讀不到剩餘時間。
-- 但可以把判斷交出去：SetDurationText 的 textColor 收一條 ColorCurve 加一個
-- property，暴雪會拿 property（例如 RemainingDuration）去取樣曲線來決定文字
-- 顏色。ColorCurve 的點是 colorRGBA，含 alpha —— 所以做一條「門檻以上 alpha 0、
-- 以下 alpha 1」的曲線，等於「只在最後 N 秒顯示數字」，而我們完全不需要知道
-- 剩幾秒。這也是 SetDurationText 會在 fontString 上蓋 SecretAspect.Alpha 的原因。
--
-- ColorCurve 沒有 SetType（不像 Curve 有 Step），只能線性內插，所以用兩個
-- 極接近的點做出等效的階梯。
local function BuildDurationAlphaCurve(threshold, r, g, b)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end

    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end

    r, g, b = r or 1, g or 1, b or 1
    local visible = CreateColor(r, g, b, 1)
    local hidden = CreateColor(r, g, b, 0)

    -- x 是剩餘秒數：0 → 門檻 之間看得見，超過門檻立刻透明
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
-- 字型
------------------------------------------------------------
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- fontSpec 讓轉接層把自己插件的字型設定攤平成統一形狀：
--   { file, size, outline, point, x, y, r, g, b }
-- 全部欄位都可省略，缺的用 iconHeight 推算或給預設值。
function Core.ApplyFont(fontString, fontSpec, owner, iconHeight, forcePoint)
    fontSpec = fontSpec or {}

    local file = fontSpec.file
    if not file and LSM and type(fontSpec.media) == "string" then
        file = LSM:Fetch("font", fontSpec.media, true)
    end
    file = file or (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT

    -- 沒有設定就依圖示高度推一個，別寫死一個對小圖示過大的字級
    local size = fontSpec.size or math.max(8, math.floor((iconHeight or 20) * 0.55))
    local outline = fontSpec.outline or "OUTLINE"
    if outline == "None" then outline = "" end

    -- forcePoint 可以是字串（文字與擁有者用同一個錨點），也可以是
    -- { point, relativePoint, x, y } —— 後者才表達得出「文字的 CENTER 對齊
    -- 按鈕的 TOP」這種一半露在外面的效果。
    local point, relativePoint, x, y
    if type(forcePoint) == "table" then
        point, relativePoint = forcePoint[1], forcePoint[2] or forcePoint[1]
        x, y = forcePoint[3] or 0, forcePoint[4] or 0
    elseif type(forcePoint) == "string" then
        point, relativePoint, x, y = forcePoint, forcePoint, 0, 0
    else
        point = fontSpec.point or "CENTER"
        relativePoint = point
        x, y = fontSpec.x or 0, fontSpec.y or 0
    end

    if file then
        fontString:SetFont(file, size, outline)
    end
    fontString:SetTextColor(fontSpec.r or 1, fontSpec.g or 1, fontSpec.b or 1)
    fontString:ClearAllPoints()
    fontString:SetPoint(point, owner, relativePoint, x, y)
end

------------------------------------------------------------
-- AuraButton 外觀
------------------------------------------------------------
-- 一定要在 initializeFrame 裡呼叫：PTR 5 起 auras 一變 secret 整個 AuraButton
-- 就 forbidden，而那個狀態正是在該 callback 回傳「之後」才套上去的。
--
-- 三層結構（抄自 Cell 的 I.CreateAura_BorderIcon）：
--   底層  border 貼圖（滿格）           靜態外框／軌道
--   中層  Cooldown 或 StatusBar          倒數，交出 widget 讓暴雪驅動
--   上層  iconFrame（內縮、level+1）     圖示、秒數、層數
--
-- 外框倒數的訣竅就在層級：Cooldown 其實蓋滿整格，但圖示往內縮又疊在它上面，
-- 所以掃描只從邊緣那一圈露出來，看起來就是外框在順時針消退。
-- 長條式遮罩則相反，要蓋在圖示「之上」。
--
-- style 欄位：
--   durationStyle  "bar" = 由上往下的深色遮罩；否則 = 外框 swipe
--   borderColor    swipe 的顏色（bar 樣式時改當外框顏色）
--   dispelBorder   true = 外框依驅散類型上色（減益用）
--   showDuration   顯示剩餘秒數
--   showStack      顯示層數
--   durationFont / stackFont  傳給 Core.ApplyFont 的 fontSpec
--   durationAnchor 覆寫秒數錨點（長條上通常要置中）
--   durationThreshold  只在剩餘秒數低於這個值時才顯示數字（nil = 一直顯示）
--   durationFormat "abbrev" = 時間縮寫（55m）；否則純秒數
function Core.InitAuraButton(auraButton, style, sizeW, sizeH)
    sizeH = sizeH or sizeW
    local border = Core.BORDER_SIZE

    auraButton:SetIgnoringChildrenForBounds(true)
    auraButton:SetSize(sizeW, sizeH)

    -- 底層
    local borderTex = auraButton:CreateTexture(nil, "BACKGROUND")
    borderTex:SetAllPoints(auraButton)
    auraButton.Border = borderTex

    if style.dispelBorder and auraButton.SetAuraBorder then
        -- 驅散色留給「底框」，讓掃描用灰色由上蓋過去 —— 灰色越蓋越多、
        -- 彩色越來越少，視覺上就是彩色外框在倒數。
        --
        -- 為什麼不直接讓掃描是彩色的（那才是 Cell 的做法）：SetSwipeColor 要
        -- 逐光環給 RGB，而 AuraButton 不告訴我們驅散類型；SetAuraBorder 只能
        -- 替「貼圖」上色，管不到 Cooldown 的掃描。把兩層對調就繞過了這個限制。
        borderTex:SetColorTexture(1, 1, 1, 1)
        auraButton:SetAuraBorder(borderTex, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle
                and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or nil,
            showIcon = false,
            showAlways = true,
        })
    else
        -- 增益沒有 dispelName，走 PreserveAsset 會讓每一顆都變預設紅框。
        -- 靜態框的顏色取決於動畫樣式，兩者不能同色否則看不出變化：
        --   swipe → 這層當黑色軌道，讓上面的彩色掃描消退時露出來
        --   bar   → 掃描沒在用 borderColor，這層就拿它當外框顏色
        local c = (style.durationStyle == "bar" and style.borderColor) or Core.TRACK_COLOR
        borderTex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end

    -- 中層：交出 widget 讓暴雪驅動，不是拿回秒數 ——
    -- SetDurationCooldown / SetDurationBar 會蓋上 SecretAspect，之後那個值
    -- 對插件就是不可讀的。
    local cooldown
    if style.durationStyle == "bar" and auraButton.SetDurationBar then
        local bar = CreateFrame("StatusBar", nil, auraButton)
        bar:SetAllPoints(auraButton)
        bar:SetOrientation("VERTICAL")
        bar:SetReverseFill(true)
        bar:SetStatusBarTexture(Core.WHITE_TEXTURE)
        bar:GetStatusBarTexture():SetVertexColor(0, 0, 0, 0.65)
        auraButton.DurationBar = bar
        auraButton:SetDurationBar(bar)
    elseif auraButton.SetDurationCooldown then
        -- 一定要帶 CooldownFrameTemplate：交給 SetDurationCooldown 是「暴雪
        -- 驅動」，少了 template 提供的內容它不會動。
        cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        cooldown:SetAllPoints(auraButton)
        cooldown:SetSwipeTexture(Core.WHITE_TEXTURE)

        if style.dispelBorder then
            -- 底框是驅散色，掃描用灰色「吃掉」它。SetReverse 讓掃描覆蓋的是
            -- 已經過去的那段，所以灰色會越來越多。
            local c = style.spentColor or Core.SPENT_COLOR
            cooldown:SetSwipeColor(c[1], c[2], c[3])
            cooldown:SetReverse(true)
        else
            -- 一般情況：掃描本身就是彩色的，底下是黑色軌道
            local c = style.borderColor or { 1, 1, 1, 1 }
            cooldown:SetSwipeColor(c[1], c[2], c[3])
        end

        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetDrawSwipe(true)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown.noCooldownCount = true   -- 擋掉 OmniCC 之類的外掛數字
        auraButton.Cooldown = cooldown
        auraButton:SetDurationCooldown(cooldown)
    end

    -- 上層
    local iconFrame = CreateFrame("Frame", nil, auraButton)
    iconFrame:SetPoint("TOPLEFT", auraButton, "TOPLEFT", border, -border)
    iconFrame:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -border, border)
    if cooldown then
        iconFrame:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    end
    auraButton.IconFrame = iconFrame

    -- 遮罩要蓋在圖示「上面」才叫遮罩
    if auraButton.DurationBar then
        auraButton.DurationBar:SetFrameLevel(iconFrame:GetFrameLevel() + 1)
    end

    -- 文字再獨立一層疊在最上面。層級順序是：
    --   外框 → 掃描 → 圖示 → 遮罩 → 文字
    -- 遮罩必須在圖示之上（不然遮不到），文字又必須在遮罩之上（不然被蓋住），
    -- 所以文字不能跟圖示同一層。
    local topLevel = iconFrame:GetFrameLevel()
    if auraButton.DurationBar then
        topLevel = math.max(topLevel, auraButton.DurationBar:GetFrameLevel())
    end
    local textFrame = CreateFrame("Frame", nil, auraButton)
    textFrame:SetAllPoints(auraButton)
    textFrame:SetFrameLevel(topLevel + 1)
    auraButton.TextFrame = textFrame

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconFrame)
    icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    auraButton.Icon = icon
    auraButton:SetIcon(icon)

    -- 文字掛在 iconFrame 上，掛在 auraButton 上會被掃描蓋住
    if style.showDuration then
        local duration = textFrame:CreateFontString(nil, "OVERLAY")
        Core.ApplyFont(duration, style.durationFont, iconFrame, sizeH,
            style.durationAnchor or Core.DURATION_ANCHOR)
        auraButton.Duration = duration
        if auraButton.SetDurationText then
            -- style.durationFormat == "abbrev" 用時間縮寫（55m），否則純數字
            local formatter = (style.durationFormat == "abbrev" and AbbrevDurationFormatter)
                or DurationFormatter
            local options = formatter and { textFormatter = formatter } or {}

            -- 只在最後 N 秒顯示數字（例如大地之盾那種一小時的長 buff，
            -- 整場都掛著 3599 沒有意義）
            if style.durationThreshold and Enum and Enum.DurationTextBindingProperty then
                local f = style.durationFont or {}
                local curve = BuildDurationAlphaCurve(style.durationThreshold, f.r, f.g, f.b)
                if curve then
                    options.textColor = {
                        curve = curve,
                        property = Enum.DurationTextBindingProperty.RemainingDuration,
                    }
                end
            end

            auraButton:SetDurationText(duration, next(options) and options or nil)
        end
    end

    if style.showStack then
        local stack = textFrame:CreateFontString(nil, "OVERLAY")
        -- 錨到 auraButton 而不是 iconFrame：iconFrame 內縮了 border，
        -- 要貼齊圖示外緣得用按鈕本身。
        Core.ApplyFont(stack, style.stackFont, auraButton, sizeH,
            style.stackAnchor or Core.STACK_ANCHOR)
        auraButton.Count = stack
        if auraButton.SetApplicationCount then
            auraButton:SetApplicationCount(stack)
        end
    end
end

------------------------------------------------------------
-- flow layout
------------------------------------------------------------
-- 排版方向是「容器層級」的設定，不是 group 的選項。
-- 預設是 Horizontal 軸、錨點 TOPLEFT、往 Right / Down 長。
--
-- maximumLineSize 是主軸上的「像素預算」不是圖示顆數 —— 傳顆數會讓每顆圖示
-- 都超出上限，一顆一行變成垂直堆疊。
-- flow 的錨點是「圖示從容器的哪個角開始排」，跟容器自己貼在哪（spec.point）
-- 是兩回事。往上長就要從下緣起算，否則圖示會往反方向長出去。
local function DeriveFlowAnchor(spec)
    if spec.flowPoint then return spec.flowPoint end
    local vertical = spec.growUp and "BOTTOM" or "TOP"
    local horizontal = spec.growLeft and "RIGHT" or "LEFT"
    return vertical .. horizontal
end

function Core.ApplyFlowLayout(container, spec)
    if container.SetFlowLayoutAnchorPoint then
        container:SetFlowLayoutAnchorPoint(DeriveFlowAnchor(spec))
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
        local step = (spec.vertical and spec.sizeH or spec.sizeW) + (spec.spacing or 0)
        container:SetFlowLayoutMaximumLineSize(spec.perLine * step)
    end
end

------------------------------------------------------------
-- 建立容器
------------------------------------------------------------
-- spec 由轉接層組好，欄位：
--   host        容器的 parent（通常是插件的指示器層，不要用 secure frame）
--   point / relativeTo / relativePoint / x / y   錨定
--   unit, filter, groupKey
--   sizeW, sizeH, max, perLine, spacing
--   vertical / growLeft / growUp                 生長方向
--   candidateFilters                             includeSpellIDs 等
--   style                                        傳給 InitAuraButton
-- 回傳 container 或 nil, errorMessage
function Core.CreateContainer(spec)
    local container = CreateFrame("AuraContainer", nil, spec.host, "CustomAuraContainerTemplate")
    container:SetSize(1, 1)
    container:SetFrameLevel(spec.host:GetFrameLevel() + (spec.levelOffset or 5))
    container:SetPoint(spec.point, spec.relativeTo or spec.host, spec.relativePoint or spec.point,
        spec.x or 0, spec.y or 0)
    container:SetUnit(spec.unit)

    Core.ApplyFlowLayout(container, spec)

    -- 欄位名稱取自 Blizzard_CustomAuraContainer.lua 的 ValidateAuraGroupLayoutOptions。
    -- 注意 layout 是巢狀在 options 底下，而且未知的鍵會被靜靜丟掉（不報錯也不生效）。
    container:AddAuraGroup(spec.groupKey, spec.filter, {
        maxFrameCount = spec.max,
        candidateFilters = spec.candidateFilters,
        layout = {
            elementWidth = spec.sizeW,
            elementHeight = spec.sizeH,
            elementSpacing = spec.spacing or 0,
            lineSpacing = spec.lineSpacing or spec.spacing or 0,
        },
        initializeFrame = function(auraButton)
            Core.InitAuraButton(auraButton, spec.style or {}, spec.sizeW, spec.sizeH)
        end,
    })

    container.__unit = spec.unit
    container:Hide()
    return container
end

------------------------------------------------------------
-- Stuf 轉接層
------------------------------------------------------------
-- 增益外框：偏深的綠，太亮會在小圖示上蓋過圖示本身
local BUFF_BORDER_COLOR = { 0, 0.55, 0.15, 1 }

-- tempenchant（武器附魔）沒有對應的 aura filter，要走 AddItemEnchantment 另外
-- 處理，所以不在這裡；dispellicon 只畫一顆，留給 aura.lua 自己的路徑。
local DISPLAYS = {
    buffgroup = {
        filter = "HELPFUL",
        style = {
            borderColor = BUFF_BORDER_COLOR,
            showDuration = true,
            showStack = true,
            -- 頭像上的光環動輒數十分鐘，純秒數讀不了
            durationFormat = "abbrev",
        },
    },
    debuffgroup = {
        filter = "HARMFUL",
        style = {
            dispelBorder = true,      -- 依驅散類型上色
            showDuration = true,
            showStack = true,
            durationFormat = "abbrev",
        },
    },
}

local attached = setmetatable({}, { __mode = "k" })  -- [uf] = { [element] = container }
local diag = { skips = {} }
local enabled = false

local function Skip(reason)
    diag.skips[reason] = (diag.skips[reason] or 0) + 1
end

-- Stuf 的字型設定散在 db 的多個鍵上，攤平成 Core.ApplyFont 要的 fontSpec
local function ReadStackFont(db, iconWidth)
    return {
        media = db.counttfont,
        size = db.counttfontsize or db.fontsize
            or (iconWidth and iconWidth > 2 and math.floor(iconWidth * 0.6 + 0.5)) or nil,
        outline = db.counttfontflags ~= "None" and db.counttfontflags or nil,
        r = db.counttfontcolor and db.counttfontcolor.r,
        g = db.counttfontcolor and db.counttfontcolor.g,
        b = db.counttfontcolor and db.counttfontcolor.b,
    }
end

-- 把 Stuf 的 growth 字串翻成 flow layout 的方向。
-- GrowthBreakdown 回傳 d1..d4 與 hdir/vdir：d1 是主軸第一個方向。
local function ReadGrowth(db)
    local breakdown = Stuf.GrowthBreakdown
    if not breakdown then return false, false, false end

    local d1, _, d3 = breakdown(db.growth)
    local horizontalFirst = (d1 == "LEFT" or d1 == "RIGHT")

    local vertical = not horizontalFirst
    local growLeft = (horizontalFirst and d1 == "RIGHT") or (not horizontalFirst and d3 == "RIGHT")
    local growUp = (horizontalFirst and d3 == "BOTTOM") or (not horizontalFirst and d1 == "BOTTOM")

    return vertical, growLeft, growUp
end

local function ReadLayout(db)
    local w, h = db.w, db.h
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
        return nil, ("尺寸不合用 w=%s h=%s"):format(tostring(w), tostring(h))
    end

    local vertical, growLeft, growUp = ReadGrowth(db)
    return {
        x = db.x or 0,
        y = db.y or 0,
        sizeW = w,
        sizeH = h,
        max = (db.cols or 1) * (db.rows or 1),
        perLine = vertical and (db.rows or 1) or (db.cols or 1),
        spacing = db.spacing or 0,
        lineSpacing = db.vspacing or 0,
        vertical = vertical,
        growLeft = growLeft,
        growUp = growUp,
        -- Stuf 的「只顯示可驅散」對應 RAID filter，跟它自己 f.filter 的用法一致
        curable = db.curable and true or false,
    }
end

-- 容器建好之後外觀就烘死了（AuraButton 在 initializeFrame 之外是 forbidden），
-- 設定改了只能重建。但 frame 無法銷毀，所以只有簽章變了才重建。
local function BuildSignature(element, layout, db)
    local cc = db.counttfontcolor
    return table.concat({
        element,
        tostring(layout.x), tostring(layout.y),
        tostring(layout.sizeW), tostring(layout.sizeH),
        tostring(layout.max), tostring(layout.perLine),
        tostring(layout.spacing), tostring(layout.lineSpacing),
        tostring(db.growth), tostring(layout.curable),
        tostring(db.counttfont), tostring(db.counttfontsize), tostring(db.counttfontflags),
        -- 顏色也要進簽章：字型設定烘在 AuraButton 裡，只改顏色不重建就不會生效
        tostring(cc and cc.r), tostring(cc and cc.g), tostring(cc and cc.b),
    }, "|")
end

------------------------------------------------------------
-- 建立／還原
------------------------------------------------------------
-- 由 aura.lua 的 CreateAuraGroup 呼叫。回傳 true 表示接管成功，呼叫端就把
-- Stuf 自己的群組關掉（Stuf:SuppressElement）。
function Core.Attach(unit, uf, element, db)
    local display = DISPLAYS[element]
    if not display or not enabled then return false end

    local layout, why = ReadLayout(db)
    if not layout then
        Skip(element .. "：" .. why)
        return false
    end

    local signature = BuildSignature(element, layout, db)
    local perFrame = attached[uf]
    local existing = perFrame and perFrame[element]
    if existing then
        if existing.__signature == signature then
            -- 外觀沒變，只要確認指向的單位還對
            if unit and unit ~= existing.__unit then
                existing:SetUnit(unit)
                existing.__unit = unit
            end
            existing:Show()
            return true
        end
        existing:Hide()
        perFrame[element] = nil
    end

    local style = {}
    for k, v in pairs(display.style) do style[k] = v end
    style.stackFont = ReadStackFont(db, layout.sizeW)
    style.durationFont = style.stackFont

    -- 容器不能 parent 到 Stuf 的群組：那個群組等一下要整個 Hide，而隱藏會往下
    -- 傳給所有子物件，容器會跟著一起不見。改掛在自己的中介 frame 上。
    local holder = uf.__auraHost
    if not holder then
        holder = CreateFrame("Frame", nil, uf)
        holder:SetAllPoints(uf)
        uf.__auraHost = holder
    end
    local group = uf[element]
    if group then
        -- 蓋過 Stuf 的光環群組，免得圖示被壓在底下
        holder:SetFrameLevel(math.max(holder:GetFrameLevel(), group:GetFrameLevel() + 1))
    end

    -- 容器會自動長大以容納圖示，所以「用哪個角釘住」決定它往哪邊長。
    -- Stuf 的群組是 2x2 的點，圖示靠位移擺出去；往上生長時內容在原點「之上」，
    -- 所以容器要用 BOTTOM 邊釘在同一個原點，才會往上長。
    local anchorPoint = (layout.growUp and "BOTTOM" or "TOP")
        .. (layout.growLeft and "RIGHT" or "LEFT")

    local ok, container = pcall(Core.CreateContainer, {
        host = holder,
        point = anchorPoint,
        -- 原點永遠是 Stuf 的 TOPLEFT + (x, y)，跟 Stuf 自己的 SetPoint 一致
        relativeTo = uf,
        relativePoint = "TOPLEFT",
        x = layout.x,
        y = layout.y,
        unit = unit,
        filter = layout.curable and (display.filter .. "|RAID") or display.filter,
        groupKey = "Stuf" .. element,
        sizeW = layout.sizeW,
        sizeH = layout.sizeH,
        max = layout.max,
        perLine = layout.perLine,
        spacing = layout.spacing,
        lineSpacing = layout.lineSpacing,
        vertical = layout.vertical,
        growLeft = layout.growLeft,
        growUp = layout.growUp,
        style = style,
    })
    if not ok then
        Skip(element .. "：建立失敗")
        diag.err = container
        return false
    end

    container.__signature = signature
    if not perFrame then
        perFrame = {}
        attached[uf] = perFrame
    end
    perFrame[element] = container
    container:Show()
    return true
end

-- 群組被關掉（db.hide）或進設定模式時把容器收起來。
-- 只 Hide 不丟掉參照 —— frame 無法銷毀，丟掉的話下次 Attach 只能再建一個新的，
-- 反覆開關就一直漏。留著的話簽章沒變就直接 Show 回來。
function Core.Detach(uf, element)
    local perFrame = attached[uf]
    local container = perFrame and perFrame[element]
    if container then container:Hide() end
end

------------------------------------------------------------
-- 換目標／焦點
------------------------------------------------------------
-- unit token 沒變但指向的對象換了時，容器不會自己重掃 —— Coolinator 也是靠
-- 這個 API 處理換目標的。
local function RepointAll()
    if not enabled then return end
    for uf, containers in pairs(attached) do
        local unit = uf.unit
        for _, container in pairs(containers) do
            if unit and unit ~= container.__unit then
                container:SetUnit(unit)
                container.__unit = unit
            end
            if container.UpdateAllAuras then
                pcall(container.UpdateAllAuras, container)
            end
        end
    end
end

-- 能力偵測在載入時就做完：CreateAuraGroup 最早會在登入建立框架時呼叫 Attach，
-- 那時 enabled 必須已經定案。AddOnInit 只負責把偵測失敗的原因印出來（載入期
-- 太早，print 還進不了聊天視窗）。
Core.Detect()
Stuf:AddOnInit(function()
    local failure = Core.Failure()
    if failure then
        print("|cff00ff00Stuf|r: 光環容器停用：" .. failure .. "（改用原生圖示，戰鬥中會凍結）")
    end
end)
enabled = (Core.Failure() == nil)

Stuf:AddEvent("PLAYER_TARGET_CHANGED", RepointAll)
Stuf:AddEvent("PLAYER_FOCUS_CHANGED", RepointAll)
Stuf:AddEvent("GROUP_ROSTER_UPDATE", RepointAll)

------------------------------------------------------------
-- 診斷
------------------------------------------------------------
SLASH_STUFAURACONTAINER1 = "/scab"
SlashCmdList.STUFAURACONTAINER = function(msg)
    local function line(k, v) print("|cff00ff00Stuf|r: " .. k .. "：" .. tostring(v)) end

    if strtrim(msg or ""):lower() == "reset" then
        enabled = false
        for uf, containers in pairs(attached) do
            for element, container in pairs(containers) do
                container:Hide()
                Stuf:SuppressElement(uf[element], false)
            end
        end
        return line("光環容器", "已還原原生圖示，停用至下次 /reload")
    end

    line("啟用中", enabled)
    line("build", caps.build)
    local failure = Core.Failure()
    if failure then line("能力偵測", failure) end

    local n = 0
    for _, containers in pairs(attached) do
        for element in pairs(containers) do n = n + 1 end
    end
    line("已接管的群組數", n)
    if diag.err then line("最後一次建立錯誤", diag.err) end
    for reason, count in pairs(diag.skips) do line("略過", reason .. " x" .. count) end
end
