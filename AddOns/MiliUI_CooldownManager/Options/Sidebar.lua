------------------------------------------------------------
-- 設定視窗左欄（寬 150）
--
--   條
--     核心技能／輔助技能／增益圖示／增益長條
--     [自訂群組…]            右鍵：重新命名／刪除
--     ＋ 新增群組            ← 主動作（primary），不參與選取
--   資源條
--   施法條
--   全域
--     主題／設定檔／關於
--
-- 選取用 accent-hover 按鈕 ＋ W.CreateButtonGroup（單位框架單位欄同款）。
-- 小節只靠「留白 ＋ accent 小字標題」分開，不畫隔線。
-- 自訂群組多到放不下時整欄可以用滾輪捲（右緣一條細的位置指示）。
--
-- 左欄也是預覽拖曳的放置目標：把圖示拖到某個自訂群組上＝拉進那一群；拖回它原本的
-- 檢視器上＝清掉 groupOf（見 Options/Preview.lua）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.Sidebar = {}
local Sidebar = ns.Sidebar

local PAD_X    = 8
local TOP_Y    = -12
local BTN_H    = 22
local BTN_GAP  = 2
local HEAD_H   = 18       -- 小節標題那一行
local HEAD_GAP = 10       -- 小節之間的留白
local WHITE    = "Interface\\BUTTONS\\WHITE8X8"

local col, scroll, child, thumb
local btnW
local rows = {}             -- { kind = "head"|"button"|"gap", region, h }
local byId = {}             -- id → 按鈕（池：刪掉的自訂群組按鈕留著重用）
local heads = {}            -- 小節標題（建一次）
local newBtn
local highlight
local current
local dropCandidates, dropHover

------------------------------------------------------------
-- 自訂群組：新增／改名／刪除
------------------------------------------------------------
local kindPopup, namePopup, deleteConfirm, pendingDelete

local function AfterBarsChanged(showKey)
    if ns.Bars and ns.Bars.OnProfileChanged then ns.Bars.OnProfileChanged() end
    ns.Options.SyncBarPages()
    Sidebar.Rebuild()
    if showKey then ns.Options.ShowPage(showKey) end
    ns.Options.ApplyEngine("structure", true)
    ns.Fire("BarsListChanged")
end

local function NamePopup()
    if not namePopup then
        namePopup = W.CreateInputPopup(ns.Options.panel, 320, "",
            { { key = "name", label = L["Name"], maxLetters = 40 } })
    end
    return namePopup
end

local function AskName(title, initial, onAccept)
    NamePopup():Open({ name = initial }, function(values)
        local name = values.name or ""
        if name == "" then return false end
        onAccept(name)
    end, title)
end

-- 真的建：kind = "icons" | "bars"。回傳新條的 key（左欄選到它、頁面切過去）
function Sidebar.CreateGroup(kind, name)
    if InCombatLockdown() then return nil end
    local key = ns.DB.CreateBar(kind, name)
    if key then AfterBarsChanged(key) end
    return key
end

-- 真的刪（確認窗按了確定之後）
function Sidebar.RemoveGroup(k)
    if not k or InCombatLockdown() or ns.DB.IsBuiltinBar(k) then return false end
    -- 錨在它身上的條：先把目前畫面上的位置換算成 pos，刪掉之後才不會跳走
    local p = ns.profile
    for other, bar in pairs(p and p.bars or {}) do
        if other ~= k and type(bar) == "table" and type(bar.anchor) == "table" and bar.anchor.to == k then
            local pos = ns.EditMode and ns.EditMode.ReadPos and ns.EditMode.ReadPos(other)
            if pos then bar.pos = pos end
        end
    end
    if not ns.DB.DeleteBar(k) then return false end
    local showing = ns.Options.CurrentPage() == k
    AfterBarsChanged(showing and "essential" or nil)
    return true
end

function Sidebar.NewGroup()
    if InCombatLockdown() then return end
    if not kindPopup then
        local function Pick(kind)
            return function()
                AskName(L["Name the new group"], "", function(name) Sidebar.CreateGroup(kind, name) end)
            end
        end
        kindPopup = W.CreateChoicePopup(ns.Options.panel, 360,
            L["What kind of group?"],
            {
                { text = L["Icon group"], color = "normal", onClick = Pick("icons") },
                { text = L["Bar group"],  color = "normal", onClick = Pick("bars") },
                { text = L["Cancel"],     color = "normal" },
            })
    end
    kindPopup:Show()
