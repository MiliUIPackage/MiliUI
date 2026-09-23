------------------------------------------------------------
-- 配方：巨集（`MacroFrame`，隨需載入 `Blizzard_MacroUI`）＋ 名稱與圖示彈窗（`MacroPopupFrame`）
--
-- 第十二／十三輪。範圍與掛點照「成熟同類實作」的巨集段落搬（外框、分頁、六顆按鈕、
-- 巨集內文的輸入框、兩條捲軸、格子的底圖淡一半、名稱／圖示彈窗），外觀換成這一包的皮。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_MacroUI/Blizzard_MacroUI.toc:2  `## LoadOnDemand: 1` ⇒ `addon = "Blizzard_MacroUI"`
--   Blizzard_MacroUI/Blizzard_MacroUI.xml:5
--     `MacroButtonTemplate`（mixin `MacroButtonMixin`，← `SelectorButtonTemplate`）：
--     **一般 Button，不是 secure**（沒有 SecureFrameTemplate、沒有 SetAttribute）；
--     `OnDragStart` → `PickupMacro`（Blizzard_MacroUI.lua:40）。拖到快捷列那一步是快捷列
--     自己的 secure 點擊在收游標，跟這顆格子無關。
--   同檔 :23 `MacroFrame` ← `ButtonFrameTemplate`（toplevel，338x424）；自己的 region：
--     `MacroFramePortrait`（OVERLAY）／一條**無名** FontString `CREATE_MACROS`（BORDER，標題）／
--     `MacroHorizontalBarLeft` ＋ 一張**無名**的橫條（ARTWORK）／
--     `MacroFrameSelectedMacroBackground`（`UI-EmptySlot`）／`MacroFrameSelectedMacroName`／
--     `MacroFrameEnterMacroText`／`MacroFrameCharLimitText`
--   同檔 :85  `SelectedMacroButton`（MacroButtonTemplate，XML 載入期就建好）
--   同檔 :96  `MacroSelector`（← ScrollBoxSelectorTemplate：`.ScrollBar` ← MinimalScrollBar、
--             `.ScrollBox` ← WowScrollBoxList，Blizzard_SharedXML/Mainline/Selector/Blizzard_ScrollBoxSelector.xml:4）
--   同檔 :106,157,166,211,223,232  `MacroEditButton`／`MacroCancelButton`／`MacroSaveButton`／
--             `MacroDeleteButton`／`MacroNewButton`／`MacroExitButton`（全是 UIPanelButtonTemplate）
--   同檔 :115 `MacroFrameScrollFrame`（← ScrollFrameTemplate ⇒ `ScrollFrame_OnLoad` 建的
--             `.ScrollBar` 是 MinimalScrollBar，SecureUIPanelTemplates.lua:1,23）
--   同檔 :175 `MacroFrameTextBackground`（← TooltipBackdropTemplate ⇒ 一個 `NineSlice` 子框，
--             Blizzard_SharedXML/SharedTooltipTemplates.xml:111）
--   同檔 :181,191 `MacroFrameTab1/2`（← PanelTopTabButtonTemplate ← PanelTabButtonTemplate ⇒
--             有 `TabTextures` parentArray；Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:905,979）
--   Blizzard_MacroUI/Blizzard_MacroUI.lua:185-235 `MacroFrameMixin:UpdateButtons`
--     ⚠ **每次都對 `MacroEditButton`／`MacroDeleteButton`／`MacroNewButton` 下
--       `SetScript("OnEnter"/"OnLeave", …)`**（:232-235）⇒ 那三顆上任何 `HookScript` 都會在
--       下一次 UpdateButtons 被整個蓋掉（`.claude/notes/wow-setscript-clobbers-hookscript.md`）。
--       所以六顆按鈕一律走**零腳本**（滑過交給 C 端的 Highlight 貼圖），不是 `Skin.Button`。
--   Blizzard_MacroUI/Blizzard_MacroIconSelector.xml:5
--     `MacroPopupFrame` ← `IconSelectorPopupFrameTemplate`
--     （Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1633）：
--       `BG`（BACKGROUND，黑 0.8）／`BorderBox`（← SelectionFrameTemplate ← NineSlicePanelTemplate，
--       九片直接掛在 BorderBox 自己身上，SecureUIPanelTemplates.xml:97）／
--       `BorderBox.EditBoxHeaderText`／`.IconSelectionText`／`.IconSelectorEditBox`
--       （三張切片的 parentKey 是 `IconSelectorPopupNameLeft/Middle/Right`，**不是** Left/Middle/Right）／
--       `.IconTypeDropdown`（WowStyle1DropdownTemplate）／`.OkayButton`／`.CancelButton`
--       （UIPanelButtonNoTooltipTemplate）／`IconSelector`（ScrollBoxSelectorTemplate）
--
------------------------------------------------------------
-- ## 照抄的做法 ／ 照抄不了的地方
--
-- 照抄：
--   * 外框整組美術淡掉（包含標題列右邊的巨集圖示、兩條橫條、選中巨集後面那張空格底圖），
--     `Inset` 只淡掉美術、**不另畫內嵌底**（成熟同類實作的 `Inset` 也是只淡不畫）。
--   * 標題、選中巨集的名稱、字數提示改白。
--   * 巨集內文那一塊（`MacroFrameTextBackground`）：美術淡掉、畫一塊 `fillInset` ＋ 1px 黑邊。
--   * 兩條捲軸、兩顆分頁、六顆按鈕。
--   * **巨集格子的空格底圖淡到一半**（圖示、滑過、選中三張不動）。
--   * 彈窗：底與九宮格淡掉、面板底、名稱輸入框、圖示類型下拉、確定／取消、兩行說明字、捲軸。
-- 照抄不了：
--   * 分頁往左靠齊、選中巨集那一叢往上移 7、內文框上移 3、儲存／取消各上移 1／5 ——
--     全是 `ClearAllPoints`／`SetPoint` 重排（契約禁止，而且要讀 `GetPoint`／`GetLeft`）。
--   * 格子底圖的淡化，它是在 `ScrollBox` **實例**的 `Update` 上掛後置勾、每次重掃；
--     我們改成勾 **`MacroButtonMixin:OnLoad`**（mixin 表，格子是第一次打開巨集視窗時才建的
--     ⇒ 在 `hooks` 裝就來得及）——每顆格子建立時淡一次，暴雪之後不再碰那張圖。
--   * **彈窗的圖示格子**：它們是 `SelectorButtonTemplate`，**沒有**自己的 mixin／OnLoad，
--     要勾就只能勾 `SelectorButtonMixin`（全遊戲的圖示選擇器共用：裝備管理員、公會銀行分頁…），
--     而 hook 裡又不准讀欄位去分辨是誰的格子 ⇒ 不做，維持暴雪原樣。
--   * 它在視窗與彈窗上各掛一支 `HookScript("OnShow")` 重跑整套 —— 我們的中和全是 alpha、
--     暴雪不會打回來，一次就夠，**不掛**。
--
-- ## 刻意不碰
--   * `SelectedMacroButton`（選中巨集的大圖示）與彈窗的 `SelectedIconButton`：圖示就是內容。
--   * 巨集格子的圖示、名字、選中框（`SelectedTexture`）、滑過框。
--   * 彈窗的 `IconDragArea`（拖曳提示）、`SelectedIconArea.SelectedIconText`（在 VerticalLayoutFrame 裡）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `MacroFrame` 自己的每一張貼圖（`GetRegions` 掃，含兩張無名的） | `SetAlpha(0)`（`Engine.NeutralizeRegions`） |
-- | `MacroFrame` 的 NineSlice／PortraitContainer | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `MacroFrame` 本身 | `Engine.RegionBackdrop`（底＋邊＋標題帶，建成它自己的 BACKGROUND 貼圖） |
-- | `MacroFrame` 自己的 FontString（標題、巨集名稱、兩行提示） | `SetTextColor`（`Engine.RecolorRegions`） |
-- | `MacroFrame.Inset` 的 Bg／NineSlice | `SetAlpha(0)` |
-- | `CloseButton` | `Skin.CloseButton` |
-- | `MacroFrameTab1/2` | `Skin.TabGroup`（TabTextures `SetAlpha(0)` ＋ `SetNormalFontObject`） |
-- | 六顆按鈕、彈窗兩顆 | 零腳本：Left/Right/Middle `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 換長相（`Engine.ScriptlessButton`） |
-- | `MacroFrameTextBackground.NineSlice` | `SetAlpha(0)`；底＋邊建在 `MacroFrameTextBackground` 自己身上 |
-- | 兩條 `MinimalScrollBar`（`MacroSelector`、`MacroFrameScrollFrame`）＋ 彈窗 `IconSelector` 那一條 | `Skin.ScrollBar` |
-- | 巨集格子（`MacroButtonTemplate`）的空格底圖（無名，`GetRegions` 找） | `SetAlpha(0.5)` |
-- | `MacroPopupFrame.BG` | `SetAlpha(0)`；面板底建在 `MacroPopupFrame` 自己身上 |
-- | `MacroPopupFrame.BorderBox` 自己的九片（`GetRegions`） | `SetAlpha(0)` |
-- | `IconSelectorEditBox` 的三張切片 | `SetAlpha(0)` ＋ 一個 overlay（`fillInset` ＋ 黑邊） |
-- | `IconTypeDropdown` | `Skin.Dropdown` |
-- | `EditBoxHeaderText`／`IconSelectionText` | `SetTextColor(textDim)`（欄位標籤） |
--
-- ### 讀了什麼
-- 只有結構：parentKey、`GetRegions()`（找無名貼圖與 FontString）、`GetObjectType`。
-- **不讀** `selectionIndex`／`GetElementData()`／`macroBase`／任何巨集資料或文字。
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc(MacroButtonMixin, "OnLoad", …)` | mixin 後置勾（`Engine.HookRows`） | 第一次見到這顆格子：空格底圖 `SetAlpha(0.5)`。**不讀任何欄位** |
-- | `Engine.TrackTab`／`TrackButtonHover`／`TrackGlyph` 的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | **只對**兩顆分頁、關閉鈕、下拉；內容只換我們自己 overlay 的顏色 |
--
-- **六顆按鈕與彈窗兩顆上的 `HookScript`：0 支**（見上面 `UpdateButtons` 那一條）。
-- **`HookScript("OnShow")`：0 支。`hooksecurefunc` 在 `MacroFrame`／`MacroPopupFrame` 實例上：0 支。**
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

