------------------------------------------------------------
-- 配方：商人視窗（MerchantFrame，含買回分頁）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_UIPanels_Game/Mainline/MerchantFrame.xml:3     MerchantItemTemplate（153x44）
--     :7   `SlotTexture`（parentKey ＋ `$parentSlotTexture`，UI-EmptySlot，64x64 雕花空格）
--     :13  `$parentNameFrame`（UI-Merchant-LabelSlots，**只有全域名字、沒有 parentKey**）
--     :19  `Name`（parentKey ＋ `$parentName`，品質色＝資訊）
--     :28  `ItemButton`（parentKey ＋ `$parentItemButton`，ItemButton intrinsic）
--     :34  `IconQuestTexture`（任務物品驚嘆號＝資訊）
--     :72,84 `$parentMoneyFrame` / `$parentAltCurrencyFrame`（值）
--   同檔 :91   MerchantFrame（**ButtonFrameTemplate**、toplevel、336x444）
--     :95  `MerchantFramePortrait`（舊的具名頭像貼圖，PortraitContainer 之外的殘留）
--     :101 `BuybackBG`（白 a=.2，買回分頁才顯示的一整片提亮）
--     :110 `MerchantPageText`（GameFontNormal 暗金）
--     :118 `MerchantFrameBottomLeftBorder`（atlas UI-Merchant-BotFrame，334x61 的底部雕花）
--     :127-186 MerchantItem1..12
--     :187,220,280,318 MerchantSellAllJunkButton／RepairAllButton／RepairItemButton／
--                      GuildBankRepairButton（36x36；**無名無 parentKey** 的 UI-EmptySlot
--                      底圖 ＋ `Icon` parentKey ＋ PushedTexture ＋ HighlightTexture，
--                      **沒有 NormalTexture／DisabledTexture**）
--     :402 MerchantBuyBackItem（Frame ＋ `SlotTexture` ＋ `$parentNameFrame` ＋ `ItemButton`）
--     :489,502 MerchantExtraCurrencyInset／MerchantMoneyInset（InsetFrameTemplate，
--              **useParentLevel="true"**）
--     :495,508 MerchantExtraCurrencyBg／MerchantMoneyBg（ThinGoldEdgeTemplate）
--     :520,548 MerchantPrevPageButton／MerchantNextPageButton（32x32，Normal/Pushed/Disabled
--              是 UI-SpellbookIcon-*Page-*；**無名**的 UI-PageButton-Background ＋
--              **無名**的「PREV」「NEXT」FontString）
--     :576,592 MerchantFrameTab1／Tab2（**PanelTabButtonTemplate**）
--     :608 `FilterDropdown`（parentKey，WowStyle1DropdownTemplate）
--   Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua:189   MerchantFrame_Update
--     :212 MerchantFrameItem_UpdateQuality → **`self.ItemButton:SetItemButtonQuality(...)`**
--     :267 MerchantFrame_UpdateMerchantInfo（:294 SetItemButtonTexture、
--          :369-397 SetItemButtonSlotVertexColor／NameFrameVertexColor／
--          NormalTextureVertexColor、:464-467 每次重設 3/5/7/9 的錨點）
--     :506 MerchantFrame_UpdateBuybackInfo（:534 SetItemButtonTexture、:562-570 一票 Hide）
--     :933 MerchantFrame_UpdateRepairButtons、:969 MerchantFrame_UpdateCurrencies
--     :1049 MerchantFrame_UpdateCurrencyButton
--   Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:94,163,154,146,189,210,241
--     SetItemButtonTexture（全域）／SlotVertexColor／NameFrameVertexColor／
--     NormalTextureVertexColor／SetItemButtonBorder_Base／SetItemButtonQuality_Base
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:660,684
--     ButtonFrameBaseTemplate（Bg／TopTileStreaks／CloseButton）＋ ButtonFrameTemplate（Inset）
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的四件事
--
-- 1. **商品格的品質色走不到 Engine 的全域後置勾。**
--    `MerchantFrameItem_UpdateQuality`（.lua:227）呼叫的是**方法**
--    `self.ItemButton:SetItemButtonQuality(...)`（ItemButtonMixin，ItemButtonTemplate.lua:409），
--    不是全域函式 `SetItemButtonQuality`（同檔 :241）⇒ `Engine.TrackItemButton`
--    裝的那個全域後置勾**一次都不會觸發**。
--    而且就算只看 `SetItemButtonTexture`（那支確實是全域，.lua:294），它在
--    `MerchantFrameItem_UpdateQuality`（:350）**之前**跑 ⇒ 轉交到的會是上一件商品的
--    品質色。所以這一份必須自己在 `MerchantFrame_UpdateMerchantInfo` /
--    `..._UpdateBuybackInfo` 的後置勾裡重跑 `Skin.ItemButtonRefresh`
--    （跟郵件收件匣同一條理由：暴雪走了一條不經過那兩支全域函式的路）。
--
-- 2. **`SlotTexture` 與 `$parentNameFrame` 每次更新被改的是 vertex color 不是 alpha**
--    （`SetItemButtonSlotVertexColor` / `SetItemButtonNameFrameVertexColor`，
--     ItemButtonTemplate.lua:154,163）⇒ 中和一次就撐得住，不必放 reapply。
--    ⚠ 反過來說「買不起／不能用」的紅色染色是下在這兩張 ＋ 圖示 ＋ NormalTexture 上的
--    （MerchantFrame.lua:368-389）。前兩張被我們中和掉了，但**圖示那一份留著**
--    （`SetItemButtonTextureVertexColor`），紅色訊號沒有消失。
--
-- 3. **四顆修裝／賣垃圾鈕沒有 NormalTexture。** 它們的長相是「一張無名無 parentKey 的
--    `UI-EmptySlot` 底圖 ＋ 一張 `Icon` parentKey 的法術圖示」，所以 `Skin.IconButton`
--    （走 GetNormalTexture 系）在這裡等於什麼都沒做。改成本檔的 local 小函式：
--    無名底圖走 `GetRegions()` ＋ keep-set 中和、`Icon` 完全不碰
--    （暴雪用 `Icon:SetDesaturated(...)` 表示「不能修裝／沒有垃圾」，那是資訊）。
--
-- 4. **`MERCHANT_ITEMS_PER_PAGE` 是一個會變的全域數字。** 套組內建的商人擴充插件會把它
--    調大並照那個數字補建 `MerchantItem13…N`（用的是暴雪自己的 `MerchantItemTemplate`、
--    暴雪自己的命名），所以格子數不是固定 12。這一份**只讀**那個全域、一個字都不寫，
--    並且在三個時機補掃新格子：`apply`、`MERCHANT_SHOW`（伴隨元件的時機）、
--    以及兩支更新後置勾（玩家在商人視窗開著的時候改列欄數就是這一條路）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 視窗本體
--
-- | 物件 | 動作 |
-- |---|---|
-- | MerchantFrame 的 NineSlice / Bg / TopTileStreaks / PortraitContainer | SetAlpha(0) |
-- | MerchantFrame.TitleContainer.TitleText | SetTextColor |
-- | MerchantFramePortrait / BuybackBG / MerchantFrameBottomLeftBorder | SetAlpha(0) |
-- | MerchantFrame.Inset 的 Bg 與 NineSlice | SetAlpha(0) |
-- | MerchantFrameCloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | 同上的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | MerchantFrameTab1..2 的 TabTextures（九張） | SetAlpha(0) |
-- | 同兩顆 | SetNormalFontObject(GameFontHighlightSmall) |
-- | MerchantPageText | SetTextColor |
-- | MerchantFrame.FilterDropdown 的 Background | SetAlpha(0) |
-- | 同上的 Arrow | SetVertexColor |
--
-- ### 商品格（1..N，N 讀 MERCHANT_ITEMS_PER_PAGE）
--
-- | 物件 | 動作 |
-- |---|---|
-- | MerchantItemN.SlotTexture | SetAlpha(0) |
-- | MerchantItemNNameFrame（全域名） | SetAlpha(0) |
-- | MerchantItemN 的格底 | overlay **parent ＝ MerchantItemNItemButton**（跟著暴雪對空格的 Hide 一起消失） |
-- | MerchantItemNItemButton 的 IconBorder / NormalTexture | SetAlpha(0) |
-- | 同上的 icon | SetTexCoord |
-- | 同上的 Highlight 貼圖 | SetColorTexture |
-- | 同上的 IconBorder | IsShown() / GetVertexColor()（**只轉交**，STYLE.md ③） |
--
-- ### 底部那一條
--
-- | 物件 | 動作 |
-- |---|---|
-- | MerchantSellAllJunk/RepairAll/RepairItem/GuildBankRepair 的無名 UI-EmptySlot 底圖 | SetAlpha(0)（GetRegions ＋ keep-set） |
-- | 同四顆的 PushedTexture | SetAlpha(0) |
-- | 同四顆的 HighlightTexture | SetColorTexture |
-- | MerchantBuyBackItem.SlotTexture / MerchantBuyBackItemNameFrame | SetAlpha(0) |
-- | MerchantBuyBackItemItemButton | 同商品格 |
-- | MerchantMoneyInset / MerchantExtraCurrencyInset 的 Bg 與 NineSlice | SetAlpha(0) |
-- | MerchantMoneyBg* / MerchantExtraCurrencyBg*（各三張全域名切片） | SetAlpha(0) |
-- | MerchantPrev/NextPageButton 的無名 UI-PageButton-Background | SetAlpha(0)（GetRegions ＋ keep-set） |
-- | 同兩顆的 Normal/Pushed/Disabled | SetVertexColor |
-- | 同兩顆的無名 FontString（「上頁」「繼續」） | SetTextColor |
-- | 同兩顆的 Highlight | SetColorTexture |
--
-- 以上各框：`CreateFrame` 掛自己的 overlay（錨在目標上、不吃滑鼠、零腳本）。
--
-- hook（全部是後置勾，不換函式）：
--   * `hooksecurefunc("MerchantFrame_UpdateMerchantInfo", …)`
--   * `hooksecurefunc("MerchantFrame_UpdateBuybackInfo", …)`
--     兩支都**第一行就過「商人視窗開著沒有」那道閘**（見下面那一段）。
--   * Engine 的 `PanelTemplates_SelectTab / DeselectTab / SetDisabledTabState`
--     三個全域後置勾（裝在 Core/Engine.lua，全套組共用一組）。
--   * Engine 的 `SetItemButtonQuality` / `SetItemButtonTexture` 兩個全域後置勾
--     （裝在 Core/Engine.lua）——在這個視窗只有 `SetItemButtonTexture` 會觸發，
--     品質色靠上面那兩支自己的後置勾補（見「查證後不一樣的第 1 件事」）。
--   * 分頁的 `HookScript("OnEnter"/"OnLeave")`（滑過態，`Skin.Tab` 裡）。
--
-- 寫入暴雪欄位：無。寫入暴雪全域：無（`MERCHANT_ITEMS_PER_PAGE` 只讀）。
--
-- 讀暴雪物件（契約的讀取例外）：
--   * 物品格 `IconBorder` 的 `IsShown()` / `GetVertexColor()` —— 走
--     `Engine.PassBorderColor`，**當傳遞者不當讀取者**（STYLE.md ③ 的傳遞者規則）。
--   * **`MerchantFrame:IsShown()`** —— 兩支更新後置勾的第一道閘（已列入 STYLE.md ③ 的讀取例外表）：
--     暴雪在 `MerchantFrame_OnLoad`（.lua:7）就註冊了 `BAG_UPDATE` 與
--     `UNIT_INVENTORY_CHANGED`，所以商人框**沒開的時候照樣會跑** `MerchantFrame_Update`
--     —— 登入後光是背包整理就能跑上千次，少了這道閘那上千次全部會變成
--     「N 顆物品格重畫一遍」的空轉。它跟表上那幾條同型：純 C 端布林查詢，不是文字／
--     尺寸／錨點，不會回秘密值；一律過 `Secret.ToBool`，問不到就當成「沒開」
--     （少畫一次，失敗方向安全）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **商品格的點擊路徑** —— `MerchantItemButton_OnClick` → `BuyMerchantItem` 吃硬體
--   事件。這一份**一個腳本都沒掛**，overlay 不吃滑鼠（Engine 保證）。
-- * **`MerchantItemNName` 的品質色**（MerchantFrame.lua:217）、**圖示的紅／灰染色**
--   （:371,383）、**`IconQuestTexture`**、**`Count`／`Stock`** —— 全部是資訊。
-- * **金錢框與 `MerchantItemNAltCurrencyFrame` 的幣值圖與數字** —— 值；金錢框的字色
--   走 `SetMoneyFrameColor` → 字型物件（白／灰），深底上讀得到。
-- * **四顆修裝／賣垃圾鈕的 `Icon`** —— 暴雪用 `SetDesaturated` 表示「不能修裝／沒有
--   垃圾」（MerchantFrame.xml:262,389、.lua:208），那是狀態不是裝飾。
-- * **`MerchantToken1..6`** —— `BackpackTokenTemplate` 是執行期才建的（.lua:994），
--   內容只有 `Icon` ＋ `Count` 兩樣「值」，沒有雕花可中和。這一輪不碰（回報 ⑦）。
-- * **買回格的 `UndoFrame.Arrow`** —— `GetNumBuybackItems() == 0` 時暴雪自己去飽和
--   （MerchantFrame.xml:457），是狀態。
-- * **套組內建商人擴充插件加上去的三樣東西**（設定齒輪、右邊補的那一格、已收藏的打勾）
--   —— 三個都是**匿名框**，伴隨元件規則只認全域名稱 ⇒ 碰不到。詳見回報 ⑤。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret
local L = ns.L

