------------------------------------------------------------
-- 配方：就位確認（ReadyCheckFrame ＋ ReadyCheckListenerFrame）
--
-- ⚠⚠ **這一份是整包唯一開了「越界白名單」的配方**（第十三輪，使用者指示：
--   「就位確認照成熟同類實作的做法，只有就位確認開白名單做」）。
--   STYLE.md ⑦ 原本把 `ReadyCheckFrame` 列在 C 級。這一份照成熟同類實作搬了
--   「量訊息寬度 → 把彈窗撐寬 → 訊息／標題／按鈕置中重錨」的幾何邏輯，
--   那幾個動作越過了 ③ 的契約（讀尺寸、SetWidth、ClearAllPoints／SetPoint）。
--   每一個越界的動作都列在下面那張「越界白名單」裡，程式行尾一律帶
--   `-- skin-lint: readycheck-allowlist`（提議的新放行註記，由主控加進 lint）。
--   **白名單以外的部分照舊守契約**：零欄位寫入、按鈕零腳本、中和只用 alpha。
--
------------------------------------------------------------
-- ## 暴雪原始碼出處（12.1 live，Gethe/wow-ui-source）
--
--   Blizzard_FrameXML/Blizzard_FrameXML.toc:70-71  `Mainline\ReadyCheck.lua/.xml`
--       ⇒ 登入當下就載好（不是隨需載入），`addon` 欄位留 nil
--   Blizzard_FrameXML/Mainline/ReadyCheck.xml
--       :15  `ReadyCheckFrame`（`frameStrata="DIALOG" toplevel="true"`，323x100，
--            `CENTER y=-10`）—— **本身一張美術都沒有**，是個空殼
--       :21  `ReadyCheckListenerFrame`（`setAllPoints`，`layoutType =
--            PortraitFrameTemplate`）—— 名字會騙人：它不是「監聽器」，
--            **彈窗看得到的每一塊都在它身上**
--       :27  `Bg`（BACKGROUND −5，`UI-DialogBox-Background-Dark`）
--       :35  `ReadyCheckFrameText`（全域名，`GameFontNormal`＝暗金，寬 240，
--            錨 `TOP x=20 y=-37` —— x=20 是替左上角的頭像讓位）
--       :44  `NineSlice`（`NineSlicePanelTemplate`，版面取父框的 `layoutType`，
--            Blizzard_SharedXML/NineSlice.lua:243）
--       :45  `TitleContainer`（`TOPLEFT x=58 y=-1`／`TOPRIGHT x=-24 y=-1`，高 20）
--            ＋ :53 `TitleText`（parentKey，`GameFontNormal`，錨 `TOP y=-5` ＋ LEFT ＋ RIGHT）
--            ⇒ 標題的上緣在彈窗上緣往下 6（2026-09-24 起改成對標題帶中線置中，不再用這個值）
--       :63  `PortraitContainer` 底下 :70 `ReadyCheckPortrait`（54x54，半個露在外面）
--       :79  `ReadyCheckFrameYesButton`（`UIPanelButtonTemplate`，119x24，
--            `BOTTOMRIGHT → BOTTOM x=11 y=16`）
--       :92  `ReadyCheckFrameNoButton`（同上，`BOTTOMLEFT → BOTTOM x=22 y=16`）
--            兩顆的 OnClick 是 XML 內嵌的 `C_PartyInfo.ConfirmReadyCheck(...)`
--       :107 listener 的 OnShow：`PlaySound` ＋ `FlashClientIcon`
--   Blizzard_FrameXML/Mainline/ReadyCheck.lua
--       :23  `ShowReadyCheck(initiator, timeLeft)`：
--            :26 `ReadyCheckFrame:Show()` → :27 `UnitIsUnit("player", initiator)`
--            → 發起人 :28 `ReadyCheckListenerFrame:Hide()`；
--              其他人 :30 `SetPortraitTexture` → :43/:45 `SetFormattedText(…, initiator)`
--              → :47 `ReadyCheckListenerFrame:Show()`
--       :61  `ReadyCheckFrame_OnEvent`：`READY_CHECK` → `ShowReadyCheck`；
--            `READY_CHECK_FINISHED`／`GROUP_LEFT` → `self:Hide()`
--   Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua
--       :103 `ConfirmReadyCheck` —— `HasRestrictions = true`、
--            `SecretArguments = "AllowedWhenUntainted"`
--       :838 `READY_CHECK` —— `SecretInChatMessagingLockdown = true`、`SynchronousEvent = true`
--            ⇒ **首領戰／鑰石裡（聊天封鎖期間）`initiatorName` 是秘密字串**
--   Blizzard_APIDocumentationGenerated/UnitDocumentation.lua
--       :2321 `UnitIsUnit`、:563 `SetPortraitTexture` —— 都是
--            `SecretArguments = "AllowedWhenUntainted"`
--   Blizzard_SharedXML/SharedUIPanelTemplates.xml:3  `UIPanelButtonHighlightTexture`
--       ＝ ADD、無錨點（鋪滿）⇒ 可以走 primary（`Engine.ScriptlessButton` 的前提）
--
------------------------------------------------------------
-- ## 照成熟同類實作搬過來的東西（做法），與我們改掉的地方
--
-- | 項目 | 成熟同類實作 | 這一份 |
-- |---|---|---|
-- | 皮掛在哪 | **掛 listener，不掛外框**：外框是空殼，發起人看到的是「listener 被 Hide 的外框」，畫在外框上的底只有發起人看得到（一塊黑方塊） | 照抄。皮走 `Skin.Panel(listener)`（`Engine.RegionBackdrop`，建成 listener 自己的貼圖） |
-- | 時機 | **不在登入時做**（皮不能是觸發第一次排版的那個人）；重載時彈窗正開著就立刻做一次 | 照抄。**觸發點從 OnShow 改掉**，見下一節 |
-- | 頭像 | 拿掉，沒有選項：它是 `PortraitFrameTemplate` 的道具，半個露在外框外、靠雕花圓環嵌住；雕花一拿掉就是一顆飄在左上角的圓 —— 發起人的名字已經在訊息裡了 | 照抄（`PortraitContainer` 整個 alpha 0） |
-- | 標題與訊息 | 兩個都是 `GameFontNormal`，改白 | 照抄（`E.TextColor`，`T.text`） |
-- | 幾何 | `RC_*` 五個常數、`CaptureTopOffset`（2026-09-24 拿掉）、`FitReadyCheck`（見下面「幾何」） | 照抄，常數一字不改；兩處修正見「幾何」 |
-- | 按鈕 | 一般皮按鈕 | **零腳本**（`Engine.ScriptlessButton`）：「就位」primary、「未就位」secondary。按鈕本身一支腳本都不掛 |
-- | 第二次就位確認重用開著的框 | 在 `ReadyCheckFrameText` 上 `hooksecurefunc(fs, "SetText"/"SetFormattedText", …)` | **不做**：那是在暴雪物件上寫欄位（契約最硬的那一條）。改由 `READY_CHECK` 事件覆蓋，見下一節 |
--
------------------------------------------------------------
-- ## 時機：為什麼**不**掛 OnShow，改用自己的事件框 ＋ 延一幀
--
-- 查了 `ShowReadyCheck` 的整條路（上面的出處）之後，兩支 OnShow 都不能掛：
--
--   * `ReadyCheckFrame` 的 OnShow 在 :26 同步觸發 —— **緊接著**是 :27 的
--     `UnitIsUnit("player", initiator)` 與 :30 的 `SetPortraitTexture(…, initiator)`。
--     兩支都是 `AllowedWhenUntainted`，而 `initiator` 在聊天封鎖期間（首領戰、
--     整趟鑰石）是**秘密字串**。我們的 hook 只要在 :26 跑過一行，這條執行就是我們的
--     （`.claude/notes/wow-121-addon-code-in-secure-stack.md`：函式返回後污染還留著），
--     :27 就會以「Secret values are only allowed during untainted execution」炸在
--     暴雪的檔案裡、點名我們。**延一幀救不了**：延的是 hook 的內容，hook 本身
--     （排 timer 那一行）還是跑在 :26 裡面。
--   * `ReadyCheckListenerFrame` 的 OnShow 看起來安全（:47 是最後一行），但
--     **父框顯示時子框的 OnShow 也會觸發**：上一次就位確認把 listener 的 shown 旗標
--     留在 true，下一次你是發起人時，:26 的 `ReadyCheckFrame:Show()` 會連帶觸發
--     listener 的 OnShow —— 又回到上面那條 :27 之前的路。
--
-- ⇒ 改成**自己的事件框聽 `READY_CHECK`**，處理器的全部內容是 `C_Timer.After(0, Run)`。
--   * 那是我們自己的框收到的事件，派送給每個框是各自獨立的呼叫，不在
--     `ShowReadyCheck` 裡面；真正動手的 `Run` 在下一幀的 timer 堆疊裡跑，
--     那時暴雪的 `ShowReadyCheck` 早就跑完、`ReadyCheckFrameText` 也已經寫好字。
--   * 同一個事件也涵蓋成熟同類實作靠 SetText 勾去補的「開著的框被重用」—— 零欄位寫入。
--   * 前提：`READY_CHECK` 是**伺服器廣播**的（發起人自己也是收廣播才彈窗），不是
--     `DoReadyCheck` 在呼叫當下同步派送的 —— 這一點是推論，待實機驗證。
--
-- **戰鬥閘**：`ReadyCheckFrame` 與它的子框在 XML 裡**沒有任何 secure 模板**
-- （兩顆按鈕是 `UIPanelButtonTemplate`，不是 `SecureActionButtonTemplate`），
-- 所以沒有保護、戰鬥中也可以重排。保險起見幾何那一段仍然先問
-- `Engine.ProtectionOf`：任一個要動的物件是保護框而且在戰鬥中 ⇒ 這一次不重排，
-- 下一次 `READY_CHECK` 再試（失敗方向＝暴雪原本的版面，不會壞）。
--
------------------------------------------------------------
-- ## 幾何（照抄 `FitReadyCheck`，兩處修正）
--
--   1. **寬度**：暴雪只替「名字」留了寬度，大多數伺服器的「<名字>-<伺服器> 發起了
--      就位確認。」會在句中斷行。量訊息寬度、把彈窗撐寬到放得下一行 ——
--      **永遠從原始寬度重算**（名字長的那一次不會把彈窗永久撐寬），而且上限是原寬的
--      `RC_MAX_GROW` 倍（離譜的名字就換行，不衝出螢幕）。
--   2. **置中**：頭像拿掉之後，暴雪替頭像留的左內縮（訊息 x=20、標題 x=58、按鈕那一對
--      的中點偏右約 16）變成左邊一個洞 ⇒ 標題、訊息、按鈕全部置中。
--      垂直方向「標題帶→訊息→按鈕→下緣」三段等距（2026-09-24；原本訊息上緣 −30、按鈕離下緣 16）。
--      按鈕對彈窗的 `BOTTOM` 對稱錨（各離中線半個間距），自動跟著 SetWidth 走。
--
--   **修正 ①：秘密訊息不放棄重排。** 聊天封鎖期間訊息裡的名字是秘密字串，量到的寬度
--     是秘密數字。成熟同類實作量到秘密值就整段 return —— 結果頭像已經拿掉、版面卻停在
--     「替頭像內縮」的原樣。這裡改成**不讀那個值、用原始寬度照樣置中**
--     （當傳遞者不當讀取者：秘密值一律過 `Secret.PlainNumber`，拿不到就當作不知道）。
--   **修正 ②：量寬用 `GetUnboundedStringWidth`**（有的話）。重排過一次之後訊息的寬度
--     被我們設成 `want − pad`，`GetStringWidth` 量到的可能是**被夾住的**寬度，下一個
--     更長的名字就撐不開了。沒有這一支的客戶端退回 `GetStringWidth`。
--   **少抄的一塊**：它另外量了一次訊息自己的 TOP 偏移，但只拿來當「版面好了沒」的閘、
--     數值從來沒用到。這裡的閘改成「原始寬度量得到」，少一次讀取。
--
------------------------------------------------------------
-- ## 越界白名單（這一份配方越過 STYLE.md ③ 契約的全部動作）
--
-- 共同條件：只在 `Run`（下一幀的 timer 堆疊）裡做；對象全部是「就位確認」這一組
-- **沒有保護、沒有 secure 子物件、暴雪 Lua 零處讀回其尺寸或錨點**的框
-- （ReadyCheck.lua 全檔沒有 GetWidth／GetPoint／GetLeft，只有 :43/:45 寫訊息字）；
-- 每一個呼叫都包 `pcall`；`MiliUI_Skin_DB.relayout = false` 整批關掉（皮照上）。
--
-- | # | 動作 | 對象 | 違反哪一條 | 為什麼安全 | 成熟同類實作原本怎麼寫 |
-- |---|---|---|---|---|---|
-- | ① | `GetWidth()` | `ReadyCheckFrame` | 讀尺寸 | 只讀一次當基準（`geo.baseW`）；外框錨在 UIParent、寬度是 XML 寫死的 323，不會是秘密值，仍過 `PlainNumber` | 同（存在它自己的框資料表） |
-- | ② | ~~`GetLeft/GetRight/GetTop()`~~ | —— | —— | **2026-09-24 拿掉**：標題改對標題帶中線置中（⑦），不必再量暴雪的標題位置 | 量標題相對上緣的 y |
-- | ③ | `GetUnboundedStringWidth()`／`GetStringWidth()`／`GetStringHeight()`（2026-09-24 加） | `ReadyCheckFrameText` | 讀文字寬度／高度 | 可能是秘密數字（名字是秘密字串時）⇒ 過 `PlainNumber`，秘密就**不讀**、改用原始寬度（修正 ①） | 只用 `GetStringWidth`，秘密就整段 return |
-- | ④ | `SetWidth(want)` | `ReadyCheckFrame` | 改尺寸 | 沒有保護；暴雪不讀回；listener `setAllPoints` 跟著變寬，皮（listener 自己的貼圖）也跟著走 | 同 |
-- | ⑤ | `SetWidth(want − pad)` | `ReadyCheckFrameText` | 改尺寸 | 只影響換行寬度；XML 原值 240 | 同 |
-- | ⑥ | `ClearAllPoints` ＋ `SetPoint("TOP", fr, "TOP", 0, −(標題帶下緣 ＋ 空隙))` | `ReadyCheckFrameText` | 重排 | FontString 區域、不是框；暴雪只在 XML 錨過一次 | 同 |
-- | ⑦ | `ClearAllPoints` ＋ `SetPoint("CENTER", fr, "TOP", 0, −(1 ＋ TITLE_BAR_H/2))` | `TitleContainer.TitleText` | 重排 | 同上；`TitleContainer` 本身不動 | 同 |
-- | ⑧ | `ClearAllPoints` ＋ `SetPoint("BOTTOMRIGHT"/"BOTTOMLEFT", fr, "BOTTOM", ∓6, 16)` | 兩顆按鈕 | 重排 | 不是 secure 按鈕；y=16 照 XML；錨點不影響點擊派送（點擊路徑上沒有我們的 Lua） | 同 |
--
-- ⚠ **不在白名單上、而且刻意沒做的**：在暴雪框／FontString 上 `hooksecurefunc`
--   （成熟同類實作勾了訊息的 SetText）、任何 `HookScript`（理由見「時機」）、
--   在暴雪框上存狀態（存在本檔的 local `geo`）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- **hook：無。**（`hooksecurefunc` 0 支、`HookScript` 0 支）
-- **事件框：1 個，自己的**（`READY_CHECK`），處理器只有 `C_Timer.After(0, Run)`，
--   事件參數（可能是秘密的名字）一個都不碰。
-- **寫入暴雪欄位：無。**
-- **讀暴雪物件**：parentKey／全域名找區域、`IsShown()`（外框，只在 `apply` 讀一次：
--   重載時彈窗正開著就立刻做；純 C 端布林、過 `Secret.ToBool`）、以及白名單 ①③。
--
-- | 物件 | 動作 | 備註 |
-- |---|---|---|
-- | listener 的 `Bg`／`NineSlice`／`PortraitContainer` | `SetAlpha(0)` | `SetPortraitTexture` 每次重設頭像材質，alpha 撐得住 |
-- | listener | `Engine.RegionBackdrop` 建底與邊（提示皮：`T.tipFill` ＋ 1px `T.Accent()`） | 不是 layout host ⇒ 直接建成它自己的 BACKGROUND 貼圖，DIALOG strata 的問題不存在 |
-- | listener | `Skin.TitleBar` 標題帶（`fillInset` ＋ 下緣髮絲線，同樣是它自己的貼圖） | 2026-09-24 試做 |
-- | `TitleContainer.TitleText`、`ReadyCheckFrameText` | `SetTextColor`（白） | 暴雪只 `SetFormattedText`，不重設顏色 ⇒ 做一次就好 |
-- | 兩顆按鈕的 `Left`/`Right`/`Middle` | `SetAlpha(0)` | |
-- | 兩顆按鈕 | `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`（`Engine.ScriptlessButton`） | **零 HookScript**；`ConfirmReadyCheck` 是 `AllowedWhenUntainted`，點擊那一次的執行裡一行我們的 Lua 都沒有 |
-- | 同上 | overlay（`Engine.Overlay`） | 無腳本、不吃滑鼠 |
-- | 白名單 ①～⑧ | 見上表 | |
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * `ReadyCheckFrame` 外框的底 —— 它本來就沒有美術；畫上去的東西只有發起人看得到。
-- * `ReadyCheckStatusTemplate`（單位框上的 ✓／✗ 圖示）—— 那是單位框的一部分（C 級）。
-- * `LFGDungeonReadyDialog`／`LFDRoleCheckPopup` —— 這一輪的特許只開給就位確認。
-- * 標題帶（提示皮沒有標題帶，同確認彈窗與 ESC 選單）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L
local S = ns.Secret

