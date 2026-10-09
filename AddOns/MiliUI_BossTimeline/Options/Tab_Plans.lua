------------------------------------------------------------
-- 「自訂時間軸」分頁：替首領排自己的提示
--
-- 一張表：每一列一條，照「開戰後第幾秒」排。兩種列混在一起照時間排：
--   * 自己的提示（白字）—— 可以編輯、刪除
--   * 上一場的紀錄（灰字、鎖頭）—— 唯讀：暴雪的首領技能、其他插件加的條。
--     暴雪的技能名稱戰鬥中是秘密值、存不下來，只看得到「這一秒有一個暴雪事件、倒數多久」；
--     它們的用途是讓玩家把自己的提示對齊上去，所以唯讀列有一顆「以此新增」，
--     會把那一秒帶進新增視窗。
--
-- 骨架階段先做清單編輯；拖拉式的時間軸編輯器是下一步（資料格式已經是秒數，換畫法不用遷移）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P
local Plans = ns.Plans

local tab, planDD, diffDD, enabledCB, showRecCB, list, emptyText, statusText
local btnRename, btnDelete, btnTest, btnStop, btnAdd, recNote
local planPopup, renamePopup, entryPopup, deletePopup
local currentID
local showRecorded = true

local ROW_H = 24
local LIST_X, LIST_W = 16, 748

-- 欄位 x（列內座標）
local COL = { time = 8, icon = 70, text = 94, lead = 470, src = 530, btn = 652 }

local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"

