------------------------------------------------------------
-- 配方：確認彈窗（StaticPopup1…4）
--
-- ⚠⚠ **這一份是特許，規矩比其他配方嚴。**
--   STYLE.md ⑦ 原本把 `StaticPopup` 列在 C 級「不碰」，理由是「裡面會出現保護按鈕」。
--   使用者點名要做，所以改成**只做純視覺、零 hook 進點擊路徑**的特許：
--     1. **一個 `HookScript` 都不掛**（連按鈕的 OnEnter／OnLeave 都不掛）——
--        滑過一律交給引擎換 Highlight 貼圖的長相（`Engine.ButtonStates`）。
--     2. **`StaticPopup_*` 的任何函式都不勾。** 這一份配方的 hook 數是 **0**，
--        下面那一節「為什麼一個 hook 都不需要」寫了為什麼做得到。
--     3. 零欄位寫入；不呼叫任何 `StaticPopup_*`；不碰 `dialog.data` / `dialog.which`
--        /按鈕的 `GetText()`。
--   彈窗按鈕的 callback 會執行受保護的動作（刪除物品、離開隊伍、登出、綁定確認、
--   購買…）。只要點擊那一次的執行被我們的程式污染，動作就會被擋，而且錯誤訊息
--   指不到我們（`.claude/notes/wow-121-addon-code-in-secure-stack.md`）。
--
------------------------------------------------------------
-- ## 暴雪原始碼出處（12.1 live，Gethe/wow-ui-source）
--
--   Blizzard_StaticPopup_Game/GameDialog.xml:3      `StaticPopupButtonTemplate`
--       NormalTexture `UI-DialogBox-Button-Up`（:34）／PushedTexture `-Down`（:37）／
--       DisabledTexture `-Disabled`（:40）／HighlightTexture `-Highlight`（ADD，:43）
--       ＋ ButtonText `Text`（:27）、`Flash`（:18，PulseAnim 用）
--       NormalFont `UserScaledFontGameNormal`（:46，**暗金**）、
--       HighlightFont `UserScaledFontGameHighlight`（:48，白）
--   同檔 :51   `StaticPopupBaseTemplate` → `BG`（Frame，`useParentLevel`）底下
--       `BG.Top`／`BG.Bottom` 兩張；`CloseButton`（`UIPanelCloseButton`，:64）
--   同檔 :78   `StaticPopupTemplate`（← `StaticPopupBaseTemplate, ResizeLayoutFrame`）
--       `Text`(:94)／`SubText`(:103)／`AlertIcon`(:112)／`ProgressBarBorder`(:123)／
--       `ProgressBarFill`(:135)／`CoverFrame`(:154)／`ButtonContainer`(:170) 底下
--       `Button1…4`（parentKey ＋ parentArray `Buttons`，:172-175）／`Separator`(:181)／
--       `ExtraButton`(:196)／`EditBox`(:201)／`Dropdown`(:235)／`MoneyFrame`(:240)／
--       `MoneyInputFrame`(:248)／`ItemFrame`(:253，內含 `Item`/`Text`/`NameFrame`)／
--       `DarkOverlay`(:296)／`Spinner`(:312)
--   同檔 :334,339,344,349  **`StaticPopup1` / `2` / `3` / `4` 是 XML 靜態建好的**
--   Blizzard_StaticPopup_Game/GameDialog.lua:24    `GameDialogBaseMixin:OnLoad`
--       `BG.Top:SetAtlas(GameDialogBackgroundTop)`（＝`UI-DiamondDialogBox-Border`，
--       Mainline/GameDialog.lua:5）、`BG.Bottom:SetAtlas("UI-DialogBox-Background-Dark")`
--   同檔 :179  `GameDialogMixin:SetupCloseButton` → :184/:186 每次 Init 都
--       `SetNormalTexture`／`SetPushedTexture` 重設 atlas（見下面「為什麼 Pushed 要中和」）
--   同檔 :206  `SetupEditBox`／:230 `SetupDropdown`／:234 `SetupMoneyFrame`／
--       :260 `SetupItemFrame`／:284 `SetupButtons`／:310 `SetupAlertIcon`
--   同檔 :801  `StaticPopupItemFrameMixin:DisplayInfo` → `SetItemButtonTexture` ＋
--       `SetItemButtonQuality` ＋ `Text:SetTextColor(品質色)`
--   Blizzard_StaticPopup_Game/Blizzard_StaticPopup_Game.toc  **沒有 `## LoadOnDemand`**
--       ⇒ 登入當下就載好了，`addon` 欄位留 nil
--   Blizzard_SharedXML/SharedTooltipTemplates.xml:111  `TooltipBackdropTemplate`
--       → 一個 `NineSlice` 子框（EditBox 的外框就是它）
--   Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml:3,72  `MoneyFrameEditBoxTemplate`
--       → `left`/`right` 是**小寫 parentKey**、`Middle` 只有全域名字
--
------------------------------------------------------------
-- ## 為什麼這一份**一個 hook 都不需要**（查證結論）
--
-- 彈窗框不是池化的、也不是執行期才建的：`StaticPopup1…4` 在
-- `GameDialog.xml:334-353` 就寫死了，四顆都有全域名字。所以「登入之後掃一次」
-- 就是完整的 —— 不需要事件、不需要後置勾、不需要延一幀。
--
-- 剩下的問題只有一個：**暴雪每次顯示彈窗會不會把我們的中和打回去？**
-- 逐一查過，答案是不會，因為我們一律用 `SetAlpha(0)`，而 alpha 與材質是兩個
-- 獨立的屬性（STYLE.md ③）：
--   * `BG.Top` / `BG.Bottom` —— 只在 `GameDialogBaseMixin:OnLoad` 設一次 atlas。
--   * 按鈕的 Normal／Pushed／Disabled —— **全檔沒有任何 Lua 重設它們**
--     （只有 XML 的 `<NormalTexture>` 那一次）。
--   * 關閉鈕的 Normal／Pushed —— `SetupCloseButton` 每次 Init 都重設 atlas，
--     alpha 照樣撐得住。
--   * `ItemFrame.Item.IconBorder` —— `SetItemButtonBorder_Base` 每次
--     `SetShown(true)` ＋ 重設材質，alpha 一樣撐得住。
--   * EditBox 的 `NineSlice`、Dropdown 的 `Background` —— 同理。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- **hook：無。**（`hooksecurefunc` 0 支、`HookScript` 0 支、事件框 0 個）
-- **寫入暴雪欄位：無。**
-- **讀暴雪物件**：只讀 parentKey／parentArray 找區域（`BG`、`ButtonContainer.Buttons`…）、
--   `GetObjectType`、以及 `Engine.Overlay` 內部有三道守衛的 `GetFrameLevel`。
--   **沒有**讀文字／尺寸／錨點，**沒有**讀 `which`／`data`／`dialogInfo`。
--
-- | 物件（`StaticPopupN` = 1…4） | 動作 | 為什麼不會進到按鈕的點擊執行鏈 |
-- |---|---|---|
-- | `StaticPopupN.BG.Top` / `.Bottom` | `SetAlpha(0)` | 一次性的區域屬性寫入，跑在我們自己的 `PLAYER_LOGIN` 堆疊裡；之後執行期零 Lua |
-- | `StaticPopupN` | `CreateFrame` 一個 overlay（parent 指定 `BG`，見下） | 建立時就定好錨點與層級，**沒有腳本**（陷阱 1）⇒ 點擊時不會有我們的程式被呼叫 |
-- | `StaticPopupN.ButtonContainer.ButtonN` ／ `.ExtraButton` 的 Normal/Pushed/Disabled | `SetAlpha(0)` | 同上，一次性 |
-- | 同上按鈕的 `GetHighlightTexture()` | `SetColorTexture(1,1,1,0.08)` | **只換那張貼圖長什麼樣**；顯示／隱藏仍然完全由 C 端在滑鼠進出時決定，我們沒有掛 OnEnter/OnLeave ⇒ 滑過與點擊的派送裡一行我們的 Lua 都沒有（STYLE.md ③ 陷阱 3） |
-- | 同上按鈕 | `SetNormalFontObject(UserScaledFontGameHighlight)` | 白名單動作，傳的是**暴雪自己的**字型物件；一次性設定，之後由 C 端在三態之間切換 |
-- | `StaticPopupN.CloseButton` 的 Normal/Pushed/Disabled | `SetAlpha(0)` | 同上 |
-- | `StaticPopupN.EditBox.NineSlice`（Frame） | `SetAlpha(0)` | 純美術容器，白名單允許對 frame 下 SetAlpha |
-- | `StaticPopupN.EditBox.Instructions` | `SetTextColor` | 不屬於按鈕的 FontString（白名單） |
-- | `StaticPopupN.Dropdown.Background` / `.Arrow` | `SetAlpha(0)` / `SetVertexColor` | `Skin.Dropdown`，不傳 `opts.textColor` ⇒ 那條會掛 HookScript 的路**沒有**被走到 |
-- | `StaticPopupN.MoneyInputFrame.{gold,silver,copper}` 的 `left`/`right` ＋ 全域 `…Middle` | `SetAlpha(0)` | 同上 |
-- | `StaticPopupN.ItemFrame.NameFrame` | `SetAlpha(0)` | 純裝飾（`UI-QuestItemNameFrame`）；上面的字是品質色＝資訊，不碰 |
-- | `StaticPopupN.ItemFrame.Item.IconBorder` ／ `GetNormalTexture()` | `SetAlpha(0)` | 同上 |
-- | `StaticPopupN.ItemFrame.Item.GetHighlightTexture()` | `SetColorTexture` | 同按鈕那一條 |
--
-- overlay 一律**不吃滑鼠**（`Engine.Overlay` 建的是 `EnableMouse` 預設 false 的純 Frame），
-- 所以彈窗按鈕的滑鼠焦點完全沒有被動到
-- （`.claude/notes/wow-child-frame-steals-mouse-focus.md`）。
--
------------------------------------------------------------
-- ## 三個實作上的講究
--
-- **1. overlay 的 parent 一定要指定成 `dialog.BG`，不能讓 `SafeParent` 去猜。**
--   `StaticPopupTemplate` 繼承 `ResizeLayoutFrame`（GameDialog.xml:78），是個 layout
--   host ⇒ `Engine.SafeParent` 會一路往上爬到 `UIParent`（陷阱 2）。可是彈窗在顯示時
--   會被 `dialog:SetFrameStrata("DIALOG")`（Blizzard_StaticPopup/StaticPopup.lua:880,947），
--   掛在 `UIParent` 底下的 overlay 是 MEDIUM ⇒ **皮會整塊掉到彈窗後面**。
--   `BG` 是 `<Frame parentKey="BG" useParentLevel="true" setAllPoints="true">`（:54）——
--   不是 layout host、在彈窗的子樹裡 ⇒ 既拿得到 DIALOG 又不會被 `ResizeLayoutMixin:Layout`
--   當成 layout child 去量（`Blizzard_SharedXML/LayoutFrame.lua:487` 只走**直接** children）。
--   ⚠ `BG` 找不到就**整塊外框不畫**並記一筆 missing —— 退到「彈窗沒換皮」比
--     「皮畫在彈窗後面」好。
--
-- **2. 按鈕的 Pushed 一律中和，不上色（註 ⓔ 的二選一）。**
--   關閉鈕是整包唯一走「Pushed 上色」的按鈕，理由是「模板寫死、暴雪不會在執行期
--   重設材質」。**彈窗的關閉鈕不符合那個前提**：`GameDialogMixin:SetupCloseButton`
--   每次 Init 都 `SetPushedTexture(GameDialogCloseButtonStatePressed)`（GameDialog.lua:184），
--   我們的 `SetColorTexture` 撐不過一次彈窗。所以這裡不用 `Skin.CloseButton`，
--   自己組一支只中和、不上色的版本。
--
-- **3. 物品格只畫靜態的 1px 黑邊，不追品質色。**
--   追品質色要靠 `Engine.TrackItemButton` 的兩個全域後置勾
--   （`SetItemButtonQuality`／`SetItemButtonTexture`）。那兩支在這裡會跑在
--   `StaticPopupItemFrameMixin:DisplayInfo` 裡面 —— 也就是**彈窗顯示的那一次執行**，
--   而彈窗顯示常常就接在一次受保護的動作後面。這一份配方的特許條件是「零 hook」，
--   所以不走。圖示也因此**不裁邊**：`DisplayInfo` 每次都 `SetItemButtonTexture`，
--   texCoord 會被打回 `0,1,0,1`（`ItemButtonTemplate.lua:76`），沒有 reapply 的話
--   會變成「有時候裁了有時候沒裁」，比從頭到尾不裁更糟。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * `Text` / `SubText` / `AlertIcon` / `Separator` —— 彈窗底本來就是
--   `UI-DialogBox-Background-Dark`（深色），暴雪那一組字色（白／金）就是為深底設計的，
--   換成我們的 `fill` 之後照樣讀得出來 ⇒ 不必接管（內容底材規則的「接得住才換」
--   這裡變成「本來就不用換」）。`SubText` 另外還有一個硬理由：
--   `GameDialogMixin` 每次 Init 都 `SetFontObject`（GameDialog.lua:171），
--   `SetTextColor` 撐不過一次彈窗。
-- * `CoverFrame` / `DarkOverlay` / `Spinner` —— 「等待伺服器回應」的狀態，是資訊。
-- * `ProgressBarBorder` / `ProgressBarFill` —— 那兩張是**貼圖不是 StatusBar**
--   （`ProgressBarFill` 的寬度由 `StaticPopup_UpdateProgressBar` 直接算），
--   要換皮就得知道它的幾何，風險不對稱 ⇒ 留著。
-- * 按鈕的 `Flash` ＋ `PulseAnim` —— `SetupButtons` 只在 `buttonNPulse` 時播
--   （GameDialog.lua:296），那是「建議按這顆」的訊號，是資訊。
-- * `MoneyFrame`（只顯示金額的那個）—— 沒有自己的美術，數字的金／銀／銅是值。
-- * `insertedFrame` —— 別的系統塞進來的框，各有各的皮，不是這份配方的範圍。
--
-- ## 同家族的其他小彈窗：這一輪**一個都不做**，逐一說明理由
--
-- * `ReadyCheckFrame`（就位確認，`Blizzard_FrameXML/Mainline/ReadyCheck.xml:15`）——
--   兩顆 `UIPanelButtonTemplate` 的 OnClick 是 XML 內嵌的
--   `ConfirmReadyCheck(...)`（同檔 :85-102）。就位確認是**戰鬥中／首領戰中**在用的，
--   而 12.x 的插件限制系統把就位確認整條路都收緊了
--   （`.claude/notes/wow-12x-addon-restrictions.md`）。為了一圈邊去碰它不划算。
-- * `LFGDungeonReadyDialog` / `LFGDungeonReadyStatus`（`Blizzard_GroupFinder/Shared/
--   LFGReadyCheck.xml`）—— 同上，而且「進入地城」那顆通往傳送。
-- * `LFDRoleCheckPopup` —— STYLE.md ⑦ 已經寫明刻意不做（`frameStrata="DIALOG"`
--   的彈出視窗，離 StaticPopup 太近），這一輪沒有新的理由推翻它。
-- * `GuildInviteFrame`（`Blizzard_FrameXML/GuildInviteFrame.xml:3`）——
--   它繼承的是 `TranslucentFrameTemplate` 不是 `DialogBorderTemplate`，而且整個框
--   幾乎都是公會徽章美術（`$parentTabardBackground`／`Emblem`／`Border`／`Ring`），
--   「同一支 local 函式順手處理」不成立，要做就是另一份配方。
-- * `BNToastFrame` —— **判準落在別套皮上**：它浮在世界上方、是彈出來給人讀一眼的
--   ⇒ 依 STYLE.md ① 的兩個問題應該走**提示皮**（不透明 0.133 底 ＋ 職業色邊），
--   不是這包的設定視窗皮。硬套會讓同一個套組出現兩種「提示」長相。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

