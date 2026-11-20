------------------------------------------------------------
-- 設定視窗開著時，畫面上每條容器蓋一層透明的點擊層：點了就切到那條的設定頁，
-- 並讓點擊層閃一下職業色邊（0.3 秒）；**拖了就移動那條**（走編輯模式同一套 EM.BeginDrag／EndDrag，
-- 條與條對齊、套組磁吸都在（格線看不到所以不吸格線），Shift 按著不吸）。覆蓋層（條名、職業色邊）此時也由 EditMode 顯示。
--
-- 細到「格」（2026-11-21）：
--   * 滑鼠在點擊層上時，游標底下那一格（Bars.Cells 記的上一輪放格：暴雪 item、自訂框、代畫格、暗圖示占位、溢來的格）
--     描一圈 1px 職業色框，提示第一行換成那一格的名字＋「點一下：設定這一格」「右鍵：更多」，拖曳／方向鍵說明照留。
--     游標不在任何一格上 ⇒ 提示跟以前一字不差。
--   * 左鍵點在格上 ⇒ 切到那條的頁，接著開那一格的逐法術小窗、貼在畫面上那一格旁邊；點在格外 ⇒ 照舊只切頁。
--     小窗錨的是另一個不會動的定位框（pin），不是職業色框：職業色框會跟著游標換格，錨在它身上小窗會跟著跑。
--   * 右鍵 ⇒ 選單（CL.ShowMenu；畫面編輯的條名籤右鍵也是這一支）：在格上時先一段「這一格」（設定／從這條移除），
--     再一段「這條」（開啟設定／加入法術／錨定）；面板沒有格，只有「這條」那段、也沒有加入法術。
--   * 命中測試是純函式 Layout.HitCell；游標換算成容器座標前，容器的 GetLeft／GetTop 先過 ns.IsSecret
--     （錨在外部單位框上的條，秘密錨點沿錨定鏈傳染）：秘密或 nil ⇒ 當作沒有命中，退回條層行為。
--   * 追蹤只在滑鼠在點擊層上時跑（OnEnter 掛 OnUpdate、OnLeave 拿掉），0.05 秒一次。
--
-- 規則
--   * 自己的框（parent UIParent，錨在容器上），不是容器的子框，也不寫容器任何東西。
--   * 只在「設定視窗開著、不在編輯模式、不在戰鬥」時顯示：編輯模式有自己的覆蓋層與
--     選取框，點擊層蓋上去會擋掉拖曳；戰鬥中設定視窗本來就鎖著。
--   * 畫面編輯（Options/LiveEdit.lua）正在畫假格的條不蓋：假格自己收滑鼠。面板照蓋。
--   * 大小至少一格（空條的容器可能只有 1×1），跟編輯模式的覆蓋層同一個算法。
--   * 顯示／收起走 ns.Write：容器之後可能被光環格的保護連坐，錨在它身上的框也一樣。
--   * 1px 邊（點擊層、格框）一律 P.Pixel、顯示時換算、跟上次不同才重套、backdrop 關貼齊（wow-1px-border-rules）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.ClickLayer = {}
local CL = ns.ClickLayer

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local TRACK_EVERY = 0.05
local layers = {}
CL.layers = layers          -- 除錯／測試用
local hooked = {}

local function PanelShown()
    local panel = ns.Options and ns.Options.panel
    return panel and panel:IsShown() or false
end

local function Wanted()
    return PanelShown() and not (ns.EditMode and ns.EditMode.active) and not InCombatLockdown()
end

local function SetBorder(l, a)
    l:SetBackdropBorderColor(W.Accent(a))
end

-- 1px 邊：顯示前換算、跟上次不同才重套（登入後才定的縮放、改過 UI 縮放）
local function Edge(f, a)
    local px = P.Pixel(1)
    if f.edgePx == px then return end
    f.edgePx = px
    f:SetBackdrop({ edgeFile = WHITE, edgeSize = px })
    if ns.NoSnapBackdrop then ns.NoSnapBackdrop(f) end
    f:SetBackdropBorderColor(W.Accent(a))
end

local function Layout(key)
    local l, c = layers[key], ns.Bars and ns.Bars.Get(key)
    local bar = ns.DB.ConfigTable(key)
    if not (l and c and bar) then return end
    local w, h = 36, 36
    if ns.EditMode and ns.EditMode.MinSize then w, h = ns.EditMode.MinSize(key, bar) end
    -- 錨定鏈接到外部框時尺寸可能讀回秘密值：讀不到就當 1（照最小尺寸；同 EM.LayoutOverlay）
    local cw, ch = c:GetWidth(), c:GetHeight()
    if type(cw) ~= "number" or ns.IsSecret(cw) then cw = 1 end
    if type(ch) ~= "number" or ns.IsSecret(ch) then ch = 1 end
    if cw > w then w = cw end
    if ch > h then h = ch end
    local ap = ns.Bars.AnchorPoint(key)
    l:ClearAllPoints()
    l:SetPoint(ap, c, ap, 0, 0)
    l:SetSize(w, h)
    Edge(l, l.flashUntil and 1 or 0)
