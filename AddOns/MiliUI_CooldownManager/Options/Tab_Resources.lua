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
-- 「這個專精要顯示哪些」一列一個資源：勾選框（resources.rows[specID][key]，分專精）＋上移／下移
-- （resources.order，不分專精；移一下就把目前候選的完整順序寫回去，見 Modules/Resources.lua 的 R.MergeOrder）。
-- 血量列（Health）的設定在「顏色與條件」那一段：職業色、百分比、門檻換色（彈窗在 Options/HealthThresholds.lua）。
--
-- 資源清單跟著專精走、條件規則的列數跟著規則走，所以表單照「形狀」快取（專精、候選清單（含順序）、
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

local RUNE_TEXT_ITEMS = {
    { text = L["Seconds left on each rune"], value = "countdown" },
    { text = L["Ready runes count"],         value = "count" },
}

local ARCANE_SOUL_ITEMS = {
    { text = L["Seconds left"],       value = "seconds" },
    { text = L["Global cooldowns left"], value = "gcd" },
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
        ns.Picker.AddSpellsOpener(popup)
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

------------------------------------------------------------
-- 一筆一張卡：標題列（滿版）＋ 選項列（可摺疊）
--
-- 標題列：［本列顏色的直條］［拖曳點］［摺疊箭頭］［圖示］［法術名（大字）］［種類 · 法術 ID（灰字）］……［刪除］
--   * 點標題列 ＝ 摺疊／展開底下的選項（entry.collapsed，存檔；換表單 ⇒ 簽章帶它）
--   * 拖標題列 ＝ 排序：游標所在的位置畫一條插入線，放開就把這一筆搬過去（清單順序 ＝ 畫面上的列序）
-- 卡片的位置記在表單內容框上（content._cards），一份表單一份；插入線也掛在那裡。
-- 拖曳時捲軸會跟著游標捲（游標貼到捲動區上下緣）。
------------------------------------------------------------
local CARD_H   = 32
local CARD_GAP = 10
local LABEL_W  = ns.WidgetsEnv.LABEL_W or 128
local CTRL_GAP = 12               -- 共用層表單：標籤欄與控件欄的間距（Controls.lua 的 GAP）
local ARROW    = "Interface\\ChatFrame\\ChatFrameExpandArrow"

local drag                        -- { from, content, ctx, header, target }
local ghost

local function Cards(content)
    content._cards = content._cards or { list = {} }
    return content._cards
end

-- 游標在 content 座標系的 y（負值，跟 SetPoint 的 y 同一套）
local function CursorY(content)
    local top = content:GetTop()
    if not top then return nil end
    local _, cy = GetCursorPosition()
    return cy / content:GetEffectiveScale() - top
end

-- 插入位置 1..n+1：游標在第 i 張標題列中線以上 ⇒ 插在 i 前面
local function DropSlot(cards, cy)
    local n = #cards.list
    for i = 1, n do
        local c = cards.list[i]
        if c and cy > c.top - CARD_H / 2 then return i end
    end
    return n + 1
end

local function EnsureGhost()
    if ghost then return ghost end
    ghost = W.CreateFrame(nil, UIParent, 200, 26)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetBackdropColor(0.2, 0.2, 0.2, 0.95)
    ghost:SetBackdropBorderColor(W.Accent(1))
    ghost:EnableMouse(false)
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ns.P.Size(ghost.icon, 18, 18)
    ghost.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ghost.icon:SetPoint("LEFT", 5, 0)
    ghost.text = ghost:CreateFontString(nil, "OVERLAY")
    ghost.text:SetFontObject(W.fontNormal)
    ghost.text:SetPoint("LEFT", ghost.icon, "RIGHT", 6, 0)
    ghost:Hide()
    return ghost
end

-- 拖曳中每幀：鬼影跟著游標、插入線、貼邊自動捲動
local function DragUpdate()
    if not drag then return end
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    ghost:ClearAllPoints()
    ghost:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / s + 14, y / s)

    local sc = Tab.scroll
    if sc and sc.GetTop and sc:GetTop() then
        local ss = sc:GetEffectiveScale()
        local sy = y / ss
        local step
        if sy > sc:GetTop() - 24 then step = -8 elseif sy < sc:GetBottom() + 24 then step = 8 end
        if step then
            local range = sc.GetVerticalScrollRange and sc:GetVerticalScrollRange() or 0
            local v = math.max(0, math.min(range, (sc:GetVerticalScroll() or 0) + step))
            sc:SetVerticalScroll(v)
        end
    end

    local cards = Cards(drag.content)
    local cy = CursorY(drag.content)
    if not cy then return end
    local slot = DropSlot(cards, cy)
    drag.target = slot
    local lineY
    if slot <= #cards.list then
        lineY = cards.list[slot].top + CARD_GAP / 2
    else
        lineY = (cards.endY or cy) - 2
    end
    local line = cards.line
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", drag.content, "TOPLEFT", cards.left or 4, lineY + 1)
    line:SetSize(cards.width or 300, 2)
    -- 放回原位（自己前後）不算移動：線就不畫
    line:SetShown(slot ~= drag.from and slot ~= drag.from + 1)
