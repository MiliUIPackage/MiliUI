------------------------------------------------------------
-- 配方：天賦與法術書（`PlayerSpellsFrame`，隨需載入 `Blizzard_PlayerSpells`）
--
-- ⚠⚠ **這一份原本是 C 級（STYLE.md ⑦「法術書、天賦」）。** 第十一輪使用者點名要做，
--   所以走一條**比特許視窗還窄**的路：只重畫「框」，天賦樹、法術、專精卡片的
--   **內容一顆都不碰**。判準跟宏偉寶庫、拍賣場那兩條特許是同一條：
--   「這個物件在不在會送出受保護／受限請求的執行流上」，在的就不碰或零腳本。
-- ⚠ **第十四輪（2026-09-23）修正**：法術書的字與背板必須接管（第十一輪「字本來就是淺色」
--   的判斷是錯的，見「做法」與「法術格」兩段）。法術格仍然**只動貼圖與字**，
--   施法鈕本身、圖示、點擊路徑一根手指都不碰。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.xml:5
--     `PlayerSpellsFrame` ← `PortraitFrameTemplate, TabSystemOwnerTemplate`（toplevel）
--   同檔 :15,20,31,42,48
--     `MaximizeMinimizeButton`（MaximizeMinimizeButtonFrameTemplate）／
--     `TabSystem`（錨在視窗的 **BOTTOMLEFT** ⇒ 分頁在內容下方）／
--     `SpecFrame`／`TalentsFrame`／`SpellBookFrame`（三頁都是 1612x856、錨 BOTTOM y=4）
--   Blizzard_PlayerSpellsFrame.lua:14-16  `OnLoad` → `AddNamedTab` ×3（XML 載入期就建好）
--   同檔 :143-144  `PlayerSpellsFrameMixin:SetTab` → `TabSystemOwnerMixin.SetTab(self, tabID)`
--     （明碼的全域表查詢 ⇒ `Engine.TabSystemOwnerHooks` 接得到）
--   ClassTalents/Blizzard_ClassTalentsFrame.xml:40
--     `ClassTalentsFrameTemplate` ← `TalentFrameBaseTemplate`；
--     `BlackBG`（BACKGROUND 0）／`BottomBar`（BACKGROUND 1，atlas
--     `talents-background-bottombar` **1612x82**）／`Background`（專精樹美術，錨在
--     BottomBar 的 TOP，1612x774）＋ 一整組動畫貼圖；
--     子框 `LoadSystem`（DropdownLoadSystemTemplate ⇒ `.Dropdown` 是 WowStyle1DropdownTemplate，
--     Blizzard_SharedXML/Shared/LoadSystem/LoadSystemTemplates.xml:6）／
--     `SearchBox`（SpellSearchBoxTemplate ← SearchBoxTemplate）／
--     `ApplyButton`、`InspectCopyButton`（UIPanelButtonNoTooltipTemplate）／
--     `ResetButton`、`UndoButton`（IconButtonTemplate）／`WarmodeButton`／
--     `PvPTalentSlotTray`／`PvPTalentList`／`HeroTalentsContainer`／
--     `ClassCurrencyDisplay`／`SpecCurrencyDisplay`／`FxModelScene`
--     `bottomPadding = 82`（同檔 KeyValue）⇒ 樹的可用區就是「底部 82 以上」
--   SpellBook/Blizzard_SpellBookFrame.xml:6
--     `SpellBookFrameTemplate`（TabSystemOwnerTemplate）：
--     `TopBar`（atlas `spellbook-background-evergreen-header`，BACKGROUND 1）／
--     `BookBGHalved`／`BookBGLeft`／`BookBGRight`（BACKGROUND 1，從 y=-51 開始）／
--     `BookCornerFlipbook`／`Bookmark`（BACKGROUND 2）；
--     子框 `CategoryTabSystem`（TabSystemTemplate，分頁是 `SpellBookCategoryTabTemplate`
--     ← TabSystemButtonTemplate，`isTabOnTop = true`，SpellBook/Blizzard_SpellBookTemplates.xml:38）／
--     `SettingsDropdown`／`AssistedCombatRotationSpellFrame`／`SearchBox`／
--     `PagedSpellsFrame`（`PagingControls` ← PagingControlsHorizontalTemplate，
--     Blizzard_PagedContent/Blizzard_PagingControls.xml）
--   SpellBook/Blizzard_SpellBookFrame.lua:36-49  `OnLoad` → 三顆分類分頁 `AddNamedTab`（XML 載入期）
--   同檔 :7-10  `Templates` 表：`initFunc = SpellBookHeaderMixin.Init`／`SpellBookItemMixin.Init`
--     是**檔案載入時就取走的函式參照**（勾這兩支 Init 不會跑）
--   SpellBook/Blizzard_SpellBookItem.xml:41  `SpellBookItemTemplate`（mixin `SpellBookItemMixin`）：
--     `Backplate`（BACKGROUND，atlas spellbook-item-backplate）／`TextContainer.Name`・`.SubName`・
--     `.RequiredLevel`（XML `<Color SPELLBOOK_FONT_COLOR>`）／`Button`（施法鈕，
--     `SpellBookItemButtonMixin`）的 `Icon`／`Border`／`IconHighlight`／`BorderSheen`／`IconMask`
--   SpellBook/Blizzard_SpellBookItem.lua:13-23 `OnLoad`（`self.Name = self.TextContainer.Name` 等別名、
--     背板 alpha 0.25）／:184-306 `UpdateVisuals`／:488-556 `OnIconEnter`・`OnIconLeave`
--     （背板 alpha 1／0.25）／:728-765 `SpellBookItemButtonMixin`（施法鈕的腳本）
--   SpellBook/Blizzard_SpellBookTemplates.xml:6  `SpellBookHeaderTemplate`（mixin `SpellBookHeaderMixin`）：
--     `Backplate`（atlas spellbook-list-backplate，alpha 0.65）／`Text`（SystemFont_Huge2，
--     `SPELLBOOK_FONT_COLOR`）／`Border`（atlas spellbook-divider，高 11，
--     錨 BOTTOMLEFT x=-32 ～ BOTTOMRIGHT x=-60）；.lua:3 `Init` 只 `Text:SetText`
--   Blizzard_PagedContent/Blizzard_PagedContentFrame.lua:194-204  `EnumerateFrames`／`ForEachFrame`
--     （`ipairs(self.frames)`，唯讀）；:474-543 `DisplayViewsForCurrentPage`
--   Blizzard_PagedContent/Blizzard_PagingControls.lua:16-17  `PageText:SetTextColor(fontColor)`（只在 OnLoad）
--   SpellBook/Blizzard_SpellBookFrame.lua:198-199  `SpellBookFrameMixin:SetTab` → `TabSystemOwnerMixin.SetTab(self, tabID)`
--   ClassSpecializations/Blizzard_ClassSpecializationsFrame.xml:311
--     `ClassSpecContentFrameTemplate.ActivateButton`（MagicButtonTemplate ← UIPanelButtonTemplate）
--   同資料夾 .lua `ClassSpecFrameMixin:OnLoad` → `SpecContentFramePool` 在載入期就
--     `UpdateSpecContents` 把卡片建好（之後只重用同一批）
--   ClassTalents/Blizzard_ClassTalentLoadoutDialogTemplates.xml:6,40
--     `ClassTalentLoadoutDialogButtonTemplate`（UIPanelButtonTemplate）／
--     `ClassTalentLoadoutDialogTemplate`（DIALOG strata；`Border` ← DialogBorderDarkTemplate、
--     `Title`、`ContentArea`）；三個實例：
--     `ClassTalentLoadoutImportDialog`（`ImportControl.InputContainer` ← InputScrollFrameTemplate、
--      `NameControl.EditBox` ← InputBoxTemplate）／`ClassTalentLoadoutCreateDialog`／
--     `ClassTalentLoadoutEditDialog`（`LoadoutName`、`UsesSharedActionBars.CheckButton`、
--      `DeleteButton`）
--
------------------------------------------------------------
-- ## 做法：學「成熟同類實作」怎麼避開天賦的 taint，再收得更窄
--
-- 研讀過的做法歸納成三條（只記策略，見 `.claude/notes/wow-blizzard-window-skin-strategies.md`）：
--   1. **天賦樹一根手指都不碰**：按鈕、連線、英雄天賦、PvP 天賦格全留原樣；
--      樹後面的專精美術是**內容**（跟冒險指南的首領圖同一類），保留。
--   2. **只處理「認得的模板形狀」**：三片式按鈕、搜尋框、下拉、捲軸、分頁，
--      其餘（天賦鈕、法術格、專精卡）天然不符合就被跳過。
--   3. **不掛任何會跑在天賦執行流裡的東西**。
-- 我們比它再收一步：
--   * 法術書的**每一格法術**：第十四輪起**照它的做法**勾 `SpellBookItemMixin` 的
--     `UpdateVisuals`／`OnIconEnter`／`OnIconLeave` 三支 mixin 方法（背板淡掉、字改白）。
--     ⚠ 第十一輪這裡寫「字本來就是淺色、不接管、零 hook」—— **錯了**：
--     `SPELLBOOK_FONT_COLOR` 是**暗紅棕色**（配羊皮紙用的），書頁換成深底之後名字與
--     副標幾乎看不見（2026-09-23 實機擷圖）。內容底材規則「換底就要連字一起換」在這裡
--     不是零成本 —— 必須接管。
--     法術格點下去就是施法，所以三支 hook 裡的動作收在最窄的白名單
--     （見下面「法術格」那一段與 taint 接觸面表）：只 `SetAlpha`／`SetTextColor`／
--     `SetDesaturated` 對**貼圖與字**，不讀任何法術資料、不碰那顆施法鈕本身
--     （`SpellBookItemButtonMixin` 一支都不勾）。
--   * 分類標題列（`SpellBookHeaderTemplate`）：它**在每次翻頁／切分頁後重掃**；我們沒有
--     那種掛點（`SpellBookFrame:SetTab` 是框實例、`PagedSpellsFrame` 的方法是 XML 載入期
--     就拷走的副本、`SpellBookHeaderMixin.Init` 被 `Templates` 表在檔案載入時就**拿走了原函式
--     參照**⇒ 勾了也不會跑）⇒ 改成「法術格的 `UpdateVisuals` 後置勾排一次下一幀的補掃」：
--     每一次 `DisplayViewsForCurrentPage` 都會對頁上每一格法術 `Init` → `UpdateVisuals`，
--     所以**任何**會換頁內容的路徑（翻頁、滾輪、切分類、搜尋、`SPELLS_CHANGED`）都會帶到它。
--   * 它對載入方案的名稱輸入框、標題 `ClearAllPoints`／`SetPoint`／`SetHeight` 重排；
--     我們的契約不准，**零重排**。
--   * 它的主要按鈕（套用變更、啟用專精、載入方案彈窗）是一般按鈕；我們一律走
--     **零腳本**（`Engine.ScriptlessButton`，STYLE.md ⑦「特許的第二種用法」）——
--     那幾顆都是「提交天賦設定／切換專精／匯入方案」，戰鬥中受限、而且會觸發
--     `TRAIT_CONFIG_UPDATED` 那一整串暴雪的更新。
--
-- ## 為什麼書頁可以換、天賦樹不換
--
-- * 法術書的書頁（`BookBG*`）只是一張底圖：Lua 只在最小化／最大化時對
--   `minimizedArt`／`maximizedArt` 這兩個 parentArray 做 `SetShown`，沒有讀回、沒有換 atlas
--   ⇒ `SetAlpha(0)` 撐得住。上面的字色是 XML 寫死的 `SPELLBOOK_FONT_COLOR`（**暗紅棕**，
--   第十一輪誤記成淺米色）⇒ 內容底材規則「換底就要連字一起換」：法術名／副標／
--   需求等級／分類標題／頁碼全部接管（見「法術格」「分類標題列」兩段）。
--   好消息是這幾條字**暴雪的 Lua 一次都不 `SetTextColor`**（只在未學會時 `SetAlpha(0.6)`，
--   Blizzard_SpellBookItem.lua:228-230,255-257；頁碼只在 `PagingControlsMixin:OnLoad`
--   設一次，Blizzard_PagingControls.lua:16-17）⇒ 每一格／每一條**上一次色就永久有效**。
-- * 天賦樹的 `Background` 是「這是哪個專精」的識別圖，而且有一整組動畫貼圖
--   （雲、粒子、套用時的閃光）疊在上面、以它為錨 —— 它是內容，不是框。
--   換掉的只有它**下面那條** `BottomBar`（木紋按鈕列）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `PlayerSpellsFrame` 的 NineSlice／PortraitContainer／Bg／TopTileStreaks | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `PlayerSpellsFrame` 本身 | `Engine.RegionBackdrop`（底＋邊＋標題帶，建成**它自己的** BACKGROUND 貼圖） |
-- | `TitleContainer.TitleText` | `SetTextColor` |
-- | `CloseButton` | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture`（`Skin.CloseButton`） |
-- | `MaximizeMinimizeButton` 兩顆 | 三張狀態圖 `SetAlpha(0)` ＋ 我們的 ＋／− 圖記（`Skin.IconButton`） |
-- | 底部三顆分頁、法術書三顆分類分頁的 `RotatedTextures` | `SetAlpha(0)` ＋ `SetNormalFontObject`（`Skin.TabSystemAll`） |
-- | `TalentsFrame.BottomBar` | `SetAlpha(0)`；換成 `TalentsFrame` 自己的一條 `fillInset` footer 帶（`Engine.RegionBackdrop`） |
-- | `TalentsFrame.LoadSystem.Dropdown` | `Background`／`Arrow` `SetAlpha(0)` ＋ ⌄ 圖記（`Skin.Dropdown`） |
-- | 兩個 `SearchBox` | `Left`／`Right`／`Middle` `SetAlpha(0)`；`searchIcon`／清除鈕 `SetVertexColor`；`Instructions` `SetTextColor`（`Skin.EditBox`） |
-- | **零腳本按鈕**：`ApplyButton`、`InspectCopyButton`、專精卡的 `ActivateButton`、三個載入方案彈窗的按鈕 | `Left`／`Right`／`Middle` `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`（`Engine.ScriptlessButton`）。**零 HookScript** |
-- | `SpellBookFrame` 的 `TopBar`／`BookBG*`／`BookCornerFlipbook`／`Bookmark` | `SetAlpha(0)`；書頁換成 `SpellBookFrame` 自己的 `fillInset` 貼圖 |
-- | 法術書 `PagingControls` 的兩顆翻頁鈕 | 三張狀態圖 `SetAlpha(0)` ＋ ‹ › 圖記（`Skin.IconButton`） |
-- | 三個載入方案彈窗的 `Border` | `SetAlpha(0)`；外框走提示皮（`T.tipFill` ＋ 職業色邊，同確認彈窗） |
-- | **法術格**（`SpellBookItemTemplate`）的 `Backplate`（羊皮紙煙霧背板） | `SetAlpha(0)`（每次 `UpdateVisuals`／`OnIconEnter`／`OnIconLeave` 之後重申：暴雪在這三支裡把它設回 0.25／1） |
-- | 法術格的 `TextContainer.Name`／`.SubName`／`.RequiredLevel` | `SetTextColor`（白／`textDim`／`textDim`，一次） |
-- | 法術格施法鈕上的**貼圖** `Button.Border`（金色翅膀框） | `SetAlpha(0.5)`（一次）＋ `SetDesaturated(true)`（每次 `UpdateVisuals` 之後，那一支會 `SetAtlas`） |
-- | 同上 `Button.BorderSheen`（掃光動畫） | `SetAlpha(0)`（一次；動畫只有位移、不動 alpha） |
-- | 同上 `Button.IconHighlight`（滑過光暈） | `SetDesaturated(true)`（每次 `UpdateVisuals` 之後）。alpha 仍由暴雪管（滑過 0.35／按下 0.65） |
-- | **分類標題列**（`SpellBookHeaderTemplate`）的 `Backplate`／`Border`（暗紅分隔線） | `SetAlpha(0)`；分隔線換成標題列自己的一條 1px `fillHover` 貼圖（`Engine.RegionBackdrop`） |
-- | 分類標題列的 `Text` | `SetTextColor(白)`（一次） |
-- | 頁碼 `PagingControls.PageText` | `SetTextColor(白)`（一次） |
-- | 彈窗的輸入框（`InputBoxTemplate`／`InputScrollFrameTemplate`）、勾選框 | `Skin.EditBox`／`Skin.InputScroll`／`Skin.CheckBox` |
--
-- ### 讀了什麼
--
-- 只有結構：`GetChildren()`（認分頁、認專精卡）與 parentKey。
-- **不讀** `specID`／`configID`／`nodeID`／任何天賦或法術資料，不讀 `self.tabs`、
-- 不讀 `SpecContentFramePool`（那是暴雪的欄位，不在讀取例外表上 ⇒ 改用 `GetChildren()`
-- 找「有 `ActivateButton` 這個 parentKey 的子框」）。
-- 法術格／分類標題列：只認 parentKey（`Backplate`／`Button`／`TextContainer`／`Text`／`Border`）。
-- **不讀** `spellBookItemInfo`／`artSet`／`isUnlearned`／`elementData`，不呼叫 `HasValidData()`。
-- 補掃分類標題列走 `PagedSpellsFrame:ForEachFrame`（Blizzard_PagedContentFrame.lua:198，
-- `ipairs(self.frames)` 的唯讀走訪 —— 跟 ScrollBox 的 `ForEachFrame` 同一類，
-- 它順手傳給回呼的 `elementData` 我們不看）。
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc(TabSystemOwnerMixin, "SetTab", …)` | 全域 mixin 後置勾（`Engine.TabSystemOwnerHooks`，跟專業視窗**共用同一支**） | 只呼叫 `Engine.SyncTabSystemAll()`，不讀參數 |
-- | `TabSystemButtonArtMixin:SetTabSelected` | 全域 mixin 後置勾（`Engine.TabSystemHooks`，既有） | 第一行查弱鍵表 |
-- | `Engine.TrackButtonHover`／`TrackSelectable`／`TrackGlyph` 的 `HookScript("OnEnter"/"OnLeave")`（翻頁鈕另加 `OnEnable`/`OnDisable`） | frame script 後掛 | **只對**分頁、下拉、搜尋框的清除鈕、關閉鈕、最大化最小化、翻頁鈕；內容只換我們自己 overlay 的顏色 |
-- | `hooksecurefunc(SpellBookItemMixin, "UpdateVisuals", …)` | mixin 後置勾（`Engine.HookRows`） | 第一次：三條字上色、翅膀框半透明、掃光 alpha 0；每次：背板 alpha 0、翅膀框與滑過光暈去飽和、**排一次下一幀的分類標題列補掃**（`C_Timer.After(0)`，同一幀只排一次） |
-- | `hooksecurefunc(SpellBookItemMixin, "OnIconEnter"/"OnIconLeave", …)` | mixin 後置勾（`Engine.HookRows`，`requireKnown`） | 只有背板 `SetAlpha(0)` |
--
-- ⚠ 三支法術格 hook 的時機與範圍（查證）：
--   * 三支都是 **mixin 方法**，法術格是 `PagedSpellsFrame` 第一次顯示時才從池子建的
--     （Blizzard_PagedContentFrame.lua:474-540，`SpellBookFrameMixin:OnShow` → `UpdateAllSpellData`），
--     比 `ADDON_LOADED` 晚 ⇒ frame 建立時拷到的是**我們勾過的**版本（陷阱 4）。
--   * `OnIconEnter`／`OnIconLeave` 由施法鈕的 `SpellBookItemButtonMixin:OnEnter`／`OnLeave`
--     以 `self:GetParent():OnIconEnter()` 呼叫（Blizzard_SpellBookItem.lua:742-750），
--     `UpdateVisuals` 在游標停在格子上時也會自己呼叫一次（:302-305）—— 每次滑進滑出都跑。
--   * **不勾** `OnIconMouseDown`／`OnIconMouseUp`／`OnIconClick`／`SpellBookItemButtonMixin` 的
--     任何方法：那是點擊（施法）的派送路徑，我們的 Lua 不准出現在那裡
--     （wow-121-addon-code-in-secure-stack 入口 6／7）。所以按下時的光暈亮度
--     （`iconHighlightPressAlpha` 0.65）仍是暴雪的 —— 我們只把它去飽和成中性白光。
--
-- **`hooksecurefunc` 在 `PlayerSpellsFrame`／`TalentsFrame`／`SpellBookFrame` 或它們任何子框
-- （框實例）：0 支。`Talent*Mixin`／`ClassSpec*Mixin`／`SpellBookItemButtonMixin`：0 支。**
-- **`HookScript("OnShow")` 在這個視窗的任何框上：0 支**（`ShowUIPanel` 的執行流裡不准有我們的 Lua）。
-- **零腳本按鈕上的 `HookScript`：0 支。**
--
-- ### 刻意不碰的東西
--
-- * 天賦樹：`ButtonsParent` 底下的每一顆天賦鈕、連線、`HeroTalentsContainer`、
--   `PvPTalentSlotTray`／`PvPTalentList`、`WarmodeButton`、`FxModelScene`、
--   `ClassCurrencyDisplay`／`SpecCurrencyDisplay`（可用點數）、`SearchPreviewContainer`。
-- * 樹的專精美術 `Background` 與整組動畫貼圖（見上面）。
-- * `ResetButton`／`UndoButton`：紅金色的重設／復原圖示本身就是這兩顆鈕的全部長相，
--   而且它們改的是「還沒提交的天賦點」—— 跟套用鈕同一條執行流，不值得為了兩顆小圖掛東西。
-- * 法術格的**圖示本身**、遮罩、冷卻、自動施放螞蟻線、「不在快捷列上」的光暈
--   （`ActionBarHighlight`）、雕文／點擊綁定／等級鎖的標記 —— 那些是資訊。
-- * 法術格的圖示外框**沒有**改成「方形 1px 黑框、滑過職業色」（使用者偏好的那一種），
--   評估過、做不到，退回成熟同類實作的「半透明＋去飽和」：
--     1. 圖示有**遮罩**（`Button.IconMask`），而且是 Lua 管的：`UpdateVisuals` 每次依
--        主動／被動 `SetAtlas` 成方形（`spellbook-item-spellicon-mask`）或**圓形**
--        （`talents-node-circle-mask`）（Blizzard_SpellBookItem.lua:210-216,675-713）。
--        `Engine.UnmaskIcon` 的前提是「XML 寫死、Lua 零引用」—— 這一張不符合。
--     2. 被動技能畫成圓的**本身就是資訊**（主動＝方、被動＝圓）；而分辨主動被動要讀
--        `spellBookItemInfo.isPassive`／`artSet`（暴雪欄位，不在讀取例外表上）。
--        不分辨就會替被動技能畫出「方框裡一顆圓圖」。
-- * `AssistedCombatRotationSpellFrame`（裡面是一顆 secure 的法術鈕）、
--   `SettingsDropdown`（齒輪）、`HelpPlateButton`。
-- * 專精頁的卡片美術（專精縮圖、職責圖示、代表技能圓圈）與整頁底圖 —— 卡片就是內容。
--   只換 `ActivateButton` 的長相（零腳本）。
-- * `HeroTalentsSelectionDialog`（英雄天賦的選擇視窗，本身就是一棵小天賦樹）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 小工具（跟 `Skins/Professions.lua` 同一組寫法）
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

