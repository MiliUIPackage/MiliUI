------------------------------------------------------------
-- 配方：物品互動視窗（催化器／物品轉換，`ItemInteractionFrame`，隨需載入
--       `Blizzard_ItemInteractionUI`）
--
-- 同一個框服務好幾種互動（催化器轉換套裝外觀、淨化腐化…），長相由伺服器給的
-- `textureKit` 決定；標題、按鈕文字、說明也都是伺服器資料。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_ItemInteractionUI/Blizzard_ItemInteractionUI.xml
--     :5    `ItemInteractionFrame` ← `PortraitFrameTemplate`（toplevel）⇒ NineSlice／Bg／
--           TopTileStreaks／PortraitContainer／TitleContainer／`CloseButton`
--     :10   `Background`（BACKGROUND -4，**textureKit 場景圖**，位置由 Lua 決定）
--     :13   `Description`（GameFontHighlight；顏色由 Lua 依狀態重設，見下）
--     :29   `Inset`（InsetFrameTemplate，依互動類型 `SetShown`）
--     :40-83 `CurrencyCost`（`Costs` 標籤 GameFontNormal ＋ `Currency` 通貨鈕）
--     :84   `ItemSlot`、:110 `ItemConversionFrame`（輸入／輸出兩顆物品格、箭頭、慶祝閃光）
--     :270-348 `ButtonFrame`（高 35 的底部列）：`ActionButton`（MagicButtonTemplate ←
--           UIPanelButtonTemplate，mixin `ItemInteractionActionButtonMixin`）、`Currency`、
--           `MoneyFrame`、`MoneyFrameEdge`（ThinGoldEdgeTemplate，三張 `$parent*` 貼圖 ——
--           父框無名 ⇒ 只能 `GetRegions`）、`BlackBorder`／`ButtonBorder`／`ButtonBottomBorder`
--   Blizzard_ItemInteractionUI.lua
--     :262-320 `LoadInteractionFrameData`（每次 `OnShow`）：`SetTitle`、`SetupTextureKitOnFrames`
--             換 `Background` 的 atlas（`SetVisibility` ⇒ 只 `SetShown`）、`Inset:SetShown`、
--             `self:SetSize(...)`、`UpdateDescriptionColor`
--     :393-410 `UpdateDescriptionColor`：`Description:SetTextColor(紅／停用灰／NORMAL)` —— **資訊**
--     :425-431 `UpdateCostFrame`：`BlackBorder:SetShown`、`MoneyFrameEdge:SetShown`
--     :853-855 `ActionButton:OnClick` → `InteractWithItem`（花通貨／金幣、改變物品）
--
------------------------------------------------------------
-- ## 做法對照成熟同類實作（第十三輪：範圍照抄、外觀用我們的）
--
-- 它做的、我們照做：外框換皮（**連 `Background` 場景圖一起拿掉** —— 它的 shell 會把視窗
-- 自己的 region 全部淡掉）、頭像拿掉、NineSlice／Bg、Inset、關閉鈕、底部列的三張裝飾
-- （`BlackBorder`／`ButtonBorder`／`ButtonBottomBorder`）、金額框的金邊（`MoneyFrameEdge`
-- 的 region 全部淡掉）、動作鈕換長相。它的註解：**「物品格維持原樣 —— 輸入格那個綠色 ＋ 就是
-- 它的 NormalAtlas」**，我們一樣不碰三顆物品格。
--
-- **照抄不了的地方（契約）：**
-- * `Description` 改白：暴雪每次 `LoadInteractionFrameData`／放入物品／次數變動都會
--   `SetTextColor` 重設（紅＝次數不夠、灰＝還沒放物品）—— 那是資訊，而唯一的重設點是
--   **這個框實例的方法**（mixin 在建框時就拷貝走了，勾 mixin 表追不上，勾實例＝寫欄位）
--   ⇒ 不碰，維持暴雪的顏色。它那邊只設一次，下一次更新就被暴雪蓋回去了，實際效果跟我們一樣。
-- * 它每次顯示都 `HookScript("OnShow")` 重掃 —— 我們的中和全是 alpha，暴雪對那些區域只
--   `SetShown`／換 atlas，不動 alpha ⇒ 套一次就夠，**零 hook**。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `ItemInteractionFrame` 的 NineSlice／Bg／TopTileStreaks／PortraitContainer | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `ItemInteractionFrame.Background` | `SetAlpha(0)` |
-- | `ItemInteractionFrame` 本身 | `Engine.RegionBackdrop`（底＋邊＋標題帶；視窗會被 `SetSize`，貼圖錨點跟著走） |
-- | `TitleContainer.TitleText` | `SetTextColor` |
-- | `Inset` 的 Bg／NineSlice | `SetAlpha(0)` ＋ `fillInset` 貼圖（`Skin.Inset`） |
-- | `CloseButton` | 同 `Skin.CloseButton` |
-- | `CurrencyCost.Costs`（「花費：」標籤） | `SetTextColor(textDim)` |
-- | `ButtonFrame.BlackBorder`／`ButtonBorder`／`ButtonBottomBorder` | `SetAlpha(0)` |
-- | `ButtonFrame.MoneyFrameEdge` 的三張金邊 | `SetAlpha(0)`（`GetRegions`） |
-- | **零腳本**：`ButtonFrame.ActionButton`（primary） | Left／Right／Middle `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`（＋ `SetDisabledTexture` 一張白貼圖）。**零 HookScript** |
--
-- **hook：0 支 `hooksecurefunc`、0 支 `HookScript("OnShow")`。** 只有原語內建的
-- `HookScript("OnEnter"/"OnLeave")`（關閉鈕）。**讀取：只有 parentKey 與 `GetRegions`。寫入暴雪欄位：無。**
--
-- ## 刻意不碰的東西
-- * `ItemSlot`、`ItemConversionFrame`（輸入／輸出物品格、箭頭、閃光動畫）——
--   放物品／拿物品的點擊路徑，也是 textureKit 的內容美術。
-- * `Description` 的顏色（見上）、`DescriptionCurrencies`、兩顆通貨鈕、`MoneyFrame` 的數字與顏色
--   （金錢不夠時暴雪會染紅）。
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

