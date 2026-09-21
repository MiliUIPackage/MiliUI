------------------------------------------------------------
-- 配方：冒險指南（EncounterJournal，隨需載入 Blizzard_EncounterJournal）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source，
-- Interface/AddOns/Blizzard_EncounterJournal/Mainline/）：
--   Blizzard_EncounterJournal.xml:1333  `EncounterJournal`
--     （**PortraitFrameTemplate**、toplevel、enableMouse、parent=UIParent）
--     :1340 `LootJournalViewDropdown`（WowStyle1DropdownTemplate）
--     :1346 `$parentSearchBox`（parentKey `searchBox`，SearchBoxListTemplate）
--     :1358 `$parentSearchResults`（`searchResults`，BottomPopupScrollBoxTemplate，
--           frameStrata DIALOG）
--     :1359 `$parentNavBar`（`navBar`，NavBarTemplate）＋ 五張內嵌邊框切片
--           （`InsetBorderBottomLeft/BottomRight/Bottom/Left/Right`，:1366-1388）
--     :1401 `$parentInset`（`inset`，InsetFrameTemplate，**useParentLevel**）
--     :1407 `$parentInstanceSelect`（`instanceSelect`，useParentLevel）
--       :1414 `$parentBG`（`bg`，UI-EJ-Cataclysm）、:1419 `evergreenBg`
--             （atlas activities-background）、:1426 `Title`
--       :1434 `ExpansionDropdown`、:1435 `GreatVaultButton`
--             （AlphaHighlightButtonTemplate ＋ NormalTexture/PushedTexture）
--       :1449 `ScrollBox`（WowScrollBoxList）、:1455 `ScrollBar`（MinimalScrollBar）
--     :1463 `$parentEncounterFrame`（`encounter`，useParentLevel）
--       :1469 `$parentInstanceFrame`（`instance`）→ :1476 `loreBG`、:1485 `title`、
--             :1493 `titleBG`、:1501 `$parentMapButton`、
--             :1553 `LoreScrollingFont`、:1562 `LoreScrollBar`
--       :1573 `$parentInfo`（`info`，useParentLevel）
--         :1580 **`$parentBG`（UI-EJ-JournalBG，785x425）** ＝整個書頁的羊皮紙
--         :1589,1594 `leftShadow` / `rightShadow`（UI-EJ-LeftPageHeader / Right）
--         :1601 `encounterTitle`、:1611 `difficultyIcon`、:1618 `instanceTitle`
--         :1628 `$parentInstanceButton`（`instanceButton`）
--         :1649,1679,1703,1733 `overviewTab` / `lootTab` / `bossTab` / `modelTab`
--             （都是 `EncounterTabTemplate`，各帶 `unselected` / `selected` 兩張圖）
--         :1761 `BossesScrollBox`、:1767 `BossesScrollBar`
--         :1773 `$parentDifficulty`（`difficulty`，WowStyle1DropdownTemplate）
--         :1778 `$parentDetailsScrollFrame`、:1816 `$parentOverviewScrollFrame`
--         :1875 `LootContainer`（frameStrata HIGH）→ `classClearFilter`、
--               :1944 `ScrollBox`、:1950 `ScrollBar`、:1956 `filter`、
--               :1957 `slotFilter`
--         :1969 `$parentModelFrame`（`model`，ModelScene）
--     :2054,2061,2068,2265 `MonthlyActivitiesFrame` / `JourneysFrame` /
--           `suggestFrame` / `TutorialsFrame`
--     :2316-2348 底部七顆分頁（`JourneysTab`／`MonthlyActivitiesTab`／
--           `suggestTab`／`dungeonsTab`／`raidsTab`／`LootJournalTab`／
--           `TutorialsTab`，全部是 `BottomEncounterTierTabTemplate`）
--   同檔 :1325 `BottomEncounterTierTabTemplate` **inherits PanelTabButtonTemplate**
--   同檔 :652  `EncounterTabTemplate`：NormalTexture `UI-EJ-Tab-UnSelected`、
--          PushedTexture `UI-EJ-Tab-Selected`、DisabledTexture、
--          HighlightTexture `UI-EJ-Tab-Highlight`（alphaMode ADD）
--   同檔 :1220 `EncounterItemTemplate`（mixin `EncounterJournalItemMixin`）：
--          `icon`、`bossTexture`（UI-EJ-DungeonLootFrame）、
--          `bosslessTexture`（UI-EJ-LootFrame）、`name`（GameFontNormalMed3）、
--          `armorType` / `slot` / `boss`（**GameFontBlack**）、
--          `IconBorder`（WhiteIconFrame）、`IconOverlay`、`IconOverlay2`
--   同檔 :583  `EncounterBossButtonTemplate`（mixin `EncounterBossButtonMixin`）：
--          `DefeatedOverlay`、`creature`、`text`
--   Blizzard_EncounterJournal.lua:192 `EncounterJournalItemMixin:Init`
--     :212,214,217,219,224-232 `slot` / `armorType` / `boss` **只走
--       SetText／SetFormattedText**（不重設字型物件、不 SetTextColor）
--     :207 `self.icon:SetTexture(...)`（⇒ texCoord 被打回，要放 reapply）
--     :236 **`SetItemButtonQuality(self, quality, itemInfo.link)`** ——
--       是**全域函式**，所以 `IconBorder` 每次更新都會被 `SetShown(true)` ＋ 重設材質
--   同檔 :268 `EncounterBossButtonMixin:Init`
--     :276-279 選中態走 **`LockHighlight()` / `UnlockHighlight()`**
--   同檔 :335 `view:SetElementInitializer("EncounterBossButtonTemplate", fn)`
--   同檔 :392,416 首領清單以外的**副本卡片**（`EncounterInstanceButtonTemplate`）
--     用的是一個 **local 的 `Initializer` 函式**，沒有 mixin 也沒有全域函式
--   同檔 :2231-2237 `info[data.button].selected:Show()` / `unselected:Hide()`
--     ⇒ 四顆頁籤鈕的選中態是**兩張圖的 Show/Hide**，不是 Pushed 貼圖
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的四件事
--
-- 1. **副本選擇頁的卡片接不到。** `EncounterInstanceButtonTemplate` 沒有 mixin，
--    它的初始化是 `EncounterJournal_OnLoad` 裡一個 **local 的 `Initializer`**
--    （.lua:392,416）—— 既不是 mixin 表也不是全域函式，`Engine.HookRows` 兩條路
--    都走不到，而唯一剩下的 `ScrollUtil.AddAcquiredFrameCallback` 是契約明文禁止的。
--    ⇒ 副本卡片這一輪**不做**（回報 ⑦）。那一頁只做外框級的東西
--    （Inset、捲軸、資料片下拉、標題），背景大圖照內容底材規則保留。
--
-- 2. **四顆頁籤鈕的選中態是兩張圖的 Show/Hide，不是 Pushed。**
--    模板上確實有 `PushedTexture`（.xml:655），但 `EJ_ContentTab_Select`
--    走的是 `info[data.button].selected:Show()` / `unselected:Hide()`（.lua:2231-2237）。
--    ⇒ 殼（Normal/Pushed/Disabled）可以整組中和，`selected` / `unselected`
--    **兩張都留著** —— 它們同時是「這顆是哪一頁」的識別與「選中了沒」的狀態。
--    ⚠ `unselected` 還被 `SetDesaturated(not enabled)`（.lua:2248）當停用訊號用。
--
-- 3. **首領清單的選中態讀不到，所以維持暴雪的語彙。**
--    `EncounterBossButtonMixin:Init`（.lua:276-279）用
--    `LockHighlight()` / `UnlockHighlight()` 表示選中，而判斷的依據是
--    `elementData.bossID`——**elementData 不准讀**（STYLE.md ③），
--    後置勾也拿不到「選中了沒」這個參數（對照成就分類列的
--    `UpdateSelectionState(selected)`）。
--    ⇒ 這一排**不走 `ownHover`**：Highlight 留著交給引擎換成白 8%，
--    選中的那一列（被 LockHighlight 鎖住）就是那個白 8%。
--    代價是「選中跟滑過長得一樣」——但那正是暴雪自己的語彙，
--    而且比「選中完全看不出來」好。
--
-- 4. **戰利品列的三條次要文字是 `GameFontBlack`，但它們的顏色接得住。**
--    `slot` / `armorType` / `boss` 在 `Init` 裡**只有 SetText／SetFormattedText**
--    （.lua:212-232），沒有任何一條路會重設字型物件或顏色
--    ⇒ 列底可以平面化。`SetTextColor` 仍然放進 reapply：
--    暴雪對「裝備不合手／不能穿」的那兩種會用
--    `INVALID_EQUIPMENT_COLOR:WrapTextInColorCode(...)` 把顏色**寫進字串裡**
--    （.lua:212,217），內嵌色碼蓋過 `SetTextColor` ⇒ 那個紅色警示自動留著。
--    **物品名（`name`）一根手指都不碰** —— 它是
--    `WrapTextInColorCode(itemInfo.name, itemInfo.itemQuality)`，品質色是資訊。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 視窗本體
--
-- | 物件 | 動作 |
-- |---|---|
-- | EncounterJournal 的 NineSlice / Bg / TopTileStreaks / PortraitContainer | SetAlpha(0) |
-- | EncounterJournal.TitleContainer.TitleText | SetTextColor |
-- | EncounterJournal | `Engine.RegionBackdrop`（面板底＋邊＋標題帶） |
-- | EncounterJournal.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | 同上的 Highlight/Pushed | SetColorTexture；overlay ＋ ×；`HookScript`（滑過） |
-- | EncounterJournal.inset 的 Bg / NineSlice | SetAlpha(0)；`Engine.RegionBackdrop` |
-- | EncounterJournal.navBar 的五張 InsetBorder* | SetAlpha(0) |
-- | EncounterJournal.searchBox 的 Left/Right/Middle | SetAlpha(0) |
-- | 同上的 searchIcon / Instructions | SetVertexColor / SetTextColor |
-- | 底部七顆分頁的 TabTextures（每顆九張） | SetAlpha(0) |
-- | 同七顆 | SetNormalFontObject；overlay；`HookScript`（滑過，`Skin.Tab`） |
-- | 四個下拉（LootJournalViewDropdown／ExpansionDropdown／difficulty／filter／slotFilter）的 Background | SetAlpha(0) |
-- | 同上的 Arrow | SetDesaturated ＋ SetVertexColor |
-- | 五條捲軸（instanceSelect／Bosses／Loot／Lore） | 走 `Skin.ScrollBar` |
--
-- ### 首領／戰利品頁
--
-- | 物件 | 動作 |
-- |---|---|
-- | 四顆 EncounterTabTemplate 的 Normal/Pushed/Disabled | SetAlpha(0) |
-- | 同四顆的 Highlight | SetColorTexture |
-- | 同四顆 | overlay（底 `fill` ＋ 1px 邊） |
-- | LootContainer | overlay（底 `fillInset` ＋ 1px 邊） |
-- | 首領列（池化）的 Normal/Pushed | SetAlpha(0)；Highlight → 白 8%；overlay 底 |
-- | 戰利品列（池化）的 bossTexture / bosslessTexture / IconBorder | SetAlpha(0) |
-- | 同上的 icon | SetTexCoord（reapply） |
-- | 同上的 slot / armorType / boss | SetTextColor（reapply） |
-- | 同上 | overlay（列底）＋ 圖示外一圈方框（前景，品質色靠 `Engine.PassBorderColor` 轉交） |
--
-- hook（全部是後置勾，不換函式）：
--   * `hooksecurefunc(EncounterJournalItemMixin, "Init", …)`（`Engine.HookRows`）
--   * `hooksecurefunc(EncounterBossButtonMixin, "Init", …)`（`Engine.HookRows`）
--   * Engine 的 `PanelTemplates_SelectTab / DeselectTab / SetDisabledTabState`
--     三個全域後置勾（裝在 Core/Engine.lua，全套組共用一組）
--   * Engine 的 `SetItemButtonQuality` / `SetItemButtonTexture` 兩個全域後置勾
--     （`Skin.ItemButtonRefresh` 的來源；戰利品列走的是 `SetItemButtonQuality`）
--   * 分頁與按鈕的 `HookScript("OnEnter"/"OnLeave")`（滑過態，住在原語裡）
--
-- 寫入暴雪欄位：無。寫入暴雪全域：無。
--
-- 讀暴雪物件（契約的讀取例外）：
--   * `ScrollBox:ForEachFrame`（`Engine.SweepRows` 的一次性補掃，唯讀走訪）。
--     ⚠ 第七輪穩定性規則 (a)：**不呼叫任何 `Update` / `FullUpdate` /
--       `SetDataProvider`** —— 我們不當「第一次 layout」的觸發者。
--   * 戰利品列 `IconBorder` 的 `IsShown()` / `GetVertexColor()` ——
--     走 `Engine.PassBorderColor`，當傳遞者不當讀取者。
--   `elementData` 的欄位一個都沒讀。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`$parentInfo` 的羊皮紙（`EncounterJournalEncounterFrameInfoBG`）與
--   技能說明區的整套字色。** 判準照 STYLE.md ③ 的內容底材規則：
--   換底就必須接住**所有**文字顏色路徑，而這一頁的文字散在
--   `EncounterInfoTemplate`（:762 的 `title` ＋ SimpleHTML `Text`）、
--   `EncounterOverviewBulletTemplate`（:722 的 SimpleHTML）、
--   `EncounterDescriptionTemplate`（:749）、`$parentDescription`（:1796）、
--   `$parentLoreDescription`（:1834）等十幾處，而且 SimpleHTML 的內文顏色
--   還會被暴雪的 `SetText` 連同 `<html>` 標籤一起重設。少接一條的症狀是
--   「某些段落在某些狀態下整段消失」—— 收益與風險完全不成比例。
--   ⇒ **羊皮紙保留，只做 chrome。** 戰利品清單另外處理（它坐在右半頁上，
--   但它自己的 `LootContainer` 是一個獨立的框，可以整塊給一個深色底）。
-- * **`encounterTitle` / `instanceTitle` / `$parentDescription` 等所有壓在
--   羊皮紙上的文字** —— 同上，它們是為羊皮紙設計的深色字。
-- * **`$parentModelFrame`（ModelScene）與 `creatureButtons`** ——
--   STYLE.md ③「3D 模型場景不碰」、⑦ B 級「場景本體與控制鈕不碰」。
-- * **副本選擇頁的卡片**（`EncounterInstanceButtonTemplate`）—— 見「不一樣的第 1 件事」。
-- * **`instanceSelect.bg` / `evergreenBg`** —— 那是副本選擇頁的背景大圖
--   （資料片插畫），內容底材規則「預設保留」。
-- * **`GreatVaultButton`** —— 它是一顆通往宏偉寶庫的按鈕
--   （`GreatVaultButtonMixin`，.xml:1435），整顆就是一張 atlas 美術
--   （`ui-journeys-greatvault-button`）。中和掉就變成一顆空白方塊。
-- * **搜尋結果彈出清單（`searchResults`）** —— `BottomPopupScrollBoxTemplate`，
--   frameStrata DIALOG 的彈出物，而且它的列同樣沒有 mixin。
-- * **`navBar` 的按鈕**（`NavBarTemplate` 的麵包屑）—— 執行期由物件池建立、
--   沒有 mixin 也沒有全域刷新函式。只中和它那五張內嵌邊框切片。
-- * **`MonthlyActivitiesFrame` / `JourneysFrame` / `suggestFrame` /
--   `TutorialsFrame`** —— 見回報 ⑦，這一輪沒做。
-- * **套組內建的冒險指南擴充插件** 掛在這個視窗上的元件：見下面的伴隨元件表。
--
------------------------------------------------------------
-- ## 伴隨元件（套組內建、固定掛在這個視窗上）
--
-- 規則照 STYLE.md ③「伴隨元件」：只認全域名稱、沒有就靜默跳過、
-- 不呼叫也不 hook 它的函式、不在它的框上寫欄位。
--
-- | 全域名 | 是什麼 | 這一輪怎麼處理 |
-- |---|---|---|
-- | `AGSCPanel` | 套組內建的冒險指南專精比較面板（BasicFrameTemplate） | **不處理**（見下） |
-- | `AGSCSpecDropdown` | 同上的專精下拉 | 不處理 |
-- | `AGSCShowShared` | 同上的勾選框 | 不處理 |
-- | `AGSCToggle` | 同上掛在 `EncounterJournal` 上的開關鈕 | 不處理 |
--
-- 為什麼這一輪不處理：那支插件**自己就是套組的自製插件**，它的面板已經是自己
-- 畫的深色底（不是暴雪的原生美術），套上這包的皮只會變成「兩層底」。
-- 它要對齊套組語彙的話應該改它自己那一份，不是從這裡蓋過去。
--
-- ⚠ **確認過：這一份的中和不會藏掉它加的東西。** 那支插件在戰利品列上掛的是
--   `hooksecurefunc(EncounterJournalItemMixin, "Init", …)` ＋ 一顆**以列為 parent**
--   的匿名 Button（它自己 `CreateFrame` 的），不是暴雪的 region
--   ⇒ `Engine.NeutralizeKeys` 指名中和的那三張（`bossTexture`／
--   `bosslessTexture`／`IconBorder`）碰不到它，而我們的列底 overlay 層級是
--   「列 − 1」、圖示方框是「+1」，兩層都在它那顆子框之下。
--   （這一份**沒有**用 `Engine.NeutralizeRegions` 去掃戰利品列 ——
--    那種全掃的寫法才會把別人加上去的 region 一起關掉。）
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 戰利品列（`EncounterItemTemplate`，`LootContainer.ScrollBox` 的 element）
--
-- apply（只跑一次）：兩張列底美術與圓角品質框中和、列底 overlay、
--   圖示外一圈直角方框（前景 slot）。
-- reapply（每次 Init 都跑）：
--   * `IconBorder` 重新中和 —— `SetItemButtonQuality`（全域，.lua:236）每次都
--     `SetShown(true)` ＋ 重設材質（`SetItemButtonBorder_Base`）。
--   * 品質色轉交到我們的方框（`Engine.PassBorderColor`，當傳遞者不當讀取者）。
--   * 圖示重裁 —— `self.icon:SetTexture(...)`（.lua:207）把 texCoord 打回 0,1。
--   * 三條次要文字重上色 —— 放 reapply 是保險（查證結果是 `Init` 只 SetText，
--     不重設顏色），成本只有三次 `SetTextColor`。
--
-- ⚠ **不用 `Skin.ItemButton`。** 那一支把品質方框畫成**整顆按鈕的矩形**，
--   而這裡的「按鈕」是一整條 345 寬的列、圖示只是左邊一小塊 ⇒ 會變成一圈
--   橫跨整列的品質色邊。改成把方框錨在 `icon` 這張貼圖上（`Skin.Icon`）。
-- ⚠ **不用 `Engine.NeutralizeRegions`**：那會連套組內建插件加在列上的東西
--   一起掃掉（見伴隨元件那一段）。指名中和三張就夠。
------------------------------------------------------------
local LOOT_ART = { "bossTexture", "bosslessTexture" }
local LOOT_DIM_TEXTS = { "slot", "armorType", "boss" }

