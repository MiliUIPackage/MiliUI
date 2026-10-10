------------------------------------------------------------
-- 「資源條」頁（profile.resources；引擎在 Modules/Resources.lua）
--
-- 職業資源分頁：顯示 → 這個專精要顯示哪些 → 版面 → 外觀（所有資源的預設）→ 載入條件（騎乘隱藏、只在戰鬥中、
-- 跟核心技能一起淡）→「錨定」一節（跟條頁同一支 Specs.Anchor；key ＝ "resources"）→ 恢復預設。
-- 每種資源自己的東西（高、外觀、數字格式、顏色、醉仙緩勁／符文／氣漩／征戰聖擊／血量等職業特有的設定、
-- 條件規則）在那一列的「設定…」開的視窗裡（Options/ResourceSettings.lua）。
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
-- 每列右邊一顆「設定…」開那種資源的設定視窗（一次一個，開另一列就換內容）。
--
-- 資源清單跟著專精走，所以表單照「形狀」快取（專精、候選清單（含順序）、自訂格子清單、有沒有錨定、條清單）：
-- 形狀變了才另建一份、變回來就拿舊的（frame 刪不掉，每改一次重建一次就是洩漏）。
-- 形狀的比對延一幀做（不在按鈕的處理器裡換表單）。
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

-- 推薦下拉：接在「開啟天賦與法術書」右邊（紅框那格），選了就帶入法術 ID／層數上限。
-- 下拉而不是 W.Menu：W.Menu 的層級在彈窗（410）底下，下拉的清單開在 TOOLTIP 層。
-- 開著的那一份推薦清單掛在 dd.recs（每次開彈窗重算：專精、天賦、已加過的都會變）
local function RecLabel(r)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(r.spellID) or ("#" .. r.spellID)
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(r.spellID)
    local text = icon and ("|T%s:14:14:0:0:64:64:5:59:5:59|t %s"):format(icon, name) or name
    if r.kind == "stacks" and r.max then text = text .. " " .. L["(max %d)"]:format(r.max) end
    return text
end

local function AddRecommendDropdown(popup, kind)
    local opener
    for _, child in ipairs({ popup:GetChildren() }) do
        if type(child.GetText) == "function" and child:GetText() == L["Open talents & spellbook"] then opener = child end
    end
    if not opener then return end
    local dd
    dd = W.CreateDropdown(popup, 120, {}, function(i)
        local r = dd.recs and dd.recs[i]
        dd.text:SetText(L["Recommended"])
        if not r then return end
        popup.boxes.id:SetText(tostring(r.spellID))
        if popup.boxes.max and r.max then popup.boxes.max:SetText(tostring(r.max)) end
        ns.Picker.SetInputError(popup, nil)
    end)
    dd:SetPoint("TOPLEFT", opener, "TOPRIGHT", 8, -1)
    dd:SetPoint("RIGHT", popup, "RIGHT", -14, 0)
    popup:HookScript("OnHide", function() W.CloseDropdowns() end)
    function dd:Refresh()
        local recs = ns.Pips.CustomRecommendations(Cfg(), ns.playerClass, ns.specID, kind, ns.Pips.recommendProbe)
        dd.recs = recs
        if #recs == 0 then dd:Hide() return end
        local items = {}
        for i, r in ipairs(recs) do items[i] = { text = RecLabel(r), value = i } end
        dd:SetItems(items)
        dd.text:SetText(L["Recommended"])
        dd:Show()
    end
    popup.recommend = dd
end

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
        AddRecommendDropdown(popup, kind)
        inputPopups[kind] = popup
    end
    ns.Picker.SetInputError(popup, nil)
    if popup.recommend then popup.recommend:Refresh() end
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

-- 第二列：顏色；層數多「上限」（數字的開關與樣式在下面各自一列）
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
        local box
        if kind ~= "charges" then
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

