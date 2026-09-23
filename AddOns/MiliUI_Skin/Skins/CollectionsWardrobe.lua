------------------------------------------------------------
-- 配方：收藏 —— 外觀（WardrobeCollectionFrame）
--
-- 跟 Skins/Collections.lua 共用設定 key `collections`（理由見那一份的檔頭），
-- 共用工具在 `ns.CollectionsSkin`。
--
-- **範圍：chrome ＋ 控制列 ＋（第十四輪）套裝頁的兩排圖示。** 模型格子（`DressUpModel`）、
-- 部位按鈕、套裝清單列本身的底圖這一輪都不做，理由見下面「刻意不碰的東西」。
-- 塑形師那個大視窗（`WardrobeFrame`）不在這一輪，它是另一個框。
--
-- ## 第十四輪（2026-09-23，使用者看實機擷圖點名）：套裝頁的圖示改方形
--
-- 成熟同類實作在這兩排圖示上沒有專門的處理（只有整個收藏視窗的通用掃描），
-- 所以這一段是照「圖示一律方形＋1px 硬邊、品質色走框」的套組語彙自己做的。
--
-- 1. **左側套裝清單每列的圖示** → 裁邊 ＋ 1px 黑框。
--    列是 `WardrobeSetsScrollFrameButtonTemplate`（mixin `WardrobeSetsScrollFrameButtonMixin`，
--    Blizzard_Collections/Shared/Blizzard_Wardrobe_Sets.xml:5），ScrollBox 第一次顯示套裝頁
--    才從池子建 ⇒ `Engine.HookRows` 勾 mixin 的 `Init`（Blizzard_Wardrobe_Sets.lua:515）。
--    圖示每次 `Init` 都被 `SetIconTexture` → `Icon:SetTexture`（:611-613）打回 texCoord ⇒ 裁邊放 reapply。
--    框是 `IconFrame` **自己的**四張貼圖（`Engine.RegionBackdrop`），邊畫在 OVERLAY −2：
--    蓋在圖示（ARTWORK）上、在「未收藏」的黑色遮罩 `Cover`（OVERLAY −1）與最愛星號
--    `Favorite`（OVERLAY 1）之下 —— 星號露在框外那一角不會被線切過。
-- 2. **右側套裝細節上方那一排部位圖示** → 裁邊 ＋ 1px 方框，**框的顏色照品質**。
--    ⚠ 查證後跟計畫假設不一樣：暴雪**不是**用 vertex color 上品質色，
--    是**每個品質一張 atlas**（`WardrobeSetsCollectionMixin:SetItemFrameQuality`，
--    Blizzard_Wardrobe_Sets.lua:332-349 → `ColorManager.GetAtlasDataForWardrobeSetItemQuality`，
--    Blizzard_Colors/Mainline/ColorManager.lua:174-192 → `WARDROBE_SETS_ITEM_QUALITY_ICON_BORDER_ATLASES`，
--    ColorConstants.lua:98-102）：綠／藍／紫三張（各 41x41 的雕花框），`SetVertexColor(1,1,1)`；
--    只有色盲／自訂品質色（`ITEM_QUALITY_OVERRIDES`）才用白底的 `loottab-set-itemborder-color`
--    ＋ `SetVertexColor(覆寫色)`；未收藏是 `loottab-set-itemborder-white`。
--    ⇒ `Engine.PassBorderColor` 只轉交 vertex color，**對綠藍紫三種會拿到白色**。
--    所以這一支多讀一樣東西：`IconBorder:GetAtlas()`（**待加進讀取例外表**，見 `SetItemQualityBorder`）：
--      * `-color`（覆寫色）→ 照舊走 `PassBorderColor`（傳遞者規則，轉交暴雪設的 vertex color）；
--      * 綠／藍／紫 → 反查暴雪自己那張「品質 → atlas」表，拿 `ITEM_QUALITY_COLORS[品質]`
--        （`ColorManager.UpdateColorsForItemQuality` 建的，已含覆寫色，ColorManager.lua:19-26）；
--      * 其餘（未收藏的白框、沒有 atlas）→ 1px 黑框。
--    暴雪那張雕花框（`IconBorder`）中和（alpha 0）。
--    ⚠ 這排圖示是 `CreateFramePool` 借的（:78），更新全在 `WardrobeSetsCollectionMixin` 的方法裡
--    （`DisplaySet` :224／`SetItemFrameQuality` :332／`OnEvent` :188），而 `SetsCollectionFrame`
--    是 XML 載入期建的 ⇒ 那些方法是**拷走的副本**，勾 mixin 不會跑；圖示框自己的 mixin
--    只剩 `OnShow`（`HookScript OnShow` 契約禁止，同理不勾它的 mixin 版）。
--    ⇒ 觸發點改成「排一次下一幀的補掃」，由三支 hook 排：
--      a. `ColorManager.GetAtlasDataForWardrobeSetItemQuality`（全域表的函式，整份原始碼只有這裡在用）——
--         `SetItemFrameQuality` 已收藏那一支每次都會呼叫：換套裝、`GET_ITEM_INFO_RECEIVED`、
--         `TRANSMOG_COLLECTION_ITEM_UPDATE` 都帶得到；
--      b. 清單列的 `Init`（`Refresh`／打開套裝頁都會重建清單，緊接著 `DisplaySet`）；
--      c. 清單列的 `SetSelected`（:557；點清單換套裝 ⇒ 選取回呼 → `SelectBaseSetID` → `DisplaySet`）。
--    補掃：`DetailsFrame:GetChildren()`（讀結構）認出有 `Icon`／`IconBorder`／`Favorite` 的子框。
--    ⚠ 補掃晚一幀：換套裝的那一幀暴雪剛把雕花框 `SetAlpha(1 或 0.3)` 回來 ⇒ **可能閃一幀**。
--    ⚠ 已知漏洞：從**變體下拉**換到一個「一件都沒收藏」的變體 —— 那條路不經過 a／b／c
--      （選取沒變、沒有已收藏的件），補掃不會跑，框留著上一個變體的顏色，
--      直到下一次換套裝／重開。要補就得勾 `SetsCollectionFrame` 的框實例，契約不准。
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
-- | 套裝清單列的 `IconFrame.Icon` | SetTexCoord（裁邊，每次 Init 之後） |
-- | 套裝清單列的 `IconFrame` | `Engine.RegionBackdrop`（四條 1px 黑邊，**它自己的** OVERLAY −2 貼圖） |
-- | 套裝細節部位圖示的 `Icon` | SetTexCoord（裁邊，每次補掃） |
-- | 同一顆的 `IconBorder`（雕花品質框） | SetAlpha(0)（每次補掃：`DisplaySet` 每次都 `SetAlpha(1/0.3)`） |
-- | 同一顆 | `Engine.RegionBackdrop`（四條 1px 邊，錨在 `Icon` 的矩形上、ARTWORK 層），顏色見檔頭 2. |
--
-- hook：Engine 的三個 `PanelTemplates_*` 全域後置勾與兩顆分頁的
--   `HookScript("OnEnter"/"OnLeave")`（都由 `Engine.TrackTab` 代掛）；第十四輪加：
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `WardrobeSetsScrollFrameButtonMixin:Init` | mixin 後置勾（`Engine.HookRows`） | 第一次：`IconFrame` 建四條邊；每次：圖示裁邊、排一次細節圖示補掃。**不讀 elementData** |
-- | `WardrobeSetsScrollFrameButtonMixin:SetSelected` | mixin 後置勾（`Engine.HookRows`，`requireKnown`） | 只排一次細節圖示補掃（**不讀參數 `selected`**） |
-- | `ColorManager.GetAtlasDataForWardrobeSetItemQuality` | 全域表函式後置勾 | 只排一次細節圖示補掃（**不讀參數 `quality`**、不看回傳值） |
--
-- 補掃跑在 `C_Timer.After(0)` 的下一幀，同一幀只排一次。
--
-- 寫入暴雪欄位：無。讀暴雪物件：`Engine.TrackTab` 的 `LeftActive:IsShown()`
--   （讀取例外表第 4 條）與 `GetFrameLevel`；`ScrollBox:ForEachFrame`／`GetChildren()`（結構）；
--   第十四輪：細節部位圖示 `IconBorder` 的 `IsShown()`／`GetVertexColor()`（`Engine.PassBorderColor`）
--   與 **`GetAtlas()`（新的讀取例外，待主控加進 STYLE ③；理由見 `SetItemQualityBorder`）**；
--   暴雪的全域常數表 `WARDROBE_SETS_ITEM_QUALITY_ICON_BORDER_ATLASES`／`ITEM_QUALITY_COLORS`。
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
-- * **`SetsCollectionFrame.ListContainer.ScrollBox` 的套裝列本身**（列底 `Background`、
--   選中 `SelectedTexture`、滑過、進度條、名字顏色）：`WowScrollBoxList` 的池化 element，
--   而且**整包裡另有第三方插件掛在同一個 ScrollBox 上**（見下面「別的插件」那一段）。
--   第十四輪只動每列的**圖示**（`IconFrame`；那支插件畫的小圖示是它自己的框，不在這裡）。
--   名字的綠／金／灰是「收集進度」的**狀態**，每次 `Init` 都 `SetTextColor`，不接管。
-- * **`SetsCollectionFrame.DetailsFrame` 的其餘部分**（套裝名、`LimitedSet`、`IconRowBackground`、
--   `ModelFadeTexture`）：貼在模型上的一層資訊，底材是模型場景。第十四輪只動那一排部位圖示。
--   部位圖示上的「新」光暈（`New`）與最愛星號（`Favorite.Icon`）是資訊，不碰。
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
local T = ns.Tokens
local L = ns.L
local S = ns.Secret

