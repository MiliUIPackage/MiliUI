------------------------------------------------------------
-- 配方：成就視窗（Blizzard_AchievementUI）—— 隨需載入 ＋ ScrollBox 的代表
--
-- 暴雪原始碼出處（12.1.0.69875）：
--   Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml / .lua
--   Blizzard_SharedXML/Backdrop.lua（BACKDROP_ACHIEVEMENTS_0_64、ApplyBackdrop）
--   Blizzard_SharedXML/SharedTooltipTemplates.xml（TooltipBackdropTemplate）
--   Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml
--   Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml（SearchBoxTemplate）
--
-- 這個視窗是**舊式**的：不繼承 PortraitFrameTemplate，外框是
-- `BackdropTemplate` ＋ 十幾張 `$parent…` 具名貼圖（木框、金屬框、接角）。
-- backdrop 的九片是 `NineSliceUtil.ApplyLayout(self, …)` 直接掛在 frame 上的
-- 欄位（TopEdge / LeftEdge / TopLeftCorner / … / Center），所以點名得到。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 物件 | 動作 |
-- |---|---|
-- | AchievementFrame 的 backdrop 九片（TopEdge…Center） | SetAlpha(0) |
-- | AchievementFrame.Background（UI-Background-Rock-Brown） | SetAlpha(0) |
-- | AchievementFrameMetalBorder{Left,Right,Top,Bottom}、四個接角 | SetAlpha(0) |
-- | AchievementFrameWoodBorder{TopLeft,TopRight,BottomLeft,BottomRight} | SetAlpha(0) |
-- | AchievementFrameWaterMark | SetAlpha(0) |
-- | AchievementFrame.Header 的 Left / Right / PointBorder | SetAlpha(0) |
-- | AchievementFrame.Header 的 Title / Points | SetTextColor |
-- | AchievementFrame.HeaderDetails.TopTileStreaks | SetAlpha(0) |
-- | AchievementFrame.HeaderDetails.Back（UIPanelButtonTemplate） | SetAlpha(0) / SetColorTexture / SetNormalFontObject |
-- | AchievementFrame.HeaderDetails.Filters.SearchBox | SetAlpha(0) / SetVertexColor / SetTextColor |
-- | AchievementFrame.Categories.NineSlice ＋ 各面板裡的無名金邊 | SetAlpha(0) |
-- | 三個 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 三個 MinimalScrollBar 的 Back/Forward.Texture | SetVertexColor |
-- | AchievementFrameTab1..3 的九張貼圖 | SetAlpha(0) |
-- | AchievementFrameCloseButton 的狀態貼圖 | SetAlpha(0) / SetColorTexture |
-- | 以上各框 | CreateFrame 掛自己的 overlay |
--
-- hook：只有 Engine 的三個 `PanelTemplates_*` 全域後置勾（成就視窗自己也是走
--   `PanelTemplates_UpdateTabs` 切分頁，見 Blizzard_AchievementUI.lua:258-260）。
-- 寫入暴雪欄位：無。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * `AchievementFrameCategoriesBG`、`AchievementFrameAchievements.Background`、
--   `AchievementFrameSummary.Background` —— 成就列與分類列的**羊皮紙底**，
--   列上的字色是為它設計的（內容底材保留規則）。
-- * 成就列本身（`AchievementTemplate`）、分類列、統計列 —— 那是內容，PoC 不做。
-- * `Filters.FilterDropdown`（`WowStyle1FilterDropdownTemplate`）—— 下拉是一整套
--   自己的美術與狀態機，列在 STYLE.md ⑦ 的 B 級，PoC 不做。
-- * `SearchPreviewContainer` / `SearchResults` / `AchievementFrameComparison` ——
--   同上，B 級。
--
-- ⚠ overlay 一律不 parent 到 `HeaderDetails.Filters`（`HorizontalLayoutFrame`）：
--   那種框會走訪 children 讀 layoutIndex 與尺寸。搜尋框的 overlay 掛在搜尋框
--   自己身上，Engine.SafeParent 也會再擋一次。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
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
}

-- 三個內容面板長得一樣：一層無名的金邊（AchivementGoldBorderBackdrop）＋ 一條
-- MinimalScrollBar。分類欄自己就是那個金邊模板，所以它的 NineSlice 點名得到。
local function SkinContentPanel(panel, key, hasOwnNineSlice)
    if not panel then
        E.Missing(key)
        return
    end
    if hasOwnNineSlice then
        E.NeutralizeKeys(panel, { "NineSlice" }, key)
    end
    E.NeutralizeChildNineSlices(panel, key)

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
    E.NeutralizeKeys(header, { "Left", "Right", "PointBorder" }, "AchievementFrame.Header")

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

    local filters, search
    if pcall(function() filters = hd.Filters end) and filters
        and pcall(function() search = filters.SearchBox end) and search then
        Skin.EditBox(search, "AchievementFrame.HeaderDetails.Filters.SearchBox")
    else
        E.Missing("AchievementFrame.HeaderDetails.Filters.SearchBox")
    end
end

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
    SkinContentPanel(categories, "AchievementFrame.Categories", true)
    SkinContentPanel(_G.AchievementFrameAchievements, "AchievementFrameAchievements", false)
    SkinContentPanel(_G.AchievementFrameStats, "AchievementFrameStats", false)

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
end

E.Register{
    key   = "achievement",
    addon = "Blizzard_AchievementUI",   -- 隨需載入：ADDON_LOADED 才套（同樣過戰鬥閘）
    title = L["Achievements"],
    apply = Apply,
}
