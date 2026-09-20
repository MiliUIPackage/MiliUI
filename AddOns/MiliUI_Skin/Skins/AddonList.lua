------------------------------------------------------------
-- 配方：插件列表（AddonList，遊戲內那一份）
--
-- ⚠ **只處理遊戲內那一份。** 同一個 `Blizzard_AddOnList` 在角色選擇畫面（glue）
--   也會載入一次，那個環境是另一個 Lua 狀態、我們的插件根本不在那裡，碰不到也不該碰。
--   （TOC 的 `## AllowLoad: Both` 就是這個意思。）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_AddOnList/Blizzard_AddOnList.toc     `## DefaultState: enabled`、
--                                                 **沒有** LoadOnDemand、`AllowLoad: Both`
--   Blizzard_AddOnList/AddonList.xml:4    AddonListBaseTemplate
--     —— HighlightTexture 是 `UI-QuestTitleHighlight`（ADD），而且錨的是
--        `LEFT x=40` / `RIGHT`、高度寫死 22（列本身只有 16 高）
--        ⇒ **矩形跟按鈕矩形不一樣**，跟成就分類列同一個坑（STYLE.md ⑤ 的
--        `AchievementCategoryTemplate` 那一列）⇒ 走 `Skin.Row` 的 `opts.ownHover`
--   同檔 :14   AddonListCategoryTemplate（`CollapseExpand` 按鈕 ＋ `Title`）
--     :22-24   CollapseExpand 的 `Normal`/`Pushed`/`Highlight`（三張都是 atlas `bag-arrow`）
--   同檔 :45   AddonListEntryTemplate（`Title`/`Status`/`Reload` ＋ `Enabled`
--              CheckButton ＋ `LoadAddonButton` UIPanelButtonTemplate）
--   同檔 :91,93 AddonDialog（全螢幕 modal）／AddonDialogBackground（**DialogBorderTemplate**）
--     :97,106,109 AddonDialogText（GameFontNormalLarge）／AddonDialogButton1/2
--   同檔 :120  AddonList（**ButtonFrameTemplate**，600x550）
--     :126  `Dropdown`（WowStyle1DropdownTemplate，角色下拉）
--     :131  `ForceLoad`（**MinimalCheckboxTemplate**）＋ 一條**無名** FontString
--     :145  `SearchBox`（SearchBoxTemplate）
--     :151  `Performance`（`Header`/`Current`/`Average`/`Peak` ＋ `Divider`
--            atlas Options_HorizontalDivider）
--     :190,196,202,208 CancelButton／OkayButton／EnableAllButton／DisableAllButton
--            （**SharedButtonSmallTemplate**）
--     :214,222 `ScrollBox`（WowScrollBoxList）／`ScrollBar`（MinimalScrollBar）
--   Blizzard_AddOnList/AddonList.lua:207  **`local function AddonList_InitCategory`**
--   同檔 :338  `function AddonList_InitAddon`（**全域**）
--   同檔 :317  TriStateCheckbox_SetState（`checkedTexture:SetVertexColor(1,1,1)` ／
--              `SetDesaturated(true)`，「部分角色啟用」是灰勾）
--   同檔 :367-371 `entry.Title:SetTextColor(...)`（金／紅／灰＝可否載入，是**資訊**）
--   同檔 :426  `function AddonList_Update`（**全域**）
--   同檔 :901  AddonCategoryCollapseExpandMixin:UpdateState（只 `SetRotation`）
--   Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:66,74
--     MinimalCheckboxArtTemplate／MinimalCheckboxTemplate
--     （NormalTexture/PushedTexture/HighlightTexture ＝ atlas `checkbox-minimal`、
--      CheckedTexture ＝ `checkmark-minimal`、DisabledCheckedTexture）
--   Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:4,62,83
--     ThreeSliceButtonTemplate → `Left` / `Right` / **`Center`**（不是 `Middle`）
--   Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.lua
--     ThreeSliceButtonMixin:UpdateButton 每次 OnShow/OnEnable/OnDisable/OnMouseDown
--       重設三張的 **atlas** ＋ UpdateScale 改 SetScale/SetTexCoord/SetWidth
--       ⇒ alpha 是獨立屬性，中和撐得住
--     ThreeSliceButtonMixin:InitButton `SetHighlightAtlas(...)` **只在 OnLoad 跑一次**
--       ⇒ 引擎的白 8% 不會被打回
--   Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml:63,69
--     DialogBorderNoCenterTemplate ← NineSlicePanelTemplate（九片掛在框自己身上）
--     ＋ DialogBorderTemplate 的 `Bg`（UI-DialogBox-Background）
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的三件事
--
-- 1. **分類列沒有可以掛的初始化。** `AddonList_InitCategory`（AddonList.lua:207）是
--    **local**，`AddonListCategoryMixin` 只有 `OnClick`（繼承自 `AddonListNodeMixin`），
--    池化列那條標準路（`Engine.HookRows` 勾 mixin 的 Init）走不通。
--    走法改成：借 `AddonList_Update`（**全域**，:426）當觸發點，每次清單重建之後
--    用 `Engine.SweepRows` 把**當下已經 Acquire 的列**掃一遍。
--    ⚠ 「套一次／已經套過」的機制仍然全部在引擎裡（弱鍵表、保護框跳過、出錯停用），
--      配方只是把 sweeper 拿來用 —— 那支 sweeper 是 `Engine.HookRows` 產生的，
--      而它掛的那支「Init」在這裡指定成 `AddonList_Update` 本身：那支函式沒有參數，
--      `HookRows` 的第一行型別檢查會直接返回，等於只借它的 sweeper、不真的靠它派送。
--
-- 2. **「啟用」勾選框是三態的，所以第六輪起它的勾一根手指都不碰。**
--    `TriStateCheckbox_SetState` 對「部分角色啟用」做
--    `checkedTexture:SetDesaturated(true)`、對「全部啟用」做
--    `SetVertexColor(1, 1, 1)` ＋ `SetDesaturated(false)`。
--    ⚠ 第五輪的作法（Checked 換成整格職業色）**在實機上是錯的**：那顆按鈕是
--      24x24，整格塗滿就是一個大藍方塊（使用者擷圖 33）。
--    ⚠ 但也不能改成「染職業色」：那支函式是 **local**（AddonList.lua:164-179）、
--      勾不到，而我們唯一能動手的時機（`AddonList_InitAddon` 的後置勾）跑在它
--      **之後** —— 在那裡無條件染色會讓「全部啟用」與「部分啟用」長得一模一樣，
--      等於把那個區分抹掉。而且我們也沒有辦法分辨是哪一種
--      （分辨要讀 `elementData`／按鈕的狀態欄位，兩個都不在讀取例外表上）。
--    ⇒ 方框收成 18 的小方框（`Skin.CheckBox` 的預設），**勾整個交還暴雪**
--      （`opts.keepCheck`）。它的 CheckedTexture 本來就是 `checkmark-minimal`，
--      白色細勾配深色小方框 —— 形狀已經是目標，只是顏色是白的不是職業色。
--
-- 3. **底部四顆按鈕不是 `UIPanelButtonTemplate`。** 它們是
--    `SharedButtonSmallTemplate` ← `ThreeSliceButtonTemplate`，三片的 parentKey 是
--    `Left` / `Right` / **`Center`** —— `Skin.Button` 找的是 `Middle`，直接套會
--    把中間那一片留在畫面上。所以這一份自己有一支三片式的 local 小函式。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 視窗本體
--
-- | 物件 | 動作 |
-- |---|---|
-- | AddonList 的 NineSlice / Bg / TopTileStreaks / PortraitContainer | SetAlpha(0) |
-- | AddonList.TitleContainer.TitleText | SetTextColor |
-- | AddonList.Inset 的 Bg 與 NineSlice | SetAlpha(0) |
-- | AddonListCloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | 同上的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | AddonList.Dropdown 的 Background | SetAlpha(0)；Arrow | SetVertexColor |
-- | AddonList.SearchBox 的 Left/Right/Middle | SetAlpha(0)；searchIcon／clearButton.Icon／Instructions | SetVertexColor／SetTextColor |
-- | AddonList.ForceLoad 的 Normal/Pushed/Disabled | SetAlpha(0)。**Checked 不碰**（見上） |
-- | AddonList.ForceLoad 的無名 FontString | SetTextColor |
-- | AddonList.Performance.Header | SetTextColor |
-- | AddonList.Performance.Divider | SetVertexColor |
-- | Cancel/Okay/EnableAll/DisableAll 的 Left/Right/Center | SetAlpha(0) |
-- | 同四顆 | SetNormalFontObject(GameFontHighlight)；Highlight 貼圖 | SetColorTexture |
-- | AddonList.ScrollBar 的 Track/Thumb 六張 | SetAlpha(0)；Back/Forward.Texture | SetVertexColor |
--
-- ### 池化列
--
-- | 物件 | 動作 |
-- |---|---|
-- | 插件列的 HighlightTexture | SetAlpha(0)（兩態都自己畫，`opts.ownHover`） |
-- | 插件列的 `Enabled` 勾選框 | 同 ForceLoad |
-- | 插件列的 `LoadAddonButton` 的 Left/Right/Middle | SetAlpha(0) |
-- | 分類列的 HighlightTexture | SetAlpha(0)（同上） |
-- | 分類列的 `Title` | SetTextColor |
-- | 分類列的 `CollapseExpand` 的 Normal/Pushed | SetVertexColor |
--
-- ### 彈出的重載對話框
--
-- | 物件 | 動作 |
-- |---|---|
-- | AddonDialogBackground 的九片 ＋ Bg | SetAlpha(0) |
-- | AddonDialogText | SetTextColor |
-- | AddonDialogButton1/2 的 Left/Right/Middle | SetAlpha(0) |
--
-- 以上各框：`CreateFrame` 掛自己的 overlay（錨在目標上、不吃滑鼠、零腳本）。
--
-- hook（全部是後置勾，不換函式）：
--   * `Engine.HookRows` 兩支：`AddonList_InitAddon`（全域）與
--     `AddonCategoryCollapseExpandMixin:UpdateState`。
--   * `Engine.HookRows` 借掛在 `AddonList_Update` 上的第三支（只為了拿 sweeper，
--     見上面第 1 點）。
--   * `hooksecurefunc("AddonList_Update", …)` —— 每次清單重建之後補掃已建立的列。
--   * 列的 `HookScript("OnEnter"/"OnLeave")`（`opts.ownHover` →
--     `Engine.TrackSelectable`，模板自己的 OnEnter 保留）。
--
-- 寫入暴雪欄位：無。讀暴雪物件：無（這一份一條讀取例外都沒用到）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **角色選擇畫面（glue）那一份 AddonList** —— 另一個 Lua 狀態，我們不在那裡。
-- * **插件列的 `Title` 顏色** —— 金／紅／灰是「可以載入／要重載／停用中」
--   （AddonList.lua:367-371），是資訊，而且每次 Init 都重設。
-- * **`Status`（GameFontNormalSmall）與 `Reload`（GameFontRed）** —— 同上，是狀態文字。
-- * **`Enabled` 勾選框的三態語意** —— 我們只換 Checked 貼圖的長相，
--   `SetChecked` 一次都沒呼叫（契約禁止）。
-- * **`CollapseExpand` 的箭頭圖形與旋轉** —— `UpdateState`（:901）用
--   `SetRotation` 表示收合／展開，那是資訊；我們只染色（`SetRotation` 不碰
--   vertex color ⇒ 染一次就撐得住）。
-- * **`Performance` 的 Current/Average/Peak** —— 已經是 `GameFontWhite`。
-- * **`AddonDialog` 本身**（全螢幕的 modal 擋板）—— 它沒有任何美術，只是一塊
--   吃滑鼠與鍵盤的透明板。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

