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
-- 底壓在目標自己的區域之下，所以**一定要先中和**目標自己的底圖，
-- 不然我們畫的東西看不見。
--
-- ⚠ 第六輪起預設走 `Engine.RegionBackdrop`（底與邊直接建成**目標框自己的貼圖**，
--   不建子框）。理由與退路寫在 `Engine.RegionBackdrop` 的註解裡，一句話版本是：
--   貼圖沒有 frame level／strata／parent 的問題，保護框與 `useParentLevel` 的
--   內嵌框都不必再各自特判，而且失敗會自動退回子框那條路。
--
-- ⚠ **`opts.parent` 有給就一律走子框。** 那表示配方知道得比引擎清楚
--   （確認彈窗要掛 `dialog.BG`、ESC 選單要掛 `GameMenuFrame.Border`，
--    兩個本體都是 layout host ＋ DIALOG strata）——
--   那兩份的作法第六輪一個字都不動。
------------------------------------------------------------
function Skin.Panel(frame, key, opts)
    opts = opts or {}
    local spec = {
        key = key,
        inset = opts.inset,
        points = opts.points,
        parent = opts.parent,
    }
    local ov
    if opts.parent then
        ov = E.Overlay(frame, spec)
    else
        ov = E.RegionBackdrop(frame, spec)
    end
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

-- opts:
--   titleBar  傳 false 就不畫標題帶（標題區長得跟標準模板不一樣的視窗）
--
-- ⚠ **標題帶（第六輪）**：視窗上緣一條比面板暗一階的橫帶 ＋ 下緣一條髮絲線。
--   幾何常數從 XML 抄：`PortraitFrameBaseTemplate` 的 `TitleContainer` 是
--   `<Size y="20"/>` ＋ `TOPLEFT/TOPRIGHT y="-1"`（`Blizzard_SharedXML/Mainline/
--   SharedUIPanelTemplates.xml`）⇒ 標題那一條佔上緣往下 1~21，取 `T.titleBarHeight`
--   ＝ 22。**沒有量測任何東西。**
--
-- ⚠ 為什麼這一條可以放心畫：它走 `Engine.RegionBackdrop`，也就是**目標框自己的
--   一張 BACKGROUND 貼圖**，sublevel 排在面板底（−8）之上、其餘一切之下
--   ⇒ 它**蓋不住任何內容**（標題文字在 `TitleContainer` 這個子框上、內嵌框也是
--   子框，子框永遠畫在父層貼圖之上，見 wow-frame-vs-texture-layering）。
--   最壞的情況只是「這條帶子在這個視窗裡位置不好看」，不會是「字不見了」。
--   真的不好看就傳 `titleBar = false`。
local TITLE_BAR_SUBLEVEL = -6      -- 面板底是 −8、面板的四條邊是 −7
local TITLE_RULE_SUBLEVEL = -5

function Skin.PortraitChrome(frame, key, opts)
    opts = opts or {}
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

    if opts.titleBar == false then return end
    Skin.TitleBar(frame, key, opts.titleBarHeight)
end

------------------------------------------------------------
-- TitleBar：視窗上緣的標題帶（第七輪從 `Skin.PortraitChrome` 裡拆出來）
--
-- 第六輪只有走 `PortraitFrameTemplate` 系的視窗有這條帶子。結果是同一套皮裡
-- 兩種視窗：大部分有標題帶，而**沒有**繼承那個模板的（物品升級、成就）沒有
-- —— 那不是設計決定，只是原語的邊界剛好落在那裡。拆成獨立的一支之後，
-- 任何配方都補得上。
--
-- ⚠ 為什麼這一條可以放心畫：它走 `Engine.RegionBackdrop`，也就是**目標框自己的
--   一張 BACKGROUND 貼圖**，sublevel 排在面板底（−8）之上、其餘一切之下
--   ⇒ 它**蓋不住任何內容**（標題文字與內嵌框都是子框，子框永遠畫在父層貼圖之上，
--   見 wow-frame-vs-texture-layering）。最壞的情況只是「這條帶子在這個視窗裡
--   位置不好看」，不會是「字不見了」。
------------------------------------------------------------
function Skin.TitleBar(frame, key, height)
    if not E.Usable(frame, key) then return end
    local h = height or T.titleBarHeight

    local band = E.RegionBackdrop(frame, {
        key = key .. ".titleBar",
        slot = "titleBar",
        noBorder = true,
        sublevel = TITLE_BAR_SUBLEVEL,
        points = {
            { "TOPLEFT", "TOPLEFT", 0, 0 },
            { "TOPRIGHT", "TOPRIGHT", 0, 0 },
        },
        height = h,
    })
    E.Paint(band, T.fillInset)

    -- 下緣的髮絲線。深底上的分隔線要比底**亮**才看得見（同 `Skin.SectionTitle`）。
    local rule = E.RegionBackdrop(frame, {
        key = key .. ".titleRule",
        slot = "titleRule",
        noBorder = true,
        sublevel = TITLE_RULE_SUBLEVEL,
        points = {
            { "TOPLEFT", "TOPLEFT", 0, -h },
            { "TOPRIGHT", "TOPRIGHT", 0, -h },
        },
        height = 1,
    })
    E.Paint(rule, T.fillHover)
    return band
end

