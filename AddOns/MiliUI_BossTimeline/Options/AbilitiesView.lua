------------------------------------------------------------
-- 「首領」頁的【技能】區塊：這隻首領每個技能各自的顏色、音效、要不要顯示，以及「＋提醒」
--
-- 心智模型：選一隻首領 → 看到它的技能 → 每個技能可以「改樣子」或「加提醒」。
-- 首領、難度由「首領」頁（Tab_Plans）選；這裡只畫難度卡片裡面那一塊。
--
--   ┌────────────────────────────────────────────────────────────────┐
--   │ 對這隻首領的所有難度、所有設定檔都有效。         [搜尋____][搜尋] │
--   │ 技能                 顏色 快到 快到時音效 施放時音效 隱藏          │
--   │ ── 階段一 › 梵克胡 ──────────────────────────────────────────── │
--   │ [圖] 劇毒湧現 #744    ■    ■   [無 ▼]    [無 ▼]     □   [+] [×] │
--   └────────────────────────────────────────────────────────────────┘
--
-- 清單來自冒險指南（分組照手冊）、MRT 補（JournalAbilities.ForEncounter）；選了難度就只列
-- 冒險指南在這個難度有寫的技能。顏色與音效寫進暴雪官方的 C_EncounterEvents（Plans/Abilities.lua），
-- 不分難度、不分設定檔 —— 暴雪的設定本來就是跟著技能記錄走的，畫面上要講清楚。
--
-- 寬度跟著卡片走（側欄展開 / 收合差 150px）：右邊的控件錨在列的右緣，名稱欄吃剩下的。
--
--   view = AbilitiesView.Create(parent, { onAddReminder = function(info) end })
--   view:Place(x, y, w, h)    相對 parent 左上
--   view:Set(encounterID, difficultyID)
--   view:Refresh()
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P
local A = ns.Abilities

ns.AbilitiesView = {}
local AV = ns.AbilitiesView

local ROW_H = 26
local TOP_H = 26          -- 第一排（範圍說明＋搜尋）
local HEAD_H = 20
local NOTE_H = 44         -- 底下的說明灰字
local UNSET = { r = 0.22, g = 0.22, b = 0.22, a = 1 }

-- 欄位：離列右緣多遠（各欄的左緣）。寬的時候音效下拉給大一點
local function Columns(w)
    local dw = w >= 660 and 130 or 92
    local c = {}
    c.clear = 24
    c.add = c.clear + 28
    c.hide = c.add + 30
    c.sndCast = c.hide + 6 + dw
    c.sndHl = c.sndCast + 6 + dw
    c.soon = c.sndHl + 34
    c.color = c.soon + 34
    c.dw = dw
    return c
end

local soundItems

local function PlayPreview(name)
    local path = ns.Media.Sound(name)
    if path then PlaySoundFile(path, "Master") end
end

local function Tip(frame, title, body)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(title, 1, 1, 1)
        if body then GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------