local KEY = "ReadyCheckFrame"

-- 幾何常數：照抄成熟同類實作，一字不改
local RC_PAD      = 24   -- 訊息左右各留的內距
local RC_MAX_GROW = 2    -- 上限：最多撐到暴雪原寬的兩倍
local RC_BTN_GAP  = 12   -- 兩顆按鈕之間
local RC_GAP_MIN  = 4    -- 三段空隙的下限（長名字換兩行時）

-- 標題帶高度（像素）：比其他視窗的標題帶高 4（2026-09-24 使用者試看）。
-- 標題字對這條帶子的中線置中（`Fit` 的 ⑦），不再沿用暴雪量出來的上緣偏移。
local TITLE_BAR_H = T.titleBarHeight + 4

-- 垂直版面（2026-09-24）：標題帶下緣 → 訊息、訊息 → 按鈕、按鈕 → 彈窗下緣
-- **三段空隙一樣大**。彈窗高度不動，扣掉標題帶、訊息、按鈕之後平分成三份；
-- 按鈕原本離下緣 16（暴雪 ReadyCheck.xml:82,95），現在跟著空隙走。
-- 彈窗高 100（ReadyCheck.xml:15，暴雪 Lua 零處 SetHeight）、按鈕高 24（:80,93）
local RC_FRAME_H = 100
local RC_BTN_H   = 24

