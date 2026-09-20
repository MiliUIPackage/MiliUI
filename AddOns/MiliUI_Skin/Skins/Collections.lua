------------------------------------------------------------
-- 配方：收藏（CollectionsJournal 外框 ＋ 坐騎 MountJournal）
--
-- 這一份是收藏視窗的**第一支**：外框、關閉鈕、底部六顆分頁，以及坐騎頁。
-- 同一個視窗的其餘四頁在
--   Skins/CollectionsToys.lua      玩具箱／傳家寶／戰隊場景
--   Skins/CollectionsPets.lua      寵物日誌
--   Skins/CollectionsWardrobe.lua  外觀
-- 四份各自 `E.Register`，但**共用同一個設定 key `collections`** ——
-- 玩家看到的是一個視窗，設定裡就只該有一個勾選框（STYLE.md ⑥ 第 5 條）。
-- `Engine.RunRecipe` 的閘是 `ns.DB.IsWindowEnabled(rec.key)`，key 相同的配方會一起
-- 開關，不需要動 Engine；`title` 各自不同，`/mskin debug` 仍然分得出是哪一支。
--
-- 這一支另外把「四份都要用」的小工具掛在 `ns.CollectionsSkin` 上（分頁原語的替身、
-- `CollectionsBackgroundTemplate` 的美術清單、進度條、翻頁鈕），TOC 保證它先載入。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_Collections/Mainline/Blizzard_Collections.xml:5    CollectionsJournalTab ← PanelTabButtonTemplate
--   Blizzard_Collections/Mainline/Blizzard_Collections.xml:14   CollectionsJournal（PortraitFrameTemplate）
--   Blizzard_Collections/Mainline/Blizzard_Collections.xml:20-49  六顆分頁與它們的錨點
--   Blizzard_Collections/Mainline/Blizzard_Collections.lua:3-6  CollectionsJournal_SetTab → PanelTemplates_SetTab
--   Blizzard_Collections/Mainline/Blizzard_Collections.lua:60-67 CheckAndDisplayHeirloomsTab 每次 OnShow 重錨外觀分頁
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:80   MountListButtonTemplate
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:217  MountJournal
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:333,340,397  LeftInset／BottomLeftInset／RightInset
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:403  searchBox（SearchBoxTemplate）
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:413  FilterDropdown（WowStyle1FilterDropdownTemplate）
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:421  MountCount（InsetFrameTemplate3）
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:442,449  MountDisplay ＋ YesMountsTex／NoMountsTex
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:467,477  MountDisplay.InfoButton 與它的 Icon
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:523  MountDisplay.ModelScene
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:568,575  ScrollBox ＋ ScrollBar（MinimalScrollBar）
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:582  MountButton（MagicButtonTemplate）
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.lua:152  view:SetElementInitializer → MountJournal_InitMountButton
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.lua:328-411  MountJournal_InitMountButton
--   Blizzard_Collections/Mainline/Blizzard_MountCollection.lua:730-760  MountJournal_UpdateMountDisplay（InfoButton.Icon 每次 SetTexture）
--   Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:5    CollectionsProgressBarTemplate
--   Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:170,178,186  翻頁鈕與 CollectionsPagingFrameTemplate
--   Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.lua:130  CollectionItemListButton_SetRedOverlayShown
--   Blizzard_SharedXML/Mainline/SharedCollectionTemplates.xml:56  CollectionsBackgroundTemplate（← InsetFrameTemplate ＋ 21 張裝飾）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:905  PanelTabButtonTemplate（九張 TabTextures）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:722  MagicButtonTemplate ← UIPanelButtonTemplate
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:393  TAB_SIDES_PADDING = 20
--   Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:724  InsetFrameTemplate3（八片邊 ＋ Bg）
--
-- 查證後跟計畫假設不一樣的四件事：
--   1. **分頁是 `PanelTabButtonTemplate` 不是 `TabSystem`。** 狀態走
--      `CollectionsJournal_SetTab` → `PanelTemplates_SetTab`（.lua:3-6），Engine 的
--      三個後置勾會照常觸發 ⇒ 分頁這一輪做得了。
--      （外觀頁自己的兩顆頂部分頁是 `PanelTopTabButtonTemplate`，也是同一家族，
--       見 Skins/CollectionsWardrobe.lua。好友名單那種 `TabSystemButtonTemplate`
--       這裡一顆都沒有。）
--   2. **分頁的按鈕矩形彼此重疊 16**（`LEFT → RIGHT x="-16"`，.xml:27,32,37,42,47），
--      不是角色面板那種「間隔 1」。所以 `Skin.Tab` 的「往右多畫 7」在這裡是反效果：
--      後建的那顆會壓掉前一顆右邊 16＋7＝23，而分頁文字只內縮 10（TAB_SIDES_PADDING
--      ／2）⇒ 前一顆文字的尾巴 6 像素會落在鄰居的底色上。
--      ⇒ 這一份用自己的 `SkinPanelTab`，overlay **左右各內縮 8**，相鄰兩顆的矩形
--        剛好首尾相接（`left_{n+1}+8 = right_n-16+8 = right_n-8`），文字也整段落在
--        自己的底色上。⚠ 例外是「外觀」那一顆：`CollectionsJournal_CheckAndDisplay
--        HeirloomsTab`（.lua:60-67）每次 OnShow 都把它重錨成 `RIGHT x=+3`
--        （不是 −16），所以它的左邊要改成 −11 才接得上（＋3 的間隔 ＋ 8 的內縮）。
--   3. **「坐騎召喚」不是 secure 按鈕。** `MountJournal.MountButton` 是
--      `MagicButtonTemplate` ← `UIPanelButtonTemplate`（SharedUIPanelTemplates.xml:722），
--      OnClick 是普通 Lua（`MountJournalMountButton_OnClick`）⇒ `Skin.Button` 適用。
--      真正 secure 的是**玩具／傳家寶的格子**（`CollectionsSpellButtonTemplate` 繼承
--      `SecureFrameTemplate`，Blizzard_CollectionTemplates.xml:39），那一批的處理
--      寫在 Skins/CollectionsToys.lua 的檔頭。
--   4. **坐騎列沒有 mixin**，`MountListButtonTemplate` 的初始化走**全域函式**
--      `MountJournal_InitMountButton`（.lua:328）⇒ `Engine.HookRows{ mixin = _G }`。
--
------------------------------------------------------------
-- ## taint 接觸面清單（外框 ＋ 坐騎）
--
-- | 物件 | 動作 |
-- |---|---|
-- | CollectionsJournal.NineSlice / .Bg / .TopTileStreaks / .PortraitContainer | SetAlpha(0) |
-- | CollectionsJournal.TitleContainer.TitleText | SetTextColor |
-- | CollectionsJournalTab1..6 的九張 TabTextures | SetAlpha(0) |
-- | CollectionsJournalTab1..6 | SetNormalFontObject(GameFontHighlightSmall) |
-- | CollectionsJournal.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | CollectionsJournal.CloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | MountJournal.LeftInset / .BottomLeftInset / .RightInset 的 Bg / NineSlice | SetAlpha(0) |
-- | MountJournal.BottomLeftInset 自己的裝飾貼圖（含無名的 mountequipment-insetshadow） | SetAlpha(0)（GetRegions 掃） |
-- | MountJournal.MountCount 的八片邊 ＋ Bg | SetAlpha(0) |
-- | MountJournal.searchBox 的 Left/Right/Middle | SetAlpha(0) |
-- | MountJournal.searchBox 的 searchIcon / clearButton.Icon / Instructions | SetVertexColor / SetTextColor |
-- | MountJournal.FilterDropdown.Background | SetAlpha(0) |
-- | MountJournal.MountButton 的 Left/Right/Middle | SetAlpha(0) |
-- | MountJournal.MountButton | SetNormalFontObject(GameFontHighlight) |
-- | MountJournal.ScrollBar 的 Track/Thumb 六張 | SetAlpha(0)；Back/Forward.Texture | SetVertexColor |
-- | MountJournal.MountDisplay.InfoButton.Icon | SetTexCoord（裁邊） |
-- | 坐騎列（池化）的 background | SetAlpha(0) |
-- | 坐騎列的 HighlightTexture | SetColorTexture（白 8%） |
-- | 坐騎列的 icon | SetTexCoord（裁邊，放 reapply） |
-- | 以上各框 | CreateFrame 掛自己的 overlay |
--
-- hook：
--   * Engine 的三個 `PanelTemplates_*` 全域後置勾（分頁選中態，`Engine.TrackTab` 代掛）
--   * 每顆分頁的 `HookScript("OnEnter"/"OnLeave")`（滑過態，同樣由 `Engine.TrackTab` 代掛）
--   * `Engine.HookRows{ mixin = _G, method = "MountJournal_InitMountButton" }` ×1
--   * `hooksecurefunc("MountJournal_UpdateMountDisplay", …)` ×1
--     —— 只為了重裁 `InfoButton.Icon` 的 texCoord（`SetTexture` 每次打回 0,1,0,1，
--        .lua:751,756）。整支 pcall，出錯一次就停用。
-- 寫入暴雪欄位：無。讀暴雪物件：只有 `Engine.TrackTab` 的 `LeftActive:IsShown()`
-- （讀取例外表第 4 條）與 `GetRegions`／`GetFrameLevel`。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`MountJournal.MountDisplay` 的兩張背景大圖**（`YesMountsTex`／`NoMountsTex`，
--   `Interface\PetBattles\MountJournal-BG`）與 **`ModelScene`**：那是內容底材，
--   `Name`／`Source`／`Lore` 的白／金字是為它設計的（內容底材規則）。只把外面的
--   `RightInset` 換成皮，模型與大圖原樣保留。`ShadowOverlay` 同理。
-- * **`MountJournal.SummonRandomFavoriteSpellFrame`／`ToggleDynamicFlightFlyoutButton`
--   ／`DynamicFlightFlyoutPopup`**：前者是 `UIPanelSpellButtonFrameTemplate`
--   （底下是 secure 的施法按鈕），後兩者是 `FlyoutButtonTemplate`／`FlyoutPopupTemplate`
--   的彈出系統。**動態飛行那一組是「按了會施法／開天賦樹」的路**，只做視覺也
--   得先確認它不是保護框 —— 這一輪一律不碰，列進回報。
-- * **`MountJournal.BottomLeftInset.SlotButton`（坐騎裝備格）**：那是拖放目標
--   （`OnReceiveDrag` → `C_MountJournal.ApplyMountEquipment`），而且它的
--   `SlotBorder`／`SlotBorderOpen`／`ItemBorder` 是**被暴雪 Show/Hide 的狀態貼圖**
--   （有沒有裝備、能不能放）。中和掉就看不出狀態，補畫又要讀狀態 ⇒ 不碰。
-- * **坐騎列的 `selectedTexture`（PetList-ButtonSelect）**：那是「目前選的是哪一隻」。
--   它在 OVERLAY 層、由暴雪 Show/Hide（.lua:363,366），我們的 overlay 在
--   目標層級 −1 ⇒ 它照樣看得見，直接留著當選中態。
--   **不染色**：`SetVertexColor` 雖然在白名單裡，但那張圖是金色的，乘上職業色會
--   變成第三種色相（藍職業乘金＝綠），違反「狀態只換明暗、色相不變」。
-- * **坐騎列的 `favorite`（星號）、`factionIcon`（陣營）、`new`／`newGlow`、
--   `DragButton` 的 `ActiveTexture`（目前召喚中）**：全部是資訊。
-- * **坐騎列 `name` 的字型物件**：`GameFontNormal`／`GameFontDisable` 由暴雪依
--   「這隻能不能用」切換（.lua:377,391），那是資訊不是裝飾。
-- * **列的紅色「已收集但不能用」訊號**：`CollectionItemListButton_SetRedOverlayShown`
--   （CollectionTemplates.lua:130-139）同時染 `background` 與 `icon`。我們中和了
--   `background`，但 `icon:SetVertexColor(150/255,50/255,50/255)` 那一半留著 ⇒
--   訊號還在。
-- * **`CollectionsJournal` 的 portrait 圖像**：`PortraitContainer` 整個中和掉，
--   跟其餘視窗一致。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 四份配方共用的小工具
------------------------------------------------------------
local Shared = {}
ns.CollectionsSkin = Shared

