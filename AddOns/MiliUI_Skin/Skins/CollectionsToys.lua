------------------------------------------------------------
-- 配方：收藏 —— 玩具箱 / 傳家寶 / 戰隊場景
--
-- 跟 Skins/Collections.lua 共用設定 key `collections`（理由見那一份的檔頭），
-- 共用工具在 `ns.CollectionsSkin`，TOC 保證 Collections.lua 先載入。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:39  CollectionsSpellButtonTemplate（← **SecureFrameTemplate**）
--   Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:5   CollectionsProgressBarTemplate
--   Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:186 CollectionsPagingFrameTemplate
--   Blizzard_Collections/Mainline/Blizzard_ToyBox.xml:5    ToySpellButtonTemplate ← CollectionsSpellButtonTemplate
--   Blizzard_Collections/Mainline/Blizzard_ToyBox.xml:25   ToyBox
--   Blizzard_Collections/Mainline/Blizzard_ToyBox.xml:27,30,39,47,144  progressBar／searchBox／FilterDropdown／iconsFrame／PagingFrame
--   Blizzard_Collections/Mainline/Blizzard_ToyBox.lua:445  ToyBox_UpdateProgressBar（只 SetMinMaxValues／SetValue）
--   Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.xml:5    HeirloomHeaderTemplate
--   Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.xml:29   HeirloomSpellButtonTemplate ← CollectionsSpellButtonTemplate
--   Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.xml:105  HeirloomsJournal
--   Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.xml:107,108,117,125,130,131
--        progressBar／SearchBox／FilterDropdown／ClassDropdown／iconsFrame／PagingFrame
--   Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.lua:409,451  AcquireFrame／LayoutCurrentPage（標題列的池子）
--   Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.lua:657  UpdateProgressBar
--   Blizzard_Collections/Mainline/Blizzard_WarbandSceneCollection.xml:3   WarbandSceneJournal
--   Blizzard_Collections/Mainline/Blizzard_WarbandSceneCollection.xml:5,7,19,28,35,59
--        IconsFrame／Icons／Controls／ShowOwned／Checkbox／PagingControls
--   Blizzard_SharedXML/Mainline/SharedCollectionTemplates.xml:56  CollectionsBackgroundTemplate
--   Blizzard_Menu/Mainline/MenuTemplates.xml:3,66  WowStyle1DropdownTemplate／WowStyle1FilterDropdownTemplate
--
-- 查證後跟計畫假設不一樣的三件事：
--   1. **玩具格與傳家寶格是 secure 框。** 兩者都繼承
--      `CollectionsSpellButtonTemplate`，而它 `inherits="SecureFrameTemplate"`
--      （Blizzard_CollectionTemplates.xml:39）⇒ `IsProtected()` 為真，
--      `Engine.Overlay` 會擋下來並記進 `/mskin debug` 的「因為是保護框而跳過」。
--      **這一輪對那兩種格子一個動作都不做**（連中和都不做），理由見下面
--      「刻意不碰的東西」第 1 條。
--   2. **玩具箱／傳家寶的格子背景是 `CollectionsBackgroundTemplate`**，
--      不是普通的 `InsetFrameTemplate` —— 除了 `Bg`／`NineSlice` 之外還有一張平鋪底
--      ＋ 8 張外陰影 ＋ 8 張內陰影 ＋ 4 個角花（SharedCollectionTemplates.xml:56-202）。
--      整組中和才乾淨，收在 `ns.CollectionsSkin.SkinCollectionsBackground`。
--   3. **傳家寶多一顆「職業」下拉**（`ClassDropdown`，`WowStyle1DropdownTemplate`），
--      跟 `FilterDropdown`（filter 版）不是同一種，`Skin.Dropdown` 的 kind 要分開傳。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 物件 | 動作 |
-- |---|---|
-- | ToyBox / HeirloomsJournal / WarbandSceneJournal 的 iconsFrame（21 張裝飾 ＋ Bg ＋ NineSlice） | SetAlpha(0) |
-- | 同上三個 iconsFrame | CreateFrame 掛 Inset overlay |
-- | ToyBox.progressBar / HeirloomsJournal.progressBar 的 border ＋無名黑底 | SetAlpha(0) |
-- | 同兩條的填充貼圖 | SetStatusBarTexture（走 Engine.BarTexture）＋ SetVertexColor（綠） |
-- | ToyBox.searchBox / HeirloomsJournal.SearchBox 的 Left/Right/Middle | SetAlpha(0) |
-- | 同兩個的 searchIcon / clearButton.Icon / Instructions | SetVertexColor / SetTextColor |
-- | 三顆下拉的 Background | SetAlpha(0)；ClassDropdown.Arrow | SetVertexColor |
-- | 四組翻頁鈕的 Normal/Pushed/Disabled 貼圖 | SetVertexColor |
-- | 四組翻頁鈕的 Highlight 貼圖 | SetColorTexture |
-- | WarbandSceneJournal 的 ShowOwned.Checkbox 的 Normal/Pushed/Disabled | SetAlpha(0) |
-- | 同一顆的 Checked / DisabledChecked | SetColorTexture（職業色） |
-- | 以上各框 | CreateFrame 掛自己的 overlay |
--
-- hook：**無**。這三頁沒有池化列（玩具與傳家寶是 18 顆固定格子、
--   戰隊場景走 `PagedNaturalSizeGridContentFrameTemplate`）。
-- 寫入暴雪欄位：無。讀暴雪物件：只有 `GetRegions` / `GetFrameLevel`。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- 1. **玩具格（`ToySpellButtonTemplate`）與傳家寶格（`HeirloomSpellButtonTemplate`）**。
--    兩者都繼承 `SecureFrameTemplate` ⇒ `IsProtected()` 為真 ⇒ 依契約不掛 overlay，
--    `Engine.Overlay` 會自己擋（**不為它開後門**）。
--    剩下「只中和純裝飾貼圖」那條路也**刻意不走**：那顆按鈕的長相幾乎全在
--    `slotFrameCollected`／`slotFrameUncollected` 兩張框上
--    （Blizzard_CollectionTemplates.xml:92,98），中和掉之後我們**沒有東西可以補**
--    （不能掛 overlay），結果是一片沒有框的裸圖示 —— 比整頁不換皮更難看，
--    而且「已收集／未收集」那組明暗也跟著弱掉。
--    ⇒ 格子維持暴雪原樣，只把它們坐的那塊底換成皮。
-- 2. **`HeirloomHeaderTemplate` 的分類標題帶**（`collections-slotheader`）。
--    那張 atlas 是亮色的，上面的 `text` 是**深橄欖綠**（XML 寫死 0.47/0.44/0.28，
--    .xml:17）—— 中和底材就必須連文字一起接管（內容底材規則）。
--    接管的路徑只有一條：勾 `HeirloomsMixin:LayoutCurrentPage` 然後走訪
--    `self.heirloomHeaderFrames`（HeirloomCollection.lua:409,451）—— 那是**讀暴雪框
--    的欄位**，不在讀取例外表裡。標題帶因此原樣保留：它自己是「亮底深字」，
--    內部一致，不會出現深底暗字。
-- 3. **傳家寶格的升級光暈／等級泡泡（`glow`／`bling`／`levelBackground`／`level`）**
--    與**玩具格的冷卻框**：都是資訊，而且住在保護框上。
-- 4. **戰隊場景的 `PagingControls`**（`PagingControlsHorizontalTemplate`）與
--    `Icons`（`PagedNaturalSizeGridContentFrameTemplate`）：兩個都是 layout host
--    系的共用模板，接觸面要另外查一輪，這一輪只做 `IconsFrame` 的底與那顆勾選框。
-- 5. **戰隊場景的場景卡（`WarbandSceneTemplate`）**：整張卡就是一張預覽圖 ＋
--    `campcollection-frame` 外框，跟坐騎的模型背景同一類內容底材。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local L = ns.L