-- 暴雪自己建好的格子數（1…12；11、12 只在買回分頁顯示）
local STOCK_CELLS = 12

------------------------------------------------------------
-- `Engine.NeutralizeRegions` 的「要留下的」set
--
-- 這幾顆按鈕上要中和的東西（那張 64x64 的 `UI-EmptySlot` 雕花、翻頁鈕的
-- `UI-PageButton-Background`）是**無名也沒有 parentKey** 的，指名不到；反過來
-- 「要留下的」全部有 parentKey 或 getter ⇒ 只能列出要留的那一邊。
--
-- ⚠ 狀態貼圖（Normal／Pushed／Disabled／Highlight）也是 `GetRegions()` 掃得到的
--   region，所以要留的話一定要放進 keep-set，否則會被一起中和掉。
-- （第五輪升格成 `Engine.KeepSet`，三份配方共用。）
------------------------------------------------------------

------------------------------------------------------------
-- 商人視窗開著沒有？
--
-- 兩支更新後置勾的第一道閘，理由寫在檔頭的「讀暴雪物件」那一段。
-- 問不到就當成「沒開」——少畫一次是安全的失敗方向。
------------------------------------------------------------
local function MerchantShown()
    local f = _G.MerchantFrame
    if not f or type(f.IsShown) ~= "function" then return false end
    local ok, shown = pcall(f.IsShown, f)
    if not ok then return false end
    return S.ToBool(shown) == true