-- `PanelTabButtonTemplate` 的九張貼圖（`PanelTopTabButtonTemplate` 同名）
local TAB_TEXTURES = {
    "LeftActive", "MiddleActive", "RightActive",
    "Left", "Middle", "Right",
    "LeftHighlight", "MiddleHighlight", "RightHighlight",
}

-- TODO(升格): `Skin.Tab` 只吃 `kind`，矩形（左右內縮）與「相連的是哪一邊」都寫死成
--   「往右多畫 overhang、上邊不畫」。收藏視窗兩種分頁都不符合：底部六顆的按鈕矩形
--   互相**重疊** 16（往右多畫只會更糟），外觀頁那兩顆是**頂部**分頁（相連的是下邊）。
--   等 `Skin.Tab` 收了 `opts.points` / `opts.joined` 之後，這一支直接刪掉。
--   這裡只組合 Engine 的公開函式（Neutralize／Overlay／Paint／ButtonFonts／TrackTab），
--   契約與 `Skin.Tab` 完全一樣。
--
-- opts:
--   left / right  overlay 相對按鈕矩形的左右偏移（框架單位，Engine 會過 P.Scale）
--   joined        跟內容相連、因此不畫的那一邊（"TOP" ＝底部分頁／"BOTTOM" ＝頂部分頁）
function Shared.SkinPanelTab(tab, key, opts)
    if not E.Usable(tab, key) then return end
    opts = opts or {}

    local arr
    if pcall(function() arr = tab.TabTextures end) and type(arr) == "table" then
        for i, tex in ipairs(arr) do
            E.Neutralize(tex, key .. ".TabTextures[" .. i .. "]")
        end
    else
        -- 模板換掉了就退回逐一點名，parentKey 的名字是一樣的
        E.NeutralizeKeys(tab, TAB_TEXTURES, key)
    end

    local ov = E.Overlay(tab, {
        key = key,
        skipEdges = { opts.joined or "TOP" },
        points = {
            { "TOPLEFT", "TOPLEFT", opts.left or 0, 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", opts.right or 0, 0 },
        },
    })
    E.Paint(ov, T.fill, T.border)

    -- 未選中走 NormalFont；選中（＝Disabled 狀態）的白字由暴雪自己在
    -- PanelTemplates_SelectTab 設，不用我們管（STYLE.md 註 ⓔ）。
    E.ButtonFonts(tab, GameFontHighlightSmall, key)
    E.TrackTab(tab, ov, key)
    return ov
end

-- `InsetFrameTemplate3`（UIPanelTemplates.xml:724）：八片 Common-Input-Border ＋ Bg
local INSET3_KEYS = {
    "BorderTopLeft", "BorderTopMiddle", "BorderTopRight",
    "BorderLeftMiddle", "BorderRightMiddle",
    "BorderBottomLeft", "BorderBottomMiddle", "BorderBottomRight",
    "Bg",
}

function Shared.SkinInset3(frame, key)
    if not E.Usable(frame, key) then return end
    E.NeutralizeKeys(frame, INSET3_KEYS, key)
    local ov = E.Overlay(frame, { key = key })
    E.Paint(ov, T.fillInset, T.border)
    return ov
end

-- `CollectionsBackgroundTemplate`（SharedCollectionTemplates.xml:56）＝
-- `InsetFrameTemplate` ＋ 一張平鋪底 ＋ 8 張外陰影 ＋ 8 張內陰影 ＋ 4 個角花。
-- 全部是裝飾，整組中和之後交給 `Skin.Inset` 畫平面皮。
local COLLECTIONS_BG_ART = {
    "BackgroundTile",
    "ShadowCornerTopLeft", "ShadowCornerTopRight",
    "ShadowCornerBottomLeft", "ShadowCornerBottomRight",
    "ShadowCornerTop", "ShadowCornerLeft", "ShadowCornerRight", "ShadowCornerBottom",
    "OverlayShadowTopLeft", "OverlayShadowTopRight",
    "OverlayShadowBottomLeft", "OverlayShadowBottomRight",
    "OverlayShadowTop", "OverlayShadowLeft", "OverlayShadowRight", "OverlayShadowBottom",
    "BGCornerTopLeft", "BGCornerTopRight", "BGCornerBottomLeft", "BGCornerBottomRight",
}

function Shared.SkinCollectionsBackground(frame, key)
    if not E.Usable(frame, key) then return end
    E.NeutralizeKeys(frame, COLLECTIONS_BG_ART, key)
    return Skin.Inset(frame, key)
end

-- `CollectionsProgressBarTemplate`（Blizzard_CollectionTemplates.xml:5）的填充色。
--
-- ⚠ 抄自 XML 的 `<BarColor r="0.03125" g="0.85" b="0.0" />`（同檔 :36）。
--   那一行只在 frame 建立時生效一次；`Engine.BarTexture` 換掉填充貼圖之後 vertex
--   color 沒人補得回來，所以配方要把同一個綠色重下一次
--   （跟 Skins/Achievement.lua 的 `ACHIEVEMENT_BAR_GREEN` 同一個理由）。
-- ⚠ **不改成職業色**：綠＝進度是全遊戲通用的語彙，而且收藏視窗的職業色已經被
--   「分頁選中態」用掉了，一個視覺訊號只能有一個語意。
local COLLECTIONS_BAR_GREEN = { 0.03125, 0.85, 0 }

-- ⚠ 換材質的前提是「沒有程式讀回這張圖」。查過四支使用者
--   （ToyBox.lua:445、HeirloomCollection.lua:659、Wardrobe.lua:366、
--    Wardrobe_Sets.lua:170）全部只 `SetMinMaxValues`／`SetValue`／`SetShown` ＋
--   寫 `progressBar.text`，沒有 `GetAtlas()`／`GetTexture()` ⇒ 安全。
function Shared.SkinProgressBar(bar, key)
    -- `border`（UI-Character-Skills-BarBorder）與 BACKGROUND 層那張**無名**的純黑
    -- 一起掃掉：stripArt 走 GetRegions，填充貼圖會被排除。
    Skin.StatusBar(bar, key, { stripArt = true, color = COLLECTIONS_BAR_GREEN })
end

-- `CollectionsPagingFrameTemplate`（Blizzard_CollectionTemplates.xml:186）
--
-- ⚠ `inset = 4`：按鈕是 32x32，但 `UI-SpellbookIcon-PrevPage-Up` 的箭頭只佔中間
--   一小塊，框畫成整個矩形會比箭頭大一圈（同收件匣翻頁鈕）。
-- `PageText` 是 `CollectionsPageTextTemplate` ← `GameFontWhite`，本來就是白的，不碰。
function Shared.SkinPaging(frame, key)
    if not E.Usable(frame, key) then return end
    for _, k in ipairs({ "PrevPageButton", "NextPageButton" }) do
        local btn
        if pcall(function() btn = frame[k] end) and btn then
            Skin.IconButton(btn, key .. "." .. k, { inset = 4 })
        else
            E.Missing(key .. "." .. k)
        end
    end
end

-- 「某個 parentKey 底下掛了一條 MinimalScrollBar」的通用寫法
function Shared.SkinOwnedScrollBar(owner, key)
    local bar
    if owner and pcall(function() bar = owner.ScrollBar end) and bar then
        Skin.ScrollBar(bar, key)
    else
        E.Missing(key)
    end
end

-- 收藏視窗的清單列（坐騎與寵物長得一模一樣）：
--   `background`（PetList-ButtonBackground）中和、列底走 `Skin.Row` 的 `fill`、
--   滑過交給引擎（`HighlightTexture` → 白 8%）、圖示裁邊 ＋ 1px 邊。
--
-- ⚠ **不做隔行明暗**：那要知道自己是第幾列，而列號住在 `elementData` 裡 ——
--   契約禁止讀（STYLE.md ③）。收件匣那種固定七列才做得到。
function Shared.ApplyCompanionRow(row, key)
    Skin.Row(row, key, { keys = { "background" } })

    local icon
    if pcall(function() icon = row.icon end) and icon then
        -- owner 不給 ⇒ 邊直接錨在圖示貼圖上（`Skin.Icon` 的預設）
        Skin.Icon(icon, key .. ".icon")
    end
end

-- ⚠ 每次重用都要重裁：`icon:SetTexture(...)` 會把 texCoord 打回 0,1,0,1
--   （MountCollection.lua:333 / PetCollection.lua 的 InitPetButton 同樣）。
function Shared.ReapplyCompanionRow(row, key)
    local icon
    if pcall(function() icon = row.icon end) and icon then
        E.CropIcon(icon, key .. ".icon")
    end
end

------------------------------------------------------------
-- 外框
------------------------------------------------------------
-- 六顆分頁的 overlay 矩形（相對按鈕矩形的左右偏移）。
--
-- 幾何全部從 XML 的錨點換算，不量測（STYLE.md ④）：
--   * 分頁 2/3/4/6 錨 `LEFT → 前一顆的 RIGHT x="-16"` ⇒ 按鈕矩形重疊 16。
--     左右各內縮 8，相鄰兩顆的 overlay 就首尾相接。
--   * 分頁 5（外觀）被 `CollectionsJournal_CheckAndDisplayHeirloomsTab`
--     （Blizzard_Collections.lua:66）每次 OnShow 重錨成 `RIGHT x=+3` ⇒ 跟前一顆
--     之間是 3 的**間隔**不是重疊，左邊要往外拉 8+3＝11 才接得上。
--   * 文字內縮 10（TAB_SIDES_PADDING 20 的一半，SharedUIPanelTemplates.lua:393,403）
--     ⇒ 內縮 8 之後文字仍然整段落在自己的底色上。
local TAB_INSETS = {
    { 8, -8 },    -- 1 坐騎
    { 8, -8 },    -- 2 寵物
    { 8, -8 },    -- 3 玩具箱
    { 8, -8 },    -- 4 傳家寶
    { -11, -8 },  -- 5 外觀（被 Lua 重錨成 +3，見上）
    { 8, -8 },    -- 6 戰隊場景
}

local function SkinChrome()
    local f = _G.CollectionsJournal
    if not f then
        E.Missing("CollectionsJournal")
        return nil
    end

    Skin.PortraitChrome(f, "CollectionsJournal")
    Skin.Panel(f, "CollectionsJournal")

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "CollectionsJournal.CloseButton")
    else
        E.Missing("CollectionsJournal.CloseButton")
    end

    -- ⚠ 由左往右套：同層級的 overlay 疊放順序看建立先後，接縫上才只有一條線。
    --   第 4 顆（傳家寶）在時空漫遊期間會被 `PanelTemplates_HideTab` 藏起來
    --   （Blizzard_Collections.lua:62），照樣要套 —— 藏起來的框一樣收得到我們的皮。
    for i = 1, 6 do
        local key = "CollectionsJournalTab" .. i
        local tab = _G[key]
        if tab then
            local inset = TAB_INSETS[i]
            Shared.SkinPanelTab(tab, key, { left = inset[1], right = inset[2], joined = "TOP" })
        else
            E.Missing(key)
        end
    end

    return f
