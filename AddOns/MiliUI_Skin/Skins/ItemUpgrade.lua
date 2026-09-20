------------------------------------------------------------
-- 配方：物品升級（Blizzard_ItemUpgradeUI，隨需載入）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_ItemUpgradeUI/Blizzard_ItemUpgradeUI_Mainline.toc   `## LoadOnDemand: 1`
--   Blizzard_ItemUpgradeUI/Mainline/Blizzard_ItemUpgradeUI.xml:21,29
--     ItemUpgradeTooltipTemplate ← `SharedTooltipTemplate`；
--     ItemUpgradePreviewTemplate 再多四個純特效的子框
--     （`GlowNineSlice` / `GlowAnimatedPieces` / `GlowSheen` / `GlowMasks`，
--      全部由 `UpgradedAnim` 這個動畫組驅動 alpha）
--   同檔 :144  ItemUpgradeFrame（**PortraitFrameTemplate**，538x540，隨需載入）
--     :148,155,160,165,170  `BottomBG`（ItemUpgrade_BottomPanel）／`BottomPanel_Flash`／
--            `IdleGlow`／`Ring`／`LineMask`
--     :181,188  `BottomBGShadow`／`TopBG`（ItemUpgrade_TopPanel）
--     :195,200  `MicaFleckSheen`／`MicaFleckMask`
--     :210,218,226,227  `MissingDescription`（GRAY_FONT_COLOR）／`FrameErrorText`（紅）／
--            `LeftPreviewBigText`／`RightPreviewBigText`（GameFontHighlight，白）
--     :232  `UpgradeItemButton`（**ItemButton** intrinsic，58x58）＋ `EmptySlotGlow`
--            （動畫 `PulseEmptySlotGlow` 驅動）＋ `ButtonFrame`（atlas itemupgrade_slotborder）
--     :268  `ItemInfo`（**ResizeLayoutFrame**，所以 overlay 不可以掛上去 —— 陷阱 2）
--     :301  `ItemInfo.Dropdown`（WowStyle1DropdownTemplate）
--     :315,324,333  `LeftItemPreviewFrame`／`RightItemPreviewFrame`／`ItemHoverPreviewFrame`
--     :335  `Arrow`（ItemUpgrade_HelpTipArrow，動畫）
--     :358  `UpgradeButton`（UIPanelButtonTemplate ＋ TruncatedButtonTemplate ＋
--            DisabledTooltipButtonTemplate）＋ `Glow`（動畫）
--     :388,399  `UpgradeCostFrame`（CurrencyHorizontalLayoutFrameTemplate，
--            **layout host**）＋ `BGTex`（atlas ItemUpgrade_TotalCostBar）
--     :422  `$parentPlayerCurrenciesBorder`（**ThinGoldEdgeTemplate**）
--     :429  `PlayerCurrencies`（同樣是 layout host）
--   Blizzard_ItemUpgradeUI/Mainline/Blizzard_ItemUpgradeUI.lua:112,113,164,165,647
--     `SetItemButtonTexture(self.UpgradeItemButton, …)` 與
--     `SetItemButtonQuality(self.UpgradeItemButton, …)` —— **兩支都是全域函式**
--     ⇒ `Engine.TrackItemButton` 裝的兩個全域後置勾在這裡是有效的
--     （跟商人視窗相反，那邊走的是 ItemButtonMixin 的同名方法）
--   同檔全檔 **沒有任何一行 `SetTextColor`**（見下面的「內容底材」那一段）
--   Blizzard_SharedXML/SharedTooltipTemplates.xml:10,95,111
--     SharedTooltipArtTemplate → `NineSlice`（NineSlicePanelTemplate，useParentLevel）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:544,631
--     PortraitFrameBaseTemplate ← 只有 NineSlice / PortraitContainer / TitleContainer，
--     **沒有** Bg / TopTileStreaks / Inset（那三個是 ButtonFrameTemplate 才有的）
--   Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:1314  ThinGoldEdgeTemplate
--     （`$parentLeft`／`$parentMiddle`／`$parentRight`，**只有全域名字**）
--
------------------------------------------------------------
-- ## 內容底材：這個視窗破例走深色（判斷理由寫在這裡，要改回來只動一張表）
--
-- STYLE.md ③ 的預設是「內容底材保留」。這個視窗破例，理由跟成就視窗與信紙同一條：
-- 深灰外框裡包著兩整片金石雕花（`ItemUpgrade_TopPanel` / `_BottomPanel`）是整個
-- 視窗最不協調的地方，而且這一輪要做的「左右兩欄屬性預覽的背景雕花」與「費用列」
-- **就長在那兩片上** —— 只換那兩塊、留著底下的石板，會比兩邊都不動更亂。
--
-- 破例的代價是規則的後半段：**換底材就要連同上面所有文字顏色一起接管，而且要查清楚
-- 暴雪在哪些路徑重設那些顏色。** 這個視窗查出來的答案是「一條都沒有」：
--   * `Blizzard_ItemUpgradeUI.lua` **全檔沒有任何一行 `SetTextColor`**。
--   * 面板上的字全部由 XML 的字型物件決定，而且本來就是淺色：
--       `MissingDescription`  GameFontHighlightMedium ＋ GRAY_FONT_COLOR
--       `FrameErrorText`      GameFontHighlightMedium ＋ RED_FONT_COLOR（錯誤訊息）
--       `LeftPreviewBigText` / `RightPreviewBigText`   GameFontHighlight（白）
--       `ItemInfo` 那一組（MissingItemText／ItemName／UpgradeProgress／UpgradeTo）
--                             GameFontHighlight 系（白）
--       兩欄預覽是 **GameTooltip**，字色由提示系統自己管（本來就是深底淺字）
--   ⇒ 沒有東西需要接管，也沒有「某些狀態下整段消失」的風險。
--
-- **「中央的大圖／動畫特效」全部留著**：`IdleGlow`、`Ring`、`BottomPanel_Flash`、
-- `MicaFleckSheen` 與兩張遮罩、升級鈕的 `Glow`、物品槽的 `EmptySlotGlow`、
-- 兩欄預覽的四個 `Glow*` 子框、`Arrow`。那幾張的 alpha 本來就由動畫組在改
-- （`UpgradedFlash`／`PulseEmptySlotGlow`／`UpgradedAnim`），我們中和也擋不住，
-- 而且它們是這個視窗的身分。
--
-- ⚠ 要把石板底放回來只要把下面 `PANEL_ART` 那張表清空 —— 三個名字，其餘不用動。
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的三件事
--
-- 1. **物品槽走的是全域 `SetItemButtonQuality` / `SetItemButtonTexture`**（.lua:112,
--    113,164,165,647）⇒ `Engine.TrackItemButton` 的兩個全域後置勾在這個視窗是有效的，
--    這一份**不需要**自己掛重畫的後置勾。（商人視窗正好相反，那邊走的是
--    `ItemButtonMixin` 的同名方法，所以 Skins/Merchant.lua 得自己來。）
--
-- 2. **`ItemUpgradeFrame` 繼承 `PortraitFrameTemplate` 不是 `ButtonFrameTemplate`**
--    ⇒ 沒有 `Bg`／`TopTileStreaks`／`Inset`。直接套 `Skin.PortraitChrome` 會在
--    「找不到的區域」那張清單裡永遠留兩筆假的 —— 那張清單是給「這次改版暴雪改了
--    什麼」用的，所以這裡逐一點名，不走那支原語。
--
-- 3. **`ItemInfo` 與 `UpgradeCostFrame` / `PlayerCurrencies` 都是 layout host**
--    （ResizeLayoutFrame／CurrencyHorizontalLayoutFrameTemplate）⇒ overlay 不可以
--    parent 上去（陷阱 2）。`Engine.SafeParent` 會自己往上爬到 `ItemUpgradeFrame`，
--    錨點照樣錨在目標身上 —— 配方只要不硬指定 `opts.parent` 就好。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 物件 | 動作 |
-- |---|---|
-- | ItemUpgradeFrame 的 NineSlice / PortraitContainer | SetAlpha(0) |
-- | ItemUpgradeFrame.TitleContainer.TitleText | SetTextColor |
-- | ItemUpgradeFrame 的 TopBG / BottomBG / BottomBGShadow | SetAlpha(0) |
-- | ItemUpgradeFrameCloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | 同上的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | UpgradeItemButton 的 ButtonFrame（itemupgrade_slotborder） | SetAlpha(0) |
-- | UpgradeItemButton 的 IconBorder / NormalTexture | SetAlpha(0) |
-- | 同上的 icon | SetTexCoord；Highlight | SetColorTexture |
-- | 同上的 IconBorder | IsShown() / GetVertexColor()（**只轉交**，STYLE.md ③） |
-- | ItemInfo.Dropdown 的 Background | SetAlpha(0)；Arrow | SetVertexColor |
-- | UpgradeButton 的 Left/Right/Middle | SetAlpha(0) |
-- | 同上 | SetNormalFontObject(GameFontHighlight)；Highlight | SetColorTexture |
-- | UpgradeCostFrame.BGTex | SetAlpha(0) |
-- | ItemUpgradeFramePlayerCurrenciesBorder{Left,Middle,Right}（全域名） | SetAlpha(0) |
-- | Left/Right/ItemHoverPreviewFrame 的 NineSlice | SetAlpha(0) |
--
-- 以上各框：`CreateFrame` 掛自己的 overlay（錨在目標上、不吃滑鼠、零腳本）。
--
-- hook：**這一份自己一個都沒掛。** 物品槽靠 Engine 的
--   `SetItemButtonQuality` / `SetItemButtonTexture` 兩個全域後置勾（裝在
--   Core/Engine.lua，第一行查弱鍵表）。
--
-- 寫入暴雪欄位：無。
-- 讀暴雪物件：只有 `Engine.PassBorderColor` 那一條（`IconBorder` 的 `IsShown()` /
--   `GetVertexColor()`，**當傳遞者不當讀取者**）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **物品槽的腳本與拖曳流程** —— `ItemUpgradeSlotMixin` 的
--   `OnClick`／`OnDrag`／`OnReceiveDrag`（.xml:262-264）一個字都沒碰，
--   `Skin.ItemButton` 只做 SetAlpha／SetTexCoord／SetColorTexture ＋ 自己的 overlay。
-- * **「升級」按鈕的行為** —— 只做視覺。那顆鈕的 `OnClick` 走
--   `ItemUpgradeButtonMixin:OnClick`，我們沒有掛任何腳本、也沒有呼叫它。
-- * **所有動畫特效**（見上面「內容底材」那一段的清單）。
-- * **`MissingDescription`（灰）與 `FrameErrorText`（紅）** —— 顏色本身就是訊息。
-- * **費用／持有量的數字與貨幣圖示**（`UpgradeCostFrame` 與 `PlayerCurrencies`
--   底下的 `ItemUpgradeCostIconTemplate` / `ItemUpgradeCostQuantityTemplate`）—— 值。
-- * **套組內建的「升級預覽圖示」**（掛在左右兩欄預覽上的那兩顆圖示鈕）——
--   它們是**匿名框**，伴隨元件規則只認全域名稱 ⇒ 碰不到。不過它們是預覽框的
--   **子框**、層級比預覽框高，而我們的 overlay 走 target−1，**壓在它們之下**，
--   所以中和不會把它們藏掉。詳見回報 ⑤。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 兩片石板底 ＋ 它的陰影。
--
-- ⚠ **要把暴雪的底放回來就把這張表清空**，其餘一個字都不用動
--   （理由見檔頭「內容底材」那一段）。
------------------------------------------------------------
local PANEL_ART = { "TopBG", "BottomBG", "BottomBGShadow" }

