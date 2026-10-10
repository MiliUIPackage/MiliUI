------------------------------------------------------------
-- 資源條的「條件規則」編輯器（每種資源設定視窗底下的一段，Options/ResourceSettings.lua）
--
-- 宿主只要給：一張 Specs.MakeCtx 的 ctx（增刪規則／檢查叫 ctx.apply，宿主在 apply 裡照 FormSignature
-- 換表單），以及候選清單 cand（只有一種就不出「編輯對象」下拉）。這支不認得任何頁面。
--
-- 資料模型、求值語意與白名單在 Modules/ResourceConditions.lua，這支只負責畫表單。
-- 一條規則長這樣：
--
--   規則 1                                    [上移] [刪除]
--   目標      [ 整條 / 第 N 格 ]
--   如果      [變數][比較][數值]               [移除]
--   並且      [變數][比較][數值]               [移除]
--             [ 新增檢查 ]
--   則
--   條形顏色  ☑ ■
--   背景      ☐
--   透明度    ☐ ────────
--   數值文字  ☐
--
-- ⚠ **什麼時候可以換表單**：frame 刪不掉，換一份表單就是把舊的藏起來永久留著 ⇒
-- 連續操作（拖滑桿、打字、調色）一次都不准換。只有「列數真的變了」才換：增刪規則／檢查、
-- 上移、換編輯對象、換目標 —— 那些都會改到 RC.FormSignature，宿主照簽章換一份（快取）。
-- 換變數型別與勾選覆寫都**不換** —— 那幾個控件一開始就建好，原地顯示／隱藏。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.ResourceConditionsUI = {}
local UI = ns.ResourceConditionsUI

local RC = ns.ResCond

local ROW_H = 26
local ROW_H_TALL = 30

-- 現在在編輯哪個資源。**刻意不存進 DB**：那是「面板開在哪一頁」，不是玩家的設定
-- （設定視窗一次只給一種資源，這裡就是那一種）
local editKey

local function Cfg() return ns.DB.ConfigTable("resources") end

------------------------------------------------------------
-- 讀寫
------------------------------------------------------------
local function Rules(key, create)
    local cfg = Cfg()
    if not cfg then return nil end
    local root = cfg.conditions
    if type(root) ~= "table" then
        if not create then return nil end
        root = {}
        cfg.conditions = root
    end
    local t = root[key]
    if type(t) ~= "table" then
        if not create then return nil end
        t = {}
        root[key] = t
    end
    return t
end

local function RuleAt(key, i)
    local t = Rules(key)
    return t and t[i] or nil
end

-- 空的規則陣列就把整個鍵拿掉
local function PruneRules(key)
    local cfg = Cfg()
    local root = cfg and cfg.conditions
    local t = type(root) == "table" and root[key]
    if type(t) == "table" and t[1] == nil then root[key] = nil end
end

------------------------------------------------------------
-- 下拉的選項
------------------------------------------------------------
local VAR_LABELS = {
    always        = L["No condition"],
    powerValue    = L["Value"],
    powerPercent  = L["Percent"],
    powerFull     = L["Full"],
    pipRecharging = L["Rune state"],
}

