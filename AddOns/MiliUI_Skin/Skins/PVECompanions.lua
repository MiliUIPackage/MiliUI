------------------------------------------------------------
-- 配方：地城與團隊的伴隨元件（套組內建的預組隊伍過濾插件）
--
-- 這一份**不是**一份獨立的配方 —— 它把自己的入口交給 `Skins/PVE.lua`
-- （`ns.PVESkin.ApplyCompanions`，跟 PvP／傳奇鑰石同一張交接桌），
-- 由 `pve` 那一筆的 `companions` 觸發。玩家看到的是一個視窗，設定裡就只有一個開關。
--
-- 處理兩樣東西（STYLE.md ③「伴隨元件」那條窄路）：
--   1. 搜尋頁右上的勾選框 `UsePGFButton`（`UICheckButtonTemplate`，
--      parent 是 `LFGListFrame.SearchPanel`）。
--   2. 貼在 `PVEFrame` 右邊的篩選視窗 `PremadeGroupsFilterDialog`
--      （`PortraitFrameTemplateMinimizable`）與它底下的七個面板。
--
------------------------------------------------------------
-- ## 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）
--
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1074-1121
--       `PortraitFrameBaseTemplate` → `NineSlice`／`PortraitContainer`／
--       `TitleContainer.TitleText`
--   同檔 :1123-1137  `PortraitFrameTexturedBaseTemplate` → `Bg`
--       （`Interface\FrameGeneral\UI-Background-Rock`）＋ `TopTileStreaks`
--   同檔 :1129-1132  `PortraitFrameTemplate` → `CloseButton`（`UIPanelCloseButton*`）
--   同檔 :1134-1139  **`PortraitFrameTemplateMinimizable`** ——
--       只多一個 `layoutType` 的 KeyValue，**自己並沒有 `MaximizeMinimizeFrame`**
--       （見下面「查證後跟計畫假設不一樣的地方」第 2 點）
--   同檔 :1341-1375  `MaximizeMinimizeButtonFrameTemplate` →
--       `MaximizeButton`（`RedButton-Expand` / `-Expand-Pressed` / `-Expand-Disabled`）
--       ＋ `MinimizeButton`（`RedButton-Condense` / `-Condense-Pressed` /
--       `-Condense-disabled`），兩顆的 Highlight 都是 `RedButton-Highlight`
--       —— 跟關閉鈕的 `RedButton-Exit` 同一族「紅底按鈕連符號」的合成圖
--   同檔 :1260-1267  `MagicButtonTemplate` ← `UIPanelButtonTemplate`
--       ⇒ `Left`／`Right`／`Middle` 三片，`Skin.Button` 直接適用
--   Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml:4,25
--       **`IconButtonTemplate` 只有一張 OVERLAY 層的 `Icon`**，
--       `NormalTexture`／`PushedTexture`／`DisabledTexture` 是
--       **`SquareIconButtonTemplate`（:39,52-55）才加上去**的殼
--   Blizzard_SharedXML/Shared/Button/IconButtonTemplate.lua:3-27
--       `IconButtonMixin:OnLoad` —— `useIconAsHighlight` 時
--       `SetHighlightTexture(icon, "ADD")`；**只在 OnLoad 跑一次**，
--       而且全檔沒有任何一行重設 `Icon` 的 alpha／vertex color
--       ⇒ 我們對 Highlight 的 alpha 中和撐得住
--   Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:15-23
--       `UICheckButtonTemplate` 的四張狀態圖（`Skin.CheckBox` 走 getter，不點名）
--   Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml
--       `InputBoxTemplate`／`InputBoxInstructionsTemplate` → `Left`／`Right`／`Middle`
--       （＋ `Instructions`）；:72 `InputScrollFrameTemplate` → 九張 `*Tex` 切片
--
-- ## 伴隨元件那一邊的出處（只讀，一個字都沒改）
--
--   AddOns/PremadeGroupsFilter/UI/UsePGFButton.lua:24,32-34,73
--       `CreateFrame("CheckButton", "UsePGFButton", LFGListFrame.SearchPanel,
--        "UICheckButtonTemplate")` 寫在**檔案層**，`OnLoad()` 在同一個檔案的
--       最後一行就被呼叫 ⇒ 插件載入當下就建好了
--   AddOns/PremadeGroupsFilter/UI/Dialog.xml:4-9
--       `PremadeGroupsFilterDialogTemplate` ← `PortraitFrameTemplateMinimizable`，
--       `frameStrata="FULLSCREEN"`、`movable`、`enableMouse`
--   同檔 :11-15  `MaximizeMinimizeFrame`（`MaximizeMinimizeButtonFrameTemplate`）
--   同檔 :16-27,28-38  `ResetButton`／`SettingsButton`（兩顆 `IconButtonTemplate`，
--       `useIconAsHighlight = true`）
--   同檔 :39-44  `RefreshButton`（`MagicButtonTemplate`）
--   AddOns/PremadeGroupsFilter/UI/Dialog.lua:32,296
--       `CreateFrame("Frame", "PremadeGroupsFilterDialog", PVEFrame, …)` 同樣寫在
--       **檔案層**，`OnLoad()` 也在檔案的最後幾行 ⇒ 載入當下就建好
--   UI/DungeonPanel.lua:100、RaidPanel.lua:31、RolePanel.lua:25、ArenaPanel.lua:30、
--   RBGPanel.lua:25、DelvePanel.lua:65、MiniPanel.lua:25
--       七個面板**全部**是檔案層的 `CreateFrame(..., PGF.Dialog, …Template)`
--       ⇒ 沒有一個是「切到那個分類才建」的
--   UI/Templates.xml:5-24,27-36,39-64
--       `PremadeGroupsFilterBasicTemplate`（`Act` ＝ `UICheckButtonTemplate`
--        ＋ `Title` ＝ `GameFontHighlight`）／`…DropdownTemplate`（多一個 `DropDown`）／
--       `…MinMaxTemplate`（多 `Min`／`Max` 兩個 `InputBoxTemplate` ＋ `To`）
--   同檔 :68-101  `PremadeGroupsFilterInfoButtonTemplate`（`Interface\common\help-i`）
--   同檔 :103-122 `PremadeGroupsFilterTextButtonTemplate`（`Bg` ＋ `Label` ＋ 金色
--       HighlightTexture），mixin 在 `UI/TextButtonMixin.lua`
--   同檔 :125-159 `PremadeGroupsFilterExpressionTemplate`
--       （`Title` ＝ `GameFontNormal`、`Info`、`Expression` ＝ `InputScrollFrameTemplate`）
--   UI/PopupMenu.xml:74-139  `PremadeGroupsFilterDropDownPopupMenuTemplate`
--       （`Left`／`Middle`／`Right` ＝ `CharacterCreate-LabelFrame` 三片切法、
--        `Text` ＝ `GameFontHighlight`、`Button` ＝ `UI-ChatIcon-ScrollDown-*` 四張）
--   UI/MiniPanel.xml:16-44  `Sorting`（`Title` ＋ `Expression` ＝
--       `InputBoxInstructionsTemplate`）—— **只有迷你面板有排序欄**
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的地方
--
-- 1. **「面板是切分類時才建」是錯的。** 七個面板連同每一列的勾選框、輸入框、
--    下拉、表達式框，全部是**檔案層 `CreateFrame` ＋ XML** 一次建完的（出處見上），
--    切分類做的只是 `Show()`／`Hide()`。
--    ⇒ 不需要「每次觸發重掃一遍」，掃一次就完整。
--    ⇒ 也**沒有**一個暴雪事件擺在對的時間點上：`LFG_LIST_SEARCH_RESULTS_RECEIVED`
--      要等第一次搜尋結果回來（視窗已經顯示了一拍），`LFG_LIST_AVAILABILITY_UPDATE`
--      跟這幾個框的生命週期完全無關。挑任何一個都是「第一次開晚一拍上皮，
--      之後每次白掃一遍」。所以 `Engine` 的 `companions` 這一輪多一個
--      **`atLogin = true`**：同一條路（延一幀、戰鬥閘、脫戰補跑），觸發點改成
--      「配方全部套完之後」。
--    ⚠ 那一刻不是在賭載入順序：`PLAYER_LOGIN` 在所有 `ADDON_LOADED` 之後，
--      而那支插件的 TOC 沒有 `LoadOnDemand`。沒裝就是全域名字查不到 ⇒ 靜默返回。
--
-- 2. **`PortraitFrameTemplateMinimizable` 自己沒有最大化／最小化鈕**
--    （`SharedUIPanelTemplates.xml:1134-1139` 只多一個 `layoutType` KeyValue）。
--    那顆 `MaximizeMinimizeFrame` 是它**自己**在 `Dialog.xml:11` 加的子框，
--    只是模板用的是暴雪的 `MaximizeMinimizeButtonFrameTemplate`
--    ⇒ 原語照樣適用（同試衣間，`Skins/DressUp.lua`）。
--
-- 3. **兩顆小圖示鈕不是 `SquareIconButtonTemplate`。**
--    `IconButtonTemplate` 只有一張 `Icon`，沒有 `UI-SquareButton-*` 那組殼
--    ⇒ **不能**用 `Skin.SquareIconButton`（`opts.stripFrame` 會去染 `Icon`，
--    而這裡的 `Icon` 就是按鈕的全部內容：一顆重設箭頭、一顆齒輪）。
--    走 `Skin.IconButton` 的預設路徑：三個 getter 都回 nil（沒有殼可中和、
--    也沒有東西可染），實際發生的只有「Highlight 中和 ＋ 我們自己的底與邊與滑過」。
--
-- 4. **「P...」那個被截斷的標籤不是我們造成的。**
--    `UsePGFButton.lua:33` 自己寫死 `self.Text:SetWidth(30)`，而標籤字串是
--    `L["addon.name.short"] = "PGF"`（三個語系都一樣）。
--    套組的字型比暴雪預設寬，30 點放不下三個字母 ⇒ 被截成「P...」。
--    **我們不碰它**：`SetWidth`／`SetPoint` 對伴隨元件跟對暴雪物件同一條線，
--    契約禁止。那是另一支 Fix 的事（`MiliUI/Fix/`），見回報。
--
-- 5. **那個下拉不是暴雪的下拉。** `PremadeGroupsFilterDropDownPopupMenuTemplate`
--    是它自己用 `CharacterCreate-LabelFrame` 切出來的三片式欄位 ＋ 一顆
--    `UI-ChatIcon-ScrollDown-*` 的箭頭鈕 ⇒ `Skin.Dropdown`（`WowStyle1Dropdown` 系）
--    一個 parentKey 都對不上。這一份自己寫一支 local，形狀照 `Skin.Dropdown`：
--    欄位是 `fillInset` ＋ 1px 邊，箭頭中和改畫 ⌄ 線條圖記，**不給它一顆自己的方框**
--    （那會變成「框裡有框」，跟整包的下拉語彙不一致）。
--
------------------------------------------------------------
-- ## taint 接觸面清單（伴隨元件）
--
-- ⚠ 這一份**一個暴雪物件都沒有碰**，所以只有這一張表（STYLE.md ③ 第 6 條要求
--   兩張分開）。
--
-- | 物件 | 動作 |
-- |---|---|
-- | `UsePGFButton` 的 Normal／Pushed／Disabled 貼圖 | `SetAlpha(0)` |
-- | 同上的 Highlight | `SetAlpha(0)`（滑過自己畫）；Checked／DisabledChecked | `SetDesaturated` ＋ `SetVertexColor` |
-- | `PremadeGroupsFilterDialog` 的 `NineSlice`／`Bg`／`TopTileStreaks`／`PortraitContainer` | `SetAlpha(0)` |
-- | 同上的 `TitleContainer.TitleText` | `SetTextColor` |
-- | 同上的 `CloseButton` 的 Normal／Disabled | `SetAlpha(0)`；Highlight／Pushed | `SetColorTexture` |
-- | `MaximizeMinimizeFrame` 的 `MaximizeButton`／`MinimizeButton` 的 Normal／Pushed／Disabled | `SetAlpha(0)`（改畫 ＋／− 線條圖記） |
-- | `ResetButton`／`SettingsButton` 的 Highlight | `SetAlpha(0)`（`Icon` **不碰**） |
-- | `RefreshButton` 的 `Left`／`Right`／`Middle` | `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` |
-- | 七個面板各區塊的 `Title`（`GameFontNormal` 暗金） | `SetTextColor`（白） |
-- | 每一列的 `Act`（`UICheckButtonTemplate`） | 同 `UsePGFButton` |
-- | 每一列的 `Min`／`Max`（`InputBoxTemplate`）的 `Left`／`Right`／`Middle` | `SetAlpha(0)` |
-- | `DropDown` 的 `Left`／`Middle`／`Right` | `SetAlpha(0)` |
-- | `DropDown.Button` 的 Normal／Pushed／Disabled／Highlight | `SetAlpha(0)`（改畫 ⌄ 線條圖記） |
-- | `SelectAll`／`SelectNone`／`SelectInvert`／`SelectBountiful` 的 `Bg` ＋ Highlight | `SetAlpha(0)` |
-- | `Advanced.Expression`（`InputScrollFrameTemplate`）的九張 `*Tex` | `SetAlpha(0)`；`ScrollBar` 同 `Skin.ScrollBar` |
-- | `Sorting.Expression`（`InputBoxInstructionsTemplate`）的三片 ＋ `Instructions` | `SetAlpha(0)` ／ `SetTextColor` |
-- | 以上各框 | `CreateFrame` 掛自己的 overlay（錨在目標上、不吃滑鼠、零腳本） |
--
-- hook：**一支都沒有掛在它的函式上**。只有原語內建的
--   `HookScript("OnEnter"/"OnLeave")`（`Engine.TrackButtonHover`／`TrackGlyph`，
--   只碰我們自己的 overlay）與 `HookScript("OnEnable"/"OnDisable")`（箭頭鈕的停用態）。
--   **沒有 `hooksecurefunc`、沒有 `SetScript`、沒有呼叫它的任何函式。**
-- 寫入它的欄位：無（狀態全在 `Engine.State` 的弱鍵表裡）。
-- 讀它的物件：只有 parentKey 查詢（`frame.Act`…）、`GetChildren()` 與
--   `GetObjectType()` —— 讀**結構**不是讀值，跟讀取例外表同一條線。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`UsePGFButton.Text`** —— 寬度是它自己設死的（見上面第 4 點），
--   而且字色已經是 `GameFontHighlight`（白）。
-- * **兩顆小圖示鈕的 `Icon`** —— 一顆是 `talents-button-reset` atlas、一顆是
--   `Interface\Icons\Pet_Type_Mechanical`。那是按鈕的全部內容，染灰就等於把
--   「這顆是幹嘛的」抹掉；而且 `IconButtonMixin:SetEnabledState` 用
--   `SetDesaturated` 表示停用，我們一去飽和那個狀態就看不出來了。
--   裁邊也不做：atlas 那一張本來就帶 texCoord，再裁一次會挑到別格。
-- * **說明鈕 `Advanced.Info`** —— 黃色的 `help-i` 圓圖就是「這裡有說明」的線索，
--   中和掉等於少一個入口；而且它自己的 `OnMouseDown`／`OnMouseUp` 會對那兩張圖
--   `SetPoint`（`Templates.xml:89-98`），我們在同一塊位置上畫東西只會打架。
-- * **列標籤 `Title` 與 `To`（`GameFontHighlight`）** —— 本來就是白的，
--   照 STYLE.md ④「一般內文＝白」不必動。只有 `GameFontNormal` 的**區塊標題**
--   （篩選／地城／探究／進階過濾式）才改白。
-- * **`SelectAll` 那幾顆的 `Label` 顏色** —— mixin 的 `OnEnter`／`OnLeave` 每次
--   都重設（`TextButtonMixin.lua:26,34`），要接管就得 hook 它的函式，禁止。
-- * **彈出的下拉選單 `PremadeGroupsFilterPopupMenuFrameTemplate`** ——
--   彈出選單一律不碰（STYLE.md ③）。
-- * **它的設定頁（`Settings/`）與 StaticPopup** —— 前者住在暴雪的設定視窗裡、
--   後者離 `StaticPopup` 太近（⑦ 的 C 級）。
-- * **`Dungeons.Alert` / `Delves.Alert` 的 `Icon`** —— 那是「這一季的地城清單
--   對不上」的警告圖示，是資訊。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens

ns.PVESkin = ns.PVESkin or {}

-- 安全取欄位（同 `Skins/PVE.lua` 的那一支，這裡借用它匯出的版本）
local Field = ns.PVESkin.Field or function(owner, key)
    if type(owner) ~= "table" then return nil end
    local v
    if pcall(function() v = owner[key] end) then return v end
end

local TRANSPARENT = { 0, 0, 0, 0 }

------------------------------------------------------------
-- 全域名稱（STYLE.md ③ 第 2 條：**只用全域名稱判斷有沒有，沒有就靜默跳過**）
------------------------------------------------------------
local DIALOG_NAME = "PremadeGroupsFilterDialog"
local BUTTON_NAME = "UsePGFButton"

local PANEL_NAMES = {
    "PremadeGroupsFilterDungeonPanel",
    "PremadeGroupsFilterRaidPanel",
    "PremadeGroupsFilterRolePanel",
    "PremadeGroupsFilterArenaPanel",
    "PremadeGroupsFilterRBGPanel",
    "PremadeGroupsFilterDelvePanel",
    "PremadeGroupsFilterMiniPanel",
}

-- 面板底下的區塊。七個面板加起來只有這五種，各面板有哪幾個是它自己的事
-- （`Frame` 的 parentKey 查不到就跳過）。
local SECTION_KEYS = { "Group", "Dungeons", "Delves", "Advanced", "Sorting" }