-- NineSliceUtil.ApplyLayout 建出來的九片，直接掛在框自己身上
-- （Blizzard_SharedXML/NineSlice.lua；同 Skins/Character.lua）
local NINE_SLICE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

-- 三片式按鈕（`ThreeSliceButtonTemplate` 系）第五輪升格成 `Skin.ThreeSliceButton`，
-- 模板名與「中間那一片叫 Center」的理由都搬進原語。

------------------------------------------------------------
-- 池化列
------------------------------------------------------------
-- 「這一列是插件還是分類」——讀結構不讀值（SweepRows 補掃時認人用）
local function IsAddonEntry(row)
    return type(row) == "table" and row.Enabled ~= nil and row.LoadAddonButton ~= nil
end

local function IsCategoryRow(row)
    return type(row) == "table" and row.CollapseExpand ~= nil and row.Enabled == nil
end

-- 列底色。清單列沒有邊、也不隔行明暗：整片跟 Inset 同色（閒置時看不出來），
-- 滑過才亮成 `fillHover`。
-- ⚠ 滑過**不能交給引擎**：模板的 HighlightTexture 錨的是 `LEFT x=40` / `RIGHT`、
--   高度寫死 22（列只有 16 高），換成純色就會是一條比列還高、左邊缺 40 的白帶。
--   所以走 `opts.ownHover`（中和 Highlight ＋ `Engine.TrackSelectable` 兩態自己畫），
--   跟成就分類列同一條退路。
local function ApplyEntryRow(row)
    Skin.Row(row, "AddonListEntry", { fill = T.fillInset, ownHover = true })

    -- ⚠ `keepCheck`：**這顆勾是三態的，那張圖本身帶了狀態語意。**
    --   `TriStateCheckbox_SetState`（AddonList.lua:164-179，**local**、勾不到）
    --   用「全部啟用 ＝ `SetVertexColor(1,1,1)` ＋ `SetDesaturated(false)`」與
    --   「部分角色啟用 ＝ `SetDesaturated(true)`」區分兩種已勾。
    --   我們要是去染職業色，兩種狀態就會長得一模一樣 —— 那是把資訊抹掉，
    --   不是換皮。而且它的 CheckedTexture 本來就是 `checkmark-minimal`
    --   （CheckButtonTemplates.xml:66,74）：白色細勾配深色小方框，
    --   形狀已經就是我們要的那一種，只差顏色。
    --   ⇒ 方框照樣收成 18 的小方框，勾整個交還暴雪。
    local cb
    if pcall(function() cb = row.Enabled end) and cb then
        Skin.CheckBox(cb, "AddonListEntry.Enabled", { keepCheck = true })
    end

    local load
    if pcall(function() load = row.LoadAddonButton end) and load then
        Skin.Button(load, "AddonListEntry.LoadAddonButton")
    end
