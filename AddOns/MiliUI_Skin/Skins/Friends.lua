------------------------------------------------------------
-- 配方：好友名單（FriendsFrame：聯絡人／查詢／忽略名單）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:478   FriendsFrame（ButtonFrameTemplate）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:482   $parentIcon ＝ FriendsFrameIcon
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:490   FriendsFrameTitleText（查詢／團隊／快速加入頁在用）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:499   FriendsTabHeader（TabSystemOwnerTemplate，頂部分頁）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:512   FriendsFrameBattlenetFrame
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:581   BroadcastFrame（戰網廣播）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:596   BroadcastFrame.Border（DialogBorderOpaqueTemplate）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:597   BroadcastFrame.EditBox（九張 Common-Input-Border-*）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:686,696  BroadcastFrame 的 Update／Cancel
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:770,777  加好友／傳送訊息
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:851   FriendsListFrame.ScrollBar（MinimalScrollBar）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:873   FriendsFrame.IgnoreListWindow（ButtonFrameTemplate）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:879,896  忽略名單的解除鈕與捲軸
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:911,923  WhoFrameEditBox（SearchBoxTemplate）＋ Backdrop
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:941   WhoFrameListInset（InsetFrameTemplate）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:425   WhoFrameColumnHeaderTemplate（Left/Middle/Right parentKey）
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:960,971,1009,1020  四個欄位表頭
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:1031,1039,1050     查詢頁三顆按鈕
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:1071  WhoFrame.ScrollBar
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:472   FriendsFrameTabTemplate ← PanelTabButtonTemplate
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:1098-1105  FriendsFrameTab1..4
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.lua:462,487,494,500  FriendsFrameIcon 每次切頁重設材質
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.lua:289,319  PanelTemplates_SetNumTabs／UpdateTabs
--   Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml:111  DialogBorderOpaqueTemplate ← NineSlicePanelTemplate ＋ Bg
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:381  NineSlicePanelTemplate（九片掛在框自己身上）
--   Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:206  SearchBoxTemplate
--   Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml:3   TabSystemButtonArtTemplate
--   Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.lua:209 TabSystemMixin 的 tabPool
--
-- 查證後跟計畫假設不一樣的三件事：
--   1. **好友名單不是隨需載入的。** `Blizzard_FriendsFrame` 的 TOC 是
--      `## DefaultState: enabled` 且沒有 `LoadOnDemand` ⇒ `addon = nil`。
--   2. **頂部分頁跟 `Skin.Tab` 完全不是同一套。** 底部那四顆（好友／查詢／團隊／快速加入）
--      是 `FriendsFrameTabTemplate` ← `PanelTabButtonTemplate`，有 `TabTextures`
--      parentArray、狀態走 `PanelTemplates_*` ⇒ `Skin.Tab(..., "panel")` 適用。
--      但 `FriendsTabHeader` 裡那排（聯絡人／近期盟友／招募好友）是
--      `TabSystemButtonTemplate`：九張貼圖的 parentKey 名字**剛好一樣**，可是
--      (a) parentArray 叫 `RotatedTextures` 不是 `TabTextures`、
--      (b) 選中態走 `TabSystemButtonArtMixin:SetTabSelected`，**不經過
--          `PanelTemplates_SelectTab`** ⇒ Engine 的三個後置勾一次都不會觸發，
--          套下去會變成「每一顆都畫成閒置」、
--      (c) 它們是 `CreateFramePool` 生出來的（TabSystemTemplates.lua:209），
--          生命週期要跟著池子走。
--      ⇒ **頂部分頁這一輪不做**，跟下拉與池化列一起排下一輪。
--   3. **戰網廣播輸入框不是暴雪標準 EditBox。** 它沒有繼承 `InputBoxTemplate`，
--      而是自己在 BACKGROUND 層放九張 `Common-Input-Border-*`，parentKey 是
--      `TopLeftBorder` / `TopBorder` / … / `MiddleBorder`（FriendsFrame.xml:604-658）
--      ⇒ 逐一點名中和，overlay 照畫。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 物件 | 動作 |
-- |---|---|
-- | FriendsFrame.NineSlice / .Bg / .TopTileStreaks / .PortraitContainer | SetAlpha(0) |
-- | FriendsFrame.TitleContainer.TitleText、FriendsFrameTitleText | SetTextColor |
-- | FriendsFrameIcon | SetAlpha(0) |
-- | FriendsFrame.Inset 的 Bg / NineSlice | SetAlpha(0) |
-- | FriendsFrame.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | FriendsFrame.CloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | FriendsFrameTab1..4 的 TabTextures（九張） | SetAlpha(0) |
-- | FriendsFrameTab1..4 | SetNormalFontObject(GameFontHighlightSmall) |
-- | 八顆 UIPanelButtonTemplate 的 Left/Right/Middle | SetAlpha(0) |
-- | 同八顆 | SetNormalFontObject(GameFontHighlight) |
-- | WhoFrameColumnHeader1..4 的 Left/Middle/Right | SetAlpha(0) |
-- | WhoFrameColumnHeader1..4 的 Highlight 貼圖 | SetColorTexture |
-- | WhoFrameEditBox 的 Left/Right/Middle / Backdrop | SetAlpha(0) |
-- | WhoFrameEditBox 的 searchIcon / clearButton.Icon / Instructions | SetVertexColor / SetTextColor |
-- | WhoFrameListInset 的 Bg / NineSlice | SetAlpha(0) |
-- | BroadcastFrame.Border 的九片 ＋ Bg | SetAlpha(0) |
-- | BroadcastFrame.EditBox 的九張 *Border | SetAlpha(0) |
-- | IgnoreListWindow 的整組 chrome（同 FriendsFrame） | SetAlpha(0) / SetTextColor / SetColorTexture |
-- | 三條 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 三條 MinimalScrollBar 的 Back/Forward.Texture | SetVertexColor |
-- | 以上各框 | CreateFrame 掛自己的 overlay |
--
-- hook：只有 Engine 的三個 `PanelTemplates_*` 全域後置勾（底部分頁選中態）。
-- 寫入暴雪欄位：無。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- ⚠ **跟「開聊天輸入框／密語」有關的按鈕一律只做視覺，腳本一個都不掛。**
--   `FriendsFrameSendMessageButton` 的 OnClick 是
--   `ChatFrameUtil.SendTell` / `SendBNetTell`（FriendsFrame.lua:1370-1380），
--   那條路上只要有插件的 Lua，`LAST_ACTIVE_CHAT_EDIT_BOX` 就髒到 /reload
--   （`.claude/notes/wow-121-chat-reply-secret-taint.md`）。我們對它只做
--   「中和三張貼圖 ＋ 換 NormalFont 字型物件 ＋ 掛一個不吃滑鼠的 overlay」——
--   沒有 hook、沒有 SetScript、沒有欄位寫入，點下去的那次執行從頭到尾是暴雪的。
--   好友列的名字按鈕（`FriendsListButtonTemplate`）同理，而且它是池化列，這一輪不碰。
--
-- * **好友列／忽略列／查詢結果列**（`FriendsListButtonTemplate`、`IgnoreListButtonTemplate`、
--   `WhoListButtonTemplate`，FriendsFrame.xml:260,366,384）—— `WowScrollBoxList` 的
--   池化 element，overlay 生命週期要跟著池子走，列在下一輪。
-- * **`FriendsTabHeader` 的頂部分頁** —— 理由見上面第 2 點。
-- * **狀態下拉 `FriendsFrameStatusDropdown`（:746）與聯絡人選單
--   `BattlenetFrame.ContactsMenuButton`（:545）、`WhoFrameDropdown`（:976）** ——
--   下拉自己一整套美術與狀態機，STYLE.md ⑦ 的 B 級，下一輪。
-- * **戰網頭像／遊戲圖示**（`FriendsFrameBattlenetFrame` 的底圖與各遊戲的小圖）——
--   那是身分不是裝飾。
-- * **`FriendsListFrame.RIDWarning`**（:782）—— 它自己是一層 85% 黑遮罩，
--   而且 `$parentContinueButton` 的 `$parent` 指向一個沒有名字的框，取不到全域名。
-- * **`BattlenetFrame.UnavailableInfoFrame`**（DialogBorderTemplate）—— 離線提示框，
--   極少出現，先不花接觸面。
-- * **團隊（RaidFrame）／快速加入（QuickJoinFrame）／近期盟友（RecentAlliesFrame）／
--   招募好友（RecruitAFriendFrame）** —— 前兩個的框根本不住在 `Blizzard_FriendsFrame`
--   裡（`ClaimRaidFrame`，FriendsFrame.lua:496），要各自一份配方；後兩個是清單模板。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