local function LootIcon(row)
    local icon
    if pcall(function() icon = row.icon end) and type(icon) == "table" then return icon end
    return nil
end

local function LootApply(row)
    local key = "EncounterItem"

    -- 列底：`Skin.Row` 會把 Normal/Pushed 中和、Highlight 交給引擎（白 8%）。
    -- 隔行不分明暗：這一份的列高會在 45／64 之間跳（.lua:194,199），
    -- 用底色分行反而讓兩種高度看起來像兩種列。
    Skin.Row(row, key, { fill = T.fillInset, keys = LOOT_ART })

    -- 圓角品質框中和（一定要 alpha：每次更新都被 SetShown(true) ＋ 重設材質）
    E.NeutralizeKeys(row, { "IconBorder" }, key)

    local icon = LootIcon(row)
    if icon then
        Skin.Icon(icon, key .. ".icon")
    else
        E.Missing(key .. ".icon")
    end

    for _, field in ipairs(LOOT_DIM_TEXTS) do
        local fs
        if pcall(function() fs = row[field] end) and fs then
            E.TextColor(fs, T.textDim, key .. "." .. field)
        end
    end
end

local function LootReapply(row)
    local key = "EncounterItem"

    local border
    if pcall(function() border = row.IconBorder end) and border then
        E.Neutralize(border, key .. ".IconBorder")
    end

    local icon = LootIcon(row)
    if icon then
        E.CropIcon(icon, key .. ".icon")
        -- 品質色轉交給我們自己畫的那一圈方框（`Skin.Icon` 建的是前景 slot）
        E.PassBorderColor(E.GetOverlay(icon, "front"), border)
    end

    for _, field in ipairs(LOOT_DIM_TEXTS) do
        local fs
        if pcall(function() fs = row[field] end) and fs then
            E.TextColor(fs, T.textDim, key .. "." .. field)
        end
    end
