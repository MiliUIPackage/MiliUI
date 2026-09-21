------------------------------------------------------------
-- 配方：ESC 選單（GameMenuFrame）
--
-- ⚠⚠ **這一份是特許，規矩比其他配方嚴。**
--   STYLE.md ⑦ 原本沒有這個視窗（它的按鈕通往編輯模式、設定、商城、登出 ——
--   「從被污染的執行進編輯模式」是全遊戲最經典的 taint 災難，
--   `.claude/notes/wow-121-addon-code-in-secure-stack.md` 入口 8）。
--   使用者點名要做，所以改成**只做純視覺、零 hook 進點擊路徑**的特許：
--     1. **一個按鈕上都不掛 `HookScript`**（連 OnEnter／OnLeave 都不掛）。
--        滑過一律交給引擎換 Highlight 貼圖的長相（`Engine.ButtonStates`）。
--        ⚠ 這裡還有一個硬理由：`MainMenuFrameMixin:AddButton` **每次**都
--          `SetScript("OnEnter"/"OnLeave", …)`（Blizzard_SharedXML/Shared/Frame/
--          MainMenuFrameTemplates.lua:46,54,58,59）—— `HookScript` 掛上去也會被
--          下一次開選單整個蓋掉（`.claude/notes/wow-setscript-clobbers-hookscript.md`
--          的反向版本），是個**靜默失效**的作法。
--     2. 唯一的 hook 是 `GameMenuFrame:HookScript("OnShow", …)`，而且它的內容
--        **只有一行 `C_Timer.After(0, …)`**：延一幀之後才去掃按鈕，
--        我們的程式一行都不會跑在 `ShowUIPanel → OnShow → InitButtons` 那一段裡面。
--     3. 零欄位寫入（**特別是不 `hooksecurefunc(GameMenuFrame, "InitButtons")`**
--        —— 那會把 `GameMenuFrame.InitButtons` 這個欄位寫掉，違反「暴雪物件零欄位
--        寫入」；`HookScript` 是 C 層的腳本後掛，不寫任何 Lua 欄位）。
--
------------------------------------------------------------
-- ## 暴雪原始碼出處（12.1 live，Gethe/wow-ui-source）
--
--   Blizzard_GameMenu/Shared/GameMenuFrame.xml:4
--       `GameMenuFrame`（mixin `GameMenuFrameMixin`，← `MainMenuFrameTemplate,
--       CallbackRegistrantTemplate`，`toplevel="true" frameStrata="DIALOG"`）
--       ＋ `NewOptionsFrame`(:18)／`NewExternalEventFrame`(:23)／`EditModeNotification`(:28)
--   Blizzard_SharedXML/Mainline/Frame/MainMenuFrameTemplates.xml:18
--       `MainMenuFrameTemplate`（← **`VerticalLayoutFrame`**，`buttonTemplate` ＝
--       `MainMenuFrameButtonTemplate`，topPadding 48／bottomPadding 34／
--       left/rightPadding 28）
--       :35  `Border`（← `DialogBorderTemplate`，`ignoreInLayout`）
--       :40  `Header`（← `DialogHeaderTemplate`，`ignoreInLayout`，錨 `TOP y=11`）
--   同檔 :11  `MainMenuFrameButtonTemplate`（← `BigRedThreeSliceButtonTemplate`，200x36）
--       NormalFont／HighlightFont **已經是 `GameFontHighlightLarge`（白）**、
--       DisabledFont `GameFontDisableLarge`（:13-15）⇒ **字型一個都不用換**
--   Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:4,61
--       `ThreeSliceButtonTemplate` → BACKGROUND 三張 `Left`/`Center`/`Right`
--       （注意是 **`Center`** 不是 `Middle`）；**沒有 PushedTexture**
--       `BigRedThreeSliceButtonTemplate` → `atlasName = "128-RedButton"`
--   Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.lua:83
--       `ThreeSliceButtonMixin:UpdateButton` 每次狀態改變都把三張 `SetAtlas`
--       ⇒ **一定要 alpha 中和**；:20 `InitButton` 的 `SetHighlightAtlas`
--       只在 OnLoad 跑一次 ⇒ 白 8% 撐得住
--   Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml:11,69
--       `DialogHeaderTemplate` → `LeftBG`/`RightBG`/`CenterBG`（UI-Frame-DiamondMetal-
--       Header-*）＋ `Text`（`GameFontNormal`，被 `SetHeaderFont` 換成
--       `GameFontNormalMed1`，**暗金**）；`DialogBorderTemplate` → `Bg`
--       （`UI-DialogBox-Background`）＋ `NineSlicePanelTemplate` 的八片
--   Blizzard_SharedXML/Mainline/NineSliceLayouts.lua:157  `Dialog` 版面
--       ⇒ 只有四個角 ＋ 四條邊，**沒有 `Center`**（所以中和清單只列八個）
--   Blizzard_SharedXML/NineSlice.lua:40,135  九片一律存成 `container[pieceName]`
--   Blizzard_SharedXML/Shared/Frame/MainMenuFrameTemplates.lua:14,25
--       `buttonPool = CreateFramePool("BUTTON", self, self.buttonTemplate, …)`；
--       `AddButton` 每次 `Acquire()` ⇒ 按鈕是**第一次開選單才建**的
--   Blizzard_GameMenu/Shared/GameMenuFrame.lua:57,68  `OnShow` → `self:InitButtons()`
--   Blizzard_GameMenu/Blizzard_GameMenu_Mainline.toc  **沒有 `## LoadOnDemand`**
--
------------------------------------------------------------
-- ## 時機：為什麼是 `HookScript("OnShow")` ＋ 延一幀
--
-- 按鈕是 `buttonPool:Acquire()` 借出來的，數量會變（商城／獎勵／編輯模式／評分
-- 那幾顆是條件式的），所以「登入時掃一次」不夠。可用的掛點有三條，逐一評估過：
--
--   (a) 我們自己的事件框 —— **ESC 選單沒有專屬的遊戲事件**。
--       `GameMenuFrameMixin:OnShow` 最後那一行 `EventRegistry:TriggerEvent(
--       "GameMenuFrame.Shown")`（GameMenuFrame.lua:72）是暴雪的 callback 表，
--       要接就得把我們的函式註冊進去 —— STYLE.md ③ 明文禁止。⇒ 走不通。
--   (b) `hooksecurefunc(GameMenuFrame, "InitButtons", …)` ——
--       `GameMenuFrameMixin` 是 `mixin=` 在 frame **建立時**拷貝上去的（陷阱 4），
--       所以只能勾 frame 自己那份副本，而那等於 `GameMenuFrame.InitButtons = 包裝函式`
--       ⇒ **在暴雪框上寫欄位**，契約最硬的那一條。⇒ 不走。
--   (c) `GameMenuFrame:HookScript("OnShow", …)` ← **選這條**。
--       `HookScript` 在白名單裡（STYLE.md ③），它是 C 層的腳本後掛、不寫 Lua 欄位，
--       接觸面只有我們指名的這一個框，而且**不在任何按鈕的點擊路徑上**
--       （OnShow 是「選單被打開」那一次）。
--       ⚠ hook 的內容只有 `C_Timer.After(0, Scan)` —— 真正會建 overlay 的那一段
--         跑在**下一幀的 timer 堆疊**裡，不在 `ShowUIPanel → OnShow → InitButtons`
--         這條暴雪執行流裡面（`wow-121-addon-code-in-secure-stack.md` 的入口 1／2）。
--       ⚠ 套組本體在這個框上已經有一支同形狀的 `HookScript("OnShow")`（那支
--         在 ESC 選單加了自己的兩顆按鈕），而且已經實機跑了很久 ——
--         這條路在這個套組裡是**有前例**的，不是新的接觸面型別。
--
-- **戰鬥閘**：`Scan` 第一行就問 `InCombatLockdown()`，戰鬥中直接返回。
-- 代價是「戰鬥中第一次開 ESC 選單看到的是原生紅按鈕」，脫戰後下一次開就補上。
-- 這是刻意選的失敗方向：少一次上皮，換「戰鬥中一次都不碰這個框」。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- **hook：`GameMenuFrame:HookScript("OnShow", fn)` 一支**（`hooksecurefunc` 0 支）。
--   `fn` 的全部內容是：查一個 broken 旗標 → `C_Timer.After(0, Scan)`。
-- **寫入暴雪欄位：無。**
-- **讀暴雪物件**：`GameMenuFrame:GetChildren()`（讀結構，讀取例外表上有）、
--   每個 child 的 `GetObjectType()`、以及「有沒有 `Left`/`Center`/`Right` 這三個
--   parentKey」——跟 `Skin.TabSystemAll` 用「有沒有 `RotatedTextures`」認分頁同一條。
--   **沒有**讀 `buttonPool`、**沒有**讀文字／尺寸／錨點、**沒有**讀 `atlasName`。
--
-- | 物件 | 動作 | 為什麼不會進到按鈕的點擊執行鏈 |
-- |---|---|---|
-- | `GameMenuFrame.Border` 的八片 ＋ `Bg` | `SetAlpha(0)` | 一次性的區域屬性寫入，跑在我們自己的 `PLAYER_LOGIN`／timer 堆疊裡 |
-- | `GameMenuFrame` | `CreateFrame` 一個 overlay（parent 指定 `Border`，見下） | 建立時定好錨點與層級，**沒有腳本**（陷阱 1）、**不吃滑鼠** |
-- | `GameMenuFrame.Header.LeftBG`/`.RightBG`/`.CenterBG` | `SetAlpha(0)` | 同上 |
-- | `GameMenuFrame.Header.Text` | `SetTextColor` | 不屬於按鈕的 FontString（白名單）。`SetHeaderFont` 只在 `MainMenuFrameMixin:OnLoad` 跑一次，之後沒有人重設 ⇒ 不必重申 |
-- | 每顆選單按鈕的 `Left`/`Center`/`Right` | `SetAlpha(0)` | 一次性；`UpdateButton` 之後重設 atlas 也蓋不掉 alpha |
-- | 每顆選單按鈕的 `GetHighlightTexture()` | `SetColorTexture(1,1,1,0.08)` | **只換那張貼圖長什麼樣**；顯示／隱藏仍然由 C 端在滑鼠進出時決定 ⇒ 滑過與點擊的派送裡一行我們的 Lua 都沒有 |
-- | 每顆選單按鈕 | `CreateFrame` 一個 overlay | 同上，無腳本、不吃滑鼠 |
--
------------------------------------------------------------
-- ## 兩個實作上的講究
--
-- **1. overlay 的 parent 一定要指定成 `GameMenuFrame.Border`。**
--   `MainMenuFrameTemplate` 繼承 `VerticalLayoutFrame` ⇒ 它是 layout host，
--   `Engine.SafeParent` 會一路爬到 `UIParent`（陷阱 2）。可是 `GameMenuFrame` 是
--   `frameStrata="DIALOG"`，掛在 `UIParent` 底下的 overlay 是 MEDIUM
--   ⇒ **皮會整塊掉到選單後面**。`Border` 是 `DialogBorderTemplate`
--   （`useParentLevel`，`ignoreInLayout`）—— 不是 layout host、在選單的子樹裡，
--   正好。找不到就整塊外框不畫並記一筆 missing。
--
-- **2. 面板的矩形往上長 11，把標題吃進來。**
--   `Header` 錨在 `TOP y=+11`、高 39（DialogTemplates.xml:12），標題文字錨在
--   `Header` 的 `TOP y=-13` ⇒ 文字上緣在「選單上緣 −2」。雕花牌一中和，標題就
--   貼在我們那條 1px 上邊線上，只差 2 點。往上長 11（＝ Header 的 y 偏移，
--   **常數從 XML 抄，不量測**）之後標題離上緣 13，跟一般設定視窗的標題內縮一致，
--   而且套組本體掛在 `GameMenuFrame` `TOPRIGHT` 外側 `y=+13` 的那兩顆按鈕仍然在
--   我們的矩形之上 2 點，不會被蓋到。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **按鈕的字型物件** —— `MainMenuFrameButtonTemplate` 的 NormalFont 本來就是
--   `GameFontHighlightLarge`（白），Disabled 是 `GameFontDisableLarge`（灰）。
--   那正好是「狀態只換明暗」，換掉反而把「這顆不能按」的訊號拿掉。
-- * `NewOptionsFrame` / `NewExternalEventFrame`（「新」標記）、`EditModeNotification`
--   —— 是資訊，不是裝飾。
-- * **暴雪的按下態** —— `ThreeSliceButtonTemplate` 沒有 PushedTexture，按下是靠換
--   那三張的 atlas 表示的，而它們已經 alpha 0 ⇒ 按下沒有視覺（註 ⓒ 的同一條）。
-- * **套組本體加在這個框上的兩顆按鈕**（設定入口與重載鈕，全域名
--   `MiliUI_GameMenuButton` / `MiliUI_GameMenuReloadButton`）—— 它們**本來就已經是
--   深色皮**（套組自己的樣式層畫的），再套一次只會多一圈邊。伴隨元件規則的第 2 條：
--   沒有就靜默跳過、有也不呼叫它的函式、不寫它的欄位。這裡連 skin 都不需要。
--   ⚠ 認人不靠名字靠結構：下面的 `IsMenuButton` 要求 `Left`/`Center`/`Right`
--     三個 parentKey 都在，那兩顆是 `BackdropTemplate` 做的，天然排除。
------------------------------------------------------------
local _, ns = ...

