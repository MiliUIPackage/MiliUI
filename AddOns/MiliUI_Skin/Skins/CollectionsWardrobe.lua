------------------------------------------------------------
-- 配方：收藏 —— 外觀（WardrobeCollectionFrame）
--
-- 跟 Skins/Collections.lua 共用設定 key `collections`（理由見那一份的檔頭），
-- 共用工具在 `ns.CollectionsSkin`。
--
-- **範圍：chrome ＋ 控制列。** 模型格子（`DressUpModel`）、部位按鈕、套裝清單的
-- 池化列這一輪都不做，理由見下面「刻意不碰的東西」。
-- 塑形師那個大視窗（`WardrobeFrame`）不在這一輪，它是另一個框。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:186  WardrobeCollectionFrame
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:198,211  ItemsTab／SetsTab（PanelTopTabButtonTemplate）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:246  SearchBox（SearchBoxTemplate）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:401  progressBar（CollectionsProgressBarTemplate）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:406  FilterButton（WowStyle1FilterDropdownTemplate）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:415  ClassDropdown（WowStyle1DropdownTemplate）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:425  ItemsCollectionFrame（CollectionsBackgroundTemplate）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:430,435,440  PagingFrame／WeaponDropdown／SlotsFrame
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:446  ModelR1C1…（DressUpModel 格子）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:546  SetsCollectionFrame
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:555,562  LeftInset（InsetFrameTemplate）／RightInset（CollectionsBackgroundTemplate）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:568,574,575  ListContainer／ScrollBox／ScrollBar
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:589  Model（DressUpModel，套裝預覽）
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.xml:604,689  DetailsFrame／VariantSetsDropdown
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.lua:8,13-14,131-135  ClickTab → SetTab → PanelTemplates_SetTab
--   Blizzard_Collections/Mainline/Blizzard_Wardrobe.lua:366  UpdateProgressBar（只 SetMinMaxValues／SetValue）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:979  PanelTopTabButtonTemplate ← PanelTabButtonTemplate
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:280-299  PanelTopTabButtonMixin:OnLoad（把九張貼圖上下翻轉、Right 錨 BOTTOMRIGHT x=+7）
--
-- 查證後跟計畫假設不一樣的兩件事：
--   1. **頂部那兩顆分頁做得了。** `PanelTopTabButtonTemplate` 只是
--      `PanelTabButtonTemplate` 加一個 mixin（SharedUIPanelTemplates.xml:979），
--      九張 `TabTextures` 一樣在，狀態一樣走 `PanelTemplates_SetTab`
--      （Blizzard_Wardrobe.lua:14）⇒ Engine 的三個後置勾照常觸發。
--      **但相連的是下邊不是上邊**（它們掛在內容框的上緣，`TOPLEFT y="-28"`），
--      所以走 `ns.CollectionsSkin.SkinPanelTab` 的 `joined = "BOTTOM"`，
--      不能直接用 `Skin.Tab`。
--      兩顆的按鈕矩形是**首尾相接**的（`SetsTab` 錨 `LEFT → Tab1 的 RIGHT x="0"`，
--      .xml:216）⇒ 左右都不內縮，接縫剛好一條線。
--   2. **「套裝」頁的右半邊不是 `InsetFrameTemplate`** 而是
--      `CollectionsBackgroundTemplate`（.xml:562），跟玩具箱的格子底同一種
--      ⇒ 走 `ns.CollectionsSkin.SkinCollectionsBackground`。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 物件 | 動作 |
-- |---|---|
-- | WardrobeCollectionFrameTab1/2 的九張 TabTextures | SetAlpha(0) |
-- | 同兩顆 | SetNormalFontObject(GameFontHighlightSmall) |
-- | WardrobeCollectionFrame.SearchBox 的 Left/Right/Middle | SetAlpha(0) |
-- | 同一顆的 searchIcon / clearButton.Icon / Instructions | SetVertexColor / SetTextColor |
-- | WardrobeCollectionFrame.progressBar 的 border ＋無名黑底 | SetAlpha(0) |
-- | 同一條的填充貼圖 | SetStatusBarTexture（走 Engine.BarTexture）＋ SetVertexColor（綠） |
-- | FilterButton / ClassDropdown / WeaponDropdown / VariantSetsDropdown 的 Background | SetAlpha(0) |
-- | 同三顆 style1 下拉的 Arrow | SetVertexColor |
-- | ItemsCollectionFrame ＋ SetsCollectionFrame.RightInset（各 21 張裝飾 ＋ Bg ＋ NineSlice） | SetAlpha(0) |
-- | SetsCollectionFrame.LeftInset 的 Bg / NineSlice | SetAlpha(0) |
-- | ItemsCollectionFrame.PagingFrame 兩顆鈕的 Normal/Pushed/Disabled | SetVertexColor |
-- | 同兩顆的 Highlight | SetColorTexture |
-- | ListContainer.ScrollBar 的 Track/Thumb 六張 | SetAlpha(0)；Back/Forward.Texture | SetVertexColor |
-- | 以上各框 | CreateFrame 掛自己的 overlay |
--
-- hook：只有 Engine 的三個 `PanelTemplates_*` 全域後置勾與兩顆分頁的
--   `HookScript("OnEnter"/"OnLeave")`（都由 `Engine.TrackTab` 代掛）。
-- 寫入暴雪欄位：無。讀暴雪物件：`Engine.TrackTab` 的 `LeftActive:IsShown()`
--   （讀取例外表第 4 條）與 `GetFrameLevel`。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **所有 `DressUpModel`**（外觀頁的模型格子 `ModelR1C1…`、套裝頁的 `Model`）：
--   3D 模型場景，契約明列不碰。它們的「已收藏／未收藏／已裝備」外框
--   （`WardrobeItemsModelTemplate` 的 `Border`／`TransmogStateTexture`）是**狀態**，
--   由 `WardrobeItemsCollectionMixin:UpdateItems` 每次翻頁重設，中和掉就看不出
--   哪一件收過了。
-- * **`ItemsCollectionFrame.SlotsFrame` 的部位按鈕**（`WardrobeSlotButtonTemplate`／
--   `WardrobeSmallSlotButtonTemplate`，.xml:100,133）：一排十幾顆「目前在看哪個
--   部位」的圖示鈕，選中態同樣是暴雪自己 Show/Hide 的貼圖，接觸面沒查完。
-- * **`SetsCollectionFrame.ListContainer.ScrollBox` 的套裝列**：`WowScrollBoxList`
--   的池化 element，而且**整包裡另有第三方插件掛在同一個 ScrollBox 上**
--   （見下面「別的插件」那一段）—— 兩邊在同一批列上畫東西的風險要先實機看過，
--   這一輪只做它的捲軸。
-- * **`SetsCollectionFrame.DetailsFrame`**（右下角的套裝明細，含 `LimitedSet`
--   與部位小圖）：貼在模型上的一層資訊，底材是模型場景。
-- * **`WardrobeCollectionFrame.SearchBox.ProgressFrame`**（搜尋進度的轉圈與細條）：
--   只在搜尋大量外觀時短暫出現，接觸面不值得花。
-- * **`WardrobeCollectionFrame.InfoButton`（`MainHelpPlateButton`）**：`HelpTip`
--   系統的觸發鈕，理由同寵物日誌那一份。
-- * **`SetsTab.FlashFrame`**：它帶一段 `OnUpdate` 的閃爍（.xml:230-237），
--   是「有新套裝」的提示，屬於資訊。
--
------------------------------------------------------------
-- ## 整包裡有別的插件掛在收藏視窗上（`grep -rn` 的結果，四份配方共用一張表）
--
-- 全部是**第三方插件**，這一輪一律不碰，也不呼叫／不 hook 它們的任何函式：
--   * 一支外觀提示插件：`RegisterAddonHook("Blizzard_Collections", …)`，在
--     `WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame` 與
--     `.ListContainer.ScrollBox` 上掛 `Update` 後置勾與 `OnUpdate` callback，
--     在每一格上畫自己的小圖示。**它用的是 `ScrollBox:RegisterCallback`** ——
--     那正是我們契約裡明文禁止的那條路（把自己的函式註冊進暴雪的 callback 表），
--     所以我們不會跟它在同一個地方相遇；但套裝列這一輪不做，也就沒有重疊。
--   * 一支多功能增強插件：在 `MountJournal.MountDisplay.InfoButton.Source` 上把
--     成就名字做成超連結，另外修 `WardrobeCollectionFrame.ItemsCollectionFrame`
--     的模型載入。我們對 `InfoButton` 只裁 `Icon` 的邊、對模型完全不碰 ⇒ 不重疊。
--   * 一支 M+ 用的小工具：`EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", …)`
--     幫外觀頁的職業名稱上色。純文字顏色，跟我們的區域沒有交集。
-- 套組內建、固定掛在收藏視窗上的自製元件：**沒有**（`MiliUI_*` 裡只有用
--   `C_MountJournal` / `C_ToyBox` 這類 API 的，沒有人在這些框上長東西）
--   ⇒ 這四份配方都不需要 `companions`。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local L = ns.L

