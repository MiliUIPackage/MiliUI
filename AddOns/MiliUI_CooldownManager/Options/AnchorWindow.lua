------------------------------------------------------------
-- 錨定視窗：每條／每個面板「錨定」那一列的「設定」鈕開的小視窗（2026-10-12）
--
--   ns.AnchorWindow.Open(key)     開（已經開著就換成這一條）
--   ns.AnchorWindow.Close() ／ Refresh() ／ IsOpen() ／ Current()
--
-- 所有會錨定的東西都走這一支：四條內建檢視器、自訂圖示／長條群組、資源條、自訂格子（pips）、施法條、
-- 下一招圖示、天空騎術獨立擺放——表單上的入口都是 Specs.Anchor 的摘要列。
--
-- 內容（由上到下，全部 spec，Specs.BuildForm 建）：
--   跟著哪條走     Specs.AnchorTargetSpec（候選＋寫入規則只有那一份）
--   框架名稱       選了「指定框架名稱」才有（Specs.FrameNameRow）
--   目前接到       單位框解析得到時一行灰字「目前接到：家名（框名）」（Anchor.Provider）；解析不到時黃字
--   錨點           雙九宮格：主格＝目標的點（anchor.relPoint）、次格＝這條的點（anchor.point）。
--                  次格用**遊戲裡同一句** sub:SetPoint(point, main, relPoint, 0, 0) 擺在主格上，
--                  所以次格的位置就是真實結果的縮影（TOP→BOTTOM 在正下方外面、CENTER→CENTER 疊在正中央）。
--                  holder 固定 132×132（主格 64 置中，次格最遠外凸 34），列高不隨選擇變
--   偏移           anchor.x／y
--   兩行灰字       同邊排開；只有上下、左右相對的組合排開（Core/Layout.lua 的 AnchorSide 判法，不改）
--
-- 讀寫一律 spec root "bar@<key>"（Specs.MakeCtx 的 TargetOf）；殼（Options/SettingsWindow.lua）的 configKey 省略＝
-- 每一列自己的 key。表單照形狀快取：key、有沒有錨定、目標種類、解析得到不得到、整張錨定圖（候選清單過期就重建）。
-- 值一改：Options.ApplyEngine("structure")＋ns.Fire("AnchorChanged", key)（各頁的摘要列重讀）。
-- 編輯模式拖了脫離錨定（BarMoved）、外部目標的解析結果變了、條被刪了：開著就重讀（形狀變了殼自己換表單）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.AnchorWindow = {}
local AW = ns.AnchorWindow

local WIDTH = 460         -- 控件欄要放得下 230 寬的下拉（歐語標籤欄 148）：4 + 148 + 12 + 230 + 10 ＋ 殼的內距與捲軸 48
local MAX_H = 600

-- 雙九宮格（畫法照 Specs 的 PointGridTS：深底直角、選中塗職業色、滑過變亮）
local MAIN_CELL, SUB_CELL, GRID_GAP = 20, 10, 2
local MAIN_SIDE = MAIN_CELL * 3 + GRID_GAP * 2        -- 64
local SUB_SIDE  = SUB_CELL * 3 + GRID_GAP * 2         -- 34
local HOLDER    = MAIN_SIDE + SUB_SIDE * 2            -- 132：次格往任何方向外凸到底都還在裡面
local MAIN_IDLE, MAIN_HOVER = { 0.28, 0.28, 0.28, 1 }, { 0.45, 0.45, 0.45, 1 }
local SUB_IDLE, SUB_HOVER   = { 0.40, 0.40, 0.40, 1 }, { 0.58, 0.58, 0.58, 1 }
local SUB_BG    = { 0.08, 0.08, 0.08, 1 }             -- 次格的格縫：疊在主格上時不透出底下的格子
local SUB_EDGE  = { 0.75, 0.75, 0.75, 1 }             -- 次格外面一圈 1px 淺灰邊
local BLACK     = { 0, 0, 0, 1 }
local LEGEND_SW = 9
local NOTE_GRAY = 0.65

