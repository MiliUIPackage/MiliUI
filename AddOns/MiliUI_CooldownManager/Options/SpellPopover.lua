------------------------------------------------------------
-- 逐法術面板：預覽裡左鍵點一格開的小視窗
--
--   ns.SpellPopover.Open(key, cooldownID, cell)
--
-- 法術本來就屬於專精，改了就是「這個專精的這個法術」（spells[specID].overrides[id]），
-- 沒有範圍可選。三態：覆寫沒設的欄位顯示條層的值、旁邊灰字「（跟隨條）」；
-- 點了就寫成覆寫（「（已覆寫，右鍵還原）」），右鍵那一列清掉那一格。
-- 「所在條」改的是 groupOf：原本的檢視器（＝清掉）或同類型的任一自訂群組。
--
-- 自訂項目（id "c:<index>"）：
--   * 「所在條」改的是它自己的 bar（任何一條圖示類的條）。
--   * 光環格：觸發／就緒發光、冷卻去飽和這三列藏起來（不知道光環在不在，也沒有冷卻）；
--     多一列「不在時顯示占位」；沒有「隱藏此法術」（固定前綴）。
--   * 「移除」是整筆刪掉（後面的 id 由 DB.RemoveCustom 往前挪）；暴雪清單上的法術的「移除」是記進 hidden。
-- 列是動態排的：每一列是一個自己的框，Layout 依種類決定哪幾列顯示、由上往下疊。
--
-- 音效（Core/Sound.lua）：冷卻類（暴雪核心／輔助、自訂法術／物品）一列「就緒音效」；增益類（暴雪
-- 增益圖示／增益長條、光環格）兩列「出現音效」「消失音效」。每列一個下拉（第一項「無」＝清掉覆寫，
-- 其餘是 LibSharedMedia 的音效名，開選單那一刻才列、依名稱排序；清單長時下拉自己會裁切＋滾輪捲）
-- ＋「試聽」。一個音效都沒有時多一列灰字說明。
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
local CTRL_X  = LABEL_W + 10
local ROW_W   = WIDTH - PAD * 2
local TOP_Y   = -PAD - 32 - 12

local frame, cur
local rows = {}          -- 依顯示順序：{ frame, h, when = function(kind, class) → bool }
local toggles = {}
local sounds = {}        -- { field, dd }

-- 音效欄位與顯示在哪一類（class：「cooldown」冷卻類｜「aura」增益類）
local SOUNDS = {
    { field = "readySound", label = L["Ready sound"], class = "cooldown" },
    { field = "gainSound",  label = L["Gain sound"],  class = "aura" },
    { field = "loseSound",  label = L["Lose sound"],  class = "aura" },
}

local TOGGLES = {
    { field = "procGlow",         label = L["Proc glow"],              noAura = true },
    { field = "readyGlow",        label = L["Ready glow"],             noAura = true },
    { field = "desaturate",       label = L["Desaturate on cooldown"], noAura = true },
    { field = "hideCooldownText", label = L["Hide countdown"] },
    { field = "hideStackText",    label = L["Hide stacks"] },
}

local function Override(field)
    local sp = ns.DB.SpecSpells(false)
    local o = sp and type(sp.overrides) == "table" and cur and sp.overrides[cur.id]
    if type(o) ~= "table" then return nil end
    return o[field]
end

local function Changed(level)
    if not cur then return end
    ns.Preview.Refresh(cur.key)
    if ns.TabBar and ns.TabBar.RefreshForm then ns.TabBar.RefreshForm(cur.key) end
    ns.Options.ApplyEngine(level or "layout")
    Pop.Refresh()
end

