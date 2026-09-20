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
function Skin.Button(btn, key)
    E.NeutralizeKeys(btn, { "Left", "Right", "Middle" }, key)
    E.ButtonStates(btn, key)
    -- 文字白色：換 NormalFont，不要 SetTextColor（撐不過一次滑過，理由見 Engine.ButtonFonts）
    E.ButtonFonts(btn, GameFontHighlight, key)

    local ov = E.Overlay(btn, { key = key })
    E.Paint(ov, T.fill, T.border)
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
-- 所以整組 alpha 0，叉叉由 overlay 自己畫一張靜態圖記。
-- 滑過與按下交給引擎（Highlight → 白 8%、Pushed → 黑 18%）。
------------------------------------------------------------
local CLOSE_GLYPH = "Interface\\Buttons\\UI-StopButton"

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
        glyph = { texture = CLOSE_GLYPH, size = 10, color = T.text },
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
-- ⚠ 待辦：風格規則是「跟內容相連的那一邊不畫」（這兩個視窗的分頁掛在視窗**下緣**，
--   相連的是分頁的上邊）。PoC 先四邊都畫，等實機看過接縫再決定要不要拿掉那一條。
------------------------------------------------------------
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

    local ov = E.Overlay(tab, { key = key })
    E.Paint(ov, T.fill, T.border)

    -- 未選中的文字白色走 NormalFont；選中（＝Disabled 狀態）的白字與停用的灰字
    -- 是暴雪自己在 PanelTemplates_* 裡設 DisabledFont 的，不用我們管。
    E.ButtonFonts(tab, GameFontHighlightSmall, key)
    E.TrackTab(tab, ov, key)
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
function Skin.EditBox(eb, key)
    if not E.Usable(eb, key) then return end

    E.NeutralizeKeys(eb, { "Left", "Right", "Middle" }, key)

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

    local ov = E.Overlay(eb, { key = key })
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

    if type(cb.GetCheckedTexture) == "function" then
        local ok, tex = pcall(cb.GetCheckedTexture, cb)
        if ok and tex then E.VertexColor(tex, T.text, key .. ".Checked") end
    end

    local ov = E.Overlay(cb, { key = key })
    E.Paint(ov, T.fillCheck, T.border)
    return ov
end

------------------------------------------------------------
-- Row：清單列（一列一筆資料的按鈕）
--
-- 沒有邊，只有底色 ＋ 引擎畫的滑過。列與列之間靠底色明暗分，不畫分隔線 ——
-- 一排都有邊會變成格子紙。
------------------------------------------------------------
function Skin.Row(btn, key, alt)
    if not E.Usable(btn, key) then return end

    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    E.ButtonStates(btn, key)

    local ov = E.Overlay(btn, { key = key, noBorder = true })
    E.Paint(ov, alt and T.fillInset or T.fill)
    return ov
end

------------------------------------------------------------
-- Icon：裁邊 ＋ 一圈 1px 硬邊
--
-- ⚠ 只對「確定是方形圖示」的貼圖用。已經被設過 texCoord 的（暴雪自己從合成表
--   裡挑格子的那種）不要碰 —— 再裁一次會挑到別格。
------------------------------------------------------------
function Skin.Icon(tex, key, owner)
    E.CropIcon(tex, key)
    if owner then
        -- 圖示的邊要畫在**圖示之上**，所以這一個 overlay 的層級是 +1（其餘都是 −1）。
        -- 底色全透明：這層只是一圈邊。
        local ov = E.Overlay(owner, { key = key .. ".border", levelOffset = 1 })
        E.Paint(ov, { 0, 0, 0, 0 }, T.border)
        return ov
    end
end

------------------------------------------------------------
-- StatusBar：底 ＋ 邊，填充色只換明暗
--
-- ⚠ 上色走**貼圖的** SetVertexColor，不要 SetStatusBarColor ——
--   顏色分量在 12.1 可能是秘密數字，只有貼圖層的 setter 保證吃得下
--   （見 .claude/notes/wow-121-secret-values.md）。
-- ⚠ `GetStatusBarTexture()` 在材質設定之前會回 nil，所以要判空。
------------------------------------------------------------
function Skin.StatusBar(bar, key, color)
    if not E.Usable(bar, key) then return end

    if type(bar.GetStatusBarTexture) == "function" then
        local ok, tex = pcall(bar.GetStatusBarTexture, bar)
        if ok and tex then
            E.VertexColor(tex, color or T.fillHover, key .. ".StatusBarTexture")
        else
            E.Missing(key .. ".StatusBarTexture")
        end
    end

    local ov = E.Overlay(bar, { key = key })
    E.Paint(ov, T.fillInset, T.border)
    return ov
end