end

local function Flash(l)
    SetBorder(l, 1)
    l.flashUntil = GetTime() + 0.3
    C_Timer.After(0.3, function()
        if l.flashUntil and GetTime() >= l.flashUntil - 0.01 then
            l.flashUntil = nil
            SetBorder(l, l:IsMouseOver() and 0.5 or 0)
        end
    end)
end

------------------------------------------------------------
-- 格：命中測試、名字、職業色框
------------------------------------------------------------
-- 游標底下是這條的哪一格（Bars.Cells 的那一筆，就地重用的表：要留著用就複製值）；沒有回 nil
function CL.CellAtCursor(key)
    local B = ns.Bars
    local c = B and B.Get(key)
    local cells = c and B.Cells and B.Cells(key)
    if not (cells and (cells.n or 0) > 0) then return nil end
    local l, t, s = c:GetLeft(), c:GetTop(), c:GetEffectiveScale()
    -- 秘密錨點沿錨定鏈傳染：讀回來的幾何是秘密值就不算（連跟 nil 比都會炸，IsSecret 排第一）
    if ns.IsSecret(l) or ns.IsSecret(t) or ns.IsSecret(s) then return nil end
    if type(l) ~= "number" or type(t) ~= "number" or type(s) ~= "number" or s <= 0 then return nil end
    local cx, cy = GetCursorPosition()
    return ns.Layout.HitCell(cells, cx / s - l, t - cy / s)
end

function CL.CellName(id)
    local info = id ~= nil and ns.Catalog.Info(id)
    return (info and info.name) or ("#" .. tostring(id))
end

-- 格框／定位框貼到某一格（座標相對容器左上、y 往下為正，同放格那句 SetPoint）
local function PlaceOn(f, c, x, y, w, h)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
    f:SetSize(w, h)
end