-- `StaticPopup1…4`（GameDialog.xml:334-353）
local POPUP_COUNT = 4

-- 彈窗按鈕的白字。模板的 HighlightFont 就是這一支（GameDialog.xml:48），
-- 跟 NormalFont 同字型同字級只差顏色 ⇒ `UserScaledFrameTemplate` 的
-- `useScaleWeight` 量到的度量不會變。取不到就退回一般的 `GameFontHighlight`。
local function ButtonFont()
    return _G.UserScaledFontGameHighlight or GameFontHighlight
end

------------------------------------------------------------
-- 平面按鈕（`StaticPopupButtonTemplate`）
--
-- ⚠ **這一支是配方自己的 local，不用 `Skin.Button`。**
--   `Skin.Button` 在第五輪之後會替一般按鈕掛 `HookScript` 的職業色邊框滑過態，
--   而這兩個視窗的特許條件是「零 HookScript 在任何按鈕上」。
--   所以這裡只組合四個不掛腳本的動作：中和 → 引擎畫三態 → 換字型物件 → overlay。
--
-- 三態：滑過交給引擎（Highlight → 白 8%）。**按下沒有視覺** ——
-- Pushed 已經被 alpha 0，再 `SetColorTexture` 也乘不出東西（註 ⓔ 的二選一）。
--
-- TODO(升格): 如果第五輪之後「要一顆完全不掛腳本的平面按鈕」在別的配方也出現，
--   就把這支升格成 `Skin.Button` 的 `opts.noHover` 之類的開關。
------------------------------------------------------------
local BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }

local function FlatButton(btn, key, opts)
    if not E.Usable(btn, key) then return nil end
    opts = opts or {}

    -- ⚠ **先建 overlay 再中和。** `Engine.Overlay` 對保護框會回 nil（並記進
    --   `/mskin debug`），倒過來寫的話那顆按鈕會變成「美術被中和掉、又沒有東西補」
    --   的一顆隱形按鈕 —— 彈窗的按鈕是「確定／取消」，看不見比沒換皮嚴重得多。
    local ov = E.Overlay(btn, { key = key, inset = opts.inset, glyph = opts.glyph })
    if not ov then return nil end

    for _, getter in ipairs(BUTTON_TEXTURES) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    -- 第三個參數不給 ⇒ 只換 Highlight 的長相，Pushed 不上色
    E.ButtonStates(btn, key)

    if opts.font then E.ButtonFonts(btn, opts.font, key) end

    E.Paint(ov, T.fill, T.border)
    return ov
end

------------------------------------------------------------
-- 彈窗的關閉鈕
--
-- 跟 `Skin.CloseButton` 差一件事：**Pushed 也中和**。理由見檔頭的講究 2 ——
-- `SetupCloseButton` 每次 Init 都重設 Pushed 的 atlas，上色撐不過一次彈窗。
-- × 一樣是 overlay 上兩條 `CreateLine()`（建立時定好、執行期零 Lua，註 ⓖ）。
------------------------------------------------------------
local CLOSE_GLYPH = { kind = "cross", size = 9, thickness = 1 }