local Shared = ns.CollectionsSkin

------------------------------------------------------------
-- 一頁的共同形狀：進度條 ＋ 搜尋框 ＋ 篩選下拉 ＋ 格子底 ＋ 翻頁
------------------------------------------------------------
-- spec:
--   frame       頁框
--   key         debug 前綴
--   search      搜尋框的 parentKey（玩具箱是小寫 `searchBox`、傳家寶是 `SearchBox`）
--   icons       格子底的 parentKey（同樣一大一小寫）
--   classDrop   額外的 `WowStyle1DropdownTemplate` 下拉（只有傳家寶有）
local function SkinCollectionPage(spec)
    local f = spec.frame
    if not E.Usable(f, spec.key) then return end

    local bar
    if pcall(function() bar = f.progressBar end) and bar then
        Shared.SkinProgressBar(bar, spec.key .. ".progressBar")
    else
        E.Missing(spec.key .. ".progressBar")
    end

    local search
    if pcall(function() search = f[spec.search] end) and search then
        Skin.EditBox(search, spec.key .. "." .. spec.search)
    else
        E.Missing(spec.key .. "." .. spec.search)
    end

    local filter
    if pcall(function() filter = f.FilterDropdown end) and filter then
        Skin.Dropdown(filter, spec.key .. ".FilterDropdown", "filter")
    else
        E.Missing(spec.key .. ".FilterDropdown")
    end

    if spec.classDrop then
        local drop
        if pcall(function() drop = f.ClassDropdown end) and drop then
            Skin.Dropdown(drop, spec.key .. ".ClassDropdown", "style1")
        else
            E.Missing(spec.key .. ".ClassDropdown")
        end
    end

    local icons
    if pcall(function() icons = f[spec.icons] end) and icons then
        Shared.SkinCollectionsBackground(icons, spec.key .. "." .. spec.icons)
    else
        E.Missing(spec.key .. "." .. spec.icons)
    end

    local paging
    if pcall(function() paging = f.PagingFrame end) and paging then
        Shared.SkinPaging(paging, spec.key .. ".PagingFrame")
    else
        E.Missing(spec.key .. ".PagingFrame")
    end
