------------------------------------------------------------
-- 「自訂時間軸」分頁：替首領排自己的提示
--
-- 一張表：每一列一條，照「開戰後第幾秒」排。幾種列混在一起照時間排：
--   * 自己的提示（白字）—— 可以編輯、刪除
--   * MRT 時間軸（灰字、金色來源）—— 唯讀：MRT 自帶的整場首領技能統計，有名稱有圖示
--     （資料見 Plans/MRTData.lua）；換階段的那一秒另有一列分隔
--   * 上一場的紀錄（灰字、鎖頭）—— 唯讀：暴雪的首領技能、其他插件加的條。
--     暴雪的技能名稱戰鬥中是秘密值、存不下來，只看得到「這一秒有一個暴雪事件、倒數多久」
-- 唯讀列的用途是讓玩家把自己的提示對齊上去，所以每一列都有「以此新增」，
-- 會把那一秒（MRT 列連法術一起）帶進新增視窗。
--
-- 另外可以整段貼上 MRT 筆記／lorrgs 的 {time:mm:ss} 提示行匯入（Plans.ImportNote）。
--
-- 拖拉式的時間軸編輯器是下一步（資料格式已經是秒數，換畫法不用遷移）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P
local Plans = ns.Plans
local MD = ns.MRTData

local tab, planDD, diffDD, enabledCB, list, emptyText, statusText, recNote
local btnRename, btnDelete, btnTest, btnStop, btnAdd, btnImport
local showRecCB, showMRTCB, mrtDD
local renamePopup, deletePopup, importPopup, exportPopup, reviewPopup
local btnExport, btnReview, btnPreview, btnUndo, keyCatcher, diffLbl
local head, editor, modeButtons, highlightMode
local currentID

local ROW_H = 24
local LIST_X, LIST_W = 16, 748

-- 欄位 x（列內座標）
local COL = { time = 8, icon = 70, text = 94, lead = 470, src = 530, btn = 652 }

local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local QUESTION_ICON = 134400

-- 同一秒的排序：自己的 → 換階段 → MRT → 上一場紀錄（玩家的眼睛先找自己的）
local KIND_ORDER = { entry = 1, phase = 2, mrt = 3, recorded = 4 }

local function View()
    return ns.db.planView
end

------------------------------------------------------------
-- 清單資料
------------------------------------------------------------
local function MRTVariant(plan)
    if not currentID or not MD.Has(currentID) then return end
    local idx = plan and plan.mrtVariant
    local variants = MD.Variants(currentID)
    if idx and variants[idx] then return idx end
    return MD.DefaultVariant(currentID, plan and plan.difficulty)
end