end

local function StopDrag(commit)
    local d = drag
    drag = nil
    if ghost then
        ghost:SetScript("OnUpdate", nil)
        ghost:Hide()
    end
    if not d then return end
    local cards = Cards(d.content)
    if cards.line then cards.line:Hide() end
    d.header:SetAlpha(1)
    local to = d.target
    if not (commit and to) or to == d.from or to == d.from + 1 then return end
    local list = CustomList()
    if not (list and list[d.from]) then return end
    local e = table.remove(list, d.from)
    if to > d.from then to = to - 1 end
    table.insert(list, to, e)
    Changed(d.ctx)
end

local function StartDrag(header, i, content, ctx)
    local e = CustomEntry(i)
    if not e then return end
    local cards = Cards(content)
    if not cards.line then
        local line = content:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetColorTexture(W.Accent(1))
        line:Hide()
        cards.line = line
    end
    drag = { from = i, content = content, ctx = ctx, header = header }
    header:SetAlpha(0.45)
    local g = EnsureGhost()
    g.icon:SetTexture(SpellIcon(e.spellID))
    g.text:SetText(SpellLabel(e.spellID))
    local tw = g.text:GetStringWidth()
    ns.P.Size(g, math.max(80, (type(tw) == "number" and tw or 60) + 40), 26)
    g:SetScript("OnUpdate", DragUpdate)
    g:Show()
    DragUpdate()
end