-- TODO(升格): 同 `Skins/PlayerSpells.lua` 的 local `ScriptlessButton`
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)
    return ov
end

local BUTTON_FRAME_ART = { "BlackBorder", "ButtonBorder", "ButtonBottomBorder" }

local function Apply()
    local f = _G.ItemInteractionFrame
    if not f then
        E.Missing("ItemInteractionFrame")
        return
    end
    local key = "ItemInteractionFrame"
    if not E.Usable(f, key) then return end

    Skin.PortraitChrome(f, key)
    E.NeutralizeKeys(f, { "Background" }, key)
    Skin.Panel(f, key)

    local inset = Required(f, "Inset", key .. ".Inset")
    if inset then Skin.Inset(inset, key .. ".Inset") end

    local close = Required(f, "CloseButton", key .. ".CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end

    local cost = Optional(f, "CurrencyCost")
    local costs = cost and Optional(cost, "Costs")
    if costs then E.TextColor(costs, T.textDim, key .. ".CurrencyCost.Costs") end

    local bf = Required(f, "ButtonFrame", key .. ".ButtonFrame")
    if not bf then return end
    local bkey = key .. ".ButtonFrame"
    E.NeutralizeKeys(bf, BUTTON_FRAME_ART, bkey)

    local edge = Optional(bf, "MoneyFrameEdge")
    if edge then E.NeutralizeRegions(edge, bkey .. ".MoneyFrameEdge") end

    -- 動作鈕：花通貨／金幣、改變物品 ⇒ 零腳本；這個視窗唯一的動作 ⇒ primary。
    -- 暴雪依「有沒有放物品／錢夠不夠」停用它 ⇒ 補的 DisabledTexture 蓋上中性底。
    local action = Required(bf, "ActionButton", bkey .. ".ActionButton")
    if action then ScriptlessButton(action, bkey .. ".ActionButton", "primary") end
end

E.Register{
    key   = "iteminteraction",
    addon = "Blizzard_ItemInteractionUI",
    title = L["Catalyst & Item Conversion"],
    apply = Apply,
}
