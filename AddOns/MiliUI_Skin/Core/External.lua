------------------------------------------------------------
-- 對外 handle：`MiliUISkin_API`
--
-- 別的插件自己有一套「皮膚」系統、會把自己的每一個框逐一交給皮膚處理時
-- （例：背包插件的皮膚下拉選單），這裡給它一個 handle，讓它把框交給
-- **這一包的原語**畫 —— 長相就跟換過皮的暴雪視窗同一套（設定視窗皮）。
--
-- ## 介面（version 1）
--
--   MiliUISkin_API.RegisterSkin(addonName, cb) → true／false
--     cb(handle) 在**引擎 Boot 之後**被呼叫一次。Boot 之前的登記先暫存，
--     Boot 當下統一交付；Boot 之後的登記立刻交付。
--     總開關關掉 ⇒ 永遠不交付（回 false；Boot 前無從得知，先回 true）。
--
--   handle.version = 1
--   handle.Shell(frame, opts)        視窗外框 ＋ 標題帶 ＋ 關閉鈕（`ButtonFrameTemplate` 系）
--   handle.Inset(frame)              內嵌框（`InsetFrameTemplate`）
--   handle.Button(btn, opts)         文字按鈕，opts.variant = "primary"｜"secondary"（預設 secondary）
--   handle.IconButton(btn)           `UIPanelButtonTemplate` 殼 ＋ 自己的圖示（圖示不碰）
--   handle.ItemButton(btn, opts)     物品格（直角品質方框，見下）
--   handle.SideTab(btn, opts)        側邊圖示分頁（圖示鋪滿整顆的那種）
--   handle.Tab(tab, opts)            `PanelTabButtonTemplate` 系，opts.joined = "TOP"｜"BOTTOM"
--   handle.EditBox(eb)               輸入框／搜尋框（自動認美術的種類）
--   handle.Dropdown(dd, opts)        `WowStyle1DropdownTemplate` 系
--   handle.CheckBox(cb, opts)        勾選框
--   handle.ScrollBar(bar)            `MinimalScrollBar` 與 `WowTrimScrollBar` 兩種都收
--   handle.Slider(holder)            `MinimalSliderWithSteppersTemplate`
--   handle.Dialog(frame, opts)       浮在世界上方的小對話框（提示皮）
--   handle.SectionHeader(btn, opts)  可收合的區段標題（白字 ＋ 次要色箭頭）
--   handle.Label(btn, opts)          分類標籤（白字）
--   handle.Divider(tex)              分隔線（中和原本的美術、改畫 1px 髮絲線）
--
-- 每一支都是 `(物件, opts)`，物件是 nil 就直接返回；錯誤走 `ns.ReportError`，
-- 不會拋回呼叫端。
--
-- ## 契約（STYLE.md ③ 那一套**照舊適用**）
--
-- 交進來的框當成「不能寫欄位的框」看待，跟暴雪物件同一條線：
--   * 零欄位寫入，狀態一律在 Engine 的弱鍵表；
--   * 中和一律 `SetAlpha(0)`；不 `SetPoint`／`SetSize`／`Hide` 別人的框；
--   * 能做的動作只有 ③ 的白名單，原語直接重用 ——
--     `check_skin.py` 的掃描範圍**含這支檔案**。
--
-- ## 開關
--
-- 套用**不看**設定頁的各視窗開關（選不選這款皮是對方的皮膚選單決定的），
-- 只看總開關（`db.enabled`）：總開關關掉 ⇒ 不交付 handle ⇒ 對方的框維持原樣。
--
-- ## 戰鬥
--
-- 交進來的框可能在戰鬥中才建（背包在戰鬥中第一次打開、格子池擴張）。
-- 規則跟配方同一條（③「保護框：顯式跳過、隱式照做」）：
--   * 物件本身**沒有保護** ⇒ 戰鬥中照畫（只建貼圖／自己的子框、改 alpha 與顏色，
--     都不是保護操作）；
--   * **有保護**（顯式或隱式）＋ 戰鬥中 ⇒ 整筆延到 `PLAYER_REGEN_ENABLED` 再畫。
--     不延的話 `Engine.Overlay` 會回 nil、而且**沒有人會再叫它一次** ——
--     配方有 `Engine.ApplyAll` 補跑，對外 handle 沒有，所以補跑的佇列在這裡。
--
-- ## 物品格
--
-- 背包一開就是兩三百格 ⇒ 底與品質方框都走 `Engine.RegionBackdrop`
-- （貼圖直接建在格子上，一格 0 個子框），不是每格兩個 overlay 子框。
--   底     BACKGROUND −8，`fillInset`
--   方框   OVERLAY 7（壓在圖示與暴雪的品質框之上），`T.itemBorderSize`，
--          顏色＝**轉交** `IconBorder` 當下的顏色（`Engine.PassBorderColor`，
--          當傳遞者不當讀取者）；沒有品質就是 1px 黑邊。
-- 刷新走 `Engine.TrackItemButtonBorder`：`SetItemButtonBorder`／
-- `SetItemButtonBorderVertexColor` 這兩支全域的後置勾 —— 格子呼叫**自己的方法**
-- `btn:SetItemButtonQuality(…)` 時全域的 `SetItemButtonQuality` 不會跑，
-- 但這兩支一定會（理由與出處寫在 Engine 那一段）。
-- 只准 alpha 中和 ＋ 貼圖；**錨點與尺寸一根手指都不碰**（物品格在戰鬥中也要能用）。
--
-- ## 接觸面清單
--
-- | 動作 | 對象 | 白名單出處 |
-- |---|---|---|
-- | `SetAlpha(0)` | 美術貼圖（呼叫端點名的 parentKey、原語認得的模板區域） | ③ |
-- | `CreateTexture`（經 `Engine.RegionBackdrop`） | 面板、內嵌框、物品格、分隔線的底 | ③ |
-- | `CreateFrame` 子框（經 `Engine.Overlay`） | 按鈕、分頁、輸入框、捲軸、滑桿、側邊分頁的外框 | ③ |
-- | `SetNormalFontObject`（經 `Engine.ButtonFonts`） | 按鈕／分類標籤／區段標題 | ③（`Engine.DimFont`） |
-- | `SetVertexColor`／`SetDesaturated` | 側邊分頁的選中光暈、區段標題的箭頭、滑桿的拇指 | ③ |
-- | `HookScript("OnEnter"/"OnLeave"/"OnEnable"/"OnDisable")` | 原語內建的三態，只碰自己的 overlay | ③ |
-- | 全域後置勾 | `SetItemButtonBorder`、`SetItemButtonBorderVertexColor`（Engine） | ③ 陷阱 4 |
-- | 讀取 | `GetParent`（分隔線找宿主框）、`GetName`（舊式輸入框的具名切片）、`IsProtected` | ③ 讀取例外表 |
--
-- 刻意不做：彈出選單本身（C 級）、物品格上別的插件掛的角落小元件、
-- 物品格的錨點／尺寸、任何需要讀文字或尺寸才決定得了的東西。
------------------------------------------------------------
local _, ns = ...