end

local function ApplyCategoryRow(row)
    Skin.Row(row, "AddonListCategory", { fill = T.fillInset, ownHover = true })

    -- 分類名字是 GameFontNormal（暗金），`AddonList_InitCategory` 只 SetText、
    -- 不重設顏色 ⇒ 設一次就撐得住。
    local title
    if pcall(function() title = row.Title end) and title then
        E.TextColor(title, T.text, "AddonListCategory.Title")
    end
end

-- 收合／展開的小箭頭。三張都是 atlas `bag-arrow`（中性灰的箭頭，不是烤了顏色的
-- 紅金鈕），所以不必去飽和、直接染 `textDim` 就準。
-- ⚠ **不畫 overlay、也不碰 Highlight**：那顆鈕只有 10x16，框起來比箭頭還顯眼；
--   而它的 HighlightTexture 就是同一張箭頭（alpha 0.4 ADD），`SetColorTexture`
--   會把它變成一個白色方塊。滑過的提亮交給那張 ADD 貼圖自己。
local function ApplyCollapseButton(btn)
    for _, key in ipairs({ "Normal", "Pushed" }) do
        local tex
        if pcall(function() tex = btn[key] end) and tex then
            E.VertexColor(tex, T.textDim, "AddonListCategory.CollapseExpand." .. key)
        end
    end