end

------------------------------------------------------------
-- 坐騎
------------------------------------------------------------
local INFO_ICON_KEY = "MountJournal.MountDisplay.InfoButton.Icon"

local infoIconHookInstalled = false
local infoIconHookBroken = false

-- `MountJournal_UpdateMountDisplay`（MountCollection.lua:730）每次換坐騎都
-- `InfoButton.Icon:SetTexture(...)`（:751,756）⇒ texCoord 被打回 0,1,0,1。
-- 裁邊要跟著重下一次，跟池化列的 reapply 是同一類問題，只是這裡只有一顆框，
-- 用不上 `Engine.HookRows`（它的第一個參數是列，這支全域函式的第一個參數是布林）。
local function InstallInfoIconHook()
    if infoIconHookInstalled then return end
    if type(_G.MountJournal_UpdateMountDisplay) ~= "function" then
        E.Missing("MountJournal_UpdateMountDisplay")
        return
    end
    infoIconHookInstalled = true
    hooksecurefunc("MountJournal_UpdateMountDisplay", function()
        if infoIconHookBroken then return end
        local ok, err = pcall(function()
            local icon = MountJournal.MountDisplay.InfoButton.Icon
            E.CropIcon(icon, INFO_ICON_KEY)
        end)
        if not ok then
            -- 出錯一次就停用：換一次坐騎報一發的洗版比「少裁一次邊」嚴重得多
            infoIconHookBroken = true
            E.Missing(INFO_ICON_KEY .. " (hook 已停用)")
            ns.ReportError(err)
        end
    end)