local function Note(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetTextColor(0.6, 0.6, 0.6)
    fs:SetJustifyH("LEFT")
    return fs
end

-- 一列：自己的框，左邊標籤（靠右對齊）、右邊控件；高度照標籤換行長
local function NewRow(label, when)
    local r = CreateFrame("Frame", nil, frame)
    local h = ROW_H
    if label then
        local fs = r:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontNormal)
        fs:SetWidth(LABEL_W)
        fs:SetJustifyH("RIGHT")
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(true)
        h = ROW_H + W.TextExtraHeight(fs, label)
        fs:SetHeight(h)
        fs:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        r.label = fs
    end
    r:SetSize(ROW_W, h)
    local row = { frame = r, h = h, when = when }
    -- 視窗第一次顯示前量不到字高（TextExtraHeight 會回 0）：OnShow 時照這支重量一次。
    -- 控件一律錨在列的 LEFT（＝垂直置中），列高變了自己跟著走
    if label then
        row.remeasure = function()
            local nh = ROW_H + W.TextExtraHeight(r.label, label)
            r.label:SetHeight(nh)
            r:SetHeight(nh)
            row.h = nh
        end
    end
    rows[#rows + 1] = row
    return r, h, row
end

-- 右鍵整列清掉那一格覆寫（標籤上蓋一層只吃右鍵語意的框）
local function RightClickClears(r, h, field)
    local hit = CreateFrame("Frame", nil, r)
    hit:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    hit:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)     -- 列高重量之後跟著長
    hit:SetWidth(LABEL_W)
    hit:EnableMouse(true)
    hit:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and cur then
            ns.DB.SetOverride(cur.id, field, nil)
            Changed()
        end
    end)
end

local function IsAura(kind) return kind == "aura" end
-- 只給有冷卻的（核心／輔助技能、自訂法術／物品／裝備欄）：增益類（暴雪的增益兩條、光環格）沒有觸發亮框、
-- 沒有冷卻可轉好或去飽和。看 class 不看 kind —— kind 只有自訂項目才有，暴雪的增益是 nil
local function NotAura(_, class) return class ~= "aura" end
local function IsCustom(kind) return kind ~= nil end