-- 量到的東西存在這裡，**不存在暴雪框上**
local geo = {}

local function Field(owner, k)
    if type(owner) ~= "table" then return nil end
    local v
    if pcall(function() v = owner[k] end) then return v end
    return nil
end

------------------------------------------------------------
-- 零腳本按鈕（跟 PlayerSpells.lua／Professions.lua 同一支）
-- TODO(升格): 第四份配方也用到了 —— 該收成 `Skin.ScriptlessButton`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })   -- 先建 overlay 再中和（避免隱形按鈕）
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant, key)   -- **不掛腳本**
    return ov
end

------------------------------------------------------------
-- 靜態的皮（只做一次）
------------------------------------------------------------
local skinned = false

local function SkinOnce()
    if skinned then return end
    local listener = _G.ReadyCheckListenerFrame
    if not E.Usable(listener, KEY .. ".Listener") then return end

    -- 先建底再中和：底建不起來就保留暴雪原樣（比「沒底的彈窗」好）
    local ov = Skin.Panel(listener, KEY, { fill = T.tipFill, border = { T.Accent() } })
    if not ov then return end
    E.NeutralizeKeys(listener, { "Bg", "NineSlice", "PortraitContainer" }, KEY .. ".Listener")
    -- 標題帶（2026-09-24 試做）：標題與訊息同為白字，層級只剩位置在分。暴雪原版的
    -- 標題區就是 Bg 上緣（y=-23，ReadyCheck.xml:29）以上那一條，跟其他視窗的標題帶同一格
    -- ⇒ 直接用 `Skin.TitleBar`（listener 自己的貼圖，蓋不住任何內容）。
    Skin.TitleBar(listener, KEY, TITLE_BAR_H)

    local title = Field(Field(listener, "TitleContainer"), "TitleText")
    if title then
        E.TextColor(title, T.text, KEY .. ".TitleText")
    else
        E.Missing(KEY .. ".TitleContainer.TitleText")
    end
    E.TextColor(_G.ReadyCheckFrameText, T.text, "ReadyCheckFrameText")

    -- 成對：「就位」＝確認 ⇒ primary；「未就位」＝拒絕 ⇒ secondary（STYLE ④ 判準 1）
    ScriptlessButton(_G.ReadyCheckFrameYesButton, "ReadyCheckFrameYesButton", "primary")
    ScriptlessButton(_G.ReadyCheckFrameNoButton, "ReadyCheckFrameNoButton", "secondary")

    skinned = true