local E = ns.Engine
local T = ns.Tokens
local Skin = ns.Skin

local API_VERSION = 1
local TRANSPARENT = { 0, 0, 0, 0 }

ns.External = {}
local External = ns.External

------------------------------------------------------------
-- 小工具
------------------------------------------------------------

-- 讀一個欄位（別人的框、可能是 forbidden）。讀不到就 nil。
local function Field(obj, k)
    local v
    if type(obj) == "table" and pcall(function() v = obj[k] end) then return v end
    return nil
end

-- 「有才中和」：對方的框不一定每一顆都有同一組美術，找不到不記進 `Engine.Missing`
-- （那張清單是給「暴雪改版改了什麼」用的，不是「這顆框沒有這張圖」）。
local function NeutralizeIfPresent(owner, keys, key)
    if type(keys) ~= "table" then return end
    for _, k in ipairs(keys) do
        local region = Field(owner, k)
        if region then E.Neutralize(region, key .. "." .. k) end
    end
end

local function AccentColor()
    local r, g, b = T.Accent()
    return { r, g, b, 1 }
end

-- 同一個字型物件、只換成白字（`Engine.DimFont` 的同一條路：整份繼承再只改顏色，
-- 度量一個位元都不動）。`baseName` 是全域字型物件的名字，拿不到就退回 `GameFontHighlight`。
local function WhiteFont(baseName)
    local base = type(baseName) == "string" and _G[baseName] or nil
    if not base then return GameFontHighlight end
    return E.DimFont(base, "MiliUISkinFontExt_" .. baseName, T.text)
