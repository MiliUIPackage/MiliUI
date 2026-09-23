------------------------------------------------------------
-- 配方：拾取通知（「你獲得」那種 AlertFrame 吐司）
--
-- 不是視窗：吐司是**物件池**借出來的（`AlertFrameQueueMixin:OnLoad` 的
-- `CreateFramePool("ContainedAlertFrame", UIParent, 模板)`），登入時沒有任何一個框可以掃。
-- 做法照「成熟同類實作」：**每次通知觸發時拿到那個框、冪等地重上皮**。
-- 浮在世界上方、彈出來看一眼 ⇒ **提示皮**（`T.tipFill` ＋ 1px 職業色邊，STYLE.md ①）。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_FrameXML/Mainline/AlertFrames.lua
--     :84-97   `AlertFrameQueueMixin:OnLoad` → 物件池（parent 是 UIParent，**不是** AlertFrame）
--     :166-191 `ShowAlert` → `setUpFunction(alertFrame, …)` → `GetAlertContainer():AddAlertFrame(alertFrame)`
--     :320-349 子系統是 `CreateFromMixins(AlertFrameQueueMixin)`、`setUpFunction` 是**當值傳進去的**
--              ⇒ 勾 mixin 表或勾全域 `LootWonAlertFrame_SetUp` 都追不上已經建好的子系統
--     :454-461 `AlertContainerMixin:AddAlertFrame(frame)` → SetParent／SetFrameStrata →
--              **`AlertFrame_ShowNewAlert(frame)`（全域名呼叫）**
--     :883-886 `AlertFrame_ShowNewAlert(frame)` → `frame:Show()` ＋ `AlertFrame_PlayAnimations`
--              ⇒ **所有吐司的共同出口，而且排在 setUp 之後**：這一支的後置勾拿得到「剛設定好」的框
--     :845-861 `AlertFrame_PlayIntroAnimation`：`animIn`（整框 alpha）、`glow.animIn`、`shine.animIn`
--   Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua:607-620
--     額外戰利品骰的兩個靜態框 `BonusRollLootWonFrame`／`BonusRollMoneyWonFrame` 也走
--     `AlertFrame:AddAlertFrame` ⇒ 同一個出口接得到
--   Blizzard_FrameXML/Mainline/AlertFrameSystems.xml
--     :842-895  `MoneyWonAlertFrameTemplate`（249x71）：`Background`（setAllPoints）／`Icon`（金幣 38）／
--               `IconBorder`（金圈）／`Label`（GameFontNormal）／`Amount`
--     :897-950  `HonorAwardedAlertFrameTemplate`：同一個形狀
--     :953-1083 `LootWonAlertFrameTemplate`（276x96）：`lootItem`（LootItemExtended）／`Background`／
--               `PvPBackground`／`RatedPvPBackground`／`BGAtlas`／`Label`／`ItemName`／`RollTypeIcon`／
--               `RollValue`／`glow`（ADD，自帶 alpha 動畫）／`shine`（ADD，alpha ＋ 平移動畫）
--     :1090-1259 `LootUpgradeFrameTemplate`（276x96）：`Background`／`BaseQualityBorder`／`Icon`（50）／
--               `UpgradeQualityBorder`／`BorderGlow`／`Arrow1..5`／`TitleText`／三條物品名／`Sheen`，
--               `animIn` 對上面一半的貼圖**逐張**跑 alpha 動畫（setToFinalAlpha）
--   Blizzard_FrameXML/Mainline/AlertFrameSystems.lua
--     :470-578 `LootWonAlertFrame_SetUp`：依情境 Show／Hide 四張底圖、`glow:SetAtlas`、
--              **`ItemName:SetVertexColor(品質色)`**、`lootItem:Init(...)`
--     :583-630 `LootUpgradeFrame_SetUp`：品質色走 `SetTextColor`（不是 vertex）、`Icon:SetTexture`、
--              兩張品質框與箭頭 `SetAtlas`
--   Blizzard_FrameXML/ItemDisplay.xml:3-140 ＋ ItemDisplay.lua:3-52  `LootItemExtended`：
--     `Icon`（52）／`IconBorder`（atlas 編碼品質，`SetAtlas` ＋ `SetShown`）／`IconBorderDropShadow`／
--     `IconOverlay`（艾澤萊／靈魂羈絆，資訊）／`SpecIcon`／`Count`；`Init` 每次 `Icon:SetTexture`
--
------------------------------------------------------------
-- ## 動畫會把 alpha 打回來 —— 用 vertex 的 alpha 中和
--
-- 那個實作說得對：`glow`／`shine`／升級吐司的品質框與箭頭都有**自己的 alpha 動畫**，
-- 每幀改區域 alpha，`SetAlpha(0)` 撐不過去。它的解法是 `SetAtlas("")`／`SetTexture("")`
-- （契約不准：中和一律 alpha、禁止 SetAtlas）。
-- 我們改走 **`SetVertexColor(1,1,1,0)`**：vertex 的 alpha 跟區域 alpha 是兩個獨立的乘數，
-- 動畫只驅動後者 ⇒ 撐得住，而且 `SetVertexColor` 在白名單內。暴雪對這幾張只
-- `SetAtlas`／`Show`（不重設 vertex color），但為了不賭，每次通知都重下一次。
--
-- ## 品質色（傳遞者）
--
-- 物品吐司的品質框是 atlas（名字編碼品質），沒有 vertex color 可讀；但 `ItemName`
-- 每次都被 `SetVertexColor(品質色)` ⇒ 用 `Engine.PassBorderColor` 原封不動轉交給方框。
-- （那個實作讀 `ItemName:GetTextColor()` 去畫左緣色條 —— 讀值，不准。）
-- 升級吐司的品質色走 `SetTextColor`（不是 vertex）⇒ 接不到，方框維持黑邊。金錢吐司沒有品質。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | 吐司本身 | `Engine.RegionBackdrop`（提示皮底＋職業色邊，建成**它自己的**貼圖；矩形從 XML 抄內縮值） |
-- | 各種底圖（`Background`／`PvPBackground`／`RatedPvPBackground`／`BGAtlas`）、金錢吐司的 `IconBorder`、`lootItem.IconBorder`／`IconBorderDropShadow` | `SetAlpha(0)` |
-- | `glow`／`shine`；升級吐司的 `BaseQualityBorder`／`UpgradeQualityBorder`／`BorderGlow`／`Sheen`／`Arrow1..5` | `SetVertexColor(1,1,1,0)`（每次通知重下） |
-- | `lootItem.Icon`／`Icon` | `SetTexCoord`（裁邊，每次通知重下） |
-- | `lootItem`／吐司 | 以它為 parent 建前景子框（1px 方框，不吃滑鼠） |
-- | `Label`（「你獲得」） | `SetTextColor(textDim)`（欄位標籤；暴雪只 `SetText`／`SetPoint`） |
--
-- **讀了什麼**：parentKey（認形狀：有 `lootItem`＋`ItemName` ＝物品；有 `BaseQualityBorder` ＝升級；
-- 有 `Amount`＋`IconBorder` ＝金錢／榮譽）；`ItemName` 的 `IsShown()`／`GetVertexColor()`
-- （只經 `Engine.PassBorderColor`）。**不讀** `hyperlink`／`isCurrency`／`queue`／任何暴雪欄位、
-- 不讀文字、不讀尺寸。形狀不符的吐司（成就、好友上線、要塞…）**直接返回**。
--
-- **hook**：`hooksecurefunc("AlertFrame_ShowNewAlert", …)` ×1（全域函式後置勾）。
-- 內容只有「把參數那個框放進我們自己的弱鍵表 ＋ `C_Timer.After(0, …)`」——
-- 上皮跑在下一幀，不在 AlertFrame 的顯示流程裡。
-- **在 `AlertFrame`／子系統／物件池／任何吐司上寫欄位：0 個**；勾 mixin 表：0 支；
-- `HookScript`：0 支；自建事件框：0 個。
--
-- ## 刻意不碰
-- * `AlertFrame` 容器、子系統、物件池、錨點（`AdjustAnchors` 每次重排）。
-- * 文字顏色（`ItemName` 品質色、`Amount`、`RollValue` 綠字、升級吐司的三條名字）、
--   `RollTypeIcon`（骰子／硬幣）、`SpecIcon`、`IconOverlay`（艾澤萊／靈魂羈絆框是資訊）、`Count`。
-- * 其他種類的吐司（成就、坐騎、寵物、要塞、好友上線…）。
--
-- ## 照抄不了的地方
-- * **量金錢吐司的尺寸、存進 SV、把物品吐司縮成同樣大小並重錨圖示／名稱／標題**
--   （`GetHeight`／`GetLeft`／`GetCenter`、`SetHeight`／`SetWidth`／`SetSize`／`ClearAllPoints`／`SetPoint`）
--   ⇒ 只重畫不重排：物品吐司維持暴雪原本的大小，我們的底用 XML 的內縮值貼齊原圖的可見範圍。
-- * 玩家可調的吐司縮放（`SetScale`）⇒ 不做。
-- * 左緣的品質色條（讀 `GetTextColor`、讀 `GetRect` 做像素對齊）⇒ 改成圖示方框轉交品質色。
-- * 裝飾貼圖 `SetAtlas("")`／`SetTexture("")` ⇒ 改成 alpha／vertex alpha 中和（見上）。
-- * 掃 `UIParent` 所有子框找匿名吐司、`alertFrameSubSystems[i].alertFramePool:EnumerateActive()`
--   ⇒ 不需要：全域出口的參數就是那個框（而且那是讀暴雪欄位）。
-- * 聽七個 SHOW_LOOT_TOAST 類事件、0.05／0.2／0.5 秒補掃 ⇒ 不需要：後置勾排在 setUp 之後。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local TRANSPARENT = { 0, 0, 0, 0 }
local VERTEX_HIDDEN = { 1, 1, 1, 0 }

