------------------------------------------------------------
-- 配方：專業（`ProfessionsFrame`，隨需載入 `Blizzard_Professions`
--       ＋ 它的模板插件 `Blizzard_ProfessionsTemplates`）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_Professions/Blizzard_ProfessionsFrame.xml:5,7
--     `ProfessionsFrameTabTemplate` ← **`TabSystemButtonTemplate`**；
--     `ProfessionsFrame` ← `PortraitFrameTemplateNoCloseButton, TabSystemOwnerTemplate`
--   同檔 :10,11,17,28-30
--     `CloseButton`／`MaximizeMinimize`（MaximizeMinimizeButtonFrameTemplate）／
--     `TabSystem`（**錨在視窗的 BOTTOMLEFT ⇒ 分頁在內容下方**）／
--     `CraftingPage`／`SpecPage`／`OrdersPage`
--   Blizzard_ProfessionsFrame.lua:35,41-43  `ProfessionsMixin:OnLoad` →
--     `AddNamedTab` ×3（配方／專精／製作訂單）⇒ **三顆分頁在 XML 載入期就建好**
--   同檔 :349,457  `ProfessionsMixin:SetTab` → 最後一行
--     `TabSystemOwnerMixin.SetTab(self, tabID)`（**明碼的全域表查詢**，見下面）
--   Blizzard_SharedXML/Shared/TabSystem/TabSystemOwner.lua:98
--     `TabSystemOwnerMixin:SetTab` → `self.tabSystem:SetTabVisuallySelected(tabID)`
--   Blizzard_Professions/Blizzard_ProfessionsCrafting.xml:86,122
--     `ProfessionsGearSlotTemplate`（ItemButton，走 `PaperDollItemSlotButton_*`）／
--     `ProfessionsCraftingPageTemplate`
--   同檔 :136,144,167,199,205,209,219,226,362
--     `RecipeList`／`SchematicForm`（`Background`／`MinimalBackground`／`NineSlice`，
--      layoutType = InsetFrameTemplate）／`MinimizedSearchBox`／`RankBar`／
--     `CreateButton`／`CreateMultipleInputBox`（NumericInputSpinnerTemplate）／
--     `CreateAllButton`／`ViewGuildCraftersButton`／`LinkButton`
--   Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.xml:5,66,94,151
--     `ProfessionsRecipeListTemplate`（`Background` atlas Professions-background-summarylist
--      ＋ `BackgroundNineSlice` ＋ `FilterDropdown` ＋ `SearchBox` ＋ `ScrollBox`
--      ＋ `ScrollBar`）／`ProfessionsRecipeListDividerTemplate`／
--     `ProfessionsRecipeListCategoryTemplate`（`LeftPiece`／`CenterPiece`／`RightPiece`
--      ＋ `Label` ＋ `CollapseIcon` ＋ `RankBar`）／
--     `ProfessionsRecipeListRecipeTemplate`（`Label`／`Count`／`SkillUps`／`LockedIcon`
--      ＋ `SelectedOverlay`（ARTWORK 之上，atlas Professions_Recipe_Active）
--      ＋ `HighlightOverlay`（**HIGHLIGHT 層**，atlas Professions_Recipe_Hover））
--   Blizzard_ProfessionsRecipeList.lua:192,236,374
--     `ProfessionsRecipeListCategoryMixin:Init(node)`／
--     `ProfessionsRecipeListRecipeMixin:Init(node, hideCraftableCount)`／
--     `ProfessionsRecipeListRecipeMixin:SetSelected(selected)` →
--       `SelectedOverlay:SetShown(selected)` ＋ `HighlightOverlay:SetShown(not selected)`
--   Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeSchematicForm.xml:31,52,56,114,116
--     `OutputIcon`（← **CircularGiantItemButtonTemplate**）／`TrackRecipeCheckbox`／
--     `AllocateBestQualityCheckbox`（兩顆都是 `UICheckButtonTemplate`）／
--     `RecipeLevelBar`／`RecipeLevelDropdown`
--   Blizzard_Professions/Blizzard_ProfessionsRankBar.xml:5
--     `ProfessionsRankBarTemplate` —— **不是 StatusBar**，見下面第 2 點
--   Blizzard_Professions/Blizzard_ProfessionsCrafterOrderPage.xml:5,32,46
--     `ProfessionsCraftingOrderTypeTabTemplate` ← `TabSystemButtonArtTemplate`
--      （`isTabOnTop = true`）／`ProfessionsCrafterOrderListElementTemplate`／
--     `ProfessionsCraftingOrderPageTemplate`
--   同檔 :54,56,66,72,79,88,103,109,119,124,162-199,226
--     `BrowseFrame`／`RecipeList`／`FavoritesSearchButton`（SquareIconButtonTemplate）／
--     `SearchButton`／`BackButton`（Normal/Pushed/Disabled 是翻頁箭頭）／
--     `OrderList`（`Background` atlas auctionhouse-background-index ＋
--      `HeaderContainer` ＋ `NineSlice` ＋ `ScrollBox` ＋ `ScrollBar`）／
--     四顆範圍分頁／`OrdersRemainingDisplay`／`OrderView`
--   Blizzard_ProfessionsCrafterOrderPage.lua:611-615
--     `ProfessionsCraftingOrderPageMixin:SetCraftingOrderType` →
--     `typeTab:SetTabSelected(...)`（**frame 自己那份副本**，見下面第 3 點）
--   Blizzard_Professions/Blizzard_ProfessionsCrafterOrderView.xml:44,109,115,122,177,202,209,302,316,421,430,439,448
--     `OrderInfo`（`Background` ＋ `NineSlice`）／`BackButton`／`SocialDropdown`
--      （UIMenuButtonStretchTemplate）／`StartOrderButton`／`DeclineOrderButton`／
--     `ReleaseOrderButton`／`OrderDetails`（`Background` ＋ `NineSlice`）／
--     `CreateButton`／`CompleteOrderButton`／`StartRecraftButton`／`StopRecraftButton`
--   Blizzard_Professions/Blizzard_ProfessionsSpecializations.xml:5,20,36,43,51,59,66,73,80
--     `ProfessionsSpecPageTemplate` ← **`TalentFrameBaseTemplate`**／`PanelFooter`
--      （一張無名的 Professions-Specializations-Background-Footer）／`ApplyButton`／
--     `UnlockTabButton`／`ViewTreeButton`／`BackToPreviewButton`／`ViewPreviewButton`／
--     `BackToFullTreeButton`／`UndoButton`（IconButtonTemplate）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1032
--     `MaximizeMinimizeButtonFrameTemplate`（`MaximizeButton`／`MinimizeButton`）
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的四件事
--
-- 1. **頂部三顆分頁在 XML 載入期就建好了**（`ProfessionsMixin:OnLoad` →
--    `AddNamedTab` ×3），比我們的 `ADDON_LOADED` 早 ⇒ `Engine.TabSystemHooks`
--    的 mixin 後置勾對它們一點用都沒有（陷阱 4 的第三層、註 ⓘ）。
--    好友名單的解法是勾一支**全域刷新函式**；專業沒有全域函式，但
--    `ProfessionsMixin:SetTab` 的最後一行是
--    **`TabSystemOwnerMixin.SetTab(self, tabID)`** —— 明碼的全域 mixin 表查詢，
--    每次切分頁都會重新解析 ⇒ `hooksecurefunc(TabSystemOwnerMixin, "SetTab", …)`
--    接得到，而且**不必在暴雪框上寫任何欄位**。
--    ⚠ 反過來 `hooksecurefunc(ProfessionsFrame, "SetTab", …)` 是**禁止**的：
--      那等於 `ProfessionsFrame.SetTab = 包裝函式`，在暴雪框上寫欄位（STYLE.md ⑦
--      的 ESC 選單那一條寫死了同一件事）。
--    ⚠ `TabSystemOwnerMixin` 是全遊戲共用的 ⇒ 後置勾裡只呼叫
--      `Engine.SyncTabSystemAll()`，而那一支第一行就查弱鍵表。
--
-- 2. **底部的專業等級進度條不是 `StatusBar`。**
--    `ProfessionsRankBarTemplate`（Blizzard_ProfessionsRankBar.xml:5）是一個
--    **Frame**：填充是一張 `Fill` 貼圖，被 `Professions-skillbar-mask`
--    這張 `MaskTexture` 遮住（同檔 :27-35），而且由一個 60 格的 `FlipBook`
--    動畫在跑（:94-96）。它沒有 `SetStatusBarTexture`、沒有 `GetStatusBarTexture`
--    ⇒ `Skin.StatusBar` 一行都套不上去。
--    中和外框那張 `Professions-skillbar-frame` 之後，剩下的是一條被不規則遮罩切過
--    的填充 —— 那比原樣難看。**所以整條不碰**，列進回報。
--
-- 3. **製作訂單頁的四顆範圍分頁（公開／公會／NPC／個人）同樣勾不到，而且連
--    「重讀」的路都沒有。** 它們是 XML 建的 `TabSystemButtonArtTemplate`，
--    唯一會改選中態的地方是
--    `ProfessionsCraftingOrderPageMixin:SetCraftingOrderType`
--    （Blizzard_ProfessionsCrafterOrderPage.lua:611-615）裡的
--    `typeTab:SetTabSelected(...)` —— 走的是**分頁 frame 自己那份副本**，
--    而 `SetCraftingOrderType` 本身是暴雪框的方法（勾它＝寫暴雪框的欄位）。
--    九張貼圖一中和，選中態就會凍在我們第一次讀到的那個值。
--    **所以這四顆一顆都不碰**，列進回報。
--
-- 4. **`SchematicForm` 的底不是「專業各自的美術」。** 它只有兩張貼圖
--    （`Background` / `MinimalBackground`，兩張在 XML 裡都是 `hidden="true"`，
--    由 `ProfessionsRecipeSchematicFormMixin` 依「是否最小化」擇一顯示）
--    ＋ 一個 `NineSlice`，`layoutType` 就是 `InsetFrameTemplate`。
--    也就是說它本來就是一塊標準內嵌框，不是羊皮紙那一類「文字顏色是針對它設計的」
--    內容底材 ⇒ 換成 `fillInset` **不需要接管任何文字顏色**（表單上的字本來就是
--    `GameFontHighlight` 系的白字與品質色）。
--
------------------------------------------------------------
-- ## 特許：通往受保護動作的按鈕
--
-- 製作、全部製作、下訂單／接單／完成訂單、套用專精變更都是需要硬體事件的路徑。
-- 這些按鈕照第五輪確認彈窗那條窄路處理：
--
--   * **零 `HookScript`**、**零 `hooksecurefunc`** 在它們或它們的 mixin 上。
--   * 滑過交還給引擎（Highlight 貼圖換成白 8%），**不呼叫 `Skin.Button`**
--     （它會經由 `Engine.TrackButtonHover` 掛 `OnEnter`/`OnLeave`）。
--   * 走本檔的 local `CommerceButton`，逐顆列在下面的接觸面清單。
--
-- 純導覽的按鈕（搜尋、返回、翻頁、最大化／最小化、篩選）維持一般原語。
--
------------------------------------------------------------
-- ## 伴隨元件（套組內建，掛在專業視窗上）
--
-- | 誰 | 掛在哪 | 怎麼處理 |
-- |---|---|---|
-- | 套組本體的「製作訂單獎勵欄」 | 用 `TableBuilder` 的 `AddUnsortableFixedWidthColumn` 在訂單瀏覽清單多加一個欄位 | **不碰**：它自己建 cell frame 與欄位表頭，我們對 `OrderList` 只中和 `Background`／`NineSlice` 兩張具名貼圖（**沒有** `NeutralizeRegions` 這種遞迴掃），所以它加的圖示與表頭都不會被藏掉 |
-- | 套組內建的採購清單插件 | 在 `CraftingPage.SchematicForm` 與顧客端下單頁上掛自己的按鈕（自己的子框，不寫暴雪欄位） | **不碰**：同上，我們只中和 `SchematicForm` 的 `Background`／`MinimalBackground`／`NineSlice` 三個具名 parentKey |
-- | 套組內建的另一支輔助插件 | 在專業視窗上顯示材料價格（讀取為主） | **不碰** |
--
-- ⚠ 這一份沒有 `companions`：上面三支都不是「用暴雪模板建的控件」，
--   它們有自己的長相，照伴隨元件規則第 1 條不在窄路的範圍內。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **專業等級進度條 `RankBar`**（配方頁與訂單檢視頁各一條）—— 理由見上面第 2 點。
-- * **製作訂單頁的四顆範圍分頁** —— 理由見上面第 3 點。
-- * **材料格（`ProfessionsReagentSlotBaseTemplate` 的 `Button`）與產出圖示
--   （`OutputIcon`／`ItemIcon`）** —— 兩個都是 `CircularGiantItemButtonTemplate`
--   系的**圓形**格子，而且身上還疊著 `CropFrame`（`Professions-ChoiceReagent-Frame`）、
--   `QualityOverlay`（品質星等）、`ColorOverlay`（配不配得出來）三層**都是值**的
--   資訊圖層。`Skin.ItemButton` 畫的是直角方框，套上去是「圓框外面一個方框」，
--   而要把那三層一起接管就不是「上一層皮」了。
-- * **專精頁的天賦樹本身**（`TreeView`／`DetailedView`／`ProfessionsSpecPathTemplate`
--   的整組 `SpecDial_*` 轉盤與它的六組動畫）—— 天賦樹在 STYLE.md ⑦ 是 C 級。
--   這一份只做那一頁的**底部按鈕列**。
-- * **裝備格（`ProfessionsGearSlotTemplate`）** —— 它走的是
--   `PaperDollItemSlotButton_*` 那一整套（XML 內嵌腳本），跟角色面板的裝備欄同源；
--   那一塊已經由 `Skins/Character.lua` 的 `Skin.ItemButton` ＋
--   `Engine.TrackItemButton` 的兩個全域後置勾接管，這裡不重複接。
-- * **`CraftingOutputLog`／`OverlayCastBarAnchor`／`DeclineOrderDialog`
--   ／`QualityDialog`** —— `frameStrata="DIALOG"` 的彈出視窗，判準離
--   StaticPopup 太近（STYLE.md ⑦ 的同一條）。
-- * **`ConcentrationDisplay`／`OrdersRemainingDisplay`／`UnspentPoints`** ——
--   那是「還剩多少」的數值顯示，底圖本身就是那個數值的容器美術。
-- * **`NoteBox`／`NoteEditBox` 的 `CraftingOrders-NoteFrameNarrow`** ——
--   那是「一張便條紙」的造型，換成方框就看不出它是顧客留言了。
-- * **`ProfessionsBookFrame`（專業書）** —— 第八輪補上了，住在
--   `Skins/ProfessionsBook.lua`（同一個 key `professions` 的 `parts`）。
--   第七輪「不做」的三條理由查證後有兩條是錯的（它繼承 `ButtonFrameTemplate`、
--   書頁上的字色一次 `SetTextColor` 就永久有效），完整說明寫在那一份的檔頭。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `ProfessionsFrame` 的 NineSlice／PortraitContainer／Bg／TopTileStreaks | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `TitleContainer.TitleText` | `SetTextColor` |
-- | 三顆頂部分頁的 `RotatedTextures`（九張） | `SetAlpha(0)` ＋ `SetNormalFontObject` |
-- | `CloseButton` 的 Normal／Disabled | `SetAlpha(0)`；Highlight／Pushed | `SetColorTexture` |
-- | `MaximizeMinimize` 兩顆的 Normal／Pushed／Disabled | `SetAlpha(0)`（`opts.glyph` ⇒ ＋／− 線條圖記） |
-- | `RecipeList` 的 `Background`／`BackgroundNineSlice`、`SchematicForm` 的 `Background`／`MinimalBackground`／`NineSlice`、`OrderList` 的 `Background`／`NineSlice`、`OrderInfo`／`OrderDetails` 的同兩張 | `SetAlpha(0)` |
-- | 配方分類列的 `LeftPiece`／`CenterPiece`／`RightPiece` | `SetAlpha(0)`；`Label` | `SetTextColor` |
-- | 配方列的 `SelectedOverlay`／`HighlightOverlay` | `SetAlpha(0)` |
-- | 訂單列的 `HighlightTexture` | `SetAlpha(0)` |
-- | 欄位表頭的 `Left`／`Right`／`Middle` | `SetAlpha(0)` |
-- | 搜尋框的 `Left`／`Right`／`Middle`、`searchIcon`、`Instructions` | `SetAlpha(0)` / `SetVertexColor` / `SetTextColor` |
-- | 篩選下拉的 `Background` | `SetAlpha(0)`；`Arrow` | `SetDesaturated` ＋ `SetVertexColor`；`Text` | `SetTextColor` ＋ 兩支 `HookScript` |
-- | 兩顆勾選框的四張狀態圖 | `SetAlpha(0)` / `SetColorTexture` / `SetDesaturated`（`Skin.CheckBox`） |
-- | 一般按鈕的 `Left`／`Right`／`Middle` | `SetAlpha(0)` ＋ `SetNormalFontObject` ＋ Highlight 中和 ＋ `HookScript("OnEnter"/"OnLeave")` |
-- | **特許按鈕**的 `Left`／`Right`／`Middle` | `SetAlpha(0)` ＋ `SetNormalFontObject` ＋ Highlight `SetColorTexture`。**零 HookScript** |
-- | 捲軸的 Track／Thumb／Back／Forward | `SetAlpha(0)` / `SetVertexColor` |
-- | 專精頁 `PanelFooter` 的那張無名底圖 | `SetAlpha(0)`（`Engine.NeutralizeRegions`） |
-- | 上面所有目標 | 以它們為 parent／anchor 建**我們自己的** overlay 框與貼圖 |
--
-- ### 掛了哪些 hook（這一輪新增）
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc(TabSystemOwnerMixin, "SetTab", …)` | 全域 mixin 後置勾 | 只呼叫 `Engine.SyncTabSystemAll()`（第一行查弱鍵表，不是我們接管的分頁立刻返回）。**不讀參數** |
-- | `hooksecurefunc(ProfessionsRecipeListCategoryMixin, "Init", …)` | mixin 後置勾（`Engine.HookRows`） | 中和三片式標題底、重申 `Label` 白字、畫我們的列底。**不讀 `node`** |
-- | `hooksecurefunc(ProfessionsRecipeListRecipeMixin, "Init", …)` | mixin 後置勾（`Engine.HookRows`） | 中和選中／滑過兩張 atlas、畫我們的列底。**不讀 `node`／`hideCraftableCount`** |
-- | `hooksecurefunc(ProfessionsRecipeListRecipeMixin, "SetSelected", …)` | mixin 後置勾（`requireKnown`） | 只把**參數**過 `Secret.ToBool` 之後餵進 `Engine.SetSelected` |
-- | `hooksecurefunc(ProfessionsCrafterOrderListElementMixin, "Init", …)` | mixin 後置勾（`Engine.HookRows`） | 只畫我們的列底（滑過那張留給暴雪）。**不讀 `elementData`** |
-- | `Engine.DropdownText` 的 `HookScript("OnEnable"/"OnDisable")` | frame script 後掛 | 只對兩顆篩選下拉，內容只有 `SetTextColor` |
-- | `Engine.TrackButtonHover`／`TrackSelectable` 的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | 只對**一般**按鈕與清單列；內容只有換我們自己 overlay 的底色與邊色 |
--
-- **`hooksecurefunc` 在 `ProfessionsFrame` 或它任何子框上：0 支。**
-- **在特許按鈕上的 `HookScript`：0 支。**
-- **`hooksecurefunc` 在任何 `C_TradeSkillUI` / `C_CraftingOrders` 函式上：0 支。**
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L
local S = ns.Secret

------------------------------------------------------------
-- 專業書（`ProfessionsBookFrame`）住在 `Skins/ProfessionsBook.lua`，走這份配方的
-- `parts`、共用 `professions` 這一個設定開關（STYLE.md ⑥ 第 5 步：玩家看到的是
-- 一個功能）。交接表的形狀跟 `ns.PVESkin` 一樣。
--
-- ⚠ 這兩個 stub 是為了「TOC 少載一支、或那一份在本機被停掉」的情況：
--   `Engine.Register` 的 `parts` 會照樣跑，但兩支什麼都不做。
--   `hooks` 排在戰鬥閘**前面**（陷阱 4），所以分成兩支交接。
------------------------------------------------------------
ns.ProfessionsSkin = ns.ProfessionsSkin or {}
ns.ProfessionsSkin.HookBook = ns.ProfessionsSkin.HookBook or function() end
ns.ProfessionsSkin.ApplyBook = ns.ProfessionsSkin.ApplyBook or function() end

------------------------------------------------------------
-- 特許：通往受保護動作的按鈕
--
-- 跟 `Skins/AuctionHouse.lua` 的 `CommerceButton` 是同一支（同一條特許）。
-- TODO(升格): 第三個視窗也需要時，把它升格成 `Skin.Button` 的 `opts.noHover`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function CommerceButton(btn, key)
    if not E.Usable(btn, key) then return nil end

    -- ⚠ 先建 overlay 再中和：`Engine.Overlay` 對顯式保護框會回 nil，
    --   倒過來寫的話「製作」會變成一顆隱形按鈕。
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end

    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonStates(btn, key)          -- Highlight → 白 8%，**不掛腳本**
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.Paint(ov, T.fill, T.border)
    return ov
end

local function Sub(owner, key, label)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then
        return child
    end
    E.Missing(label)
    return nil
end

local function WithSub(owner, key, label, fn)
    local child = Sub(owner, key, label)
    if child then fn(child, label) end
    return child
end

-- 一組「有就做、沒有就靜默跳過」的按鈕（暴雪依情境隱藏的那幾顆）
local function OptionalButtons(owner, names, prefix, fn)
    for _, name in ipairs(names) do
        local btn
        if pcall(function() btn = owner[name] end) and btn then
            fn(btn, prefix .. "." .. name)
        end
    end
end

------------------------------------------------------------
-- 一塊「底圖 ＋ NineSlice」的內容面板
--
-- 專業視窗裡的面板有三種 parentKey 組合（配方清單是 `Background`
-- ＋ `BackgroundNineSlice`，其餘是 `Background`／`MinimalBackground`
-- ＋ `NineSlice`），一次全點名比為每一塊各寫一行便宜。
--
-- ⚠ **只點名具名的那幾張，不做 `NeutralizeRegions` 遞迴掃** ——
--   套組內建的插件在這幾塊面板上掛了自己的欄位與按鈕，遞迴掃會把它們一起藏掉。
------------------------------------------------------------
local PANEL_ART = { "Background", "MinimalBackground", "NineSlice", "BackgroundNineSlice" }

local function SkinContentPanel(frame, key, fill)
    if not E.Usable(frame, key) then return nil end
    E.NeutralizeKeys(frame, PANEL_ART, key)
    local ov = E.RegionBackdrop(frame, { key = key })
    E.Paint(ov, fill or T.fillInset, T.border)
    return ov
end

------------------------------------------------------------
-- 配方清單（配方頁與製作訂單頁共用同一個模板）
------------------------------------------------------------
local function SkinRecipeList(list, key)
    if not E.Usable(list, key) then return end
    SkinContentPanel(list, key)
    WithSub(list, "SearchBox", key .. ".SearchBox", function(box, label)
        Skin.EditBox(box, label)
    end)
    WithSub(list, "FilterDropdown", key .. ".FilterDropdown", function(dd, label)
        Skin.Dropdown(dd, label, "filter")
    end)
    WithSub(list, "ScrollBar", key .. ".ScrollBar", function(bar, label)
        Skin.ScrollBar(bar, label)
    end)
end

------------------------------------------------------------
-- 池化列
--
-- 三種列，三支 mixin 後置勾，全部放進 `Engine.Register` 的 `hooks`
-- （戰鬥閘前面 —— 晚裝就漏掉先建好的列，陷阱 4）。
------------------------------------------------------------

-- 分類標題列：三片式標題底中和，換成一條 `fillInset` 的列底。
-- `CollapseIcon`（展開／收合的箭頭）與 `RankBar`（那一類的學習進度）都是**值**，
-- 一根手指都不碰。
local CATEGORY_ART = { "LeftPiece", "CenterPiece", "RightPiece" }

local function ApplyCategoryRow(row)
    Skin.Row(row, "ProfessionsRecipeListCategory", {
        fill = T.fillInset,
        keys = CATEGORY_ART,
    })
end

local function ReapplyCategoryRow(row)
    -- `Init` 每次重用都重設標題文字；顏色本身暴雪沒有重設，但重申一次最便宜
    local label
    if pcall(function() label = row.Label end) and label then
        E.TextColor(label, T.text, "ProfessionsRecipeListCategory.Label")
    end
    E.NeutralizeKeys(row, CATEGORY_ART, "ProfessionsRecipeListCategory")
end

-- 配方列：`SelectedOverlay` 與 `HighlightOverlay` 是暴雪畫選中／滑過的兩張 atlas
-- （`SetSelected` 對它們 `SetShown(selected)` / `SetShown(not selected)`）。
-- 兩張一起中和、兩態都由 `Engine.TrackSelectable` 畫在同一個矩形上
-- —— 跟好友名單那三種列同一條退路（STYLE.md ④「選中與滑過是同一張貼圖的列」）。
--
-- `Label` / `Count` 的顏色**不碰**：`SetLabelFontColors(GetLabelColor())` 在
-- 「學會了」與「還沒學」之間切（Blizzard_ProfessionsRecipeList.lua:232,346），
-- 那是資訊不是裝飾。
local RECIPE_ART = { "SelectedOverlay", "HighlightOverlay" }

local function ApplyRecipeRow(row)
    Skin.Row(row, "ProfessionsRecipeListRecipe", {
        fill     = T.fill,
        keys     = RECIPE_ART,
        ownHover = true,
    })
end

local function SelectRecipeRow(row, selected)
    -- ⚠ `selected` 是**後置勾的參數**，不是 elementData 的欄位；
    --   一律過 `Secret.ToBool`，問不到就畫成閒置（失敗方向安全）。
    E.SetSelected(row, S.ToBool(selected) == true)
end

-- 製作訂單瀏覽列：只畫一層列底。
--
-- ⚠ `HighlightTexture` **不中和**：它是 parentKey 的一張 OVERLAY 貼圖
--   （Blizzard_ProfessionsCrafterOrderPage.xml:35），不是 `GetHighlightTexture()`
--   拿得到的狀態貼圖 ⇒ 引擎沒有東西可以換，而暴雪是在
--   `OnLineEnter`／`OnLineLeave` 裡 Show/Hide 它的。中和掉等於把滑過回饋整個拿走，
--   而它本來就是中性的白色 ADD 疊加，留著正好是「狀態只換明暗」。
-- ⚠ 選中態沒有對應的方法可勾（這個 mixin 沒有 `SetSelected`），所以不自己畫。
local function ApplyOrderRow(row)
    Skin.Row(row, "ProfessionsCrafterOrderListElement", { fill = T.fillInset })
end

local function InstallHooks()
    -- 第一條同步路徑（註 ⓘ）：`TabSystemButtonArtMixin:SetTabSelected` 的 mixin
    -- 後置勾。對**現有**那三顆沒用（它們在 XML 載入期就建好了），裝著是為了
    -- 「之後才生出來的分頁」。冪等。
    E.TabSystemHooks()

    -- 頂部三顆分頁的第二條同步路徑（見檔頭第 1 點）。
    -- ⚠ 勾的是**全域 mixin 表**，不是 `ProfessionsFrame` 這個暴雪框。
    if type(_G.TabSystemOwnerMixin) == "table"
        and type(_G.TabSystemOwnerMixin.SetTab) == "function" then
        hooksecurefunc(_G.TabSystemOwnerMixin, "SetTab", function()
            E.SyncTabSystemAll()
        end)
    else
        E.Missing("TabSystemOwnerMixin:SetTab")
    end

    E.HookRows{
        key     = "ProfessionsRecipeListCategory",
        mixin   = _G.ProfessionsRecipeListCategoryMixin,
        method  = "Init",
        apply   = ApplyCategoryRow,
        reapply = ReapplyCategoryRow,
    }

    E.HookRows{
        key    = "ProfessionsRecipeListRecipe",
        mixin  = _G.ProfessionsRecipeListRecipeMixin,
        method = "Init",
        apply  = ApplyRecipeRow,
    }
    E.HookRows{
        key          = "ProfessionsRecipeListRecipe.SetSelected",
        mixin        = _G.ProfessionsRecipeListRecipeMixin,
        method       = "SetSelected",
        requireKnown = true,
        reapply      = SelectRecipeRow,
    }

    E.HookRows{
        key    = "ProfessionsCrafterOrderListElement",
        mixin  = _G.ProfessionsCrafterOrderListElementMixin,
        method = "Init",
        apply  = ApplyOrderRow,
    }
end

------------------------------------------------------------
-- (b) 配方頁
------------------------------------------------------------
local CRAFTING_NAV_BUTTONS = { "ViewGuildCraftersButton" }
-- **特許**：製作／全部製作
local CRAFTING_COMMERCE_BUTTONS = { "CreateButton", "CreateAllButton" }

local function SkinCraftingPage(page, key)
    if not E.Usable(page, key) then return end

    WithSub(page, "RecipeList", key .. ".RecipeList", SkinRecipeList)

    WithSub(page, "SchematicForm", key .. ".SchematicForm", function(form, fkey)
        SkinContentPanel(form, fkey)
        -- 兩顆勾選框（追蹤配方／自動配最高品質）
        for _, name in ipairs({ "TrackRecipeCheckbox", "AllocateBestQualityCheckbox" }) do
            local cb
            if pcall(function() cb = form[name] end) and cb then
                Skin.CheckBox(cb, fkey .. "." .. name)
            end
        end
        -- 配方等級下拉（只有可選等級的配方才有）
        local dd
        if pcall(function() dd = form.RecipeLevelDropdown end) and dd then
            Skin.Dropdown(dd, fkey .. ".RecipeLevelDropdown", "style1")
        end
    end)

    -- 數量輸入框（`NumericInputSpinnerTemplate` ← `InputBoxTemplate`
    -- ⇒ `Left`/`Right`/`Middle` parentKey，`Skin.EditBox` 直接適用）
    WithSub(page, "CreateMultipleInputBox", key .. ".CreateMultipleInputBox", function(box, label)
        Skin.EditBox(box, label)
    end)

    OptionalButtons(page, CRAFTING_NAV_BUTTONS, key, function(btn, label)
        Skin.Button(btn, label)
    end)
    OptionalButtons(page, CRAFTING_COMMERCE_BUTTONS, key, CommerceButton)

    -- 最小化狀態下的搜尋框
    local box
    if pcall(function() box = page.MinimizedSearchBox end) and box then
        Skin.EditBox(box, key .. ".MinimizedSearchBox")
    end
end

------------------------------------------------------------
-- (c) 製作訂單頁
--
-- ⚠ 訂單清單只做**框級**：面板底、欄位表頭那條帶、捲軸。
--   列本身走上面那支 mixin 後置勾（只有滑過帶，沒有選中態）。
-- ⚠ 「下訂單／接單／完成訂單」相關的面板只做外框，按鈕走特許。
------------------------------------------------------------
-- **特許**：接單／婉拒／釋出／製作／完成訂單／重新製作
local ORDER_COMMERCE_BUTTONS = {
    "StartOrderButton", "DeclineOrderButton", "ReleaseOrderButton",
    "CreateButton", "CompleteOrderButton", "StartRecraftButton", "StopRecraftButton",
}

local function SkinOrderList(list, key)
    if not E.Usable(list, key) then return end
    SkinContentPanel(list, key)

    -- 欄位表頭：照 `HeaderContainer` 自己的矩形畫一條 `fillInset` 帶，不量測。
    -- parent 明確指定成清單本身 —— `HeaderContainer` 是表格引擎往裡面塞表頭框的
    -- 容器（陷阱 2 的同一條理由）。
    local header
    if pcall(function() header = list.HeaderContainer end) and header then
        local ov = E.Overlay(header, {
            key = key .. ".HeaderContainer",
            parent = list,
            noBorder = true,
        })
        E.Paint(ov, T.fillInset)
    end

    WithSub(list, "ScrollBar", key .. ".ScrollBar", function(bar, label)
        Skin.ScrollBar(bar, label)
    end)
end

local function SkinOrdersPage(page, key)
    if not E.Usable(page, key) then return end

    WithSub(page, "BrowseFrame", key .. ".BrowseFrame", function(browse, bkey)
        WithSub(browse, "RecipeList", bkey .. ".RecipeList", SkinRecipeList)
        WithSub(browse, "OrderList", bkey .. ".OrderList", SkinOrderList)
        WithSub(browse, "SearchButton", bkey .. ".SearchButton", function(btn, label)
            Skin.Button(btn, label)
        end)
        WithSub(browse, "FavoritesSearchButton", bkey .. ".FavoritesSearchButton",
            function(btn, label) Skin.SquareIconButton(btn, label) end)
        -- 翻頁鈕：圖就是 Normal/Pushed/Disabled 三張箭頭 ⇒ 預設的 `Skin.IconButton`
        WithSub(browse, "BackButton", bkey .. ".BackButton", function(btn, label)
            Skin.IconButton(btn, label, { inset = 4 })
        end)
    end)

    WithSub(page, "OrderView", key .. ".OrderView", function(view, vkey)
        for _, name in ipairs({ "OrderInfo", "OrderDetails" }) do
            local panel
            if pcall(function() panel = view[name] end) and panel then
                SkinContentPanel(panel, vkey .. "." .. name)
            end
        end
        WithSub(view, "SchematicForm", vkey .. ".SchematicForm", function(form, fkey)
            SkinContentPanel(form, fkey)
        end)
        local back
        if pcall(function() back = view.OrderInfo and view.OrderInfo.BackButton end) and back then
            Skin.Button(back, vkey .. ".OrderInfo.BackButton")
        end
        local social
        if pcall(function() social = view.OrderInfo and view.OrderInfo.SocialDropdown end)
            and social then
            Skin.StretchButton(social, vkey .. ".OrderInfo.SocialDropdown")
        end
        -- 按鈕散在 `OrderInfo` 與 `OrderView` 兩層，兩層都掃一遍（有就做）
        OptionalButtons(view, ORDER_COMMERCE_BUTTONS, vkey, CommerceButton)
        if type(view.OrderInfo) == "table" then
            OptionalButtons(view.OrderInfo, ORDER_COMMERCE_BUTTONS, vkey .. ".OrderInfo",
                CommerceButton)
        end
    end)
end

------------------------------------------------------------
-- (d) 專精頁 —— 只做外框與底部按鈕列
--
-- 天賦樹本身是 C 級（STYLE.md ⑦），這裡只把底部那條 footer 的木紋底換掉，
-- 讓按鈕列跟視窗其他地方是同一個語彙。
------------------------------------------------------------
-- **特許**：套用專精變更（`ApplyButton`）與撤銷（`UndoButton`）
local SPEC_COMMERCE_BUTTONS = { "ApplyButton" }
local SPEC_NAV_BUTTONS = {
    "UnlockTabButton", "ViewTreeButton", "BackToPreviewButton",
    "ViewPreviewButton", "BackToFullTreeButton",
}

local function SkinSpecPage(page, key)
    if not E.Usable(page, key) then return end

    WithSub(page, "PanelFooter", key .. ".PanelFooter", function(footer, fkey)
        -- 那張 `Professions-Specializations-Background-Footer` 是**無名無 parentKey**
        -- 的（Blizzard_ProfessionsSpecializations.xml:26-31）⇒ 只剩 GetRegions 一條路。
        E.NeutralizeRegions(footer, fkey)
        local ov = E.RegionBackdrop(footer, { key = fkey })
        E.Paint(ov, T.fillInset, T.border)
    end)

    OptionalButtons(page, SPEC_COMMERCE_BUTTONS, key, CommerceButton)
    OptionalButtons(page, SPEC_NAV_BUTTONS, key, function(btn, label)
        Skin.Button(btn, label)
    end)
    -- 撤銷鈕是 `IconButtonTemplate`（殼 ＋ `Icon`）⇒ `Skin.SquareIconButton`。
    -- 它跟「套用」同一條路（都改變未提交的專精點數），所以**不給職業色滑過**——
    -- 但 `Skin.SquareIconButton` 會掛 hover 腳本 ⇒ 這裡也走特許的處理方式：
    -- 整組狀態圖中和、圖染成次要色、底交給引擎。
    local undo
    if pcall(function() undo = page.UndoButton end) and undo then
        local ukey = key .. ".UndoButton"
        local ov = E.Overlay(undo, { key = ukey })
        if ov then
            -- `IconButtonTemplate` ← `UIButtonTemplate`：殼是 Normal/Pushed/Disabled
            -- 三張狀態貼圖（不是 Left/Right/Middle 切片），真正的圖在 `Icon`
            -- （Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml:4,23-）。
            for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
                if type(undo[getter]) == "function" then
                    local ok, tex = pcall(undo[getter], undo)
                    if ok and tex then E.Neutralize(tex, ukey .. "." .. getter) end
                end
            end
            E.ButtonStates(undo, ukey)
            local icon
            if pcall(function() icon = undo.Icon end) and icon then
                E.VertexColor(icon, T.textDim, ukey .. ".Icon")
            end
            E.Paint(ov, T.fill, T.border)
        end
    end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local MAXMIN_GLYPH = { MaximizeButton = "expand", MinimizeButton = "collapse" }

local function Apply()
    local f = _G.ProfessionsFrame
    if not f then
        E.Missing("ProfessionsFrame")
        return
    end

    Skin.PortraitChrome(f, "ProfessionsFrame")
    Skin.Panel(f, "ProfessionsFrame")

    WithSub(f, "CloseButton", "ProfessionsFrame.CloseButton", function(btn, label)
        Skin.CloseButton(btn, label)
    end)

    WithSub(f, "MaximizeMinimize", "ProfessionsFrame.MaximizeMinimize", function(frame, key)
        for name, glyph in pairs(MAXMIN_GLYPH) do
            local btn
            if pcall(function() btn = frame[name] end) and btn then
                Skin.IconButton(btn, key .. "." .. name, { glyph = glyph })
            else
                E.Missing(key .. "." .. name)
            end
        end
    end)

    -- 頂部分頁：`TabSystemTemplate`，錨在視窗**下方**
    -- （Blizzard_ProfessionsFrame.xml:24 `TOPLEFT → $parent BOTTOMLEFT`）
    -- ⇒ 分頁在內容下方、相連的是**上邊** ⇒ `onTop = false`（預設）。
    WithSub(f, "TabSystem", "ProfessionsFrame.TabSystem", function(tabSystem, key)
        Skin.TabSystemAll(tabSystem, key)
        -- 建立時讀一次，之後由 `TabSystemOwnerMixin:SetTab` 的後置勾重讀
        E.SyncTabSystemAll()
    end)

    WithSub(f, "CraftingPage", "ProfessionsFrame.CraftingPage", SkinCraftingPage)
    WithSub(f, "OrdersPage", "ProfessionsFrame.OrdersPage", SkinOrdersPage)
    WithSub(f, "SpecPage", "ProfessionsFrame.SpecPage", SkinSpecPage)
end

E.Register{
    key   = "professions",
    addon = "Blizzard_Professions",
    title = L["Professions"],
    hooks = InstallHooks,
    apply = Apply,
    parts = {
        -- 專業技能書（按 K 開的那一本）。隨需載入的是**另一支**暴雪插件，
        -- 所以 `addon` 要各自寫一條。
        {
            addon = "Blizzard_ProfessionsBook",
            hooks = function() ns.ProfessionsSkin.HookBook() end,
            apply = function() ns.ProfessionsSkin.ApplyBook() end,
        },
    },
}