------------------------------------------------------------
-- 清單資料
------------------------------------------------------------
local function Items()
    local items = {}
    local plan = Plans.Get(currentID)
    if plan then
        for i, e in ipairs(plan.entries) do
            items[#items + 1] = { kind = "entry", index = i, entry = e, t = e.t or 0 }
        end
    end
    local rec = showRecorded and currentID and ns.db.recorded[currentID]
    if rec then
        for _, ev in ipairs(rec.events) do
            items[#items + 1] = { kind = "recorded", ev = ev, t = ev.t or 0 }
        end
    end
    -- 同一秒：自己的排在前面（玩家的眼睛先找自己的）
    table.sort(items, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.kind == "entry" and b.kind ~= "entry"
    end)
    return items
end

------------------------------------------------------------
-- 彈窗
------------------------------------------------------------
local function OpenEntryPopup(values, index)
    entryPopup:Open(values, function(v)
        local t = Plans.ParseTime(v.t)
        if not t or t <= 0 then
            ns.Print(L["Time must look like 1:30 or 90."])
            return false
        end
        local lead = tonumber(v.lead)
        Plans.SaveEntry(currentID, {
            t     = t,
            text  = v.text,
            spell = tonumber(v.spell),
            icon  = tonumber(v.icon),
            lead  = lead and math.max(1, lead) or nil,
        }, index)
        ns.Fire("PlansChanged")
    end, index and L["Edit reminder"] or L["Add reminder"])
end

local function EntryValues(e)
    return {
        t     = Plans.FormatTime(e.t),
        spell = e.spell or "",
        text  = e.text or "",
        lead  = e.lead or Plans.DEFAULT_LEAD,
        icon  = e.icon or "",
    }
end

local function CreatePopups()
    local parent = ns.Options.panel

    planPopup = W.CreateInputPopup(parent, 380, L["Add a boss"], {
        { key = "id",   label = L["Encounter ID"],
          hint = L["The ID from the boss fight itself, not the Adventure Guide. After one pull the last boss you fought is filled in for you."] },
        { key = "name", label = L["Name"] },
    })

    renamePopup = W.CreateInputPopup(parent, 340, L["Rename"], {
        { key = "name", label = L["Name"] },
    })

    entryPopup = W.CreateInputPopup(parent, 400, L["Add reminder"], {
        { key = "t",     label = L["When (time into the fight)"], hint = L["1:30 or 90 both mean 90 seconds after the pull."] },
        { key = "spell", label = L["Spell ID (optional)"], hint = L["Icon and name come from the spell."] },
        { key = "text",  label = L["Text (blank = spell name)"] },
        { key = "lead",  label = L["Seconds on the timeline before it happens"] },
        { key = "icon",  label = L["Icon ID (optional, used without a spell)"] },
    })

    deletePopup = W.CreateConfirmPopup(parent, 320, L["Delete this boss's custom timeline?"], function()
        if currentID then
            Plans.Delete(currentID)
            currentID = nil
            ns.Fire("PlansChanged")
        end
    end)
end

------------------------------------------------------------
-- 清單列
------------------------------------------------------------
local function Font(row, x, w, justify)
    local fs = row:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("LEFT", row, "LEFT", x, 0)
    fs:SetWidth(w)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function BuildRow(row)
    row.time = Font(row, COL.time, 58, "RIGHT")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row, "LEFT", COL.icon, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.text = Font(row, COL.text, COL.lead - COL.text - 8)
    row.lead = Font(row, COL.lead, 52, "RIGHT")
    row.src  = Font(row, COL.src, COL.btn - COL.src - 8)
    row.src:SetFontObject(W.fontSmall)

    row.edit = W.CreateButton(row, L["Edit"], "normal", 44, 18)
    row.edit:SetPoint("LEFT", row, "LEFT", COL.btn, 0)
    row.edit:SetScript("OnClick", function()
        local it = row.item
        if it and it.kind == "entry" then OpenEntryPopup(EntryValues(it.entry), it.index) end
    end)

    row.del = W.CreateButton(row, L["Delete"], "red", 44, 18)
    row.del:SetPoint("LEFT", row.edit, "RIGHT", 4, 0)
    row.del:SetScript("OnClick", function()
        local it = row.item
        if it and it.kind == "entry" then
            Plans.RemoveEntry(currentID, it.index)
            ns.Fire("PlansChanged")
        end
    end)

    -- 唯讀列：以這一秒新增一條自己的提示
    row.copy = W.CreateButton(row, L["Add at this time"], "normal", 92, 18)
    W.FitButton(row.copy, 92, 18)
    row.copy:SetPoint("LEFT", row, "LEFT", COL.btn, 0)
    row.copy:SetScript("OnClick", function()
        local it = row.item
        if not (it and it.kind == "recorded") then return end
        OpenEntryPopup({
            t    = Plans.FormatTime(it.ev.t),
            text = it.ev.src ~= "blizzard" and it.ev.text or "",
            lead = Plans.DEFAULT_LEAD,
        })
    end)
end

local function UpdateRow(row, it)
    row.item = it
    if it.kind == "entry" then
        local e = it.entry
        local icon, text = Plans.Resolve(e)
        local on = e.enabled ~= false
        row.time:SetText(Plans.FormatTime(e.t))
        row.icon:SetTexture(icon)
        row.icon:SetDesaturated(not on)
        row.text:SetText(text)
        row.lead:SetText(("%ds"):format(e.lead or Plans.DEFAULT_LEAD))
        row.src:SetText("|cff55ff55" .. L["Mine"] .. "|r")
        local c = on and 1 or 0.5
        row.time:SetTextColor(c, c, c)
        row.text:SetTextColor(c, c, c)
        row.lead:SetTextColor(c, c, c)
        row.edit:Show()
        row.del:Show()
        row.copy:Hide()
    else
        local ev = it.ev
        row.time:SetText(Plans.FormatTime(ev.t))
        if ev.src == "blizzard" then
            row.icon:SetTexture(LOCK_ICON)
            row.text:SetText(L["Blizzard ability (name hidden by the game)"])
            row.src:SetText("|cffff7f00" .. L["Blizzard"] .. "|r")
        else
            row.icon:SetTexture(LOCK_ICON)
            row.text:SetText(ev.text or "?")
            row.src:SetText("|cff66ccff" .. ns.Owners.Label(ev.owner) .. "|r")
        end
        row.icon:SetDesaturated(false)
        row.lead:SetText(ev.d and ("%ds"):format(ev.d) or "")
        row.time:SetTextColor(0.6, 0.6, 0.6)
        row.text:SetTextColor(0.6, 0.6, 0.6)
        row.lead:SetTextColor(0.6, 0.6, 0.6)
        row.edit:Hide()
        row.del:Hide()
        row.copy:Show()
    end
end

------------------------------------------------------------
-- 重畫整頁
------------------------------------------------------------
local function PlanItems()
    local items = {}
    for _, p in ipairs(Plans.List()) do
        items[#items + 1] = { text = ("%s  |cff9d9d9d%d|r"):format(p.plan.name or "?", p.id), value = p.id }
    end
    return items
end

local function Refresh()
    if not tab then return end
    local plans = Plans.List()
    if not Plans.Get(currentID) then
        currentID = plans[1] and plans[1].id or nil
    end
    planDD:SetItems(PlanItems())
    planDD:SetSelectedValue(currentID)

    local plan = Plans.Get(currentID)
    local has = plan ~= nil
    for _, w in ipairs({ planDD, diffDD, enabledCB, btnRename, btnDelete, btnTest, btnAdd, list, showRecCB }) do
        w:SetShown(has)
    end
    emptyText:SetShown(not has)

    local running = ns.Scheduler.Running()
    btnStop:SetShown(running and running.test and true or false)

    if not has then
        statusText:SetText("")
        recNote:SetText("")
        return
    end
    enabledCB:SetChecked(plan.enabled ~= false)
    diffDD:SetSelectedValue(plan.difficulty or 0)
    showRecCB:SetChecked(showRecorded)

    if running and running.test and running.id == currentID then
        statusText:SetText("|cffffd200" .. L["Testing — watch the timeline on screen."] .. "|r")
    else
        statusText:SetText("")
    end

    local rec = ns.db.recorded[currentID]
    if rec then
        recNote:SetText(L["Gray rows are from your last pull (%s, %s). They can't be edited."]:format(
            Plans.DifficultyLabel(rec.difficulty), Plans.FormatTime(rec.duration or 0)))
    else
        recNote:SetText(L["No recorded pull for this boss yet. Fight it once and Blizzard's abilities show up here as gray rows."])
    end

    list:Update(Items(), UpdateRow)
end

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, L["Custom timelines"], ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    CreatePopups()

    -- 第一排：選首領、新增、改名、刪除
    local lbl = tab:CreateFontString(nil, "OVERLAY")
    lbl:SetFontObject(W.fontNormal)
    lbl:SetPoint("TOPLEFT", 18, -56)
    lbl:SetText(L["Boss"])

    planDD = W.CreateDropdown(tab, 260, {}, function(value)
        currentID = value
        Refresh()
    end)
    planDD:SetPoint("LEFT", lbl, "RIGHT", 10, 0)

    local btnNew = W.CreateButton(tab, L["Add a boss"], "primary", 90, 20)
    W.FitButton(btnNew, 90, 20)
    btnNew:SetPoint("LEFT", planDD, "RIGHT", 10, 0)
    btnNew:SetScript("OnClick", function()
        local last = ns.db.lastEncounter
        planPopup:Open({ id = last and last.id or "", name = last and last.name or "" }, function(v)
            local id = tonumber(v.id)
            if not id or id <= 0 then
                ns.Print(L["Encounter ID must be a number."])
                return false
            end
            local rec = ns.db.recorded[id]
            Plans.Ensure(id, v.name ~= "" and v.name or (rec and rec.name) or nil)
            currentID = id
            ns.Fire("PlansChanged")
        end)
    end)

    btnRename = W.CreateButton(tab, L["Rename"], "normal", 70, 20)
    W.FitButton(btnRename, 70, 20)
    btnRename:SetPoint("LEFT", btnNew, "RIGHT", 6, 0)
    btnRename:SetScript("OnClick", function()
        local plan = Plans.Get(currentID)
        if not plan then return end
        renamePopup:Open({ name = plan.name }, function(v)
            if v.name == "" then return false end
            plan.name = v.name
            ns.Fire("PlansChanged")
        end)
    end)

    btnDelete = W.CreateButton(tab, L["Delete"], "red", 70, 20)
    W.FitButton(btnDelete, 70, 20)
    btnDelete:SetPoint("LEFT", btnRename, "RIGHT", 6, 0)
    btnDelete:SetScript("OnClick", function() deletePopup:Show() end)

    -- 第二排：啟用、難度、測試
    enabledCB = W.CreateCheckButton(tab, L["Enabled"], function(checked)
        local plan = Plans.Get(currentID)
        if plan then plan.enabled = checked end
    end)
    enabledCB:SetPoint("TOPLEFT", 18, -86)

    local diffLbl = tab:CreateFontString(nil, "OVERLAY")
    diffLbl:SetFontObject(W.fontNormal)
    diffLbl:SetPoint("TOPLEFT", 150, -88)
    diffLbl:SetText(L["Difficulty"])
    local diffItems = {}
    for _, d in ipairs(Plans.DIFFICULTIES) do diffItems[#diffItems + 1] = { text = L[d.label], value = d.value } end
    diffDD = W.CreateDropdown(tab, 160, diffItems, function(value)
        local plan = Plans.Get(currentID)
        if plan then plan.difficulty = value end
    end)
    diffDD:SetPoint("LEFT", diffLbl, "RIGHT", 10, 0)

    btnTest = W.CreateButton(tab, L["Test now"], "normal", 80, 20)
    W.FitButton(btnTest, 80, 20)
    btnTest:SetPoint("LEFT", diffDD, "RIGHT", 16, 0)
    btnTest:SetScript("OnClick", function()
        ns.Scheduler.Test(currentID)
    end)
    btnStop = W.CreateButton(tab, L["Stop"], "red", 60, 20)
    W.FitButton(btnStop, 60, 20)
    btnStop:SetPoint("LEFT", btnTest, "RIGHT", 6, 0)
    btnStop:SetScript("OnClick", function() ns.Scheduler.Stop() end)

    statusText = tab:CreateFontString(nil, "OVERLAY")
    statusText:SetFontObject(W.fontSmall)
    statusText:SetPoint("LEFT", btnStop, "RIGHT", 10, 0)

    -- 表頭
    local head = CreateFrame("Frame", nil, tab)
    head:SetPoint("TOPLEFT", LIST_X, -114)
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
    Head(COL.time, 58, L["Time"], "RIGHT")
    Head(COL.text, 200, L["Reminder"])
    Head(COL.lead, 52, L["On timeline"], "RIGHT")
    Head(COL.src, 110, L["From"])

    list = W.CreateRowList(tab, LIST_W, 300, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", LIST_X, -134)

    -- 底下：新增、紀錄開關與說明
    btnAdd = W.CreateButton(tab, L["+ Add reminder"], "primary", 120, 22)
    W.FitButton(btnAdd, 120, 22)
    btnAdd:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -10)
    btnAdd:SetScript("OnClick", function()
        OpenEntryPopup({ lead = Plans.DEFAULT_LEAD })
    end)

    showRecCB = W.CreateCheckButton(tab, L["Show my last pull"], function(checked)
        showRecorded = checked
        Refresh()
    end)
    showRecCB:SetPoint("LEFT", btnAdd, "RIGHT", 20, 0)

    recNote = tab:CreateFontString(nil, "OVERLAY")
    recNote:SetFontObject(W.fontSmall)
    recNote:SetPoint("TOPLEFT", btnAdd, "BOTTOMLEFT", 0, -8)
    recNote:SetWidth(LIST_W)
    recNote:SetJustifyH("LEFT")

    emptyText = tab:CreateFontString(nil, "OVERLAY")
    emptyText:SetFontObject(W.fontNormal)
    emptyText:SetPoint("TOPLEFT", 18, -90)
    emptyText:SetWidth(LIST_W - 20)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetSpacing(4)
    emptyText:SetText(L["No custom timelines yet. Press \"Add a boss\" — after you have pulled a boss once, it is filled in for you."])
end

ns.RegisterCallback("ShowOptionsTab", "plansTab", function(id)
    if id ~= "plans" then
        if tab then tab:Hide() end
        return
    end
    Init()
    Refresh()
    tab:Show()
end)

ns.RegisterCallback("PlansChanged", "plansTab", Refresh)
ns.RegisterCallback("RecordedChanged", "plansTab", Refresh)
ns.RegisterCallback("SchedulerChanged", "plansTab", Refresh)