end

------------------------------------------------------------
-- 幾何（越界白名單 ①～⑧）
------------------------------------------------------------
-- 任一個要動的物件是保護框、而且在戰鬥中 ⇒ 這次不重排（XML 裡沒有 secure 模板，
-- 正常情況永遠放行；這一道只防「將來暴雪把它改成 secure」）
local function GeometryAllowed(list)
    if not InCombatLockdown() then return true end
    for _, obj in ipairs(list) do
        if obj and E.ProtectionOf(obj) ~= "none" then return false end
    end
    return true
end

local function MeasureMessage(fs)
    local ok, v = pcall(function()
        if type(fs.GetUnboundedStringWidth) == "function" then
            return fs:GetUnboundedStringWidth()   -- skin-lint: readycheck-allowlist ③
        end
        return fs:GetStringWidth()                -- skin-lint: readycheck-allowlist ③
    end)
    if not ok then return nil end
    return S.PlainNumber(v)                       -- 秘密 ⇒ nil ⇒ 當作不知道（修正 ①）
end

-- 訊息的高度：秘密（名字是秘密字串時）就退回字型大小 —— 一行的高度，
-- 換成兩行時只是空隙算得稍大，不會重疊。
local function MeasureMessageHeight(fs)
    local ok, v = pcall(function() return fs:GetStringHeight() end)   -- skin-lint: readycheck-allowlist ③
    v = ok and S.PlainNumber(v) or nil
    if v and v > 0 then return v end
    local okF, _, size = pcall(function() return fs:GetFont() end)
    return okF and S.PlainNumber(size) or nil
