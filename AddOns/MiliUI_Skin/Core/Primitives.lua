------------------------------------------------------------
-- 原語：一個暴雪模板對應一支函式
--
-- 配方（Skins/*.lua）只做兩件事：說出「這個框是哪一種東西」，然後把找得到的
-- 區域交給這裡。所有「怎麼畫」的知識集中在這一支，改樣式只改這裡。
--
-- ⚠ 這支檔案在 `.claude/scripts/check_skin.py` 的掃描範圍內：
--   不准出現 Hide/Show/SetShown/SetParent/ClearAllPoints/SetPoint/SetSize/
--   SetScale/SetScript/SetFrameLevel/SetFrameStrata/EnableMouse/SetAtlas/
--   PanelTemplates_*()/ShowUIPanel/HideUIPanel/BackdropTemplate。
--   overlay 的定位一律經由 Engine.Overlay 的 opts（Engine.lua 不在掃描範圍）。
--
-- ⚠ 區域名稱全部查證自 12.1.0.69875 的暴雪原始碼，出處記在 STYLE.md ⑤ 的配方表。
--   查不到的區域**只記錄不報錯**（Engine.Missing），暴雪改名時這支插件會退化成
--   「少中和一塊」而不是整份配方掛掉。
------------------------------------------------------------
local _, ns = ...

local E = ns.Engine
local T = ns.Tokens

ns.Skin = {}
local Skin = ns.Skin

------------------------------------------------------------
-- Panel：視窗本體的底 ＋ 1px 硬邊
--
-- overlay 壓在目標自己的區域之下（levelOffset −1），所以**一定要先中和**
-- 目標自己的底圖，不然我們畫的東西看不見。
------------------------------------------------------------
function Skin.Panel(frame, key, opts)
    opts = opts or {}
    local ov = E.Overlay(frame, {
        key = key,
        inset = opts.inset,
        points = opts.points,
        parent = opts.parent,
    })
    E.Paint(ov, opts.fill or T.fill, opts.border)
    return ov
end

------------------------------------------------------------
-- PortraitChrome：`PortraitFrameTemplate` / `ButtonFrameTemplate` 那一整組美術
--
-- 出處：Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml
--   PortraitFrameBaseTemplate → NineSlice（Frame）、PortraitContainer（Frame，
--       底下是 portrait 與 CircleMask）、TitleContainer.TitleText（FontString）
--   ButtonFrameBaseTemplate   → Bg（UI-Background-Rock）、TopTileStreaks
--   ButtonFrameTemplate       → Inset（InsetFrameTemplate）
--
-- 標題文字改白：暴雪用 GameFontNormal（暗金），壓在深底上偏灰。
-- ⚠ 有些視窗會在更新時重新 `SetTitleColor`（CharacterFrame 就是），那種要另外
--   掛勾，見 Skins/Character.lua。
------------------------------------------------------------
local PORTRAIT_ART = { "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer" }

function Skin.PortraitChrome(frame, key)
    E.NeutralizeKeys(frame, PORTRAIT_ART, key)

    local title
    if type(frame) == "table" and pcall(function() title = frame.TitleContainer end) and title then
        local fs
        if pcall(function() fs = title.TitleText end) and fs then
            E.TextColor(fs, T.text, key .. ".TitleContainer.TitleText")
        else
            E.Missing(key .. ".TitleContainer.TitleText")
        end
    else
        E.Missing(key .. ".TitleContainer")
    end
end

------------------------------------------------------------
-- Inset：`InsetFrameTemplate`（Bg = UI-Background-Marble ＋ NineSlice）
--
-- 內容區比外框暗一階。兩層同色就完全看不出內縮，等於把資訊層級抹平。
------------------------------------------------------------
function Skin.Inset(inset, key)
    E.NeutralizeKeys(inset, { "Bg", "NineSlice" }, key)
    local ov = E.Overlay(inset, { key = key })
    E.Paint(ov, T.fillInset, T.border)
    return ov
end

------------------------------------------------------------
-- Button：`UIPanelButtonTemplate` 系
--
-- 出處：Blizzard_SharedXML/SecureUIPanelTemplates.xml 的 UIPanelButtonNoTooltipTemplate
--   BACKGROUND 三張：Left / Right / Middle（UI-Panel-Button-Up）
--   ButtonText  ：Text
--   HighlightTexture：UIPanelButtonHighlightTexture（alphaMode ADD）
--
-- ⚠ **一定要用 alpha 中和那三張，不能換材質**：`UIPanelButton_OnShow` /
--   `_OnEnable` / `_OnDisable` / `_OnMouseDown` / `_OnMouseUp`（同檔的 .lua）
--   每次都會 `SetTexture` 回去，換材質撐不過一次點擊。
--
-- 三態：滑過交給引擎（Highlight 換成白色 8%）。**按下沒有視覺** —— 這個模板
-- 沒有 PushedTexture，它是靠換 Left/Middle/Right 的材質來表示按下的，而那三張
-- 已經被我們 alpha 0 了。補一張 PushedTexture 等於對暴雪按鈕做結構性修改，
-- 不在白名單裡，所以 PoC 接受「按下沒有回饋」。
------------------------------------------------------------
-- opts:
--   keepFont  不要換 NormalFont。給「字型物件本身帶了別的語意」的按鈕用 ——
--             好友查詢頁的欄位表頭是 `UserScaledFontGameHighlightSmall`
--             （跟著玩家的文字大小設定縮放），換成固定字級的 `GameFontHighlight`
--             等於把那個縮放弄掉。
--   points    overlay 改用自訂錨點（仍然錨在按鈕上）
function Skin.Button(btn, key, opts)
    opts = opts or {}
    E.NeutralizeKeys(btn, { "Left", "Right", "Middle" }, key)
    E.ButtonStates(btn, key)
    -- 文字白色：換 NormalFont，不要 SetTextColor（撐不過一次滑過，理由見 Engine.ButtonFonts）
    if not opts.keepFont then
        E.ButtonFonts(btn, GameFontHighlight, key)
    end

    local ov = E.Overlay(btn, { key = key, points = opts.points })
    E.Paint(ov, T.fill, T.border)
    return ov
end

------------------------------------------------------------
-- BorderOnly：只畫一圈邊、不動底
--
-- 給「保留了內容底材、但還是想要一圈外框」的區塊用（信紙、模型場景）。
-- 層級 +1 才畫得在底材之上（其餘 overlay 一律 −1），同 `Skin.Icon` 的邊框那一層。
------------------------------------------------------------
local TRANSPARENT = { 0, 0, 0, 0 }

function Skin.BorderOnly(target, key, opts)
    opts = opts or {}
    local ov = E.Overlay(target, {
        key = key .. ".border",
        levelOffset = 1,
        points = opts.points,
        parent = opts.parent,
    })
    E.Paint(ov, TRANSPARENT, opts.border or T.border)
    return ov
end

------------------------------------------------------------
-- CloseButton：`UIPanelCloseButton`
--
-- 出處：Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:134
--   NormalTexture   atlas RedButton-Exit
--   PushedTexture   atlas RedButton-exit-pressed
--   DisabledTexture atlas RedButton-Exit-Disabled
--   HighlightTexture atlas RedButton-Highlight（alphaMode ADD）
--
-- 三張狀態圖都是「紅底按鈕連叉叉」的合成圖，換色救不回來（紅底會留著），
-- 所以整組 alpha 0，叉叉由 overlay 自己畫一個靜態圖記。
-- 滑過與按下交給引擎（Highlight → 白 8%、Pushed → 黑 18%）。
--
-- ⚠ 圖記**不要用貼圖**。第一版拿 `Interface\Buttons\UI-StopButton` 當 ×，結果那張
--   圖本身是暗金色的 —— SetVertexColor 是乘法，乘不出白色，只會更暗。改成兩條
--   `CreateLine()` 自己畫，純白、粗細走 P.Scale，一樣是建立時定好、執行期零 Lua。
------------------------------------------------------------
function Skin.CloseButton(btn, key)
    if not E.Usable(btn, key) then return end

    -- ⚠ Pushed **不中和**：它要被換成黑色疊加，中和過就看不見了（見 Engine.ButtonStates）。
    --   模板裡三張都是寫死的 atlas，暴雪不會在執行期重設，所以換材質撐得住。
    for _, getter in ipairs({ "GetNormalTexture", "GetDisabledTexture" }) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    E.ButtonStates(btn, key, true)

    local ov = E.Overlay(btn, {
        key = key,
        inset = 2,
        glyph = { kind = "cross", size = 9, thickness = 1, color = T.text },
    })
    E.Paint(ov, T.fill, T.border)
    return ov
end

------------------------------------------------------------
-- Tab：兩種暴雪分頁模板
--
-- kind = "panel"  → `PanelTabButtonTemplate`（角色面板）。模板有
--                   `parentArray="TabTextures"`，九張貼圖收在 tab.TabTextures。
-- kind = "legacy" → `AchievementFrameTabButtonTemplate`（成就視窗）。同樣的
--                   parentKey 名字，但**沒有** parentArray，要逐一點名。
--
-- 選中／未選中／停用由 Engine 的三個 PanelTemplates_* 後置勾重畫（理由寫在
-- Engine.lua 的那一段：Active 那組貼圖是 useAtlasSize、橫向超出分頁矩形，
-- 要修就得對暴雪區域 SetPoint，契約禁止）。
--
-- ⚠ **與視窗相連的那一邊（上邊）不畫。** 兩個視窗的分頁都掛在視窗**下緣**
--   （`CharacterFrameTab1` 錨 TOPLEFT→CharacterFrame BOTTOMLEFT x=11 y=2，
--   `AchievementFrameTab1` 錨 TOPLEFT→BOTTOMLEFT x=17 y=3 —— 都往上疊了幾像素），
--   所以分頁的**上邊**貼著視窗下緣。兩條 1px 黑邊疊在同一條線上會變成一條 2px 的
--   粗線，而且分頁看起來就不像跟視窗連在一起（feedback-ui-visual-style）。
------------------------------------------------------------
--
-- ⚠ **分頁的 overlay 要往右多畫一截，不能只畫按鈕矩形。**
--   暴雪的分頁按鈕彼此之間**有空隙**（第二輪實測擷圖量到約 3~4 像素），
--   只是它的端帽貼圖橫向超出按鈕矩形、把空隙補起來了：
--     `PanelTabButtonTemplate`（SharedUIPanelTemplates.xml:927,932）
--       `Left` 錨 TOPLEFT x=-3、`Right` 錨 TOPRIGHT x=+7
--     `AchievementFrameTabButtonTemplate`（Blizzard_AchievementUI.xml:253,260）
--       `Left` 錨 TOPLEFT x=-4、`Right` 錨 TOPRIGHT x=+4
--   九張貼圖一 alpha 0，那個空隙就露出底下的地形 —— 這就是第二輪擷圖裡
--   「分頁之間的紅棕色殘片」的真身：不是漏中和的貼圖，是**沒有東西去補的縫**。
--
--   只往**右**補（不往左）是為了讓接縫上只有一條線：配方一律由左往右
--   （`for i = 1, N`）套，所以第 n+1 顆的 overlay 建得比較晚、畫在上面，
--   它的左邊線壓在第 n 顆的右延伸上 ⇒ 每個接縫剛好一條 1px 黑線，
--   最左邊留左邊線、最右邊留右邊線。兩邊都補的話接縫會變成兩條平行線。
local TAB_OVERHANG = {
    panel  = 7,   -- uiframe-tab-right 錨在 TOPRIGHT x=+7
    legacy = 4,   -- UI-Achievement-Header 的右端帽錨在 TOPRIGHT x=+4
}

local LEGACY_TAB_TEXTURES = {
    "LeftActive", "MiddleActive", "RightActive",
    "Left", "Middle", "Right",
    "LeftHighlight", "MiddleHighlight", "RightHighlight",
}

function Skin.Tab(tab, key, kind)
    if not E.Usable(tab, key) then return end

    if kind == "panel" then
        local arr
        if pcall(function() arr = tab.TabTextures end) and type(arr) == "table" then
            for i, tex in ipairs(arr) do
                E.Neutralize(tex, key .. ".TabTextures[" .. i .. "]")
            end
        else
            -- 模板換掉了就退回逐一點名，兩邊的 parentKey 名字是一樣的
            E.NeutralizeKeys(tab, LEGACY_TAB_TEXTURES, key)
        end
    else
        E.NeutralizeKeys(tab, LEGACY_TAB_TEXTURES, key)
    end

    local overhang = TAB_OVERHANG[kind or "panel"] or TAB_OVERHANG.panel
    local ov = E.Overlay(tab, {
        key = key,
        skipEdges = { "TOP" },
        points = {
            { "TOPLEFT", "TOPLEFT", 0, 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", overhang, 0 },
        },
    })
    E.Paint(ov, T.fill, T.border)

    -- 未選中的文字白色走 NormalFont；選中（＝Disabled 狀態）的白字與停用的灰字
    -- 是暴雪自己在 PanelTemplates_* 裡設 DisabledFont 的，不用我們管。
    E.ButtonFonts(tab, GameFontHighlightSmall, key)
    E.TrackTab(tab, ov, key)
    return ov
end

------------------------------------------------------------
-- TabSystem：新式分頁（`TabSystemButtonTemplate` 系）
--
-- 出處（12.1 live）：
--   Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml:3
--     `TabSystemButtonArtTemplate`：九張貼圖，parentKey 的名字跟
--     `PanelTabButtonTemplate` 一模一樣，但 parentArray 叫 **`RotatedTextures`**
--     （同檔 :27,32,37,43,48,53,61,66,72）。
--   同檔 :89 `TabSystemButtonTemplate`（10x32）、:98 `TabSystemTopButtonTemplate`
--     （多一個 `isTabOnTop=true`）、:110 `TabSystemTemplate`（← HorizontalLayoutFrame，
--     `spacing` 預設 **1**，同檔 :125）。
--   TabSystemTemplates.lua:6 `HandleRotation`：`isTabOnTop` 的分頁把九張貼圖
--     旋轉 180°，端帽改成往**左**外擴 6／7（同檔 :13,18）。
--
-- 這是**通用**原語：專業、收藏這些新式視窗的頂部分頁全都是這一套，之後會大量重用。
--
-- 狀態機、兩條同步路徑（mixin 後置勾 ＋ 重讀 `LeftActive:IsShown()`）與
-- 「為什麼不能沿用 `Skin.Tab`」全部寫在 `Core/Engine.lua` 的 `Engine.TrackTabSystem`
-- 那一段 —— 配方只要記得把 `Engine.TabSystemHooks()` 放進 `hooks`、
-- 把 `Engine.SyncTabSystemAll()` 掛在視窗的全域刷新函式後面。
--
-- opts:
--   onTop     分頁掛在內容的**上方**（`isTabOnTop=true`）⇒ 與內容相連的是**下邊**，
--             那一邊不畫。預設 false（跟模板的 `isTabOnTop` 預設一致，相連的是上邊）。
--             ⚠ 由**配方**指定，不從 `tab.isTabOnTop` 讀 —— 那是暴雪的欄位，
--               不在讀取例外表上；而配方本來就知道自己接的是哪個模板。
--   overhang  overlay 往右多畫幾點，把分頁之間的縫補起來。預設 **1** ＝
--             `TabSystemTemplate` 的 `spacing`（TabSystemTemplates.xml:125）。
--             理由跟 `Skin.Tab` 的 `TAB_OVERHANG` 一樣：只往右補，接縫上只留一條線。
------------------------------------------------------------
local TAB_SYSTEM_TEXTURES = {
    "LeftActive", "MiddleActive", "RightActive",
    "Left", "Middle", "Right",
    "LeftHighlight", "MiddleHighlight", "RightHighlight",
}

function Skin.TabSystem(tab, key, opts)
    if not E.Usable(tab, key) then return end
    opts = opts or {}

    -- 首選 parentArray（九張一次掃完，暴雪加減貼圖也跟得上），
    -- 陣列不在就退回逐一點名。
    local arr
    if pcall(function() arr = tab.RotatedTextures end) and type(arr) == "table" then
        for i, tex in ipairs(arr) do
            E.Neutralize(tex, key .. ".RotatedTextures[" .. i .. "]")
        end
    else
        E.NeutralizeKeys(tab, TAB_SYSTEM_TEXTURES, key)
    end

    local overhang = opts.overhang or 1
    local ov = E.Overlay(tab, {
        key = key,
        skipEdges = { opts.onTop and "BOTTOM" or "TOP" },
        points = {
            { "TOPLEFT", "TOPLEFT", 0, 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", overhang, 0 },
        },
    })
    E.Paint(ov, T.fill, T.border)

    -- 三態（選中／滑過／閒置）＋ 白字，全部收在 Engine 那一支
    E.TrackTabSystem(tab, ov, key)
    return ov
end

-- 把一整排新式分頁一次套完。
--
-- ⚠ **走 `GetChildren()` 認分頁，不讀 `tabSystem.tabs`。**
--   `TabSystemMixin:AddTab`（TabSystemTemplates.lua:212-221）把分頁收在
--   `self.tabs` 這個 Lua 陣列裡，但那是暴雪的欄位、不在讀取例外表上。
--   `GetChildren()` 是表上有的那一條（「讀結構不是讀值」），而且認人的依據
--   （有沒有 `RotatedTextures` 這個 parentArray）同樣只是問結構。
-- ⚠ 只掃一次。`FriendsTabHeaderMixin:GenerateHeaderTabs`（FriendsFrame.lua:642）
--   在 `OnLoad` 就把分頁建完了，之後 `RefreshTabVisibility`（:648）只做
--   Show/Hide，不會再 `AddTab` ⇒ 掃一次就夠。真的有視窗會在執行期加分頁的話，
--   那顆會落在 `Engine.TabSystemHooks` 的 mixin 後置勾上（有狀態、沒有 overlay），
--   到時候再為它想辦法。
function Skin.TabSystemAll(tabSystem, key, opts)
    if not E.Usable(tabSystem, key) then return end
    if type(tabSystem.GetChildren) ~= "function" then
        E.Missing(key .. ".GetChildren")
        return
    end
    local ok, children = pcall(function() return { tabSystem:GetChildren() } end)
    if not ok then return end

    local n = 0
    for _, child in ipairs(children) do
        local arr
        if type(child) == "table" and pcall(function() arr = child.RotatedTextures end)
            and type(arr) == "table" then
            n = n + 1
            Skin.TabSystem(child, key .. "." .. n, opts)
        end
    end
    if n == 0 then E.Missing(key .. ".tabs") end
end

------------------------------------------------------------
-- StretchButton：`UIMenuButtonStretchTemplate`（那顆銀色九宮格小鈕）
--
-- 出處（12.1 live）：
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:745
--     九張 `UI-Silver-Button-Up` 的切片，parentKey：
--     TopLeft / TopRight / BottomLeft / BottomRight /
--     TopMiddle / MiddleLeft / MiddleRight / BottomMiddle / MiddleMiddle
--     ＋ HighlightTexture（`UI-Silver-Button-Highlight`，alphaMode ADD，同檔 :839）
--     ＋ NormalFont/HighlightFont **已經是 `GameFontHighlightSmall`**（白，:836-837）、
--       DisabledFont `GameFontDisableSmall`（:838）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:820
--     `UIMenuButtonStretchMixin:SetTextures(texture)` 把那九張一起 `SetTexture`，
--     由 `OnMouseDown`(:832) / `OnMouseUp`(:841) / `OnShow`(:850) / `OnEnable`(:855)
--     各呼叫一次 ⇒ **一定要 alpha 中和，換材質撐不過一次點擊**（同 `Skin.Button`）。
--
-- 三態：滑過交給引擎。**按下沒有視覺** —— 這個模板跟 `UIPanelButtonTemplate` 一樣
-- 沒有 PushedTexture，它是靠換那九張的材質表示按下的（註 ⓒ 的同一條）。
-- 字型不碰：NormalFont 本來就是白的。
------------------------------------------------------------
local STRETCH_BUTTON_ART = {
    "TopLeft", "TopRight", "BottomLeft", "BottomRight",
    "TopMiddle", "MiddleLeft", "MiddleRight", "BottomMiddle", "MiddleMiddle",
}

function Skin.StretchButton(btn, key, opts)
    if not E.Usable(btn, key) then return end
    opts = opts or {}

    E.NeutralizeKeys(btn, STRETCH_BUTTON_ART, key)
    E.ButtonStates(btn, key)

    local ov = E.Overlay(btn, { key = key, points = opts.points, inset = opts.inset })
    E.Paint(ov, T.fill, T.border)
    return ov
end

------------------------------------------------------------
-- ScrollBar：`MinimalScrollBar`
--
-- 出處：Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml
--   bar.Track                 Frame，ARTWORK 三張：Begin / Middle / End
--   bar.Track.Thumb           EventButton，ARTWORK 三張：Begin / Middle / End
--   bar.Back / bar.Forward    EventButton，各一張 Texture
--
-- ⚠⚠ **拇指那三張只能 alpha 0，絕對不能 SetColorTexture。**
--   `MinimalScrollBarThumbScriptsMixin:OnSizeChanged`（同資料夾的 .lua）會做
--   `C_Texture.GetAtlasInfo(self.Middle:GetAtlas())` 然後讀 `info.height` ——
--   材質一換成純色，`GetAtlas()` 就回 nil，每次捲動都是一發 Lua error，
--   而且掛在我們的插件名下。這是整份計畫裡唯一一個「照原本想法寫會當場壞掉」的點。
--
-- 上下箭頭不中和，只染成次要色：藏掉會讓玩家失去「這裡可以按」的線索，
-- 而 `MinimalScrollBarStepperScriptsMixin:OnButtonStateChanged` 只換 atlas，
-- 不碰 vertex color，所以染色撐得過狀態切換。
------------------------------------------------------------
function Skin.ScrollBar(bar, key)
    if not E.Usable(bar, key) then return end

    local track
    pcall(function() track = bar.Track end)
    if not track then
        E.Missing(key .. ".Track")
        return
    end

    E.NeutralizeKeys(track, { "Begin", "Middle", "End" }, key .. ".Track")
    local trackOv = E.Overlay(track, { key = key .. ".Track", noBorder = true })
    E.Paint(trackOv, T.scrollTrack)

    local thumb
    pcall(function() thumb = track.Thumb end)
    if thumb then
        E.NeutralizeKeys(thumb, { "Begin", "Middle", "End" }, key .. ".Thumb")
        local thumbOv = E.Overlay(thumb, { key = key .. ".Thumb", noBorder = true })
        E.Paint(thumbOv, T.scrollThumb)
    else
        E.Missing(key .. ".Track.Thumb")
    end

    for _, side in ipairs({ "Back", "Forward" }) do
        local stepper
        pcall(function() stepper = bar[side] end)
        if stepper then
            local tex
            pcall(function() tex = stepper.Texture end)
            E.VertexColor(tex, T.textDim, key .. "." .. side .. ".Texture")
        else
            E.Missing(key .. "." .. side)
        end
    end
end

------------------------------------------------------------
-- EditBox：`InputBoxTemplate` / `SearchBoxTemplate`
--
-- 出處：Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml
--   InputBoxVisualTemplate → Left / Right / Middle（common-search-border-*）
--   SearchBoxTemplate      → searchIcon、clearButton.Icon、Instructions（繼承自
--                            InputBoxInstructionsTemplate）
------------------------------------------------------------
-- opts:
--   globalPrefix  舊式視窗的三張切片**只有全域名字、沒有 parentKey**
--                 （`<Texture name="$parentLeft">`，郵件的收件人／主旨、
--                  `ThinGoldEdgeTemplate`、查詢頁的欄位表頭都是這種），
--                 `NeutralizeKeys` 找不到 ⇒ 改用全域名字掃。
--                 傳 `true` 表示「前綴就是 key」。
--   points        overlay 改用自訂錨點。**舊式輸入框一定要給** ——
--                 它的邊框美術跟 EditBox 的矩形不一樣大（收件人框是 109x25，
--                 但三張切片只涵蓋 TOPLEFT(-8,-2) 到 116x20 的範圍），
--                 直接 SetAllPoints 畫出來的方塊會比暴雪原本的美術大一圈，
--                 往右壓到旁邊的「郵資」。常數一律從 XML 的錨點抄，不要量測。
function Skin.EditBox(eb, key, opts)
    if not E.Usable(eb, key) then return end
    opts = opts or {}

    E.NeutralizeKeys(eb, { "Left", "Right", "Middle" }, key)

    if opts.globalPrefix then
        local prefix = opts.globalPrefix == true and key or opts.globalPrefix
        E.NeutralizeGlobals({ prefix .. "Left", prefix .. "Middle", prefix .. "Right" })
    end

    local icon
    if pcall(function() icon = eb.searchIcon end) and icon then
        E.VertexColor(icon, T.textDim, key .. ".searchIcon")
    end

    local instructions
    if pcall(function() instructions = eb.Instructions end) and instructions then
        E.TextColor(instructions, T.textDisabled, key .. ".Instructions")
    end

    local clear
    if pcall(function() clear = eb.clearButton end) and clear then
        local cicon
        if pcall(function() cicon = clear.Icon end) and cicon then
            E.VertexColor(cicon, T.textDim, key .. ".clearButton.Icon")
        end
    end

    local ov = E.Overlay(eb, { key = key, points = opts.points })
    E.Paint(ov, T.fillInset, T.border)
    return ov
end

------------------------------------------------------------
-- CheckBox：走 getter 不點名 parentKey
--
-- 勾選框模板不只一種（`UICheckButtonTemplate`、`InterfaceOptionsCheckButtonTemplate`…），
-- 但四張狀態圖一律走 GetNormalTexture / GetPushedTexture / GetHighlightTexture /
-- GetCheckedTexture，所以這支不必知道是哪個模板。
--
-- 勾勾本身**不中和**：那是「值」不是裝飾，中和掉玩家就看不出有沒有勾。
-- 底色用比面板亮一階的 fillCheck（共用層 CHECKBOX_FILL 的理由：沒勾的時候
-- 它是唯一「什麼都沒有」的控件）。
--
-- ⚠ **已勾的樣式換成「整格填滿職業色」，不是保留暴雪的勾／圓點。**
--   第二輪實測（寄信頁的「寄送金錢／付款取信」）看得很清楚：
--   `UIRadioButtonTemplate` 的已勾是 `UI-RadioButton` 的第二格 —— 一顆為了亮色
--   圓鈕設計的小圓點，放進 16 像素的深色方框裡幾乎看不見。
--   `UICheckButtonTemplate` 的 `UI-CheckBox-Check` 也是同一個問題。
--   換成滿色之後「有沒有勾」＝「這格是不是亮的」，而且跟共用層
--   `Widgets.lua` 的 `W.CreateCheckButton`（勾＝整條職業色）是同一套顏色語彙。
--   做法走 `Engine.CheckedTexture` —— C 端自己依狀態顯示／隱藏那張貼圖，
--   我們只換長相，沒有 `SetChecked`、沒有腳本（見 Engine 那一段）。
--
-- ⚠ **邊要畫在前景。** Checked 貼圖的矩形等於按鈕矩形
--   （`UICheckButtonTemplate` 的 CheckedTexture 沒有 Size／Anchor ⇒ setAllPoints；
--    `UIRadioButtonTemplate` 的三張都是整顆 16x16 的 TexCoord 切片，
--    Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:15-23, 46-47）
--   ⇒ 填滿之後會蓋掉背景 overlay 的 1px 黑邊。所以底走 −1、邊另外走 +1
--   （`slot = "front"`），跟 StatusBar 的填充條同一個作法。
------------------------------------------------------------
function Skin.CheckBox(cb, key)
    if not E.Usable(cb, key) then return end

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        if type(cb[getter]) == "function" then
            local ok, tex = pcall(cb[getter], cb)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    E.ButtonStates(cb, key)

    local checked = { T.AccentCheck(1) }
    local checkedDisabled = { T.AccentCheckDisabled(1) }
    E.CheckedTexture(cb, checked, checkedDisabled, key)

    local ov = E.Overlay(cb, { key = key })
    E.Paint(ov, T.fillCheck, T.border)
    -- 邊畫在已勾的填色之上
    Skin.BorderOnly(cb, key)
    return ov
end

------------------------------------------------------------
-- Row：清單列（一列一筆資料的按鈕）
--
-- 沒有邊，只有底色 ＋ 引擎畫的滑過。列與列之間靠底色明暗分，不畫分隔線 ——
-- 一排都有邊會變成格子紙。
------------------------------------------------------------
-- opts:
--   fill      底色（預設 fill；`alt = true` 是舊的簡寫，等同 fillInset）
--   border    給邊（清單列預設沒有邊；成就列是一列一張卡片，那個要邊）
--   keys      順便中和的 parentKey 區域
--   points    overlay 改用自訂錨點
--   ownHover  **兩態都自己畫**：把暴雪的 Highlight 中和掉，滑過與選中都走
--             `Engine.TrackSelectable`。只有「暴雪的 Highlight 矩形跟按鈕矩形
--             不一樣大」的列需要這一條，理由與代價寫在 Engine 那一段。
function Skin.Row(btn, key, opts)
    if not E.Usable(btn, key) then return end
    if opts == true then opts = { fill = T.fillInset } end   -- 舊的 `alt` 簽章
    opts = opts or {}

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end

    if opts.ownHover then
        -- Highlight 一起中和 ⇒ 暴雪的 LockHighlight（選中）也跟著看不見，
        -- 選中與滑過兩態全部由 Engine.TrackSelectable 畫在同一個矩形上。
        if type(btn.GetHighlightTexture) == "function" then
            local ok, hl = pcall(btn.GetHighlightTexture, btn)
            if ok and hl then E.Neutralize(hl, key .. ".GetHighlightTexture") end
        end
    else
        E.ButtonStates(btn, key)
    end

    if opts.keys then
        E.NeutralizeKeys(btn, opts.keys, key)
    end

    local ov = E.Overlay(btn, { key = key, noBorder = not opts.border, points = opts.points })
    E.Paint(ov, opts.fill or T.fill, opts.border and T.border or nil)

    if opts.ownHover then
        E.TrackSelectable(btn, ov, opts.fill or T.fill)
    end
    return ov
end

------------------------------------------------------------
-- Icon：裁邊 ＋ 一圈 1px 硬邊
--
-- ⚠ 只對「確定是方形圖示」的貼圖用。已經被設過 texCoord 的（暴雪自己從合成表
--   裡挑格子的那種）不要碰 —— 再裁一次會挑到別格。
-- ⚠ **`SetTexture` 會把 texCoord 打回 0,1,0,1**，所以池化列的圖示每次 Init 都要
--   重裁一次（放在 `Engine.HookRows` 的 reapply，不是只跑一次的 apply）。
--
-- `owner` 不給就直接錨在**貼圖本身**上（圖示常常只是某個框裡的一張 20x20 貼圖，
-- 沒有自己的框）。子框永遠畫在父層貼圖之上（wow-frame-vs-texture-layering），
-- 所以這一圈邊蓋得住圖示。
------------------------------------------------------------
function Skin.Icon(tex, key, owner)
    if not E.Usable(tex, key) then return end
    E.CropIcon(tex, key)
    -- 圖示的邊要畫在**圖示之上**，所以這一個 overlay 的層級是 +1（其餘都是 −1）。
    -- 底色全透明：這層只是一圈邊。
    local ov = E.Overlay(owner or tex, { key = key .. ".border", levelOffset = 1 })
    E.Paint(ov, { 0, 0, 0, 0 }, T.border)
    return ov
end

------------------------------------------------------------
-- ItemButton：物品格（裝備欄、附件格、信件圖示鈕……）
--
-- 出處（12.1.0.69875）：
--   Blizzard_ItemButton/Shared/ItemButtonTemplate.xml:4
--     `ItemButton` intrinsic：`icon`（BORDER）、`Count`/`Stock`（ARTWORK）、
--     `searchOverlay`、`ItemContextOverlay`、`IconBorder`、`IconOverlay`、
--     `IconOverlay2`（OVERLAY 各子層）＋ `NormalTexture`（UI-Quickslot2，64x64）
--     ＋ `PushedTexture` ＋ `HighlightTexture`
--   Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:189
--     `SetItemButtonBorder_Base` → `IconBorder:SetShown(asset ~= nil)` ＋
--     `SetAtlas`／`SetTexture`（`Interface\Common\WhiteIconFrame`，**圓角**）
--   同檔 :210 `SetItemButtonQuality_Base` → 上面那支 ＋
--     `SetItemButtonBorderVertexColor`（:127）餵品質色
--   同檔 :76 `SetItemButtonTexture_Base` → `icon:SetTexture(...)`
--     ⇒ **每次更新都會把 texCoord 打回 0,1,0,1**，裁邊一定要放 reapply
--
-- 三個不同的「格子」都走這一支（欄位名字不一樣，所以兩種都找）：
--   * `ItemButton` intrinsic —— 圖示叫 `icon`（小寫）。裝備欄、讀信附件格、
--     `OpenMailLetterButton`／`OpenMailMoneyButton` 都是。
--   * 手寫的格子 —— 圖示叫 `Icon`（大寫）。收件匣每列的信件鈕
--     （`MailItemTemplate` 的 `$parentButton`，MailFrame.xml:71-99）是這種，
--     它是 `CheckButton` 不是 `ItemButton`，但一樣有 `IconBorder`。
--   * 只有 `IconBorder` 沒有圖示欄位的 —— 寄信附件格（`SendMailAttachment`，
--     MailFrame.xml:173），圖示是 `SetItemButtonTexture` 從
--     `GetItemButtonIconTexture` 拿的，取不到就只畫框、不裁邊。
--
-- 做什麼：
--   1. 暴雪那張**圓角**品質邊框中和（alpha 0）—— 圓角跟這包的直角語彙對不上。
--      ⚠ 一定要 alpha 不能換材質：`SetItemButtonBorder_Base` 每次更新都
--        `SetAtlas`／`SetTexture` 回去。
--   2. 自己畫一圈**直角方框**，邊寬走 `T.itemBorderSize`（預設 1px，走 P.Scale）。
--      顏色是**轉交**暴雪邊框當下的顏色（`Engine.PassBorderColor`，
--      當傳遞者不當讀取者）；沒有品質就是 1px 黑邊。
--   3. 圖示裁邊（`T.iconCrop`）。
--   4. 空格底圖（`NormalTexture`，那張 64x64 的 UI-Quickslot2 雕花）中和，
--      改成我們自己的 `fillInset` 底 —— 這樣空格看起來就是一個乾淨的深色方塊。
--
-- ⚠ **框畫在圖示之上，但要讓得開別的插件的文字。**
--   套組裡有插件在裝備格上畫裝等／耐久，它把自己的框做成格子的 child 並且
--   `SetFrameLevel(110)` / `(111)`；我們這一圈邊走 `levelOffset = +1`
--   （相對格子本身，通常是個位數），穩穩在那兩層之下。
--
-- ⚠ 保護框照規矩跳過（`Engine.Overlay` 自己會擋並記進 `/mskin debug`），
--   **不為物品格開後門**。
------------------------------------------------------------
local ITEM_BUTTON_ICON_KEYS = { "icon", "Icon" }

local function ItemButtonIcon(btn)
    for _, k in ipairs(ITEM_BUTTON_ICON_KEYS) do
        local tex
        if pcall(function() tex = btn[k] end) and type(tex) == "table" then
            return tex
        end
    end
    return nil
end

-- opts:
--   noFill     不要畫底（格子底下已經有別的底材時用）
--   keepNormal 不要中和 NormalTexture（那張雕花空格圖就是這顆按鈕的全部長相時用）
function Skin.ItemButton(btn, key, opts)
    if not E.Usable(btn, key) then return end
    opts = opts or {}

    -- 圓角品質框中和。`IconOverlay`／`IconOverlay2` 是「艾澤萊／腐蝕／造型」那種
    -- **額外**的圈，它們是資訊不是裝飾，留著。
    local border
    if pcall(function() border = btn.IconBorder end) and border then
        E.Neutralize(border, key .. ".IconBorder")
    else
        E.Missing(key .. ".IconBorder")
    end

    if not opts.keepNormal and type(btn.GetNormalTexture) == "function" then
        local ok, tex = pcall(btn.GetNormalTexture, btn)
        if ok and tex then E.Neutralize(tex, key .. ".GetNormalTexture") end
    end
    E.ButtonStates(btn, key)

    local icon = ItemButtonIcon(btn)
    if icon then E.CropIcon(icon, key .. ".icon") end

    if not opts.noFill then
        local bg = E.Overlay(btn, { key = key, noBorder = true })
        E.Paint(bg, T.fillInset)
    end

    -- 方框走前景 slot（+1）：要蓋在圖示之上
    local ov = E.Overlay(btn, {
        key = key .. ".quality",
        levelOffset = 1,
        borderSize = T.itemBorderSize,
    })
    E.Paint(ov, TRANSPARENT, T.border)
    E.PassBorderColor(ov, border)

    -- 登記進弱鍵表，之後暴雪每次更新這顆格子都會回到 `Skin.ItemButtonRefresh`
    E.TrackItemButton(btn, key)
    return ov
end

-- 每次暴雪更新這顆格子之後要重跑的部分：轉交顏色 ＋ 重裁圖示。
-- （`SetItemButtonTexture` 會把 texCoord 打回 0,1；品質色本來就是每次更新才有意義。）
function Skin.ItemButtonRefresh(btn, key)
    if type(btn) ~= "table" then return end
    local ov = E.GetOverlay(btn, "front")
    if not ov then return end

    local border
    if pcall(function() border = btn.IconBorder end) and border then
        -- ⚠ 暴雪每次更新都會把它 `SetShown(true)` 回來（SetItemButtonBorder_Base），
        --   所以中和也要重下一次，不然圓角框會跟我們的方框疊在一起。
        E.Neutralize(border, key .. ".IconBorder")
    end
    E.PassBorderColor(ov, border)

    local icon = ItemButtonIcon(btn)
    if icon then E.CropIcon(icon, key .. ".icon") end
end

------------------------------------------------------------
-- IconButton：一顆「圖就是內容」的小方鈕（通貨頁右上的兌換紀錄鈕）
--
-- 圖不中和、只染 textDim：中和掉就變成一顆空白方塊，玩家不知道那顆是什麼。
-- 底與邊由 overlay 畫，滑過交給引擎。
--
-- opts:
--   inset       overlay 四邊各內縮。給「圖記本身四周帶一大圈透明留白」的按鈕用：
--               收件匣的翻頁鈕是 32x32，但 `UI-SpellbookIcon-PrevPage-Up` 的箭頭
--               只佔中間一小塊 ⇒ 框畫成整個按鈕矩形就會比箭頭大一圈、看起來很空。
--   desaturate  先去飽和再染色。給「顏色烤在素材裡」的圖記用（紅金色的 ＋／− 鈕）。
--   labelColor  把按鈕自己 region 裡的 FontString 一起染色。舊式按鈕常常把說明字
--               做成**沒有名字也沒有 parentKey** 的 layer FontString（收件匣翻頁鈕
--               旁邊的「上頁」「繼續」就是，MailFrame.xml:388,413），
--               指名不到，只能走 `GetRegions()`。
--   stripFrame  **Normal/Pushed/Disabled 是「按鈕的殼」而不是「按鈕的圖」時用**：
--               改成中和那三張，再把真正的圖（`opts.iconKey`，預設 `Icon`）染 textDim。
--               `SquareIconButtonTemplate` 就是這種形狀：殼是
--               `UI-SquareButton-Up/Down/Disabled`（Blizzard_SharedXML/Shared/Button/
--               IconButtonTemplate.xml:53-55），圖是 OVERLAY 層一張獨立的 `Icon`
--               （同檔 :25）。預設那條路（染 Normal/Pushed/Disabled）是給
--               「圖就是 NormalTexture」的舊式按鈕用的，兩者不能混。
--               ⚠ 那三張只寫在 XML 裡，`IconButtonMixin` 完全不重設它們
--               （同檔 .lua:30-38 只動 `Icon` 的錨點）⇒ alpha 中和撐得住。
--   iconKey     `stripFrame` 時要染色的那張圖的 parentKey，預設 `"Icon"`。
------------------------------------------------------------
local ICON_BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }

function Skin.IconButton(btn, key, opts)
    if not E.Usable(btn, key) then return end
    opts = opts or {}

    for _, getter in ipairs(ICON_BUTTON_TEXTURES) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then
                if opts.stripFrame then
                    -- 殼不是內容：整組中和，長相交給 overlay
                    E.Neutralize(tex, key .. "." .. getter)
                else
                    if opts.desaturate then
                        -- 乘法染不出中性灰，先壓成灰階（見 Engine.Desaturate）
                        E.Desaturate(tex, key .. "." .. getter)
                    end
                    -- 停用態再暗一階：「狀態只換明暗」
                    local c = (getter == "GetDisabledTexture") and T.textDisabled or T.textDim
                    E.VertexColor(tex, opts.color or c, key .. "." .. getter)
                end
            end
        end
    end

    if opts.stripFrame then
        local iconKey = opts.iconKey or "Icon"
        local icon
        if pcall(function() icon = btn[iconKey] end) and icon then
            E.VertexColor(icon, opts.color or T.textDim, key .. "." .. iconKey)
        else
            E.Missing(key .. "." .. iconKey)
        end
    end

    E.ButtonStates(btn, key)

    if opts.labelColor then
        E.RecolorRegions(btn, opts.labelColor, key)
    end

    local ov = E.Overlay(btn, { key = key, inset = opts.inset, points = opts.points })
    E.Paint(ov, T.fill, T.border)
    return ov
end

------------------------------------------------------------
-- StatusBar：底 ＋ 邊，填充色只換明暗
--
-- ⚠ 上色走**貼圖的** SetVertexColor，不要 SetStatusBarColor ——
--   顏色分量在 12.1 可能是秘密數字，只有貼圖層的 setter 保證吃得下
--   （見 .claude/notes/wow-121-secret-values.md）。
-- ⚠ `GetStatusBarTexture()` 在材質設定之前會回 nil，所以要判空。
--
-- opts:
--   color       填充色。**不給就不碰填充** —— 聲望條的顏色是暴雪依聲望等級給的
--               （`FACTION_BAR_COLORS[reaction]`），那是**資訊**不是裝飾，改掉
--               玩家就看不出中立／友善／崇敬。而且它每次 Init 都會重設
--               （`ReputationBarMixin:UpdateBarColor` → SetStatusBarColor），
--               我們染的色本來也撐不過一次重用。
--   stripArt    true ＝ 連同「沒有名字也沒有 parentKey」的裝飾貼圖一起中和
--               （物件池 Acquire 出來的框是無名的，`$parentBG`／`$parentBorder*`
--               連全域名字都沒有）。填充貼圖會被排除。
--   texture     填充材質。**預設就換成 `T.barTexture`**（套組的細橫紋）；
--               傳 `false` 才維持暴雪原本那張。理由與「有沒有程式讀回它」的
--               查證結果寫在 `Engine.BarTexture`。
--
-- ⚠ **1px 黑邊要畫在填充條之上（前景 slot），不是之下。**
--   第二輪實測（聲望頁擷圖）的症狀是「底框的左緣不見了、填充的左端看起來露在
--   框外」—— 真正的原因是 overlay 的層級是 target−1，而 StatusBar 的填充貼圖
--   從**條的左緣**開始畫、正好壓在那條黑邊上；條走到哪、黑邊就被蓋到哪，
--   看起來就像框比條短一截。底（fillInset）留在背景沒問題（填充本來就該蓋住它），
--   只有邊要提到前景來。
------------------------------------------------------------
function Skin.StatusBar(bar, key, opts)
    if not E.Usable(bar, key) then return end
    opts = opts or {}

    if opts.texture ~= false then
        E.BarTexture(bar, opts.texture or T.barTexture, key)
    end

    local fill
    if type(bar.GetStatusBarTexture) == "function" then
        local ok, tex = pcall(bar.GetStatusBarTexture, bar)
        if ok and tex then
            fill = tex
            if opts.color then
                E.VertexColor(tex, opts.color, key .. ".StatusBarTexture")
            end
        else
            E.Missing(key .. ".StatusBarTexture")
        end
    end

    if opts.stripArt then
        E.NeutralizeRegions(bar, key, fill)
    end
    if opts.keys then
        E.NeutralizeKeys(bar, opts.keys, key)
    end

    local ov = E.Overlay(bar, { key = key, points = opts.points, noBorder = true })
    E.Paint(ov, T.fillInset)
    Skin.BorderOnly(bar, key, { points = opts.points })
    return ov
end

------------------------------------------------------------
-- Dropdown：12.x 的 `DropdownButton` 系（`Blizzard_Menu/`）
--
-- 出處（12.1.0.69875）：
--   Blizzard_Menu/Mainline/MenuTemplates.xml:3   WowStyle1DropdownTemplate
--     Background  atlas common-dropdown-textholder，BACKGROUND 層，
--                 錨 TOPLEFT −8,+7 / BOTTOMRIGHT +8,−9 ⇒ **比按鈕本身大一圈**
--     Arrow       atlas common-dropdown-a-button，OVERLAY 層
--     Text        GameFontHighlight
--   Blizzard_Menu/Mainline/MenuTemplates.xml:66  WowStyle1FilterDropdownTemplate
--     Background  atlas common-dropdown-b-button，錨 TOPLEFT −4,+4 / BOTTOMRIGHT +4,−4
--     Text        GameFontNormal（沒有 Arrow）
--   Blizzard_Menu/MenuTemplates.lua:937  WowStyle1DropdownMixin:OnButtonStateChanged
--     每次狀態改變都 `self.Arrow:SetAtlas(...)` ＋ `self.Text:SetTextColor(...)`
--   Blizzard_Menu/MenuTemplates.lua:986  WowStyle1FilterDropdownMixin:OnButtonStateChanged
--     每次狀態改變都 `self.Background:SetAtlas(...)`
--
-- 三個結論：
-- 1. Background **只能 alpha 0**（filter 那支每次狀態改變都重設 atlas）。
-- 2. Arrow **不中和、只染 textDim**：藏掉玩家就失去「這裡可以展開」的線索，
--    而暴雪只換 atlas 不碰 vertex color，染色撐得過狀態切換 —— 而且滑過時
--    暴雪自己會換成 `-hover` 那張，乘上 textDim 之後仍然是一次提亮，
--    正好是「狀態只換明暗」。這也是這支唯一的滑過回饋：`DropdownButton` 這個
--    intrinsic（Blizzard_Menu/DropdownButton.xml:3）**沒有 HighlightTexture**，
--    引擎沒有東西可以畫，而補一張等於對暴雪按鈕做結構性修改（同註 ⓒ）。
-- 3. Text：`WowStyle1DropdownMixin` 已經是 HIGHLIGHT_FONT_COLOR（白），不必碰。
--    filter 那支是 `GameFontNormal`（暗金）—— 第二／三輪的結論是「改不了」
--    （字型物件由 `baseFontObject` **欄位**驅動，寫欄位是契約禁止的）。
--    **第四輪重查之後解開了**：會重設它的兩條路 `OnEnable` / `OnDisable`
--    在模板裡是 **frame script**（Blizzard_Menu/Mainline/MenuTemplates.xml:113,114），
--    `HookScript` 就接得到，而且對已經建好的那一顆也有效。
--    走 `opts.textColor` → `Engine.DropdownText`，完整查證寫在那一支的註解裡。
--
-- **只 skin 下拉按鈕本體，彈出的選單不碰**（選單系統是 STYLE.md ⑦ 的 C 級）。
--
-- overlay **貼齊按鈕本體**，不照原本那張背景圖的矩形。
--
-- 第二輪照著 `Background` 的錨點畫（`-8,+7 / +8,-9`），實測起來是一個比按鈕大一圈
-- 的方塊：上下各多出 7~9，正好壓到下面清單的上緣（聲望／兌換通貨頁的擷圖）。
-- 那張 atlas 是「有厚邊與圓角的容器」，外框的厚度本來就不該算進我們的矩形裡。
--
-- 文字不會頂到邊：`Text` 錨在按鈕 `TOPLEFT x=8 y=-8`（MenuTemplates.xml:24），
-- 內縮是模板自己給的。右邊留 2 是因為 `Arrow` 錨在 `RIGHT x=1`（同檔 :17）——
-- 箭頭本來就突出按鈕矩形 1，不留這 2 它會壓在邊線上。
local DROPDOWN_INSETS = {
    -- kind = { 左, 上, 右, 下 }
    style1 = { 0, 0, 2, 0 },
    filter = { 0, 0, 0, 0 },
}

-- opts:
--   textColor  把 `Text` 染成這個顏色，並把暴雪兩條會重設字型物件的 script 接住
--              （`Engine.DropdownText`）。`style1` 那一支本來就是白字，**不要給**；
--              只有 `filter` 那一支需要。
function Skin.Dropdown(btn, key, kind, opts)
    if not E.Usable(btn, key) then return end
    opts = opts or {}

    E.NeutralizeKeys(btn, { "Background" }, key)

    local arrow
    if pcall(function() arrow = btn.Arrow end) and arrow then
        E.VertexColor(arrow, T.textDim, key .. ".Arrow")
    end

    if opts.textColor then
        E.DropdownText(btn, opts.textColor, T.textDisabled, key)
    end

    local inset = DROPDOWN_INSETS[kind or "style1"] or DROPDOWN_INSETS.style1
    local ov = E.Overlay(btn, {
        key = key,
        points = {
            { "TOPLEFT", "TOPLEFT", inset[1], inset[2] },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", inset[3], inset[4] },
        },
    })
    E.Paint(ov, T.fillInset, T.border)
    return ov
end

------------------------------------------------------------
-- SectionTitle：小節標題（角色面板屬性欄的三塊分類牌）
--
-- 出處：Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml:78
--   `CharacterStatFrameCategoryTemplate` → Background（atlas UI-Character-Info-Title，
--   雕花的卷軸牌）＋ Title（GameFontHighlight，已經是白的）
--
-- 樣式選的是「**標題 ＋ 標題底下一條髮絲線**」，不是「一條 fillInset 平面橫條」。
-- 理由（feedback-ui-visual-style／miliui-menu-design）：
--   * 小節標題是**後設資訊**，應該比內容弱。給它一塊實心底反而變成一個比內容還
--     重的方塊，一欄三塊就成了三條橫槓。
--   * 髮絲線已經在說「以下是新的一節」，這也是套組其他自製面板的既有寫法，
--     換一套會讓同一個套組裡出現兩種小節樣式。
--   * 線的顏色用 `fillHover`（0.23）而不是 `border`（黑）—— 深底上的分隔線要比底
--     **亮**才看得見，黑線在 0.08 的底上等於沒畫。
--
-- ⚠ 線只能錨在「標題框的下緣」，不能錨在文字底下：量文字位置要讀 FontString 的
--   尺寸／錨點，契約禁止。
------------------------------------------------------------
function Skin.SectionTitle(frame, key, opts)
    if not E.Usable(frame, key) then return end
    opts = opts or {}

    E.NeutralizeKeys(frame, { "Background" }, key)

    local title
    if pcall(function() title = frame.Title end) and title then
        E.TextColor(title, T.text, key .. ".Title")
    end

    local pad = opts.pad or 10
    local ov = E.Overlay(frame, {
        key = key .. ".rule",
        noBorder = true,
        height = 1,
        points = {
            { "BOTTOMLEFT", "BOTTOMLEFT", pad, opts.y or 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", -pad, opts.y or 0 },
        },
    })
    E.Paint(ov, T.fillHover)
    return ov
end

------------------------------------------------------------
-- ListHeader：三片式的清單分類列（那條圓角長條）
--
-- 出處（12.1.0.69875）：
--   Blizzard_SharedXML/ListTemplates.xml:53
--     `ListHeaderThreeSliceTemplate` → Left / Middle / Right（BACKGROUND）
--     ＋ HighlightLeft / HighlightMiddle / HighlightRight（HIGHLIGHT，alpha 0.4 ADD）
--     ＋ Name（GameFontNormalLeft）
--   Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml:3
--     `ReputationHeaderTemplate` —— 同樣的九個 parentKey，自己一份拷貝
--   Blizzard_SharedXML/ListTemplates.lua:160
--     `ListHeaderThreeSliceMixin:UpdateCollapsedState` 每次都
--     `self.Right:SetAtlas(collapsed and "Options_ListExpand_Right"
--                                     or "Options_ListExpand_Right_Expanded")`
--   Blizzard_UIPanels_Game/Mainline/ReputationFrame.lua:205
--     `ReputationHeaderMixin:Initialize` 對 Right / HighlightRight 做同一件事
--
-- ⚠ **`Right` 不能中和**：展開／收合的 ＋／− 記號是**烤進右端帽那張 atlas 裡**的，
--   不是獨立的一張圖。中和掉就沒有「這裡可以收合」的線索了。所以 Left/Middle
--   alpha 0、Right 只染 textDim —— 暴雪重設 atlas 不會把 vertex color 洗掉，
--   收合狀態自己會跟著換圖。
-- ⚠ `HighlightRight` 反過來**一定要中和**：它每次 Init 都被重新 SetAtlas，
--   換成純色撐不過一次重用，只有 alpha 0 擋得住。滑過帶就交給 Left ＋ Middle
--   兩張（涵蓋整列到右端帽為止）。
------------------------------------------------------------
function Skin.ListHeader(row, key)
    if not E.Usable(row, key) then return end

    E.NeutralizeKeys(row, { "Left", "Middle" }, key)
    E.NeutralizeKeys(row, { "HighlightRight" }, key)

    local right
    if pcall(function() right = row.Right end) and right then
        E.VertexColor(right, T.textDim, key .. ".Right")
    end

    for _, k in ipairs({ "HighlightLeft", "HighlightMiddle" }) do
        local tex
        if pcall(function() tex = row[k] end) and tex then
            E.HighlightTexture(tex, key .. "." .. k)
        end
    end

    local ov = E.Overlay(row, { key = key })
    E.Paint(ov, T.fill, T.border)
    return ov
end