-- 提示皮底的矩形：原圖四周是透明的暈光，框的矩形比看得到的吐司大一圈。
-- 內縮值從 XML 的內容位置抄（不量測）：
--   物品／升級（276x96）：`lootItem` 在 x=22,y=-23、52 見方；`RollTypeIcon` 右緣在 x=256
--     ⇒ 左右各 10、上下各 12（圖示外留 12／標題上留 6／圖示下留 9）
--   金錢／榮譽（249x71）：`Icon` 在 LEFT x=16、38 見方 ⇒ 四邊各 8
local INSET = {
    item    = { 10, 12 },
    upgrade = { 10, 12 },
    money   = { 8, 8 },
}

local ITEM_BG = { "Background", "PvPBackground", "RatedPvPBackground", "BGAtlas" }
local ITEM_FX = { "glow", "shine" }
local UPGRADE_FX = {
    "BaseQualityBorder", "UpgradeQualityBorder", "BorderGlow", "Sheen",
    "Arrow1", "Arrow2", "Arrow3", "Arrow4", "Arrow5",
}

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

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

-- 認形狀（只看 parentKey 在不在）。回 nil ＝不是拾取吐司，不碰。
local function KindOf(t)
    if Optional(t, "lootItem") and Optional(t, "ItemName") then return "item" end
    if Optional(t, "BaseQualityBorder") and Optional(t, "UpgradeQualityBorder") then return "upgrade" end
    if Optional(t, "Amount") and Optional(t, "IconBorder") and Optional(t, "Icon") then return "money" end
    return nil
