------------------------------------------------------------
-- 「外觀」分頁：左邊即時預覽、右邊表單
--
-- 預覽的設計（「美觀又直覺」那一題的答案）：
--   * 左半邊是一張分頁卡片，卡片上方的兩顆分頁鈕就是「直式｜橫式」—— 點哪顆，預覽、
--     畫面上的時間軸、右邊表單的版面那一節**同時**切過去。同一個開關不在表單裡再放一次：
--     玩家看到的就是他點的，不用在兩個地方對照。
--   * 預覽跟畫面上那一條是同一支 Display、吃同一份設定，只是資料換成 Mock（三種來源、
--     快到了、排隊中、暫停都會輪流出現），所以每拉一格滑桿兩邊一起變。
--   * 卡片高是固定的：直式天生是高瘦的、橫式是寬扁的，放進同一張卡片時自動縮放到放得下、
--     置中（包含名稱與刻度數字的估計寬度），所以切換時卡片本身不跳動、不擠到表單。
--   * 版面（長度、時間範圍、圖示大小、文字放哪邊、反向）直式橫式各存一份；樣式共用。
--     所以表單的「版面」一節標題會跟著寫「直式」或「橫式」，玩家知道自己在改哪一份。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, tabCard, clip, preview, refreshers, layoutHeader, scroll

local LEFT_X, TOP_Y = 16, -50
local LEFT_W = 320
local CARD_H = 380
local PAD = 8

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

-- 預覽：套設定 → 量外框 → 縮放到卡片放得下 → 置中
local function ApplyPreview()
    if not preview then return end
    local d = ns.db.display
    preview:Apply(d, ns.DB.Layout(), d.orientation)
    local cw, ch = clip:GetSize()
    local l, r, t, b = preview:GetBounds()
    local scale = math.min(1, (cw - PAD * 2) / (l + r), (ch - PAD * 2) / (t + b))
    if scale <= 0 then scale = 1 end
    local f = preview.frame
    f:SetScale(scale)
    f:ClearAllPoints()
    -- ⚠ 被縮放的框，SetPoint 的位移也會跟著乘上縮放（wow-setscale-offset-units），
    --   所以這裡給「框自己的單位」：外框中心相對框中心的偏移，反過來推回去
    f:SetPoint("CENTER", clip, "CENTER", -(r - l) / 2, -(t - b) / 2)
end

local function UpdateLayoutHeader()
    if not layoutHeader then return end
    local o = ns.db.display.orientation
    layoutHeader:SetText(o == "horizontal" and L["Layout — horizontal"]
        or o == "bars" and L["Layout — bars"] or L["Layout — vertical"])
end

local function Apply()
    ns.Screen.Apply()
    ApplyPreview()
end

local function ApplyAndRefresh()
    Apply()
    UpdateLayoutHeader()
    RefreshAll()
end

------------------------------------------------------------
-- 表單
------------------------------------------------------------
local function LayoutSpec(t)
    t.root = "layout"
    return t
end