------------------------------------------------------------
-- Inset：`InsetFrameTemplate`（Bg = UI-Background-Marble ＋ NineSlice）
--
-- 內容區比外框暗一階。兩層同色就完全看不出內縮，等於把資訊層級抹平。
------------------------------------------------------------
--
-- ⚠ 第六輪起走 `Engine.RegionBackdrop`（同 `Skin.Panel`）。內嵌框特別吃這條路的好處：
--   `InsetFrameTemplate` 常常帶 `useParentLevel="true"`（商人視窗的金錢列就是），
--   那種框的層級等於**父框**的層級 ⇒ 子框 overlay 要靠「誰先建」決定誰蓋誰。
--   改成建在內嵌框自己身上的貼圖之後，那個先後順序的問題就不存在了。
function Skin.Inset(inset, key)
    E.NeutralizeKeys(inset, { "Bg", "NineSlice" }, key)
    local ov = E.RegionBackdrop(inset, { key = key })
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
-- 三態：**滑過自己畫**（底提亮 ＋ 1px 邊換成職業色，`Engine.TrackButtonHover`）——
-- 第五輪對齊套組設定視窗的按鈕語彙，理由與代價寫在 Engine 那一段。
-- 暴雪的 Highlight 因此改成中和（`ownHover`），不然白 8% 會疊在我們的提亮上。
-- **按下仍然沒有視覺** —— 這個模板沒有 PushedTexture，它是靠換 Left/Middle/Right
-- 的材質來表示按下的，而那三張已經被我們 alpha 0 了。補一張 PushedTexture 等於
-- 對暴雪按鈕做結構性修改，不在白名單裡。
------------------------------------------------------------
------------------------------------------------------------
-- 按鈕的兩種變體（第九輪）—— `Skin.Button`／`ThreeSliceButton`／`StretchButton` 共用
--
-- | 狀態 | primary（預設） | secondary（＝第五輪，不改） |
-- |---|---|---|
-- | 平時 | 底 `T.AccentButton()`、邊 `T.AccentButtonBorder()` | `fill` ＋ 黑邊 |
-- | 滑過 | 底 `T.AccentHover()`、邊 `T.Accent()` | `fillHover` ＋ 職業色邊 |
-- | 停用 | **中性**：`fill` ＋ 黑邊（字是暴雪的停用灰） | 同平時 |
-- | 按下 | 沒有視覺（這三個模板都沒有 PushedTexture，註 ⓒ） | 同左 |
--
-- 判準（STYLE.md ④「按鈕的兩種變體」）：成對／成組時「確認／執行」那顆 primary、
-- 「取消／返回／拒絕／關閉」那顆 secondary；單獨一顆 primary；一整排平行選項全部 secondary。
--
-- ⚠ 停用態走 `Engine.TrackButtonHover` 的 `disabledFill` ⇒ **多掛兩支
--   `HookScript("OnEnable"/"OnDisable")`**。零腳本那條路（DisabledTexture）在這三個
--   模板上不存在：`UIPanelButtonNoTooltipTemplate`（SecureUIPanelTemplates.xml:39-86）、
--   `ThreeSliceButtonTemplate`、`UIMenuButtonStretchTemplate` 都**沒有** `<DisabledTexture>`
--   ——停用是靠 `UIPanelButton_OnDisable`（SecureUIPanelTemplates.lua:70）換
--   Left/Middle/Right 的材質表示的，而那三張已經被我們 alpha 0。補一張 DisabledTexture
--   是結構性修改（註 ⓒ），所以只能追事件。
------------------------------------------------------------
local function PaintVariant(btn, ov, variant)
    if not ov then return end
    local pal = T.ButtonPalette(variant or "primary")
    if not pal then
        E.Paint(ov, T.fill, T.border)
        E.TrackButtonHover(btn, ov, T.fill)
        return
    end
    E.Paint(ov, pal.idle, pal.idleBorder)
    E.TrackButtonHover(btn, ov, pal.idle, nil, pal.hover, {
        idleBorder     = pal.idleBorder,
        hoverBorder    = pal.hoverBorder,
        disabledFill   = pal.disabled,
        disabledBorder = pal.disabledBorder,
    })
end

-- opts:
--   keepFont  不要換 NormalFont。給「字型物件本身帶了別的語意」的按鈕用 ——
--             好友查詢頁的欄位表頭是 `UserScaledFontGameHighlightSmall`
--             （跟著玩家的文字大小設定縮放），換成固定字級的 `GameFontHighlight`
--             等於把那個縮放弄掉。
--   points    overlay 改用自訂錨點（仍然錨在按鈕上）
--   variant   **第九輪**：`"primary"`（預設）｜`"secondary"`，見 `PaintVariant`
function Skin.Button(btn, key, opts)
    opts = opts or {}
    E.NeutralizeKeys(btn, { "Left", "Right", "Middle" }, key)
    E.ButtonStates(btn, key, nil, true)
    -- 文字白色：換 NormalFont，不要 SetTextColor（撐不過一次滑過，理由見 Engine.ButtonFonts）
    if not opts.keepFont then
        E.ButtonFonts(btn, GameFontHighlight, key)
    end

    local ov = E.Overlay(btn, { key = key, points = opts.points })
    PaintVariant(btn, ov, opts.variant)
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
        width = opts.width,
        height = opts.height,
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
    E.ButtonStates(btn, key, true, true)

    local ov = E.Overlay(btn, {
        key = key,
        inset = 2,
        glyph = { kind = "cross", size = 9, thickness = 1, color = T.text },
    })
    E.Paint(ov, T.fill, T.border)
    E.TrackButtonHover(btn, ov, T.fill)
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

