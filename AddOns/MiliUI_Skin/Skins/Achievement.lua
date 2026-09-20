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
-- | 分類列（池化）的 Button.Background | SetAlpha(0) |
-- | 分類列的 Button 的 Highlight 貼圖 | SetColorTexture |
-- | 分類列的 Button.Label | SetTextColor |
-- | 成就列（池化）的 Background / NineSlice / TitleBar / Glow / RewardBackground / 四角 Tsunami / 上下 Tsunami / GuildCornerL/R / Icon.frame / Icon.bling | SetAlpha(0) |
-- | 成就列的 Description | SetTextColor |
-- | 成就列的 Icon.texture | SetTexCoord |
-- | 子目標（池化）的 Name / MetaCriteria.Label | SetTextColor |
-- | 子目標進度條的無名底圖與邊框 | SetAlpha(0) |
-- | 統計列（池化）的 Left / Middle / Right / Background | SetAlpha(0) |
-- | 總結頁兩塊小節標題的底圖 | SetAlpha(0)；Title | SetTextColor |
-- | 總結頁 13 條進度條的無名美術 | SetAlpha(0)；Label | SetTextColor |
-- | 總結頁「最近達成」五列 | 同成就列 |
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
-- * **搜尋預覽／完整搜尋結果**（`SearchPreviewContainer` / `SearchResults`）與
--   **比較視窗**（`AchievementFrameComparison`）—— STYLE.md ⑦ 的 B 級。
--   ⚠ 比較視窗的列跟總結頁共用 `AchievementComparisonPlayerButton_Saturate`，
--     所以它的**列**會一起變平面皮、但它的**面板底**還是羊皮紙。已知不一致，待辦。
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

local function SkinHeader(f)
    local header
    if not (pcall(function() header = f.Header end) and header) then
        E.Missing("AchievementFrame.Header")
        return
    end
    -- Left/Right 是那塊木頭橫幅，PointBorder 是點數的小牌子。
    -- 三張拿掉之後標題與點數就直接浮在面板上方 —— 這是刻意的：橫幅大半在面板
    -- 外面，補一塊實心底反而會變成一個懸空的方塊。
    -- ⚠ 浮在視窗外面＝背後是會動的地形，所以字一定要白＋有陰影才讀得到。
    --   `Title` 是 GameFontNormalSmall、`Points` 是 GameFontHighlight，兩個字型物件
    --   本來就自帶陰影，我們只換顏色。
    -- RightDDLInset 平常 hidden，公會分頁會顯示，一起中和
    E.NeutralizeKeys(header, { "Left", "Right", "PointBorder", "RightDDLInset" },
        "AchievementFrame.Header")

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
-- 所以：滑過交給引擎（Highlight → 白 8%），選中另外走 overlay 底色（`AccentFill`）。
--
-- ⚠ `Init`（.lua:549）每次都 `Button.Label:SetFontObject(...)`，而 SetFontObject
--   會把文字顏色一起換掉 ⇒ 白字要放在 reapply，不是只跑一次的 apply。
------------------------------------------------------------
local accentFill = {}
local function AccentFill()
    local r, g, b, a = T.AccentFill(1)
    accentFill[1], accentFill[2], accentFill[3], accentFill[4] = r, g, b, a
    return accentFill
end

local function ApplyCategoryRow(row)
    local btn
    if not (pcall(function() btn = row.Button end) and btn) then
        E.Missing("AchievementCategory.Button")
        return
    end
    Skin.Row(btn, "AchievementCategory", { keys = { "Background" } })
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
    local ov = E.GetOverlay(btn)
    if not ov then return end
    E.Fill(ov, S.ToBool(selected) == true and AccentFill() or T.fill)
end

------------------------------------------------------------
-- 成就列（池化）
------------------------------------------------------------
local ACHIEVEMENT_ART = {
    "Background", "NineSlice", "TitleBar", "Glow", "RewardBackground",
    "BottomLeftTsunami", "BottomRightTsunami", "TopLeftTsunami", "TopRightTsunami",
    "BottomTsunami1", "TopTsunami1", "GuildCornerL", "GuildCornerR",
}

-- 總結頁／比較頁的列走 `ComparisonPlayerTemplate`（XML:1138），美術比成就列少一半
-- —— 共用一份中和清單的話，少掉的那幾個會被記進「找不到的區域」變成假警報。
local SUMMARY_ROW_ART = { "Background", "NineSlice", "TitleBar", "Glow" }

local function ApplyRowArt(row, keys, key)
    E.NeutralizeKeys(row, keys, key)

    local icon
    if pcall(function() icon = row.Icon end) and icon then
        -- frame＝那圈雕花圓框、bling＝取得時的閃光。兩張都是裝飾。
        E.NeutralizeKeys(icon, { "frame", "bling" }, key .. ".Icon")
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
    -- `Init` 每次都 `Icon.texture:SetTexture(icon)`（.lua:1281），SetTexture 會把
    -- texCoord 打回 0,1,0,1 ⇒ 裁邊每次都要重下。
    local tex
    if pcall(function() tex = row.Icon.texture end) and tex then
        E.CropIcon(tex, "Achievement.Icon.texture")
    end
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
            Skin.StatusBar(bar, "AchievementObjectives.ProgressBar", { stripArt = true })
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
    Skin.StatusBar(bar, key, { stripArt = true })

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
