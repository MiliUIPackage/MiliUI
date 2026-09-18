------------------------------------------------------------
-- 資源條的「條件規則」編輯器（「資源」分頁底下的一段）
--
-- 資料模型、求值語意與白名單都在 Elements/ClassPower.lua，這支只負責畫表單。
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
-- ⚠ **什麼時候可以重建控件**：暴雪的 frame 刪不掉，Rebuild 只是把舊內容藏起來
-- 永久留著 ⇒ 連續操作（拖滑桿、打字、調色）一次都不准重建。
-- 只有「列數真的變了」才重建：增刪規則／檢查、上移、換編輯對象、換目標。
-- 換變數型別與勾選覆寫都**不重建** —— 那幾個控件一開始就建好，原地顯示／隱藏就行。
--
-- ⚠ 這一頁的控件幾乎全走 type = "custom"（一列要塞三四個控件），所以設定搜尋
-- 索引不到它們（Search 只收得下有 label 的標準列）。那是刻意的取捨：
-- 為了深層路徑去改共用層 Controls 的代價更大（十個插件共用的 vendor 複製）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.ResourceConditions = {}
local RC = ns.ResourceConditions

local ROW_H = 26
local ROW_H_TALL = 30

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
-- 現在在編輯哪個資源。**刻意不存進 DB**：那是「面板開在哪一頁」，不是玩家的設定，
-- 存進去會被匯出字串一起帶到別人身上
local editKey

-- 結構變了 ⇒ 下一次 ctx.apply 要重建控件（由 Options/Tab_Resource.lua 取用）
local needsRebuild = false

function RC.MarkRebuild() needsRebuild = true end

function RC.ConsumeRebuild()
    local v = needsRebuild
    needsRebuild = false
    return v
end

local function EDB()
    local u = ns.db and ns.db.units and ns.db.units.player
    return u and u.elements and u.elements.classpower
end

------------------------------------------------------------
-- 讀寫
------------------------------------------------------------
-- 這個資源的規則陣列。create = true 時順便把中間的表建出來
local function Rules(key, create)
    local edb = EDB()
    if not edb then return nil end
    local root = edb.conditions
    if type(root) ~= "table" then
        if not create then return nil end
        root = {}
        edb.conditions = root
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

-- 空的規則陣列就把整個鍵拿掉：求值端用 `t[1] ~= nil` 判「有沒有條件」，
-- 留一張空表只是讓存檔多一筆沒意義的東西
local function PruneRules(key)
    local edb = EDB()
    local root = edb and edb.conditions
    local t = root and root[key]
    if type(t) == "table" and t[1] == nil then root[key] = nil end
end

------------------------------------------------------------
-- 檢查：一律當成**陣列**看
--
-- 存法照 Ayije_CDM：只有一條就直接存 leaf，兩條以上才包成 { op = "and", children }。
-- 兩邊要能互吃彼此的資料，存法就得一樣。
------------------------------------------------------------
local function CheckCount(rule)
    local c = rule and rule.check
    if type(c) ~= "table" then return 0 end
    if c.op then
        local ch = c.children
        return (type(ch) == "table") and #ch or 0
    end
    return 1
end

local function CheckAt(rule, i)
    local c = rule and rule.check
    if type(c) ~= "table" then return nil end
    if c.op then
        local ch = c.children
        return (type(ch) == "table") and ch[i] or nil
    end
    return (i == 1) and c or nil
end

local function ChecksArray(rule)
    local out = {}
    for i = 1, CheckCount(rule) do out[i] = CheckAt(rule, i) end
    return out
end

local function SetChecks(rule, list)
    if list[2] == nil then
        rule.check = list[1]
    else
        rule.check = { op = "and", children = list }
    end
end

------------------------------------------------------------
-- 下拉的選項
------------------------------------------------------------
local VAR_LABELS = {
    -- ⚠ 這一欄是「拿什麼來比」，不是「什麼時候顯示」。借可見度那邊的「一直顯示」
    -- 當標籤會變成「一直顯示」這個變數，意思整個跑掉 ⇒ 自己一個 key
    always       = L["No condition"],
    powerValue   = L["Value"],
    powerPercent = L["Percent"],
    powerFull    = L["Full"],
    -- 「符文狀態」只有符文列才列得出來，所以標籤直接講符文，不用抽象的「充能中」
    pipRecharging = L["Rune state"],
}

