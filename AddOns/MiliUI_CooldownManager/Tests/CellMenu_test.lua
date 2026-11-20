------------------------------------------------------------
-- 預覽格／點擊層格的右鍵選單（Options/Preview.lua 的 Preview.CellMenuItems 與 Proto:CellMenu）（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/CellMenu_test.lua
--
-- Preview.lua 連同 Core/Layout.lua 載進假環境（框全是假的，其餘 ns 欄位自動補成空殼）。
-- 覆蓋：
--   1. 產生器的形狀：標題 → 設定 → 移到 › → 分隔線 → 從這條移除；不給 settings 就不列「設定」
--   2. 移到：候選照左欄順序（barOrder，沒列到的照字母接後面）、現在這條打勾且點了不動、父列右側灰字是現在的條、
--      點了走 Preview.MoveTo(id, 目標, 來源)；沒有候選就不列；候選預設來自 Preview.DropCandidates
--   3. 溢來的格不列「移到」但照列移除；沒給 incoming 時自己查溢出表（實際的優先，再看設定算的）
--   4. hiddenItem：只剩標題與設定
--   5. Wire：右鍵放手開選單、提示有「右鍵：更多」；拖曳中／剛拖完不開；「＋」格不開；右鍵不會開始拖曳
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local ROOT = here .. "/.."

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- 假環境
------------------------------------------------------------
local function Auto()
    return setmetatable({}, {
        __index = function(s, k) local v = Auto(); rawset(s, k, v); return v end,
        __call = function() return nil end,
    })
end
local Methods = {}
local function Frame()
    local f = { shown = true, scripts = {}, level = 1, w = 1, h = 1, mouseOver = true }
    return setmetatable(f, { __index = function(_, k)
        if type(k) == "string" and k:match("^%l") then return nil end
        return Methods[k] or function() end
    end })
end
function Methods.Show(f) f.shown = true end
function Methods.Hide(f) f.shown = false end
function Methods.IsShown(f) return f.shown end
function Methods.IsVisible(f) return f.shown end
function Methods.SetScript(f, n, fn) f.scripts[n] = fn end
function Methods.GetScript(f, n) return f.scripts[n] end
function Methods.HookScript(f, n, fn) f.scripts[n] = fn end
function Methods.GetFrameLevel(f) return f.level end
function Methods.SetFrameLevel(f, l) f.level = l end
function Methods.SetSize(f, w, h) f.w, f.h = w, h end
function Methods.GetWidth(f) return f.w end
function Methods.GetHeight(f) return f.h end
function Methods.GetCenter() return 100, 100 end
function Methods.GetEffectiveScale() return 1 end
function Methods.IsMouseOver(f) return f.mouseOver end
function Methods.CreateTexture() return Frame() end
function Methods.CreateFontString() return Frame() end
function Methods.GetStringWidth() return 30 end
function Methods.GetChildren() return end