-- 三個預覽框（左欄＝目前、右欄＝升級後、滑過時另外彈一個）
local PREVIEW_FRAMES = { "LeftItemPreviewFrame", "RightItemPreviewFrame", "ItemHoverPreviewFrame" }

-- ThinGoldEdgeTemplate 的三張切片只有全域名字、沒有 parentKey
local CURRENCY_EDGE_GLOBALS = {
    "ItemUpgradeFramePlayerCurrenciesBorderLeft",
    "ItemUpgradeFramePlayerCurrenciesBorderMiddle",
    "ItemUpgradeFramePlayerCurrenciesBorderRight",
}

------------------------------------------------------------
-- 一個預覽框（GameTooltip ← SharedTooltipTemplate）
--
-- 雕花全部收在 `NineSlice` 這個子框裡（SharedTooltipTemplates.xml:19），
-- 中和它再補一層我們自己的底與邊就好。四個 `Glow*` 子框不碰（動畫）。
------------------------------------------------------------
local function SkinPreview(frame, key)
    if not E.Usable(frame, key) then return end
    E.NeutralizeKeys(frame, { "NineSlice" }, key)
    local ov = E.Overlay(frame, { key = key })
    E.Paint(ov, T.fill, T.border)
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Apply()
    local f = _G.ItemUpgradeFrame
    if not f then
        E.Missing("ItemUpgradeFrame")
        return
    end

    -- ⚠ 不走 `Skin.PortraitChrome`：這個框是 `PortraitFrameTemplate`，沒有
    --   `Bg`／`TopTileStreaks`，那支會在 debug 清單裡留兩筆永遠不會出現的東西
    --   （見檔頭第 2 點）。
    E.NeutralizeKeys(f, { "NineSlice", "PortraitContainer" }, "ItemUpgradeFrame")
    local titleContainer
    if pcall(function() titleContainer = f.TitleContainer end) and titleContainer then
        local fs
        if pcall(function() fs = titleContainer.TitleText end) and fs then
            E.TextColor(fs, T.text, "ItemUpgradeFrame.TitleContainer.TitleText")
        end
    else
        E.Missing("ItemUpgradeFrame.TitleContainer")
    end

    E.NeutralizeKeys(f, PANEL_ART, "ItemUpgradeFrame")

    Skin.Panel(f, "ItemUpgradeFrame")

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "ItemUpgradeFrame.CloseButton")
    else
        E.Missing("ItemUpgradeFrame.CloseButton")
    end

    -- 物品槽。`ButtonFrame` 是它外圈那張 itemupgrade_slotborder 的雕花，
    -- `EmptySlotGlow` 留著（空槽時的呼吸光，由 `PulseEmptySlotGlow` 驅動）。
    local slot
    if pcall(function() slot = f.UpgradeItemButton end) and slot then
        E.NeutralizeKeys(slot, { "ButtonFrame" }, "ItemUpgradeFrame.UpgradeItemButton")
        Skin.ItemButton(slot, "ItemUpgradeFrame.UpgradeItemButton")
    else
        E.Missing("ItemUpgradeFrame.UpgradeItemButton")
    end

    -- 升級等級下拉。⚠ 它住在 `ItemInfo`（ResizeLayoutFrame）底下，但
    --   `Engine.SafeParent` 會自己往上爬過那一層（陷阱 2），配方不指定 parent。
    local info
    if pcall(function() info = f.ItemInfo end) and info then
        local dd
        if pcall(function() dd = info.Dropdown end) and dd then
            Skin.Dropdown(dd, "ItemUpgradeFrame.ItemInfo.Dropdown", "style1")
        else
            E.Missing("ItemUpgradeFrame.ItemInfo.Dropdown")
        end
    else
        E.Missing("ItemUpgradeFrame.ItemInfo")
    end

    -- 左右兩欄屬性預覽 ＋ 滑過時彈出的那一個
    for _, key in ipairs(PREVIEW_FRAMES) do
        local preview
        if pcall(function() preview = f[key] end) and preview then
            SkinPreview(preview, "ItemUpgradeFrame." .. key)
        else
            E.Missing("ItemUpgradeFrame." .. key)
        end
    end

    -- 「升級」按鈕。⚠ 只做視覺：`OnClick` 沒碰、也沒有呼叫任何升級 API。
    --   它是 `UIPanelButtonTemplate` ＋ `TruncatedButtonTemplate`，
    --   `Engine.ButtonFonts` 換的是同家族同字級的 `GameFontHighlight`，
    --   截字判斷的度量不變。
    local upgrade
    if pcall(function() upgrade = f.UpgradeButton end) and upgrade then
        Skin.Button(upgrade, "ItemUpgradeFrame.UpgradeButton")
    else
        E.Missing("ItemUpgradeFrame.UpgradeButton")
    end

    -- 費用列：中和那張 ItemUpgrade_TotalCostBar，補一塊內嵌色的底。
    local cost
    if pcall(function() cost = f.UpgradeCostFrame end) and cost then
        E.NeutralizeKeys(cost, { "BGTex" }, "ItemUpgradeFrame.UpgradeCostFrame")
        Skin.Panel(cost, "ItemUpgradeFrame.UpgradeCostFrame", { fill = T.fillInset })
    else
        E.Missing("ItemUpgradeFrame.UpgradeCostFrame")
    end

    -- 底部「你身上有多少」那一條：ThinGoldEdgeTemplate 的三張切片只有全域名字。
    E.NeutralizeGlobals(CURRENCY_EDGE_GLOBALS)
    local edge
    if pcall(function() edge = f.PlayerCurrenciesBorder end) and edge then
        Skin.Panel(edge, "ItemUpgradeFrame.PlayerCurrenciesBorder", { fill = T.fillInset })
    else
        E.Missing("ItemUpgradeFrame.PlayerCurrenciesBorder")
    end
end

E.Register{
    key   = "itemupgrade",
    addon = "Blizzard_ItemUpgradeUI",  -- `## LoadOnDemand: 1`
    title = L["Item Upgrade"],
    apply = Apply,
}