-- 「有就做、沒有就靜默跳過」（暴雪依情境才有的那幾顆：檢視他人天賦時才出現的複製鈕…）
local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

------------------------------------------------------------
-- 零腳本按鈕（特許的第二種用法，STYLE.md ⑦）
--
-- 跟 `Skins/Professions.lua` 的 `CommerceButton` 是同一支：先建 overlay 再中和
-- （`Engine.Overlay` 對顯式保護框回 nil，倒過來寫會得到一顆隱形的「套用變更」）、
-- 字型物件換暴雪自己的白字、三態全交給 C 端依狀態顯示的貼圖。
-- TODO(升格): 第三份配方也用到了（專業／拍賣場／這裡）—— 下一輪收成 `Skin.ScriptlessButton`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)   -- **不掛腳本**
    return ov
end

------------------------------------------------------------
-- 外框（三頁共用）
------------------------------------------------------------
local MAXMIN_GLYPH = { MaximizeButton = "expand", MinimizeButton = "collapse" }

local function SkinChrome(f)
    Skin.PortraitChrome(f, "PlayerSpellsFrame")
    Skin.Panel(f, "PlayerSpellsFrame")

    WithSub(f, "CloseButton", "PlayerSpellsFrame.CloseButton", function(btn, label)
        Skin.CloseButton(btn, label)
    end)

    WithSub(f, "MaximizeMinimizeButton", "PlayerSpellsFrame.MaximizeMinimizeButton",
        function(frame, key)
            for name, glyph in pairs(MAXMIN_GLYPH) do
                local btn = Sub(frame, name, key .. "." .. name)
                if btn then
                    Skin.IconButton(btn, key .. "." .. name, { glyph = glyph })
                end
            end
        end)

    -- 底部三顆分頁（專精／天賦／法術書）。`TabSystem` 錨在視窗**下方**
    -- （Blizzard_PlayerSpellsFrame.xml:20 `TOPLEFT → $parent BOTTOMLEFT`）
    -- ⇒ 相連的是上邊 ⇒ `onTop = false`（預設）。
    WithSub(f, "TabSystem", "PlayerSpellsFrame.TabSystem", function(tabSystem, key)
        Skin.TabSystemAll(tabSystem, key)
    end)