local BUTTON_TEXTURE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }

------------------------------------------------------------
-- 「整組狀態圖中和掉、改畫一個線條圖記」的按鈕
--
-- `Skin.IconButton` 的 `opts.glyph` 會順便給按鈕一塊 `fill` 的底與 1px 邊，
-- 那對「獨立的一顆小鈕」是對的（最大化／最小化），但對**長在欄位裡的箭頭**
-- 是錯的 —— 會變成「框裡有框」。所以這一支只畫圖記、底全透明，
-- 跟 `Skin.ScrollBar` 的上下箭頭同一個形狀。
------------------------------------------------------------
local function SkinGlyphOnlyButton(btn, key, kind)
    if not E.Usable(btn, key) then return end

    for _, getter in ipairs(BUTTON_TEXTURE_GETTERS) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    E.ButtonStates(btn, key, nil, true)

    local ov = E.Overlay(btn, {
        key = key,
        noBorder = true,
        glyph = { kind = kind, size = T.glyphSize, thickness = 1, color = T.textDim },
    })
    E.Paint(ov, TRANSPARENT)
    -- 三態跟捲軸箭頭同一套：閒置 textDim／滑過 text／停用 textDisabled
    E.TrackGlyph(btn, ov, { idle = T.textDim, trackHover = true, trackEnabled = true })
