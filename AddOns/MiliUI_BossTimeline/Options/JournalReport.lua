------------------------------------------------------------
-- /mbt ej：冒險指南 ↔ 首領技能記錄的比對報告（比對本身在 Plans/JournalAbilities.lua）
--
--   /mbt ej            「首領技能」分頁選中的首領；沒選過就用上一場的首領
--   /mbt ej <首領戰ID>  指定首領
--   /mbt ej here       現在所在副本的每一隻首領
--   /mbt ej tier       最新資料片每個副本的每一隻首領（先印總表、再印每隻的細節）
--
-- 結果是一大段純文字，放在可全選複製的視窗裡 —— 實機驗證時整段貼回來對照用。
-- 法術名稱第一次查常常還沒從伺服器載下來：有缺就自動等一下重跑一次，之後按「重新產生」。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local JA = ns.JournalAbilities
local J = ns.Journal

ns.JournalReport = {}
local R = ns.JournalReport

local RETRY_DELAY = 1.5

------------------------------------------------------------
-- 文字工具
------------------------------------------------------------
local function DiffName(d)
    local name = GetDifficultyInfo and GetDifficultyInfo(d)
    return ("%s(%d)"):format(type(name) == "string" and name or "?", d)
end

local function FlagList(flags)
    local out = {}
    for _, f in ipairs(flags or {}) do out[#out + 1] = JA.FlagName(f) end
    return #out > 0 and ("{" .. table.concat(out, ", ") .. "}") or ""
end

local function MaskList(mask)
    if not mask or mask == 0 then return "{}" end
    return FlagList(JA.MaskToFlags(mask))
end

local function Pct(a, b)
    if not b or b == 0 then return "-" end
    return ("%d%%"):format(math.floor(a / b * 100 + 0.5))
end

local function EventLabel(res, id)
    local info = res.index.info[id]
    if not info then return ("#%d"):format(id) end
    return ("#%d %s"):format(id, info.name or ("spell " .. tostring(info.spell)))
end

local MARK = { exact = "=", name = "~", far = "!", none = "?", nospell = "." }

------------------------------------------------------------
-- 一隻首領的摘要（總表與細節開頭共用）
------------------------------------------------------------
local function Verdict(res)
    local st = res.stats
    if not res.range then return L["No journal spell matches any boss ability record directly."] end
    local c = st.coverage or 0
    if c >= 0.9 then return L["Usable on its own: the journal covers almost every record in the range."] end
    if c >= 0.6 then return L["Partly usable: pair it with MRT or the ID range for the rest."] end
    return L["Not reliable: most records in the range have no journal section."]
end

local function SummaryLines(res, out)
    local st = res.stats
    local k = st.kind
    out[#out + 1] = L["Journal sections: %d (with a spell %d, distinct spells %d, overview %d, without a spell %d)"]
        :format(st.sections, st.withSpell, st.uniqueSpells, st.overview, st.headers)
    out[#out + 1] = L["Ability sections: same spell ID %d, same name %d, only far away %d, no record %d, no spell %d"]
        :format(k.exact or 0, k.name or 0, k.far or 0, k.none or 0, k.nospell or 0)
    if res.range then
        out[#out + 1] = L["Record range: #%d–#%d (%d records), journal covers %d (%s), not covered %d"]
            :format(res.range.lo, res.range.hi, st.rangeSize, st.rangeCovered, Pct(st.rangeCovered, st.rangeSize), #st.gaps)
        local others = {}
        for i = 2, #res.clusters do
            local c = res.clusters[i]
            others[#others + 1] = ("#%d–#%d (%d/%d)"):format(c.lo, c.hi, c.spells, #c.ids)
        end
        if #others > 0 then
            out[#out + 1] = L["Other clusters (likely shared spells; spells/records): %s"]:format(table.concat(others, ", "))
        end
    end
    if not res.mrt.available then
        out[#out + 1] = L["MRT: not loaded"]
    elseif not res.mrt.has then
        out[#out + 1] = L["MRT: no timeline for this boss"]
    else
        out[#out + 1] = L["MRT: matched %d, guessed from the ID range %d (range #%d–#%d)"]
            :format(st.mrtMatch, st.mrtGuess, res.mrtRange.lo, res.mrtRange.hi)
        out[#out + 1] = L["Found by both %d, journal only %d (of which MRT only guessed %d), MRT only %d"]
            :format(st.both, st.ejOnly, st.mrtGuessCoveredByEJ, st.mrtOnly)
    end
    out[#out + 1] = L["Flags agree: %d / %d pairs"]:format(st.flagAgree, st.flagPairs)
    out[#out + 1] = L["One section → several records: %d   One record ← several sections: %d"]
        :format(st.multiEvent, st.multiSection)
    local diffs = {}
    for _, d in ipairs(res.journal.diffs) do diffs[#diffs + 1] = DiffName(d) end
    out[#out + 1] = L["Difficulties checked: %s"]:format(#diffs > 0 and table.concat(diffs, " ") or "-")
        .. (res.journal.diffsSkipped and ("  " .. L["(Adventure Guide window was open: only its current difficulty)"]) or "")
    local missing = res.index.missingNames + st.missingSectionSpellNames
    if missing > 0 then
        out[#out + 1] = L["Spell names not loaded yet: %d (press Regenerate)"]:format(missing)
    end
    out[#out + 1] = L["Verdict: %s"]:format(Verdict(res))
end

------------------------------------------------------------
-- 一隻首領的細節
------------------------------------------------------------
local function DetailLines(res, out)
    local diffs = res.journal.diffs

    -- 段落樹
    out[#out + 1] = ""
    out[#out + 1] = "-- " .. L["Journal sections"] .. " --"
    for _, sec in ipairs(res.sections) do
        local m = sec.match
        local parts = { ("  "):rep(sec.depth + 1) .. (MARK[m.kind] or " ") .. " " .. (sec.title ~= "" and sec.title or "?") }
        if sec.overview then parts[#parts + 1] = "[" .. L["overview"] .. "]" end
        if sec.spell then
            local sp = "spell " .. sec.spell
            if m.spellName and m.spellName ~= sec.title then sp = sp .. " " .. m.spellName end
            parts[#parts + 1] = "(" .. sp .. ")"
        end
        if #sec.flags > 0 then parts[#parts + 1] = FlagList(sec.flags) end
        local hidden = {}
        for _, d in ipairs(diffs) do
            if sec.hidden[d] then hidden[#hidden + 1] = DiffName(d) end
        end
        if #hidden > 0 then
            parts[#parts + 1] = "<" .. (#hidden == #diffs and L["hidden on every difficulty"]
                or L["hidden on: %s"]:format(table.concat(hidden, " "))) .. ">"
        end
        if #m.ids > 0 then
            local ids = {}
            for _, id in ipairs(m.ids) do
                local s = EventLabel(res, id)
                local chk = m.flagCheck[id]
                if chk and not chk.agree then s = s .. " *" end
                ids[#ids + 1] = s
            end
            parts[#parts + 1] = "-> " .. table.concat(ids, ", ")
        end
        if #m.far > 0 then
            local ids = {}
            for i, id in ipairs(m.far) do
                if i > 4 then ids[#ids + 1] = "…" .. (#m.far - 4); break end
                ids[#ids + 1] = "#" .. id
            end
            parts[#parts + 1] = L["far:"] .. " " .. table.concat(ids, " ")
        end
        out[#out + 1] = table.concat(parts, " ")
    end

    -- 範圍內與兩端外的每一筆記錄
    local function EventLine(id)
        local info = res.index.info[id]
        local e = res.events[id]
        local parts = { "  " .. EventLabel(res, id) }
        if info then
            parts[#parts + 1] = ("spell %s  sev %s  %s"):format(tostring(info.spell), tostring(info.severity),
                MaskList(info.icons and bit.band(info.icons, 1023)))
            if info.enabled == false then parts[#parts + 1] = "[" .. L["disabled"] .. "]" end
        end
        local who = {}
        if e then
            for _, sec in ipairs(e.sections) do
                who[#who + 1] = (MARK[sec.match.kind] or "") .. sec.title .. (sec.overview and ("[" .. L["overview"] .. "]") or "")
            end
            if e.mrt == "match" then who[#who + 1] = "MRT" elseif e.mrt == "guess" then who[#who + 1] = L["MRT guess"] end
        end
        parts[#parts + 1] = "<- " .. (#who > 0 and table.concat(who, " / ") or L["(nothing)"])
        return table.concat(parts, "  ")
    end

    if res.range then
        out[#out + 1] = ""
        out[#out + 1] = "-- " .. L["Records in the range"] .. " --"
        for _, id in ipairs(ns.Abilities.AllEventIDs()) do
            if id >= res.range.lo and id <= res.range.hi and res.index.info[id] then out[#out + 1] = EventLine(id) end
        end
        local before, after = JA.Edges(res)
        if #before + #after > 0 then
            out[#out + 1] = ""
            out[#out + 1] = "-- " .. L["Just outside the range"] .. " --"
            for _, id in ipairs(before) do out[#out + 1] = EventLine(id) end
            out[#out + 1] = "  ……"
            for _, id in ipairs(after) do out[#out + 1] = EventLine(id) end
        end
    end

    -- MRT 有、冒險指南沒有
    local mrtOnly = {}
    for id, e in pairs(res.events) do
        if #e.sections == 0 and e.mrt and not (res.range and id >= res.range.lo and id <= res.range.hi) then
            mrtOnly[#mrtOnly + 1] = id
        end
    end
    table.sort(mrtOnly)
    if #mrtOnly > 0 then
        out[#out + 1] = ""
        out[#out + 1] = "-- " .. L["MRT has these, outside the journal's range"] .. " --"
        for _, id in ipairs(mrtOnly) do out[#out + 1] = EventLine(id) end
    end

    -- 標記不一致
    if #res.stats.flagMismatch > 0 then
        out[#out + 1] = ""
        out[#out + 1] = "-- " .. L["Flag mismatches (* above)"] .. " --"
        for _, mm in ipairs(res.stats.flagMismatch) do
            local c = mm.check
            out[#out + 1] = ("  %s -> %s:  %s %s   %s %s"):format(mm.section.title, EventLabel(res, mm.id),
                L["journal only"], MaskList(c.missing), L["record only"], MaskList(c.extra))
        end
    end
end

------------------------------------------------------------
-- 一隻首領的完整報告；res 為 nil 時印原因
------------------------------------------------------------
local WHY = {
    events  = L["This game client has no boss ability settings API."],
    api     = L["This game client can't read the Adventure Guide's ability sections."],
    journal = L["This boss isn't in the Adventure Guide."],
    empty   = L["The Adventure Guide has no ability sections for this boss."],
}

local function BossName(encounterID, res)
    return (res and res.name) or J.NameFor(encounterID) or L["Boss"]
end

local function Header(encounterID, res)
    local s = ("==== %s  encounter %d"):format(BossName(encounterID, res), encounterID)
    if res then
        local info = res.journal.info
        local inst = EJ_GetInstanceInfo and ns.Secret.SafeCall(EJ_GetInstanceInfo, info.instance)
        s = s .. ("  journal %d  %s"):format(info.journal, type(inst) == "string" and inst or tostring(info.instance))
    end
    return s .. " ===="
end

local function BossReport(encounterID, out, detail)
    local res, why = JA.Compare(encounterID)
    out[#out + 1] = Header(encounterID, res)
    if not res then
        out[#out + 1] = WHY[why] or WHY.api
        return
    end
    SummaryLines(res, out)
    if detail then DetailLines(res, out) end
    return res
end

local function Legend(out)
    out[#out + 1] = L["Legend: = same spell ID   ~ same name, different ID   ! only matches records far away   ? no record   . heading without a spell"]
    out[#out + 1] = L["* = the journal's role/effect icons differ from the record's.  sev = severity (0 low, 1 medium, 2 high)."]
end

------------------------------------------------------------
-- 要報告哪幾隻
------------------------------------------------------------
local function TierBosses()
    local list = {}
    local newest = EJ_GetNumTiers and EJ_GetNumTiers()
    if not newest or newest < 1 then return list end
    for _, inst in ipairs(J.Instances(newest)) do
        for _, enc in ipairs(J.Encounters(inst.value, newest)) do
            list[#list + 1] = { id = enc.value, instance = inst.text }
        end
    end
    return list
end

local function HereBosses()
    local list = {}
    local cur = J.CurrentInstanceInfo()
    if not cur then return list end
    for _, enc in ipairs(J.Encounters(cur.value)) do
        list[#list + 1] = { id = enc.value, instance = cur.text }
    end
    return list
end

local lastArg

local function Build(arg)
    local out = {}
    local missing = 0
    local function Note(res)
        if res then missing = missing + res.index.missingNames + res.stats.missingSectionSpellNames end
    end

    if arg == "tier" or arg == "here" then
        local bosses = arg == "tier" and TierBosses() or HereBosses()
        if #bosses == 0 then
            return arg == "here" and L["You're not in an instance the Adventure Guide knows."] or L["The Adventure Guide has no current expansion."], 0
        end
        Legend(out)
        -- 總表：一隻一行
        out[#out + 1] = ""
        out[#out + 1] = "-- " .. L["Summary"] .. " --"
        out[#out + 1] = L["boss | encounter | journal spells | same ID / same name / none | range covered | MRT both / journal only / MRT only | flags agree"]
        local results = {}
        local index = JA.BuildIndex()     -- 全遊戲的記錄索引每隻共用，不要每隻重建
        local tot = { size = 0, covered = 0, exact = 0, name = 0, none = 0, pairs = 0, agree = 0 }
        for _, b in ipairs(bosses) do
            local res, why = JA.Compare(b.id, index)
            results[#results + 1] = { boss = b, res = res, why = why }
            Note(res)
            if res then
                local st, k = res.stats, res.stats.kind
                out[#out + 1] = ("%s | %d | %d | %d / %d / %d | %s | %s | %d/%d"):format(
                    BossName(b.id, res), b.id, st.uniqueSpells, k.exact or 0, k.name or 0, (k.none or 0) + (k.far or 0),
                    res.range and ("%d/%d (%s)"):format(st.rangeCovered, st.rangeSize, Pct(st.rangeCovered, st.rangeSize)) or "-",
                    res.mrt.has and ("%d / %d / %d"):format(st.both, st.ejOnly, st.mrtOnly) or "-",
                    st.flagAgree, st.flagPairs)
                tot.size, tot.covered = tot.size + st.rangeSize, tot.covered + st.rangeCovered
                tot.exact, tot.name = tot.exact + (k.exact or 0), tot.name + (k.name or 0)
                tot.none = tot.none + (k.none or 0) + (k.far or 0)
                tot.pairs, tot.agree = tot.pairs + st.flagPairs, tot.agree + st.flagAgree
            else
                out[#out + 1] = ("%s | %d | %s"):format(BossName(b.id), b.id, L["(no data)"])
            end
        end
        out[#out + 1] = L["Total: same ID %d, same name %d, none %d; range covered %d/%d (%s); flags agree %d/%d"]
            :format(tot.exact, tot.name, tot.none, tot.covered, tot.size, Pct(tot.covered, tot.size), tot.agree, tot.pairs)
        -- 每隻的細節
        for _, r in ipairs(results) do
            out[#out + 1] = ""
            out[#out + 1] = Header(r.boss.id, r.res)
            if r.res then
                SummaryLines(r.res, out)
                DetailLines(r.res, out)
            else
                out[#out + 1] = WHY[r.why] or WHY.api
            end
        end
        return table.concat(out, "\n"), missing
    end

    local id = tonumber(arg)
    if not id then
        id = ns.SelectedBoss and ns.SelectedBoss()
        local last = ns.db.lastEncounter
        id = id or (last and last.id)
    end
    if not id then
        return L["Pick a boss on the Bosses tab first, or type /mbt ej <encounter ID>."], 0
    end
    Legend(out)
    out[#out + 1] = ""
    Note(BossReport(id, out, true))
    return table.concat(out, "\n"), missing
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local frame, box, status

local function SetText(text)
    box.text = text
    box.editBox:SetText(text)
    box.editBox:SetCursorPosition(0)
    box.scroll:SetVerticalScroll(0)
end

local function CreateWindow()
    local Wd, Ht = 820, 560
    frame = W.CreateFrame("MiliUIBT_JournalReport", UIParent, Wd, Ht)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdropBorderColor(W.Accent(1))
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    W.CloseOnEscape(frame)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(L["Adventure Guide vs. boss ability records"])

    -- 標題列一整條都能拖
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", 0, 0)
    drag:SetHeight(32)
    drag:EnableMouse(true)
    W.MakeDragHandle(drag, frame)

    status = frame:CreateFontString(nil, "OVERLAY")
    status:SetFontObject(W.fontSmall)
    status:SetPoint("TOPLEFT", 14, -36)
    status:SetWidth(Wd - 28)
    status:SetJustifyH("LEFT")

    box = W.CreateScrollEditBox(frame, Wd - 28, Ht - 104)
    box:SetPoint("TOPLEFT", 14, -56)
    -- 唯讀但選得到（同 W.CreateCopyBox 的做法：被輸入就還原）
    box.editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(box.text or "") end
    end)

    local bSel = W.CreateButton(frame, L["Select all"], "normal", 90, 22)
    W.FitButton(bSel, 90, 22)
    bSel:SetPoint("BOTTOMLEFT", 14, 12)
    bSel:SetScript("OnClick", function()
        box.editBox:SetFocus()
        box.editBox:HighlightText()
    end)

    local bRegen = W.CreateButton(frame, L["Regenerate"], "normal", 90, 22)
    W.FitButton(bRegen, 90, 22)
    bRegen:SetPoint("LEFT", bSel, "RIGHT", 6, 0)
    bRegen:SetScript("OnClick", function() R.Open(lastArg) end)

    local bClose = W.CreateButton(frame, L["Okay"], "normal", 90, 22)
    bClose:SetPoint("BOTTOMRIGHT", -14, 12)
    bClose:SetScript("OnClick", function() frame:Hide() end)

    frame:Hide()
end

local pendingRetry

function R.Open(arg, isRetry)
    if InCombatLockdown() then
        ns.Print(L["Can't change settings during combat"])
        return
    end
    lastArg = arg
    if not frame then CreateWindow() end
    local t0 = debugprofilestop()
    local text, missing = Build(arg)
    SetText(text)
    status:SetText(L["Generated in %.1f s. Copy everything and paste it back for review."]:format((debugprofilestop() - t0) / 1000))
    frame:Show()
    frame:Raise()

    -- 法術名稱缺了：伺服器送過來需要一點時間，自動重跑一次
    if missing > 0 and not isRetry and not pendingRetry then
        pendingRetry = true
        C_Timer.After(RETRY_DELAY, function()
            pendingRetry = nil
            if frame:IsShown() and lastArg == arg then R.Open(arg, true) end
        end)
    end
end
