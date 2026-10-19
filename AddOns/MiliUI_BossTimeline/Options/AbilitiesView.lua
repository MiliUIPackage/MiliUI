------------------------------------------------------------
-- 「首領」頁的【技能】區塊：這隻首領的技能清單，每個技能「設定」或「加提示」
--
-- 心智模型：選一隻首領 → 看到它的技能 → 每個技能可以「改樣子」（設定小窗）或「加提示」。
-- 首領、難度由「首領」頁（Tab_Plans）選；這裡只畫難度卡片裡面那一塊。
--
--   ┌────────────────────────────────────────────────────────────────┐
--   │ 對這隻首領的所有難度都有效。                 [搜尋____][搜尋] │
--   │ 技能                                   已設定               │
--   │ ── 階段一 › 梵克胡 ──────────────────────────────────────── │
--   │ [圖] 劇毒湧現 #744           ■ 音效 語音 隱藏  [設定][加提示] │
--   └────────────────────────────────────────────────────────────────┘
--
-- 2026-10-11 從「一列七個沒標籤的控件」改成「摘要＋設定鈕」：玩家看不出那些勾與色塊是什麼。
-- 設定本身在 Options/AbilityPopover.lua（有標籤、有說明）；清單只講「這個技能設了什麼」。
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
local NOTE_H = 30         -- 底下的說明灰字

-- 右邊兩顆鈕：離列右緣多遠（各自的左緣）
local COL_ADD = 64
local COL_SET = COL_ADD + 50
local COL_SUM = COL_SET + 150     -- 摘要欄的左緣

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
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("LEFT", row, "LEFT", 30, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -(COL_SUM + 8), 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- 摘要：色塊（設了顏色才顯示）＋ 文字標籤
    row.swatch = P.NoSnap(row:CreateTexture(nil, "ARTWORK"))     -- 色塊與 1px 黑框都不貼齊（P.NoSnap）
    row.swatch:SetSize(12, 12)
    row.swatch:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.swatch:SetPoint("LEFT", row, "RIGHT", -COL_SUM, 0)
    row.swatchEdge = P.NoSnap(row:CreateTexture(nil, "BORDER"))
    row.swatchEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.swatchEdge:SetVertexColor(0, 0, 0, 1)
    row.swatchEdge:SetPoint("TOPLEFT", row.swatch, "TOPLEFT", -P.Pixel(1), P.Pixel(1))
    row.swatchEdge:SetPoint("BOTTOMRIGHT", row.swatch, "BOTTOMRIGHT", P.Pixel(1), -P.Pixel(1))
    row.summary = row:CreateFontString(nil, "OVERLAY")
    row.summary:SetFontObject(W.fontSmall)
    row.summary:SetPoint("LEFT", row, "RIGHT", -COL_SUM, 0)
    row.summary:SetPoint("RIGHT", row, "RIGHT", -(COL_SET + 6), 0)
    row.summary:SetJustifyH("LEFT")
    row.summary:SetWordWrap(false)
    row.summary:SetTextColor(0.75, 0.75, 0.75)

    row.set = W.CreateButton(row, L["Settings"], "normal", 44, 18)
    W.FitButton(row.set, 44, 18)
    row.set:SetPoint("LEFT", row, "RIGHT", -COL_SET, 0)
    row.set:SetScript("OnClick", function()
        local it = row.item
        if it and it.info then
            ns.AbilityPopover.Open(it.info, { onAddReminder = view.encID and view.onAddReminder or nil })
        end
    end)
    Tip(row.set, L["Ability settings"], L["Its color on the timeline, a sound or speech when it's about to happen or is cast, or hide it."])

    row.add = W.CreateButton(row, L["Add reminder"], "normal", 58, 18)
    W.FitButton(row.add, 58, 18)
    row.add:SetPoint("LEFT", row, "RIGHT", -COL_ADD, 0)
    row.add:SetScript("OnClick", function()
        local it = row.item
        if it and it.info and view.onAddReminder then view.onAddReminder(it.info) end
    end)
    Tip(row.add, L["Add a reminder for this ability"],
        L["A reminder that follows this ability: your own words, a sound, speech or a boss warning. Switches to My reminders."])

    row.controls = { row.icon, row.name, row.summary, row.set, row.add }

    -- 分組標題（冒險指南的階段／小怪／多首領戰的各隻）
    row.header = row:CreateFontString(nil, "OVERLAY")
    row.header:SetFontObject(W.fontNormal)
    row.header:SetPoint("LEFT", row, "LEFT", 6, -2)
    row.header:SetPoint("RIGHT", row, "RIGHT", -6, -2)
    row.header:SetJustifyH("LEFT")
    row.header:SetWordWrap(false)
    row.header:SetTextColor(W.Accent(1))
    row.headerLine = P.NoSnap(row:CreateTexture(nil, "ARTWORK"))
    row.headerLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.headerLine:SetVertexColor(W.Accent(0.35))
    row.headerLine:SetHeight(P.Pixel(1))
    row.headerLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 1)
    row.headerLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 1)