------------------------------------------------------------
-- TabGroup：**一整排分頁一次套完**，接縫由「下一顆分頁的左緣」決定
--
-- 第四輪每顆分頁各自「往右多畫 overhang」把縫補起來，結果是相鄰兩顆的 overlay
-- **重疊**：後建的那顆左邊線壓在前一顆的右延伸上，而前一顆自己的右邊線還在
-- ⇒ 選中的分頁右邊變成「底色 → 1px 黑 → 2px 底色 → 1px 黑」兩條線
-- （使用者實機擷圖的角色頁／信箱頁）。
--
-- 這一輪改成：
--   * 每顆 overlay 的左緣錨在**自己**，右緣直接錨到**下一顆分頁的左緣**
--     （`Engine.Overlay` 的 `points[i].rel`）。
--   * 除了最後一顆，右邊線不畫（`skipEdges`）⇒ 接縫上永遠只有下一顆的左邊線，
--     一條 1px。
-- 暴雪把間距設成 `+3`（`PanelTemplates_AnchorTabs`）、`+1`（TabSystem 的 spacing）
-- 還是**重疊 16**（收藏視窗的底部分頁）都自動對上，配方不必再抄常數。
--
-- opts:
--   kind      "panel"（有 `TabTextures` parentArray）／"legacy"（逐一點名）
--   joined    跟內容相連、因此不畫的那一邊（預設 "TOP" ＝分頁在內容下方）
--   pad       左緣與接縫的水平偏移（預設 0）。
--             **按鈕矩形彼此重疊**的那一種要給：收藏視窗底部六顆重疊 16
--             （`Blizzard_Collections.xml` 的 `LEFT → RIGHT x="-16"`），
--             pad 給 8 之後 overlay 剛好落在按鈕矩形的正中間，分頁文字
--             （內縮 `TAB_SIDES_PADDING/2` ＝ 10）也才整段落在自己的底色上。
--
-- 每個 entry：`{ tab = <frame>, key = "..." }`，**由左往右**。
--
-- ⚠⚠ **接縫一律錨在「緊鄰的下一顆」，不跳過任何一顆。**
--   第五輪為了「暴雪會把某一顆藏起來」的情況加了一個 `hideable` 旗標，讓前一顆
--   跳過它、直接錨到再下一顆。結果是**正常情況就錯**：收藏視窗的玩具箱分頁
--   （第 3 顆）因此把 overlay 一路畫過傳家寶（第 4 顆）——
--   選中玩具箱的時候傳家寶跟著一起亮（實機擷圖 29）。
--   同一個根因還有兩個症狀：滑過玩具箱時提亮的底與邊線一路延伸到傳家寶的右緣
--   （實機擷圖 37）、切到傳家寶時它**看起來沒亮**（它自己的 overlay 有上選中色，
--   只是被玩具箱那塊橫跨過來的 overlay 蓋住了，實機擷圖 36）。
--   權衡很清楚：跳過的寫法保的是一個少數情況（時空漫遊角色才會發生），
--   代價卻是每一個玩家每一次開收藏視窗都看到三個症狀。
--   所以改成永遠錨緊鄰的下一顆；那一顆真的被藏起來時，它那一段會留一個縫
--   （藏起來的框位置仍然在，所以是縫不是錯位）—— 那是可以接受的失敗方向。
--
-- ⚠ **接壤，不重疊 —— 疊放順序因此不再是一個變數。**
--   第 n 顆的右緣 ＝ 第 n+1 顆的 `BOTTOMLEFT + pad`，
--   而第 n+1 顆的左緣 ＝ 它自己的 `TOPLEFT + pad` —— 同一個 x。
--   兩塊 overlay 剛好貼在一起、一個像素都不重疊，所以「誰畫在上面」
--   （同層級時看建立先後）對畫面沒有任何影響。
--   第四輪的 overhang 與第五輪的 `hideable` 都是「靠重疊補縫、再靠建立順序
--   決定誰蓋誰」，兩個症狀都是從那裡來的。
--   接縫上只有一條線：第 n 顆不畫右邊線（`skipEdges`），留下第 n+1 顆的左邊線。
------------------------------------------------------------
function Skin.TabGroup(list, opts)
    opts = opts or {}
    local pad = opts.pad or 0
    local joined = opts.joined or "TOP"
    -- 選中的那一條線畫在「朝外」的那一邊：分頁掛在內容下方（joined = TOP）
    -- ⇒ 線在下緣；掛在內容上方（joined = BOTTOM）⇒ 線在上緣。
    local accentSide = (joined == "BOTTOM") and "TOP" or "BOTTOM"
    local n = #list

    for i = 1, n do
        local entry = list[i]
        local tab, key = entry.tab, entry.key

        local nextTab = list[i + 1] and list[i + 1].tab or nil

        local points
        if nextTab then
            -- ⚠ BOTTOMRIGHT 錨到下一顆的 BOTTOMLEFT 會同時定住**下緣** ——
            --   一排分頁本來就等高、底邊對齊（暴雪的 AnchorTabs 是
            --   `TOPLEFT → 前一顆 TOPRIGHT`），這個前提成立才這樣寫。
            points = {
                { "TOPLEFT", "TOPLEFT", pad, 0 },
                { "BOTTOMRIGHT", "BOTTOMLEFT", pad, 0, rel = nextTab },
            }
        else
            points = {
                { "TOPLEFT", "TOPLEFT", pad, 0 },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", -pad, 0 },
            }
        end

        local skip = { joined }
        if nextTab then skip[#skip + 1] = "RIGHT" end

        Skin.Tab(tab, key, opts.kind, {
            points = points,
            skipEdges = skip,
            accentSide = accentSide,
        })
    end
end

-- opts（`Skin.TabGroup` 用；舊簽章 `Skin.Tab(tab, key, kind)` 照樣可用）：
--   points      overlay 的錨點（不給就是舊的「往右多畫 overhang」）
--   skipEdges   不畫的邊（不給就是「上邊不畫」）
--   accentSide  選中時那條職業色線畫在哪一邊（不給就是下緣）
function Skin.Tab(tab, key, kind, opts)
    if not E.Usable(tab, key) then return end
    opts = opts or {}

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
        skipEdges = opts.skipEdges or { "TOP" },
        points = opts.points or {
            { "TOPLEFT", "TOPLEFT", 0, 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", overhang, 0 },
        },
        -- 選中時那條職業色線（`Engine.PaintTab` 負責開關），建立時就定好
        accentSide = opts.accentSide or "BOTTOM",
        accentSize = T.tabAccentSize,
    })
    E.Paint(ov, T.fill, T.border)

    -- 文字的三態全部交給暴雪自己的字型物件系統（`PanelTabButtonTemplate` 的
    -- `NormalFont` / `HighlightFont` / `DisabledFont`，
    -- SharedUIPanelTemplates.xml:1330-1332）：
    --   * `HighlightFont` 本來就是 `GameFontHighlightSmall`（白）⇒ **滑過自動變白**
    --   * 選中的分頁被 `PanelTemplates_SelectTab` 設成 Disabled 狀態，
    --     而 `DisabledFont` 也是 `GameFontHighlightSmall`（白）⇒ **選中自動是白的**
    --   * 我們只換 `NormalFont`，也就是「閒置」那一態。
    -- `"underline"` 樣式把閒置降到 `textDim`（同一個字型、只換顏色，見 Engine.DimFont）；
    -- `"fill"` 退回第五輪的白字。**一顆腳本都沒多掛。**
    if T.tabStyle == "fill" then
        E.ButtonFonts(tab, GameFontHighlightSmall, key)
    else
        E.ButtonFonts(tab, E.DimFont(GameFontHighlightSmall, "MiliUISkinFontTabDim"), key)
    end
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

    -- 接縫：往右多畫 `overhang`（＝`TabSystemTemplate` 的 `spacing`，預設 1）**並且
    -- 不畫右邊線**（`opts.hasNext`）⇒ 接縫上只剩下一顆的左邊線，一條 1px。
    -- 第四輪只做了前半，結果兩顆的邊線緊貼成一條 2px 的粗線（同 `Skin.Tab` 的症狀，
    -- 只是細一點）。
    --
    -- ⚠ 這裡**不學 `Skin.TabGroup` 去錨下一顆的左緣**：`TabSystemTemplate` 是
    --   `HorizontalLayoutFrame`（`TabSystemTemplates.xml`），藏起來的分頁會被排除在
    --   排版之外、位置不保證是最新的 —— 錨在它身上等於錨在一個過期的矩形上。
    --   反過來說也不需要：layout frame 會把剩下的分頁重排成連續的一排，
    --   間距永遠是 `spacing`，往右多畫 `spacing` 就剛好接上。
    local skip = { opts.onTop and "BOTTOM" or "TOP" }
    if opts.hasNext then skip[#skip + 1] = "RIGHT" end

    local overhang = opts.overhang or 1
    local ov = E.Overlay(tab, {
        key = key,
        skipEdges = skip,
        points = {
            { "TOPLEFT", "TOPLEFT", 0, 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", overhang, 0 },
        },
        -- 選中的那條職業色線畫在「朝外」的那一邊：分頁在內容上方（onTop）
        -- ⇒ 線在上緣，否則在下緣。跟 `Skin.TabGroup` 同一條規則。
        accentSide = opts.onTop and "TOP" or "BOTTOM",
        accentSize = T.tabAccentSize,
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
    -- ⚠ `opts` 是選用的：少了這一行，不傳 opts 的呼叫端會在下面讀 `opts.onTop` 時炸掉，
    --   而且是炸在「視窗第一次載入」那一刻（實機抓到：專業視窗）。
    opts = opts or {}
    if not E.Usable(tabSystem, key) then return end
    if type(tabSystem.GetChildren) ~= "function" then
        E.Missing(key .. ".GetChildren")
        return
    end
    local ok, children = pcall(function() return { tabSystem:GetChildren() } end)
    if not ok then return end

    -- 先收齊，再串接縫（每一顆的右緣錨到下一顆的左緣）。
    -- ⚠ `GetChildren()` 的順序是建立順序，而 `TabSystemMixin:AddTab` 是由左往右
    --   一顆一顆加的（`TabSystemTemplates.lua:212`）⇒ 順序就是版面順序。
    local tabs = {}
    for _, child in ipairs(children) do
        local arr
        if type(child) == "table" and pcall(function() arr = child.RotatedTextures end)
            and type(arr) == "table" then
            tabs[#tabs + 1] = child
        end
    end
    if #tabs == 0 then
        E.Missing(key .. ".tabs")
        return
    end

    for i, tab in ipairs(tabs) do
        Skin.TabSystem(tab, key .. "." .. i, {
            onTop    = opts.onTop,
            overhang = opts.overhang,
            hasNext  = tabs[i + 1] ~= nil,
        })
    end
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
    E.ButtonStates(btn, key, nil, true)

    local ov = E.Overlay(btn, { key = key, points = opts.points, inset = opts.inset })
    PaintVariant(btn, ov, opts.variant)      -- 第九輪：opts.variant（預設 primary）
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

    -- ⚠ 第六輪：軌道與拇指都收成一條**置中的細條**（`T.scrollThumbSize`），
    --   不再整塊塗滿。暴雪的拇指矩形有十幾點寬，塗滿之後是一根跟內容搶注意力的
    --   灰柱；捲軸是「還有多少沒看到」的次要資訊，細條就夠了。
    --   長度仍然完全由暴雪決定（那才是資訊），我們只收窄。
    --   ⚠ 只錨上下兩端 ＋ 自己給寬度 ⇒ 垂直捲軸才對。這一整包遇到的
    --     `MinimalScrollBar` 全部是垂直的（清單、說明文字），水平的另外遇到再說。
    local thin = T.scrollThumbSize
    local thinPoints = {
        { "TOP", "TOP", 0, 0 },
        { "BOTTOM", "BOTTOM", 0, 0 },
    }

    E.NeutralizeKeys(track, { "Begin", "Middle", "End" }, key .. ".Track")
    local trackOv = E.Overlay(track, {
        key = key .. ".Track", noBorder = true,
        points = thinPoints, width = thin,
    })
    E.Paint(trackOv, T.scrollTrack)

    local thumb
    pcall(function() thumb = track.Thumb end)
    if thumb then
        E.NeutralizeKeys(thumb, { "Begin", "Middle", "End" }, key .. ".Thumb")
        local thumbOv = E.Overlay(thumb, {
            key = key .. ".Thumb", noBorder = true,
            points = thinPoints, width = thin,
        })
        E.Paint(thumbOv, T.scrollThumb)
        -- 滑過提亮。⚠ 閒置的拇指是 0.35，比 `fillHover`（0.23）還亮
        -- ⇒ 一定要自己給滑過色，不然會變成「滑過反而變暗」。
        E.TrackButtonHover(thumb, thumbOv, T.scrollThumb, nil, T.scrollThumbHover)
    else
        E.Missing(key .. ".Track.Thumb")
    end

    -- ⚠⚠ **第七輪：上下箭頭改成中和 ＋ 自己畫的 ∧／∨ 線條圖記。**
    --
    -- 出處（12.1 live，`Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml`）：
    --   `Back`／`Forward` 各是 17x11 的 EventButton，錨在捲軸的 TOP／BOTTOM，
    --   底下一張 parentKey 是 `Texture` 的 atlas 貼圖；
    --   `Track` 錨 `TOP y=-19` / `BOTTOM y=19` ⇒ 軌道本來就讓開了那兩段。
    -- 中和撐得住，同檔 `.lua` 的 `MinimalScrollBarStepperScriptsMixin` 只有兩處碰它：
    --   `:OnLoad` → `SetDisplacedRegions(1, -1, self.Texture)`（按下時位移）
    --             ＋ `DesaturateIfDisabled()`
    --   `:OnButtonStateChanged` → `self.Texture:SetAtlas(self:GetAtlas(), UseAtlasSize)`
    --   **一行 `SetAlpha`／`SetShown` 都沒有** ⇒ alpha 中和撐得過狀態切換。
    --
    -- ⚠ 圖記畫在**我們自己的一層 overlay** 上（`noBorder`、無底色），不是把
    --   軌道那一條延伸過去：延伸過去的話拇指永遠走不到軌道的兩端，捲到底時會
    --   在頭尾各留一段空軌，讀起來像「捲不完」。
    -- ⚠ `T.scrollStepper = "hide"` 一行就切成「整個中和、什麼都不補」。
    for _, side in ipairs({ "Back", "Forward" }) do
        local stepper
        pcall(function() stepper = bar[side] end)
        if stepper then
            local tex
            pcall(function() tex = stepper.Texture end)
            if T.scrollStepper == "hide" then
                E.Neutralize(tex, key .. "." .. side .. ".Texture")
            else
                E.Neutralize(tex, key .. "." .. side .. ".Texture")
                local stepOv = E.Overlay(stepper, {
                    key = key .. "." .. side,
                    noBorder = true,
                    glyph = {
                        kind = (side == "Back") and "chevronUp" or "chevronDown",
                        size = T.glyphSize, thickness = 1, color = T.textDim,
                    },
                })
                -- 底色全透明：這一層只是拿來掛圖記的。
                E.Paint(stepOv, TRANSPARENT)
                -- 捲到頭的那一顆暴雪會 `Disable()` ⇒ 圖記跟著變暗
                -- （原本那張 atlas 的灰掉版本已經被我們中和了）。
                E.TrackGlyph(stepper, stepOv, { trackHover = true, trackEnabled = true })
            end
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

    -- 預設照暴雪原本那組美術的幾何畫（`InputBoxVisualTemplate`，InputBoxTemplates.xml:46-62）：
    -- Left 錨 LEFT x=-5、Right 錨 RIGHT x=0、三段都是 20 高、垂直置中。
    -- ⚠ **不是**輸入框本身的矩形：框可以比美術高（成就搜尋框 107x30，
    --   Blizzard_AchievementUI.xml:1710），照框畫會變成一塊 30 高的方塊；
    --   左緣也少了那 5，放大鏡（LEFT x=1）就貼在邊線上。
    -- 只在認得這組美術（有 `Left`）時才這樣畫；呼叫端給了 points 就照呼叫端。
    local points, height = opts.points, nil
    if not points then
        local left
        if pcall(function() left = eb.Left end) and left then
            points = { { "LEFT", "LEFT", -5, 0 }, { "RIGHT", "RIGHT", 0, 0 } }
            height = 20
        end
    end

    local ov = E.Overlay(eb, { key = key, points = points, height = height })
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
-- ⚠⚠ **第六輪整個換掉了「已勾」的畫法。**
--
--   第三～五輪是「已勾＝整格填滿職業色」（`Engine.CheckedTexture` →
--   `SetColorTexture`）。那條路的前提是「方框很小，暴雪的細勾看不見」，
--   但實機上**方框一點都不小** —— overlay 照按鈕矩形畫，而暴雪的勾選按鈕矩形
--   常常是 32x32（`UICheckButtonTemplate`）、24x24（插件列表）。
--   結果就是使用者看到的一整排大方塊（實機擷圖 33，原話：「方塊好醜」）。
--
--   現在對齊套組自己的設定視窗（共用層 `Widgets.lua` 的 `W.CreateCheckButton`）：
--     * **方框固定邊長、置中**（`T.checkBoxSize` ＝ 18，跟共用層同一個數字），
--       跟按鈕矩形多大無關 —— 也就不必為每個模板各查一個內縮量。
--     * 未勾與已勾**同一個底**（`fillCheck`），狀態全部由那個勾表示。
--     * 勾**保留暴雪自己的形狀**，只去飽和 ＋ 染職業色（`Engine.CheckedGlyph`）。
--       Checked 貼圖仍然是整顆按鈕大（setAllPoints），比 18 的方框大
--       ⇒ 共用層那個「勾刻意比框大一圈往外溢」的效果自動成立。
--
-- ⚠ **邊仍然畫在前景。** Checked 貼圖的矩形等於按鈕矩形
--   （`UICheckButtonTemplate` 的 CheckedTexture 沒有 Size／Anchor ⇒ setAllPoints；
--    `UIRadioButtonTemplate` 的三張都是整顆 16x16 的 TexCoord 切片，
--    Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:15-23, 46-47）
--   ⇒ 勾會畫在背景 overlay 的黑邊之上。所以底走 −1、邊另外走 +1
--   （`slot = "front"`），跟第五輪一樣。
--
-- opts:
--   boxSize    方框邊長（像素）。預設 `T.checkBoxSize`。
--   keepCheck  **完全不碰 Checked 貼圖。** 給「那張圖本身帶了狀態語意」的勾選框：
--              插件列表的三態勾選（`TriStateCheckbox_SetState` 用
--              `SetDesaturated` 區分「全部啟用」與「部分角色啟用」，
--              我們一染色那個區分就沒了），而且它的 Checked 本來就是
--              `checkmark-minimal` —— 白勾配深色小方框，長相已經是我們要的。
--   noHover    不掛 `HookScript`（確認彈窗／ESC 選單那兩個特許視窗）
------------------------------------------------------------
function Skin.CheckBox(cb, key, opts)
    opts = opts or {}
    if not E.Usable(cb, key) then return end

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        if type(cb[getter]) == "function" then
            local ok, tex = pcall(cb[getter], cb)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    E.ButtonStates(cb, key, nil, true)

    if not opts.keepCheck then
        E.CheckedGlyph(cb, { T.AccentCheck(1) }, { T.AccentCheckDisabled(1) }, key,
            { boxSize = opts.boxSize, radio = opts.radio })
    end

    -- 置中的固定邊長方框（**不量按鈕**，見上）
    local size = opts.boxSize or T.checkBoxSize
    local boxPoints = { { "CENTER", "CENTER", 0, 0 } }

    local ov = E.Overlay(cb, {
        key = key, points = boxPoints, width = size, height = size,
    })
    -- 邊跟底畫在**同一層、都在勾的下面**。第三～六輪邊是另一層前景（那時已勾＝整格填色，
    -- 邊不畫在上面會被蓋掉）；現在勾比框大、刻意往外溢，前景的邊反而會橫切過勾（實機擷圖）。
    E.Paint(ov, T.fillCheck, T.border)
    if not opts.noHover then
        E.TrackButtonHover(cb, ov, T.fillCheck)
    end
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
--             ⚠ **第七輪：這一種列的選中態多一條左緣職業色直條**（見下）。
--   noAccentLine
--             不要那條左緣直條。給「左緣已經被別的東西佔住」的列用
--             （目前沒有實例，留給配方當退路）。
--
-- ⚠⚠ **第七輪：清單列的語彙統一成「滑過提亮一階／選中＝壓暗職業色底 ＋ 左緣 2px
--   職業色條」。** 在這之前各視窗各做各的：成就分類列與好友列是整塊 `AccentFill`、
--   插件列表只有 `ownHover` 的底色明暗、商人格什麼都沒有 —— 同一個套組裡「選中」
--   長三種樣子。
--
--   為什麼加那條直條而不是只換底色（`miliui-menu-design` 第二條）：顏色是最弱的
--   一層訊號。暗色系職業（戰士 0.78/0.61/0.43 壓到 0.45）的底跟 `fillHover`（0.23）
--   在低對比螢幕上幾乎分不出來 —— 一條**滿飽和**的職業色直條是第二層（結構）訊號，
--   而且跟分頁那條線是同一個語彙（選中＝一條職業色線），只是換了方向。
--   ⚠ 分頁的線畫在「朝外」的那一邊、清單列畫在左緣：兩者不會同時出現在同一個
--   元件上，所以不算兩個語意共用一個訊號。
--
-- ⚠ **只有 `ownHover` 的列有這條線。** 沒有 `ownHover` 的列（坐騎／寵物清單、
--   搜尋結果列）本來就沒有「選中」這個狀態掛點 —— 為了畫一條線去新增 hook
--   是本末倒置。
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

    local accent = opts.ownHover and not opts.noAccentLine
    local ov = E.Overlay(btn, {
        key = key,
        noBorder = not opts.border,
        points = opts.points,
        accentSide = accent and (opts.accentSide or "LEFT") or nil,   -- opts.accentSide：大類鈕的左緣被圖示蓋住，改畫右緣
        accentSize = T.rowAccentSize,
    })
    E.Paint(ov, opts.fill or T.fill, opts.border and T.border or nil)

    if opts.ownHover then
        E.TrackSelectable(btn, ov, opts.fill or T.fill, { accentLine = accent })
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
--   glyph       **Normal/Pushed/Disabled 是暴雪的立體小圖，而那個圖形我們畫得出來**
--               時用：三張整組中和，改畫自己的線條圖記（`Engine` 的 `BuildGlyph`）。
--               第五輪只有 `"expand"`／`"collapse"`；第七輪多了
--               `"chevronLeft"`／`"chevronRight"`（翻頁鈕）與 `"plus"`／`"minus"`。
--   glyphSize   圖記的外框邊長，預設 9。
--   glyphColor  **有給才把圖記交給三態管**（閒置這個色／滑過白／停用 `textDisabled`）。
--               翻頁鈕那一類是「次要指示符號」⇒ 給 `T.textDim`；
--               最大化／最小化那兩顆的 ＋／− 是按鈕的全部內容 ⇒ 不給，維持靜態白。
--   trackEnabled  追「這顆能不能按」（翻頁鈕到頭時暴雪會 `Disable()`）。
--               詳見 `Engine.TrackGlyph`。
------------------------------------------------------------
local ICON_BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }

function Skin.IconButton(btn, key, opts)
    if not E.Usable(btn, key) then return end
    opts = opts or {}

    for _, getter in ipairs(ICON_BUTTON_TEXTURES) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then
                if opts.stripFrame or opts.glyph then
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

    E.ButtonStates(btn, key, nil, true)

    if opts.labelColor then
        E.RecolorRegions(btn, opts.labelColor, key)
    end

    local ov = E.Overlay(btn, {
        key = key,
        inset = opts.inset,
        points = opts.points,
        glyph = opts.glyph and {
            kind = opts.glyph,
            size = opts.glyphSize or 9,
            thickness = 1,
            color = opts.glyphColor or T.text,
        } or nil,
    })
    E.Paint(ov, T.fill, T.border)
    E.TrackButtonHover(btn, ov, T.fill)
    -- 圖記的三態（第七輪）。`glyphColor` 有給才交給三態管 ——
    -- 最大化／最小化那兩顆的 ＋／− 是**白**的（它是按鈕的全部內容，不是次要指示），
    -- 維持第五輪的靜態白字，不進三態。
    if opts.glyph and opts.glyphColor then
        E.TrackGlyph(btn, ov, {
            idle = opts.glyphColor,
            trackEnabled = opts.trackEnabled,
        })
    end
    return ov
end

------------------------------------------------------------
-- SquareIconButton：`SquareIconButtonTemplate`（殼是 UI-SquareButton-*、圖是 `Icon`）
--
-- 只是 `Skin.IconButton` 的 `stripFrame` 模式取個名字 —— 第四輪有兩份配方各自
-- 寫了一支同名的 local（STYLE.md ⑤ 的 `TODO(升格)`），配方裡看不出「這是哪個
-- 暴雪模板」，升格之後模板名就是函式名。
------------------------------------------------------------
function Skin.SquareIconButton(btn, key, opts)
    opts = opts or {}
    return Skin.IconButton(btn, key, {
        stripFrame = true,
        iconKey    = opts.iconKey,
        color      = opts.color,
        inset      = opts.inset,
        points     = opts.points,
    })
end

------------------------------------------------------------
-- SlotIconButton：「底圖無名、圖示是 parentKey，而且圖示本身帶狀態」的圖示鈕
--
-- 出處（12.1 live）：`Blizzard_UIPanels_Game/Mainline/MerchantFrame.xml:187,220,280,318`
--   賣垃圾／修裝／修全部／公會修裝四顆 —— 一張**無名無 parentKey** 的
--   `UI-EmptySlot`（64x64）＋ `PushedTexture`，**沒有** NormalTexture／DisabledTexture。
--
-- 跟 `Skin.IconButton` 的差別只有一條：**`Icon` 完全不碰**。
-- 暴雪用 `Icon:SetDesaturated(...)` 表示「不能修裝／沒有垃圾」，那是狀態不是裝飾；
-- 我們要是也去染它，狀態就被抹掉了。
--
-- ⚠ keep-set 一定要把 `GetHighlightTexture()` 那張留下來 —— 中和過的貼圖再也
--   上不了色（區域 alpha 與顏色 alpha 相乘，見 `Engine.ButtonStates`）。
------------------------------------------------------------
function Skin.SlotIconButton(btn, key, opts)
    if not E.Usable(btn, key) then return end
    opts = opts or {}

    E.NeutralizeRegions(btn, key, E.KeepSet(btn, opts.keep or { "Icon" },
        opts.keepGetters or { "GetHighlightTexture" }))
    E.ButtonStates(btn, key, nil, true)

    local ov = E.Overlay(btn, { key = key, inset = opts.inset, points = opts.points })
    E.Paint(ov, T.fill, T.border)
    E.TrackButtonHover(btn, ov, T.fill)
    return ov
end

------------------------------------------------------------
-- ThreeSliceButton：`ThreeSliceButtonTemplate`（`SharedButton*Template` 系）
--
-- 出處（12.1 live）：
--   `Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:4,62,83`
--   跟 `UIPanelButtonTemplate` 只差一個名字：中間那一片叫 **`Center`** 不是 `Middle`
--   （直接套 `Skin.Button` 會留下中間那一片沒中和）。
--   同名 `.lua` 的 `UpdateButton` 每次狀態改變都重設三張的 **atlas** ⇒ 一定要 alpha。
------------------------------------------------------------
function Skin.ThreeSliceButton(btn, key, opts)
    if not E.Usable(btn, key) then return end
    opts = opts or {}

    E.NeutralizeKeys(btn, { "Left", "Right", "Center" }, key)
    E.ButtonStates(btn, key, nil, true)
    if not opts.keepFont then
        E.ButtonFonts(btn, GameFontHighlight, key)
    end

    local ov = E.Overlay(btn, { key = key, points = opts.points })
    PaintVariant(btn, ov, opts.variant)      -- 第九輪：opts.variant（預設 primary）
    return ov
end

------------------------------------------------------------
-- InputScroll：`InputScrollFrameTemplate`（多行輸入框）
--
-- 出處（12.1 live）：
--   `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:72`
--   九張 `*Tex` 切片，跟 `InputBoxTemplate` 的 Left/Right/Middle 完全不同一組名字
--   ⇒ `Skin.EditBox` 套不上去（第四輪配方裡的 local `SkinInputScroll`）。
--   它繼承 `ScrollFrameTemplate` ⇒ `.ScrollBar` 是 `MinimalScrollBar`。
------------------------------------------------------------
local INPUT_SCROLL_ART = {
    "TopLeftTex", "TopRightTex", "TopTex",
    "BottomLeftTex", "BottomRightTex", "BottomTex",
    "LeftTex", "RightTex", "MiddleTex",
}

function Skin.InputScroll(frame, key, opts)
    if not E.Usable(frame, key) then return end
    opts = opts or {}

    E.NeutralizeKeys(frame, INPUT_SCROLL_ART, key)

    local ov = E.Overlay(frame, { key = key, points = opts.points })
    E.Paint(ov, T.fillInset, T.border)

    local bar
    if pcall(function() bar = frame.ScrollBar end) and bar then
        Skin.ScrollBar(bar, key .. ".ScrollBar")
    end
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
--   pad         底與邊往外推幾個框架單位（預設 0）。
--               給「條的文字比條還高」的那幾種用 —— 聲望條只有 13 高
--               （`ReputationFrame.xml` 的 `ReputationBarTemplate`），
--               上面那條 `BarText` 是 `GameFontHighlightSmall`，中文字面高過 13
--               ⇒ 不留內距的話字的上下兩端會頂到邊線上。
--
-- ⚠ **1px 黑邊畫在條之下、而且往外推一圈** —— 這是第五輪改的。
--
--   第二輪：邊跟底同一層（target−1）⇒ 填充貼圖從條的左緣開始畫、蓋住黑邊，
--           看起來像「框比條短一截」。
--   第三輪：把邊提到**前景**（target+1）。填充蓋不到了，但條上的文字
--           （`BarText`／`Label`／`$parentText`）也在條上 ⇒ 1px 黑線改成橫切過
--           文字（使用者實機擷圖的聲望頁與成就總結頁，「字被擋住」）。
--   第五輪：邊回到**背景**（target−1）、矩形往外推 1px ——
--           填充在條的矩形**內**、碰不到往外推的邊；文字在條**上**、
--           也碰不到。兩個症狀同時沒有，而且不必跟任何一層搶層級。
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

    -- 底：條的矩形（＋ opts.pad），沒有邊
    local pad = opts.pad or 0
    local basePoints = opts.points or {
        { "TOPLEFT", "TOPLEFT", 0, 0 },
        { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
    }
    local fillPoints = pad ~= 0 and E.ExpandPoints(basePoints, pad) or basePoints

    -- ⚠ 第六輪：底與邊都改成**建在條自己身上的貼圖**（`Engine.RegionBackdrop`）。
    --   第五輪是「下層子框 ＋ 矩形往外推」，這一輪把子框拿掉之後，
    --   「邊會不會橫切過條上的文字」這個問題從根本上消失了：
    --   同一個框裡的 region 是按 draw layer 交錯的，文字（OVERLAY／ARTWORK）
    --   天然浮在 BACKGROUND 的底與 BORDER 的邊之上，不必跟任何層級搶。
    --   （`pad` 的語意不變：底與邊一起往外推，給「字比條高」的那幾種。）
    local ov = E.RegionBackdrop(bar, { key = key, points = fillPoints, noBorder = true })
    E.Paint(ov, T.fillInset)

    -- 邊：矩形再往外推 1px ⇒ 那一圈落在條的矩形**外面**，填充碰不到它。
    -- ⚠ slot 要跟底分開（底用預設的 "main"），不然冪等會把第二次呼叫
    --   當成同一個背景直接回傳上一個。
    local border = E.RegionBackdrop(bar, {
        key = key .. ".border",
        slot = "border",
        points = E.ExpandPoints(fillPoints, 1),
        -- 邊在 BORDER 層：確保它畫在自己的底（BACKGROUND）之上，
        -- 同時仍然在填充貼圖與文字之下。
        edgeLayer = "BORDER",
        edgeSublevel = -7,
    })
    E.Paint(border, TRANSPARENT, T.border)
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
    local glyph

    E.NeutralizeKeys(btn, { "Background" }, key)

    -- ⚠⚠ **第七輪：箭頭改成中和 ＋ 自己畫的 ⌄ 線條圖記。**
    --
    -- 第五輪是「先 `SetDesaturated(true)` 再染 `textDim`」。那解決了「深灰面板上
    -- 一顆很亮的黃色三角形」（實機擷圖 16），但留下的仍然是暴雪那張**立體、帶
    -- 內描邊**的三角形 atlas —— 在 1px 硬邊的直角語彙裡它是唯一一顆有厚度的零件。
    --
    -- 中和撐得住，查證過（12.1 live，`Blizzard_Menu/MenuTemplates.lua`）：
    --   `WowStyle1DropdownMixin:OnButtonStateChanged`（:455-462）碰 Arrow 的只有
    --   一行 `self.Arrow:SetAtlas(self:GetArrowAtlas(), UseAtlasSize)` ——
    --   **沒有 `SetAlpha`、沒有 `SetShown`**，而 alpha 與 atlas 是兩個獨立的屬性。
    --   全檔唯一對 Arrow 下 `SetShown`／`SetDesaturated` 的是
    --   `WowStyle2DropdownMixin:OnButtonStateChanged`（:540-541），那是**另一個**
    --   模板，這支原語不接它（配方只送 style1／filter 進來）。
    --   ⇒ 真的哪天送了一顆 style2 進來，最壞的情況是「箭頭在滑鼠移開時被暴雪
    --     `SetShown(false)`，而我們的 ⌄ 還在」——多一顆圖記，不是少一個功能。
    --
    -- ⚠ 只有**真的有 Arrow** 的那一種才畫（filter 那一支沒有 Arrow，也不該憑空
    --   長出一顆箭頭）。位置照抄 XML 的錨點：`Arrow` 錨在按鈕的 `RIGHT x=1`
    --   （`MenuTemplates.xml:17`）⇒ 我們的圖記也錨在 overlay 的 RIGHT，
    --   往內縮一個半徑多一點。
    local arrow
    if pcall(function() arrow = btn.Arrow end) and arrow then
        E.Neutralize(arrow, key .. ".Arrow")
        glyph = {
            kind = "chevronDown",
            size = T.glyphSize,
            thickness = 1,
            color = T.textDim,
            anchor = "RIGHT",
            x = -(T.glyphSize),
        }
    end

    -- 篩選下拉的 `Text` 是 `GameFontNormal`（暗金），壓在深底上偏灰 ——
    -- 第四輪查清楚了兩條會重設字型物件的路徑都是 frame script、接得住
    -- （`Engine.DropdownText`），所以這一種**預設**就接管成白字，不必每個配方各記一次。
    -- `style1` 那一支本來就是 `HIGHLIGHT_FONT_COLOR`（白），不要碰。
    local textColor = opts.textColor or (kind == "filter" and T.text or nil)
    if textColor then
        E.DropdownText(btn, textColor, T.textDisabled, key)
    end

    local inset = DROPDOWN_INSETS[kind or "style1"] or DROPDOWN_INSETS.style1
    local ov = E.Overlay(btn, {
        key = key,
        points = {
            { "TOPLEFT", "TOPLEFT", inset[1], inset[2] },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", inset[3], inset[4] },
        },
        glyph = glyph,
    })
    E.Paint(ov, T.fillInset, T.border)
    -- 第五輪補上滑過：這個 intrinsic 沒有 HighlightTexture（註 ⓕ），原本唯一的
    -- 回饋是暴雪自己把 Arrow 換成 `-hover` atlas —— 那顆箭頭只有幾像素，
    -- 在一整排下拉裡看不出「游標在哪一顆上」。底提亮 ＋ 職業色邊補上這一條。
    -- ⚠ `opts.noHover`：確認彈窗／ESC 選單是「零按鈕 HookScript」的特許視窗
    --   （STYLE.md ⑦），那裡的下拉不掛這一支。
    if not opts.noHover then
        E.TrackButtonHover(btn, ov, T.fillInset)
    end
    -- ⌄ 跟著邊框一起提亮（`noHover` 的視窗裡它就停在 `textDim`，等同靜態）。
    -- ⚠ `TrackGlyph` 本身不掛任何腳本（`trackEnabled` 才掛），所以「零 HookScript」
    --   的特許視窗照樣呼叫得起。
    if glyph then
        E.TrackGlyph(btn, ov)
    end
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