end

------------------------------------------------------------
-- 首領列（`EncounterBossButtonTemplate`，`BossesScrollBox` 的 element）
--
-- ⚠ **不走 `ownHover`**（＝不自己畫選中態）。理由見檔頭「不一樣的第 3 件事」：
--   暴雪用 `LockHighlight()` 表示選中，而「選中了沒」只存在 `elementData` 裡
--   ——那是不准讀的。把 Highlight 中和掉就等於把選中態一起抹掉。
--   ⇒ Highlight 交給引擎換成白 8%，選中的那一列就是被鎖住的那個白 8%。
------------------------------------------------------------
local function BossApply(row)
    Skin.Row(row, "EncounterBossButton", { fill = T.fillInset })
end

------------------------------------------------------------
-- 四顆頁籤鈕（`EncounterTabTemplate`：綜覽／戰利品／首領技能／模型）
--
-- 殼是 Normal/Pushed/Disabled 三張 `UI-EJ-Tab-*`，整組中和；
-- `selected` / `unselected` 兩張圖**留著**（識別 ＋ 狀態 ＋ 停用的去飽和，
-- 檔頭「不一樣的第 2 件事」）。滑過交給引擎的 Highlight。
------------------------------------------------------------
local PAGE_TAB_KEYS = { "overviewTab", "lootTab", "bossTab", "modelTab" }
local PAGE_TAB_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }

local function SkinPageTab(info, key)
    local tab
    local label = "EncounterJournal.encounter.info." .. key
    if not (pcall(function() tab = info[key] end) and tab) then
        E.Missing(label)
        return
    end

    local ov = E.Overlay(tab, { key = label })
    if not ov then return end

    for _, getter in ipairs(PAGE_TAB_GETTERS) do
        if type(tab[getter]) == "function" then
            local ok, tex = pcall(tab[getter], tab)
            if ok and tex then E.Neutralize(tex, label .. "." .. getter) end
        end
    end
    E.ButtonStates(tab, label)
    E.Paint(ov, T.fill, T.border)
end

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Child(owner, key, label)
    local v
    if pcall(function() v = owner[key] end) and v then return v end
    E.Missing(label)
    return nil
end

local function SkinDropdown(owner, key, label)
    local dd = Child(owner, key, label)
    if dd then Skin.Dropdown(dd, label, "style1") end
end

local function SkinBar(owner, key, label)
    local bar = Child(owner, key, label)
    if bar then Skin.ScrollBar(bar, label) end
end

------------------------------------------------------------
-- 底部七顆分頁
--
-- `BottomEncounterTierTabTemplate` inherits `PanelTabButtonTemplate`（.xml:1325）
-- ⇒ `kind = "panel"`、`joined = "TOP"`（分頁掛在視窗下緣）。
-- ⚠ 相鄰兩顆的按鈕矩形**重疊 15**（每一顆都是 `LEFT → 前一顆 RIGHT, x = -15`，
--   .xml:2321,2326,…）⇒ `pad = 7`，讓 overlay 落在按鈕矩形的正中間
--   （同收藏視窗底部那六顆重疊 16 → pad 8 的算法）。
-- ⚠ 第七顆（`TutorialsTab`）**沒有全域名字**（.xml:2345 的 `<Button>` 沒有 name），
--   所以整排一律走 parentKey。
------------------------------------------------------------
local BOTTOM_TABS = {
    "JourneysTab", "MonthlyActivitiesTab", "suggestTab",
    "dungeonsTab", "raidsTab", "LootJournalTab", "TutorialsTab",
}
local BOTTOM_TAB_PAD = 7

