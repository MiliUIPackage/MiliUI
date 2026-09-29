------------------------------------------------------------
-- 逐法術面板：預覽裡左鍵點一格開的小視窗
--
--   ns.SpellPopover.Open(key, cooldownID, cell)
--
-- 法術本來就屬於專精，改了就是「這個專精的這個法術」（spells[specID].overrides[id]），
-- 沒有範圍可選。三態：覆寫沒設的欄位顯示條層的值、旁邊灰字「（跟隨條）」；
-- 點了就寫成覆寫（「（已覆寫，右鍵還原）」），右鍵那一列清掉那一格。
-- 「所在條」改的是 groupOf：原本的檢視器（＝清掉）或同類型的任一自訂群組。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.SpellPopover = {}
local Pop = ns.SpellPopover

local WIDTH   = 320
local PAD     = 12
local LABEL_W = 130
local ROW_H   = 26
local CTRL_X  = PAD + LABEL_W + 10

local frame, cur
local rows = {}

local TOGGLES = {
    { field = "procGlow",         label = L["Proc glow"] },
    { field = "readyGlow",        label = L["Ready glow"] },
    { field = "desaturate",       label = L["Desaturate on cooldown"] },
    { field = "hideCooldownText", label = L["Hide countdown"] },
    { field = "hideStackText",    label = L["Hide stacks"] },
}

local function Override(field)
    local sp = ns.DB.SpecSpells(false)
    local o = sp and type(sp.overrides) == "table" and cur and sp.overrides[cur.id]
    if type(o) ~= "table" then return nil end
    return o[field]
end

local function Changed()
    if not cur then return end
    ns.Preview.Refresh(cur.key)
    if ns.TabBar and ns.TabBar.RefreshForm then ns.TabBar.RefreshForm(cur.key) end
    ns.Options.ApplyEngine("layout")
    Pop.Refresh()
end

local function Label(text, y)
    local fs = frame:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetWidth(LABEL_W)
    fs:SetJustifyH("RIGHT")
    fs:SetWordWrap(true)
    fs:SetNonSpaceWrap(true)
    local h = ROW_H + W.TextExtraHeight(fs, text)
    fs:SetHeight(h)
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    return fs, h
end

local function Note()
    local fs = frame:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetTextColor(0.6, 0.6, 0.6)
    fs:SetJustifyH("LEFT")
    return fs
end

-- 右鍵整列清掉那一格覆寫（列上蓋一層只吃右鍵語意的框）
local function RightClickClears(y, h, field)
    local hit = CreateFrame("Frame", nil, frame)
    hit:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    hit:SetSize(LABEL_W, h)
    hit:EnableMouse(true)
    hit:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and cur then
            ns.DB.SetOverride(cur.id, field, nil)
            Changed()
        end
    end)
end

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

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", PAD, -PAD)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon
    local name = frame:CreateFontString(nil, "OVERLAY")
    name:SetFontObject(W.fontTitle)
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    name:SetPoint("RIGHT", close, "LEFT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    frame.name = name
    local idText = Note()
    idText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 1)
    frame.idText = idText

    local y = -PAD - 32 - 12

    -- 所在條
    local _, h = Label(L["On bar"], y)
    local dd = W.CreateDropdown(frame, WIDTH - CTRL_X - PAD, {}, function(value)
        if not cur then return end
        local id, key = cur.id, cur.key
        frame:Hide()
        ns.Preview.MoveTo(id, value, key)
    end)
    dd:SetMaxWidth(WIDTH - CTRL_X - PAD)
    dd:SetPoint("LEFT", frame, "TOPLEFT", CTRL_X, y - h / 2)
    frame.barDD = dd
    y = y - h

    -- 邊框顏色：勾「自訂」才寫覆寫
    local _, bh = Label(L["Border color"], y)
    local custom = W.CreateCheckButton(frame, L["Custom"], function(on)
        if not cur then return end
        if on then
            local c = ns.SpellSetting(cur.key, cur.id, "borderColor") or {}
            ns.DB.SetOverride(cur.id, "borderColor", { r = c.r or 0, g = c.g or 0, b = c.b or 0, a = c.a or 1 })
        else
            ns.DB.SetOverride(cur.id, "borderColor", nil)
        end
        Changed()
    end)
    custom:SetPoint("LEFT", frame, "TOPLEFT", CTRL_X, y - bh / 2)
    local swatch = W.CreateColorPicker(frame, nil, true, function(r, g, b, a)
        if not cur or not Override("borderColor") then return end
        ns.DB.SetOverride(cur.id, "borderColor", { r = r, g = g, b = b, a = a })
        Changed()
    end)
    swatch:SetPoint("LEFT", custom.label, "RIGHT", 10, 0)
    frame.customCB, frame.swatch = custom, swatch
    RightClickClears(y, bh, "borderColor")
    y = y - bh

    for _, t in ipairs(TOGGLES) do
        local _, th = Label(t.label, y)
        local cb = W.CreateCheckButton(frame, nil, function(on)
            if not cur then return end
            ns.DB.SetOverride(cur.id, t.field, on and true or false)
            Changed()
        end)
        cb:SetPoint("LEFT", frame, "TOPLEFT", CTRL_X, y - th / 2)
        local note = Note()
        note:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        note:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
        note:SetWordWrap(false)
        rows[#rows + 1] = { field = t.field, cb = cb, note = note }
        RightClickClears(y, th, t.field)
        y = y - th
    end

    local tip = Note()
    tip:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y - 4)
    tip:SetWidth(WIDTH - PAD * 2)
    tip:SetWordWrap(true)
    tip:SetText(L["Settings here apply to this spell in your current specialization. Right-click a row to follow the bar again."])
    y = y - 4 - math.max(14, tip:GetStringHeight()) - 10

    local hide = W.CreateButton(frame, L["Hide this spell"], "normal", 130, 22)
    W.FitButton(hide, 130, 22)
    hide:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    hide:SetScript("OnClick", function()
        if not cur then return end
        local key, id = cur.key, cur.id
        frame:Hide()
        ns.Preview.SetHidden(key, id, true)
    end)
    local restore = W.CreateButton(frame, L["Reset this spell"], "normal", 130, 22)
    W.FitButton(restore, 130, 22)
    restore:SetPoint("LEFT", hide, "RIGHT", 6, 0)
    restore:SetScript("OnClick", function()
        if not cur then return end
        local sp = ns.DB.SpecSpells(false)
        if sp and type(sp.overrides) == "table" then sp.overrides[cur.id] = nil end
        Changed()
    end)
    frame.restoreBtn = restore
    y = y - 22 - PAD
    P.Height(frame, -y)

    ns.RegisterCallback("OptionsHidden", "popover", function() frame:Hide() end)
    ns.RegisterCallback("SpecChanged", "popover", function() frame:Hide() end)
    ns.RegisterCallback("ProfileChanged", "popover", function() frame:Hide() end)
