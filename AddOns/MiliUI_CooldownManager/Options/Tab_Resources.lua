------------------------------------------------------------
-- 「資源條」頁（profile.resources；引擎在 Modules/Resources.lua）
--
-- 控件清單照單位框架的資源條分頁改：顯示／尺寸／外觀／顏色與條件／這個專精要顯示哪幾列，
-- 多了法力的數字格式、載入條件（騎乘隱藏、只在戰鬥中、跟核心技能一起淡）與「錨定」一節
-- （跟條頁同一支 Specs.Anchor；key ＝ "resources"）。
--
-- 「自訂格子」一節：整組開關（profile.pips.enabled）＋目前專精的 customRows 清單（法術充能／光環層數），
-- 一筆三列：名字＋圖示＋種類＋［刪除］、顏色＋（充能）顯示秒數／（層數）上限、顯示時機（下拉）；底下「＋ 新增格子」
-- → 選種類（兩顆按鈕滑過有說明與舉例）→ 輸入 ID（層數多一欄上限）→ 驗證。增刪走換表單
-- （簽章含整份清單），改色／勾選／上限原地套用。
-- 自訂格子畫在自己的面板（Modules/Pips.lua、profile.pips）：清單與樣式在這張表，這一節底下
-- 多一小節「位置與錨定」（Specs.Anchor("pips", { other = true })，讀寫 profile.pips）、
-- 「跟核心技能一起淡出」與自訂格子自己的載入條件（profile.pips.loadConditions）。
--
-- 資源清單跟著專精走、條件規則的列數跟著規則走，所以表單照「形狀」快取（專精、候選清單、
-- 條件編輯器的結構、自訂格子清單、有沒有錨定、條清單）：形狀變了才另建一份、變回來就拿舊的
-- （frame 刪不掉，每改一次重建一次就是洩漏）。形狀的比對延一幀做（不在按鈕的處理器裡換表單）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.TabResources = {}
local Tab = ns.TabResources

local KEY = "resources"
local PIPS = "pips"               -- 自訂格子的面板（位置／錨定／淡出存在 profile.pips）
local FORM_W = Options.PAGE_W - 6

local function Cfg() return ns.DB.ConfigTable(KEY) end