-- 「有就做、沒有就靜默跳過」
local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

------------------------------------------------------------
-- 零腳本按鈕（同 `Skins/PlayerSpells.lua` 的 `ScriptlessButton`）
-- TODO(升格): 這一輪又多兩份配方各寫一支（巨集／訓練師／交易／行事曆）—— 收成 `Skin.ScriptlessButton`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })       -- 先建 overlay 再中和（顯式保護框會回 nil）
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)   -- **不掛腳本**
    return ov
end

------------------------------------------------------------
-- 把「無名的裝飾貼圖」淡到某個 alpha（不是 0）
--
-- 成熟同類實作把巨集格子的空格底圖淡到**一半**而不是拿掉：拿掉之後格子之間只剩圖示，
-- 空格（還沒建的巨集）整個看不見，玩家不知道還剩幾格。`Engine.NeutralizeRegions` 只會
-- 下 0，所以這裡寫一支 local。只動 Texture、跳過 `keep` 與我們自己建的貼圖。
-- TODO(升格): 第二個需要「半淡」的配方出現時收進 Engine（`NeutralizeRegions` 加一個 alpha 參數）。
------------------------------------------------------------
local MACRO_SLOT_ART_ALPHA = 0.5     -- 成熟同類實作的值；空格底圖保留一半讓空格看得出來

