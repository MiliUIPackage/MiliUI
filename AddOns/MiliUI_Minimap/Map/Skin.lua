------------------------------------------------------------
-- 小地圖皮：方形遮罩 ＋ 1px 職業色邊 ＋ 上下兩條資訊帶
--
-- 框架結構（由外而內）：
--
--   holder      普通 frame，掛 UIParent。**位置與尺寸的唯一權威**，也是拖曳目標。
--    ├ Minimap  暴雪的地圖本體，reparent 進來後 SetAllPoints(holder)
--    ├ blocker  滑鼠覆蓋層（滾輪縮放、中鍵）
--    ├ overlay  我們畫的東西：邊框、上下條、座標、時鐘、重新錨過的暴雪按鈕
--    └ drag     解鎖時才顯示的拖曳遮罩
--
-- ⚠ 為什麼要多一層 holder，不直接對 Minimap 設點？
--   因為 Minimap 會被暴雪搶走 —— 住宅系統的轉場、編輯模式重排都會 reparent 它。
--   位置資料放在一個暴雪不認識的框上，搶走了只要把 Minimap 錨回來就好，
--   不必重算位置。（Ellesmere 走的是「Minimap 直接掛 UIParent ＋ 另建 layoutFrame」，
--   同一個問題的另一種解法。）
--
-- ⚠ MinimapCluster 是**編輯模式管的系統框**。這裡對它只做兩件事：
--   `SetAlpha(0)` 與 `EnableMouse(false)`。
--   **不 Hide()、不 SetPoint()、不 SetSize()** —— 那三樣會讓登入時 Edit Mode 跑版面
--   時碰到被我們染過的框，症狀是「嘗試進行 Blizzard UI 專屬動作，遭到封鎖」
--   而且錯誤訊息指向暴雪自己的 RegisterEvent，完全看不出跟這裡有關
--   （見 .claude/notes/project-miliui-hide-blizzard-taint.md）。
------------------------------------------------------------
local _, ns = ...

ns.Skin = {}
local Skin = ns.Skin
local S = ns.Style
local P = ns.P

local holder, overlay, blocker, dragOverlay, borderHost
local topBar, botBar, zoneText, coordText, clockText
local applyQueued = false

-- 方形／圓形遮罩。130937 是暴雪那張純白方塊，186178 是原本的圓形遮罩。
local MASK_SQUARE = 130937
local MASK_CIRCLE = 186178

-- 上下兩條的高度。刻意比字級高 5：文字貼著條的上下緣會看起來像被夾住。
local BAR_PAD = 5

-- 拉角落調整尺寸的上下限。下限 100 是「還看得出地形」的底線，
-- 上限 400 已經佔掉 1080p 螢幕高度的三分之一了。
local MIN_SIZE, MAX_SIZE = 100, 400
Skin.MIN_SIZE, Skin.MAX_SIZE = MIN_SIZE, MAX_SIZE

------------------------------------------------------------
-- 暴雪的裝飾：這些就是「美化」要拿掉的東西
--
-- 一律 alpha 歸零而不是 Hide()：這幾個框有些是暴雪自己會再 Show 回來的，
-- 跟它比誰後叫到 Show 是打不完的仗；alpha 0 它 Show 一百次也是透明的。
------------------------------------------------------------
-- 12.x 的實際結構（Blizzard_Minimap/Mainline/Minimap.xml 查過）：
--
--   Minimap
--     ├ ZoomHitArea / ZoomIn / ZoomOut
--     └ MinimapBackdrop                    ← 圓環那圈畫在這裡面
--          ├ MinimapCompassTexture         （四個箭頭的羅盤環）
--          ├ StaticOverlayTexture          （金邊）
--          └ ExpansionLandingPageMinimapButton   ← ⚠ 功能按鈕，不是裝飾
--   MinimapCluster
--     ├ BorderTop / ZoneTextButton / Tracking / IndicatorFrame
--     ├ MinimapContainer                   ← Minimap 實際掛在這裡
--     └ InstanceDifficulty
--
-- 舊的全域名（MinimapBorder / MinimapBorderTop / MinimapNorthTag）在 12.x 多半
-- 已經不存在，留著只是為了相容老客戶端 —— 查不到就跳過，不算錯。
local BLIZZ_ART = {
    "MinimapBorder", "MinimapBorderTop", "MinimapNorthTag", "TimeManagerClockButton",
}

