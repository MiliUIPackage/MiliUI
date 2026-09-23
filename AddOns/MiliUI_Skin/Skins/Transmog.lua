------------------------------------------------------------
-- 配方：塑形師（`TransmogFrame`，隨需載入 `Blizzard_Transmog`）
--
-- ⚠ 12.x 的塑形師**不是** `WardrobeFrame` 了：舊的 `WardrobeFrame`＋`WardrobeTransmogFrame`
--   整組被換成新的 `TransmogFrame`（外觀套組／情境／自訂套組那一版），住在自己的
--   隨需載入插件 `Blizzard_Transmog`（TOC 的 Dependencies 帶 `Blizzard_TransmogShared`）。
--   收藏視窗的外觀頁（`WardrobeCollectionFrame`，`Skins/CollectionsWardrobe.lua`）是另一個框。
--
-- 做法照「成熟同類實作」的塑形師那一段搬過來（範圍、哪裡不碰），外觀換成我們的原語：
--   它的範圍 ＝ chrome ＋ 動作控件；**模型、塑形部位格、內嵌的外觀清單留原樣**。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_Transmog/Blizzard_Transmog.toc  LoadOnDemand；載入順序 Templates.xml → .lua → .xml
--   Blizzard_Transmog/Blizzard_Transmog_Bootstrap.lua:3-15
--     `RegisterPlayerInteraction(Transmogrifier, { frame = "TransmogFrame", loadFunc })`
--   Blizzard_Transmog/Blizzard_Transmog.xml:4
--     `TransmogFrame` ← `PortraitFrameTemplate`（toplevel，1618x883）
--     ⇒ `NineSlice`／`PortraitContainer`／`Bg`／`TopTileStreaks`／`TitleContainer.TitleText`／`CloseButton`
--       （Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:597-633）
--   同檔 :10  `HelpPlateButton`（MainHelpPlateButton）
--   同檔 :15-190  `OutfitCollection`（frameLevel 1）：
--     `Background`（transmog-outfit-darkbg）／`GradientTop`／`GradientBottom`／`DividerBar`／
--     `ShowEquippedGearSpellFrame`（UIPanelSpellButtonFrameTemplate）／
--     `OutfitList`（`ScrollBox` ← WowScrollBoxList、`ScrollBar` ← **MinimalScrollBar**，:111,117）／
--     `PurchaseOutfitButton`（自訂四張狀態圖）／
--     `SaveOutfitButton`（**SharedButtonTemplate**，:153）／`MoneyFrame`（common-currencybox-a）
--   同檔 :192  `OutfitPopup`（IconSelectorPopupFrameTemplate，HIGH strata）
--   同檔 :200-454  `CharacterPreview`：`Background`（transmog-locationbg）／`SavedFrame` 一整組動畫／
--     `Gradients`／`ClearAllPendingButton`／`ModelScene`（PanningModelSceneMixinTemplate）／
--     `ToggleOptions`（**VerticalLayoutFrame**，三個 toggle，各自 `.Checkbox` ← MinimalCheckboxArtTemplate
--      ＋ `.Text`，:360-422）／`LeftSlots`／`RightSlots`／`BottomSlots`（Layout frame，塑形部位格）
--   同檔 :456-818  `WardrobeCollection`（TabSystemOwnerTemplate）：
--     `Background`／`TabHeaders`（**TabSystemTemplate**，分頁模板
--      `TransmogWardrobeCollectionTabTemplate`，:467-476）／
--     `TabContent`（frameLevel 100；`Background` atlas transmog-tabs-frame-bg **useAtlasSize**、
--      錨 TOPLEFT 4,-4；`Border` atlas transmog-tabs-frame 661x841、錨 TOPLEFT -11,12，:478-496）
--       `ItemsFrame`：`FilterButton`（WowStyle1FilterDropdownTemplate）／`SearchBox`（TransmogSearchBoxTemplate）／
--         `WeaponDropdown`（WowStyle1DropdownTemplate）／`DisplayTypes`／`PagedContent.PagingControls`／
--         `SecondaryAppearanceToggle.Checkbox`／`WeaponSheatheDropdown`（:517-600）
--       `SetsFrame`：`FilterButton`／`SearchBox`／`PagedContent.PagingControls`（:614-667）
--       `CustomSetsFrame`：`NewCustomSetButton`（SharedButtonTemplate）／`PagedContent.PagingControls`（:675-724）
--       `SituationsFrame`：`DescriptionText`／`DefaultsButton`（SharedButtonTemplate）／
--         `Situations`（**VerticalLayoutFrame**，`Background`）／`EnabledToggle.Checkbox`／
--         `ApplyButton`（SharedButtonTemplate）／`UndoButton`（IconButtonTemplate）（:732-812）
--   Blizzard_Transmog/Blizzard_TransmogTemplates.xml:594-617
--     `TransmogWardrobeCollectionTabTemplate` ← **TabSystemTopButtonTemplate**（isTabOnTop）
--      ＋ `SelectedHighlight`（子框 frameLevel 200，`Highlight` 貼圖 transmog-tab-hl）
--   同檔 :619  `TransmogSearchBoxTemplate` ← **SearchBoxNineSliceTemplate**
--     （Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:438-455：`Background`
--      atlas common-searchbar-a setAllPoints ＋ `searchIcon` ＋ `clearButton.Icon`；**沒有 Left/Right/Middle**）
--   同檔 :1291-1313  `TransmogSituationTemplate`（`Title` ＋ `Dropdown` ← WowStyle1DropdownTemplate）
--   Blizzard_Transmog/Blizzard_TransmogTemplates.lua:851-855
--     `TransmogWardrobeCollectionTabMixin:SetTabSelected` → **`TabSystemButtonArtMixin.SetTabSelected(self, …)`**
--     （明碼的全域表查詢 ⇒ `Engine.TabSystemHooks` 對 XML 期就建好的這四顆也接得到）
--     ＋ `self.SelectedHighlight:SetShown(isSelected)`
--   同檔 :1821  `TransmogSituationMixin:Init(elementData)`（池化列，`SituationFramePool`，
--     Blizzard_Transmog.lua:3035 `CreateFramePool("FRAME", self.Situations, "TransmogSituationTemplate")`、
--     :3087-3097 Acquire → `Init`；**第一次打開情境頁才建**）
--   Blizzard_Transmog/Blizzard_Transmog.lua:112-114  `TransmogFrameMixin:OnLoad` → `SetPortraitAtlasRaw`／`SetTitle`
--   同檔 :1478-1491  `TransmogWardrobeMixin:OnLoad` → `AddNamedTab` ×4（**XML 載入期**就建好）
--   同檔 :1522-1526  `TransmogWardrobeMixin:SetTab` → **`TabSystemOwnerMixin.SetTab(self, tabID)`**（全域表查詢）
--   同檔 :333-341  `UpdateCostDisplay` → `SaveOutfitButton:SetEnabled(canApply)` ＋
--     `GlowEmitterFactory:Show/Hide(SaveOutfitButton, …)`（綠色發光是它自己另建的框）
--   同檔 :458-475  `SaveOutfitButton` 的 OnClick → `C_TransmogOutfitInfo.CommitAndApplyAllPending`（**花金幣**）
--   同檔 :3053-3056  情境 `ApplyButton` 的 OnClick → `C_TransmogOutfitInfo.CommitPendingSituations`
--   Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:4-67,69-74
--     `ThreeSliceButtonTemplate`（`Left`／`Right`／`Center` 三張 BACKGROUND，**沒有 Disabled／Pushed 貼圖**）
--     ← `BigRedThreeSliceButtonTemplate` ← `SharedButtonTemplate`（NormalFont GameFontNormal）
--   Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.lua:19-24,88-107
--     `InitButton` 只在 `Controller` 的 OnLoad 跑一次（SharedUIPanelTemplates.lua:978-982）→
--     `SetHighlightAtlas(...-Highlight)`；`UpdateButton` 每次狀態改變只對 Left/Center/Right `SetAtlas`
--     ⇒ **alpha 中和撐得住**，Highlight 那張之後沒有 Lua 重設。
--
------------------------------------------------------------
-- ## 做了什麼
--
-- * 外框：`Skin.PortraitChrome`（NineSlice／頭像／Bg／TopTileStreaks 中和、標題白字、標題帶）
--   ＋ `Skin.Panel` ＋ 關閉鈕。
-- * 右側外觀瀏覽器：
--   - 頂部四顆分頁（物品／套裝／自訂套裝／情境）：`Skin.TabSystemAll`（`onTop`）＋ 每顆的
--     `SelectedHighlight` 子框 alpha 0（它是選中時那條金色光帶；我們的選中線已經畫了）。
--     同步兩條路都接得到（檔頭出處）：`TabSystemButtonArtMixin.SetTabSelected` 的全域後置勾、
--     `TabSystemOwnerMixin.SetTab` 的全域後置勾。
--   - `TabContent` 的 `Background`／`Border` 中和，換一塊 `fillInset` ＋ 黑邊，**矩形取 `Background`
--     那張貼圖**（alpha 0 之後照樣有矩形）—— 同類實作把邊框「坐在 Background 的矩形上」，
--     因為 `TabContent` 本身比看得到的清單大一圈。
--   - 兩個搜尋框（`Background` 中和 ＋ `Skin.EditBox`，這個模板沒有 Left/Right/Middle）、
--     兩顆篩選下拉、兩顆武器下拉、三組翻頁鈕、「副手肩甲」勾選框。
--   - 自訂套裝頁「新增套裝」：`Skin.ThreeSliceButton` primary（只開命名彈窗，不是受限請求）。
--   - 情境頁：啟用勾選框、池化的情境列下拉（`TransmogSituationMixin:Init` 後置勾）、
--     「套用」零腳本 primary、「預設值」零腳本 secondary。
-- * 左側外裝清單：捲軸；**「套用」（`SaveOutfitButton`，花金幣）零腳本 primary**。
-- * 中間預覽：只有左上角三個勾選框（隱藏未指派部位／收起武器／預覽武器）。
--
-- ## 刻意不碰（同類實作也不碰，理由各自寫）
--
-- * **`CharacterPreview` 的 `ModelScene`、背景、`SavedFrame` 動畫、塑形部位格（三個 Layout frame
--   裡的 `TransmogAppearanceSlotTemplate`／`TransmogIllusionSlotTemplate`）**：模型場景是內容；
--   部位格的外框是「已變更／待套用／隱藏」的**狀態**，暴雪依 pending 狀態每次重設。
-- * **外觀格子**（`PagedContent` 裡的 `TransmogItemModelTemplate`／`TransmogSetModelTemplate` ——
--   `DressUpModel`）：跟收藏視窗外觀頁同一條（`Skins/CollectionsWardrobe.lua`），已收藏／可用／
--   已選中的外框是狀態。`DisplayTypes` 那兩顆圓形鈕（圓框 atlas 本身是狀態，:1950,1960 換 atlas）。
-- * **外裝清單的列**（`TransmogOutfitEntryTemplate`）：同類實作明列「內嵌清單留原樣」；列上有
--   右鍵選單與改名、圖示選擇，接觸面沒查完。
-- * `OutfitCollection`／`WardrobeCollection`／`CharacterPreview` 的深色底圖與漸層、`MoneyFrame` 的
--   錢框、情境容器的 `Background`：本來就是深色的內容底材／數值容器，同類實作也沒動。
-- * `PurchaseOutfitButton`（購買外裝欄位，自訂的三態 atlas ＋ 綠字＝「還能買」的狀態）、
--   `ShowEquippedGearSpellFrame`（**法術按鈕**，點下去是施法）、`ClearAllPendingButton`、
--   情境頁的 `UndoButton`、`HelpPlateButton`（HelpTip 系統）、`OutfitPopup`（共用的圖示選擇彈窗）。
-- * 三個 toggle 的 `Text`：暴雪用 `SetFontObject(勾了 ? Highlight : Normal)` 表示開關狀態
--   （Blizzard_Transmog.lua:1088,1098,1109,1657,2050,3107）—— 那是資訊。
-- * `SaveOutfitButton` 的綠色發光（`GlowEmitterFactory` 自己的框，「有變更可以套用」的提示）。
--
-- ## 照抄不了的地方（同類實作有、我們契約不准）
--
-- * 它把分頁那一排 `TabHeaders` 整排往上移 6（`ClearAllPoints`／`SetPoint`）——不准重排。
-- * 它把篩選鈕的文字改成靠左（對 `Text` 重錨）——不准重排。
-- * 它把「套用」的邊框拿掉、按鈕高度減 2（`SetHeight`）——不准改尺寸；我們照零腳本 primary 畫。
-- * 它對標題 `ClearAllPoints` 置中——不准重排；標題維持暴雪的位置。
-- * 它在 `TransmogFrame` 上 `HookScript("OnShow")` 每次開窗整份重跑 —— 我們不掛 OnShow：
--   查證過開窗（`TransmogFrameMixin:OnShow`，Blizzard_Transmog.lua:136-144）不會重設我們中和過的
--   任何一張（全部是 alpha，暴雪只 SetAtlas／SetShown），一次就撐得住。
-- * 它在 `SaveOutfitButton` 上掛 `OnEnable`／`OnDisable` 換字色 —— 這顆花金幣 ⇒ 零腳本；
--   停用的灰字交給暴雪自己的 `DisabledFont`（`GameFontDisable`）。
-- * 它的原始碼還在找 `TransmogFrame.ApplyButton`／`.OutfitDropdown` —— 12.1 live 的 XML 沒有這兩個
--   parentKey（舊版的遺跡），我們不寫。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `TransmogFrame` 的 NineSlice／PortraitContainer／Bg／TopTileStreaks | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `TransmogFrame` 本身 | `Engine.RegionBackdrop`（面板底＋邊＋標題帶，建成它自己的 BACKGROUND 貼圖） |
-- | `TitleContainer.TitleText` | `SetTextColor` |
-- | `CloseButton` | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture`（`Skin.CloseButton`） |
-- | 四顆分頁的 `RotatedTextures` | `SetAlpha(0)` ＋ `SetNormalFontObject`（`Skin.TabSystemAll`） |
-- | 四顆分頁的 `SelectedHighlight`（子框） | `SetAlpha(0)` |
-- | `TabContent.Background`／`.Border` | `SetAlpha(0)`；`TabContent` 自己的 `fillInset` 貼圖（錨在 `Background` 上） |
-- | 兩個搜尋框的 `Background`、`searchIcon`、`clearButton.Icon`、`Instructions` | `SetAlpha(0)` / `SetVertexColor` / `SetTextColor` |
-- | 六顆下拉（兩顆篩選、兩顆武器、情境列每列一顆） | `Background`／`Arrow` `SetAlpha(0)` ＋ ⌄ 圖記（`Skin.Dropdown`） |
-- | 三組翻頁鈕 | 三張狀態圖 `SetAlpha(0)` ＋ ‹ › 圖記（`Skin.IconButton`） |
-- | 五顆勾選框 | 四張狀態圖 `SetAlpha(0)`／`SetColorTexture`／勾的 `SetTexture`＋`SetVertexColor`（`Skin.CheckBox`） |
-- | `OutfitList.ScrollBar` | Track／Thumb／Back／Forward `SetAlpha(0)`／`SetVertexColor`（`Skin.ScrollBar`） |
-- | `NewCustomSetButton` | `Left`／`Right`／`Center` `SetAlpha(0)` ＋ `SetNormalFontObject` ＋ Highlight 中和 ＋ `HookScript("OnEnter"/"OnLeave"/"OnEnable"/"OnDisable")`（`Skin.ThreeSliceButton`） |
-- | **零腳本**：`SaveOutfitButton`、情境 `ApplyButton`／`DefaultsButton` | `Left`／`Right`／`Center` `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`（primary 另 `SetDisabledTexture` 一張白貼圖，`Engine.ScriptlessButton`）。**零 HookScript** |
--
-- ### 讀了什麼
--
-- 只有結構：parentKey 與 `TabHeaders:GetChildren()`（認分頁、認 `SelectedHighlight`）。
-- **不讀** `elementData`、外裝／情境資料、`self.tabs`、`SituationFramePool`。
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `TabSystemButtonArtMixin:SetTabSelected` | 全域 mixin 後置勾（`Engine.TabSystemHooks`，既有、冪等） | 第一行查弱鍵表 |
-- | `TabSystemOwnerMixin:SetTab` | 全域 mixin 後置勾（`Engine.TabSystemOwnerHooks`，既有、冪等） | 只呼叫 `Engine.SyncTabSystemAll()` |
-- | `TransmogSituationMixin:Init` | mixin 後置勾（`Engine.HookRows`，池化列第一次開情境頁才建 ⇒ 裝在 `hooks` 來得及） | 只把那一列的 `Dropdown` 交給 `Skin.Dropdown`。**不讀 `elementData`** |
-- | 原語內建的 `HookScript("OnEnter"/"OnLeave")`（＋翻頁鈕與 primary 一般按鈕的 `OnEnable`/`OnDisable`） | frame script 後掛 | 只對分頁、下拉、勾選框、關閉鈕、翻頁鈕、`NewCustomSetButton`；內容只換我們自己 overlay 的顏色 |
--
-- **`hooksecurefunc` 在 `TransmogFrame` 或它任何子框上：0 支。`HookScript("OnShow")`：0 支。**
-- **零腳本按鈕（套用、情境套用／預設值）上的 `HookScript`：0 支。**
-- **`hooksecurefunc` 在任何 `C_TransmogOutfitInfo` 函式上：0 支。**
--
-- ### 套組裡別人掛在這個框上的東西
--
-- 一支第三方工具插件在 `TransmogFrame` 上放自己的拖曳鈕（自己的框）。我們只點名具名
-- parentKey、不做遞迴掃，碰不到它。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 小工具（跟 `Skins/PlayerSpells.lua` 同一組寫法）
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

-- 「有就做、沒有就靜默跳過」
local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

------------------------------------------------------------
-- 零腳本的三片式按鈕（特許的第二種用法，STYLE.md ⑦）
--
-- 跟 `Skins/PlayerSpells.lua` 的 `ScriptlessButton` 同一支，只差中間那一片叫 `Center`
-- （`ThreeSliceButtonTemplate.xml:33`）。先建 overlay 再中和（`Engine.Overlay` 對顯式保護框
-- 回 nil，倒過來寫會做出一顆隱形的「套用」）。
-- ⚠ Highlight 是 `InitButton` 在 OnLoad 用 `SetHighlightAtlas` 設的那一張；`Engine.ScriptlessButton`
--   的 primary 滑過假設它是 ADD（`SetHighlightAtlas` 不帶 blendMode 時的預設）—— 待實機確認。
-- ⚠ 這個模板沒有 DisabledTexture ⇒ `Engine.ScriptlessButton` 會替它設一張（STYLE.md ③ 的
--   `SetDisabledTexture` 條）；`ThreeSliceButtonMixin:UpdateButton` 只碰 Left/Center/Right，打不回來。
-- TODO(升格): 第四份配方用到零腳本按鈕了（三片式這一版是第一次）—— 收成 `Skin.ScriptlessButton(btn, key, variant, { art = … })`。
------------------------------------------------------------
local THREE_SLICE_ART = { "Left", "Right", "Center" }

local function ScriptlessThreeSlice(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end
    E.NeutralizeKeys(btn, THREE_SLICE_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)   -- **不掛腳本**
    return ov
end

------------------------------------------------------------
-- 共用小塊
------------------------------------------------------------

-- `TransmogSearchBoxTemplate` ← `SearchBoxNineSliceTemplate`：美術是一整張 `Background`
-- （setAllPoints），沒有 Left/Right/Middle ⇒ 先中和那一張，`Skin.EditBox` 找不到 `Left`
-- 就照輸入框自己的矩形畫（142x19，正好是那張底的大小）。
local function SkinSearchBox(box, key)
    if not E.Usable(box, key) then return end
    E.NeutralizeKeys(box, { "Background" }, key)
    Skin.EditBox(box, key)
end

-- `PagingControlsHorizontalTemplate`（Blizzard_PagedContent/Blizzard_PagingControls.xml:69,74）
-- 同 `Skins/PlayerSpells.lua` 的法術書翻頁鈕
local PAGING_GLYPH = { PrevPageButton = "chevronLeft", NextPageButton = "chevronRight" }

local function SkinPaging(page, key)
    local paged = Sub(page, "PagedContent", key .. ".PagedContent")
    local pc = paged and Sub(paged, "PagingControls", key .. ".PagedContent.PagingControls")
    if not pc then return end
    for _, k in ipairs({ "PrevPageButton", "NextPageButton" }) do
        local pkey = key .. ".PagingControls." .. k
        local btn = Sub(pc, k, pkey)
        if btn then
            Skin.IconButton(btn, pkey, {
                inset = 4,
                glyph = PAGING_GLYPH[k],
                glyphColor = T.textDim,
                trackEnabled = true,
            })
        end
    end
end

-- toggle 那一種「一個小框 ＋ `.Checkbox` ＋ `.Text`」：只畫勾選框，字不碰（見檔頭）
local function SkinToggle(owner, name, key)
    local toggle = Optional(owner, name)
    if not toggle then
        E.Missing(key .. "." .. name)
        return
    end
    WithSub(toggle, "Checkbox", key .. "." .. name .. ".Checkbox", function(cb, label)
        Skin.CheckBox(cb, label)
    end)
end

------------------------------------------------------------
-- 左：外裝清單
------------------------------------------------------------
local function SkinOutfitCollection(oc, key)
    if not E.Usable(oc, key) then return end

    local list = Sub(oc, "OutfitList", key .. ".OutfitList")
    if list then
        WithSub(list, "ScrollBar", key .. ".OutfitList.ScrollBar", function(bar, label)
            Skin.ScrollBar(bar, label)
        end)
    end

    -- 「套用」：按下去是 `CommitAndApplyAllPending`（花金幣）⇒ 零腳本；
    -- 這一塊唯一的執行鈕 ⇒ primary（判準第 2 條）。
    WithSub(oc, "SaveOutfitButton", key .. ".SaveOutfitButton", function(btn, label)
        ScriptlessThreeSlice(btn, label, "primary")
    end)
end

------------------------------------------------------------
-- 中：預覽 —— 只有左上角三個勾選框
------------------------------------------------------------
local PREVIEW_TOGGLES = { "HideIgnoredToggle", "SheatheWeaponToggle", "PreviewedWeaponToggle" }

local function SkinCharacterPreview(cp, key)
    if not E.Usable(cp, key) then return end
    -- ⚠ `ToggleOptions` 是 VerticalLayoutFrame：我們只在它**孫子**（`.Checkbox`）身上掛 overlay，
    --   它 `GetLayoutChildren` 走訪的是三個 toggle 小框，多不出東西（陷阱 2）。
    local opts = Sub(cp, "ToggleOptions", key .. ".ToggleOptions")
    if opts then
        for _, name in ipairs(PREVIEW_TOGGLES) do
            SkinToggle(opts, name, key .. ".ToggleOptions")
        end
    end
end

------------------------------------------------------------
-- 右：外觀瀏覽器
------------------------------------------------------------
local function SkinTabHeaders(th, key)
    Skin.TabSystemAll(th, key, { onTop = true })

    -- 每顆分頁的 `SelectedHighlight`（選中時的金色光帶，frameLevel 200 的子框）：
    -- 我們的選中態已經是「底亮一階 ＋ 上緣一條職業色線」，同一個訊號不講兩次。
    -- 暴雪只對它 `SetShown`（TransmogTemplates.lua:854）⇒ alpha 0 一次就撐得住。
    if type(th.GetChildren) ~= "function" then return end
    local ok, children = pcall(function() return { th:GetChildren() } end)
    if not ok then return end
    local n = 0
    for _, tab in ipairs(children) do
        local hl = Optional(tab, "SelectedHighlight")
        if hl then
            n = n + 1
            E.Neutralize(hl, key .. "." .. n .. ".SelectedHighlight")
        end
    end
end

local function SkinTabContent(tc, key)
    if not E.Usable(tc, key) then return end

    -- 內容底：`Background`（transmog-tabs-frame-bg，useAtlasSize，TOPLEFT 4,-4）才是
    -- 看得到的清單矩形；`TabContent` 本身 644x823、比它大一圈，`Border` 那張又往外凸 11/12。
    -- ⇒ 兩張中和，我們的底與邊**錨在 `Background` 的矩形上**（中和的是 alpha，矩形還在）。
    local bg = Optional(tc, "Background")
    E.NeutralizeKeys(tc, { "Background", "Border" }, key)
    local ov = E.RegionBackdrop(tc, {
        key = key,
        points = bg and {
            { "TOPLEFT", "TOPLEFT", 0, 0, rel = bg },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, rel = bg },
        } or nil,
    })
    E.Paint(ov, T.fillInset, T.border)

    -- 物品頁
    WithSub(tc, "ItemsFrame", key .. ".ItemsFrame", function(items, ikey)
        WithSub(items, "FilterButton", ikey .. ".FilterButton", function(dd, label)
            Skin.Dropdown(dd, label, "filter")
        end)
        WithSub(items, "SearchBox", ikey .. ".SearchBox", SkinSearchBox)
        for _, name in ipairs({ "WeaponDropdown", "WeaponSheatheDropdown" }) do
            WithSub(items, name, ikey .. "." .. name, function(dd, label)
                Skin.Dropdown(dd, label, "style1")
            end)
        end
        SkinPaging(items, ikey)
        SkinToggle(items, "SecondaryAppearanceToggle", ikey)
    end)

    -- 套裝頁
    WithSub(tc, "SetsFrame", key .. ".SetsFrame", function(sets, skey)
        WithSub(sets, "FilterButton", skey .. ".FilterButton", function(dd, label)
            Skin.Dropdown(dd, label, "filter")
        end)
        WithSub(sets, "SearchBox", skey .. ".SearchBox", SkinSearchBox)
        SkinPaging(sets, skey)
    end)

    -- 自訂套裝頁：「新增套裝」只開命名彈窗（不是受限請求）⇒ 一般原語、primary
    WithSub(tc, "CustomSetsFrame", key .. ".CustomSetsFrame", function(cs, ckey)
        WithSub(cs, "NewCustomSetButton", ckey .. ".NewCustomSetButton", function(btn, label)
            Skin.ThreeSliceButton(btn, label)
        end)
        SkinPaging(cs, ckey)
    end)

    -- 情境頁：「套用」送出情境設定 ⇒ 零腳本 primary；「預設值」同一塊的另一顆 ⇒ 零腳本 secondary
    WithSub(tc, "SituationsFrame", key .. ".SituationsFrame", function(sf, fkey)
        WithSub(sf, "ApplyButton", fkey .. ".ApplyButton", function(btn, label)
            ScriptlessThreeSlice(btn, label, "primary")
        end)
        WithSub(sf, "DefaultsButton", fkey .. ".DefaultsButton", function(btn, label)
            ScriptlessThreeSlice(btn, label, "secondary")
        end)
        SkinToggle(sf, "EnabledToggle", fkey)
    end)
end

------------------------------------------------------------
-- 池化的情境列：只換下拉
--
-- ⚠ `Title` 的顏色不碰：`RefreshSituations`（Blizzard_Transmog.lua:3113-3116）依「情境啟用與否」
--   每次重設它 —— 那是狀態。下拉的啟用／停用也是暴雪 `SetEnabled`，我們的原語只換長相。
------------------------------------------------------------
local function ApplySituationRow(row)
    local dd = Optional(row, "Dropdown")
    if dd then Skin.Dropdown(dd, "TransmogSituation.Dropdown", "style1") end
end

local function InstallHooks()
    E.TabSystemHooks()
    E.TabSystemOwnerHooks()
    E.HookRows{
        key    = "TransmogSituation",
        mixin  = _G.TransmogSituationMixin,
        method = "Init",
        apply  = ApplySituationRow,
    }
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Apply()
    local f = _G.TransmogFrame
    if not f then
        E.Missing("TransmogFrame")
        return
    end

    Skin.PortraitChrome(f, "TransmogFrame")
    Skin.Panel(f, "TransmogFrame")
    WithSub(f, "CloseButton", "TransmogFrame.CloseButton", function(btn, label)
        Skin.CloseButton(btn, label)
    end)

    WithSub(f, "OutfitCollection", "TransmogFrame.OutfitCollection", SkinOutfitCollection)
    WithSub(f, "CharacterPreview", "TransmogFrame.CharacterPreview", SkinCharacterPreview)

    WithSub(f, "WardrobeCollection", "TransmogFrame.WardrobeCollection", function(wc, key)
        WithSub(wc, "TabHeaders", key .. ".TabHeaders", SkinTabHeaders)
        WithSub(wc, "TabContent", key .. ".TabContent", SkinTabContent)
    end)

    -- 四顆分頁在 XML 載入期就建好 ⇒ 建立時讀一次選中態，之後由兩支全域後置勾同步
    E.SyncTabSystemAll()
end

E.Register{
    key   = "transmog",
    addon = "Blizzard_Transmog",
    title = L["Transmogrifier"],
    hooks = InstallHooks,
    apply = Apply,
}