local function Cfg(key) return ns.DB.ConfigTable(key) end
local function AnchorOf(key)
    local b = Cfg(key)
    return b and type(b.anchor) == "table" and b.anchor or nil
end

------------------------------------------------------------
-- 「目前接到：家名（框名）」（單位框解析得到時）
------------------------------------------------------------
local function ProviderText(key)
    local A = ns.Anchor
    local a = AnchorOf(key)
    if not (A and a) then return "" end
    local _, name = A.Resolve(a.to)
    if not name then return "" end
    local prov = A.Provider(a.to)
    if prov == "Blizzard" then prov = L["Blizzard"] end
    return L["Connected to: %s (%s)"]:format(prov or "?", name)
end

local function ProviderRow(key)
    return { type = "custom", noReset = true, h = 22, build = function(parent, x, y, width)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(NOTE_GRAY, NOTE_GRAY, NOTE_GRAY)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(ProviderText(key))
        return math.max(22, (fs:GetStringHeight() or 14) + 10), function() fs:SetText(ProviderText(key)) end
    end }
end

------------------------------------------------------------
-- 雙九宮格
------------------------------------------------------------
local function Swatch(parent, bg, edge)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(LEGEND_SW, LEGEND_SW)
    W.Stylize(f, bg, edge)
    return f
end