local function HideBlizzardArt(hide)
    local a = hide and 0 or 1

    for _, name in ipairs(BLIZZ_ART) do
        local f = _G[name]
        if f then f:SetAlpha(a) end
    end

    ------------------------------------------------------------
    -- ⚠⚠ **不要整個 `MinimapBackdrop` alpha 歸零。**
    --
    --   `ExpansionLandingPageMinimapButton`（資料片戰役／龍騎那顆）是它的小孩，
    --   而 alpha 是相乘的 —— 整框歸零會連那顆**功能按鈕**一起弄不見，
    --   而且是靜默的：玩家只會發現「戰役按鈕不見了」，怎麼看都不像小地圖美化造成的。
    --   要關掉的只有它身上那兩張裝飾貼圖。
    ------------------------------------------------------------
    local bd = _G.MinimapBackdrop
    if bd then
        if _G.MinimapCompassTexture then _G.MinimapCompassTexture:SetAlpha(a) end
        if bd.StaticOverlayTexture then bd.StaticOverlayTexture:SetAlpha(a) end
    end

    -- 12.x 的區域名按鈕在 cluster 上；cluster 已經 alpha 0，這裡只是把滑鼠關掉，
    -- 免得看不見的東西還在吃 hover。
    local zb = MinimapCluster and MinimapCluster.ZoneTextButton
    if zb then zb:EnableMouse(not hide) end
    if MinimapCluster and MinimapCluster.BorderTop then
        MinimapCluster.BorderTop:SetAlpha(a)
    end
end

------------------------------------------------------------
-- 暴雪的功能按鈕：追蹤／郵件／製作訂單／副本難度／日曆／插件隔間
--
-- **重新錨位而不是重畫一套。** Ellesmere 是自己畫了一整組 atlas 按鈕再把暴雪的藏起來
-- —— 那樣造型能完全統一，代價是每顆按鈕的點擊行為都要自己重接一次（追蹤選單、
-- 日曆開關、郵件提示…），而且暴雪改一次就要跟一次。我們要的只是「它們不要散在
-- 圓形地圖外圍」，重新錨位就夠了，點擊行為原封不動＝零 taint、零維護。
--
-- ⚠ 它們原本是 MinimapCluster 的小孩，而 cluster 被我們 alpha 歸零了 ——
--   alpha 是**相乘**的，所以不 reparent 就等於全部看不見。
------------------------------------------------------------
local function Anchor(frame, point, rel, relPoint, x, y, level)
    if not frame then return end
    frame:SetParent(overlay)
    frame:ClearAllPoints()
    frame:SetPoint(point, rel, relPoint, x, y)
    if level then frame:SetFrameLevel(overlay:GetFrameLevel() + level) end
    frame:SetAlpha(1)
end