end

local function HideByVertex(owner, keys, prefix)
    for _, k in ipairs(keys) do
        local tex = Optional(owner, k)
        if tex then E.VertexColor(tex, VERTEX_HIDDEN, prefix .. "." .. k) end
    end
end

local skinned = setmetatable({}, { __mode = "k" })   -- 我們自己的表，不寫在吐司上

local function FirstTime(t, kind, key)
    local inset = INSET[kind]
    local bg = E.RegionBackdrop(t, {
        key = key,
        points = {
            { "TOPLEFT", "TOPLEFT", inset[1], -inset[2] },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", -inset[1], inset[2] },
        },
    })
    E.Paint(bg, T.tipFill, { T.Accent() })

    local label = Optional(t, "Label")
    if label then E.TextColor(label, T.textDim, key .. ".Label") end

    if kind == "item" then
        E.NeutralizeKeys(t, ITEM_BG, key)
        local li = Optional(t, "lootItem")
        if li then
            E.NeutralizeKeys(li, { "IconBorder", "IconBorderDropShadow" }, key .. ".lootItem")
            local q = E.Overlay(li, {
                key = key .. ".lootItem.quality",
                levelOffset = 1,
                borderSize = T.itemBorderSize,
            })
            E.Paint(q, TRANSPARENT, T.border)
        end
    elseif kind == "upgrade" then
        E.NeutralizeKeys(t, { "Background" }, key)
        local icon = Optional(t, "Icon")
        if icon then Skin.Icon(icon, key .. ".Icon") end
    else -- money
        E.NeutralizeKeys(t, { "Background", "IconBorder" }, key)
        local icon = Optional(t, "Icon")
        if icon then Skin.Icon(icon, key .. ".Icon") end
    end
end

-- 每次通知都要重申的（池化框換了內容、動畫會重跑）
local function EveryTime(t, kind, key)
    if kind == "item" then
        HideByVertex(t, ITEM_FX, key)
        local li = Optional(t, "lootItem")
        if li then
            local icon = Optional(li, "Icon")
            if icon then E.CropIcon(icon, key .. ".lootItem.Icon") end
            local q = E.GetOverlay(li, "front")
            if q then E.PassBorderColor(q, Optional(t, "ItemName")) end
        end
    elseif kind == "upgrade" then
        HideByVertex(t, UPGRADE_FX, key)
        local icon = Optional(t, "Icon")
        if icon then E.CropIcon(icon, key .. ".Icon") end
    else
        local icon = Optional(t, "Icon")
        if icon then E.CropIcon(icon, key .. ".Icon") end
    end
end

local function SkinToast(t)
    if type(t) ~= "table" then return end
    local kind = KindOf(t)
    if not kind then return end
    local key = "LootToast." .. kind
    if not E.Usable(t, key) then return end
    if not skinned[t] then
        skinned[t] = true
        FirstTime(t, kind, key)
    end
    EveryTime(t, kind, key)
end

------------------------------------------------------------
-- 下一幀才上皮：後置勾裡只記下框
------------------------------------------------------------
local pending = setmetatable({}, { __mode = "k" })
local scheduled = false

local flush = Guard("AlertFrame_ShowNewAlert", function()
    scheduled = false
    for t in pairs(pending) do
        pending[t] = nil
        SkinToast(t)
    end
end)

local function InstallHooks()
    if type(_G.AlertFrame_ShowNewAlert) ~= "function" then
        E.Missing("AlertFrame_ShowNewAlert")
        return
    end
    hooksecurefunc("AlertFrame_ShowNewAlert", function(frame)
        if type(frame) ~= "table" then return end
        pending[frame] = true
        if not scheduled then
            scheduled = true
            C_Timer.After(0, flush)
        end
    end)
end

E.Register{
    key   = "loottoast",
    title = L["Loot Toasts"],
    hooks = InstallHooks,
}