local Shared = ns.CollectionsSkin

local TRANSPARENT = { 0, 0, 0, 0 }

local function Probe(owner, key)
    local v
    if type(owner) == "table" and pcall(function() v = owner[key] end) then return v end
    return nil
end

------------------------------------------------------------
-- 套裝細節那一排部位圖示（`WardrobeSetsDetailsItemFrameTemplate`，
-- Blizzard_Collections/Shared/Blizzard_Wardrobe_Sets.xml:80）
--
-- `Icon`（BORDER，28x28 置中）／`IconBorder`（OVERLAY，41x41 雕花品質框 atlas，
-- 錨 RIGHT → Icon 的 CENTER x=20）／`New`（OVERLAY，光暈）／`Favorite`（子框，星號）。
------------------------------------------------------------
local DETAIL_KEY = "WardrobeSetsDetailsItem"
local detailsFrame            -- `SetsCollectionFrame.DetailsFrame`（Apply 時記下；只拿來 GetChildren）
local detailDone = setmetatable({}, { __mode = "k" })

local function IsDetailItem(f)
    return (Probe(f, "Icon") and Probe(f, "IconBorder") and Probe(f, "Favorite")) and true or false
end

-- 暴雪「品質 → atlas」表反查成「atlas → 品質」。表是暴雪的全域常數
-- （ColorConstants.lua:98-102），讀不到就退回同一份字面值。
local OVERRIDE_ATLAS = "loottab-set-itemborder-color"
local qualityByAtlas