local CONTROLS = {
    -- 標題文字由 UpdateLayoutHeader 換成「版面（直式）」或「版面（橫式）」
    { type = "header", label = L["Layout — vertical"], layoutHeader = true },
    LayoutSpec({ type = "slider", key = "length",   label = L["Length"],               min = 120, max = 900, step = 10 }),
    LayoutSpec({ type = "slider", key = "window",   label = L["Time range (seconds)"], min = 10,  max = 90,  step = 5 }),
    { type = "text", label = L["Abilities further away than this wait off the track and slide in when they get close."] },
    LayoutSpec({ type = "slider", key = "iconSize", label = L["Icon size"],            min = 16,  max = 64,  step = 1 }),
    LayoutSpec({ type = "slider", key = "spacing",  label = L["Minimum gap"],          min = 0,   max = 12,  step = 1 }),
    LayoutSpec({ type = "toggle", key = "flip",     label = L["Reverse direction"] }),
    { type = "text", label = L["Off: abilities move down (vertical) or to the left (horizontal)."] },
    { type = "text", label = L["Bars: length is the bar width, icon size is the bar height, reverse puts the soonest bar at the bottom."] },
    LayoutSpec({ type = "dropdown", key = "textSide", label = L["Name side"], items = {
        { text = L["Right / below the icon"], value = "after" },
        { text = L["Left / above the icon"],  value = "before" },
    } }),
    LayoutSpec({ type = "toggle", key = "showName", label = L["Show ability name"] }),
    { type = "slider", sub = "display", key = "scale", label = L["Scale"], min = 0.5, max = 2, step = 0.05 },

    { type = "header", label = L["Bars"] },
    { type = "dropdown", sub = "display", sub2 = "bar", key = "texture", label = L["Texture"],
      items = function() return ns.Media.TextureItems() end },
    { type = "color", sub = "display", sub2 = "bar", key = "color",   label = L["Bar color"] },
    { type = "color", sub = "display", sub2 = "bar", key = "bgColor", label = L["Background color"], hasAlpha = true },
    { type = "text", label = L["Only used by the bars layout. With \"Use the ability's timeline color\" on, abilities that have a color use it instead."] },

    { type = "header", label = L["Icon"] },
    { type = "toggle", sub = "display", sub2 = "icon", key = "border",        label = L["Square border"] },
    { type = "color",  sub = "display", sub2 = "icon", key = "borderColor",   label = L["Border color"], hasAlpha = true },
    { type = "toggle", sub = "display", sub2 = "icon", key = "useEventColor", label = L["Use the ability's timeline color"] },
    { type = "text", label = L["Blizzard (and addons such as DBM) can give each boss ability its own color; when it has none, the border color above is used."] },
    { type = "toggle", sub = "display", sub2 = "icon", key = "zoom",          label = L["Crop icon edges"] },
    { type = "toggle", sub = "display", sub2 = "icon", key = "indicators",    label = L["Role and danger marks"] },

    { type = "header", label = L["Ability name"] },
    { type = "dropdown", sub = "display", sub2 = "name", key = "font", label = L["Font"],
      items = function() return ns.Media.FontItems() end },
    { type = "slider",   sub = "display", sub2 = "name", key = "size",    label = L["Font size"], min = 8, max = 28, step = 1 },
    { type = "dropdown", sub = "display", sub2 = "name", key = "outline", label = L["Outline"],
      items = function() return ns.Media.OutlineItems() end },
    { type = "toggle",   sub = "display", sub2 = "name", key = "shadow",  label = L["Shadow"] },
    { type = "color",    sub = "display", sub2 = "name", key = "color",   label = L["Color"] },
    { type = "toggle",   sub = "display", sub2 = "name", key = "showOwner", label = L["Show which addon added it"] },
    { type = "text", label = L["Entries added by another addon get its name in front, in gray. Blizzard's own abilities never do."] },

    { type = "header", label = L["Countdown"] },
    { type = "toggle",   sub = "display", sub2 = "countdown", key = "show",    label = L["Show countdown"] },
    { type = "dropdown", sub = "display", sub2 = "countdown", key = "font",    label = L["Font"],
      items = function() return ns.Media.FontItems() end },
    { type = "slider",   sub = "display", sub2 = "countdown", key = "size",    label = L["Font size"], min = 8, max = 32, step = 1 },
    { type = "dropdown", sub = "display", sub2 = "countdown", key = "outline", label = L["Outline"],
      items = function() return ns.Media.OutlineItems() end },
    { type = "color",    sub = "display", sub2 = "countdown", key = "color",   label = L["Color"] },
    { type = "toggle",   sub = "display", sub2 = "countdown", key = "decimals", label = L["Tenths of a second under 3 seconds"] },

    { type = "header", label = L["About to happen"] },
    { type = "slider", sub = "display", sub2 = "highlight", key = "time",  label = L["Highlight under (seconds)"], min = 0, max = 10, step = 1 },
    { type = "color",  sub = "display", sub2 = "highlight", key = "color", label = L["Border color"] },
    { type = "color",  sub = "display", sub2 = "highlight", key = "countdownColor", label = L["Countdown color"] },

    { type = "header", label = L["Track"] },
    { type = "toggle", sub = "display", sub2 = "track", key = "show",       label = L["Show the track line"] },
    { type = "slider", sub = "display", sub2 = "track", key = "thickness",  label = L["Line thickness"], min = 1, max = 6, step = 1 },
    { type = "color",  sub = "display", sub2 = "track", key = "color",      label = L["Line color"], hasAlpha = true },
    { type = "toggle", sub = "display", sub2 = "track", key = "ticks",      label = L["Tick every 5 seconds"] },
    { type = "toggle", sub = "display", sub2 = "track", key = "background", label = L["Background"] },
    { type = "color",  sub = "display", sub2 = "track", key = "bgColor",    label = L["Background color"], hasAlpha = true },

    { type = "space", h = 10 },
    { type = "button", label = "", text = L["Restore defaults"], color = "red", width = 160,
      confirm = L["Restore every appearance setting to its default? Position and custom timelines are kept."],
      onClick = function()
          ns.DB.ResetStyle()
          if tabCard then tabCard:Select(ns.db.display.orientation) end
          Apply()
          UpdateLayoutHeader()
      end },
}