local function LayoutBlizzardButtons()
    local db = ns.DB.Get()
    local cluster = MinimapCluster
    if not cluster then return end

    local topH = topBar and topBar:IsShown() and topBar:GetHeight() or 0
    local botH = botBar and botBar:IsShown() and botBar:GetHeight() or 0
    local inset = 2

    -- 追蹤：左上角，讓開上面那條
    local tracking = cluster.Tracking
    if tracking then
        if db.hideTracking then
            tracking:SetAlpha(0); tracking:EnableMouse(false)
        else
            tracking:EnableMouse(true)
            Anchor(tracking, "TOPLEFT", holder, "TOPLEFT", inset, -(topH + inset), 4)
        end
    end

    -- 郵件／製作訂單（暴雪把兩顆包在同一個容器裡，一起搬）
    local ind = cluster.IndicatorFrame
    if ind then
        if db.hideMail then
            ind:SetAlpha(0); ind:EnableMouse(false)
        else
            ind:EnableMouse(true)
            Anchor(ind, "TOPRIGHT", holder, "TOPRIGHT", -inset, -(topH + inset), 4)
        end
    end

    -- 副本難度旗：左下角，讓開下面那條
    local diff = cluster.InstanceDifficulty or _G.MiniMapInstanceDifficulty
    if diff then
        Anchor(diff, "BOTTOMLEFT", holder, "BOTTOMLEFT", inset, botH + inset, 3)
    end

    -- 日曆：右下角
    local cal = _G.GameTimeFrame
    if cal then
        if db.hideCalendar then
            cal:SetAlpha(0); cal:EnableMouse(false)
        else
            cal:EnableMouse(true)
            Anchor(cal, "BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, botH + inset, 4)
            cal:SetScale(0.85)
        end
    end

    -- 縮放鈕：方形地圖上這兩顆一定會壓到角落的東西，而滾輪已經接管縮放。
    -- reparent 到隱藏框而不是 alpha 0 —— 它們的滑鼠判定區跟角落的按鈕重疊。
    local zin, zout = Minimap.ZoomIn, Minimap.ZoomOut
    if db.hideZoomButtons then
        if zin then zin:SetParent(ns.hiddenParent); zin:Hide() end
        if zout then zout:SetParent(ns.hiddenParent); zout:Hide() end
    else
        if zin and zin:GetParent() == ns.hiddenParent then zin:SetParent(Minimap); zin:Show() end
        if zout and zout:GetParent() == ns.hiddenParent then zout:SetParent(Minimap); zout:Show() end
    end

    -- 暴雪的「插件」隔間鈕。預設藏起來 —— 它是一塊寫著「插件」的**文字招牌**，
    -- 在這套皮旁邊像是別人家的東西，而且它列的入口跟我們的按鈕收納重疊。
    --
    -- ⚠ 藏起來走 **reparent 到隱藏框**，不是 Hide()：暴雪在編輯模式重排與
    --   cluster 更新時會把它 Show 回來、還會重新錨位（Ellesmere 為此掛了
    --   持續性的 hook）。搬到一個它找不到的父層就不必跟它比誰後叫到 Show。
    local comp = _G.AddonCompartmentFrame
    if comp then
        if db.showAddonCompartment then
            comp:SetParent(overlay)
            comp:ClearAllPoints()
            comp:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 0, 3)
            comp:SetAlpha(1)
            comp:SetFrameLevel(overlay:GetFrameLevel() + 4)
        else
            comp:SetParent(ns.hiddenParent)
            comp:Hide()
        end
    end
end

------------------------------------------------------------
-- 上下兩條的內容
------------------------------------------------------------
local lastZone
local function UpdateZone()
    if not zoneText then return end
    local sub = GetMinimapZoneText()
    local text = (sub and sub ~= "") and sub or (GetZoneText() or "")
    if text == lastZone then return end
    lastZone = text
    zoneText:SetText(text)
end

local function UpdateCoords()
    if not coordText or not coordText:IsShown() then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then coordText:SetText("--") return end
    local x, y = pos:GetXY()
    if not x then coordText:SetText("--") return end
    coordText:SetFormattedText("%.1f  %.1f", x * 100, y * 100)
end

local function UpdateClock()
    if not clockText or not clockText:IsShown() then return end
    -- 跟著暴雪的「24 小時制」設定走，玩家不必在兩個地方各設一次
    local h, m
    if GetCVarBool("timeMgrUseLocalTime") then
        h, m = tonumber(date("%H")), tonumber(date("%M"))
    else
        h, m = GetGameTime()
    end
    if not h then return end
    if GetCVarBool("timeMgrUseMilitaryTime") then
        clockText:SetFormattedText("%02d:%02d", h, m)
    else
        -- 大寫。小寫的 am/pm 在描邊白字裡跟數字混成一團（p 的下伸部會跟
        -- 下一條帶的邊貼在一起），大寫的字身高度一致，讀起來才是一個標記。
        local suffix = h >= 12 and "PM" or "AM"
        local h12 = h % 12
        if h12 == 0 then h12 = 12 end
        clockText:SetFormattedText("%d:%02d %s", h12, m, suffix)
    end
end

------------------------------------------------------------
-- 三種顯示模式共用的求值。always / mouseover / never
--
-- 回傳「現在該不該顯示」。mouseover 的判定包含上下兩條自己 —— 只看 Minimap
-- 的話，滑鼠移到條上（條蓋在地圖上面）就會被判定成離開，元素會閃。
------------------------------------------------------------
local hovering = false
local function ModeShown(mode)
    if mode == "never" then return false end
    if mode == "mouseover" then return hovering end
    return true
end

