------------------------------------------------------------
-- 伴隨元件：套組內建的拍賣插件（掛在拍賣場上的四頁：購物／銷售／取消／設定）
--
-- 兩件事：
--   1. 底部那四顆分頁**只登記名字**（`Engine.AddCompanionTabs`），由 host 配方
--      `Skins/AuctionHouse.lua` 跟暴雪三顆**同一次**交給 `Skin.TabGroup`（理由見下）。
--   2. 四頁的內容元件（輸入框、按鈕、單選鈕、捲軸、內嵌框、欄位表頭…）在這裡畫，
--      `Engine.AddCompanion("auctionhouse", …)`。
--
-- 出處：`AddOns/Auctionator`（Version 320）。下面的「檔案:行」都是那支插件裡的路徑。
--
------------------------------------------------------------
-- ## 建立時機（決定觸發事件的依據）
--
-- `Source_Mainline/Initialize/Main.lua:26-49`：收到
-- `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`（拍賣商）⇒ `CreateFrame("FRAME", "AuctionatorAHFrame",
-- AuctionHouseFrame, …)`；它的 `OnShow`（`Source_ModernAH/Core/Mixin.lua:109-134`）**同步**建：
--   * `AuctionatorAHTabsContainer` → `OnLoad`（`Source_ModernAH/Tabs/Mixins/TabContainer.lua:10-39`）
--     依序 `CreateFrame` 四頁：`AuctionatorShoppingFrame`／`AuctionatorSellingFrame`／
--     `AuctionatorCancellingFrame`／`AuctionatorConfigFrame`（**有全域名**，`Tabs/Main.lua:17-50`）
--     ＋ 四顆分頁 `AuctionatorTabs_*`
--   * `AuctionatorBuyItemFrame`／`AuctionatorBuyCommodityFrame`（購物頁裡的兩個購買面板）
-- 四頁的子元件全是 XML 靜態建好的；各頁 `OnLoad` 再用 Lua 補建一批
-- （結果清單的欄位表頭 `ResultsListing:Init`、購物頁的兩個清單容器與五個對話框、
-- `FilterKeySelector` 的下拉）—— **也都在同一個呼叫堆疊裡**，沒有「第一次顯示某頁才建」的東西。
--
-- 唯一例外是**銷售頁左邊背包清單的分類標題列**（護甲／消耗品…）：`CreateFramePool`
-- （`Source/Groups/View.lua:10`）在背包快取算完之後才 `Acquire`，時間點不定。
--
-- ## 觸發時機與理由
--
-- | 觸發 | 做什麼 | 理由 |
-- |---|---|---|
-- | `event = "AUCTION_HOUSE_SHOW"`（引擎延一幀） | 全掃 | 上面那一整批在拍賣商互動事件的同一幀建好；延一幀之後都在。冪等，每次開拍賣場重掃無害 |
-- | `event = "AUCTION_HOUSE_THROTTLED_SYSTEM_READY"` | 還沒全掃成功就全掃；成功過就**只掃分類標題列** | 補掃時機：(a) 分類標題列是物件池晚一拍才借出來的；(b) 那支插件有一條「別的插件把拍賣場縮到很小」的退路（`Mixin.lua:119-126`，改用 OnUpdate 延後建頁），那時四頁要晚很久才建。這個事件在拍賣場開著的時候、每次查詢節流解除都會來，不開拍賣場不會來 |
--
-- 戰鬥閘照走（引擎）；**不排 timer**、自己的檔案裡沒有事件框。
--
------------------------------------------------------------
-- ## 掛了哪些元件
--
-- 取得方式一律「全域名 ＋ parentKey 路徑」（`Field`），沒有就靜默跳過、不記 `Engine.Missing`
-- （伴隨元件規則第 2 條）。沒有 parentKey 的只有三種，改讀**結構**（`GetChildren`）：
-- 重新整理鈕、單選鈕、欄位表頭與分類標題列 —— 見各段註解。
--
-- ### 銷售頁 `AuctionatorSellingFrame`（`Source_ModernAH/Tabs/Selling/Frames/Main.xml`、`SaleItem.xml`）
--
-- | 元件 | 模板 | 原語 |
-- |---|---|---|
-- | `SaleItemFrame.Icon`（拖物品進來那一格） | 自製 `AuctionatorGroupsViewItemTemplate`（`Icon`／`EmptySlot`／`IconBorder`／`IconSelectedHighlight` 四張 parentKey 貼圖，**不是** `ItemButton`） | local `SaleIcon`：`EmptySlot` 中和、`fillInset` 底、前景 1px 黑方框；品質框見「刻意不碰」 |
-- | `SaleItemFrame.Quantity.InputBox` | `LargeInputBoxTemplate`（經 `AuctionatorRetailImportLargeInputBoxTemplate`） | `Skin.EditBox` |
-- | `SaleItemFrame.Price／BidPrice.MoneyInput` 的 `GoldBox`／`SilverBox`／`CopperBox` | `LargeMoneyInputFrameTemplate` | `Skin.EditBox`（同 host 的 `SkinLargeMoneyInput`） |
-- | `SaleItemFrame.MaxButton`（最大） | `UIPanelDynamicResizeButtonTemplate` | `Skin.Button` secondary |
-- | `SaleItemFrame.Duration` 底下三個無名框的 `.RadioButton`（12／24／48） | `UIRadioButtonTemplate` | `Skin.CheckBox{ radio = true }` |
-- | **`AuctionatorPostButton`**（開始拍賣） | `UIPanelButtonTemplate` | **特許零腳本 primary**（local `CommerceButton`） |
-- | `AuctionatorSkipPostingButton`／`AuctionatorPrevPostingButton` | 同上 | `Skin.Button` secondary |
-- | `SaleItemFrame` 底下無名的重新整理鈕 | `RefreshButtonTemplate` | `Skin.SquareIconButton` |
-- | `PricesTabsContainer.CurrentPricesTab／PriceHistoryTab／YourHistoryTab` | `PanelTabButtonTemplate` | `Skin.TabGroup{ kind = "panel", joined = "TOP" }` |
-- | `CurrentPricesListing`／`HistoricalPriceListing`／`PostingHistoryListing` | 自製 `AuctionatorResultsListingTemplate` | local `ResultsListing`（表頭帶 ＋ 表頭三片中和 ＋ 捲軸） |
-- | `BagListing.View.ScrollBar` ＋ 清單兩個的 `ScrollArea.ScrollBar` | **`WowTrimScrollBar`** | `ns.External.ScrollBar`（`Core/External.lua` 的 local 那一支，TODO(升格)） |
-- | `BagInset`／`HistoricalPriceInset` | 自製 `AuctionatorInset(Dark)Template`（`Bg` ＋ `NineSlice`） | local `Inset` |
-- | 背包清單的分類標題列（`…ItemListingFrame` 子框的 `.GroupTitle`） | **暴雪的** `AuctionCategoryButtonTemplate` | local `GroupTitle`（見那一段） |
-- | `Deposit`／`Total` 與各輸入框的 `Label` | FontString（標籤） | `E.TextColor` → `textDim`（④ 文字層級：欄位標籤） |
--
-- ### 取消頁 `AuctionatorCancellingFrame`（`Source/Tabs/Cancelling/Frames/Main.xml`）
--
-- `SearchFilter`（`SearchBoxTemplate` → `Skin.EditBox`）、`ResultsListing`、`HistoricalPriceInset`、
-- **`AuctionatorCancelUndercutButton`（取消被壓價的拍賣 ⇒ `C_AuctionHouse.CancelAuction`，特許零腳本 primary）**、
-- `UndercutScanContainer.StartScanButton`（掃描，`Skin.Button` secondary）、無名的重新整理鈕。
--
-- ### 購物頁 `AuctionatorShoppingFrame`（`Source/Tabs/Shopping/Frames/Main.xml`）
--
-- 搜尋列（`SearchOptions.SearchString` 輸入框、清除鈕、「搜尋」primary、其餘兩顆 secondary）、
-- 兩個清單容器（Lua 建的 `.Inset` ＋ `.ScrollBar`，`Source/Tabs/Shopping/Mixins/ListsContainer.lua:379-388`）、
-- 清單上方兩顆分頁（`PanelTopTabButtonTemplate` → `Skin.TabGroup{ joined = "BOTTOM" }`）、
-- 新清單／匯出／匯入／匯出結果四顆 secondary、`ResultsListing` ＋ `ShoppingResultsInset`。
-- 兩個購買面板：
--   * `AuctionatorBuyItemFrame`：返回、重新整理、`ResultsListing`、`Inset`；
--     購買彈窗 `BuyDialog` 的 **`Buy`（⇒ `C_AuctionHouse.PlaceBid`，特許 primary）**／`Cancel`（特許 secondary）
--   * `AuctionatorBuyCommodityFrame`：返回、重新整理、`DetailsContainer.Quantity` 輸入框、
--     **`DetailsContainer.BuyButton`（⇒ `StartCommoditiesPurchase`，特許 primary）**、三個確認彈窗的
--     **`ContinueButton`／`AcceptButton`（⇒ `StartCommoditiesPurchase`／`ConfirmCommoditiesPurchase`，特許 primary）**
--     與 `CancelButton`（特許 secondary）、`QuantityCheckConfirmationDialog.QuantityInput` 輸入框
-- 五個對話框：`AuctionatorShoppingTabItemFrame`（`ButtonFrameTemplate` 外框 ＋ 輸入框／最小最大值／
-- 下拉／勾選框／清除鈕／三顆按鈕）、`AuctionatorItemHistoryFrame`／`AuctionatorExportListFrame`／
-- `AuctionatorImportListFrame`／購物頁的 `exportCSVDialog`（`AuctionatorSimplePanelTemplate` 外框 ＋
-- 內嵌框 ＋ 捲軸 ＋ 按鈕 ＋ 關閉鈕）。
--
-- ### 設定頁 `AuctionatorConfigFrame`（`Source/Tabs/Auctionator/Frames/Main.xml`）
--
-- 頁框本身（繼承 `AuctionatorInsetTemplate`）、八個大標題的 `HeadingText`（白）、
-- 三個複製連結框的 `InputBox`（`InputBoxTemplate`）、`ScanButton`（完整掃描，primary）、
-- `OptionsButton`（開設定頁，secondary）。
--
------------------------------------------------------------
-- ## 特許：通往受保護動作的按鈕（STYLE.md ⑦「特許的第二種用法」）
--
-- 判準是「按下去會不會送出需要硬體事件的請求」，逐顆查那支插件的 OnClick 走到哪：
--
-- | 按鈕 | OnClick → | 變體 |
-- |---|---|---|
-- | `AuctionatorPostButton` | `SaleItem:PostItem()` → `C_AuctionHouse.PostItem`／`PostCommodity`（`Source_ModernAH/Tabs/Selling/Mixins/SaleItem.lua:724,731`） | primary |
-- | `AuctionatorCancelUndercutButton` | `CancelNextAuction()` → `Auctionator.AH.CancelAuction` → `C_AuctionHouse.CancelAuction`（`Source_ModernAH/AH/Wrappers.lua:74`） | primary |
-- | `AuctionatorBuyItemFrame.BuyDialog.Buy` | `BuyClicked()` → `C_AuctionHouse.PlaceBid`（`Source_ModernAH/Tabs/Buying/Item/Mixins/Dialog.lua:38`） | primary |
-- | 同一個彈窗的 `Cancel` | 關彈窗 | secondary（同彈窗兩種滑過語彙比少一圈職業色邊難看，同 host 的 `SkinBuyDialog`） |
-- | `AuctionatorBuyCommodityFrame.DetailsContainer.BuyButton` | `BuyClicked()` → `C_AuctionHouse.StartCommoditiesPurchase`（`…/Commodity/Mixins/Main.lua:236`） | primary |
-- | 三個確認彈窗的 `ContinueButton`／`AcceptButton` | `StartCommoditiesPurchase`／`ConfirmCommoditiesPurchase`（`…/Commodity/Mixins/Dialogs.lua:47,78`） | primary |
-- | 三個確認彈窗的 `CancelButton` | 關彈窗（`OnHide` 裡 `CancelCommoditiesPurchase`） | secondary |
--
-- 做法照 host 的 `CommerceButton`（`Skins/AuctionHouse.lua`）：**先 `E.Overlay` 再中和**
-- （顯式保護框回 nil 的話不會留下一顆隱形按鈕）→ `E.ButtonFonts` → `E.ScriptlessButton`。
-- **不呼叫 `Skin.Button`**（它會經由 `TrackButtonHover` 掛 `OnEnter`／`OnLeave`／`OnEnable`／`OnDisable`）。
-- 這一份另外有一道保險：`Special` 表把這幾顆記下來，通用的按鈕函式遇到就跳過，
-- 哪天路徑寫重了也不會被 `Skin.Button` 補掛腳本。
--
------------------------------------------------------------
-- ## 底部四顆分頁為什麼只登記名字、不自己畫
--
-- 四顆用的是**暴雪同一個**分頁模板（`AuctionHouseFrameDisplayModeTabTemplate`，那支插件的
-- 分頁函式庫直接借用）。`Skin.TabGroup` 的接縫是「這一顆的右緣錨在**下一顆**的左緣」，
-- 而 overlay 的錨點只在**建立時**定一次（STYLE.md ③ 陷阱 1）⇒ 整排一定要同一次畫完。
-- 所以這裡只 `Engine.AddCompanionTabs`，真正畫的是 host 的 `SkinTabRow`。
-- 第三方開關關掉時 `Engine.CompanionTabs` 回空表 ⇒ 那一排只剩暴雪三顆，接縫照樣對。
--
------------------------------------------------------------
-- ## 那支插件有沒有自己的主題／外觀設定
--
-- **沒有。** 全檔找不到 theme／skin／backdrop 的設定項；`Source/Components/Dialogs.lua`
-- 裡的 `…BySkin` 只是一張以空字串為 key 的快取表，不是外觀系統。
-- （STYLE.md ⑦ 與 host 檔頭原本寫「它有自己的主題系統，兩邊都畫就是兩層底」——那是把
-- 同樣掛在拍賣場上、另一支自帶主題的側邊面板插件跟它搞混了，這一輪一併更正。）
--
-- 會跟我們互動的只有兩個設定，都不打架：
--   * `SMALL_TABS`（`TabContainer.lua:30-37`）：`PanelTemplates_TabResize` 改分頁寬度 ——
--     overlay 錨在分頁上，跟著走。
--   * `SHOW_SELLING_BAG` = 否（`Source_ModernAH/Tabs/Selling/Mixins/Main.lua:20-30`）：藏掉背包清單、
--     **把三顆小分頁改成由右往左排**。`Skin.TabGroup` 要求由左往右 ⇒ 這裡讀
--     `BagListing:IsShown()` 決定順序（讀取例外表那一條，理由寫在 STYLE.md）。
--     ⚠ 那個設定是「開拍賣場時的 OnLoad 才生效」，overlay 的錨點也只在建立時定一次
--       ⇒ 改了設定要 `/reload`（跟它自己一樣）。
--
------------------------------------------------------------
-- ## taint 接觸面清單（伴隨元件）
--
-- ⚠ 這一份**一個暴雪物件都沒有碰**（分類標題列用的是暴雪模板，但那顆按鈕是它建的），
--   所以只有這一張表（STYLE.md ③ 第 6 條）。
--
-- | 物件 | 動作 |
-- |---|---|
-- | 一般按鈕的 `Left`／`Right`／`Middle` | `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)`（清除鈕與停靠鈕不換字型） ＋ Highlight `SetAlpha(0)` |
-- | **特許按鈕**的 `Left`／`Right`／`Middle` | `SetAlpha(0)` ＋ `SetNormalFontObject`；Highlight `SetColorTexture`；**`SetDisabledTexture`（`Engine.ScriptlessButton`）**。零腳本 |
-- | 輸入框的 `Left`／`Right`／`Middle`；搜尋框的 `searchIcon`／`Instructions`／`clearButton.Icon` | `SetAlpha(0)`；`SetVertexColor`／`SetTextColor` |
-- | 單選鈕的 Normal／Pushed／Disabled／Highlight；Checked／DisabledChecked | `SetAlpha(0)`；勾選圖 `SetTexture(自帶)` ＋ `SetVertexColor`（`Engine.CheckedGlyph`） |
-- | 勾選框（購物對話框的「精確搜尋」） | 同上 |
-- | 分頁的 `TabTextures` | `SetAlpha(0)` ＋ `SetNormalFontObject` |
-- | 下拉（`WowStyle1DropdownTemplate`）的 `Background`／`Arrow` | `SetAlpha(0)` |
-- | 捲軸（`WowTrimScrollBar`）的 `Backplate`／`Background.*`／`Thumb.*`／`Back`／`Forward` 的 `Texture`／`Overlay` | `SetAlpha(0)` |
-- | 內嵌框與對話框的 `Bg`／`NineSlice`／`Background`／`Border` | `SetAlpha(0)`；`CreateTexture`（`Engine.RegionBackdrop`） |
-- | `ButtonFrameTemplate` 對話框的 NineSlice／Portrait／Bg／TitleText | `SetAlpha(0)`／`SetTextColor`（`Skin.PortraitChrome`） |
-- | 欄位表頭的 `Left`／`Right`／`Middle`；`Arrow` | `SetAlpha(0)`；`SetVertexColor`；Highlight `SetColorTexture`（白 8%） |
-- | 銷售頁物品格的 `EmptySlot` | `SetAlpha(0)` |
-- | 分類標題列的 `NormalTexture`；`HighlightTexture`／`SelectedTexture`／`Lines` | `SetAlpha(0)`；`SetDesaturated` ＋ `SetVertexColor` |
-- | 標籤 FontString（`Deposit`、`Total`、各 `Label`、`SearchLabel`、大標題 `HeadingText`） | `SetTextColor` |
-- | 以上各框 | `CreateFrame` 掛自己的 overlay（錨在目標上、不吃滑鼠、零腳本） |
--
-- hook：**一支都沒有掛在它的函式上**（`hooksecurefunc` 0、`SetScript` 0、呼叫它的函式 0）。
--   只有原語內建的 `HookScript("OnEnter"/"OnLeave")`（一般按鈕、下拉、勾選框、單選鈕、分頁、
--   捲軸拇指）與 primary 一般按鈕的 `HookScript("OnEnable"/"OnDisable")`，內容只碰我們自己的 overlay；
--   分頁的選中態走引擎既有的三支 `PanelTemplates_*` 後置勾（第一行查弱鍵表）。
--   **特許按鈕上的 HookScript：0。**
-- 寫入它的欄位：無（狀態全在 `Engine.State` 的弱鍵表裡）。
-- 讀它的東西：`_G[名字]`、parentKey 路徑、`GetChildren`／`GetObjectType`（結構）、
--   `BagListing:IsShown()`（一次，決定小分頁順序）、原語內部的 getter。
--   **不讀** 它的任何 Lua 資料欄位（`itemInfo`、`elementData`…）、不讀 `Auctionator.Config`。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **所有清單的「列」**（結果清單、購物清單、最近搜尋、背包清單的物品格、匯出清單的勾選列）——
--   `ScrollBox` 的池化元素，捲動時重用；而且結果列就是購買／取消的執行流（host 檔頭同一條理由）。
--   只做框級：內嵌框、表頭帶、捲軸。
-- * **銷售頁物品格的品質框（`IconBorder`）** —— 方形 1px 品質框做不到：那支插件在
--   `AuctionatorGroupsViewItemMixin:SetItemInfo`（`Source/Groups/ViewItem.lua:25-31`）直接對自己的貼圖
--   `SetVertexColor`，**沒有經過任何全域函式**（`SetItemButtonQuality` 系勾不到），而規則不准 hook 它。
--   換成我們的方框的話顏色只能在套用當下轉交一次，換物品之後就是錯的 ⇒ 保留它自己那圈
--   （白色貼圖乘品質色，有物品才顯示），我們只換空格底與外圈 1px 黑邊。圖示不裁邊：它每次
--   `SetTexture` 都會把 texCoord 打回 0,1，而我們沒有 reapply 掛點。
-- * **分類標題列的文字顏色**（`AuctionCategoryButtonTemplate` 的按鈕字型）—— 跟 host 的暴雪分類清單一致，不動。
-- * **`IconAndName`（購買面板的物品圖示與名稱）、`TitleArea.Text`、金額數字、`Total` 等值** ——
--   顏色本身帶資訊（④ 文字層級）。
-- * **`ConfirmDropDown`（右鍵確認選單）、`MultisellProgress`、`FullScanStatus`、翻譯者旗幟、設定頁說明文字** ——
--   選單是 C 級；其餘是值或裝飾性資訊。
-- * **對話框裡的 `ScrollingEditBoxTemplate` 內容區、匯出清單的 `ListListingFrame`** —— 捲動內容本身。
-- * **位置與尺寸** —— 那支插件自己 `SetPoint`／`SetWidth` 的東西一律不動（只重畫不重排）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret

------------------------------------------------------------
-- 1. 底部四顆分頁：只登記名字（畫的是 host 的 `SkinTabRow`）
------------------------------------------------------------
E.AddCompanionTabs("auctionhouse", {
    "AuctionatorTabs_Shopping",
    "AuctionatorTabs_Selling",
    "AuctionatorTabs_Cancelling",
    "AuctionatorTabs_Auctionator",
}, "auctionator")

------------------------------------------------------------
-- 小工具
------------------------------------------------------------

-- 沿 parentKey 路徑取物件（"SaleItemFrame.Quantity.InputBox"）。任何一段拿不到就 nil。
-- ⚠ 伴隨元件：拿不到**不記** `E.Missing`（玩家的版本不同不是暴雪改版事故）。
local function Field(obj, path)
    for k in string.gmatch(path, "[^%.]+") do
        if type(obj) ~= "table" then return nil end
        local v
        if not pcall(function() v = obj[k] end) then return nil end
        obj = v
    end
    return obj
end

local function At(root, path)
    return path and Field(root, path) or root
end

-- 讀結構：直屬子框。拿不到就空表。
local function Children(frame)
    if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then return {} end
    local ok, list = pcall(function() return { frame:GetChildren() } end)
    return ok and list or {}
end

local function ObjectType(obj)
    if type(obj) ~= "table" or type(obj.GetObjectType) ~= "function" then return nil end
    local ok, kind = pcall(obj.GetObjectType, obj)
    return ok and kind or nil
