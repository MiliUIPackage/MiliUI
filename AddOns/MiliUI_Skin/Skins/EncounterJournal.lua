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
-- ## 第十輪（使用者擷圖 58～60：「有點不自然，再打磨調整一下」）改了什麼
--
-- 1. **綜覽頁／首領技能頁／副本簡介頁的羊皮紙內嵌整塊拿掉，文字全接管。**
--    第九輪判「接不住」的三條理由逐條重查（12.1 live）：
--      * 「SimpleHTML 每次 SetText 會重設顏色」—— SetText 只發生在一支全域函式
--        `EncounterJournal_SetBullets` 裡（.lua:1598），勾它、在 SetText 之後重申即可；
--      * 「`PAPER_FRAME_*_COLOR` 會切換」—— 只在 `EncounterJournal_UpdateButtonState`
--        （.lua:1533），它的三條呼叫路徑都接得到（見「書頁深色化 ＋ …」那一段）；
--      * 「Lore 在 OnLoad 設暗棕」—— 全檔**只有** OnLoad 那一次（.lua:425），
--        我們的 apply 必然更晚，一次就撐得住。
--    ⇒ `ParchmentInlay`／`ParchmentUV` 與第九輪的 `TODO(升格)` 一起刪掉（不再有第二個用途）。
--    段落標題列換成 `T.fill` 條 ＋ 黑邊 ＋ 白字，說明區直接落在 `fillInset` 的書頁上，
--    條列點換成自己畫的 4px `textDim` 小方點。**沒有任何一塊保留羊皮紙。**
-- 2. **書頁其實一直是 `T.fill`**（擷圖取樣 29,29,29）：`info`／`inset` 都是
--    `useParentLevel`，底跟視窗本體同一個 sublevel（−8）⇒ 平手被本體蓋掉。墊到 −4／−3。
--    「首領清單捲軸像一條粗黑柱」就是這個：軌道（20）擺在 29 的底上。書頁回到 20 之後
--    軌道融進去、只剩拇指 —— 跟成就視窗等其他視窗一致（那些捲軸的軌道都坐在同色的內嵌上）。
-- 3. **戰利品清單：內嵌區往左擴 7**（`LOOT_PAD`），列與捲軸左右各 7 的內距；
--    職業過濾條的左緣跟著擴，上緣兩者都貼 LootContainer 的上緣。
-- 4. **戰利品分類列（「額外戰利品」）上皮**：白字 ＋ 字下一條 `fillHover` 髮絲線，ⓘ 保留。
--    同樣會被「早於 mixin 勾建立」繞過 ⇒ 走同一條 `EncounterJournal_LootUpdate` 補掃。
-- 5. 天賦版本鈕（伴隨元件）改 secondary —— 在 `ThirdParty/RaiderIO.lua`。
--
------------------------------------------------------------
-- ## 書頁的字色（內容底材規則的查證；第十輪更新）
--
-- | 文字 | 在哪一塊底上 | 暴雪怎麼設顏色 | 處理 |
-- |---|---|---|---|
-- | `info.encounterTitle` / `instanceTitle` | 深色書頁 | XML `<Color>`；Lua **只有** `SetText`（.lua:1272,1364,2198）與 `SetPoint` | `SetTextColor(T.text)` 一次 |
-- | 首領列的文字 | 我們的 `fill` 列底 | 字型物件（GameFontNormalMed3 金、Disabled 白） | 不動（金字在深底上讀得出來） |
-- | 戰利品列 `slot` / `armorType` / `boss` | 列底 | 只 `SetText`（.lua:212-232） | `textDim`；紅色內嵌色碼自動留著 |
-- | 戰利品分類列「額外戰利品」 | LootContainer 深底 | GameFontNormalMed3（金）；`Init` 只 `SetText`（.lua:257） | **第十輪**：`SetTextColor(T.text)` 一次 |
-- | `classClearFilter.text` | 我們的 `fill` 條 | XML `<Color>`；Lua 只 `SetText`（.lua:2982） | `SetTextColor(T.text)` 一次 |
-- | 綜覽頁：`loreDescription`（簡介）、「概況說明」標題 | 深色書頁 | XML `<Color>`；Lua 只 `SetText`／尺寸 | **第十輪**：一次（簡介 `textDim`、標題 `text`） |
-- | 綜覽頁與各段的 `overviewDescription.Text`、每一顆 `Bullets[i].Text`（SimpleHTML） | 深色書頁 | XML `<Color>`；**只有** `EncounterJournal_SetBullets` 會 SetText | **第十輪**：那一支的後置勾裡 `text` |
-- | 首領技能頁：`description`（簡介） | 深色書頁 | XML `<Color>`；只 `SetText` | **第十輪**：一次（`textDim`） |
-- | 段落（`EncounterInfoTemplate`）的 `button.title`／`expandedIcon` | 我們的 `fill` 條 | `UpdateButtonState` 的 `PAPER_FRAME_*_COLOR`（.lua:1538-1543）＋ `ToggleHeaders` 的 `SetFontObject`（.lua:1926,1928） | **第十輪**：三條路徑 ＋ ToggleHeaders 後置勾都重申（`text`／± 號 `textDim`） |
-- | 段落的 `description`（FontString） | 深色書頁 | XML `<Color>`；只 `SetText` | **第十輪**：`text` |
-- | 副本簡介：`LoreScrollingFont` 的 FontString | 深色書頁 | **只有** OnLoad 一次（.lua:425） | **第十輪**：一次（`text`） |
-- | 模型頁 | 它自己的 `dungeonBG` ＋ 紙框 | — | 不碰（3D 模型場景） |
--
-- 內文裡的法術連結（`|cff…|r` 藍字）不碰，深底上讀得到。完整的逐條查證與掛點在
-- 「書頁深色化 ＋ 綜覽／首領技能／副本簡介三頁的文字接管」那一段。
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
-- | EncounterJournal.inset、info | `Engine.RegionBackdrop` 的 sublevel 墊到 −4（第十輪） |
-- | overviewScroll／detailsScroll／instance.LoreScrollBar | 走 `Skin.ScrollBar`（第十輪） |
-- | overviewScroll.child 的 loreDescription、`$parentTitle`（全域名）、overviewDescription.Text | SetTextColor（第十輪） |
-- | overviewScroll.child.header（UI-EJ-Header-Overview） | SetAlpha(0)；child 上 `Engine.RegionBackdrop`（錨在 header 上的 `fill` 條） |
-- | detailsScroll.child.description | SetTextColor（第十輪） |
-- | 段落（EncounterInfoTemplate，動態建立、池化）的 descriptionBG / descriptionBGBottom | SetAlpha(0) |
-- | 段落 button 的十二張標題條切片 ＋ 三張 HIGHLIGHT 切片（GetRegions，keep `abilityIcon`）、`$parentGlow` 子框的三張 | SetAlpha(0) |
-- | 段落 button | `Engine.RegionBackdrop`（`fill` ＋ 邊）；`HookScript` OnEnter/OnLeave（滑過）、**OnShow／OnClick（重申字色）** |
-- | 段落 button 的 title / expandedIcon | SetTextColor；abilityIcon | SetTexCoord |
-- | 段落的 description、overviewDescription.Text | SetTextColor |
-- | 條列點（EncounterOverviewBulletTemplate，動態建立）的 Bullet | SetAlpha(0)；overlay（4px 小方點）；Text | SetTextColor |
-- | instance.LoreScrollingFont.ScrollBox.FontStringContainer.FontString | SetTextColor（第十輪） |
-- | 四顆 EncounterTabTemplate 的 Normal/Pushed/Disabled/Highlight | SetAlpha(0) |
-- | 同四顆 | overlay（底 ＋ 三邊 ＋ 右緣職業色線）；`HookScript` OnEnter/OnLeave |
-- | LootContainer | overlay（底 `fillInset` ＋ 1px 邊；第十輪左緣往外擴 7） |
-- | 戰利品分類列（池化，第十輪）的 name | SetTextColor；overlay（髮絲線） |
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
--   * **第十輪新增**：
--       `hooksecurefunc(EncounterJournalItemHeaderMixin, "Init", …)`（`Engine.HookRows`，分類列）
--       全域後置勾 `EncounterJournal_ToggleHeaders`／`EncounterJournal_UpdateButtonState`／
--       `EncounterJournal_SetBullets`
--       每個段落標題列按鈕的 `HookScript("OnShow")`、`HookScript("OnClick")`（重申字色）、
--       `HookScript("OnEnter"/"OnLeave")`（滑過，`Engine.TrackButtonHover`）
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
--     找 classClearFilter 的關閉鈕；第十輪：找兩個捲動子框底下的段落、段落底下的條列點、
--     標題列按鈕底下沒有 parentKey 的 `$parentGlow`）—— 讀結構不是讀值。
--   * `GetParent`（第十輪，`EncounterJournal_SetBullets` 的參數 `object` 的 parent ＝
--     條列點所在的框，同 .lua:1599 暴雪自己的取法）—— 讀結構。
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
-- * ~~綜覽頁、首領技能頁、副本簡介頁的內文顏色~~ —— **第十輪接管了**（見第十輪那一節）。
-- * **段落的角色圖示（`icon1..4`：盾／劍／⚠／骷髏）、首領小頭像（`portrait` 與圓框）**
--   —— 那是資訊與識別，原樣留著。
-- * **段落「從連結跳過來」的閃光**（`flashAnim` 對 `$parentGlow` 的 alpha 動畫）——
--   動畫照跑，但它的三張切片已經 alpha 0 ⇒ 看不到閃光。要保留就得自己畫一層跟著
--   動畫走的東西，那需要掛 OnUpdate 或勾動畫腳本，不划算。
-- * **副本簡介頁的插畫（`loreBG`）、名牌（`titleBG`／`title`）、`mapButton`** —— 插畫類，不碰。
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
-- * ~~戰利品分類列~~ —— **第十輪上皮了**（白字 ＋ 髮絲線）；它的 ⓘ（`TipButton`）不碰。
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
-- 戰利品內嵌區往左擴多少（第十輪，實機擷圖 58 的兩個箭頭）
--
-- 列是貼著 LootContainer 的左緣排的：ScrollBox 345 寬、錨 `BOTTOMRIGHT -20,1`
-- （.xml:1944-1948），沒有過濾時 `TOPLEFT 0,0`、有過濾時錨過濾條的 `BOTTOMLEFT 14,7`
-- （.lua:2985,2988；過濾條左緣在 −15 ⇒ 列從 −1 開始），view 沒有 padding（.lua:345）
-- ⇒ 列的左緣＝容器的左邊線。右邊則是 列(≈325) → 捲軸(330~338，.xml:1950-1954) → 容器右緣 345，
-- 捲軸外面還剩 **7**。列的位置不能動（不 SetPoint 暴雪框），所以讓我們的底往左擴同樣的 7：
-- 內容（列 ＋ 捲軸）左右各 7 的內距，分類列的字也就不再凸出邊線。
-- 擴出去的 7 落在首領清單捲軸（info x≈368~376）與容器左緣（435）之間的空白裡。
-- 上緣不擴：容器上方緊貼著兩顆篩選下拉，而且上緣要跟職業過濾條的上緣齊。
------------------------------------------------------------
local LOOT_PAD = 7