local function DimRegions(owner, alpha, keep, label)
    if not E.Usable(owner, label) then return end
    if type(owner.GetRegions) ~= "function" then return end
    local ok, regions = pcall(function() return { owner:GetRegions() } end)
    if not ok then return end
    for _, region in ipairs(regions) do
        if type(region) == "table" and not (keep and keep[region]) and not E.ownRegions[region]
            and type(region.GetObjectType) == "function" then
            local ok2, kind = pcall(region.GetObjectType, region)
            if ok2 and kind == "Texture" and type(region.SetAlpha) == "function" then
                pcall(region.SetAlpha, region, alpha)
            end
        end
    end
end

------------------------------------------------------------
-- 巨集格子（`MacroButtonTemplate`）
--
-- 圖示是 NormalTexture（parentKey `Icon`）、滑過是 `Highlight`、選中是 `SelectedTexture`
-- （Blizzard_SharedXML/Shared/Selector/Blizzard_SelectorUI.xml:16,22,28）—— 這三張都是內容或狀態，
-- 留著；剩下那張無名的 `UI-EmptySlot-Disabled`（:7）才是底圖。
-- 暴雪之後只 `SetIconTexture`（換 Icon 的材質），不碰底圖 ⇒ 建立時淡一次就永久有效。
------------------------------------------------------------
local SLOT_KEEP_KEYS = { "Icon", "Highlight", "SelectedTexture" }