end

------------------------------------------------------------
-- 一顆商品格
--
-- 格子本身是 `MerchantItemTemplate`（Frame，不是 Button），底下掛著一顆
-- `ItemButton` intrinsic。三件事：
--   1. 格底那張 64x64 的 `UI-EmptySlot` 雕花（`SlotTexture`）與商品名字底下那張
--      `UI-Merchant-LabelSlots` 標籤底（`$parentNameFrame`，只有全域名字）中和。
--   2. 格子本身給一塊**內嵌底框**（`fillInset` ＋ 1px 黑邊、四邊各內縮 2）。
--   3. 物品鈕走 `Skin.ItemButton`（圓角品質框換成直角方框、圖示裁邊、空格底）。
--
-- ⚠ **第六輪把格底從「跟視窗同色的平面底」換成內嵌底框。**
--   第五輪是 `T.fill`，跟 `MerchantFrame.Inset` 的 `fillInset` 疊在一起只差
--   0.035 的亮度 —— 實機上就是「看不出這裡是一格一格的」（擷圖 28 的買回頁，
--   使用者原話：「每件商品沒有格子，有點怪」）。換成比內嵌框**暗**一階
--   ＋ 一圈 1px 黑邊之後，每一格讀起來是一個凹槽。
--   這跟「一排都有邊會變成格子紙」不衝突：那條規則講的是**清單列**
--   （一列一筆文字），商品格是格子不是列 —— 暴雪自己原本就給了每一格一張雕花底圖。
--
-- ⚠ **空格的底要跟著消失，而且零讀取。**
--   `MerchantFrame_UpdateMerchantInfo`（MerchantFrame.lua:271）與
--   `..._UpdateBuybackInfo`（同檔 :411）對沒有商品的那一格做的是
--   **`itemButton:Hide()`** —— 藏的是 `MerchantItem<i>ItemButton`，不是格子本身
--   （格子只被改 vertex color）。所以把底 overlay 的 **parent 設成那顆物品鈕**
--   （錨點仍然錨在格子上）：鈕被藏起來，我們的底跟著消失。
--   跟收件匣七列同一招（`Skins/Mail.lua`），零讀取、零 hook、零判斷。
--   找不到那顆鈕就退回掛在格子上 —— 那是第五輪的行為，至少不會少一塊皮。
local CELL_INSET = 2