end

------------------------------------------------------------
-- 天賦頁：只換底部那條按鈕列
--
-- `BottomBar` 是 1612x82 的木紋條（atlas 尺寸查自 wago.tools 的 UiTextureAtlasMember；
-- `ClassTalentsFrameTemplate` 的 `bottomPadding = 82` 是同一個數字 —— 樹的可用區就是
-- 「底部 82 以上」）。換成 footer 帶：`fillInset` ＋ 上緣一條 `fillHover` 髮絲線
-- （STYLE.md ④「footer 帶」的規格；高度有 XML 常數可抄，所以這一份可以做）。
--
-- ⚠ 兩張都建成 **`TalentsFrame` 自己的** BACKGROUND 貼圖（`Engine.RegionBackdrop`）：
--   sublevel 排在 `BlackBG`(0)／`BottomBar`・`Background`(1) 之上、雲霧粒子(2) 之下 ——
--   footer 帶跟樹的美術不重疊（樹錨在 BottomBar 的 TOP），所以誰上誰下其實無所謂，
--   重點是它**永遠在所有子框（下拉、搜尋框、按鈕、PvP 天賦格）之下**。
--   `TalentsFrame` 不是 layout host，`RegionBackdrop` 不會退回子框。
------------------------------------------------------------
local TALENT_FOOTER_HEIGHT = 82
local FOOTER_SUBLEVEL = 1        -- 跟 BottomBar 同一層，建得晚 ⇒ 畫在它上面（它已經 alpha 0）
local FOOTER_RULE_SUBLEVEL = 2

