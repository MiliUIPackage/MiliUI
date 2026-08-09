------------------------------------------------------------
-- MiliUI: Cell 光環圖示 ← AuraContainer 補救
--
-- 12.1 起，以 index / slot / auraInstanceID 取光環的 API 在
-- auras 為 secret 時（戰鬥、encounter、M+、PvP）一律 Lua error。
-- Cell 走 GetAuraSlots + GetAuraDataBySlot，所以它的增益與減益圖示
-- 都會凍結在進戰鬥當下的狀態。
--
-- 本模組不試圖解凍 Cell。改為在每顆 unit button 上掛一個
-- AuraContainer，auras 為 secret 時顯示它、把 Cell 自己的圖示
-- 淡出，恢復時反向。AuraContainer 由暴雪自行過濾、排序、建立與
-- 排版 AuraButton，插件完全碰不到底層光環資料 —— 這正是它在舊
-- API 全掛的情況下還能運作的原因。
--
--
-- ⚠ 這支「不」使用 Fix/AuraContainerCore.lua，而是自己保留一份 AuraButton 建構、
--   字型套用與 flow layout 邏輯（刻意的：這支已在 PTR 驗證過，不想為了收斂而
--   冒回歸風險）。因此**任何視覺上的共通修改都要在兩個地方各改一次**：
--     Fix/Cell_AuraContainer.lua（本檔）
--     Fix/AuraContainerCore.lua（Stuf 那支用的）
--   已經漏過一次（驅散色與掃描對調只改了 Core，Cell 沒吃到）。
-- /cab            診斷與 API 能力報告
-- /cab list       列出 Cell 版面裡所有自訂指示器（型別、追蹤法術、是否鏡射）
-- /cab where      倒出某顆按鈕上所有容器的位置與大小，用來指認畫面上的東西
-- /cab test       在非戰鬥時強制顯示，用來確認錨點與圖示大小
-- /cab spell <id> 查某顆法術在戰鬥中會不會變 secret，以及有沒有被鏡射
-- /cab reset      還原 Cell 圖示並停用本模組至下次 /reload
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

local BRIDGE_MIN_BUILD = 120100

-- 外框分兩層，缺一個動畫就看不出來：
--   TRACK  底下那圈「軌道」，深色，永遠滿格
--   掃描   上面那圈會消退的顏色，取自 DISPLAYS 的 borderColor
-- Cell 在 duration > 0 時是把靜態 border 藏起來、只留掃描；我沒辦法知道光環有
-- 沒有持續時間，所以改成讓兩層顏色對比 —— 效果一樣看得出消退，永久光環則會
-- 停在滿格的掃描色。
--（踩過的坑：兩層都白色時掃描被靜態框完全遮蔽，看起來像「完全沒有動畫」。）
local TRACK_COLOR = { 0, 0, 0, 1 }
-- 暴雪預設的光環倒數走 SecondsFormatter，一定會帶單位 ——
-- Abbreviation 只有 None(0) / Truncate(1) / OneLetter(2) 三種，中文全都是「秒」，
-- 沒有「純數字」的出口。
--
-- 倒數文字要「純數字不帶單位」。
--
-- 預設走 SecondsFormatter，而它的 Enum.SecondsFormatterAbbreviation 只有
-- None(0) / Truncate(1) / OneLetter(2)，三種在中文全都輸出「秒」—— 設計上
-- 沒有無單位的出口。
--
-- 解法是換掉 formatter 本身：AbbreviatedNumberFormatter 的職責是「數字縮寫」
--（123456 → "123k"），91 這種值原樣輸出 "91"，永遠不會加時間單位。
-- 文件對 textFormatter 的說明就是「用來顯示剩餘時間的 formatter」，所以直接
-- 換掉它即可，不需要動 textFormat/components。
--（繞過的彎路：textFormat.components 是結構陣列而非列舉陣列，元素要帶
--  property + formatter，但即使照著填仍會被驗證吃掉變成 0 個，於是回報
--  「expected 0 format components for 1 placeholders」。textFormatter 這條路
--  單純得多。）
-- 用 NumericRuleFormatter 而不是 AbbreviatedNumberFormatter：後者不會取整，
-- 剩餘秒數是浮點數（5.15、1410.065），畫面上會一直跳小數。
-- NumericRuleFormatBreakpoint 支援 step + rounding：
--   threshold=0  這條規則從 0 開始適用（也就是全部）
--   step=1       輸入先取整到 1 的倍數
--   rounding=Up  無條件進位 —— 倒數慣例是「還剩 1 秒」顯示 1 而不是 0
--   format="%d"  純數字，沒有任何單位
local DurationFormatter
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
local DEFAULT_BORDER_COLOR = { 1, 1, 1, 1 }
-- 增益用綠色：左右兩側（自身減傷／隊友減傷）都是 buff
-- 增益外框：偏深的綠，太亮會在小圖示上蓋過圖示本身
local BUFF_BORDER_COLOR = { 0, 0.55, 0.15, 1 }
-- 驅散色外框的「消耗色」：掃描用這個顏色蓋過彩色底框
local SPENT_COLOR = { 0.35, 0.35, 0.35, 1 }

------------------------------------------------------------
-- 顯示定義
------------------------------------------------------------
-- 每一項 = 一個 AuraContainer（各自獨立，這樣錨點才能各自對齊 Cell 的
-- 對應指示器；同一個容器裡的多個 group 會被依加入順序連續排版）。
--
-- anchorTo：借用哪個 Cell 指示器的位置與圖示大小。依序嘗試，取第一個
-- 已經被 Cell 排版過的。
--
-- candidateFilters：由 buildFilters() 在掛載時計算，這樣才能讀到 Cell 當
-- 下的設定。完整可用欄位見 Blizzard_CustomAuraContainer.lua 的
-- ValidateCandidateFilters —— includeSpellIDs / excludeSpellIDs（都是
-- [spellID]=true 的對照表）、includeDispelTypes / excludeDispelTypes、
-- maxDuration，以及 isStealable / isBossAura / isFromPlayerOrPlayerPet 等布林。
--
-- 但 spellID 過濾有一條關鍵限制（見該檔第 78 行的註解）：光環是 secret 時
-- 只允許「友方單位上的增益」與「敵方單位上的減益」。也就是說團隊框架上的
-- 減益**不能**用 spellID 過濾（防自動化），只有增益可以。被標為 non-secret
-- 的法術則不受限（12.1 PTR 6 放寬）。
--
-- 所以：
--   增益 → 可以完整複製 Cell 的策展清單（等 Cell 願意暴露清單，或自己填）
--   減益 → 黑名單只對 non-secret 的減益生效；secret 的只能靠 dispel 類型、
--          maxDuration、布林這些非 ID 條件過濾
-- 前向宣告：下面的 buildFilters 閉包會用到這兩個，但它們的定義在後面。
-- 沒有這行的話閉包會把它們當成全域變數查，執行時拿到 nil。
local BuildCellCuratedList, MergeSpellIDMaps