local function SkinCell(i)
    local key = "MerchantItem" .. i
    local cell = _G[key]
    if not cell then return false end

    E.NeutralizeKeys(cell, { "SlotTexture" }, key)
    -- `$parentNameFrame` 只有全域名字、沒有 parentKey（MerchantFrame.xml:13）
    E.NeutralizeGlobals({ key .. "NameFrame" })

    local btn = _G[key .. "ItemButton"]

    local ov = E.Overlay(cell, { key = key, inset = CELL_INSET, parent = btn })
    E.Paint(ov, T.fillInset, T.border)

    if btn then
        Skin.ItemButton(btn, key .. "ItemButton")
    else
        E.Missing(key .. "ItemButton")
    end
    return true
end

------------------------------------------------------------
-- 補掃格子
--
-- 格子數不是固定 12：套組內建的商人擴充插件會把 `MERCHANT_ITEMS_PER_PAGE` 調大
-- 並照那個數字補建 `MerchantItem13…N`。**那個全域只讀不寫。**
--
-- ⚠ `skinned` 只在「那一格真的存在」時才往前走 —— 全域已經調大但格子還沒建好的
--   那一幀不能把它記成處理過，否則那幾格永遠不會再回來。
-- ⚠ 這支會被兩支高頻後置勾呼叫，所以沒有新格子的時候只做兩次比較就返回。
------------------------------------------------------------
local skinned = 0