end

local function NeutralizeIfPresent(owner, keys, key)
    for _, k in ipairs(keys) do
        local region = Field(owner, k)
        if region then E.Neutralize(region, key .. "." .. k) end
    end
end

-- 特許按鈕的登記（弱鍵）：通用的按鈕函式遇到就跳過，保證它們身上不會被補掛腳本。
local Special = setmetatable({}, { __mode = "k" })

------------------------------------------------------------
-- 元件
------------------------------------------------------------

-- 特許：通往受保護動作的按鈕（照 host 的 `CommerceButton`，理由見檔頭）
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function CommerceButton(btn, key, variant)
    if not btn or not E.Usable(btn, key) then return end
    Special[btn] = true
    local ov = E.Overlay(btn, { key = key })       -- ⚠ 先建 overlay 再中和
    if not ov then return end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)
end

-- 一般文字按鈕（`UIPanelButtonTemplate` 系）
local function Button(btn, key, variant)
    if not btn or Special[btn] then return end
    Skin.Button(btn, key, { variant = variant or "secondary" })
end

-- 只有圖示、沒有文字的 `UIPanelButtonTemplate`（清除鈕的 ×、停靠鈕的箭頭）：
-- 殼照按鈕畫、圖不碰、字型物件不換（同 `Core/External.lua` 的 `P.IconButton`）
local function IconShellButton(btn, key)
    if not btn or Special[btn] then return end
    Skin.Button(btn, key, { variant = "secondary", keepFont = true })
