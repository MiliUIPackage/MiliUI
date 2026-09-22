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
--     :1359 `$parentNavBar`（`navBar`，NavBarTemplate，500x34）＋ 五張內嵌邊框切片
--           （`InsetBorderBottomLeft/BottomRight/Bottom/Left/Right`，:1366-1388）
--     :1401 `$parentInset`（`inset`，InsetFrameTemplate，**useParentLevel**）
--     :1407 `$parentInstanceSelect`（`instanceSelect`，useParentLevel）
--       :1414 `$parentBG`（`bg`，UI-EJ-Cataclysm）、:1419 `evergreenBg`
--             （atlas activities-background）、:1426 `Title`
--       :1434 `ExpansionDropdown`、:1435 `GreatVaultButton`
--       :1449 `ScrollBox`（WowScrollBoxList）、:1455 `ScrollBar`（MinimalScrollBar）
--     :1463 `$parentEncounterFrame`（`encounter`，useParentLevel，錨 inset 內縮 3）
--       :1469 `$parentInstanceFrame`（`instance`，**390x425、BOTTOMRIGHT -1,2**
--             ＝ 右半頁）→ :1476 `loreBG`（副本插畫，390x330）、:1485 `title`、
--             :1493 `titleBG`、:1501 `$parentMapButton`、
--             :1553 `LoreScrollingFont`（KeyValue `fontName = GameFontBlack`）、
--             :1562 `LoreScrollBar`（`hideTrack = true`）
--       :1573 `$parentInfo`（`info`，**785x425、BOTTOMRIGHT -1,2**，useParentLevel）
--         :1580 **`$parentBG`**（全域名 `EncounterJournalEncounterFrameInfoBG`，
--               沒有 parentKey；`UI-EJ-JournalBG`，785x425，
--               TexCoords 0~0.766601562 / 0~0.830078125 ⇒ 原檔是 1024x512）
--         :1589,1594 `leftShadow` / `rightShadow`（UI-EJ-LeftPageHeader / Right，
--               BACKGROUND sublevel 3）
--         :1601 `encounterTitle`、:1618 `instanceTitle`（兩條都是
--               GameFontNormalLarge ＋ XML `<Color 0.902/0.788/0.671>`）
--         :1611 `difficultyIcon`、:1628 `$parentInstanceButton`（`instanceButton`）
--         :1649,1679,1703,1733 `overviewTab` / `lootTab` / `bossTab` / `modelTab`
--             （`EncounterTabTemplate`，id 1～4，各帶 `unselected` / `selected`；
--              :1651 第一顆錨 info 的 `TOPRIGHT x=-12`，其餘 `TOP → 上一顆 BOTTOM y=2`）
--         :1761 `BossesScrollBox`、:1767 `BossesScrollBar`（MinimalScrollBar）
--         :1773 `$parentDifficulty`（`difficulty`，WowStyle1DropdownTemplate）
--         :1778 `$parentDetailsScrollFrame`（`detailsScroll`）、
--         :1816 `$parentOverviewScrollFrame`（`overviewScroll`）——
--               兩個都是 ScrollFrameTemplate，**350x383、BOTTOMRIGHT -5,1**；
--               子框裡的字全部是 `GameFontBlack` ＋ `<Color 0.25/0.148/0.02>`（暗棕）
--         :1875 `LootContainer`（345x382，frameStrata HIGH）
--           :1881 `classClearFilter`（355x28，`BOTTOM → TOP x=-10 y=-27`；
--                 BACKGROUND 一張**無名**的 `UI-EJ-FilterBar`，`text` 是
--                 GameFontNormalSmall ＋ `<Color 0.973/0.902/0.581>`，
--                 子框一顆**無 parentKey** 的 `$parentExitButton`）
--           :1944 `ScrollBox`、:1950 `ScrollBar`、:1956 `filter`、:1957 `slotFilter`
--         :1969 `$parentModelFrame`（`model`，ModelScene ＋ 自己的 `dungeonBG` 與
--               `UI-EJ-BossModelPaperFrame`）
--     :2316-2348 底部七顆分頁（`BottomEncounterTierTabTemplate` inherits
--           `PanelTabButtonTemplate`，.xml:1325）
--   同檔 :652  `EncounterTabTemplate`（frameLevel 510，63x57）：Normal／Pushed／
--          Disabled 三張 `UI-EJ-Tab-*`，HighlightTexture `UI-EJ-Tab-Highlight`
--   同檔 :1220 `EncounterItemTemplate`（mixin `EncounterJournalItemMixin`）：
--          `icon`（BACKGROUND）、`bossTexture` / `bosslessTexture`（BORDER）、
--          `name`（GameFontNormalMed3）、`armorType` / `slot` / `boss`（**GameFontBlack**）、
--          `IconBorder`（WhiteIconFrame）、`IconOverlay`、`IconOverlay2`；
--          **沒有** Normal／Pushed／Highlight 狀態貼圖
--   同檔 :583  `EncounterBossButtonTemplate`（mixin `EncounterBossButtonMixin`）
--
--   Blizzard_EncounterJournal.lua:
--     :41-46 `EJ_Tabs`（local）：1=overviewScroll/overviewTab、2=LootContainer/lootTab、
--            3=detailsScroll/bossTab、4=model/modelTab（＝XML 的 id）
--     :192 `EncounterJournalItemMixin:Init`
--       :207 `self.icon:SetTexture(...)`（texCoord 被打回 ⇒ 重裁）
--       :212,214,217,219,224-232 `slot` / `armorType` / `boss` **只走 SetText／
--            SetFormattedText**；:212,217 不合手／不能穿用
--            `INVALID_EQUIPMENT_COLOR:WrapTextInColorCode(...)` 把紅色寫進字串
--       :236 **`SetItemButtonQuality(self, quality, itemInfo.link)`**（**全域**函式）
--     :268 `EncounterBossButtonMixin:Init`（:276-279 選中＝LockHighlight）
--     :305 `EncounterJournal_OnLoad`：:326 `overviewTab:Click()`（⇒ 初始頁籤是 1）、
--          :335 首領清單 initializer、:361 戰利品 factory、:425
--          `loreScrollingFont:SetTextColor(.13, .07, .01)`（副本簡介的字是暗棕）、
--          :452 `NavBar_Initialize(self.navBar, "NavButtonTemplate", …)`
--     :775 `EncounterJournal_OnShow` → :789 `EncounterJournal_LootUpdate()`
--     :1002 `EncounterJournal_OnEvent`：`EJ_LOOT_DATA_RECIEVED` → :1014
--           `EncounterJournal_LootUpdate()` —— **視窗沒開也會跑**（事件在 OnLoad 就註冊）
--     :1239 `EncounterJournal_DisplayInstance` → :1252 LootUpdate、:1323
--           `instance:Show()`、:1342 `NavBar_AddButton(EncounterJournal.navBar, …)`
--     :2225 **`EncounterJournal_SetTab(tabType)`**（全域）：四顆頁籤的
--           `selected:Show()` / `unselected:Hide()` ＋ `LockHighlight()`
--     :2278 **`EncounterJournal_LootUpdate()`**（全域）→ :2334 `scrollBox:SetDataProvider`
--     :2966 `EncounterJournal_UpdateFilterString` → :2982 `classClearFilter.text:SetText`
--           ＋ `Show`／`Hide`，:2985 ScrollBox 重錨到 `classClearFilter BOTTOMLEFT 14,7`
--
--   Blizzard_FrameXML/Mainline/NavigationBar.xml（NavBarTemplate／NavButtonTemplate）：
--     `NavBarTemplate`：BACKGROUND 一張**無名**的 `CS_HelpTextures_Tile` 橫條；
--       子框 `overlay`（OnLoad `SetFrameLevel(50)`，OVERLAY 一張**無名**的亮面條）；
--       `$parentOverflowButton`（`overflow`，DropdownButton 44x30，OnLoad `xoffset = -18`，
--       Normal／Pushed／Highlight `CS_HelpTextures`）；`$parentHomeButton`（`home`，
--       OnLoad `xoffset = -15`、寬 `min(128, 字寬+50)`，文字 `LEFT 10 / RIGHT -30`，
--       Normal／Pushed／Highlight ＋ 一張**無 parentKey** 的 `$parentLeft` 陰影）；
--       `KioskOverlay`（只有展示機模式）
--     `NavButtonTemplate`（80x30）：OVERLAY `arrowUp` / `arrowDown`（21x30，錨在按鈕
--       **RIGHT 的外側**）＋ `selected`；`MenuArrowButton`（DropdownButton 27x31，
--       `Art` 是 `SquareButtonTextures` 的小箭頭；Normal／Pushed 是 **alpha 0 的
--       `UI-SquareButton-*`，它自己的 OnEnter／OnLeave 會 `SetAlpha(1)`／`SetAlpha(0)`**）；
--       Normal／Pushed／Highlight `CS_HelpTextures*`；文字 `GameFontNormal`、`LEFT x=20`；
--       **沒有** DisabledFont
--   Blizzard_FrameXML/Mainline/NavigationBar.lua：
--     :5  `NavBar_Initialize`（home／overflow 用 XML 那兩顆）
--     :77 **`NavBar_AddButton(self, buttonData)`**（全域）—— 從 `freeButtons` 拿或
--         `CreateFrame("BUTTON", name.."Button"..n, self, self.template)`；
--         :123 寬 = 字寬 + 30（有下拉 +53）；:130 `NavBar_CheckLength`
--     :194 `NavBar_CheckLength`：:218 後一顆 `LEFT → 前一顆 RIGHT, 前一顆.xoffset or 0`；
--         :230,237 最後一顆 `Disable()`、其餘 `Enable()`；:228,233 `selected` Show／Hide
--
------------------------------------------------------------
-- ## 第九輪（使用者擷圖 57：「這頁怪怪的」）改了什麼
--
-- 1. **戰利品列沒上皮 ⇒ 兩條補救，一條診斷。**
--    查證結果：`HookRows`／`match`／`requireKnown` 的邏輯對得上原始碼，沒有 bug；
--    存檔裡的 `/mskin debug` 也沒有「hook 已停用」。同一張擷圖裡**首領列有皮、
--    戰利品列沒有** —— 兩者的差別是「誰建的列」：首領列只有玩家點進副本
--    （`DisplayInstance` → `SetDataProvider`）才會建；戰利品列除了視窗的 OnShow，
--    **`EJ_LOOT_DATA_RECIEVED` 也會走 `EncounterJournal_LootUpdate` →
--    `SetDataProvider`，視窗沒開也照跑**（.lua:1002-1014，事件在 OnLoad 就註冊了），
--    而套組裡有好幾支插件在登入時就把冒險指南載進來並查戰利品
--    （套組內建的角色筆記、專精比較、團隊減益、傳奇鑰石戰利品…）。
--    只要有一批列在「冒險指南載入 → 我們的 mixin 後置勾裝好」之間被建出來，
--    那批列身上就是**沒被勾的 Init 副本**（陷阱 4），而且之後永遠被物件池重用。
--    ⇒ 這一輪不再只靠 mixin 勾：
--    (a) **補掃**：`hooksecurefunc("EncounterJournal_LootUpdate", …)`，在暴雪自己的
--        `SetDataProvider` 之後 `ForEachFrame` 唯讀走一遍（見「補掃時機」）。
--        補掃接手的列（弱鍵表裡沒有紀錄 ＝ Init 沒經過我們的勾）記一筆進
--        `/mskin debug`，那就是這個假設的實機證據。
--    (b) **每次 Init 都要重申的那幾件事改走全域出口**：列登記進
--        `Engine.TrackItemButton`，由既有的 `SetItemButtonQuality` 全域後置勾
--        （.lua:236，Init 每次都會呼叫）重跑品質色轉交與圖示重裁 ——
--        全域函式不會被 mixin 拷走，所以「列的 Init 是不是被勾的副本」不再重要。
-- 2. **整個書頁深色化。** 羊皮紙（`$parentBG`）與兩張頁眉陰影 alpha 0，
--    `info` 走 `Engine.RegionBackdrop` 的 `fillInset`。字色逐條查過，見「書頁的字色」。
--    **接不住的三塊內容區保留原本的羊皮紙貼圖**（不是自己畫的假羊皮紙）：
--    綜覽頁、首領技能頁、副本簡介頁。
-- 3. **麵包屑平面化**（`NavBar_AddButton` 後置勾，只處理冒險指南那一條）。
-- 4. **四顆頁籤鈕貼著書頁**：左邊不畫邊、選中＝亮一階底 ＋ 朝外（右）一條職業色線
--    （`EncounterJournal_SetTab` 後置勾，讀的是**參數**）。
-- 5. 首領清單捲軸：**本來就走 `Skin.ScrollBar`**，粗是因為 6px 深色軌道壓在亮羊皮紙上；
--    書頁深色化之後自然融進去。副本簡介那條（`LoreScrollBar`）改成**不上皮** ——
--    它坐在保留下來的羊皮紙上，那裡就該是暴雪的原生捲軸。
-- 8. 職業過濾條平面化（`classClearFilter`）。
--
------------------------------------------------------------
-- ## 書頁的字色（內容底材規則的查證）
--
-- | 文字 | 在哪一塊底上 | 暴雪怎麼設顏色 | 處理 |
-- |---|---|---|---|
-- | `info.encounterTitle` / `instanceTitle` | 深色書頁 | XML `<Color>`；Lua **只有** `SetText`（.lua:1272,1364,2198）與 `SetPoint` | `SetTextColor(T.text)` 一次 |
-- | 首領列的文字 | 我們的 `fill` 列底 | 字型物件（GameFontNormalMed3 金、Disabled 白） | 不動（金字在深底上讀得出來） |
-- | 戰利品列 `slot` / `armorType` / `boss` | 列底 | 只 `SetText`（.lua:212-232） | `textDim`；紅色內嵌色碼自動留著 |
-- | 戰利品分類列「額外戰利品」 | LootContainer 深底 | GameFontNormalMed3（金） | 不動 |
-- | `classClearFilter.text` | 我們的 `fill` 條 | XML `<Color>`；Lua 只 `SetText`（.lua:2982） | `SetTextColor(T.text)` 一次 |
-- | 綜覽頁：`loreDescription`、`overviewDescription`（SimpleHTML）、動態的 `Bullets` | **保留的羊皮紙** | GameFontBlack 暗棕；SimpleHTML 每次 `SetText` 連 `<html>` 標籤一起重設 | **接不住** ⇒ 羊皮紙內嵌 |
-- | 首領技能頁：`description`、動態的 `EncounterInfoTemplate`（`title` 被 `SetTextColor(PAPER_FRAME_*_COLOR)` 切換，.lua:1538-1543）與它的 SimpleHTML | **保留的羊皮紙** | 同上，另有逐段的色碼 | **接不住** ⇒ 羊皮紙內嵌 |
-- | 副本簡介：`LoreScrollingFont` | **保留的羊皮紙** | OnLoad `SetTextColor(.13,.07,.01)`（.lua:425） | **接不住**（`ScrollingFont` 的字是它自己管的）⇒ 羊皮紙內嵌 |
-- | 模型頁 | 它自己的 `dungeonBG` ＋ 紙框 | — | 不碰（3D 模型場景） |
--
-- 羊皮紙內嵌的畫法：`Engine.RegionBackdrop`（建在那個頁面框自己身上 ⇒ 跟著那一頁
-- 顯示／隱藏、而且在它所有內容之下），底那張貼圖換成**原本那張** `UI-EJ-JournalBG`、
-- texCoord 照「那一塊在書頁上的位置」換算（`ParchmentUV`，常數全部從 XML 的尺寸
-- 與錨點抄），外加一圈 1px 黑邊 ⇒ 看起來是深色書頁上鑲著一塊原本的書頁。
-- `-- TODO(升格)`：「RegionBackdrop 的底換成一張貼圖」第二個視窗用到時搬進 Engine。
--
------------------------------------------------------------
-- ## 補掃時機（第七輪穩定性規則 (a)）
--
-- 選 **`hooksecurefunc("EncounterJournal_LootUpdate", …)` ＋ 唯讀 `ForEachFrame`**：
--   * 它是全域函式，勾它**不在暴雪框上寫欄位**。任務說明提的
--     `LootContainer.ScrollBox` 的 `Update` 後置勾 ＝ `hooksecurefunc(scrollBox, "Update")`
--     ＝ 在 ScrollBox 身上寫一個 `Update` 欄位（同 STYLE.md ⑦「不准勾
--     `ProfessionsFrame.SetTab`」那一條），契約禁止。
--   * 它是**所有**建列路徑的共同出口：視窗 OnShow（.lua:789）、`EJ_LOOT_DATA_RECIEVED`
--     （:1014，**包括視窗沒開的時候**）、點進副本／首領（:1252,1361）、篩選（:2448,2948）。
--     「LootContainer 第一次 OnShow 之後延一幀」那條只接得到第一種，
--     而上面的假設正好是「視窗沒開時就建好的列」。
--   * 我們跑在它**最後一行**（`scrollBox:SetDataProvider`，:2334）之後 ⇒
--     我們**不是** layout 的觸發者，只是事後唯讀走訪。
--     不呼叫 Update／FullUpdate／SetDataProvider，不讀 elementData。
--   * 順手把首領清單也補掃一次（同一個掛點、不多一支 hook）。
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
-- | EncounterJournal.searchBox 的 Left/Right/Middle | SetAlpha(0) |
-- | 同上的 searchIcon / Instructions | SetVertexColor / SetTextColor |
-- | 底部七顆分頁的 TabTextures（每顆九張） | SetAlpha(0) |
-- | 同七顆 | SetNormalFontObject；overlay；`HookScript`（滑過，`Skin.Tab`） |
-- | 五個下拉（LootJournalViewDropdown／ExpansionDropdown／difficulty／filter／slotFilter）的 Background | SetAlpha(0) |
-- | 同上的 Arrow | SetDesaturated ＋ SetVertexColor |
-- | 三條捲軸（instanceSelect／Bosses／Loot） | 走 `Skin.ScrollBar` |
--
-- ### 麵包屑（`EncounterJournal.navBar`，第九輪）
--
-- | 物件 | 動作 |
-- |---|---|
-- | navBar 自己的 region（無名橫條 ＋ 五張 InsetBorder*） | SetAlpha(0)（`NeutralizeRegions`） |
-- | navBar.overlay 的 region（無名亮面條） | SetAlpha(0) |
-- | navBar | `Engine.RegionBackdrop`（`fillInset` ＋ 1px 邊） |
-- | home／overflow／每顆 NavButton 的 region（Normal／Pushed／Highlight／arrowUp／arrowDown／selected／`$parentLeft`） | SetAlpha(0)（`NeutralizeRegions`） |
-- | 同上的按鈕 | SetNormalFontObject(GameFontHighlight)；overlay（底 ＋ 邊 ＋ › 圖記）；`HookScript` OnEnter/OnLeave（滑過）、OnEnable/OnDisable（圖記三態） |
-- | NavButton.MenuArrowButton 的 `Art` / Highlight | SetAlpha(0) |
-- | 同上的 Normal／Pushed（**它自己的 OnEnter 會 `SetAlpha(1)`**） | **SetVertexColor(1,1,1,0)**（見回報 ④） |
-- | 同上 | overlay（⌄ 圖記）；`HookScript` OnEnter/OnLeave |
--
-- ### 首領／戰利品頁
--
-- | 物件 | 動作 |
-- |---|---|
-- | `EncounterJournalEncounterFrameInfoBG`（全域名）、info.leftShadow / rightShadow | SetAlpha(0) |
-- | info | `Engine.RegionBackdrop`（`fillInset`，無邊） |
-- | info.encounterTitle / instanceTitle | SetTextColor |
-- | info.overviewScroll / detailsScroll / encounter.instance | `Engine.RegionBackdrop`（羊皮紙內嵌）；**我們自己那張底貼圖**的 SetTexture ＋ SetTexCoord |
-- | 四顆 EncounterTabTemplate 的 Normal/Pushed/Disabled/Highlight | SetAlpha(0) |
-- | 同四顆 | overlay（底 ＋ 三邊 ＋ 右緣職業色線）；`HookScript` OnEnter/OnLeave |
-- | LootContainer | overlay（底 `fillInset` ＋ 1px 邊） |
-- | classClearFilter 的 region（無名 UI-EJ-FilterBar） | SetAlpha(0) |
-- | classClearFilter | `Engine.RegionBackdrop`（`fill` ＋ 1px 邊） |
-- | classClearFilter.text | SetTextColor |
-- | 首領列（池化）的 Normal/Pushed | SetAlpha(0)；Highlight → 白 8%；overlay 底 |
-- | 戰利品列（池化）的 bossTexture / bosslessTexture / IconBorder | SetAlpha(0) |
-- | 同上的 icon | SetTexCoord（每次 Init） |
-- | 同上的 slot / armorType / boss | SetTextColor |
-- | 同上 | overlay（列底）＋ 圖示外一圈方框（前景 slot，品質色靠 `Engine.PassBorderColor` 轉交） |
--
-- hook（全部是後置勾，不換函式）：
--   * `hooksecurefunc(EncounterJournalItemMixin, "Init", …)`（`Engine.HookRows`）
--   * `hooksecurefunc(EncounterBossButtonMixin, "Init", …)`（`Engine.HookRows`）
--   * **第九輪新增三支全域後置勾**（理由各寫在 `InstallHooks`）：
--       `EncounterJournal_LootUpdate`（補掃）、`NavBar_AddButton`（新的麵包屑）、
--       `EncounterJournal_SetTab`（頁籤選中態）
--   * Engine 的 `PanelTemplates_SelectTab / DeselectTab / SetDisabledTabState`
--     三個全域後置勾（裝在 Core/Engine.lua，全套組共用一組）
--   * Engine 的 `SetItemButtonQuality` / `SetItemButtonTexture` 兩個全域後置勾
--     （**第九輪起戰利品列也登記進去**，`Engine.TrackItemButton`）
--   * 分頁、按鈕、頁籤、麵包屑的 `HookScript("OnEnter"/"OnLeave"/"OnEnable"/"OnDisable")`
--     （住在原語 / Engine 裡，只碰我們自己的 overlay）
--
-- 寫入暴雪欄位：無。寫入暴雪全域：無。
--
-- 讀暴雪物件（契約的讀取例外）：
--   * `ScrollBox:ForEachFrame`（`Engine.SweepRows`，唯讀走訪）。
--   * `GetRegions` / `GetChildren`（找無名的美術區域、找 navBar 底下的按鈕、
--     找 classClearFilter 的關閉鈕）—— 讀結構不是讀值。
--   * 戰利品列 `IconBorder` 的 `IsShown()` / `GetVertexColor()` ——
--     走 `Engine.PassBorderColor`，當傳遞者不當讀取者。
--   * 麵包屑按鈕的 `IsEnabled()`（`Engine.TrackGlyph` 的 `trackEnabled`，讀取例外表
--     上那一條）：最後一顆（＝目前這一頁）被暴雪 `Disable()`，它後面的 › 就收掉。
--   * `EncounterJournal_SetTab` 的**參數** `tabType`（過 `Secret.IsSecret`）。
--   `elementData` 的欄位一個都沒讀；`navList`／`info.tab` 這些暴雪欄位也沒讀。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **綜覽頁、首領技能頁、副本簡介頁的內文顏色** —— 見「書頁的字色」：SimpleHTML
--   與 `ScrollingFont` 的顏色是逐段／由它自己管的，少接一條就是「某一段在某個狀態下
--   整段消失」。那三塊保留原本的羊皮紙。它們的捲軸（ScrollFrameTemplate 的
--   `ScrollBar`、`LoreScrollBar`）也維持原生，坐在羊皮紙上本來就該長那樣。
-- * **`$parentModelFrame`（ModelScene）與它的背景、`creatureButtons`** ——
--   STYLE.md ③「3D 模型場景不碰」。
-- * **`instanceButton`**（書頁左上的圓形副本圖示）—— 整顆就是一張圓框美術
--   （`UI-EJ-BossModelButton`），中和掉就只剩一張沒有框的圖。
-- * **副本選擇頁的卡片**（`EncounterInstanceButtonTemplate`）—— 初始化是
--   `EncounterJournal_OnLoad` 裡一個 **local 的 `Initializer`**（.lua:392,416），
--   沒有 mixin 也沒有全域函式，唯一的路 `ScrollUtil.AddAcquiredFrameCallback`
--   是契約禁止的。
-- * **`instanceSelect.bg` / `evergreenBg`** —— 副本選擇頁的背景大圖，而且
--   `evergreenBg` 同時是教學說明頁的內容背景。內容底材規則「預設保留」。
-- * **`GreatVaultButton`** —— 整顆就是一張 atlas 美術。
-- * **搜尋結果彈出清單（`searchResults`）** —— DIALOG strata 的彈出物，列沒有 mixin。
-- * **麵包屑按鈕的「目前這一頁」標示（`selected` 那張光暈）** —— 中和掉了、沒有另外畫：
--   它被 `NavBar_CheckLength` 用 Lua `Show`／`Hide`（不是 C 端狀態貼圖），
--   `SetColorTexture` 不在它的白名單裡；而目前這一頁本來就是**停用**的
--   （沒有滑過回饋、後面沒有 ›），那已經是足夠的訊號。
-- * **戰利品分類列（`EncounterItemDividerTemplate`，「額外戰利品」）** —— 金字在
--   深底上讀得出來，為了把它改白要多勾一支 mixin，不划算。
-- * **`classClearFilter` 的 ⊗ 關閉鈕** —— 那張 `ClearBroadcastIcon` 本來就是灰白色的，
--   而且它自己的 OnEnter／OnLeave 在切 alpha，中和不了。原樣留著。
-- * **`MonthlyActivitiesFrame` / `JourneysFrame` / `suggestFrame` /
--   `TutorialsFrame`** —— 這一輪沒做。
-- * **套組內建的冒險指南擴充插件** 掛在這個視窗上的元件：見下面的伴隨元件表。
--
------------------------------------------------------------
-- ## 伴隨元件（套組內建、固定掛在這個視窗上）
--
-- | 全域名 | 是什麼 | 這一輪怎麼處理 |
-- |---|---|---|
-- | `AGSCPanel` / `AGSCSpecDropdown` / `AGSCShowShared` / `AGSCToggle` | 套組內建的冒險指南專精比較（面板、下拉、勾選框、視窗右上方的開關鈕） | **不處理**：它自己就是套組的自製插件，面板本來就是自己畫的深色底，再套一層只會變成兩層底 |
-- | `RaiderIO_TalentBuildsEncounterJournalShortcut` | 套組內建的傳奇鑰石檔案插件放在難度下拉上方的「天賦版本」鈕 | `ThirdParty/RaiderIO.lua` 套 `Skin.Button`；**位置不動**（見那一支的檔頭） |
--
-- ⚠ **確認過：這一份的中和不會藏掉別人加在戰利品列上的東西。**
--   專精比較掛在列上的是一顆**以列為 parent** 的自建 Button（層級 列 +2）、
--   物品等級插件是一個以列為 parent、層級 110 的自建框 —— 都不是暴雪的 region。
--   我們對戰利品列只 `NeutralizeKeys` 指名的三張（`bossTexture`／`bosslessTexture`／
--   `IconBorder`），**不**對列跑 `Engine.NeutralizeRegions`；列底 overlay 是「列 − 1」、
--   圖示方框是「列 + 1」，兩層都在那兩個框之下。
--   （麵包屑按鈕與 `classClearFilter` 有跑 `NeutralizeRegions`，但它們上面沒有別家的東西。）
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L
local S = ns.Secret