local function SkinTalents(tf, key)
    if not E.Usable(tf, key) then return end

    E.NeutralizeKeys(tf, { "BottomBar" }, key)

    local band = E.RegionBackdrop(tf, {
        key = key .. ".footer",
        slot = "footer",
        noBorder = true,
        sublevel = FOOTER_SUBLEVEL,
        points = {
            { "BOTTOMLEFT", "BOTTOMLEFT", 0, 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
        },
        height = TALENT_FOOTER_HEIGHT,
    })
    E.Paint(band, T.fillInset)

    local rule = E.RegionBackdrop(tf, {
        key = key .. ".footerRule",
        slot = "footerRule",
        noBorder = true,
        sublevel = FOOTER_RULE_SUBLEVEL,
        points = {
            { "BOTTOMLEFT", "BOTTOMLEFT", 0, TALENT_FOOTER_HEIGHT },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, TALENT_FOOTER_HEIGHT },
        },
        height = 1,
    })
    E.Paint(rule, T.fillHover)

    -- 載入方案下拉（`DropdownLoadSystemTemplate` 包一顆 WowStyle1DropdownTemplate）
    WithSub(tf, "LoadSystem", key .. ".LoadSystem", function(ls, lkey)
        WithSub(ls, "Dropdown", lkey .. ".Dropdown", function(dd, label)
            Skin.Dropdown(dd, label, "style1")
        end)
    end)

    WithSub(tf, "SearchBox", key .. ".SearchBox", function(box, label)
        Skin.EditBox(box, label)
    end)

    -- 套用變更：這一塊唯一的「執行」⇒ primary；零腳本（提交天賦設定的執行流）
    WithSub(tf, "ApplyButton", key .. ".ApplyButton", function(btn, label)
        ScriptlessButton(btn, label, "primary")
    end)
    -- 檢視他人天賦時才出現的「複製方案字串」：`CopyToClipboard` 是保護函式
    -- （.claude/notes/wow-121-unitpopup-menu.md）⇒ 一樣零腳本。
    -- 那個狀態下它是這一塊唯一的按鈕 ⇒ primary（判準第 2 條）。
    local copy = Optional(tf, "InspectCopyButton")
    if copy then ScriptlessButton(copy, key .. ".InspectCopyButton", "primary") end