local function EnsureCells()
    local n = tonumber(_G.MERCHANT_ITEMS_PER_PAGE) or 0
    if n < STOCK_CELLS then n = STOCK_CELLS end
    if n <= skinned then return end
    for i = skinned + 1, n do
        if not SkinCell(i) then break end
        skinned = i
    end
end

------------------------------------------------------------
-- 底部那一條的圖示鈕（賣垃圾／修裝／修全部／公會修裝）
--
-- 出處：MerchantFrame.xml:187,220,280,318。四顆長得一模一樣：
--   BACKGROUND  一張**無名無 parentKey** 的 `UI-EmptySlot`（64x64）
--   BORDER      `Icon`（parentKey，atlas SpellIcon-256x256-*）
--   PushedTexture / HighlightTexture（**沒有** Normal／Disabled）
--
-- 所以 `Skin.IconButton` 在這裡沒有東西可做（它走的是 GetNormalTexture 系）。
-- 這支改成：無名底圖 ＋ Pushed 中和、Highlight 交給引擎、overlay 畫底與邊，
-- **`Icon` 完全不碰** —— 暴雪拿它的去飽和表示「不能修裝／沒有垃圾」，那是狀態。
--
-- （第五輪升格成 `Skin.SlotIconButton`，keep-set 與「Icon 不碰」的理由都搬進原語。）
------------------------------------------------------------

local SLOT_ICON_BUTTONS = {
    "MerchantSellAllJunkButton",
    "MerchantRepairAllButton",
    "MerchantRepairItemButton",
    "MerchantGuildBankRepairButton",
}

------------------------------------------------------------
-- 翻頁鈕
--
-- 跟收件匣的翻頁鈕同一套素材（UI-SpellbookIcon-*Page-*，32x32，箭頭只佔中間一小塊）
-- ⇒ 四邊各內縮 4，框才不會比箭頭大一圈。
-- 「上頁」「繼續」是按鈕自己 region 裡的**無名** FontString（MerchantFrame.xml:527,555），
-- 指名不到 ⇒ 走 `opts.labelColor`（`Engine.RecolorRegions`）。
-- 另外還有一張**無名**的 `UI-PageButton-Background`（:532,560）要中和，
-- 但 `GetRegions()` 會連 Normal/Pushed/Disabled/Highlight 一起掃到 ⇒ keep-set 要列全。
------------------------------------------------------------
local PAGE_BUTTON_KEEP_GETTERS = {
    "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
}