-- NineSliceUtil.ApplyLayout 建出來的九片，直接掛在框自己身上
-- （Blizzard_SharedXML/NineSlice.lua；同 Skins/Achievement.lua 的 BACKDROP_PIECES）
local NINE_SLICE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

-- 戰網廣播輸入框自己的九張 Common-Input-Border-*（FriendsFrame.xml:604-658）
local BROADCAST_EDIT_BORDERS = {
    "TopLeftBorder", "TopRightBorder", "TopBorder",
    "BottomLeftBorder", "BottomRightBorder", "BottomBorder",
    "LeftBorder", "RightBorder", "MiddleBorder",
}

------------------------------------------------------------
-- TODO(升格): 查詢頁的欄位表頭（WhoFrameColumnHeaderTemplate）
--
-- 三張切片的 parentKey 名字跟 `UIPanelButtonTemplate` 一樣（Left/Middle/Right），
-- 所以中和的部分跟 `Skin.Button` 完全重疊 —— **但不能直接用 Skin.Button**：
-- 表頭的 NormalFont 是 `UserScaledFontGameHighlightSmall`（跟著玩家的文字大小設定縮放），
-- `Skin.Button` 會把它換成固定字級的 `GameFontHighlight`，等於把縮放弄掉。
-- 升格時正解是 `Skin.Button` 多一個 `opts.keepFont`，不是再多一支函式。
------------------------------------------------------------
local function SkinColumnHeader(btn, key)
    if not E.Usable(btn, key) then return end
    E.NeutralizeKeys(btn, { "Left", "Right", "Middle" }, key)
    E.ButtonStates(btn, key)
    local ov = E.Overlay(btn, { key = key })
    E.Paint(ov, T.fill, T.border)
    return ov