local TRANSPARENT = { 0, 0, 0, 0 }

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Child(owner, key, label)
    local v
    if pcall(function() v = owner[key] end) and v then return v end
    E.Missing(label)
    return nil
end

-- 探得到就回，探不到**不記** missing（給「本來就可能沒有」的東西用）
local function Probe(owner, key)
    local v
    if type(owner) == "table" and pcall(function() v = owner[key] end) then return v end
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

-- hook 的共同包裝：pcall、出錯一次就停用並記進 `/mskin debug` 的「hook 已停用」
-- （同 `Engine.HookRows` 的紀律：捲動／點擊一次報一百發比少一塊皮嚴重得多）。
local function Guard(label, fn)
    local broken = false
    return function(...)
        if broken then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            broken = true
            E.NoteBrokenHook(label)
            ns.ReportError(err)
        end
    end
end

------------------------------------------------------------
-- 戰利品列（`EncounterItemTemplate`，`LootContainer.ScrollBox` 的 element）
--
-- apply（每一列只跑一次）：兩張列底美術與圓角品質框中和、列底 overlay、
--   圖示外一圈直角方框、三條次要文字降成 `textDim`、登記進 `Engine.TrackItemButton`。
-- 每次 Init 都要重申的（**兩條路都會跑到**，冪等）：
--   * `IconBorder` 重新中和（`SetItemButtonQuality` 每次都 `SetShown(true)` ＋ 重設材質）
--   * 品質色轉交到我們的方框（`Engine.PassBorderColor`）
--   * 圖示重裁（`self.icon:SetTexture(...)`，.lua:207，把 texCoord 打回 0,1）
--   路 1：mixin 後置勾的 reapply（列是在勾裝好之後建的）；
--   路 2：`Skin.ItemButtonRefresh`，由 Engine 的 `SetItemButtonQuality` 全域後置勾觸發
--        —— **不管這一列的 Init 是不是被勾的副本都會跑**（見檔頭第 1 條）。
--
-- ⚠ 不用 `Skin.ItemButton`：它把品質方框畫成**整顆按鈕的矩形**，而這裡的
--   「按鈕」是一整條 321 寬的列。方框改成錨在 `icon` 這張貼圖上（`anchorTo`），
--   但 target 是**列**、slot 是 `front` —— 這樣 `Skin.ItemButtonRefresh` 用
--   `E.GetOverlay(row, "front")` 找得到它，而且層級相對列（+1）。
-- ⚠ 不用 `Engine.NeutralizeRegions`：那會連套組內建插件加在列上的東西一起掃掉。
--
-- 列與列之間留 1 點縫：overlay 照「上下各內縮 1」畫（同好友名單三種列的作法，
-- STYLE.md ④「清單列的 overlay 要照抄暴雪那張色帶的矩形」）—— 這個 ScrollBox 沒有
-- spacing，不留縫的話整張清單會是一塊實心的灰。
------------------------------------------------------------
local LOOT_KEY = "EncounterItem"
local LOOT_ART = { "bossTexture", "bosslessTexture" }
local LOOT_DIM_TEXTS = { "slot", "armorType", "boss" }
local ROW_POINTS = {
    { "TOPLEFT", "TOPLEFT", 0, -1 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 1 },
}