local function DimMacroSlot(btn)
    DimRegions(btn, MACRO_SLOT_ART_ALPHA, E.KeepSet(btn, SLOT_KEEP_KEYS), "MacroButton")
end

local macroSlotSweep

------------------------------------------------------------
-- 外框
------------------------------------------------------------
local function SkinChrome(f)
    -- 自己的每一張貼圖（肖像、兩條橫條、選中巨集的空格底圖、ButtonFrame 的 Bg／TopTileStreaks）
    E.NeutralizeRegions(f, "MacroFrame")
    Skin.PortraitChrome(f, "MacroFrame")
    Skin.Panel(f, "MacroFrame")

    -- 標題（無名 FontString `CREATE_MACROS`，GameFontNormal 暗金）、巨集名稱、兩行提示 → 白。
    -- 暴雪對這幾條只 `SetText`／`SetFormattedText`（Blizzard_MacroUI.lua:132,281）⇒ 一次就永久有效。
    E.RecolorRegions(f, T.text, "MacroFrame")

    -- Inset：成熟同類實作只淡掉美術、不另畫內嵌底（格子與內文框各自有底）
    local inset = Optional(f, "Inset")
    if inset then E.NeutralizeKeys(inset, { "Bg", "NineSlice" }, "MacroFrame.Inset") end

    local close = Sub(f, "CloseButton", "MacroFrame.CloseButton")
    if close then Skin.CloseButton(close, "MacroFrame.CloseButton") end

    -- 兩顆頂部分頁：`PanelTopTabButtonTemplate` 掛在格子區的**上方** ⇒ 相連的是下邊
    -- （同收藏視窗外觀頁的頂部分頁，`Skins/CollectionsWardrobe.lua`）。
    local tabs = {}
    for i = 1, 2 do
        local tab = _G["MacroFrameTab" .. i]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = "MacroFrameTab" .. i }
        else
            E.Missing("MacroFrameTab" .. i)
        end
    end
    if #tabs > 0 then Skin.TabGroup(tabs, { kind = "panel", joined = "BOTTOM" }) end
end