-- 標題列：滿版（從表單左緣畫到右緣，蓋過標籤欄）
local function CustomCardHeader(i)
    return function(parent, x, y, width, ctx)
        local left = x - LABEL_W - CTRL_GAP
        local fullW = width + LABEL_W + CTRL_GAP
        local cards = Cards(parent)
        cards.left, cards.width = left, fullW
        cards.list[i] = { top = y }

        local h = CreateFrame("Button", nil, parent, "BackdropTemplate")
        W.Stylize(h, { 0.17, 0.17, 0.17, 0.95 }, { 0, 0, 0, 1 })
        ns.P.Size(h, fullW, CARD_H)
        h:SetPoint("TOPLEFT", parent, "TOPLEFT", left, y)
        h:RegisterForClicks("LeftButtonUp")
        h:RegisterForDrag("LeftButton")
        cards.list[i].header = h

        -- 本列顏色的直條：一眼對得上畫面上哪一列
        local strip = h:CreateTexture(nil, "ARTWORK")
        strip:SetPoint("TOPLEFT", 1, -1)
        strip:SetPoint("BOTTOMLEFT", 1, 1)
        strip:SetWidth(3)

        -- 拖曳點：兩行三列的小方點
        for col = 0, 1 do
            for row = -1, 1 do
                local d = h:CreateTexture(nil, "ARTWORK")
                d:SetColorTexture(0.55, 0.55, 0.55, 1)
                ns.P.Size(d, 2, 2)
                d:SetPoint("CENTER", h, "LEFT", 11 + col * 4, row * 4)
            end
        end

        local arrow = h:CreateTexture(nil, "ARTWORK")
        arrow:SetTexture(ARROW)
        arrow:SetDesaturated(true)
        arrow:SetVertexColor(0.8, 0.8, 0.8)
        ns.P.Size(arrow, 12, 12)
        arrow:SetPoint("LEFT", h, "LEFT", 22, 0)

        local icon = h:CreateTexture(nil, "ARTWORK")
        ns.P.Size(icon, 22, 22)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("LEFT", arrow, "RIGHT", 6, 0)

        local name = h:CreateFontString(nil, "OVERLAY")
        name:SetFontObject(W.fontTitle)
        name:SetTextColor(1, 1, 1)
        name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)

        local meta = h:CreateFontString(nil, "OVERLAY")
        meta:SetFontObject(W.fontSmall)
        meta:SetTextColor(0.6, 0.6, 0.6)
        meta:SetPoint("LEFT", name, "RIGHT", 10, -1)
        meta:SetJustifyH("LEFT")
        meta:SetWordWrap(false)

        local del = W.CreateButton(h, L["Delete"], "normal", 60, 20)
        W.FitButton(del, 60, 20)
        del:SetPoint("RIGHT", h, "RIGHT", -6, 0)
        meta:SetPoint("RIGHT", del, "LEFT", -8, -1)
        local confirm
        del:SetScript("OnClick", function()
            if not confirm then
                confirm = W.CreateConfirmPopup(Options.panel, 320, L["Remove this custom row?"], function()
                    if ns.Pips.RemoveCustomRow(Cfg(), ns.specID, i) then Changed(ctx) end
                end)
            end
            confirm:Show()
        end)

        -- 狀態只換明暗：滑過底色亮一階
        h:SetScript("OnEnter", function(self)
            if drag then return end
            self:SetBackdropColor(0.23, 0.23, 0.23, 0.95)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(name:GetText() or "", 1, 1, 1)
            GameTooltip:AddLine(L["Drag a title bar to reorder the rows; click it to show or hide its options."], 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.17, 0.17, 0.17, 0.95)
            GameTooltip:Hide()
        end)
        h:SetScript("OnClick", function(self)
            if self.dragging or self.justDragged then return end
            local e = CustomEntry(i)
            if not e then return end
            e.collapsed = (not e.collapsed) or nil
            Changed(ctx)
        end)
        h:SetScript("OnDragStart", function(self)
            self.dragging = true
            GameTooltip:Hide()
            StartDrag(self, i, parent, ctx)
        end)
        h:SetScript("OnDragStop", function(self)
            self.dragging = false
            self.justDragged = true
            C_Timer.After(0, function() self.justDragged = nil end)
            StopDrag(true)
        end)
        h:SetScript("OnHide", function(self)
            if drag and drag.header == self then StopDrag(false) end
        end)

        local function Refresh()
            local e = CustomEntry(i)
            if not e then return end
            icon:SetTexture(SpellIcon(e.spellID))
            name:SetText(SpellLabel(e.spellID))
            meta:SetText(((e.kind == "charges") and L["Charges"] or L["Stacks"]) .. "  ·  "
                .. L["Spell ID"] .. " " .. tostring(e.spellID))
            local r, g, b = ns.Pips.CustomColor(e)
            strip:SetColorTexture(r, g, b, 1)
            arrow:SetRotation(e.collapsed and 0 or math.rad(-90))
        end
        Refresh()
        return CARD_H, Refresh
    end
end

-- 最後一張卡的下緣（插入線放到最後面時畫在這裡）
local function CardsEnd(parent, x, y)
    Cards(parent).endY = y
    return 0
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