local function QualityByAtlas()
    if qualityByAtlas then return qualityByAtlas end
    qualityByAtlas = {}
    local src = _G.WARDROBE_SETS_ITEM_QUALITY_ICON_BORDER_ATLASES
    if type(src) == "table" then
        for q, atlas in pairs(src) do
            if type(atlas) == "string" then qualityByAtlas[atlas] = q end
        end
    end
    if next(qualityByAtlas) == nil and Enum and Enum.ItemQuality then
        qualityByAtlas["loottab-set-itemborder-green"]  = Enum.ItemQuality.Uncommon
        qualityByAtlas["loottab-set-itemborder-blue"]   = Enum.ItemQuality.Rare
        qualityByAtlas["loottab-set-itemborder-purple"] = Enum.ItemQuality.Epic
    end
    return qualityByAtlas
end

------------------------------------------------------------
-- 品質框的顏色
--
-- ⚠ **新的讀取例外（待主控加進 STYLE.md ③ 的表）：`IconBorder:GetAtlas()`**
--   條件逐條對照表頭那一句「純 C 端查詢、不是文字／尺寸／錨點、不會回秘密值」：
--     * 純 C 端查詢：貼圖目前的 atlas 名；
--     * 不是文字／尺寸／錨點；
--     * 不會是秘密值：收藏資料不在 12.1 的秘密值範圍，atlas 名是美術資源的名字；
--       照樣過 `Secret.PlainText`，問不到（或是秘密）⇒ 當成「沒有品質」＝黑框，失敗方向安全。
--   為什麼非讀不可：品質色烤在 atlas 裡（見檔頭 2.），三種品質的 vertex color 都是白色，
--   `PassBorderColor` 轉交不到。這是暴雪自己表達「這件是什麼品質」的**同一個**依據
--   （`SetItemFrameQuality` 依品質選 atlas）。
--   讀到的字串只拿去查兩張**暴雪自己的**常數表，不存、不跨幀使用。
-- TODO(升格): 若別的配方也遇到「品質烤在 atlas 裡」，收成 `Engine.PassAtlasQuality`。
------------------------------------------------------------
local function SetItemQualityBorder(rec, iconBorder)
    if not rec then return end
    local atlas
    if type(iconBorder.GetAtlas) == "function" then
        local ok, v = pcall(iconBorder.GetAtlas, iconBorder)
        if ok then atlas = S.PlainText(v) end
    end
    if atlas == OVERRIDE_ATLAS then
        -- 覆寫色：暴雪是 `SetVertexColor(覆寫色)` ⇒ 傳遞者規則，原封不動轉交
        E.PassBorderColor(rec, iconBorder)
        return
    end
    local q = atlas and QualityByAtlas()[atlas]
    local colors = _G.ITEM_QUALITY_COLORS
    local c = q and type(colors) == "table" and colors[q]
    if type(c) == "table" and type(c.r) == "number" then
        E.Border(rec, { c.r, c.g, c.b, 1 })
    else
        E.Border(rec, T.border)
    end