local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local KEY = "GameMenuFrame"

-- `DialogBorderTemplate` 的九宮格。`Dialog` 版面沒有 `Center`
-- （NineSliceLayouts.lua:157）⇒ 不要列，列了只會在 `/mskin debug` 多一筆假的 missing。
local DIALOG_BORDER_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
    "Bg",
}

-- `Header` 錨在 `TOP y=11`（MainMenuFrameTemplates.xml:46）⇒ 面板往上長這麼多，
-- 標題就落在面板裡面。常數從 XML 抄，不量測。
local HEADER_OVERHANG = 11

------------------------------------------------------------
-- 平面按鈕（`MainMenuFrameButtonTemplate`／`ThreeSliceButtonTemplate`）
--
-- ⚠ **這一支是配方自己的 local，不用 `Skin.Button`。** 兩個理由：
--   (1) `Skin.Button` 中和的是 `Left`/`Right`/`Middle`，三片式按鈕的中間那張叫
--       **`Center`**（ThreeSliceButtonTemplate.xml:33）—— 直接套會留下中間一片紅。
--   (2) 第五輪之後 `Skin.Button` 會替一般按鈕掛 `HookScript` 的滑過態，
--       而這個視窗的特許條件是「零 HookScript 在任何按鈕上」。
--
-- TODO(升格): 「三片式按鈕」在 Skins/AddonList.lua 也有一份 local（STYLE.md ⑤ 的
--   `ThreeSliceButtonTemplate` 那一列）。兩份都定下來之後就該升格成
--   `Skin.ThreeSliceButton`，順便把「要不要掛滑過腳本」做成 opts。
------------------------------------------------------------
local THREE_SLICE_ART = { "Left", "Center", "Right" }