------------------------------------------------------------
-- 格子區與內文區
------------------------------------------------------------
local function SkinBody(f)
    local sel = Sub(f, "MacroSelector", "MacroFrame.MacroSelector")
    if sel then
        local bar = Optional(sel, "ScrollBar")
        if bar then Skin.ScrollBar(bar, "MacroFrame.MacroSelector.ScrollBar") end
        -- 已經建好的格子（戰鬥中第一次開、或 hook 之前就開過）補掃一次
        local box = Optional(sel, "ScrollBox")
        if box and macroSlotSweep then
            E.SweepRows(box, "MacroFrame.MacroSelector.ScrollBox", macroSlotSweep)
        end
    end

    -- 巨集內文框：TooltipBackdrop 的九宮格淡掉，底＋邊建在它自己身上。
    -- 它跟 `MacroFrameScrollFrame` 是兄弟、同一層 ⇒ 原本那塊不透明的 NineSlice 中心就畫在
    -- 內文底下；我們的貼圖在它自己的 BACKGROUND −8，位置一樣。
    local well = _G.MacroFrameTextBackground
    if well then
        E.NeutralizeKeys(well, { "NineSlice" }, "MacroFrameTextBackground")
        local ov = E.RegionBackdrop(well, { key = "MacroFrameTextBackground" })
        E.Paint(ov, T.fillInset, T.border)
    else
        E.Missing("MacroFrameTextBackground")
    end

    local scroll = _G.MacroFrameScrollFrame
    local sbar = scroll and Optional(scroll, "ScrollBar")
    if sbar then
        Skin.ScrollBar(sbar, "MacroFrameScrollFrame.ScrollBar")
    else
        E.Missing("MacroFrameScrollFrame.ScrollBar")
    end

    -- 六顆按鈕，一律零腳本（檔頭：`UpdateButtons` 每次都 SetScript 其中三顆的 OnEnter/OnLeave）。
    -- 分派（STYLE.md ④ 判準）：
    --   儲存／取消 成對 ⇒ 儲存 primary、取消 secondary；
    --   底部一排：新增 primary（這一塊唯一的「執行」）、刪除與離開 secondary；
    --   「變更名稱／圖示」開彈窗（判準 5 的精神：它不是動作本身）⇒ secondary。
    local buttons = {
        { "MacroSaveButton",   "primary" },
        { "MacroCancelButton", "secondary" },
        { "MacroNewButton",    "primary" },
        { "MacroDeleteButton", "secondary" },
        { "MacroExitButton",   "secondary" },
        { "MacroEditButton",   "secondary" },
    }
    for _, b in ipairs(buttons) do
        local btn = _G[b[1]]
        if btn then
            ScriptlessButton(btn, b[1], b[2])
        else
            E.Missing(b[1])
        end
    end
end

------------------------------------------------------------
-- 名稱與圖示彈窗（`MacroPopupFrame`）
--
-- 貼在巨集視窗右邊的延伸面板（錨 `TOPLEFT → MacroFrame TOPRIGHT`，XML:7）⇒ 設定視窗皮，
-- 跟巨集視窗同一套（成熟同類實作也是用面板底，不是提示皮）。
-- ⚠ `BorderBox` 是 `frameLevel="50"` 的 setAllPoints 子框、九片掛在**它自己身上** ——
--   不能對它下 `SetAlpha(0)`（整個子樹的輸入框與按鈕會一起消失），只能掃它自己的 region。
------------------------------------------------------------
local POPUP_NAME_ART = { "IconSelectorPopupNameLeft", "IconSelectorPopupNameMiddle", "IconSelectorPopupNameRight" }