local function SkinPageButton(name)
    local btn = _G[name]
    if not btn then
        E.Missing(name)
        return
    end
    E.NeutralizeRegions(btn, name, E.KeepSet(btn, nil, PAGE_BUTTON_KEEP_GETTERS))
    Skin.IconButton(btn, name, { inset = 4, labelColor = T.text })
end

------------------------------------------------------------
-- 底部的金錢／貨幣列
--
-- `MerchantMoneyInset` 與 `MerchantExtraCurrencyInset` 是 `InsetFrameTemplate`
-- （MerchantFrame.xml:489,502，**useParentLevel="true"** ⇒ 它們的層級等於
--  MerchantFrame 的層級，overlay 會落在跟視窗 overlay 同一層 —— 配方順序是
--  「先視窗、後內嵌框」，後建的畫在上面）。
-- 兩條 `ThinGoldEdgeTemplate` 的金邊（:495,508）三張切片同樣**只有全域名字**，
-- 中和就好、不補 overlay：它們正好疊在上面那兩個 inset 上，那一層已經有底有邊了。
------------------------------------------------------------
local THIN_GOLD_EDGES = {
    "MerchantMoneyBgLeft", "MerchantMoneyBgMiddle", "MerchantMoneyBgRight",
    "MerchantExtraCurrencyBgLeft", "MerchantExtraCurrencyBgMiddle", "MerchantExtraCurrencyBgRight",
}

local function SkinBottomStrip()
    for _, name in ipairs(SLOT_ICON_BUTTONS) do
        local btn = _G[name]
        if btn then
            Skin.SlotIconButton(btn, name)
        else
            E.Missing(name)
        end
    end

    SkinPageButton("MerchantPrevPageButton")
    SkinPageButton("MerchantNextPageButton")

    -- 買回格（底部那一格「最近賣出」）：外層是 Frame（`MerchantBuyBackItem`），
    -- 物品鈕是它的 `ItemButton` 子框。底框跟商品格一致（內嵌底 ＋ 1px 邊、內縮 2）。
    -- ⚠ 這一格**不能**學商品格把 parent 掛在物品鈕上：
    --   `MerchantFrame_UpdateMerchantInfo`（MerchantFrame.lua:534-553）在「沒有
    --   可買回的東西」時只清掉圖示與名字、**不 Hide 那顆鈕**；真正被 Show／Hide 的是
    --   格子本身（`MerchantBuyBackItem:Show()`，同檔 :541）⇒ 掛在格子上就對了。
    local bb = _G.MerchantBuyBackItem
    if bb then
        E.NeutralizeKeys(bb, { "SlotTexture" }, "MerchantBuyBackItem")
        E.NeutralizeGlobals({ "MerchantBuyBackItemNameFrame" })
        local ov = E.Overlay(bb, { key = "MerchantBuyBackItem", inset = CELL_INSET })
        E.Paint(ov, T.fillInset, T.border)

        local btn = _G.MerchantBuyBackItemItemButton
        if btn then
            Skin.ItemButton(btn, "MerchantBuyBackItemItemButton")
        else
            E.Missing("MerchantBuyBackItemItemButton")
        end
    else
        E.Missing("MerchantBuyBackItem")
    end

    for _, name in ipairs({ "MerchantMoneyInset", "MerchantExtraCurrencyInset" }) do
        local inset = _G[name]
        if inset then
            Skin.Inset(inset, name)
        else
            E.Missing(name)
        end
    end
    E.NeutralizeGlobals(THIN_GOLD_EDGES)
end