local DISPLAYS = {
    {
        key = "debuffs",
        filter = "HARMFUL",
        anchorTo = { "debuffs" },
        showDuration = true,
        dispelBorder = true,   -- 依驅散類型上色
        -- Cell 的減益黑名單是公開的（Cell.vars.debuffBlacklist，[id]=true）。
        -- 對 secret 減益無效（見上），但 non-secret 的會被正確濾掉。
        buildFilters = function()
            local blacklist = _G.Cell and _G.Cell.vars and _G.Cell.vars.debuffBlacklist
            if type(blacklist) ~= "table" or not next(blacklist) then return nil end
            return { excludeSpellIDs = blacklist }
        end,
    },
    -- 內建的冷卻指示器。清單直接跟 Cell 要（I.GetDefensives / I.GetExternals），
    -- 再套上使用者在 CellDB 裡的停用與自訂，等於完整複製 Cell 的過濾規則 ——
    -- 這是「不過濾就全顯示」跟「跟著 Cell 走」的差別所在。
    {
        key = "defensiveCooldowns",
        filter = "HELPFUL",
        anchorTo = { "defensiveCooldowns" },
        requireEnabled = "defensiveCooldowns",
        showDuration = false,
        borderColor = BUFF_BORDER_COLOR,   -- 綠色 swipe，底層是黑色軌道
        buildFilters = function()
            local map = BuildCellCuratedList("GetDefensives", "defensives")
            return map and { includeSpellIDs = map } or nil
        end,
    },
    {
        key = "externalCooldowns",
        filter = "HELPFUL",
        anchorTo = { "externalCooldowns" },
        requireEnabled = "externalCooldowns",
        showDuration = false,
        borderColor = BUFF_BORDER_COLOR,   -- 綠色 swipe，底層是黑色軌道
        buildFilters = function()
            local map = BuildCellCuratedList("GetExternals", "externals")
            return map and { includeSpellIDs = map } or nil
        end,
    },
    {
        key = "allCooldowns",
        filter = "HELPFUL",
        anchorTo = { "allCooldowns" },
        requireEnabled = "allCooldowns",
        showDuration = false,
        borderColor = BUFF_BORDER_COLOR,   -- 綠色 swipe，底層是黑色軌道
        buildFilters = function()
            local map = MergeSpellIDMaps(
                BuildCellCuratedList("GetDefensives", "defensives"),
                BuildCellCuratedList("GetExternals", "externals"))
            return map and { includeSpellIDs = map } or nil
        end,
    },
}

------------------------------------------------------------
-- 能力偵測
------------------------------------------------------------
-- AuraContainer / AuraButton 在 12.1 的八個 PTR build 之間改過名也
-- 移除過 API，所以這裡不假設任何呼叫存在：缺一個就整組停用並印一
-- 行說明，而不是讓每顆 unit button 各噴一次錯。

local caps = {
    build = select(4, GetBuildInfo()) or 0,
    auraContainer = false,
    addAuraGroup = false,
    setAuraGroupLayout = false,
    shouldAurasBeSecret = type(C_Secrets) == "table" and type(C_Secrets.ShouldAurasBeSecret) == "function",
}

-- 一律接管，不只在 auras 為 secret 時。
-- 原本是「戰鬥中才換成我畫」，結果戰鬥內外兩套樣式（Cell 的 vs 我的）長得不
-- 一樣，切換時很干擾。AuraContainer 在非戰鬥時一樣能用，所以乾脆全程由它負責，
-- 樣式就只有一種。
-- 代價：Cell 自己的光環指示器全程被淡出，它的逐光環驅散上色等功能也一併停用。
local ALWAYS_ON = true

local function AurasAreSecret()
    if ALWAYS_ON then return true end
    if caps.shouldAurasBeSecret then
        return C_Secrets.ShouldAurasBeSecret() and true or false
    end
    -- 退路刻意保守：戰鬥中不一定代表 auras 受限，會過度觸發，但不會
    -- 漏觸發，而過度觸發只是在 Cell 本來也能用的時候顯示即時容器。
    return InCombatLockdown() and true or false
end

local function DetectCapabilities()
    if caps.build < BRIDGE_MIN_BUILD then return end

    -- CreateFrame 遇到不存在的 intrinsic 會直接 error，所以用 pcall 探一次
    local ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not frame then return end

    frame:Hide()
    caps.auraContainer = true
    caps.addAuraGroup = type(frame.AddAuraGroup) == "function"
    caps.setAuraGroupLayout = type(frame.SetAuraGroupLayout) == "function"
    caps.flowLayout = type(frame.SetFlowLayoutAnchorPoint) == "function"
        and type(frame.SetFlowLayoutMaximumLineSize) == "function"
    caps.flowAxis = type(frame.SetFlowLayoutAxis) == "function"
        and type(AnchorUtil) == "table" and type(AnchorUtil.FlowLayoutAxis) == "table"
    caps.flowGrowth = type(frame.SetFlowLayoutGrowthDirection) == "function"
        and type(AnchorUtil) == "table" and type(AnchorUtil.FlowDirection) == "table"
end

local function CapabilityFailure()
    if caps.build < BRIDGE_MIN_BUILD then
        return ("需要 build %d 以上（目前 %d）"):format(BRIDGE_MIN_BUILD, caps.build)
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
-- AuraButton 外觀
------------------------------------------------------------
-- 必須寫在 initializeFrame 裡：PTR 5 起 auras 一變 secret 整個
-- AuraButton 就 forbidden，而那個狀態正是在此 callback 回傳「之後」
-- 才套上去的，寫在別處會 error。