end

------------------------------------------------------------
-- 重載對話框（切換啟用狀態之後彈出來的那個）
------------------------------------------------------------
local function ApplyDialog()
    local bg = _G.AddonDialogBackground
    if not bg then
        E.Missing("AddonDialogBackground")
        return
    end

    E.NeutralizeKeys(bg, NINE_SLICE_PIECES, "AddonDialogBackground")
    E.NeutralizeKeys(bg, { "Bg" }, "AddonDialogBackground")
    E.NeutralizeChildNineSlices(bg, "AddonDialogBackground")

    local ov = E.Overlay(bg, { key = "AddonDialogBackground" })
    E.Paint(ov, T.fill, T.border)

    E.TextColor(_G.AddonDialogText, T.text, "AddonDialogText")

    for i = 1, 2 do
        local name = "AddonDialogButton" .. i
        local btn = _G[name]
        if btn then
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local entrySweep, categorySweep

local function InstallHooks()
    -- ⚠ 這一段**不過戰鬥閘**（Engine 的 RunUnit 在戰鬥閘之前跑它）。
    --   mixin／全域後置勾裝晚了，先建好的列永遠不會進來（STYLE.md ③ 的陷阱 4）。

    -- 插件列：初始化函式是**全域**（AddonList.lua:338）⇒ `mixin = _G`
    entrySweep = E.HookRows{
        key    = "AddonListEntry",
        mixin  = _G,
        method = "AddonList_InitAddon",
        match  = IsAddonEntry,
        apply  = ApplyEntryRow,
        -- reapply 不需要：`AddonList_InitAddon` 對我們碰過的東西只做
        -- `Title:SetTextColor`（資訊，我們不接管）與 `TriStateCheckbox_SetState`
        -- （改的是 Checked 貼圖的 vertex color／去飽和，不是我們下的 colorTexture）。
    }

    -- 分類列：`AddonList_InitCategory` 是 **local**，掛不上去 ⇒ 借
    -- `AddonList_Update`（全域、無參數）當掛點，只為了拿它產生的 sweeper。
    -- `HookRows` 的 `Handle` 第一行是 `type(row) ~= "table"` ⇒ 真的被派送到時
    -- 會立刻返回，不會誤把一個非 frame 當成列。
    categorySweep = E.HookRows{
        key    = "AddonListCategory",
        mixin  = _G,
        method = "AddonList_Update",
        match  = IsCategoryRow,
        apply  = ApplyCategoryRow,
    }

    -- 收合鈕：這一支是真的 mixin 方法（AddonList.lua:901），每次分類列初始化與
    -- 每次收合／展開都會跑。`SetRotation` 不碰 vertex color ⇒ 只要 apply。
    E.HookRows{
        key    = "AddonListCategory.CollapseExpand",
        mixin  = _G.AddonCategoryCollapseExpandMixin,
        method = "UpdateState",
        apply  = ApplyCollapseButton,
    }

    -- 每次清單重建之後補掃一次已經 Acquire 的列（分類列唯一的來源，
    -- 插件列則是「hook 也沒趕上」時的保險）。
    if type(_G.AddonList_Update) == "function" then
        hooksecurefunc("AddonList_Update", function()
            local f = _G.AddonList
            local box
            if f and pcall(function() box = f.ScrollBox end) and box then
                E.SweepRows(box, "AddonList.ScrollBox", entrySweep, categorySweep)
            end
        end)
    else
        E.Missing("AddonList_Update")
    end