-- 音效下拉：第一項「無」，其餘 LSM 的音效名（已排序）
local function SoundItems()
    local items = { { text = L["None"], value = false } }
    for _, name in ipairs(ns.Media.List("sound")) do
        items[#items + 1] = { text = name, value = name }
    end
    return items
end

local function NoSounds() return #ns.Media.List("sound") == 0 end

local Layout          -- 前置宣告（Build 的 OnShow 要用，定義在下面）

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
    -- 生效發光的即時預覽：畫在圖示上的獨立框（Core/Glow.lua 的 PreviewActive）
    local glowHost = CreateFrame("Frame", nil, frame)
    glowHost:SetAllPoints(icon)
    glowHost:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.glowHost = glowHost
    local name = frame:CreateFontString(nil, "OVERLAY")
    name:SetFontObject(W.fontTitle)
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    name:SetPoint("RIGHT", close, "LEFT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    frame.name = name
    local idText = Note(frame)
    idText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 1)
    idText:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    idText:SetWordWrap(false)
    frame.idText = idText

    -- 所在條
    local r, h = NewRow(L["On bar"])
    local dd = W.CreateDropdown(r, ROW_W - CTRL_X, {}, function(value)
        if not cur then return end
        local id, key = cur.id, cur.key
        frame:Hide()
        ns.Preview.MoveTo(id, value, key)
    end)
    dd:SetMaxWidth(ROW_W - CTRL_X)
    dd:SetPoint("LEFT", r, "LEFT", CTRL_X, 0)
    frame.barDD = dd

    -- 邊框顏色：勾「自訂」才寫覆寫
    local br, bh = NewRow(L["Border color"])
    local custom = W.CreateCheckButton(br, L["Custom"], function(on)
        if not cur then return end
        if on then
            local c = ns.SpellSetting(cur.key, cur.id, "borderColor") or {}
            ns.DB.SetOverride(cur.id, "borderColor", { r = c.r or 0, g = c.g or 0, b = c.b or 0, a = c.a or 1 })
        else
            ns.DB.SetOverride(cur.id, "borderColor", nil)
        end
        Changed()
    end)
    custom:SetPoint("LEFT", br, "LEFT", CTRL_X, 0)
    local swatch = W.CreateColorPicker(br, nil, true, function(rr, g, b, a)
        if not cur or not Override("borderColor") then return end
        ns.DB.SetOverride(cur.id, "borderColor", { r = rr, g = g, b = b, a = a })
        Changed()
    end)
    swatch:SetPoint("LEFT", custom.label, "RIGHT", 10, 0)
    frame.customCB, frame.swatch = custom, swatch
    RightClickClears(br, bh, "borderColor")

    for _, t in ipairs(TOGGLES) do
        local tr, th = NewRow(t.label, t.noAura and NotAura or nil)
        local cb = W.CreateCheckButton(tr, nil, function(on)
            if not cur then return end
            ns.DB.SetOverride(cur.id, t.field, on and true or false)
            Changed()
        end)
        cb:SetPoint("LEFT", tr, "LEFT", CTRL_X, 0)
        local note = Note(tr)
        note:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        note:SetPoint("RIGHT", tr, "RIGHT", 0, 0)
        note:SetWordWrap(false)
        toggles[#toggles + 1] = { field = t.field, cb = cb, note = note }
        RightClickClears(tr, th, t.field)
    end

    -- 生效發光：暴雪的增益與光環格（增益類）。勾選框＋顏色，下一列樣式（沒挑過＝ glow.active 的預設）；
    -- 右鍵整列全清。標題的圖示即時預覽
    local ar, ah = NewRow(L["Glow while active"], function(_, class) return class == "aura" end)
    local acb = W.CreateCheckButton(ar, nil, function(on)
        if not cur then return end
        ns.DB.SetOverride(cur.id, "activeGlow", on and true or nil)
        Changed()
    end)
    acb:SetPoint("LEFT", ar, "LEFT", CTRL_X, 0)
    local aswatch = W.CreateColorPicker(ar, nil, true, function(rr, g, b, a)
        if not cur or not ns.SpellSetting(cur.key, cur.id, "activeGlow") then return end
        ns.DB.SetOverride(cur.id, "activeGlowColor", { r = rr, g = g, b = b, a = a })
        Changed()
    end)
    aswatch:SetPoint("LEFT", acb, "RIGHT", 10, 0)
    frame.activeCB, frame.activeSwatch = acb, aswatch
    -- 脫戰也亮（預設勾）：取消 ＝ 只在戰鬥中亮。只存 false（勾回去就清掉覆寫）。
    -- 自訂光環格不給：發光烘在受保護的按鈕裡，戰鬥中切不了
    local occb = W.CreateCheckButton(ar, L["Out of combat too"], function(on)
        if not cur or not ns.SpellSetting(cur.key, cur.id, "activeGlow") then return end
        ns.DB.SetOverride(cur.id, "activeGlowOutOfCombat", (not on) and false or nil)
        Changed()
    end)
    occb:SetPoint("LEFT", aswatch, "RIGHT", 14, 0)
    frame.activeOOC = occb
    local ahit = CreateFrame("Frame", nil, ar)
    ahit:SetPoint("TOPLEFT", ar, "TOPLEFT", 0, 0)
    ahit:SetPoint("BOTTOMLEFT", ar, "BOTTOMLEFT", 0, 0)
    ahit:SetWidth(LABEL_W)
    ahit:EnableMouse(true)
    ahit:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and cur then
            ns.DB.SetOverride(cur.id, "activeGlow", nil)
            ns.DB.SetOverride(cur.id, "activeGlowColor", nil)
            ns.DB.SetOverride(cur.id, "activeGlowType", nil)
            ns.DB.SetOverride(cur.id, "activeGlowOutOfCombat", nil)
            Changed()
        end
    end)
    local tr2 = NewRow(L["Glow style"], function(_, class) return class == "aura" end)
    local tdd = W.CreateDropdown(tr2, ROW_W - CTRL_X, {
        { text = L["Pixel"],         value = "pixel" },
        { text = L["Autocast"],      value = "autocast" },
        { text = L["Action button"], value = "button" },
        { text = L["Proc"],          value = "proc" },
    }, function(value)
        if not cur or not ns.SpellSetting(cur.key, cur.id, "activeGlow") then return end
        ns.DB.SetOverride(cur.id, "activeGlowType", value)
        Changed()
    end)
    tdd:SetMaxWidth(ROW_W - CTRL_X)
    tdd:SetPoint("LEFT", tr2, "LEFT", CTRL_X, 0)
    frame.activeTypeDD = tdd

    -- 音效：下拉＋試聽（右鍵整列清掉＝無）
    for _, t in ipairs(SOUNDS) do
        local cls = t.class
        local sr, sh = NewRow(t.label, function(_, class) return class == cls end)
        local listen = W.CreateButton(sr, L["Listen"], "normal", 44, 20)
        W.FitButton(listen, 44, 20)
        listen:SetPoint("RIGHT", sr, "RIGHT", 0, 0)
        local ddW = ROW_W - CTRL_X - (listen:GetWidth() or 44) - 6
        local sdd = W.CreateDropdown(sr, ddW, {}, function(value)
            if not cur then return end
            ns.DB.SetOverride(cur.id, t.field, (type(value) == "string" and value ~= "") and value or nil)
            Changed()
        end)
        sdd:SetPoint("LEFT", sr, "LEFT", CTRL_X, 0)
        listen:SetScript("OnClick", function()
            local v = sdd:GetSelected()
            if type(v) == "string" and ns.Sound then ns.Sound.Preview(v) end
        end)
        sounds[#sounds + 1] = { field = t.field, dd = sdd, listen = listen }
        RightClickClears(sr, sh, t.field)
    end
    -- 一個音效都沒有（保底：內建音效沒註冊成功時才會出現）
    local nsRow = CreateFrame("Frame", nil, frame)
    local nsTip = Note(nsRow)
    nsTip:SetPoint("TOPLEFT", nsRow, "TOPLEFT", CTRL_X, -2)
    nsTip:SetWidth(ROW_W - CTRL_X)
    nsTip:SetWordWrap(true)
    nsTip:SetText(L["No sounds available."])
    local nsH = 2 + math.max(14, nsTip:GetStringHeight() or 0) + 6
    nsRow:SetSize(ROW_W, nsH)
    local nsEntry = { frame = nsRow, h = nsH, when = function() return NoSounds() end }
    nsEntry.remeasure = function()
        local sh2 = nsTip:GetStringHeight()
        local nh = 2 + math.max(14, type(sh2) == "number" and sh2 or 0) + 6
        nsRow:SetHeight(nh)
        nsEntry.h = nh
    end
    rows[#rows + 1] = nsEntry

    -- 光環格：不在時顯示占位（存在那一筆自訂項目上，不是覆寫）
    local pr, ph = NewRow(L["Placeholder when missing"], IsAura)
    local pcb = W.CreateCheckButton(pr, nil, function(on)
        if not cur then return end
        local e = ns.DB.CustomEntry(cur.id)
        if not e then return end
        e.placeholder = on and true or false
        Changed("membership")
    end)
    pcb:SetPoint("LEFT", pr, "LEFT", CTRL_X, 0)
    frame.placeholderCB = pcb

    -- 說明
    local tipRow = CreateFrame("Frame", nil, frame)
    local tip = Note(tipRow)
    tip:SetPoint("TOPLEFT", tipRow, "TOPLEFT", 0, -4)
    tip:SetWidth(ROW_W)
    tip:SetWordWrap(true)
    tip:SetText(L["Settings here apply to this spell in your current specialization. Right-click a row to follow the bar again."])
    local tipH = 4 + math.max(14, tip:GetStringHeight()) + 10
    tipRow:SetSize(ROW_W, tipH)
    local tipEntry = { frame = tipRow, h = tipH }
    tipEntry.remeasure = function()
        local sh = tip:GetStringHeight()
        local nh = 4 + math.max(14, type(sh) == "number" and sh or 0) + 10
        tipRow:SetHeight(nh)
        tipEntry.h = nh
    end
    rows[#rows + 1] = tipEntry

    -- 按鈕：移除（從這條拿掉；見 Preview.Remove）／還原設定
    local btnRow = CreateFrame("Frame", nil, frame)
    btnRow:SetSize(ROW_W, 22)
    local remove = W.CreateButton(btnRow, L["Remove from this bar"], "normal", 130, 22)
    W.FitButton(remove, 130, 22)
    remove:SetScript("OnClick", function()
        if not cur then return end
        ns.Preview.Remove(cur.key, cur.id)
    end)
    local restore = W.CreateButton(btnRow, L["Reset this spell"], "normal", 130, 22)
    W.FitButton(restore, 130, 22)
    restore:SetScript("OnClick", function()
        if not cur then return end
        local sp = ns.DB.SpecSpells(false)
        if sp and type(sp.overrides) == "table" then sp.overrides[cur.id] = nil end
        Changed()
    end)
    frame.removeBtn, frame.restoreBtn, frame.btnRow = remove, restore, btnRow
    rows[#rows + 1] = { frame = btnRow, h = 22 + 6, buttons = true }

    -- 顯示之後才量得到字高（換行的語系）：每次顯示重量、照目前種類重排
    frame:HookScript("OnShow", function()
        for _, row in ipairs(rows) do
            if row.remeasure then row.remeasure() end
        end
        if cur then Layout(frame.kind, frame.soundClass) end
    end)

    ns.RegisterCallback("OptionsHidden", "popover", function() frame:Hide() end)
    ns.RegisterCallback("SpecChanged", "popover", function() frame:Hide() end)
    ns.RegisterCallback("ProfileChanged", "popover", function() frame:Hide() end)
end

-- 依種類排列：kind = nil（暴雪的法術）| "aura" | "spell" | "item"；class = "cooldown" | "aura"（音效列）
Layout = function(kind, class)
    frame.kind, frame.soundClass = kind, class
    local y = TOP_Y
    for _, row in ipairs(rows) do
        local show = not row.when or row.when(kind, class)
        row.frame:SetShown(show)
        if show then
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
            if row.buttons then
                local list = { frame.removeBtn, frame.restoreBtn }
                local _, bh = W.FlowLayout(frame.btnRow, list, ROW_W, 6, 4, 22)
                frame.btnRow:SetHeight(bh)
                row.h = bh + 6
            end
            y = y - row.h
        end
    end
    P.Height(frame, -y + PAD)
end

-- 所在條：原本的檢視器 ＋ 同類型的自訂群組；自訂項目是任何一條圖示類的條
local function BarItems(id)
    local items = {}
    local p = ns.profile
    if ns.Catalog.IsCustom(id) then
        for _, k in ipairs(p and p.barOrder or {}) do
            local b = ns.DB.BarTable(k)
            if b and b.kind ~= "bars" then
                items[#items + 1] = { text = ns.Options.PageTitle(k) or ns.Options.BarTitle(k), value = k }
            end
        end
        return items
    end
    local origin = ns.Catalog.SourceOf(id)
    if origin then
        items[#items + 1] = { text = ns.Options.PageTitle(origin) or origin, value = origin }
    end
    local ob = origin and ns.DB.BarTable(origin)
    local wantBars = ob and ob.kind == "bars" or false
    for _, k in ipairs(p and p.barOrder or {}) do
        local b = ns.DB.BarTable(k)
        if b and not ns.DB.IsBuiltinBar(k) and (b.kind == "bars") == wantBars then
            items[#items + 1] = { text = ns.Options.BarTitle(k), value = k }
        end
    end
    return items
end

-- 音效列的類別：光環格與暴雪增益兩條 ⇒ 增益類，其餘冷卻類
local function SoundClass(id, kind)
    if kind == "aura" then return "aura" end
    if kind then return "cooldown" end
    local src = ns.Catalog.SourceOf(id)
    if src and ns.Viewers.AURA_KIND[src] then return "aura" end
    return "cooldown"
end

local KIND_TEXT = {
    spell = function(info) return ("spellID %s  ·  %s"):format(tostring(info.spellID), L["Custom spell"]) end,
    item  = function(info) return ("itemID %s  ·  %s"):format(tostring(info.itemID), L["Custom item"]) end,
    slot  = function(info) return ("%s  ·  %s"):format(tostring(info.slotName or info.slot), L["Equipment slot"]) end,
    aura  = function(info)
        return ("spellID %s  ·  %s"):format(tostring(info.spellID),
            info.filter == "HARMFUL" and L["Aura slot (debuff)"] or L["Aura slot (buff)"])
    end,
}

function Pop.Refresh()
    if not (frame and cur) then return end
    local key, id = cur.key, cur.id
    local info = ns.Catalog.Info(id)
    local kind = info and info.custom and info.kind or nil
    frame.icon:SetTexture((info and info.icon) or 134400)
    local name = (info and info.name) or ("#" .. tostring(id))
    if info and info.isKnown == false and kind then name = name .. "  |cffff5555" .. L["Not learned"] .. "|r" end
    frame.name:SetText(name)
    if kind then
        frame.idText:SetText(KIND_TEXT[kind](info))
    else
        frame.idText:SetText(("cooldownID %s  ·  spellID %s"):format(tostring(id),
            tostring(info and (info.overrideSpellID or info.spellID) or "?")))
    end
    local class = SoundClass(id, kind)
    Layout(kind, class)

    frame.barDD:SetItems(BarItems(id))
    if kind then
        frame.barDD:SetSelectedValue(info.bar)
    else
        local sp = ns.DB.SpecSpells(false)
        local g = sp and type(sp.groupOf) == "table" and sp.groupOf[id]
        frame.barDD:SetSelectedValue((g and ns.DB.BarTable(g)) and g or ns.Catalog.SourceOf(id))
    end

    local own = Override("borderColor")
    frame.customCB:SetChecked(own ~= nil)
    frame.swatch:SetColor(ns.SpellSetting(key, id, "borderColor") or { r = 0, g = 0, b = 0, a = 1 })
    frame.swatch:SetEnabled(own ~= nil)
    frame.swatch:SetAlpha(own ~= nil and 1 or 0.4)

    for _, r in ipairs(toggles) do
        r.cb:SetChecked(ns.SpellSetting(key, id, r.field) and true or false)
        -- 沒覆寫時講清楚值從哪來：條在這一節跟隨主題就是「跟隨主題」，條用自己的值就是「跟隨這一條」，
        -- 兩個都沒有（隱藏倒數／層數）就是預設
        if Override(r.field) ~= nil then
            r.note:SetText(L["(overridden, right-click to reset)"])
        else
            local src = ns.DB.SpellFallbackSource(key, r.field)
            r.note:SetText(src == "theme" and L["(follows the theme)"]
                or src == "bar" and L["(follows this bar)"] or L["(default)"])
        end
    end
    local activeOn = ns.SpellSetting(key, id, "activeGlow") and true or false
    frame.activeCB:SetChecked(activeOn)
    local ac = ns.SpellSetting(key, id, "activeGlowColor")
    if type(ac) ~= "table" then ac = ns.Setting(key, "glow.active.color") end
    frame.activeSwatch:SetColor(type(ac) == "table" and ac or { r = 0.95, g = 0.95, b = 0.32, a = 1 })
    frame.activeSwatch:SetEnabled(activeOn)
    frame.activeSwatch:SetAlpha(activeOn and 1 or 0.4)
    local at = ns.SpellSetting(key, id, "activeGlowType")
    if type(at) ~= "string" then at = ns.Setting(key, "glow.active.type") end
    frame.activeTypeDD:SetSelectedValue(type(at) == "string" and at or "pixel")
    frame.activeTypeDD:SetEnabled(activeOn)
    frame.activeOOC:SetShown(kind ~= "aura")
    frame.activeOOC:SetChecked(ns.SpellSetting(key, id, "activeGlowOutOfCombat") ~= false)
    frame.activeOOC:SetEnabled(activeOn)
    frame.activeOOC:SetAlpha(activeOn and 1 or 0.4)
    frame.activeTypeDD:SetAlpha(activeOn and 1 or 0.4)
    if ns.Glow and ns.Glow.PreviewActive then
        ns.Glow.PreviewActive(frame.glowHost, key, class == "aura" and id or nil)
    end
    local items = SoundItems()
    for _, r in ipairs(sounds) do
        r.dd:SetItems(items)
        local v = Override(r.field)
        v = (type(v) == "string" and v ~= "") and v or false
        r.dd:SetSelectedValue(v)
        r.listen:SetEnabled(v ~= false)
    end
    if kind == "aura" then
        local e = ns.DB.CustomEntry(id)
        frame.placeholderCB:SetChecked(e and e.placeholder and true or false)
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

-- 面板本體（還沒開過是 nil；離線測試讀按鈕的顯示狀態用）
function Pop.Frame() return frame end

function Pop.IsShown()
    return frame and frame:IsShown() or false
end
