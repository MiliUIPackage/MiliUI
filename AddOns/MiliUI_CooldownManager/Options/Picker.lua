------------------------------------------------------------
-- 預覽最右邊「＋」的挑選器：這條還能加什麼
--
--   ns.Picker.Open(key, anchorFrame)
--
-- 三區：
--   已在暴雪冷卻管理器  別條（含自訂群組）現在顯示中的法術，點一下拉進這條（groupOf）。
--                      這條是四條檢視器之一時，只列別條的（自己那條本來就在）。
--                      長條只收長條、圖示只收圖示（暴雪的長條 item 跟圖示 item 是兩種框）。
--   要先去暴雪面板加    已經學會、但還沒放進暴雪冷卻管理器任何一條的（Catalog.Pool），
--                      那要在暴雪自己的面板裡拖進去 —— 附一顆開面板的按鈕。
--   自訂 ID            光環格／自訂法術／物品在下一版加入，這裡先放一行字。
-- 暴雪面板開著時（Catalog.IsPaused）清單不準：整個挑選器鎖住並說明，面板關掉自動重讀。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.Picker = {}
local Picker = ns.Picker

local WIDTH    = 380
local ICON     = 28
local GAP      = 4
local PAD      = 12
local QUESTION = 134400

local frame, curKey
local sections = {}
local pools = { move = {}, pool = {} }

local function BarCfg(key) return ns.DB.BarTable(key) end

local function IsBarsKind(key)
    local b = BarCfg(key)
    return b and b.kind == "bars" or false
end