local function ApplyElementVisibility()
    local db = ns.DB.Get()
    local showZone  = ModeShown(db.zoneText)
    local showCoord = ModeShown(db.coords)
    local showClock = ModeShown(db.clock)

    topBar:SetShown(showZone)
    zoneText:SetShown(showZone)
    coordText:SetShown(showCoord)
    clockText:SetShown(showClock)
    botBar:SetShown(showCoord or showClock)

    if showZone then UpdateZone() end
    if showCoord then UpdateCoords() end
    if showClock then UpdateClock() end
end

local function SetHovering(v)
    if hovering == v then return end
    hovering = v
    ns.Safe(ApplyElementVisibility)
    ns.Fire("MinimapHover", v)
end

------------------------------------------------------------
-- ⚠⚠ **FontString 一建出來就要給字型，不能等到 Apply。**
--
--   `FontString:SetText()` 在沒有字型物件的 region 上會直接丟
--   "FontString:SetText(): Font not set"，而不是靜默不畫。
--   踩到的地方是拖曳遮罩的標籤：它在 Build() 裡就 SetText 了，字型卻要等
--   Apply 的字型迴圈才設 —— 於是 Build 整支中斷、Apply 從來沒跑到，
--   症狀是「小地圖完全沒被接管」，跟字型看起來八竿子打不著。
--
--   （同一條在 MiliUI_DamageMeters/Meter/Window.lua 的 MakeBar 也寫著：
--   「建立時就給字型，因為不是所有路徑都會經過 RelayoutBar」。）
--
--   所以這裡不提供「裸的 CreateFontString」—— 一律走這支。
------------------------------------------------------------
local function MakeText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    S.SetFont(fs, size)
    return fs
end

