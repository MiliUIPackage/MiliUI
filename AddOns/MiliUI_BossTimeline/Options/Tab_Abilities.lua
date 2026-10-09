------------------------------------------------------------
-- 「首領技能」分頁：每個首領技能各自的顏色、音效、要不要顯示
--
-- 一列一個技能記錄（encounterEventID）：
--   圖示 名稱 #ID │ 時間軸顏色 │ 快到時顏色 │ 快到時音效 │ 施放時音效 │ 隱藏 │ 清除
-- 顏色與音效寫進暴雪官方的 C_EncounterEvents（Plans/Abilities.lua），暴雪的時間軸、
-- 本插件的時間軸（外觀 → 邊框使用技能在時間軸上的顏色）、DBM 讀到的都是同一份。
--
-- 首領 → 技能記錄的對應靠 MRT 時間軸（暴雪沒給這個欄位，見 Abilities.lua 檔頭）；
-- MRT 沒有的首領可以用法術名稱搜尋。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P
local A = ns.Abilities

local tab, bossDD, searchBox, list, note, emptyText
local currentID
local searchText = ""

local ROW_H = 26
local LIST_X, LIST_W = 16, 748
local COL = { icon = 6, name = 30, color = 268, highlight = 312, sndHl = 356, sndCast = 494, hide = 634, clear = 676 }
local UNSET = { r = 0.22, g = 0.22, b = 0.22, a = 1 }