-- 這一列的數字（entry.text = { show, size, font, outline }，Modules/Pips.lua 的 Pips.TextStyle）：
-- 充能列＝回充秒數、層數列＝引擎寫的層數。開關、大小、字型、描邊都是每一列自己的；原地套用不換表單。
-- 「跟隨」存 nil（沒存就是跟）：大小 0 ＝ 照列高、字型跟資源條的字型、描邊跟主題
local function TextTable(i, create)
    local e = CustomEntry(i)
    if not e then return nil end
    if type(e.text) ~= "table" then
        if not create then return nil end
        e.text = {}
    end
    return e.text
end

local function TextShowSpec(i)
    return BS("toggle", "customRows.textShow." .. i, L["Show number"], {
        noReset = true,
        get = function() return (ns.Pips.TextStyle(CustomEntry(i))) end,
        set = function(_, v)
            local t = TextTable(i, true)
            if t then t.show = v and true or false end
        end,
    })
end

local function TextSizeSpec(i)
    return BS("slider", "customRows.textSize." .. i, L["Number size"], {
        min = 0, max = ns.Pips.TEXT_SIZE_MAX, step = 1, noReset = true,
        get = function()
            local t = TextTable(i)
            local v = math.floor(tonumber(t and t.size) or 0)
            return v > 0 and v or 0
        end,
        set = function(_, v)
            local t = TextTable(i, true)
            if not t then return end
            v = math.floor(tonumber(v) or 0)
            t.size = (v > 0) and v or nil
        end,
    })
end

local function TextFontSpec(i)
    return BS("dropdown", "customRows.textFont." .. i, L["Number font"], {
        items = ns.Specs.ElementFontItems, noReset = true,
        get = function()
            local t = TextTable(i)
            return ns.Specs.InheritOr(t and t.font)
        end,
        set = function(_, v)
            local t = TextTable(i, true)
            if t then t.font = (type(v) == "string" and v ~= "" and v ~= ns.Media.INHERIT) and v or nil end
        end,
    })
end

