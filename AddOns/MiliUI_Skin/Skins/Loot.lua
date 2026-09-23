------------------------------------------------------------
-- 配方：戰利品視窗（`LootFrame`，常駐的 `Blizzard_UIPanels_Game`）
--
-- 12.1 的拾取視窗是新式的「物品卡」清單：`ScrollingFlatPanelTemplate` 的面板 ＋ 一個
-- `WowScrollBoxList`，每一列是池化的卡片。它同時是**編輯模式系統**（可以拖位置）。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_UIPanels_Game/Mainline/LootFrame.xml
--     :113  `LootFrame` ← `ScrollingFlatPanelTemplate, EditModeLootFrameSystemTemplate`（HIGH strata、toplevel）
--     :7-69 `LootFrameElementTemplate`：`Item`（ItemButton，useParentLevel，HitRect 往右延伸 157
--           ⇒ 整列都是那顆按鈕的點擊區）、`NameFrame`（`looting_itemcard_bg`，每次 Init 染品質色）、
--           `BorderFrame`（`looting_itemcard_stroke_normal`）、`IconQuestTexture`、
--           `HighlightNameFrame`／`PushedNameFrame`（`looting_itemcard_stroke_clickstate`，Lua 只 Show／Hide）
--     :71-95 `LootFrameItemElementTemplate`：`QualityStripe`（稀有度標籤底）、`QualityText`、`Text`
--     :97   `LootFrameMoneyElementTemplate`（mixin 直接是 `LootFrameElementMixin`）
--   Blizzard_UIPanels_Game/Mainline/ScrollingFlatPanel.xml:3
--     `ScrollingFlatPanelTemplate` ← `DefaultPanelFlatTemplate`（SharedUIPanelTemplates.xml:527：
--     `Bg` 是 FlatPanelBackgroundTemplate **子框**、`NineSlice`、`TitleContainer.TitleText`）＋
--     `ClosePanelButton`（UIPanelCloseButtonDefaultAnchors）＋ `ScrollBox` ＋ `ScrollBar`（MinimalScrollBar）
--   Blizzard_UIPanels_Game/Mainline/LootFrame.lua
--     :35-58 Initializer：`frame:Init()` 之後 `frame.Item:SetScript("OnClick", …LootSlot…)` ——
--            **點擊拾取的整條路**（在 Init 之後、跟我們的後置勾無關）
--     :262-319 `LootFrameElementMixin:Init`：`Text`／`NameFrame` `SetVertexColor(品質色)`、
--            全域 `SetItemButtonQuality(self.Item, …)`，**之後才** `self.Item.icon:SetTexture(...)`
--            ⇒ 圖示裁邊一定要在 Init 跑完之後重下（reapply）
--     :335-340 `LootFrameItemElementMixin:Init` 明碼呼叫 `LootFrameElementMixin.Init(self)`（全域表查詢）
--            ⇒ 勾 `LootFrameElementMixin.Init` 物品列與金錢列都接得到；列是第一次拾取才建的
--            （晚於登入時裝 hook），金錢列建框時拷貝到的就是包過的那一支
--     :124-132 `LOOT_SLOT_CHANGED` → `frame:Init()`（同一支，reapply 照樣跑）
--
------------------------------------------------------------
-- ## 風險判斷（任務要求：查下來風險太高就不做）
--
-- 結論：**可以做，範圍收在「純貼圖＋一支 mixin 後置勾」**。
-- * 點擊拾取的路徑（`Item` 的 OnClick → `LootSlot`）上**沒有我們的 Lua**：我們不掛任何腳本在列
--   或 `Item` 上（連 OnEnter／OnLeave 都沒有），`Init` 的後置勾跑在「借出列／格子內容變了」的時候，
--   不在點擊派送裡。`LootSlot` 本身不是保護函式。
-- * 編輯模式：我們不碰它的選取框、不讀／不寫位置，只在 `LootFrame` 身上建自己的 BACKGROUND 貼圖。
-- * `GroupLootContainer`（骰裝框）是 C 級，不在這份配方裡。
-- * 秘密值：不讀 elementData、不讀 `GetLootSlotInfo`，品質色走 `IconBorder` 的轉交。
--
------------------------------------------------------------
-- ## 做法對照成熟同類實作（第十三輪：範圍照抄、外觀用我們的）
--
-- 它做的、我們照做：外框換皮（NineSlice、`Bg`、視窗自己的 region）、標題改白、關閉鈕
-- （`ClosePanelButton` —— 它特別註明新模板的 × 叫這個名字）、捲軸、每一列：`NameFrame`
-- 卡片底拿掉、`BorderFrame`／`HighlightNameFrame`／`PushedNameFrame` 三條卡片描邊拿掉、
-- 物品格的 `NormalTexture` 拿掉、圖示裁成方形、**1px 品質色邊（顏色取自暴雪自己的 IconBorder）**、
-- **名字與稀有度文字的品質色一律不動**、疊數字體不動。
--
-- 外觀：浮在世界上方、撿完就關 ⇒ **提示皮**（STYLE.md ①；`T.tipFill` ＋ 1px 職業色邊，
-- 同確認彈窗）。它那邊用的是一般視窗殼。
--
-- **照抄不了的地方（契約）：**
-- * 列的滑過：它把 `Item` 的 HighlightTexture **重錨到整列**、改成平面白 8%、
--   並在那張貼圖上 `hooksecurefunc(hl, "SetAtlas"/"SetTexture")` 重申 —— 重錨與勾實例都不准。
--   我們只把 Highlight 換成白 8%（`Engine.ButtonStates`，C 端依滑鼠顯示）⇒ **滑過回饋只在圖示那一格**。
-- * 圖示裁邊：它在每一張 icon 上 `hooksecurefunc(icon, "SetTexture")` —— 改成 mixin `Init` 後置勾的 reapply。
-- * 它把捲動框往下挪 5（`ClearAllPoints`／`SetPoint`）、把卡片描邊 `SetAtlas("")` 清空 —— 不重排；
--   描邊只 `SetAlpha(0)`（12.1 的 Lua 對那三張只 Show／Hide，不動 alpha，撐得住）。
-- * 它重設列上所有文字的字型（`SetFont`）—— 字型不在白名單，不做。
-- * 它 `hooksecurefunc(ScrollBox, "Update")` ＋ `HookScript("OnShow")` 每次重掃 —— 改成 `Engine.HookRows`
--   勾 mixin 表 ＋ apply 時 `SweepRows` 補掃。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `LootFrame.NineSlice`、`LootFrame.Bg`（子框，純美術容器） | `SetAlpha(0)` |
-- | `LootFrame` 自己的 region | `SetAlpha(0)`（`GetRegions`；我們的貼圖除外） |
-- | `LootFrame` 本身 | `Engine.RegionBackdrop`（`tipFill` 底 ＋ 1px 職業色邊，建成它自己的 BACKGROUND 貼圖） |
-- | `TitleContainer.TitleText` | `SetTextColor` |
-- | `ClosePanelButton` | 同 `Skin.CloseButton` |
-- | `ScrollBar` | 同 `Skin.ScrollBar` |
-- | 每一列（池化）的 `NameFrame`／`BorderFrame`／`HighlightNameFrame`／`PushedNameFrame` | `SetAlpha(0)` |
-- | 每一列的 `Item` | IconBorder／NormalTexture `SetAlpha(0)`、icon `SetTexCoord`、Highlight `SetColorTexture`、IconBorder `IsShown()`／`GetVertexColor()`（**只轉交**）（`Skin.ItemButton`，`noFill`） |
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc(LootFrameElementMixin, "Init", …)` | mixin 後置勾（`Engine.HookRows`） | 第一次見到：中和四張卡片美術 ＋ `Skin.ItemButton`；每次：`Skin.ItemButtonRefresh`（重下 IconBorder 的 alpha、轉交品質色、重裁圖示）。**不讀 elementData** |
-- | 引擎的 `SetItemButtonQuality`／`SetItemButtonTexture` 全域後置勾 | 既有 | 第一行查弱鍵表 |
-- | 關閉鈕、捲軸箭頭的 `HookScript("OnEnter"/"OnLeave")` | 原語內建 | 只換我們自己 overlay 的顏色 |
--
-- **列與 `Item` 上的 `HookScript`：0 支。`HookScript("OnShow")`：0 支。寫入暴雪欄位：無。**
--
-- ## 刻意不碰的東西
-- * `Text`、`QualityText` 的品質色、`QualityStripe`（稀有度標籤底）、`IconQuestTexture`（任務物品標記）、
--   `Item.Count`、上鎖時暴雪染在圖示上的紅色。
-- * 編輯模式的選取框、`ScrollBox` 的上下陰影、面板的開關動畫。
-- * 骰裝框 `GroupLootContainer`／`GroupLootFrame*`（C 級）、拾取提示 toast。
-- * 套組裡 `KeystoneLoot`／`AppearanceTooltip` 在列上畫自己的標記（它們掛 ScrollBox 的 callback），各畫各的；
--   `Plumber` 的拾取介面開著時暴雪這個視窗根本不會開，我們的皮沒有作用也沒有副作用。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

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

local ROW_ART = { "NameFrame", "BorderFrame", "HighlightNameFrame", "PushedNameFrame" }
local ROW_KEY = "LootFrame.row"

local function ApplyRow(row)
    E.NeutralizeKeys(row, ROW_ART, ROW_KEY)
    local item = Optional(row, "Item")
    if item then
        -- `noFill`：圖示鋪滿整格，底永遠看不到，省一個子框
        Skin.ItemButton(item, ROW_KEY .. ".Item", { noFill = true })
    else
        E.Missing(ROW_KEY .. ".Item")
    end
end

-- Init 最後才 `icon:SetTexture` ⇒ 裁邊、品質色都在這裡重下
local function ReapplyRow(row)
    local item = Optional(row, "Item")
    if item then Skin.ItemButtonRefresh(item, ROW_KEY .. ".Item") end
end

local rowSweep

local function InstallHooks()
    rowSweep = E.HookRows{
        key     = "LootFrameElement",
        mixin   = _G.LootFrameElementMixin,
        method  = "Init",
        match   = function(row)
            return type(row) == "table" and row.Item ~= nil and row.NameFrame ~= nil
        end,
        apply   = ApplyRow,
        reapply = ReapplyRow,
    }
end

local FRAME_ART = { "NineSlice", "Bg" }

local function Apply()
    local f = _G.LootFrame
    if not f then
        E.Missing("LootFrame")
        return
    end
    local key = "LootFrame"
    if not E.Usable(f, key) then return end

    E.NeutralizeKeys(f, FRAME_ART, key)
    E.NeutralizeRegions(f, key)       -- 視窗自己的 region（我們的貼圖由 ownRegions 排除）

    -- 提示皮：`tipFill` ＋ 1px 職業色邊
    local ov = E.RegionBackdrop(f, { key = key })
    E.Paint(ov, T.tipFill, { T.Accent() })

    local tc = Optional(f, "TitleContainer")
    local title = tc and Optional(tc, "TitleText")
    if title then E.TextColor(title, T.text, key .. ".TitleContainer.TitleText") else E.Missing(key .. ".TitleText") end

    local close = Required(f, "ClosePanelButton", key .. ".ClosePanelButton")
    if close then Skin.CloseButton(close, key .. ".ClosePanelButton") end

    local bar = Required(f, "ScrollBar", key .. ".ScrollBar")
    if bar then Skin.ScrollBar(bar, key .. ".ScrollBar") end

    -- 保險：hook 沒趕上的列（正常情況登入時一列都還沒建）
    local box = Optional(f, "ScrollBox")
    if box then E.SweepRows(box, key .. ".ScrollBox", rowSweep) end
end

E.Register{
    key   = "loot",
    addon = nil,                 -- Blizzard_UIPanels_Game 是 LoadFirst
    title = L["Loot Window"],
    hooks = InstallHooks,
    apply = Apply,
}