end

------------------------------------------------------------
-- 戰隊場景（12.x 新分頁）：只做 chrome
------------------------------------------------------------
local function SkinWarbandScenes()
    local j = _G.WarbandSceneJournal
    if not j then
        E.Missing("WarbandSceneJournal")
        return
    end

    local icons
    if pcall(function() icons = j.IconsFrame end) and icons then
        Shared.SkinCollectionsBackground(icons, "WarbandSceneJournal.IconsFrame")
    else
        E.Missing("WarbandSceneJournal.IconsFrame")
        return
    end

    -- 「只顯示已擁有」勾選框。它掛在 HorizontalLayoutFrame 底下，但 overlay 的
    -- parent 由 `Engine.SafeParent` 決定（勾選框自己不是 layout host）⇒ 安全。
    local cb
    if pcall(function() cb = icons.Icons.Controls.ShowOwned.Checkbox end) and cb then
        Skin.CheckBox(cb, "WarbandSceneJournal.ShowOwned.Checkbox")
    else
        E.Missing("WarbandSceneJournal.ShowOwned.Checkbox")
    end
end

local function Apply()
    local toyBox = _G.ToyBox
    if toyBox then
        SkinCollectionPage{
            frame  = toyBox,
            key    = "ToyBox",
            search = "searchBox",
            icons  = "iconsFrame",
        }
    else
        E.Missing("ToyBox")
    end

    local heirlooms = _G.HeirloomsJournal
    if heirlooms then
        SkinCollectionPage{
            frame     = heirlooms,
            key       = "HeirloomsJournal",
            search    = "SearchBox",
            icons     = "iconsFrame",
            classDrop = true,
        }
    else
        E.Missing("HeirloomsJournal")
    end

    SkinWarbandScenes()
end

E.Register{
    key   = "collections",              -- 跟 Skins/Collections.lua 同一個設定開關
    addon = "Blizzard_Collections",
    title = L["Collections: Toys & Heirlooms"],
    apply = Apply,
}