end

-- 一條 MinimalScrollBar 掛在某個 parentKey 底下（好友／忽略／查詢三頁都是這個形狀）
local function SkinOwnedScrollBar(owner, key)
    local bar
    if owner and pcall(function() bar = owner.ScrollBar end) and bar then
        Skin.ScrollBar(bar, key)
    else
        E.Missing(key)
    end
end

------------------------------------------------------------
-- 聯絡人頁
------------------------------------------------------------
local function SkinFriendsList()
    local frame = _G.FriendsListFrame
    if not frame then
        E.Missing("FriendsListFrame")
        return
    end

    for _, name in ipairs({ "FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton" }) do
        local btn = _G[name]
        if btn then
            -- ⚠ 傳送訊息那顆會開聊天輸入框 —— 只做視覺，腳本一個都不掛（見檔頭）。
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end

    SkinOwnedScrollBar(frame, "FriendsListFrame.ScrollBar")
end

------------------------------------------------------------
-- 戰網廣播
------------------------------------------------------------
local function SkinBroadcast(battlenet)
    local broadcast
    if not (pcall(function() broadcast = battlenet.BroadcastFrame end) and broadcast) then
        E.Missing("FriendsFrameBattlenetFrame.BroadcastFrame")
        return
    end

    local border
    if pcall(function() border = broadcast.Border end) and border then
        -- DialogBorderOpaqueTemplate ＝ NineSlicePanelTemplate（九片）＋ 一張全黑的 Bg。
        -- Bg 也要中和：它在 BACKGROUND −5，我們的 overlay 在 −1 層，不中和就被它蓋住。
        E.NeutralizeKeys(border, NINE_SLICE_PIECES, "FriendsFrame.BroadcastFrame.Border")
        E.NeutralizeKeys(border, { "Bg" }, "FriendsFrame.BroadcastFrame.Border")
    else
        E.Missing("FriendsFrame.BroadcastFrame.Border")
    end
    Skin.Panel(broadcast, "FriendsFrame.BroadcastFrame")

    local eb
    if pcall(function() eb = broadcast.EditBox end) and eb then
        E.NeutralizeKeys(eb, BROADCAST_EDIT_BORDERS, "FriendsFrame.BroadcastFrame.EditBox")
        local ov = E.Overlay(eb, { key = "FriendsFrame.BroadcastFrame.EditBox" })
        E.Paint(ov, T.fillInset, T.border)

        local prompt
        if pcall(function() prompt = eb.PromptText end) and prompt then
            E.TextColor(prompt, T.textDisabled, "FriendsFrame.BroadcastFrame.EditBox.PromptText")
        end
    else
        E.Missing("FriendsFrame.BroadcastFrame.EditBox")
    end

    for _, key in ipairs({ "UpdateButton", "CancelButton" }) do
        local btn
        if pcall(function() btn = broadcast[key] end) and btn then
            Skin.Button(btn, "FriendsFrame.BroadcastFrame." .. key)
        else
            E.Missing("FriendsFrame.BroadcastFrame." .. key)
        end
    end
end

------------------------------------------------------------
-- 查詢頁
------------------------------------------------------------
local WHO_BUTTONS = {
    "WhoFrameWhoButton",
    "WhoFrameAddFriendButton",
    "WhoFrameGroupInviteButton",
}

