------------------------------------------------------------
-- 虛空化身計時／崩陷之星計數的門檻規則編輯器（靈魂碎片設定視窗「虛空化身」那一節的按鈕開的彈窗，
-- Options/ResourceSettings.lua）。版面照 Options/HealthThresholds.lua。
--
--   ns.MetaRules.Open(which, changedCallback)   which ＝ "time"｜"stars"
--   ns.MetaRules.Close()
--   ns.MetaRules.Count(which)
--
-- 一列一條規則：比較（ns.ResCond.CMP_LIST，下拉顯示符號）＋數值（計時是秒、星是顆）＋三個可缺的覆寫
-- （顏色：勾了才換；字級：空白＝不改；音效：跟逐法術音效同一個下拉來源）＋上下移＋刪除。
-- 由上而下、第一條成立的生效（跟資源條的條件規則同一個語意），最多 6 條。
-- 存進 resources.metaTime.rules／metaStars.rules；每次寫入前整張過 R.CleanMetaRules（丟壞資料、截 6 條），
-- 清空了就整個拿掉（nil ＝ 沒有規則）。引擎在 Modules/DevourerMeta.lua。
--
-- 為什麼開成獨立視窗：規則數是可增減的，而設定視窗的表單是照形狀建一次就快取重用的。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.MetaRules = {}
local MR = ns.MetaRules

local POPUP_W, POPUP_H = 720, 380
local LIST_W, LIST_H   = 688, 230
local ROW_H            = 28
local ARROW_TEX        = "Interface\\ChatFrame\\ChatFrameExpandArrow"

local popup, list, addBtn, hint, onChanged
local cur = "time"             -- 現在編輯哪一段

-- 新規則的預設：計時 ≥ 60 秒紅、星 ≥ 5 顆金（一出現就看得到效果）
local NEW_RULE = {
    time  = { cmp = ">=", value = 60, color = { r = 1, g = 0.25, b = 0.25, a = 1 } },
    stars = { cmp = ">=", value = 5,  color = { r = 1, g = 0.82, b = 0, a = 1 } },
}
local DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }

-- 比較符號照資源條條件規則的下拉（Options/ResourceConditions.lua）直接印 >=、~= 這些 ASCII：
-- 西文介面的字型不一定有 ≥ ≠（同 L["At least %d%%"] 的理由）
local CMP_ITEMS = {}
for _, op in ipairs(ns.ResCond.CMP_LIST) do CMP_ITEMS[#CMP_ITEMS + 1] = { text = op, value = op } end

local function DM() return ns.DevourerMeta end
local function Cfg() return ns.DB.ConfigTable("resources") end

local function Own(create)
    local cfg = Cfg()
    if not cfg then return nil end
    local f = DM().FIELD[cur]
    if type(cfg[f]) ~= "table" then
        if not create then return nil end
        cfg[f] = {}
    end
    return cfg[f]
end

local function Rules()
    local own = Own(false)
    return own and type(own.rules) == "table" and own.rules or {}
end

-- 寫回：整張過清理；空了拿掉
local function Commit(rules)
    local own = Own(true)
    if not own then return end
    local clean = ns.Resources.CleanMetaRules(rules)
    own.rules = (#clean > 0) and clean or nil
    if ns.Resources and ns.Resources.Apply then ns.Resources.Apply() end
    if onChanged then onChanged() end
end

local Refresh   -- 前向宣告

-- 原地改一條（handler 一律讀 row.index：列會回收再用）
local function Edit(row, fn)
    local rules = Rules()
    local r = row.index and rules[row.index]
    if type(r) ~= "table" then return end
    fn(r)
    Commit(rules)
    Refresh()
end

local function SmallLabel(row, text)
    local fs = row:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetText(text)
    return fs
end

local function ArrowButton(row, up)
    local b = W.CreateButton(row, "", "normal", 20, 18)
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetTexture(ARROW_TEX)
    t:SetRotation(math.rad(up and 90 or -90))
    t:SetSize(12, 12)
    t:SetPoint("CENTER")
    t:SetDesaturated(true)
    b.arrow = t
    return b
end

local function SetArrowEnabled(b, on)
    b:SetEnabled(on)
    b.arrow:SetAlpha(on and 1 or 0.3)
end

local function Move(row, delta)
    local rules = Rules()
    local i = row.index
    local j = i and i + delta
    if not (i and rules[i] and rules[j]) then return end
    rules[i], rules[j] = rules[j], rules[i]
    Commit(rules)
    Refresh()
end

------------------------------------------------------------
-- 一列
------------------------------------------------------------
local function BuildRow(row)
    row.when = SmallLabel(row, L["When value"])
    row.when:SetPoint("LEFT", 8, 0)

    row.cmp = W.CreateDropdown(row, 48, CMP_ITEMS, function(v)
        Edit(row, function(r) r.cmp = v end)
    end)
    row.cmp:SetPoint("LEFT", row.when, "RIGHT", 6, 0)

    row.value = W.CreateNumberBox(row, 46, 1, function(v)
        Edit(row, function(r)
            v = math.floor(v + 0.5)
            local mx = DM().VALUE_MAX[cur] or 600
            if v < 0 then v = 0 elseif v > mx then v = mx end
            r.value = v
        end)
    end)
    row.value:SetPoint("LEFT", row.cmp, "RIGHT", 4, 0)

    row.unit = row:CreateFontString(nil, "OVERLAY")
    row.unit:SetFontObject(W.fontSmall)
    row.unit:SetTextColor(0.65, 0.65, 0.65)
    row.unit:SetPoint("LEFT", row.value, "RIGHT", 4, 0)

    -- 顏色：勾了才換（沒勾 ＝ 照這一段的顏色）
    row.colorOn = W.CreateCheckButton(row, nil, function(on)
        Edit(row, function(r)
            if on then
                local base = DM().Get(Cfg(), cur, "color") or DEFAULT_COLOR
                r.color = { r = base.r, g = base.g, b = base.b, a = tonumber(base.a) or 1 }
            else
                r.color = nil
            end
        end)
    end)
    row.colorOn:SetPoint("LEFT", row.unit, "RIGHT", 12, 0)
    row.colorLabel = SmallLabel(row, L["Color"])
    row.colorLabel:SetPoint("LEFT", row.colorOn, "RIGHT", 4, 0)
    row.swatch = W.CreateColorPicker(row, nil, true, function(r_, g, b, a)
        Edit(row, function(r) r.color = { r = r_, g = g, b = b, a = a or 1 } end)
    end)
    row.swatch:SetPoint("LEFT", row.colorLabel, "RIGHT", 6, 0)

    -- 字級：空白 ＝ 不改（照這一段的字級）
    row.sizeLabel = SmallLabel(row, L["Font size"])
    row.sizeLabel:SetPoint("LEFT", row.swatch, "RIGHT", 12, 0)
    row.size = W.CreateEditBox(row, 36, 18)
    row.size:SetJustifyH("CENTER")
    row.size:SetFontObject(W.fontSmall)
    row.size:SetPoint("LEFT", row.sizeLabel, "RIGHT", 6, 0)
    local function CommitSize(self)
        local txt = strtrim(self:GetText() or "")
        local n = tonumber(txt)
        Edit(row, function(r) r.size = n end)     -- 清理時夾在 6～40；不是數字 ＝ 拿掉
    end
    row.size:SetScript("OnEnterPressed", function(self) CommitSize(self); self:ClearFocus() end)
    row.size:HookScript("OnEditFocusLost", function(self)
        local rules = Rules()
        local r = row.index and rules[row.index]
        local want = r and r.size and tostring(r.size) or ""
        if strtrim(self:GetText() or "") ~= want then CommitSize(self) end
    end)

    -- 音效
    row.soundLabel = SmallLabel(row, L["Sound"])
    row.soundLabel:SetPoint("LEFT", row.size, "RIGHT", 12, 0)
    row.sound = W.CreateDropdown(row, 130, {}, function(v)
        Edit(row, function(r) r.sound = (type(v) == "string" and v ~= "") and v or nil end)
    end)
    row.sound:SetPoint("LEFT", row.soundLabel, "RIGHT", 6, 0)
    row.listen = W.CreateButton(row, L["Listen"], "normal", 44, 20)
    W.FitButton(row.listen, 44, 20)
    row.listen:SetPoint("LEFT", row.sound, "RIGHT", 4, 0)
    row.listen:SetScript("OnClick", function()
        local v = row.sound:GetSelected()
        if type(v) == "string" and ns.Sound then ns.Sound.Preview(v) end
    end)

    row.del = W.CreateButton(row, "X", "red", 20, 18)
    row.del:SetPoint("RIGHT", -6, 0)
    row.del:SetScript("OnClick", function()
        local rules = Rules()
        if not (row.index and rules[row.index]) then return end
        table.remove(rules, row.index)
        Commit(rules)
        Refresh()
    end)
    row.down = ArrowButton(row, false)
    row.down:SetPoint("RIGHT", row.del, "LEFT", -6, 0)
    row.down:SetScript("OnClick", function() Move(row, 1) end)
    row.up = ArrowButton(row, true)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
    row.up:SetScript("OnClick", function() Move(row, -1) end)
end

local function SoundItems()
    local fn = ns.SpellPopover and ns.SpellPopover.SoundItems
    if fn then return fn() end
    return { { text = L["None"], value = false } }
end

local function UpdateRow(row, r, index, n, sounds)
    row.index = index
    row.cmp:SetSelectedValue(r.cmp)
    row.value:SetValue(r.value or 0)
    row.unit:SetText(cur == "time" and L["seconds"] or L["count"])
    local hasColor = ns.ResCond.ValidColor(r.color) ~= nil
    row.colorOn:SetChecked(hasColor)
    row.swatch:SetColor(hasColor and r.color or (DM().Get(Cfg(), cur, "color") or DEFAULT_COLOR))
    row.swatch:SetAlpha(hasColor and 1 or 0.35)
    row.swatch:EnableMouse(hasColor)
    row.size:SetText(r.size and tostring(r.size) or "")
    row.size:SetCursorPosition(0)
    row.sound:SetItems(sounds)
    row.sound:SetSelectedValue(r.sound or false)
    row.listen:SetEnabled(type(r.sound) == "string")
    SetArrowEnabled(row.up, index > 1)
    SetArrowEnabled(row.down, index < n)
end

local function Title()
    return L["Thresholds: %s"]:format(cur == "time" and L["Timer"] or DM().StarName())
end

Refresh = function()
    if not (popup and popup:IsShown()) then return end
    popup.title:SetText(Title())
    local rules = Rules()
    local n = #rules
    local sounds = SoundItems()
    list:Update(rules, function(row, r, i) UpdateRow(row, r, i, n, sounds) end)
    -- 滿了就停用「新增」（做不了的動作不給按）
    addBtn:SetEnabled(n < DM().MAX_RULES)
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local function CreatePopup()
    if popup then return end
    local parent = ns.Options and ns.Options.panel
    if not parent then return end

    popup = W.CreateFrame(nil, parent, POPUP_W, POPUP_H)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:Hide()

    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function()
        mask:Hide()
        W.CloseDropdowns()
    end)

    popup.title = popup:CreateFontString(nil, "OVERLAY")
    popup.title:SetFontObject(W.fontTitle)
    popup.title:SetPoint("TOP", 0, -12)

    hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", 16, -34)
    hint:SetPoint("RIGHT", popup, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(2)
    hint:SetText(L["Rules are checked from top to bottom; the first one that matches applies. A rule's sound plays once when that rule starts to match, so a rule like \">= 0\" plays as you enter %s."]:format(ns.DevourerMeta.MetaName()))

    list = W.CreateRowList(popup, LIST_W, LIST_H, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", 16, -80)

    addBtn = W.CreateButton(popup, L["Add rule"], "normal", 120, 22)
    W.FitButton(addBtn, 120, 22)
    addBtn:SetPoint("BOTTOMLEFT", 16, 12)
    addBtn:SetScript("OnClick", function()
        local rules = Rules()
        if #rules >= DM().MAX_RULES then return end
        local d = NEW_RULE[cur]
        rules[#rules + 1] = { cmp = d.cmp, value = d.value,
            color = { r = d.color.r, g = d.color.g, b = d.color.b, a = d.color.a } }
        Commit(rules)
        Refresh()
    end)

    local close = W.CreateButton(popup, L["Okay"], "primary", 100, 22)
    close:SetPoint("BOTTOMRIGHT", -16, 12)
    close:SetScript("OnClick", function() popup:Hide() end)
end

-- changedCallback：規則增刪時叫（設定頁那顆按鈕的筆數跟著換）
function MR.Open(which, changedCallback)
    cur = (which == "stars") and "stars" or "time"
    onChanged = changedCallback
    CreatePopup()
    if not popup then return end
    popup:Show()
    Refresh()
end

-- 開它的設定視窗收起來時一起收
function MR.Close()
    if popup then popup:Hide() end
end

function MR.Count(which)
    local cfg = Cfg()
    local f = ns.DevourerMeta and ns.DevourerMeta.FIELD[which]
    local own = cfg and f and cfg[f]
    local rules = type(own) == "table" and own.rules
    return type(rules) == "table" and #rules or 0
end