------------------------------------------------------------
-- 戰利品分類列（`EncounterItemDividerTemplate`，.xml:1176，mixin
-- `EncounterJournalItemHeaderMixin`，.lua:254-264；factory 在 .lua:355-357）
--
-- 第九輪不碰（金字讀得出來）；第十輪上皮成小節標題的語彙（STYLE.md ④「文字層級」、
-- `Skin.SectionTitle` 同一套：白字 ＋ 字下一條 `fillHover` 髮絲線，無底）。
--   * `name`（GameFontNormalMed3，錨 TOPLEFT `0,-22`、高 12 ⇒ 字的下緣在 −34）
--     ⇒ 髮絲線畫在列下緣往上 7（字下 4 點）。列高 45（BOSS_LOOT_BUTTON_HEIGHT）。
--   * `Init` 只 `name:SetText` ＋ `TipButton` Show/Hide ⇒ 顏色一次就撐得住（沒有 reapply）。
--   * ⓘ（`TipButton`，`Interface\common\help-i`）保留原樣 —— 它是「滑過看說明」的入口。
-- ⚠ 不走 `Skin.SectionTitle`：那一支找的是 `Title`／`Background`，這個模板是 `name` 而且
--   沒有底圖，套下去只會多兩筆假的「找不到」。
------------------------------------------------------------
local DIVIDER_KEY = "EncounterItemDivider"
local DIVIDER_RULE_Y = 7

