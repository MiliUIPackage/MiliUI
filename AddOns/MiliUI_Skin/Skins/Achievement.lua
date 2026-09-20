------------------------------------------------------------
-- 配方：成就視窗（Blizzard_AchievementUI）—— 隨需載入 ＋ ScrollBox 的代表
--
-- 暴雪原始碼出處（12.1.0.69875）：
--   Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml / .lua
--   Blizzard_SharedXML/Backdrop.lua（BACKDROP_ACHIEVEMENTS_0_64、ApplyBackdrop）
--   Blizzard_SharedXML/SharedTooltipTemplates.xml:107,123（TooltipBackdropTemplate
--     → parentKey NineSlice；TooltipBorderBackdropTemplate 繼承它）
--   Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml
--   Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml（SearchBoxTemplate）
--   Blizzard_Menu/Mainline/MenuTemplates.xml:66（WowStyle1FilterDropdownTemplate）
--
-- 這個視窗是**舊式**的：不繼承 PortraitFrameTemplate，外框是
-- `BackdropTemplate` ＋ 十幾張 `$parent…` 具名貼圖（木框、金屬框、接角）。
-- backdrop 的九片是 `NineSliceUtil.ApplyLayout(self, …)` 直接掛在 frame 上的
-- 欄位（TopEdge / LeftEdge / TopLeftCorner / … / Center），所以點名得到。
--
------------------------------------------------------------
-- ## 為什麼這個視窗破例連「內容底材」一起換
--
-- STYLE.md ③ 的預設規則是「內容底材保留」（羊皮紙上的字色是為那張底設計的）。
-- 成就視窗是**唯一**的例外，理由是外框換了皮之後它變成全套最不協調的地方：
-- 深灰外框裡包著一整片亮橘羊皮紙 ＋ 一條木頭分類欄。
--
-- 破例的代價是規則的後半段：**換了底材就要連同上面所有文字顏色一起接管，而且
-- 要查清楚暴雪在哪些路徑重設那些顏色。** 這個視窗有四條：
--
--   1. `AchievementTemplateMixin:Saturate`（.lua:1395）
--      → `Description:SetTextColor(0, 0, 0, 1)` —— **黑字**，壓在深底上完全看不見。
--   2. `AchievementTemplateMixin:Desaturate`（.lua:1428）
--      → `Description:SetTextColor(1, 1, 1, 1)`
--   3. `AchievementTemplateMixin:Init`（.lua:1194）—— 每次重用都跑，而且
--      **只有在 `saturatedStyle` 變了的時候才呼叫 Saturate**（.lua:1288），
--      所以不能只勾 Saturate。
--   4. `AchievementObjectives_DisplayCriteria`（.lua:2044）與
--      `…_DisplayProgressiveAchievement` → 已完成的子目標也是 `(0, 0, 0, 1)`。
--
-- 三條都勾（後置勾），`Description` 一律接管成 `textDim`。
-- **已完成／未完成的區別改用明暗**：暴雪自己在 Saturate/Desaturate 裡把
-- `Label`（標題）與 `Icon.texture` 的 vertex color 在 1.0 / 0.65 之間切，那個保留；
-- 我們只多加一層「整列底色」的明暗（完成＝`fill`、未完成＝`fillInset`）。
-- **不換色相** —— 沒有綠列紅列。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 外框
--
-- | 物件 | 動作 |
-- |---|---|
-- | AchievementFrame 的 backdrop 九片（TopEdge…Center） | SetAlpha(0) |
-- | AchievementFrame.Background（UI-Background-Rock-Brown） | SetAlpha(0) |
-- | AchievementFrameMetalBorder{Left,Right,Top,Bottom}、四個接角 | SetAlpha(0) |
-- | AchievementFrameWoodBorder{TopLeft,TopRight,BottomLeft,BottomRight} | SetAlpha(0) |
-- | AchievementFrameWaterMark、AchievementFrameCategoriesBG | SetAlpha(0) |
-- | AchievementFrameGuildEmblem{Left,Right}（公會分頁才顯示） | SetAlpha(0) |
-- | AchievementFrame.Header 的 Left / Right / PointBorder / RightDDLInset | SetAlpha(0) |
-- | AchievementFrame.Header 的 Title / Points | SetTextColor |
-- | AchievementFrame.Header（標題帽） | CreateFrame 掛自己的 overlay，錨在 PointBorder 上 |
-- | AchievementFrame.HeaderDetails.TopTileStreaks | SetAlpha(0) |
-- | AchievementFrame.HeaderDetails.Back（UIPanelButtonTemplate） | SetAlpha(0) / SetColorTexture / SetNormalFontObject |
-- | AchievementFrame.HeaderDetails.Filters.SearchBox | SetAlpha(0) / SetVertexColor / SetTextColor |
-- | AchievementFrame.HeaderDetails.Filters.FilterDropdown.Background | SetAlpha(0) |
-- | 三個 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 三個 MinimalScrollBar 的 Back/Forward.Texture | SetVertexColor |
-- | AchievementFrameTab1..3 的九張貼圖 | SetAlpha(0) |
-- | AchievementFrameCloseButton 的狀態貼圖 | SetAlpha(0) / SetColorTexture |
--
-- ### 內容區（破例的部分）
--
-- | 物件 | 動作 |
-- |---|---|
-- | AchievementFrame.Categories / …Achievements / …Stats / …Summary 的 NineSlice ＋ 各面板裡的無名金邊 | SetAlpha(0) |
-- | 同上四個面板自己的貼圖（羊皮紙／木頭／統計底） | SetAlpha(0)（GetRegions 掃） |
-- | AchievementFrameStatsBG 的無名底圖 | SetAlpha(0) |
-- | 分類列（池化）的 Button.Background ＋ **Highlight 貼圖** | SetAlpha(0) |
-- | 分類列的 Button | HookScript("OnEnter"/"OnLeave")（兩態都自己畫，見下面） |
-- | 分類列的 Button.Label | SetTextColor |
-- | 成就列（池化）**apply**：Background / NineSlice / RewardBackground / 四角 Tsunami / GuildCornerL/R | SetAlpha(0) |
-- | 成就列（池化）**reapply**：TitleBar / BottomTsunami1 / TopTsunami1 / Icon.frame / Icon.bling | SetAlpha(0) |
-- | 成就列的 Description | SetTextColor |
-- | 成就列的 Icon.texture | SetTexCoord |
-- | 子目標（池化）的 Name / MetaCriteria.Label | SetTextColor |
-- | 子目標進度條的無名底圖與邊框 | SetAlpha(0) |
-- | 子目標進度條與總結頁 13 條的填充 | SetStatusBarTexture ＋ SetVertexColor（暴雪自己的綠） |
-- | 統計列（池化）的 Left / Middle / Right / Background | SetAlpha(0) |
-- | 總結頁兩塊小節標題的底圖 | SetAlpha(0)；Title | SetTextColor |
-- | 總結頁 13 條進度條的無名美術 | SetAlpha(0)；Label | SetTextColor |
-- | 總結頁「最近達成」五列 | 同成就列 |
--
-- ### 比較視窗（第三輪補完）
--
-- | 物件 | 動作 |
-- |---|---|
-- | AchievementFrameComparisonBackground / .Dark / .Watermark ＋ 無名的金邊子框 | SetAlpha(0) |
-- | AchievementFrameComparisonHeaderBG | SetAlpha(0) |
-- | AchievementFrameComparisonHeaderName / .Points | SetTextColor |
-- | Summary.Player / .Friend 的羊皮紙（GetRegions 掃）與 NineSlice | SetAlpha(0) |
-- | 同兩塊的 StatusBar | 同進度條 |
-- | AchievementContainer / StatContainer 的 ScrollBar | 同捲軸 |
--
-- 以上各框：`CreateFrame` 掛自己的 overlay。
--
-- hook（全部是後置勾，不換函式）：
--   * Engine 的三個 `PanelTemplates_*` 全域後置勾（成就視窗自己也是走
--     `PanelTemplates_UpdateTabs` 切分頁，見 Blizzard_AchievementUI.lua:258-260）。
--   * `Engine.HookRows` ×7：分類列的 `Init` 與 `UpdateSelectionState`、
--     成就列的 `Init` / `Saturate` / `Desaturate`、統計列的 `Init`、
--     總結頁列的 `AchievementComparisonPlayerButton_Saturate` / `_Desaturate`（全域）。
--   * `hooksecurefunc("AchievementObjectives_DisplayCriteria", …)` 與
--     `…_DisplayProgressiveAchievement` —— 展開後的子目標文字色與進度條。
--   * `hooksecurefunc("AchievementFrameSummary_Refresh", …)` —— 總結頁五列的
--     `TitleBar` 每次都被設回 0.5（.lua:2364），跟 `_Saturate` 是兩條獨立的路。
--   * 分類列的 `HookScript("OnEnter"/"OnLeave")`（滑過態；模板自己的 OnEnter 保留，
--     `AchievementCategoryTemplateButtonMixin:OnEnter` 會開提示）。
--
-- 寫入暴雪欄位：無。
--
-- 讀暴雪物件（契約的讀取例外）：
--   * `AchievementCategoryTemplateMixin:UpdateSelectionState` 的 `selected` 參數
--     （純布林，過 `Secret.ToBool`）—— 分類列的選中底色。
--   * 子目標的 `criteria.Check:IsShown()` / `meta.Check:IsShown()`（純 C 端布林）
--     —— 暴雪自己判斷「這條完成了沒」的同一個依據（.lua:2056 / .lua:1988）。
--   * `objectivesFrame.criterias` / `.metas` / `.progressBars`（走訪自己的池子拿
--     frame 參照，不讀欄位值）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **盾牌點數徽章**（`row.Shield`）—— 那是分數，`AchievementShield_Saturate`
--   用 TexCoord 在彩色／灰階之間切，本來就是明暗語彙。
-- * **成就列的 `Label` 與 `Icon.texture` 的 vertex color** —— 完成 1.0／未完成 0.65，
--   那正是我們要的明暗，接管反而會把資訊抹掉。
-- * **`Reward` 的金字**、子目標的 `RepCriteria`（綠／紅）—— 深底上讀得到，而且是資訊。
-- * **成就列的 `Highlight` 框**（UI-Character-ReputationBar-Highlight，ADD 疊加）——
--   暴雪自己在 OnEnter/OnLeave 顯示隱藏，ADD 疊在深底上正好是一次提亮。
-- * **搜尋預覽／完整搜尋結果**（`SearchPreviewContainer` / `SearchResults`）——
--   STYLE.md ⑦ 的 B 級，會動態建立子框，成本要先量。
-- * **比較視窗的頭像與頭像底**（`…HeaderPortrait` / `…HeaderPortraitBg`）——
--   頭像是身分，底下那塊純黑方塊是它的襯底，拿掉頭像會直接貼在面板上。
-- * **彈出的下拉選單**（`Filters.FilterDropdown` 展開後的那張）—— C 級，只 skin 按鈕本體。
--
-- ⚠ overlay 一律不 parent 到 `HeaderDetails.Filters`（`HorizontalLayoutFrame`）：
--   那種框會走訪 children 讀 layoutIndex 與尺寸。搜尋框的 overlay 掛在搜尋框
--   自己身上，Engine.SafeParent 也會再擋一次。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret
local L = ns.L