local BORDER_SIZE = 1
local ELEMENT_SPACING = 1
-- Cell 用同一張純白貼圖做掃描（Cell.vars.whiteTexture），沿用它
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- Cell 指示器設定裡的字型長這樣：
--   {字型名稱, 字級, 外框, 陰影, 錨點, x, y, {r,g,b}}
-- 字型名稱要透過 LibSharedMedia 轉成檔案路徑（Cell 自己也是這樣註冊的）。
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local function ApplyCellFont(fontString, cellFont, auraButton, iconHeight, fallbackPoint, fx, fy, forcePoint)
    local file, size, outline = nil, nil, "OUTLINE"
    local point, offsetX, offsetY = fallbackPoint or "CENTER", fx or 0, fy or 0
    local r, g, b = 1, 1, 1

    if type(cellFont) == "table" then
        if LSM and type(cellFont[1]) == "string" then
            file = LSM:Fetch("font", cellFont[1], true)
        end
        if type(cellFont[2]) == "number" then size = cellFont[2] end
        if type(cellFont[3]) == "string" then outline = cellFont[3] end
        if type(cellFont[5]) == "string" then point = cellFont[5] end
        if type(cellFont[6]) == "number" then offsetX = cellFont[6] end
        if type(cellFont[7]) == "number" then offsetY = cellFont[7] end
        local color = cellFont[8]
        if type(color) == "table" then
            r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
        end
    end

    -- 沒有設定就依圖示高度推一個，別再寫死一個對小圖示過大的字級
    if not size then
        size = math.max(8, math.floor((iconHeight or 20) * 0.55))
    end
    file = file or (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT

    -- display 指定了錨點就蓋掉 Cell 的（長條上的倒數要水平垂直都置中，
    -- Cell 的字型設定是 BOTTOMRIGHT）。
    -- forcePoint 可以是字串，也可以是 { point, relativePoint, x, y } ——
    -- 後者才表達得出「文字的 CENTER 對齊按鈕的 TOP」這種一半露在外面的效果。
    local relativePoint = point
    if type(forcePoint) == "table" then
        point, relativePoint = forcePoint[1], forcePoint[2] or forcePoint[1]
        offsetX, offsetY = forcePoint[3] or 0, forcePoint[4] or 0
    elseif type(forcePoint) == "string" then
        point, relativePoint, offsetX, offsetY = forcePoint, forcePoint, 0, 0
    end

    if file then
        fontString:SetFont(file, size, outline == "None" and "" or outline)
    end
    fontString:SetTextColor(r, g, b)
    fontString:ClearAllPoints()
    fontString:SetPoint(point, auraButton, relativePoint, offsetX, offsetY)
end

-- Cell 的 showDuration 有四種值：
--   false        永不顯示
--   true         永遠顯示
--   >= 1         剩餘「秒數」低於門檻才顯示
--   0.75 / 0.5   剩餘「比例」低於門檻才顯示
--
-- 大前提不變：Cell 沒勾「顯示時間」就完全不顯示，這裡只決定「有勾的時候」
-- 要不要再加門檻。
--
-- 門檻本身在 Lua 做不到（讀不到剩餘時間），但可以交給暴雪算：SetDurationText
-- 的 textColor 收一條 ColorCurve，暴雪拿 RemainingDuration 去取樣它決定文字顏色，
-- 而 ColorCurve 的點含 alpha。做一條「門檻以上 alpha 0」的曲線就等於門檻顯示。
--
-- 對應方式：
--   >= 1  → 直接用 Cell 設的秒數當門檻（尊重使用者在 Cell 裡的設定）
--   true  → 用 DEFAULT_DURATION_THRESHOLD。像大地之盾那種一小時的 buff，
--           整場掛著 3599 沒有意義。設成 nil 就是真的「永遠顯示」。
--   < 1   → 比例門檻要用 RemainingPercent 取樣，而它的值域（0-1 還是 0-100）
--           沒有文件，先當成「永遠顯示」，不亂猜。
-- 層數貼在圖示正上方、水平置中，文字中線壓在上緣所以一半露在圖示外 ——
-- 不會蓋到圖示內容，一眼就看得到。
local STACK_ANCHOR = { "CENTER", "TOP", 0, 0 }

-- 倒數數字一律置中。Cell 的字型設定預設是 BOTTOMRIGHT（那是給層數用的角落
-- 位置），套到倒數上會變成靠右下角，讀起來不直覺。
local DURATION_ANCHOR = "CENTER"

local DEFAULT_DURATION_THRESHOLD = 60

-- 「門檻以上 alpha 0、以下 alpha 1」的顏色曲線。
-- ColorCurve 沒有 SetType（不像 Curve 有 Step），只能線性內插，所以用兩個極
-- 接近的點做出等效的階梯。
local function BuildDurationAlphaCurve(threshold, r, g, b)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end

    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end

    r, g, b = r or 1, g or 1, b or 1
    local visible, hidden = CreateColor(r, g, b, 1), CreateColor(r, g, b, 0)

    -- x 是剩餘秒數
    local added = pcall(function()
        curve:AddPoint(0, visible)
        curve:AddPoint(threshold, visible)
        curve:AddPoint(threshold + 0.01, hidden)
        curve:AddPoint(threshold + 86400, hidden)
    end)
    if not added then return nil end
    return curve
end

local function ShouldShowDuration(showDuration)
    if showDuration == nil or showDuration == false then return false end
    return true
end

-- 回傳秒數門檻，或 nil 表示不設門檻
local function ResolveDurationThreshold(showDuration)
    if type(showDuration) == "number" and showDuration >= 1 then
        return showDuration
    end
    if showDuration == true then
        return DEFAULT_DURATION_THRESHOLD
    end
    return nil
end

local function InitAuraButton(auraButton, display, sizeW, sizeH)
    sizeH = sizeH or sizeW
    auraButton:SetIgnoringChildrenForBounds(true)
    auraButton:SetSize(sizeW, sizeH)

    -- Cell 的外框倒數手法（I.CreateAura_BorderIcon）：
    -- Cooldown 蓋滿整格、用實心貼圖做掃描，然後把「圖示」放進一個往內縮
    -- borderSize、frame level 比 Cooldown 高的子框架蓋在它上面。掃描其實是滿
    -- 格的，但只有邊緣那一圈露得出來 —— 看起來就是外框順時針消退，顏色歸零
    -- 時光環也剛好結束。
    -- 這裡把同一套搬到 SetDurationCooldown 上，所以視覺跟 Cell 原本一致。

    -- 底層：永久光環（沒有倒數）時看到的靜態外框
    local border = auraButton:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(auraButton)
    auraButton.Border = border

    if display.dispelBorder and auraButton.SetAuraBorder then
        -- 驅散色留給「底框」，讓掃描用灰色由上蓋過去 —— 灰色越蓋越多、
        -- 彩色越來越少，視覺上就是彩色外框在倒數。
        --
        -- 為什麼不直接讓掃描是彩色的（那才是 Cell 自己的做法）：SetSwipeColor
        -- 要逐光環給 RGB，而 AuraButton 不告訴我們驅散類型；SetAuraBorder 只能
        -- 替「貼圖」上色，管不到 Cooldown 的掃描。把兩層對調就繞過了這個限制。
        border:SetColorTexture(1, 1, 1, 1)
        auraButton:SetAuraBorder(border, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle
                and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or nil,
            showIcon = false,
            showAlways = true,
        })
    else
        -- 增益不要走驅散上色：增益沒有 dispelName，PreserveAsset 會讓每一顆
        -- 都變成預設的紅框（就是那排紅框增益的來源）。
        --
        -- 靜態框的顏色取決於動畫樣式，兩者不能同色否則看不出變化：
        --   swipe 樣式 → 這層當黑色軌道，讓上面的彩色掃描消退時露出來
        --   bar 樣式   → 掃描沒在用 borderColor，這層就直接用它當外框顏色，
        --                動畫交給上面的深色遮罩
        local c = (display.durationStyle == "bar" and display.borderColor) or TRACK_COLOR
        border:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end

    -- 中層：倒數。交出 widget 讓暴雪驅動，不是拿回秒數 ——
    -- SetDurationCooldown / SetDurationBar 會在它上面蓋
    -- SecretAspect.Cooldown / SecretAspect.BarValue。
    local cooldown
    if display.durationStyle == "bar" and auraButton.SetDurationBar then
        -- 由上往下的遮罩，跟 Cell 那兩排長條一致。用深色半透明而不是白色 ——
        -- 白色整片覆蓋會把圖示洗掉（試過，很醜）。
        local bar = CreateFrame("StatusBar", nil, auraButton)
        bar:SetAllPoints(auraButton)
        bar:SetOrientation("VERTICAL")
        bar:SetReverseFill(true)
        bar:SetStatusBarTexture(WHITE_TEXTURE)
        bar:GetStatusBarTexture():SetVertexColor(0, 0, 0, 0.65)
        auraButton.DurationBar = bar
        auraButton:SetDurationBar(bar)
    elseif auraButton.SetDurationCooldown then
        -- 一定要帶 CooldownFrameTemplate。Cell 自己建 Cooldown 時可以不帶，
        -- 因為它自己呼叫 SetCooldown 驅動；但交給 SetDurationCooldown 是「暴雪
        -- 驅動」，少了 template 提供的內容它不會動。Coolinator 也是帶 template 的。
        cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        cooldown:SetAllPoints(auraButton)
        cooldown:SetSwipeTexture(WHITE_TEXTURE)

        if display.dispelBorder then
            -- 底框是驅散色，掃描用灰色「吃掉」它。SetReverse 讓掃描覆蓋的是
            -- 已經過去的那段，所以灰色會越來越多。
            cooldown:SetSwipeColor(SPENT_COLOR[1], SPENT_COLOR[2], SPENT_COLOR[3])
            cooldown:SetReverse(true)
        else
            local c = display.borderColor or { 1, 1, 1, 1 }
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

    -- 上層：圖示。往內縮 borderSize 並疊在 Cooldown 之上，這樣掃描就只從
    -- 邊緣露出來。少了這個 frame level，掃描會整片蓋住圖示。
    local iconFrame = CreateFrame("Frame", nil, auraButton)
    iconFrame:SetPoint("TOPLEFT", auraButton, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    iconFrame:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    if cooldown then
        iconFrame:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    end
    auraButton.IconFrame = iconFrame

    -- 遮罩要蓋在圖示「上面」才叫遮罩，所以放到 iconFrame 之上。
    -- 外框掃描剛好相反 —— 它要在圖示下面，才會只從邊緣露出來。
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

    -- 剩餘時間文字。字型直接抄 Cell 指示器的設定（font[2] 是 durationFont，
    -- font[1] 是 stackFont），沒設定才退回依圖示高度縮放 —— 寫死
    -- NumberFontNormalSmall 對 13px 的圖示來說太大了。
    -- 文字掛在 iconFrame 上，跟 Cell 一樣 —— 掛在 auraButton 上會被 Cooldown
    -- 的掃描蓋住。
    if ShouldShowDuration(display.showDuration) then
        local duration = textFrame:CreateFontString(nil, "OVERLAY")
        ApplyCellFont(duration, display.fontConfig and display.fontConfig[2], iconFrame, sizeH,
            nil, nil, nil, display.durationAnchor or DURATION_ANCHOR)
        auraButton.Duration = duration
        if auraButton.SetDurationText then
            local options = DurationFormatter and { textFormatter = DurationFormatter } or {}

            local threshold = ResolveDurationThreshold(display.showDuration)
            if threshold and Enum and Enum.DurationTextBindingProperty then
                local font = display.fontConfig and display.fontConfig[2]
                local color = type(font) == "table" and font[8] or nil
                local curve = BuildDurationAlphaCurve(threshold,
                    color and color[1], color and color[2], color and color[3])
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

    if display.showStack ~= false then
        local stack = textFrame:CreateFontString(nil, "OVERLAY")
        -- 錨到 auraButton 而不是 iconFrame：iconFrame 內縮了 BORDER_SIZE，
        -- 要貼齊圖示外緣得用按鈕本身。
        ApplyCellFont(stack, display.fontConfig and display.fontConfig[1], auraButton, sizeH,
            nil, nil, nil, STACK_ANCHOR)
        auraButton.Count = stack
        if auraButton.SetApplicationCount then
            auraButton:SetApplicationCount(stack)
        end
    end
end

------------------------------------------------------------
-- 每顆 unit button 的容器
------------------------------------------------------------

local attached = setmetatable({}, { __mode = "k" })    -- [cellButton] = { [key] = container }
local customDone = setmetatable({}, { __mode = "k" })  -- 自訂指示器只需掃一次
local diag = { stage = nil, err = nil, skips = {} }

local function Skip(reason)
    diag.skips[reason] = (diag.skips[reason] or 0) + 1
end

-- 直接鏡射 Cell 自己的指示器，而不是去讀 Cell 的 SavedVariables：那個
-- 指示器上已經帶著使用者設定好的錨點、圖示大小與數量，讀它等於免費跟
-- 著 Cell 的設定走。回傳 layout 與被借用的指示器本身（切換顯示時要把
-- 它淡出的就是它）。
-- 前向宣告：ReadCellIndicatorLayout 要用到它，但定義在後面。
local GetCellIndicatorConfig

local function ReadCellIndicatorLayout(cellButton, anchorTo)
    local indicators = cellButton.indicators
    if not indicators then return nil end

    for _, name in ipairs(anchorTo) do
        local indicator = indicators[name]
        -- GetPoint 回 nil 代表 Cell 還沒替這顆按鈕排版過該指示器
        local point, relativeTo, relativePoint, x, y = indicator and indicator:GetPoint(1)
        if point then
            -- 寬高要分開讀：Cell 的防禦／減傷指示器是畫成直立長條的，
            -- 只讀寬度會把它們變成正方形。
            local sizeW, sizeH = 20, 20
            local first = indicator[1]
            if first and first.GetSize then
                local w, h = first:GetSize()
                if type(w) == "number" and w > 0 then sizeW = w end
                if type(h) == "number" and h > 0 then sizeH = h end
            end

            local num = 3
            if type(indicator.numPerLine) == "number" and indicator.numPerLine > 0 then
                num = indicator.numPerLine
            elseif #indicator > 0 then
                num = math.min(#indicator, 5)
            end

            -- 一併撈該指示器的設定條目，字型（font[1]=層數 font[2]=倒數）在裡面
            local entry
            for _, t in pairs(GetCellIndicatorConfig(cellButton) or {}) do
                if type(t) == "table" and t["indicatorName"] == name then entry = t break end
            end

            return {
                indicatorName = name,
                point = point, relativeTo = relativeTo, relativePoint = relativePoint,
                x = x or 0, y = y or 0, sizeW = sizeW, sizeH = sizeH, num = num,
                fontConfig = entry and entry["font"] or nil,
                showStack = entry and entry["showStack"] or nil,
                showDuration = entry and entry["showDuration"],
                color = entry and entry["color"] or nil,
                -- Cell 在 Debuffs_SetPoint / SetOrientation 裡寫入這兩個欄位
                hAlignment = indicator.hAlignment, vAlignment = indicator.vAlignment,
            }, indicator
        end
    end

    return nil
end

------------------------------------------------------------
-- Cell 自訂指示器 → AuraSlot
------------------------------------------------------------
-- 這是整個遷移裡條件最好的一塊：
--   * 追蹤的法術是使用者自己設定的，清單就存在 Cell 的設定裡（button._config
--     的 ["auras"]），外部讀得到 —— 不像內建的防禦技能清單是檔案 local。
--   * 目標是友方單位上的增益，而那正是 12.1 唯一允許 spellID 過濾的情況。
--   * 一格只顯示一個光環 = AuraSlot 的定義（maxFrameCount 固定 1，而且可以
--     自己錨定，AuraGroup 不行）。
--
-- 大地之盾（383648）在 12.1 被移出 never-secret 名單，所以戰鬥中變 secret，
-- Cell 自己的指示器就瞎了 —— 但 includeSpellIDs 的 AuraSlot 仍然看得到它。

-- Cell 的內建策展清單其實是公開的：I.GetDefensives() / I.GetExternals() /
-- I.GetCrowdControls()，結構是 {[class] = {[spellID] = trackByName}}。
-- 再套上使用者在 CellDB 裡的停用與自訂，就能完整重建 Cell 的過濾規則。
--（防禦／減傷是友方單位上的增益，正好是 12.1 允許 spellID 過濾的情況。）
function BuildCellCuratedList(getterName, dbKey)
    local Cell = _G.Cell
    local I = Cell and Cell.iFuncs
    local getter = I and I[getterName]
    if type(getter) ~= "function" then return nil end

    local ok, byClass = pcall(getter)
    if not ok or type(byClass) ~= "table" then return nil end

    local db = _G.CellDB and _G.CellDB[dbKey]
    local disabled = (type(db) == "table" and type(db["disabled"]) == "table") and db["disabled"] or nil

    local map, count = {}, 0
    for _, spells in pairs(byClass) do
        if type(spells) == "table" then
            for spellID in pairs(spells) do
                if type(spellID) == "number" and not (disabled and disabled[spellID]) then
                    map[spellID] = true
                    count = count + 1
                end
            end
        end
    end

    -- 使用者自訂的追加
    if type(db) == "table" and type(db["custom"]) == "table" then
        for _, spellID in pairs(db["custom"]) do
            if type(spellID) == "number" then
                map[spellID] = true
                count = count + 1
            end
        end
    end

    if count == 0 then return nil end
    return map
end

function MergeSpellIDMaps(...)
    local map, count = {}, 0
    for i = 1, select("#", ...) do
        local source = select(i, ...)
        if type(source) == "table" then
            for spellID in pairs(source) do
                map[spellID] = true
                count = count + 1
            end
        end
    end
    if count == 0 then return nil end
    return map
end

local function BuildSpellIDMap(auras)
    if type(auras) ~= "table" then return nil end
    local map, count = {}, 0
    for _, spellID in pairs(auras) do
        if type(spellID) == "number" then
            map[spellID] = true
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return map
end

-- 會顯示光環圖示（含倒數）的自訂指示器型別。Cell 還有 text / color / glow /
-- border 等型別，那些不畫圖示，這裡不接管。
-- 單數型別只顯示一個光環 → AuraSlot（可自行錨定）
-- 複數型別會顯示多個 → AuraGroup（帶 maxFrameCount，由容器自己排版）
-- 這個區分很重要：像「Healers」那種追 68 顆 HoT 的 icons 指示器，接成
-- AuraSlot 的話永遠只會顯示一顆。
local MIRRORED_TYPES = {
    icon = "slot", bar = "slot", block = "slot", rect = "slot",
    icons = "group", bars = "group", blocks = "group",
}

-- Cell 的 orientation 字串 → flow layout 的生長方向
local ORIENTATION_GROWTH = {
    ["right-to-left"] = { h = "Left", v = "Down" },
    ["left-to-right"] = { h = "Right", v = "Down" },
    ["top-to-bottom"] = { h = "Right", v = "Down" },
    ["bottom-to-top"] = { h = "Right", v = "Up" },
}

-- 設定的權威來源是 Cell.vars.currentLayoutTable["indicators"]。
-- button._config 只是指向它的參照，而且 Cell 在某些路徑會把它設成 nil
--（UnitButton.lua:471），所以不能只靠它，否則掃出來會是空的。
function GetCellIndicatorConfig(cellButton)
    local Cell = _G.Cell
    local layout = Cell and Cell.vars and Cell.vars.currentLayoutTable
    local config = layout and layout["indicators"]
    if type(config) == "table" then return config end
    return type(cellButton._config) == "table" and cellButton._config or nil
end

-- 挑出「會畫圖示、已啟用、有指定法術」的自訂指示器
local function EnumerateCustomIconIndicators(cellButton, fn)
    local config = GetCellIndicatorConfig(cellButton)
    if not config then return end

    for _, t in pairs(config) do
        local kind = type(t) == "table" and MIRRORED_TYPES[t["type"]]
        if kind and t["enabled"] ~= false and t["indicatorName"] then
            local spellIDs = BuildSpellIDMap(t["auras"])
            if spellIDs then
                fn(t, spellIDs, kind)
            end
        end
    end
end

-- 容器是「建一次就快取」的，所以 Cell 設定改了不會反映 —— 之前必須 /reload
-- 才看得到。AuraButton 的外觀是在 initializeFrame 裡烘進去的，事後改不了
--（auras 為 secret 時它還是 forbidden），所以唯一的辦法是重建。
--
-- 但不能每次 Refresh 都重建：WoW 的 frame 無法銷毀，重建等於永久多一批。
-- 所以替每個容器記一份「設定簽章」，只有簽章變了才重建。
local function BuildSignature(layout, display)
    local font = layout.fontConfig and layout.fontConfig[2]
    return table.concat({
        tostring(display.key),
        tostring(layout.indicatorName),
        tostring(layout.point), tostring(layout.relativePoint),
        tostring(layout.x), tostring(layout.y),
        tostring(layout.sizeW), tostring(layout.sizeH), tostring(layout.num),
        tostring(layout.showDuration), tostring(layout.showStack),
        layout.color and table.concat(layout.color, ",") or "-",
        font and table.concat({ tostring(font[1]), tostring(font[2]), tostring(font[3]) }, ",") or "-",
    }, "|")
end

local function GetUnitFor(cellButton)
    local unit = cellButton.states and cellButton.states.displayedUnit
    if unit then return unit end
    return cellButton:GetAttribute("unit")
end

-- 掛載失敗要記錄下來而不是吞掉。每一步都標記階段，這樣 /cab 能指出是
-- 哪個呼叫拒絕的 —— 把 AuraContainer 掛到 Cell 的 secure unit button、
-- 錨定、SetUnit、AddAuraGroup 在 12.1 各有各的規矩（例如 Forbidden
-- Aspects 會透過 SetParent / SetPoint 傳染）。
local function BuildContainer(cellButton, display, layout, unit)
    -- parent 到 Cell 自己掛減益圖示的那層，而不是 unit button。兩個理由：
    -- indicatorFrame 在血條之上，AuraButton 才不會被血條蓋住；而且它是
    -- 普通 frame，unit button 是 secure 的，避開 Forbidden Aspects。
    local host = (cellButton.widgets and cellButton.widgets.indicatorFrame) or cellButton

    diag.stage = "CreateFrame"
    local container = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")

    diag.stage = "SetSize"
    container:SetSize(1, 1)

    diag.stage = "SetFrameLevel"
    container:SetFrameLevel(host:GetFrameLevel() + 5)

    diag.stage = "SetPoint"
    container:SetPoint(layout.point, layout.relativeTo or host, layout.relativePoint, layout.x, layout.y)

    diag.stage = "SetUnit"
    container:SetUnit(unit)

    -- 排版方向是「容器層級」的 flow layout，不是 group 的選項。
    -- 預設值（AnchorUtil.FlowLayoutMixin:ResetOptions）是 Horizontal 軸、
    -- 錨點 TOPLEFT、往右往下長。
    diag.stage = "FlowLayout"
    if container.SetFlowLayoutAnchorPoint then
        container:SetFlowLayoutAnchorPoint(layout.point)
    end

    if container.SetFlowLayoutAxis and AnchorUtil and AnchorUtil.FlowLayoutAxis then
        container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    end

    -- 生長方向要跟著錨點走，否則從 BOTTOMLEFT 起算卻往下長會跑出框外。
    if container.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
        local dir = AnchorUtil.FlowDirection
        local horizontal = strfind(layout.point, "RIGHT") and dir.Left or dir.Right
        local vertical = strfind(layout.point, "^BOTTOM") and dir.Up or dir.Down
        container:SetFlowLayoutGrowthDirection(horizontal, vertical)
    end

    -- maximumLineSize 是「主軸上的像素預算」，不是圖示顆數 —— FlowLayout
    -- 拿它跟累積的 element 寬度比大小。第一版直接傳 num（5）等於每顆圖示
    -- 都超出上限，於是一顆一行，變成整排垂直堆疊。
    if container.SetFlowLayoutMaximumLineSize then
        container:SetFlowLayoutMaximumLineSize(layout.num * (layout.sizeW + ELEMENT_SPACING))
    end

    -- 這一版的欄位名稱是從 Blizzard_CustomAuraContainer.lua 的
    -- ValidateAuraGroupLayoutOptions 抄來的，不是猜的。要注意兩件事：
    -- 1. layout 是「巢狀」在 options 底下，不是攤平的。
    -- 2. 未知的鍵會被 CopyAndValidateInboundTable 靜靜丟掉 —— 不會報錯，
    --    只是完全沒作用（第一版就是這樣白忙一場）。
    -- 把 DISPLAYS 的設定跟從 Cell 指示器讀到的字型／層數設定合併，
    -- 這樣文字大小才會跟 Cell 一致，而不是寫死一個對小圖示過大的字級。
    local resolved = {}
    for k, v in pairs(display) do resolved[k] = v end
    resolved.fontConfig = layout.fontConfig
    if layout.showStack ~= nil then resolved.showStack = layout.showStack end
    if layout.showDuration ~= nil then resolved.showDuration = layout.showDuration end
    -- DISPLAYS 有指定顏色就以它為準（例如左右兩側刻意統一成綠色）；
    -- 沒指定才沿用 Cell 指示器設定裡的 ["color"]。
    if layout.color and not display.borderColor then
        resolved.borderColor = { layout.color[1], layout.color[2], layout.color[3], 1 }
    end

    diag.stage = "AddAuraGroup"
    container:AddAuraGroup(display.key, display.filter, {
        maxFrameCount = layout.num,
        candidateFilters = display.buildFilters and display.buildFilters() or nil,
        layout = {
            elementWidth = layout.sizeW,
            elementHeight = layout.sizeH,
            elementSpacing = ELEMENT_SPACING,
            lineSpacing = ELEMENT_SPACING,
        },
        initializeFrame = function(auraButton)
            InitAuraButton(auraButton, resolved, layout.sizeW, layout.sizeH)
        end,
    })
    diag.stage = nil

    container.__layout = layout
    container.__unit = unit
    container:Hide()
    return container
end

-- 每顆按鈕、每個顯示定義各掛一個容器：attached[cellButton][display.key]
-- 使用者在 Cell 裡停用的指示器不該被鏡射，否則會冒出他關掉的東西
local function IsCellIndicatorEnabled(cellButton, indicatorName)
    local config = GetCellIndicatorConfig(cellButton)
    if not config then return true end  -- 讀不到設定就不擋，交給後續重試
    for _, t in pairs(config) do
        if type(t) == "table" and t["indicatorName"] == indicatorName then
            return t["enabled"] ~= false
        end
    end
    return true
end

local function AttachOne(cellButton, display)
    local perButton = attached[cellButton]
    local existing = perButton and perButton[display.key]

    if display.requireEnabled and not IsCellIndicatorEnabled(cellButton, display.requireEnabled) then
        -- 使用者在 Cell 裡關掉了：把先前建的收起來、還原 Cell 的圖示
        if existing then
            existing:Hide()
            if existing.__cellIndicator then existing.__cellIndicator:SetAlpha(1) end
            perButton[display.key] = nil
        end
        return nil
    end

    local layout, cellIndicator = ReadCellIndicatorLayout(cellButton, display.anchorTo)
    if not layout then Skip(display.key .. "：讀不到可借用的指示器版面") return nil end

    local signature = BuildSignature(layout, display)
    if existing then
        if existing.__signature == signature then return existing end
        -- 設定變了：舊的收起來讓它閒置（frame 無法銷毀），下面重建一個
        existing:Hide()
        perButton[display.key] = nil
    end

    local unit = GetUnitFor(cellButton)
    if not unit then Skip(display.key .. "：沒有 unit token") return nil end

    local ok, container = pcall(BuildContainer, cellButton, display, layout, unit)
    if not ok then
        Skip(display.key .. "：錯誤發生在 " .. tostring(diag.stage))
        diag.err = container
        return nil
    end
    if not container then Skip(display.key .. "：BuildContainer 回傳 nil") return nil end

    container.__cellIndicator = cellIndicator
    container.__signature = signature

    if not perButton then
        perButton = {}
        attached[cellButton] = perButton
    end
    perButton[display.key] = container
    return container
end

-- 自訂指示器共用一個容器：AuraSlot 可以自己錨定，所以不需要像 AuraGroup
-- 那樣一個容器對一個位置。
local function AttachCustomSlots(cellButton)
    if customDone[cellButton] then return end

    local unit = GetUnitFor(cellButton)
    if not unit then return end

    local host = (cellButton.widgets and cellButton.widgets.indicatorFrame) or cellButton
    local container
    local customContainers = {}
    local matched, created = 0, 0

    EnumerateCustomIconIndicators(cellButton, function(t, spellIDs, kind)
        matched = matched + 1
        local name = tostring(t["indicatorName"])
        local cellIndicator = cellButton.indicators[t["indicatorName"]]
        if not cellIndicator then
            -- Cell 是在 HandleIndicators 裡才建立自訂指示器 frame 的，比我們的
            -- 第一輪掃描晚。這裡不能記為完成，否則永遠不會再試。
            Skip("自訂 " .. name .. "：這顆按鈕上還沒有這個指示器")
            return
        end

        local ok, err = pcall(function()
            local pos = t["position"] or { "TOPRIGHT", "button", "TOPRIGHT", 0, 3 }
            local size = t["size"] or { 13, 13 }
            local spacing = t["spacing"] or { 0, 0 }
            local relativeTo = (pos[2] == "healthBar" and cellButton.widgets and cellButton.widgets.healthBar)
                or cellButton
            local filterString = (t["auraType"] == "debuff") and "HARMFUL" or "HELPFUL"
            local display = {
                showDuration = t["showDuration"],
                showStack = t["showStack"],
                fontConfig = t["font"],
                -- 自訂指示器（例如 Healers）走「深色遮罩由上往下」，
                -- 所以外框是靜態黑色軌道，動畫交給 DurationBar。
                durationStyle = "bar",
                borderColor = t["color"]
                    and { t["color"][1], t["color"][2], t["color"][3], 1 }
                    or TRACK_COLOR,
                dispelBorder = (t["auraType"] == "debuff"),
            }

            if kind == "group" then
                -- 多圖示：容器整個錨到 Cell 指示器的位置，由 AuraGroup 自己排版
                local num = tonumber(t["num"]) or 5
                local perLine = tonumber(t["numPerLine"]) or num
                local growth = ORIENTATION_GROWTH[t["orientation"]] or ORIENTATION_GROWTH["right-to-left"]

                diag.stage = "custom group anchor"
                local sub = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")
                sub:SetSize(1, 1)
                sub:SetFrameLevel(host:GetFrameLevel() + 6)
                sub:SetPoint(pos[1], relativeTo, pos[3], pos[4] or 0, pos[5] or 0)
                sub:SetUnit(unit)
                sub.__unit = unit
                sub.__customSlots = { [t["indicatorName"]] = cellIndicator }

                if sub.SetFlowLayoutAnchorPoint then sub:SetFlowLayoutAnchorPoint(pos[1]) end
                if sub.SetFlowLayoutAxis and AnchorUtil and AnchorUtil.FlowLayoutAxis then
                    sub:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
                end
                if sub.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
                    sub:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection[growth.h],
                        AnchorUtil.FlowDirection[growth.v])
                end
                if sub.SetFlowLayoutMaximumLineSize then
                    sub:SetFlowLayoutMaximumLineSize(perLine * (size[1] + (spacing[1] or 0)))
                end

                diag.stage = "custom AddAuraGroup"
                sub:AddAuraGroup(t["indicatorName"], filterString, {
                    maxFrameCount = num,
                    candidateFilters = { includeSpellIDs = spellIDs },
                    layout = {
                        elementWidth = size[1],
                        elementHeight = size[2],
                        elementSpacing = spacing[1] or 0,
                        lineSpacing = spacing[2] or 0,
                    },
                    initializeFrame = function(auraButton)
                        InitAuraButton(auraButton, display, size[1], size[2])
                    end,
                })
                sub:Hide()
                sub.__slotCount = num
                customContainers[#customContainers + 1] = sub
            else
                -- 單一光環：AuraSlot 可以自行錨定，所有 slot 共用一個容器。
                -- 這個容器只有真的遇到單數型指示器才建 —— 之前無條件先建，
                -- 結果每顆按鈕都多出一個永遠空著的容器。
                if not container then
                    diag.stage = "custom CreateFrame"
                    container = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")
                    container:SetSize(1, 1)
                    container:SetFrameLevel(host:GetFrameLevel() + 6)
                    container:SetPoint("CENTER", host, "CENTER", 0, 0)
                    container:SetUnit(unit)
                    container.__unit = unit
                    container.__customSlots = {}
                end

                diag.stage = "AddAuraSlot"
                container:AddAuraSlot(t["indicatorName"], filterString, {
                    candidateFilters = { includeSpellIDs = spellIDs },
                    initializeFrame = function(auraButton)
                        InitAuraButton(auraButton, display, size[1], size[2])
                        -- AuraButton 只有在 initializeFrame 內（以及 PLAYER_LOGIN
                        -- 之前）才允許 SetPoint/SetSize，所以錨定必須寫在這裡
                        auraButton:ClearAllPoints()
                        auraButton:SetPoint(pos[1], relativeTo, pos[3], pos[4] or 0, pos[5] or 0)
                    end,
                })
                container.__customSlots[t["indicatorName"]] = cellIndicator
                container.__slotCount = (container.__slotCount or 0) + 1
            end
            diag.stage = nil
        end)

        if ok then
            created = created + 1
        else
            Skip("自訂 " .. name .. "：錯誤發生在 " .. tostring(diag.stage))
            diag.err = err
            diag.stage = nil
        end
    end)

    -- 只有「設定裡的每一個都真的建起來了」才記為完成。
    -- 這正是原本只建出一顆的 bug：Cell 建立自訂指示器 frame 的時機比我們第一
    -- 輪掃描晚，先前只要讀得到設定就無條件標記完成，於是那些當下還沒有 frame
    -- 的按鈕永遠不會再被掃第二次。matched == 0 也標記完成，避免沒有自訂指示器
    -- 的版面每次 Refresh 都白掃一遍。
    if GetCellIndicatorConfig(cellButton) and created >= matched then
        customDone[cellButton] = true
    end

    if container or #customContainers > 0 then
        local perButton = attached[cellButton]
        if not perButton then
            perButton = {}
            attached[cellButton] = perButton
        end
        if container then
            container:Hide()
            perButton["custom"] = container
        end
        for i, sub in ipairs(customContainers) do
            perButton["custom" .. i] = sub
        end
    end
end

local function Attach(cellButton)
    if not cellButton.indicators then Skip("沒有 indicators") return nil end

    for _, display in ipairs(DISPLAYS) do
        AttachOne(cellButton, display)
    end
    AttachCustomSlots(cellButton)
    return attached[cellButton]
end

------------------------------------------------------------
-- 顯示切換
------------------------------------------------------------
-- auras 為 secret 時 Cell 的圖示是過期資料，所以是「淡出」而不是隱藏：
-- Show/Hide 是 Cell 自己在管的，去搶會閃爍。alpha 不在 Cell 的每次更新
-- 路徑上，設了會一直保留到我們還原為止。

-- 交還控制權給 Cell 時要叫它重掃一次。
-- 整場戰鬥中 Cell 的光環管線是停擺的（payload 不可讀，它自己會提早 return），
-- 快取停在進戰前的狀態甚至是空的。單純把 alpha 調回 1，使用者會看到圖示「一
-- 出戰鬥就全部消失」，要等下一個 UNIT_AURA 才回來。
-- 不帶 updateInfo 呼叫 = 走全量重掃路徑，此時 auras 已非 secret，
-- GetAuraSlots/GetAuraDataBySlot 可以正常用。
local function ForceCellAuraRefresh(cellButton)
    local B = _G.Cell and _G.Cell.bFuncs
    if B and type(B.UpdateAuras) == "function" then
        pcall(B.UpdateAuras, cellButton)
    end
end

local function ApplyState(cellButton, containers, secret, justLeftSecret)
    local unit = secret and GetUnitFor(cellButton) or nil

    -- 只在「剛離開 secret 狀態」那一次重掃。每次 Refresh 都掃的話，等於每個
    -- 事件都對每顆按鈕做一次全量光環掃描，太浪費。
    if justLeftSecret then
        ForceCellAuraRefresh(cellButton)
    end

    for _, container in pairs(containers) do
        if secret then
            if unit and unit ~= container.__unit then
                container:SetUnit(unit)
                container.__unit = unit
            end
            container:Show()
        else
            container:Hide()
        end

        -- 被接管的 Cell 指示器要淡出，避免跟我們的圖示疊在一起。
        -- 一般顯示是一個容器對一個指示器；自訂容器則一次對到多個。
        local alpha = secret and 0 or 1
        if container.__cellIndicator then
            container.__cellIndicator:SetAlpha(alpha)
        end
        if container.__customSlots then
            for _, cellIndicator in pairs(container.__customSlots) do
                cellIndicator:SetAlpha(alpha)
            end
        end
    end
end

local function IterateCellButtons(fn)
    local groups = _G.Cell and _G.Cell.unitButtons
    if not groups then return end

    for groupName, group in pairs(groups) do
        if groupName ~= "quickAssist" then
            -- Cell 同時用陣列（solo / spotlight / arena）和 .units 對照表
            --（party / raid / pet / npc）兩種方式存按鈕
            for _, button in pairs(group) do
                if type(button) == "table" and button.indicators then
                    fn(button)
                end
            end
            if type(group.units) == "table" then
                for _, button in pairs(group.units) do
                    if type(button) == "table" and button.indicators then
                        fn(button)
                    end
                end
            end
        end
    end
end

local enabled = false
-- /cab test 用：非戰鬥時 auras 不是 secret，容器本來會保持隱藏；強制
-- 打開才能在不用打怪的情況下確認錨點與圖示大小。
local forceOn = false
-- 上一次 Refresh 時 auras 是不是 secret，用來偵測「剛離開戰鬥」那一瞬間
local wasSecret = false

local function Refresh()
    if not enabled then return end
    -- 每次執行前清空，否則 /cab 報的是登入以來的累計而不是最後一輪的狀態
    wipe(diag.skips)
    diag.ranAt = GetTime()
    local secret = forceOn or AurasAreSecret()
    local justLeftSecret = wasSecret and not secret
    wasSecret = secret

    IterateCellButtons(function(cellButton)
        local containers = Attach(cellButton)
        if containers then
            ApplyState(cellButton, containers, secret, justLeftSecret)
        end
    end)
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Cell", function()
    local driver = CreateFrame("Frame")
    driver:RegisterEvent("PLAYER_LOGIN")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:RegisterEvent("GROUP_ROSTER_UPDATE")
    driver:RegisterEvent("ENCOUNTER_START")
    driver:RegisterEvent("ENCOUNTER_END")
    driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    local pending = false
    local function ScheduleRefresh()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            Refresh()
        end)
    end

    -- Cell 是分好幾個 frame 才建完 unit button 並指派 unit token 的，而
    -- 單人時之後不會再有 GROUP_ROSTER_UPDATE —— 只在 PLAYER_LOGIN 掃一
    -- 次會掃到「按鈕存在但還沒有 unit」然後再也不重試。接上 Cell 自己的
    -- 「框架重建完成」回呼，另外補幾次延遲掃描以防 Cell 比我們的最後一
    -- 個事件還晚完成。
    local function HookCellCallbacks()
        local Cell = _G.Cell
        if not Cell or type(Cell.RegisterCallback) ~= "function" then return false end
        for _, event in ipairs({ "UpdateLayout", "UpdateIndicators", "GroupTypeChanged", "UpdateAppearance" }) do
            pcall(Cell.RegisterCallback, event, "MiliUICellAuraContainer_" .. event, function()
                -- 設定改變時把自訂指示器的「掃過」記號清掉，讓它重讀一次。
                -- 一般顯示是靠 BuildSignature 自動偵測，這裡的自訂指示器沒有
                -- 簽章機制，所以直接放行重掃。
                wipe(customDone)
                ScheduleRefresh()
            end)
        end
        return true
    end

    driver:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            DetectCapabilities()
            local failure = CapabilityFailure()
            if failure then
                print("|cffffe00a[MiliUI]|r Cell 光環容器停用：" .. failure)
                return
            end
            enabled = true
            diag.hookedCell = HookCellCallbacks()
            for _, delay in ipairs({ 1, 3, 10 }) do
                C_Timer.After(delay, ScheduleRefresh)
            end
        end
        ScheduleRefresh()
    end)

    ------------------------------------------------------------
    -- 診斷
    ------------------------------------------------------------

    -- Cell 的圖示是淡出而不是隱藏，萬一本模組中途出錯就會一直看不見。
    -- 這個指令手動把它們救回來。
    local function Reset()
        enabled = false
        forceOn = false
        IterateCellButtons(function(cellButton)
            for _, container in pairs(attached[cellButton] or {}) do
                container:Hide()
                if container.__cellIndicator then container.__cellIndicator:SetAlpha(1) end
            end
        end)
        print("|cffffe00a[MiliUI]|r 已還原 Cell 光環圖示，本模組停用至下次 /reload")
    end

    SLASH_MILIUICELLAURACONTAINER1 = "/cab"
    SlashCmdList["MILIUICELLAURACONTAINER"] = function(msg)
        local cmd = strtrim(msg or ""):lower()

        if cmd == "reset" then
            Reset()
            return
        end

        -- /cab spell <id>：判斷某個法術在戰鬥中會不會變 secret。
        -- 不能也不該去問「這個光環現在在不在某人身上」—— 那正是 12.1 要擋的。
        -- ShouldSpellAuraBeSecret 只回答「這顆法術的光環資料會不會被遮蔽」，
        -- 跟誰身上有沒有無關，所以戰鬥中問也安全。
        local spellID = cmd:match("^spell%s+(%d+)$")
        if spellID then
            spellID = tonumber(spellID)
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
            print(("|cffffe00a[MiliUI]|r 法術 %d %s"):format(spellID, name and ("（" .. name .. "）") or ""))

            if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
                local isSecret = C_Secrets.ShouldSpellAuraBeSecret(spellID)
                print(("|cffffe00a[MiliUI]|r 戰鬥中是否 secret：%s%s"):format(
                    tostring(isSecret),
                    isSecret and " —— Cell 讀不到它，要靠 includeSpellIDs 的 AuraSlot 才看得見" or ""))
            else
                print("|cffffe00a[MiliUI]|r C_Secrets.ShouldSpellAuraBeSecret 不存在")
            end

            -- 有沒有哪個 Cell 自訂指示器在追這顆法術
            local found = false
            IterateCellButtons(function(cellButton)
                if found then return end
                EnumerateCustomIconIndicators(cellButton, function(t, spellIDs)
                    if spellIDs[spellID] and not found then
                        found = true
                        print(("|cffffe00a[MiliUI]|r Cell 自訂指示器「%s」有在追它，已鏡射成 AuraSlot"):format(
                            tostring(t["name"] or t["indicatorName"])))
                    end
                end)
            end)
            if not found then
                print("|cffffe00a[MiliUI]|r 沒有任何 Cell 自訂指示器在追它 —— 先去 Cell 設定裡加，本模組會跟著鏡射")
            end
            return
        end

        -- /cab list：把 Cell 版面裡的自訂指示器全部倒出來。哪個型別、追哪些
        -- 法術、有沒有被鏡射，一次看清楚，不用再猜。
        if cmd == "list" then
            local config
            IterateCellButtons(function(cellButton)
                config = config or GetCellIndicatorConfig(cellButton)
            end)

            if not config then
                print("|cffffe00a[MiliUI]|r 讀不到 Cell.vars.currentLayoutTable[\"indicators\"]")
                return
            end

            local n = 0
            for _, t in pairs(config) do
                if type(t) == "table" and t["indicatorName"] then
                    n = n + 1
                    local auras = BuildSpellIDMap(t["auras"])
                    local ids = {}
                    if auras then
                        for id in pairs(auras) do tinsert(ids, id) end
                        table.sort(ids)
                    end
                    print(("|cffffe00a[MiliUI]|r %s｜type=%s auraType=%s enabled=%s 鏡射=%s 法術=%s"):format(
                        tostring(t["name"] or t["indicatorName"]),
                        tostring(t["type"]),
                        tostring(t["auraType"]),
                        tostring(t["enabled"]),
                        tostring(MIRRORED_TYPES[t["type"]] and auras and true or false),
                        #ids > 0 and table.concat(ids, ",") or "（無）"))
                end
            end
            print(("|cffffe00a[MiliUI]|r 共 %d 個指示器"):format(n))
            return
        end

        -- /cab where：把某一顆按鈕上所有容器的位置與大小倒出來，用來指認畫面上
        -- 那個對不上的東西是哪個容器（還是根本不是我們畫的）。
        if cmd == "where" then
            local n = 0
            IterateCellButtons(function(cellButton)
                local containers = attached[cellButton]
                if not containers or not next(containers) then return end

                -- 只倒「畫得出來」的：按鈕自己是隱藏的話它底下什麼都不會顯示，
                -- 列出來只是干擾。
                if not cellButton:IsVisible() then return end
                n = n + 1

                print(("|cffffe00a[MiliUI]|r %s（unit=%s）螢幕位置 (%.0f, %.0f)"):format(
                    tostring(cellButton:GetName() or "?"), tostring(GetUnitFor(cellButton)),
                    cellButton:GetLeft() or -1, cellButton:GetTop() or -1))

                for key, container in pairs(containers) do
                    local point, _, relativePoint, x, y = container:GetPoint(1)
                    print(("|cffffe00a[MiliUI]|r   %s：%s→%s (%.0f, %.0f) 螢幕 (%.0f, %.0f) 大小 %.0fx%.0f 顯示=%s 格數=%s"):format(
                        key, tostring(point), tostring(relativePoint), x or 0, y or 0,
                        container:GetLeft() or -1, container:GetTop() or -1,
                        container:GetWidth() or 0, container:GetHeight() or 0,
                        tostring(container:IsShown()), tostring(container.__slotCount or "?")))
                end
            end)
            if n == 0 then print("|cffffe00a[MiliUI]|r 沒有任何「可見的」按鈕掛上容器") end
            return
        end

        if cmd == "test" then
            forceOn = not forceOn
            Refresh()
            print("|cffffe00a[MiliUI]|r 強制顯示 " .. (forceOn and "開" or "關")
                .. " —— 開啟時 Cell 圖示會淡出，再打一次 /cab test 切回")
            return
        end

        local function line(k, v) print("|cffffe00a[MiliUI]|r " .. k .. "：" .. tostring(v)) end
        line("build", caps.build)
        line("已啟用", enabled)
        line("AuraContainer intrinsic", caps.auraContainer)
        line("AddAuraGroup", caps.addAuraGroup)
        line("SetAuraGroupLayout", caps.setAuraGroupLayout)
        line("FlowLayout 錨點／每行上限", caps.flowLayout)
        line("FlowLayout 軸向（AnchorUtil.FlowLayoutAxis）", caps.flowAxis)
        line("FlowLayout 生長方向（AnchorUtil.FlowDirection）", caps.flowGrowth)
        line("C_Secrets.ShouldAurasBeSecret", caps.shouldAurasBeSecret)
        line("全程接管（ALWAYS_ON）", ALWAYS_ON)
        if caps.shouldAurasBeSecret then
            line("目前 auras 是否 secret", C_Secrets.ShouldAurasBeSecret())
        else
            line("目前 auras 是否 secret", "無法查詢")
        end

        line("倒數 formatter 是否可用", DurationFormatter ~= nil)
        line("強制顯示（/cab test）", forceOn)

        local perDisplay = {}
        for _, containers in pairs(attached) do
            for key in pairs(containers) do
                perDisplay[key] = (perDisplay[key] or 0) + 1
            end
        end
        for _, display in ipairs(DISPLAYS) do
            line("已掛載容器（" .. display.key .. " / " .. display.filter .. "）", perDisplay[display.key] or 0)
        end
        -- 從活著的容器現算，而不是用累加計數器 —— 重試會讓累加值失真
        local customContainerCount, customSlots, buttonsWithCustom = 0, 0, 0
        for _, containers in pairs(attached) do
            local any = false
            for key, container in pairs(containers) do
                if key:find("^custom") then
                    any = true
                    customContainerCount = customContainerCount + 1
                    customSlots = customSlots + (container.__slotCount or 0)
                end
            end
            if any then buttonsWithCustom = buttonsWithCustom + 1 end
        end
        line("有自訂鏡射的按鈕數", buttonsWithCustom)
        line("自訂指示器容器", customContainerCount)
        line("自訂光環格總數", customSlots)

        local failure = CapabilityFailure()
        if failure then line("失敗原因", failure) end

        -- 按鈕被跳過的原因。掛載數是 0 但上面全部 true 時，關鍵就在這裡。
        local anySkip = false
        for reason, count in pairs(diag.skips) do
            anySkip = true
            line("跳過", ("%s x%d"):format(reason, count))
        end
        if not anySkip then line("跳過", "無") end
        line("上次 Refresh", diag.ranAt and ("%.1f 秒前"):format(GetTime() - diag.ranAt) or "從未執行")
        line("已接上 Cell 回呼", diag.hookedCell)
        if diag.err then line("最後錯誤", diag.err) end
        if diag.layoutErr then line("SetAuraGroupLayout 被拒", diag.layoutErr) end

        -- 從一顆 Cell 按鈕讀到的資料取一筆樣本，這樣錨點或圖示大小不對時
        -- 不必去翻 Cell 的 SavedVariables 就能診斷。
        local dumped = {}
        IterateCellButtons(function(cellButton)
            for _, display in ipairs(DISPLAYS) do
                if not dumped[display.key] then
                    local layout = ReadCellIndicatorLayout(cellButton, display.anchorTo)
                    if layout then
                        dumped[display.key] = true
                        line("版面樣本（" .. display.key .. "）",
                            ("借用=%s point=%s size=%s num=%s hAlign=%s unit=%s"):format(
                                layout.indicatorName, layout.point,
                                ("%dx%d"):format(layout.sizeW, layout.sizeH), layout.num,
                                tostring(layout.hAlignment), tostring(GetUnitFor(cellButton))))
                    end
                end
            end
        end)
    end
end)