local function SmallText(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetTextColor(NOTE_GRAY, NOTE_GRAY, NOTE_GRAY)
    fs:SetJustifyH("LEFT")
    return fs
end

-- 一組 3×3 格子（Button），照 POINT_ITEMS 的順序（左上→右下）
local function Cells(parent, cell, inset, idle)
    local cells = {}
    for i, it in ipairs(ns.Specs.POINT_ITEMS) do
        local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(cell, cell)
        b:SetPoint("TOPLEFT", inset + ((i - 1) % 3) * (cell + GRID_GAP), -inset - math.floor((i - 1) / 3) * (cell + GRID_GAP))
        W.Stylize(b, idle, BLACK)
        b.point = it.value
        cells[i] = b
    end
    return cells
end

local function GridRow(key, root, gate)
    local Sp = ns.Specs
    local DP, DR = Sp.ANCHOR_DEFAULT_POINT, Sp.ANCHOR_DEFAULT_REL
    local spec = { type = "custom", label = L["Anchor"], root = root, path = "anchor.point", key = "anchor.point",
                   level = "structure", resettable = true, resetPaths = { "anchor.point", "anchor.relPoint" },
                   -- 預設表沒有錨定的（自訂群組…）重設成新錨定的預設：這條的上緣貼目標的下緣
                   fallbacks = { ["anchor.point"] = DP, ["anchor.relPoint"] = DR },
                   disabled = gate }
    -- 點格子時寫的那一個欄位（ctx.set 照 root／path 寫進 "bar@<key>"）
    local pointSpec = { root = root, path = "anchor.point", key = "anchor.point", level = "structure" }
    local relSpec   = { root = root, path = "anchor.relPoint", key = "anchor.relPoint", level = "structure" }
    spec.build = function(parent, x, y, width, ctx)
        local top = y - 4
        -- 圖例：■ 目標的點　■ 這條的點（次格會跑，標題沒辦法跟著它走，改成同色小方塊對照）。
        -- 一列放不下（長譯文）就把第二組換到下一列
        local sw1 = Swatch(parent, MAIN_IDLE, BLACK)
        sw1:SetPoint("TOPLEFT", parent, "TOPLEFT", x, top - 3)
        local t1 = SmallText(parent)
        t1:SetText(L["Its point"])
        t1:SetPoint("LEFT", sw1, "RIGHT", 4, 0)
        local sw2 = Swatch(parent, SUB_IDLE, SUB_EDGE)
        local t2 = SmallText(parent)
        t2:SetText(L["This bar's point"])
        t2:SetPoint("LEFT", sw2, "RIGHT", 4, 0)
        local w1 = LEGEND_SW + 4 + math.ceil(t1:GetStringWidth() or 0)
        local w2 = LEGEND_SW + 4 + math.ceil(t2:GetStringWidth() or 0)
        local legendH = 15
        if w1 + 16 + w2 <= width then
            sw2:SetPoint("LEFT", sw1, "LEFT", w1 + 16, 0)
        else
            sw2:SetPoint("TOPLEFT", sw1, "BOTTOMLEFT", 0, -6)
            legendH = 30
        end

        local holder = CreateFrame("Frame", nil, parent)
        holder:SetSize(HOLDER, HOLDER)
        holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, top - legendH - 6)
        local main = CreateFrame("Frame", nil, holder)
        main:SetSize(MAIN_SIDE, MAIN_SIDE)
        main:SetPoint("CENTER")
        local mainCells = Cells(main, MAIN_CELL, 0, MAIN_IDLE)

        -- 次格：層級比主格高、底色亮一階、外面一圈淺灰邊（疊在主格上時看得出邊界）
        local sub = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        sub:SetSize(SUB_SIDE, SUB_SIDE)
        sub:SetFrameLevel(main:GetFrameLevel() + 10)
        W.Stylize(sub, SUB_BG, SUB_BG)
        local subCells = Cells(sub, SUB_CELL, 0, SUB_IDLE)
        local edge = CreateFrame("Frame", nil, sub, "BackdropTemplate")
        edge:SetPoint("TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", 1, -1)
        edge:SetFrameLevel(sub:GetFrameLevel() + 5)
        edge:SetBackdrop({ edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = ns.P and ns.P.Scale and ns.P.Scale(1) or 1 })
        edge:SetBackdropBorderColor(unpack(SUB_EDGE))

        -- 結果一行：「這條的上緣中點 貼在 核心技能 的下緣中點」
        local result = SmallText(parent)
        result:SetWordWrap(true)
        result:SetWidth(width)
        result:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -6)
        local names = Sp.ANCHOR_POINT_TEXT
        -- 列高要固定（表單形狀不變）：拿最長的點名＋這張表單的目標名量最壞的情況
        local longest, lw = "", -1
        for _, t in pairs(names) do
            result:SetText(t)
            local w = result:GetStringWidth() or 0
            if w > lw then longest, lw = t, w end
        end
        local function ResultText(point, rel)
            local a = AnchorOf(key)
            return L["This bar's %s sits on %s, at its %s."]:format(names[point] or point,
                Sp.AnchorTargetLabel(a and a.to), names[rel] or rel)
        end
        do
            local a = AnchorOf(key)
            result:SetText(L["This bar's %s sits on %s, at its %s."]:format(longest, Sp.AnchorTargetLabel(a and a.to), longest))
        end
        local resultH = math.max(14, result:GetStringHeight() or 14)

        local point, rel = DP, DR
        local function Paint()
            for _, b in ipairs(mainCells) do
                if b.point == rel then b:SetBackdropColor(W.Accent(1))
                else b:SetBackdropColor(unpack(b.hover and MAIN_HOVER or MAIN_IDLE)) end
            end
            for _, b in ipairs(subCells) do
                if b.point == point then b:SetBackdropColor(W.Accent(1))
                else b:SetBackdropColor(unpack(b.hover and SUB_HOVER or SUB_IDLE)) end
            end
            result:SetText(ResultText(point, rel))
        end
        -- 遊戲裡貼條的同一句：次格的 point 貼在主格的 relPoint
        local function Place()
            sub:ClearAllPoints()
            sub:SetPoint(point, main, rel, 0, 0)
        end
        local function Write(which, v)
            if not AnchorOf(key) then return end
            ctx.set(which, v)
            ctx.apply()
        end
        for _, b in ipairs(mainCells) do
            b:SetScript("OnEnter", function() b.hover = true; Paint() end)
            b:SetScript("OnLeave", function() b.hover = false; Paint() end)
            b:SetScript("OnClick", function()
                if rel == b.point then return end
                rel = b.point
                Write(relSpec, rel)
                Place()
                Paint()
            end)
        end
        for _, b in ipairs(subCells) do
            b:SetScript("OnEnter", function() b.hover = true; Paint() end)
            b:SetScript("OnLeave", function() b.hover = false; Paint() end)
            b:SetScript("OnClick", function()
                if point == b.point then return end
                point = b.point
                Write(pointSpec, point)
                Place()
                Paint()
            end)
        end

        -- 次格的外框最遠凸出 holder 1px（淺灰邊在次格外面）：多留 2
        local h = 4 + legendH + 6 + HOLDER + 2 + 6 + resultH + 8
        return h, function()
            local a = AnchorOf(key)
            point = a and a.point or DP
            rel = a and a.relPoint or DR
            Place()
            Paint()
        end
    end
    return spec