local function FlatThreeSliceButton(btn, key)
    if not E.Usable(btn, key) then return end

    -- ⚠ **先建 overlay 再中和。** `Engine.Overlay` 對保護框會回 nil（並記進
    --   `/mskin debug`），倒過來寫的話那顆按鈕會變成「美術被中和掉、又沒有東西補」
    --   的一顆隱形按鈕 —— 而 ESC 選單的按鈕是「登出／退出遊戲」，看不見比沒換皮嚴重。
    local ov = E.Overlay(btn, { key = key })
    if not ov then return end

    E.NeutralizeKeys(btn, THREE_SLICE_ART, key)
    -- 第三個參數不給 ⇒ 只換 Highlight 的長相，Pushed 不上色（這個模板也沒有 Pushed）
    E.ButtonStates(btn, key)

    E.Paint(ov, T.fill, T.border)
end

------------------------------------------------------------
-- 認人：這個 child 是不是一顆選單按鈕？
--
-- **只問結構**（跟 `Skin.TabSystemAll` 用「有沒有 `RotatedTextures`」認分頁同一條）：
-- 是 Button，而且 `Left`/`Center`/`Right` 三個 parentKey 都在。
-- 這樣既認得出池子借出來的按鈕，又天然排除掉套組本體加的那兩顆
-- （那兩顆是 `BackdropTemplate` 做的，沒有這三個 parentKey）。
------------------------------------------------------------
local function IsMenuButton(child)
    if type(child) ~= "table" then return false end
    if type(child.GetObjectType) ~= "function" then return false end
    local ok, kind = pcall(child.GetObjectType, child)
    if not ok or kind ~= "Button" then return false end

    for _, k in ipairs(THREE_SLICE_ART) do
        local region
        if not (pcall(function() region = child[k] end) and region) then return false end
    end
    return true