local function IsLootRow(row)
    return Probe(row, "bosslessTexture") ~= nil
end

local function LootApply(row)
    -- 列底：`Skin.Row` 會把 Normal/Pushed 中和、Highlight 交給引擎（這個模板三張都沒有，
    -- 所以實際上只有底）。底用 `fill`：它坐在 `fillInset` 的 LootContainer 上，
    -- 控件要比內嵌框亮一階（面板 fill → 內嵌 fillInset → 控件）。
    -- 隔行不分明暗：列高會在 45／64 之間跳（.lua:194,199），用底色分行反而讓兩種
    -- 高度看起來像兩種列。
    Skin.Row(row, LOOT_KEY, { fill = T.fill, keys = LOOT_ART, points = ROW_POINTS })

    -- 圓角品質框中和（一定要 alpha：每次更新都被 SetShown(true) ＋ 重設材質）
    local border = Probe(row, "IconBorder")
    E.NeutralizeKeys(row, { "IconBorder" }, LOOT_KEY)

    local icon = Probe(row, "icon")
    if type(icon) == "table" then
        E.CropIcon(icon, LOOT_KEY .. ".icon")
        local ov = E.Overlay(row, {
            key = LOOT_KEY .. ".quality",
            slot = "front",
            levelOffset = 1,
            anchorTo = icon,
            borderSize = T.itemBorderSize,
        })
        E.Paint(ov, TRANSPARENT, T.border)
        E.PassBorderColor(ov, border)
    else
        E.Missing(LOOT_KEY .. ".icon")
    end

    for _, field in ipairs(LOOT_DIM_TEXTS) do
        local fs = Probe(row, field)
        if fs then
            E.TextColor(fs, T.textDim, LOOT_KEY .. "." .. field)
        else
            E.Missing(LOOT_KEY .. "." .. field)
        end
    end

    -- 路 2：之後每一次 `SetItemButtonQuality(row, …)` 都會回到 `Skin.ItemButtonRefresh`
    E.TrackItemButton(row, LOOT_KEY)