local CMP_ITEMS = {}
for _, op in ipairs(RC.CMP_LIST) do CMP_ITEMS[#CMP_ITEMS + 1] = { text = op, value = op } end

local FULL_ITEMS     = { { text = L["Yes"], value = true },        { text = L["No"], value = false } }
local RECHARGE_ITEMS = { { text = L["Recharging"], value = true }, { text = L["Ready"], value = false } }

local function Info(key) return ns.Resources.Info(key) end
local function IsPip(key) local i = Info(key); return i and i.mode == "pip" or false end
local function IsRune(key) local i = Info(key); return i and i.fill == "rune" or false end

-- 點數型用「數值」（第幾點），連續條多一個「百分比」
local function VarItems(key)
    local items = {
        { text = VAR_LABELS.always, value = "always" },
        { text = VAR_LABELS.powerValue, value = "powerValue" },
    }
    if not IsPip(key) then items[#items + 1] = { text = VAR_LABELS.powerPercent, value = "powerPercent" } end
    items[#items + 1] = { text = VAR_LABELS.powerFull, value = "powerFull" }
    if IsRune(key) then items[#items + 1] = { text = VAR_LABELS.pipRecharging, value = "pipRecharging" } end
    return items
end

local function TargetItems(key)
    local items = { { text = L["The whole bar"], value = 0 } }
    local n = ns.Resources.SegmentsFor(key) or 0
    for i = 1, n do items[#items + 1] = { text = L["Segment %d"]:format(i), value = i } end
    return items
end

local function DefaultLeaf(key)
    if IsPip(key) then return { var = "powerValue", cmp = ">=", value = 1 } end
    return { var = "powerPercent", cmp = ">=", value = 50 }
end

------------------------------------------------------------
-- 自訂列：build(parent, x, y, width, ctx) → 高度, refresh
------------------------------------------------------------
local function Hairline(parent, x, y, width)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    t:SetVertexColor(1, 1, 1, 0.12)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    t:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
    t:SetHeight(ns.P.Scale(1))
    return t
end

-- 每一次結構變動都叫 ctx.apply（宿主的 apply 會照簽章決定要不要換表單）
local function Changed(ctx)
    ctx.lastSpec = { structural = true }
    ctx.apply()
end

local function SelectorRow(cand)
    return function(parent, x, y, width, ctx)
        local dd = W.CreateDropdown(parent, 170, nil, function(v)
            editKey = v
            Changed(ctx)
        end)
        local items = {}
        for _, key in ipairs(cand) do
            local i = Info(key)
            items[#items + 1] = { text = (i and i.name) or key, value = key }
        end
        dd:SetItems(items)
        dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - ROW_H_TALL / 2)
        local function Refresh() dd:SetSelectedValue(editKey) end
        Refresh()
        return ROW_H_TALL, Refresh
    end
end

local function RuleHeaderRow(key, index)
    return function(parent, x, y, width, ctx)
        Hairline(parent, x, y, width)
        local cy = y - ROW_H_TALL / 2
        if index > 1 then
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFontObject(W.fontSmall)
            fs:SetTextColor(0.6, 0.6, 0.6)
            fs:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
            fs:SetText(L["Otherwise, if"])
        end
        local del = W.CreateButton(parent, L["Delete"], "red", 76, 20)
        del:SetPoint("RIGHT", parent, "TOPLEFT", x + width, cy)
        del:SetScript("OnClick", function()
            local t = Rules(key)
            if t then table.remove(t, index) end
            PruneRules(key)
            Changed(ctx)
        end)
        if index > 1 then
            local up = W.CreateButton(parent, L["Move up"], "normal", 76, 20)
            up:SetPoint("RIGHT", parent, "TOPLEFT", x + width - 82, cy)
            up:SetScript("OnClick", function()
                local t = Rules(key)
                if t and t[index] and t[index - 1] then t[index], t[index - 1] = t[index - 1], t[index] end
                Changed(ctx)
            end)
        end
        return ROW_H_TALL
    end
end

local function TargetRow(key, index)
    return function(parent, x, y, width, ctx)
        local dd = W.CreateDropdown(parent, 140, TargetItems(key), function(v)
            local rule = RuleAt(key, index)
            if not rule then return end
            rule.target = (v ~= 0) and v or nil
            -- 整條層級的三個覆寫只有「整條」才給 ⇒ 列數會變
            Changed(ctx)
        end)
        dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - ROW_H_TALL / 2)
        local function Refresh()
            local rule = RuleAt(key, index)
            dd:SetSelectedValue((rule and rule.target) or 0)
        end
        Refresh()
        return ROW_H_TALL, Refresh
    end
end

local function CheckRow(key, index, checkIndex, canRemove)
    return function(parent, x, y, width, ctx)
        local cy = y - ROW_H_TALL / 2
        local varDD, cmpDD, numBox, boolDD
        local function Leaf()
            local rule = RuleAt(key, index)
            return rule and RC.CheckAt(rule, checkIndex) or nil
        end
        -- 換變數型別不換表單：三種控件一開始就建好，這裡只決定誰現身
        local function Sync()
            local leaf = Leaf()
            local var = (leaf and leaf.var) or "always"
            local isBool = (var == "powerFull" or var == "pipRecharging")
            local isNum = (var == "powerValue" or var == "powerPercent")
            varDD:SetSelectedValue(var)
            cmpDD:SetShown(isNum)
            numBox:SetShown(isNum)
            boolDD:SetShown(isBool)
            if isNum then
                cmpDD:SetSelectedValue(leaf.cmp or ">=")
                numBox:SetValue(tonumber(leaf.value) or 0)
            elseif isBool then
                boolDD:SetItems(var == "powerFull" and FULL_ITEMS or RECHARGE_ITEMS)
                boolDD:SetSelectedValue(leaf.value == true)
            end
        end

        varDD = W.CreateDropdown(parent, 116, VarItems(key), function(v)
            local leaf = Leaf()
            if not leaf then return end
            leaf.var = v
            -- 換型別時清掉用不到的欄位、補上合理的預設（殘值會讓整條判不成立，畫面上看不出原因）
            if v == "powerFull" or v == "pipRecharging" then
                leaf.cmp, leaf.value = nil, true
            elseif v == "always" then
                leaf.cmp, leaf.value = nil, nil
            else
                leaf.cmp = leaf.cmp or ">="
                if type(leaf.value) ~= "number" then leaf.value = 0 end
            end
            Sync()
            ctx.apply()
        end)
        varDD:SetPoint("LEFT", parent, "TOPLEFT", x, cy)

        cmpDD = W.CreateDropdown(parent, 58, CMP_ITEMS, function(v)
            local leaf = Leaf()
            if leaf then leaf.cmp = v end
            ctx.apply()
        end)
        cmpDD:SetPoint("LEFT", parent, "TOPLEFT", x + 122, cy)

        numBox = W.CreateNumberBox(parent, 62, 1, function(v)
            local leaf = Leaf()
            if leaf then leaf.value = v end
            ctx.apply()
        end)
        numBox:SetPoint("LEFT", parent, "TOPLEFT", x + 186, cy)

        boolDD = W.CreateDropdown(parent, 126, FULL_ITEMS, function(v)
            local leaf = Leaf()
            if leaf then leaf.value = (v == true) end
            ctx.apply()
        end)
        boolDD:SetPoint("LEFT", parent, "TOPLEFT", x + 122, cy)

        if canRemove then
            local rm = W.CreateButton(parent, L["Remove"], "normal", 76, 20)
            rm:SetPoint("LEFT", parent, "TOPLEFT", x + 256, cy)
            rm:SetScript("OnClick", function()
                local rule = RuleAt(key, index)
                if rule then
                    local list = RC.ChecksArray(rule)
                    table.remove(list, checkIndex)
                    RC.SetChecks(rule, list)
                end
                Changed(ctx)
            end)
        end

        Sync()
        return ROW_H_TALL, Sync
    end
end

------------------------------------------------------------
-- 覆寫列：勾選框 ＋ 控件。勾掉＝把那一項設回 nil。勾選**不換表單**（原地顯示／隱藏）
------------------------------------------------------------
local function Overrides(key, index, create)
    local rule = RuleAt(key, index)
    if not rule then return nil end
    local ov = rule.overrides
    if type(ov) ~= "table" then
        if not create then return nil end
        ov = {}
        rule.overrides = ov
    end
    return ov
end

-- 勾起來時的起手色：這個資源目前的主色
local function SeedColor(key)
    local d = ns.Resources.ResolveColor(Cfg(), key, "color")
    return { r = d.r or 1, g = d.g or 1, b = d.b or 1, a = 1 }
end

local function ColorOverrideRow(key, index, field)
    return function(parent, x, y, width, ctx)
        local cy = y - ROW_H / 2
        local swatch
        local cb = W.CreateCheckButton(parent, nil, function(checked)
            local ov = Overrides(key, index, true)
            if not ov then return end
            if checked then
                if type(ov[field]) ~= "table" then ov[field] = SeedColor(key) end
            else
                ov[field] = nil
            end
            local c = ov[field]
            swatch:SetShown(c ~= nil)
            if c then swatch:SetColor(c) end
            ctx.apply()
        end)
        cb:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        swatch = W.CreateColorPicker(parent, nil, true, function(r, g, b, a)
            local ov = Overrides(key, index)
            local c = ov and ov[field]
            if type(c) ~= "table" then return end
            c.r, c.g, c.b, c.a = r, g, b, a
            ctx.apply()
        end)
        swatch:SetPoint("LEFT", parent, "TOPLEFT", x + 26, cy)
        local function Refresh()
            local ov = Overrides(key, index)
            local c = ov and ov[field]
            local on = type(c) == "table"
            cb:SetChecked(on)
            swatch:SetShown(on)
            if on then swatch:SetColor(c) end
        end
        Refresh()
        return ROW_H, Refresh
    end
end

-- 說明問號：控件後面一個小「?」，滑過才顯示（同一段說明每條規則都會重複，不放成下一列灰字；樣式同逐法術小窗的 HelpMark）
local HELP_W = 14
local function HelpMark(parent, text)
    local m = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    m:SetSize(HELP_W, HELP_W)
    W.Stylize(m, { 0.1, 0.1, 0.1, 0.9 }, { 0.4, 0.4, 0.4, 1 })
    local q = m:CreateFontString(nil, "OVERLAY")
    q:SetFontObject(W.fontSmall)
    q:SetPoint("CENTER", m, "CENTER", 0, 0)
    q:SetText("?")
    q:SetTextColor(0.6, 0.6, 0.6)
    m:EnableMouse(true)
    m:SetScript("OnEnter", function(self)
        q:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function()
        q:SetTextColor(0.6, 0.6, 0.6)
        GameTooltip:Hide()
    end)
    return m
end

-- 透明度：連續條（漩渦、怒氣、能量…）戰鬥中數值是秘密值，規則改走色曲線（Modules/Resources.lua 的 CondCurve）——
-- 顏色三項照換、透明度換不了（曲線挑出來的是秘密的顏色，要的是 SetAlpha 的數字）⇒ 控件後面的「?」寫給玩家看。
-- 點數型的值是明文，照常生效、不掛問號
local function AlphaOverrideRow(key, index)
    return function(parent, x, y, width, ctx)
        local cy = y - ROW_H_TALL / 2
        local slider
        local cb = W.CreateCheckButton(parent, nil, function(checked)
            local ov = Overrides(key, index, true)
            if not ov then return end
            ov.alpha = checked and (type(ov.alpha) == "number" and ov.alpha or 0.5) or nil
            slider:SetShown(ov.alpha ~= nil)
            if ov.alpha then slider:SetValue(ov.alpha) end
            ctx.apply()
        end)
        cb:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        -- 回呼接在 afterChange（放開滑鼠／數字框按 Enter）：數字框打字只觸發它
        slider = W.CreateSlider(parent, 0, 1, 200, 0.05, nil, function(v)
            local ov = Overrides(key, index)
            if ov and type(ov.alpha) == "number" then
                ov.alpha = v
                ctx.apply()
            end
        end)
        slider:SetPoint("LEFT", parent, "TOPLEFT", x + 26, cy)
        if not IsPip(key) then
            local help = HelpMark(parent, L["In combat this bar's value is hidden from addons, so opacity only follows the rule out of combat. Bar, background and value text colors still change in combat."])
            help:SetPoint("LEFT", parent, "TOPLEFT", x + 26 + 200 + 10, cy)
        end
        local function Refresh()
            local ov = Overrides(key, index)
            local a = ov and ov.alpha
            local on = type(a) == "number"
            cb:SetChecked(on)
            slider:SetShown(on)
            if on then slider:SetValue(a) end
        end
        Refresh()
        return ROW_H_TALL, Refresh
    end
end

------------------------------------------------------------
-- 組表
------------------------------------------------------------
local function ResolveEditKey(cand)
    for _, key in ipairs(cand) do
        if key == editKey then return editKey end
    end
    editKey = cand[1]
    return editKey
end

local function AppendRule(list, key, index)
    list[#list + 1] = { type = "space", h = 6 }
    list[#list + 1] = { type = "custom", label = L["Rule %d"]:format(index),
                        h = ROW_H_TALL, build = RuleHeaderRow(key, index) }
    local rule = RuleAt(key, index)
    local wholeBar = not (rule and rule.target)
    -- 連續條沒有格子可以指；已經帶著 target 的規則例外（不然永遠不成立又沒地方清掉）
    if IsPip(key) or not wholeBar then
        list[#list + 1] = { type = "custom", label = L["Applies to"], h = ROW_H_TALL, build = TargetRow(key, index) }
    end
    local n = RC.CheckCount(rule)
    for j = 1, n do
        list[#list + 1] = { type = "custom", label = (j == 1) and L["If"] or L["And"],
                            h = ROW_H_TALL, build = CheckRow(key, index, j, n > 1) }
    end
    list[#list + 1] = { type = "custom", label = "", h = ROW_H_TALL, build = function(parent, x, y, width, ctx)
        local b = W.CreateButton(parent, L["Add check"], "normal", 170, 22)
        W.FitButton(b, 170, 22)
        b:SetPoint("LEFT", parent, "TOPLEFT", x, y - ROW_H_TALL / 2)
        b:SetScript("OnClick", function()
            local r = RuleAt(key, index)
            if not r then return end
            local checks = RC.ChecksArray(r)
            checks[#checks + 1] = DefaultLeaf(key)
            RC.SetChecks(r, checks)
            Changed(ctx)
        end)
        return ROW_H_TALL
    end }
    list[#list + 1] = { type = "header", label = L["Then"], nested = true }
    list[#list + 1] = { type = "custom", label = L["Bar color"], h = ROW_H, build = ColorOverrideRow(key, index, "color") }
    if wholeBar then
        list[#list + 1] = { type = "custom", label = L["Background"], h = ROW_H, build = ColorOverrideRow(key, index, "bgColor") }
        list[#list + 1] = { type = "custom", label = L["Opacity"], h = ROW_H_TALL, build = AlphaOverrideRow(key, index) }
        list[#list + 1] = { type = "custom", label = L["Value text color"], h = ROW_H, build = ColorOverrideRow(key, index, "tagColor") }
    else
        list[#list + 1] = { type = "text",
            label = L["Background, opacity and value text color belong to the whole bar, so a rule aimed at one segment only offers the bar color."] }
    end
end

function UI.Append(list, cand)
    local key = ResolveEditKey(cand)
    if not key then return end
    list[#list + 1] = { type = "header", label = L["Conditions"], nested = true }
    list[#list + 1] = { type = "text",
        label = L["Rules are checked from the top down and the first one that matches wins. Charged combo points keep their own color."] }
    if #cand > 1 then
        list[#list + 1] = { type = "custom", label = L["Edit rules for"], h = ROW_H_TALL, build = SelectorRow(cand) }
    end
    local rules = Rules(key)
    local total = rules and #rules or 0
    if total == 0 then
        list[#list + 1] = { type = "text", label = L["No rules yet — the bar keeps its normal color."] }
    else
        for i = 1, total do AppendRule(list, key, i) end
    end
    list[#list + 1] = { type = "space", h = 6 }
    list[#list + 1] = { type = "custom", label = "", h = ROW_H_TALL, build = function(parent, x, y, width, ctx)
        local b = W.CreateButton(parent, L["Add rule"], "normal", 150, 22)
        W.FitButton(b, 150, 22)
        b:SetPoint("LEFT", parent, "TOPLEFT", x, y - ROW_H_TALL / 2)
        b:SetScript("OnClick", function()
            local t = Rules(key, true)
            if not t then return end
            t[#t + 1] = { check = DefaultLeaf(key), overrides = {} }
            Changed(ctx)
        end)
        return ROW_H_TALL
    end }
end

-- 表單形狀的簽章：編輯對象 ＋ 它的規則結構
function UI.FormSignature(cand)
    local key = ResolveEditKey(cand)
    if not key then return "-" end
    return key .. ":" .. RC.Signature(Cfg(), key)
end

function UI.EditKey() return editKey end
