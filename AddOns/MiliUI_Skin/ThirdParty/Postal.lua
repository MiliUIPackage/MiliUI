------------------------------------------------------------
-- 伴隨元件：套組內建的郵件增強插件（掛在郵件視窗上）
--
-- 收件匣與寄信頁上長著它的一排按鈕。第二輪定的是「只 skin 暴雪自己的物件」，
-- 結果是一個換了皮的視窗上擺著三顆原生紅色按鈕 —— 比整個視窗都沒換皮更難看。
-- 所以走 STYLE.md ③ 的「伴隨元件」那條窄路。
--
-- ## 掛了哪些元件
--
-- | 全域名稱 | 是什麼 | 模板 | 用哪個原語 |
-- |---|---|---|---|
-- | `PostalSelectOpenButton` | 收件匣「開啟」 | `UIPanelButtonTemplate` 系 | `Skin.Button` |
-- | `PostalSelectReturnButton` | 收件匣「返回」 | 同上 | `Skin.Button` |
-- | `PostalOpenAllButton` | 收件匣「收取全部」 | 同上 | `Skin.Button` |
-- | `OpenMailForwardButton` | 讀信視窗「轉寄」 | 同上 | `Skin.Button` |
-- | `Postal_ModuleMenuButton` | 視窗右上的 ▼ | 小圖示鈕 | `Skin.IconButton`（`inset = 4`） |
-- | `Postal_OpenAllMenuButton` | 「收取全部」右邊的 ▼ | 同上 | `Skin.IconButton`（`inset = 4`） |
-- | `Postal_BlackBookButton` | 寄信頁收件人欄右邊的 ▼ | 同上 | `Skin.IconButton`（`inset = 4`） |
-- | `PostalInboxCB1..7` | 每一列左邊的勾選框 | `UICheckButtonTemplate` 系 | `Skin.CheckBox` |
--
-- ⚠⚠ **「收取全部」有兩顆，兩顆都要有皮。** 暴雪自己那顆 `OpenAllMail`
--   （`Blizzard_MailFrame/MailFrame.xml:431`）會被這支插件藏起來、換成它自己的
--   `PostalOpenAllButton` 擺在同一個位置。我們**兩顆都上皮**：
--     * `OpenAllMail` 的皮在 `Skins/Mail.lua` 的 `SkinInbox`（玩家可能沒裝這支插件）；
--     * `PostalOpenAllButton` 的皮在這一份。
--   兩邊各自獨立、互相不知道對方在不在 —— 這正是伴隨元件規則第 2、3 條要的：
--   不呼叫它的函式、不問它藏了誰、沒有就靜默跳過。搬檔案的時候**不要**把
--   `Skins/Mail.lua` 那一顆順手拿掉。
--
-- ## 觸發時機與理由
--
-- `Engine.AddCompanion("mail", { event = "MAIL_SHOW", … })` ＋ 引擎延一幀。
-- 這些元件是**開信箱那一刻才建**的（不像預組隊伍過濾那支是檔案層一次建完），
-- 所以有一個擺在對的時間點上的暴雪事件可以用，不需要 `atLogin`。
-- 冪等（`Engine.Overlay` 本來就是），每次開信箱重掃一遍無害；戰鬥閘照走
-- （信箱在戰鬥中開得起來），戰鬥中收到的事件由引擎在 `PLAYER_REGEN_ENABLED` 補跑。
--
-- host ＝ `mail` ⇒ 郵件視窗的開關關掉時這一支也不跑（伴隨元件本來就跟著視窗走）。
-- 單獨關掉走設定頁「其他插件」那一節（`addonKey = "postal"`）。
--
------------------------------------------------------------
-- ## taint 接觸面清單（伴隨元件）
--
-- ⚠ 這一份**一個暴雪物件都沒有碰**，所以只有這一張表（STYLE.md ③ 第 6 條）。
--
-- | 物件 | 動作 |
-- |---|---|
-- | 四顆按鈕的 `Left`／`Right`／`Middle` | `SetAlpha(0)`（`Skin.Button`） |
-- | 同四顆 | `SetNormalFontObject(GameFontHighlight)` |
-- | 同四顆的 Highlight | `SetAlpha(0)`（滑過自己畫，`Engine.TrackButtonHover`） |
-- | 三顆 ▼ 小鈕的 Normal／Pushed／Disabled／Highlight | `SetAlpha(0)`（`Skin.IconButton`） |
-- | `PostalInboxCB1..7` 的 Normal／Pushed／Disabled／Highlight | `SetAlpha(0)` |
-- | 同七顆的 Checked／DisabledChecked | `SetAlpha(1)` ＋ 形狀遮罩／去飽和 ＋ 職業色 |
-- | 以上各框 | `CreateFrame` 掛自己的 overlay（錨在目標上、不吃滑鼠、零腳本） |
--
-- hook：**一支都沒有掛在它的函式上**。只有原語內建的
--   `HookScript("OnEnter"/"OnLeave")`（`Engine.TrackButtonHover`，只碰我們自己的
--   overlay）；**第九輪**起 primary 的那一顆（`PostalOpenAllButton`）再多
--   `HookScript("OnEnable"/"OnDisable")`（同一支引擎函式，停用時退回中性底）。**沒有 `hooksecurefunc`、沒有 `SetScript`、沒有呼叫它的任何函式。**
-- 寫入它的欄位：無（狀態全在 `Engine.State` 的弱鍵表裡）。
-- 讀它的物件：只有 `_G[名字]` 在不在，以及原語內部的 getter（`GetHighlightTexture`…）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **那幾顆按鈕的文字內容與它自己的選單** —— 彈出的選單一律不碰（STYLE.md ③）。
-- * **它掛在暴雪信件列上的任何東西的位置** —— `SetPoint`／`SetSize` 對伴隨元件
--   跟對暴雪物件同一條線，契約禁止。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine

------------------------------------------------------------
-- ⚠ 一律 `_G[...]` 判斷，**找不到就靜默跳過**，不走 `E.Missing`
--   （STYLE.md ③ 第 2 條：玩家沒裝那支插件不是暴雪改版事故）。
------------------------------------------------------------
local BUTTONS = {
    "PostalSelectOpenButton",     -- 收件匣「開啟」
    "PostalSelectReturnButton",   -- 收件匣「返回」
    "PostalOpenAllButton",        -- 收件匣「收取全部」（暴雪那顆 OpenAllMail 會被它
                                  --  藏起來，但 Skins/Mail.lua 照樣給 OpenAllMail
                                  --  上皮 —— 玩家可能沒裝，見檔頭）
    "OpenMailForwardButton",      -- 讀信視窗「轉寄」
}

local ICON_BUTTONS = {
    "Postal_ModuleMenuButton",    -- 視窗右上的 ▼
    "Postal_OpenAllMenuButton",   -- 「收取全部」右邊的 ▼
    "Postal_BlackBookButton",     -- 寄信頁收件人欄右邊的 ▼
}

local CHECKBOXES = 7              -- PostalInboxCB1..7

local function Apply()
    for _, name in ipairs(BUTTONS) do
        local btn = _G[name]
        -- 第九輪：「收取全部」primary（它取代暴雪那顆單獨的主按鈕）；
        -- 開啟／返回（對勾選信件的一對平行操作）與轉寄 secondary
        if btn then
            Skin.Button(btn, name, {
                variant = name ~= "PostalOpenAllButton" and "secondary" or nil,
            })
        end
    end
    for _, name in ipairs(ICON_BUTTONS) do
        local btn = _G[name]
        if btn then Skin.IconButton(btn, name, { inset = 4 }) end
    end
    for i = 1, CHECKBOXES do
        local cb = _G["PostalInboxCB" .. i]
        if cb then Skin.CheckBox(cb, "PostalInboxCB" .. i) end
    end

    -- 「開啟／返回」置中（2026-09-24 使用者要求，實機擷圖整組偏右）
    --
    -- 原因：Postal 把兩顆錨在 **`InboxFrame` 的 TOP**（Postal/Modules/Select.lua:92,103：
    --   開啟 `RIGHT → InboxFrame TOP 0,-42`、返回 `LEFT → InboxFrame TOP 5,-42`），
    --   但 `InboxFrame` 是舊版寬度 384、錨在 `MailFrame` 的 TOPLEFT
    --   （Blizzard_MailFrame/MailFrame.xml:288-291），比可見的 `MailFrame` 寬 ⇒ 中心偏右約 23。
    -- 做法：`Engine.ShiftRoot`（重錨的唯一例外）把**同名錨點**改掛到 `MailFrame` 的 TOP，
    --   兩顆各離中線 3（原本間距 5 ⇒ 6，對稱）。y 照 Postal 原值 -42。
    --   * Postal 只在 `OnEnable` 建立時錨一次、之後零處重設或讀回這兩顆的位置（grep 過）⇒ 撐得住；
    --     它是 Postal 建的框、不在任何 secure 路徑上。
    --   * `db.relayout = false` 整批關；戰鬥中 ShiftRoot 自己回 false（伴隨輪本來就過戰鬥閘）。
    local mail = _G.MailFrame
    if mail then
        local open, ret = _G.PostalSelectOpenButton, _G.PostalSelectReturnButton
        if open then E.ShiftRoot(open, "RIGHT", mail, "TOP", -3, -42, "PostalSelectOpenButton") end
        if ret then E.ShiftRoot(ret, "LEFT", mail, "TOP", 3, -42, "PostalSelectReturnButton") end
    end
end

E.AddCompanion("mail", {
    event    = "MAIL_SHOW",
    addonKey = "postal",
    apply    = Apply,
})