-- 一列：技能列或分組標題列（同一個列池）
------------------------------------------------------------
local function BuildRow(view, row)
    local function Id() return row.item and row.item.info and row.item.info.id end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("LEFT", row, "LEFT", 30, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.color = W.CreateColorPicker(row, "", false, function(r, g, b)
        if Id() then A.Set(Id(), "color", { r = r, g = g, b = b }) end
    end)
    row.highlight = W.CreateColorPicker(row, "", false, function(r, g, b)
        if Id() then A.Set(Id(), "highlight", { r = r, g = g, b = b }) end
    end)

    -- 「未設定」要跟「設成深灰」分得出來：色塊上畫一條斜線（色票的「無」慣例），滑過說明
    local function MarkUnset(swatch)
        local slash = swatch:CreateTexture(nil, "OVERLAY")
        slash:SetTexture("Interface\\Buttons\\WHITE8X8")
        slash:SetVertexColor(0.85, 0.25, 0.25, 1)
        slash:SetSize(18, P.Scale(1.5))
        slash:SetPoint("CENTER")
        slash:SetRotation(math.rad(45))
        swatch.unset = slash
        swatch:HookScript("OnEnter", function(self)
            if not self.unset:IsShown() then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["Not set"], 1, 1, 1)
            GameTooltip:AddLine(L["Uses Blizzard's color, or DBM's if it set one. Click to pick your own."], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        swatch:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    MarkUnset(row.color)
    MarkUnset(row.highlight)

    row.sndHl = W.CreateDropdown(row, view.cols.dw, soundItems, function(value)
        if Id() then
            A.Set(Id(), "soundHighlight", value ~= "" and value or nil)
            PlayPreview(value)
        end
    end)
    row.sndCast = W.CreateDropdown(row, view.cols.dw, soundItems, function(value)
        if Id() then
            A.Set(Id(), "soundCast", value ~= "" and value or nil)
            PlayPreview(value)
        end
    end)

    row.hide = W.CreateCheckButton(row, "", function(checked)
        if Id() then A.Set(Id(), "hide", checked or nil) end
    end)

    -- ＋提醒：替這個技能加一條「跟著它」的提醒（切到【我的提醒】）
    row.add = W.CreateButton(row, "+", "normal", 24, 18)
    row.add:SetScript("OnClick", function()
        local it = row.item
        if it and it.info and view.onAddReminder then view.onAddReminder(it.info) end
    end)
    Tip(row.add, L["Add a reminder for this ability"],
        L["Creates a reminder that follows this ability and switches to My reminders."])

    -- 清除：中文字型可能沒有 ×，用貼圖
    row.clear = W.CreateButton(row, "", "normal", 20, 18)
    local x = row.clear:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(10, 10)
    x:SetPoint("CENTER")
    x:SetVertexColor(1, 0.8, 0.8)
    row.clear:SetScript("OnClick", function()
        if Id() then A.Clear(Id()) end
    end)
    Tip(row.clear, L["Clear"], L["Back to Blizzard's color and sound (or DBM's)."])

    row.controls = { row.icon, row.name, row.color, row.highlight, row.sndHl, row.sndCast, row.hide, row.add, row.clear }

    -- 分組標題（冒險指南的階段／小怪／多首領戰的各隻）
    row.header = row:CreateFontString(nil, "OVERLAY")
    row.header:SetFontObject(W.fontNormal)
    row.header:SetPoint("LEFT", row, "LEFT", 6, -2)
    row.header:SetPoint("RIGHT", row, "RIGHT", -6, -2)
    row.header:SetJustifyH("LEFT")
    row.header:SetWordWrap(false)
    row.header:SetTextColor(W.Accent(1))
    row.headerLine = row:CreateTexture(nil, "ARTWORK")
    row.headerLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.headerLine:SetVertexColor(W.Accent(0.35))
    row.headerLine:SetHeight(P.Scale(1))
    row.headerLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 1)
    row.headerLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 1)
end

-- 欄位錨點跟著寬度：列是回收再用的，寬度變了（側欄收合）才重錨
local function PlaceRow(view, row)
    if row.placedW == view.w then return end
    row.placedW = view.w
    local c = view.cols
    local function At(widget, off, dy)
        widget:ClearAllPoints()
        widget:SetPoint("LEFT", row, "RIGHT", -off, dy or 0)
    end
    At(row.color, c.color)
    At(row.highlight, c.soon)
    At(row.sndHl, c.sndHl)
    At(row.sndCast, c.sndCast)
    At(row.hide, c.hide)
    At(row.add, c.add)
    At(row.clear, c.clear)
    P.Size(row.sndHl, c.dw, 20)
    P.Size(row.sndCast, c.dw, 20)
    row.name:SetPoint("RIGHT", row, "RIGHT", -(c.color + 8), 0)
end

