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
-- * **等級條的 `capRight` 與 `capped`** —— `capRight` 是「練滿了」
--   （`FormatProfession` .lua:418-422 的 Show／Hide），`capped` 是試用帳號封頂的
--   鎖頭。兩個都是狀態指示，不是裝飾。
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
-- ⚠ `$parentRight`（parentKey `capRight`）**不在這張表裡**：它是「練滿了」的
--   狀態指示（`FormatProfession` 對它 Show／Hide），不是裝飾。
------------------------------------------------------------
local BAR_ART = { "BGLeft", "BGMiddle", "BGRight", "Left" }

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

-- 我們**自己的**弱鍵表：記住「這個專業框的圖示已經拿掉圓形遮罩、裁過邊」。
-- 暴雪框上零欄位寫入（STYLE.md ③）。
local squareIcons = setmetatable({}, { __mode = "k" })

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

    -- 顏色不給 ⇒ 不碰填充色（註 ⓓ）。材質換成套組的細橫紋。
    Skin.StatusBar(bar, key .. ".statusBar")
end

------------------------------------------------------------
-- 一個專業區塊
------------------------------------------------------------
local function SkinProfession(frameName, spec)
    local frame = _G[frameName]
    if not E.Usable(frame, frameName) then return end

    -- 每個專業一塊 `fillInset` 的內嵌區（書頁是 `fill`）
    Skin.Panel(frame, frameName, { fill = T.fillInset })

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

    -- secure 技能鈕：**只有**名牌底板那一張
    local names = {}
    for i, suffix in ipairs(spec.buttons) do
        names[i] = frameName .. suffix .. "NameFrame"
    end
    E.NeutralizeGlobals(names)
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
    end)
end

------------------------------------------------------------
-- 交接給 `Skins/Professions.lua` 的 `parts`（同 `ns.PVESkin` 的形狀）
------------------------------------------------------------
ns.ProfessionsSkin = ns.ProfessionsSkin or {}
ns.ProfessionsSkin.HookBook = InstallHooks
ns.ProfessionsSkin.ApplyBook = Apply
