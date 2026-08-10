------------------------------------------------------------
-- MiliUI: AuraContainer 共用核心
--
-- 12.1 起，以 index / slot / auraInstanceID 取光環的 API 在 auras 為 secret 時
-- 一律 Lua error，所以任何自己讀光環來畫圖示的插件都會在戰鬥中凍結。
-- 補救方式一律相同：在插件原本的光環群組上掛一個 AuraContainer 接管顯示，
-- 由暴雪自行過濾、排序、建立與排版 AuraButton —— 插件完全碰不到底層資料，
-- 所以在舊 API 全掛的情況下仍能運作。
--
-- 這個檔案放「跟目標插件無關」的部分：能力偵測、AuraButton 外觀、flow layout
-- 對應、倒數格式。各插件的轉接層（Stuf_AuraContainer）只負責讀自己的設定，然後呼叫這裡。
--
-- Cell 的橋接（Fix/Cell_AuraContainer.lua）已於 2026-08-11 移除：Cell 12.1 改寫後
-- 自帶 AuraContainer（RaidFrames/RaidDebuffContainer.lua），橋接與它在戰鬥中雙重
-- 繪製同一批光環（樣式還不同），故整支退場。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

MiliUI_AuraContainerCore = {}
local Core = MiliUI_AuraContainerCore

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
    shouldAurasBeSecret = type(C_Secrets) == "table"
        and type(C_Secrets.ShouldAurasBeSecret) == "function",
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

function Core.AurasAreSecret()
    if caps.shouldAurasBeSecret then
        return C_Secrets.ShouldAurasBeSecret() and true or false
    end
    -- 退路刻意保守：戰鬥中不一定代表 auras 受限，會過度觸發但不會漏觸發。
    return InCombatLockdown() and true or false
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