end

------------------------------------------------------------
-- 它自己那一種下拉（出處與為什麼不能用 `Skin.Dropdown` 見檔頭第 5 點）
------------------------------------------------------------
local DROPDOWN_ART = { "Left", "Middle", "Right" }

local function SkinDropDown(dd, key)
    if not E.Usable(dd, key) then return end

    E.NeutralizeKeys(dd, DROPDOWN_ART, key)

    -- 矩形不能照框自己的 145x32 畫（第一版這樣做，實機是一個凸出視窗右緣、比旁邊輸入框
    -- 高一截的大方塊）：這個框是舊式下拉的外盒，**可見的欄位只佔中間一塊**，而且整個框
    -- 被錨在列的 `TOPRIGHT x=+13 y=+4`（UI/Templates.xml:32）刻意超出列的右緣，靠美術的
    -- 透明邊把多出來的部分藏掉。對齊的基準是同一欄的「最小值／最大值」輸入框：
    --   列高 23；Min 佔 x=-110..-70、Max 佔 x=-45..-5（相對列的右緣），y=-1..-21（同檔 :45-52）
    --   下拉框：右緣在 +13、寬 145 ⇒ 左緣在 -132；上緣在 +4、高 32 ⇒ 下緣在 -28
    -- ⇒ 左內縮 22（-132 → -110，對齊 Min 輸入框的左緣）、右內縮 18（+13 → -5，對齊 Max 的右緣）、
    --   上內縮 5（+4 → -1）、下內縮 7（-28 → -21）。
    --   （拿實機擷圖回推過：Min 框左緣、Max 框右緣、列距 23 三個數字都跟這組換算對得上。）
    local ov = E.Overlay(dd, {
        key = key,
        points = {
            { "TOPLEFT", "TOPLEFT", 22, -5 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", -18, 7 },
        },
    })
    E.Paint(ov, T.fillInset, T.border)

    local btn = Field(dd, "Button")
    if btn then SkinGlyphOnlyButton(btn, key .. ".Button", "chevronDown") end
    return ov
end

------------------------------------------------------------
-- 它自己那一種小文字鈕（全選／全不選／反選／獎勵探究）
--
-- `Bg` 是它自己畫的 0.08 深灰 ＋ 一張金色 HighlightTexture。底與滑過換成套組的，
-- `Label` 不碰（mixin 每次滑過都重設顏色，見檔頭「刻意不碰」）。
------------------------------------------------------------
local function SkinTextButton(btn, key)
    if not E.Usable(btn, key) then return end

    E.NeutralizeKeys(btn, { "Bg" }, key)
    E.ButtonStates(btn, key, nil, true)

    local ov = E.Overlay(btn, { key = key })
    E.Paint(ov, T.fill, T.border)
    E.TrackButtonHover(btn, ov, T.fill)
    return ov
end

------------------------------------------------------------
-- 一列篩選條件（`Basic` / `MinMax` / `Dropdown` 三個模板的共同形狀）
--
-- 認人只看 parentKey 在不在，不看它是哪個模板 —— 三個模板是繼承關係，
-- `MinMax` 與 `Dropdown` 都是 `Basic` 多長出來的東西。
------------------------------------------------------------
local function SkinFilterRow(row, key)
    local act = Field(row, "Act")
    if act then Skin.CheckBox(act, key .. ".Act") end

    for _, side in ipairs({ "Min", "Max" }) do
        local box = Field(row, side)
        if box then Skin.EditBox(box, key .. "." .. side) end
    end

    local dd = Field(row, "DropDown")
    if dd then SkinDropDown(dd, key .. ".DropDown") end
end

------------------------------------------------------------
-- 一個區塊（篩選／地城／探究／進階過濾式／排序）
--
-- 列是**走 `GetChildren()` 認的**，不抄一張「這個面板有哪幾列」的表：
-- 那張表每個賽季都會變（地城八格、探究十五格），抄下來就是每季要維護一次，
-- 而漏抄的症狀是「某一列沒有皮」——看得到但找不出原因。
-- `GetChildren()` 讀的是**結構**不是值（STYLE.md ③ 的讀取例外表同一條）。
------------------------------------------------------------
local function SkinSection(sec, key)
    if not E.Usable(sec, key) then return end

    -- 區塊標題是 `GameFontNormal`（暗金）⇒ 照 ④ 的文字層級改白。
    -- 靜態 FontString，`SetText` 不會把顏色打回來（`UI_Setup*` 只呼叫 `SetText`）。
    local title = Field(sec, "Title")
    if title then E.TextColor(title, T.text, key .. ".Title") end

    -- 進階過濾式（多行）與排序（單行）共用 parentKey `Expression`，型別不同：
    -- 前者是 `InputScrollFrameTemplate`（ScrollFrame）、後者是 `EditBox`。
    local exp = Field(sec, "Expression")
    if exp and type(exp.GetObjectType) == "function" then
        local ok, kind = pcall(exp.GetObjectType, exp)
        if ok and kind == "ScrollFrame" then
            Skin.InputScroll(exp, key .. ".Expression")
        elseif ok and kind == "EditBox" then
            Skin.EditBox(exp, key .. ".Expression")
        end
    end

    if type(sec.GetChildren) ~= "function" then return end
    local ok, kids = pcall(function() return { sec:GetChildren() } end)
    if not ok then return end

    for i, kid in ipairs(kids) do
        local ckey = key .. ".child" .. i
        if Field(kid, "Act") then
            SkinFilterRow(kid, ckey)
        elseif Field(kid, "Bg") and Field(kid, "Label") then
            SkinTextButton(kid, ckey)
        end
        -- 其餘（`Info` 說明鈕、`Alert` 警告圖、`Expression` 本身）刻意不碰，見檔頭
    end
end

------------------------------------------------------------
-- 篩選視窗本體
------------------------------------------------------------
local DIALOG_ART = { "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer" }

-- ⚠ 不走 `Skin.PortraitChrome`：那一支對「找不到的 parentKey」會記進
--   `Engine.Missing`，而伴隨元件**不准進那張清單**（STYLE.md ③ 第 2 條）。
--   逐一探就沒有這個問題，動作跟它一模一樣。
local MAXMIN_GLYPH = {
    MaximizeButton = "expand",    -- ＋
    MinimizeButton = "collapse",  -- −
}

local function SkinDialog(dlg)
    local key = DIALOG_NAME

    for _, k in ipairs(DIALOG_ART) do
        local region = Field(dlg, k)
        if region then E.Neutralize(region, key .. "." .. k) end
    end

    local titleContainer = Field(dlg, "TitleContainer")
    local titleText = titleContainer and Field(titleContainer, "TitleText")
    if titleText then E.TextColor(titleText, T.text, key .. ".TitleContainer.TitleText") end

    Skin.TitleBar(dlg, key)
    Skin.Panel(dlg, key)

    local close = Field(dlg, "CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end

    -- 最大化／最小化：跟試衣間同一套（三張紅底狀態圖整組中和、＋／− 自己畫）
    local maxmin = Field(dlg, "MaximizeMinimizeFrame")
    if maxmin then
        for k, glyph in pairs(MAXMIN_GLYPH) do
            local btn = Field(maxmin, k)
            if btn then
                Skin.IconButton(btn, key .. ".MaximizeMinimizeFrame." .. k, { glyph = glyph })
            end
        end
    end

    -- 重設／設定：`IconButtonTemplate`，只有一張 `Icon`（檔頭第 3 點）
    for _, k in ipairs({ "ResetButton", "SettingsButton" }) do
        local btn = Field(dlg, k)
        if btn then Skin.IconButton(btn, key .. "." .. k) end
    end

    local refresh = Field(dlg, "RefreshButton")
    if refresh then Skin.Button(refresh, key .. ".RefreshButton") end
end

------------------------------------------------------------
-- 進入點（`Skins/PVE.lua` 的 `companions` 呼叫，延一幀 ＋ 戰鬥閘 ＋ 脫戰補跑）
--
-- ⚠ 全域名字查不到就**靜默返回** —— 玩家沒裝那支插件不是改版事故。
-- ⚠ 冪等：`Engine.Overlay` 本來就只建一次，重跑（脫戰補跑）不會長出第二層。
------------------------------------------------------------
local function ApplyCompanions()
    local btn = _G[BUTTON_NAME]
    if btn then Skin.CheckBox(btn, BUTTON_NAME) end

    local dlg = _G[DIALOG_NAME]
    if not dlg then return end

    SkinDialog(dlg)

    for _, name in ipairs(PANEL_NAMES) do
        local panel = _G[name]
        if panel then
            for _, sectionKey in ipairs(SECTION_KEYS) do
                local sec = Field(panel, sectionKey)
                if sec then SkinSection(sec, name .. "." .. sectionKey) end
            end
        end
    end
end

ns.PVESkin.ApplyCompanions = ApplyCompanions