end

function Sidebar.RenameGroup(key)
    local bar = ns.DB.BarTable(key)
    if not bar or ns.DB.IsBuiltinBar(key) then return end
    AskName(L["Rename group"], bar.name or "", function(name)
        bar.name = name
        Sidebar.Rebuild()
        local page = ns.Options.GetPage(key)
        if page and page:IsShown() and page.OnShowPage then page:OnShowPage() end
        local EM = ns.EditMode
        if EM and EM.Editing() and EM.RefreshBar then EM.RefreshBar(key) end
        ns.Fire("BarsListChanged")
    end)
end

function Sidebar.DeleteGroup(key)
    if ns.DB.IsBuiltinBar(key) or not ns.DB.BarTable(key) then return end
    pendingDelete = key
    if not deleteConfirm then
        deleteConfirm = W.CreateConfirmPopup(ns.Options.panel, 340, "", function()
            local k = pendingDelete
            pendingDelete = nil
            Sidebar.RemoveGroup(k)
        end)
    end
    deleteConfirm.text:SetText(L["Delete \"%s\"? Its spells go back to the Blizzard bar they came from."]
        :format(ns.Options.BarTitle(key)))
    deleteConfirm:Show()
end

local function ShowGroupMenu(btn)
    local key = btn.id
    if W.Menu.IsOpenFor(btn) then W.Menu.Hide() return end
    W.Menu.Show({
        { text = ns.Options.BarTitle(key), isTitle = true },
        { text = L["Rename"], onClick = function() Sidebar.RenameGroup(key) end },
        { isSeparator = true },
        { text = L["Delete"], onClick = function() Sidebar.DeleteGroup(key) end },
    }, btn)
end

------------------------------------------------------------
-- 清單內容（照目前設定檔的 barOrder）
------------------------------------------------------------
-- 分三節：法術（核心／輔助）、增益（增益圖示／增益長條）、自訂群組（＋新增群組）；
-- 底下資源條／施法條／戰鬥助手照舊。節內順序照 barOrder（漏列的舊資料排在最後，不然那條就找不到設定頁）
local SECTION_OF = { essential = "spells", utility = "spells", buffs = "buffs", buffbars = "buffs" }