-- 暴雪自己寫死的進度綠。出處：`AchievementFrameSummaryCategoryTemplate` 的 OnLoad
-- （Blizzard_AchievementUI.xml:562）與 `AchievementProgressBarTemplate` 的 OnLoad
-- （同檔 :1909），兩支都是 `self:SetStatusBarColor(0, .6, 0, 1)`。
--
-- ⚠ 為什麼要把它抄下來再重下一次：那兩支 OnLoad **只在 frame 建立時跑一次**，
--   之後沒有任何路徑會再設一次顏色。換填充材質有可能把填充貼圖的 vertex color
--   一起重置 —— 真的被重置就再也沒人補回來，整排條會變成白色。
--   抄一個常數重下最省事，而且這是「查證來的暴雪值」不是我們挑的顏色
--   （`Skin.StatusBar` 的 `opts.color` 走貼圖的 SetVertexColor，不是 SetStatusBarColor）。
--   聲望條不需要這一招：`ReputationEntryMixin:Initialize` 每次都呼叫
--   `UpdateBarColor`（ReputationFrame.lua:502,524,547），顏色本來就每次重設。
local ACHIEVEMENT_BAR_GREEN = { 0, 0.6, 0 }

-- BackdropTemplateMixin:ApplyBackdrop 建出來的九片（Blizzard_SharedXML/Backdrop.lua:317）
local BACKDROP_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