end

------------------------------------------------------------
-- 法術格（`SpellBookItemTemplate`，`PagedSpellsFrame` 池化的 element）
--
-- 做法照成熟同類實作：背板淡掉、名字／副標改白、翅膀框半透明去飽和、掃光拿掉。
-- ⚠ 法術格點下去是施法。這裡的每一個動作都只對**貼圖與字**，而且只在三支
--   **非點擊路徑**的 mixin 方法之後跑（`UpdateVisuals`／`OnIconEnter`／`OnIconLeave`）：
--   `SetAlpha`、`SetTextColor`、`SetDesaturated` —— 沒有 overlay、沒有 HookScript、
--   不讀任何欄位。施法鈕（`Button`）本身一個方法都沒被呼叫。
-- ⚠ 暴雪自己動過的 alpha 我們不去搶：
--   * 字：未學會時暴雪 `SetAlpha(0.6)`（.lua:228-230）—— 那是「還不能用」的訊號，留著；
--     我們只換顏色（兩者相乘 ⇒ 未學會的字是 60% 的白／灰）。
--   * `IconHighlight`：滑過 0.35、按下 0.65（.lua:22,546,655,665）—— 只去飽和，
--     不然滑過就沒有任何回饋（背板我們拿掉了）；而 `OnIconMouseDown` 在點擊路徑上，勾不得。
-- ⚠ 翅膀框（`Button.Border`）為什麼不是方形 1px：見檔頭「刻意不碰」最後一條。
------------------------------------------------------------
local SPELL_ITEM_KEY = "SpellBookItem"
local BORDER_ALPHA = 0.5