end

local function LootReapply(row)
    -- 路 1。跟路 2 做的是同一件事（`Skin.ItemButtonRefresh` 本身冪等）；
    -- 留著是因為「取不到物品資訊」那一支（.lua:237-243）不會呼叫 `SetItemButtonQuality`，
    -- 問號圖示的裁邊只有這裡補得到。
    Skin.ItemButtonRefresh(row, LOOT_KEY)
end

------------------------------------------------------------
-- 首領列（`EncounterBossButtonTemplate`，`BossesScrollBox` 的 element）
--
-- ⚠ **不走 `ownHover`**：暴雪用 `LockHighlight()` 表示選中，而「選中了沒」只存在
--   `elementData` 裡 —— 那是不准讀的。Highlight 交給引擎換成白 8%，
--   選中的那一列就是被鎖住的那個白 8%。
-- 底用 `fill`（第九輪從 `fillInset` 改）：書頁本身深色化成 `fillInset` 之後，
-- 列要比頁面亮一階才看得出是一列。
------------------------------------------------------------
local function IsBossRow(row)
    return Probe(row, "creature") ~= nil
end

local function BossApply(row)
    Skin.Row(row, "EncounterBossButton", { fill = T.fill })
end

------------------------------------------------------------
-- 四顆頁籤鈕（`EncounterTabTemplate`：綜覽／戰利品／首領技能／模型）
--
-- 它們從書頁的右緣**伸出去**（第一顆錨 info 的 `TOPRIGHT x=-12`，.xml:1651），
-- 所以畫成「掛在書頁邊上的分頁」，跟底部分頁同一套語彙、轉 90°：
--   * overlay 從按鈕的 x=12 開始（＝書頁右緣，那 12 點是壓在書頁上的部分），
--     **左邊不畫邊**（跟內容相連的那一邊不畫，feedback-ui-visual-style）；
--   * 閒置 `fill`／滑過 `fillHover`／選中 `fillSelected` ＋ **朝外那一邊（右）
--     2px 職業色線**（`T.tabStyle = "underline"` 的語彙）；
--   * 相鄰兩顆重疊 2（`TOP → BOTTOM y=2`）⇒ 每顆的下緣往上收 1，
--     上一顆的底邊跟下一顆的頂邊落在同一排像素上，接縫只有一條線。
--     ⚠ 不用「最後一顆才畫底邊」那種寫法：`DisplayInstance` 會把首領技能那顆
--       藏掉、把模型那顆重錨到戰利品下面（.lua:1318-1319），哪一顆是最後一顆會變。
--
-- 選中態：暴雪是 `selected:Show()` ＋ `LockHighlight()`（.lua:2229-2238）。
--   * 「錨在 `selected` 貼圖上的線」這條零讀取的路**走不通**：錨點不會傳遞顯示／隱藏，
--     錨在一張藏起來的貼圖上的東西照樣畫得出來；而 `selected` 是 Lua `Show`／`Hide`
--     的一般貼圖，`SetColorTexture` 不在它的白名單裡。
--   * 所以走 `EncounterJournal_SetTab(tabType)` 的**全域後置勾，只讀參數**
--     （讀取例外表的「後置勾拿到的參數」），跟 XML 的 id（＝`EJ_Tabs` 的鍵）比對。
--   * `selected` / `unselected` 兩張圖**留著**：它們是「這顆是哪一頁」的識別，
--     而且 `unselected` 被 `SetDesaturated(not enabled)`（.lua:2248）當停用訊號用。
--   * Highlight 中和：選中改由我們畫，`LockHighlight` 的那層白就不要了
--     （不然選中＝滑過＝白 8%，跟我們的選中底疊在一起）。
------------------------------------------------------------
local PAGE_TABS = {
    { key = "overviewTab", id = 1 },
    { key = "lootTab",     id = 2 },
    { key = "bossTab",     id = 3 },
    { key = "modelTab",    id = 4 },
}
-- `EncounterJournal_OnLoad` 的 `overviewTab:Click()`（.lua:326）⇒ 載入時選中的是 1。
-- 那一下發生在我們的勾裝好之前，所以初始值只能照原始碼抄，不讀 `info.tab`。
local PAGE_TAB_INITIAL = 1
local PAGE_TAB_BOOK_OVERLAP = 12      -- .xml:1651 `x="-12"`
local PAGE_TAB_STACK_OVERLAP = 2      -- .xml:1681 等 `y="2"`
local PAGE_TAB_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