local CMP_ITEMS = {}
for _, op in ipairs(ns.RESOURCE_CMP_LIST or {}) do
    CMP_ITEMS[#CMP_ITEMS + 1] = { text = op, value = op }
end

local FULL_ITEMS     = { { text = L["Yes"], value = true },        { text = L["No"], value = false } }
local RECHARGE_ITEMS = { { text = L["Recharging"], value = true }, { text = L["Ready"], value = false } }

local function IsPip(key)
    local info = ns.ResourceInfo and ns.ResourceInfo(key)
    return info and info.mode == "pip" or false
end

local function IsRune(key)
    local info = ns.ResourceInfo and ns.ResourceInfo(key)
    return info and info.fill == "rune" or false
end

-- 點數型用「數值」（第幾點），連續條用「百分比」——跟 Ayije_CDM 的規則一致。
-- spec 刻意不列：同職業多專精共用同一種資源時它才有意義，而求值端本來就支援，
-- 跟隨 Ayije 的資料照樣吃得下
local function VarItems(key)
    local pip = IsPip(key)
    local items = {
        { text = VAR_LABELS.always, value = "always" },
        { text = VAR_LABELS.powerValue, value = "powerValue" },
    }
    if not pip then
        items[#items + 1] = { text = VAR_LABELS.powerPercent, value = "powerPercent" }
    end
    items[#items + 1] = { text = VAR_LABELS.powerFull, value = "powerFull" }
    if IsRune(key) then
        items[#items + 1] = { text = VAR_LABELS.pipRecharging, value = "pipRecharging" }
    end
    return items
end

local function TargetItems(key)
    local items = { { text = L["The whole bar"], value = 0 } }
    local n = (ns.ResourceSegments and ns.ResourceSegments(key)) or 0
    for i = 1, n do
        items[#items + 1] = { text = L["Segment %d"]:format(i), value = i }
    end
    return items
end

local function DefaultLeaf(key)
    if IsPip(key) then return { var = "powerValue", cmp = ">=", value = 1 } end
    return { var = "powerPercent", cmp = ">=", value = 50 }
end

------------------------------------------------------------
-- 自訂列
--
-- build(parent, x, y, width, ctx) → 高度, refresh
-- x / y 是控件欄左上角（跟其他列同一套座標），width 是可用寬度。
------------------------------------------------------------
-- 一條髮絲線：規則之間靠結構分開，不是靠顏色（顏色是最弱的一層訊號）
local function Hairline(parent, x, y, width)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(ns.Media.WHITE8X8)
    t:SetVertexColor(1, 1, 1, 0.12)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    t:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + width, y)
    t:SetHeight(ns.P.Scale(1))
    return t
end

-- 編輯對象
local function SelectorRow(cand)
    return function(parent, x, y, width, ctx)
        local dd = W.CreateDropdown(parent, 170, nil, function(v)
            editKey = v
            RC.MarkRebuild()
            ctx.apply()
        end)
        local items = {}
        for _, key in ipairs(cand) do
            local info = ns.ResourceInfo and ns.ResourceInfo(key)
            items[#items + 1] = { text = (info and info.name) or key, value = key }
        end
        dd:SetItems(items)
        dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - ROW_H_TALL / 2)
        local function Refresh() dd:SetSelectedValue(editKey) end
        Refresh()
        return ROW_H_TALL, Refresh
    end
end

-- 規則標題列：髮絲線 ＋「否則如果」 ＋ 上移／刪除
local function RuleHeaderRow(key, index)
    return function(parent, x, y, width, ctx)
        Hairline(parent, x, y, width)
        local cy = y - ROW_H_TALL / 2
        if index > 1 then
            -- 灰、小一級：它是後設資訊（「這一條是前面沒中才輪到的」），
            -- 不是可以點的東西，所以要比內容弱
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
            RC.MarkRebuild()
            ctx.apply()
        end)
        if index > 1 then
            local up = W.CreateButton(parent, L["Move up"], "normal", 76, 20)
            up:SetPoint("RIGHT", parent, "TOPLEFT", x + width - 82, cy)
            up:SetScript("OnClick", function()
                local t = Rules(key)
                if t and t[index] and t[index - 1] then
                    t[index], t[index - 1] = t[index - 1], t[index]
                end
                RC.MarkRebuild()
                ctx.apply()
            end)
        end
        return ROW_H_TALL
    end
end

-- 目標（只有點數型會有）
local function TargetRow(key, index)
    return function(parent, x, y, width, ctx)
        local dd = W.CreateDropdown(parent, 140, TargetItems(key), function(v)
            local rule = RuleAt(key, index)
            if not rule then return end
            rule.target = (v ~= 0) and v or nil
            -- 整條層級的三個覆寫（背景／透明度／數值文字色）只有「整條」才給，
            -- 所以那幾列會跟著出現或消失 ⇒ 這個要重建
            RC.MarkRebuild()
            ctx.apply()
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

-- 一個檢查：變數 ＋ 比較 ＋ 數值（＋ 移除）
local function CheckRow(key, index, checkIndex, canRemove)
    return function(parent, x, y, width, ctx)
        local cy = y - ROW_H_TALL / 2
        local varDD, cmpDD, numBox, boolDD
        local function Leaf()
            local rule = RuleAt(key, index)
            return rule and CheckAt(rule, checkIndex) or nil
        end
        -- 換變數型別不重建：三種控件一開始就建好，這裡只決定誰現身
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
            -- 換型別時把用不到的欄位清掉、缺的補成合理的預設。留著對不起來的殘值
            -- 會讓求值端整條判不成立，而畫面上完全看不出原因
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
                    local list = ChecksArray(rule)
                    table.remove(list, checkIndex)
                    SetChecks(rule, list)
                end
                RC.MarkRebuild()
                ctx.apply()
            end)
        end

        Sync()
        return ROW_H_TALL, Sync
    end
end

------------------------------------------------------------
-- 覆寫列：勾選框 ＋ 控件
--
-- 勾掉＝把那一項設回 nil（求值端看 nil 就當這條規則沒有指定這一項）。
-- ⚠ 勾選**不重建**：控件一開始就建好，勾掉只是藏起來 —— 重建會留下孤兒 frame。
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

-- 勾起來時的起手色：拿這個資源目前的主色，玩家一眼看得出自己在改什麼
local function SeedColor(key)
    local d = ns.ResourceDefaultColor and ns.ResourceDefaultColor(key, "color")
    return { r = (d and d.r) or 1, g = (d and d.g) or 1, b = (d and d.b) or 1, a = 1 }
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
        -- ⚠ 色票是「拿到 table 就原地改」，所以這裡改的一定是我們自己 DB 裡的表
        -- （Overrides 只回傳 edb.conditions 底下的東西，永遠不會是 Ayije 的表）
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
        -- ⚠ 回呼接在 afterChange（放開滑鼠／數字框按 Enter），onChange 那格刻意留 nil ——
        -- 共用層的 slider 列也是這樣接：
        --   * 數字框打字只會觸發 afterChange ⇒ 接在 onChange 的話打的數字不會存
        --   * 每一格都 ctx.apply 等於拖一下就整個單位框重套幾十次
        slider = W.CreateSlider(parent, 0, 1, 200, 0.05, nil, function(v)
            local ov = Overrides(key, index)
            if ov and type(ov.alpha) == "number" then
                ov.alpha = v
                ctx.apply()
            end
        end)
        slider:SetPoint("LEFT", parent, "TOPLEFT", x + 26, cy)
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
-- 目前該編輯哪個資源（選過的還在清單裡就沿用，不然退回第一個）
local function ResolveEditKey(cand)
    for _, key in ipairs(cand) do
        if key == editKey then return editKey end
    end
    editKey = cand[1]
    return editKey
end

local function AppendRule(list, key, index, ctx)
    list[#list + 1] = { type = "space", h = 6 }
    list[#list + 1] = { type = "custom", label = L["Rule %d"]:format(index),
                        h = ROW_H_TALL, build = RuleHeaderRow(key, index) }
    local rule = RuleAt(key, index)
    local wholeBar = not (rule and rule.target)
    -- 連續條沒有格子可以指，本來不該出現這一列；但**已經帶著 target 的規則要例外**
    -- （從 Ayije_CDM 複製過來的資料可能有），不然那條規則永遠不成立又沒地方清掉。
    -- 連續條的目標下拉只有「整條」一個選項，選下去就把 target 清掉了
    if IsPip(key) or not wholeBar then
        list[#list + 1] = { type = "custom", label = L["Applies to"],
                            h = ROW_H_TALL, build = TargetRow(key, index) }
    end
    local n = CheckCount(rule)
    for j = 1, n do
        list[#list + 1] = { type = "custom", label = (j == 1) and L["If"] or L["And"],
                            h = ROW_H_TALL, build = CheckRow(key, index, j, n > 1) }
    end
    list[#list + 1] = { type = "button", label = "", text = L["Add check"], width = 170,
        onClick = function()
            local r = RuleAt(key, index)
            if not r then return end
            local checks = ChecksArray(r)
            checks[#checks + 1] = DefaultLeaf(key)
            SetChecks(r, checks)
            RC.MarkRebuild()
            ctx.apply()
        end }
    list[#list + 1] = { type = "header", label = L["Then"], nested = true }
    list[#list + 1] = { type = "custom", label = L["Bar color"], h = ROW_H,
                        build = ColorOverrideRow(key, index, "color") }
    if wholeBar then
        list[#list + 1] = { type = "custom", label = L["Background"], h = ROW_H,
                            build = ColorOverrideRow(key, index, "bgColor") }
        list[#list + 1] = { type = "custom", label = L["Opacity"], h = ROW_H_TALL,
                            build = AlphaOverrideRow(key, index) }
        list[#list + 1] = { type = "custom", label = L["Value text color"], h = ROW_H,
                            build = ColorOverrideRow(key, index, "tagColor") }
    else
        list[#list + 1] = { type = "text",
            label = L["Background, opacity and value text color belong to the whole bar, so a rule aimed at one segment only offers the bar color."] }
    end
end

-- ⚠ 標準的 button spec 只會呼叫 spec.onClick()，**不會**幫忙 ctx.apply ——
-- 所以每個按鈕都要自己叫（不叫的話 MarkRebuild 沒人消費，畫面停在舊的列數）
local function AppendEditor(list, cand, ctx)
    local key = ResolveEditKey(cand)
    if not key then return end

    list[#list + 1] = { type = "header", label = L["Conditions"], nested = true }
    list[#list + 1] = { type = "text",
        label = L["Rules are checked from the top down and the first one that matches wins. Charged combo points keep their own color."] }
    if #cand > 1 then
        list[#list + 1] = { type = "custom", label = L["Edit rules for"],
                            h = ROW_H_TALL, build = SelectorRow(cand) }
    end

    local rules = Rules(key)
    local total = rules and #rules or 0
    if total == 0 then
        list[#list + 1] = { type = "text", label = L["No rules yet — the bar keeps its normal color."] }
    else
        for i = 1, total do AppendRule(list, key, i, ctx) end
    end
    list[#list + 1] = { type = "space", h = 6 }
    list[#list + 1] = { type = "button", label = "", text = L["Add rule"], width = 150,
        onClick = function()
            local t = Rules(key, true)
            if not t then return end
            t[#t + 1] = { check = DefaultLeaf(key), overrides = {} }
            RC.MarkRebuild()
            ctx.apply()
        end }
end

RC.Append = AppendEditor

------------------------------------------------------------
-- 跟隨中的唯讀摘要
--
-- 勾著「與 Ayije_CDM 相同」時編輯器整段不顯示（顯示了也沒用，畫面不會照它走），
-- 但要讓玩家看得出「條件真的有被吃到」—— 不然「我在那邊設了規則，這裡到底有沒有生效」
-- 是沒辦法從畫面確認的（規則沒成立時本來就跟沒設一樣）。
------------------------------------------------------------
-- ⚠ 走 custom 而不是 text，是為了**每次開分頁都重算一次**：玩家可能在關著這一頁的
-- 時候去 Ayije_CDM 那邊加減規則。text 是建表當下就定死的字串，會停在舊的數字，
-- 而為了一行摘要去重建整頁只會留下孤兒 frame。
local function SummaryText(cand)
    local parts = {}
    for _, key in ipairs(cand) do
        local info = ns.ResourceInfo and ns.ResourceInfo(key)
        local n = ns.ResourceConditionDebug and ns.ResourceConditionDebug(key) or 0
        parts[#parts + 1] = ("%s (%d)"):format((info and info.name) or key, n)
    end
    return L["Rules Ayije_CDM currently has for this specialization: %s"]
           :format(table.concat(parts, "   "))
end

function RC.SummarySpec(cand)
    if #cand == 0 then return nil end
    return { type = "custom", build = function(parent, x, y, width)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        local function Refresh() fs:SetText(SummaryText(cand)) end
        Refresh()
        return math.max(ROW_H, (fs:GetStringHeight() or 0) + 10), Refresh
    end }
end