local function SkinPopup()
    local p = _G.MacroPopupFrame
    if not p then
        E.Missing("MacroPopupFrame")
        return
    end
    if not E.Usable(p, "MacroPopupFrame") then return end

    E.NeutralizeKeys(p, { "BG" }, "MacroPopupFrame")
    Skin.Panel(p, "MacroPopupFrame")

    local bb = Sub(p, "BorderBox", "MacroPopupFrame.BorderBox")
    if bb then
        E.NeutralizeRegions(bb, "MacroPopupFrame.BorderBox")

        -- 名稱輸入框：三張切片的 parentKey 不是 Left/Middle/Right ⇒ `Skin.EditBox` 會把
        -- 三個找不到的 key 記成 missing，這裡自己組。矩形照原本那組美術的橫向範圍
        -- （Left 錨 x=-11、Right 接在 175 寬的 Middle 之後 ⇒ 比框多出左 11／右 6），
        -- 收成左右各 5，高度就是框本身的 20（SharedUIPanelTemplates.xml:1765-1790）。
        local eb = Optional(bb, "IconSelectorEditBox")
        if eb then
            E.NeutralizeKeys(eb, POPUP_NAME_ART, "MacroPopupFrame.IconSelectorEditBox")
            local ov = E.Overlay(eb, {
                key = "MacroPopupFrame.IconSelectorEditBox",
                points = {
                    { "TOPLEFT", "TOPLEFT", -5, 0 },
                    { "BOTTOMRIGHT", "BOTTOMRIGHT", 5, 0 },
                },
            })
            E.Paint(ov, T.fillInset, T.border)
        else
            E.Missing("MacroPopupFrame.BorderBox.IconSelectorEditBox")
        end

        local dd = Optional(bb, "IconTypeDropdown")
        if dd then Skin.Dropdown(dd, "MacroPopupFrame.IconTypeDropdown", "style1") end

        -- 確定（建立／修改巨集）primary、取消 secondary；零腳本跟巨集視窗一致
        local okay = Optional(bb, "OkayButton")
        if okay then ScriptlessButton(okay, "MacroPopupFrame.OkayButton", "primary") end
        local cancel = Optional(bb, "CancelButton")
        if cancel then ScriptlessButton(cancel, "MacroPopupFrame.CancelButton", "secondary") end

        -- 兩行欄位說明（「輸入巨集名稱：」「選擇一個圖示：」）⇒ `textDim`（④ 文字層級）。
        -- `EditBoxHeaderText` 只在 OnLoad `SetText` 一次（SharedUIPanelTemplates.lua:1717）；
        -- `IconSelectionText` 只被 `SetShown`（:1786）⇒ 一次就永久有效。
        for _, k in ipairs({ "EditBoxHeaderText", "IconSelectionText" }) do
            local fs = Optional(bb, k)
            if fs then E.TextColor(fs, T.textDim, "MacroPopupFrame." .. k) end
        end
    end

    local grid = Optional(p, "IconSelector")
    local gbar = grid and Optional(grid, "ScrollBar")
    if gbar then Skin.ScrollBar(gbar, "MacroPopupFrame.IconSelector.ScrollBar") end
end

------------------------------------------------------------
-- hooks：一支 mixin 後置勾（格子的底圖）
--
-- `MacroButtonMixin` 定義在 Blizzard_MacroUI.lua:25，格子由 `MacroSelector` 第一次 OnShow
-- （`ScrollBoxSelectorMixin:OnShow` → `Init`，Blizzard_ScrollBoxSelector.lua:4-30）才建 ⇒
-- 在 ADDON_LOADED 的 `hooks` 裝，比所有格子都早。`SelectedMacroButton` 是 XML 期建的、
-- 追不上 —— 刻意不處理（它是選中巨集的大圖示，檔頭「刻意不碰」）。
------------------------------------------------------------
local function InstallHooks()
    macroSlotSweep = E.HookRows{
        key    = "MacroFrame.MacroButton",
        mixin  = _G.MacroButtonMixin,
        method = "OnLoad",
        apply  = DimMacroSlot,
    }
end

local function Apply()
    local f = _G.MacroFrame
    if not f then
        E.Missing("MacroFrame")
        return
    end
    if not E.Usable(f, "MacroFrame") then return end

    SkinChrome(f)
    SkinBody(f)
    SkinPopup()
end

E.Register{
    key   = "macro",
    addon = "Blizzard_MacroUI",
    title = L["Macros"],
    hooks = InstallHooks,
    apply = Apply,
}