------------------------------------------------------------
-- `navBar` 的五張內嵌邊框切片（.xml:1366-1388）
------------------------------------------------------------
local NAVBAR_BORDERS = {
    "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderBottom",
    "InsetBorderLeft", "InsetBorderRight",
}

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local lootSweeper, bossSweeper

local function InstallHooks()
    -- ⚠ 這一段**不過戰鬥閘**（`Engine.RunUnit` 把 hooks 排在戰鬥閘前面）。
    --   池化列的 mixin 後置勾一定要在這裡裝：晚一步，先建好的列就永遠追不上
    --   （陷阱 4）。冒險指南是隨需載入的，兩個 mixin 表在 `ADDON_LOADED`
    --   當下已經存在，而第一顆首領／戰利品列要等玩家點進副本才建 ⇒ 來得及。
    lootSweeper = E.HookRows{
        key     = "EncounterItem",
        mixin   = _G.EncounterJournalItemMixin,
        method  = "Init",
        apply   = LootApply,
        reapply = LootReapply,
        match   = function(row) return row and row.bosslessTexture ~= nil end,
    }
    bossSweeper = E.HookRows{
        key    = "EncounterBossButton",
        mixin  = _G.EncounterBossButtonMixin,
        method = "Init",
        apply  = BossApply,
        match  = function(row) return row and row.creature ~= nil end,
    }