local Shared = ns.CollectionsSkin

local function SkinItemsPage(f)
    local items
    if not (pcall(function() items = f.ItemsCollectionFrame end) and items) then
        E.Missing("WardrobeCollectionFrame.ItemsCollectionFrame")
        return
    end

    Shared.SkinCollectionsBackground(items, "WardrobeCollectionFrame.ItemsCollectionFrame")

    local paging
    if pcall(function() paging = items.PagingFrame end) and paging then
        Shared.SkinPaging(paging, "WardrobeCollectionFrame.ItemsCollectionFrame.PagingFrame")
    else
        E.Missing("WardrobeCollectionFrame.ItemsCollectionFrame.PagingFrame")
    end

    -- 武器部位才出現的那顆下拉（平常 hidden，照樣要套）
    local weapon
    if pcall(function() weapon = items.WeaponDropdown end) and weapon then
        Skin.Dropdown(weapon, "WardrobeCollectionFrame.ItemsCollectionFrame.WeaponDropdown", "style1")
    else
        E.Missing("WardrobeCollectionFrame.ItemsCollectionFrame.WeaponDropdown")
    end
end

local function SkinSetsPage(f)
    local sets
    if not (pcall(function() sets = f.SetsCollectionFrame end) and sets) then
        E.Missing("WardrobeCollectionFrame.SetsCollectionFrame")
        return
    end

    local left
    if pcall(function() left = sets.LeftInset end) and left then
        Skin.Inset(left, "WardrobeCollectionFrame.SetsCollectionFrame.LeftInset")
    else
        E.Missing("WardrobeCollectionFrame.SetsCollectionFrame.LeftInset")
    end

    -- ⚠ 右半邊是 CollectionsBackgroundTemplate 不是 InsetFrameTemplate（見檔頭 2.）
    local right
    if pcall(function() right = sets.RightInset end) and right then
        Shared.SkinCollectionsBackground(right, "WardrobeCollectionFrame.SetsCollectionFrame.RightInset")
    else
        E.Missing("WardrobeCollectionFrame.SetsCollectionFrame.RightInset")
    end

    local list
    if pcall(function() list = sets.ListContainer end) and list then
        Shared.SkinOwnedScrollBar(list, "WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBar")
    else
        E.Missing("WardrobeCollectionFrame.SetsCollectionFrame.ListContainer")
    end

    local variants
    if pcall(function() variants = sets.DetailsFrame.VariantSetsDropdown end) and variants then
        Skin.Dropdown(variants, "WardrobeCollectionFrame.SetsCollectionFrame.VariantSetsDropdown", "style1")
    else
        E.Missing("WardrobeCollectionFrame.SetsCollectionFrame.VariantSetsDropdown")
    end