local function IsDividerRow(row)
    return Probe(row, "TipButton") ~= nil and Probe(row, "name") ~= nil
end

local function DividerApply(row)
    local name = Probe(row, "name")
    if name then
        E.TextColor(name, T.text, DIVIDER_KEY .. ".name")
    else
        E.Missing(DIVIDER_KEY .. ".name")
    end
    local rule = E.Overlay(row, {
        key = DIVIDER_KEY .. ".rule", noBorder = true, height = 1,
        points = {
            { "BOTTOMLEFT", "BOTTOMLEFT", 0, DIVIDER_RULE_Y },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, DIVIDER_RULE_Y },
        },
    })
    E.Paint(rule, T.fillHover)
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
-- 書頁深色化 ＋ 綜覽／首領技能／副本簡介三頁的文字接管（第十輪）
--
-- 第九輪在這三塊保留了原本的羊皮紙內嵌（字色「接不住」）。第十輪逐條重查，
-- 結論是**全部接得住**，羊皮紙整塊拿掉。每一條寫字的路徑與它的掛點：
--
-- | 文字 | 暴雪怎麼設顏色（12.1 live） | 我們的掛點 |
-- |---|---|---|
-- | 綜覽頁 `loreDescription`、首領技能頁 `infoFrame.description`、「概況說明」標題（`$parentTitle`） | XML `<Color>`（.xml:1801,1839,1851）；Lua 只 `SetText`／`SetWidth`／`SetHeight`（.lua:1376-1378,1398,2197） | apply 一次 |
-- | 各段 `overviewDescription.Text` 與每一顆 `Bullets[i].Text`（SimpleHTML） | XML `<FontString … <Color>>`（.xml:740,753）；**只有** `EncounterJournal_SetBullets`（.lua:1598）會 `SetText` | 那一支全域函式的後置勾：SetText 之後重申（不賭 SimpleHTML 的 SetText 會不會把顏色洗掉） |
-- | 段落標題列 `button.title`／`button.expandedIcon`（± 號） | `EncounterJournal_UpdateButtonState`（.lua:1533）`SetTextColor(PAPER_FRAME_*_COLOR)`；`EncounterJournal_ToggleHeaders`（.lua:1926,1928）`title:SetFontObject(...)` | 見下面「標題列的三條呼叫路徑」 |
-- | 段落內文 `header.description`（FontString） | XML `<Color>`（.xml:1039）；Lua 只 `SetText`（.lua:992,1922） | 第一次見到那一段時 ＋ 每次 sweep |
-- | 副本簡介 `LoreScrollingFont` 的 FontString | **只有** `EncounterJournal_OnLoad`（.lua:425）`SetTextColor(.13,.07,.01)` 一次；`ScrollingFontMixin:SetText`（Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.lua:347）不碰顏色、EJ 全檔沒有對它 `SetFontObject` | apply 一次（我們的 apply 必然晚於 OnLoad） |
--
-- 標題列的三條呼叫路徑（`UpdateButtonState` 的 XML 綁定是 `function="…"` ⇒ **載入當下**
-- 就把函式值拷進 script 了，勾全域函式追不上這一條）：
--   (a) 按鈕的 `OnShow`（.xml:989）—— 段落第一次顯示、或從物件池拿回來再 Show
--       ⇒ `HookScript("OnShow")`，跑在暴雪那支之後；
--   (b) `EncounterJournal_OnClick`（.lua:1562，XML 同樣是 `function=` 綁定）在最後一行
--       `self:GetScript("OnShow")(self)` ⇒ `HookScript("OnClick")`，跑在整支 OnClick 之後；
--   (c) `EncounterJournal_ToggleHeaders` 的綜覽分支**直接呼叫全域**（.lua:1868）
--       ⇒ `hooksecurefunc("EncounterJournal_UpdateButtonState")`。
--   另外 `ToggleHeaders` 本身的後置勾負責「新建出來的段落」（.lua:1686,1901 的 `CreateFrame`）。
--   ⚠ 萬一某條路漏接，那一行會回到 `PAPER_FRAME_EXPANDED/COLLAPSED_COLOR` ——
--     那是**淺米色**（原本就是寫給羊皮紙上的深色標題條用的），在我們的深色條上照樣讀得到，
--     失敗方向不會是「深底暗字」。
--
-- 內文裡的法術連結是 `|cff…|r` 內嵌色碼，深底上讀得到，不碰。
-- （暴雪在 .lua:991,1918 把**白色**色碼剝掉，是為了羊皮紙；深底上剝掉之後就是我們的白字，一樣讀得到。）
------------------------------------------------------------
local SECTION_KEY = "EncounterJournal.section"
local BULLET_DOT = 4                  -- 自己畫的小方點（取代 13x13 的棕色 `UI-PaperOverlay-Bullet`）
local SECTION_ICON_KEEP = { "abilityIcon" }