local function OutlineItems()
    local items = { { text = L["Follow the theme"], value = ns.Media.INHERIT } }
    for _, it in ipairs(ns.Specs.OUTLINE_ITEMS) do items[#items + 1] = it end
    return items
end

local function TextOutlineSpec(i)
    return BS("dropdown", "customRows.textOutline." .. i, L["Number outline"], {
        items = OutlineItems, noReset = true,
        get = function()
            local _, _, _, outline = ns.Pips.TextStyle(CustomEntry(i))
            return outline
        end,
        set = function(_, v)
            local t = TextTable(i, true)
            if t then t.outline = (type(v) == "string" and v ~= ns.Media.INHERIT) and v or nil end
        end,
    })
end

-- 層數列的文字內容（entry.text.mode，Pips.TextMode）：跟資源條的鐵鬃那幾列同一組選項
local function TextModeSpec(i)
    return BS("dropdown", "customRows.textMode." .. i, L["Number on the bar"], {
        items = ns.ResourceSettings.AuraTextItems, noReset = true,
        get = function() return ns.Pips.TextMode(CustomEntry(i)) end,
        set = function(_, v)
            local t = TextTable(i, true)
            if t then t.mode = (v ~= "stacks" and ns.Resources.AURA_TEXT_MODES[v]) and v or nil end
        end,
    })
end

local function AppendTextSpecs(add, i, kind)
    add(TextShowSpec(i))
    if kind == "stacks" then
        add(TextModeSpec(i))
        add(Note(L["The game prints these numbers itself, so they stay right in combat."]))
    end
    add(TextSizeSpec(i))
    add(Note(L["0 sizes the number to the row height."]))
    add(TextFontSpec(i))
    add(TextOutlineSpec(i))
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
                AppendTextSpecs(add, i, e.kind)
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

-- 「顯示哪些」那種一列：勾選框＋上移／下移＋「設定」鈕（開那一列自己的設定視窗）。
-- 對外出借（Tab.OrderRow）：天空騎術頁的四列也用這一支，長相一致、不另抄一份。
--   o = { label, first, last, get() → bool, set(on, ctx), move(dir, ctx), open() }
function Tab.OrderRow(o)
    return { type = "custom", label = o.label, h = ROW_TOGGLE_H, noReset = true,
             build = function(parent, x, y, width, ctx)
        local cy = y - ROW_TOGGLE_H / 2
        local cb = W.CreateCheckButton(parent, nil, function(on) o.set(on, ctx) end)
        cb:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        local up = ArrowButton(parent, math.rad(90))
        up:SetPoint("LEFT", parent, "TOPLEFT", x + 32, cy)
        local down = ArrowButton(parent, math.rad(-90))
        down:SetPoint("LEFT", up, "RIGHT", 3, 0)
        SetArrowEnabled(up, not o.first)
        SetArrowEnabled(down, not o.last)
        up:SetScript("OnClick", function() o.move(-1, ctx) end)
        down:SetScript("OnClick", function() o.move(1, ctx) end)
        local sb = W.CreateButton(parent, L["Settings"], "normal", 70, 20)
        W.FitButton(sb, 70, 20)
        sb:SetPoint("LEFT", down, "RIGHT", 12, 0)
        sb:SetScript("OnClick", function() o.open() end)
        local function Refresh() cb:SetChecked(o.get() and true or false) end
        Refresh()
        return ROW_TOGGLE_H, Refresh
    end }
end

local function ShowRow(cand, i)
    local R = ns.Resources
    local key = cand[i]
    return Tab.OrderRow({
        label = R.Name(key), first = i == 1, last = i == #cand,
        get   = function() return R.RowOn(Cfg(), ns.specID, key) end,
        set   = function(on, ctx)
            local c = Cfg()
            if not c then return end
            -- 存在這個專精底下（rows[specID][key]）：跟預設一樣就清掉（＝照預設），空的子表也清掉
            R.SetRow(c, ns.specID, key, on)
            Touched(ctx)
        end,
        move  = function(dir, ctx) MoveRow(ctx, key, dir) end,
        -- 這一列自己的設定（高、外觀、數字、顏色、條件規則）：開一個小視窗（Options/ResourceSettings.lua）
        open  = function() ns.ResourceSettings.Open(key) end,
    })
end

local function Controls(cand, sub)
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
        add(Note(L["Height, look, colors and condition rules are set per resource: click Settings on its row."]))
    end

    for _, s in ipairs({
        { type = "header", label = L["Layout"] },
        BS("slider", "width", L["Width"], { min = 0, max = 600, step = 1 }),
        Note(L["0 matches the first row of Essential Cooldowns."]),
        BS("slider", "rowSpacing", L["Row spacing"], { min = -1, max = 12, step = 1 }),
        -- 條上數字的位移（所有資源列＋自訂格子共用）：字型的行高把下伸部留在底下，數字置中後看起來偏上
        BS("numbers", nil, L["Text offset"], { sub = "textOffset", path = false,
            resetPaths = { "textOffset.x", "textOffset.y" }, fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }),
        BS("slider", "segmentSpacing", L["Segment spacing"], { min = 0, max = 8, step = 1 }),
        Note(L["Segment spacing only affects point-style resources (Holy Power, combo points and the like)."]),
        BS("dropdown", "fillDirection", L["Fill direction"], { items = FILL_ITEMS }),
        Note(L["Right to left also lights point-style resources from the right: the first point is the rightmost segment."]),
        -- 外觀（預設）：每種資源可以在自己的設定視窗裡改用自己的外觀（resources.style[key]）
        { type = "header", label = L["Appearance (default for every resource)"] },
        Note(L["Each resource can use a different look in its own settings."]),
        BS("dropdown", "texture", L["Texture"], { items = ns.Specs.TextureItems }),
        BS("dropdown", "bgTexture", L["Background texture"], { items = ns.ResourceSettings.BgTextureItems,
            get = function() local c = Cfg(); return ns.Specs.InheritOr(c and c.bgTexture) end }),
        BS("slider", "barAlpha", L["Fill opacity"], { min = 0.1, max = 1, step = 0.05 }),
        BS("slider", "bgAlpha", L["Background opacity"], { min = 0, max = 1, step = 0.05 }),
        BS("toggle", "bgCustom", L["Custom background color"], { refreshPage = true }),
        BS("color", "bgColor", L["Background color"], { hasAlpha = false,
            disabled = function() local c = Cfg(); return not (c and c.bgCustom) end }),
        Note(L["Background opacity scales the default shade: 1 keeps it as is, 0 makes the empty part fully transparent. Without a custom color, the background follows each resource's color."]),
        -- 邊框（每格／每條的四邊）：自訂格子也照這兩個（Modules/Pips.lua）
        BS("slider", "borderSize", L["Border size"], { min = 0, max = 4, step = 1 }),
        BS("color", "borderColor", L["Border color"], { hasAlpha = true }),
        Note(L["0 removes the border. Custom segments use the same border."]),
        BS("toggle", "smooth", L["Smooth bar changes"]),
        BS("dropdown", "textFont", L["Font"], { items = ns.Specs.ElementFontItems,
            get = function() local c = Cfg(); return ns.Specs.InheritOr(c and c.textFont) end }),
        BS("slider", "textSize", L["Font size"], { min = 6, max = 24, step = 1 }),
        BS("dropdown", "textOutline", L["Number outline"], { items = OutlineItems,
            get = function() local c = Cfg(); return ns.Specs.InheritOr(c and c.textOutline) end }),
        Note(L["Numbers are only printed while the game lets addons read them; the bar itself always moves."]),
    }) do add(s) end

    add({ type = "header", label = L["Load conditions"] })
    add(BS("toggle", "loadConditions.hideMounted", L["Hide while mounted"]))
    add(Note(L["Mounted includes riding a vehicle."]))
    add(BS("toggle", "loadConditions.onlyCombat", L["Only in combat"]))
    add(BS("toggle", "fadeWithEssential", L["Fade with Essential Cooldowns"]))
    add(Note(L["Takes Essential Cooldowns' current opacity, including its visibility conditions and fades."]))

    for _, s in ipairs(ns.Specs.Anchor(KEY)) do add(s) end
    -- 天空騎術接力中：這個位置在天空騎術時由那個面板接手（只放灰字，不放按鈕；切換在天空騎術頁）
    if ns.Bars.SkyRelay and ns.Bars.SkyRelay() then
        add(Note(L["While skyriding, the skyriding bars take over this spot (Skyriding page, Position: Relay)."]))
    end

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
    Tab.scroll = scroll           -- 自訂格子拖曳排序時貼邊自動捲動
    local forms = {}

    local function OnApply(spec)
        ns.Resources.Apply()
        -- 自訂格子：清單、樣式（列高、格距…）與它自己的位置／錨定都在這一頁
        if ns.Pips then ns.Pips.Apply() end
        -- 外觀、恢復預設（顏色可能一起變）：跟隨我們顏色的插件重畫，合併節流
        if ns.NotifyResourceStyle then ns.NotifyResourceStyle() end
        if ns.EditMode and ns.EditMode.Editing() and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
        if ns.Fire then ns.Fire("BarsListChanged") end
        -- 形狀可能變了（自訂格子增刪、錨定開關、開關列）：延一幀再比對，不在按鈕的處理器裡換表單。
        -- 每種資源的設定視窗開著的話一起重讀（跟著全域外觀時顯示的是這一頁的值）
        ns.Defer(function()
            if page:IsVisible() and (page.sig ~= Signature() or (spec and spec.refreshPage)) then
                page:RefreshForm()
            end
            ns.ResourceSettings.Refresh()
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
            -- 換分頁：捲回最上面（同一個分頁裡換表單形狀才維持捲動位置）；每種資源的設定視窗屬於職業資源分頁
            self.form = nil
            ns.ResourceSettings.Close()
        end
        self:RefreshForm()
    end
    highlightSub = W.CreateButtonGroup(subButtons, function(id) page:SetSub(id) end)

    function page:OnShowPage()
        self:SetSub(currentSub)
    end

    -- 離開這一頁：每種資源的設定視窗一起收（它不是暴雪框，沒有別的地方會關它）
    page:HookScript("OnHide", function() ns.ResourceSettings.Close() end)

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