end

local function Apply()
    local f = _G.AddonList
    if not f then
        E.Missing("AddonList")
        return
    end

    Skin.PortraitChrome(f, "AddonList")
    Skin.Panel(f, "AddonList")

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "AddonList.Inset")
    else
        E.Missing("AddonList.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "AddonList.CloseButton")
    else
        E.Missing("AddonList.CloseButton")
    end

    local dd
    if pcall(function() dd = f.Dropdown end) and dd then
        Skin.Dropdown(dd, "AddonList.Dropdown", "style1")
    else
        E.Missing("AddonList.Dropdown")
    end

    local search
    if pcall(function() search = f.SearchBox end) and search then
        Skin.EditBox(search, "AddonList.SearchBox")
    else
        E.Missing("AddonList.SearchBox")
    end

    -- 「載入過期插件」。`MinimalCheckboxTemplate` 的四張狀態圖全部走 getter
    -- ⇒ `Skin.CheckBox` 直接適用。旁邊那條說明字是**無名無 parentKey** 的
    -- layer FontString（AddonList.xml:137）⇒ 只能走 `Engine.RecolorRegions`。
    -- ⚠ `keepCheck`：這一顆**不是**三態的（它只是一般的勾選框），但它跟列上那
    --   一整排是同一個模板、同一個視窗、同一張 `checkmark-minimal`。
    --   只有它染成職業色的話，玩家在同一個畫面上會看到兩種不同顏色的勾 ——
    --   那讀起來像 bug 而不像設計。一致性在這裡贏過「跟別的視窗一致」。
    local force
    if pcall(function() force = f.ForceLoad end) and force then
        Skin.CheckBox(force, "AddonList.ForceLoad", { keepCheck = true })
        E.RecolorRegions(force, T.text, "AddonList.ForceLoad")
    else
        E.Missing("AddonList.ForceLoad")
    end

    -- 效能那一區：標題改白，底下那條分隔線染成髮絲線的顏色
    -- （深底上的分隔線要比底**亮**才看得見，同 `Skin.SectionTitle` 的理由）。
    local perf
    if pcall(function() perf = f.Performance end) and perf then
        local header
        if pcall(function() header = perf.Header end) and header then
            E.TextColor(header, T.text, "AddonList.Performance.Header")
        end
        local divider
        if pcall(function() divider = perf.Divider end) and divider then
            E.VertexColor(divider, T.fillHover, "AddonList.Performance.Divider")
        end
    else
        E.Missing("AddonList.Performance")
    end

    for _, key in ipairs({ "CancelButton", "OkayButton", "EnableAllButton", "DisableAllButton" }) do
        local btn
        if pcall(function() btn = f[key] end) and btn then
            Skin.ThreeSliceButton(btn, "AddonList." .. key)
        else
            E.Missing("AddonList." .. key)
        end
    end

    local bar
    if pcall(function() bar = f.ScrollBar end) and bar then
        Skin.ScrollBar(bar, "AddonList.ScrollBar")
    else
        E.Missing("AddonList.ScrollBar")
    end

    -- 補掃：正常情況下 PLAYER_LOGIN 時一列都還沒建立（ScrollBox 是開視窗才長列的），
    -- 這一掃是給「hook 也沒趕上」的情況留的保險。
    local box
    if pcall(function() box = f.ScrollBox end) and box then
        E.SweepRows(box, "AddonList.ScrollBox", entrySweep, categorySweep)
    end

    ApplyDialog()
end

E.Register{
    key   = "addonlist",
    addon = "Blizzard_AddOnList",      -- 非 LoD，但用插件名判斷比假設「一定在」安全
    title = L["AddOns"],
    hooks = InstallHooks,
    apply = Apply,
}