local sectionContainers = {}          -- { infoFrame, overviewFrame }：Apply 之後才有值（我們自己的表）
local sectionDone = setmetatable({}, { __mode = "k" })   -- 段落（EncounterInfoTemplate）
local sectionButtons = setmetatable({}, { __mode = "k" }) -- 段落的標題列按鈕
local bulletDone = setmetatable({}, { __mode = "k" })

local function Children(frame)
    if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then return nil end
    local ok, list = pcall(function() return { frame:GetChildren() } end)
    if ok then return list end
    return nil
end

-- 認人只看結構（有沒有這些 parentKey），不讀任何值
local function IsSectionHeader(f)
    return Probe(f, "button") ~= nil and Probe(f, "descriptionBG") ~= nil
end
local function IsBullet(f)
    return Probe(f, "Bullet") ~= nil and Probe(f, "Text") ~= nil
end

-- 標題列上每次都會被暴雪蓋掉的東西：標題字、± 號、技能圖示的裁邊
-- （`abilityIcon:SetTexture` 每次都在 ToggleHeaders 裡重下，.lua:1945）。
local function ReapplySectionButton(btn)
    if type(btn) ~= "table" or not sectionButtons[btn] then return end
    local title = Probe(btn, "title")
    if title then E.TextColor(title, T.text, SECTION_KEY .. ".title") end
    local sign = Probe(btn, "expandedIcon")
    if sign then E.TextColor(sign, T.textDim, SECTION_KEY .. ".expandedIcon") end
    local icon = Probe(btn, "abilityIcon")
    if icon then E.CropIcon(icon, SECTION_KEY .. ".abilityIcon") end
end

local SectionButtonScript = Guard("EncounterInfoTemplate.button:OnShow/OnClick", ReapplySectionButton)

-- 前置宣告（`SkinSectionHeader` 第一次見到一段時要補跑它；本體在下面）
local OnSetBullets

-- 一顆條列點（`EncounterOverviewBulletTemplate`，.xml:722）
local function SkinBullet(b)
    if not bulletDone[b] then
        bulletDone[b] = true
        local dot = Probe(b, "Bullet")
        if dot then
            E.Neutralize(dot, SECTION_KEY .. ".Bullet")
            -- 小方點錨在原本那顆圓點的中心（13x13，錨 TOPLEFT）＝ 第一行字的高度
            local ov = E.Overlay(b, {
                key = SECTION_KEY .. ".bulletDot", noBorder = true, anchorTo = dot,
                points = { { "CENTER", "CENTER", 0, 0 } },
                width = BULLET_DOT, height = BULLET_DOT,
            })
            E.Paint(ov, T.textDim)
        end
    end
    local text = Probe(b, "Text")
    if text then E.TextColor(text, T.text, SECTION_KEY .. ".bullet.Text") end
end

