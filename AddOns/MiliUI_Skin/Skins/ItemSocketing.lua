------------------------------------------------------------
-- 配方：物品插入（寶石插槽，`ItemSocketingFrame`，隨需載入 `Blizzard_ItemSocketingUI`）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_ItemSocketingUI/Blizzard_ItemSocketingUI.xml
--     :143  `ItemSocketingFrame` ← `ButtonFrameTemplate`（toplevel）⇒ `Inset`、`CloseButton`、
--           `TitleContainer`（空的；真正的標題是 :146 那條**無名** FontString，GameFontNormal）
--     :152-281 ARTWORK 層的框美術（全部 parentKey，名字裡帶減號）：
--           `ParchmentFrame-{Top,Bottom,Left,Right}`、`SocketFrame-{Left,Right}`、
--           `ButtonFrame-{Left,Right}`、`ButtonBorder-Mid`、`GoldBorder-*`（八張）
--     :282-388 BORDER 層：`BackgroundColor`、`BackgroundHighlight`、`BorderShadow-*`（八張）、
--           六顆 `*Nub`
--     :391  `ScrollFrame`（`ItemSocketingScrollFrame`，ScrollFrameTemplate ⇒ `.ScrollBar` 是
--           `ScrollFrame_OnLoad` 建的 MinimalScrollBar，Blizzard_SharedXML/SecureUIPanelTemplates.lua:23）
--           裡面是內嵌的 `ItemSocketingDescription`（GameTooltipTemplate，IsEmbedded）
--     :419  `SocketingContainer` ← `GenericItemSocketingFrameTemplate`（:98）：
--           `Socket1..3`（`GenericSocketButtonTemplate`，:10：`LeftFiligree`／`RightFiligree`
--           雕花、一張無名的插槽圓環、`Background`（寶石顏色）、`Icon`、`Shine`、`BracketFrame`）、
--           `ApplySocketsButton`（UIPanelButtonNoTooltipTemplate ＋ UIButtonTemplate）
--   Blizzard_ItemSocketingUI.lua
--     :40-41  `OnLoad` 自己把「套用」重錨到視窗右下角
--     :222-338 `GenericItemSocketingFrameMixin:Update`：插槽依寶石顏色 `SetupTextureKitOnFrame`
--             換 `Background`／括號的 atlas、`SetDesaturated`；雕花只 `SetShown`（:324-330）
--             ⇒ **alpha 中和撐得住**；插槽用 `SetItemButtonTexture` 換圖示
--     :151-162 「套用」＝ `C_ItemSocketInfo.AcceptSockets()`（或跳確認彈窗）—— 消耗寶石、改裝備
--
------------------------------------------------------------
-- ## 做法對照成熟同類實作（第十三輪：範圍照抄、外觀用我們的）
--
-- 它做的、我們照做：外框換皮（整個視窗自己的美術全部中和）、頭像拿掉、Inset、關閉鈕、
-- 捲軸換細條、「套用」換長相、插槽兩側的雕花**每種狀態都拿掉**、插槽的閃光子框（`Shine`）
-- 淡掉、插槽本體的「圖示／圓環／括號」**整組保留**（寶石顏色與開合是資訊）。
--
-- **照抄不了的地方（契約）：**
-- * 它把視窗縮小 40x80、重排捲軸區與插槽列、把捲軸往右挪 15（`SetSize`／`ClearAllPoints`／
--   `SetPoint`，而且要在 `ItemSocketingFrame_Update` 後置勾裡**同步**重排）—— 只重畫不重排，不做。
-- * 它用「材質名稱含 lock」判斷上鎖的插槽（`GetAtlas`／`GetTexture` 讀回）、用幾何量測找突出的雕花
--   （`GetLeft`／`GetRight`）—— 讀回材質與讀尺寸都不准。我們改用 parentKey 指名雕花，
--   而 12.1 的模板裡沒有上鎖插槽的專用區域，不需要那個判斷。
-- * 它的捲軸拇指換 `SetTexture(白)`＋`SetWidth(4)` —— 走我們的 `Skin.ScrollBar`（只 alpha／vertex color）。
-- * 它每次顯示都 `HookScript("OnShow")` ＋ `hooksecurefunc("ItemSocketingFrame_Update")` 重掃 ——
--   我們的中和全是 alpha（暴雪只 `SetShown`／換 atlas，不動 alpha）⇒ 套一次就夠，**零 hook**。
-- * 它的全視窗關鍵字掃描會連插槽的 `Background`（`socket-<顏色>-background`）一起淡掉 ——
--   那是「這個孔要什麼顏色的寶石」，**資訊，保留**（STYLE.md ④「顏色本身帶資訊的一律不動」）。
-- * 它替插槽加自己的發光 —— 不是我們的語彙，不做。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `ItemSocketingFrame` 的 NineSlice／Bg／TopTileStreaks／PortraitContainer | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `ItemSocketingFrame` 本身 | `Engine.RegionBackdrop`（底＋邊＋標題帶） |
-- | 上面列的 ARTWORK／BORDER 層框美術（33 張） | `SetAlpha(0)` |
-- | 無名標題 FontString | `SetTextColor`（`Engine.RecolorRegions`，只掃視窗自己的 region） |
-- | `Inset` 的 Bg／NineSlice | `SetAlpha(0)` ＋ `fillInset` 貼圖（`Skin.Inset`） |
-- | `CloseButton` | 同 `Skin.CloseButton` |
-- | `ScrollFrame.ScrollBar` | Track／Thumb／Back／Forward `SetAlpha(0)`／`SetVertexColor`（`Skin.ScrollBar`） |
-- | `Socket1..3` 的 `LeftFiligree`／`RightFiligree` | `SetAlpha(0)` |
-- | `Socket1..3.Shine`（AnimatedShineTemplate，純動畫美術容器） | 框 `SetAlpha(0)` |
-- | **零腳本**：`ApplySocketsButton`（primary） | Left／Right／Middle `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`（＋ `SetDisabledTexture` 一張白貼圖）。**零 HookScript** |
--
-- **hook：0 支 `hooksecurefunc`、0 支 `HookScript("OnShow")`。** 只有原語內建的
-- `HookScript("OnEnter"/"OnLeave")`（關閉鈕、捲軸箭頭），內容只換我們自己 overlay 的顏色。
-- **讀取：只有 parentKey 與 `GetRegions`（找無名標題）。寫入暴雪欄位：無。**
--
-- ## 刻意不碰的東西
-- * 插槽的 `Icon`、`Background`（寶石顏色）、無名插槽圓環、`BracketFrame`（開／合括號、色盲文字）、
--   插槽按鈕的所有腳本（點擊＝放寶石／取寶石）。
-- * 內嵌的物品說明 `ItemSocketingDescription`（tooltip 的內容與顏色）。
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