end

local function EditBox(eb, key)
    if eb then Skin.EditBox(eb, key) end
end

-- `WowTrimScrollBar`：借 `Core/External.lua` 的那一支（兩種捲軸模板它都認得）
local function ScrollBar(bar, key)
    if bar and ns.External and ns.External.ScrollBar then
        ns.External.ScrollBar(bar, key)
    end
end

local function Label(fs, color, key)
    if fs then E.TextColor(fs, color, key) end
end

-- `AuctionatorInsetTemplate`／`…DarkTemplate`（`Source_ModernAH/Components/Frames/Inset.xml`）：
-- `Bg` ＋ `NineSlice`，`useParentLevel`。底建成它自己的貼圖（`Skin.Inset` 的同一條路），
-- 但鍵是**它的**模板的 ⇒ 有才中和、不記 missing（規則第 7 條）。
local function Inset(frame, key)
    if not frame or not E.Usable(frame, key) then return end
    NeutralizeIfPresent(frame, { "Bg", "NineSlice" }, key)
    local ov = E.RegionBackdrop(frame, { key = key })
    E.Paint(ov, T.fillInset, T.border)
end

-- 浮動對話框的外框：
--   `AuctionatorSimplePanelTemplate`（`Bg` ＋ `Border`＝NineSlice）與
--   `AuctionatorConfirmationDialogTemplate`（`Background` 黑 0.8 ＋ `NineSlice`，layout Dialog）
-- 同 host 的購買彈窗：`fill` ＋ 1px 黑邊。
local function DialogChrome(frame, key)
    if not frame or not E.Usable(frame, key) then return end
    NeutralizeIfPresent(frame, { "Bg", "Border", "Background", "NineSlice" }, key)
    local ov = E.RegionBackdrop(frame, { key = key })
    E.Paint(ov, T.fill, T.border)
end

-- `AuctionatorConfigurationMoneyInput(Alternate)`：`MoneyInput`（`LargeMoneyInputFrameTemplate`）＋ `Label`
local MONEY_BOXES = { "GoldBox", "SilverBox", "CopperBox" }