local function IsSpellItem(row)
    return (Optional(row, "Backplate") and Optional(row, "Button") and Optional(row, "TextContainer")) and true or false
end

local function SpellItemApply(row)
    local tc = Optional(row, "TextContainer")
    if tc then
        local name = Optional(tc, "Name")
        if name then E.TextColor(name, T.text, SPELL_ITEM_KEY .. ".Name") end
        for _, k in ipairs({ "SubName", "RequiredLevel" }) do
            local fs = Optional(tc, k)
            if fs then E.TextColor(fs, T.textDim, SPELL_ITEM_KEY .. "." .. k) end
        end
    end
    local btn = Optional(row, "Button")
    if btn then
        local border = Optional(btn, "Border")
        if border then pcall(border.SetAlpha, border, BORDER_ALPHA) end
        E.NeutralizeKeys(btn, { "BorderSheen" }, SPELL_ITEM_KEY .. ".Button")
    end
end

-- 分類標題列的補掃排在下一幀（宣告在下面，這裡先留名字）
local ScheduleHeaderSweep

local function SpellItemReapply(row)
    -- 背板：暴雪在 OnLoad／OnIconEnter／OnIconLeave 都會把它設回來 ⇒ 每次重申
    E.NeutralizeKeys(row, { "Backplate" }, SPELL_ITEM_KEY)
    local btn = Optional(row, "Button")
    if btn then
        -- `UpdateVisuals` 每次都對這兩張 `SetAtlas`（.lua:218,268）⇒ 去飽和放 reapply
        local border = Optional(btn, "Border")
        if border then E.Desaturate(border, SPELL_ITEM_KEY .. ".Button.Border") end
        local hl = Optional(btn, "IconHighlight")
        if hl then E.Desaturate(hl, SPELL_ITEM_KEY .. ".Button.IconHighlight") end
    end
    if ScheduleHeaderSweep then ScheduleHeaderSweep() end
end

-- 滑進滑出只需要把背板再壓回去
local function SpellItemBackplate(row)
    E.NeutralizeKeys(row, { "Backplate" }, SPELL_ITEM_KEY)
end

