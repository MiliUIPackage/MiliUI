------------------------------------------------------------
-- 配方：顧客的製作訂單（`ProfessionsCustomerOrdersFrame`，隨需載入
--       `Blizzard_ProfessionsCustomerOrders`）—— 在工匠 NPC 那裡「下訂單」的那個視窗
--
-- 長相跟 `Skins/Professions.lua`（工匠那一端）一致：同一套內容面板、同一種池化列、
-- 同一條「通往受保護請求的按鈕走零腳本」的特許（`CommerceButton`）。
-- 範圍與「哪裡不碰」照成熟同類實作的「顧客製作訂單」那一段搬過來（它把這個視窗當成
-- 拍賣場的翻版來做），外觀換成我們的原語。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_ProfessionsCustomerOrders/Blizzard_ProfessionsCustomerOrders.toc
--     LoadOnDemand；Dependencies `Blizzard_ProfessionsTemplates, Blizzard_AuctionHouseUI`
--   Blizzard_ProfessionsCustomerOrders.xml:5
--     `ProfessionsCustomerOrdersFrameTabTemplate` ← **PanelTabButtonTemplate**
--   同檔 :11  `ProfessionsCustomerOrdersFrame` ← `PortraitFrameTemplate`（toplevel，825x568）
--   同檔 :17,23  `MoneyFrameInset`（InsetFrameTemplate，useParentLevel）／
--     `MoneyFrameBorder`（**ThinGoldEdgeTemplate** ＋ 一張無名的 `UI-Frame` 端帽，:35-42）
--   同檔 :46,52,58  `Form`（frameLevel 10）／`BrowseOrders`／`MyOrdersPage`（parentArray `Pages`）
--   同檔 :64,72  `BrowseTab`／`OrdersTab`（全域名 `$parentBrowseTab`／`$parentOrdersTab`；
--     第二顆 XML 寫 `LEFT → BrowseTab RIGHT x=-10`）
--   Blizzard_ProfessionsCustomerOrders.lua:33-34  `OnLoad` → `PanelTemplates_SetNumTabs(self, #self.Tabs)`
--     → `PanelTemplates_AnchorTabs`（SharedUIPanelTemplates.lua:460-471）把第二顆重錨成
--     `TOPLEFT → 前一顆 TOPRIGHT x=+3` ⇒ 實際間距是 **+3**，`pad = 0`（同收藏視窗那一條）
--   同檔 :111-126  `SelectMode` → `PanelTemplates_SetTab(self, tabIdx)`（⇒ Engine 的三支
--     `PanelTemplates_*` 全域後置勾照常觸發）
--   Blizzard_ProfessionsCustomerOrdersBrowseOrders.xml:15-60
--     `SearchBar`：`FavoritesSearchButton`（SquareIconButtonTemplate）／`SearchBox`（SearchBoxTemplate）／
--     `SearchButton`（UIPanelButtonTemplate）／`FilterDropdown`（WowStyle1FilterDropdownTemplate）；
--     `CategoryList`（ProfessionsCustomerOrdersRecipeCategoryListTemplate）／
--     `RecipeList`（ProfessionsCustomerOrdersRecipeListTemplate）
--   Blizzard_ProfessionsCustomerOrdersRecipeCategoryList.xml:5-60,62-94
--     `ProfessionsCustomerOrdersCategoryButtonTemplate`（`Lines`／`NormalTexture`／`HighlightTexture`／
--      `SelectedTexture`／`SpacerLine`，**四張都是 parentKey 的一般貼圖**，跟拍賣場分類列同一種）；
--     清單本體 `NineSlice`（NineSlicePanelTemplate ⇒ setAllPoints）／`ScrollBox`／`ScrollBar` ← MinimalScrollBar／
--     `Background`（CraftingOrders-Categories-Background）
--   Blizzard_ProfessionsCustomerOrdersRecipeCategoryList.lua:64-141
--     `ProfessionsCustomerOrdersCategoryButtonMixin:Init` —— 每次重用都 `SetAtlas` 三張、
--     `normalTexture:SetAlpha(1.0 / 0.0)`、`UpdateSelected` → `SelectedTexture:SetShown(selected)`
--   Blizzard_ProfessionsCustomerOrdersRecipeList.xml:5,31-60
--     `ProfessionsCustomerOrdersRecipeListElementTemplate`（`HighlightTexture` OVERLAY ＋ `FavoriteButton`）；
--     清單 `Background`／`HeaderContainer`／`NineSlice`（錨 0,-19 → Background BOTTOMRIGHT）／
--     `ScrollBox`／`ScrollBar`／`ResultsText`
--   Blizzard_ProfessionsCustomerOrdersRecipeList.lua:115-120  `…RecipeListElementMixin:Init`
--   Blizzard_ProfessionsCustomerOrdersMyOrders.xml:5,17-100
--     `ProfessionsCustomerOrderListElementTemplate`；`RefreshButton`（RefreshButtonTemplate ←
--     SquareIconButtonTemplate）；`OrderList`：`Background`／`HeaderContainer`／`NineSlice`（錨 -1,-32
--     → Background BOTTOMRIGHT 3,-2）／`ScrollBox`／`ScrollBar`
--   Blizzard_ProfessionsCustomerOrdersMyOrders.lua:54-56  `ProfessionsCustomerOrderListElementMixin:Init`
--   Blizzard_ProfessionsCustomerOrdersForm.xml:5,18-610
--     `ProfessionsCustomerListingsElementTemplate`；`ProfessionsCustomerOrderFormTemplate`：
--     `RecipeHeader`（ARTWORK）／`LeftPanelBackground`・`RightPanelBackground`（useParentLevel；
--      各自 `NineSlice` ＋ `Background`）／`BackButton`（UIPanelButtonTemplate）／`FavoriteButton`／
--     `OutputIcon`（ProfessionsOutputButtonTemplate ← CircularGiantItemButtonTemplate）／
--     `MinimumQuality`（`Dropdown` ← WowStyle1DropdownTemplate ＋ `Text`）／`OrderRecipientDropdown`／
--     `OrderRecipientTarget`（InputBoxTemplate, AutoCompleteEditBoxTemplate）／
--     `OrderRecipientDisplay.SocialDropdown`（UIMenuButtonStretchTemplate）／`RecraftSlot`／
--     `ReagentContainer`（`Reagents`／`OptionalReagents` ← ProfessionsReagentContainerTemplate）／
--     `PaymentContainer`：`Tip`／`Duration`／`TimeRemaining`／`PostingFee`／`TotalPrice`（標籤）／
--      `NoteEditBox`（`Border` atlas CraftingOrders-NoteFrameNarrow ＋ `TitleBox.Title` ＋
--       `ScrollingEditBox`，fontName = **GameFontHighlight**）／`TipMoneyInputFrame`
--      （**LargeMoneyInputFrameTemplate**：`GoldBox`／`SilverBox`／`CopperBox`）／`ViewListingsButton`／
--      `DurationDropdown`／`ListOrderButton`・`CancelOrderButton`（UIPanelButtonTemplate）；
--     `TrackRecipeCheckbox.Checkbox`／`AllocateBestQualityCheckbox`（UICheckButtonTemplate）；
--     `QualityDialog`（ProfessionsQualityDialogTemplate，DIALOG）；
--     `CurrentListings`（**DefaultPanelTemplate**：`NineSlice`／`Bg`／`TopTileStreaks`／`TitleContainer.TitleText`；
--      `OrderList`（`Background`／`HeaderContainer`／`NineSlice` 錨 0,-19 / -27,0／`ScrollBar`）／`CloseButton`）
--   Blizzard_ProfessionsCustomerOrdersForm.lua:13-15  `ProfessionsCustomerListingsElementMixin:Init`
--   同檔 :34,82  `ListOrderButton`／`CancelOrderButton` 的 OnClick → `C_CraftingOrders.PlaceNewOrder`／`CancelOrder`
--   同檔 :1130-1136  `RecipeName:SetTextColor(品質色／NORMAL_FONT_COLOR)`（唯一對表單文字下色的地方）
--   Blizzard_ProfessionsTemplates/Blizzard_ProfessionsQualityDialog.xml:24-60
--     `ProfessionsQualityDialogTemplate` ← DefaultPanelFlatTemplate（`Bg` 是 FlatPanelBackgroundTemplate **子框**）／
--     `ClosePanelButton`／`Container1..3.EditBox`（NumericInputSpinnerTemplate）／`CancelButton`／`AcceptButton`
--
------------------------------------------------------------
-- ## 做了什麼
--
-- * 外框、關閉鈕、底部兩顆分頁、底部金錢列（內嵌框 ＋ 細金邊換成 `fillInset` 方框）。
-- * 瀏覽頁：搜尋列（最愛鈕、搜尋框、篩選下拉、「搜尋」primary）；左側分類清單（面板 ＋ 捲軸 ＋
--   **池化分類列**：跟拍賣場分類列同一套 —— 底圖中和、選中／滑過帶去飽和染色、顯示與否交還暴雪）；
--   配方清單（面板 ＋ 欄位表頭帶 ＋ 捲軸 ＋ 池化列的列底）。
-- * 我的訂單頁：重新整理鈕、清單（面板 ＋ 表頭帶 ＋ 捲軸 ＋ 池化列的列底）。
-- * 下單表單：左右兩塊面板、返回（secondary）、三顆下拉、收件人輸入框、社交小鈕、兩顆勾選框、
--   五條欄位標籤降成 `textDim`、留言框（便條紙中和 ＋ `fillInset` 方框；內文本來就是白字）、
--   小費金額三格、**「下訂單」「取消訂單」零腳本 primary**（花金幣／撤單）。
-- * 右側「目前的委託」小面板與品質選擇對話框：外框、清單、按鈕、數字框。
--
-- ## 刻意不碰
--
-- * **材料格與產出圖示**（`ReagentContainer` 的 `ProfessionsReagentSlotBaseTemplate`、`OutputIcon`、
--   `RecraftSlot`）：跟 `Skins/Professions.lua` 同一條理由 —— 圓形格子 ＋ `CropFrame`／品質星等／
--   `ColorOverlay` 三層都是值，方框套上去是「圓框外面一個方框」。同類實作也不碰。
-- * `RecipeHeader`（配方標題的框飾，產出圖示就嵌在裡面）、`FavoriteButton`、`ViewListingsButton`
--   （自訂的放大鏡鈕）、`MinimumQualityIcon`、`OrderStateText`／`RecipeName` 的顏色（品質色是資訊）。
-- * **欄位表頭按鈕本身**（`ProfessionsCrafterTableHeaderStringTemplate`）：它的 mixin 住在
--   `Blizzard_ProfessionsTemplates`，工匠端的專業視窗也用同一個 —— 勾它會連帶改到另一個配方
--   （而且可能是玩家關掉的那一個）。只畫 `HeaderContainer` 那一條帶子，跟專業視窗一致。
-- * 各清單的 `ResultsText`、`LoadingSpinner`；配方列上的 `FavoriteButton`（HIGH strata 的星星）。
-- * 列的滑過帶 `HighlightTexture`：parentKey 的一般貼圖，暴雪在 `OnLineEnter/Leave` Show/Hide；
--   本來就是中性的白色 ADD ⇒ 留著（同專業視窗的訂單列）。
--
-- ## 照抄不了的地方（同類實作有、我們契約不准）
--
-- * 它把左側分類欄往左加寬 2、把 ScrollBox 的列距改成 −1（`view:SetPadding`＋`FullUpdate`）——
--   重排暴雪框 ＋ 呼叫暴雪 view 的方法，不做。
-- * 它把收件人下拉與輸入框整組往下移 10（`ClearAllPoints`／`SetPoint`）、把小費金額框高度減 6
--   （`SetHeight`）、量清單寬度去畫表頭條（`GetLeft`／`GetRight`／`GetTop`）—— 不准重排、不准讀尺寸。
--   表頭帶改成直接照 `HeaderContainer` 自己的矩形畫（跟專業視窗一樣，不量測）。
-- * 它對欄位表頭 `SetTexture("")` ＋ 新建滑過貼圖 —— 見上面「刻意不碰」。
-- * 它在清單、表單、兩個分頁頁面上 `HookScript("OnShow")` 重跑整份（為了重新量測它畫的分隔線）——
--   我們沒有要量的東西，一次就撐得住（全部是 alpha／自己的貼圖錨在目標上）。
-- * 它畫的「分區分隔線與淡色底」（topSep／rail wash／form split）全靠量測定位 —— 不做。
-- * 它用 `hooksecurefunc(ScrollBox, "Update", …)` 掃分類列 ＝ 在暴雪框上寫欄位；改成勾分類列 mixin 的
--   `Init`（`Engine.HookRows`）。
-- * 它讓 `CurrentListings` 的「關閉」長得像右上角的 ×；那顆是 `UIPanelButtonTemplate` 的文字鈕，
--   我們照文字鈕畫（secondary）。
--
------------------------------------------------------------
-- ## 特許：通往受保護請求的按鈕
--
-- 「下訂單」（`C_CraftingOrders.PlaceNewOrder`，扣押金與小費）與「取消訂單」（`CancelOrder`）走
-- `CommerceButton`（本檔 local，同 `Skins/Professions.lua`／`Skins/AuctionHouse.lua` 那一支）：
-- 零 `HookScript`、滑過與停用交給 C 端依狀態顯示的貼圖。兩顆不會同時出現（一個在
-- `uncommittedRegions`、一個在 `committedRegions`）⇒ 各自是那個狀態下唯一的執行鈕 ⇒ primary
-- （拍賣場的「取消拍賣」也是 primary）。
-- ⚠ `CancelOrderButton` 的 `OnEnter` 暴雪會 `SetScript` 換來換去（Form.lua:1485-1491）——
--   這正是它不能掛 `HookScript` 的另一個理由：`SetScript` 會把後掛的腳本整個蓋掉。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | 視窗的 NineSlice／PortraitContainer／Bg／TopTileStreaks | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | 視窗本身、各內容面板（`CategoryList`／`RecipeList`／`OrderList` ×2／`Left`・`RightPanelBackground`／`NoteEditBox`／`CurrentListings`／`QualityDialog`） | `Engine.RegionBackdrop`（建成它們自己的 BACKGROUND 貼圖） |
-- | 各面板的 `Background`／`NineSlice`／`Bg`／`TopTileStreaks`、`NoteEditBox.Border` | `SetAlpha(0)` |
-- | `TitleContainer.TitleText`（視窗、目前委託、品質對話框） | `SetTextColor` |
-- | 兩顆分頁的 `TabTextures` | `SetAlpha(0)` ＋ `SetNormalFontObject`（`Skin.TabGroup`） |
-- | `MoneyFrameInset` 的 Bg／NineSlice、`MoneyFrameBorder` 的四張無名貼圖 | `SetAlpha(0)`（後者走 `Engine.NeutralizeRegions`） |
-- | 關閉鈕 ×3 | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture` |
-- | 搜尋框、收件人輸入框、小費三格、品質數字框 | `Left`／`Right`／`Middle` `SetAlpha(0)`；`searchIcon`／清除鈕 `SetVertexColor`；`Instructions` `SetTextColor` |
-- | 五顆下拉 | `Background`／`Arrow` `SetAlpha(0)` ＋ 圖記；篩選那一顆的 `Text` `SetTextColor` ＋ 兩支 `HookScript` |
-- | 分類列的 `NormalTexture` | `SetAlpha(0)`（reapply：`Init` 每次設回 1.0） |
-- | 分類列的 `SelectedTexture`／`HighlightTexture`／`Lines` | `SetDesaturated` ＋ `SetVertexColor` |
-- | 三種清單列 | 以列為 parent 建我們的列底（`Skin.Row`，Highlight 走 getter，這幾種模板沒有 ⇒ 實際上不碰任何區域） |
-- | 兩顆勾選框 | 四張狀態圖 `SetAlpha(0)`／`SetColorTexture`／勾的 `SetTexture`＋`SetVertexColor` |
-- | 一般按鈕（搜尋、返回、關閉目前委託、品質對話框兩顆） | `Left`／`Right`／`Middle` `SetAlpha(0)` ＋ `SetNormalFontObject` ＋ Highlight 中和 ＋ `HookScript("OnEnter"/"OnLeave")`（primary 另加 `OnEnable`/`OnDisable`） |
-- | **特許**：`ListOrderButton`／`CancelOrderButton` | `Left`／`Right`／`Middle` `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`（＋ `SetDisabledTexture` 一張白貼圖）。**零 HookScript** |
-- | 最愛鈕、重新整理鈕、社交小鈕 | `Skin.SquareIconButton`／`Skin.StretchButton` |
-- | 五條欄位標籤、留言框標題、`MinimumQuality.Text` | `SetTextColor(textDim)`（XML 設的 GameFontNormal，Lua 不重設） |
--
-- ### 讀了什麼
--
-- 只有 parentKey 與 `Engine.NeutralizeRegions` 的 `GetRegions()`（結構）。**不讀** 訂單／配方資料、
-- `elementData`、`categoryInfo`、`self.Tabs`、`modeToTabIdx`。
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `ProfessionsCustomerOrdersCategoryButtonMixin:Init` | mixin 後置勾（`Engine.HookRows`） | apply：去飽和＋染色三張；reapply：中和 `NormalTexture`。**不讀四個參數** |
-- | `ProfessionsCustomerOrdersRecipeListElementMixin:Init` | mixin 後置勾（`Engine.HookRows`） | 只畫列底。**不讀參數** |
-- | `ProfessionsCustomerOrderListElementMixin:Init` | mixin 後置勾（`Engine.HookRows`） | 只畫列底 |
-- | `ProfessionsCustomerListingsElementMixin:Init` | mixin 後置勾（`Engine.HookRows`） | 只畫列底 |
-- | Engine 既有的三支 `PanelTemplates_*` 全域後置勾 | 全域後置勾（`Engine.TrackTab`） | 只換我們分頁 overlay 的狀態 |
-- | 原語內建的 `HookScript("OnEnter"/"OnLeave"/"OnEnable"/"OnDisable")` | frame script 後掛 | 只對一般按鈕、下拉、勾選框、關閉鈕、分頁、小圖示鈕 |
--
-- 四支列的 mixin 都是**這個插件自己的**（不在 `Blizzard_ProfessionsTemplates` 裡），列都是第一次
-- 顯示才由池子建 ⇒ 裝在 `hooks` 來得及，也不會碰到專業視窗。
-- **`hooksecurefunc` 在 `ProfessionsCustomerOrdersFrame` 或它任何子框上：0 支。`HookScript("OnShow")`：0 支。**
-- **`hooksecurefunc` 在任何 `C_CraftingOrders` 函式上：0 支。特許按鈕上的 `HookScript`：0 支。**
--
-- ### 套組裡別人掛在這個框上的東西
--
-- 拍賣插件在 `Form` 上放一顆自己的搜尋鈕、套組內建的採購清單插件在 `Form` 上放自己的按鈕
-- （都是它們自己的框）。我們只點名具名 parentKey、不做遞迴掃，碰不到它們。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
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

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

------------------------------------------------------------
-- 特許：通往受保護請求的按鈕（同 `Skins/Professions.lua` 的 `CommerceButton`）
-- TODO(升格): 第五份配方用到零腳本按鈕 —— 收成 `Skin.ScriptlessButton`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function CommerceButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    -- ⚠ 先建 overlay 再中和（顯式保護框會回 nil，倒過來寫會做出隱形的「下訂單」）
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)   -- **不掛腳本**
    return ov
end

------------------------------------------------------------
-- 內容面板：`Background` ＋ `NineSlice`（layoutType = InsetFrameTemplate）
--
-- ⚠ 只點名具名的那幾張，不做 `NeutralizeRegions` 遞迴掃（同專業視窗：套組內建的插件
--   在表單上掛了自己的按鈕）。
-- ⚠ 矩形：`opts.onNineSlice` 為真時底與邊錨在 **`NineSlice` 的矩形**上（中和的是 alpha，
--   矩形還在）。清單類的 `NineSlice` 都從表頭下方開始（XML 錨 y=-19／-32），整個清單框的
--   矩形則包含表頭那一條 —— 照 NineSlice 畫才是暴雪原本那塊內嵌框的位置。**不量測。**
------------------------------------------------------------
local PANEL_ART = { "Background", "NineSlice" }

local function SkinContentPanel(frame, key, opts)
    if not E.Usable(frame, key) then return nil end
    opts = opts or {}
    local ns9 = opts.onNineSlice and Optional(frame, "NineSlice") or nil
    E.NeutralizeKeys(frame, PANEL_ART, key)
    local ov = E.RegionBackdrop(frame, {
        key = key,
        points = ns9 and {
            { "TOPLEFT", "TOPLEFT", 0, 0, rel = ns9 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, rel = ns9 },
        } or nil,
    })
    E.Paint(ov, opts.fill or T.fillInset, T.border)
    return ov
end

-- 欄位表頭那一條帶子：照 `HeaderContainer` 自己的矩形畫 `fillInset`，parent 明確指定成清單本身
-- （`HeaderContainer` 是表格引擎塞表頭框的容器，陷阱 2）。同 `Skins/Professions.lua` 的 `SkinOrderList`。
local function SkinHeaderBand(list, key)
    local header = Optional(list, "HeaderContainer")
    if not header then
        E.Missing(key .. ".HeaderContainer")
        return
    end
    local ov = E.Overlay(header, {
        key = key .. ".HeaderContainer",
        parent = list,
        noBorder = true,
    })
    E.Paint(ov, T.fillInset)
end

-- 一整份「清單」：面板（照 NineSlice）＋ 表頭帶 ＋ 捲軸
local function SkinList(list, key, opts)
    if not E.Usable(list, key) then return end
    SkinContentPanel(list, key, { onNineSlice = true })
    if not (opts and opts.noHeader) then SkinHeaderBand(list, key) end
    WithSub(list, "ScrollBar", key .. ".ScrollBar", function(bar, label)
        Skin.ScrollBar(bar, label)
    end)
end

-- 欄位標籤降成次要灰（④「文字層級」：標籤是後設資訊）
local function DimLabels(owner, keys, prefix)
    for _, k in ipairs(keys) do
        local fs = Optional(owner, k)
        if fs then
            E.TextColor(fs, T.textDim, prefix .. "." .. k)
        else
            E.Missing(prefix .. "." .. k)
        end
    end
end

------------------------------------------------------------
-- 池化列
------------------------------------------------------------

-- 分類列：拍賣場分類列那一套（`Skins/AuctionHouse.lua` 的 `SkinCategoryRowOnce`）。
-- 選中／滑過帶的**顯示與否完全交還暴雪**（`UpdateSelected` 的 `SetShown`、`OnEnter/OnLeave` 的
-- Show/Hide），我們只換長相；`SetDesaturated`／`SetVertexColor` 跟 `SetAtlas` 互相獨立，
-- `Init` 每次重設 atlas 也洗不掉 ⇒ apply 一次就撐得住。
-- `NormalTexture` 放 reapply：`Init` 每次 `SetAlpha(1.0)`（primary／secondary）或 `0.0`（tertiary），
-- Blizzard_ProfessionsCustomerOrdersRecipeCategoryList.lua:101,119,135。
local CATEGORY_KEY = "ProfessionsCustomerOrdersCategoryButton"

local function ReapplyCategoryRow(row)
    E.NeutralizeKeys(row, { "NormalTexture" }, CATEGORY_KEY)
end

local function ApplyCategoryRow(row)
    local selected = Optional(row, "SelectedTexture")
    if selected then
        E.Desaturate(selected, CATEGORY_KEY .. ".SelectedTexture")
        E.VertexColor(selected, { T.AccentFill(1) }, CATEGORY_KEY .. ".SelectedTexture")
    end
    local highlight = Optional(row, "HighlightTexture")
    if highlight then
        E.Desaturate(highlight, CATEGORY_KEY .. ".HighlightTexture")
        E.VertexColor(highlight, T.textDim, CATEGORY_KEY .. ".HighlightTexture")
    end
    local lines = Optional(row, "Lines")
    if lines then
        E.Desaturate(lines, CATEGORY_KEY .. ".Lines")
        E.VertexColor(lines, T.textDisabled, CATEGORY_KEY .. ".Lines")
    end
end

-- 三種清單列：只畫一層列底（同專業視窗的訂單列）。`HighlightTexture` 不中和（見檔頭）；
-- 選中態沒有對應的方法可勾，不自己畫。
local function RowApplier(key)
    return function(row)
        Skin.Row(row, key, { fill = T.fillInset })
    end
end

local function InstallHooks()
    E.HookRows{
        key     = CATEGORY_KEY,
        mixin   = _G.ProfessionsCustomerOrdersCategoryButtonMixin,
        method  = "Init",
        apply   = ApplyCategoryRow,
        reapply = ReapplyCategoryRow,
    }
    E.HookRows{
        key    = "ProfessionsCustomerOrdersRecipeListElement",
        mixin  = _G.ProfessionsCustomerOrdersRecipeListElementMixin,
        method = "Init",
        apply  = RowApplier("ProfessionsCustomerOrdersRecipeListElement"),
    }
    E.HookRows{
        key    = "ProfessionsCustomerOrderListElement",
        mixin  = _G.ProfessionsCustomerOrderListElementMixin,
        method = "Init",
        apply  = RowApplier("ProfessionsCustomerOrderListElement"),
    }
    E.HookRows{
        key    = "ProfessionsCustomerListingsElement",
        mixin  = _G.ProfessionsCustomerListingsElementMixin,
        method = "Init",
        apply  = RowApplier("ProfessionsCustomerListingsElement"),
    }
end

------------------------------------------------------------
-- 瀏覽頁
------------------------------------------------------------
local function SkinBrowse(page, key)
    if not E.Usable(page, key) then return end

    WithSub(page, "SearchBar", key .. ".SearchBar", function(bar, bkey)
        WithSub(bar, "FavoritesSearchButton", bkey .. ".FavoritesSearchButton", function(btn, label)
            Skin.SquareIconButton(btn, label)
        end)
        WithSub(bar, "SearchBox", bkey .. ".SearchBox", function(box, label)
            Skin.EditBox(box, label)
        end)
        WithSub(bar, "FilterDropdown", bkey .. ".FilterDropdown", function(dd, label)
            Skin.Dropdown(dd, label, "filter")
        end)
        -- 搜尋列唯一的文字鈕 ⇒ primary（同專業視窗的 `BrowseFrame.SearchButton`）
        WithSub(bar, "SearchButton", bkey .. ".SearchButton", function(btn, label)
            Skin.Button(btn, label)
        end)
    end)

    -- 左側分類：`NineSlice` 沒有錨點（NineSlicePanelTemplate 是 setAllPoints）⇒ 整塊畫
    WithSub(page, "CategoryList", key .. ".CategoryList", function(list, lkey)
        SkinContentPanel(list, lkey)
        WithSub(list, "ScrollBar", lkey .. ".ScrollBar", function(bar, label)
            Skin.ScrollBar(bar, label)
        end)
    end)

    WithSub(page, "RecipeList", key .. ".RecipeList", SkinList)
end

------------------------------------------------------------
-- 我的訂單頁
------------------------------------------------------------
local function SkinMyOrders(page, key)
    if not E.Usable(page, key) then return end
    WithSub(page, "RefreshButton", key .. ".RefreshButton", function(btn, label)
        Skin.SquareIconButton(btn, label)
    end)
    WithSub(page, "OrderList", key .. ".OrderList", SkinList)
end

------------------------------------------------------------
-- 下單表單
------------------------------------------------------------
local PAYMENT_LABELS = { "Tip", "Duration", "TimeRemaining", "PostingFee", "TotalPrice" }
local MONEY_BOXES = { "GoldBox", "SilverBox", "CopperBox" }

local function SkinPayment(pay, key)
    if not E.Usable(pay, key) then return end

    DimLabels(pay, PAYMENT_LABELS, key)

    -- 留言框：便條紙（`CraftingOrders-NoteFrameNarrow`）中和，換一塊 `fillInset` 方框，
    -- **錨在 `ScrollingEditBox` 的矩形上**往外推 4（XML 常數：它本身就是寫字的那一塊）。
    -- 內文是 `fontName = GameFontHighlight`（白），換成深底**不需要接管任何字色**
    -- （同類實作的做法：便條紙淡掉、在捲動框後面墊一層暗底）。
    WithSub(pay, "NoteEditBox", key .. ".NoteEditBox", function(note, nkey)
        E.NeutralizeKeys(note, { "Border" }, nkey)
        local seb = Optional(note, "ScrollingEditBox")
        local ov = E.RegionBackdrop(note, {
            key = nkey,
            points = seb and {
                { "TOPLEFT", "TOPLEFT", -4, 4, rel = seb },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", 4, -4, rel = seb },
            } or nil,
        })
        E.Paint(ov, T.fillInset, T.border)
        local tb = Optional(note, "TitleBox")
        if tb then DimLabels(tb, { "Title" }, nkey .. ".TitleBox") end
    end)

    -- 小費（`LargeMoneyInputFrameTemplate`：三格都是 `LargeInputBoxTemplate` ⇒ `Skin.EditBox` 直接適用，
    -- 同 `Skins/AuctionHouse.lua` 的 `SkinLargeMoneyInput`）。金／銀／銅的幣別圖示不碰（那是值）。
    local tip = Optional(pay, "TipMoneyInputFrame")
    if tip then
        for _, name in ipairs(MONEY_BOXES) do
            local box = Optional(tip, name)
            if box then Skin.EditBox(box, key .. ".TipMoneyInputFrame." .. name) end
        end
    else
        E.Missing(key .. ".TipMoneyInputFrame")
    end

    WithSub(pay, "DurationDropdown", key .. ".DurationDropdown", function(dd, label)
        Skin.Dropdown(dd, label, "style1")
    end)

    -- **特許**：下訂單／取消訂單（見檔頭）
    WithSub(pay, "ListOrderButton", key .. ".ListOrderButton", function(btn, label)
        CommerceButton(btn, label, "primary")
    end)
    WithSub(pay, "CancelOrderButton", key .. ".CancelOrderButton", function(btn, label)
        CommerceButton(btn, label, "primary")
    end)
end

-- 「目前的委託」小面板（`DefaultPanelTemplate`，貼在表單右邊）：設定視窗皮
local DEFAULT_PANEL_ART = { "NineSlice", "Bg", "TopTileStreaks" }

local function SkinCurrentListings(cl, key)
    if not E.Usable(cl, key) then return end
    E.NeutralizeKeys(cl, DEFAULT_PANEL_ART, key)
    Skin.Panel(cl, key)
    Skin.TitleBar(cl, key)
    local tc = Optional(cl, "TitleContainer")
    local title = tc and Optional(tc, "TitleText")
    if title then E.TextColor(title, T.text, key .. ".TitleText") end

    WithSub(cl, "OrderList", key .. ".OrderList", SkinList)
    -- 「關閉」是 UIPanelButtonTemplate 的文字鈕、這個面板唯一的一顆，但它是「關閉」⇒ secondary（判準第 2 條例外）
    WithSub(cl, "CloseButton", key .. ".CloseButton", function(btn, label)
        Skin.Button(btn, label, { variant = "secondary" })
    end)
end

-- 品質選擇對話框（DIALOG strata 的小彈窗 ⇒ 提示皮，同天賦視窗的載入方案彈窗）。
-- ⚠ `Bg` 在這個模板是 **子框**（FlatPanelBackgroundTemplate，DefaultPanelFlatTemplate）⇒
--   整個子框 alpha 0；`NineSlice` 同。本體不是 layout host ⇒ `RegionBackdrop` 直接建在它身上。
-- 「接受」只在本地分配材料品質（不是受限請求）⇒ 一般原語；接受 primary、取消 secondary。
local function SkinQualityDialog(qd, key)
    if not E.Usable(qd, key) then return end
    E.NeutralizeKeys(qd, { "NineSlice", "Bg" }, key)
    local ov = E.RegionBackdrop(qd, { key = key })
    E.Paint(ov, T.tipFill, { T.Accent() })
    local tc = Optional(qd, "TitleContainer")
    local title = tc and Optional(tc, "TitleText")
    if title then E.TextColor(title, T.text, key .. ".TitleText") end

    WithSub(qd, "ClosePanelButton", key .. ".ClosePanelButton", function(btn, label)
        Skin.CloseButton(btn, label)
    end)
    for i = 1, 3 do
        local c = Optional(qd, "Container" .. i)
        local eb = c and Optional(c, "EditBox")
        if eb then Skin.EditBox(eb, key .. ".Container" .. i .. ".EditBox") end
    end
    WithSub(qd, "AcceptButton", key .. ".AcceptButton", function(btn, label)
        Skin.Button(btn, label)
    end)
    WithSub(qd, "CancelButton", key .. ".CancelButton", function(btn, label)
        Skin.Button(btn, label, { variant = "secondary" })
    end)
end

local function SkinForm(form, key)
    if not E.Usable(form, key) then return end

    -- 左右兩塊面板（`useParentLevel`：跟 `Form` 同一個 frame level。`Form` 自己沒有我們的底，
    -- `RecipeHeader` 在 ARTWORK ⇒ 我們 BACKGROUND −8 的底一定在它下面，不會有平手的問題）
    for _, name in ipairs({ "LeftPanelBackground", "RightPanelBackground" }) do
        WithSub(form, name, key .. "." .. name, SkinContentPanel)
    end

    -- 返回：導覽 ⇒ secondary
    WithSub(form, "BackButton", key .. ".BackButton", function(btn, label)
        Skin.Button(btn, label, { variant = "secondary" })
    end)

    local mq = Sub(form, "MinimumQuality", key .. ".MinimumQuality")
    if mq then
        WithSub(mq, "Dropdown", key .. ".MinimumQuality.Dropdown", function(dd, label)
            Skin.Dropdown(dd, label, "style1")
        end)
        DimLabels(mq, { "Text" }, key .. ".MinimumQuality")
    end

    WithSub(form, "OrderRecipientDropdown", key .. ".OrderRecipientDropdown", function(dd, label)
        Skin.Dropdown(dd, label, "style1")
    end)
    WithSub(form, "OrderRecipientTarget", key .. ".OrderRecipientTarget", function(box, label)
        Skin.EditBox(box, label)
    end)

    -- 社交小鈕（密語／加好友的選單）：開選單 ⇒ secondary（判準第 5 條），同專業視窗
    local disp = Optional(form, "OrderRecipientDisplay")
    local social = disp and Optional(disp, "SocialDropdown")
    if social then
        Skin.StretchButton(social, key .. ".OrderRecipientDisplay.SocialDropdown", { variant = "secondary" })
    end

    local track = Optional(form, "TrackRecipeCheckbox")
    local trackCb = track and Optional(track, "Checkbox")
    if trackCb then Skin.CheckBox(trackCb, key .. ".TrackRecipeCheckbox.Checkbox") end
    WithSub(form, "AllocateBestQualityCheckbox", key .. ".AllocateBestQualityCheckbox", function(cb, label)
        Skin.CheckBox(cb, label)
    end)

    WithSub(form, "PaymentContainer", key .. ".PaymentContainer", SkinPayment)
    WithSub(form, "CurrentListings", key .. ".CurrentListings", SkinCurrentListings)
    WithSub(form, "QualityDialog", key .. ".QualityDialog", SkinQualityDialog)
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local TAB_NAMES = { "ProfessionsCustomerOrdersFrameBrowseTab", "ProfessionsCustomerOrdersFrameOrdersTab" }

local function Apply()
    local f = _G.ProfessionsCustomerOrdersFrame
    if not f then
        E.Missing("ProfessionsCustomerOrdersFrame")
        return
    end
    local key = "ProfessionsCustomerOrdersFrame"

    Skin.PortraitChrome(f, key)
    Skin.Panel(f, key)
    WithSub(f, "CloseButton", key .. ".CloseButton", function(btn, label)
        Skin.CloseButton(btn, label)
    end)

    -- 底部分頁：`pad = 0`（`PanelTemplates_AnchorTabs` 把間距改成 +3，見檔頭）
    local tabs = {}
    for _, name in ipairs(TAB_NAMES) do
        local tab = _G[name]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = name }
        else
            E.Missing(name)
        end
    end
    if #tabs > 0 then
        Skin.TabGroup(tabs, { kind = "panel", joined = "TOP" })
    end

    -- 底部金錢列（同拍賣場：`MoneyFrameBorder` 沒有名字 ⇒ 三張切片連全域名都沒有，只剩 GetRegions）
    WithSub(f, "MoneyFrameInset", key .. ".MoneyFrameInset", function(inset, label)
        Skin.Inset(inset, label)
    end)
    WithSub(f, "MoneyFrameBorder", key .. ".MoneyFrameBorder", function(border, label)
        E.NeutralizeRegions(border, label)
        local ov = E.RegionBackdrop(border, { key = label })
        E.Paint(ov, T.fillInset, T.border)
    end)

    WithSub(f, "BrowseOrders", key .. ".BrowseOrders", SkinBrowse)
    WithSub(f, "MyOrdersPage", key .. ".MyOrdersPage", SkinMyOrders)
    WithSub(f, "Form", key .. ".Form", SkinForm)
end

E.Register{
    key   = "customerorders",
    addon = "Blizzard_ProfessionsCustomerOrders",
    title = L["Crafting Orders"],
    hooks = InstallHooks,
    apply = Apply,
}