local function MoneyInput(frame, key)
    if not frame then return end
    local money = Field(frame, "MoneyInput")
    if money then
        for _, name in ipairs(MONEY_BOXES) do
            EditBox(Field(money, name), key .. ".MoneyInput." .. name)
        end
    end
    Label(Field(frame, "Label"), T.textDim, key .. ".Label")
end

-- `AuctionatorConfigurationNumericInput(Alternate)`：`InputBox`（Large）＋ 它圖層裡的 `Label`
local function NumericInput(frame, key)
    local box = frame and Field(frame, "InputBox")
    if not box then return end
    EditBox(box, key .. ".InputBox")
    Label(Field(box, "Label"), T.textDim, key .. ".InputBox.Label")
end

-- `AuctionatorConfigurationMinMaxFrame`：兩格輸入 ＋ 清除鈕
local function MinMax(frame, key)
    if not frame then return end
    EditBox(Field(frame, "MinBox"), key .. ".MinBox")
    EditBox(Field(frame, "MaxBox"), key .. ".MaxBox")
    IconShellButton(Field(frame, "ResetButton"), key .. ".ResetButton")
end

-- `AuctionatorDropDown` 與 `FilterKeySelector`：`.DropDown` 是 `WowStyle1DropdownTemplate`
local function DropDown(dd, key)
    if dd then Skin.Dropdown(dd, key, "style1") end
end

-- 單選鈕群組（`AuctionatorConfigurationRadioButtonGroup`）：選項是**無名、無 parentKey** 的
-- `AuctionatorConfigurationRadioButton`（`Source/Components/Frames/Duration.xml`），
-- 只能讀結構：子框身上有 `.RadioButton`（`UIRadioButtonTemplate`）的就是一個選項。
local function RadioGroup(group, key)
    if not group then return end
    for i, child in ipairs(Children(group)) do
        local rb = Field(child, "RadioButton")
        if rb and ObjectType(rb) == "CheckButton" then
            Skin.CheckBox(rb, key .. ".Radio" .. i, { radio = true })
        end
    end
end

-- 無名的重新整理鈕（`RefreshButtonTemplate`，寫在 XML 裡但沒有 parentKey）：
-- 讀結構，owner 的直屬子框裡「是 Button、又不是已知的那幾個 parentKey」的就是它。
-- 每個呼叫處都查過 XML：那一層只有這一顆無名按鈕。再加一道形狀檢查
-- （`SquareIconButtonTemplate` 有 `Icon`、沒有三片式的 `Left`），別的插件哪天往同一層
-- 塞了一顆文字按鈕也不會被誤認。
local function RefreshButtons(owner, key, known)
    if not owner then return end
    local skip = {}
    for _, k in ipairs(known or {}) do
        local v = Field(owner, k)
        if v then skip[v] = true end
    end
    for _, child in ipairs(Children(owner)) do
        if not skip[child] and ObjectType(child) == "Button"
            and Field(child, "Icon") and not Field(child, "Left") then
            Skin.SquareIconButton(child, key .. ".RefreshButton")
        end
    end
end

------------------------------------------------------------
-- 結果清單（`AuctionatorResultsListingTemplate`，`Source/Components/ResultsListing/Templates/ResultsListing.xml`）
--
-- * 捲軸：`ScrollArea.ScrollBar`（`WowTrimScrollBar`）。
-- * 欄位表頭：`ResultsListing:Init` 裡 `tableBuilder:SetHeaderContainer(HeaderContainer)`
--   ＋ `ConstructHeader`（`Source/Components/ResultsListing/Mixins/ResultsListing.lua:24,86`）——
--   表頭是 `HeaderContainer` 的子框，模板 `AuctionatorStringColumnHeaderTemplate`
--   ← `ColumnDisplayButtonShortTemplate`（`Left`／`Right`／`Middle` ＋ `Arrow`）。
--   只在 `Init`（頁框 `OnLoad`）建一次，之後不增不減 ⇒ 讀結構掃一次就完整。
--   做法同 host 的 `SkinColumnHeader`：三片中和、Highlight 交給引擎白 8%、箭頭染白。
-- * 表頭帶：同 host 的 `SkinItemList`，一條 `fillInset` 的無邊帶，parent 明確給清單本身
--   （`HeaderContainer` 是表格引擎塞表頭框的容器，陷阱 2）。
--   範圍照 XML 抄、不量測：`HeaderContainer` 錨 `TOPLEFT x=-20 y=-7`、高 19；表格左右邊距 15
--   （`SetTableMargins(15)`）⇒ 表頭從 x=-5 開始，正好是底下內嵌框的左緣（各頁 XML 都是 x=-5）；
--   內嵌框的上緣在 y=-24，`HeaderContainer` 的下緣在 y=-26 ⇒ 帶子下緣往上收 2，貼在內嵌框上緣。
------------------------------------------------------------
local HEADER_ART = { "Left", "Right", "Middle" }

local function ResultsListing(listing, key)
    if not listing or not E.Usable(listing, key) then return end

    ScrollBar(Field(listing, "ScrollArea.ScrollBar"), key .. ".ScrollBar")

    local header = Field(listing, "HeaderContainer")
    if header then
        local ov = E.Overlay(header, {
            key = key .. ".HeaderContainer",
            parent = listing,
            noBorder = true,
            points = {
                { "TOPLEFT", "TOPLEFT", 15, 0 },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 2 },
            },
        })
        E.Paint(ov, T.fillInset)

        for i, col in ipairs(Children(header)) do
            if ObjectType(col) == "Button" then
                local ckey = key .. ".Header" .. i
                NeutralizeIfPresent(col, HEADER_ART, ckey)
                E.ButtonStates(col, ckey)
                local arrow = Field(col, "Arrow")
                if arrow then E.VertexColor(arrow, T.text, ckey .. ".Arrow") end
            end
        end
    end
end

------------------------------------------------------------
-- 銷售頁的物品格（`SaleItemFrame.Icon`）
--
-- 自製的 `AuctionatorGroupsViewItemTemplate`（`Source/Groups/ViewItem.xml`）：
--   BACKGROUND 1 `EmptySlot`（`UI-Slot-Background`，雕花空格）
--   BACKGROUND 2 `Icon`、BACKGROUND 3 `IconBorder`（`WhiteIconFrame`，乘品質色）／`IconSelectedHighlight`
--   ＋ Pushed（`UI-Quickslot-Depress`）＋ Highlight（`ButtonHilight-Square`，ADD）
-- 做什麼：空格中和、底 `fillInset`、前景一圈 1px 黑框；Highlight 換成引擎白 8%。
-- 品質框留給它自己（理由見檔頭「刻意不碰」）。
------------------------------------------------------------
local TRANSPARENT = { 0, 0, 0, 0 }