end

------------------------------------------------------------
-- 掃一次選單按鈕
--
-- 冪等：已經處理過的按鈕記在自己的弱鍵表裡，之後直接跳過
-- （`Engine.Overlay` 本來也是冪等的，這張表只是省掉重複的中和呼叫）。
------------------------------------------------------------
local seen = setmetatable({}, { __mode = "k" })
local skinned = 0

-- 外框畫成功了沒。⚠ 這是一道**全有全無**的閘：`Border` 被暴雪改名的時候，
-- 「按鈕平面化了、外框還是原生雕花」比「整個視窗都沒換皮」難看得多，
-- 而且看不出是我們少做了一塊還是插件壞了。降級方向選「整份不套 ＋ 一筆 missing」。
local panelOK = false

local function Scan()
    if not panelOK then return end
    -- 戰鬥中一次都不碰這個框（檔頭的「戰鬥閘」那一段）
    if InCombatLockdown() then return end

    local f = _G.GameMenuFrame
    if not f or type(f.GetChildren) ~= "function" then return end

    local ok, children = pcall(function() return { f:GetChildren() } end)
    if not ok then return end

    for _, child in ipairs(children) do
        if not seen[child] and IsMenuButton(child) then
            seen[child] = true
            skinned = skinned + 1
            FlatThreeSliceButton(child, KEY .. ".button" .. skinned)
        end
    end