local function UpdateRow(view, row, it)
    PlaceRow(view, row)
    local isHeader = it.header ~= nil
    row.header:SetShown(isHeader)
    row.headerLine:SetShown(isHeader)
    for _, c in ipairs(row.controls) do c:SetShown(not isHeader) end
    if isHeader then
        row.item = nil
        row.stripe:Hide()
        row.header:SetText(it.header)
        return
    end
    row.item = it
    local info = it.info
    local cfg = A.Get(info.id) or {}
    row.icon:SetTexture(info.icon or 134400)
    local name = info.name or (L["Spell"] .. " #" .. tostring(info.spell))
    local extra = "  |cff6f6f6f#" .. info.id .. "|r"
    if it.tags then extra = extra .. "  |cff9d9d9d" .. it.tags .. "|r" end
    if it.how == "guess" or it.guessed then extra = extra .. " |cff9d9d9d" .. L["(guessed)"] .. "|r" end
    row.name:SetText(name .. extra)
    row.color:SetColor(cfg.color or UNSET)
    row.highlight:SetColor(cfg.highlight or UNSET)
    row.color.unset:SetShown(cfg.color == nil)
    row.highlight.unset:SetShown(cfg.highlight == nil)
    row.sndHl:SetSelectedValue(cfg.soundHighlight or "")
    row.sndCast:SetSelectedValue(cfg.soundCast or "")
    row.hide:SetChecked(cfg.hide and true or false)
    row.add:SetShown(view.encID ~= nil and info.spell ~= nil)
    row.clear:SetShown(next(cfg) ~= nil)
end

------------------------------------------------------------
-- 元件
------------------------------------------------------------
local Mixin_ = {}

function Mixin_:Set(encID, diff)
    self.encID, self.diff = encID, diff
    self:Refresh()
end

function Mixin_:Refresh()
    if not self.frame:IsShown() then return end
    local items, src
    if self.search ~= "" then
        items = A.Search(self.search, 80)
    elseif self.encID then
        items, src = A.ForEncounter(self.encID, self.diff)
    else
        items = {}
    end

    local msg
    if not A.Available() then
        msg = L["This game client has no boss ability settings API."]
    elseif #items == 0 then
        if self.search ~= "" then
            msg = L["No boss ability matches that name."]
        elseif src and not src.journal and not src.mrt then
            msg = L["Neither the Adventure Guide nor MRT lists this boss's abilities. Search by spell name above instead."]
        else
            msg = L["No boss ability records found for this boss."]
        end
    end
    self.empty:SetShown(msg ~= nil)
    self.list:SetShown(msg == nil)
    if msg then
        self.empty:SetText(msg)
        return
    end
    local view = self
    self.list:Update(items, function(row, it) UpdateRow(view, row, it) end)
end

function Mixin_:Place(x, y, w, h)
    local f = self.frame
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", self.parent, "TOPLEFT", x, y)
    P.Size(f, w, h)
    if self.w ~= w then
        self.w = w
        self.cols = Columns(w)
        local c = self.cols
        for key, fs in pairs(self.heads) do
            fs:ClearAllPoints()
            if key == "name" then
                fs:SetPoint("LEFT", self.head, "LEFT", 30, 0)
            else
                -- 色塊 14px、勾選框 22px：欄名置中在控件上；下拉的欄名靠左對齊下拉
                local center = (key == "color" or key == "soon") and 7 or (key == "hide" and 11) or nil
                if center then
                    fs:SetPoint("CENTER", self.head, "RIGHT", -c[key] + center, 0)
                else
                    fs:SetPoint("LEFT", self.head, "RIGHT", -c[key], 0)
                end
            end
        end
    end
    P.Size(self.head, w, HEAD_H)
    local listH = h - TOP_H - HEAD_H - NOTE_H - 6
    P.Size(self.list, w, listH)
    self.note:SetWidth(w)
    self.empty:SetWidth(w - 8)
    self.scope:SetWidth(w - 300)
    if self.frame:IsShown() then self:Refresh() end
end