------------------------------------------------------------
-- 首領清單：自訂時間軸、上一場紀錄、最近一場、這裡手動加的
------------------------------------------------------------
local function Bosses()
    local names = {}
    for id, plan in pairs(ns.db.plans) do names[id] = plan.name end
    for id, rec in pairs(ns.db.recorded) do names[id] = names[id] or rec.name end
    for id, name in pairs(ns.db.abilityBosses) do names[id] = names[id] or name end
    local last = ns.db.lastEncounter
    if last and last.id then names[last.id] = names[last.id] or last.name end
    local items = {}
    for id, name in pairs(names) do
        name = name or ns.Journal.NameFor(id)
        items[#items + 1] = { text = ("%s  |cff9d9d9d%d|r"):format(name or L["Boss"], id), value = id, sort = name or "" }
    end
    table.sort(items, function(a, b)
        if a.sort ~= b.sort then return a.sort < b.sort end
        return a.value < b.value
    end)
    return items
end

------------------------------------------------------------
-- 清單列
------------------------------------------------------------
local soundItems

local function PlayPreview(name)
    local path = ns.Media.Sound(name)
    if path then PlaySoundFile(path, "Master") end
end

local function BuildRow(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row, "LEFT", COL.icon, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("LEFT", row, "LEFT", COL.name, 0)
    row.name:SetWidth(COL.color - COL.name - 10)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    local function Id() return row.item and row.item.info.id end

    row.color = W.CreateColorPicker(row, "", false, function(r, g, b)
        if Id() then A.Set(Id(), "color", { r = r, g = g, b = b }) end
    end)
    row.color:SetPoint("LEFT", row, "LEFT", COL.color + 8, 0)

    row.highlight = W.CreateColorPicker(row, "", false, function(r, g, b)
        if Id() then A.Set(Id(), "highlight", { r = r, g = g, b = b }) end
    end)
    row.highlight:SetPoint("LEFT", row, "LEFT", COL.highlight + 8, 0)

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

    row.sndHl = W.CreateDropdown(row, 130, soundItems, function(value)
        if Id() then
            A.Set(Id(), "soundHighlight", value ~= "" and value or nil)
            PlayPreview(value)
        end
    end)
    row.sndHl:SetPoint("LEFT", row, "LEFT", COL.sndHl, 0)

    row.sndCast = W.CreateDropdown(row, 130, soundItems, function(value)
        if Id() then
            A.Set(Id(), "soundCast", value ~= "" and value or nil)
            PlayPreview(value)
        end
    end)
    row.sndCast:SetPoint("LEFT", row, "LEFT", COL.sndCast, 0)

    row.hide = W.CreateCheckButton(row, "", function(checked)
        if Id() then A.Set(Id(), "hide", checked or nil) end
    end)
    row.hide:SetPoint("LEFT", row, "LEFT", COL.hide + 10, 0)

    row.clear = W.CreateButton(row, L["Clear"], "normal", 52, 18)
    W.FitButton(row.clear, 52, 18)
    row.clear:SetPoint("LEFT", row, "LEFT", COL.clear, 0)
    row.clear:SetScript("OnClick", function()
        if Id() then A.Clear(Id()) end
    end)
end

local function UpdateRow(row, it)
    row.item = it
    local info = it.info
    local cfg = A.Get(info.id) or {}
    row.icon:SetTexture(info.icon or 134400)
    local name = info.name or (L["Spell"] .. " #" .. tostring(info.spell))
    local extra = "  |cff6f6f6f#" .. info.id .. "|r"
    if it.guessed then extra = extra .. " |cff9d9d9d" .. L["(not in MRT)"] .. "|r" end
    row.name:SetText(name .. extra)
    row.color:SetColor(cfg.color or UNSET)
    row.highlight:SetColor(cfg.highlight or UNSET)
    row.color.unset:SetShown(cfg.color == nil)
    row.highlight.unset:SetShown(cfg.highlight == nil)
    row.sndHl:SetSelectedValue(cfg.soundHighlight or "")
    row.sndCast:SetSelectedValue(cfg.soundCast or "")
    row.hide:SetChecked(cfg.hide and true or false)
    row.clear:SetShown(next(cfg) ~= nil)
end

------------------------------------------------------------
-- 重畫
------------------------------------------------------------
local function Refresh()
    if not tab then return end
    local bosses = Bosses()
    bossDD:SetItems(bosses)
    if not currentID then
        local last = ns.db.lastEncounter
        currentID = (last and last.id) or (bosses[1] and bosses[1].value)
    end
    bossDD:SetSelectedValue(currentID)

    if not A.Available() then
        list:Hide()
        emptyText:SetText(L["This game client has no boss ability settings API."])
        emptyText:Show()
        return
    end

    local items, viaMRT
    if searchText ~= "" then
        items = A.Search(searchText, 80)
        viaMRT = true
    elseif currentID then
        items, viaMRT = A.ForEncounter(currentID)
    else
        items = {}
    end

    if #items == 0 then
        list:Hide()
        if searchText ~= "" then
            emptyText:SetText(L["No boss ability matches that name."])
        elseif not currentID then
            emptyText:SetText(L["Pick a boss above, or add one by its encounter ID."])
        elseif not ns.MRTData.Available() then
            emptyText:SetText(L["Listing a boss's abilities needs MRT's timeline data. Install or enable MRT, or search by spell name above."])
        elseif not viaMRT then
            emptyText:SetText(L["MRT has no timeline for this boss. Search by spell name above instead."])
        else
            emptyText:SetText(L["No boss ability records found for this boss."])
        end
        emptyText:Show()
        return
    end
    emptyText:Hide()
    list:Show()
    list:Update(items, UpdateRow)
end

local function Init()
    if tab then return end
    soundItems = ns.Media.SoundItems()
    tab = ns.Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, L["Boss abilities"], ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    -- 第一排：首領、加首領、搜尋
    local lbl = tab:CreateFontString(nil, "OVERLAY")
    lbl:SetFontObject(W.fontNormal)
    lbl:SetPoint("TOPLEFT", 18, -56)
    lbl:SetText(L["Boss"])

    bossDD = W.CreateDropdown(tab, 240, {}, function(value)
        currentID = value
        searchText = ""
        searchBox:SetText("")
        Refresh()
    end)
    bossDD:SetPoint("LEFT", lbl, "RIGHT", 10, 0)

    local btnNew = W.CreateButton(tab, L["Add a boss"], "normal", 90, 20)
    W.FitButton(btnNew, 90, 20)
    btnNew:SetPoint("LEFT", bossDD, "RIGHT", 10, 0)
    btnNew:SetScript("OnClick", function()
        ns.BossPicker.Open(function(id, name)
            ns.db.abilityBosses[id] = name or ns.db.abilityBosses[id] or ns.Journal.NameFor(id) or tostring(id)
            currentID = id
            searchText = ""
            searchBox:SetText("")
            Refresh()
        end)
    end)

    local sLbl = tab:CreateFontString(nil, "OVERLAY")
    sLbl:SetFontObject(W.fontNormal)
    sLbl:SetPoint("LEFT", btnNew, "RIGHT", 24, 0)
    sLbl:SetText(L["Search"])
    searchBox = W.CreateEditBox(tab, 180, 20)
    searchBox:SetPoint("LEFT", sLbl, "RIGHT", 8, 0)
    local function Search()
        searchText = strtrim(searchBox:GetText() or "")
        searchBox:ClearFocus()
        Refresh()
    end
    searchBox:SetScript("OnEnterPressed", Search)
    local btnSearch = W.CreateButton(tab, L["Search"], "normal", 56, 20)
    W.FitButton(btnSearch, 56, 20)
    btnSearch:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    btnSearch:SetScript("OnClick", Search)

    -- 表頭
    local head = CreateFrame("Frame", nil, tab)
    head:SetPoint("TOPLEFT", LIST_X, -88)
    P.Size(head, LIST_W, 18)
    local function Head(x, w, text, justify)
        local fs = head:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(W.Accent(1))
        fs:SetPoint("LEFT", head, "LEFT", x, 0)
        fs:SetWidth(w)
        fs:SetJustifyH(justify or "LEFT")
        fs:SetText(text)
    end
    Head(COL.name, 200, L["Ability"])
    Head(COL.color, 44, L["Color"], "CENTER")
    Head(COL.highlight, 44, L["Soon"], "CENTER")
    Head(COL.sndHl, 130, L["Sound when it's about to happen"])
    Head(COL.sndCast, 130, L["Sound when it's cast"])
    Head(COL.hide, 40, L["Hide"], "CENTER")

    list = W.CreateRowList(tab, LIST_W, 320, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", LIST_X, -108)

    emptyText = tab:CreateFontString(nil, "OVERLAY")
    emptyText:SetFontObject(W.fontNormal)
    emptyText:SetPoint("TOPLEFT", LIST_X + 4, -116)
    emptyText:SetWidth(LIST_W - 8)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetSpacing(4)
    emptyText:Hide()

    note = tab:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -8)
    note:SetWidth(LIST_W)
    note:SetJustifyH("LEFT")
    note:SetSpacing(3)
    note:SetText(table.concat({
        L["Colors and sounds go through Blizzard's own boss ability settings: Blizzard's timeline, this addon's timeline (Appearance → Use the ability's timeline color) and DBM all see them. \"Soon\" is about 5 seconds before."],
        L["DBM sets colors and countdown sounds for the abilities it knows; yours are applied after it, so yours win. Clearing a row also clears DBM's setting until its next pull."],
        L["Hide only works on abilities recognized in combat (General → Recognizing boss abilities in combat)."],
    }, "\n"))
end

ns.RegisterCallback("ShowOptionsTab", "abilitiesTab", function(id)
    if id ~= "abilities" then
        if tab then tab:Hide() end
        return
    end
    Init()
    Refresh()
    tab:Show()
end)

ns.RegisterCallback("AbilitiesChanged", "abilitiesTab", function()
    if tab and tab:IsShown() then Refresh() end
end)