local FRAME_ART_GLOBALS = {
    "AchievementFrameMetalBorderLeft",
    "AchievementFrameMetalBorderRight",
    "AchievementFrameMetalBorderTop",
    "AchievementFrameMetalBorderBottom",
    "AchievementFrameMetalBorderTopLeft",
    "AchievementFrameMetalBorderTopRight",
    "AchievementFrameMetalBorderBottomLeft",
    "AchievementFrameMetalBorderBottomRight",
    "AchievementFrameWoodBorderTopLeft",
    "AchievementFrameWoodBorderTopRight",
    "AchievementFrameWoodBorderBottomLeft",
    "AchievementFrameWoodBorderBottomRight",
    "AchievementFrameWaterMark",
    -- 左邊分類欄的木頭／羊皮紙底（Blizzard_AchievementUI.xml:1560）
    "AchievementFrameCategoriesBG",
    -- 公會分頁才顯示的兩片公會徽記（XML:1578）—— 平常 hidden，中和了才不會在
    -- 切到公會分頁時突然冒出一塊亮色
    "AchievementFrameGuildEmblemLeft",
    "AchievementFrameGuildEmblemRight",
}

------------------------------------------------------------
-- 內容面板：金邊 ＋ 底材一起拿掉，換成內嵌區的皮
------------------------------------------------------------
local function SkinContentPanel(panel, key, opts)
    opts = opts or {}
    if not panel then
        E.Missing(key)
        return
    end
    if opts.ownNineSlice then
        E.NeutralizeKeys(panel, { "NineSlice" }, key)
    end
    E.NeutralizeChildNineSlices(panel, key)

    -- ⚠ 這裡就是「破例」的那一刀：面板自己的底材（羊皮紙／統計底／那張蓋在上面的
    --   黑色 0.75 遮罩）全部中和，改用我們的內嵌皮。上面的文字顏色由下面那幾支
    --   後置勾接管 —— 兩件事一定要成對做，只做一半就是黑字壓深底。
    E.NeutralizeRegions(panel, key)

    local ov = E.Overlay(panel, { key = key })
    E.Paint(ov, T.fillInset, T.border)

    if opts.noScrollBar then return end
    local bar
    if pcall(function() bar = panel.ScrollBar end) and bar then
        Skin.ScrollBar(bar, key .. ".ScrollBar")
    else
        E.Missing(key .. ".ScrollBar")
    end
end