local function SkinWhoFrame()
    local frame = _G.WhoFrame
    if not frame then
        E.Missing("WhoFrame")
        return
    end

    local eb = _G.WhoFrameEditBox
    if eb then
        -- SearchBoxTemplate 的三張切片 ＋ 搜尋圖示 ＋ 提示字，交給原語。
        Skin.EditBox(eb, "WhoFrameEditBox")
        -- 這一顆另外多一張 glues-characterSelect-searchbar 當底（FriendsFrame.xml:923）。
        E.NeutralizeKeys(eb, { "Backdrop" }, "WhoFrameEditBox")
    else
        E.Missing("WhoFrameEditBox")
    end

    local inset = _G.WhoFrameListInset
    if inset then
        Skin.Inset(inset, "WhoFrameListInset")
    else
        E.Missing("WhoFrameListInset")
    end

    for i = 1, 4 do
        local key = "WhoFrameColumnHeader" .. i
        local header = _G[key]
        if header then
            SkinColumnHeader(header, key)
        else
            E.Missing(key)
        end
    end

    for _, name in ipairs(WHO_BUTTONS) do
        local btn = _G[name]
        if btn then
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end

    SkinOwnedScrollBar(frame, "WhoFrame.ScrollBar")
end

------------------------------------------------------------
-- 忽略名單（FriendsFrame 右邊彈出來的那個小 ButtonFrameTemplate）
------------------------------------------------------------
local function SkinIgnoreList(parent)
    local win
    if not (pcall(function() win = parent.IgnoreListWindow end) and win) then
        E.Missing("FriendsFrame.IgnoreListWindow")
        return
    end

    Skin.PortraitChrome(win, "FriendsFrame.IgnoreListWindow")
    Skin.Panel(win, "FriendsFrame.IgnoreListWindow")

    local inset
    if pcall(function() inset = win.Inset end) and inset then
        Skin.Inset(inset, "FriendsFrame.IgnoreListWindow.Inset")
    else
        E.Missing("FriendsFrame.IgnoreListWindow.Inset")
    end

    local close
    if pcall(function() close = win.CloseButton end) and close then
        Skin.CloseButton(close, "FriendsFrame.IgnoreListWindow.CloseButton")
    else
        E.Missing("FriendsFrame.IgnoreListWindow.CloseButton")
    end

    local unignore
    if pcall(function() unignore = win.UnignorePlayerButton end) and unignore then
        Skin.Button(unignore, "FriendsFrame.IgnoreListWindow.UnignorePlayerButton")
    else
        E.Missing("FriendsFrame.IgnoreListWindow.UnignorePlayerButton")
    end

    SkinOwnedScrollBar(win, "FriendsFrame.IgnoreListWindow.ScrollBar")
end

local function Apply()
    local f = FriendsFrame
    if not f then
        E.Missing("FriendsFrame")
        return
    end

    Skin.PortraitChrome(f, "FriendsFrame")

    -- 左上那張 60x60 的戰網／團隊圖示。
    -- ⚠ 一定要用 alpha：`FriendsFrame_Update` 每次切頁都 `SetTexture` 重設
    --   （FriendsFrame.lua:462,487,494,500），換材質撐不過一次切頁。
    E.NeutralizeGlobals({ "FriendsFrameIcon" })

    -- 查詢／團隊／快速加入頁的標題走的是這個 FontString，不是 TitleContainer.TitleText
    -- （FriendsFrame.lua:488,495,501）。兩個都要塗白，不然切頁就變回暗金色。
    E.TextColor(_G.FriendsFrameTitleText, T.text, "FriendsFrameTitleText")

    Skin.Panel(f, "FriendsFrame")

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "FriendsFrame.Inset")
    else
        E.Missing("FriendsFrame.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "FriendsFrame.CloseButton")
    else
        E.Missing("FriendsFrame.CloseButton")
    end

    -- 底部四顆分頁（好友／查詢／團隊／快速加入）。第三、四顆平常是隱藏的，照樣要套。
    for i = 1, 4 do
        local key = "FriendsFrameTab" .. i
        local tab = _G[key]
        if tab then
            Skin.Tab(tab, key, "panel")
        else
            E.Missing(key)
        end
    end

    local battlenet = _G.FriendsFrameBattlenetFrame
    if battlenet then
        SkinBroadcast(battlenet)
    else
        E.Missing("FriendsFrameBattlenetFrame")
    end

    SkinFriendsList()
    SkinWhoFrame()
    SkinIgnoreList(f)
end

E.Register{
    key   = "friends",
    addon = nil,                       -- Blizzard_FriendsFrame 的 TOC 是 DefaultState: enabled、非 LoD
    title = L["Friends List"],
    apply = Apply,
}