local pageTabs = {}   -- [id] = tab（我們自己的表）

local function SkinPageTab(info, key, id)
    local tab
    local label = "EncounterJournal.encounter.info." .. key
    if not (pcall(function() tab = info[key] end) and tab) then
        E.Missing(label)
        return
    end

    local ov = E.Overlay(tab, {
        key = label,
        points = {
            { "TOPLEFT", "TOPLEFT", PAGE_TAB_BOOK_OVERLAP, 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, PAGE_TAB_STACK_OVERLAP / 2 },
        },
        skipEdges = { "LEFT" },
        accentSide = "RIGHT",
        accentSize = T.tabAccentSize,
    })
    if not ov then return end

    for _, getter in ipairs(PAGE_TAB_GETTERS) do
        if type(tab[getter]) == "function" then
            local ok, tex = pcall(tab[getter], tab)
            if ok and tex then E.Neutralize(tex, label .. "." .. getter) end
        end
    end
    E.Paint(ov, T.fill, T.border)
    E.TrackSelectable(tab, ov, T.fill, { selectedFill = T.fillSelected, accentLine = true })
    E.SetSelected(tab, id == PAGE_TAB_INITIAL)
    pageTabs[id] = tab
end

local function SyncPageTabs(tabType)
    if type(tabType) ~= "number" or S.IsSecret(tabType) then return end
    for id, tab in pairs(pageTabs) do
        E.SetSelected(tab, id == tabType)
    end