------------------------------------------------------------
-- 兩支更新後置勾
--
-- 為什麼一定要有（不能只靠 Engine 那兩個 `SetItemButton*` 全域後置勾）：
-- 商品格的品質色走的是**方法** `ItemButton:SetItemButtonQuality`，不經過全域函式；
-- 而 `SetItemButtonTexture`（確實是全域）又跑在品質更新**之前** ⇒ 只靠引擎的話
-- 我們的品質方框永遠慢一件商品。詳見檔頭「查證後不一樣的第 1 件事」。
------------------------------------------------------------
local function RefreshCells()
    for i = 1, skinned do
        local key = "MerchantItem" .. i .. "ItemButton"
        local btn = _G[key]
        if btn then Skin.ItemButtonRefresh(btn, key) end
    end
end

local function OnMerchantInfo()
    if not MerchantShown() then return end
    EnsureCells()
    RefreshCells()
end

local function OnBuybackInfo()
    if not MerchantShown() then return end
    RefreshCells()
    local btn = _G.MerchantBuyBackItemItemButton
    if btn then Skin.ItemButtonRefresh(btn, "MerchantBuyBackItemItemButton") end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function InstallHooks()
    -- ⚠ 這一段**不過戰鬥閘**（Engine 的 RunUnit 在戰鬥閘之前跑它）。
    --   `hooksecurefunc` 不寫任何暴雪欄位，戰鬥中完全安全；被戰鬥閘擋的是「畫」。
    local function Hook(name, fn)
        if type(_G[name]) == "function" then
            hooksecurefunc(name, fn)
        else
            E.Missing(name)
        end
    end
    Hook("MerchantFrame_UpdateMerchantInfo", OnMerchantInfo)
    Hook("MerchantFrame_UpdateBuybackInfo", OnBuybackInfo)
end

local function Apply()
    local f = _G.MerchantFrame
    if not f then
        E.Missing("MerchantFrame")
        return
    end

    Skin.PortraitChrome(f, "MerchantFrame")
    Skin.Panel(f, "MerchantFrame")

    -- `MerchantFramePortrait` 是 PortraitContainer 之外的舊具名頭像貼圖（:95）；
    -- `BuybackBG` 是買回分頁才顯示的一整片白 a=.2 提亮（:101）；
    -- `MerchantFrameBottomLeftBorder` 是底部那條 334x61 的雕花（:118）——
    -- 那一條原本是用來框住修裝鈕與買回格的，換皮之後那些元件各自有底有邊，
    -- 不需要再多一層雕花。
    E.NeutralizeGlobals({
        "MerchantFramePortrait",
        "BuybackBG",
        "MerchantFrameBottomLeftBorder",
    })

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "MerchantFrame.Inset")
    else
        E.Missing("MerchantFrame.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "MerchantFrame.CloseButton")
    else
        E.Missing("MerchantFrame.CloseButton")
    end

    -- 「第 1 頁，共 3 頁」。GameFontNormal（暗金），暴雪只 SetFormattedText、
    -- 不重設顏色（.lua:273）⇒ 設一次就撐得住。
    E.TextColor(_G.MerchantPageText, T.text, "MerchantPageText")

    -- 底部兩顆分頁（商人／買回），PanelTabButtonTemplate。
    -- ⚠ 走 `Skin.TabGroup`：接縫錨在下一顆的左緣，相鄰兩顆共用一條 1px 黑線。
    local tabs = {}
    for i = 1, 2 do
        local key = "MerchantFrameTab" .. i
        local tab = _G[key]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = key }
        else
            E.Missing(key)
        end
    end
    Skin.TabGroup(tabs, { kind = "panel", joined = "TOP" })

    local dd
    if pcall(function() dd = f.FilterDropdown end) and dd then
        Skin.Dropdown(dd, "MerchantFrame.FilterDropdown", "style1")
    else
        E.Missing("MerchantFrame.FilterDropdown")
    end

    EnsureCells()
    SkinBottomStrip()
end

E.Register{
    key   = "merchant",
    addon = nil,                       -- MerchantFrame 住在 Blizzard_UIPanels_Game（LoadFirst）
    title = L["Merchant"],
    hooks = InstallHooks,
    apply = Apply,
    companions = {
        -- 格子數會被套組內建的商人擴充插件調大，而那支是在 PLAYER_LOGIN 才動手的
        -- ⇒ 開商人的時候再補掃一次（延一幀、冪等；沒有新格子就是兩次比較）。
        { event = "MERCHANT_SHOW", apply = EnsureCells },
    },
}