local function FlatCloseButton(btn, key)
    return FlatButton(btn, key, { inset = 2, glyph = CLOSE_GLYPH })
end

------------------------------------------------------------
-- 金額輸入框（`MoneyInputFrameTemplate`）
--
-- 三個小輸入框各自獨立：`left`/`right` 是**小寫 parentKey**、`Middle` 只有全域名字
-- （Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml:17-40）。
-- 右邊那張金／銀／銅幣圖（`texture`）不碰 —— 那是「這格是什麼幣值」，是值。
--
-- TODO(升格): 跟 Skins/Mail.lua 的 `SkinMoneyInput` 是同一支，第三個用到的地方
--   出現時就升格成 `Skin.MoneyInput`。
------------------------------------------------------------
local MONEY_PARTS = {
    { field = "gold",   suffix = "Gold" },
    { field = "silver", suffix = "Silver" },
    { field = "copper", suffix = "Copper" },
}

local function SkinMoneyInput(frame, globalName, key)
    if not E.Usable(frame, key) then return end
    for _, part in ipairs(MONEY_PARTS) do
        local box
        local bkey = key .. "." .. part.field
        if pcall(function() box = frame[part.field] end) and box then
            E.NeutralizeKeys(box, { "left", "right" }, bkey)
            E.NeutralizeGlobals({ globalName .. part.suffix .. "Middle" })
            local ov = E.Overlay(box, { key = bkey })
            E.Paint(ov, T.fillInset, T.border)
        else
            E.Missing(bkey)
        end
    end