local function Items()
    local p = ns.profile
    local bars = p and p.bars or {}
    local seen, keys = {}, {}
    for _, key in ipairs(p and type(p.barOrder) == "table" and p.barOrder or {}) do
        if type(bars[key]) == "table" and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end
    local extra = {}
    for key, bar in pairs(bars) do
        if type(bar) == "table" and not seen[key] then extra[#extra + 1] = key end
    end
    table.sort(extra)
    for _, key in ipairs(extra) do keys[#keys + 1] = key end

    local out = {}
    local function Section(name)
        out[#out + 1] = { header = name }
        for _, key in ipairs(keys) do
            local builtin = ns.DB.IsBuiltinBar(key)
            if (builtin and SECTION_OF[key] == name) or (not builtin and name == "custom") then
                out[#out + 1] = { id = key, custom = not builtin }
            end
        end
    end
    Section("spells")
    Section("buffs")
    Section("custom")
    out[#out + 1] = { action = "newGroup" }
    out[#out + 1] = { gap = HEAD_GAP }
    out[#out + 1] = { id = "resources" }
    out[#out + 1] = { id = "castbar" }
    out[#out + 1] = { id = "assist" }          -- 戰鬥輔助（下一招醒目標示＋下一招圖示）
    return out
end

local function Label(id)
    return ns.Options.PageTitle(id) or ns.Options.BarTitle(id)
end

local function EnsureButton(id)
    local b = byId[id]
    if not b then
        b = W.CreateButton(child, "", "accent-hover", btnW, BTN_H)
        b.id = id
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        -- 這個專精沒有內容的自訂群組：整顆變暗，滑過說明（群組是設定檔裡所有角色共用的版面位置，
        -- 內容才是按專精存；使用者 2026-10-01 定案：不列範圍、只標暗）
        b:HookScript("OnEnter", function(self)
            if not self.emptyForSpec then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(Label(self.id) or self.id)
            GameTooltip:AddLine(L["Nothing here for this specialization yet. Add spells with \"+\" or drag icons onto it."], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function(self)
            if self.emptyForSpec then GameTooltip:Hide() end
        end)
        byId[id] = b
    end
    b:SetText(Label(id) or id)
    return b
end

-- 自訂群組在目前專精有沒有內容：沒有就整顆變暗。目錄變、專精變、預覽拖了東西都要重算
function Sidebar.RefreshEmpty()
    local C = ns.Catalog
    if not (C and C.Bar) then return end
    for id, b in pairs(byId) do
        local empty = false
        if b.custom and ns.DB.BarTable(id) then
            local ok, list = pcall(C.Bar, id)
            empty = ok and type(list) == "table" and #list == 0
        end
        b.emptyForSpec = empty
        b:SetAlpha(empty and 0.45 or 1)
    end
end

ns.RegisterCallback("CatalogChanged", "sidebar_empty", function() Sidebar.RefreshEmpty() end)
ns.RegisterCallback("SpecChanged", "sidebar_empty", function() Sidebar.RefreshEmpty() end)
ns.RegisterCallback("OptionsShown", "sidebar_empty", function() Sidebar.RefreshEmpty() end)

------------------------------------------------------------
-- 縱向排版
--
-- ⚠ y 是**累加**的：放不下的語系按鈕會換行長高（W.WrapButton），後面的要往下讓。
-- 跑兩次：建完一次、視窗真的顯示之後再一次 —— 沒顯示的框量字高可能是 0，
-- 那種情況 WrapButton 會收手不換行，要等顯示後重量。
------------------------------------------------------------
local function UpdateThumb()
    if not (scroll and thumb) then return end
    local viewH = scroll:GetHeight() or 0
    local contentH = child:GetHeight() or 0
    if viewH <= 0 or contentH <= viewH + 1 then thumb:Hide() return end
    local range = contentH - viewH
    local cur = scroll:GetVerticalScroll() or 0
    local h = math.max(20, viewH * viewH / contentH)
    thumb:SetHeight(h)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", col, "TOPRIGHT", -1, -((viewH - h) * (cur / range)))
    thumb:Show()
end

function Sidebar.Relayout()
    if not col then return end
    local y = TOP_Y
    for i, row in ipairs(rows) do
        if row.kind == "head" then
            if i > 1 then y = y - HEAD_GAP end
            row.region:ClearAllPoints()
            row.region:SetPoint("TOPLEFT", child, "TOPLEFT", PAD_X + 2, y - 2)
            y = y - HEAD_H
        elseif row.kind == "gap" then
            y = y - row.h
        else
            row.region:ClearAllPoints()
            row.region:SetPoint("TOPLEFT", child, "TOPLEFT", PAD_X, y)
            y = y - (W.WrapButton(row.region, btnW, BTN_H) + BTN_GAP)
        end
    end
    child:SetHeight(-y + 10)
    local maxScroll = math.max(0, (child:GetHeight() or 0) - (scroll:GetHeight() or 0))
    if (scroll:GetVerticalScroll() or 0) > maxScroll then scroll:SetVerticalScroll(maxScroll) end
    UpdateThumb()
end

function Sidebar.Rebuild()
    if not col then return end
    for _, b in pairs(byId) do b:Hide() end
    for _, h in pairs(heads) do h:Hide() end
    newBtn:Hide()
    rows = {}
    local group = {}
    for _, item in ipairs(Items()) do
        if item.header then
            local h = heads[item.header]
            h:Show()
            rows[#rows + 1] = { kind = "head", region = h }
        elseif item.gap then
            rows[#rows + 1] = { kind = "gap", h = item.gap }
        elseif item.action == "newGroup" then
            newBtn:Show()
            rows[#rows + 1] = { kind = "button", region = newBtn }
        else
            local b = EnsureButton(item.id)
            b.custom = item.custom and true or false
            b:Show()
            group[#group + 1] = b
            rows[#rows + 1] = { kind = "button", region = b }
        end
    end
    highlight = W.CreateButtonGroup(group, function(id) ns.Options.ShowPage(id) end)
    -- 自訂群組：右鍵開選單（按鈕群組的 OnClick 只認左鍵的語意，包一層）
    for _, b in ipairs(group) do
        local orig = b:GetScript("OnClick")
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if self.custom then ShowGroupMenu(self) end
                return
            end
            orig(self, button)
        end)
    end
    Sidebar.Relayout()
    Sidebar.RefreshEmpty()
    if current then Sidebar.Highlight(current) end
end

function Sidebar.Build(panel, width)
    if col then return col end
    col = CreateFrame("Frame", nil, panel)
    col:SetPoint("TOPLEFT", 0, 0)
    col:SetPoint("BOTTOMLEFT", 0, 0)
    col:SetWidth(width)
    btnW = width - PAD_X * 2

    scroll = CreateFrame("ScrollFrame", nil, col)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, (child:GetHeight() or 0) - (self:GetHeight() or 0))
        local v = math.min(maxScroll, math.max(0, (self:GetVerticalScroll() or 0) - delta * 40))
        self:SetVerticalScroll(v)
        UpdateThumb()
    end)
    scroll:SetScript("OnSizeChanged", UpdateThumb)

    thumb = col:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(W.Accent(0.6))
    thumb:SetWidth(P.Scale(2))
    thumb:Hide()

    heads.spells = W.CreateGroupLabel(child, L["Spells"])
    heads.buffs  = W.CreateGroupLabel(child, L["Buffs"])
    heads.custom = W.CreateGroupLabel(child, L["Custom Groups"])
    newBtn = W.CreateButton(child, L["+ New Group"], "primary", btnW, BTN_H)
    newBtn:SetScript("OnClick", Sidebar.NewGroup)

    -- 左欄與頁面之間的分隔線（1px 黑）
    local sep = col:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(WHITE)
    sep:SetVertexColor(0, 0, 0, 1)
    sep:SetPoint("TOPLEFT", col, "TOPRIGHT", 0, -10)
    sep:SetPoint("BOTTOMLEFT", col, "BOTTOMRIGHT", 0, 10)
    sep:SetWidth(P.Scale(1))

    Sidebar.Rebuild()
    return col
end

-- ⚠ 按鈕群組的高亮掛在按鈕自己的 OnClick 上。從外面切頁（開窗回到上次那頁、
-- 畫面上的點擊層）不經過點擊，要從這裡補，不然左欄會亮著上一頁。
-- 「一般」以外的分頁不顯示左欄
function Sidebar.SetShown(shown)
    if col then col:SetShown(shown and true or false) end
end

function Sidebar.Highlight(id)
    current = id
    local b = byId[id]
    if b and b:IsShown() and highlight then highlight(b) end
end

------------------------------------------------------------
-- 拖曳放置目標（預覽的圖示拖到左欄上）
--   Sidebar.BeginDrop({ [id] = true, … })  可放的按鈕亮職業色邊
--   Sidebar.DropTargetAtCursor()           游標底下那顆可放的 id（沒有回 nil）
--   Sidebar.ButtonAtCursor()               游標底下那顆按鈕的 id（不管能不能放）
--   Sidebar.EndDrop()                      還原
------------------------------------------------------------
function Sidebar.BeginDrop(candidates)
    dropCandidates, dropHover = candidates, nil
    for id, b in pairs(byId) do
        if b:IsShown() and candidates[id] then b:SetBackdropBorderColor(W.Accent(1)) end
    end
end

function Sidebar.DropTargetAtCursor()
    if not dropCandidates then return nil end
    local hit
    if scroll and scroll:IsMouseOver() then
        for id, b in pairs(byId) do
            if dropCandidates[id] and b:IsShown() and b:IsMouseOver() then hit = id break end
        end
    end
    if hit ~= dropHover then
        local old = dropHover and byId[dropHover]
        if old then W.PaintButton(old, false) end
        local new = hit and byId[hit]
        if new then new:SetBackdropColor(W.Accent(0.6)) end
        dropHover = hit
    end
    return hit
end

-- 游標底下的左欄按鈕（不管能不能放）：放不進去的要說為什麼，不能放開就沒反應
function Sidebar.ButtonAtCursor()
    if not (scroll and scroll:IsMouseOver()) then return nil end
    for id, b in pairs(byId) do
        if b:IsShown() and b:IsMouseOver() then return id, b end
    end
end

function Sidebar.EndDrop()
    dropCandidates, dropHover = nil, nil
    for _, b in pairs(byId) do b:SetBackdropBorderColor(0, 0, 0, 1) end
    if current then Sidebar.Highlight(current) end
end

-- 某個 id 的按鈕（除錯／測試用）
function Sidebar.Button(id) return byId[id] end
function Sidebar.ScrollFrame() return scroll end