------------------------------------------------------------
-- 標題帽
--
-- 幾何全部查證自 Blizzard_AchievementUI.xml:1926 起，換算成「相對視窗上緣」：
--   `AchievementFrame.Header` 726x106，`BOTTOMLEFT` 錨在視窗 `TOPLEFT` x=26 y=-38
--     ⇒ Header 的下緣在視窗上緣**之下 38**。
--   `Header.PointBorder` 133x39，`BOTTOM` 錨 Header `BOTTOM` x=20 y=16
--     ⇒ 它的下緣在視窗上緣之下 22、上緣在視窗上緣**之上 17**。
--   `Header.Title` 150x20（maxLines=2），`TOP` 錨 PointBorder `TOP` y=+12
--     ⇒ 標題頂端在視窗上緣之上 29；寬度比 PointBorder 多 17（左右各 8.5）。
--   `Header.Points` `TOP` 錨 PointBorder `TOP` y=-13
--     ⇒ 點數**正好跨在視窗 overlay 的上邊線上**（這就是要做帽子的原因）。
--   `Header.Shield` 20x20 貼在 Points 右邊 +3。
--
-- 帽子＝「從視窗上緣凸出去的一顆分頁」，跟底部分頁同一套語彙、上下鏡射：
-- `T.fill` ＋ 1px 黑邊，**下邊不畫**（`skipEdges`），所以它跟視窗本體連成一塊，
-- 而那一段上邊線也就不會從點數中間穿過去。
--
-- 三個實作上的講究：
--   * **錨在 `PointBorder` 這張貼圖上**（`anchorTo`），target 傳 `Header`。
--     貼圖沒有 `GetFrameLevel`，直接拿它當 target 會讓 overlay 退回
--     「parent 的層級 +1」—— 那就蓋住標題與點數了。target 是 Header ⇒
--     層級走 `levelOffset = -1` 落在 Header 之下、視窗本體 overlay 之上。
--   * parent 明確指定 `Header`（它是普通 Frame，不是 layout host），不靠 SafeParent 猜。
--   * **不吃滑鼠**（`Engine.Overlay` 本來就不 EnableMouse）—— Header 自己是
--     `enableMouse="true"` 的拖曳區，擋掉就不能拖視窗了。
--
-- 左右各外擴 20：要包住比 PointBorder 寬 8.5 的 Title，也要包住 Points 右邊
-- 那面 20x20 的盾（點數字串置中，"25085" 這種長度加上盾還在 66 的半寬內）。
-- 上方外擴 18：Title 頂端在 PointBorder 上緣之上 12，留 6 的邊距；
-- maxLines=2 是**往下**長的，兩行也不會頂出去。
local HEADER_CAP_POINTS = {
    { "TOPLEFT", "TOPLEFT", -20, 18 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", 20, 0 },
}

local function SkinHeaderCap(f, header)
    local pointBorder
    if not (pcall(function() pointBorder = header.PointBorder end) and pointBorder) then
        E.Missing("AchievementFrame.Header.PointBorder")
        return
    end
    local ov = E.Overlay(header, {
        key = "AchievementFrame.Header.cap",
        parent = header,
        anchorTo = pointBorder,
        points = HEADER_CAP_POINTS,
        skipEdges = { "BOTTOM" },
    })
    E.Paint(ov, T.fill, T.border)
end

local function SkinHeader(f)
    local header
    if not (pcall(function() header = f.Header end) and header) then
        E.Missing("AchievementFrame.Header")
        return
    end
    -- Left/Right 是那塊木頭橫幅，PointBorder 是點數的小牌子。
    -- 三張拿掉之後標題與點數本來是直接浮在面板上方的 —— 第二輪就是這樣，
    -- 結果是「戰隊成就點數」整組懸在框外、上邊線從點數中間穿過去。
    -- 第三輪補一頂**標題帽**（見上面那一段）把它收回視窗的輪廓裡。
    -- RightDDLInset 平常 hidden，公會分頁會顯示，一起中和
    E.NeutralizeKeys(header, { "Left", "Right", "PointBorder", "RightDDLInset" },
        "AchievementFrame.Header")

    SkinHeaderCap(f, header)

    local title, points
    if pcall(function() title = header.Title end) and title then
        E.TextColor(title, T.text, "AchievementFrame.Header.Title")
    end
    if pcall(function() points = header.Points end) and points then
        E.TextColor(points, T.text, "AchievementFrame.Header.Points")
    end
end

local function SkinHeaderDetails(f)
    local hd
    if not (pcall(function() hd = f.HeaderDetails end) and hd) then
        E.Missing("AchievementFrame.HeaderDetails")
        return
    end
    E.NeutralizeKeys(hd, { "TopTileStreaks" }, "AchievementFrame.HeaderDetails")

    local back
    if pcall(function() back = hd.Back end) and back then
        Skin.Button(back, "AchievementFrame.HeaderDetails.Back")
    else
        E.Missing("AchievementFrame.HeaderDetails.Back")
    end

    local filters
    if not (pcall(function() filters = hd.Filters end) and filters) then
        E.Missing("AchievementFrame.HeaderDetails.Filters")
        return
    end

    local search
    if pcall(function() search = filters.SearchBox end) and search then
        Skin.EditBox(search, "AchievementFrame.HeaderDetails.Filters.SearchBox")
    else
        E.Missing("AchievementFrame.HeaderDetails.Filters.SearchBox")
    end

    -- 篩選下拉跟聲望／通貨頁的是同一族（都是 DropdownButton ＋ ButtonStateBehaviorMixin），
    -- 只是背景 atlas 不同、沒有 Arrow ⇒ kind = "filter"。
    local dd
    if pcall(function() dd = filters.FilterDropdown end) and dd then
        Skin.Dropdown(dd, "AchievementFrame.HeaderDetails.Filters.FilterDropdown", "filter")
    else
        E.Missing("AchievementFrame.HeaderDetails.Filters.FilterDropdown")
    end
end

------------------------------------------------------------
-- 分類列（左欄，池化）
--
-- 出處：Blizzard_AchievementUI.xml:622 `AchievementCategoryTemplate`
--   Button.Background  UI-Achievement-Category-Background（雕花木牌）
--   Button.Label       GameFontNormal / GameFontHighlight（Init 依層級換字型物件）
--   Button 的 HighlightTexture  UI-Achievement-Category-Highlight（ADD）
--
-- 選中態：`AchievementCategoryTemplateMixin:UpdateSelectionState`（.lua:602）走的是
-- `Button:LockHighlight()` / `UnlockHighlight()` —— 也就是「選中」與「滑過」在暴雪
-- 那邊是**同一張貼圖**。照抄就會變成「選中跟滑過長得一樣」，違反
-- miliui-menu-design 的第一條（一個視覺訊號只能有一個語意）。
--
-- ⚠ `Init`（.lua:549）每次都 `Button.Label:SetFontObject(...)`，而 SetFontObject
--   會把文字顏色一起換掉 ⇒ 白字要放在 reapply，不是只跑一次的 apply。
------------------------------------------------------------
-- ⚠ **選中與滑過兩態都自己畫**（`opts.ownHover`），不用引擎的 Highlight。
--   暴雪這顆按鈕是 158x24，但它的 HighlightTexture 錨的是
--   `TOPLEFT 0,0` → `BOTTOMRIGHT -1,-7`（Blizzard_AchievementUI.xml:650-654）
--   —— 比按鈕矩形往下多 7。暴雪自己的美術大半透明看不出來，換成純色之後
--   選中（`LockHighlight`，.lua:604）就在選中底色下面多畫出一條 7 像素的灰帶
--   （第二輪擷圖裡「總結」「外域」「北裂境」底下那一條）。
--   對齊那個矩形不行：列與列之間沒有間距，overlay 往下長 7 會壓到下一列，
--   而同批 overlay 層級相同、疊放只看建立先後 ⇒ 選中的那一塊會被下一列蓋掉一角。
--   所以改成把 Highlight 一起中和、兩態都由 `Engine.TrackSelectable` 畫在
--   **同一個矩形**上，選中列只會有一個色塊。完整理由在 Engine 那一段。
local function ApplyCategoryRow(row)
    local btn
    if not (pcall(function() btn = row.Button end) and btn) then
        E.Missing("AchievementCategory.Button")
        return
    end
    Skin.Row(btn, "AchievementCategory", { keys = { "Background" }, ownHover = true })
end

local function CategoryLabelWhite(row)
    local label
    if pcall(function() label = row.Button.Label end) and label then
        E.TextColor(label, T.text, "AchievementCategory.Label")
    end
end

-- ⚠ `selected` 是**後置勾的參數**（.lua:602 的 `UpdateSelectionState(selected)`），
--   不是從 elementData 撈出來的欄位。一律過 Secret.ToBool：問不到就畫成閒置。
local function CategorySelection(row, selected)
    local btn
    if not (pcall(function() btn = row.Button end) and btn) then return end
    E.SetSelected(btn, S.ToBool(selected) == true)
end

------------------------------------------------------------
-- 成就列（池化）
------------------------------------------------------------
-- 只跑一次就夠的（暴雪不會再把它們的 alpha 設回來）
local ACHIEVEMENT_ART = {
    "Background", "NineSlice", "RewardBackground",
    "BottomLeftTsunami", "BottomRightTsunami", "TopLeftTsunami", "TopRightTsunami",
    "GuildCornerL", "GuildCornerR",
}

-- ⚠ **每次 `Init` 都會被重新設定 alpha 的那幾張，一定要放 reapply。**
--   `AchievementTemplateMixin:Init`（Blizzard_AchievementUI.lua:1204,1211,1215
--   與 1218,1225,1229）不管公會視圖與否，都會做：
--       self.TitleBar:SetAlpha(1) 或 (0.8)
--       bottomTsunami:SetAlpha(0.2) 或 (0.35)
--       topTsunami:SetAlpha(0.15) 或 (0.3)
--   只在 apply 裡中和一次，第二次重用這一列就會把那條藍／棕漸層標題帶整條打回來
--   —— 這就是第二輪擷圖裡「每一列上方都還有一條漸層帶」的成因。
--
--   `Icon.frame`（那圈雕花金框）與 `Icon.bling` 也一起放進來。它們在原始碼裡只被
--   `SetTexture`／`SetTexCoord`／`SetPoint`（.lua:1205-1207, 1219-1221）與
--   `SetVertexColor`（`AchievementIcon_Saturate`/`_Desaturate`，.lua:1040,1046）碰，
--   理論上 alpha 0 撐得住 —— 但第二輪實測是「**未完成的列有金框、已完成的沒有**」
--   （擷圖 10 第 5 列、擷圖 11 第 1/2/4/5 列），而未完成正好是
--   「`Init` 每次都無條件呼叫 `Desaturate`」（.lua:1294）的那一條路。
--   源碼上找不到能解釋它的那一行 ⇒ 不賭，改成每次重申。成本是一列三發 SetAlpha。
local ACHIEVEMENT_ART_VOLATILE = { "TitleBar", "BottomTsunami1", "TopTsunami1" }

-- 總結頁／比較頁的列走 `ComparisonPlayerTemplate`（XML:1138），美術比成就列少一半
-- —— 共用一份中和清單的話，少掉的那幾個會被記進「找不到的區域」變成假警報。
-- ⚠ 總結頁的 `TitleBar` 也是每次重設：`AchievementFrameSummary_Refresh`
--   （.lua:2364）`SetAlpha(0.5)`、`AchievementFrameSummaryAchievement_SetGuildTextures`
--   （.lua:2528）`SetAlpha(1)` —— 擷圖 9「最近達成」那三條棕帶就是這個。
local SUMMARY_ROW_ART = { "Background", "NineSlice", "Glow" }

local function NeutralizeVolatileArt(row, key)
    E.NeutralizeKeys(row, ACHIEVEMENT_ART_VOLATILE, key)
    local icon
    if pcall(function() icon = row.Icon end) and icon then
        -- frame＝那圈雕花金框、bling＝取得時的閃光。兩張都是裝飾。
        E.NeutralizeKeys(icon, { "frame", "bling" }, key .. ".Icon")
    end
end

local function ApplyRowArt(row, keys, key)
    E.NeutralizeKeys(row, keys, key)
    NeutralizeVolatileArt(row, key)

    local icon
    if pcall(function() icon = row.Icon end) and icon then
        local tex
        if pcall(function() tex = icon.texture end) and tex then
            Skin.Icon(tex, key .. ".Icon.texture")
        end
    end

    Skin.Row(row, key, { border = true })
end

local function ApplyAchievementRow(row)
    ApplyRowArt(row, ACHIEVEMENT_ART, "Achievement")
end

local function ApplySummaryRow(row)
    ApplyRowArt(row, SUMMARY_ROW_ART, "SummaryAchievement")
end

local function ReapplyAchievementRow(row)
    -- ⚠ 這一條是整份配方的核心：Saturate 把描述設成**純黑**（.lua:1423），
    --   壓在深底上等於整段消失。
    local desc
    if pcall(function() desc = row.Description end) and desc then
        E.TextColor(desc, T.textDim, "Achievement.Description")
    end
    -- `Init` 每次都 `Icon.texture:SetTexture(icon)`（.lua:1283），SetTexture 會把
    -- texCoord 打回 0,1,0,1 ⇒ 裁邊每次都要重下。
    local tex
    if pcall(function() tex = row.Icon.texture end) and tex then
        E.CropIcon(tex, "Achievement.Icon.texture")
    end
    -- 每次 Init 都被打回來的那三張＋圖示金框（理由見 ACHIEVEMENT_ART_VOLATILE）
    NeutralizeVolatileArt(row, "Achievement")
end

-- 完成／未完成只換明暗，不換色相。
local function AchievementBright(row)
    ReapplyAchievementRow(row)
    E.Fill(E.GetOverlay(row), T.fill)
end

local function AchievementDim(row)
    ReapplyAchievementRow(row)
    E.Fill(E.GetOverlay(row), T.fillInset)
end

------------------------------------------------------------
-- 展開後的子目標
--
-- `AchievementObjectives_DisplayCriteria`（.lua:1897）與
-- `AchievementObjectives_DisplayProgressiveAchievement`（.lua:1797）都是全域函式，
-- 而且是整個視窗共用**兩個** objectives 容器（`AchievementTemplateMixin:
-- GetObjectiveFrame`，.lua:1187），不是一列一個 ⇒ 勾那兩支就夠了。
--
-- ⚠ 「這一條完成了沒」不從 elementData 讀，讀 `Check:IsShown()` —— 暴雪自己
--   在同一個 if 裡 `criteria.Check:Show()`（.lua:2056）／`Hide()`，純 C 端布林。
local function RecolourObjectiveList(list, field, key)
    if type(list) ~= "table" then return end
    for _, frame in ipairs(list) do
        local fs, check
        if pcall(function() fs = frame[field]; check = frame.Check end) and fs then
            local done
            if check and type(check.IsShown) == "function" then
                local ok, v = pcall(check.IsShown, check)
                if ok then done = S.ToBool(v) end
            end
            E.TextColor(fs, done == true and T.text or T.textDim, key)
        end
    end
end

local function SkinObjectives(objectivesFrame)
    if not E.Usable(objectivesFrame, "AchievementObjectives") then return end

    local criterias, metas, bars
    pcall(function()
        criterias = objectivesFrame.criterias
        metas = objectivesFrame.metas
        bars = objectivesFrame.progressBars
    end)

    RecolourObjectiveList(criterias, "Name", "AchievementObjectives.Criteria.Name")
    RecolourObjectiveList(metas, "Label", "AchievementObjectives.Meta.Label")

    if type(bars) == "table" then
        for _, bar in ipairs(bars) do
            -- 進度條的底與邊是**無名**貼圖（池子 Acquire 出來的框沒有名字，
            -- 模板裡的 `$parentBG` / `$parentBorder*` 因此連全域名字都沒有）
            -- ⇒ 只能走 GetRegions。填充貼圖會被排除，綠色進度保留。
            Skin.StatusBar(bar, "AchievementObjectives.ProgressBar",
                { stripArt = true, color = ACHIEVEMENT_BAR_GREEN })
        end
    end
end

------------------------------------------------------------
-- 統計頁的列
--
-- 出處：Blizzard_AchievementUI.xml:1351 `AchievementStatTemplate`
-- ⚠ `AchievementStatTemplateMixin:Init`（.lua:2189）每次都把 `Background` 的 alpha
--   設回 1.0 或 0.5（隔行變色）⇒ 中和**一定要放在 reapply**，只 apply 一次撐不住。
--   Left/Middle/Right 只被 Show()/Hide()，alpha 0 撐得過去。
------------------------------------------------------------
local function ApplyStatRow(row)
    E.NeutralizeKeys(row, { "Left", "Middle", "Right" }, "AchievementStat")
end

local function ReapplyStatRow(row)
    E.NeutralizeKeys(row, { "Background" }, "AchievementStat")
end

------------------------------------------------------------
-- 總結頁
------------------------------------------------------------
local SUMMARY_HEADERS = {
    -- { 底圖, 標題 }
    { "AchievementFrameSummaryAchievementsHeaderHeader", "AchievementFrameSummaryAchievementsHeaderTitle" },
    { "AchievementFrameSummaryCategoriesHeaderTexture",  "AchievementFrameSummaryCategoriesHeaderTitle" },
}

local function SkinSummaryBar(bar, key)
    if not bar then
        E.Missing(key)
        return
    end
    -- ⚠ 填充色**保留暴雪的綠**，不改成職業色。兩個理由：
    --   1. 綠＝進度／完成，是全遊戲通用的語彙，換掉等於丟掉一個讀者已經會的訊號。
    --   2. 這個視窗裡職業色已經被「分類列選中態」用掉了 —— 一個視覺訊號只能有
    --      一個語意（miliui-menu-design 第一條）。進度條再用職業色就打架了。
    Skin.StatusBar(bar, key, { stripArt = true, color = ACHIEVEMENT_BAR_GREEN })

    -- Label / Title 是 GameFontNormal（暗金），換白
    for _, k in ipairs({ "Label", "Title" }) do
        local fs
        if pcall(function() fs = bar[k] end) and fs then
            E.TextColor(fs, T.text, key .. "." .. k)
        end
    end
end

local function SkinSummary()
    local summary = _G.AchievementFrameSummary
    if not summary then
        E.Missing("AchievementFrameSummary")
        return
    end

    for _, pair in ipairs(SUMMARY_HEADERS) do
        E.Neutralize(_G[pair[1]], pair[1])
        local fs = _G[pair[2]]
        if fs then
            E.TextColor(fs, T.text, pair[2])
        else
            E.Missing(pair[2])
        end
    end

    -- 「已達成的成就」那條大的
    local total = _G.AchievementFrameSummaryCategoriesStatusBar
    SkinSummaryBar(total, "AchievementFrameSummaryCategoriesStatusBar")
    if total then
        local fs = _G.AchievementFrameSummaryCategoriesStatusBarTitle
        if fs then E.TextColor(fs, T.text, "…StatusBarTitle") end
    end

    -- 「進度一覽」的十二條（XML 就建好了，不是池化的）
    for i = 1, 12 do
        local name = "AchievementFrameSummaryCategoriesCategory" .. i
        local bar = _G[name]
        if bar then
            SkinSummaryBar(bar, name)
            -- 滑過的金色光暈（`$parentButtonHighlight` 是一個被 Show/Hide 的框，
            -- 不是 HIGHLIGHT 層）⇒ 不能交給引擎，只能把那三張中和掉。
            -- 代價是這十二條沒有滑過回饋，已列進待驗證清單。
            E.NeutralizeRegions(_G[name .. "ButtonHighlight"], name .. "ButtonHighlight")
        end
    end
end

------------------------------------------------------------
-- 比較視窗（第二輪只做了半套：列跟著總結頁一起變平面皮，面板底還是羊皮紙）
--
-- 出處：Blizzard_AchievementUI.xml:2314 起的 `$parentComparison`
--   `$parentHeader`（190x57）：`$parentBG`（UI-Achievement-ComparisonHeader）、
--     `$parentPortraitBg`（純黑方塊，留著當頭像底）、`$parentName`/`Points`/`Shield`
--   `Summary.Player` / `Summary.Friend`：`TooltipBorderBackdropTemplate` ＋
--     `$parentBackground`（UI-Achievement-Parchment-Horizontal）＋ 一條 StatusBar
--   `AchievementContainer` / `StatContainer`：各一組 ScrollBox ＋ MinimalScrollBar
--   一個**沒有名字**的 `AchivementGoldBorderBackdrop` 子框（金邊）
--   `$parentBackground`（UI-Achievement-AchievementBackground）、`Dark`、`Watermark`
------------------------------------------------------------
local function SkinComparison(f)
    local cmp = _G.AchievementFrameComparison
    if not cmp then
        E.Missing("AchievementFrameComparison")
        return
    end

    -- 面板底：羊皮紙、Dark 遮罩、浮水印與那一層無名金邊
    E.NeutralizeGlobals({ "AchievementFrameComparisonBackground" })
    E.NeutralizeKeys(cmp, { "Dark", "Watermark" }, "AchievementFrameComparison")
    E.NeutralizeChildNineSlices(cmp, "AchievementFrameComparison")

    local ov = E.Overlay(cmp, { key = "AchievementFrameComparison" })
    E.Paint(ov, T.fillInset, T.border)

    -- 標題（對方的名字／點數）。`$parentBG` 是那塊雕花牌，`$parentPortraitBg`
    -- 是頭像後面的純黑方塊 —— 後者留著，不然頭像會直接貼在面板上。
    local header = _G.AchievementFrameComparisonHeader
    if header then
        E.NeutralizeGlobals({ "AchievementFrameComparisonHeaderBG" })
        local hov = E.Overlay(header, { key = "AchievementFrameComparisonHeader" })
        E.Paint(hov, T.fill, T.border)

        local fs = _G.AchievementFrameComparisonHeaderName
        if fs then E.TextColor(fs, T.text, "AchievementFrameComparisonHeaderName") end
        local pts
        if pcall(function() pts = header.Points end) and pts then
            E.TextColor(pts, T.text, "AchievementFrameComparisonHeader.Points")
        end
    else
        E.Missing("AchievementFrameComparisonHeader")
    end

    -- 上方兩塊「我／對方」的總分條
    local summary
    if pcall(function() summary = cmp.Summary end) and summary then
        for _, key in ipairs({ "Player", "Friend" }) do
            local panel
            if pcall(function() panel = summary[key] end) and panel then
                local label = "AchievementFrameComparisonSummary" .. key
                -- ⚠ 那張羊皮紙在 XML 裡寫的是 `<Texture name="$parentBackground">`，
                --   但它的 parent（`Summary.Player` / `.Friend`）**只有 parentKey
                --   沒有 name**（Blizzard_AchievementUI.xml:2383,2389,2418）
                --   ⇒ `$parent` 展不開，根本沒有那個全域名字。
                --   只剩 `GetRegions()`（只掃 Texture，那一層沒有別的美術）。
                E.NeutralizeRegions(panel, label)
                E.NeutralizeKeys(panel, { "NineSlice" }, label)
                E.NeutralizeChildNineSlices(panel, label)
                local pov = E.Overlay(panel, { key = label })
                E.Paint(pov, T.fill, T.border)

                local bar
                if pcall(function() bar = panel.StatusBar end) and bar then
                    Skin.StatusBar(bar, label .. ".StatusBar",
                        { stripArt = true, color = ACHIEVEMENT_BAR_GREEN })
                end
            end
        end
    end

    -- 兩組捲軸
    for _, key in ipairs({ "AchievementContainer", "StatContainer" }) do
        local container
        if pcall(function() container = cmp[key] end) and container then
            local bar
            if pcall(function() bar = container.ScrollBar end) and bar then
                Skin.ScrollBar(bar, "AchievementFrameComparison." .. key .. ".ScrollBar")
            end
        end
    end
end

------------------------------------------------------------
-- hook 安裝（**不過戰鬥閘**，理由見 STYLE.md ③ 的陷阱 4）
------------------------------------------------------------
local categorySweep, achievementSweep, statSweep

local function InstallHooks()
    categorySweep = E.HookRows{
        key    = "AchievementCategory",
        mixin  = _G.AchievementCategoryTemplateMixin,
        method = "Init",
        match  = function(row) return type(row) == "table" and row.Button ~= nil end,
        apply  = ApplyCategoryRow,
        reapply = CategoryLabelWhite,
    }
    -- ⚠ 這一支也帶 apply：`Init` 的**最後一行**才呼叫 `UpdateSelectionState`
    --   （.lua:600），而 Init 的後置勾比它晚跑 ⇒ 第一次進來的時候 overlay 還沒建。
    --   兩支共用同一份 side table，誰先到誰負責 apply，所以不會建兩次。
    E.HookRows{
        key     = "AchievementCategory.Selection",
        mixin   = _G.AchievementCategoryTemplateMixin,
        method  = "UpdateSelectionState",
        apply   = ApplyCategoryRow,
        reapply = CategorySelection,
    }

    achievementSweep = E.HookRows{
        key     = "Achievement",
        mixin   = _G.AchievementTemplateMixin,
        method  = "Init",
        match   = function(row) return type(row) == "table" and row.Shield ~= nil and row.Description ~= nil end,
        apply   = ApplyAchievementRow,
        reapply = ReapplyAchievementRow,
    }
    -- ⚠ 為什麼三支都要勾：`Init` **只有在 saturatedStyle 變了的時候**才呼叫
    --   Saturate（.lua:1288），所以「重用一列、狀態沒變」那條路只有 Init 會進來；
    --   反過來 Saturate/Desaturate 也會從總結頁與比較頁被單獨呼叫。
    --   完成／未完成的底色明暗由這兩支決定 —— 不必自己判斷「這一列完成了沒」，
    --   暴雪呼叫哪一支就是答案。
    E.HookRows{
        key     = "Achievement.Saturate",
        mixin   = _G.AchievementTemplateMixin,
        method  = "Saturate",
        apply   = ApplyAchievementRow,
        reapply = AchievementBright,
    }
    E.HookRows{
        key     = "Achievement.Desaturate",
        mixin   = _G.AchievementTemplateMixin,
        method  = "Desaturate",
        apply   = ApplyAchievementRow,
        reapply = AchievementDim,
    }

    statSweep = E.HookRows{
        key     = "AchievementStat",
        mixin   = _G.AchievementStatTemplateMixin,
        method  = "Init",
        match   = function(row) return type(row) == "table" and row.Value ~= nil and row.Middle ~= nil end,
        apply   = ApplyStatRow,
        reapply = ReapplyStatRow,
    }

    -- 總結頁「最近達成的成就」那五列。它們不是 mixin，是兩支**全域函式**
    -- （`AchievementComparisonPlayerButton_OnLoad`，.lua:3097，把全域指派成
    -- `self.Saturate` / `self.Desaturate`）—— 所以 hook 的對象是 `_G`。
    -- 一樣是「hook 要比 frame 早裝」：那五顆是第一次開總結頁時才 CreateFrame 出來的。
    E.HookRows{
        key     = "SummaryAchievement.Saturate",
        mixin   = _G,
        method  = "AchievementComparisonPlayerButton_Saturate",
        apply   = ApplySummaryRow,
        reapply = AchievementBright,
    }
    E.HookRows{
        key     = "SummaryAchievement.Desaturate",
        mixin   = _G,
        method  = "AchievementComparisonPlayerButton_Desaturate",
        apply   = ApplySummaryRow,
        reapply = AchievementDim,
    }

    -- 總結頁的五列：`AchievementFrameSummary_Refresh`（.lua:2364）每次都把
    -- `TitleBar` 的 alpha 設回 0.5（公會視圖是 `…_SetGuildTextures`，.lua:2528，設回 1）。
    -- 那一支跟 `AchievementComparisonPlayerButton_Saturate` 是兩條獨立的路，
    -- 順序不保證 ⇒ 另外勾一支重申，不賭。
    if type(_G.AchievementFrameSummary_Refresh) == "function" then
        hooksecurefunc("AchievementFrameSummary_Refresh", function()
            for i = 1, (ACHIEVEMENTUI_MAX_SUMMARY_ACHIEVEMENTS or 5) do
                local row = _G["AchievementFrameSummaryAchievement" .. i]
                if row then NeutralizeVolatileArt(row, "SummaryAchievement") end
            end
        end)
    else
        E.Missing("AchievementFrameSummary_Refresh")
    end

    if type(_G.AchievementObjectives_DisplayCriteria) == "function" then
        hooksecurefunc("AchievementObjectives_DisplayCriteria", SkinObjectives)
    else
        E.Missing("AchievementObjectives_DisplayCriteria")
    end
    if type(_G.AchievementObjectives_DisplayProgressiveAchievement) == "function" then
        hooksecurefunc("AchievementObjectives_DisplayProgressiveAchievement", SkinObjectives)
    else
        E.Missing("AchievementObjectives_DisplayProgressiveAchievement")
    end
end

------------------------------------------------------------
-- 套用
------------------------------------------------------------
local function Apply()
    local f = AchievementFrame
    if not f then
        E.Missing("AchievementFrame")
        return
    end

    E.NeutralizeKeys(f, BACKDROP_PIECES, "AchievementFrame.backdrop")
    E.NeutralizeKeys(f, { "Background" }, "AchievementFrame")
    E.NeutralizeGlobals(FRAME_ART_GLOBALS)

    Skin.Panel(f, "AchievementFrame")

    SkinHeader(f)
    SkinHeaderDetails(f)

    local categories
    pcall(function() categories = f.Categories end)
    SkinContentPanel(categories, "AchievementFrame.Categories", { ownNineSlice = true })
    SkinContentPanel(_G.AchievementFrameAchievements, "AchievementFrameAchievements")
    SkinContentPanel(_G.AchievementFrameStats, "AchievementFrameStats")
    -- 總結頁是唯一沒有捲軸的內容面板
    SkinContentPanel(_G.AchievementFrameSummary, "AchievementFrameSummary", { noScrollBar = true })

    -- 統計頁的底圖住在一個自己的框裡（XML:2063 的 `$parentBG`，裡面那張貼圖無名）
    E.NeutralizeRegions(_G.AchievementFrameStatsBG, "AchievementFrameStatsBG")

    SkinSummary()
    SkinComparison(f)

    for i = 1, 3 do
        local key = "AchievementFrameTab" .. i
        local tab = _G[key]
        if tab then
            -- ⚠ 成就視窗自己的分頁模板（AchievementFrameTabButtonTemplate）跟
            --   PanelTabButtonTemplate 的 parentKey 名字一樣，但**沒有**
            --   parentArray="TabTextures"，所以要逐一點名 ⇒ kind = "legacy"。
            Skin.Tab(tab, key, "legacy")
        else
            E.Missing(key)
        end
    end

    local close = _G.AchievementFrameCloseButton
    if close then
        Skin.CloseButton(close, "AchievementFrameCloseButton")
    else
        E.Missing("AchievementFrameCloseButton")
    end

    -- 補掃已經建好的列（戰鬥中第一次開視窗的那條路）
    local box
    if categories and pcall(function() box = categories.ScrollBox end) and box then
        E.SweepRows(box, "AchievementFrame.Categories.ScrollBox", categorySweep)
    end
    box = nil
    if _G.AchievementFrameAchievements
        and pcall(function() box = _G.AchievementFrameAchievements.ScrollBox end) and box then
        E.SweepRows(box, "AchievementFrameAchievements.ScrollBox", achievementSweep)
    end
    box = nil
    if _G.AchievementFrameStats
        and pcall(function() box = _G.AchievementFrameStats.ScrollBox end) and box then
        E.SweepRows(box, "AchievementFrameStats.ScrollBox", statSweep)
    end
end

E.Register{
    key   = "achievement",
    addon = "Blizzard_AchievementUI",   -- 隨需載入：ADDON_LOADED 才套（apply 過戰鬥閘）
    title = L["Achievements"],
    hooks = InstallHooks,
    apply = Apply,
}