end

-- 所在條：原本的檢視器 ＋ 同類型的自訂群組
local function BarItems(id)
    local origin = ns.Catalog.SourceOf(id)
    local items = {}
    if origin then
        items[#items + 1] = { text = ns.Options.PageTitle(origin) or origin, value = origin }
    end
    local ob = origin and ns.DB.BarTable(origin)
    local wantBars = ob and ob.kind == "bars" or false
    local p = ns.profile
    for _, k in ipairs(p and p.barOrder or {}) do
        local b = ns.DB.BarTable(k)
        if b and not ns.DB.IsBuiltinBar(k) and (b.kind == "bars") == wantBars then
            items[#items + 1] = { text = ns.Options.BarTitle(k), value = k }
        end
    end
    return items
end

function Pop.Refresh()
    if not (frame and cur) then return end
    local key, id = cur.key, cur.id
    local info = ns.Catalog.Info(id)
    frame.icon:SetTexture((info and info.icon) or 134400)
    frame.name:SetText((info and info.name) or ("#" .. tostring(id)))
    frame.idText:SetText(("cooldownID %s  ·  spellID %s"):format(tostring(id),
        tostring(info and (info.overrideSpellID or info.spellID) or "?")))

    frame.barDD:SetItems(BarItems(id))
    local sp = ns.DB.SpecSpells(false)
    local g = sp and type(sp.groupOf) == "table" and sp.groupOf[id]
    frame.barDD:SetSelectedValue((g and ns.DB.BarTable(g)) and g or ns.Catalog.SourceOf(id))

    local own = Override("borderColor")
    frame.customCB:SetChecked(own ~= nil)
    frame.swatch:SetColor(ns.SpellSetting(key, id, "borderColor") or { r = 0, g = 0, b = 0, a = 1 })
    frame.swatch:SetEnabled(own ~= nil)
    frame.swatch:SetAlpha(own ~= nil and 1 or 0.4)

    for _, r in ipairs(rows) do
        r.cb:SetChecked(ns.SpellSetting(key, id, r.field) and true or false)
        if Override(r.field) ~= nil then
            r.note:SetText(L["(overridden, right-click to reset)"])
        else
            r.note:SetText(L["(follows the bar)"])
        end
    end
    local sp2 = ns.DB.SpecSpells(false)
    local hasAny = sp2 and type(sp2.overrides) == "table" and sp2.overrides[id] ~= nil
    frame.restoreBtn:SetEnabled(hasAny and true or false)
end

function Pop.Open(key, id, cell)
    if id == nil then return end
    Build()
    if ns.Picker and ns.Picker.IsShown() then ns.Picker.Close() end
    cur = { key = key, id = id }
    Pop.Refresh()
    frame:Show()
    local pts = { "TOPLEFT", cell, "TOPRIGHT", 6, 0 }
    local right, sw = cell:GetRight(), UIParent:GetRight()
    if right and sw and right + WIDTH + 10 > sw then
        pts = { "TOPRIGHT", cell, "TOPLEFT", -6, 0 }
    end
    W.PlaceClamped(frame, pts)
end

function Pop.Close()
    if frame then frame:Hide() end
end

function Pop.IsShown()
    return frame and frame:IsShown() or false
end
