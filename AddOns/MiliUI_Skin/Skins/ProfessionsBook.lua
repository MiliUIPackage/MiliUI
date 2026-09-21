------------------------------------------------------------
-- 配方（`professions` 的 part）：專業技能書
--   `ProfessionsBookFrame`，隨需載入 `Blizzard_ProfessionsBook`，預設快捷鍵 K
--
-- 為什麼併進 `professions` 而不是另開一個 key：設定頁那個開關本來就叫
-- 「專業技能」，而玩家看到的是**一個**功能（STYLE.md ⑥ 第 5 步）。
-- 交接走 `ns.ProfessionsSkin` 這張表，同 `Skins/PVE.lua` ↔ `PVP.lua` 的作法
-- ⇒ TOC 裡這一支一定要排在 `Skins/Professions.lua` 後面。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_ProfessionsBook/Blizzard_ProfessionsBook.xml:325
--     `ProfessionsBookFrame` ← **`ButtonFrameTemplate`**（見下面第 1 點）
--   同檔 :329,334
--     `ProfessionsBookPage1`／`ProfessionsBookPage2`（兩張**只有全域名字**的
--      BACKGROUND 羊皮紙，`Professions-Book-Left`／`-Right`）
--   同檔 :342  `$parentTutorialButton`（`MainHelpPlateButton`）
--   同檔 :353,359-408
--     `ProfessionsContentFrame` ＋ 五個專業框
--     `PrimaryProfession1`／`2`（`PrimaryProfessionTemplate`）、
--     `SecondaryProfession1`～`3`（`SecondaryProfessionTemplate`）
--   同檔 :158,162,168,174,181,188,194,203,209
--     `PrimaryProfessionTemplate` 的 `professionName`（QuestTitleFontBlackShadow）／
--     `specialization`（GameFontNormal）／`missingHeader`（**XML 色 .85/.7/.6**）／
--     `missingText`（**XML 色 .1/.05/.05**）／`rank`（GameFontHighlightSmall）／
--     `$parentIconBorder`（ProfessionsBook.blp 的 72x72 雕花環，只有全域名字）／
--     `icon`（**alphaMode ADD**）＋ `CircleMask`（TempPortraitAlphaMask）
--   同檔 :221,226,231,236
--     `$parentSpellButtonTop`／`Bottom`（`ProfessionButtonTemplate`）、
--     `$parentStatusBar`、`UnlearnButton`（`ResizeLayoutFrame`）
--   同檔 :259-263  `PrimaryProfessionTemplate` 的 OnLoad：
--     `icon:SetAlpha(0.6)` ＋ `icon:SetDesaturation(1)`
--   同檔 :265,286,293,307,314
--     `SecondaryProfessionTemplate` 的 `rank`／`professionName`（**XML 色 1/.82/0**）／
--     `missingHeader`（**XML 色 .15/.1/.1**）／`missingText`（**XML 色 .1/.05/.05**）
--   同檔 :268,273,278  `$parentSpellButtonRight`／`Left`、`$parentStatusBar`
--   同檔 :3,14,16,22,30,40,66-68
--     `ProfessionButtonTemplate` ← **`SecureFrameTemplate, FlyoutButtonTemplate`**；
--     `IconTexture`／`spellString`／`subSpellString`／**`$parentNameFrame`**／
--     `Flash`／Pushed／Highlight／Checked
--   同檔 :89,93,98,105,114,121,128,137,140
--     `ProfessionStatusBarTemplate`（**真的是 `StatusBar`**）：
--     `$parentRank`／`$parentLeft`／`$parentRight`（parentKey `capRight`）／
--     `$parentBGLeft`／`$parentBGRight`／`$parentBGMiddle`／
--     `<BarTexture name="$parentBar" file="…\Professions-Progress-Fill"/>`／
--     `$parentCapped`（`ProfessionTrialCapTemplate`）
--   Blizzard_ProfessionsBook/Blizzard_ProfessionsBook.lua:23,24
--     `ProfessionsBookFrame_OnLoad` → `ButtonFrameTemplate_HideButtonBar`
--     ＋ `ButtonFrameTemplate_HideAttic`（後者把 `TopTileStreaks` 藏掉）
--   同檔 :57-64  `ProfessionsBookFrame_Update` → `FormatProfession` ×5
--   同檔 :382-498 `FormatProfession(frame, index)`
--   同檔 :305-353 `ProfessionSpellButtonMixin:UpdateButton`
--   同檔 :361-380 `ProfessionsUnlearnButtonMixin`
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:544,660,684
--     `PortraitFrameBaseTemplate`（NineSlice／PortraitContainer／
--      TitleContainer.TitleText）／`ButtonFrameBaseTemplate`（Bg／TopTileStreaks／
--      CloseButton）／`ButtonFrameTemplate`（`Inset` ← `InsetFrameTemplate`）
--
------------------------------------------------------------
-- ## 查證後跟第七輪「不做專業書」那段說法不一樣的四件事
--
-- 1. **「書本沒有一圈可以套方框的 chrome」是錯的。**
--    `ProfessionsBookFrame` 繼承的就是 **`ButtonFrameTemplate`**
--    （Blizzard_ProfessionsBook.xml:325）—— NineSlice、Bg、TopTileStreaks、
--    PortraitContainer、TitleContainer、CloseButton、Inset 一個不少，
--    跟商人視窗同一組原語。書本造型只是**壓在上面的兩張貼圖**
--    （`ProfessionsBookPage1`／`Page2`），不是外框本身。
--
-- 2. **書頁上的字色接得住，而且一個 hook 都不用掛。**
--    那一頁上會變色的字只有兩條，兩條都是**資訊**、我們本來就不碰：
--      * `statusBar.rankText` —— `FormatProfession` 每次更新都
--        `SetTextColor(HIGHLIGHT_FONT_COLOR)`，試用帳號封頂時改成
--        `RED_FONT_COLOR`（.lua:425,433）。
--      * 技能鈕的 `spellString` —— `UpdateButton` 在
--        `NORMAL_FONT_COLOR`／`PASSIVE_SPELL_FONT_COLOR` 之間切（.lua:317,320），
--        那是「被動／主動」的訊號，而且它在 secure 鈕上。
--    其餘五條（`professionName`／`specialization`／`missingHeader`／`missingText`／
--    `rank`）**顏色全部只來自字型物件或 XML 的 `<Color>`，Lua 一行都沒有重設**
--    —— `FormatProfession` 對它們只做 `SetText`。⇒ 一次 `SetTextColor` 就永久有效，
--    符合 STYLE.md ⑦「只處理 XML 裡靜態的 FontString」那一條。
--
-- 3. **等級條是真的 `StatusBar`**（`ProfessionStatusBarTemplate`，xml:89，
--    帶 `<BarTexture>`）—— 跟配方頁底下那條 `ProfessionsRankBarTemplate`
--    （Frame ＋ MaskTexture ＋ FlipBook，`Skins/Professions.lua` 檔頭第 2 點）
--    **不是同一個東西**，`Skin.StatusBar` 直接套得上。
--    全檔沒有 `SetStatusBarTexture`／`GetStatusBarTexture`／`SetStatusBarColor`
--    ⇒ 換填充材質撐得住，顏色維持暴雪的（註 ⓓ）。
--
-- 4. **`FormatProfession` 是全域函式**（不是暴雪框的方法）⇒ 勾得到，
--    而且**不必在暴雪框上寫任何欄位**。這一份只用它做一件事：
--    `frame.icon:SetTexture(texture)`（.lua:439,485）會把 texCoord 打回
--    `0,1,0,1`（陷阱 4），所以裁邊要在它的後置勾裡重申。
--
------------------------------------------------------------
-- ## 技能鈕是 secure 的 —— 這一份對它們只做一件事
--
-- `ProfessionButtonTemplate` ← **`SecureFrameTemplate`**（xml:3）⇒ 每一顆技能鈕
-- （開啟製作視窗／烹飪營火／釣魚／考古勘測…）都是**顯式保護**的施法按鈕。
--
--   * **零 overlay**（`Engine.Overlay` 對顯式保護框回 nil，不為它們開後門）、
--     **零 `HookScript`**、**零 `hooksecurefunc`** 在
--     `ProfessionSpellButtonMixin` 的任何方法上。
--   * 唯一碰到的是 **`$parentNameFrame`**：一張 108x41、BACKGROUND 層、
--     `Interface\Spellbook\ProfessionsBook` 切出來的**名牌底板**（xml:30-37）。
--     它在整個 `Blizzard_ProfessionsBook.lua` 裡**零引用** —— 沒有 Show／Hide、
--     沒有 SetTexture、沒有 vertex color ⇒ 是純裝飾，不是狀態指示。`SetAlpha(0)`。
--   * `IconTexture`／`highlightTexture`／Pushed／Checked／`Flash`／`cooldown`
--     **一根手指都不碰**：`UpdateButton` 每次都對 `IconTexture` 下
--     `SetTexture` ＋ `SetVertexColor(0.4,…)`（不可用時壓暗）、對
--     `highlightTexture` 下 `SetTexture`（被動換一張）—— 三張都是狀態，
--     而且我們換了也會被下一次更新打回。
--
-- 書的外框因此是**隱式保護**（保護沿 parent 鏈往上傳染）。
-- 照 STYLE.md ③ 的「顯式跳過、隱式照做」：`Skin.Panel`／`Skin.Inset` 照常用
-- （`Engine.RegionBackdrop` 建的是目標框自己的貼圖，不是保護操作）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **「遺忘專業」鈕 `UnlearnButton`**（xml:236）—— 兩條理由，一條就夠：
--   (a) 它是 `ResizeLayoutFrame` ＝ **排版框**，overlay 不准掛上去（陷阱 2），
--       而 `Engine.RegionBackdrop` 遇到排版框會退回子框那條路；
--   (b) 它通往 `StaticPopup_Show("UNLEARN_SKILL")`（.lua:401）這個受保護動作，
--       而且它的 OnEnter／OnLeave／OnMouseDown／OnMouseUp 四支腳本
--       （`ProfessionsUnlearnButtonMixin`）本來就在對 `Icon` 做 `SetAlpha`／
--       `SetPoint` —— 我們畫的底會跟那個位移對不上。
--   它整顆的內容就是一個 26x26、scale 0.7 的紅色 ✗ 圖示（`UI-GroupLoot-Pass-Up`），
--   顏色本身是訊號。**整顆不碰。**
-- * **教學鈕 `MainHelpButton`**（`MainHelpPlateButton`）—— 整顆是那個金色問號的
--   美術（含自己的 `Ring` 與動畫），跟關閉鈕不同，它沒有「殼 ＋ 圖」可以拆。
-- * **等級條的 `capped`** —— 試用帳號封頂的鎖頭，是狀態指示不是裝飾。
--   （`capRight`「練滿了」那顆端帽第一版也留著，實機看是一坨凸出條外的綠點 ⇒
--   改成中和，理由寫在 `SkinRankBar`。）
-- * **`statusBar.rankText`（「XX / 100」）與技能鈕的 `spellString`／
--   `subSpellString`** —— 見上面第 2 點，兩條都是暴雪每次更新重設的資訊色。
-- * **`rank`（「大師」「宗師」那一行）** —— 它的字型物件是
--   `GameFontHighlightSmall`，本來就是白的；改它只是多一次接觸面。
-- * **專業圖示的 alpha 與去飽和** —— 模板的 OnLoad 把它設成
--   `SetAlpha(0.6)` ＋ `SetDesaturation(1)`，那是為羊皮紙設計的浮水印。
--   換到深底上 `alphaMode="ADD"` 反而讓它比在羊皮紙上更清楚（ADD 是加法：
--   底越暗，圖越顯），所以**維持暴雪的值**；要調回滿飽和得走
--   `SetDesaturated(false)`，那不在 STYLE.md ③ 的白名單上。
--
------------------------------------------------------------
-- ## 伴隨元件（套組內建，掛在專業書上）
--
-- | 誰 | 掛在哪 | 怎麼處理 |
-- |---|---|---|
-- | 套組內建的一支輔助插件 | 用 `HookScript("OnShow"/"OnHide")` 掛在 `ProfessionsBookFrame` 上，並以 `PrimaryProfession%dSpellButtonBottom` 為錨建**自己的**框，顯示未花費的專精點數 | **不碰**：它有自己的長相（伴隨元件規則第 1 條），而且我們對技能鈕只 `SetAlpha(0)` 那一張名牌底板、對專業框只**加**自己的貼圖 ⇒ 它的框不在我們的接觸面上 |
--
-- ⚠ 這一份沒有 `companions`。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `ProfessionsBookFrame` 的 NineSlice／Bg／TopTileStreaks／PortraitContainer | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `TitleContainer.TitleText` | `SetTextColor` |
-- | `ProfessionsBookPage1`／`Page2` | `SetAlpha(0)` |
-- | `ProfessionsBookFrame.Inset` 的 `Bg`／`NineSlice` | `SetAlpha(0)` |
-- | `CloseButton` 的 Normal／Disabled | `SetAlpha(0)`；Highlight／Pushed | `SetColorTexture` |
-- | 五個專業框的 `professionName`／`missingHeader` | `SetTextColor(text)`；`specialization`／`missingText` | `SetTextColor(textDim)` |
-- | `PrimaryProfessionN` 的 `$parentIconBorder` | `SetAlpha(0)` |
-- | `PrimaryProfessionN` 的 `icon` | `RemoveMaskTexture`（`Engine.UnmaskIcon`）＋ `SetTexCoord`（裁邊） |
-- | 五條等級條的 `$parentBGLeft`／`BGMiddle`／`BGRight`／`$parentLeft` | `SetAlpha(0)` |
-- | 五條等級條本身 | `SetStatusBarTexture`（`Engine.BarTexture`，明文路徑） |
-- | 十顆 secure 技能鈕的 `$parentNameFrame` | `SetAlpha(0)`（**只有這一張**） |
-- | 上面所有目標（技能鈕除外） | 以它們為 parent／anchor 建**我們自己的** overlay 框與貼圖 |
--
-- ### 掛了哪些 hook（這一輪新增）
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc("FormatProfession", …)` | **全域函式**後置勾 | 只做一件事：對「我們拿掉過圓形遮罩」的那顆圖示重裁 texCoord（第一行查自己的弱鍵表，不是我們處理過的就返回）。**不讀 `index`、不讀 frame 的任何欄位** |
-- | `Skin.CloseButton` → `Engine.TrackButtonHover` 的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | 只對關閉鈕；內容只有換我們自己 overlay 的底色與邊色 |
--
-- **`hooksecurefunc` 在 `ProfessionsBookFrame` 或它任何子框上：0 支。**
-- **`hooksecurefunc` 在 `ProfessionSpellButtonMixin`／`ProfessionsUnlearnButtonMixin`
--   上：0 支。**
-- **`HookScript` 在任何 secure 技能鈕上：0 支。**
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens

local function Field(owner, key)
    if type(owner) ~= "table" then return nil end
    local value
    if pcall(function() value = owner[key] end) then return value end
    return nil
end

------------------------------------------------------------
-- 兩張書頁：只有全域名字（沒有 parentKey），而且 `Blizzard_ProfessionsBook.lua`
-- 整份**零引用** ⇒ 沒有任何路徑會把中和打回來。
------------------------------------------------------------
local PAGE_ART = { "ProfessionsBookPage1", "ProfessionsBookPage2" }

------------------------------------------------------------
-- 等級條上「只有全域名字」的四張裝飾貼圖。
--
-- ⚠ `$parentRight`（parentKey `capRight`）不在這張表裡，但一樣會被中和 ——
--   另外點名，理由寫在用到的地方。
------------------------------------------------------------
local BAR_ART = { "BGLeft", "BGMiddle", "BGRight", "Left" }

-- 等級條的填充色：跟成就視窗的進度條同一個綠（暴雪在那邊用的 0, 0.6, 0）
local RANK_BAR_COLOR = { 0, 0.6, 0, 1 }

-- 每個專業那塊內嵌區的範圍。
--
-- 暴雪的框（主要 437x81、次要 437x46，Blizzard_ProfessionsBook.xml:158,265）**包不住
-- 自己的內容**：原本壓在一整頁羊皮紙上所以看不出來，我們替每個框畫了一圈邊之後
-- 就露餡了（實機擷圖）——
--   * 主要專業：等級條與技能鈕的下緣比框低幾個單位。
--   * 次要專業：等級條錨在 `BOTTOMLEFT y=-1`（同檔 :280）⇒ 掉到框外；
--     專業名稱疊在「等級文字」上面、等級文字又疊在條上面（:286-297）⇒ 用套組的
--     中文字型時名稱整行凸出框的上緣。
-- 只能動我們自己的範圍：上下往外擴到包得住。框與框之間隔 15／35 個單位，擴了不會碰到鄰居。
-- 第二版（實機擷圖）：內容貼著框線很擠 —— 主要專業的名稱頂著上緣、次要專業的名稱與
-- 等級條貼著左緣。四邊再各讓出一圈留白（左右各 8；上緣讓到名稱上方約 8）。
-- 左右對稱外擴，置中（ROOT_X）不受影響。暴雪排的框距：主要專業之間 12、次要專業之間 30、
-- 兩組之間 40（Blizzard_ProfessionsBook.xml:364,376,387,398）；上下外擴的量是照
-- 「同組的卡片之間剩 2、兩組之間剩 15」湊的（12−5−5、30−8−20、40−5−20），
-- 讀起來是「兩組清單」而不是五個各自飄著的方塊。
local CARD_POINTS = {
    primary = {
        { "TOPLEFT", "TOPLEFT", -8, 5 },
        { "BOTTOMRIGHT", "BOTTOMRIGHT", 8, -5 },
    },
    secondary = {
        { "TOPLEFT", "TOPLEFT", -8, 20 },
        { "BOTTOMRIGHT", "BOTTOMRIGHT", 8, -8 },
    },
}

-- 只有一顆技能鈕時，把它垂直置中的位移量。
-- XML：`SpellButtonTop` 錨 `TOPRIGHT x=-109 y=-3`（40 高），`SpellButtonBottom` 錨
-- `TOPLEFT → SpellButtonTop 的 BOTTOMLEFT (0,0)` ⇒ 下面那顆佔 y=-43..-83（同檔 :221-229）。
-- 只學了一個技能的專業只顯示下面那顆（`FormatProfession` .lua:456-458），上半格空著，
-- 看起來像整排往下掉。卡片範圍是 +5..-86 ⇒ 中線 -40.5 ⇒ 鈕頂要在 -20.5 ⇒ 往上提 22。
local SINGLE_SPELL_LIFT = 22

------------------------------------------------------------
-- 兩個專業模板的差異表（框名、字色、技能鈕後綴、有沒有圖示）
--
-- 全部是 XML 寫死的全域名字（Blizzard_ProfessionsBook.xml:221,226,268,273,359-408）
-- ⇒ 不必讀 `GetName()`，也不必走 `GetRegions()`。
------------------------------------------------------------
local TEMPLATES = {
    {   -- PrimaryProfessionTemplate
        frames  = { "PrimaryProfession1", "PrimaryProfession2" },
        white   = { "professionName", "missingHeader" },
        dim     = { "specialization", "missingText" },
        buttons = { "SpellButtonTop", "SpellButtonBottom" },
        icon    = true,
    },
    {   -- SecondaryProfessionTemplate（沒有 icon，也沒有 specialization）
        frames  = { "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3" },
        white   = { "professionName", "missingHeader" },
        dim     = { "missingText" },
        buttons = { "SpellButtonRight", "SpellButtonLeft" },
        icon    = false,
    },
}

-- 只有一顆技能鈕的主要專業：把那一顆垂直置中（兩顆都在就還原）。
--
-- 讀的是 `SpellButtonTop:IsShown()` —— 暴雪自己表達「這個專業有幾顆技能鈕」的同一個依據
-- （`FormatProfession` 對它 Show／Hide），純 C 端布林、過 `Secret.ToBool`、問不到就當成
-- 「兩顆都在」（＝不動，失敗方向安全）。已列入 STYLE.md ③ 的讀取例外表。
-- 移動走 `Engine.ShiftRoot`（同名錨點覆寫、戰鬥中不做）：技能鈕是 secure 框，戰鬥中
-- 動它會被擋，所以戰鬥中開書就維持暴雪原位，下次脫戰更新再置中。
local liftable = setmetatable({}, { __mode = "k" })   -- [專業框] = { top, bottom }

local function CenterSingleSpell(frame)
    local pair = liftable[frame]
    if not pair then return end
    local top, bottom = pair[1], pair[2]
    local both = true
    if type(top.IsShown) == "function" then
        local ok, shown = pcall(top.IsShown, top)
        if ok and ns.Secret.ToBool(shown) == false then both = false end
    end
    E.ShiftRoot(bottom, "TOPLEFT", top, "BOTTOMLEFT", 0, both and 0 or SINGLE_SPELL_LIFT,
        "ProfessionSpellButtonBottom")
end

-- 我們**自己的**弱鍵表：記住「這個專業框的圖示已經拿掉圓形遮罩、裁過邊」。
-- 暴雪框上零欄位寫入（STYLE.md ③）。
local squareIcons = setmetatable({}, { __mode = "k" })

-- 每個專業框底下那兩顆技能鈕的圖示（裁邊要在 `FormatProfession` 之後重申）
local spellIcons = setmetatable({}, { __mode = "k" })

-- 版面根框的水平位置。
--
-- 五個專業框是**一條錨定鏈**：`PrimaryProfession1` 錨在 `ProfessionsContentFrame` 的
-- `TOPLEFT x=80 y=-67`，其餘四個一個接一個往下掛（Blizzard_ProfessionsBook.xml:359-400）。
-- 視窗寬 550、專業框寬 437 ⇒ 左留白 80、右留白 33：那 47 是原本讓給書脊與左頁邊的，
-- 書本美術拿掉之後就只是一塊歪掉的空白。置中＝(550−437)/2 ≈ 56。
-- 只平移根框這一顆（`Engine.ShiftRoot`，契約例外），整條鏈與掛在它們上面的別家元件一起跟著走。
local ROOT_X, ROOT_Y = 56, -67

------------------------------------------------------------
-- 專業圖示：圓形遮罩 → 方形 ＋ 裁邊 ＋ 1px 黑框
--
-- 跟地城與團隊左側大類鈕同一條路（`Skins/PVE.lua` 的 `SkinCategoryIcon`）：
-- `CircleMask` 是 XML 寫死的、`Blizzard_ProfessionsBook.lua` 零引用，
-- 拿不掉（或 `T.categoryIconStyle = "ring"`）就退回「只中和外圈雕花」。
------------------------------------------------------------
local function SkinProfessionIcon(frameName, frame, key)
    -- 72x72 的雕花環，只有全域名字
    E.Neutralize(_G[frameName .. "IconBorder"], key .. ".IconBorder")

    local icon = Field(frame, "icon")
    if not icon then
        E.Missing(key .. ".icon")
        return
    end

    if T.categoryIconStyle ~= "square" then return end
    if not E.UnmaskIcon(icon, Field(frame, "CircleMask"), key .. ".icon") then return end

    E.CropIcon(icon, key .. ".icon")
    squareIcons[frame] = icon

    local ov = E.Overlay(frame, {
        key         = key .. ".icon.border",
        slot        = "iconBorder",
        anchorTo    = icon,
        levelOffset = 1,
    })
    E.Paint(ov, { 0, 0, 0, 0 }, T.border)
end

------------------------------------------------------------
-- 等級條
------------------------------------------------------------
local function SkinProfessionBar(frameName, frame, key)
    local bar = Field(frame, "statusBar")
    if not bar then
        E.Missing(key .. ".statusBar")
        return
    end

    local names = {}
    for i, suffix in ipairs(BAR_ART) do
        names[i] = frameName .. "StatusBar" .. suffix
    end
    E.NeutralizeGlobals(names)

    -- 練滿時右端那顆端帽（`$parentRight`，parentKey `capRight`）。第一版把它當成
    -- 「狀態指示」留著，實機看是一坨凸出條外的綠色光點（它是為暴雪那條立體條的
    -- 端頭畫的）；「練滿了」已經由「100/100」的數字與整條填滿表達 ⇒ 中和。
    -- 暴雪對它只有 Show／Hide（FormatProfession），不碰 alpha，設一次就永久有效。
    E.NeutralizeGlobals({ frameName .. "StatusBarRight" })

    -- ⚠ 這條**一定要給顏色**。暴雪原本的顏色是「烤在那張條材質裡」的（綠色立體條），
    --   不是 `SetStatusBarColor` 設的；材質一換成套組的平面條就只剩灰白（實機擷圖）。
    --   這條的顏色不帶資訊（不像聲望條依等級變色）⇒ 用跟成就進度條同一個綠。
    Skin.StatusBar(bar, key .. ".statusBar", { color = RANK_BAR_COLOR })
end

------------------------------------------------------------
-- 一個專業區塊
------------------------------------------------------------
local function SkinProfession(frameName, spec)
    local frame = _G[frameName]
    if not E.Usable(frame, frameName) then return end

    -- 每個專業一塊 `fillInset` 的內嵌區（書頁是 `fill`）
    Skin.Panel(frame, frameName, {
        fill = T.fillInset,
        points = spec.icon and CARD_POINTS.primary or CARD_POINTS.secondary,
    })

    for _, fieldKey in ipairs(spec.white) do
        E.TextColor(Field(frame, fieldKey), T.text, frameName .. "." .. fieldKey)
    end
    for _, fieldKey in ipairs(spec.dim) do
        E.TextColor(Field(frame, fieldKey), T.textDim, frameName .. "." .. fieldKey)
    end

    if spec.icon then
        SkinProfessionIcon(frameName, frame, frameName)
    end
    SkinProfessionBar(frameName, frame, frameName)

    -- secure 技能鈕：名牌底板中和 ＋ 圖示做成方形。
    --
    -- 這顆按鈕**沒有**自己的外框美術（模板只有 IconTexture／Pushed／Highlight／Checked，
    -- Blizzard_ProfessionsBook.xml:3-68）—— 看起來圓角，是因為法術圖示素材本身四周有一圈
    -- 圓角暗邊。所以「變方形」＝裁邊（`SetTexCoord`，對 region 的純 C 端 setter）。
    -- ⚠ 方框**不掛在 secure 按鈕上**（Engine 會擋，也不該繞）：掛在外層的專業框上
    --   （隱式保護的容器，第五輪起准許）、用 `anchorTo` 貼著按鈕、層級墊高到按鈕之上、
    --   底透明只有 1px 黑邊、不吃滑鼠 ⇒ 點擊與拖曳照樣落在暴雪的按鈕上。
    -- ⚠ `UpdateButton` 每次 `IconTexture:SetTexture(...)`（.lua:323,344）⇒ 裁邊要重申，
    --   掛在既有的 `FormatProfession` 後置勾上（它逐顆呼叫 UpdateProfessionButton）。
    local names, icons = {}, {}
    for i, suffix in ipairs(spec.buttons) do
        local btnName = frameName .. suffix
        names[i] = btnName .. "NameFrame"
        local icon = _G[btnName .. "IconTexture"]
        local btn = _G[btnName]
        if icon and btn then
            icons[#icons + 1] = icon
            E.CropIcon(icon, btnName .. ".IconTexture")
            -- ⚠ 方框是**直接建在那顆按鈕上的貼圖**（`Engine.RegionBackdrop`，OVERLAY 層，
            --   底透明只有邊）。第一版掛在外層專業框上、用 anchorTo 貼著按鈕 ——
            --   暴雪把沒用到的技能鈕 `Hide()` 掉時（只有一個技能的專業、還沒學的考古學），
            --   我們的框還留在原地，變成一個個空方框（實機擷圖）。貼圖是按鈕自己的 region，
            --   按鈕藏它就跟著藏，零讀取零 hook。`CreateTexture` 不寫欄位、不碰 secure 屬性；
            --   apply 過戰鬥閘，所以只會在脫戰時建。建不出來就是沒有框，不影響按鈕。
            local ov = E.RegionBackdrop(btn, {
                key = btnName .. ".border",
                slot = "iconBorder",
                layer = "OVERLAY", sublevel = 6,
                edgeLayer = "OVERLAY", edgeSublevel = 7,
            })
            if ov and ov.isRegion then
                E.Paint(ov, { 0, 0, 0, 0 }, T.border)
            end
        end
    end
    E.NeutralizeGlobals(names)
    spellIcons[frame] = icons

    if spec.icon then
        local top, bottom = _G[frameName .. "SpellButtonTop"], _G[frameName .. "SpellButtonBottom"]
        if top and bottom then
            liftable[frame] = { top, bottom }
            CenterSingleSpell(frame)
        end
    end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Apply()
    local f = _G.ProfessionsBookFrame
    if not f then
        E.Missing("ProfessionsBookFrame")
        return
    end

    Skin.PortraitChrome(f, "ProfessionsBookFrame")
    Skin.Panel(f, "ProfessionsBookFrame")

    -- 兩張書頁（內容底材）—— 字色在下面全部接管，見檔頭第 2 點
    E.NeutralizeGlobals(PAGE_ART)

    local close = Field(f, "CloseButton")
    if close then
        Skin.CloseButton(close, "ProfessionsBookFrame.CloseButton")
    else
        E.Missing("ProfessionsBookFrame.CloseButton")
    end

    -- 書頁區：`ButtonFrameTemplate` 的 `Inset`。
    -- ⚠ 這裡**刻意不用 `Skin.Inset`** —— 它固定畫 `fillInset`，而這一頁底下還要
    --   擺五塊 `fillInset` 的專業區。底材比內嵌區亮一階才分得出層次，
    --   所以中和的動作照抄、底色換成 `T.fill`。
    local inset = Field(f, "Inset")
    if inset then
        E.NeutralizeKeys(inset, { "Bg", "NineSlice" }, "ProfessionsBookFrame.Inset")
        Skin.Panel(inset, "ProfessionsBookFrame.Inset", { fill = T.fill })
    else
        E.Missing("ProfessionsBookFrame.Inset")
    end

    -- 版面置中：只平移錨定鏈的根（理由與數字見 ROOT_X 的註解）。
    -- 暴雪的 Lua 沒有任何地方重設或讀回 `PrimaryProfession1` 的位置（grep 過整個
    -- Blizzard_ProfessionsBook.lua）。要在畫內嵌區**之前**做：內嵌區是錨點跟隨的，先後都對，
    -- 但先移再畫可以少一幀跳動。
    E.ShiftRoot(_G.PrimaryProfession1, "TOPLEFT", _G.ProfessionsContentFrame, "TOPLEFT",
        ROOT_X, ROOT_Y, "PrimaryProfession1")

    for _, spec in ipairs(TEMPLATES) do
        for _, frameName in ipairs(spec.frames) do
            SkinProfession(frameName, spec)
        end
    end
end

------------------------------------------------------------
-- hook：`FormatProfession` 的後置勾
--
-- 唯一的用途是重裁 texCoord —— `FormatProfession` 對圖示下 `SetTexture`
-- （.lua:439 學會的專業、:485 沒學的那張捲軸圖），而 `SetTexture` 會把
-- texCoord 打回 `0,1,0,1`（陷阱 4）。
--
-- ⚠ 勾的是**全域函式**，不是 `ProfessionsBookFrame` 的方法
--   ⇒ 不在暴雪框上寫任何欄位。
-- ⚠ 不讀第二個參數（`index`），也不讀 frame 的任何欄位 ——
--   只拿 frame 當我們自己那張弱鍵表的 key。
------------------------------------------------------------
local function InstallHooks()
    if type(_G.FormatProfession) ~= "function" then
        E.Missing("FormatProfession")
        return
    end

    hooksecurefunc("FormatProfession", function(frame)
        if type(frame) ~= "table" then return end
        local icon = squareIcons[frame]
        if icon then
            E.CropIcon(icon, "FormatProfession.icon")
        end
        local spells = spellIcons[frame]
        if spells then
            for i = 1, #spells do
                E.CropIcon(spells[i], "FormatProfession.spellIcon")
            end
        end
        CenterSingleSpell(frame)
    end)
end

------------------------------------------------------------
-- 交接給 `Skins/Professions.lua` 的 `parts`（同 `ns.PVESkin` 的形狀）
------------------------------------------------------------
ns.ProfessionsSkin = ns.ProfessionsSkin or {}
ns.ProfessionsSkin.HookBook = InstallHooks
ns.ProfessionsSkin.ApplyBook = Apply