end

local function SkinDetailItem(f)
    local icon = Probe(f, "Icon")
    local iconBorder = Probe(f, "IconBorder")
    if not icon or not iconBorder then return end
    local rec
    if not detailDone[f] then
        if E.IsProtectedFrame(f) then return end
        detailDone[f] = true
        -- 邊畫在 ARTWORK（圖示是 BORDER、光暈 `New` 是 OVERLAY、星號是子框）⇒
        -- 蓋在圖示上、在光暈與星號之下。錨在 `Icon` 的矩形上（不是整顆 32x32 的框）。
        rec = E.RegionBackdrop(f, {
            key = DETAIL_KEY,
            slot = "qualityBorder",
            edgeLayer = "ARTWORK",
            edgeSublevel = 0,
            points = {
                { "TOPLEFT", "TOPLEFT", 0, 0, rel = icon },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, rel = icon },
            },
        })
        if rec then E.Fill(rec, TRANSPARENT) end
    else
        rec = E.GetOverlay(f, "qualityBorder")
    end
    -- 每次都重申：`DisplaySet` 每次都 `Icon:SetTexture`（texCoord 回 0,1）與
    -- `IconBorder:SetAlpha(1 或 0.3)`，`SetItemFrameQuality` 每次都換 atlas
    E.CropIcon(icon, DETAIL_KEY .. ".Icon")
    E.Neutralize(iconBorder, DETAIL_KEY .. ".IconBorder")
    SetItemQualityBorder(rec, iconBorder)
end

local function SweepDetails()
    if not detailsFrame or type(detailsFrame.GetChildren) ~= "function" then return end
    local ok, kids = pcall(function() return { detailsFrame:GetChildren() } end)
    if not ok then return end
    for _, f in ipairs(kids) do
        if IsDetailItem(f) then SkinDetailItem(f) end
    end
end

-- 出錯一次就停用（同 `Engine.HookRows` 的紀律：換一次套裝報一串錯比少一塊皮嚴重）
local detailPending = false
local detailBroken = false
local function ScheduleDetailSweep()
    if detailPending or detailBroken or not detailsFrame then return end
    detailPending = true
    C_Timer.After(0, function()
        detailPending = false
        local ok, err = pcall(SweepDetails)
        if not ok then
            detailBroken = true
            E.NoteBrokenHook(DETAIL_KEY .. ":sweep")
            ns.ReportError(err)
        end
    end)
