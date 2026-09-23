------------------------------------------------------------
-- 配方：交易（`TradeFrame`，常駐 —— 住在 `Blizzard_UIPanels_Game`）
--
-- ⚠⚠ **整包最敏感的視窗之一。** 「交易」鈕按下去就是 `AcceptTrade`（XML 直接
--   `<OnClick function="AcceptTrade"/>`，TradeFrame.xml:422）。這一份的底線：
--   **`AcceptTrade` 的執行流裡一行我們的 Lua 都沒有** —— 交易／取消兩顆零腳本、
--   整個視窗零 `hooksecurefunc`（除了全遊戲共用的物品格那兩支全域勾，見下）、
--   零 `HookScript("OnShow"/"OnHide")`、零事件框。
--
-- 第十二／十三輪。範圍照「成熟同類實作」的交易段落搬：外框、兩側分隔線與對方那半的
-- 淡色底、六塊 Inset 只淡不畫、每一格的空格底圖／名牌／附魔格圖示淡掉、名牌換成平面方框、
-- 物品格方形＋品質邊、四行字、兩顆按鈕、關閉鈕、兩個肖像。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_UIPanels_Game/Blizzard_UIPanels_Game_Mainline.toc:3,35-36
--     `## DefaultState: enabled`、**沒有 LoadOnDemand**；`Mainline\TradeFrame.lua/.xml`
--     ⇒ 登入時就在 ⇒ `addon = nil`（同 `Skins/Merchant.lua`）。
--   Blizzard_UIPanels_Game/Mainline/TradeFrame.xml:31 `TradeItemTemplate`：
--     `$parentSlotTexture`（parentKey `SlotTexture`，UI-EmptySlot 64x64）／
--     `$parentNameFrame`（**只有全域名**，UI-QuestItemNameFrame 124x64）／`$parentName`
--   同檔 :78,126 `RecipientTradeItemTemplate`／`PlayerTradeItemTemplate`：`$parentItemButton`（ItemButton intrinsic）
--   同檔 :179 `TradeFrame` ← ButtonFrameTemplate；自己的 region：`TradeRecipientBotLeftCorner`／
--     `TradeRecipientLeftBorder`（兩半之間的雕花分隔）／`TradeRecipientBG`（對方那半白 0.15）／
--     `TradeFramePlayerEnchantText`／`TradeFrameRecipientEnchantText`
--   同檔 :218-235 一個**無名**的 HIGH strata 子框，上面是 `TradeFramePlayerNameText`／`TradeFrameRecipientNameText`
--   同檔 :236 `RecipientOverlay`（← ResizeLayoutFrame，`portrait`／`portraitFrame`）
--   同檔 :258-281 `TradeHighlightPlayer/Recipient(Enchant)`（「已按下交易」的綠光，**狀態**，不碰）
--   同檔 :282-475 六塊 Inset（全域名）、`TradeFrameTradeButton`（mixin `TradeFrameTradeButtonMixin`，
--     NormalFont **GameFontNormal**、`WarningIcon`）、`TradeFrameCancelButton`、
--     `TradePlayerInputMoneyFrame`（MoneyInputFrameTemplate）、`TradeRecipientMoneyBg`（ThinGoldEdgeTemplate）、
--     `TradeRecipientMoneyFrame`（SmallMoneyFrameTemplate）
--   Blizzard_UIPanels_Game/Mainline/TradeFrame.lua:5-22 `TradeFrame_OnLoad`：
--     `FrameTemplate_SetAtticHeight(self, 440)`（⇒ `TradeFrame.Inset` 被壓成 0 高，只剩美術殘影）／
--     各 Inset 的 `Bg:SetAlpha(...)`（只在 OnLoad 一次，比我們早）／
--     **`TradePlayerInputMoneyFrame:SetForbidden()`**（:21）⇒ 我方的金額輸入框整棵是 forbidden，
--     我們碰都不能碰（連 `SetAlpha` 都會丟錯）。
--   同檔 :96-190 `TradeFrame_UpdatePlayerItem`／`_UpdateTargetItem`：
--     **全域** `SetItemButtonTexture(tradeItemButton, …)`、**全域** `SetItemButtonQuality(tradeItemButton, …)`
--     ⇒ `Skin.ItemButton` 的品質轉交（`Engine.TrackItemButton` 勾的就是這兩支全域）接得住；
--     `SetItemButtonSlotVertexColor`／`SetItemButtonNameFrameVertexColor`（不可用＝紅）只改 vertex color，
--     我們中和用的是 alpha，兩者互不干涉；圖示本身的紅（`SetItemButtonTextureVertexColor`）照樣留著。
--   同檔 :206-224 `TradeFrame_SetAcceptState`：只 Show/Hide 四片綠光、Enable/Disable 交易鈕。
--
------------------------------------------------------------
-- ## 照抄的做法 ／ 照抄不了的地方
--
-- 照抄：
--   * 外框美術全淡（含兩半之間的分隔、對方那半的淡色底、`Bg`、九宮格、左上肖像）。
--   * **七塊 Inset（含被壓扁的 `TradeFrame.Inset`）只淡不畫**；金額那一列「只拿掉暴雪的框、不畫新的」。
--   * `TradeRecipientMoneyBg`（金邊框，只有美術、金額在兄弟框 `TradeRecipientMoneyFrame` 上）整個 alpha 0。
--   * 每一格：空格底圖、名牌、附魔格那張無名的 62x62 圖示全部淡掉；名牌的位置畫一塊平面方框
--     （名牌矩形四邊內縮 14 —— 美術 64 高、那一列只有 37 高）；物品格方形＋品質邊。
--   * 對方的肖像（`RecipientOverlay.portrait`／`.portraitFrame`）淡掉。
--   * 四行字：兩個名字白、兩行「不會被交易」白（我們把後者降成 `textDim`：它是欄位說明）。
--   * 交易／取消／關閉。
-- 照抄不了：
--   * **我方金額輸入框**：forbidden，它也沒碰（只淡掉外圍的 Inset）。
--   * 它在視窗上掛 `HookScript("OnShow")` 每次重跑、`HookScript("OnHide")` 清狀態 ——
--     我們的中和全是 alpha、品質邊走全域勾，**不掛**（交易視窗的 Show/Hide 就在交易流程裡）。
--   * 它的「變更提示光跟著物品走」修正（勾 `TradeFrame_AlertItemIfChanged` 改寫暴雪的動畫行為）：
--     那是改功能不是換皮，而且要在暴雪框上寫狀態、讀 itemID ⇒ 不做。
--   * 名牌方框的「重錨」：它每次 `ClearAllPoints`／`SetPoint`；我們建一次、錨點一次定好。
--
-- ## 刻意不碰
--   * `TradeHighlight*` 四片綠光（對方／自己按下交易了沒 ＝ 狀態）。
--   * 物品名字的品質色、金錢數字、`WarningIcon`（交易內容變了的警告）、物品格上的 `Alert` 動畫。
--   * `TradePlayerInputMoneyFrame` 整棵（forbidden）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `TradeFrame` 自己的每一張貼圖（`Bg`／`TopTileStreaks`／分隔線兩張／`TradeRecipientBG`，`GetRegions`） | `SetAlpha(0)` |
-- | NineSlice／PortraitContainer | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `TradeFrame` 本身 | `Engine.RegionBackdrop`（底＋邊＋標題帶） |
-- | `TradeFrame.Inset` 與六塊具名 Inset 的 Bg／NineSlice | `SetAlpha(0)`（不畫底） |
-- | `TradeRecipientMoneyBg`（純美術容器） | `SetAlpha(0)` |
-- | `RecipientOverlay.portrait`／`.portraitFrame` | `SetAlpha(0)` |
-- | 14 格 `Trade{Player,Recipient}ItemN` 自己的貼圖（`GetRegions`） | `SetAlpha(0)`；名牌方框建成**格子自己的** BACKGROUND 貼圖（錨在 `$parentNameFrame` 上） |
-- | 14 顆 `…ItemButton` | `Skin.ItemButton`（IconBorder／NormalTexture `SetAlpha(0)`、裁邊、方框 overlay） |
-- | 兩個名字、兩行附魔說明 | `SetTextColor` |
-- | `TradeFrameTradeButton`／`TradeFrameCancelButton` | 零腳本：Left/Right/Middle `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 換長相 |
-- | `CloseButton` | `Skin.CloseButton` |
--
-- ### 讀了什麼
-- 只有結構：parentKey、全域名、`GetRegions()`、`GetObjectType`；物品格那一支另有讀取例外表上的
-- `IconBorder:IsShown()`／`GetVertexColor()`（只轉交，`Engine.PassBorderColor`）。
-- **不讀** `hasItem`／`acceptState`／`enabled`／`warningTooltip`／任何交易資料或金額。
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 什麼時候跑 | 裡面做什麼 |
-- |---|---|---|---|
-- | `hooksecurefunc("SetItemButtonQuality"/"SetItemButtonTexture", …)` | **全遊戲共用**的全域後置勾（`Engine.TrackItemButton`，角色面板／郵件早就裝了，這裡只是把 14 顆登記進弱鍵表） | `TRADE_SHOW`／`TRADE_UPDATE`／`TRADE_*_ITEM_CHANGED`／`GET_ITEM_INFO_RECEIVED` 的事件處理 | 第一行查弱鍵表；重下 IconBorder 的 alpha、轉交品質色、重裁圖示 |
-- | 關閉鈕的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | 滑鼠進出關閉鈕 | 只換我們自己 overlay 的顏色 |
--
-- **交易鈕／取消鈕上的腳本：0 支。`AcceptTrade`／`CancelTradeAccept` 的點擊派送裡：0 行我們的 Lua。**
-- `TRADE_ACCEPT_UPDATE` → `TradeFrame_SetAcceptState` 裡**沒有**任何物品格函式 ⇒ 按下交易之後的那一波
-- 更新也沒有我們的碼。物品格那兩支全域勾跑在「物品換了」的事件處理裡，而且是 `hooksecurefunc`
-- 後置勾（跑完即還原執行權的 taint），不會流進之後的 `AcceptTrade`（那是另一次硬體事件）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

------------------------------------------------------------
-- 零腳本按鈕（同 `Skins/PlayerSpells.lua`）
-- TODO(升格): 見 `Skins/Macro.lua` 同名那一支的 TODO。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })       -- 先建 overlay 再中和（倒過來會做出隱形的「交易」）
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)   -- **不掛腳本**
    return ov
end

------------------------------------------------------------
-- 外框
------------------------------------------------------------
-- 全部是全域名（TradeFrame.xml:282-469；`parentKey="LeftInset"` 六塊重複用，不可靠）。
-- `TradeFrameInset` 是 ButtonFrameTemplate 自己的那一塊，被 `SetAtticHeight(440)` 壓扁了，
-- 美術殘影會在按鈕列上面畫出一條線 ⇒ 一起淡掉。
local INSETS = {
    "TradeFrameInset",
    "TradeRecipientItemsInset", "TradeRecipientEnchantInset",
    "TradePlayerItemsInset", "TradePlayerEnchantInset",
    "TradePlayerInputMoneyInset", "TradeRecipientMoneyInset",
}

local function SkinChrome(f)
    -- 自己的貼圖：Bg、TopTileStreaks、兩張分隔、`TradeRecipientBG`
    E.NeutralizeRegions(f, "TradeFrame")
    Skin.PortraitChrome(f, "TradeFrame")
    Skin.Panel(f, "TradeFrame")

    for _, name in ipairs(INSETS) do
        local inset = _G[name]
        if inset then
            E.NeutralizeKeys(inset, { "Bg", "NineSlice" }, name)
        else
            E.Missing(name)
        end
    end

    -- 對方金額的金邊框：ThinGoldEdgeTemplate，**只有美術**（金額在兄弟框 TradeRecipientMoneyFrame）
    -- ⇒ 整個框 alpha 0（白名單：純美術容器）。
    E.Neutralize(_G.TradeRecipientMoneyBg, "TradeRecipientMoneyBg")

    -- 對方的肖像：RecipientOverlay 是 ResizeLayoutFrame，我們只對它的兩張貼圖下 alpha，
    -- 不建任何東西在它身上（alpha 不影響排版）。
    local ro = Optional(f, "RecipientOverlay")
    if ro then
        E.NeutralizeKeys(ro, { "portrait", "portraitFrame" }, "TradeFrame.RecipientOverlay")
    else
        E.Missing("TradeFrame.RecipientOverlay")
    end

    local close = Optional(f, "CloseButton")
    if close then
        Skin.CloseButton(close, "TradeFrame.CloseButton")
    else
        E.Missing("TradeFrame.CloseButton")
    end

    -- 名字（GameFontNormal 暗金）→ 白；「不會被交易」→ textDim（欄位說明）。
    -- 暴雪只 `SetText`（TradeFrame.lua:71-72），XML 的字串常數之後不再動 ⇒ 一次就永久有效。
    E.TextColor(_G.TradeFramePlayerNameText, T.text, "TradeFramePlayerNameText")
    E.TextColor(_G.TradeFrameRecipientNameText, T.text, "TradeFrameRecipientNameText")
    E.TextColor(_G.TradeFramePlayerEnchantText, T.textDim, "TradeFramePlayerEnchantText")
    E.TextColor(_G.TradeFrameRecipientEnchantText, T.textDim, "TradeFrameRecipientEnchantText")
end

------------------------------------------------------------
-- 一格（`TradeItemTemplate`）
--
-- 名牌方框：`$parentNameFrame` 是 124x64 的羊皮紙名牌，包在 37 高的一列外面 ⇒ 照成熟同類實作
-- 的幾何，矩形取名牌四邊內縮 14（96x36），剛好是名字那一塊。建成**格子自己的** BACKGROUND
-- 貼圖（`Engine.RegionBackdrop`，錨點的 `rel` 指到名牌那張貼圖 —— 錨到暴雪物件是白名單動作），
-- 格子不是 layout host；物品鈕（格子的子框、而且 OnLoad 又把自己抬高 2 層）永遠在它之上。
------------------------------------------------------------
local NAME_BOX_INSET = 14

local function SkinSlot(prefix, i)
    local name = prefix .. i
    local slot = _G[name]
    if not slot then
        E.Missing(name)
        return
    end
    if not E.Usable(slot, name) then return end

    -- 空格底圖、名牌、附魔格那張無名的 62x62 圖示（只有 GetRegions 找得到）一起淡掉
    E.NeutralizeRegions(slot, name)

    local plate = _G[name .. "NameFrame"]
    if plate then
        local box = E.RegionBackdrop(slot, {
            key = name .. ".nameBox",
            slot = "nameBox",
            points = {
                { "TOPLEFT", "TOPLEFT", NAME_BOX_INSET, -NAME_BOX_INSET, rel = plate },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", -NAME_BOX_INSET, NAME_BOX_INSET, rel = plate },
            },
        })
        E.Paint(box, T.fillInset, T.border)
    else
        E.Missing(name .. "NameFrame")
    end

    local btn = _G[name .. "ItemButton"]
    if btn then
        Skin.ItemButton(btn, name .. "ItemButton")
    else
        E.Missing(name .. "ItemButton")
    end
end

local MAX_TRADE_SLOTS = 7     -- `MAX_TRADE_ITEMS`（TradeFrame.lua:1）：六格物品 ＋ 第七格附魔

local function SkinSlots()
    for i = 1, MAX_TRADE_SLOTS do
        SkinSlot("TradePlayerItem", i)
        SkinSlot("TradeRecipientItem", i)
    end
end

------------------------------------------------------------
-- 兩顆按鈕：交易（`AcceptTrade`）primary、取消（`CancelTradeAccept`／關窗）secondary。
-- ⚠ 兩顆的 NormalFont 在 XML 是 GameFontNormal（暗金，TradeFrame.xml:426,439）—— 換成暴雪自己的
--   GameFontHighlight；DisabledFont 不動（交易鈕停用＝已按下，灰字是暴雪的語彙）。
------------------------------------------------------------
local function SkinButtons()
    local trade = _G.TradeFrameTradeButton
    if trade then
        ScriptlessButton(trade, "TradeFrameTradeButton", "primary")
    else
        E.Missing("TradeFrameTradeButton")
    end
    local cancel = _G.TradeFrameCancelButton
    if cancel then
        ScriptlessButton(cancel, "TradeFrameCancelButton", "secondary")
    else
        E.Missing("TradeFrameCancelButton")
    end
end

local function Apply()
    local f = _G.TradeFrame
    if not f then
        E.Missing("TradeFrame")
        return
    end
    if not E.Usable(f, "TradeFrame") then return end

    -- 分段 pcall：一格出錯不拖垮後面的按鈕（成熟同類實作踩過兩次「半套皮」的就是這個）
    for _, step in ipairs({ SkinChrome, SkinSlots, SkinButtons }) do
        local ok, err = pcall(step, f)
        if not ok then ns.ReportError(err) end
    end
end

E.Register{
    key   = "trade",
    addon = nil,                       -- Blizzard_UIPanels_Game 是 LoadFirst，永遠在
    title = L["Trade"],
    apply = Apply,
}