------------------------------------------------------------
-- 建框
------------------------------------------------------------
local function Build()
    if holder then return end

    ns.hiddenParent = CreateFrame("Frame")
    ns.hiddenParent:Hide()

    holder = CreateFrame("Frame", "MiliUIMinimapHolder", UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    ns.holder = holder

    overlay = CreateFrame("Frame", nil, Minimap)
    overlay:SetAllPoints(holder)
    overlay:EnableMouse(false)
    ns.overlay = overlay

    -- 邊框自己一個 host frame。⚠ 不能把 backdrop 直接下在 Minimap 上 ——
    -- 那樣「隱藏邊框」就得 Hide 宿主，整張地圖會跟著不見。
    borderHost = S.CreateBorder(overlay, holder)

    ------------------------------------------------------------
    -- 上下兩條：HUD 皮的底，但**不畫邊**
    -- 外圍已經有一圈職業色邊了，條再各畫一圈就變成三條線疊在一起。
    ------------------------------------------------------------
    local function MakeBar()
        local bar = CreateFrame("Frame", nil, overlay)
        bar:EnableMouse(false)
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(bar)
        return bar
    end
    topBar = MakeBar()
    topBar:SetPoint("TOPLEFT", holder, "TOPLEFT", P.Scale(1), -P.Scale(1))
    topBar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -P.Scale(1), -P.Scale(1))

    botBar = MakeBar()
    botBar:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", P.Scale(1), P.Scale(1))
    botBar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -P.Scale(1), P.Scale(1))

    zoneText = MakeText(topBar)
    zoneText:SetPoint("LEFT", topBar, "LEFT", 4, 0)
    zoneText:SetPoint("RIGHT", topBar, "RIGHT", -4, 0)
    zoneText:SetJustifyH("CENTER")
    zoneText:SetWordWrap(false)

    coordText = MakeText(botBar)
    coordText:SetPoint("LEFT", botBar, "LEFT", 4, 0)
    coordText:SetJustifyH("LEFT")

    clockText = MakeText(botBar)
    clockText:SetPoint("RIGHT", botBar, "RIGHT", -4, 0)
    clockText:SetJustifyH("RIGHT")

    ------------------------------------------------------------
    -- 滑鼠覆蓋層
    --
    -- 兩個理由必須有它：
    --   1. Minimap 自己的滑鼠判定區**永遠是圓的**，跟遮罩無關。方形皮的四個角落
    --      因此是「滾輪死角」，滾上去會直接去縮放攝影機。
    --   2. 從角落進入地圖時 Minimap 的 OnEnter 不會觸發，mouseover 模式的元素
    --      就不會長出來。
    -- 左右鍵一律放行（SetPassThroughButtons），暴雪的 ping 與右鍵追蹤選單照舊。
    ------------------------------------------------------------
    blocker = CreateFrame("Frame", nil, Minimap)
    blocker:SetAllPoints(holder)
    blocker:SetFrameLevel(Minimap:GetFrameLevel() + 2)
    blocker:EnableMouse(true)
    blocker:EnableMouseWheel(true)
    blocker:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton")
    blocker:SetPropagateMouseMotion(true)
    blocker:SetScript("OnEnter", function() SetHovering(true) end)
    blocker:SetScript("OnLeave", function() SetHovering(false) end)
    blocker:SetScript("OnMouseWheel", function(_, delta)
        if not ns.DB.Get().scrollZoom then return end
        local z = Minimap:GetZoom() + (delta > 0 and 1 or -1)
        Minimap:SetZoom(math.max(0, math.min(z, Minimap:GetZoomLevels() - 1)))
    end)

    overlay:SetFrameLevel(blocker:GetFrameLevel() + 2)

    ------------------------------------------------------------
    -- 拖曳遮罩：只有解鎖時才存在
    --
    -- 地圖本身要吃左鍵（ping）與右鍵（追蹤選單），所以拖曳不能直接掛在上面 ——
    -- 那會讓每次 ping 都變成一次微小的位移。解鎖時蓋一層職業色的遮罩，
    -- 玩家一眼看得出「現在是搬家模式」，鎖上就整層消失。
    ------------------------------------------------------------
    dragOverlay = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
    dragOverlay:SetAllPoints(holder)
    dragOverlay:SetFrameLevel(overlay:GetFrameLevel() + 20)
    dragOverlay:EnableMouse(true)
    dragOverlay:RegisterForDrag("LeftButton")
    dragOverlay:Hide()
    dragOverlay:SetBackdrop({ bgFile = S.WHITE, edgeFile = S.WHITE, edgeSize = P.Scale(1) })
    dragOverlay.label = MakeText(dragOverlay, 13)
    dragOverlay.label:SetPoint("CENTER")
    dragOverlay.label:SetText(ns.L["Drag to move"])
    ------------------------------------------------------------
    -- 拉把手：左下角
    --
    -- holder 錨的是 **TOPRIGHT**，所以往左下拉＝右上角釘住不動、地圖往左下長，
    -- 這是唯一不會讓地圖一邊改大小一邊漂移的角落。
    --
    -- ⚠ 不用 `StartSizing`：那支會讓寬高各自跑，而 Minimap 的地形投影與玩家
    --   箭頭**要求畫布是正方形**（長方形要另外做一張裁切遮罩貼圖，見下面的註解）。
    --   自己讀游標算邊長反而更短、也能保證正方。
    ------------------------------------------------------------
    -- ⚠ 造型：**三格斜階**，不是一塊實心方塊。
    --   第一版是「邊長 = 地圖 1/5 的實心色塊」—— 使用者第一眼的反應是
    --   「地圖左下角有個方塊」，也就是說它完全沒有傳達「這裡可以拉」。
    --   一塊沒有形狀的色塊只會被讀成「這裡有東西壞了」。
    --   斜階是縮放把手的通用符號，而且它只用三張方形貼圖就畫得出來 ——
    --   不必旋轉、不必圖檔，也還在「純色直角」的語言裡。
    --
    --   點擊範圍（GRIP_HIT）比圖案大：圖案要小才不擋地圖，但 8px 的東西
    --   在遊戲裡抓不到。
    local GRIP_HIT, GRIP_STEP = 20, 3
    local grip = CreateFrame("Button", nil, dragOverlay)
    grip:SetPoint("BOTTOMLEFT", dragOverlay, "BOTTOMLEFT", 0, 0)
    grip:SetSize(P.Scale(GRIP_HIT), P.Scale(GRIP_HIT))
    grip:SetFrameLevel(dragOverlay:GetFrameLevel() + 1)
    grip:RegisterForClicks("LeftButtonUp")
    grip.steps = {}
    for i = 1, 3 do
        local t = grip:CreateTexture(nil, "OVERLAY")
        -- ⚠ 一定要先給貼圖。空的 texture 上 SetVertexColor 是**靜默無效**的
        --   （沒有東西可以染色），畫面上什麼都不會出現。
        t:SetColorTexture(1, 1, 1, 1)
        t:SetSize(P.Scale(GRIP_STEP), P.Scale(GRIP_STEP))
        -- 由左下往右上一格一格退，畫成 ⋰
        t:SetPoint("BOTTOMLEFT", grip, "BOTTOMLEFT",
            P.Scale(3 + (i - 1) * (GRIP_STEP + 1)),
            P.Scale(3 + (3 - i) * (GRIP_STEP + 1)))
        grip.steps[i] = t
    end
    dragOverlay.grip = grip

    local function TintGrip(a)
        for _, t in ipairs(grip.steps) do t:SetVertexColor(S.Accent(a)) end
    end
    grip.Tint = TintGrip

    grip:SetScript("OnEnter", function(self)
        TintGrip(1)
        local tip = ns.Tip.Open(self, "BOTTOMLEFT", "TOPLEFT", 0, 4)
        -- ⚠ S.Accent() 回四個值，AddLine 的第四個參數是 wrapText —— 直接展開
        --   會把 alpha 當成換行旗標（見 Panel/Tip.lua 的 AddSection 註解）。
        local ar, ag, ab = S.Accent()
        tip:AddLine(ns.L["Drag to resize"], ar, ag, ab)
        tip:AddLine(("%d × %d"):format(math.floor(holder:GetWidth() + 0.5),
                                       math.floor(holder:GetHeight() + 0.5)), 1, 1, 1)
        tip:Show()
    end)
    -- ⚠ 靜置亮度**不用 STATE_ALPHA.idle（0.55）**。那個階是給常駐在畫面上的元件用的
    --   —— 平常低調、滑過才亮。這顆把手相反：它只在編輯模式存在幾秒鐘，
    --   「被找到」就是它的全部工作，低調等於失效。
    local GRIP_REST = 0.85
    grip:SetScript("OnLeave", function()
        TintGrip(GRIP_REST)
        ns.Tip.Close()
    end)
    grip.REST = GRIP_REST

    local function GripUpdate()
        local hs = holder:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / hs, cy / hs
        local right, top = holder:GetRight(), holder:GetTop()
        if not right then return end
        -- 兩軸取較大的那個：使用者往哪個方向推得多就跟哪邊走，
        -- 比硬綁單一軸自然（斜著拉的時候不會覺得「只有橫的有反應」）。
        local want = math.max(right - cx, top - cy)
        local size = math.max(MIN_SIZE, math.min(MAX_SIZE, want))
        size = P.Scale(size)
        holder:SetSize(size, size)
        Minimap:SetSize(size, size)
        dragOverlay.label:SetFormattedText("%d × %d", size, size)
    end

    grip:SetScript("OnMouseDown", function(self)
        self:SetScript("OnUpdate", GripUpdate)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        ns.DB.Get().size = math.floor(holder:GetWidth() + 0.5)
        dragOverlay.label:SetText(ns.L["Drag to move"])
        ns.Tip.Close()
        ns.Safe(Skin.Apply)
    end)

    dragOverlay:SetScript("OnDragStart", function() holder:StartMoving() end)
    dragOverlay:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        Skin.SavePosition()
    end)
    -- 右鍵叫回右上角。拖到看不見是必然會發生的意外，而位置有存檔，
    -- 關掉再開救不回來（設定視窗的把手也是同一套約定）。
    dragOverlay:SetScript("OnMouseUp", function(_, btn)
        if btn ~= "RightButton" then return end
        local db = ns.DB.Get()
        db.x, db.y = ns.DB.DEFAULTS.x, ns.DB.DEFAULTS.y
        Skin.ApplyPosition()
    end)