local function SaleIcon(btn, key)
    if not btn or not E.Usable(btn, key) then return end
    NeutralizeIfPresent(btn, { "EmptySlot" }, key)
    E.ButtonStates(btn, key)
    local bg = E.Overlay(btn, { key = key, noBorder = true })
    E.Paint(bg, T.fillInset)
    local frame = E.Overlay(btn, { key = key .. ".border", levelOffset = 1 })
    E.Paint(frame, TRANSPARENT, T.border)
end

------------------------------------------------------------
-- 銷售頁左邊背包清單的分類標題列
--
-- 群組框是 `CreateFramePool(… , "AuctionatorSellingViewGroupTemplate")`
-- （`Source/Groups/View.lua:10`，parent ＝ `View.ScrollBox.ItemListingFrame`），
-- 標題是 `.GroupTitle` ← **暴雪的** `AuctionCategoryButtonTemplate`
-- （`Source_ModernAH/Tabs/Selling/Frames/BagViewSection.xml:13`）。
--
-- ⚠ 它是 `FramePool` 不是 `ScrollBox` 的元素：群組框借出來之後永遠是「群組」，只是標題字換了，
--   我們的畫法跟內容無關 ⇒ 掃到一次就一直對。晚借出來的由 `THROTTLED_SYSTEM_READY` 那一輪補。
-- ⚠ host 的分類清單是靠 `AuctionHouseFilterButton_SetUp` 那支全域後置勾畫的；
--   正式服這支插件**不呼叫**它（只在經典服呼叫，`BagViewSection.xml:18-21`）⇒ 那條勾接不到，要自己掃。
-- 畫法：對齊 host 的分類列（`SkinCategoryRowOnce`）—— 金色底圖中和、滑過帶去飽和染 `textDim`、
-- 分隔線去飽和染 `textDisabled`；再加一層 `ListHeader` 語彙的 `fill` ＋ 1px 黑邊，
-- 讓它讀起來是「可收合的標題」而不是一列物品。
------------------------------------------------------------
local function GroupTitle(title, key)
    if not title or not E.Usable(title, key) then return end
    NeutralizeIfPresent(title, { "NormalTexture" }, key)
    local hl = Field(title, "HighlightTexture")
    if hl then
        E.Desaturate(hl, key .. ".HighlightTexture")
        E.VertexColor(hl, T.textDim, key .. ".HighlightTexture")
    end
    local sel = Field(title, "SelectedTexture")
    if sel then
        E.Desaturate(sel, key .. ".SelectedTexture")
        E.VertexColor(sel, { T.AccentFill(1) }, key .. ".SelectedTexture")
    end
    local lines = Field(title, "Lines")
    if lines then
        E.Desaturate(lines, key .. ".Lines")
        E.VertexColor(lines, T.textDisabled, key .. ".Lines")
    end
    local ov = E.Overlay(title, { key = key })
    E.Paint(ov, T.fill, T.border)
end

local function SweepGroupTitles()
    local host = Field(_G.AuctionatorSellingFrame, "BagListing.View.ScrollBox.ItemListingFrame")
    if not host then return end
    for _, group in ipairs(Children(host)) do
        local title = Field(group, "GroupTitle")
        -- 已經畫過的跳過（這一輪在查詢節流解除時都會來，要便宜）
        if title and not E.GetOverlay(title) then
            GroupTitle(title, "AuctionatorSellingFrame.GroupTitle")
        end
    end
end

------------------------------------------------------------
-- 銷售頁
------------------------------------------------------------
local SELL_TABS = { "CurrentPricesTab", "PriceHistoryTab", "YourHistoryTab" }