function AV.Create(parent, opts)
    soundItems = soundItems or ns.Media.SoundItems()
    local view = setmetatable({ parent = parent, search = "", w = 0, cols = Columns(560) }, { __index = Mixin_ })
    view.onAddReminder = opts and opts.onAddReminder

    local f = CreateFrame("Frame", nil, parent)
    view.frame = f
    f:SetScript("OnShow", function() view:Refresh() end)

    -- 第一排：範圍說明（左）＋搜尋（右）
    view.scope = f:CreateFontString(nil, "OVERLAY")
    view.scope:SetFontObject(W.fontSmall)
    view.scope:SetTextColor(0.75, 0.75, 0.75)
    view.scope:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -4)
    view.scope:SetJustifyH("LEFT")
    view.scope:SetWordWrap(false)
    view.scope:SetText(L["Applies to every difficulty and every profile of this boss."])

    local btnSearch = W.CreateButton(f, L["Search"], "normal", 56, 20)
    W.FitButton(btnSearch, 56, 20)
    btnSearch:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    local box = W.CreateEditBox(f, 160, 20)
    box:SetPoint("RIGHT", btnSearch, "LEFT", -6, 0)
    local function Search()
        view.search = strtrim(box:GetText() or "")
        box:ClearFocus()
        view:Refresh()
    end
    box:SetScript("OnEnterPressed", Search)
    btnSearch:SetScript("OnClick", Search)
    Tip(btnSearch, L["Search all boss abilities"],
        L["For bosses the Adventure Guide and MRT don't list. Clear the box to go back to this boss."])
    view.searchBox = box

    -- 表頭（欄名有滑過說明：「顏色／快到」只看字猜不到是哪兩種顏色）
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -TOP_H)
    view.head = head
    view.heads = {}
    local function Head(key, text, tipTitle, tipBody)
        local fs = head:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(W.Accent(1))
        fs:SetText(text)
        view.heads[key] = fs
        if tipTitle then
            local hit = CreateFrame("Frame", nil, head)
            hit:SetAllPoints(fs)
            hit:EnableMouse(true)
            Tip(hit, tipTitle, tipBody)
        end
    end
    Head("name", L["Ability"])
    Head("color", L["Color"], L["Color"], L["The ability's color on the timeline."])
    Head("soon", L["Soon"], L["Soon"], L["The color it turns about 5 seconds before it happens."])
    Head("sndHl", L["Sound when it's about to happen"])
    Head("sndCast", L["Sound when it's cast"])
    Head("hide", L["Hide"], L["Hide"], L["Hide only works on abilities recognized in combat (General → Recognizing boss abilities in combat)."])

    view.list = W.CreateRowList(f, 400, 200, ROW_H, function(row) BuildRow(view, row) end)
    view.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)

    view.empty = f:CreateFontString(nil, "OVERLAY")
    view.empty:SetFontObject(W.fontNormal)
    view.empty:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 4, -8)
    view.empty:SetJustifyH("LEFT")
    view.empty:SetSpacing(4)
    view.empty:Hide()

    view.note = f:CreateFontString(nil, "OVERLAY")
    view.note:SetFontObject(W.fontSmall)
    view.note:SetTextColor(0.6, 0.6, 0.6)
    view.note:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    view.note:SetJustifyH("LEFT")
    view.note:SetSpacing(2)
    view.note:SetText(table.concat({
        L["Abilities come from the Adventure Guide and are grouped the same way; MRT's timeline adds the ones the guide doesn't list. \"(guessed)\" rows sit between this boss's own records."],
        L["Colors and sounds go through Blizzard's own boss ability settings, so Blizzard's timeline and DBM see them too. DBM's own colors are applied first; yours win."],
    }, "\n"))

    -- 法術名稱第一次可能還沒載下來：載到了重畫（合併成一次）
    local pending
    f:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    f:SetScript("OnEvent", function()
        if pending or not f:IsVisible() then return end
        pending = true
        C_Timer.After(0.3, function()
            pending = false
            view:Refresh()
        end)
    end)

    ns.RegisterCallback("AbilitiesChanged", "abilitiesView", function()
        if f:IsVisible() then view:Refresh() end
    end)

    f:Hide()
    return view
end
