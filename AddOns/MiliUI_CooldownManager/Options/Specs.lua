------------------------------------------------------------
-- 設定表單的規格與接線（條頁與主題頁共用）
--
--   Specs.Themed(mode)            圖示／文字／效果三節（mode = "bar" | "theme"）
--   Specs.Layout(key)             版面（條頁）
--   Specs.Visibility()            顯示條件（條頁）
--   Specs.Anchor(key)             錨定（條頁）
--   Specs.MakeCtx(info, onApply)  info = { mode, key }；onApply(spec) 在值寫進去之後叫
--   Specs.BuildForm(parent, controls, ctx, width) → form（content／height／Refresh）
--
-- 每條 spec 除了 Controls 要的欄位，另外帶：
--   root     "theme"：主題形狀的欄位（ns.Setting 的 path，條頁讀的是三層繼承後的值、
--            寫進條自己的子表；主題頁直接讀寫 profile.theme）
--            "bar"：條自己的欄位（版面、長條、顯示條件、錨定），不繼承
--   path     點分路徑（numbers 用 sub ＋ 欄位 key 拼）
--   section  "icon" | "text" | "glow" | "fade"：條頁勾著「跟隨全域主題」時整節蓋遮罩
--   get/set  自訂的讀寫（開關型的淡出、第二列尺寸、錨定…），收 info
--   refreshPage  寫完要重建表單（有列會出現／消失）
--   level    真實條的重排等級（預設 layout；錨定是 structure）
--   resetPaths  右鍵「重設為預設」要清哪些 path（預設就是 path）
--
-- ⚠ 條頁的主題欄位**讀的是繼承後的值**：沒跟隨、但這一格自己沒存的，看到的是主題的值。
--   顏色若直接回主題那張表，Controls 的色票會就地改掉主題（它拿到表就直接寫 r/g/b）。
--   所以條頁的主題顏色回一個代理表：讀照繼承、第一次寫才把值複製進條自己的子表。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

ns.Specs = {}
local Specs = ns.Specs

local LABEL_W = ns.WidgetsEnv.LABEL_W or 128

------------------------------------------------------------
-- 下拉清單
------------------------------------------------------------
local function GrowItems(kind)
    if kind == "bars" then
        return {
            { text = L["Downward"], value = "CENTER_DOWN" },
            { text = L["Upward"],   value = "CENTER_UP" },
        }
    end
    return {
        { text = L["Centered, new rows below"],   value = "CENTER_DOWN" },
        { text = L["Centered, new rows above"],   value = "CENTER_UP" },
        { text = L["Left-aligned, rows below"],   value = "LEFT_DOWN" },
        { text = L["Left-aligned, rows above"],   value = "LEFT_UP" },
        { text = L["Right-aligned, rows below"],  value = "RIGHT_DOWN" },
        { text = L["Right-aligned, rows above"],  value = "RIGHT_UP" },
    }
end

local POINT_ITEMS = {
    { text = L["Top left"],     value = "TOPLEFT" },
    { text = L["Top"],          value = "TOP" },
    { text = L["Top right"],    value = "TOPRIGHT" },
    { text = L["Left"],         value = "LEFT" },
    { text = L["Center"],       value = "CENTER" },
    { text = L["Right"],        value = "RIGHT" },
    { text = L["Bottom left"],  value = "BOTTOMLEFT" },
    { text = L["Bottom"],       value = "BOTTOM" },
    { text = L["Bottom right"], value = "BOTTOMRIGHT" },
}

local GLOW_ITEMS = {
    { text = L["Pixel"],          value = "pixel" },
    { text = L["Autocast"],       value = "autocast" },
    { text = L["Action button"],  value = "button" },
    { text = L["Proc"],           value = "proc" },
}

local SIDE_ITEMS = {
    { text = L["Left"],  value = "LEFT" },
    { text = L["Right"], value = "RIGHT" },
    { text = L["None"],  value = "NONE" },
}