-- 一個段落（`EncounterInfoTemplate`，.xml:762）
--
-- apply（每個段落只跑一次，**弱鍵表記住**；段落是 `freeHeaders`／`usedHeaders`
-- 兩張表之間借還的，同一個框會一直被重用，.lua:1899-1905,2176,2209）：
--   * `descriptionBG`／`descriptionBGBottom`（羊皮紙的內文底與下緣）alpha 0 ——
--     它們被 Lua `Show`／`Hide`／`SetPoint`（.lua:1672-1680,1812-1813,1834-1835,1855-1856,1934-1935），
--     alpha 是獨立屬性撐得住。展開後的說明區因此直接落在書頁的 `fillInset` 上（無邊）。
--   * 標題列按鈕：十二張 `eLeftUp`…`cMidDown` 與三張 HIGHLIGHT 切片全部 alpha 0
--     （`GetRegions` ＋ keep-set 只留 `abilityIcon`）；子框 `$parentGlow`（連結跳轉時的
--     閃光動畫目標，.xml:764-769、.xml:888）的三張切片也 alpha 0 —— 那是羊皮紙色的亮帶，
--     疊在深色條上是一塊米色；代價是「從連結跳到這一段」時沒有閃光。
--   * 標題列＝ `T.fill` 條 ＋ 1px 黑邊（`Engine.RegionBackdrop`，建在按鈕自己身上）；
--     滑過＝底提亮 ＋ 職業色邊（可收合的清單標題 ⇒ secondary 語彙，STYLE.md ④）。
--   * 右側的角色圖示（`icon1..4`）、首領小頭像（`portrait` 與它的圓框）**不碰**。
-- 兩層（首領名／技能）不另外分色：暴雪自己就把子段落縮排（`hWidth - HEADER_INDENT`，
-- .lua:1884、`SetWidth(hWidth)` :1972，段落錨 TOPRIGHT ⇒ 左緣內縮），層級已經在版面上。
local function SkinSectionHeader(h)
    if not sectionDone[h] then
        sectionDone[h] = true
        E.NeutralizeKeys(h, { "descriptionBG", "descriptionBGBottom" }, SECTION_KEY)

        local btn = Probe(h, "button")
        if btn then
            E.NeutralizeRegions(btn, SECTION_KEY .. ".button", E.KeepSet(btn, SECTION_ICON_KEEP))
            -- `$parentGlow` 沒有 parentKey；按鈕的子框裡只有它沒有 `icon`
            -- （`icon1..4` 與 `portrait` 都有），讀結構認人。
            for _, child in ipairs(Children(btn) or {}) do
                if Probe(child, "icon") == nil then
                    E.NeutralizeRegions(child, SECTION_KEY .. ".button.Glow")
                end
            end
            local bar = E.RegionBackdrop(btn, { key = SECTION_KEY .. ".button" })
            E.Paint(bar, T.fill, T.border)
            E.TrackButtonHover(btn, bar, T.fill)

            sectionButtons[btn] = true
            if type(btn.HookScript) == "function" then
                pcall(btn.HookScript, btn, "OnShow", SectionButtonScript)
                pcall(btn.HookScript, btn, "OnClick", SectionButtonScript)
            end
        else
            E.Missing(SECTION_KEY .. ".button")
        end

        -- 這一段在我們 apply 之前就跑過 `SetBullets` 的話（戰鬥中第一次開、apply 延到脫戰），
        -- 它的條列點還是暗棕字 ⇒ 第一次見到時補一次。之後的由 SetBullets 的後置勾接手。
        local od = Probe(h, "overviewDescription")
        if od then OnSetBullets(od) end
    end

    local desc = Probe(h, "description")
    if desc then E.TextColor(desc, T.text, SECTION_KEY .. ".description") end
    local od = Probe(h, "overviewDescription")
    local odText = od and Probe(od, "Text")
    if odText then E.TextColor(odText, T.text, SECTION_KEY .. ".overviewDescription.Text") end
    ReapplySectionButton(Probe(h, "button"))
end

-- `EncounterJournal_ToggleHeaders` 的後置勾：兩個容器底下的段落全部走一遍
-- （新建的做 apply、舊的只重申）。只有 `GetChildren` 唯讀走訪，
-- **不讀** `usedHeaders`／`freeHeaders`／`overviews`（暴雪的欄位）。
local function SweepSections()
    for _, container in ipairs(sectionContainers) do
        for _, child in ipairs(Children(container) or {}) do
            if IsSectionHeader(child) then SkinSectionHeader(child) end
        end
    end
end