-- 這一列的高（entry.height；沒存 ＝ 預設 8）：原地套用不換表單
local function HeightSpec(i)
    return BS("slider", "customRows.height." .. i, L["Height"], {
        min = ns.Pips.HEIGHT_MIN, max = ns.Pips.HEIGHT_MAX, step = 1, noReset = true,
        get = function() return ns.Pips.CustomHeight(CustomEntry(i)) end,
        set = function(_, v)
            local e = CustomEntry(i)
            if e then e.height = math.floor(tonumber(v) or ns.Pips.CUSTOM_DEFAULT_HEIGHT) end
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
    add(Note(L["Track a spell's charges or an aura's stacks on you as rows of segments. By default they sit below Essential Cooldowns and push Utility Cooldowns down. Width and look follow the resource bar settings on the Class Resources tab, while each row sets its own color and height; each specialization keeps its own list."]))
    if not ns.specID then
        add(Note(L["Pick a specialization first."]))
        AppendPipsPlacement(list)
        return
    end
    local entries = CustomList() or {}
    local shown = 0
    for i, e in ipairs(entries) do
        if type(e) == "table" and ns.Pips.CUSTOM_KINDS[e.kind] and type(e.spellID) == "number" then
            add({ type = "space", h = shown > 0 and CARD_GAP or 4 })
            shown = shown + 1
            add({ type = "custom", h = CARD_H, noReset = true, build = CustomCardHeader(i) })
            if not e.collapsed then
                add({ type = "space", h = 4 })
                add({ type = "custom", label = "", h = CUSTOM_ROW_H, noReset = true, build = CustomOptionsRow(i, e.kind) })
                add(HeightSpec(i))
                add(ShowWhenSpec(i, e.kind))
            end
        end
    end
    if shown == 0 then
        add(Note(L["No custom segments for this specialization yet."]))
    else
        add({ type = "custom", h = 0, noReset = true, build = CardsEnd })
        add({ type = "space", h = 6 })
        add(Note(L["Drag a title bar to reorder the rows; click it to show or hide its options."]))
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

-- 表單簽章的一段：整份清單（種類＋法術＋摺疊）。標籤是建表單當下的法術名，所以清單內容一變就換一份
local function CustomSignature()
    local out = {}
    for _, e in ipairs(CustomList() or {}) do
        if type(e) == "table" then
            out[#out + 1] = tostring(e.kind) .. ":" .. tostring(e.spellID) .. (e.collapsed and "-" or "")
        end
    end
    return #out .. "=" .. table.concat(out, ",")
end
Tab.CustomSignature = CustomSignature

-- 條件規則編輯器的候選：引擎寫值的列（auraBar、auraTimer）與血量（秘密值）不列
function Tab.ConditionCandidates(cand)
    local out = {}
    for _, key in ipairs(cand or {}) do
        if ns.Resources.SupportsConditions(key) then out[#out + 1] = key end
    end
    return out
end

------------------------------------------------------------
-- 「這個專精要顯示哪些」：勾選框（同原本的開關）＋ 上移／下移
------------------------------------------------------------
local ROW_TOGGLE_H = 26
local ARROW_BTN_W, ARROW_BTN_H = 20, 18

-- 箭頭一律畫貼圖（不用「↑↓」字元：不是每個語系的字型都有那兩個字）
local function ArrowButton(parent, rotation)
    local b = W.CreateButton(parent, nil, "normal", ARROW_BTN_W, ARROW_BTN_H)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetTexture(ARROW)
    t:SetDesaturated(true)
    ns.P.Size(t, 10, 10)
    t:SetPoint("CENTER", 0, 0)
    t:SetRotation(rotation)
    b.arrow = t
    return b
end

local function SetArrowEnabled(b, on)
    b:SetEnabled(on)
    -- 停用只換明暗
    b.arrow:SetVertexColor(on and 0.85 or 0.35, on and 0.85 or 0.35, on and 0.85 or 0.35)
end

-- 把 key 往上（dir ＝ -1）或往下（+1）移一格：目前候選的完整順序寫進 order（別的專精排過的 key 留著）
local function MoveRow(ctx, key, dir)
    local c = Cfg()
    if not c then return end
    local R = ns.Resources
    local cand = R.Candidates()
    local list, at = {}, nil
    for i, k in ipairs(cand) do
        list[i] = k
        if k == key then at = i end
    end
    local to = at and at + dir
    if not (to and list[to]) then return end
    list[at], list[to] = list[to], list[at]
    c.order = R.MergeOrder(c.order, list)
    -- 候選順序進了表單簽章：換一份表單（延一幀，OnApply 裡比）
    Changed(ctx)
end

local function ShowRow(cand, i)
    local R = ns.Resources
    local key = cand[i]
    local first, last = i == 1, i == #cand
    return { type = "custom", label = R.Name(key), h = ROW_TOGGLE_H, noReset = true,
             build = function(parent, x, y, width, ctx)
        local cy = y - ROW_TOGGLE_H / 2
        local cb = W.CreateCheckButton(parent, nil, function(on)
            local c = Cfg()
            if not c then return end
            -- 存在這個專精底下（rows[specID][key]）：跟預設一樣就清掉（＝照預設），空的子表也清掉
            R.SetRow(c, ns.specID, key, on)
            Touched(ctx)
        end)
        cb:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        local up = ArrowButton(parent, math.rad(90))
        up:SetPoint("LEFT", parent, "TOPLEFT", x + 32, cy)
        local down = ArrowButton(parent, math.rad(-90))
        down:SetPoint("LEFT", up, "RIGHT", 3, 0)
        SetArrowEnabled(up, not first)
        SetArrowEnabled(down, not last)
        up:SetScript("OnClick", function() MoveRow(ctx, key, -1) end)
        down:SetScript("OnClick", function() MoveRow(ctx, key, 1) end)
        local function Refresh() cb:SetChecked(R.RowOn(Cfg(), ns.specID, key)) end
        Refresh()
        return ROW_TOGGLE_H, Refresh
    end }
end

-- 醉仙緩勁第 3／4 段的顏色：標籤是門檻本身（≥ N%），跟著滑桿改 ⇒ 標籤自己畫、Refresh 時重寫
-- （共用層的色票列標籤建好就固定，門檻放進表單簽章的話拖一次滑桿就多一份表單）
local TIER_ROW_H = 26
local function StaggerTierColorRow(tier)
    local R = ns.Resources
    return { type = "custom", h = TIER_ROW_H, noReset = true, build = function(parent, x, y, width, ctx)
        local cy = y - TIER_ROW_H / 2
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontNormal)
        fs:SetJustifyH("RIGHT")
        fs:SetWidth(LABEL_W)
        fs:SetPoint("RIGHT", parent, "TOPLEFT", x - CTRL_GAP, cy)
        local cp = W.CreateColorPicker(parent, nil, false, function(r, g, b)
            local c = Cfg()
            if not c then return end
            local colors = type(c.colors) == "table" and c.colors or {}
            c.colors = colors
            if type(colors.Stagger) ~= "table" then colors.Stagger = {} end
            colors.Stagger[tier .. "Color"] = { r = r, g = g, b = b, a = 1 }
            Touched(ctx)
        end)
        cp:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        local function Refresh()
            local c = Cfg()
            fs:SetText(R.StaggerLabel(tier, c))
            cp:SetColor(R.ResolveColor(c, "Stagger", tier .. "Color"))
        end
        Refresh()
        return TIER_ROW_H, Refresh
    end }
end

-- 血量門檻那一列：按鈕寫著目前筆數，點開是編輯器（Options/HealthThresholds.lua）
local function HealthThresholdRow()
    return { type = "custom", label = "", h = 30, noReset = true, build = function(parent, x, y)
        local btn = W.CreateButton(parent, L["Health thresholds"], "normal", 160, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local function UpdateText()
            btn:SetText(("%s  (%d)"):format(L["Health thresholds"], ns.HealthThresholds.Count()))
            W.FitButton(btn, 160, 22)
        end
        btn:SetScript("OnClick", function() ns.HealthThresholds.Open(UpdateText) end)
        UpdateText()
        return 30, UpdateText
    end }
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
    }
    local function add(s) list[#list + 1] = s end

    -- 「這個專精要顯示哪些」緊接在總開關下面：要看哪幾列、怎麼排是最先決定的事（使用者 2026-10-02 指定）
    add({ type = "header", label = L["Show for this specialization"] })
    if #cand == 0 then
        add(Note(L["This specialization has no resource to show here."]))
    else
        for i in ipairs(cand) do add(ShowRow(cand, i)) end
        add(Note(L["The arrows set the stacking order; it's shared by every specialization. Resources you never moved keep their default place below the ones you did."]))
    end

    for _, s in ipairs({
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
        BS("dropdown", "textFont", L["Font"], { items = ns.Specs.ElementFontItems,
            get = function() local c = Cfg(); return ns.Specs.InheritOr(c and c.textFont) end }),
        BS("slider", "textSize", L["Font size"], { min = 6, max = 24, step = 1 }),
        BS("dropdown", "manaAbbrev", L["Mana number format"], { items = MANA_ITEMS }),
        BS("toggle", "manaPercent", L["Mana as percent"]),
        Note(L["Numbers are only printed while the game lets addons read them; the bar itself always moves."]),
    }) do add(s) end

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
                -- 第 3／4 段：開關＋門檻＋顏色（標籤是門檻本身，見 StaggerTierColorRow）
                add(BS("toggle", "staggerTier3Enabled", L["Third tier"]))
                add(BS("slider", "staggerTier3At", L["Third tier threshold (percent of max health)"], { min = 1, max = R.STAGGER_CEILING_MAX, step = 1 }))
                add(StaggerTierColorRow("tier3"))
                add(BS("toggle", "staggerTier4Enabled", L["Fourth tier"]))
                add(BS("slider", "staggerTier4At", L["Fourth tier threshold (percent of max health)"], { min = 1, max = R.STAGGER_CEILING_MAX, step = 1 }))
                add(StaggerTierColorRow("tier4"))
                add(Note(L["The third and fourth tiers add colors above heavy stagger. Raise \"Full bar at\" above 100 to see them fill on the bar."]))
                add(BS("slider", "staggerCeiling", L["Full bar at (percent of max health)"], { min = 10, max = R.STAGGER_CEILING_MAX, step = 5 }))
                add(Note(L["The color follows how much of your max health is staggered. In instanced combat the numbers are sometimes unreadable; those updates keep the previous color and bar scale."]))
            elseif key == "Runes" then
                add(BS("dropdown", "runeText", L["Numbers on runes"], { items = RUNE_TEXT_ITEMS }))
                add(Note(L["Ready runes always line up on the left and recharging ones fill up on the right. With \"Show value on the bar\" on, pick one number: the seconds left on each recharging rune, or how many runes are ready in the middle."]))
                add(BS("toggle", "runeQueued", L["Count waiting runes"]))
                add(Note(L["Only three runes recharge at a time; the rest wait their turn. With this on, waiting runes also show the seconds until they're ready and fill up across the whole wait."]))
            elseif key == "IgnorePain" then
                add(Note(L["Shows only your own Ignore Pain shield, as a percent of how big it can get; the game fills it in itself, so it stays right in combat. Showing the value on the bar prints the percent. Until the bar is ready (for example right after logging in during combat) it falls back to the total of every absorb shield on you, where a full bar is 30 percent of your max health."]))
            elseif key == "MaelstromWeapon" then
                add(BS("toggle", "maelstromFold", L["Fold into 5 segments"]))
                add(Note(L["Stacks 6 to 10 fill the same 5 segments again on top, in the overflow color. Condition colors only apply to the first layer."]))
                add(BS("color", "colors.MaelstromWeapon.overflowColor", L["Overflow color"], { hasAlpha = false }))
            elseif key == "SoulShards" then
                add(Note(L["Destruction shows shard fragments: the segment that is filling up is a shade darker, and the number on the bar has one decimal."]))
            elseif key == "Essence" then
                add(Note(L["The next segment fills up as Essence recharges, a shade darker."]))
            elseif key == "ArcaneSoul" then
                add(BS("dropdown", "arcaneSoulText", L["Number on the bar"], { items = ARCANE_SOUL_ITEMS }))
                add(Note(L["Global cooldowns left counts how many more global cooldowns fit before the buff ends, and shows \"Last\" during the final one. It follows your haste; when haste changes in combat the count catches up after combat."]))
            elseif key == "Ironfur" then
                add(Note(L["One segment per active application, each draining with its own remaining time."]))
            elseif key == "Health" then
                add(BS("toggle", "healthClassColor", L["Use the class color for the fill"]))
                add(Note(L["While this is on, the color above isn't used."]))
                add(BS("toggle", "healthPercent", L["Health as percent"]))
                add(BS("toggle", "healthThresholdEnabled", L["Recolor below a threshold"]))
                add(Note(L["Once health drops below a threshold, the bar switches to that threshold's color. The game decides which side of the line you are on, so it also works in instanced combat."]))
                add(HealthThresholdRow())
            end
            local info = R.Info(key)
            if info and info.mode == "auraTimer" then
                -- 剩餘時間條：秒數由引擎印（數值文字適用），條件規則不適用
                add(Note(L["%s: the game runs this timer itself, so it stays right in combat. The bar drains with the buff's remaining time and stays empty while you don't have it; showing the value on the bar prints the seconds left. Condition rules don't apply."]:format(R.Name(key))))
            elseif not R.SupportsConditions(key) and not (info and (info.health or info.mode == "auraPct")) then
                -- 血量不印這句（條件規則不適用由門檻換色那段帶過）
                add(Note(L["%s: the game fills this row in itself, so it stays right in combat; condition rules and value text don't apply."]:format(R.Name(key))))
            end
        end
        -- 條件規則只給 Lua 讀得到值的列（引擎寫的沒有值可比）
        local condCand = Tab.ConditionCandidates(cand)
        if #condCand > 0 then ns.ResourceConditionsUI.Append(list, condCand) end
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
        -- 氣漩武器摺疊改了格數：條件規則的「第幾格」選單跟著換
        cfg.maelstromFold and "f" or "-",
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
    Tab.scroll = scroll           -- 自訂格子拖曳排序時貼邊自動捲動
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