local GROUP_ITEMS = {
    { text = L["Any"],   value = "any" },
    { text = L["Solo"],  value = "solo" },
    { text = L["Party"], value = "party" },
    { text = L["Raid"],  value = "raid" },
}

local OUTLINE_ITEMS = {
    { text = L["None"],          value = "" },
    { text = L["Outline"],       value = "OUTLINE" },
    { text = L["Thick outline"], value = "THICKOUTLINE" },
}

-- 錨定的「邊」：本條貼在目標的哪一邊
local EDGE_ITEMS = {
    { text = L["Below it"],       value = "BELOW" },
    { text = L["Above it"],       value = "ABOVE" },
    { text = L["To its left"],    value = "LEFTOF" },
    { text = L["To its right"],   value = "RIGHTOF" },
}
local EDGE_POINTS = {
    BELOW   = { "TOP", "BOTTOM" },
    ABOVE   = { "BOTTOM", "TOP" },
    LEFTOF  = { "RIGHT", "LEFT" },
    RIGHTOF = { "LEFT", "RIGHT" },
}

local function MediaItems(first, kind)
    return function()
        local items = { first }
        for _, name in ipairs(ns.Media.List(kind)) do
            items[#items + 1] = { text = name, value = name }
        end
        return items
    end
end
local BorderItems  = MediaItems({ text = L["Solid"], value = "solid" }, "border")
local TextureItems = MediaItems({ text = L["Solid"], value = "solid" }, "statusbar")
local FontItems    = MediaItems({ text = L["Default font"], value = "DEFAULT" }, "font")
Specs.TextureItems, Specs.FontItems = TextureItems, FontItems

------------------------------------------------------------
-- 讀寫（主題欄位在條頁與主題頁走不同的表）
------------------------------------------------------------
local function PathOf(spec)
    if spec.path then return spec.path end
    if spec.sub then return spec.sub .. "." .. spec.key end
    return spec.key
end
Specs.PathOf = PathOf

local function ReadThemed(info, path)
    if info.mode == "theme" then return ns.Setting("theme", path) end
    return ns.Setting(info.key, path)
end

local function WriteThemed(info, path, v)
    local p = ns.profile
    if not p then return end
    if info.mode == "theme" then
        ns.DB.SetPath(p.theme, path, v)
    else
        ns.DB.OwnSet(info.key, path, v)
    end
end
Specs.ReadThemed, Specs.WriteThemed = ReadThemed, WriteThemed

local function ColorProxy(key, path)
    return setmetatable({}, {
        __index = function(_, k)
            local c = ns.Setting(key, path)
            return type(c) == "table" and c[k] or nil
        end,
        __newindex = function(_, k, v)
            local own = ns.DB.OwnGet(key, path)
            if type(own) ~= "table" then
                own = {}
                local src = ns.Setting(key, path)
                if type(src) == "table" then
                    for kk, vv in pairs(src) do own[kk] = vv end
                end
                ns.DB.OwnSet(key, path, own)
            end
            own[k] = v
        end,
    })
end

function Specs.MakeCtx(info, onApply)
    local ctx
    ctx = ns.Controls.MakeCtx(function() return {} end, function()
        onApply(ctx.lastSpec)
    end)
    ctx.info = info
    ctx.get = function(spec)
        if spec.get then return spec.get(info) end
        local path = PathOf(spec)
        if spec.root == "theme" then
            if info.mode ~= "theme" and spec.type == "color" then return ColorProxy(info.key, path) end
            return ReadThemed(info, path)
        end
        return ns.DB.GetPath(ns.DB.BarTable(info.key), path)
    end
    ctx.set = function(spec, v)
        ctx.lastSpec = spec
        if spec.set then spec.set(info, v) return end
        local path = PathOf(spec)
        if spec.root == "theme" then
            WriteThemed(info, path, v)
        else
            ns.DB.SetPath(ns.DB.BarTable(info.key), path, v)
        end
    end
    return ctx
end

------------------------------------------------------------
-- spec 小工具
------------------------------------------------------------
local function Merge(s, extra)
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function TS(section, kind, path, label, extra)
    return Merge({ type = kind, root = "theme", path = path, key = path, label = label, section = section }, extra)
end

local function BS(kind, path, label, extra)
    return Merge({ type = kind, root = "bar", path = path, key = path, label = label }, extra)
end

local function Note(label, section)
    return { type = "text", label = label, section = section }
end

local function Nested(label, section)
    return { type = "header", label = label, nested = true, section = section }
end

-- 「本條 N 個法術有覆寫 ［清除覆寫］」：畫在小節標題那一行的右側，本身不佔高度
local function OverrideRow(group)
    return { type = "custom", h = 0, noReset = true, build = function(parent, x, y, width, ctx)
        local btn = W.CreateButton(parent, L["Clear overrides"], "normal", 90, 18)
        W.FitButton(btn, 90, 18)
        -- 小節標題的字在這一列上方 12 左右（HEADER_H 24 的中線）
        btn:SetPoint("RIGHT", parent, "TOPLEFT", x + width, y + 12)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("RIGHT", btn, "LEFT", -8, 0)
        fs:SetTextColor(0.65, 0.65, 0.65)
        local confirm
        local function Ids()
            local out, hid = ns.Catalog.Bar(ctx.info.key, true)
            for _, id in ipairs(hid or {}) do out[#out + 1] = id end
            return out
        end
        btn:SetScript("OnClick", function()
            if not confirm then
                confirm = W.CreateConfirmPopup(ns.Options.panel, 320,
                    L["Clear this section's per-spell overrides on this bar?"], function()
                        ns.DB.ClearOverrides(Ids(), group)
                        ctx.lastSpec = { level = "layout" }
                        ctx.apply()
                        if ctx.form then ctx.form:Refresh() end
                    end)
            end
            confirm:Show()
        end)
        local function Refresh()
            local n = ns.DB.CountOverrides(Ids(), group)
            fs:SetText(L["%d spells on this bar have overrides"]:format(n))
            fs:SetShown(n > 0)
            btn:SetShown(n > 0)
        end
        return 0, Refresh
    end }
end

local function FollowToggle(group)
    return BS("toggle", "follow." .. group, L["Follow global theme"], { refreshPage = true, level = "layout" })
end

-- 開關型的淡出：值存 false（不淡）或 0～1 的透明度
local FADE_ON = { outOfCombat = 0.5, noTarget = 0.3, mounted = 0 }
local function FadeRows(which, label)
    local path = "fade." .. which
    return
        TS("fade", "toggle", path, label, {
            get = function(info) local v = ReadThemed(info, path); return v ~= false and v ~= nil end,
            set = function(info, on)
                WriteThemed(info, path, on and FADE_ON[which] or false)
            end,
        }),
        TS("fade", "slider", path, L["Opacity"], {
            min = 0, max = 100, step = 5, scale = 100,
            get = function(info) local v = ReadThemed(info, path); return type(v) == "number" and v or 0 end,
        })
end

------------------------------------------------------------
-- 圖示／文字／效果（條頁與主題頁同一份）
------------------------------------------------------------
function Specs.Themed(mode)
    local bar = mode == "bar"
    local list = {}
    local function add(...)
        for i = 1, select("#", ...) do
            local s = select(i, ...)
            if s then list[#list + 1] = s end
        end
    end

    -- 圖示
    add({ type = "header", label = L["Icons"] })
    if bar then add(OverrideRow("icon"), FollowToggle("icon"),
        Note(L["While checked, this section uses the Theme page. Uncheck it to give this bar its own values."])) end
    add(TS("icon", "dropdown", "border.texture", L["Border texture"], { items = BorderItems }),
        TS("icon", "slider", "border.size", L["Border size"], { min = 0, max = 4, step = 1 }),
        TS("icon", "color", "border.color", L["Border color"]),
        TS("icon", "slider", "icon.zoom", L["Icon zoom"], { min = 0, max = 0.2, step = 0.01 }),
        Note(L["Crops the icon edges; 0 shows the whole texture."], "icon"),
        TS("icon", "color", "icon.swipeColor", L["Cooldown swipe color"], { hasAlpha = true }),
        TS("icon", "toggle", "icon.hideGCDSwipe", L["Hide GCD swipe"]),
        TS("icon", "toggle", "icon.desaturateOnCooldown", L["Desaturate on cooldown"]))

    -- 文字
    add({ type = "header", label = L["Text"] })
    if bar then add(OverrideRow("text"), FollowToggle("text")) end
    if not bar then
        add(TS("text", "dropdown", "font", L["Font"], { items = FontItems }),
            TS("text", "dropdown", "outline", L["Outline"], { items = OUTLINE_ITEMS }))
    end
    add(Nested(L["Countdown"], "text"),
        TS("text", "slider", "cooldownText.size", L["Font size"], { min = 6, max = 40, step = 1 }),
        TS("text", "color", "cooldownText.color", L["Color"]),
        TS("text", "slider", "cooldownText.decimalsBelow", L["Decimals below"], { min = 0, max = 10, step = 1 }),
        Note(L["Shows one decimal place under this many seconds; 0 never shows decimals."], "text"),
        TS("text", "toggle", "cooldownText.lowBelow", L["Color when low"], {
            get = function(info) return (tonumber(ReadThemed(info, "cooldownText.lowBelow")) or 0) > 0 end,
            set = function(info, on) WriteThemed(info, "cooldownText.lowBelow", on and 5 or 0) end,
        }),
        TS("text", "color", "cooldownText.lowColor", L["Low color"]),
        TS("text", "slider", "cooldownText.lowBelow", L["Low below (sec)"], { min = 0, max = 30, step = 1 }),
        Nested(L["Charges"], "text"),
        TS("text", "slider", "chargeText.size", L["Font size"], { min = 6, max = 30, step = 1 }),
        TS("text", "color", "chargeText.color", L["Color"]),
        TS("text", "dropdown", "chargeText.point", L["Anchor"], { items = POINT_ITEMS }),
        TS("text", "numbers", nil, L["Offset"], { sub = "chargeText", path = false,
            resetPaths = { "chargeText.x", "chargeText.y" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }),
        Nested(L["Stacks"], "text"),
        TS("text", "slider", "stackText.size", L["Font size"], { min = 6, max = 30, step = 1 }),
        TS("text", "color", "stackText.color", L["Color"]),
        TS("text", "dropdown", "stackText.point", L["Anchor"], { items = POINT_ITEMS }),
        TS("text", "numbers", nil, L["Offset"], { sub = "stackText", path = false,
            resetPaths = { "stackText.x", "stackText.y" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }))

    -- 效果（發光、無損刷新、按鍵文字）＋淡出
    add({ type = "header", label = L["Effects"] })
    if bar then add(OverrideRow("glow"), FollowToggle("glow")) end
    add(Note(L["Glows, pandemic borders and keybind text are drawn starting with the next version; the values are saved now."], "glow"),
        Nested(L["Proc glow"], "glow"),
        TS("glow", "toggle", "glow.proc.enabled", L["Enable"]),
        TS("glow", "dropdown", "glow.proc.type", L["Style"], { items = GLOW_ITEMS }),
        TS("glow", "color", "glow.proc.color", L["Color"]),
        Nested(L["Ready glow"], "glow"),
        TS("glow", "toggle", "glow.ready.enabled", L["Enable"]),
        TS("glow", "dropdown", "glow.ready.type", L["Style"], { items = GLOW_ITEMS }),
        TS("glow", "color", "glow.ready.color", L["Color"]),
        Nested(L["Other"], "glow"),
        TS("glow", "color", "pandemic.color", L["Pandemic border color"]),
        TS("glow", "toggle", "keybind.enabled", L["Show keybind text"]))
    add(Nested(L["Fade"]))
    if bar then add(BS("toggle", "follow.fade", L["Follow global theme"], { refreshPage = true })) end
    add(FadeRows("outOfCombat", L["Fade out of combat"]))
    add(FadeRows("noTarget", L["Fade without a target"]))
    add(FadeRows("mounted", L["Fade while mounted"]))
    add(Note(L["Opacity the bar fades to; 0 hides it completely. When several apply, the lowest wins."], "fade"))
    return list
end

------------------------------------------------------------
-- 版面（條自己的欄位）
------------------------------------------------------------
function Specs.Layout(key)
    local bar = ns.DB.BarTable(key) or {}
    local kind = bar.kind == "bars" and "bars" or "icons"
    local list = { { type = "header", label = L["Layout"] } }
    local function add(s) list[#list + 1] = s end

    if kind == "icons" then
        add(BS("slider", "layout.maxPerRow", L["Icons per row"], { min = 1, max = 20, step = 1 }))
    end
    add(BS("slider", "layout.spacing", L["Spacing"], { min = 0, max = 20, step = 1 }))
    add(BS("dropdown", "layout.grow", L["Growth"], { items = GrowItems(kind) }))
    if kind == "icons" then
        add(BS("numbers", nil, L["Icon size"], { sub = "layout.size", path = false, resetPaths = { "layout.size" },
            fields = { { key = "w", label = L["W"] }, { key = "h", label = L["H"] } } }))
        add(BS("toggle", "layout.row2Size", L["Separate size for row 2+"], {
            refreshPage = true,
            get = function() return type(ns.DB.GetPath(ns.DB.BarTable(key), "layout.row2Size")) == "table" end,
            set = function(_, on)
                local b = ns.DB.BarTable(key)
                if not b then return end
                if on then
                    local size = b.layout and b.layout.size or {}
                    b.layout.row2Size = { w = tonumber(size.w) or 36, h = tonumber(size.h) or 36 }
                else
                    b.layout.row2Size = false
                end
            end,
        }))
        if type(bar.layout) == "table" and type(bar.layout.row2Size) == "table" then
            add(BS("numbers", nil, L["Row 2+ size"], { sub = "layout.row2Size", path = false,
                resetPaths = { "layout.row2Size" }, refreshPage = true,
                fields = { { key = "w", label = L["W"] }, { key = "h", label = L["H"] } } }))
        end
        if bar.source == "buffs" or bar.source == "custom" then
            add(BS("toggle", "layout.fixedSlots", L["Keep empty slots for missing buffs"]))
            add(Note(L["Buffs that aren't up keep their place as a dimmed icon, so the others don't shift."]))
        end
    else
        add(BS("slider", "bar.width", L["Width"], { min = 0, max = 600, step = 1 }))
        add(Note(L["0 matches the first row of Essential Cooldowns."]))
        add(BS("slider", "bar.height", L["Height"], { min = 6, max = 60, step = 1 }))
        add(BS("dropdown", "bar.iconSide", L["Icon position"], { items = SIDE_ITEMS }))
        add(BS("slider", "bar.iconGap", L["Icon gap"], { min = 0, max = 10, step = 1 }))
        add(BS("dropdown", "bar.texture", L["Texture"], { items = TextureItems }))
        add(BS("color", "bar.color", L["Bar color"]))
        add(BS("color", "bar.bgColor", L["Background color"]))
    end
    return list
end

------------------------------------------------------------
-- 顯示條件
------------------------------------------------------------
function Specs.Visibility()
    return {
        { type = "header", label = L["Visibility"] },
        Nested(L["Show when"]),
        BS("toggle", "visibility.showCombat", L["In combat"]),
        BS("toggle", "visibility.showTarget", L["Has a target"]),
        Note(L["Leave both unchecked to always show. Check either to show only while one of them is true."]),
        Nested(L["Restrictions"]),
        BS("toggle", "visibility.hideMounted", L["Hide while mounted"]),
        BS("toggle", "visibility.onlyInstances", L["Only in instances"]),
        BS("dropdown", "visibility.group", L["Group"], { items = GROUP_ITEMS }),
        Note(L["Restrictions win over \"Show when\"."]),
    }
end

------------------------------------------------------------
-- 錨定
------------------------------------------------------------
local function AnchorItems(key)
    local items = { { text = L["None (own position)"], value = "none" } }
    local p = ns.profile
    for _, other in ipairs(p and p.barOrder or {}) do
        if other ~= key and ns.DB.BarTable(other) and not ns.DB.AnchorWouldCycle(key, other) then
            items[#items + 1] = { text = ns.Options.PageTitle(other) or ns.Options.BarTitle(other), value = other }
        end
    end
    return items
end

local function EdgeOf(a)
    for id, pts in pairs(EDGE_POINTS) do
        if a.point == pts[1] and a.relPoint == pts[2] then return id end
    end
    return "BELOW"
end

function Specs.Anchor(key)
    local bar = ns.DB.BarTable(key) or {}
    local anchored = type(bar.anchor) == "table"
    local list = {
        { type = "header", label = L["Anchoring"] },
        BS("dropdown", "anchor", L["Follow bar"], {
            items = AnchorItems(key), refreshPage = true, level = "structure",
            get = function()
                local a = ns.DB.GetPath(ns.DB.BarTable(key), "anchor")
                return type(a) == "table" and a.to or "none"
            end,
            set = function(_, v)
                local b = ns.DB.BarTable(key)
                if not b then return end
                if v == "none" then
                    -- 換成目前畫面上的位置，放開錨定的當下不跳
                    local pos = ns.EditMode and ns.EditMode.ReadPos and ns.EditMode.ReadPos(key)
                    if pos then b.pos = pos end
                    b.anchor = false
                else
                    local a = type(b.anchor) == "table" and b.anchor
                        or { point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }
                    a.to = v
                    b.anchor = a
                end
            end,
        }),
    }
    if anchored then
        list[#list + 1] = BS("dropdown", "anchor.point", L["Side"], {
            items = EDGE_ITEMS, level = "structure", resetPaths = { "anchor.point", "anchor.relPoint" },
            get = function()
                local a = ns.DB.GetPath(ns.DB.BarTable(key), "anchor")
                return type(a) == "table" and EdgeOf(a) or "BELOW"
            end,
            set = function(_, v)
                local a = ns.DB.GetPath(ns.DB.BarTable(key), "anchor")
                local pts = EDGE_POINTS[v]
                if type(a) == "table" and pts then a.point, a.relPoint = pts[1], pts[2] end
            end,
        })
        list[#list + 1] = BS("numbers", nil, L["Offset"], { sub = "anchor", path = false, level = "structure",
            resetPaths = { "anchor.x", "anchor.y" }, fallback = 0,
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } })
    end
    list[#list + 1] = Note(L["A bar that follows another moves with it. Dragging it in Edit Mode stops the following."])
    return list
end

-- 表單的「形狀」：有列會出現或消失的設定。形狀一樣就重用建好的表單（frame 刪不掉）
function Specs.BarSignature(key)
    local bar = ns.DB.BarTable(key) or {}
    local layout = type(bar.layout) == "table" and bar.layout or {}
    local p = ns.profile
    return table.concat({
        tostring(bar.kind), tostring(bar.source),
        type(layout.row2Size) == "table" and "r2" or "-",
        type(bar.anchor) == "table" and "a" or "-",
        table.concat(p and p.barOrder or {}, ","),
    }, "|")
end

------------------------------------------------------------
-- 表單：Controls.Build ＋ 跟隨遮罩 ＋ 右鍵重設
------------------------------------------------------------
local RESETTABLE = { toggle = true, slider = true, number = true, numbers = true, color = true, dropdown = true }

local function ResetSpec(ctx, spec)
    local info = ctx.info
    local paths = spec.resetPaths or { PathOf(spec) }
    local p = ns.profile
    if not p then return end
    for _, path in ipairs(paths) do
        if spec.root == "theme" then
            if info.mode == "theme" then
                ns.DB.SetPath(p.theme, path, ns.DB.DefaultFor("theme", nil, path))
            else
                ns.DB.OwnSet(info.key, path, nil)
            end
        else
            local v = ns.DB.DefaultFor("bar", info.key, path)
            if v == nil then v = spec.fallback end
            ns.DB.SetPath(ns.DB.BarTable(info.key), path, v)
        end
    end
    ctx.lastSpec = spec
    ctx.apply()
    if ctx.form then ctx.form:Refresh() end
end

local function ResetCatcher(content, row, ctx, x0)
    local spec = row.spec
    local f = CreateFrame("Frame", nil, content)
    f:SetPoint("TOPLEFT", content, "TOPLEFT", x0, row.top)
    f:SetSize(LABEL_W, math.max(1, row.top - row.bottom))
    f:SetFrameLevel(content:GetFrameLevel() + 5)
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" then return end
        if W.Menu.IsOpenFor(self) then W.Menu.Hide() return end
        W.Menu.Show({
            { text = spec.label or "", isTitle = true },
            { text = L["Reset to default"], onClick = function() ResetSpec(ctx, spec) end },
        }, self)
    end)
    return f
end

function Specs.BuildForm(parent, controls, ctx, width)
    local content = CreateFrame("Frame", nil, parent)
    content:SetPoint("TOPLEFT")
    content:SetSize(width, 1)
    local x0 = 4
    local height, refreshers, rows = ns.Controls.Build(content, controls, ctx, x0, -4, width)
    local form = { content = content, height = height + 20, refreshers = refreshers, rows = rows, masks = {}, ctx = ctx }
    content:SetHeight(form.height)
    ctx.form = form

    -- 每一節的上下緣（有 section 的列）
    local ranges = {}
    for _, row in ipairs(rows) do
        local sec = row.spec.section
        if sec then
            local r = ranges[sec]
            if not r then
                ranges[sec] = { top = row.top, bottom = row.bottom }
            else
                if row.top > r.top then r.top = row.top end
                if row.bottom < r.bottom then r.bottom = row.bottom end
            end
        end
    end
    if ctx.info.mode == "bar" then
        for sec, r in pairs(ranges) do
            local m = CreateFrame("Frame", nil, content, "BackdropTemplate")
            m:SetPoint("TOPLEFT", content, "TOPLEFT", 0, r.top)
            m:SetSize(width, math.max(1, r.top - r.bottom))
            m:SetFrameLevel(content:GetFrameLevel() + 40)
            m:EnableMouse(true)              -- 擋點擊；滾輪不擋（沒開 MouseWheel，照樣捲得動）
            m:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
            m:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            m:Hide()
            form.masks[sec] = m
        end
    end
    for _, row in ipairs(rows) do
        if RESETTABLE[row.spec.type] and not row.spec.noReset then ResetCatcher(content, row, ctx, x0) end
    end

    function form:Refresh()
        for _, fn in ipairs(self.refreshers) do fn() end
        if ctx.info.mode == "bar" then
            local bar = ns.DB.BarTable(ctx.info.key)
            local follow = bar and type(bar.follow) == "table" and bar.follow or {}
            for sec, m in pairs(self.masks) do m:SetShown(follow[sec] ~= false) end
        end
    end
    return form
end