end

------------------------------------------------------------
-- 左側套裝清單每列的圖示（`WardrobeSetsScrollFrameButtonTemplate.IconFrame`，
-- Blizzard_Wardrobe_Sets.xml:8-34：38x38，`Icon` ARTWORK setAllPoints、`Cover` OVERLAY −1、
-- `Favorite` OVERLAY 1 錨 TOPLEFT −8,8）
------------------------------------------------------------
local SET_ROW_KEY = "WardrobeSetsScrollFrameButton"
local setRowSweep

local function IsSetRow(row)
    return (Probe(row, "IconFrame") and Probe(row, "SelectedTexture") and Probe(row, "ProgressBar")) and true or false
end

local function SetRowApply(row)
    local iconFrame = Probe(row, "IconFrame")
    if not iconFrame then return end
    local rec = E.RegionBackdrop(iconFrame, {
        key = SET_ROW_KEY .. ".IconFrame",
        slot = "iconBorder",
        edgeLayer = "OVERLAY",
        edgeSublevel = -2,
    })
    E.Paint(rec, TRANSPARENT, T.border)
end

local function SetRowReapply(row)
    local iconFrame = Probe(row, "IconFrame")
    local icon = iconFrame and Probe(iconFrame, "Icon")
    if icon then E.CropIcon(icon, SET_ROW_KEY .. ".Icon") end
    ScheduleDetailSweep()
end

local function InstallHooks()
    -- ⚠ 不過戰鬥閘（`Engine.RunUnit` 把 hooks 排在戰鬥閘前面）：清單列是第一次打開
    --   套裝頁才建的，hook 一定要比那一刻早（陷阱 4）。
    local mixin = _G.WardrobeSetsScrollFrameButtonMixin
    setRowSweep = E.HookRows{
        key     = SET_ROW_KEY .. ":Init",
        mixin   = mixin,
        method  = "Init",
        apply   = SetRowApply,
        reapply = SetRowReapply,
        match   = IsSetRow,
    }
    E.HookRows{
        key          = SET_ROW_KEY .. ":SetSelected",
        mixin        = mixin,
        method       = "SetSelected",
        requireKnown = true,
        reapply      = function() ScheduleDetailSweep() end,
    }

    -- 全域表 `ColorManager` 的函式（Blizzard_Colors 在登入時就載入）。
    -- 裡面只排補掃：不讀參數 `quality`、不看回傳值。
    local cm = _G.ColorManager
    if type(cm) == "table" and type(cm.GetAtlasDataForWardrobeSetItemQuality) == "function" then
        hooksecurefunc(cm, "GetAtlasDataForWardrobeSetItemQuality", function()
            ScheduleDetailSweep()
        end)
    else
        E.Missing("ColorManager.GetAtlasDataForWardrobeSetItemQuality")
    end
end

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

    -- 第十四輪：清單列圖示（已經建好的列補掃一遍）與細節部位圖示
    local box = list and Probe(list, "ScrollBox")
    if box then E.SweepRows(box, SET_ROW_KEY, setRowSweep) end
    detailsFrame = Probe(sets, "DetailsFrame")
    if detailsFrame then
        SweepDetails()
    else
        E.Missing("WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame")
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

    -- 頂部兩顆分頁：相連的是**下**邊（`PanelTopTabButtonTemplate` 掛在內容框上緣），
    -- 按鈕矩形首尾相接（`LEFT → RIGHT x="0"`）⇒ `pad = 0`。
    -- 第一顆的右緣錨在第二顆的左緣上，接縫只留一條 1px 黑線（`Skin.TabGroup`）。
    local tabs = {}
    for i, key in ipairs({ "ItemsTab", "SetsTab" }) do
        local tab
        if pcall(function() tab = f[key] end) and tab then
            tabs[#tabs + 1] = { tab = tab, key = "WardrobeCollectionFrameTab" .. i }
        else
            E.Missing("WardrobeCollectionFrame." .. key)
        end
    end
    Skin.TabGroup(tabs, { kind = "panel", joined = "BOTTOM" })

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
    hooks = InstallHooks,
    apply = Apply,
}