end

local function Apply()
    local f = _G.WardrobeCollectionFrame
    if not f then
        E.Missing("WardrobeCollectionFrame")
        return
    end

    -- 頂部兩顆分頁：相連的是**下**邊，而且按鈕矩形首尾相接 ⇒ 左右都不內縮。
    -- 由左往右套，接縫上只有一條線（同 Skins/Collections.lua 的底部分頁）。
    for i, key in ipairs({ "ItemsTab", "SetsTab" }) do
        local tab
        if pcall(function() tab = f[key] end) and tab then
            Shared.SkinPanelTab(tab, "WardrobeCollectionFrameTab" .. i,
                { left = 0, right = 0, joined = "BOTTOM" })
        else
            E.Missing("WardrobeCollectionFrame." .. key)
        end
    end

    local search
    if pcall(function() search = f.SearchBox end) and search then
        Skin.EditBox(search, "WardrobeCollectionFrame.SearchBox")
    else
        E.Missing("WardrobeCollectionFrame.SearchBox")
    end

    local bar
    if pcall(function() bar = f.progressBar end) and bar then
        Shared.SkinProgressBar(bar, "WardrobeCollectionFrame.progressBar")
    else
        E.Missing("WardrobeCollectionFrame.progressBar")
    end

    -- ⚠ 這一頁的篩選鈕叫 `FilterButton`（不是別頁的 `FilterDropdown`），
    --   但模板一樣是 `WowStyle1FilterDropdownTemplate`。
    local filter
    if pcall(function() filter = f.FilterButton end) and filter then
        Skin.Dropdown(filter, "WardrobeCollectionFrame.FilterButton", "filter")
    else
        E.Missing("WardrobeCollectionFrame.FilterButton")
    end

    local class
    if pcall(function() class = f.ClassDropdown end) and class then
        Skin.Dropdown(class, "WardrobeCollectionFrame.ClassDropdown", "style1")
    else
        E.Missing("WardrobeCollectionFrame.ClassDropdown")
    end

    SkinItemsPage(f)
    SkinSetsPage(f)
end

E.Register{
    key   = "collections",              -- 跟 Skins/Collections.lua 同一個設定開關
    addon = "Blizzard_Collections",
    title = L["Collections: Appearances"],
    apply = Apply,
}