local function SkinSelling()
    local f = _G.AuctionatorSellingFrame
    if not f then return false end
    local key = "AuctionatorSellingFrame"

    local sale = Field(f, "SaleItemFrame")
    if sale then
        local skey = key .. ".SaleItemFrame"
        SaleIcon(Field(sale, "Icon"), skey .. ".Icon")
        NumericInput(Field(sale, "Quantity"), skey .. ".Quantity")
        MoneyInput(Field(sale, "Price"), skey .. ".Price")
        MoneyInput(Field(sale, "BidPrice"), skey .. ".BidPrice")
        RadioGroup(Field(sale, "Duration"), skey .. ".Duration")
        Label(Field(sale, "Deposit"), T.textDim, skey .. ".Deposit")
        Label(Field(sale, "Total"), T.textDim, skey .. ".Total")

        -- **特許**：開始拍賣（先登記，後面的通用函式才認得它）
        CommerceButton(_G.AuctionatorPostButton or Field(sale, "PostButton"), "AuctionatorPostButton")
        -- 「最大」只是把數量填滿；「上一個／略過」是多筆上架的導覽 ⇒ secondary（這一塊的 primary 是上架）
        Button(Field(sale, "MaxButton"), skey .. ".MaxButton")
        Button(_G.AuctionatorSkipPostingButton, "AuctionatorSkipPostingButton")
        Button(_G.AuctionatorPrevPostingButton, "AuctionatorPrevPostingButton")
        RefreshButtons(sale, skey, { "Icon", "MaxButton", "PostButton", "SkipButton", "PrevButton" })
    end

    Inset(Field(f, "BagInset"), key .. ".BagInset")
    Inset(Field(f, "HistoricalPriceInset"), key .. ".HistoricalPriceInset")
    ScrollBar(Field(f, "BagListing.View.ScrollBar"), key .. ".BagListing.ScrollBar")

    for _, name in ipairs({ "CurrentPricesListing", "HistoricalPriceListing", "PostingHistoryListing" }) do
        ResultsListing(Field(f, name), key .. "." .. name)
    end

    -- 清單底下那三顆小分頁（`PanelTabButtonTemplate`，掛在內嵌框**下方** ⇒ 相連的是上邊）。
    -- ⚠ 「不顯示背包」時它們改成由右往左排（檔頭「主題／外觀設定」那一段）⇒ 反過來交。
    local container = Field(f, "PricesTabsContainer")
    if container then
        local reversed = false
        local bag = Field(f, "BagListing")
        if bag and type(bag.IsShown) == "function" then
            local ok, v = pcall(bag.IsShown, bag)
            reversed = ok and S.ToBool(v) == false
        end
        local tabs = {}
        for i = 1, #SELL_TABS do
            local name = reversed and SELL_TABS[#SELL_TABS + 1 - i] or SELL_TABS[i]
            local tab = Field(container, name)
            if tab then tabs[#tabs + 1] = { tab = tab, key = key .. "." .. name } end
        end
        if #tabs > 0 then Skin.TabGroup(tabs, { kind = "panel", joined = "TOP" }) end
    end

    SweepGroupTitles()
    return true
end

------------------------------------------------------------
-- 取消頁
------------------------------------------------------------
local function SkinCancelling()
    local f = _G.AuctionatorCancellingFrame
    if not f then return false end
    local key = "AuctionatorCancellingFrame"

    EditBox(Field(f, "SearchFilter"), key .. ".SearchFilter")
    ResultsListing(Field(f, "ResultsListing"), key .. ".ResultsListing")
    Inset(Field(f, "HistoricalPriceInset"), key .. ".HistoricalPriceInset")

    -- **特許**：取消被壓價的拍賣（這一頁唯一的執行動作 ⇒ primary）
    CommerceButton(_G.AuctionatorCancelUndercutButton
        or Field(f, "UndercutScanContainer.CancelNextButton"), "AuctionatorCancelUndercutButton")
    Button(Field(f, "UndercutScanContainer.StartScanButton"), key .. ".StartScanButton")
    -- 這一層的直屬子框只有 SearchFilter（EditBox）、四個 Frame 與那顆無名的重新整理鈕
    RefreshButtons(f, key)
    return true
end

------------------------------------------------------------
-- 購物頁的兩個購買面板
------------------------------------------------------------
local function SkinBuyItem()
    local f = _G.AuctionatorBuyItemFrame
    if not f then return end
    local key = "AuctionatorBuyItemFrame"

    Button(Field(f, "BackButton"), key .. ".BackButton")          -- 返回
    RefreshButtons(f, key, { "BackButton" })
    ResultsListing(Field(f, "ResultsListing"), key .. ".ResultsListing")
    Inset(Field(f, "Inset"), key .. ".Inset")

    local dialog = Field(f, "BuyDialog")
    if dialog then
        DialogChrome(dialog, key .. ".BuyDialog")
        CommerceButton(Field(dialog, "Buy"), key .. ".BuyDialog.Buy")
        CommerceButton(Field(dialog, "Cancel"), key .. ".BuyDialog.Cancel", "secondary")
    end
end

local COMMODITY_DIALOGS = {
    { name = "WidePriceRangeWarningDialog",     go = "ContinueButton" },
    { name = "FinalConfirmationDialog",         go = "AcceptButton" },
    { name = "QuantityCheckConfirmationDialog", go = "AcceptButton", input = "QuantityInput" },
}

local function SkinBuyCommodity()
    local f = _G.AuctionatorBuyCommodityFrame
    if not f then return false end
    local key = "AuctionatorBuyCommodityFrame"

    Button(Field(f, "BackButton"), key .. ".BackButton")          -- 返回
    RefreshButtons(f, key, { "BackButton" })
    ResultsListing(Field(f, "ResultsListing"), key .. ".ResultsListing")
    Inset(Field(f, "Inset"), key .. ".Inset")

    local details = Field(f, "DetailsContainer")
    if details then
        local dkey = key .. ".DetailsContainer"
        EditBox(Field(details, "Quantity"), dkey .. ".Quantity")
        for _, name in ipairs({ "QuantityLabel", "UnitPriceLabel", "TotalPriceLabel" }) do
            Label(Field(details, name), T.textDim, dkey .. "." .. name)
        end
        -- **特許**：直購（這一塊唯一的動作）
        CommerceButton(Field(details, "BuyButton"), dkey .. ".BuyButton")
    end

    for _, d in ipairs(COMMODITY_DIALOGS) do
        local dialog = Field(f, d.name)
        if dialog then
            local dkey = key .. "." .. d.name
            DialogChrome(dialog, dkey)
            CommerceButton(Field(dialog, d.go), dkey .. "." .. d.go)
            CommerceButton(Field(dialog, "CancelButton"), dkey .. ".CancelButton", "secondary")
            if d.input then EditBox(Field(dialog, d.input), dkey .. "." .. d.input) end
        end
    end
    return true
end

------------------------------------------------------------
-- 購物頁
------------------------------------------------------------

-- 購物頁的「新增／編輯搜尋」對話框（`AuctionatorShoppingTabItemFrame`，
-- `Source/Tabs/Shopping/Frames/Item.xml`，← `ButtonFrameTemplate`）
local ITEM_DIALOG_DROPDOWNS = {
    { box = "QualityContainer",   reset = "ResetQualityButton" },
    { box = "ExpansionContainer", reset = "ResetExpansionButton" },
    { box = "TierContainer",      reset = "ResetTierButton" },
}

local function SkinItemDialog(d, key)
    if not d or not E.Usable(d, key) then return end
    -- 外框走 `Core/External.lua` 的 `P.Shell` 同一組（`ButtonFrameTemplate` 的鍵是暴雪模板內部的）
    Skin.PortraitChrome(d, key)
    Skin.Panel(d, key)
    local close = Field(d, "CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end
    local inset = Field(d, "Inset")
    if inset then Skin.Inset(inset, key .. ".Inset") end

    EditBox(Field(d, "SearchContainer.SearchString"), key .. ".SearchString")
    IconShellButton(Field(d, "SearchContainer.ResetSearchStringButton"), key .. ".ResetSearchStringButton")
    local exact = Field(d, "SearchContainer.IsExact")
    if exact then Skin.CheckBox(exact, key .. ".IsExact") end

    for _, name in ipairs({ "LevelRange", "ItemLevelRange", "PriceRange", "CraftedLevelRange" }) do
        MinMax(Field(d, name), key .. "." .. name)
    end
    NumericInput(Field(d, "PurchaseQuantity"), key .. ".PurchaseQuantity")

    -- `FilterKeySelector.DropDown` 是它 `OnLoad` 用 Lua 建的（`CreateFrame("DropdownButton", nil, self, …)`）
    DropDown(Field(d, "FilterKeySelector.DropDown"), key .. ".FilterKeySelector.DropDown")
    IconShellButton(Field(d, "FilterKeySelector.ResetButton"), key .. ".FilterKeySelector.ResetButton")
    for _, dd in ipairs(ITEM_DIALOG_DROPDOWNS) do
        local box = Field(d, dd.box)
        if box then
            DropDown(Field(box, "DropDown.DropDown"), key .. "." .. dd.box .. ".DropDown")
            IconShellButton(Field(box, dd.reset), key .. "." .. dd.box .. "." .. dd.reset)
        end
    end

    -- 完成（新增／儲存）primary；取消、全部重設 secondary
    Button(Field(d, "Finished"), key .. ".Finished", "primary")
    Button(Field(d, "Cancel"), key .. ".Cancel")
    Button(Field(d, "ResetAllButton"), key .. ".ResetAllButton")
end

-- `AuctionatorSimplePanelTemplate` 系的四個對話框
local function SkinPanelDialog(d, key, spec)
    if not d or not E.Usable(d, key) then return end
    DialogChrome(d, key)
    Inset(Field(d, "Inset"), key .. ".Inset")
    ScrollBar(Field(d, "ScrollBar"), key .. ".ScrollBar")
    local close = Field(d, "CloseDialog")
    if close then Skin.CloseButton(close, key .. ".CloseDialog") end
    if spec.listing then ResultsListing(Field(d, "ResultsListing"), key .. ".ResultsListing") end
    if spec.primary then Button(Field(d, spec.primary), key .. "." .. spec.primary, "primary") end
    for _, name in ipairs(spec.secondary or {}) do
        Button(Field(d, name), key .. "." .. name)
    end
    if spec.icon then IconShellButton(Field(d, spec.icon), key .. "." .. spec.icon) end
end

local function SkinShopping()
    local f = _G.AuctionatorShoppingFrame
    if not f then return false end
    local key = "AuctionatorShoppingFrame"

    -- 搜尋列：「搜尋」是這一列的主動作；搜尋選項／加入清單 secondary
    local opts = Field(f, "SearchOptions")
    if opts then
        local okey = key .. ".SearchOptions"
        Label(Field(opts, "SearchLabel"), T.textDim, okey .. ".SearchLabel")
        EditBox(Field(opts, "SearchString"), okey .. ".SearchString")
        IconShellButton(Field(opts, "ResetSearchStringButton"), okey .. ".ResetSearchStringButton")
        Button(Field(opts, "SearchButton"), okey .. ".SearchButton", "primary")
        Button(Field(opts, "MoreButton"), okey .. ".MoreButton")
        Button(Field(opts, "AddToListButton"), okey .. ".AddToListButton")
    end

    -- 兩個清單容器：`.Inset`／`.ScrollBar` 是它 `OnLoad` 用 Lua 建的（檔頭）
    for _, name in ipairs({ "ListsContainer", "RecentsContainer" }) do
        local c = Field(f, name)
        if c then
            Inset(Field(c, "Inset"), key .. "." .. name .. ".Inset")
            ScrollBar(Field(c, "ScrollBar"), key .. "." .. name .. ".ScrollBar")
        end
    end

    -- 清單上方兩顆分頁（`PanelTopTabButtonTemplate` ⇒ 相連的是下邊），固定由左往右
    local ctabs = Field(f, "ContainerTabs")
    if ctabs then
        local tabs = {}
        for _, name in ipairs({ "ListsTab", "RecentsTab" }) do
            local tab = Field(ctabs, name)
            if tab then tabs[#tabs + 1] = { tab = tab, key = key .. ".ContainerTabs." .. name } end
        end
        if #tabs > 0 then Skin.TabGroup(tabs, { kind = "panel", joined = "BOTTOM" }) end
    end

    for _, name in ipairs({ "NewListButton", "ExportButton", "ImportButton", "ExportCSV" }) do
        Button(Field(f, name), key .. "." .. name)
    end

    ResultsListing(Field(f, "ResultsListing"), key .. ".ResultsListing")
    Inset(Field(f, "ShoppingResultsInset"), key .. ".ShoppingResultsInset")

    -- 對話框（`Source/Tabs/Shopping/Mixins/Main.lua:55-81`，同一個 `OnLoad` 建的）
    SkinItemDialog(_G.AuctionatorShoppingTabItemFrame, "AuctionatorShoppingTabItemFrame")
    SkinPanelDialog(_G.AuctionatorItemHistoryFrame, "AuctionatorItemHistoryFrame",
        { listing = true, secondary = { "Close" }, icon = "Dock" })
    SkinPanelDialog(_G.AuctionatorExportListFrame, "AuctionatorExportListFrame",
        { primary = "Export", secondary = { "SelectAll", "UnselectAll" } })
    SkinPanelDialog(_G.AuctionatorImportListFrame, "AuctionatorImportListFrame",
        { primary = "Import" })
    -- 匯出結果的文字框沒有全域名，是購物頁的 Lua 欄位（同一個 OnLoad，`Main.lua:68`）
    SkinPanelDialog(Field(f, "exportCSVDialog"), key .. ".exportCSVDialog",
        { secondary = { "Close" } })
    return true
end

------------------------------------------------------------
-- 設定頁（`AuctionatorConfigFrame`）
------------------------------------------------------------
local CONFIG_HEADINGS = {
    "AuthorHeading", "ContributorsHeading", "VersionHeading", "ContributeHeading",
    "EngageHeading", "TranslatorsHeading",
}

local function SkinConfig()
    local f = _G.AuctionatorConfigFrame
    if not f then return false end
    local key = "AuctionatorConfigFrame"

    Inset(f, key)          -- 頁框本身繼承 `AuctionatorInsetTemplate`（`Source/Tabs/Frames/TabFrame.xml`）
    for _, name in ipairs(CONFIG_HEADINGS) do
        Label(Field(f, name .. ".HeadingText"), T.text, key .. "." .. name)
    end
    for _, name in ipairs({ "ContributeLink", "DiscordLink", "BugReportLink" }) do
        local link = Field(f, name)
        if link then
            EditBox(Field(link, "InputBox"), key .. "." .. name .. ".InputBox")
            Label(Field(link, "Label"), T.textDim, key .. "." .. name .. ".Label")
        end
    end
    -- 完整掃描是這一頁唯一的動作（`ReplicateItems` 是查詢，不需要硬體事件 ⇒ 一般按鈕）；開設定頁是導覽
    Button(Field(f, "ScanButton"), key .. ".ScanButton", "primary")
    Button(Field(f, "OptionsButton"), key .. ".OptionsButton")
    return true
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------

-- 全掃成功過一次（四頁與兩個購買面板都在）就記起來：之後的節流事件只補分類標題列。
-- 重新開拍賣場（`AUCTION_HOUSE_SHOW`）照樣全掃 —— 冪等。
local complete = false

local function ApplyAll()
    local a = SkinSelling()
    local b = SkinCancelling()
    local c = SkinShopping()
    local d = SkinConfig()
    SkinBuyItem()
    local e = SkinBuyCommodity()
    complete = (a and b and c and d and e) and true or false
end

local function ApplyThrottled()
    if complete then
        SweepGroupTitles()
    else
        ApplyAll()
    end
end

E.AddCompanion("auctionhouse", {
    event    = "AUCTION_HOUSE_SHOW",
    addonKey = "auctionator",
    apply    = ApplyAll,
})

E.AddCompanion("auctionhouse", {
    event    = "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    addonKey = "auctionator",
    apply    = ApplyThrottled,
})