local now = 1000
local tipLines = {}
local env = setmetatable({}, { __index = _G })
env.CreateFrame = function() return Frame() end
env.UIParent = Frame()
env.GameTooltip = Frame()
env.GameTooltip.AddLine = function(_, t) tipLines[#tipLines + 1] = t end
env.GameTooltip.SetText = function(_, t) tipLines = { t } end
env.GetTime = function() return now end
env.GetCursorPosition = function() return 100, 100 end
env.IsMouseButtonDown = function() return true end
env.IsShiftKeyDown = function() return false end
env.C_Timer = { After = function() end }
env.C_Spell = { GetSpellCharges = function() return nil end }
env.C_UnitAuras = {}

local ns = Auto()
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.P = { Scale = function(v) return v end, Size = function(f, w, h) f:SetSize(w, h) end, Pixel = function(n) return n end }
local shownMenu
ns.W = Auto()
ns.W.Accent = function() return 1, 1, 1, 1 end
ns.W.Menu = { Show = function(items) shownMenu = items end }
ns.RegisterCallback = function() end
ns.Text = { TEXT_LIFT = 5 }
ns.Media = { SetFont = function() end }
ns.Glow = nil
local bars = {
    essential = { kind = "icons", layout = { maxPerRow = 8, spacing = 2, grow = "CENTER_DOWN", size = { w = 30, h = 30 } } },
    g1 = { kind = "icons", name = "Group 1", layout = { maxPerRow = 8, size = { w = 30, h = 30 } } },
    g2 = { kind = "icons", name = "Group 2", layout = { maxPerRow = 8, size = { w = 30, h = 30 } } },
    zz = { kind = "icons", name = "Zed", layout = { maxPerRow = 8, size = { w = 30, h = 30 } } },
}
ns.profile = { bars = bars, barOrder = { "essential", "g2", "g1" } }
ns.DB = { BarTable = function(k) return bars[k] end, BarIsRings = function() return false end, IsBuiltinBar = function(k) return k == "essential" end }
ns.Options = { PageTitle = function() return nil end, BarTitle = function(k) return bars[k] and bars[k].name or k end }
local lists = { essential = { 101, 102, 103 } }
ns.Catalog = Auto()
ns.Catalog.Bar = function(k) return lists[k] or {}, {} end
ns.Catalog.Info = function(id) return { name = "S" .. tostring(id), spellID = id } end
ns.Catalog.IsCustom = function() return false end
ns.Catalog.RingAccepts = function() return true end
ns.Catalog.SourceOf = function() return "essential" end
local overflowLive, overflowStatic
ns.Catalog.Overflow = function() return overflowLive end
ns.Catalog.OverflowStatic = function() return overflowStatic end
ns.Presets = { IsRacial = function() end, IsDefensive = function() end, IsControl = function() end }
ns.Sidebar = { BeginDrop = function() end, DropTargetAtCursor = function() end, ButtonAtCursor = function() end, EndDrop = function() end }
local popover
ns.SpellPopover = { Open = function(k, id, a) popover = { k, id, a } end }

local function Load(p)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(ROOT .. p)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(ROOT .. p, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end
Load("/Core/Layout.lua")
Load("/Options/Preview.lua")
local Preview = ns.Preview

local moved, removed = {}, {}
Preview.MoveTo = function(id, target, from) moved[#moved + 1] = { id, target, from } end
Preview.Remove = function(k, id) removed[#removed + 1] = { k, id } end

local function Texts(items)
    local t = {}
    for i, it in ipairs(items) do
        t[i] = it.isSeparator and "---" or ((it.isTitle and "#" or "") .. tostring(it.text))
    end
    return table.concat(t, "|")
end

------------------------------------------------------------
-- 1／2. 形狀與「移到」
------------------------------------------------------------
do
    local items = Preview.CellMenuItems("essential", 101, {
        settings = function() end, incoming = false, candidates = { g1 = true, g2 = true, zz = true } })
    eq("形狀", Texts(items), "#S101|Settings|Move to|---|Remove from this bar")
    eq("標題是格名、灰（isTitle）", items[1].isTitle, true)
    local mv = items[3]
    eq("移到：右側灰字是現在的條", mv.value, "essential")
    check("移到：有子選單", type(mv.submenu) == "table")
    eq("子選單照左欄順序，沒列到的接後面", Texts(mv.submenu), "essential|Group 2|Group 1|Zed")
    eq("現在這條打勾", mv.submenu[1].isActive, true)
    eq("現在這條點了不動（沒有 onClick）", mv.submenu[1].onClick, nil)
    eq("其他條沒打勾", mv.submenu[2].isActive, nil)
    mv.submenu[3].onClick()
    eq("點了走 MoveTo：id", moved[1] and moved[1][1], 101)
    eq("點了走 MoveTo：目標", moved[1] and moved[1][2], "g1")
    eq("點了走 MoveTo：來源", moved[1] and moved[1][3], "essential")
    items[5].onClick()
    eq("移除走 Preview.Remove：條", removed[1] and removed[1][1], "essential")
    eq("移除走 Preview.Remove：id", removed[1] and removed[1][2], 101)
end
do
    local items = Preview.CellMenuItems("essential", 101, { settings = function() end, incoming = false, candidates = {} })
    eq("沒有候選：不列移到", Texts(items), "#S101|Settings|---|Remove from this bar")
    items = Preview.CellMenuItems("essential", 101, { incoming = false, candidates = { g1 = true } })
    eq("沒給 settings：不列設定", Texts(items), "#S101|Move to|---|Remove from this bar")
    -- 候選預設來自 DropCandidates
    local saved = Preview.DropCandidates
    local asked
    Preview.DropCandidates = function(k, id) asked = { k, id }; return { g2 = true } end
    items = Preview.CellMenuItems("essential", 102, { incoming = false })
    eq("預設問 DropCandidates：條", asked and asked[1], "essential")
    eq("預設問 DropCandidates：id", asked and asked[2], 102)
    eq("預設候選", Texts(items[2].submenu), "essential|Group 2")
    Preview.DropCandidates = saved
end

------------------------------------------------------------
-- 3. 溢來的格
------------------------------------------------------------
do
    local items = Preview.CellMenuItems("g1", 101, { settings = function() end, incoming = "essential", candidates = { g2 = true } })
    eq("溢來的格：不列移到、照列移除", Texts(items), "#S101|Settings|---|Remove from this bar")
    -- 沒給 incoming：自己查（設定算的）
    overflowStatic = { from = { g1 = { [101] = "essential" } } }
    items = Preview.CellMenuItems("g1", 101, { candidates = { g2 = true } })
    eq("查溢出表（設定算的）：不列移到", Texts(items), "#S101|---|Remove from this bar")
    eq("IncomingFrom：設定算的", Preview.IncomingFrom("g1", 101), "essential")
    overflowStatic = nil
    overflowLive = { from = { g1 = { [101] = "utility" } } }
    eq("IncomingFrom：實際的優先", Preview.IncomingFrom("g1", 101), "utility")
    overflowLive = nil
    eq("IncomingFrom：不是溢來的", Preview.IncomingFrom("g1", 101), nil)
    items = Preview.CellMenuItems("g1", 101, { candidates = { g2 = true } })
    eq("沒溢出：列移到", Texts(items), "#S101|Move to|---|Remove from this bar")
end

------------------------------------------------------------
-- 4. hiddenItem
------------------------------------------------------------
do
    local items = Preview.CellMenuItems("essential", 101, { settings = function() end, incoming = false,
        hiddenItem = true, candidates = { g1 = true } })
    eq("hiddenItem：只剩標題與設定", Texts(items), "#S101|Settings")
end

------------------------------------------------------------
-- 5. Wire：右鍵放手
------------------------------------------------------------
do
    Preview.DropCandidates = function() return { g1 = true } end
    local pv = Preview.Create(Frame(), "essential", nil, { bare = true, drop = ns.Sidebar })
    pv:Refresh()
    local c = pv.slots[1]
    check("有格子", c ~= nil)
    -- 提示
    c.scripts.OnEnter(c)
    local hasRight = false
    for _, t in ipairs(tipLines) do if t == "Right-click: more options" then hasRight = true end end
    check("提示有「右鍵：更多」", hasRight)
    local midAt, rightAt
    for i, t in ipairs(tipLines) do
        if t == "Middle-click: remove" then midAt = i end
        if t == "Right-click: more options" then rightAt = i end
    end
    check("「右鍵：更多」排在中鍵那一行後面", midAt and rightAt and rightAt == midAt + 1)
    -- 右鍵按下不開始拖曳
    c.scripts.OnMouseDown(c, "RightButton")
    eq("右鍵按下：不記 press", pv.press, nil)
    -- 右鍵放手：開選單
    shownMenu = nil
    c.scripts.OnMouseUp(c, "RightButton")
    check("右鍵放手：開選單", shownMenu ~= nil)
    eq("選單標題是這一格", shownMenu and shownMenu[1].text, "S101")
    -- 設定 → 開小窗貼這一格
    popover = nil
    shownMenu[2].onClick()
    eq("設定：開小窗", popover and popover[2], 101)
    eq("設定：貼這一格", popover and popover[3], c)
    -- 拖曳中（左鍵按著）放開右鍵：不開
    c.scripts.OnMouseDown(c, "LeftButton")
    pv.press.dragging = true
    shownMenu = nil
    c.scripts.OnMouseUp(c, "RightButton")
    eq("拖曳中：右鍵不開選單", shownMenu, nil)
    check("拖曳中：右鍵不收掉拖曳", pv.press ~= nil and pv.press.dragging)
    pv:EndDrag(false)
    -- 剛拖完 0.2 秒內：不開
    pv.dragEnded = now
    c.scripts.OnMouseUp(c, "RightButton")
    eq("剛拖完：不開", shownMenu, nil)
    now = now + 1
    c.scripts.OnMouseUp(c, "RightButton")
    check("過了寬限：開", shownMenu ~= nil)
    -- suppressClick（溢來的格被拖、跳過彈窗）：那一下不開
    shownMenu = nil
    c.suppressClick = true
    c.scripts.OnMouseUp(c, "RightButton")
    eq("suppressClick：不開", shownMenu, nil)
    -- 「＋」格：右鍵不開
    local plus = pv.plus
    check("有「＋」格", plus ~= nil)
    shownMenu = nil
    plus.scripts.OnMouseUp(plus, "RightButton")
    eq("「＋」格：右鍵不開", shownMenu, nil)
    -- 溢來的格（預覽格上記著 incoming）：選單沒有移到
    c.incoming = "utility"
    c.scripts.OnMouseUp(c, "RightButton")
    eq("溢來的預覽格：不列移到", shownMenu and Texts(shownMenu), "#S101|Settings|---|Remove from this bar")
end

print(("CellMenu_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