end

local function Fit()
    if ns.db and ns.db.relayout == false then return end

    local fr = _G.ReadyCheckFrame
    if not E.Usable(fr, KEY) then return end
    local listener = _G.ReadyCheckListenerFrame
    local fs = _G.ReadyCheckFrameText
    local title = Field(Field(listener, "TitleContainer"), "TitleText")
    local yes, no = _G.ReadyCheckFrameYesButton, _G.ReadyCheckFrameNoButton

    if not GeometryAllowed({ fr, listener, yes, no }) then return end

    if not geo.baseW then
        local ok, w = pcall(function() return fr:GetWidth() end)   -- skin-lint: readycheck-allowlist ①
        w = ok and S.PlainNumber(w) or nil
        if not w or w <= 0 then return end
        geo.baseW = w
    end

    local pad = RC_PAD * 2
    local want = geo.baseW
    local need = fs and MeasureMessage(fs)
    if need then
        want = math.max(geo.baseW, math.min(need + pad, geo.baseW * RC_MAX_GROW))
    end

    pcall(function() fr:SetWidth(want) end)                            -- skin-lint: readycheck-allowlist ④

    -- 三段等距（見 RC_FRAME_H 上面的說明）。訊息高度要在 SetWidth 之後量（換行跟著寬度變）
    local top = ns.P.Scale(1 + TITLE_BAR_H)                -- 標題帶下緣，離彈窗上緣
    local textH
    if fs then
        pcall(function() fs:SetWidth(want - pad) end)                  -- skin-lint: readycheck-allowlist ⑤
        textH = MeasureMessageHeight(fs)
    end
    local gap = math.max(RC_GAP_MIN, (RC_FRAME_H - top - RC_BTN_H - (textH or 0)) / 3)
    if fs then
        pcall(function() fs:ClearAllPoints() end)                      -- skin-lint: readycheck-allowlist ⑥
        pcall(function() fs:SetPoint("TOP", fr, "TOP", 0, -(top + gap)) end)   -- skin-lint: readycheck-allowlist ⑥
    end

    if title then
        -- 帶子從面板的邊（1px）往下 TITLE_BAR_H ⇒ 中線在 1 ＋ H/2（Skin.TitleBar）
        local dy = -ns.P.Scale(1 + TITLE_BAR_H / 2)
        pcall(function() title:ClearAllPoints() end)                   -- skin-lint: readycheck-allowlist ⑦
        pcall(function() title:SetPoint("CENTER", fr, "TOP", 0, dy) end)   -- skin-lint: readycheck-allowlist ⑦
    end

    if yes and no then
        local half = RC_BTN_GAP / 2
        pcall(function() yes:ClearAllPoints() end)                     -- skin-lint: readycheck-allowlist ⑧
        pcall(function() yes:SetPoint("BOTTOMRIGHT", fr, "BOTTOM", -half, gap) end)   -- skin-lint: readycheck-allowlist ⑧
        pcall(function() no:ClearAllPoints() end)                      -- skin-lint: readycheck-allowlist ⑧
        pcall(function() no:SetPoint("BOTTOMLEFT", fr, "BOTTOM", half, gap) end)      -- skin-lint: readycheck-allowlist ⑧
    end