end

------------------------------------------------------------
-- 外框 ＋ 標題
------------------------------------------------------------
local function Apply()
    local f = _G.GameMenuFrame
    if not f then
        E.Missing(KEY)
        return
    end

    local border
    if pcall(function() border = f.Border end) and border then
        -- 先建 overlay 再中和（同 `FlatThreeSliceButton` 的理由）
        local ov = E.Overlay(f, {
            key = KEY,
            parent = border,
            points = {
                { "TOPLEFT", "TOPLEFT", 0, HEADER_OVERHANG },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
            },
        })
        panelOK = ov ~= nil
        if panelOK then
            E.NeutralizeKeys(border, DIALOG_BORDER_PIECES, KEY .. ".Border")
            -- 提示皮（同確認彈窗，理由見 Popup.lua）：0.133 底 ＋ 1px 職業色邊；
            -- 裡面那排按鈕照舊 `fill` ＋ 黑邊。
            E.Paint(ov, T.tipFill, { T.Accent() })
        end
    else
        -- parent 沒著落就整塊不畫（檔頭的講究 1）
        E.Missing(KEY .. ".Border")
    end

    if not panelOK then return end

    local header
    if pcall(function() header = f.Header end) and header then
        E.NeutralizeKeys(header, { "LeftBG", "RightBG", "CenterBG" }, KEY .. ".Header")

        local text
        if pcall(function() text = header.Text end) and text then
            E.TextColor(text, T.text, KEY .. ".Header.Text")
        else
            E.Missing(KEY .. ".Header.Text")
        end
    else
        E.Missing(KEY .. ".Header")
    end

    -- 登入之後選單通常還沒開過（池子是空的），這一掃多半掃不到東西；
    -- 真正的來源是下面那支 OnShow 的延一幀。留著是為了「插件晚一點才啟用」的情況。
    Scan()
end

------------------------------------------------------------
-- 唯一的 hook
--
-- 內容只有「延一幀再掃」。出錯一次就停用，`/mskin debug` 的第一節看得到 ——
-- 每次開選單報一發的洗版比少一塊皮嚴重得多（陷阱 4 的同一條紀律）。
------------------------------------------------------------
local broken = false

local function InstallHooks()
    local f = _G.GameMenuFrame
    if not f or type(f.HookScript) ~= "function" then
        E.Missing(KEY .. ".HookScript")
        return
    end

    pcall(f.HookScript, f, "OnShow", function()
        if broken then return end
        C_Timer.After(0, function()
            if broken then return end
            local ok, err = pcall(Scan)
            if not ok then
                broken = true
                E.NoteBrokenHook(KEY .. ":OnShow")
                ns.ReportError(err)
            end
        end)
    end)
end

E.Register{
    key   = "gamemenu",
    addon = nil,                       -- Blizzard_GameMenu 沒有 LoadOnDemand
    title = L["Game Menu"],
    hooks = InstallHooks,
    apply = Apply,
}