end

------------------------------------------------------------
-- 位置
------------------------------------------------------------
-- ⚠ 位移的單位是**被錨的那個框自己的 effective scale**，不是 UIParent 的。
--   holder 有自己的 SetScale（設定裡的「整體縮放」），所以算差值要先把兩邊都
--   換算成螢幕像素，再除回 holder 的 scale —— 少了最後那一步，縮放不是 1 的人
--   每存一次位置地圖就往角落漂一點（見 wow-setscale-offset-units）。
function Skin.SavePosition()
    local db = ns.DB.Get()
    local hs = holder:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale()
    db.x = math.floor((holder:GetRight() * hs - UIParent:GetRight() * us) / hs + 0.5)
    db.y = math.floor((holder:GetTop() * hs - UIParent:GetTop() * us) / hs + 0.5)
    ns.Fire("MinimapMoved")
end

function Skin.ApplyPosition()
    local db = ns.DB.Get()
    holder:ClearAllPoints()
    holder:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", db.x, db.y)
end

------------------------------------------------------------
-- 接管 Minimap
--
-- ⚠ 全部延後一幀（C_Timer.After(0)）。同步做會在 ShowUIPanel／開世界地圖的
--   流程中途動到 secure frame 環境，症狀是稍後地城圖釘的資料提供者呼叫受保護的
--   SetPropagateMouseClicks 時噴 ADDON_ACTION_BLOCKED —— 錯誤指向地圖圖釘，
--   完全看不出跟小地圖有關。（這一條是照 Ellesmere 的註解抄的，它踩過。）
------------------------------------------------------------
local parentGuardInstalled = false

