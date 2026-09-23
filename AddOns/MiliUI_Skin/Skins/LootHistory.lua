------------------------------------------------------------
-- 配方：拾取記錄視窗（`GroupLootHistoryFrame`，官方標題 LOOT_ROLLS「拾取記錄」）
--
-- 做法照「成熟同類實作」的 Loot Rolls 段落：**列舉式**（不掃整棵樹 —— 樹裡是池化的
-- 戰利品列），外框、關閉鈕、首領下拉、計時條、捲軸、底部的縮放握把、池化列。
-- 外觀換成本包的設定視窗皮（`T.fill` 面板 ＋ 黑邊、`fillInset` 內嵌）。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_FrameXML/Mainline/LootHistory.xml:190-430  `GroupLootHistoryFrame`
--     ← `DefaultPanelFlatTemplate`（HIGH strata、toplevel、resizable、261x590）
--     `ClosePanelButton`（UIPanelCloseButtonDefaultAnchors）／`ScrollBox`（WowScrollBoxList）／
--     `ScrollBar`（MinimalScrollBar）／`EncounterDropdown`（WowStyle1DropdownTemplate）／
--     `Timer`（Frame 238x13：`Background` atlas、`Fill` atlas **Texture**（不是 StatusBar）、`Border` atlas）／
--     `ResizeButton`（Button 32x12，無名 OVERLAY 貼圖 `lootroll-resizehandle`）／
--     `PerfectAnimFrame`（LootHistoryElementTemplate ＋ 動畫，XML 載入期就建好）／`NoInfoString`
--   同檔 :3-141  `LootHistoryElementTemplate`（mixin="LootHistoryElementMixin"，frameLevel 500）：
--     `Item`（ItemButton 48x48，NormalTexture 覆寫成空）／`BackgroundArtFrame`（frameLevel 400：
--     `NameFrame` BACKGROUND、`BorderFrame` BORDER）／`WinningRollInfo`／`PendingRollInfo`／
--     `AllPassedInfo`／`PlayerRoll`（HIGH strata）／`ItemName`
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:478-535
--     `DefaultPanelBaseTemplate`（`TitleContainer.TitleText`、`NineSlice`）／
--     `DefaultPanelFlatTemplate`（`Bg` ← FlatPanelBackgroundTemplate，**是子框**，frameLevel 0）
--     ⇒ 沒有 `PortraitContainer`／`TopTileStreaks`，不用 `Skin.PortraitChrome`（會記一堆 Missing）
--   Blizzard_FrameXML/Mainline/LootHistory.lua
--     :100-188 `LootHistoryElementMixin:Init(dropInfo)` → `SetItemButtonQuality(self.Item, …)`（全域，
--              `Engine.TrackItemButton` 接得到）**之後**才 `self.Item.icon:SetTexture(...)`
--              ⇒ 裁邊一定要放在 Init 的後置勾（reapply）；`ItemName:SetVertexColor(品質色)` 不碰；
--              每次 Init 都 `self.Item:SetScript("OnClick"/"OnEnter"/"OnLeave")` ⇒ Item 上**不能**掛 HookScript
--              （會被 SetScript 蓋掉；`Skin.ItemButton` 本來就不掛）
--     :16-24   `OnEvent(LOOT_HISTORY_UPDATE_DROP)` → `self:Init(...)`（方法呼叫 ⇒ 也走 mixin 後置勾）
--     :377-405 `InitScrollBox`：列是**看到才建**（`SetDataProvider` 在 OnShow 之後）⇒ `hooks` 裝的 mixin
--              後置勾來得及；`PerfectAnimFrame` 是 XML 期建的，apply 裡直接補一次
--     :474-495 `UpdateTimer` 每幀 `Timer.Fill:SetWidth`／`Show`／`Hide` —— `Fill` 不碰
--
------------------------------------------------------------
-- ## 時機：那個實作的「第一次 OnShow 才上皮」這裡照抄不了
--
-- 它的理由：**皮絕不能是觸發 ScrollBox 第一次排版的那一個** —— 它在載入期動了視窗的
-- 幾何（計時條與握把 `ClearAllPoints`／`SetPoint`／`SetSize`），污染了
-- `ScrollBox.updateLock`，之後每次 Update 都帶污染。所以它把整個上皮延到第一次 OnShow。
-- 我們：(a) 契約不准在暴雪框上 `HookScript("OnShow")`；(b) 我們**根本不動幾何**
-- （不重排、不量尺寸、不碰 ScrollBox 與 ScrollTarget），觸發不了它說的那條路。
-- ⇒ 照常在登入時套（戰鬥閘照走）。ScrollBox 只做唯讀的 `ForEachFrame` 補掃。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `NineSlice`、`Bg`（子框） | `SetAlpha(0)` |
-- | 視窗本身 | `Engine.RegionBackdrop`（面板底＋黑邊＋標題帶，建成**它自己的**貼圖） |
-- | `TitleContainer.TitleText` | `SetTextColor`（白；暴雪只 `SetText` 一次，InitRegions :416） |
-- | `ClosePanelButton` | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture`（`Skin.CloseButton`） |
-- | `EncounterDropdown` | `Background`／`Arrow` `SetAlpha(0)` ＋ ⌄ 圖記（`Skin.Dropdown`） |
-- | `ScrollBar` | `Skin.ScrollBar` |
-- | `Timer.Background`／`Timer.Border` | `SetAlpha(0)`；換成 `Timer` 自己的 `fillInset` 槽 ＋ 黑邊（`Engine.RegionBackdrop`） |
-- | `ResizeButton` 的無名貼圖 | `SetDesaturated(true)`（`Engine.Desaturate`）＋ `SetVertexColor(textDim)` |
-- | 每一列 `BackgroundArtFrame.NameFrame`／`.BorderFrame` | `SetAlpha(0)`；換成 `BackgroundArtFrame` 自己的 `fillInset` 卡片 ＋ 黑邊 |
-- | 每一列 `Item` | `Skin.ItemButton`（圓角品質框 alpha 0、方框轉交品質色、裁邊、底） |
--
-- **讀了什麼**：parentKey；`GetRegions()`（找握把那張無名貼圖，讀結構）；
-- `Item.IconBorder` 的 `IsShown()`／`GetVertexColor()`（`Engine.PassBorderColor`，既有例外）；
-- ScrollBox 的 `ForEachFrame`（唯讀補掃）。**不讀** `dropInfo`／`encounterID`／`selectedEncounterID`。
--
-- **hook**：
-- | hook | 型別 | 內容 |
-- |---|---|---|
-- | `hooksecurefunc(LootHistoryElementMixin, "Init", …)` | mixin 後置勾（`Engine.HookRows`） | 第一次：中和列底、建卡片、`Skin.ItemButton`；每次：重裁圖示 |
-- | `SetItemButtonQuality`／`SetItemButtonTexture` | 全域後置勾（引擎既有，`Skin.ItemButton` 登記） | 轉交品質色 |
-- | 關閉鈕、下拉、捲軸箭頭的 `HookScript("OnEnter"/"OnLeave")` | 原語內建 | 只換我們自己 overlay 的顏色 |
-- **`HookScript("OnShow")`：0 支。** 在 `ScrollBox` 上 `hooksecurefunc(box, "Update")`：**0 支**
-- （那個實作這樣勾 —— 那是在暴雪框上寫欄位）。
--
-- ## 刻意不碰
-- * `ScrollBox`／`ScrollTarget`、列上的文字（`ItemName` 品質色、得主的職業色、「全部放棄」紅字）、
--   `PlayerRoll` 的你擲了什麼圖示、`WinningRollInfo.Check`、等待中的兩個點動畫。
-- * `Timer.Fill`（計時條的填充）：它是 Texture 不是 StatusBar，換材質不在白名單、
--   而暴雪每幀改它的寬度 ⇒ 保留原 atlas 與顏色。
-- * `PerfectAnimFrame` 的百點動畫特效（只換它那一列本體，跟一般列同一套）。
-- * 列的 `IconOverlay`（那個實作會讀材質名字、看到房屋木框才藏 —— 讀材質不准）。
--
-- ## 照抄不了的地方
-- * 標題置中重錨、計時條貼齊下拉寬度重錨、縮放握把往內拉 2px 並放大、握把自畫三條線
--   ＋ HookScript 提亮：全是重排／改尺寸／在暴雪按鈕上掛腳本 ⇒ 只剩握把去飽和染灰。
-- * 計時條填充換成平面色（`SetTexture(FLAT)` ＋ 職業色）⇒ 保留原圖。
-- * `HookShow` 延到第一次顯示、`hooksecurefunc(ScrollBox, "Update")` 補掃 ⇒ 改成
--   登入時套 ＋ mixin 後置勾（見上）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local KEY = "GroupLootHistoryFrame"
local ROW_KEY = KEY .. ".row"

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

local function Required(owner, key, label)
    local child = Optional(owner, key)
    if not child then E.Missing(label) end
    return child
end

------------------------------------------------------------
-- 池化列（`LootHistoryElementTemplate`）
------------------------------------------------------------
local function ApplyRow(row)
    local art = Optional(row, "BackgroundArtFrame")
    if art then
        E.NeutralizeKeys(art, { "NameFrame", "BorderFrame" }, ROW_KEY .. ".BackgroundArtFrame")
        -- 卡片建成 `BackgroundArtFrame` 自己的貼圖：它在列之下（frameLevel 400 < 500），
        -- 不是 layout host，而且 setAllPoints ⇒ 卡片就是整列的矩形
        local card = E.RegionBackdrop(art, { key = ROW_KEY .. ".card" })
        E.Paint(card, T.fillInset, T.border)
    end

    local item = Optional(row, "Item")
    if item then Skin.ItemButton(item, ROW_KEY .. ".Item") end
end

-- 每次 Init 都要重申：`Item.icon:SetTexture` 排在 `SetItemButtonQuality` 之後，裁邊被打回
local function ReapplyRow(row)
    local item = Optional(row, "Item")
    local icon = item and Optional(item, "icon")
    if icon then E.CropIcon(icon, ROW_KEY .. ".Item.icon") end
end

local function MatchRow(row)
    return Optional(row, "BackgroundArtFrame") ~= nil and Optional(row, "Item") ~= nil
end

local sweeper

local function InstallHooks()
    local mixin = _G.LootHistoryElementMixin
    if type(mixin) ~= "table" then
        E.Missing("LootHistoryElementMixin")
        return
    end
    sweeper = E.HookRows{
        key     = "LootHistoryElementMixin:Init",
        mixin   = mixin,
        method  = "Init",
        match   = MatchRow,
        apply   = ApplyRow,
        reapply = ReapplyRow,
    }
end

------------------------------------------------------------
-- 外框
------------------------------------------------------------
local function SkinTimer(f)
    local timer = Required(f, "Timer", KEY .. ".Timer")
    if not timer or not E.Usable(timer, KEY .. ".Timer") then return end
    E.NeutralizeKeys(timer, { "Background", "Border" }, KEY .. ".Timer")
    local slot = E.RegionBackdrop(timer, { key = KEY .. ".Timer" })
    E.Paint(slot, T.fillInset, T.border)
end

-- 縮放握把：一張無名貼圖（`lootroll-resizehandle`）。形狀留著（玩家要認得出「這裡可以拉」），
-- 只去飽和染成次要灰。
local function SkinResizeGrip(f)
    local rb = Optional(f, "ResizeButton")
    if not rb or not E.Usable(rb, KEY .. ".ResizeButton") then return end
    if type(rb.GetRegions) ~= "function" then return end
    local ok, regions = pcall(function() return { rb:GetRegions() } end)
    if not ok then return end
    for i, r in ipairs(regions) do
        if type(r) == "table" and type(r.GetObjectType) == "function" then
            local ok2, kind = pcall(r.GetObjectType, r)
            if ok2 and kind == "Texture" then
                local label = KEY .. ".ResizeButton.region" .. i
                E.Desaturate(r, label)
                E.VertexColor(r, T.textDim, label)
            end
        end
    end
end

local function Apply()
    local f = _G.GroupLootHistoryFrame
    if not f then
        E.Missing(KEY)
        return
    end
    if not E.Usable(f, KEY) then return end

    E.NeutralizeKeys(f, { "NineSlice", "Bg" }, KEY)
    Skin.Panel(f, KEY)
    Skin.TitleBar(f, KEY)

    local tc = Required(f, "TitleContainer", KEY .. ".TitleContainer")
    local title = tc and Required(tc, "TitleText", KEY .. ".TitleContainer.TitleText")
    if title then E.TextColor(title, T.text, KEY .. ".TitleContainer.TitleText") end

    local close = Required(f, "ClosePanelButton", KEY .. ".ClosePanelButton")
    if close then Skin.CloseButton(close, KEY .. ".ClosePanelButton") end

    local dd = Required(f, "EncounterDropdown", KEY .. ".EncounterDropdown")
    if dd then Skin.Dropdown(dd, KEY .. ".EncounterDropdown", "style1") end

    local bar = Required(f, "ScrollBar", KEY .. ".ScrollBar")
    if bar then Skin.ScrollBar(bar, KEY .. ".ScrollBar") end

    SkinTimer(f)
    SkinResizeGrip(f)

    -- 已經建好的列：`PerfectAnimFrame`（XML 期建的，mixin 後置勾追不上）＋ 萬一先開過的池化列
    if sweeper then
        local perfect = Optional(f, "PerfectAnimFrame")
        if perfect then sweeper(perfect) end
        local box = Optional(f, "ScrollBox")
        if box then E.SweepRows(box, KEY .. ".ScrollBox", sweeper) end
    end
end

E.Register{
    key   = "loothistory",
    title = L["Loot Rolls Window"],
    hooks = InstallHooks,
    apply = Apply,
}