end

------------------------------------------------------------
-- 書頁深色化 ＋ 三塊羊皮紙內嵌
--
-- `UI-EJ-JournalBG` 在 XML 裡是 785x425、TexCoords 右 0.766601562／下 0.830078125
-- ⇒ 原檔 1024x512，書頁上的一點 ＝ 貼圖上的一點（沒有縮放）。
-- 內嵌那一塊在書頁上的矩形（以 info 的左上角為原點、往右往下為正）直接換算 texCoord，
-- 所以羊皮紙的紋理跟原本同一個位置一模一樣，只是周圍變深色。
------------------------------------------------------------
local PARCHMENT = "Interface\\EncounterJournal\\UI-EJ-JournalBG"
local PARCHMENT_W, PARCHMENT_H = 1024, 512

local function ParchmentUV(x1, y1, x2, y2)
    return { x1 / PARCHMENT_W, x2 / PARCHMENT_W, y1 / PARCHMENT_H, y2 / PARCHMENT_H }
end

-- 綜覽／首領技能：ScrollFrame 350x383、BOTTOMRIGHT -5,1（.xml:1779,1817）
--   ⇒ 在書頁上是 x 430～780、y 41～424。往外留 左 6／上 4／右 4／下 1
--   （下面只剩 1 點就到書頁底了）⇒ x 424～784、y 37～425。
local SCROLL_INLAY = {
    points = {
        { "TOPLEFT", "TOPLEFT", -6, 4 },
        { "BOTTOMRIGHT", "BOTTOMRIGHT", 4, -1 },
    },
    uv = ParchmentUV(424, 37, 784, 425),
}
-- 副本簡介：`instance` 390x425、BOTTOMRIGHT -1,2（.xml:1470），跟 info 同一個右下角
--   ⇒ 在書頁上是 x 395～785、y 0～425（整個右半頁）。四邊內縮 2，
--   讓 1px 黑邊落在書頁裡面 ⇒ x 397～783、y 2～423。
local INSTANCE_INLAY = {
    points = {
        { "TOPLEFT", "TOPLEFT", 2, -2 },
        { "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2 },
    },
    uv = ParchmentUV(397, 2, 783, 423),
}

-- `-- TODO(升格)`：「RegionBackdrop 的底換成一張貼圖」。第二個視窗要用時搬進 Engine
-- （`Engine.RegionBackdrop` 的 opts 加 `texture` / `texCoord`）。
-- ⚠ 動的全是 `Engine.RegionBackdrop` 回傳的**我們自己的**那張底貼圖（`ownRegions`
--   裡登記過的），暴雪的物件一張都沒有碰；失敗退回子框時那張底一樣是我們的。
local function ParchmentInlay(target, label, spec)
    local rec = E.RegionBackdrop(target, {
        key = label .. ".parchment",
        slot = "parchment",
        points = spec.points,
    })
    if not rec or not rec.bg then return end
    local bg = rec.bg
    local uv = spec.uv
    pcall(function()
        bg:SetTexture(PARCHMENT)
        bg:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
        bg:SetVertexColor(1, 1, 1, 1)
    end)
    E.Border(rec, T.border)
end

------------------------------------------------------------
-- 麵包屑（`EncounterJournal.navBar`）
--
-- 幾何全部從 NavigationBar.xml／.lua 抄，沒有量測：
--   * 按鈕高 30、橫條高 34 ⇒ 我們的方塊上下各內縮 2（離橫條邊 4）。
--   * 一般按鈕：文字 `LEFT x=20`、寬 ＝ 字寬 ＋ 30（有下拉 ＋53，下拉鈕 27 寬錨在
--     `RIGHT x=-2`）；下一顆 `LEFT → 這一顆 RIGHT, 0`（NavButtonTemplate 沒有 xoffset），
--     而暴雪的 › 箭頭（21 寬）錨在按鈕**外側**、壓在下一顆的前 21 點上
--     ⇒ 方塊取 x 10 ～ 寬−2：左右各留 8～10 點給字，跟下一顆的方塊之間空 12，
--       我們的 › 就畫在那 12 點的正中間（方塊右緣 ＋6）。
--   * 首頁鈕：`xoffset = -15`（下一顆壓進它右邊 15），文字 `LEFT 10 / RIGHT -30`
--     ⇒ 方塊取 x 0 ～ 寬−17，空隙同樣是 12、› 同樣在方塊右緣 ＋6。
--   * 溢出鈕（44 寬）：`xoffset = -18` ⇒ 方塊取 x 0 ～ 寬−20，裡面一個 ‹。
--
-- 三態：滑過＝底 `fillHover` ＋ 職業色邊（`Engine.TrackButtonHover`）；
-- **目前這一頁**＝暴雪 `Disable()` 的那一顆（NavBar.lua:237）⇒ 沒有滑過回饋，
-- 而且它後面的 › 收掉（`TrackGlyph` 的停用色給全透明）—— 麵包屑的最後一節後面
-- 不該還有一個「下一層」的箭頭。
--
-- ⚠ 下拉鈕（`MenuArrowButton`）的 Normal／Pushed 是 XML `alpha="0"`，但**它自己的
--   OnEnter／OnLeave 會 `SetAlpha(1)`／`SetAlpha(0)`**（NavigationBar.xml 的 Scripts）
--   ⇒ alpha 中和撐不過一次滑過。改成 `SetVertexColor(1,1,1,0)`：
--   vertex color 跟區域 alpha 是兩個獨立的屬性、相乘，暴雪只動後者（回報 ④）。
------------------------------------------------------------
local NAV_BOX_INSET_Y = 2
local NAV_SEP_X = 6
local NAV_BUTTON_POINTS = {
    { "TOPLEFT", "TOPLEFT", 10, -NAV_BOX_INSET_Y },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", -2, NAV_BOX_INSET_Y },
}
local NAV_HOME_POINTS = {
    { "TOPLEFT", "TOPLEFT", 0, -NAV_BOX_INSET_Y },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", -17, NAV_BOX_INSET_Y },
}
local NAV_OVERFLOW_POINTS = {
    { "TOPLEFT", "TOPLEFT", 0, -NAV_BOX_INSET_Y },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", -20, NAV_BOX_INSET_Y },
}
local INVISIBLE = { 1, 1, 1, 0 }

local ejNavBar            -- Apply 時記下來；`NavBar_AddButton` 的勾只認這一條
local navDone = setmetatable({}, { __mode = "k" })

local function NavGlyph(kind, anchor, x)
    return { kind = kind, size = T.glyphSize, thickness = 1, color = T.textDim,
             anchor = anchor, x = x }
end

-- 一顆麵包屑：美術中和、白字、方塊、（可選）後面的 ›
local function NavCrumb(btn, label, points, glyph, trackEnabled)
    E.NeutralizeRegions(btn, label)          -- Normal／Pushed／Highlight／箭頭／selected／陰影
    E.ButtonFonts(btn, GameFontHighlight, label)
    local ov = E.Overlay(btn, { key = label, points = points, glyph = glyph })
    if not ov then return end
    E.Paint(ov, T.fill, T.border)
    E.TrackButtonHover(btn, ov, T.fill)
    if glyph then
        E.TrackGlyph(btn, ov, {
            idle = T.textDim,
            hover = T.textDim,               -- 分隔符號不跟著滑過閃
            disabled = TRANSPARENT,          -- 目前這一頁：後面不畫 ›
            trackEnabled = trackEnabled,
        })
    end
end

local function NavMenuArrow(btn, label)
    local mab = Probe(btn, "MenuArrowButton")
    if not mab then
        E.Missing(label .. ".MenuArrowButton")
        return
    end
    local mlabel = label .. ".MenuArrowButton"
    E.Neutralize(Probe(mab, "Art"), mlabel .. ".Art")
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        if type(mab[getter]) == "function" then
            local ok, tex = pcall(mab[getter], mab)
            if ok and tex then E.VertexColor(tex, INVISIBLE, mlabel .. "." .. getter) end
        end
    end
    E.ButtonStates(mab, mlabel, nil, true)   -- Highlight 中和（32x32，會溢出我們的方塊）
    local mov = E.Overlay(mab, {
        key = mlabel, noBorder = true,
        glyph = { kind = "chevronDown", size = T.glyphSize, thickness = 1,
                  color = T.textDim, y = -1 },  -- `Art` 錨 `CENTER 0,-1`
    })
    if not mov then return end
    E.Paint(mov, TRANSPARENT)
    E.TrackGlyph(mab, mov, { trackHover = true })
end

local function SkinNavButton(btn)
    if navDone[btn] then return end
    navDone[btn] = true
    local label = "EncounterJournal.navBar.button"
    NavCrumb(btn, label, NAV_BUTTON_POINTS, NavGlyph("chevronRight", "RIGHT", NAV_SEP_X), true)
    NavMenuArrow(btn, label)
end

-- 走 navBar 底下的子框認按鈕（讀結構）：有 `arrowUp` 的就是 NavButtonTemplate。
-- **不讀 `navList`／`freeButtons`**（暴雪的欄位）。
local function SkinNavButtons(navBar)
    if type(navBar) ~= "table" or type(navBar.GetChildren) ~= "function" then return end
    local ok, children = pcall(function() return { navBar:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(children) do
        if type(child) == "table" and Probe(child, "arrowUp") ~= nil then
            SkinNavButton(child)
        end
    end
end

local function SkinNavBar(navBar)
    local label = "EncounterJournal.navBar"
    ejNavBar = navBar

    -- 無名的橫條 ＋ 五張 InsetBorder*（都是 navBar 自己的 region）
    E.NeutralizeRegions(navBar, label)
    local overlay = Probe(navBar, "overlay")
    if overlay then
        E.NeutralizeRegions(overlay, label .. ".overlay")   -- 那條無名的亮面
    else
        E.Missing(label .. ".overlay")
    end
    local bar = E.RegionBackdrop(navBar, { key = label })
    E.Paint(bar, T.fillInset, T.border)

    local home = Child(navBar, "home", label .. ".home")
    if home and not navDone[home] then
        navDone[home] = true
        NavCrumb(home, label .. ".home", NAV_HOME_POINTS,
            NavGlyph("chevronRight", "RIGHT", NAV_SEP_X), true)
    end
    local overflow = Child(navBar, "overflow", label .. ".overflow")
    if overflow and not navDone[overflow] then
        navDone[overflow] = true
        NavCrumb(overflow, label .. ".overflow", NAV_OVERFLOW_POINTS, nil, false)
        local ov = E.GetOverlay(overflow)
        if ov then
            -- 溢出鈕的「‹」就是它的全部內容 ⇒ 圖記畫在方塊中間，走一般的三態
            local g = E.Overlay(overflow, {
                key = label .. ".overflow.glyph", slot = "glyph", noBorder = true,
                levelOffset = 1,
                points = NAV_OVERFLOW_POINTS,
                glyph = NavGlyph("chevronLeft", "CENTER", 0),
            })
            if g then
                E.Paint(g, TRANSPARENT)
                E.TrackGlyph(overflow, g, {})
            end
        end
    end

    SkinNavButtons(navBar)
end

------------------------------------------------------------
-- 職業過濾條（`LootContainer.classClearFilter`）
--
-- 355x28、`BOTTOM → LootContainer TOP, x=-10, y=-27`（.xml:1882-1885）
--   ⇒ 左緣在 LootContainer 左邊 −15、右緣在右邊 −5、頂在上緣 +1。
-- 顯示的時候 ScrollBox 重錨到它的 `BOTTOMLEFT 14, 7`（.lua:2985）＝ 列從它底下往上
-- 7 點的地方開始 ⇒ 我們的條只畫到那裡（`BOTTOMRIGHT y=+7`），不然第一列會壓在條上。
-- 左右對齊 LootContainer（右緣 ＋5），頂對齊 LootContainer 的上緣。
------------------------------------------------------------
local function SkinClassFilter(loot, label)
    local ccf = Child(loot, "classClearFilter", label)
    if not ccf then return end
    E.NeutralizeRegions(ccf, label)           -- 無名的 UI-EJ-FilterBar
    local bar = E.RegionBackdrop(ccf, {
        key = label,
        points = {
            { "TOPLEFT", "TOPLEFT", 0, 0, rel = loot },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 5, 7 },
        },
    })
    E.Paint(bar, T.fill, T.border)
    local text = Child(ccf, "text", label .. ".text")
    if text then E.TextColor(text, T.text, label .. ".text") end
end

------------------------------------------------------------
-- 底部七顆分頁
--
-- `BottomEncounterTierTabTemplate` inherits `PanelTabButtonTemplate`（.xml:1325）
-- ⇒ `kind = "panel"`、`joined = "TOP"`（分頁掛在視窗下緣）。
-- ⚠ 第七顆（`TutorialsTab`）**沒有全域名字**（.xml:2345 的 `<Button>` 沒有 name），
--   所以整排一律走 parentKey。
------------------------------------------------------------
local BOTTOM_TABS = {
    "JourneysTab", "MonthlyActivitiesTab", "suggestTab",
    "dungeonsTab", "raidsTab", "LootJournalTab", "TutorialsTab",
}
-- ⚠ 一定是 0：XML 寫的重疊從來沒生效 —— `EncounterJournal_OnLoad` 的
--   `PanelTemplates_SetNumTabs`（Blizzard_EncounterJournal.lua:456）會走
--   `PanelTemplates_AnchorTabs` 把每顆重錨成「前一顆 TOPRIGHT x=+3」（同收藏視窗）。
local BOTTOM_TAB_PAD = 0

------------------------------------------------------------
-- 補掃（見檔頭「補掃時機」）
------------------------------------------------------------
local lootSweeper, bossSweeper
local lootScrollBox, bossScrollBox
local bypassNoted = false

-- 補掃接手的列＝弱鍵表裡沒有紀錄＝它的 Init 沒經過我們的 mixin 勾。
-- 記一筆（只記一次）進 `/mskin debug`，那就是檔頭第 1 條假設的實機證據。
local function LootAdopt(row)
    if not bypassNoted and IsLootRow(row) and E.RowState[row] == nil then
        bypassNoted = true
        E.Missing(LOOT_KEY .. ":Init (hook bypassed; adopted by EncounterJournal_LootUpdate sweep)")
    end
    if lootSweeper then lootSweeper(row) end
end

local function Resweep()
    if lootScrollBox then E.SweepRows(lootScrollBox, LOOT_KEY, LootAdopt) end
    if bossScrollBox then E.SweepRows(bossScrollBox, "EncounterBossButton", bossSweeper) end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function InstallHooks()
    -- ⚠ 這一段**不過戰鬥閘**（`Engine.RunUnit` 把 hooks 排在戰鬥閘前面）。
    lootSweeper = E.HookRows{
        key     = LOOT_KEY,
        mixin   = _G.EncounterJournalItemMixin,
        method  = "Init",
        apply   = LootApply,
        reapply = LootReapply,
        match   = IsLootRow,
    }
    bossSweeper = E.HookRows{
        key    = "EncounterBossButton",
        mixin  = _G.EncounterBossButtonMixin,
        method = "Init",
        apply  = BossApply,
        match  = IsBossRow,
    }

    -- ① 補掃。理由與「為什麼不是 ScrollBox:Update 的勾」見檔頭「補掃時機」。
    --    只有 `ForEachFrame` 唯讀走訪 ＋ 我們自己的 overlay；apply 裡的動作全是非保護的，
    --    戰鬥中照做（跟 mixin 勾同一條紀律）。
    if type(_G.EncounterJournal_LootUpdate) == "function" then
        hooksecurefunc("EncounterJournal_LootUpdate", Guard("EncounterJournal_LootUpdate", Resweep))
    else
        E.Missing("EncounterJournal_LootUpdate")
    end

    -- ② 新的麵包屑。按鈕是 `NavBar_AddButton` 執行期 `CreateFrame` 的（NavigationBar.lua:86），
    --    沒有 mixin、也沒有別的刷新函式；它是**全遊戲共用**的（說明視窗等也用 NavBar），
    --    所以第一行只認我們記下來的那一條 navBar（身分比較，不讀它的欄位）。
    --    後置勾跑在它自己 `NavBar_CheckLength` 之後 ⇒ 新按鈕的寬度與啟用狀態都已經定了。
    if type(_G.NavBar_AddButton) == "function" then
        hooksecurefunc("NavBar_AddButton", Guard("NavBar_AddButton", function(navBar)
            if navBar ~= nil and navBar == ejNavBar then SkinNavButtons(navBar) end
        end))
    else
        E.Missing("NavBar_AddButton")
    end

    -- ③ 四顆頁籤的選中態。只讀參數 `tabType`（見 SkinPageTab 那一段）。
    if type(_G.EncounterJournal_SetTab) == "function" then
        hooksecurefunc("EncounterJournal_SetTab", Guard("EncounterJournal_SetTab", SyncPageTabs))
    else
        E.Missing("EncounterJournal_SetTab")
    end
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
    if navBar then SkinNavBar(navBar) end

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

    local info = Child(enc, "info", "EncounterJournal.encounter.info")

    -- 副本簡介頁：羊皮紙內嵌（整個右半頁）。`LoreScrollBar` 不上皮 —— 它坐在羊皮紙上。
    local instance = Child(enc, "instance", "EncounterJournal.encounter.instance")
    if instance then
        ParchmentInlay(instance, "EncounterJournal.encounter.instance", INSTANCE_INLAY)
    end

    if not info then return end

    -- 書頁深色化：羊皮紙與兩張頁眉陰影 alpha 0，底交給 `info` 自己的 region。
    -- 不畫邊：`info` 幾乎貼齊 `inset`（encounter 錨 inset 內縮 3、info 再內縮 1），
    -- 再畫一圈就是兩條幾乎重疊的黑線。
    E.NeutralizeGlobals({ "EncounterJournalEncounterFrameInfoBG" })
    E.NeutralizeKeys(info, { "leftShadow", "rightShadow" }, "EncounterJournal.encounter.info")
    local book = E.RegionBackdrop(info, { key = "EncounterJournal.encounter.info", noBorder = true })
    E.Paint(book, T.fillInset)

    for _, field in ipairs({ "encounterTitle", "instanceTitle" }) do
        local fs = Child(info, field, "EncounterJournal.encounter.info." .. field)
        if fs then E.TextColor(fs, T.text, "EncounterJournal.encounter.info." .. field) end
    end

    -- 綜覽／首領技能兩頁：羊皮紙內嵌（字色接不住，見檔頭「書頁的字色」）
    for _, key in ipairs({ "overviewScroll", "detailsScroll" }) do
        local sf = Child(info, key, "EncounterJournal.encounter.info." .. key)
        if sf then ParchmentInlay(sf, "EncounterJournal.encounter.info." .. key, SCROLL_INLAY) end
    end

    for _, t in ipairs(PAGE_TABS) do
        SkinPageTab(info, t.key, t.id)
    end

    SkinBar(info, "BossesScrollBar", "EncounterJournal.encounter.info.BossesScrollBar")
    SkinDropdown(info, "difficulty", "EncounterJournal.encounter.info.difficulty")

    local loot = Child(info, "LootContainer", "EncounterJournal.encounter.info.LootContainer")
    if loot then
        -- 戰利品清單一塊內嵌區（`fillInset` ＋ 1px 邊）：它是獨立的框
        -- （frameStrata HIGH，.xml:1875），列坐在它上面、比它亮一階。
        local ov = E.Overlay(loot, { key = "EncounterJournal.encounter.info.LootContainer" })
        E.Paint(ov, T.fillInset, T.border)

        SkinClassFilter(loot, "EncounterJournal.encounter.info.LootContainer.classClearFilter")
        SkinBar(loot, "ScrollBar", "EncounterJournal.encounter.info.LootContainer.ScrollBar")
        SkinDropdown(loot, "filter", "EncounterJournal.encounter.info.LootContainer.filter")
        SkinDropdown(loot, "slotFilter", "EncounterJournal.encounter.info.LootContainer.slotFilter")

        lootScrollBox = Child(loot, "ScrollBox", "EncounterJournal.…LootContainer.ScrollBox")
    end
    bossScrollBox = Child(info, "BossesScrollBox", "EncounterJournal.encounter.info.BossesScrollBox")

    -- 已經建立的列補掃一遍（`ForEachFrame`，唯讀）。之後由 `EncounterJournal_LootUpdate`
    -- 的後置勾接手。⚠ 第七輪穩定性規則 (a)：只走訪，不呼叫 Update／FullUpdate／SetDataProvider。
    Resweep()

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