end

local function SkinMountJournal()
    local j = _G.MountJournal
    if not j then
        E.Missing("MountJournal")
        return
    end

    -- 三塊內嵌區。BottomLeftInset 另外帶著坐騎裝備的雕花底
    -- （`Background`／`BackgroundOverlay` ＋ 一張**無名**的 mountequipment-insetshadow，
    --  .xml:361,369,374）⇒ `NeutralizeRegions` 整批掃（只掃 Texture，兩條說明文字
    --  是 FontString，自動排除）。
    for _, k in ipairs({ "LeftInset", "BottomLeftInset", "RightInset" }) do
        local inset
        if pcall(function() inset = j[k] end) and inset then
            Skin.Inset(inset, "MountJournal." .. k)
            if k == "BottomLeftInset" then
                E.NeutralizeRegions(inset, "MountJournal.BottomLeftInset")
            end
        else
            E.Missing("MountJournal." .. k)
        end
    end

    local search
    if pcall(function() search = j.searchBox end) and search then
        Skin.EditBox(search, "MountJournal.searchBox")
    else
        E.Missing("MountJournal.searchBox")
    end

    local filter
    if pcall(function() filter = j.FilterDropdown end) and filter then
        Skin.Dropdown(filter, "MountJournal.FilterDropdown", "filter")
    else
        E.Missing("MountJournal.FilterDropdown")
    end

    local count
    if pcall(function() count = j.MountCount end) and count then
        Shared.SkinInset3(count, "MountJournal.MountCount")
    else
        E.Missing("MountJournal.MountCount")
    end

    local mountBtn
    if pcall(function() mountBtn = j.MountButton end) and mountBtn then
        -- MagicButtonTemplate ← UIPanelButtonTemplate，OnClick 是普通 Lua（見檔頭 3.）
        Skin.Button(mountBtn, "MountJournal.MountButton")
    else
        E.Missing("MountJournal.MountButton")
    end

    Shared.SkinOwnedScrollBar(j, "MountJournal.ScrollBar")

    -- 右側展示區：**大圖與 ModelScene 都保留**，只把它外面那圈換成皮（見檔頭），
    -- 並且給資訊區的圖示一圈 1px 邊。
    local info
    if pcall(function() info = j.MountDisplay.InfoButton end) and info then
        local icon
        if pcall(function() icon = info.Icon end) and icon then
            Skin.Icon(icon, INFO_ICON_KEY)
        else
            E.Missing(INFO_ICON_KEY)
        end
    else
        E.Missing("MountJournal.MountDisplay.InfoButton")
    end

    -- 已經建好的列補掃（戰鬥中第一次點開這一頁才會用到）
    local box
    if pcall(function() box = j.ScrollBox end) and box then
        E.SweepRows(box, "MountJournal.ScrollBox", Shared.mountSweep)
    end
end

------------------------------------------------------------
-- hook 安裝（**不過戰鬥閘**，理由見 STYLE.md ③ 的陷阱 4）
------------------------------------------------------------
local MOUNT_ROW_KEY = "MountListButton"

local function InstallHooks()
    Shared.mountSweep = E.HookRows{
        key    = "MountListButton",
        mixin  = _G,                              -- 初始化走全域函式，不是 mixin
        method = "MountJournal_InitMountButton",
        match  = function(row)
            return type(row) == "table" and row.DragButton ~= nil and row.factionIcon ~= nil
        end,
        apply  = function(row) Shared.ApplyCompanionRow(row, MOUNT_ROW_KEY) end,
        reapply = function(row) Shared.ReapplyCompanionRow(row, MOUNT_ROW_KEY) end,
    }
    InstallInfoIconHook()
end

local function Apply()
    if not SkinChrome() then return end
    SkinMountJournal()
end

E.Register{
    key   = "collections",
    addon = "Blizzard_Collections",     -- 隨需載入：ADDON_LOADED 才套（apply 過戰鬥閘）
    title = L["Collections"],
    hooks = InstallHooks,
    apply = Apply,
}