end

------------------------------------------------------------
-- 觸發：自己的事件框（理由見檔頭「時機」）
------------------------------------------------------------
local broken = false

local function Run()
    if broken then return end
    local ok, err = pcall(function()
        SkinOnce()
        -- 皮沒上成就不重排：頭像還在的時候置中會把訊息壓到頭像底下
        if skinned then Fit() end
    end)
    if not ok then
        broken = true
        E.NoteBrokenHook(KEY .. ":READY_CHECK")
        ns.ReportError(err)
    end
end

local function InstallHooks()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("READY_CHECK")
    -- 處理器的全部內容：延一幀。事件參數（可能是秘密的名字）一個都不碰。
    ev:SetScript("OnEvent", function()   -- skin-lint: own-frame
        if broken then return end
        C_Timer.After(0, Run)
    end)
end

local function Apply()
    -- 登入時**不**上皮（皮不能是觸發第一次排版的那個人）。
    -- 唯一的例外：重載的當下彈窗正開著 —— 那一次等不到 READY_CHECK。
    local fr = _G.ReadyCheckFrame
    if not fr then
        E.Missing(KEY)
        return
    end
    local ok, shown = pcall(function() return fr:IsShown() end)
    if ok and S.ToBool(shown) == true then Run() end
end

E.Register{
    key   = "readycheck",
    addon = nil,                       -- Blizzard_FrameXML，登入時就載好
    title = L["Ready Check"],
    hooks = InstallHooks,
    apply = Apply,
}
