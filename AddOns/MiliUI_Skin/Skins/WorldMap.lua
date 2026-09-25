------------------------------------------------------------
-- 配方：世界地圖＋任務日誌（`WorldMapFrame`／`QuestMapFrame`）
--
-- ⚠⚠ **這一份把 STYLE.md ⑦ C 級「世界地圖／任務日誌的腳本與池化任務列」裡的「框」移出來，
--   內容仍留在 C 級。** 範圍照成熟同類實作的同一段：外框、導覽列、任務日誌面板、
--   細節／戰役／事件／圖例四頁的框、右側三顆側邊分頁。它刻意不碰的我們一樣不碰：
--   * `QuestMapFrame` 自己的腳本（`QuestMapFrame_OnShow`／`_OnEvent`／`QuestLogQuests_Update`…）——
--     那是通往任務追蹤（ObjectiveTracker）的 taint 路徑。**這一份在 QuestMapFrame 的任何框、
--     任何 `QuestLog*Mixin`、任何 `QuestMapFrame_*`／`QuestLogQuests_*` 全域函式上：0 支 hook、
--     0 支 HookScript。**
--   * 隊伍同步的指令鈕（`QuestSessionManagement.ExecuteSessionCommand`）。
--   * 地圖疊加按鈕（追蹤選項、地圖圖釘、樓層下拉、懸賞板、活動追蹤…）與地圖畫布、地圖上的 pin。
--   * 池化的任務列（`QuestLogTitleTemplate`、`QuestLogHeaderTemplate`、戰役標題）。
--     ⚠ 成熟同類實作其實有勾 `QuestLogQuests_Update` 去重畫**標題列**（讀 `headerFramePool`、
--       量 `GetTop()` 決定哪一條要分隔線、在列上 HookScript OnEnter/OnLeave）。那三件事我們的
--       契約全部禁止（讀暴雪欄位、讀尺寸、而且那一支就是任務追蹤的更新路徑）⇒ 標題列不做。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_WorldMap/Blizzard_WorldMap_Mainline.toc   **沒有** LoadOnDemand（登入就載入）
--   Blizzard_WorldMap/Blizzard_WorldMap.xml:5,28
--     `WorldMapFrameTemplate` ← `MapCanvasFrameTemplate`（MEDIUM strata、toplevel，
--     Blizzard_MapCanvas/Blizzard_MapCanvas.xml:52）；`WorldMapFrame` 本體：
--     `BlackoutFrame`（:30，最大化時的全螢幕黑底，不碰）／
--     `BorderFrame`（:43，`PortraitFrameTemplateMinimizable`、**HIGH strata**、setAllPoints）＋
--     `InsetBorderTop`（:51）＋ `Underlay`（:46，hidden，不碰）＋ `Tutorial`（:61，不碰）＋
--     `MaximizeMinimizeFrame`（:71）
--   Blizzard_WorldMap/Blizzard_WorldMap.lua:10-16  `SetupTitle` → `BorderFrame.Bg:SetParent(self)`、
--     `TopTileStreaks:Hide()`、`SetPortraitToAsset`；:40,55 `SetBorder(...)` 換 NineSlice 版型
--     （Blizzard_SharedXML/PortraitFrame.lua:42 → `NineSliceUtil.ApplyLayout`，**不動 NineSlice 框的 alpha**
--      ⇒ 框級 `SetAlpha(0)` 撐得住）
--   同檔 :314-320  `NavBar`（`WorldMapNavBarTemplate`）與 `SidePanelToggle` 由 `AddOverlayFrame` 建立
--   同檔 :541-549  `AttachQuestLog`：`QuestMapFrame` 改 parent 到地圖、HIGH strata、錨 TOPRIGHT(-3,-25)
--   Blizzard_WorldMap/Blizzard_WorldMapTemplates.xml:155  `WorldMapNavBarTemplate` ← `NavBarTemplate`
--     ＋ 五張 `InsetBorder*`；:228 `WorldMapSidePanelToggleTemplate`（`OpenButton`／`CloseButton`，
--     各一張無名 BACKGROUND 陰影 ＋ Normal／Pushed atlas ＋ Highlight）
--   Blizzard_WorldMap/Blizzard_WorldMapTemplates.lua:475-486  `NavBar_Initialize(self, "NavButtonTemplate",
--     homeData, self.home, self.overflow)`；:631-646 收合鈕 `Refresh` 只 Show/Hide 兩顆
--   Blizzard_FrameXML/Mainline/NavigationBar.xml:123 `NavButtonTemplate`（`arrowUp`／`arrowDown`／`selected`
--     三張 OVERLAY、`MenuArrowButton`（:151，OnEnter/OnLeave 會 `NormalTexture/PushedTexture:SetAlpha(1/0)`）、
--     Normal／Pushed／Highlight、ButtonText `text` GameFontNormal）；:241 `NavBarTemplate`（無名 BACKGROUND
--     磚、`overlay` 子框、`overflow`、`home`（`$parentLeft` 陰影）、`KioskOverlay`）
--   Blizzard_FrameXML/Mainline/NavigationBar.lua:77 `NavBar_AddButton`（全域）—— 新的麵包屑
--     `CreateFrame("BUTTON", …, self, self.template)` ⇒ **是導覽列的子框**，`GetChildren()` 找得到
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:981 `LargeSideTabButtonTemplate`
--     （`Background`／`Icon`／`SelectedTexture`／`TabGlow`（有動畫，不碰）／HIGHLIGHT 層的 `HighlightTexture`）；
--     SharedUIPanelTemplates.lua:324 `SidePanelTabButtonMixin:SetChecked` 只 `Icon:SetAtlas` ＋
--     `SelectedTexture:SetShown` ⇒ alpha 中和撐得住
--   Blizzard_UIPanels_Game/Mainline/QuestMapFrame.xml（QuestMapFrame 住在 LoadFirst 的 UIPanels_Game）
--     :248 `QuestLogBorderFrameTemplate`（`Border`／`TopDetail`，frameLevel 100）
--     :383 `QuestMapFrame`：`VerticalSeparator`、`QuestsTab`／`EventsTab`／`MapLegendTab`（:397-430）、
--       `QuestsFrame.ScrollFrame`＝`QuestScrollFrame`（:449，`Background`／`Edge`／`Contents.Separator.Divider`／
--       `Contents.StoryHeader.Divider`／`SearchBox`／`BorderFrame`（含 `Shadow`））、
--       `QuestsFrame.DetailsFrame`（:625，`Bg`／`SealMaterialBG`／`BorderFrame`／`BackFrame`（無名 BORDER 貼圖 ＋
--       `BackButton`）／`RewardsFrameContainer`／`AbandonButton`／`ShareButton`（兩張無名分隔貼圖）／`TrackButton`）、
--       `QuestsFrame.CampaignOverview`（:839）、`EventsFrame`（:842，**自己有一張黃色 BACKGROUND 貼圖**）、
--       `QuestSessionManagement`（:858，`BG`）、`MapLegend`（:931）
--   Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua:919-948  `DetailsFrame:OnShow` 依 `questTextContrast`
--     換 `Bg` 的 atlas、`AdjustBackgroundTexture` **讀回 `GetAtlas()`** ⇒ `Bg` 只能 alpha、而且我們不碰它（見下）
--   同檔 :1331-1368  `UpdateBottomShadow` 改 `Shadow` 的 alpha、`UpdateBackground` 重設 `Background` 的 atlas
--     （alpha 不動）⇒ `Background` 用 alpha 中和撐得住；`Shadow` 由 `BorderFrame` 框級 alpha 0 一起蓋掉
--   Blizzard_UIPanels_Game/Mainline/CampaignOverview.xml:4  `BorderFrame`／`BG`（lore 底圖）／`ScrollFrame`
--   Blizzard_UIPanels_Game/Mainline/EventScheduler.xml:251  `BorderFrame`／`ScrollBox.Background`／`ScrollBar`／`TitleText`
--   Blizzard_UIPanels_Game/Mainline/MapLegendFrame.xml:4  `BorderFrame`／`ScrollFrame.Background`／`TitleText`
--   Blizzard_SharedXML/SecureUIPanelTemplates.lua:1  `ScrollFrame_OnLoad` → `self.ScrollBar`（MinimalScrollBar）
--
------------------------------------------------------------
-- ## 做了什麼
--
-- * 外框：面板底建在 **`WorldMapFrame` 自己身上**（MEDIUM strata，壓在地圖畫布之下）；
--   `BorderFrame` 是 HIGH strata、跟整個視窗一樣大 —— 底要是建在它身上就會蓋住地圖，所以
--   它只拿來中和雕花、畫標題帶（上緣 22，底下是導覽列與任務日誌、沒有地圖）。
--   關閉鈕、最大化／最小化照一般原語。
-- * 導覽列：整條換成 `fillInset` 的內嵌帶（照成熟同類實作「不改麵包屑的寬度與錨點」）、
--   麵包屑的磚紋與箭頭中和、字改白、下拉小箭頭去飽和染次要灰、溢出鈕改畫 ‹。
--   新長出來的麵包屑靠 `NavBar_AddButton`（**全域函式**）的後置勾補上。
-- * 側邊收合鈕（地圖右下角）：‹ ›。
-- * 任務日誌：清單、戰役、事件、圖例四塊的雕花邊框中和，各換成一塊 `fillInset` 內嵌底；
--   搜尋框、五條捲軸；細節頁的雕花與上方按鈕帶中和；四顆按鈕**零腳本**（secondary）。
-- * 右側三顆側邊分頁：底座與選中框中和、改畫方框；滑過交給 HIGHLIGHT 層那一張（零腳本）。
--
-- ## 刻意不碰（除了檔頭第一段那四類）
--
-- * **細節頁的 `Bg`／`SealMaterialBG` 與獎勵框的美術**（內容底材規則）：`Bg` 是跟著
--   `questTextContrast` 換的（本包 `Skins/Quest.lua` 預設設成 4 ＝深色），上面的字色由暴雪依同一個
--   CVar 決定。成熟同類實作是把它拿掉再用 `QuestInfo_Display` 的後置勾接管全部字色 ——
--   那一支是任務視窗與任務日誌共用的，而且我們已經有「讓暴雪自己換深色」這條更安全的路。
-- * 標題列、任務列、戰役標題、事件列（池化）；`SettingsDropdown`（齒輪）；`Tutorial`；
--   `BlackoutFrame`；`Underlay`；側邊分頁的 `TabGlow`（有動畫在跑 alpha）與 `Icon`（選中態就是換 atlas）。
-- * 側邊分頁的圖示裁邊、停用半透明（成熟同類實作有做：每次 `SetTexCoord`、`tab:SetAlpha`）——
--   寫框的 alpha 在禁止清單上；裁邊要在 `SetChecked` 之後重做，而那是建立時就拷貝走的 mixin 方法，勾不到。
--   （重新定位 2026-09-24 起有做，但不量尺寸：`Engine.ShiftRoot` 挪第一顆，見 `SkinSideTab` 上方。）
-- * 導覽列「黑條只延伸到最後一顆麵包屑」與「整條往下 4」：要每次重錨自己的貼圖（lint 禁 SetPoint）
--   與對暴雪框 `ClearAllPoints`＋`SetPoint` ⇒ 改成整條內嵌帶，不重排。
-- * 麵包屑的 `HookScript("OnClick")`（成熟同類實作用來重算黑條）—— 我們沒有要重算的東西。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事
--
-- | 對象 | 動作 |
-- |---|---|
-- | `WorldMapFrame` | `Engine.RegionBackdrop`（面板底＋邊，建成它自己的 BACKGROUND 貼圖） |
-- | `BorderFrame` 的 NineSlice／Bg／TopTileStreaks／PortraitContainer／`InsetBorderTop` | `SetAlpha(0)` |
-- | `BorderFrame` | `Engine.RegionBackdrop`（標題帶，上緣 22） |
-- | `BorderFrame.TitleContainer.TitleText` | `SetTextColor` |
-- | `BorderFrame.CloseButton` | `Skin.CloseButton` |
-- | `MaximizeMinimizeFrame` 兩顆 | `Skin.IconButton`（＋／− 圖記） |
-- | `NavBar` 自己的貼圖（磚紋＋`InsetBorder*`）、`NavBar.overlay`（框） | `SetAlpha(0)`；導覽列底 `Engine.RegionBackdrop` |
-- | 麵包屑（`home` ＋ 每一顆 `NavButtonTemplate`） | 貼圖 `SetAlpha(0)`（Highlight 除外）＋ Highlight `SetColorTexture`（白 8%）＋ `SetNormalFontObject(GameFontHighlight)` |
-- | 麵包屑的 `MenuArrowButton` | `Normal/PushedTexture` `SetAlpha(0)`；`Art` 去飽和 ＋ `SetVertexColor`；Highlight 白 8% |
-- | `NavBar.overflow` | Normal／Pushed `SetAlpha(0)`；Highlight 白 8%；‹ 圖記 overlay |
-- | `SidePanelToggle.OpenButton／CloseButton` | 陰影貼圖 `SetAlpha(0)`；`Skin.IconButton`（‹ ›） |
-- | `QuestMapFrame.VerticalSeparator` | `SetAlpha(0)` |
-- | 五個 `BorderFrame`（清單／細節／戰役／事件／圖例，`QuestLogBorderFrameTemplate`） | 框級 `SetAlpha(0)` |
-- | `QuestScrollFrame.Background`／`Edge`、`Contents.Separator.Divider`、`StoryHeader.Divider` | `SetAlpha(0)` |
-- | `QuestScrollFrame`、`CampaignOverview`、`EventsFrame`、`MapLegend` | `Engine.RegionBackdrop`（`fillInset` 內嵌底） |
-- | `QuestScrollFrame.SearchBox` | `Skin.EditBox` |
-- | 五條 `ScrollBar`（清單、細節、戰役、事件、圖例） | `Skin.ScrollBar` |
-- | `DetailsFrame.BackFrame` 的無名貼圖 | `SetAlpha(0)` |
-- | **零腳本按鈕**：`BackButton`、`AbandonButton`、`ShareButton`、`TrackButton` | Left/Right/Middle（＋分隔貼圖）`SetAlpha(0)` ＋ `SetNormalFontObject` ＋ Highlight `SetColorTexture`（`Engine.ScriptlessButton` secondary）。**零 HookScript** |
-- | `CampaignOverview.BG`、`EventsFrame` 自己的貼圖、`EventsFrame.ScrollBox.Background`、`MapLegend.ScrollFrame.Background`、`QuestSessionManagement.BG` | `SetAlpha(0)` |
-- | `EventsFrame.TitleText`、`MapLegend.TitleText` | `SetTextColor` |
-- | 三顆側邊分頁的 `Background`／`SelectedTexture` | `SetAlpha(0)`；方框 `Engine.RegionBackdrop`（錨在 `Icon` 外 5）；`HighlightTexture` `SetAlpha(1)`＋`SetColorTexture`（HIGHLIGHT 層，C 端顯示） |
--
-- ### 讀了什麼
--
-- 只有結構：parentKey、`GetRegions()`（找無名貼圖）、`GetChildren()`（找麵包屑）。
-- 後置勾裡比較的是「傳進來的導覽列是不是 `WorldMapFrame.NavBar`」（框參照相等），不讀任何值。
-- **不讀** `navList`／`freeButtons`／任何任務資料、`questID`、`displayMode`、`headerFramePool`。
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc("NavBar_AddButton", …)` | **全域函式**後置勾 | 不是世界地圖的導覽列就返回；是就走訪它的子框、把還沒上皮的麵包屑套上（冪等） |
-- | 麵包屑 `MenuArrowButton` 的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | 模板自己的 OnEnter 會把 `NormalTexture/PushedTexture` 設回 alpha 1 ⇒ 我們跟在後面再 `SetAlpha(0)`。只碰這兩張貼圖 |
-- | `Skin.CloseButton`／`Skin.IconButton` 內建的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | **只對**地圖的關閉鈕、最大化最小化、側邊收合鈕；內容只換我們自己 overlay 的顏色 |
--
-- **`QuestMapFrame` 與它的任何子框：0 支 hook、0 支 HookScript**（按鈕全零腳本、側邊分頁的滑過交給 HIGHLIGHT 層）。
-- **`hooksecurefunc` 在 `WorldMapFrame`／`QuestMapFrame` 實例或任何 `WorldMap*Mixin`／`QuestLog*Mixin` 上：0 支。**
-- **`HookScript("OnShow"/"OnHide")`：0 支。**
--
-- ### 伴隨元件（這一輪沒做，只記下來）
-- 套組裡 `Mapster` 在 `BorderFrame.TitleContainer` 上建了一顆 `MapsterOptionsButton`、
-- `HandyNotes_WorldMapButton` 在 `WorldMapFrame` 上建了一顆按鈕（都是 `UIPanelButtonTemplate`）。
-- 要上皮的話走 `ThirdParty/*.lua` ＋ `Engine.AddCompanion("worldmap", …)`，不寫在這裡。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 小工具（同 `Skins/PlayerSpells.lua`）
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

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

local TRANSPARENT = { 0, 0, 0, 0 }
local HIGHLIGHT_GETTERS = { "GetHighlightTexture" }

------------------------------------------------------------
-- 零腳本按鈕（同 `Skins/PlayerSpells.lua` 的那一支）
-- TODO(升格): 第四份配方用到了 —— 收成 `Skin.ScriptlessButton`。
--
-- `extraArt`：模板以外、按鈕自己身上的無名貼圖（分享鈕左右兩張 `UI-Frame-BtnDivMiddle`）
-- ⇒ 走 `NeutralizeRegions`，Highlight 留下來給引擎上色。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant, extraArt)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    if extraArt then
        E.NeutralizeRegions(btn, key, E.KeepSet(btn, {}, HIGHLIGHT_GETTERS))
    end
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "secondary", key)   -- **不掛腳本**
    return ov
end

-- `QuestLogBorderFrameTemplate`：整個框就是雕花（`Border`／`TopDetail`，清單那一個多一張 `Shadow`），
-- 沒有可互動的子物件 ⇒ 框級 alpha 0。
local function NeutralizeBorderFrame(owner, key)
    local bf = Optional(owner, "BorderFrame")
    if bf then
        E.Neutralize(bf, key .. ".BorderFrame")
    else
        E.Missing(key .. ".BorderFrame")
    end
end

local function InsetBackdrop(target, key)
    local ov = E.RegionBackdrop(target, { key = key .. ".inset" })
    E.Paint(ov, T.fillInset, T.border)
    return ov
end

local function ScrollBarOf(owner, key)
    local bar = Optional(owner, "ScrollBar")
    if bar then
        Skin.ScrollBar(bar, key .. ".ScrollBar")
    else
        E.Missing(key .. ".ScrollBar")
    end
end

------------------------------------------------------------
-- 外框
------------------------------------------------------------
local MAXMIN_GLYPH = { MaximizeButton = "expand", MinimizeButton = "collapse" }

local function SkinChrome(f)
    -- 面板底：建在 WorldMapFrame 自己身上（MEDIUM，壓在地圖畫布之下）。
    -- ⚠ 不建在 BorderFrame：它是 HIGH strata、setAllPoints，底會蓋住整張地圖。
    Skin.Panel(f, "WorldMapFrame")

    local bf = Sub(f, "BorderFrame", "WorldMapFrame.BorderFrame")
    if not bf then return end

    -- NineSlice／Bg（已被暴雪改 parent 到 WorldMapFrame，欄位仍在）／TopTileStreaks／PortraitContainer
    -- ＋ 標題白字 ＋ 標題帶（上緣 22：底下是導覽列與任務日誌，沒有地圖，蓋不到內容）
    Skin.PortraitChrome(bf, "WorldMapFrame.BorderFrame")
    E.NeutralizeKeys(bf, { "InsetBorderTop" }, "WorldMapFrame.BorderFrame")

    local close = Sub(bf, "CloseButton", "WorldMapFrame.BorderFrame.CloseButton")
    if close then Skin.CloseButton(close, "WorldMapFrame.BorderFrame.CloseButton") end

    local mm = Sub(bf, "MaximizeMinimizeFrame", "WorldMapFrame.BorderFrame.MaximizeMinimizeFrame")
    if mm then
        for name, glyph in pairs(MAXMIN_GLYPH) do
            local key = "WorldMapFrame.MaximizeMinimizeFrame." .. name
            local btn = Sub(mm, name, key)
            if btn then Skin.IconButton(btn, key, { glyph = glyph }) end
        end
    end
end

------------------------------------------------------------
-- 導覽列（麵包屑）
--
-- 照成熟同類實作：**保留暴雪的麵包屑排版**（寬度、錨點、箭頭形的幾何一律不動 —— 那條鏈一改，
-- 地圖名稱會被甩出視窗），只換美術：磚紋與箭頭中和、白字、細微的滑過。
-- 背景改成整條 `fillInset` 內嵌帶（它是「限長到最後一顆」的黑條，那要每次重錨，我們不重排）。
------------------------------------------------------------
local crumbDone = setmetatable({}, { __mode = "k" })

local function FadeMenuArrowArt(ma)
    for _, k in ipairs({ "NormalTexture", "PushedTexture" }) do
        local tex = Optional(ma, k)
        if tex then E.Neutralize(tex, "WorldMapFrame.NavBar.MenuArrowButton." .. k) end
    end
end

local function SkinCrumb(btn, key)
    if crumbDone[btn] or not E.Usable(btn, key) then return end
    crumbDone[btn] = true

    -- 磚紋（Normal／Pushed）、arrowUp／arrowDown／selected、home 的 `$parentLeft` 陰影：全部是無名或
    -- 狀態貼圖 ⇒ 一次掃自己的 region，Highlight 留下來換成白 8%。
    E.NeutralizeRegions(btn, key, E.KeepSet(btn, {}, HIGHLIGHT_GETTERS))
    E.ButtonStates(btn, key)
    E.ButtonFonts(btn, GameFontHighlight, key)

    -- 下拉小箭頭（同層樓群組地圖才出現）：箭頭本身留著、去飽和染次要灰；
    -- 模板的 OnEnter/OnLeave 會把方框底圖設回 alpha 1/0 ⇒ 跟在後面再中和一次。
    local ma = Optional(btn, "MenuArrowButton")
    if ma then
        FadeMenuArrowArt(ma)
        local art = Optional(ma, "Art")
        if art then
            E.Desaturate(art, key .. ".MenuArrowButton.Art")
            E.VertexColor(art, T.textDim, key .. ".MenuArrowButton.Art")
        end
        E.ButtonStates(ma, key .. ".MenuArrowButton")
        if type(ma.HookScript) == "function" then
            pcall(ma.HookScript, ma, "OnEnter", FadeMenuArrowArt)
            pcall(ma.HookScript, ma, "OnLeave", FadeMenuArrowArt)
        end
    end
end

-- 導覽列底下所有「長得像麵包屑」的子框（home、每一顆 `NavButtonTemplate`）。
-- 認人靠結構：有 `MenuArrowButton`（NavButtonTemplate）或它就是 `home`。
local function SweepCrumbs(nav)
    if type(nav) ~= "table" or type(nav.GetChildren) ~= "function" then return end
    local home = Optional(nav, "home")
    if home then SkinCrumb(home, "WorldMapFrame.NavBar.home") end
    local ok, children = pcall(function() return { nav:GetChildren() } end)
    if not ok then return end
    for i, child in ipairs(children) do
        if type(child) == "table" and child ~= home and Optional(child, "MenuArrowButton") then
            SkinCrumb(child, "WorldMapFrame.NavBar.crumb" .. i)
        end
    end
end

local function SkinNavBar(nav)
    local key = "WorldMapFrame.NavBar"
    if not E.Usable(nav, key) then return end

    -- 自己的磚紋（無名 BACKGROUND）＋ 五張 InsetBorder*；`overlay` 子框只有一張磚紋 ⇒ 框級 alpha
    E.NeutralizeRegions(nav, key)
    local over = Optional(nav, "overlay")
    if over then E.Neutralize(over, key .. ".overlay") end

    local band = E.RegionBackdrop(nav, { key = key .. ".band" })
    E.Paint(band, T.fillInset, T.border)

    -- 溢出鈕（「…」）：Normal／Pushed 中和、Highlight 白 8%、改畫 ‹
    local ovf = Optional(nav, "overflow")
    if ovf and E.Usable(ovf, key .. ".overflow") then
        E.NeutralizeRegions(ovf, key .. ".overflow", E.KeepSet(ovf, {}, HIGHLIGHT_GETTERS))
        E.ButtonStates(ovf, key .. ".overflow")
        local gov = E.Overlay(ovf, {
            key = key .. ".overflow",
            noBorder = true,
            glyph = { kind = "chevronLeft", size = T.glyphSize, thickness = 1, color = T.textDim },
        })
        E.Paint(gov, TRANSPARENT)
    end

    SweepCrumbs(nav)
end

------------------------------------------------------------
-- 側邊收合鈕（地圖右下角）。打開＝把任務日誌拉出來（›）、收起＝‹（照成熟同類實作）。
------------------------------------------------------------
local function SkinSidePanelToggle(spt)
    local key = "WorldMapFrame.SidePanelToggle"
    for k, glyph in pairs({ OpenButton = "chevronRight", CloseButton = "chevronLeft" }) do
        local btn = Optional(spt, k)
        if btn then
            -- 陰影（`MapCornerShadow-Right`，無名 BACKGROUND）；Normal／Pushed／Highlight 由 IconButton 處理
            E.NeutralizeRegions(btn, key .. "." .. k, E.KeepSet(btn, {}, HIGHLIGHT_GETTERS))
            Skin.IconButton(btn, key .. "." .. k, { glyph = glyph, glyphColor = T.textDim, inset = 4 })
        else
            E.Missing(key .. "." .. k)
        end
    end
end

------------------------------------------------------------
-- 任務日誌
------------------------------------------------------------
local SIDE_TABS = { "QuestsTab", "EventsTab", "MapLegendTab" }

-- 側邊分頁：**零腳本**，長相跟社群視窗的側邊分頁同一套分頁語言（2026-09-24）：
--   * 方框貼著視窗右緣（左邊框跟視窗邊框疊成一條），選中＝朝外那一邊（右緣）一條職業色直條。
--   * 方框的矩形照**分頁本身**算，不再錨在圖示上：圖示是 `SetAtlas(..., UseAtlasSize)`，
--     選中／未選中兩張 atlas 不保證同尺寸，按下時暴雪還會 `Icon:SetPoint` 位移
--     （SharedUIPanelTemplates.lua:305-316）⇒ 錨圖示的框會跟著變大變小、跟著跳。
--   分頁 43x55、圖示 `CENTER x=-2`（SharedUIPanelTemplates.xml:982,994）⇒ 方框以圖示中心
--   為中心、邊長 42：左右 −1.5／−2.5、上下各內縮 6.5。
--   * 選中條：暴雪的 `SelectedTexture`（`SetChecked` 只對它 `SetShown`，:324-333）重錨到
--     方框右緣、塗職業色 ⇒ 顯示與否照舊是暴雪決定，零 hook。
--   * 滑過：`HighlightTexture`（atlas 尺寸、比方框大）重錨成方框矩形、塗白 8%。
--   * 貼齊：QuestsTab 原本錨 `TOPLEFT → QuestMapFrame TOPRIGHT x=3 y=-28`（QuestMapFrame.xml:405）
--     ⇒ 方框左緣在視窗右緣外 1.5。改 x=SIDE_TAB_X 讓方框左緣落在視窗邊框上；另外兩顆
--     `TOP → 上一顆 BOTTOM` 串在它下面（暴雪 Lua 只重錨 MapLegendTab，也是錨在上一顆上，
--     QuestMapFrame.lua:246）⇒ 只挪第一顆整排就跟著走。
local SIDE_TAB_BOX_POINTS = {
    { "TOPLEFT", "TOPLEFT", -1.5, -6.5 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", -2.5, 6.5 },
}
local SIDE_TAB_X = 0.5

local function SkinSideTab(tab, key)
    if not E.Usable(tab, key) then return end
    E.NeutralizeKeys(tab, { "Background" }, key)

    local box = E.RegionBackdrop(tab, { key = key .. ".box", points = SIDE_TAB_BOX_POINTS })
    E.Paint(box, T.fill, T.border)

    local sel = Optional(tab, "SelectedTexture")
    if sel then
        local accent = T.tabAccentSize or 2
        E.Reanchor({ { sel, {
            { "TOPLEFT", "TOPRIGHT", -2.5 - accent, -6.5, rel = tab },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", -2.5, 6.5, rel = tab },
        } } }, key .. ".SelectedTexture")
        local r, g, b = T.Accent()
        E.SolidTexture(sel, { r, g, b, 1 }, key .. ".SelectedTexture")
    else
        E.Missing(key .. ".SelectedTexture")
    end

    local hl = Optional(tab, "HighlightTexture")
    if hl then
        E.Reanchor({ { hl, {
            { "TOPLEFT", "TOPLEFT", -1.5, -6.5, rel = tab },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", -2.5, 6.5, rel = tab },
        } } }, key .. ".HighlightTexture")
        E.HighlightTexture(hl, key .. ".HighlightTexture")
    else
        E.Missing(key .. ".HighlightTexture")
    end
end

local function SkinQuestList(qs)
    local key = "QuestScrollFrame"
    if not E.Usable(qs, key) then return end

    E.NeutralizeKeys(qs, { "Background", "Edge" }, key)
    NeutralizeBorderFrame(qs, key)
    InsetBackdrop(qs, key)

    local contents = Optional(qs, "Contents")
    if contents then
        local sep = Optional(contents, "Separator")
        if sep then E.NeutralizeKeys(sep, { "Divider" }, key .. ".Contents.Separator") end
        local sh = Optional(contents, "StoryHeader")
        if sh then E.NeutralizeKeys(sh, { "Divider" }, key .. ".Contents.StoryHeader") end
    end

    local sb = Optional(qs, "SearchBox")
    if sb then Skin.EditBox(sb, key .. ".SearchBox") else E.Missing(key .. ".SearchBox") end
    ScrollBarOf(qs, key)
end

-- 細節頁：`Bg`／`SealMaterialBG`／獎勵框**不碰**（內容底材，跟著 questTextContrast 走，檔頭）。
local DETAIL_BUTTONS = { "AbandonButton", "ShareButton", "TrackButton" }

local function SkinDetails(det)
    local key = "QuestMapFrame.DetailsFrame"
    if not E.Usable(det, key) then return end

    NeutralizeBorderFrame(det, key)

    local back = Optional(det, "BackFrame")
    if back then
        -- 按鈕帶的底圖（`questlog-reward-top-frame`，無名 BORDER）
        E.NeutralizeRegions(back, key .. ".BackFrame")
        local bb = Optional(back, "BackButton")
        -- 「返回」：判準第 2 條的例外（它本身就是返回）⇒ secondary
        if bb then ScriptlessButton(bb, key .. ".BackFrame.BackButton", "secondary") end
    else
        E.Missing(key .. ".BackFrame")
    end

    -- 放棄／分享／追蹤：一整排平行選項 ⇒ 全部 secondary；零腳本（追蹤就是任務追蹤的入口）
    for _, k in ipairs(DETAIL_BUTTONS) do
        local btn = Optional(det, k)
        if btn then
            ScriptlessButton(btn, key .. "." .. k, "secondary", k == "ShareButton")
        else
            E.Missing(key .. "." .. k)
        end
    end

    local dsf = Optional(det, "ScrollFrame")
    if dsf then ScrollBarOf(dsf, key .. ".ScrollFrame") end
end

local function SkinCampaign(co)
    local key = "QuestMapFrame.CampaignOverview"
    if not E.Usable(co, key) then return end
    NeutralizeBorderFrame(co, key)
    E.NeutralizeKeys(co, { "BG" }, key)
    InsetBackdrop(co, key)
    local sf = Optional(co, "ScrollFrame")
    if sf then ScrollBarOf(sf, key .. ".ScrollFrame") end
end

local function SkinEvents(ev)
    local key = "QuestMapFrame.EventsFrame"
    if not E.Usable(ev, key) then return end
    NeutralizeBorderFrame(ev, key)
    -- ⚠ 這一頁自己有一張 setAllPoints 的**黃色** BACKGROUND（QuestMapFrame.xml:850），平常被
    --   `ScrollBox.Background` 蓋著；我們把後者中和了，前者一定要一起收掉。
    E.NeutralizeRegions(ev, key)
    local box = Optional(ev, "ScrollBox")
    if box then E.NeutralizeKeys(box, { "Background" }, key .. ".ScrollBox") end
    InsetBackdrop(ev, key)
    local title = Optional(ev, "TitleText")
    if title then E.TextColor(title, T.text, key .. ".TitleText") end
    ScrollBarOf(ev, key)
end

local function SkinLegend(ml)
    local key = "QuestMapFrame.MapLegend"
    if not E.Usable(ml, key) then return end
    NeutralizeBorderFrame(ml, key)
    local sf = Optional(ml, "ScrollFrame")
    if sf then
        E.NeutralizeKeys(sf, { "Background" }, key .. ".ScrollFrame")
        ScrollBarOf(sf, key .. ".ScrollFrame")
    end
    InsetBackdrop(ml, key)
    local title = Optional(ml, "TitleText")
    if title then E.TextColor(title, T.text, key .. ".TitleText") end
end

local function SkinQuestLog(qm)
    local key = "QuestMapFrame"
    if not E.Usable(qm, key) then return end

    E.NeutralizeKeys(qm, { "VerticalSeparator" }, key)

    local qf = Sub(qm, "QuestsFrame", key .. ".QuestsFrame")
    if qf then
        local qs = Optional(qf, "ScrollFrame") or _G.QuestScrollFrame
        if qs then SkinQuestList(qs) else E.Missing("QuestScrollFrame") end

        local det = Optional(qf, "DetailsFrame")
        if det then SkinDetails(det) else E.Missing(key .. ".DetailsFrame") end

        local co = Optional(qf, "CampaignOverview")
        if co then SkinCampaign(co) end
    end

    local ev = Optional(qm, "EventsFrame")
    if ev then SkinEvents(ev) end

    local ml = Optional(qm, "MapLegend")
    if ml then SkinLegend(ml) end

    -- 隊伍同步：只把底圖收掉；指令鈕、說明字一律不碰（檔頭）
    local qsm = Optional(qm, "QuestSessionManagement")
    if qsm then E.NeutralizeKeys(qsm, { "BG" }, key .. ".QuestSessionManagement") end

    for _, k in ipairs(SIDE_TABS) do
        local tab = Optional(qm, k)
        if tab then SkinSideTab(tab, key .. "." .. k) else E.Missing(key .. "." .. k) end
    end
    local first = Optional(qm, "QuestsTab")
    if first then
        E.ShiftRoot(first, "TOPLEFT", qm, "TOPRIGHT", SIDE_TAB_X, -28, key .. ".QuestsTab")
    end
end

------------------------------------------------------------
-- hooks：一支**全域函式**後置勾（新的麵包屑）
------------------------------------------------------------
local function InstallHooks()
    if type(_G.NavBar_AddButton) ~= "function" then
        E.Missing("NavBar_AddButton")
        return
    end
    local broken = false
    hooksecurefunc("NavBar_AddButton", function(bar)
        if broken then return end
        local f = _G.WorldMapFrame
        local nav = f and Optional(f, "NavBar")
        if not nav or bar ~= nav then return end
        local ok, err = pcall(SweepCrumbs, nav)
        if not ok then
            broken = true
            E.NoteBrokenHook("worldmap.NavBar_AddButton")
            ns.ReportError(err)
        end
    end)
end

local function Apply()
    local f = _G.WorldMapFrame
    if not f then
        E.Missing("WorldMapFrame")
        return
    end

    SkinChrome(f)

    local nav = Optional(f, "NavBar")
    if nav then SkinNavBar(nav) else E.Missing("WorldMapFrame.NavBar") end

    -- 任務日誌面板被遊戲規則停用時沒有這一顆（Blizzard_WorldMap.lua:318-320）
    local spt = Optional(f, "SidePanelToggle")
    if spt then SkinSidePanelToggle(spt) end

    local qm = _G.QuestMapFrame
    if qm then SkinQuestLog(qm) else E.Missing("QuestMapFrame") end
end

E.Register{
    key   = "worldmap",
    addon = "Blizzard_WorldMap",       -- 非 LoD，但用插件名判斷比假設「一定在」安全
    title = L["World Map & Quest Log"],
    hooks = InstallHooks,
    apply = Apply,
}