-- 視窗自己那一整套羊皮紙／金框／陰影（Blizzard_ItemSocketingUI.xml:152-388）
local FRAME_ART = {
    "ParchmentFrame-Top", "ParchmentFrame-Bottom", "ParchmentFrame-Left", "ParchmentFrame-Right",
    "SocketFrame-Left", "SocketFrame-Right",
    "ButtonFrame-Left", "ButtonFrame-Right", "ButtonBorder-Mid",
    "GoldBorder-BottomRight", "GoldBorder-BottomLeft", "GoldBorder-TopRight", "GoldBorder-TopLeft",
    "GoldBorder-Left", "GoldBorder-Right", "GoldBorder-Top", "GoldBorder-Bottom",
    "BackgroundColor", "BackgroundHighlight",
    "BorderShadow-TopLeftCorner", "BorderShadow-TopRightCorner",
    "BorderShadow-BottomLeftCorner", "BorderShadow-BottomRightCorner",
    "BorderShadow-Top", "BorderShadow-Left", "BorderShadow-Bottom", "BorderShadow-Right",
    "BottomLeftNub", "BottomRightNub", "MiddleLeftNub", "MiddleRightNub", "TopLeftNub", "TopRightNub",
}

local SOCKET_ART = { "LeftFiligree", "RightFiligree", "Shine" }

local function Apply()
    local f = _G.ItemSocketingFrame
    if not f then
        E.Missing("ItemSocketingFrame")
        return
    end
    local key = "ItemSocketingFrame"
    if not E.Usable(f, key) then return end

    Skin.PortraitChrome(f, key)
    E.NeutralizeKeys(f, FRAME_ART, key)
    Skin.Panel(f, key)
    -- 標題是視窗自己一條無名的 FontString（XML :146）；視窗自己身上只有這一條字
    E.RecolorRegions(f, T.text, key)

    local inset = Required(f, "Inset", key .. ".Inset")
    if inset then Skin.Inset(inset, key .. ".Inset") end

    local close = Required(f, "CloseButton", key .. ".CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end

    local sf = Required(f, "ScrollFrame", key .. ".ScrollFrame")
    local bar = sf and Optional(sf, "ScrollBar")
    if bar then Skin.ScrollBar(bar, key .. ".ScrollBar") elseif sf then E.Missing(key .. ".ScrollBar") end

    local c = Required(f, "SocketingContainer", key .. ".SocketingContainer")
    if not c then return end
    for i = 1, 3 do
        local skey = key .. ".Socket" .. i
        local sock = Required(c, "Socket" .. i, skey)
        if sock then E.NeutralizeKeys(sock, SOCKET_ART, skey) end
    end

    -- 「套用」：消耗寶石、改裝備 ⇒ 零腳本；這個視窗唯一的動作 ⇒ primary
    local apply = Required(c, "ApplySocketsButton", key .. ".ApplySocketsButton")
    if apply then ScriptlessButton(apply, key .. ".ApplySocketsButton", "primary") end
end

E.Register{
    key   = "socketing",
    addon = "Blizzard_ItemSocketingUI",
    title = L["Item Socketing"],
    apply = Apply,
}