-- 已在暴雪冷卻管理器、可以拉進 key 的：{ { id, from } … }
function Picker.MovableInto(key)
    local out, seen = {}, {}
    local mine, hid = ns.Catalog.Bar(key, true)
    for _, id in ipairs(mine) do seen[id] = true end
    for _, id in ipairs(hid or {}) do seen[id] = true end
    local wantBars = IsBarsKind(key)
    local p = ns.profile
    for _, other in ipairs(p and p.barOrder or {}) do
        if other ~= key and BarCfg(other) then
            for _, id in ipairs(ns.Catalog.Bar(other)) do
                local origin = ns.Catalog.SourceOf(id)
                if not seen[id] and origin and IsBarsKind(origin) == wantBars then
                    seen[id] = true
                    out[#out + 1] = { id = id, from = other }
                end
            end
        end
    end
    return out
end

-- 要先去暴雪面板加的：這條對應的候選池
function Picker.PoolFor(key)
    local bar = BarCfg(key)
    if not bar then return {} end
    local homes
    if ns.Catalog.BAR_CATEGORY_NAME[bar.source] then
        homes = { bar.source }
    elseif bar.kind == "bars" then
        homes = { "buffbars" }
    else
        homes = { "essential", "utility", "buffs" }
    end
    local out = {}
    for _, h in ipairs(homes) do
        for _, id in ipairs(ns.Catalog.Pool(h)) do out[#out + 1] = id end
    end
    return out
end

------------------------------------------------------------
-- 圖示格
------------------------------------------------------------
local function IconButton(parent, pool, i)
    local b = pool[i]
    if b then return b end
    b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    P.Size(b, ICON, ICON)
    W.Stylize(b, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 1, -1)
    b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(W.Accent(1))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local info = ns.Catalog.Info(self.id)
        GameTooltip:SetText((info and info.name) or ("#" .. tostring(self.id)))
        if self.tip then GameTooltip:AddLine(self.tip, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip:Hide()
    end)
    pool[i] = b
    return b
end

-- 一排排的圖示，回傳高度
local function LayoutIcons(parent, pool, ids, y, onClick, tipFn, desat)
    for _, b in ipairs(pool) do b:Hide() end
    local perRow = math.floor((WIDTH - PAD * 2 + GAP) / (ICON + GAP))
    for i, entry in ipairs(ids) do
        local id = type(entry) == "table" and entry.id or entry
        local b = IconButton(parent, pool, i)
        local info = ns.Catalog.Info(id)
        b.id = id
        b.tex:SetTexture((info and info.icon) or QUESTION)
        b.tex:SetDesaturated(desat and true or false)
        b.tip = tipFn and tipFn(entry) or nil
        b:SetScript("OnClick", onClick and function() onClick(entry) end or nil)
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + col * (ICON + GAP), y - row * (ICON + GAP))
        b:Show()
    end
    if #ids == 0 then return 0 end
    local rows = math.ceil(#ids / perRow)
    return rows * ICON + (rows - 1) * GAP
end

local function Text(parent, small)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(small and W.fontSmall or W.fontNormal)
    fs:SetJustifyH("LEFT")
    fs:SetWidth(WIDTH - PAD * 2)
    fs:SetWordWrap(true)
    if small then fs:SetTextColor(0.65, 0.65, 0.65) end
    return fs
end

local function Place(region, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local function Build()
    if frame then return end
    frame = W.CreateFrame(nil, ns.Options.panel, WIDTH, 200)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(300)
    frame:SetBackdropBorderColor(W.Accent(1))
    frame:Hide()
    W.CloseOnEscape(frame)

    local close = W.CreateButton(frame, "", "red", 18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(10, 10)
    x:SetPoint("CENTER")
    close:SetScript("OnClick", function() frame:Hide() end)

    sections.title = frame:CreateFontString(nil, "OVERLAY")
    sections.title:SetFontObject(W.fontTitle)
    sections.title:SetPoint("TOPLEFT", PAD, -10)
    sections.title:SetPoint("RIGHT", close, "LEFT", -6, 0)
    sections.title:SetJustifyH("LEFT")
    sections.title:SetWordWrap(false)

    sections.moveHead = W.CreateGroupLabel(frame, L["Already in Blizzard's Cooldown Manager"])
    sections.moveNote = Text(frame, true)
    sections.moveNote:SetText(L["Click one to move it onto this bar."])
    sections.moveEmpty = Text(frame, true)
    sections.moveEmpty:SetText(L["Nothing else to move here."])

    sections.poolHead = W.CreateGroupLabel(frame, L["Add these in Blizzard's panel first"])
    sections.poolNote = Text(frame, true)
    sections.poolNote:SetText(L["You know these, but they aren't on any Blizzard Cooldown Manager bar yet. Drag them in there, then they show up above."])
    sections.poolEmpty = Text(frame, true)
    sections.poolEmpty:SetText(L["Nothing left to add."])
    sections.openBtn = W.CreateButton(frame, L["Open Blizzard Cooldown Manager"], "normal", 200, 22)
    W.FitButton(sections.openBtn, 200, 22)
    sections.openBtn:SetScript("OnClick", function()
        frame:Hide()
        if ns.TabBar and ns.TabBar.OpenBlizzard then ns.TabBar.OpenBlizzard() end
    end)

    sections.customHead = W.CreateGroupLabel(frame, L["Custom ID"])
    sections.customNote = Text(frame, true)
    sections.customNote:SetText(L["Tracking auras, spells or items by ID comes in the next version."])

    -- 暴雪面板開著：整片鎖住並講原因
    local mask = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mask:SetPoint("TOPLEFT", 1, -32)
    mask:SetPoint("BOTTOMRIGHT", -1, 1)
    mask:SetFrameLevel(frame:GetFrameLevel() + 20)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
    mask:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
    local mt = mask:CreateFontString(nil, "OVERLAY")
    mt:SetFontObject(W.fontNormal)
    mt:SetPoint("LEFT", 16, 0)
    mt:SetPoint("RIGHT", -16, 0)
    mt:SetJustifyH("CENTER")
    mt:SetText(L["Blizzard's Cooldown Manager settings are open. Close them and this list reloads by itself."])
    mask:Hide()
    sections.mask = mask

    ns.RegisterCallback("CatalogResumed", "picker", function()
        if frame:IsShown() then Picker.Refresh() end
    end)
    ns.RegisterCallback("CatalogChanged", "picker", function()
        if frame:IsShown() then Picker.Refresh() end
    end)
    ns.RegisterCallback("OptionsHidden", "picker", function() frame:Hide() end)
end

function Picker.Refresh()
    if not (frame and curKey) then return end
    local key = curKey
    sections.title:SetText(L["Add to \"%s\""]:format(ns.Options.PageTitle(key) or ns.Options.BarTitle(key)))
    local y = -38

    Place(sections.moveHead, y); y = y - 16
    Place(sections.moveNote, y); y = y - (sections.moveNote:GetStringHeight() + 6)
    local movable = Picker.MovableInto(key)
    local h = LayoutIcons(frame, pools.move, movable, y, function(entry)
        ns.Preview.MoveTo(entry.id, key, entry.from)
        Picker.Refresh()
    end, function(entry)
        return L["Now on: %s"]:format(ns.Options.PageTitle(entry.from) or ns.Options.BarTitle(entry.from))
    end)
    sections.moveEmpty:SetShown(h == 0)
    if h == 0 then
        Place(sections.moveEmpty, y); h = sections.moveEmpty:GetStringHeight()
    end
    y = y - h - 14

    Place(sections.poolHead, y); y = y - 16
    Place(sections.poolNote, y); y = y - (sections.poolNote:GetStringHeight() + 6)
    local pool = Picker.PoolFor(key)
    h = LayoutIcons(frame, pools.pool, pool, y, nil, function()
        return L["Add it in Blizzard's Cooldown Manager panel first."]
    end, true)
    sections.poolEmpty:SetShown(h == 0)
    if h == 0 then
        Place(sections.poolEmpty, y); h = sections.poolEmpty:GetStringHeight()
    end
    y = y - h - 8
    Place(sections.openBtn, y); y = y - 22 - 14

    Place(sections.customHead, y); y = y - 16
    Place(sections.customNote, y); y = y - (sections.customNote:GetStringHeight() + 12)

    P.Height(frame, -y)
    sections.mask:SetShown(ns.Catalog.IsPaused())
end

function Picker.Open(key, anchor)
    Build()
    if ns.SpellPopover and ns.SpellPopover.IsShown() then ns.SpellPopover.Close() end
    curKey = key
    Picker.Refresh()
    frame:Show()
    -- 往右開；右邊放不下改往左開，再不行交給 PlaceClamped 平移
    local pts = { "TOPLEFT", anchor, "TOPRIGHT", 6, 0 }
    local right = anchor:GetRight()
    local sw = UIParent:GetRight()
    if right and sw and right + WIDTH + 10 > sw then
        pts = { "TOPRIGHT", anchor, "TOPLEFT", -6, 0 }
    end
    W.PlaceClamped(frame, pts)
end

function Picker.IsShown()
    return frame and frame:IsShown() or false
end

function Picker.Close()
    if frame then frame:Hide() end
end