-- `EncounterJournal_SetBullets(object, description, hideBullets)` 的後置勾：
-- `object` 是某一段（或綜覽頁本身）的 `overviewDescription`，條列點是它 parent 的子框
-- （.lua:1599,1635）。
--
-- 實機（2026-09-22）：第一次出現的綜覽／條列還是暗棕字 —— SimpleHTML 的顏色是
-- SetText 那一刻才烘進去的，後置勾裡的 SetTextColor 只管得到「下一次」。
-- ⇒ 用暴雪剛寫進去的同一段文字重畫（`Engine.RepaintHTML`，STYLE.md ③ 的例外）。
--   原文取自這支函式的**參數** `description`，不讀任何暴雪物件的文字欄位。
-- 切段方式**逐字照抄** `EncounterJournal_SetBullets`（.lua:1601-1650）：
--   * `string.find(description, "$bullet;")` 找不到 ⇒ 整段寫進 `object.Text`；
--   * 找得到 ⇒ 第一個 `$bullet;` 之前那段 strtrim 後寫進 `object.Text`，
--     之後每一段 `strtrim(v) .. "|n|n"` 依序寫進 `parent.Bullets[k].Text`
--     （接了 "|n|n" 不可能是空字串 ⇒ 暴雪的 skipped 分支走不到，k 與段落序一致）。
-- ⚠ 暴雪改了切段方式，重畫出來的字就會跟它不一樣（高度也跟著不對）——
--   改版時對照 SetBullets 重看這一段。
local function RepaintBullets(object, parent, description)
    local text = Probe(object, "Text")
    if not string.find(description, "$bullet;") then
        if text then E.RepaintHTML(text, T.text, description, SECTION_KEY .. ".overviewDescription.Text") end
        return
    end
    local desc = string.match(description, "(.-)$bullet;")
    if desc and text then
        E.RepaintHTML(text, T.text, strtrim(desc), SECTION_KEY .. ".overviewDescription.Text")
    end
    local list = parent and Probe(parent, "Bullets")
    if type(list) ~= "table" then return end
    local k = 1
    for v in string.gmatch(description, "$bullet;([^$]+)") do
        local b = list[k]
        local bt = b and Probe(b, "Text")
        if bt then E.RepaintHTML(bt, T.text, strtrim(v) .. "|n|n", SECTION_KEY .. ".Bullets.Text") end
        k = k + 1
    end
end

function OnSetBullets(object, description)   -- 指派給上面的前置宣告，不是全域
    if #sectionContainers == 0 or type(object) ~= "table" then return end
    local text = Probe(object, "Text")
    if text then E.TextColor(text, T.text, SECTION_KEY .. ".overviewDescription.Text") end
    if type(object.GetParent) ~= "function" then return end
    local ok, parent = pcall(object.GetParent, object)
    if not ok then return end
    for _, child in ipairs(Children(parent) or {}) do
        if IsBullet(child) then SkinBullet(child) end
    end
    -- 只有從後置勾進來（拿得到暴雪的參數）才重畫；apply 時的補掃沒有原文，
    -- 那幾段要等暴雪下一次 SetText（顏色已經設好，下一次就對）。
    if type(description) == "string" then RepaintBullets(object, parent, description) end
end