------------------------------------------------------------
-- 左半邊：直式｜橫式 分頁卡片 ＋ 預覽
------------------------------------------------------------
local function BuildPreview()
    tabCard = W.CreateTabCard(tab, {
        tabs = {
            { id = "vertical",   label = L["Vertical"] },
            { id = "horizontal", label = L["Horizontal"] },
            { id = "bars",       label = L["Bars"] },
        },
        selected = ns.db.display.orientation,
        help = L["Vertical, horizontal and bars each keep their own layout (length, time range, icon size, name side). Fonts, colors and borders are shared."],
        onSelect = function(id)
            ns.db.display.orientation = id
            ApplyAndRefresh()
        end,
    })
    local stripH = tabCard:Place(LEFT_X, TOP_Y, LEFT_W)
    tabCard:SetCardHeight(CARD_H)

    -- 預覽區：卡片內縮 1px（邊框）＋ 剪裁，縮放後的時間軸不會畫出卡片
    clip = CreateFrame("Frame", nil, tab)
    clip:SetPoint("TOPLEFT", tab, "TOPLEFT", LEFT_X + 1, TOP_Y - stripH - 1)
    clip:SetSize(LEFT_W - 2, CARD_H - 2)
    clip:SetClipsChildren(true)

    preview = ns.Display.New(clip)
    preview:SetCollector(ns.Mock.Collect)
    preview:SetFilter(function(kind) return ns.db.display.sources[kind] ~= false end)

    -- 卡片底下：畫面上同步預覽的開關＋一行說明
    local cb = W.CreateCheckButton(tab, L["Also preview on screen"], function(checked)
        ns.db.previewOnScreen = checked and true or false
        ns.Screen.Refresh()
    end)
    cb:SetPoint("TOPLEFT", tab, "TOPLEFT", LEFT_X, TOP_Y - stripH - CARD_H - 10)
    cb:SetChecked(ns.db.previewOnScreen)
    tab.previewCheck = cb

    local note = tab:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -6)
    note:SetWidth(LEFT_W)
    note:SetJustifyH("LEFT")
    note:SetSpacing(2)
    note:SetText(L["While this window is open the timeline on screen runs the same preview. Drag it to move; in a boss fight it shows the real thing."])
end

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, L["Appearance"], ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    BuildPreview()

    -- 右半邊：表單
    local formX = LEFT_X + LEFT_W + 16
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", formX - 4, TOP_Y + 6)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(holder)
    local formW = ns.Options.PANEL_W - formX - 30

    local ctx = ns.Options.MakeCtx(Apply)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(formW, 1)
    local height, rf, rows = ns.Controls.Build(content, CONTROLS, ctx, 4, -4, formW)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    refreshers = rf

    -- 找到「版面」那一節的標題字（Controls 建的 group label），之後換字
    for _, row in ipairs(rows or {}) do
        if row.spec.layoutHeader then
            for _, region in ipairs({ content:GetRegions() }) do
                if region.GetText and region:GetText() == row.spec.label then
                    layoutHeader = region
                    break
                end
            end
        end
    end
end

ns.RegisterCallback("ShowOptionsTab", "styleTab", function(id)
    if id ~= "style" then
        if tab then
            tab:Hide()
            preview:SetRunning(false)
        end
        return
    end
    Init()
    tabCard:Select(ns.db.display.orientation)
    tab.previewCheck:SetChecked(ns.db.previewOnScreen)
    UpdateLayoutHeader()
    RefreshAll()
    tab:Show()
    ApplyPreview()
    preview:SetRunning(true)
end)

ns.RegisterCallback("OptionsClosed", "styleTab", function()
    if preview then preview:SetRunning(false) end
end)