end

------------------------------------------------------------
-- 物品格（`ItemFrame.Item`，ItemButton intrinsic）
--
-- **不走 `Skin.ItemButton`**：那一支會呼叫 `Engine.TrackItemButton`，掛上兩個
-- 全域後置勾去追品質色。理由見檔頭的講究 3。這裡只做靜態的一圈 1px 黑邊。
------------------------------------------------------------
local function FlatItemButton(btn, key)
    if not E.Usable(btn, key) then return end

    -- 先建 overlay 再中和（同 `FlatButton` 的理由）
    local bg = E.Overlay(btn, { key = key, noBorder = true })
    if not bg then return end

    -- 圓角品質框（`WhiteIconFrame`）中和。一定要 alpha：
    -- `SetItemButtonBorder_Base` 每次更新都 `SetShown(true)` ＋ 重設材質。
    E.NeutralizeKeys(btn, { "IconBorder" }, key)

    if type(btn.GetNormalTexture) == "function" then
        local ok, tex = pcall(btn.GetNormalTexture, btn)
        if ok and tex then E.Neutralize(tex, key .. ".GetNormalTexture") end
    end
    E.ButtonStates(btn, key)

    E.Paint(bg, T.fillInset)
    -- 邊畫在圖示之上（前景 slot）
    Skin.BorderOnly(btn, key)