end

local function UpdateRow(view, row, it)
    local isHeader = it.header ~= nil
    row.header:SetShown(isHeader)
    row.headerLine:SetShown(isHeader)
    for _, c in ipairs(row.controls) do c:SetShown(not isHeader) end
    row.swatch:SetShown(false)
    row.swatchEdge:SetShown(false)
    if isHeader then
        row.item = nil
        row.stripe:Hide()
        row.header:SetText(it.header)
        return
    end
    row.item = it
    local info = it.info
    local cfg = A.Get(info.id)
    row.icon:SetTexture(info.icon or 134400)
    local name = info.name or (L["Spell"] .. " #" .. tostring(info.spell))
    local extra = "  |cff6f6f6f#" .. info.id .. "|r"
    if it.tags then extra = extra .. "  |cff9d9d9d" .. it.tags .. "|r" end
    if it.how == "guess" or it.guessed then extra = extra .. " |cff9d9d9d" .. L["(guessed)"] .. "|r" end
    row.name:SetText(name .. extra)

    -- 摘要：設了顏色就畫那個顏色的小色塊，其餘用字
    local sum = A.Summary(cfg)
    local parts = {}
    local x = 0
    if sum and sum.color then
        local c = cfg.color or cfg.highlight
        row.swatch:SetVertexColor(c.r, c.g, c.b, 1)
        row.swatch:Show()
        row.swatchEdge:Show()
        x = 18
    end
    if sum and sum.sound then parts[#parts + 1] = L["sound"] end
    if sum and sum.tts then parts[#parts + 1] = L["speech"] end
    if sum and sum.hide then parts[#parts + 1] = "|cffff6060" .. L["hidden"] .. "|r" end
    row.summary:ClearAllPoints()
    row.summary:SetPoint("LEFT", row, "RIGHT", -COL_SUM + x, 0)
    row.summary:SetPoint("RIGHT", row, "RIGHT", -(COL_SET + 6), 0)
    row.summary:SetText(table.concat(parts, " "))
    row.add:SetShown(view.encID ~= nil and info.spell ~= nil)
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
    self.w = w
    P.Size(self.head, w, HEAD_H)
    local listH = h - TOP_H - HEAD_H - NOTE_H - 6
    P.Size(self.list, w, listH)
    self.note:SetWidth(w)
    self.empty:SetWidth(w - 8)
    self.scope:SetWidth(w - 240)
    if self.frame:IsShown() then self:Refresh() end
end

function AV.Create(parent, opts)
    local view = setmetatable({ parent = parent, search = "", w = 0 }, { __index = Mixin_ })
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
    view.scope:SetText(L["Applies to every difficulty of this boss."])

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

    -- 表頭
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -TOP_H)
    view.head = head
    local function Head(text, point, x)
        local fs = head:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(W.Accent(1))
        fs:SetText(text)
        fs:SetPoint("LEFT", head, point, x, 0)
        return fs
    end
    Head(L["Ability"], "LEFT", 30)
    Head(L["Customized"], "RIGHT", -COL_SUM)

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
    view.note:SetText(L["Abilities come from the Adventure Guide, grouped the same way; MRT's timeline adds the ones the guide doesn't list. Settings go through Blizzard's own boss ability settings, so Blizzard's timeline and DBM see them too."])

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