local function TakeOver()
    if InCombatLockdown() then Skin.Queue(); return end

    C_Timer.After(0, function()
        if InCombatLockdown() then Skin.Queue(); return end
        if Minimap:GetParent() ~= holder then
            Minimap:SetParent(holder)
        end
        Minimap:ClearAllPoints()
        Minimap:SetPoint("CENTER", holder, "CENTER", 0, 0)
        if MinimapCluster then
            MinimapCluster:SetAlpha(0)
            MinimapCluster:EnableMouse(false)
        end
    end)

    if not parentGuardInstalled then
        parentGuardInstalled = true
        -- 暴雪在住宅轉場等時機會把 Minimap 搶回去。只**排程**搶回來，
        -- 不要在 hook 裡同步做 —— 那等於跑在暴雪的安全流程裡
        -- （見 project-miliui-hide-blizzard-taint 第 2 條）。
        hooksecurefunc(Minimap, "SetParent", function()
            if Minimap:GetParent() == holder then return end
            C_Timer.After(0, function()
                if InCombatLockdown() then Skin.Queue(); return end
                if Minimap:GetParent() ~= holder then
                    Minimap:SetParent(holder)
                    Minimap:ClearAllPoints()
                    Minimap:SetPoint("CENTER", holder, "CENTER", 0, 0)
                end
            end)
        end)
        if Minimap.SetFixedFrameStrata then Minimap:SetFixedFrameStrata(true) end
        if Minimap.SetFixedFrameLevel then Minimap:SetFixedFrameLevel(true) end
    end
end

------------------------------------------------------------
-- 套用全部設定
--
-- 這支會走過整個 frame 樹，所以**只在設定變動時呼叫**，絕不進刷新迴圈。
-- 刷新迴圈只做 SetText。
------------------------------------------------------------
function Skin.Apply()
    if not holder then return end
    local db = ns.DB.Get()

    if InCombatLockdown() then Skin.Queue(); return end
    applyQueued = false

    ------------------------------------------------------------
    -- 尺寸與形狀
    ------------------------------------------------------------
    -- 一個算好的像素值餵給兩個框。holder 用 P.Scale、Minimap 用原始值的話，
    -- 兩者會差到不足 1px —— 但那正好是「邊框某一側露出一條地形」的量
    -- （見 project-miliui-pixel-snapping）。
    local size = P.Scale(db.size)
    holder:SetScale(db.scale)
    holder:SetSize(size, size)
    Minimap:SetSize(size, size)
    Minimap:SetMaskTexture(db.shape == "circle" and MASK_CIRCLE or MASK_SQUARE)

    -- 方形地圖上那圈圓形的任務／考古範圍環會突出到角落外面
    local circle = db.shape == "circle"
    if Minimap.SetArchBlobRingScalar then Minimap:SetArchBlobRingScalar(circle and 1 or 0) end
    if Minimap.SetQuestBlobRingScalar then Minimap:SetQuestBlobRingScalar(circle and 1 or 0) end

    Skin.ApplyPosition()
    TakeOver()

    ------------------------------------------------------------
    -- 外觀
    ------------------------------------------------------------
    S.RefreshBorder(borderHost)
    local br, bg, bb, ba = S.BackdropColor()
    local barH = db.fontSize + BAR_PAD
    for _, bar in ipairs({ topBar, botBar }) do
        bar:SetHeight(barH)
        -- 兩條比整體底色再實心一階（alpha +0.1）：它們是疊在**地圖上面**的，
        -- 跟外框同一個 alpha 會讓地形從字底下透出來，白字在雪地上就沒了。
        bar.bg:SetColorTexture(br, bg, bb, math.min(1, ba + 0.1))
    end
    for _, fs in ipairs({ zoneText, coordText, clockText }) do
        S.SetFont(fs, db.fontSize)
        fs:SetTextColor(unpack(S.TEXT))
    end

    dragOverlay:SetBackdropColor(S.Accent(0.25))
    dragOverlay:SetBackdropBorderColor(S.Accent(1))
    S.SetFont(dragOverlay.label, 13)
    -- 把手的尺寸是固定的（建立時就設好），這裡只重新上色 ——
    -- 它是一個符號不是版面元件，跟著地圖放大只會變成一塊礙眼的色塊。
    dragOverlay.grip.Tint(dragOverlay.grip.REST)
    Skin.RefreshDrag()

    ------------------------------------------------------------
    -- 暴雪的東西
    ------------------------------------------------------------
    HideBlizzardArt(db.hideBlizzardArt)
    ApplyElementVisibility()
    LayoutBlizzardButtons()

    ns.Fire("SkinApplied")