-- 綜覽頁那一條「概況說明」（不是 EncounterInfoTemplate，是捲動子框上的一張貼圖 ＋ 一條字）
--   .xml:1841 `header`（`UI-EJ-Header-Overview`，327x30（.xml:314），錨 `loreDescription` 的 BOTTOM）
--   .xml:1846 `$parentTitle`（**沒有 parentKey**，全域名
--             `EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildTitle`，
--             錨 header 的 BOTTOMLEFT `8, 6`、高 10）
-- 我們的條：左右對齊下面那一排段落（段落錨子框的 TOPLEFT/TOPRIGHT 0，.lua:1717-1718）。
--   header 是 327 寬、置中在 `loreDescription`（x=2、寬＝子框寬 −5，.lua:1377）的下方
--   ⇒ 子框寬 320（.xml:1828）時左緣在 −4、右緣在 323 ⇒ 條取 header 的 `+4 … −3`。
--   垂直取 header 下緣往上 22：字的中心（下緣 +6、高 10 ⇒ +11）正好落在條的正中。
local OVERVIEW_TITLE_GLOBAL = "EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildTitle"
local OVERVIEW_HEADER_POINTS = {
    { "TOPLEFT", "BOTTOMLEFT", 4, 22 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", -3, 0 },
}

local function SkinOverviewPage(overviewFrame, label)
    local lore = Child(overviewFrame, "loreDescription", label .. ".loreDescription")
    if lore then E.TextColor(lore, T.textDim, label .. ".loreDescription") end

    local header = Child(overviewFrame, "header", label .. ".header")
    if header then
        E.Neutralize(header, label .. ".header")
        local points = {}
        for i, pt in ipairs(OVERVIEW_HEADER_POINTS) do
            points[i] = { pt[1], pt[2], pt[3], pt[4], rel = header }
        end
        local bar = E.RegionBackdrop(overviewFrame, {
            key = label .. ".header", slot = "overviewHeader", points = points,
        })
        E.Paint(bar, T.fill, T.border)
    end
    local title = _G[OVERVIEW_TITLE_GLOBAL]
    if title then
        E.TextColor(title, T.text, OVERVIEW_TITLE_GLOBAL)
    else
        E.Missing(OVERVIEW_TITLE_GLOBAL)
    end

    local od = Child(overviewFrame, "overviewDescription", label .. ".overviewDescription")
    if od then OnSetBullets(od) end
end

-- 書頁底與內嵌框的繪製子層（第十輪）
--
-- ⚠ 實機擷圖 58／59 取樣：書頁是 (29,29,29) ＝ `T.fill`，不是 `info` 身上那張
--   `fillInset`（20）—— **`info`／`inset` 的底都被視窗本體的底蓋掉了**。
--   兩個都是 `useParentLevel`（.xml:1401,1573），跟 `EncounterJournal` 同一個 frame level，
--   而同一層的 region 是**跨框按 draw layer／sublevel 交錯**畫的（暴雪自己就靠這個：
--   `InsetFrameTemplate` 的 Bg 在 BACKGROUND −5、`ButtonFrameTemplate` 的 Bg 在 −6，
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:394,451）。
--   `Engine.RegionBackdrop` 預設三個都是 −8 ⇒ 平手，誰在上面看建立順序。
--   ⇒ 這兩張改成 −4（邊 −3）：高於本體的底（−8）、邊（−7）、標題帶（−6）、髮絲線（−5）。
--   「首領清單捲軸像一條粗黑柱」也是這個的症狀：軌道是 `scrollTrack`（＝ `fillInset`，20），
--   本來應該融進書頁，結果擺在 29 的底上變成一條深色柱；書頁回到 20 之後只剩拇指。
local BOOK_SUBLEVEL = -4
local BOOK_EDGE_SUBLEVEL = -3

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
-- 左右對齊我們畫的戰利品內嵌區（**第十輪：左緣跟著內嵌區往外擴 `LOOT_PAD`**，
-- 右緣 ＋5 ＝ LootContainer 右緣），頂對齊 LootContainer 的上緣 ＝ 內嵌區的上緣。
------------------------------------------------------------
local function SkinClassFilter(loot, label)
    local ccf = Child(loot, "classClearFilter", label)
    if not ccf then return end
    E.NeutralizeRegions(ccf, label)           -- 無名的 UI-EJ-FilterBar
    local bar = E.RegionBackdrop(ccf, {
        key = label,
        points = {
            { "TOPLEFT", "TOPLEFT", -LOOT_PAD, 0, rel = loot },
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
local lootSweeper, dividerSweeper, bossSweeper
local lootScrollBox, bossScrollBox
local bypassNoted, dividerBypassNoted = false, false

-- 補掃接手的列＝弱鍵表裡沒有紀錄＝它的 Init 沒經過我們的 mixin 勾。
-- 記一筆（只記一次）進 `/mskin debug`，那就是檔頭第 1 條假設的實機證據
-- （第十輪：使用者的報告裡已經看到 `EncounterItem:Init (hook bypassed…)`，假設成立）。
-- 分類列（`EncounterItemDividerTemplate`）跟物品列是同一個 ScrollBox、同一個 factory
-- （.lua:355-363）建的，會被同一件事繞過 ⇒ 同一條補掃、各自記一筆。
local function LootAdopt(row)
    if IsLootRow(row) then
        if not bypassNoted and E.RowState[row] == nil then
            bypassNoted = true
            E.Missing(LOOT_KEY .. ":Init (hook bypassed; adopted by EncounterJournal_LootUpdate sweep)")
        end
        if lootSweeper then lootSweeper(row) end
    elseif IsDividerRow(row) then
        if not dividerBypassNoted and E.RowState[row] == nil then
            dividerBypassNoted = true
            E.Missing(DIVIDER_KEY .. ":Init (hook bypassed; adopted by EncounterJournal_LootUpdate sweep)")
        end
        if dividerSweeper then dividerSweeper(row) end
    end
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
    -- 第十輪：分類列（「額外戰利品」）。`EncounterJournalItemHeaderMixin:Init`（.lua:256）
    -- 只 `name:SetText` ＋ `TipButton` Show／Hide ⇒ 全部放 apply，沒有 reapply。
    dividerSweeper = E.HookRows{
        key    = DIVIDER_KEY,
        mixin  = _G.EncounterJournalItemHeaderMixin,
        method = "Init",
        apply  = DividerApply,
        match  = IsDividerRow,
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

    -- ④～⑥ 第十輪：綜覽／首領技能兩頁的段落與內文（理由與三條路徑見「書頁深色化 ＋ …」那一段）。
    --    三支都是**全域函式**的後置勾；Apply 之前（`sectionContainers` 還是空的）等於空轉。
    --    動作只有 SetTextColor／SetAlpha／SetTexCoord ＋ 建我們自己的底，戰鬥中照做。
    if type(_G.EncounterJournal_ToggleHeaders) == "function" then
        hooksecurefunc("EncounterJournal_ToggleHeaders",
            Guard("EncounterJournal_ToggleHeaders", SweepSections))
    else
        E.Missing("EncounterJournal_ToggleHeaders")
    end
    if type(_G.EncounterJournal_UpdateButtonState) == "function" then
        hooksecurefunc("EncounterJournal_UpdateButtonState",
            Guard("EncounterJournal_UpdateButtonState", ReapplySectionButton))
    else
        E.Missing("EncounterJournal_UpdateButtonState")
    end
    if type(_G.EncounterJournal_SetBullets) == "function" then
        hooksecurefunc("EncounterJournal_SetBullets", Guard("EncounterJournal_SetBullets", OnSetBullets))
    else
        E.Missing("EncounterJournal_SetBullets")
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

    -- 內嵌框：`Skin.Inset` 的同一件事，只是底與邊的 sublevel 墊高（見 BOOK_SUBLEVEL 的註解）
    local inset = Child(f, "inset", "EncounterJournal.inset")
    if inset then
        E.NeutralizeKeys(inset, { "Bg", "NineSlice" }, "EncounterJournal.inset")
        local rec = E.RegionBackdrop(inset, {
            key = "EncounterJournal.inset",
            sublevel = BOOK_SUBLEVEL, edgeSublevel = BOOK_EDGE_SUBLEVEL,
        })
        E.Paint(rec, T.fillInset, T.border)
    end

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

    -- 副本簡介頁（第十輪：羊皮紙內嵌拿掉，直接落在深色書頁上）。
    --   `loreBG`（副本插畫）與 `titleBG`／`title` 是插畫與它的名牌，不碰。
    --   簡介文字：`LoreScrollingFont.ScrollBox.FontStringContainer.FontString`
    --   （ScrollTemplates.xml:48-57 的 parentKey 鏈；**不呼叫**它的 mixin 方法
    --   `SetTextColor(color)`，直接對那一條 FontString 下 SetTextColor）。
    local instance = Child(enc, "instance", "EncounterJournal.encounter.instance")
    if instance then
        local label = "EncounterJournal.encounter.instance"
        local lsf = Child(instance, "LoreScrollingFont", label .. ".LoreScrollingFont")
        local box = lsf and Child(lsf, "ScrollBox", label .. ".LoreScrollingFont.ScrollBox")
        local holder = box and Child(box, "FontStringContainer", label .. ".LoreScrollingFont.FontStringContainer")
        local fs = holder and Child(holder, "FontString", label .. ".LoreScrollingFont.FontString")
        if fs then E.TextColor(fs, T.text, label .. ".LoreScrollingFont.FontString") end
        SkinBar(instance, "LoreScrollBar", label .. ".LoreScrollBar")
    end

    if not info then return end

    -- 書頁深色化：羊皮紙與兩張頁眉陰影 alpha 0，底交給 `info` 自己的 region。
    -- 不畫邊：`info` 幾乎貼齊 `inset`（encounter 錨 inset 內縮 3、info 再內縮 1），
    -- 再畫一圈就是兩條幾乎重疊的黑線。
    -- ⚠ 第十輪：sublevel 墊高（見 BOOK_SUBLEVEL）——第九輪這一張其實從來沒被看見過。
    E.NeutralizeGlobals({ "EncounterJournalEncounterFrameInfoBG" })
    E.NeutralizeKeys(info, { "leftShadow", "rightShadow" }, "EncounterJournal.encounter.info")
    local book = E.RegionBackdrop(info, {
        key = "EncounterJournal.encounter.info", noBorder = true, sublevel = BOOK_SUBLEVEL,
    })
    E.Paint(book, T.fillInset)

    for _, field in ipairs({ "encounterTitle", "instanceTitle" }) do
        local fs = Child(info, field, "EncounterJournal.encounter.info." .. field)
        if fs then E.TextColor(fs, T.text, "EncounterJournal.encounter.info." .. field) end
    end

    -- 綜覽／首領技能兩頁（第十輪：羊皮紙內嵌拿掉，文字全接管，見「書頁深色化 ＋ …」那一段）。
    --   容器 ＝ 兩個 ScrollFrame 的 `child`（暴雪自己也叫它們 `overviewFrame`／`infoFrame`，
    --   .lua:318,323 —— 我們從 parentKey 走過去，不讀那兩個欄位）。
    wipe(sectionContainers)
    for _, key in ipairs({ "overviewScroll", "detailsScroll" }) do
        local label = "EncounterJournal.encounter.info." .. key
        local sf = Child(info, key, label)
        if sf then
            -- ScrollFrameTemplate 的捲軸是 `ScrollFrame_OnLoad` 執行期建的 MinimalScrollBar
            -- （Blizzard_SharedXML/SecureUIPanelTemplates.lua:23、Mainline/ScrollDefine.lua:1）
            SkinBar(sf, "ScrollBar", label .. ".ScrollBar")
            local child = Child(sf, "child", label .. ".child")
            if child then
                sectionContainers[#sectionContainers + 1] = child
                if key == "overviewScroll" then
                    SkinOverviewPage(child, label .. ".child")
                else
                    local desc = Child(child, "description", label .. ".child.description")
                    if desc then E.TextColor(desc, T.textDim, label .. ".child.description") end
                end
            end
        end
    end
    SweepSections()

    for _, t in ipairs(PAGE_TABS) do
        SkinPageTab(info, t.key, t.id)
    end

    SkinBar(info, "BossesScrollBar", "EncounterJournal.encounter.info.BossesScrollBar")
    SkinDropdown(info, "difficulty", "EncounterJournal.encounter.info.difficulty")

    local loot = Child(info, "LootContainer", "EncounterJournal.encounter.info.LootContainer")
    if loot then
        -- 戰利品清單一塊內嵌區（`fillInset` ＋ 1px 邊）：它是獨立的框
        -- （frameStrata HIGH，.xml:1875），列坐在它上面、比它亮一階。
        -- 第十輪：左緣往外擴 `LOOT_PAD`，讓列有內距（見 LOOT_PAD 的註解）。
        local ov = E.Overlay(loot, {
            key = "EncounterJournal.encounter.info.LootContainer",
            points = {
                { "TOPLEFT", "TOPLEFT", -LOOT_PAD, 0 },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
            },
        })
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