------------------------------------------------------------
-- 分類標題列（`SpellBookHeaderTemplate`）
--
-- 成熟同類實作的做法：標題改白、羊皮紙煙霧背板淡掉、華麗分隔線換成一條 1px 細線。
-- 它靠「量尺寸認分隔線」＋ 在 `SetTab`／翻頁鈕／滾輪／OnShow 之後重掃；
-- 我們不量尺寸（分隔線就是 parentKey `Border`），也不掛 OnShow ——
-- 觸發點改成法術格 `UpdateVisuals` 的後置勾（理由見檔頭「做法」）。
--
-- 認列：有 `Text`／`Border`／`Backplate`、**沒有** `Button`（法術格有 `Button`）。
-- 標題列的三樣東西暴雪都只在 XML 設過（`Init` 只 `SetText`）⇒ 每一條只要處理一次。
-- 細線是標題列**自己的**一張貼圖（`Engine.RegionBackdrop`，BACKGROUND）：
--   從 `Text` 的左緣（x=-8）拉到原分隔線的右緣（x=-60），垂直置中在原分隔線那 11 點高度裡。
--   標題列不是 layout host（純 Frame），寬度由暴雪排版（`autoExpandHeaders`）決定，
--   我們的線錨在它兩端 ⇒ 跟著走。
------------------------------------------------------------
local HEADER_KEY = "SpellBookHeader"
local HEADER_RULE_POINTS = {
    { "BOTTOMLEFT", "BOTTOMLEFT", -8, 5 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", -60, 5 },
}
local headerDone = setmetatable({}, { __mode = "k" })
local pagedSpells              -- `SpellBookFrame.PagedSpellsFrame`（Apply 時記下；身分，不讀欄位）

local function IsHeader(f)
    return (Optional(f, "Text") and Optional(f, "Border") and Optional(f, "Backplate")
        and not Optional(f, "Button")) and true or false
end

local function HeaderSweep(f)
    if headerDone[f] or not IsHeader(f) then return end
    if E.IsProtectedFrame(f) then return end
    headerDone[f] = true
    E.NeutralizeKeys(f, { "Backplate", "Border" }, HEADER_KEY)
    local text = Optional(f, "Text")
    if text then E.TextColor(text, T.text, HEADER_KEY .. ".Text") end
    local rule = E.RegionBackdrop(f, {
        key = HEADER_KEY .. ".rule",
        slot = "rule",
        noBorder = true,
        points = HEADER_RULE_POINTS,
        height = 1,
    })
    E.Paint(rule, T.fillHover)
end

local function SweepHeaders()
    if pagedSpells then E.SweepRows(pagedSpells, HEADER_KEY, HeaderSweep) end
end

local sweepPending = false
ScheduleHeaderSweep = function()
    if sweepPending or not pagedSpells then return end
    sweepPending = true
    C_Timer.After(0, function()
        sweepPending = false
        SweepHeaders()
    end)
end

------------------------------------------------------------
-- 法術書頁
--
-- 版面（SpellBook/Blizzard_SpellBookFrame.xml）：上緣 51 是標題列（`TopBar` 1614x58 的 atlas，
-- 分類分頁坐在上面 y=-19），51 以下是書頁（`BookBGLeft`／`Right`／`Halved` 都從 y=-51 起）。
-- 換成：標題列就是視窗本身的 `fill`（中和 TopBar 之後自然透出來）＋ 下緣一條髮絲線，
-- 書頁是 `SpellBookFrame` 自己的一張 `fillInset` 貼圖。
--
-- ⚠ 書頁上的字（法術名稱、副標、分類標題、頁碼）是 XML 寫死的 `SPELLBOOK_FONT_COLOR`
--   （暗紅棕）⇒ 全部接管：法術格與分類標題列走上面兩段，頁碼在這裡一次。
-- ⚠ 最小化時暴雪 `SetWidth` 視窗、切換 `minimizedArt`／`maximizedArt` 的顯示 ——
--   我們的書頁貼圖是錨點跟著 `SpellBookFrame` 的矩形走，兩種寬度都對。
------------------------------------------------------------
local SPELLBOOK_HEADER_HEIGHT = 51
local SPELLBOOK_ART = { "TopBar", "BookBGHalved", "BookBGLeft", "BookBGRight", "BookCornerFlipbook", "Bookmark" }

local function SkinSpellBook(sb, key)
    if not E.Usable(sb, key) then return end

    E.NeutralizeKeys(sb, SPELLBOOK_ART, key)

    local pages = E.RegionBackdrop(sb, {
        key = key .. ".pages",
        slot = "pages",
        noBorder = true,
        points = {
            { "TOPLEFT", "TOPLEFT", 0, -SPELLBOOK_HEADER_HEIGHT },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
        },
    })
    E.Paint(pages, T.fillInset)

    local rule = E.RegionBackdrop(sb, {
        key = key .. ".headerRule",
        slot = "headerRule",
        noBorder = true,
        sublevel = -7,
        points = {
            { "TOPLEFT", "TOPLEFT", 0, -SPELLBOOK_HEADER_HEIGHT },
            { "TOPRIGHT", "TOPRIGHT", 0, -SPELLBOOK_HEADER_HEIGHT },
        },
        height = 1,
    })
    E.Paint(rule, T.fillHover)

    -- 分類分頁（職業／通用／寵物）：`isTabOnTop = true` ⇒ 分頁在書頁**上方**、
    -- 相連的是下邊 ⇒ `onTop = true`（選中那條職業色線也跟著畫在上緣）。
    WithSub(sb, "CategoryTabSystem", key .. ".CategoryTabSystem", function(tabSystem, label)
        Skin.TabSystemAll(tabSystem, label, { onTop = true })
    end)

    WithSub(sb, "SearchBox", key .. ".SearchBox", function(box, label)
        Skin.EditBox(box, label)
    end)

    -- 翻頁鈕（同收藏視窗的 `SkinPaging`：箭頭素材中和、改畫 ‹ ›，翻到頭時變暗）
    local paged = Sub(sb, "PagedSpellsFrame", key .. ".PagedSpellsFrame")
    pagedSpells = paged
    local pc = paged and Sub(paged, "PagingControls", key .. ".PagedSpellsFrame.PagingControls")
    if pc then
        -- 頁碼「第 X/Y 頁」：`fontColor = SPELLBOOK_FONT_COLOR`，只在 OnLoad 設一次
        local pageText = Optional(pc, "PageText")
        if pageText then E.TextColor(pageText, T.text, key .. ".PagingControls.PageText") end
        for i, k in ipairs({ "PrevPageButton", "NextPageButton" }) do
            local pkey = key .. ".PagingControls." .. k
            local btn = Sub(pc, k, pkey)
            if btn then
                Skin.IconButton(btn, pkey, {
                    inset = 4,
                    glyph = (i == 1) and "chevronLeft" or "chevronRight",
                    glyphColor = T.textDim,
                    trackEnabled = true,
                })
            end
        end
    end
end

------------------------------------------------------------
-- 專精頁：只換每張卡片的「啟用」鈕
--
-- 卡片（`ClassSpecContentFrameTemplate`）是 `SpecContentFramePool` 在 `OnLoad` 就建好的，
-- 之後只重用同一批 ⇒ 掃一次就夠。認卡片走 `GetChildren()` ＋「有沒有 `ActivateButton`」
-- （讀結構，不讀 pool 那個暴雪欄位）。
-- ⚠ `SpecFrame` 本身是 `HorizontalLayoutFrame` —— 我們**不在它身上建任何東西**；
--   按鈕的 overlay 由 `Engine.Overlay` 的 `SafeParent` 掛到卡片上（卡片不是 layout host）。
-- ⚠ 按下去是切換專精 ⇒ 零腳本、primary（每張卡片各自一顆，卡片之間不是「成組」）。
------------------------------------------------------------
local function SkinSpecPage(sf, key)
    if not E.Usable(sf, key) then return end
    if type(sf.GetChildren) ~= "function" then return end
    local ok, children = pcall(function() return { sf:GetChildren() } end)
    if not ok then return end
    local n = 0
    for _, card in ipairs(children) do
        local btn = Optional(card, "ActivateButton")
        if btn then
            n = n + 1
            ScriptlessButton(btn, key .. ".card" .. n .. ".ActivateButton", "primary")
        end
    end
    if n == 0 then E.Missing(key .. ".ActivateButton") end
end

------------------------------------------------------------
-- 載入方案的三個彈窗（匯入／新增／編輯）
--
-- 浮在世界上方、彈出來填一格就關 ⇒ **提示皮**（STYLE.md ①；跟確認彈窗同一套）：
-- `T.tipFill` ＋ 1px 職業色邊，裡面的輸入框與按鈕照舊是設定視窗皮。
-- `Border` 是 `DialogBorderDarkTemplate`（九宮格 ＋ 暗色底），整個子框 alpha 0。
-- ⚠ 本體不是 layout host（`ClassTalentLoadoutDialogTemplate` 是普通 Frame）⇒
--   `RegionBackdrop` 直接建在彈窗自己身上，DIALOG strata 的問題不存在。
-- ⚠ 「接受／儲存」會建立或匯入天賦方案 ⇒ 零腳本；取消／刪除 secondary。
------------------------------------------------------------
local DIALOGS = {
    "ClassTalentLoadoutImportDialog",
    "ClassTalentLoadoutCreateDialog",
    "ClassTalentLoadoutEditDialog",
}
local DIALOG_BUTTONS = {
    { key = "AcceptButton", variant = "primary" },
    { key = "CancelButton", variant = "secondary" },
    { key = "DeleteButton", variant = "secondary" },
}

local function SkinLoadoutDialog(name)
    local d = _G[name]
    if not d then
        E.Missing(name)
        return
    end
    if not E.Usable(d, name) then return end

    E.NeutralizeKeys(d, { "Border" }, name)
    local ov = E.RegionBackdrop(d, { key = name })
    E.Paint(ov, T.tipFill, { T.Accent() })

    for _, b in ipairs(DIALOG_BUTTONS) do
        local btn = Optional(d, b.key)
        if btn then ScriptlessButton(btn, name .. "." .. b.key, b.variant) end
    end

    -- 名稱欄（三個彈窗都有）。欄位標籤降成 `textDim`（④「文字層級」：標籤是後設資訊）；
    -- `Label` 是 XML 的 GameFontNormal（暗金），Lua 只 `SetText`
    -- （Blizzard_ClassTalentLoadoutDialogTemplates.lua 的 NameControl OnLoad）⇒ 一次就永久有效。
    local nc = Optional(d, "NameControl")
    if nc then
        local nameBox = Optional(nc, "EditBox")
        if nameBox then Skin.EditBox(nameBox, name .. ".NameControl.EditBox") end
        local label = Optional(nc, "Label")
        if label then E.TextColor(label, T.textDim, name .. ".NameControl.Label") end
    end

    -- 匯入字串的多行輸入框
    local ic = Optional(d, "ImportControl")
    if ic then
        local input = Optional(ic, "InputContainer")
        if input then Skin.InputScroll(input, name .. ".ImportControl.InputContainer") end
        local label = Optional(ic, "Label")
        if label then E.TextColor(label, T.textDim, name .. ".ImportControl.Label") end
    end

    -- 編輯彈窗：「使用共享快捷列」勾選框（它的說明字是一般內文 ⇒ 白）
    local shared = Optional(d, "UsesSharedActionBars")
    if shared then
        local cb = Optional(shared, "CheckButton")
        if cb then Skin.CheckBox(cb, name .. ".UsesSharedActionBars.CheckButton") end
        local label = Optional(shared, "Label")
        if label then E.TextColor(label, T.text, name .. ".UsesSharedActionBars.Label") end
    end
end

------------------------------------------------------------
-- hooks：只有兩支**全域** mixin 後置勾（都是冪等、全遊戲共用的那兩支）
------------------------------------------------------------
local spellItemSweep

local function InstallHooks()
    -- 之後才建的新式分頁（這個視窗的分頁全是 XML 載入期建的，裝著是為了一致）
    E.TabSystemHooks()
    -- 兩排分頁（底部三顆、法術書三顆）都在 XML 載入期建好 ⇒ 靠這一支重讀選中態
    E.TabSystemOwnerHooks()

    -- 法術格（第十四輪）。⚠ 不過戰鬥閘（`Engine.RunUnit` 把 hooks 排在戰鬥閘前面）：
    --   法術格是第一次開法術書才建的，hook 一定要比那一刻早。
    local mixin = _G.SpellBookItemMixin
    spellItemSweep = E.HookRows{
        key     = SPELL_ITEM_KEY .. ":UpdateVisuals",
        mixin   = mixin,
        method  = "UpdateVisuals",
        apply   = SpellItemApply,
        reapply = SpellItemReapply,
        match   = IsSpellItem,
    }
    for _, method in ipairs({ "OnIconEnter", "OnIconLeave" }) do
        E.HookRows{
            key          = SPELL_ITEM_KEY .. ":" .. method,
            mixin        = mixin,
            method       = method,
            requireKnown = true,
            reapply      = SpellItemBackplate,
        }
    end
end

local function Apply()
    local f = _G.PlayerSpellsFrame
    if not f then
        E.Missing("PlayerSpellsFrame")
        return
    end

    SkinChrome(f)
    WithSub(f, "TalentsFrame", "PlayerSpellsFrame.TalentsFrame", SkinTalents)
    WithSub(f, "SpellBookFrame", "PlayerSpellsFrame.SpellBookFrame", SkinSpellBook)
    WithSub(f, "SpecFrame", "PlayerSpellsFrame.SpecFrame", SkinSpecPage)

    for _, name in ipairs(DIALOGS) do
        SkinLoadoutDialog(name)
    end

    -- 建立時讀一次選中態；之後由 `TabSystemOwnerMixin:SetTab` 的後置勾重讀
    E.SyncTabSystemAll()

    -- 已經建好的法術格與分類標題列補掃一遍（正常情況下這時候書還沒開過、池子是空的）
    if pagedSpells then
        E.SweepRows(pagedSpells, SPELL_ITEM_KEY, spellItemSweep, HeaderSweep)
    end
end

E.Register{
    key   = "playerspells",
    addon = "Blizzard_PlayerSpells",
    title = L["Talents & Spellbook"],
    hooks = InstallHooks,
    apply = Apply,
}