local function BS(kind, path, label, extra)
    local s = { type = kind, root = "bar", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function Note(label) return { type = "text", label = label } end

local FILL_ITEMS = {
    { text = L["Left to right"], value = "ltr" },
    { text = L["Right to left"], value = "rtl" },
}

local MANA_ITEMS = {
    { text = L["Full number"],           value = "none" },
    { text = L["K / M"],                 value = "k" },
    { text = L["10K / 100M (wan / yi)"], value = "wan" },
}

-- 重設整張 profile.resources 與 profile.pips（自訂格子的位置／錨定也在這一頁）。
-- 原地清空再灌：引擎抓著的是這兩張表的參照
local function ResetAll()
    local p = ns.profile
    if not p then return end
    local d = ns.DB.BuildDefaults().profile
    for _, key in ipairs({ KEY, PIPS }) do
        local cfg = ns.DB.ConfigTable(key)
        if cfg then
            for k in pairs(cfg) do cfg[k] = nil end
            ns.DB.MergeDefaults(cfg, d[key])
        end
    end
end

local function ResetRow(label, text, confirmText, fn)
    return { type = "custom", label = label, h = 30, noReset = true, build = function(parent, x, y, width, ctx)
        local b = W.CreateButton(parent, text, "red", 180, 22)
        W.FitButton(b, 180, 22)
        b:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local popup
        b:SetScript("OnClick", function()
            if not popup then
                popup = W.CreateConfirmPopup(Options.panel, 320, confirmText, function()
                    fn()
                    -- refreshPage：值全換了但表單形狀常常沒變（簽章相同就不重建），不強制重讀的話
                    -- 畫面停在重設前的值（條件規則、滑桿），要切頁才看得到（同施法條頁）
                    ctx.lastSpec = { structural = true, refreshPage = true }
                    ctx.apply()
                end)
            end
            popup:Show()
        end)
        return 30
    end }
end

------------------------------------------------------------
-- 自訂格子（profile.resources.customRows[specID]；引擎在 Modules/Pips.lua）
------------------------------------------------------------
local CUSTOM_ROW_H = 26
local QUESTION = 134400

local function CustomList(create)
    return ns.Pips.CustomRowList(Cfg(), ns.specID, create)
end

local function CustomEntry(i)
    local list = CustomList()
    local e = list and list[i]
    return type(e) == "table" and e or nil
end

local function PlainOf(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

local function SpellLabel(id)
    local fn = C_Spell and C_Spell.GetSpellName
    if fn then
        local ok, n = pcall(fn, id)
        n = ok and PlainOf(n) or nil
        if type(n) == "string" and n ~= "" then return n end
    end
    return "#" .. tostring(id)
end

local function SpellIcon(id)
    local fn = C_Spell and C_Spell.GetSpellTexture
    if fn then
        local ok, t = pcall(fn, id)
        t = ok and PlainOf(t) or nil
        if t then return t end
    end
    return QUESTION
end

-- 清單增刪：換表單（簽章變了，資源條頁的 apply 會延一幀換一份）
local function Changed(ctx)
    ctx.lastSpec = { structural = true }
    ctx.apply()
end

-- 原地改值（顏色、勾選、上限）：不換表單
local function Touched(ctx)
    ctx.lastSpec = nil
    ctx.apply()
end

-- 驗證輸入，回傳 entry 或 nil, 給玩家看的原因（純邏輯＋查詢 API；冒煙測得到）
function Tab.ValidateCustomRow(kind, idText, maxText, specID)
    specID = specID or ns.specID
    if not specID then return nil, L["Pick a specialization first."] end
    if not ns.Pips.CUSTOM_KINDS[kind] then return nil, L["Enter a number."] end
    local id = ns.Picker.ParseID(idText)
    if not id then return nil, L["Enter a number."] end
    if not ns.Picker.SpellExists(id) then return nil, L["No spell with that ID."] end
    if ns.Pips.FindCustomRow(Cfg(), specID, kind, id) then
        return nil, L["Already tracked in this specialization."]
    end
    local r, g, b = ns.Style.Accent()
    local entry = { kind = kind, spellID = id, color = { r = r, g = g, b = b, a = 1 }, showTime = true, enabled = true }
    local MAX = ns.ResCond.MAX_SEGMENTS
    if kind == "charges" then
        local info
        local fn = C_Spell and C_Spell.GetSpellCharges
        if fn then
            local ok, v = pcall(fn, id)
            if ok then info = v end
        end
        if type(info) ~= "table" then return nil, L["This spell has no charges."] end
        -- 充能上限順手記下來：戰鬥中讀不到時的退路（讀得到的時候引擎一律以 API 為準）
        local ok, m = pcall(function() return info.maxCharges end)
        m = ok and PlainOf(m) or nil
        entry.max = ns.Pips.ClampSegments(m)
    else
        local text = tostring(maxText or ""):gsub("%s", "")
        local n = (text == "") and ns.Pips.CUSTOM_DEFAULT_STACKS or tonumber(text)
        if not n or n ~= math.floor(n) or n < 1 or n > MAX then
            return nil, L["Max stacks must be a whole number from 1 to %d."]:format(MAX)
        end
        entry.max = n
    end
    return entry
end

local kindPopup, pendingCtx
local AppendPipsPlacement          -- 前置宣告（定義在 AppendCustomRows 前面）
local ShowWhenSpec                 -- 同上
local inputPopups = {}

function Tab.AskCustomID(kind)
    local popup = inputPopups[kind]
    local title = kind == "charges" and L["Track spell charges"] or L["Track aura stacks"]
    if not popup then
        local fields = {
            { key = "id", label = kind == "charges" and L["Spell ID"] or L["Spell ID of the aura"], maxLetters = 10,
              hint = L["Find it in the spell's link or on a database site."]
                  .. " " .. L["Or Shift-click it in your spellbook or talents to fill in the ID."] },
        }
        if kind == "stacks" then
            fields[2] = { key = "max", label = L["Max stacks"], maxLetters = 2 }
        end
        popup = W.CreateInputPopup(Options.panel, ns.Picker.INPUT_W, title, fields)
        inputPopups[kind] = popup
    end
    ns.Picker.SetInputError(popup, nil)
    -- Shift＋點法術書／天賦 → 填 ID（跟追蹤清單的輸入彈窗同一個掛勾）
    ns.Picker.WatchInput(popup, "spell", L["That is an item link. Enter a spell ID here."])
    popup:Open({ max = kind == "stacks" and tostring(ns.Pips.CUSTOM_DEFAULT_STACKS) or nil }, function(values)
        local entry, why = Tab.ValidateCustomRow(kind, values.id, values.max)
        if not entry then
            ns.Picker.SetInputError(popup, why)
            return false
        end
        ns.Picker.SetInputError(popup, nil)
        if not ns.Pips.AddCustomRow(Cfg(), ns.specID, entry) then return end
        if pendingCtx then Changed(pendingCtx) end
    end, title)
    return popup
end

-- 選種類那兩顆按鈕的滑鼠提示：標題＝按鈕字，內文說明長相並舉例
local KIND_TIPS = {
    { title = L["Spell charges"], body = L["A spell with charges, one segment per charge. The next empty segment fills up smoothly as it recharges, with the seconds left. For example, the Paladin's Divine Steed or the Mage's Blink. Enter the spell ID."] },
    { title = L["Aura stacks"], body = L["A buff on you that stacks, one segment per stack; all empty while you don't have it, with no recharge timer. The game fills it in itself, so it stays right in boss fights and Mythic+. For example, the Death Knight's Bone Shield. Enter the aura's spell ID and the max stacks."] },
}

-- CreateChoicePopup 不回傳按鈕（共用層不改）：建完照按鈕字從彈窗的子框認回來，掛 OnEnter／OnLeave
local function AttachKindTips(popup)
    local byText = {}
    for _, tip in ipairs(KIND_TIPS) do byText[tip.title] = tip end
    local n = 0
    for _, child in ipairs({ popup:GetChildren() }) do
        local tip = type(child) == "table" and type(child.GetText) == "function" and byText[child:GetText()]
        if tip and type(child.HookScript) == "function" then
            child:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(tip.title)
                GameTooltip:AddLine(tip.body, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            child:HookScript("OnLeave", function() GameTooltip:Hide() end)
            n = n + 1
        end
    end
    -- 按鈕按下去彈窗就收：滑鼠還停在按鈕上時 OnLeave 不一定來，提示一起收
    popup:HookScript("OnHide", function() GameTooltip:Hide() end)
    popup.tipCount = n                -- 自己的框；冒煙測試用
end

function Tab.AskCustomKind(ctx)
    pendingCtx = ctx
    if not kindPopup then
        kindPopup = W.CreateChoicePopup(Options.panel, 360, L["What should this row track?"], {
            { text = L["Spell charges"], color = "normal", onClick = function() Tab.AskCustomID("charges") end },
            { text = L["Aura stacks"], color = "normal", onClick = function() Tab.AskCustomID("stacks") end },
            { text = L["Cancel"], color = "normal" },
        })
        AttachKindTips(kindPopup)
    end
    kindPopup:Show()
    return kindPopup
end

-- 一筆的第一列：標籤欄是法術名；控件欄 圖示＋種類（灰字）……［刪除］
local function CustomHeadRow(i)
    return function(parent, x, y, width, ctx)
        local cy = y - CUSTOM_ROW_H / 2
        local icon = parent:CreateTexture(nil, "ARTWORK")
        ns.P.Size(icon, 18, 18)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        local kind = parent:CreateFontString(nil, "OVERLAY")
        kind:SetFontObject(W.fontSmall)
        kind:SetTextColor(0.65, 0.65, 0.65)
        kind:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        kind:SetJustifyH("LEFT")
        local del = W.CreateButton(parent, L["Delete"], "normal", 60, 20)
        W.FitButton(del, 60, 20)
        del:SetPoint("RIGHT", parent, "TOPLEFT", x + width, cy)
        local confirm
        del:SetScript("OnClick", function()
            if not confirm then
                confirm = W.CreateConfirmPopup(Options.panel, 320, L["Remove this custom row?"], function()
                    if ns.Pips.RemoveCustomRow(Cfg(), ns.specID, i) then Changed(ctx) end
                end)
            end
            confirm:Show()
        end)
        local function Refresh()
            local e = CustomEntry(i)
            if not e then return end
            icon:SetTexture(SpellIcon(e.spellID))
            kind:SetText(((e.kind == "charges") and L["Charges"] or L["Stacks"]) .. "  ·  "
                .. L["Spell ID"] .. " " .. tostring(e.spellID))
        end
        Refresh()
        return CUSTOM_ROW_H, Refresh
    end
end

-- 第二列：顏色；充能多「顯示秒數」、層數多「上限」
local function CustomOptionsRow(i, kind)
    return function(parent, x, y, width, ctx)
        local cy = y - CUSTOM_ROW_H / 2
        local swatch = W.CreateColorPicker(parent, L["Color"], false, function(r, g, b)
            local e = CustomEntry(i)
            if not e then return end
            e.color = { r = r, g = g, b = b, a = 1 }
            Touched(ctx)
        end)
        swatch:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        local lw = swatch.label:GetStringWidth()
        local nx = x + 14 + 5 + ((type(lw) == "number" and lw > 0) and lw or 30) + 18
        local cb, box
        if kind == "charges" then
            cb = W.CreateCheckButton(parent, L["Show seconds"], function(on)
                local e = CustomEntry(i)
                if not e then return end
                e.showTime = on and true or false
                Touched(ctx)
            end)
            cb:SetPoint("LEFT", parent, "TOPLEFT", nx, cy)
        else
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFontObject(W.fontNormal)
            fs:SetPoint("LEFT", parent, "TOPLEFT", nx, cy)
            fs:SetText(L["Max stacks"])
            box = W.CreateNumberBox(parent, 46, 1, function(v)
                local e = CustomEntry(i)
                if not e then return end
                local n = ns.Pips.ClampSegments(v) or 1
                e.max = n
                box:SetValue(n)
                Touched(ctx)
            end)
            box:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        end
        local function Refresh()
            local e = CustomEntry(i)
            if not e then return end
            local r, g, b = ns.Pips.CustomColor(e)
            swatch:SetColor({ r = r, g = g, b = b, a = 1 })
            if cb then cb:SetChecked(e.showTime ~= false) end
            if box then box:SetValue(ns.Pips.ClampSegments(e.max) or ns.Pips.CUSTOM_DEFAULT_STACKS) end
        end
        Refresh()
        return CUSTOM_ROW_H, Refresh
    end
end

-- 顯示時機（entry.showWhen）：選項依種類（Modules/Pips.lua 的 SHOW_WHEN），原地套用不換表單
local SHOW_WHEN_TEXT = {
    charges = { always = L["Always"], active = L["Only while recharging"], activeOrCombat = L["While recharging or in combat"] },
    stacks  = { always = L["Always"], active = L["Only while you have the aura"] },
}

local function ShowWhenItems(kind)
    local items = {}
    for _, v in ipairs(ns.Pips.SHOW_WHEN[kind] or { "always" }) do
        items[#items + 1] = { text = SHOW_WHEN_TEXT[kind] and SHOW_WHEN_TEXT[kind][v] or v, value = v }
    end
    return items
end
Tab.ShowWhenItems = ShowWhenItems

ShowWhenSpec = function(i, kind)
    return BS("dropdown", "customRows.showWhen." .. i, L["Show when"], {
        items = ShowWhenItems(kind), noReset = true,
        get = function() return ns.Pips.ShowWhen(CustomEntry(i)) end,
        set = function(_, v)
            local e = CustomEntry(i)
            if e then e.showWhen = (v ~= "always") and v or nil end
        end,
    })
end

-- 自訂格子的位置與錨定（profile.pips）：跟條頁同一支 Specs.Anchor，讀寫轉到 pips
AppendPipsPlacement = function(list)
    local function add(s) list[#list + 1] = s end
    for _, s in ipairs(ns.Specs.Anchor(PIPS, { other = true, header = L["Position and anchoring"], nested = true })) do
        add(s)
    end
    add(BS("toggle", "fadeWithEssential", L["Fade with Essential Cooldowns"], { root = "bar@" .. PIPS }))
    add(Note(L["Takes Essential Cooldowns' current opacity, including its visibility conditions and fades."]))
    add({ type = "header", label = L["Load conditions"], nested = true })
    add(BS("toggle", "loadConditions.hideMounted", L["Hide while mounted"], { root = "bar@" .. PIPS }))
    add(Note(L["Mounted includes riding a vehicle."]))
    add(BS("toggle", "loadConditions.onlyCombat", L["Only in combat"], { root = "bar@" .. PIPS }))
end

local function AppendCustomRows(list)
    local function add(s) list[#list + 1] = s end
    -- 自訂格子是這一頁的第二個分頁，分頁鈕本身就是標題，不再放一條同名的小節標題
    add(BS("toggle", "enabled", L["Show custom segments"], { root = "bar@" .. PIPS, level = "structure" }))
    add(Note(L["Track a spell's charges or an aura's stacks on you as rows of segments. By default they sit below Essential Cooldowns and push Utility Cooldowns down. Size and look follow the resource bar settings on the Class Resources tab; each specialization keeps its own list."]))
    if not ns.specID then
        add(Note(L["Pick a specialization first."]))
        AppendPipsPlacement(list)
        return
    end
    local entries = CustomList() or {}
    local shown = 0
    for i, e in ipairs(entries) do
        if type(e) == "table" and ns.Pips.CUSTOM_KINDS[e.kind] and type(e.spellID) == "number" then
            if shown > 0 then add({ type = "space", h = 6 }) end
            shown = shown + 1
            add({ type = "custom", label = SpellLabel(e.spellID), h = CUSTOM_ROW_H, noReset = true, build = CustomHeadRow(i) })
            add({ type = "custom", label = "", h = CUSTOM_ROW_H, noReset = true, build = CustomOptionsRow(i, e.kind) })
            add(ShowWhenSpec(i, e.kind))
        end
    end
    if shown == 0 then
        add(Note(L["No custom segments for this specialization yet."]))
    else
        add(Note(L["A row that hides keeps its space, so the rows below it don't jump."]))
    end
    add({ type = "space", h = 4 })
    add({ type = "custom", label = "", h = 30, noReset = true, build = function(parent, x, y, width, ctx)
        local b = W.CreateButton(parent, L["+ Add segments"], "primary", 150, 22)
        W.FitButton(b, 150, 22)
        b:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        b:SetScript("OnClick", function() Tab.AskCustomKind(ctx) end)
        return 30
    end })
    AppendPipsPlacement(list)
end

-- 表單簽章的一段：整份清單（種類＋法術）。標籤是建表單當下的法術名，所以清單內容一變就換一份
local function CustomSignature()
    local out = {}
    for _, e in ipairs(CustomList() or {}) do
        if type(e) == "table" then out[#out + 1] = tostring(e.kind) .. ":" .. tostring(e.spellID) end
    end
    return #out .. "=" .. table.concat(out, ",")
end
Tab.CustomSignature = CustomSignature

-- 條件規則編輯器的候選：引擎寫值的列（auraBar、auraTimer）不列
function Tab.ConditionCandidates(cand)
    local out = {}
    for _, key in ipairs(cand or {}) do
        if ns.Resources.SupportsConditions(key) then out[#out + 1] = key end
    end
    return out
end

local function Controls(cand, sub)
    local R = ns.Resources
    if sub == "pips" then
        local only = {}
        AppendCustomRows(only)
        return only
    end
    local list = {
        BS("toggle", "enabled", L["Show resource bars"], { level = "structure" }),
        Note(L["Which resources appear follows your specialization and switches automatically. Specs that cast with mana get a mana row at the bottom."]),
        { type = "header", label = L["Layout"] },
        BS("slider", "width", L["Width"], { min = 0, max = 600, step = 1 }),
        Note(L["0 matches the first row of Essential Cooldowns."]),
        BS("slider", "rowHeight", L["Row height"], { min = 2, max = 30, step = 1 }),
        BS("slider", "rowSpacing", L["Row spacing"], { min = 0, max = 12, step = 1 }),
        BS("slider", "segmentSpacing", L["Segment spacing"], { min = 0, max = 8, step = 1 }),
        Note(L["Segment spacing only affects point-style resources (Holy Power, combo points and the like)."]),
        BS("dropdown", "fillDirection", L["Fill direction"], { items = FILL_ITEMS }),
        Note(L["Right to left also lights point-style resources from the right: the first point is the rightmost segment."]),
        { type = "header", label = L["Appearance"] },
        BS("dropdown", "texture", L["Texture"], { items = ns.Specs.TextureItems }),
        BS("slider", "barAlpha", L["Fill opacity"], { min = 0.1, max = 1, step = 0.05 }),
        BS("toggle", "smooth", L["Smooth bar changes"]),
        BS("toggle", "showText", L["Show value on the bar"]),
        BS("slider", "textSize", L["Font size"], { min = 6, max = 24, step = 1 }),
        BS("dropdown", "manaAbbrev", L["Mana number format"], { items = MANA_ITEMS }),
        BS("toggle", "manaPercent", L["Mana as percent"]),
        Note(L["Numbers are only printed while the game lets addons read them; the bar itself always moves."]),
    }
    local function add(s) list[#list + 1] = s end

    if #cand > 0 then
        add({ type = "header", label = L["Colors and conditions"] })
        for _, key in ipairs(cand) do
            -- 標籤直接用資源名（暴雪的官方譯名／法術名）
            add(BS("color", "colors." .. key .. ".color", R.Name(key), { hasAlpha = false }))
            if key == "ComboPoints" then
                add(BS("color", "colors.ComboPoints.chargedColor", L["Charged color"], { hasAlpha = false }))
                add(BS("color", "colors.ComboPoints.chargedEmptyColor", L["Charged (empty)"], { hasAlpha = false }))
                add(Note(L["Some combo points become charged (the Rogue's Supercharger, the Feral druid's Overflowing Power). The dim shade marks a charged point you haven't filled yet."]))
            elseif key == "Stagger" then
                -- 中度／重度的標籤是暴雪自己的減益名（中度醉仙緩勁、重度醉仙緩勁）
                add(BS("color", "colors.Stagger.moderateColor", R.StaggerLabel("moderate"), { hasAlpha = false }))
                add(BS("color", "colors.Stagger.heavyColor", R.StaggerLabel("heavy"), { hasAlpha = false }))
                add(BS("slider", "staggerModerateAt", L["Moderate threshold (percent of max health)"], { min = 1, max = 100, step = 1 }))
                add(BS("slider", "staggerHeavyAt", L["Heavy threshold (percent of max health)"], { min = 1, max = 200, step = 1 }))
                add(BS("slider", "staggerCeiling", L["Full bar at (percent of max health)"], { min = 10, max = 200, step = 5 }))
                add(Note(L["The color follows how much of your max health is staggered. In instanced combat the numbers are sometimes unreadable; those updates keep the previous color and bar scale."]))
            elseif key == "IgnorePain" then
                add(Note(L["Shows the total of every absorb shield on you, not just this one; a full bar is 30 percent of your max health."]))
            elseif key == "Ironfur" then
                add(Note(L["One segment per active application, each draining with its own remaining time."]))
            end
            if R.Info(key) and R.Info(key).mode == "auraTimer" then
                -- 剩餘時間條：秒數由引擎印（數值文字適用），條件規則不適用
                add(Note(L["%s: the game runs this timer itself, so it stays right in combat. The bar drains with the buff's remaining time and stays empty while you don't have it; showing the value on the bar prints the seconds left. Condition rules don't apply."]:format(R.Name(key))))
            elseif not R.SupportsConditions(key) then
                add(Note(L["%s: the game fills this row in itself, so it stays right in combat; condition rules and value text don't apply."]:format(R.Name(key))))
            end
        end
        -- 條件規則只給 Lua 讀得到值的列（引擎寫的沒有值可比）
        local condCand = Tab.ConditionCandidates(cand)
        if #condCand > 0 then ns.ResourceConditionsUI.Append(list, condCand) end
    end

    add({ type = "header", label = L["Show for this specialization"] })
    if #cand == 0 then
        add(Note(L["This specialization has no resource to show here."]))
    else
        for _, key in ipairs(cand) do
            local path = "rows." .. key
            add(BS("toggle", path, R.Name(key), {
                get = function() return R.RowOn(Cfg(), ns.specID, key) end,
                set = function(_, on)
                    local c = Cfg()
                    if not c then return end
                    if type(c.rows) ~= "table" then c.rows = {} end
                    -- 跟這個專精的預設一樣就存 nil（＝照預設），不一樣才存 true／false。
                    -- ⚠ 不能寫 `(not on) and false or nil`：`x and false or nil` 永遠是 nil，取消勾選等於沒存
                    on = on and true or false
                    if on == R.DefaultOn(ns.specID, key) then c.rows[key] = nil else c.rows[key] = on end
                end,
            }))
        end
    end

    add({ type = "header", label = L["Load conditions"] })
    add(BS("toggle", "loadConditions.hideMounted", L["Hide while mounted"]))
    add(Note(L["Mounted includes riding a vehicle."]))
    add(BS("toggle", "loadConditions.onlyCombat", L["Only in combat"]))
    add(BS("toggle", "fadeWithEssential", L["Fade with Essential Cooldowns"]))
    add(Note(L["Takes Essential Cooldowns' current opacity, including its visibility conditions and fades."]))

    for _, s in ipairs(ns.Specs.Anchor(KEY)) do add(s) end

    add({ type = "header", label = L["Reset"] })
    add(ResetRow(L["Restore defaults"], L["Restore resource defaults"],
        L["Restore the resource bar settings to their defaults?"], ResetAll))
    return list
end

------------------------------------------------------------
-- 頁面
------------------------------------------------------------
local currentSub = "class"        -- "class"（職業資源）| "pips"（自訂格子）

local function Signature()
    local cand, specID = ns.Resources.Candidates()
    local cfg = Cfg() or {}
    local p = ns.profile
    return table.concat({
        currentSub,
        tostring(specID), table.concat(cand, ","),
        ns.ResourceConditionsUI.FormSignature(Tab.ConditionCandidates(cand)),
        CustomSignature(),
        type(cfg.anchor) == "table" and "a" or "-",
        type(ns.DB.GetPath(ns.DB.ConfigTable(PIPS), "anchor")) == "table" and "pa" or "-",
        table.concat(p and p.barOrder or {}, ","),
        ns.Specs.AnchorGraphSig(),
    }, "|")
end
Tab.Signature = Signature

function Tab.Build(parent, title)
    local page, y = Options.NewPage(parent, title)
    local pad = Options.PAGE_PAD

    local note = page:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetTextColor(0.65, 0.65, 0.65)
    note:SetPoint("TOPLEFT", page, "TOPLEFT", pad + 2, y)
    note:SetWidth(Options.PAGE_W - 4)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(L["One row per resource, stacked; drag it in Edit Mode or anchor it to a bar below."])

    -- 兩個分頁：職業資源／自訂格子。分頁鈕放在頁標題右邊、同一列
    local subButtons = {}
    local prevBtn
    for i, def in ipairs({ { id = "class", label = L["Class Resources"] }, { id = "pips", label = L["Custom segments"] } }) do
        local b = W.CreateButton(page, def.label, "accent-hover", 80, 20)
        W.FitButton(b, 80, 20)
        b.id = def.id
        if prevBtn then
            b:SetPoint("LEFT", prevBtn, "RIGHT", 3, 0)
        else
            b:SetPoint("BOTTOMLEFT", page.head.text, "BOTTOMRIGHT", 14, -2)
        end
        prevBtn = b
        subButtons[i] = b
    end

    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    -- 職業資源分頁上面有一行說明；自訂格子分頁的說明在表單裡，表單直接貼標題線
    local function PlaceHolder()
        holder:ClearAllPoints()
        holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
        if currentSub == "pips" then
            note:Hide()
            holder:SetPoint("TOPLEFT", page, "TOPLEFT", pad, y)
        else
            note:Show()
            holder:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -2, -6)
        end
    end
    PlaceHolder()
    local scroll = W.CreateScrollFrame(holder)
    page.scroll = scroll
    local forms = {}

    local function OnApply(spec)
        ns.Resources.Apply()
        -- 自訂格子：清單、樣式（列高、格距…）與它自己的位置／錨定都在這一頁
        if ns.Pips then ns.Pips.Apply() end
        -- 顏色與條件規則（條件編輯器直接叫 ctx.apply，分不出是哪一格）：跟隨我們的插件重畫，合併節流
        if ns.NotifyResourceStyle then ns.NotifyResourceStyle() end
        if ns.EditMode and ns.EditMode.Editing() and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
        if ns.Fire then ns.Fire("BarsListChanged") end
        -- 形狀可能變了（規則增刪、錨定開關、開關列）：延一幀再比對，不在按鈕的處理器裡換表單
        ns.Defer(function()
            if page:IsVisible() and (page.sig ~= Signature() or (spec and spec.refreshPage)) then
                page:RefreshForm()
            end
        end)
    end

    function page:RefreshForm()
        if not Cfg() then return end
        local sig = Signature()
        local form = forms[sig]
        if not form then
            local ctx = ns.Specs.MakeCtx({ mode = "panel", key = KEY }, OnApply)
            form = ns.Specs.BuildForm(scroll.child, Controls((ns.Resources.Candidates()), currentSub), ctx, FORM_W)
            forms[sig] = form
        end
        for _, fm in pairs(forms) do fm.content:SetShown(fm == form) end
        -- 表單換了形狀（規則增刪、開關長出新列）：**維持原本的捲動位置**，只在第一次建這頁時歸零。
        -- 換表單就跳回最上面的話，按一下「新增規則」整頁飛走、玩家還得拉回來找自己在哪
        local keep = self.form and scroll:GetVerticalScroll() or 0
        if self.form ~= form and not self.form then scroll:SetVerticalScroll(0) end
        self.form, self.sig = form, sig
        scroll:SetContentHeight(form.height)
        if keep > 0 then
            local maxScroll = math.max(0, form.height - (scroll:GetHeight() or 0))
            scroll:SetVerticalScroll(math.min(keep, maxScroll))
        end
        form:Refresh()
    end

    local highlightSub
    function page:SetSub(sub)
        if sub ~= "pips" then sub = "class" end
        local changed = currentSub ~= sub
        currentSub = sub
        PlaceHolder()
        for _, b in ipairs(subButtons) do
            if b.id == sub and highlightSub then highlightSub(b) end
        end
        if changed then
            -- 換分頁：捲回最上面（同一個分頁裡換表單形狀才維持捲動位置）
            self.form = nil
        end
        self:RefreshForm()
    end
    highlightSub = W.CreateButtonGroup(subButtons, function(id) page:SetSub(id) end)

    function page:OnShowPage()
        self:SetSub(currentSub)
    end

    return page
end

Options.RegisterPage(KEY, Options.PageTitle(KEY), Tab.Build)

-- 專精／天賦換了、編輯模式拖完（拖了就脫離錨定）：開著的這一頁照新的形狀重讀
local function Reread()
    local page = Options.GetPage(KEY)
    if page and page:IsVisible() and page.RefreshForm then
        ns.Defer(function() page:RefreshForm() end)
    end
end
ns.RegisterCallback("SpecChanged", "tab_resources", Reread)
ns.RegisterCallback("BarMoved", "tab_resources", function(key) if key == KEY or key == PIPS then Reread() end end)