-- 點擊層的提示。cell ＝ 游標底下那一格（nil ＝ 跟以前一字不差）
local function ShowTip(l, key, cell)
    GameTooltip:SetOwner(l, "ANCHOR_TOP")
    if cell then
        GameTooltip:SetText(CL.CellName(cell.id))
        GameTooltip:AddLine(L["Click: settings for this icon"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Right-click: more options"], 0.8, 0.8, 0.8)
    else
        GameTooltip:SetText(ns.Options.PageTitle(key) or ns.Options.BarTitle(key))
        GameTooltip:AddLine(L["Click to open this bar's settings."], 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(L["Drag to move. Hold Shift to disable snapping."], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Hover a bar and press the arrow keys to nudge it by 1 (Shift: 10)."], 0.8, 0.8, 0.8)
    GameTooltip:Show()
    -- 錨在別條／外部框上的條：最下面接一行黃字「拖曳會解除跟隨」（覆蓋層條名後的「!」記號講的就是這個）
    if ns.EditMode and ns.EditMode.AppendHint then ns.EditMode.AppendHint(l, key) end
end

-- 游標底下的格變了才重畫職業色框與提示（id 與 rect 都比：換專精後同一個 id 可能換了位置）
local function Track(l, key, force)
    local cell = CL.CellAtCursor(key)
    local hv = l.hover
    if cell then
        if not force and hv.id == cell.id and hv.x == cell.x and hv.y == cell.y and hv.w == cell.w and hv.h == cell.h then return end
        hv.id, hv.x, hv.y, hv.w, hv.h = cell.id, cell.x, cell.y, cell.w, cell.h
        local c = ns.Bars.Get(key)
        Edge(l.box, 1)
        PlaceOn(l.box, c, cell.x, cell.y, cell.w, cell.h)
        l.box:Show()
    else
        if not force and hv.id == nil then return end
        hv.id = nil
        l.box:Hide()
    end
    if l:IsMouseOver() and not (W.Menu and W.Menu.IsOpenFor and W.Menu.IsOpenFor(nil)) then ShowTip(l, key, cell) end
end

local function StopTrack(l)
    l:SetScript("OnUpdate", nil)
    l.hover.id = nil
    l.box:Hide()
end

------------------------------------------------------------
-- 動作（點擊層與畫面編輯的條名籤共用）
------------------------------------------------------------
-- 開一格的逐法術小窗、貼在畫面上那一格旁邊。snap ＝ 那一格的值（id, x, y, w, h，複製出來的，不是 Bars.Cells 的表）
local function OpenCell(l, key, snap)
    local c = ns.Bars and ns.Bars.Get(key)
    if not (c and ns.SpellPopover) then return end
    ns.Options.ShowPage(key)
    PlaceOn(l.pin, c, snap.x, snap.y, snap.w, snap.h)
    ns.SpellPopover.Open(key, snap.id, l.pin)
end

local function Snap(cell)
    if not cell then return nil end
    return { id = cell.id, x = cell.x, y = cell.y, w = cell.w, h = cell.h }
end

-- 右鍵選單（miliui-menu-design：標題比選項弱、破壞性動作有分隔線而且不放第一個、分隔線後面不直接接標題）
--   key     哪一條（面板也行）
--   cell    游標底下那一格（Bars.Cells 的那一筆或 nil）；有的話先一段「這一格」
--   anchor  「加入法術」的挑選器貼在哪個框旁邊（點擊層自己；畫面編輯傳條名籤）
function CL.ShowMenu(key, cell, anchor)
    if not (W.Menu and W.Menu.Show) then return end
    GameTooltip:Hide()
    local snap = Snap(cell)
    local B = ns.Bars
    local isPanel = B and B.IsPanel and B.IsPanel(key) or false
    -- 畫面編輯中：視窗收合著，「加入法術」不切頁（切頁會把視窗展開）
    local live = ns.LiveEdit and ns.LiveEdit.Active and ns.LiveEdit.Active() or false
    local items = {}
    if snap then
        local l = layers[key]
        items[#items + 1] = { text = CL.CellName(snap.id), isTitle = true }
        if l then
            items[#items + 1] = { text = L["Settings for this icon"], onClick = function() OpenCell(l, key, snap) end }
        end
        items[#items + 1] = { isSeparator = true }
        -- 判準跟預覽的中鍵、小窗的「移除」鈕同一支：暴雪清單上的記 hidden、自訂項目整筆刪（寬層先問）
        items[#items + 1] = { text = L["Remove from this bar"], onClick = function() ns.Preview.Remove(key, snap.id) end }
    end
    items[#items + 1] = { text = ns.Options.PageTitle(key) or ns.Options.BarTitle(key), isTitle = true }
    items[#items + 1] = { text = L["Open this bar's settings"], onClick = function() ns.Options.ShowPage(key) end }
    if not isPanel and ns.Picker and anchor then
        items[#items + 1] = { text = L["Add spells to this bar"], onClick = function()
            if not live then ns.Options.ShowPage(key) end
            ns.Picker.Open(key, anchor)
        end }
    end
    -- 錨定：入口跟每頁「錨定」摘要列的「設定」鈕同一支；跟著游標的條那一列是停用的，這裡就不列
    local follows = ns.Cursor and ns.Cursor.Configured and ns.Cursor.Configured(key) or false
    if ns.AnchorWindow and not follows and ns.DB.ConfigTable(key) then
        items[#items + 1] = { text = L["Anchoring"], onClick = function() ns.AnchorWindow.Open(key) end }
    end
    W.Menu.Show(items)
end

------------------------------------------------------------
-- 點擊層
------------------------------------------------------------
local function Ensure(key)
    local l = layers[key]
    if l then return l end
    l = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    l:SetFrameStrata("HIGH")
    l:EnableMouse(true)
    l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    l:RegisterForDrag("LeftButton")
    l:SetScript("OnDragStart", function(self)
        StopTrack(self)
        if ns.EditMode and ns.EditMode.BeginDrag then ns.EditMode.BeginDrag(key) end
    end)
    l:SetScript("OnDragStop", function()
        if ns.EditMode and ns.EditMode.EndDrag then ns.EditMode.EndDrag(true) end
    end)
    Edge(l, 0)
    l:Hide()
    l.hover = {}

    -- 游標底下那一格的 1px 職業色框（不吃滑鼠：滑鼠一律是點擊層的）
    local box = CreateFrame("Frame", nil, l, "BackdropTemplate")
    box:SetFrameLevel(l:GetFrameLevel() + 5)
    box:EnableMouse(false)
    box:Hide()
    l.box = box
    -- 逐法術小窗的定位框：點下去那一刻貼到那一格，之後不跟著游標動（見檔頭）
    local pin = CreateFrame("Frame", nil, l)
    pin:EnableMouse(false)
    pin:SetSize(1, 1)
    l.pin = pin

    l:SetScript("OnEnter", function(self)
        if not self.flashUntil then SetBorder(self, 0.5) end
        local acc = 0
        self:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            if acc < TRACK_EVERY then return end
            acc = 0
            Track(self, key)
        end)
        Track(self, key, true)
    end)
    l:SetScript("OnLeave", function(self)
        if not self.flashUntil then SetBorder(self, 0) end
        StopTrack(self)
        GameTooltip:Hide()
    end)
    l:SetScript("OnClick", function(self, button)
        local cell = CL.CellAtCursor(key)
        if button == "RightButton" then
            CL.ShowMenu(key, cell, self)
            return
        end
        local snap = Snap(cell)
        if snap then
            OpenCell(self, key, snap)
        else
            ns.Options.ShowPage(key)
        end
        Flash(self)
    end)
    l:SetScript("OnHide", StopTrack)
    layers[key] = l
    local c = ns.Bars and ns.Bars.Get(key)
    if c and not hooked[c] then
        hooked[c] = true
        -- 自己的容器：掛它的 OnSizeChanged 沒有污染問題
        c:HookScript("OnSizeChanged", function()
            local layer = layers[key]
            if layer and layer:IsShown() then Layout(key) end
        end)
    end
    return l
end

function CL.Refresh()
    local want = Wanted()
    local p = ns.profile
    local bars = {}
    for key in pairs(p and p.bars or {}) do bars[key] = true end
    -- 面板（資源條、自訂格子、施法條）也蓋一層；關掉的面板容器是藏著的，不蓋。
    -- 自訂格子沒有自己一頁：點了開資源條頁（Options.ShowPage 照 HostPage 轉）
    -- 接力中的天空騎術不蓋（跟著資源條，點資源條那一層）
    -- 閒置的面板（Bars.Dormant）同理不蓋
    -- 坐騎特效按鈕（mountspecial）不蓋：它是真的要按的控件，蓋了就按不到、滑過效果也會被點擊層搶走（玩家 2026-10-16 回報
    -- 「滑過閃一下、不是每次都有」就是在設定視窗開著時測的）。要移動它走編輯模式或它那一頁的錨定設定
    local dormant = ns.Bars and ns.Bars.Dormant
    for _, key in ipairs(ns.DB.PANEL_ORDER) do
        local cfg = ns.DB.ConfigTable(key)
        if key ~= "mountspecial" and cfg and cfg.enabled ~= false and not (dormant and dormant(key)) then bars[key] = true end
    end
    -- 獨立擺放的資源列（"res:<key>"，第一次用到才登記的面板）：現在拆出來的才蓋，點了開資源條頁（HostPage）
    for key in pairs(ns.Bars and ns.Bars.Panels and ns.Bars.Panels() or {}) do
        if ns.DB.DetachedResource(key) and ns.DB.ConfigTable(key) and not (dormant and dormant(key)) then bars[key] = true end
    end
    -- 畫面編輯正在畫假格的條：讓位給假格（面板沒有假格，照蓋）
    local LE = ns.LiveEdit
    for key in pairs(bars) do
        if LE and LE.Wants and LE.Wants(key) then bars[key] = nil end
    end
    for key in pairs(bars) do
        if want and ns.Bars and ns.Bars.Get(key) then
            local l = Ensure(key)
            ns.Write(l, function(f)
                Layout(key)
                f:Show()
            end, "clicklayer")
        end
    end
    for key, l in pairs(layers) do
        if not (want and bars[key]) then
            ns.Write(l, function(f) f:Hide() end, "clicklayer")
        end
    end
end

-- 設定視窗的開關、編輯模式進出、條增減、換設定檔、資源列拆出收回：下一幀對一次
local armed = false
local function Later()
    if armed then return end
    armed = true
    ns.Defer(function()
        armed = false
        CL.Refresh()
    end)
end
CL.Later = Later

ns.RegisterCallback("OptionsShown", "clicklayer", Later)
ns.RegisterCallback("OptionsHidden", "clicklayer", function() CL.Refresh() end)
ns.RegisterCallback("EditModeChanged", "clicklayer", Later)
ns.RegisterCallback("BarsListChanged", "clicklayer", Later)
ns.RegisterCallback("ProfileChanged", "clicklayer", Later)
ns.RegisterCallback("BarMoved", "clicklayer", Later)
-- 資源列拆出／收回（Modules/Resources.lua 的 SyncDetached）：面板出現或閒置
ns.RegisterCallback("DetachedChanged", "clicklayer", Later)
-- 換專精：觸發牌堆的列只有增強薩不閒置（Modules/ProcDeckRows.lua 的 Idle）
ns.RegisterCallback("SpecChanged", "clicklayer", Later)
-- 設定視窗收合／展開（畫面編輯）：有假格的條讓位或收回
ns.RegisterCallback("OptionsCompactChanged", "clicklayer", Later)

-- 進戰鬥那一刻（鎖定還沒生效）當場收掉；脫戰再照狀態對一次
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for _, l in pairs(layers) do l:Hide() end
    else
        Later()
    end
end)
