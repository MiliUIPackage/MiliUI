------------------------------------------------------------
-- 配方：拍賣場（`AuctionHouseFrame`，隨需載入 `Blizzard_AuctionHouseUI`）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.xml:4
--     `AuctionHouseFrame`（← `PortraitFrameTemplate`，toplevel）
--   同檔 :11,17,23   `MoneyFrameInset`（InsetFrameTemplate，useParentLevel）／
--                    `MoneyFrameBorder`（**ThinGoldEdgeTemplate**，底下掛
--                    `MoneyFrame` ＋ 一張**無名**的 `UI-Frame` 端帽，:30-38）
--   同檔 :44,52,60   `BuyTab` / `SellTab` / `AuctionsTab`
--                    （`AuctionHouseFrameDisplayModeTabTemplate`）
--   同檔 :71,76,82,89    `SearchBar` / `CategoriesList` / `BrowseResultsFrame` /
--                        `WoWTokenResults`
--   同檔 :99,107     `CommoditiesBuyFrame` / `ItemBuyFrame`
--   同檔 :118,126,141,147,154
--                    `ItemSellFrame` / `ItemSellList` / `CommoditiesSellFrame` /
--                    `CommoditiesSellList` / `WoWTokenSellFrame`
--   同檔 :163,174,181    `AuctionsFrame` / `DialogOverlay` / `BuyDialog`
--   Mainline/Blizzard_AuctionHouseTab.xml:4,11,20
--     `AuctionHouseFrameTabTemplate` ← **`PanelTabButtonTemplate`**、
--     `AuctionHouseFrameTopTabTemplate` ← **`PanelTopTabButtonTemplate`**、
--     `AuctionHouseFrameDisplayModeTabTemplate` ← 前者
--   Shared/Blizzard_AuctionHouseSearchBar.xml:5,13,29,52,65
--     `AuctionHouseSearchBoxTemplate`（← SearchBoxTemplate）／
--     `AuctionHouseFavoritesSearchButtonTemplate`（← **SquareIconButtonTemplate**）／
--     `AuctionHouseFilterButtonTemplate`（← **WowStyle1FilterDropdownTemplate**
--      ＋ `ClearFiltersButton`，:31-39）／
--     `AuctionHouseSearchButtonTemplate`（← UIPanelButtonTemplate）／
--     `AuctionHouseSearchBarTemplate`（`FavoritesSearchButton`／`SearchBox`／
--      `SearchButton`／`FilterButton`）
--   Mainline/Blizzard_AuctionHouseCategoriesList.xml:4,62
--     `AuctionCategoryButtonTemplate`（`Lines`／`NormalTexture`／`HighlightTexture`／
--      `SelectedTexture`，四張都是 **parentKey 的一般貼圖**，不是 getter 拿得到的
--      狀態貼圖）／`AuctionHouseCategoriesListTemplate`（`Background`＋`NineSlice`
--      ＋`ScrollBox`＋`ScrollBar`）
--   Mainline/Blizzard_AuctionHouseCategoriesList.lua:1,13-65
--     **全域** `AuctionHouseFilterButton_SetUp(button, info)` —— 三種 type 各自
--     `SetAtlas` ＋ `normalTexture:SetAlpha(1.0 / 0.0)`，最後
--     `SelectedTexture:SetShown(info.selected)`（:77）
--   Shared/Blizzard_AuctionHouseCategoriesList.lua:87 `SetElementInitializer` ——
--     初始化器是**匿名 closure**，勾不到；上面那支全域才是共同出口
--   Shared/Blizzard_AuctionHouseSharedTemplates.xml:3,34,53,89,97,127,150,165
--     `AuctionHouseBackgroundTemplate`（`Background` 貼圖 ＋ `NineSlice`，
--      layoutType = InsetFrameTemplate）／`AuctionHouseItemDisplayBaseTemplate`／
--     `AuctionHouseInteractableItemDisplayTemplate`（`ItemButton` ←
--      **GiantItemButtonTemplate**）／`AuctionHouseQuantityInputEditBoxTemplate`
--      （← **LargeInputBoxTemplate**）／`AuctionHouseRefreshFrameTemplate`
--      （`RefreshButton` ← **RefreshButtonTemplate** ← SquareIconButtonTemplate）／
--     `AuctionHouseBidFrameTemplate`（`BidAmount` ← **MoneyInputFrameTemplate**
--      ＋ `BidButton`）／`AuctionHouseBuyoutFrameTemplate`（`BuyoutButton`）／
--     `AuctionHouseFavoriteButtonBaseTemplate`
--   Mainline/Blizzard_AuctionHouseSharedTemplates.xml:3
--     `AuctionHouseItemDisplayTemplate`（`ItemButton` ← **CircularGiantItemButtonTemplate**
--      ＋ `FavoriteButton` ＋ `Name`）
--   Mainline/Blizzard_AuctionHouseItemList.xml:4,28,32
--     `AuctionHouseItemListLineTemplate`（`SelectedHighlight`／`HighlightTexture`
--      ＋ NormalTexture `auctionhouse-rowstripe-1`）／
--     `AuctionHouseItemListHeadersTemplate`／`AuctionHouseItemListTemplate`
--      （← AuctionHouseBackgroundTemplate；`RefreshFrame`／`HeaderContainer`／
--       `ScrollBox`／`ScrollBar`／`LoadingSpinner`／`ResultsText`）
--   Shared/Blizzard_AuctionHouseItemList.lua:141-152
--     `SetElementFactory` 的初始化器同樣是**匿名 closure**
--   Shared/Blizzard_AuctionHouseTableBuilder.xml:203
--     `AuctionHouseTableHeaderStringTemplate` ← **`ColumnDisplayButtonShortTemplate`**
--     ＋ `Arrow`（atlas auctionhouse-ui-sortarrow）
--   Shared/Blizzard_AuctionHouseTableBuilder.lua:877,884
--     `AuctionHouseTableHeaderStringMixin:Init(owner, headerText, sortOrder)`
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1142
--     `ColumnDisplayButtonShortTemplate`（`Left`／`Right`／`Middle`
--      ＋ HighlightTexture ＋ NormalFont `GameFontHighlightSmall`）
--   同檔 :1294 `RefreshButtonTemplate`、:1314 `ThinGoldEdgeTemplate`
--     （三張切片只有 `$parentLeft/Middle/Right` 全域名字，而 `MoneyFrameBorder`
--      本身**沒有名字** ⇒ 那三張連全域名字都沒有，只剩 `GetRegions` 一條路）
--   Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:13
--     `LargeInputBoxTemplate`（`Left`／`Right`／`Middle` parentKey）
--   Blizzard_MoneyFrame/Shared/MoneyInputFrame.xml:3,33
--     `LargeMoneyInputBoxTemplate`（← LargeInputBoxTemplate ＋ `Icon`／`Text`）／
--     `LargeMoneyInputFrameTemplate`（`GoldBox`／`SilverBox`／`CopperBox`，**大寫**）
--   Shared/Blizzard_AuctionHouseSellFrame.xml:4,51,74,124,138,163
--     `AuctionHouseSellFrameAlignedControlTemplate`（`Label`／`LabelTitle`／`Subtext`）／
--     `AuctionHouseAlignedQuantityInputFrameTemplate`（`InputBox`／`MaxButton`）／
--     `AuctionHouseAlignedPriceInputFrameTemplate`（`MoneyInputFrame` ←
--      **LargeMoneyInputFrameTemplate** ＋ `PriceError`）／
--     `AuctionHouseAlignedDurationTemplate`（`Dropdown` ← WowStyle1DropdownTemplate）／
--     `AuctionHouseAlignedPriceDisplayTemplate`（`MoneyDisplayFrame`）／
--     `AuctionHouseSellFrameTemplate`（← **VerticalLayoutFrame** ＋
--      AuctionHouseBackgroundTemplate；`CreateAuctionTabLeft/Middle/Right`
--      ＋ `CreateAuctionLabel` ＋ `Overlay` ＋ `ItemDisplay` ＋ `QuantityInput`
--      ＋ `PriceInput` ＋ `Duration` ＋ `Deposit` ＋ `TotalPrice` ＋ `PostButton`）
--   Shared/Blizzard_AuctionHouseItemSellFrame.xml:4
--     `BuyoutModeCheckButton`（← UICheckButtonTemplate，36x36）／`SecondaryPriceInput`／
--     `DisabledOverlay`
--   Shared/Blizzard_AuctionHouseItemBuyFrame.xml:4
--     `BackButton`／`ItemDisplay`／`BuyoutFrame`／`BidFrame`／`ItemList`
--   Shared/Blizzard_AuctionHouseCommoditiesBuyFrame.xml:4,80
--     `AuctionHouseCommoditiesBuyDisplayTemplate`（← **VerticalLayoutFrame**；
--      `ItemDisplay`／`QuantityInput`／`UnitPrice`／`TotalPrice`／`BuyButton`）／
--     `AuctionHouseCommoditiesBuyFrameTemplate`（`BackButton`／`BuyDisplay`／`ItemList`）
--   Mainline/Blizzard_AuctionHouseAuctionsFrame.xml:4,10,54
--     `AuctionHouseAuctionsFrameTabTemplate` ← AuctionHouseFrameTopTabTemplate／
--     `AuctionHouseAuctionsSummaryLineTemplate`／
--     `AuctionHouseAuctionsFrameTemplate`（`AuctionsTab`／`BidsTab`／
--      `CancelAuctionButton`／`BuyoutFrame`／`BidFrame`／`SummaryList`／`ItemDisplay`／
--      `AllAuctionsList`／`BidsList`／`ItemList`／`CommoditiesList`）
--   Shared/Blizzard_AuctionHouseBuyDialog.xml:41,54-94
--     `AuctionHouseDialogButtonTemplate`（← UIPanelButtonTemplate）／
--     `BuyDialog` 的 `Border`（DialogBorderDarkTemplate）／`ItemDisplay`／
--     `PriceFrame`／`BuyNowButton`／`CancelButton`／`OkayButton`／`Notification`
--
------------------------------------------------------------
-- ## 特許：通往受保護動作的按鈕
--
-- 拍賣場的「出價／直購／建立拍賣／取消拍賣」都是需要硬體事件的路徑。這一份配方
-- 因此照第五輪確認彈窗與 ESC 選單的那條**窄路**處理那幾顆按鈕：
--
--   * **零 `HookScript`**、**零 `hooksecurefunc` 在任何 `C_AuctionHouse.*` 或
--     那幾顆按鈕的 mixin 上**。滑過一律交給引擎換 Highlight 貼圖的長相
--     （`Engine.ButtonStates` ⇒ 白 8%），不是 `Engine.TrackButtonHover` 的
--     職業色邊（那一支會掛 `OnEnter`/`OnLeave`）。
--   * 所以它們走本檔的 local `CommerceButton`，**不呼叫 `Skin.Button`**。
--   * 純導覽的按鈕（搜尋、返回、最大數量、重新整理、分頁）維持一般原語。
--
-- 被歸類為「通往受保護動作」的按鈕，逐顆列在下面的接觸面清單裡。
--
------------------------------------------------------------
-- ## 結果清單的「列」為什麼一顆都不碰
--
-- 兩條理由疊在一起，任何一條單獨都夠：
--
-- 1. **那條列就是出價／直購的執行流。** 選一列 → `BidFrame`／`BuyoutFrame`
--    → `C_AuctionHouse.PlaceBid`。第七輪的穩定性規則 (b)：跟受保護請求同一條
--    執行流的清單列只做外框（已知的先例是兌換通貨列）。
-- 2. **沒有勾得到的每列出口。** `AuctionHouseItemListMixin:Init`
--    （Shared/Blizzard_AuctionHouseItemList.lua:141-152）把初始化器寫成
--    `SetElementFactory` 裡的**匿名 local closure**，`AuctionHouseItemListLineMixin`
--    （同檔 :10）只有 `OnClick`／`OnLineEnter`／`OnLineLeave`／`GetRowData`，
--    沒有任何「每次重用都會跑」的具名方法。唯一每列都會經過的具名出口是
--    `TableBuilderMixin:AddRow`（Blizzard_SharedXML/TableBuilder.lua:323）——
--    那是**全遊戲**共用的表格引擎，公會名冊、預組隊伍都會進來，
--    而 `Engine.HookRows` 的 `apply` 沒有辦法在進來的那一刻分辨是誰的列。
--
-- ⇒ 清單只做「框級」：面板底、欄位表頭那條帶、捲軸、重新整理鈕。
--   列的斑馬紋、選中帶、滑過帶全部留給暴雪。
--
-- 同一條理由也適用 `AuctionsFrame.SummaryList` 的池化列
-- （`AuctionHouseAuctionsSummaryLineTemplate` 沒有 initializer 可勾）。
--
------------------------------------------------------------
-- ## 左側分類清單為什麼可以做
--
-- 它的共同出口是**全域函式** `AuctionHouseFilterButton_SetUp`
-- （Mainline/Blizzard_AuctionHouseCategoriesList.lua:1），而且它只改搜尋條件、
-- 不在任何受保護請求的執行流上。所以走 `Engine.HookRows{ mixin = _G }`。
--
-- 選中態與滑過態**不自己畫**：那四張都是 parentKey 的一般貼圖
-- （不是 getter 拿得到的狀態貼圖），顯示與否完全由暴雪決定
-- （`SelectedTexture:SetShown(info.selected)` 是那支的最後一行）。
-- 我們只對它們用白名單裡的 `SetDesaturated` ＋ `SetVertexColor`：
--   * 去飽和是必要的 —— 那幾張 atlas 本身是金棕色的，`SetVertexColor` 是乘法，
--     乘不出職業色（同 `Engine.Desaturate` 那一段的紅金 ＋／− 鈕）。
--   * `SetDesaturated` 與 `SetVertexColor` 跟 `SetAtlas` 是互相獨立的屬性
--     ⇒ 那支每次重用都重設 atlas 也洗不掉，**一次就撐得住**。
-- 這樣「哪一列選中」仍然完全是暴雪說了算，我們零讀取、零狀態。
--
------------------------------------------------------------
-- ## 伴隨元件（套組內建，掛在拍賣場上）
--
-- | 全域名稱 | 是什麼 | 怎麼處理 |
-- |---|---|---|
-- | `AuctionatorTabs_Shopping` / `_Selling` / `_Cancelling` / `_Auctionator` | 套組內建的拍賣插件加在底部的四顆分頁，用的是**暴雪同一個** `AuctionHouseFrameDisplayModeTabTemplate` ⇒ 不處理的話一排分頁會有兩種長相 | 名字登記在 `ThirdParty/Auctionator.lua`，下面 `SkinTabRow` 用 `Engine.CompanionTabs` 取出來，跟暴雪那三顆**同一次**交給 `Skin.TabGroup` |
-- | `YUI_AuctionHelperFrame` | 另一支套組內建插件的**獨立側邊面板**（錨在拍賣場右外側，自己有一整套主題系統） | 不碰，見下面「刻意不碰」 |
-- | `MiliUI_AHFilterBtn` | 套組本體加在視窗右上外側的「僅限當前資料片」開關 | 不碰，見下面「刻意不碰」 |
--
-- ⚠ 分頁那一排**整排都在伴隨元件的那一輪才畫**（`AUCTION_HOUSE_SHOW` ＋ 延一幀）。
--   理由是 `Skin.TabGroup` 的接縫是「這一顆的右緣錨在下一顆的左緣」，錨點只在
--   overlay **建立時**定一次 ⇒ 先畫暴雪那三顆、之後再補伴隨的四顆，第三顆會停在
--   「我是最後一顆」的幾何上。等整排都在了再一次畫完，接縫才會對。
--   拍賣場只有在跟拍賣商交談時才開得起來，`AUCTION_HOUSE_SHOW` 一定先到。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **所有結果清單的「列」**（`AuctionHouseItemListLineTemplate`、
--   `AuctionHouseAuctionsSummaryLineTemplate`）—— 理由見上面。
-- * **`ItemDisplay` 的 `ItemButton`** —— `CircularGiantItemButtonTemplate`，
--   那一圈品質框是**圓形**的。`Skin.ItemButton` 畫的是直角方框，套上去會變成
--   「圓框外面再一個方框」。要做是另外一支「圓形物品格」原語。
-- * **`FavoriteButton`（星號）／`ClearFiltersButton`（紅 ×）／`PriceError`（驚嘆號）**
--   —— 三顆都是「一張圖就是全部語意」的小按鈕，加底加框只會變成圖上罩一個方塊。
-- * **`MoneyDisplayFrameTemplate` / `MoneyFrame` 的金幣數字** —— 那是值不是裝飾，
--   字色走 `SetMoneyFrameColorByFrame` → `SetNormalFontObject`。
-- * **`ResultsText` / `TotalQuantity` / `TimeLeftText` / `Name` 等資訊文字** ——
--   全部是值（含「剩餘時間」的紅字），顏色本身就是訊息。
-- * **`LoadingSpinner` / `DarkOverlay` / `DisabledOverlay` / `DialogOverlay`** ——
--   遮罩與讀取動畫，本來就該是半透明的一層。
-- * **`AuctionHouseMultisellProgressFrame`** —— 上架多筆時彈出來的進度條，
--   判準落在提示皮那一邊（STYLE.md ①），不是這包的設定視窗皮。
-- * **`WoWTokenResults` / `WoWTokenSellFrame` 的內容** —— 只做外框級。
--   那一頁整片是時光徽章的專屬美術（含 3D 場景），換底就得接管上面所有文字。
-- * **套組內建的另一支拍賣插件的側邊面板與它自己的分頁內容** ——
--   它有自己的主題系統（會依自己的設定切深色／原生），兩邊都畫就是兩層底。
--   我們只處理「它用暴雪模板建的那四顆分頁」。
-- * **套組本體的「僅限當前資料片」按鈕** —— 它是 `BackdropTemplate` ＋ 自己的
--   `OnEnter`/`OnLeave` 會重設 backdrop 顏色；我們的 overlay 壓在它的 backdrop
--   之下，畫了也看不見，而要讓它看得見就得動它的腳本（伴隨元件規則明文禁止）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `AuctionHouseFrame` 的 NineSlice／PortraitContainer／Bg／TopTileStreaks | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `TitleContainer.TitleText` | `SetTextColor` |
-- | `MoneyFrameInset` 的 Bg／NineSlice、各清單的 `Background`／`NineSlice`／`BackgroundNineSlice` | `SetAlpha(0)` |
-- | `MoneyFrameBorder` 的四張無名貼圖 | `SetAlpha(0)`（`Engine.NeutralizeRegions`，走 `GetRegions`） |
-- | 九顆分頁的 `TabTextures`（含伴隨元件那四顆） | `SetAlpha(0)` ＋ `SetNormalFontObject` |
-- | `CloseButton` 的 Normal／Disabled | `SetAlpha(0)`；Highlight／Pushed | `SetColorTexture` |
-- | 分類列的 `NormalTexture`／`SelectedTexture`／`HighlightTexture`／`Lines` | `SetDesaturated` ＋ `SetVertexColor`（`NormalTexture` 是 `SetAlpha(0)`） |
-- | 欄位表頭的 `Left`／`Right`／`Middle` | `SetAlpha(0)`；`Arrow` | `SetVertexColor` |
-- | 搜尋框／數量框／金額框的 `Left`／`Right`／`Middle`／`left`／`right` | `SetAlpha(0)` |
-- | 篩選下拉的 `Background` | `SetAlpha(0)`；`Arrow` | `SetDesaturated` ＋ `SetVertexColor`；`Text` | `SetTextColor` ＋ 兩支 `HookScript`（`Engine.DropdownText`） |
-- | 一般按鈕的 `Left`／`Right`／`Middle` | `SetAlpha(0)` ＋ `SetNormalFontObject` ＋ Highlight 中和 ＋ `HookScript("OnEnter"/"OnLeave")`（`Engine.TrackButtonHover`） |
-- | **特許按鈕**的 `Left`／`Right`／`Middle` | `SetAlpha(0)` ＋ `SetNormalFontObject` ＋ Highlight `SetColorTexture`。**零 HookScript** |
-- | `BuyoutModeCheckButton` 的四張狀態圖 | `SetAlpha(0)` / `SetColorTexture` / `SetDesaturated`（`Skin.CheckBox`） |
-- | 捲軸的 Track／Thumb／Back／Forward | `SetAlpha(0)` / `SetVertexColor`（`Skin.ScrollBar`） |
-- | 賣出頁的 `CreateAuctionTabLeft/Middle/Right` | `SetAlpha(0)`；`CreateAuctionLabel` | `SetTextColor` |
-- | 上面所有目標 | 以它們為 parent／anchor 建**我們自己的** overlay 框與貼圖 |
--
-- ### 掛了哪些 hook（這一輪新增）
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc(_G, "AuctionHouseFilterButton_SetUp", …)` | 全域函式後置勾（`Engine.HookRows`） | 第一行查弱鍵表；中和 `NormalTexture`、去飽和＋染 `SelectedTexture`／`HighlightTexture`／`Lines`。**不讀第二個參數 `info`** |
-- | `hooksecurefunc(AuctionHouseTableHeaderStringMixin, "Init", …)` | mixin 後置勾（`Engine.HookRows`） | 中和三片式底圖、染排序箭頭。**不讀 `owner`／`headerText`／`sortOrder`** |
-- | `Engine.DropdownText` 的 `HookScript("OnEnable"/"OnDisable")` | frame script 後掛 | 只對篩選下拉那一顆，內容只有 `SetTextColor` |
-- | `Engine.TrackButtonHover` 的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | 只對**一般**按鈕；內容只有換我們自己 overlay 的底色與邊色 |
-- | `Engine.TrackTab` 的三支 `PanelTemplates_*` 後置勾 | 全域函式後置勾（引擎既有，不是新的） | 第一行查弱鍵表 |
--
-- **`hooksecurefunc` 在 `AuctionHouseFrame`／任何 `C_AuctionHouse` 函式上：0 支。**
-- **在特許按鈕上的 `HookScript`：0 支。**
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 特許：通往受保護動作的按鈕（`UIPanelButtonTemplate` 系）
--
-- 跟 `Skin.Button` 差一件事，而那一件事就是特許的全部內容：
-- **不呼叫 `Engine.TrackButtonHover`** ⇒ 這顆按鈕身上一條我們的腳本都沒有，
-- 滑過回饋交還給引擎（Highlight 貼圖換成白 8%，C 端自己決定什麼時候顯示）。
--
-- ⚠ **先建 overlay 再中和**（同 `Skins/Popup.lua` 的 `FlatButton`）：
--   `Engine.Overlay` 對顯式保護框會回 nil，倒過來寫的話那顆按鈕會變成
--   「美術被中和掉、又沒有東西補」的隱形按鈕 —— 而這幾顆是「出價／直購／上架」。
--
-- TODO(升格): 第三個視窗也需要「一顆完全不掛腳本的平面按鈕」時，
--   就把它升格成 `Skin.Button` 的 `opts.noHover`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function CommerceButton(btn, key)
    if not E.Usable(btn, key) then return nil end

    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end

    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    -- 第三、四個參數都不給 ⇒ Highlight 換成白 8%、Pushed 不上色、**不掛腳本**
    E.ButtonStates(btn, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.Paint(ov, T.fill, T.border)
    return ov
end

-- 取子物件的共同寫法：拿不到就記一筆 missing（伴隨元件另外走靜默跳過）
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

------------------------------------------------------------
-- `AuctionHouseBackgroundTemplate` 的面板（Background 貼圖 ＋ NineSlice）
--
-- 出處：Shared/Blizzard_AuctionHouseSharedTemplates.xml:3
-- 這是拍賣場裡最常見的「一塊內容面板」：左側分類欄、每一個結果清單、
-- 賣出頁、商品購買頁全部繼承它。
--
-- ⚠ `Skin.Inset` 套不上去：它找的是 `Bg`／`NineSlice` 兩個 parentKey，
--   這裡的底圖叫 `Background`。
-- ⚠ 有些繼承者同時是 `VerticalLayoutFrame`（賣出頁、商品購買區）——
--   `Engine.RegionBackdrop` 會自己認出排版框並退回子框那條路（白名單第 2 條），
--   所以這裡不必特判。
------------------------------------------------------------
local function SkinBackgroundPanel(frame, key, fill)
    if not E.Usable(frame, key) then return nil end
    E.NeutralizeKeys(frame, { "Background", "NineSlice", "BackgroundNineSlice" }, key)
    local ov = E.RegionBackdrop(frame, { key = key })
    E.Paint(ov, fill or T.fillInset, T.border)
    return ov
end

------------------------------------------------------------
-- 金額輸入框
--
-- 拍賣場同時用了**兩種**金額輸入框，切片的取法不一樣：
--   * `MoneyInputFrameTemplate`（出價欄）—— `gold`/`silver`/`copper`（**小寫**），
--     切片是 `left`/`right` parentKey ＋ 只有全域名字的 `$parentMiddle`
--     （Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml，同 `Skins/Mail.lua`）。
--     ⚠ 這裡的 `BidAmount` 在 XML 裡有 `name="BidAmount"`
--       （Shared/Blizzard_AuctionHouseSharedTemplates.xml:130）⇒ 全域前綴查得到。
--   * `LargeMoneyInputFrameTemplate`（上架頁的單價／競標底價）——
--     `GoldBox`/`SilverBox`/`CopperBox`（**大寫**），每一格都是
--     `LargeInputBoxTemplate`，三張切片是正規的 `Left`/`Right`/`Middle` parentKey
--     ⇒ `Skin.EditBox` 直接適用。
--
-- 兩種的右邊那張金／銀／銅幣圖（`Icon` / `texture`）都**不碰** ——
-- 那是「這一格是什麼幣值」，是值不是裝飾。
--
-- TODO(升格): `Skins/Mail.lua`／`Skins/Popup.lua`／這一份三處都有小寫那一版了，
--   下一輪把它升格成 `Skin.MoneyInput`（`Skins/Popup.lua` 的 TODO 講的是同一支）。
------------------------------------------------------------
local MONEY_PARTS = {
    { field = "gold",   suffix = "Gold" },
    { field = "silver", suffix = "Silver" },
    { field = "copper", suffix = "Copper" },
}

local function SkinMoneyInput(frame, globalName, key)
    if not E.Usable(frame, key) then return end
    for _, part in ipairs(MONEY_PARTS) do
        local bkey = key .. "." .. part.field
        local box = Sub(frame, part.field, bkey)
        if box then
            E.NeutralizeKeys(box, { "left", "right" }, bkey)
            if globalName then
                E.NeutralizeGlobals({ globalName .. part.suffix .. "Middle" })
            end
            local ov = E.Overlay(box, { key = bkey })
            E.Paint(ov, T.fillInset, T.border)
        end
    end
end

local LARGE_MONEY_BOXES = { "GoldBox", "SilverBox", "CopperBox" }

local function SkinLargeMoneyInput(frame, key)
    if not E.Usable(frame, key) then return end
    for _, name in ipairs(LARGE_MONEY_BOXES) do
        local bkey = key .. "." .. name
        local box = Sub(frame, name, bkey)
        if box then Skin.EditBox(box, bkey) end
    end
end

------------------------------------------------------------
-- 上架／購買頁那一排「標籤 ＋ 控件」
--
-- `AuctionHouseSellFrameAlignedControlTemplate`（Shared/Blizzard_AuctionHouseSellFrame.xml:4）
-- 的三條 FontString（`Label` / `LabelTitle` / `Subtext`）是**標籤**不是按鈕文字
-- ⇒ 可以直接 `SetTextColor`（白名單第 2 條）。`Subtext` 是暴雪自己的 `DISABLED_FONT_COLOR`
-- （次要說明），維持次要色。
------------------------------------------------------------
local function SkinAlignedLabels(frame, key)
    if not E.Usable(frame, key) then return end
    for _, name in ipairs({ "Label", "LabelTitle" }) do
        local fs
        if pcall(function() fs = frame[name] end) and fs then
            E.TextColor(fs, T.text, key .. "." .. name)
        end
    end
    local sub
    if pcall(function() sub = frame.Subtext end) and sub then
        E.TextColor(sub, T.textDim, key .. ".Subtext")
    end
end

------------------------------------------------------------
-- 一個結果清單（`AuctionHouseItemListTemplate`）
--
-- ⚠ **列一顆都不碰**（理由見檔頭），而且**不呼叫它的任何 Update／FullUpdate／
--   SetDataProvider** —— 第七輪的穩定性規則 (a)：不要當某個 ScrollBox
--   「第一次 layout」的觸發者。這裡連唯讀的 `ForEachFrame` 都不用，
--   因為我們對列沒有任何事要做。
--
-- 欄位表頭做成**一條橫帶**：`HeaderContainer` 自己的矩形
-- （TOPLEFT x=4 / TOPRIGHT x=-26，Mainline/Blizzard_AuctionHouseItemList.xml:55-59）
-- 就是那一排表頭按鈕的範圍，直接照抄它，不量測、不猜清單邊緣。
-- 帶子的 parent 明確指定成清單本身：`HeaderContainer` 是表格引擎往裡面塞表頭框的
-- 容器，不拿它當 parent（陷阱 2 的同一條理由）。
------------------------------------------------------------
local function SkinItemList(list, key)
    if not E.Usable(list, key) then return end

    SkinBackgroundPanel(list, key)

    WithSub(list, "ScrollBar", key .. ".ScrollBar", function(bar, label)
        Skin.ScrollBar(bar, label)
    end)

    local header
    if pcall(function() header = list.HeaderContainer end) and header then
        local ov = E.Overlay(header, {
            key = key .. ".HeaderContainer",
            parent = list,
            noBorder = true,
        })
        E.Paint(ov, T.fillInset)
    end

    local refresh
    if pcall(function() refresh = list.RefreshFrame end) and refresh then
        local btn
        if pcall(function() btn = refresh.RefreshButton end) and btn then
            Skin.SquareIconButton(btn, key .. ".RefreshFrame.RefreshButton")
        end
    end
end

------------------------------------------------------------
-- 物品展示區（`AuctionHouseItemDisplayBaseTemplate` 系）
--
-- 只做外框：底換成內嵌色、`ItemButton`（圓形品質框）與 `Name`（物品品質色）
-- 一根手指都不碰。
------------------------------------------------------------
local function SkinItemDisplay(display, key)
    if not E.Usable(display, key) then return end
    SkinBackgroundPanel(display, key)
    -- `auctionhouse-itemheaderframe` 那一張是**無名無 parentKey** 的裝飾圈
    -- （Shared/Blizzard_AuctionHouseCommoditiesBuyFrame.xml:31、
    --  同 SellFrame.xml:218），只剩 GetRegions 一條路；要留下的
    --  （Background 已經中和過、Name 是 FontString、不會被掃到）沒有衝突。
    E.NeutralizeRegions(display, key)
end

------------------------------------------------------------
-- 搜尋列
------------------------------------------------------------
local function SkinSearchBar(bar, key)
    if not E.Usable(bar, key) then return end

    WithSub(bar, "SearchBox", key .. ".SearchBox", function(box, label)
        Skin.EditBox(box, label)
    end)
    WithSub(bar, "SearchButton", key .. ".SearchButton", function(btn, label)
        -- 搜尋不在任何受保護請求的執行流上（它走 `C_AuctionHouse.SendBrowseQuery`）
        -- ⇒ 一般按鈕，有職業色滑過邊。
        Skin.Button(btn, label)
    end)
    WithSub(bar, "FavoritesSearchButton", key .. ".FavoritesSearchButton", function(btn, label)
        Skin.SquareIconButton(btn, label)
    end)
    WithSub(bar, "FilterButton", key .. ".FilterButton", function(btn, label)
        Skin.Dropdown(btn, label, "filter")
    end)
end

------------------------------------------------------------
-- 左側分類清單
------------------------------------------------------------
local function SkinCategoriesList(list, key)
    if not E.Usable(list, key) then return end
    SkinBackgroundPanel(list, key)
    WithSub(list, "ScrollBar", key .. ".ScrollBar", function(bar, label)
        Skin.ScrollBar(bar, label)
    end)
end

------------------------------------------------------------
-- 出價／直購欄（`AuctionHouseBidFrameTemplate` / `AuctionHouseBuyoutFrameTemplate`）
------------------------------------------------------------
local function SkinBidFrame(frame, key)
    if not E.Usable(frame, key) then return end
    local amount
    if pcall(function() amount = frame.BidAmount end) and amount then
        SkinMoneyInput(amount, "BidAmount", key .. ".BidAmount")
    end
    local btn
    if pcall(function() btn = frame.BidButton end) and btn then
        CommerceButton(btn, key .. ".BidButton")
    end
end

local function SkinBuyoutFrame(frame, key)
    if not E.Usable(frame, key) then return end
    local btn
    if pcall(function() btn = frame.BuyoutButton end) and btn then
        CommerceButton(btn, key .. ".BuyoutButton")
    end
end

------------------------------------------------------------
-- 上架頁（`AuctionHouseSellFrameTemplate` 的兩個實例）
------------------------------------------------------------
local SELL_TAB_ART = { "CreateAuctionTabLeft", "CreateAuctionTabMiddle", "CreateAuctionTabRight" }

local function SkinSellFrame(frame, key)
    if not E.Usable(frame, key) then return end

    SkinBackgroundPanel(frame, key)
    -- 左上那顆「建立拍賣」小分頁：三張 `auctionhouse-selltab-*` 中和，
    -- 標籤文字接管成白字（它是 FontString 不是按鈕文字）
    E.NeutralizeKeys(frame, SELL_TAB_ART, key)
    local label
    if pcall(function() label = frame.CreateAuctionLabel end) and label then
        E.TextColor(label, T.text, key .. ".CreateAuctionLabel")
    end

    WithSub(frame, "ItemDisplay", key .. ".ItemDisplay", SkinItemDisplay)

    WithSub(frame, "QuantityInput", key .. ".QuantityInput", function(q, qkey)
        SkinAlignedLabels(q, qkey)
        WithSub(q, "InputBox", qkey .. ".InputBox", function(box, blabel)
            Skin.EditBox(box, blabel)
        end)
        WithSub(q, "MaxButton", qkey .. ".MaxButton", function(btn, blabel)
            -- 「最大數量」只是把數字填滿，不通往任何受保護請求 ⇒ 一般按鈕
            Skin.Button(btn, blabel)
        end)
    end)

    for _, name in ipairs({ "PriceInput", "SecondaryPriceInput" }) do
        local input
        if pcall(function() input = frame[name] end) and input then
            local ikey = key .. "." .. name
            SkinAlignedLabels(input, ikey)
            local money
            if pcall(function() money = input.MoneyInputFrame end) and money then
                SkinLargeMoneyInput(money, ikey .. ".MoneyInputFrame")
            end
        end
    end

    WithSub(frame, "Duration", key .. ".Duration", function(d, dkey)
        SkinAlignedLabels(d, dkey)
        WithSub(d, "Dropdown", dkey .. ".Dropdown", function(dd, dlabel)
            Skin.Dropdown(dd, dlabel, "style1")
        end)
    end)

    for _, name in ipairs({ "Deposit", "TotalPrice" }) do
        local display
        if pcall(function() display = frame[name] end) and display then
            SkinAlignedLabels(display, key .. "." .. name)
        end
    end

    -- **特許**：上架
    WithSub(frame, "PostButton", key .. ".PostButton", CommerceButton)

    -- 「只賣直購價」勾選框（`UICheckButtonTemplate`，36x36 ⇒ 方框走置中固定邊長）
    local cb
    if pcall(function() cb = frame.BuyoutModeCheckButton end) and cb then
        Skin.CheckBox(cb, key .. ".BuyoutModeCheckButton")
    end
end

------------------------------------------------------------
-- 我的拍賣頁
------------------------------------------------------------
local function SkinAuctionsFrame(frame, key)
    if not E.Usable(frame, key) then return end

    -- 兩顆子分頁（`PanelTopTabButtonTemplate` ⇒ 掛在內容**上方**，相連的是下邊）
    local tabs = {}
    for _, name in ipairs({ "AuctionsTab", "BidsTab" }) do
        local tab
        if pcall(function() tab = frame[name] end) and tab then
            tabs[#tabs + 1] = { tab = tab, key = key .. "." .. name }
        else
            E.Missing(key .. "." .. name)
        end
    end
    if #tabs > 0 then
        Skin.TabGroup(tabs, { kind = "panel", joined = "BOTTOM" })
    end

    WithSub(frame, "SummaryList", key .. ".SummaryList", function(list, lkey)
        SkinBackgroundPanel(list, lkey)
        WithSub(list, "ScrollBar", lkey .. ".ScrollBar", function(bar, blabel)
            Skin.ScrollBar(bar, blabel)
        end)
    end)

    WithSub(frame, "ItemDisplay", key .. ".ItemDisplay", SkinItemDisplay)

    for _, name in ipairs({ "AllAuctionsList", "BidsList", "ItemList", "CommoditiesList" }) do
        local list
        if pcall(function() list = frame[name] end) and list then
            SkinItemList(list, key .. "." .. name)
        end
    end

    WithSub(frame, "BidFrame", key .. ".BidFrame", SkinBidFrame)
    WithSub(frame, "BuyoutFrame", key .. ".BuyoutFrame", SkinBuyoutFrame)
    -- **特許**：取消拍賣
    WithSub(frame, "CancelAuctionButton", key .. ".CancelAuctionButton", CommerceButton)
end

------------------------------------------------------------
-- 購買確認彈窗（`AuctionHouseBuyDialogTemplate`）
--
-- 三顆按鈕全部走特許：`BuyNowButton` 直接通往購買，而
-- `CancelButton`／`OkayButton` 跟它同一個 `AuctionHouseDialogButtonTemplate`、
-- 同一個彈窗 —— 一個視窗裡兩種滑過語彙比少一圈職業色邊難看得多。
------------------------------------------------------------
local function SkinBuyDialog(dialog, key)
    if not E.Usable(dialog, key) then return end

    -- `DialogBorderDarkTemplate` 的九張切片是 parentArray/無名的 ⇒ 整組掃
    local border
    if pcall(function() border = dialog.Border end) and border then
        E.NeutralizeRegions(border, key .. ".Border")
    end
    local ov = E.RegionBackdrop(dialog, { key = key })
    E.Paint(ov, T.fill, T.border)

    for _, name in ipairs({ "BuyNowButton", "CancelButton", "OkayButton" }) do
        local btn
        if pcall(function() btn = dialog[name] end) and btn then
            CommerceButton(btn, key .. "." .. name)
        end
    end
end

------------------------------------------------------------
-- 池化列：**只有**左側分類清單與欄位表頭
--
-- 兩支都放在 `Engine.Register` 的 `hooks` 欄位（戰鬥閘前面，陷阱 4）。
------------------------------------------------------------
local function SkinCategoryRow(row)
    -- 底圖（`auctionhouse-nav-button` 系）：中和。
    -- ⚠ 一定要放 reapply —— `AuctionHouseFilterButton_SetUp` 每次都對它
    --   `SetAlpha(1.0)`（category/subCategory）或 `SetAlpha(0.0)`（subSubCategory）
    --   （Mainline/Blizzard_AuctionHouseCategoriesList.lua:28,47,64）。
    E.NeutralizeKeys(row, { "NormalTexture" }, "AuctionCategoryButton")
end

local function SkinCategoryRowOnce(row)
    -- 選中帶與滑過帶：**顯示與否完全留給暴雪**，我們只換長相。
    -- 去飽和是必要的（那幾張 atlas 是金棕色的，乘法染不出職業色）；
    -- `SetDesaturated`／`SetVertexColor` 跟 `SetAtlas` 互相獨立 ⇒ 設一次就撐得住。
    local selected
    if pcall(function() selected = row.SelectedTexture end) and selected then
        E.Desaturate(selected, "AuctionCategoryButton.SelectedTexture")
        -- 壓暗的職業色：那張 atlas 是 `alphaMode="ADD"`，滿色疊在深底上會過亮
        -- （同 `T.AccentFill` 的理由：一排都亮就變成霓虹燈）
        E.VertexColor(selected, { T.AccentFill(1) }, "AuctionCategoryButton.SelectedTexture")
    end
    local highlight
    if pcall(function() highlight = row.HighlightTexture end) and highlight then
        E.Desaturate(highlight, "AuctionCategoryButton.HighlightTexture")
        E.VertexColor(highlight, T.textDim, "AuctionCategoryButton.HighlightTexture")
    end
    local lines
    if pcall(function() lines = row.Lines end) and lines then
        E.Desaturate(lines, "AuctionCategoryButton.Lines")
        E.VertexColor(lines, T.textDisabled, "AuctionCategoryButton.Lines")
    end
    SkinCategoryRow(row)
end

local HEADER_ART = { "Left", "Right", "Middle" }

local function SkinColumnHeader(row)
    E.NeutralizeKeys(row, HEADER_ART, "AuctionHouseTableHeaderString")
    -- Highlight 留給引擎畫成白 8%（這一顆不掛腳本：表頭是排序，不是受保護動作，
    -- 但它每次 layout 都會重跑 Init，少一層腳本就少一次重複掛勾的機會）
    E.ButtonStates(row, "AuctionHouseTableHeaderString")
    local arrow
    if pcall(function() arrow = row.Arrow end) and arrow then
        E.VertexColor(arrow, T.text, "AuctionHouseTableHeaderString.Arrow")
    end
end

local function InstallHooks()
    -- 分類列：共同出口是**全域函式**，`mixin = _G` 就是勾全域（同成就視窗的
    -- `AchievementComparisonPlayerButton_Saturate`）。
    -- ⚠ 不讀第二個參數 `info`（那是 elementData，可能是秘密值）。
    E.HookRows{
        key     = "AuctionCategoryButton",
        mixin   = _G,
        method  = "AuctionHouseFilterButton_SetUp",
        apply   = SkinCategoryRowOnce,
        reapply = SkinCategoryRow,
    }

    -- 欄位表頭：表格引擎每次重排都會重新 `ConstructHeader` → `frame:Init(...)`
    -- （Blizzard_SharedXML/TableBuilder.lua:68-74）。表頭框是池化的。
    -- ⚠ 不讀三個參數中的任何一個。
    E.HookRows{
        key    = "AuctionHouseTableHeaderString",
        mixin  = _G.AuctionHouseTableHeaderStringMixin,
        method = "Init",
        apply  = SkinColumnHeader,
    }
end

------------------------------------------------------------
-- 伴隨元件：底部那一排分頁
--
-- 暴雪三顆 ＋ 套組內建拍賣插件的四顆用的是**同一個**模板
-- （`AuctionHouseFrameDisplayModeTabTemplate`，LibAHTab 的 `CreateTab` 直接借用）
-- ⇒ 不一起處理就是一排分頁兩種長相。
--
-- ⚠ 一律 `_G[...]` 判斷，**找不到就靜默跳過**（不記 `E.Missing`）：
--   玩家沒裝那支插件不是暴雪改版事故。
-- ⚠ 不呼叫它的任何函式、不 hook 它的函式、不在它的框上寫欄位。
-- ⚠ 順序就是版面順序：那支插件依自己的分頁序由左往右建
--   （購物／上架／取消／設定），接在暴雪第三顆的右邊。
--
-- ⚠ **那四顆的名字不寫在這裡**：它們登記在 `ThirdParty/Auctionator.lua`
--   （`Engine.AddCompanionTabs`），這裡用 `E.CompanionTabs` 取出來。
--   第三方開關關掉時取到的是空表 ⇒ 這一排就只剩暴雪三顆，接縫照樣對。
------------------------------------------------------------
local BLIZZARD_TABS = { "BuyTab", "SellTab", "AuctionsTab" }

local function SkinTabRow()
    local f = _G.AuctionHouseFrame
    if not f then return end

    local tabs = {}
    for _, name in ipairs(BLIZZARD_TABS) do
        local tab
        if pcall(function() tab = f[name] end) and tab then
            tabs[#tabs + 1] = { tab = tab, key = "AuctionHouseFrame." .. name }
        else
            E.Missing("AuctionHouseFrame." .. name)
        end
    end
    for _, name in ipairs(E.CompanionTabs("auctionhouse")) do
        local tab = _G[name]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = name }
        end
    end

    if #tabs > 0 then
        Skin.TabGroup(tabs, { kind = "panel", joined = "TOP" })
    end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Apply()
    local f = _G.AuctionHouseFrame
    if not f then
        E.Missing("AuctionHouseFrame")
        return
    end

    Skin.PortraitChrome(f, "AuctionHouseFrame")
    Skin.Panel(f, "AuctionHouseFrame")
    WithSub(f, "CloseButton", "AuctionHouseFrame.CloseButton", function(btn, label)
        Skin.CloseButton(btn, label)
    end)

    -- 底部金錢列：內嵌框 ＋ 那條細金邊。
    -- ⚠ `MoneyFrameBorder` 本身沒有名字 ⇒ `ThinGoldEdgeTemplate` 的三張
    --   `$parentLeft/Middle/Right` 連全域名字都沒有，只剩 `GetRegions`
    --   （讀結構不是讀值，讀取例外表上那一條）。同時掃掉 XML 裡那張無名的
    --   `UI-Frame` 端帽（Shared/Blizzard_AuctionHouseFrame.xml:30-38）。
    WithSub(f, "MoneyFrameInset", "AuctionHouseFrame.MoneyFrameInset", function(inset, label)
        Skin.Inset(inset, label)
    end)
    WithSub(f, "MoneyFrameBorder", "AuctionHouseFrame.MoneyFrameBorder", function(border, label)
        E.NeutralizeRegions(border, label)
        local ov = E.RegionBackdrop(border, { key = label })
        E.Paint(ov, T.fillInset, T.border)
    end)

    WithSub(f, "SearchBar", "AuctionHouseFrame.SearchBar", SkinSearchBar)
    WithSub(f, "CategoriesList", "AuctionHouseFrame.CategoriesList", SkinCategoriesList)

    -- 瀏覽結果
    WithSub(f, "BrowseResultsFrame", "AuctionHouseFrame.BrowseResultsFrame", function(frame, key)
        WithSub(frame, "ItemList", key .. ".ItemList", SkinItemList)
    end)

    -- 物品購買頁
    WithSub(f, "ItemBuyFrame", "AuctionHouseFrame.ItemBuyFrame", function(frame, key)
        WithSub(frame, "BackButton", key .. ".BackButton", function(btn, label)
            Skin.Button(btn, label)
        end)
        WithSub(frame, "ItemDisplay", key .. ".ItemDisplay", SkinItemDisplay)
        WithSub(frame, "ItemList", key .. ".ItemList", SkinItemList)
        WithSub(frame, "BidFrame", key .. ".BidFrame", SkinBidFrame)
        WithSub(frame, "BuyoutFrame", key .. ".BuyoutFrame", SkinBuyoutFrame)
    end)

    -- 商品（可堆疊）購買頁
    WithSub(f, "CommoditiesBuyFrame", "AuctionHouseFrame.CommoditiesBuyFrame", function(frame, key)
        WithSub(frame, "BackButton", key .. ".BackButton", function(btn, label)
            Skin.Button(btn, label)
        end)
        WithSub(frame, "ItemList", key .. ".ItemList", SkinItemList)
        WithSub(frame, "BuyDisplay", key .. ".BuyDisplay", function(display, dkey)
            SkinBackgroundPanel(display, dkey)
            WithSub(display, "ItemDisplay", dkey .. ".ItemDisplay", SkinItemDisplay)
            WithSub(display, "QuantityInput", dkey .. ".QuantityInput", function(q, qkey)
                SkinAlignedLabels(q, qkey)
                WithSub(q, "InputBox", qkey .. ".InputBox", function(box, blabel)
                    Skin.EditBox(box, blabel)
                end)
                WithSub(q, "MaxButton", qkey .. ".MaxButton", function(btn, blabel)
                    Skin.Button(btn, blabel)
                end)
            end)
            for _, name in ipairs({ "UnitPrice", "TotalPrice" }) do
                local display2
                if pcall(function() display2 = display[name] end) and display2 then
                    SkinAlignedLabels(display2, dkey .. "." .. name)
                end
            end
            -- **特許**：直購
            WithSub(display, "BuyButton", dkey .. ".BuyButton", CommerceButton)
        end)
    end)

    -- 上架頁（物品／商品兩個實例共用同一個模板）＋ 兩個對應的清單
    WithSub(f, "ItemSellFrame", "AuctionHouseFrame.ItemSellFrame", SkinSellFrame)
    WithSub(f, "CommoditiesSellFrame", "AuctionHouseFrame.CommoditiesSellFrame", SkinSellFrame)
    WithSub(f, "ItemSellList", "AuctionHouseFrame.ItemSellList", SkinItemList)
    WithSub(f, "CommoditiesSellList", "AuctionHouseFrame.CommoditiesSellList", SkinItemList)

    -- 我的拍賣
    WithSub(f, "AuctionsFrame", "AuctionHouseFrame.AuctionsFrame", SkinAuctionsFrame)

    -- 時光徽章的兩頁：**只做外框**（整頁是專屬美術，換底就得接管所有文字）
    for _, name in ipairs({ "WoWTokenResults", "WoWTokenSellFrame" }) do
        local frame
        if pcall(function() frame = f[name] end) and frame then
            Skin.BorderOnly(frame, "AuctionHouseFrame." .. name)
        end
    end

    -- 購買確認彈窗
    WithSub(f, "BuyDialog", "AuctionHouseFrame.BuyDialog", SkinBuyDialog)
end

E.Register{
    key   = "auctionhouse",
    addon = "Blizzard_AuctionHouseUI",
    title = L["Auction House"],
    hooks = InstallHooks,
    apply = Apply,
    companions = {
        -- 整排分頁（暴雪三顆 ＋ 伴隨元件四顆）一次畫完，理由見檔頭。
        -- 冪等（`Engine.Overlay` 本來就是），每次開拍賣場重掃一遍無害。
        { event = "AUCTION_HOUSE_SHOW", apply = SkinTabRow },
    },
}