end

------------------------------------------------------------
-- 表單
------------------------------------------------------------
local function Note(label) return { type = "text", label = label } end

local function Controls(key)
    local Sp = ns.Specs
    local root = "bar@" .. key
    local gate = Sp.AnchorCursorGate(key)
    local a = AnchorOf(key)
    local kind = a and ns.Anchor and ns.Anchor.Parse(a.to) or nil
    local list = { Sp.AnchorTargetSpec(key, root, gate) }
    if kind == "frame" then list[#list + 1] = Sp.FrameNameRow(key, gate) end
    if Sp.ExternalUnresolved(key) then
        list[#list + 1] = Sp.EmphasisNote(L["Not found, using its own position for now."])
    elseif kind == "unit" then
        list[#list + 1] = ProviderRow(key)
    end
    if a then
        list[#list + 1] = GridRow(key, root, gate)
        list[#list + 1] = { type = "numbers", root = root, label = L["Offset"], sub = "anchor", path = false,
            level = "structure", resetPaths = { "anchor.x", "anchor.y" }, fallback = 0, disabled = gate,
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }
    end
    list[#list + 1] = Note(L["Elements that follow the same side of the same bar stack outward instead of overlapping."])
    list[#list + 1] = Note(L["Only edge-to-opposite-edge pairs (top/bottom, left/right) stack; other pairs are placed exactly as chosen."])
    return list
end

-- 表單的形狀：有列會出現或消失的東西
local function Signature(key)
    local a = AnchorOf(key)
    local kind = a and ns.Anchor and ns.Anchor.Parse(a.to) or nil
    return table.concat({
        tostring(key),
        a and "a" or "-",
        kind or "-",
        ns.Specs.ExternalUnresolved(key) and "!" or "-",
        ns.Specs.AnchorGraphSig(),
    }, "|")
end

local function Title(key)
    return L["Anchoring: %s"]:format(ns.Specs.AnchorTargetLabel(key))
end

local win
win = ns.SettingsWindow.New({
    id        = "anchorwindow",
    width     = WIDTH,
    maxH      = MAX_H,
    controls  = Controls,
    signature = Signature,
    onApply   = function()
        Options.ApplyEngine("structure")
        -- 各頁的摘要列重讀；延一幀，不在按鈕的處理器裡換表單
        local key = win:Current()
        ns.Defer(function() if ns.Fire then ns.Fire("AnchorChanged", key) end end)
    end,
    hideOn    = { "OptionsHidden", "SpecChanged", "ProfileChanged" },
})

function AW.Open(key)
    if type(key) ~= "string" or not Cfg(key) then return end
    win:Open(key, Title(key))
end

function AW.Close()
    win:Close()
end

function AW.IsOpen()
    return win:IsOpen()
end

function AW.Current()
    return win:IsOpen() and win:Current() or nil
end

function AW.Refresh()
    if not win:IsOpen() then return end
    local key = win:Current()
    if not Cfg(key) then win:Close() return end      -- 群組被刪了
    win:SetHeader(Title(key))                        -- 群組改名
    win:Refresh()
end

-- 編輯模式拖了就脫離錨定、外部目標的解析結果變了、條增刪改名：開著就重讀（延一幀，不在別人的處理器裡換表單）
local function Later() ns.Defer(AW.Refresh) end
ns.RegisterCallback("BarMoved", "anchorwindow", Later)
ns.RegisterCallback("AnchorTargetsChanged", "anchorwindow", Later)
ns.RegisterCallback("BarsListChanged", "anchorwindow", Later)
