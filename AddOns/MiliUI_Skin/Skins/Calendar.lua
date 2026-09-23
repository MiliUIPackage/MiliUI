------------------------------------------------------------
-- 配方：行事曆（`CalendarFrame`，隨需載入 `Blizzard_Calendar`）＋ 它底下的七個彈出面板
--
-- 第十二／十三輪。範圍與掛點照「成熟同類實作」的行事曆段落搬：主視窗外框整組淡掉、
-- 月曆格一格一個平面底框、翻月鈕、篩選下拉、關閉鈕、所有面板的外框／標題／按鈕／下拉／
-- 輸入框／勾選框／捲軸、事件格上的裝飾淡掉；外觀換成這一包的皮。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_Calendar/Blizzard_Calendar_Mainline.toc:3  `## LoadOnDemand: 1`
--   Blizzard_Calendar/Mainline/Blizzard_Calendar.xml:5  `CalendarFrame`（659x624，HIGH，toplevel）；
--     自己的 region：`$parent{TopLeft,TopMiddle,TopRight,LeftTop,LeftMiddle,LeftBottom,RightTop,
--     RightMiddle,RightBottom,BottomLeft,BottomMiddle,BottomRight}Texture`（外框 12 片）／
--     `CalendarWeekday1..7Background`（BACKGROUND）／`CalendarWeekday1..7Name`（色 1,1,0.6）／
--     `CalendarMonthBackground`／`CalendarMonthName`／`CalendarYearBackground`／`CalendarYearName`／
--     `CalendarLastDayDarkTexture`／`CalendarWeekdaySelectedTexture`
--   同檔 :228 `CalendarTodayFrame`（今天的框與呼吸光，OnUpdate 改 Glow 的 alpha）
--   同檔 :259,272 `CalendarPrevMonthButton`／`CalendarNextMonthButton`（Normal/Pushed/Disabled/Highlight 四張檔案貼圖）
--   同檔 :285 `FilterButton`（WowStyle1FilterDropdownTemplate）／:290 `CalendarCloseButton`（UIPanelCloseButton）
--   同檔 :323 `CalendarFrameModalOverlay`（黑 0.6，modal 時蓋住月曆格）
--   同檔 :354 `CalendarViewHolidayFrame`／:404 `CalendarViewRaidFrame`／:433 `CalendarViewEventFrame`／
--     :640 `CalendarCreateEventFrame`／:1001 `CalendarMassInviteFrame`／:1107 `CalendarEventPickerFrame`／
--     :1169 `CalendarTexturePickerFrame` —— 全部 `parent="CalendarFrame"`，各有
--     `Border`（DialogBorderDarkTemplate：NineSlice ＋ `Bg`，useParentLevel）與
--     `Header`（DialogHeaderTemplate：`LeftBG`／`CenterBG`／`RightBG` ＋ `Text`，
--     Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml:11,83）
--   Blizzard_Calendar/Mainline/Blizzard_CalendarTemplates.xml:4 `CalendarDayButtonTemplate`（91x91）：
--     `$parentEventTexture`／`$parentEventBackgroundTexture`／`$parentPendingInviteTexture`／
--     `$parentOverlayFrame`（節日的橫跨圖）／`$parentDateFrame`（`Background` ＋ `Date`）／
--     `$parentMoreEventsButton`／`$parentDarkFrame`（`Top`／`Bottom`，CalendarShadows）／
--     NormalTexture（CalendarBackground）／HighlightTexture（Highlights，ADD）
--   同檔 :210 `CalendarCloseButtonTemplate`（← UIPanelCloseButton）／:222 `CalendarEventButtonTemplate`
--     （← UIPanelButtonTemplate）／:256 `CalendarEventInviteListTemplate`（← TooltipBackdropTemplate，
--     `ScrollBox`／`ScrollBar`）／:368 `CalendarViewEventRSVPButtonTemplate`（`flashTexture`）
--   Blizzard_Calendar/Mainline/Blizzard_Calendar.lua:1079 `CalendarDayButton1..42` 在 `CalendarFrame_OnLoad`
--     建好（XML 載入期，比 ADDON_LOADED 早）⇒ **掃一次就完整，不需要 hook**。
--   同檔 :1210-1219 `CalendarFrame_InitDay`：NormalTexture `SetDrawLayer`＋`SetTexCoord`（只一次）、
--     Highlight `SetAlpha(0.5)`
--   同檔 :1690-1698 `CalendarFrame_SetSelectedDay`：**選中那一天＝`LockHighlight` ＋ Highlight
--     `SetAlpha(1.0)`**（滑過是 0.5）⇒ Highlight 是「選中／滑過」的共同載體，**不能中和**。
--   同檔 :1424-1463 `CalendarFrame_UpdateDay`：DarkFrame 兩張只 `SetTexCoord` ＋ 框的 Show/Hide
--   全檔對我們中和的那幾張（外框 12 片、星期底、月／年底、事件底、陰影、日期底、各面板的
--     Border／Header 美術、按鈕框）**零處 `SetAlpha`／`SetShown`** ⇒ alpha 中和撐得住。
--
------------------------------------------------------------
-- ## 照抄的做法 ／ 照抄不了的地方
--
-- 照抄：
--   * 主視窗：自己的每一張貼圖淡掉（外框、星期底、月份／年份的底板、`LastDayDark`、
--     `WeekdaySelected`），**不畫標題帶**（它刻意拿掉，跟月份那一列打架）。
--   * 月曆格：NormalTexture 淡掉、一格一個平面底框 ＋ 1px 黑邊。
--   * 格子上被它的關鍵字掃描淡掉的那幾張，逐一點名淡掉：事件底（`EventBackgroundTexture`）、
--     陰影（`DarkFrameTop/Bottom`）、日期底（`DateFrameBackground`）。
--   * 翻月鈕 ‹ ›、篩選下拉、關閉鈕、所有面板的捲軸與 `UIPanelButtonTemplate` 系按鈕。
--   * 節日／建立活動／活動選擇三個面板：面板底 ＋ 標題帶、`Border` 與 `Header` 美術淡掉、
--     節日面板自己的 `ModalOverlay` 淡掉、分隔線與按鈕框淡掉、各面板的關閉鈕、下拉、輸入框、勾選框。
--   * 其餘四個面板（檢視活動、團隊重置、大量邀請、圖示選擇）：它只經由遞迴掃描碰到
--     （按鈕、捲軸、關鍵字美術），我們**同樣的外框做法一併套上**（不這樣做的話，那幾個面板的
--     `Border.Bg` 被淡掉之後會變成沒有底的透明面板）。
-- 照抄不了：
--   * 關鍵字掃描（`GetTexture()`／`GetAtlas()` 讀材質名稱比對 background/shadow/divider…）：
--     讀材質名不在讀取例外表上 ⇒ 改成**逐一點名**同一批貼圖（上面那幾條）。
--   * 篩選下拉與關閉鈕上移 10、面板標題下移 5～8、關閉鈕的 × 上移 6、職業欄右移 3：全是重排。
--   * 它在 `CalendarFrame_Update` 的後置勾與三個面板的 `HookScript("OnShow")` 裡重掃：
--     我們的中和全是 alpha、暴雪不會打回來 ⇒ **一個都不掛**。
--   * 月曆格的 `SetNormalTexture("")`：禁止（結構性修改），改成 alpha 0。
--
-- ## 刻意不碰（內容與狀態）
--   * **節日圖**：`$parentEventTexture`、`$parentOverlayFrameTexture`（橫跨多天的節日橫幅）、
--     `CalendarViewHolidayFrame.Texture`（面板裡的大圖）。
--   * 今天的框與呼吸光（`CalendarTodayFrame`）、待回覆邀請的信封（`PendingInviteTexture`）、
--     「更多活動」的小箭頭、事件列的字色（活動類型色）、`CalendarFrameModalOverlay`（modal 遮罩）。
--   * 各面板的 `ModalOverlay`（CalendarModalEventOverlayTemplate）、`RetrievingFrame`（讀取中遮罩）。
--   * 邀請名單的**列**（CalendarEventInviteListButtonTemplate：名字＝職業色、狀態色都是資訊；
--     右鍵是「移除邀請／設為管理員」這類請求）、邀請名單的三顆排序鈕、職業統計欄
--     （`CalendarClassButtonContainer`）、活動選擇／圖示選擇的列。
--   * RSVP 按鈕的 `flashTexture`（待回覆時的閃光提示＝狀態）。
--
-- ## 按鈕分派（STYLE.md ④；會送出受限請求的一律零腳本）
--   * 零腳本：接受（primary）／暫定／拒絕／移除（secondary）—— `C_Calendar.EventAvailable`／
--     `EventTentative`／`EventDecline`／`ContextMenuEventRemove`；建立活動（primary，`AddEvent`／
--     `UpdateEvent`）；邀請（`EventInvite`）、邀請公會成員（`CalendarCreateEventRaidInviteButton`，
--     送出隊伍邀請）、大量邀請（secondary）；大量邀請面板的「接受」（primary，`MassInviteGuild/Community`）。
--   * 一般按鈕（`Skin.Button`）：活動選擇面板的「關閉」（secondary）、圖示選擇面板的「接受」
--     （primary，只是選一張圖）／「取消」（secondary）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `CalendarFrame` 自己的每一張貼圖（`GetRegions`） | `SetAlpha(0)` |
-- | `CalendarFrame` 本身、七個面板本身 | `Engine.RegionBackdrop`（`fill` ＋ 黑邊；面板另有標題帶） |
-- | `CalendarWeekdayNName`／`CalendarYearName` | `SetTextColor`（星期＝欄位標籤 `textDim`、年份白） |
-- | `CalendarDayButton1..42` 的 NormalTexture、`EventBackgroundTexture`、`DarkFrameTop/Bottom`、`DateFrameBackground` | `SetAlpha(0)` |
-- | 同上的 HighlightTexture（選中／滑過的共同載體） | `SetDesaturated(true)`（`Engine.Desaturate`）＋ `SetVertexColor(職業色)` —— alpha 仍是暴雪在 0.5／1.0 之間切 |
-- | 同上每一格 | 底＋邊建成**格子自己的** BACKGROUND 貼圖（只畫右／下兩邊，第一欄補左邊、第一列補上邊 ⇒ 格線永遠 1px） |
-- | 翻月鈕兩顆 | 三張狀態圖 `SetAlpha(0)` ＋ ‹ › 圖記（`Skin.IconButton`） |
-- | `FilterButton` | `Skin.Dropdown`（filter） |
-- | 八顆關閉鈕 | `Skin.CloseButton` |
-- | 各面板的 `Border`（純美術容器）、`CalendarViewHolidayFrameModalOverlay` | `SetAlpha(0)` |
-- | 各面板 `Header` 的 `LeftBG`／`CenterBG`／`RightBG` | `SetAlpha(0)`；`Header.Text` `SetTextColor(白)` |
-- | 兩條分隔線、四張 `ButtonBackground`、按鈕的 `$parentBorder`、`CalendarEventPickerCloseButtonBorder` | `SetAlpha(0)` |
-- | 兩個描述框、兩個邀請名單（TooltipBackdropTemplate） | `NineSlice` `SetAlpha(0)`；`fillInset` ＋ 黑邊建在它們自己身上 |
-- | 六個下拉、四個輸入框、兩個勾選框、七條捲軸 | `Skin.Dropdown`／`Skin.EditBox`／`Skin.CheckBox`／`Skin.ScrollBar` |
-- | 零腳本按鈕 8 顆 | Left/Right/Middle `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 換長相 |
-- | `CalendarViewEventTitle` | `SetTextColor(白)`（Lua 從不重設它的顏色） |
--
-- ### 讀了什麼
-- 只有結構：全域名、parentKey、`GetRegions()`、`GetObjectType`、`GetNormalTexture()`／`GetHighlightTexture()`。
-- **不讀** `day`／`monthOffset`／`dark`／`selectedDayButton`／任何活動資料或文字。
--
-- ### 掛了哪些 hook
-- **`hooksecurefunc`：0 支。`HookScript("OnShow"/"OnHide")`：0 支。**
-- 只有原語內建的 `HookScript("OnEnter"/"OnLeave")`（翻月鈕另加 `OnEnable`/`OnDisable`）——
-- 關閉鈕、翻月鈕、下拉、勾選框、`Skin.Button` 那三顆；內容只換我們自己 overlay 的顏色。
-- **零腳本按鈕上的 `HookScript`：0 支。**
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

local function Global(name)
    local obj = _G[name]
    if not obj then E.Missing(name) end
    return obj
end

------------------------------------------------------------
-- 零腳本按鈕（同 `Skins/PlayerSpells.lua`），外加按鈕自己那張 `$parentBorder` 框
-- TODO(升格): 見 `Skins/Macro.lua` 同名那一支的 TODO。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(name, variant)
    local btn = Global(name)
    if not btn or not E.Usable(btn, name) then return nil end
    local ov = E.Overlay(btn, { key = name })       -- 先建 overlay 再中和
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, name)
    if _G[name .. "Border"] then E.Neutralize(_G[name .. "Border"], name .. "Border") end
    E.ButtonFonts(btn, GameFontHighlight, name)
    E.ScriptlessButton(btn, ov, variant or "primary", name)   -- **不掛腳本**
    return ov
end

local function PlainButton(name, variant)
    local btn = Global(name)
    if not btn then return end
    if _G[name .. "Border"] then E.Neutralize(_G[name .. "Border"], name .. "Border") end
    Skin.Button(btn, name, { variant = variant })
end

local function CloseButton(name)
    local btn = Global(name)
    if btn then Skin.CloseButton(btn, name) end
end

local function ScrollBarOf(owner, label)
    local bar = Optional(owner, "ScrollBar")
    if bar then
        Skin.ScrollBar(bar, label .. ".ScrollBar")
    else
        E.Missing(label .. ".ScrollBar")
    end
end

local function EditBox(name)
    local eb = Global(name)
    if eb then Skin.EditBox(eb, name) end
end

local function CheckBox(name)
    local cb = Global(name)
    if cb then Skin.CheckBox(cb, name) end
end

local function Dropdowns(owner, label, keys)
    for _, k in ipairs(keys) do
        local dd = Optional(owner, k)
        if dd then
            Skin.Dropdown(dd, label .. "." .. k, "style1")
        else
            E.Missing(label .. "." .. k)
        end
    end
end

-- TooltipBackdropTemplate 系的內嵌框（描述、邀請名單）：九宮格淡掉、底＋邊建在它自己身上
local function TooltipWell(name)
    local f = Global(name)
    if not f or not E.Usable(f, name) then return nil end
    E.NeutralizeKeys(f, { "NineSlice" }, name)
    local ov = E.RegionBackdrop(f, { key = name })
    E.Paint(ov, T.fillInset, T.border)
    return f
end

------------------------------------------------------------
-- 一個彈出面板的外框（七個共用）
--
-- 全部是行事曆的**延伸面板**（貼在月曆右邊，或蓋在月曆上的 modal）⇒ 設定視窗皮，跟主視窗同一套
-- （成熟同類實作這三個也是用主視窗同一個外殼，不是提示皮）。
-- ⚠ 七個本體都是普通 Frame（不是 layout host）⇒ `RegionBackdrop` 直接建在面板自己身上，
--   DIALOG strata 的那三個（CalendarModalDialogTemplate）也不必特判。
-- ⚠ `Header` 是 DialogHeaderTemplate：錨 `TOP y=11`、字在上緣往下 2～14 之間
--   ⇒ 美術淡掉之後字剛好落在我們 22 高的標題帶裡。`Header:Setup` 只 `SetText`／`SetWidth`
--   （DialogTemplates.lua:10-22）⇒ 字色一次就永久有效。
------------------------------------------------------------
local HEADER_ART = { "LeftBG", "CenterBG", "RightBG" }

local function SkinDialog(name, closeName)
    local d = Global(name)
    if not d or not E.Usable(d, name) then return nil end

    E.NeutralizeKeys(d, { "Border" }, name)
    Skin.Panel(d, name)
    Skin.TitleBar(d, name)

    local header = Optional(d, "Header")
    if header then
        E.NeutralizeKeys(header, HEADER_ART, name .. ".Header")
        local text = Optional(header, "Text")
        if text then E.TextColor(text, T.text, name .. ".Header.Text") end
    else
        E.Missing(name .. ".Header")
    end

    -- 底部按鈕列那一條 `UI-Button-Borders`（只有全域名，沒有的面板靜默跳過）
    local bg = _G[name .. "ButtonBackground"]
    if bg then E.Neutralize(bg, name .. "ButtonBackground") end

    if closeName then CloseButton(closeName) end
    return d
end

------------------------------------------------------------
-- 主視窗
------------------------------------------------------------
local WEEKDAYS = 7
local DAY_BUTTONS = 42     -- `CALENDAR_MAX_DAYS_PER_MONTH`（Blizzard_Calendar.lua:1078）
local DAY_ART = { "EventBackgroundTexture", "DarkFrameTop", "DarkFrameBottom", "DateFrameBackground" }

local function SkinDay(i)
    local name = "CalendarDayButton" .. i
    local day = _G[name]
    if not day then
        E.Missing(name)
        return
    end
    if not E.Usable(day, name) then return end

    local ok, normal = pcall(day.GetNormalTexture, day)
    if ok and normal then E.Neutralize(normal, name .. ".NormalTexture") end
    for _, suffix in ipairs(DAY_ART) do
        E.Neutralize(_G[name .. suffix], name .. suffix)
    end

    -- 選中／滑過：暴雪用同一張 Highlight 表示兩者（alpha 1.0／0.5），不能中和。
    -- 那張是金色的框形光（ADD），乘法染不出職業色 ⇒ 先去飽和再染（同 `Engine.Desaturate` 的理由）。
    -- 形狀照舊是暴雪的框，顯示與 alpha 照舊是暴雪決定的 —— 我們只換色相。
    local ok2, hl = pcall(day.GetHighlightTexture, day)
    if ok2 and hl then
        E.Desaturate(hl, name .. ".HighlightTexture")
        E.VertexColor(hl, { T.Accent() }, name .. ".HighlightTexture")
    end

    -- 一格一個平面底框。相鄰兩格各畫四邊會變成 2px 的格線 ⇒ 每格只畫右／下兩邊，
    -- 第一欄補左邊、第一列補上邊（格子的排法是 1..7 一列、每列往下接，Blizzard_Calendar.lua:1203-1209）。
    local col = (i - 1) % WEEKDAYS + 1
    local skip = {}
    if col > 1 then skip[#skip + 1] = "LEFT" end
    if i > WEEKDAYS then skip[#skip + 1] = "TOP" end
    local ov = E.RegionBackdrop(day, { key = name, skipEdges = skip })
    E.Paint(ov, T.fillInset, T.border)
end

local function SkinMain(f)
    -- 自己的每一張貼圖：外框 12 片、星期底、月份／年份底板、LastDayDark、WeekdaySelected
    E.NeutralizeRegions(f, "CalendarFrame")
    Skin.Panel(f, "CalendarFrame")
    -- ⚠ 不畫標題帶：月份那一列（翻月鈕、月份、年份、篩選、關閉）本身就是標題，
    --   多一條帶子會跟它打架（成熟同類實作也是刻意拿掉）。

    for i = 1, WEEKDAYS do
        E.TextColor(_G["CalendarWeekday" .. i .. "Name"], T.textDim, "CalendarWeekday" .. i .. "Name")
    end
    -- 年份：GameFontNormalSmall 暗金 → 白（月份本來就是 GameFontHighlightLarge 白）
    E.TextColor(_G.CalendarYearName, T.text, "CalendarYearName")

    for i = 1, DAY_BUTTONS do
        SkinDay(i)
    end

    local prev, nxt = Global("CalendarPrevMonthButton"), Global("CalendarNextMonthButton")
    if prev then
        Skin.IconButton(prev, "CalendarPrevMonthButton",
            { inset = 4, glyph = "chevronLeft", glyphColor = T.textDim, trackEnabled = true })
    end
    if nxt then
        Skin.IconButton(nxt, "CalendarNextMonthButton",
            { inset = 4, glyph = "chevronRight", glyphColor = T.textDim, trackEnabled = true })
    end

    local filter = Optional(f, "FilterButton")
    if filter then
        Skin.Dropdown(filter, "CalendarFrame.FilterButton", "filter")
    else
        E.Missing("CalendarFrame.FilterButton")
    end

    CloseButton("CalendarCloseButton")
end

------------------------------------------------------------
-- 七個面板
------------------------------------------------------------
local function SkinHoliday()
    local d = SkinDialog("CalendarViewHolidayFrame", "CalendarViewHolidayCloseButton")
    if not d then return end
    -- 它自己的 modal 遮罩（黑 0.5）：成熟同類實作淡掉；主視窗與其他面板的保留
    E.Neutralize(_G.CalendarViewHolidayFrameModalOverlay, "CalendarViewHolidayFrameModalOverlay")
    -- `Texture`（節日大圖，Lua `SetAlpha(0.4)`）是內容，不碰
end

local function SkinRaid()
    SkinDialog("CalendarViewRaidFrame", "CalendarViewRaidCloseButton")
end

local function SkinViewEvent()
    local d = SkinDialog("CalendarViewEventFrame", "CalendarViewEventCloseButton")
    if not d then return end

    -- 活動名稱：GameFontNormal 暗金 → 白。社群名／類型／建立者三條 Lua 會依狀態換色
    -- （綠／灰／一般，Blizzard_Calendar.lua:2827-2850）＝資訊，不碰。
    E.TextColor(_G.CalendarViewEventTitle, T.text, "CalendarViewEventTitle")

    local desc = TooltipWell("CalendarViewEventDescriptionContainer")
    if desc then ScrollBarOf(desc, "CalendarViewEventDescriptionContainer") end

    E.Neutralize(_G.CalendarViewEventDivider, "CalendarViewEventDivider")

    -- 回覆鈕：接受 primary、暫定／拒絕 secondary；移除（從自己的行事曆刪掉）secondary
    ScriptlessButton("CalendarViewEventAcceptButton", "primary")
    ScriptlessButton("CalendarViewEventTentativeButton", "secondary")
    ScriptlessButton("CalendarViewEventDeclineButton", "secondary")
    ScriptlessButton("CalendarViewEventRemoveButton", "secondary")

    local list = TooltipWell("CalendarViewEventInviteList")
    if list then ScrollBarOf(list, "CalendarViewEventInviteList") end
end

local CREATE_DROPDOWNS = {
    "EventTypeDropdown", "HourDropdown", "MinuteDropdown", "AMPMDropdown",
    "DifficultyOptionDropdown", "CommunityDropdown",
}

local function SkinCreateEvent()
    local d = SkinDialog("CalendarCreateEventFrame", "CalendarCreateEventCloseButton")
    if not d then return end

    Dropdowns(d, "CalendarCreateEventFrame", CREATE_DROPDOWNS)
    EditBox("CalendarCreateEventTitleEdit")
    EditBox("CalendarCreateEventInviteEdit")
    CheckBox("CalendarCreateEventLockEventCheck")
    CheckBox("CalendarCreateEventAutoApproveCheck")

    E.Neutralize(_G.CalendarCreateEventDivider, "CalendarCreateEventDivider")

    local desc = TooltipWell("CalendarCreateEventDescriptionContainer")
    if desc then ScrollBarOf(desc, "CalendarCreateEventDescriptionContainer") end
    local list = TooltipWell("CalendarCreateEventInviteList")
    if list then ScrollBarOf(list, "CalendarCreateEventInviteList") end

    -- 建立／更新活動是這個面板唯一的 primary；三顆邀請相關的都會送出邀請 ⇒ 零腳本 secondary
    ScriptlessButton("CalendarCreateEventCreateButton", "primary")
    ScriptlessButton("CalendarCreateEventInviteButton", "secondary")
    ScriptlessButton("CalendarCreateEventRaidInviteButton", "secondary")
    ScriptlessButton("CalendarCreateEventMassInviteButton", "secondary")
end

local function SkinMassInvite()
    local d = SkinDialog("CalendarMassInviteFrame", "CalendarMassInviteCloseButton")
    if not d then return end
    Dropdowns(d, "CalendarMassInviteFrame", { "CommunityDropdown", "RankDropdown" })
    EditBox("CalendarMassInviteMinLevelEdit")
    EditBox("CalendarMassInviteMaxLevelEdit")
    -- 「接受」＝對整個公會／社群送出邀請 ⇒ 零腳本 primary
    ScriptlessButton("CalendarMassInviteAcceptButton", "primary")
end

local function SkinEventPicker()
    local d = SkinDialog("CalendarEventPickerFrame")
    if not d then return end
    ScrollBarOf(d, "CalendarEventPickerFrame")
    -- 底部那顆是「關閉」文字鈕（不是 ×）⇒ 一般按鈕、secondary
    PlainButton("CalendarEventPickerCloseButton", "secondary")
end

local function SkinTexturePicker()
    local d = SkinDialog("CalendarTexturePickerFrame")
    if not d then return end
    ScrollBarOf(d, "CalendarTexturePickerFrame")
    -- 只是選一張活動圖示（本機狀態），不是請求 ⇒ 一般按鈕
    PlainButton("CalendarTexturePickerAcceptButton", "primary")
    PlainButton("CalendarTexturePickerCancelButton", "secondary")
end

local function Apply()
    local f = _G.CalendarFrame
    if not f then
        E.Missing("CalendarFrame")
        return
    end
    if not E.Usable(f, "CalendarFrame") then return end

    -- 分段 pcall：一個面板出錯不拖垮其他面板
    for _, step in ipairs({
        SkinMain, SkinHoliday, SkinRaid, SkinViewEvent, SkinCreateEvent,
        SkinMassInvite, SkinEventPicker, SkinTexturePicker,
    }) do
        local ok, err = pcall(step, f)
        if not ok then ns.ReportError(err) end
    end
end

E.Register{
    key   = "calendar",
    addon = "Blizzard_Calendar",
    title = L["Calendar"],
    apply = Apply,
}