end

------------------------------------------------------------
-- 戰鬥延後佇列
------------------------------------------------------------
local deferred = {}
local deferFrame

local function Flush()
    local list = deferred
    deferred = {}
    for _, job in ipairs(list) do
        xpcall(job.fn, ns.ReportError, job.key, job.obj, job.opts)
    end
end

local function Defer(fn, key, obj, opts)
    deferred[#deferred + 1] = { fn = fn, key = key, obj = obj, opts = opts }
    if not deferFrame then
        deferFrame = CreateFrame("Frame")
        deferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        deferFrame:SetScript("OnEvent", Flush)   -- skin-lint: own-frame
    end
end

-- 每一支原語的共同入口：型別、forbidden、戰鬥 × 保護。
local function Run(fn, key, obj, opts)
    if obj == nil then return end
    if not E.Usable(obj, key) then return end
    opts = type(opts) == "table" and opts or {}
    if InCombatLockdown() and E.ProtectionOf(obj) ~= "none" then
        Defer(fn, key, obj, opts)
        return
    end
    xpcall(fn, ns.ReportError, key, obj, opts)
end

------------------------------------------------------------
-- 原語。簽章一律 (key, obj, opts)。
------------------------------------------------------------
local P = {}

-- 視窗外框：`ButtonFrameTemplate` 那一整組 ＋ 面板底 ＋ 關閉鈕。
function P.Shell(key, frame, opts)
    Skin.PortraitChrome(frame, key, { titleBar = opts.titleBar })
    Skin.Panel(frame, key)
    local close = Field(frame, "CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end
end

function P.Inset(key, frame)
    Skin.Inset(frame, key)
end

-- 預設 secondary：對方的按鈕大多是一排平行的工具鈕（STYLE.md ④ 判準第 3 條）。
-- 真正的主動作由呼叫端明說 `variant = "primary"`。
function P.Button(key, btn, opts)
    Skin.Button(btn, key, { variant = opts.variant or "secondary" })
end

-- `UIPanelButtonTemplate` 的殼 ＋ 一張自己的圖示：殼照按鈕畫，圖示是內容、不碰。
-- 沒有文字 ⇒ 字型物件不換（`keepFont`）。
function P.IconButton(key, btn)
    Skin.Button(btn, key, { variant = "secondary", keepFont = true })
end

-- 物品格。opts.art ＝ 呼叫端自己加在格子上的美術（parentKey 清單），一起中和。
function P.ItemButton(key, btn, opts)
    -- ⚠ 這裡**不跳過顯式保護**：③ 的「顯式跳過」是為了 overlay 子框而定的，物品格這支
    -- 只做貼圖層的事（alpha 中和、CreateTexture 建在格子上、後置勾全域），沒有子框。
    -- 背包格的模板是顯式保護的，照規矩跳過的話整顆都不換皮 —— 空格那張翅膀底圖
    -- （呼叫端交進來的 `opts.art`）也就留著。戰鬥中的保護框照樣由 `Run` 延到脫戰。
    --
    -- opts.artOnly：格子的長相交給別人（Masque）時，只中和呼叫端點名的底圖，其餘一概不碰。
    if opts.artOnly then
        NeutralizeIfPresent(btn, opts.art, key)
        return
    end

    local border = Field(btn, "IconBorder")
    if border then E.Neutralize(border, key .. ".IconBorder") end
    if type(btn.GetNormalTexture) == "function" then
        local ok, tex = pcall(btn.GetNormalTexture, btn)
        if ok and tex then E.Neutralize(tex, key .. ".GetNormalTexture") end
    end
    NeutralizeIfPresent(btn, opts.art, key)
    E.ButtonStates(btn, key)

    local icon = Field(btn, "icon") or Field(btn, "Icon")
    if icon then E.CropIcon(icon, key .. ".icon") end

    local bg = E.RegionBackdrop(btn, { key = key, noBorder = true })
    E.Paint(bg, T.fillInset)

    -- 方框用 "front" 這一格：`Skin.ItemButtonRefresh` 認的就是這一格。
    -- levelOffset 只有在退回子框那條路時才有意義（排版框），那時要畫在圖示之上。
    local front = E.RegionBackdrop(btn, {
        key = key .. ".quality",
        slot = "front",
        levelOffset = 1,
        borderSize = T.itemBorderSize,
        edgeLayer = "OVERLAY",
        edgeSublevel = 7,
    })
    E.Paint(front, TRANSPARENT, T.border)
    E.PassBorderColor(front, border)

    E.TrackItemButtonBorder(btn, key)
end

-- 側邊圖示分頁：圖示鋪滿整顆 ⇒ 底畫在下面會被圖示整個蓋掉，所以只畫一圈**前景**的邊。
--   opts.art       要中和的底圖（parentKey 清單）
--   opts.selected  選中光暈的 parentKey。它的顯示與否是對方決定的，我們只換長相：
--                  去飽和 ＋ 染職業色（兩個都是 region 的白名單動作）。
function P.SideTab(key, btn, opts)
    NeutralizeIfPresent(btn, opts.art, key)
    local glow = opts.selected and Field(btn, opts.selected)
    if glow then
        E.Desaturate(glow, key .. "." .. opts.selected)
        E.VertexColor(glow, AccentColor(), key .. "." .. opts.selected)
    end
    E.ButtonStates(btn, key, nil, true)

    local ov = E.Overlay(btn, { key = key .. ".border", levelOffset = 1 })
    E.Paint(ov, TRANSPARENT, T.border)
    -- 滑過只換邊（職業色），底維持透明 —— 前景那一層有底就會蓋住圖示。
    E.TrackButtonHover(btn, ov, TRANSPARENT, nil, TRANSPARENT)
end

-- 單顆分頁。對方是一顆一顆交進來的，湊不成一整排 ⇒ 不走 `Skin.TabGroup` 的接縫，
-- 每顆畫自己的按鈕矩形（分頁之間留下對方原本的間距）。
--   opts.joined  跟內容相連、不畫的那一邊（預設 "TOP" ＝分頁在內容下方）
function P.Tab(key, tab, opts)
    local joined = opts.joined or "TOP"
    Skin.Tab(tab, key, "panel", {
        points = {
            { "TOPLEFT", "TOPLEFT", 0, 0 },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
        },
        skipEdges = { joined },
        accentSide = (joined == "BOTTOM") and "TOP" or "BOTTOM",
    })
end

-- 輸入框：依美術的種類分三路（都用「有沒有這個 parentKey」判斷，讀的是結構）。
--   `Left`   ＝ `InputBoxTemplate`／`SearchBoxTemplate` ⇒ `Skin.EditBox`
--   `left`   ＝ 金額輸入框（`MoneyFrameEditBoxTemplate`，Blizzard_MoneyFrame/Mainline/
--              MoneyInputFrame.xml:17-40）：兩張小寫 parentKey ＋ 一張只有全域名字的
--              `$parentMiddle`；矩形照抄那三張的錨點（左 −5、其餘貼齊）
--   都沒有 ＝ 沒有美術的純輸入框（捲動文字框裡那一顆）⇒ 不畫，框由它的容器負責
function P.EditBox(key, eb)
    if Field(eb, "Left") then
        Skin.EditBox(eb, key)
        return
    end
    if Field(eb, "left") then
        NeutralizeIfPresent(eb, { "left", "right" }, key)
        local ok, name = pcall(eb.GetName, eb)
        if ok and type(name) == "string" then
            E.NeutralizeGlobals({ name .. "Middle" })
        end
        local ov = E.Overlay(eb, {
            key = key,
            points = {
                { "TOPLEFT", "TOPLEFT", -5, 0 },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
            },
        })
        E.Paint(ov, T.fillInset, T.border)
    end
end

function P.Dropdown(key, dd, opts)
    Skin.Dropdown(dd, key, opts.kind or "style1")
end

--   opts.art  額外要中和的區域（設定頁那種勾選框有一張整列的滑過底 `HoverBackground`）
function P.CheckBox(key, cb, opts)
    NeutralizeIfPresent(cb, opts.art, key)
    Skin.CheckBox(cb, key)
end

------------------------------------------------------------
-- `WowTrimScrollBar`（Blizzard_SharedXML/Shared/Scroll/TrimScrollBar.xml）
--
-- TODO(升格)：跟 `Skin.ScrollBar`（`MinimalScrollBar`）只差「美術在哪幾個 parentKey」，
-- 升格時把 `Skin.ScrollBar` 參數化（軌道美術的 owner／keys、步進鈕的額外區域）。
-- 先放這裡是因為暴雪視窗的配方目前沒有人用到這個模板。
--
-- 區域（同檔）：
--   bar.Backplate                        BACKGROUND 的半透明黑底
--   bar.Background.Begin/Middle/End      軌道的端帽與中段（`useParentLevel` 的子框）
--   bar.Track                            沒有美術，只有拇指
--   bar.Track.Thumb.Begin/Middle/End     拇指三段
--   bar.Back / bar.Forward               `Texture`（箭頭）＋ `Overlay`（滑過光）
--
-- ⚠ 拇指三段**只能 alpha**：`WowScrollBarThumbScriptsMixin:OnSizeChanged`（TrimScrollBar.lua）
--   讀 `C_Texture.GetAtlasInfo(self.Middle:GetAtlas())`，換成純色就每次捲動炸一發
--   （同註 ⓑ）。`OnButtonStateChanged` 只 `SetAtlas`，alpha 撐得住。
-- ⚠ 步進鈕的 `Overlay` 被 `WowTrimScrollBarStepperMixin:OnButtonStateChanged`
--   `SetShown(self:IsOver())` —— 只切顯示、不碰 alpha ⇒ 中和撐得住。
------------------------------------------------------------
local function TrimScrollBar(key, bar)
    NeutralizeIfPresent(bar, { "Backplate" }, key)
    local back = Field(bar, "Background")
    if back then NeutralizeIfPresent(back, { "Begin", "Middle", "End" }, key .. ".Background") end

    local thin = T.scrollThumbSize
    local thinPoints = {
        { "TOP", "TOP", 0, 0 },
        { "BOTTOM", "BOTTOM", 0, 0 },
    }

    local track = Field(bar, "Track")
    if track then
        local trackOv = E.Overlay(track, {
            key = key .. ".Track", noBorder = true,
            points = thinPoints, width = thin,
        })
        E.Paint(trackOv, T.scrollTrack)

        local thumb = Field(track, "Thumb")
        if thumb then
            NeutralizeIfPresent(thumb, { "Begin", "Middle", "End" }, key .. ".Thumb")
            local thumbOv = E.Overlay(thumb, {
                key = key .. ".Thumb", noBorder = true,
                points = thinPoints, width = thin,
            })
            E.Paint(thumbOv, T.scrollThumb)
            E.TrackButtonHover(thumb, thumbOv, T.scrollThumb, nil, T.scrollThumbHover)
        end
    end

    for _, side in ipairs({ "Back", "Forward" }) do
        local stepper = Field(bar, side)
        if stepper then
            NeutralizeIfPresent(stepper, { "Texture", "Overlay" }, key .. "." .. side)
            if T.scrollStepper ~= "hide" then
                local stepOv = E.Overlay(stepper, {
                    key = key .. "." .. side,
                    noBorder = true,
                    glyph = {
                        kind = (side == "Back") and "chevronUp" or "chevronDown",
                        size = T.glyphSize, thickness = 1, color = T.textDim,
                    },
                })
                E.Paint(stepOv, TRANSPARENT)
                E.TrackGlyph(stepper, stepOv, { trackHover = true, trackEnabled = true })
            end
        end
    end
end

function P.ScrollBar(key, bar)
    if Field(bar, "Background") and Field(bar, "Backplate") then
        TrimScrollBar(key, bar)
    else
        Skin.ScrollBar(bar, key)
    end
end

------------------------------------------------------------
-- `MinimalSliderWithSteppersTemplate`（Blizzard_SharedXML/Shared/Slider/MinimalSlider.xml）
--
-- TODO(升格)：暴雪視窗的配方目前沒有滑桿，先住這裡。
--
--   holder.Slider                 `MinimalSliderTemplate`：Left/Right/Middle 三段軌道 ＋ `Thumb`
--   holder.Back / holder.Forward  各一張**無名**的箭頭貼圖
--
-- ⚠ 拇指**不能中和**：`MinimalSliderWithSteppersMixin` 的 `ConfigureSlider`
--   （MinimalSlider.lua:174）在每次啟用／停用時 `Thumb:SetAlpha(...)`，中和撐不過一次。
--   改成去飽和 ＋ 染白（形狀留著、金色拿掉）—— vertex color 它不碰。
-- ⚠ 步進鈕的停用是對**整顆按鈕** `SetAlpha` ＋ `DesaturateHierarchy`（:106-109），
--   我們的圖記 overlay 是它的子框 ⇒ 自動跟著變暗，不必另外追。
-- 軌道：三段中和，畫一條置中的細槽（高 `scrollThumbSize`，`fillInset` ＋ 1px 黑邊）。
------------------------------------------------------------
function P.Slider(key, holder)
    local slider = Field(holder, "Slider")
    if slider then
        NeutralizeIfPresent(slider, { "Left", "Right", "Middle" }, key .. ".Slider")
        local thumb = Field(slider, "Thumb")
        if thumb then
            E.Desaturate(thumb, key .. ".Thumb")
            E.VertexColor(thumb, T.text, key .. ".Thumb")
        end
        local ov = E.Overlay(slider, {
            key = key .. ".Slider",
            height = T.scrollThumbSize,
            points = {
                { "LEFT", "LEFT", 0, 0 },
                { "RIGHT", "RIGHT", 0, 0 },
            },
        })
        E.Paint(ov, T.fillInset, T.border)
    end

    for _, side in ipairs({ "Back", "Forward" }) do
        local stepper = Field(holder, side)
        if stepper then
            E.NeutralizeRegions(stepper, key .. "." .. side)
            local stepOv = E.Overlay(stepper, {
                key = key .. "." .. side,
                noBorder = true,
                glyph = {
                    kind = (side == "Back") and "chevronLeft" or "chevronRight",
                    size = T.glyphSize, thickness = 1, color = T.textDim,
                },
            })
            E.Paint(stepOv, TRANSPARENT)
            E.TrackGlyph(stepper, stepOv, { trackHover = true })
        end
    end
end

-- 浮在世界上方的小對話框（DIALOG strata、自己帶一層九宮格）。
-- 照 STYLE.md ① 的兩個問題：彈出來讀一眼 ⇒ **提示皮**（`tipFill` ＋ 1px 職業色邊），
-- 跟確認彈窗同一套；裡面的按鈕、輸入框照舊設定視窗皮。
--   opts.art  九宮格之類有 parentKey 的美術。沒有名字的底圖（對方 `CreateTexture` 出來的
--             那張半透明黑底）走 `NeutralizeRegions` —— 它先跑、我們的底後建，
--             而且 `Engine.ownRegions` 會讓之後的重掃跳過我們自己的貼圖。
function P.Dialog(key, frame, opts)
    NeutralizeIfPresent(frame, opts.art, key)
    E.NeutralizeRegions(frame, key)
    local ov = E.RegionBackdrop(frame, { key = key })
    E.Paint(ov, T.tipFill, AccentColor())
end

-- 可收合的區段標題：字換成同字型的白字、箭頭壓成灰階再染次要色。
--   opts.baseFont  對方用的字型物件名（全域）。白字版本從它衍生，度量不變。
--   opts.arrow     箭頭貼圖的 parentKey
function P.SectionHeader(key, btn, opts)
    E.ButtonFonts(btn, WhiteFont(opts.baseFont), key)
    local arrow = opts.arrow and Field(btn, opts.arrow)
    if arrow then
        E.Desaturate(arrow, key .. "." .. opts.arrow)
        E.VertexColor(arrow, T.textDim, key .. "." .. opts.arrow)
    end
end

-- 分類標籤：只換成白字。標籤裡對方自己包的色碼（`|cff……|r`）優先於字型顏色，照樣生效 ——
-- 那是玩家自己設的分類顏色，是資訊。
function P.Label(key, btn, opts)
    E.ButtonFonts(btn, WhiteFont(opts.baseFont), key)
end

-- 分隔線：原本的美術中和，改在**它的宿主框**上畫一條 1px 髮絲線，
-- 左右端與垂直中心錨在原本那張貼圖上（錨到別人的區域是允許的，動的是我們的貼圖）。
-- 顏色用 `fillHover`：深底上的分隔線要比底亮才看得見（同 `Skin.SectionTitle`）。
function P.Divider(key, tex)
    local ok, owner = pcall(tex.GetParent, tex)
    if not ok or not owner then return end
    E.Neutralize(tex, key)
    local line = E.RegionBackdrop(owner, {
        key = key .. ".rule",
        slot = "divider",
        noBorder = true,
        sublevel = -5,
        height = 1,
        points = {
            { "LEFT", "LEFT", 0, 0, rel = tex },
            { "RIGHT", "RIGHT", 0, 0, rel = tex },
        },
    })
    E.Paint(line, T.fillHover)
end

------------------------------------------------------------
-- handle 與交付
------------------------------------------------------------
local handles = {}      -- [addonName] = handle
local waiting = {}      -- Boot 前的登記：{ name, cb }
local booted = false

local function MakeHandle(addonName)
    local prefix = string.lower(addonName)
    local h = { version = API_VERSION }
    for name, fn in pairs(P) do
        -- debug 的 key 前綴是呼叫端的名字（`baganator.ItemButton`…），
        -- `/mskin debug` 裡一眼分得出是誰交進來的框。
        local key = prefix .. "." .. name
        h[name] = function(obj, opts)
            Run(fn, key, obj, opts)
        end
    end
    return h
end

local function Deliver(addonName, cb)
    local h = handles[addonName]
    if not h then
        h = MakeHandle(addonName)
        handles[addonName] = h
    end
    xpcall(cb, ns.ReportError, h)
end

-- `Init.lua` 在 `Engine.Boot()` 之後呼叫。
function External.OnBoot()
    booted = true
    local list = waiting
    waiting = {}
    if not (ns.db and ns.db.enabled) then return end
    for _, w in ipairs(list) do
        Deliver(w.name, w.cb)
    end
end

-- 全域：登記在 .claude/scripts/check_lua.py 的 ALLOWED_GLOBAL_WRITES。
MiliUISkin_API = {
    version = API_VERSION,
    RegisterSkin = function(addonName, cb)
        if type(addonName) ~= "string" or type(cb) ~= "function" then return false end
        if not booted then
            waiting[#waiting + 1] = { name = addonName, cb = cb }
            return true
        end
        if not (ns.db and ns.db.enabled) then return false end
        Deliver(addonName, cb)
        return true
    end,
}