end

-- 戰鬥中不能改版面（reparent 受保護框會被封鎖）。排一次，出戰鬥補跑。
--
-- ⚠ 等待用的 frame **建一次就留著**，不要每次排程都 CreateFrame ——
--   WoW 的 frame 刪不掉，那是每進出一次戰鬥就永久多一個
--   （見 .claude/notes/wow-frame-lifecycle-costs.md）。
local waiter
function Skin.Queue()
    if applyQueued then return end
    applyQueued = true
    if not waiter then
        waiter = CreateFrame("Frame")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            ns.Safe(Skin.Apply)
        end)
    end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
end

------------------------------------------------------------
-- 拖曳遮罩的顯示與「鎖定」設定是**兩件事**
--
-- ⚠ 之前是同一支：設定視窗一開就叫 SetLocked(false) 把地圖解鎖（開設定多半就是
--   要調位置，不該逼玩家先去找那個勾選框），但那支會**寫進 DB** —— 於是關掉視窗
--   時讀回來的 db.locked 已經是 false，鎖定狀態每開一次設定就被洗掉一次。
--   現在分成：SetLocked 才寫檔，RefreshDrag 只算「現在該不該顯示遮罩」。
------------------------------------------------------------
function Skin.RefreshDrag()
    if not dragOverlay then return end
    dragOverlay:SetShown(ns._optionsOpen or not ns.DB.Get().locked)
end

function Skin.SetLocked(locked)
    ns.DB.Get().locked = locked
    Skin.RefreshDrag()
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local ZONE_EVENTS = {
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_ENTERING_WORLD",
}

ns.RegisterCallback("Init", "Skin", function()
    Build()
    Skin.Apply()

    local ev = CreateFrame("Frame")
    for _, e in ipairs(ZONE_EVENTS) do ev:RegisterEvent(e) end
    ev:RegisterEvent("UPDATE_PENDING_MAIL")
    ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
    ev:RegisterEvent("UI_SCALE_CHANGED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "DISPLAY_SIZE_CHANGED"
            or event == "UI_SCALE_CHANGED" then
            -- 編輯模式跑完版面會把 cluster 的 alpha 與按鈕位置還原
            ns.Safe(Skin.Apply)
        else
            lastZone = nil
            ns.Safe(ApplyElementVisibility)
        end
    end)

    -- 座標與時鐘共用**一個** ticker。兩個各開一個 OnUpdate 是團隊框那條教訓的
    -- 縮小版：N 個每幀腳本的成本主要在派送次數，不在腳本內容
    -- （見 .claude/notes/wow-unitframe-event-dispatch-cost.md）。
    -- 0.5 秒對「走路時的座標」與「分鐘制的時鐘」都綽綽有餘。
    C_Timer.NewTicker(0.5, function()
        if not holder or not holder:IsVisible() then return end
        ns.Safe(UpdateCoords)
        ns.Safe(UpdateClock)
    end)
end)

ns.RegisterCallback("ConfigChanged", "Skin", function()
    ns.Safe(Skin.Apply)
end)

ns.RegisterCallback("AccentChanged", "Skin", function()
    if borderHost then S.RefreshBorder(borderHost) end
    if dragOverlay then
        dragOverlay:SetBackdropColor(S.Accent(0.25))
        dragOverlay:SetBackdropBorderColor(S.Accent(1))
    end
end)