end

local function Apply()
    local f = _G.EncounterJournal
    if not f then
        E.Missing("EncounterJournal")
        return
    end

    Skin.PortraitChrome(f, "EncounterJournal")
    Skin.Panel(f, "EncounterJournal")

    local close = Child(f, "CloseButton", "EncounterJournal.CloseButton")
    if close then Skin.CloseButton(close, "EncounterJournal.CloseButton") end

    local inset = Child(f, "inset", "EncounterJournal.inset")
    if inset then Skin.Inset(inset, "EncounterJournal.inset") end

    local navBar = Child(f, "navBar", "EncounterJournal.navBar")
    if navBar then E.NeutralizeKeys(navBar, NAVBAR_BORDERS, "EncounterJournal.navBar") end

    local search = Child(f, "searchBox", "EncounterJournal.searchBox")
    if search then Skin.EditBox(search, "EncounterJournal.searchBox") end

    SkinDropdown(f, "LootJournalViewDropdown", "EncounterJournal.LootJournalViewDropdown")

    ------------------------------------------------------------
    -- 副本選擇頁（只做外框級；背景大圖與卡片見檔頭）
    ------------------------------------------------------------
    local sel = Child(f, "instanceSelect", "EncounterJournal.instanceSelect")
    if sel then
        local title = Child(sel, "Title", "EncounterJournal.instanceSelect.Title")
        if title then E.TextColor(title, T.text, "EncounterJournal.instanceSelect.Title") end
        SkinDropdown(sel, "ExpansionDropdown", "EncounterJournal.instanceSelect.ExpansionDropdown")
        SkinBar(sel, "ScrollBar", "EncounterJournal.instanceSelect.ScrollBar")
    end

    ------------------------------------------------------------
    -- 首領／戰利品頁
    ------------------------------------------------------------
    local enc = Child(f, "encounter", "EncounterJournal.encounter")
    if not enc then return end

    local instance = Child(enc, "instance", "EncounterJournal.encounter.instance")
    if instance then
        SkinBar(instance, "LoreScrollBar", "EncounterJournal.encounter.instance.LoreScrollBar")
    end

    local info = Child(enc, "info", "EncounterJournal.encounter.info")
    if not info then return end

    for _, key in ipairs(PAGE_TAB_KEYS) do
        SkinPageTab(info, key)
    end

    SkinBar(info, "BossesScrollBar", "EncounterJournal.encounter.info.BossesScrollBar")
    SkinDropdown(info, "difficulty", "EncounterJournal.encounter.info.difficulty")

    local loot = Child(info, "LootContainer", "EncounterJournal.encounter.info.LootContainer")
    if loot then
        -- 戰利品清單整塊給一個深色底。它坐在羊皮紙的右半頁上，但它自己是一個
        -- 獨立的框（frameStrata HIGH，.xml:1875）⇒ 換掉它的底不必接管羊皮紙上
        -- 其他頁的字色，而列上那三條次要文字本來就在我們的接管範圍裡。
        local ov = E.Overlay(loot, { key = "EncounterJournal.encounter.info.LootContainer" })
        E.Paint(ov, T.fillInset, T.border)

        SkinBar(loot, "ScrollBar", "EncounterJournal.encounter.info.LootContainer.ScrollBar")
        SkinDropdown(loot, "filter", "EncounterJournal.encounter.info.LootContainer.filter")
        SkinDropdown(loot, "slotFilter", "EncounterJournal.encounter.info.LootContainer.slotFilter")

        -- 已經建立的列補掃一遍（`ForEachFrame`，唯讀）。
        -- ⚠ 第七輪穩定性規則 (a)：只走訪，不呼叫 Update／FullUpdate／SetDataProvider。
        E.SweepRows(Child(loot, "ScrollBox", "EncounterJournal.…LootContainer.ScrollBox"),
            "EncounterItem", lootSweeper)
    end

    E.SweepRows(Child(info, "BossesScrollBox", "EncounterJournal.encounter.info.BossesScrollBox"),
        "EncounterBossButton", bossSweeper)

    ------------------------------------------------------------
    -- 底部七顆分頁
    ------------------------------------------------------------
    local tabs = {}
    for _, key in ipairs(BOTTOM_TABS) do
        local tab
        if pcall(function() tab = f[key] end) and tab then
            tabs[#tabs + 1] = { tab = tab, key = "EncounterJournal." .. key }
        else
            E.Missing("EncounterJournal." .. key)
        end
    end
    Skin.TabGroup(tabs, { kind = "panel", joined = "TOP", pad = BOTTOM_TAB_PAD })
end

E.Register{
    key   = "encounterjournal",
    addon = "Blizzard_EncounterJournal",
    title = L["Adventure Guide"],
    hooks = InstallHooks,
    apply = Apply,
}