local function Items()
    local items = {}
    local plan = Plans.Get(currentID)
    if not plan then return items end
    for i, e in ipairs(plan.entries) do
        items[#items + 1] = { kind = "entry", index = i, entry = e, t = e.t or 0 }
    end
    if View().mrt then
        local v = MRTVariant(plan)
        if v then
            local nth = {}
            for _, ev in ipairs(MD.Events(currentID, v)) do
                nth[ev.spell] = (nth[ev.spell] or 0) + 1
                items[#items + 1] = { kind = "mrt", ev = ev, t = ev.t, n = nth[ev.spell] }
            end
            for _, ph in ipairs(MD.Phases(currentID, v)) do
                items[#items + 1] = { kind = "phase", phase = ph.phase, t = ph.t }
            end
        end
    end
    local rec = View().recorded and ns.db.recorded[currentID]
    if rec then
        for _, ev in ipairs(rec.events) do
            items[#items + 1] = { kind = "recorded", ev = ev, t = ev.t or 0 }
        end
    end
    table.sort(items, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return KIND_ORDER[a.kind] < KIND_ORDER[b.kind]
    end)
    return items
end

------------------------------------------------------------
-- 彈窗
------------------------------------------------------------
-- entry：要改的那一條（表的參考）。排序後 index 會變，所以存檔前才找它現在的位置
local function OpenEntryPopup(values, entry)
    ns.EntryEditor.Open(values, function(v)
        Plans.SaveEntry(currentID, v, entry and Plans.IndexOf(currentID, entry))
        ns.Fire("PlansChanged")
    end, entry and L["Edit reminder"] or L["Add reminder"], currentID)
end

local function EntryValues(e)
    local v = CopyTable(e)
    if e.anchor then v.anchorName = MD.SpellInfo(e.anchor.spell) end
    return v
end

-- 彈窗外殼：共用層的輸入彈窗只有單行欄位，這幾個（多行貼上、匯出、回顧）照它的遮罩／層級規則自己組
local function PopupShell(name, parent, w, h, titleText)
    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    local popup = W.CreateFrame(name, parent, w, h)
    W.CloseOnEscape(popup)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function() mask:Hide() end)

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOP", 0, -12)
    title:SetText(titleText)
    popup.title = title

    local hint = popup:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", 14, -36)
    hint:SetWidth(w - 28)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(2)
    popup.hint = hint
    return popup
end

-- 貼上匯入：米利字串（!MBT1!）或 MRT 筆記行，自動判斷
local function CreateImportPopup(parent)
    local W_, H_ = 560, 380
    local popup = PopupShell("MiliUIBT_ImportPopup", parent, W_, H_, L["Paste reminders"])
    popup.hint:SetText(L["Paste a MiliUI Boss Timeline string (starts with !MBT1!), or MRT note lines, one reminder per line: {time:01:30} {spell:31821} text. Times relative to a phase ({time:00:54,p2}) are not supported; turn off the dynamic timer when exporting from lorrgs."])

    local box = W.CreateScrollEditBox(popup, W_ - 28, H_ - 140)
    box:SetPoint("TOPLEFT", 14, -88)
    popup.box = box

    local ok = W.CreateButton(popup, L["Import"], "green", 90, 22)
    ok:SetPoint("BOTTOMLEFT", 26, 12)
    ok:SetScript("OnClick", function()
        local text = box.editBox:GetText() or ""
        if ns.Share.IsShareString(text) then
            local payload, err = ns.Share.Decode(text)
            if not payload then
                ns.Print(err)
                return
            end
            local added, skipped = ns.Share.Import(payload)
            currentID = payload.id
            ns.Print(L["Imported %d reminders into %s (%d were already there)."]:format(added, payload.name or tostring(payload.id), skipped))
            popup:Hide()
            ns.Fire("PlansChanged")
            return
        end
        if not Plans.Get(currentID) then
            ns.Print(L["Pick or add a boss first; MRT note lines don't say which boss they are for."])
            return
        end
        local added, skipped, phased = Plans.ImportNote(currentID, text)
        ns.Print(L["Imported %d, skipped %d, phase-relative (not supported) %d."]:format(added, skipped, phased))
        popup:Hide()
        if added > 0 then ns.Fire("PlansChanged") end
    end)
    local cancel = W.CreateButton(popup, L["Cancel"], "red", 90, 22)
    cancel:SetPoint("BOTTOMRIGHT", -26, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)

    function popup:Open()
        box.editBox:SetText("")
        self:Show()
        box.editBox:SetFocus()
    end

    popup:Hide()
    return popup
end

-- 匯出：兩種格式切換，複製框
local function CreateExportPopup(parent)
    local W_, H_ = 560, 320
    local popup = PopupShell("MiliUIBT_ExportPopup", parent, W_, H_, L["Export"])
    local format = "mbt"

    local function Text()
        if format == "note" then return ns.Share.ExportNote(currentID) end
        return ns.Share.Export(currentID) or L["This game client can't create share strings."]
    end

    local bMBT = W.CreateButton(popup, L["MiliUI string"], "accent-hover", 90, 20)
    local bNote = W.CreateButton(popup, L["MRT note lines"], "accent-hover", 90, 20)
    W.FitButton(bMBT, 90, 20)
    W.FitButton(bNote, 90, 20)
    bMBT.id, bNote.id = "mbt", "note"
    bMBT:SetPoint("TOPLEFT", 14, -34)
    bNote:SetPoint("LEFT", bMBT, "RIGHT", 3, 0)
    popup.hint:ClearAllPoints()
    popup.hint:SetPoint("TOPLEFT", 14, -62)

    local copy = W.CreateCopyBox(popup, W_ - 28, H_ - 150, Text, L["Select all"])
    copy:SetPoint("TOPLEFT", 14, -96)

    local function Show(id)
        format = id
        popup.hint:SetText(id == "note"
            and L["MRT note lines: time, spell and text only. MRT, DreamForgeTools and other addons that read this format can use it."]
            or L["Everything in this boss's custom timeline, including sounds, conditions and anchors. Paste it into Paste reminders on another character or for a friend."])
        copy:Refresh()
    end
    local highlight = W.CreateButtonGroup({ bMBT, bNote }, Show)

    local close = W.CreateButton(popup, L["Okay"], "normal", 90, 22)
    close:SetPoint("BOTTOM", 0, 12)
    close:SetScript("OnClick", function() popup:Hide() end)

    function popup:Open()
        self:Show()
        highlight(format == "note" and bNote or bMBT)
        Show(format)
    end

    popup:Hide()
    return popup
end

-- 戰後回顧：錨點提示 上一場實際 vs 備援時間；一鍵套用、整份平移
local function CreateReviewPopup(parent)
    local W_, H_ = 600, 420
    local popup = PopupShell("MiliUIBT_ReviewPopup", parent, W_, H_, L["Review last pull"])
    popup.hint:SetText(L["Reminders that follow a boss cast are compared with when that cast actually happened in your last pull. Reminders with a fixed time have nothing to compare; use Shift all to move them."])

    local list = W.CreateRowList(popup, W_ - 28, 220, 22, function(row)
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFontObject(W.fontNormal)
        row.name:SetPoint("LEFT", 6, 0)
        row.name:SetWidth(300)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.vals = row:CreateFontString(nil, "OVERLAY")
        row.vals:SetFontObject(W.fontNormal)
        row.vals:SetPoint("LEFT", 316, 0)
        row.vals:SetWidth(W_ - 360)
        row.vals:SetJustifyH("LEFT")
    end)
    list:SetPoint("TOPLEFT", 14, -84)

    local summary = popup:CreateFontString(nil, "OVERLAY")
    summary:SetFontObject(W.fontSmall)
    summary:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -6)
    summary:SetWidth(W_ - 28)
    summary:SetJustifyH("LEFT")

    local function Refresh_()
        local rows = ns.Review.Rows(currentID)
        local off = 0
        list:Update(rows, function(row, r)
            local _, text = Plans.Resolve(r.entry)
            row.name:SetText(text)
            if r.actual then
                local d = r.delta
                local color = math.abs(d) >= 2 and "|cffff6060" or "|cff9d9d9d"
                row.vals:SetText(("%s → %s  %s%+.1f|r"):format(Plans.FormatTime(r.planned), Plans.FormatTime(r.actual), color, d))
                if math.abs(d) >= 0.1 then off = off + 1 end
            else
                row.vals:SetText("|cff6f6f6f" .. Plans.FormatTime(r.planned) .. "  " .. L["(nothing to compare)"] .. "|r")
            end
        end)
        summary:SetText(ns.db.recorded[currentID] and L["%d reminders differ from your last pull."]:format(off)
            or L["No recorded pull for this boss yet."])
    end

    local apply = W.CreateButton(popup, L["Use last pull's times"], "primary", 150, 22)
    W.FitButton(apply, 150, 22)
    apply:SetPoint("BOTTOMLEFT", 14, 44)
    apply:SetScript("OnClick", function()
        local n = ns.Review.ApplyAnchored(currentID)
        ns.Print(L["Updated %d reminders."]:format(n))
        ns.Fire("PlansChanged")
        Refresh_()
    end)

    local shiftLbl = popup:CreateFontString(nil, "OVERLAY")
    shiftLbl:SetFontObject(W.fontNormal)
    shiftLbl:SetPoint("LEFT", apply, "RIGHT", 24, 0)
    shiftLbl:SetText(L["Shift all by"])
    local shiftBox = W.CreateEditBox(popup, 50, 20)
    shiftBox:SetPoint("LEFT", shiftLbl, "RIGHT", 8, 0)
    local shiftUnit = popup:CreateFontString(nil, "OVERLAY")
    shiftUnit:SetFontObject(W.fontSmall)
    shiftUnit:SetPoint("LEFT", shiftBox, "RIGHT", 4, 0)
    shiftUnit:SetText(L["seconds"])
    local shiftBtn = W.CreateButton(popup, L["Apply"], "normal", 60, 22)
    W.FitButton(shiftBtn, 60, 22)
    shiftBtn:SetPoint("LEFT", shiftUnit, "RIGHT", 8, 0)
    shiftBtn:SetScript("OnClick", function()
        local d = tonumber(shiftBox:GetText())
        if not d or d == 0 then return end
        ns.Review.ShiftAll(currentID, d)
        ns.Fire("PlansChanged")
        Refresh_()
    end)

    local close = W.CreateButton(popup, L["Okay"], "normal", 90, 22)
    close:SetPoint("BOTTOM", 0, 12)
    close:SetScript("OnClick", function() popup:Hide() end)

    function popup:Open()
        shiftBox:SetText("")
        self:Show()
        Refresh_()
    end

    popup:Hide()
    return popup
end

local function CreatePopups()
    local parent = ns.Options.panel

    renamePopup = W.CreateInputPopup(parent, 340, L["Rename"], {
        { key = "name", label = L["Name"] },
    })

    deletePopup = W.CreateConfirmPopup(parent, 320, L["Delete this boss's custom timeline?"], function()
        if currentID then
            Plans.Delete(currentID)
            currentID = nil
            ns.Fire("PlansChanged")
        end
    end)

    importPopup = CreateImportPopup(parent)
    exportPopup = CreateExportPopup(parent)
    reviewPopup = CreateReviewPopup(parent)
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
    row.text = Font(row, COL.text, COL.lead - COL.text - 8)
    row.lead = Font(row, COL.lead, 52, "RIGHT")
    row.src  = Font(row, COL.src, COL.btn - COL.src - 8)
    row.src:SetFontObject(W.fontSmall)

    row.edit = W.CreateButton(row, L["Edit"], "normal", 44, 18)
    row.edit:SetPoint("LEFT", row, "LEFT", COL.btn, 0)
    row.edit:SetScript("OnClick", function()
        local it = row.item
        if it and it.kind == "entry" then OpenEntryPopup(EntryValues(it.entry), it.entry) end
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
        if not it then return end
        if it.kind == "mrt" then
            -- 從 MRT 的某一次施放建立：預設錨在「這個技能第 n 次施放」上
            OpenEntryPopup({
                t = it.ev.t, spell = it.ev.spell,
                anchor = { spell = it.ev.spell, n = it.n, offset = 0 }, anchorName = it.ev.name,
            })
        elseif it.kind == "recorded" then
            OpenEntryPopup({
                t     = it.ev.t,
                spell = it.ev.spell,
                text  = (it.ev.src ~= "blizzard" or not it.ev.spell) and it.ev.text or nil,
            })
        end
    end)
end

local GRAY = 0.6

local function SetRowColor(row, c)
    row.time:SetTextColor(c, c, c)
    row.text:SetTextColor(c, c, c)
    row.lead:SetTextColor(c, c, c)
end

local function ShowButtons(row, editable, copyable)
    row.edit:SetShown(editable)
    row.del:SetShown(editable)
    row.copy:SetShown(copyable)
end

local function UpdateRow(row, it)
    row.item = it
    row.icon:SetDesaturated(false)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if it.kind == "entry" then
        local e = it.entry
        local icon, text = Plans.Resolve(e)
        local on = e.enabled ~= false
        row.time:SetText(Plans.FormatTime(e.t))
        row.icon:SetTexture(icon)
        row.icon:SetDesaturated(not on)
        local tags = ""
        if e.anchor then tags = tags .. "  |cffffd100" .. L["[follows]"] .. "|r" end
        if e.sound or e.tts then tags = tags .. " |cff9d9d9d" .. L["[sound]"] .. "|r" end
        if e.roles or e.class then tags = tags .. " |cff9d9d9d" .. L["[only some]"] .. "|r" end
        row.text:SetText(text .. tags)
        row.lead:SetText(("%ds"):format(e.lead or Plans.DEFAULT_LEAD))
        row.src:SetText("|cff55ff55" .. L["Mine"] .. "|r")
        SetRowColor(row, on and 1 or 0.5)
        ShowButtons(row, true, false)

    elseif it.kind == "phase" then
        row.time:SetText(Plans.FormatTime(it.t))
        row.icon:SetTexture(nil)
        row.text:SetText("|cffffd100— " .. L["Phase %s"]:format(tostring(it.phase)) .. " —|r")
        row.lead:SetText("")
        row.src:SetText("|cffffd100MRT|r")
        SetRowColor(row, GRAY)
        ShowButtons(row, false, false)

    elseif it.kind == "mrt" then
        local ev = it.ev
        local name = ev.name or (L["Spell"] .. " #" .. ev.spell)
        if ev.count > 1 then name = name .. "  |cff9d9d9dx" .. ev.count .. "|r" end
        row.time:SetText(Plans.FormatTime(ev.t))
        row.icon:SetTexture(ev.icon or QUESTION_ICON)
        row.text:SetText(name)
        row.lead:SetText(ev.cast and ("%.1fs"):format(ev.cast) or "")
        row.src:SetText("|cffffd100MRT|r")
        SetRowColor(row, 0.75)
        ShowButtons(row, false, true)

    else
        local ev = it.ev
        row.time:SetText(Plans.FormatTime(ev.t))
        row.icon:SetTexture(LOCK_ICON)
        row.icon:SetTexCoord(0, 1, 0, 1)
        if ev.src == "blizzard" then
            if ev.text then
                -- 戰鬥中認出來的（DBM／MRT）：有名稱就照常顯示，圖示換回技能的
                row.text:SetText(ev.text .. (ev.ident == "mrt" and "  |cff9d9d9d" .. L["(guessed from MRT)"] .. "|r" or ""))
                if ev.icon then
                    row.icon:SetTexture(ev.icon)
                    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
            else
                row.text:SetText(L["Blizzard ability (name hidden by the game)"])
            end
            row.src:SetText("|cffff7f00" .. L["Last pull"] .. "|r")
        else
            row.text:SetText(ev.text or "?")
            row.src:SetText("|cff66ccff" .. ns.Owners.Label(ev.owner) .. "|r")
        end
        row.lead:SetText(ev.d and ("%ds"):format(ev.d) or "")
        SetRowColor(row, GRAY)
        ShowButtons(row, false, true)
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

local function VariantItems()
    local items = {}
    for _, v in ipairs(MD.Variants(currentID)) do
        local label = v.difficulty and Plans.DifficultyLabel(v.difficulty) or ("#" .. v.index)
        if v.keystone then label = label .. " +" .. v.keystone end
        if v.length then label = label .. "  " .. Plans.FormatTime(math.floor(v.length)) end
        if v.note then label = label .. "  " .. v.note end
        items[#items + 1] = { text = label, value = v.index }
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
    for _, w in ipairs({ planDD, diffDD, enabledCB, btnRename, btnDelete, btnPreview, btnTest, btnReview, btnAdd, btnExport, btnUndo, showRecCB }) do
        w:SetShown(has)
    end
    btnUndo:SetAlpha(Plans.CanUndo(currentID) and 1 or 0.4)
    diffLbl:SetShown(has)
    -- 貼上匯入沒有首領也能用（米利字串自己帶著首領）：放到清單區頂端的位置
    btnImport:SetShown(true)
    local mode = View().mode == "timeline" and "timeline" or "list"
    head:SetShown(has and mode == "list")
    list:SetShown(has and mode == "list")
    editor.frame:SetShown(has and mode == "timeline")
    for _, b in ipairs(modeButtons) do
        b:SetShown(has)
        if b.id == mode then highlightMode(b) end
    end
    emptyText:SetShown(not has)

    local running = ns.Scheduler.Running()
    btnStop:SetShown(running and running.test and true or false)

    local hasMRT = has and MD.Has(currentID)
    showMRTCB:SetShown(hasMRT)
    mrtDD:SetShown(hasMRT and View().mrt)

    if not has then
        statusText:SetText("")
        recNote:SetText("")
        return
    end
    enabledCB:SetChecked(plan.enabled ~= false)
    diffDD:SetSelectedValue(plan.difficulty or 0)
    showRecCB:SetChecked(View().recorded)
    showMRTCB:SetChecked(View().mrt)
    if hasMRT then
        mrtDD:SetItems(VariantItems())
        mrtDD:SetSelectedValue(MRTVariant(plan))
    end

    -- 立即測試：沒有會跑的提示就停用（不然按了什麼都不會發生）；正在測這份＝字改現況＋停用
    local testingThis = running and running.test and running.id == currentID
    btnTest.reason = ns.Scheduler.RunnableCount(plan) == 0
        and (#plan.entries == 0 and L["Add a reminder first."]
             or L["None of the reminders apply to you (disabled, or role/class conditions)."])
        or nil
    btnTest:SetText(testingThis and L["Testing"] or L["Test now"])
    btnTest:SetEnabled(not testingThis and not btnTest.reason)

    if testingThis then
        statusText:SetText("|cffffd200" .. L["Testing — watch the timeline on screen."] .. "|r")
    else
        statusText:SetText("")
    end

    -- 底下那行說明：先講 MRT 有沒有資料，再講上一場紀錄
    local notes = {}
    if hasMRT then
        notes[#notes + 1] = L["MRT rows are averaged from logs; phase changes drift from pull to pull."]
    elseif MD.Available() then
        notes[#notes + 1] = L["MRT has no timeline for this boss."]
    else
        notes[#notes + 1] = L["Install or enable MRT to see the whole fight's boss abilities here."]
    end
    local rec = ns.db.recorded[currentID]
    if rec then
        notes[#notes + 1] = L["Locked rows are from your last pull (%s, %s)."]:format(
            Plans.DifficultyLabel(rec.difficulty), Plans.FormatTime(rec.duration or 0))
        -- 別的插件（地瓜語音之類）在這隻首領也有語音提醒：提醒玩家自己的音效可能疊上去
        local voices, owner = 0, nil
        for _, ev in ipairs(rec.events) do
            if ev.voice then voices, owner = voices + 1, ev.owner end
        end
        if voices > 0 then
            table.insert(notes, 1, "|cffffd100" .. L["%s played %d voice cues on this boss last pull (see Last pull). Sounds on your reminders may overlap with them."]:format(
                ns.Owners.Label(owner), voices) .. "|r")
        end
    end
    recNote:SetText(table.concat(notes, "\n"))

    if mode == "timeline" then
        editor:SetPlan(currentID, {
            mrtVariant = View().mrt and hasMRT and MRTVariant(plan) or nil,
            recorded   = View().recorded,
            review     = ns.Review.Rows(currentID),
        })
    else
        list:Update(Items(), UpdateRow)
    end
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
    -- 從冒險指南挑（BossPicker）；冒險指南沒收的首領在選單裡可以改成手動輸入 ID
    btnNew:SetScript("OnClick", function()
        ns.BossPicker.Open(function(id, name)
            local rec = ns.db.recorded[id]
            Plans.Ensure(id, name or (rec and rec.name) or ns.Journal.NameFor(id))
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

    diffLbl = tab:CreateFontString(nil, "OVERLAY")
    diffLbl:SetFontObject(W.fontNormal)
    diffLbl:SetPoint("TOPLEFT", 150, -88)
    diffLbl:SetText(L["Difficulty"])
    local diffItems = {}
    for _, d in ipairs(Plans.DIFFICULTIES) do diffItems[#diffItems + 1] = { text = L[d.label], value = d.value } end
    diffDD = W.CreateDropdown(tab, 160, diffItems, function(value)
        local plan = Plans.Get(currentID)
        if plan then
            plan.difficulty = value
            plan.mrtVariant = nil     -- 換難度就讓 MRT 那份跟著重挑
            Refresh()
        end
    end)
    diffDD:SetPoint("LEFT", diffLbl, "RIGHT", 10, 0)

    btnPreview = W.CreateButton(tab, L["Preview"], "primary", 70, 20)
    W.FitButton(btnPreview, 70, 20)
    btnPreview:SetPoint("LEFT", diffDD, "RIGHT", 16, 0)
    btnPreview:SetScript("OnClick", function() ns.PlanPreview.Open(currentID) end)

    btnTest = W.CreateButton(tab, L["Test now"], "normal", 80, 20)
    W.FitButton(btnTest, 80, 20)
    btnTest:SetPoint("LEFT", btnPreview, "RIGHT", 6, 0)
    btnTest:SetScript("OnClick", function()
        ns.Scheduler.Test(currentID)
    end)
    -- 停用的按鈕照樣收得到 OnEnter：告訴玩家為什麼按不了
    btnTest:HookScript("OnEnter", function(self)
        if not self.reason then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.reason, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnTest:HookScript("OnLeave", function() GameTooltip:Hide() end)
    btnReview = W.CreateButton(tab, L["Review"], "normal", 70, 20)
    W.FitButton(btnReview, 70, 20)
    btnReview:SetPoint("LEFT", btnTest, "RIGHT", 6, 0)
    btnReview:SetScript("OnClick", function() reviewPopup:Open() end)

    btnStop = W.CreateButton(tab, L["Stop"], "red", 60, 20)
    W.FitButton(btnStop, 60, 20)
    btnStop:SetPoint("LEFT", btnReview, "RIGHT", 6, 0)
    btnStop:SetScript("OnClick", function() ns.Scheduler.Stop() end)

    statusText = tab:CreateFontString(nil, "OVERLAY")
    statusText:SetFontObject(W.fontSmall)
    statusText:SetPoint("LEFT", btnStop, "RIGHT", 10, 0)

    -- 表頭
    head = CreateFrame("Frame", nil, tab)
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

    -- 時間軸檢視：跟「表頭＋清單」同一塊位置，二選一
    editor = ns.PlanEditor.Create(tab, LIST_W, 320, {
        onAdd  = function(values) OpenEntryPopup(values) end,
        onEdit = function(entry) OpenEntryPopup(EntryValues(entry), entry) end,
        onMove = function(entry, t)
            Plans.MoveEntry(currentID, entry, t)
            ns.Fire("PlansChanged")
        end,
        onMenu = function(entry, btn)
            W.Menu.Show({
                { text = L["Edit"], onClick = function() OpenEntryPopup(EntryValues(entry), entry) end },
                { text = entry.enabled == false and L["Enable"] or L["Disable"], onClick = function()
                    Plans.SetEnabled(currentID, entry, entry.enabled == false)
                    ns.Fire("PlansChanged")
                end },
                { text = L["Delete"], onClick = function()
                    local i = Plans.IndexOf(currentID, entry)
                    if i then Plans.RemoveEntry(currentID, i) end
                    ns.Fire("PlansChanged")
                end },
            }, btn)
        end,
    })
    editor.frame:SetPoint("TOPLEFT", LIST_X, -114)

    -- 清單｜時間軸 切換（右上角）
    local bList = W.CreateButton(tab, L["List"], "accent-hover", 60, 20)
    local bTime = W.CreateButton(tab, L["Timeline"], "accent-hover", 60, 20)
    W.FitButton(bList, 60, 20)
    W.FitButton(bTime, 60, 20)
    bList.id, bTime.id = "list", "timeline"
    bTime:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -16, -52)
    bList:SetPoint("RIGHT", bTime, "LEFT", -3, 0)
    modeButtons = { bList, bTime }
    highlightMode = W.CreateButtonGroup(modeButtons, function(id)
        View().mode = id
        Refresh()
    end)

    -- 底下：新增、貼上匯入、顯示哪些參考列
    btnAdd = W.CreateButton(tab, L["+ Add reminder"], "primary", 110, 22)
    W.FitButton(btnAdd, 110, 22)
    btnAdd:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -10)
    btnAdd:SetScript("OnClick", function()
        OpenEntryPopup({})
    end)

    btnImport = W.CreateButton(tab, L["Paste reminders"], "normal", 90, 22)
    W.FitButton(btnImport, 90, 22)
    btnImport:SetPoint("LEFT", btnAdd, "RIGHT", 6, 0)
    btnImport:SetScript("OnClick", function() importPopup:Open() end)

    btnExport = W.CreateButton(tab, L["Export"], "normal", 60, 22)
    W.FitButton(btnExport, 60, 22)
    btnExport:SetPoint("LEFT", btnImport, "RIGHT", 6, 0)
    btnExport:SetScript("OnClick", function() exportPopup:Open() end)

    showRecCB = W.CreateCheckButton(tab, L["Last pull"], function(checked)
        View().recorded = checked
        Refresh()
    end)
    -- 復原（也可以 Ctrl＋Z）：只記這次登入、每隻首領 20 步
    btnUndo = W.CreateButton(tab, L["Undo"], "normal", 60, 22)
    W.FitButton(btnUndo, 60, 22)
    btnUndo:SetPoint("LEFT", btnExport, "RIGHT", 6, 0)
    btnUndo:SetScript("OnClick", function()
        if Plans.Undo(currentID) then ns.Fire("PlansChanged") end
    end)
    btnUndo:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Undo the last change (Ctrl+Z)"], 1, 1, 1)
        GameTooltip:Show()
    end)
    btnUndo:HookScript("OnLeave", function() GameTooltip:Hide() end)

    showRecCB:SetPoint("LEFT", btnUndo, "RIGHT", 18, 0)

    showMRTCB = W.CreateCheckButton(tab, L["MRT timeline"], function(checked)
        View().mrt = checked
        Refresh()
    end)
    showMRTCB:SetPoint("LEFT", showRecCB.label, "RIGHT", 16, 0)

    mrtDD = W.CreateDropdown(tab, 170, {}, function(value)
        local plan = Plans.Get(currentID)
        if plan then
            plan.mrtVariant = value
            Refresh()
        end
    end)
    mrtDD:SetPoint("LEFT", showMRTCB.label, "RIGHT", 10, 0)

    recNote = tab:CreateFontString(nil, "OVERLAY")
    recNote:SetFontObject(W.fontSmall)
    recNote:SetPoint("TOPLEFT", btnAdd, "BOTTOMLEFT", 0, -8)
    recNote:SetWidth(LIST_W)
    recNote:SetJustifyH("LEFT")
    recNote:SetSpacing(2)

    emptyText = tab:CreateFontString(nil, "OVERLAY")
    emptyText:SetFontObject(W.fontNormal)
    emptyText:SetPoint("TOPLEFT", 18, -120)
    emptyText:SetWidth(LIST_W - 20)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetSpacing(4)
    emptyText:SetText(L["No custom timelines yet. Press \"Add a boss\" — after you have pulled a boss once, it is filled in for you."])

    -- MRT 列的法術名稱第一次可能還沒從伺服器載下來：載到了重畫一次（合併成一次，不要每個法術重畫）
    local pending
    tab:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    tab:SetScript("OnEvent", function()
        if pending or not tab:IsShown() then return end
        pending = true
        C_Timer.After(0.3, function()
            pending = false
            if tab:IsShown() then Refresh() end
        end)
    end)
end

ns.RegisterCallback("ShowOptionsTab", "plansTab", function(id)
    if id ~= "plans" then
        if tab then tab:Hide() end
        return
    end
    Init()
    -- Ctrl＋Z：鍵盤框一律「轉發」（SetPropagateKeyboardInput(true)），不擋任何快捷鍵；
    -- 那支 API 戰鬥中受限，所以只在戰鬥外建（.claude/notes/wow-keyboard-capture-blocks-bindings.md）
    if not keyCatcher and not InCombatLockdown() then
        keyCatcher = CreateFrame("Frame", nil, tab)
        keyCatcher:EnableKeyboard(true)
        keyCatcher:SetPropagateKeyboardInput(true)
        keyCatcher:SetScript("OnKeyDown", function(_, key)
            if key == "Z" and IsControlKeyDown() and not GetCurrentKeyBoardFocus() then
                if Plans.Undo(currentID) then ns.Fire("PlansChanged") end
            end
        end)
    end
    Refresh()
    tab:Show()
end)

ns.RegisterCallback("PlansChanged", "plansTab", Refresh)
ns.RegisterCallback("RecordedChanged", "plansTab", Refresh)
ns.RegisterCallback("SchedulerChanged", "plansTab", Refresh)