end

------------------------------------------------------------
-- 一顆彈窗
------------------------------------------------------------
local function SkinDialog(dialog, key)
    if not E.Usable(dialog, key) then return end

    ------------------------------------------------------------
    -- 外框
    ------------------------------------------------------------
    local bg
    if not (pcall(function() bg = dialog.BG end) and bg) then
        -- parent 沒著落就整塊不畫（檔頭的講究 1）。
        -- ⚠ 這是一道**全有全無**的閘：外框沒換成，底下那些平面按鈕擺在原生雕花框裡
        --   比「整顆彈窗都沒換皮」難看，而且看不出是少做一塊還是插件壞了。
        E.Missing(key .. ".BG")
        return
    end

    -- 先建 overlay 再中和（同 `FlatButton` 的理由：保護框上 `Engine.Overlay`
    -- 會回 nil，倒過來寫會得到一顆看不見的彈窗）
    local ov = E.Overlay(dialog, { key = key, parent = bg })
    if not ov then return end

    E.NeutralizeKeys(bg, { "Top", "Bottom" }, key .. ".BG")
    E.Paint(ov, T.fill, T.border)

    ------------------------------------------------------------
    -- 關閉鈕
    ------------------------------------------------------------
    local close
    if pcall(function() close = dialog.CloseButton end) and close then
        FlatCloseButton(close, key .. ".CloseButton")
    else
        E.Missing(key .. ".CloseButton")
    end

    ------------------------------------------------------------
    -- 四顆按鈕 ＋ 額外按鈕
    --
    -- `Button1…4` 收在 `ButtonContainer` 底下（GameDialog.xml:170-176），
    -- 同時有 parentKey 與 parentArray（`Buttons`）。先走陣列，沒有再逐一點名 ——
    -- 兩種都只是「問結構」，跟 `Skin.Tab` 讀 `TabTextures` 同一條。
    ------------------------------------------------------------
    local font = ButtonFont()

    local container
    if pcall(function() container = dialog.ButtonContainer end) and container then
        local arr
        if pcall(function() arr = container.Buttons end) and type(arr) == "table" and #arr > 0 then
            for i, btn in ipairs(arr) do
                FlatButton(btn, key .. ".Button" .. i, { font = font })
            end
        else
            for i = 1, 4 do
                local btn
                if pcall(function() btn = container["Button" .. i] end) and btn then
                    FlatButton(btn, key .. ".Button" .. i, { font = font })
                else
                    E.Missing(key .. ".ButtonContainer.Button" .. i)
                end
            end
        end
    else
        E.Missing(key .. ".ButtonContainer")
    end

    local extra
    if pcall(function() extra = dialog.ExtraButton end) and extra then
        FlatButton(extra, key .. ".ExtraButton", { font = font })
    else
        E.Missing(key .. ".ExtraButton")
    end

    ------------------------------------------------------------
    -- 輸入框（刪除物品要打 DELETE 的那個）
    --
    -- 外框是 `TooltipBackdropTemplate` 的 `NineSlice` 子框，**不是**
    -- `InputBoxTemplate` 的 Left/Middle/Right ⇒ 不能用 `Skin.EditBox`
    -- （那會在 `/mskin debug` 留三筆假的「找不到的區域」）。
    ------------------------------------------------------------
    local eb
    if pcall(function() eb = dialog.EditBox end) and eb then
        local ekey = key .. ".EditBox"
        -- 先建 overlay 再中和（同 `FlatButton` 的理由）
        local eov = E.Overlay(eb, { key = ekey })
        if eov then
            E.NeutralizeKeys(eb, { "NineSlice" }, ekey)
            E.Paint(eov, T.fillInset, T.border)

            local instructions
            if pcall(function() instructions = eb.Instructions end) and instructions then
                E.TextColor(instructions, T.textDisabled, ekey .. ".Instructions")
            end
        end
    else
        E.Missing(key .. ".EditBox")
    end

    ------------------------------------------------------------
    -- 下拉（`StaticPopup_ShowGenericDropdown` 那一種）
    --
    -- ⚠ **不傳 `opts.textColor`**：那條路會走 `Engine.DropdownText`，而那一支會
    --   `HookScript("OnEnable"/"OnDisable")`。`WowStyle1DropdownTemplate` 的
    --   `Text` 本來就是 `HIGHLIGHT_FONT_COLOR`（白，註 ⓕ），沒有理由去碰。
    ------------------------------------------------------------
    local dd
    if pcall(function() dd = dialog.Dropdown end) and dd then
        Skin.Dropdown(dd, key .. ".Dropdown", "style1")
    else
        E.Missing(key .. ".Dropdown")
    end

    ------------------------------------------------------------
    -- 金額輸入框
    ------------------------------------------------------------
    local money
    if pcall(function() money = dialog.MoneyInputFrame end) and money then
        SkinMoneyInput(money, key .. "MoneyInputFrame", key .. ".MoneyInputFrame")
    else
        E.Missing(key .. ".MoneyInputFrame")
    end

    ------------------------------------------------------------
    -- 物品格（綁定確認、分解確認…）
    ------------------------------------------------------------
    local itemFrame
    if pcall(function() itemFrame = dialog.ItemFrame end) and itemFrame then
        -- 那張 `UI-QuestItemNameFrame` 是任務視窗來的羊皮紙名牌，放在深底上很突兀。
        -- 上面的字是**品質色**（`DisplayInfo` 每次 SetTextColor）＝資訊，不接管，
        -- 而品質色在 0.115 的底上本來就讀得出來。
        E.NeutralizeKeys(itemFrame, { "NameFrame" }, key .. ".ItemFrame")

        local item
        if pcall(function() item = itemFrame.Item end) and item then
            FlatItemButton(item, key .. ".ItemFrame.Item")
        else
            E.Missing(key .. ".ItemFrame.Item")
        end
    else
        E.Missing(key .. ".ItemFrame")
    end
end

local function Apply()
    for i = 1, POPUP_COUNT do
        local name = "StaticPopup" .. i
        local dialog = _G[name]
        if dialog then
            SkinDialog(dialog, name)
        else
            E.Missing(name)
        end
    end
end

E.Register{
    key   = "popup",
    addon = nil,                       -- Blizzard_StaticPopup_Game 沒有 LoadOnDemand
    title = L["Confirmation Popups"],
    apply = Apply,
}
