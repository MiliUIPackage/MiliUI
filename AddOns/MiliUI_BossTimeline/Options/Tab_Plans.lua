------------------------------------------------------------
-- 「自訂時間軸」分頁：替首領排自己的提示
--
-- 導覽順序＝心智順序：副本 → 首領（左側欄，用選的）→ 難度（分頁卡片）→ 設定檔（下拉，可多份）
--
--   ┌側欄────────────┐┌內容──────────────────────────────────────────┐
--   │[副本 ▼]        ││[頭像] 首領名稱                  [清單][時間軸]│
--   │ 1. 首領A    2 ●││       ☑上一場 ☑MRT [變體▼]                    │
--   │ 2. 首領B    1 ●││ [隨機][普通][英雄][傳奇]   ← 分頁卡片包住下面全部│
--   │ …              ││ 設定檔 [▼] [新增][複製][改名][刪除]            │
--   │                ││ ☑生效   也用在：□普通 ☑英雄 ☑傳奇              │
--   │[輸入首領戰 ID] ││ [預覽播放][立即測試][戰後回顧]                 │
--   │            [<<]││ 清單／時間軸編輯器                             │
--   └────────────────┘│ [+新增提示][貼上匯入][匯出][復原]  說明灰字      │
--
-- 側欄只讀冒險指南的「最新資料片」＋「現在所在的副本」（Journal.SidebarInstances）；
-- 存檔裡有、但不在這幾個副本裡的首領（手動 ID、舊資料片）落在「其他首領」。
-- 一隻首領×難度可以有好幾份設定檔、可以同時生效（團長的＋自己的），開戰時合併、重複的只跑一次。
--
-- 清單檢視：每一列一條，照「開戰後第幾秒」排。幾種列混在一起照時間排：
--   * 自己的提示（白字）—— 可以編輯、刪除
--   * MRT 時間軸（灰字、金色來源）—— 唯讀：MRT 自帶的整場首領技能統計（Plans/MRTData.lua）
--   * 上一場的紀錄（灰字、鎖頭）—— 唯讀：暴雪的首領技能、其他插件加的條
-- 唯讀列都有「以此新增」，會把那一秒（MRT 列連法術一起）帶進新增視窗。
--
-- 內容區所有寬度都從「內容區寬」推算（側欄收合時撐滿），不要寫死。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P
local Plans = ns.Plans
local MD = ns.MRTData
local J = ns.Journal

local tab
-- 側欄
local instDD, bossList, btnManual, btnCollapse, sideEmpty
-- 內容：標題列
local bossBox, bossModel, bossSkull, bossName, bossSub, modeButtons, highlightMode
local showRecCB, showMRTCB, mrtDD
-- 內容：卡片
local diffTabs, profLbl, profDD, btnNew, btnCopy, btnRename, btnDelete
local activeCB, alsoLbl, alsoCBs, activeNote
local btnPreview, btnTest, btnReview, btnStop, statusText
local head, headCols, list, editor
local btnAdd, btnImport, btnExport, btnUndo, recNote
local emptyText, btnCreate, btnEmptyImport, noBossText
local renamePopup, deletePopup, importPopup, exportPopup, reviewPopup, idPopup, choicePopup
local keyCatcher

-- 目前選的：副本（冒險指南 ID 或 "other"）、首領戰 ID、難度、設定檔 ID
local sel = {}
local chosen = false          -- 這次登入選過預設了沒（第一次打開照「所在副本 → 上次看的 → 最新團隊副本」挑）

local OTHER = "other"
local ROW_H = 24
local BOSS_ROW_H = 22
local TOP = -46
local SIDE_X, SIDE_W = 16, 170
local SIDE_GAP = 10
local COLLAPSED_W = 20 + 8    -- 收起來時只剩展開鈕那一條
local RIGHT_PAD = 16
local CARD_BOTTOM = -512
local BOTTOM_ROW_Y = -440     -- 底下一排按鈕
local NOTE_Y = -468           -- 最底下的說明灰字
local AVATAR = 40
local GREEN = { 0.3, 0.9, 0.3 }

local LOCK_ICON = "Interface\\PetBattles\\PetBattle-LockIcon"
local QUESTION_ICON = 134400
-- 設定檔下拉裡的「生效中」勾：中文字型沒有 ✓，用貼圖跳脫字串；沒勾的列用同一張貼圖的透明角落佔同寬，文字才對齊
local CHECK_MARK = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16:0:0:32:32:2:30:2:30|t"
local CHECK_BLANK = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16:0:0:32:32:0:1:0:1|t"

-- 同一秒的排序：自己的 → 換階段 → MRT → 上一場紀錄（玩家的眼睛先找自己的）
local KIND_ORDER = { entry = 1, phase = 2, mrt = 3, recorded = 4 }

local function View()
    return ns.db.planView
end

local function Profile()
    return Plans.Get(sel.pid)
end

------------------------------------------------------------
-- 版面：內容區的左緣與寬度（側欄展開／收合）
------------------------------------------------------------
local function ContentX()
    if View().sidebar then return SIDE_X + SIDE_W + SIDE_GAP end
    return SIDE_X + COLLAPSED_W
end

local function ContentW()
    return ns.Options.PANEL_W - RIGHT_PAD - ContentX()
end

------------------------------------------------------------
-- 側欄資料：副本清單、每個副本的首領、其他首領
------------------------------------------------------------
local instances, instanceById = {}, {}

local function RebuildInstances()
    wipe(instances)
    wipe(instanceById)
    for _, inst in ipairs(J.SidebarInstances()) do
        instances[#instances + 1] = inst
    end
    local cur = J.CurrentInstanceInfo()
    local present = false
    for _, inst in ipairs(instances) do
        if inst.value == (cur and cur.value) then present = true end
    end
    if cur and not present then table.insert(instances, 1, cur) end
    for _, inst in ipairs(instances) do instanceById[inst.value] = inst end
    return cur
end

-- 側欄這幾個副本的首領 → 副本（只有「其他首領」、匯入後跳轉、手動輸入 ID 時才需要；
-- 只讀最新資料片＋所在副本，結果在 Journal 那邊快取）
local function InstanceOf(encID)
    local boss = Plans.Boss(encID)
    if boss and boss.instance and instanceById[boss.instance] then return boss.instance end
    for _, inst in ipairs(instances) do
        for _, enc in ipairs(J.EncountersCached(inst.value, inst.tier)) do
            if enc.value == encID then
                if boss then boss.instance = inst.value end
                return inst.value
            end
        end
    end
    return OTHER
end

-- 一個副本的首領列：{ { id, name, journal, num }, ... }
local function BossRows(instID)
    local rows = {}
    if instID == OTHER then
        for _, b in ipairs(Plans.Bosses()) do
            if InstanceOf(b.id) == OTHER then
                rows[#rows + 1] = { id = b.id, name = b.boss.name or tostring(b.id), journal = b.boss.journal }
            end
        end
        return rows
    end
    local inst = instanceById[instID]
    if not inst then return rows end
    for i, enc in ipairs(J.EncountersCached(inst.value, inst.tier)) do
        rows[#rows + 1] = { id = enc.value, name = enc.text, journal = enc.journal, num = i }
    end
    return rows
end

local function FindRow(rows, encID)
    for _, r in ipairs(rows) do
        if r.id == encID then return r end
    end
end

------------------------------------------------------------
-- 難度：副本類型決定分頁那一組
------------------------------------------------------------
local function IsRaidBoss(encID)
    local inst = instanceById[sel.inst]
    if inst then return inst.isRaid ~= false end
    -- 其他首領：看它的設定檔用在哪些難度；全是地城難度才當地城（手動 ID 的首領預設團隊那組）
    local raidSet, dungeonSet = {}, {}
    for _, d in ipairs(Plans.RAID_DIFFICULTIES) do raidSet[d.value] = true end
    for _, d in ipairs(Plans.DUNGEON_DIFFICULTIES) do dungeonSet[d.value] = true end
    local raid, dungeon = false, false
    for _, p in ipairs(Plans.Profiles(encID)) do
        for d in pairs(p.difficulties or {}) do
            if raidSet[d] then raid = true end
            if dungeonSet[d] then dungeon = true end
        end
    end
    return not (dungeon and not raid)
end

local function DiffGroup()
    return (sel.boss and not IsRaidBoss(sel.boss)) and Plans.DUNGEON_DIFFICULTIES or Plans.RAID_DIFFICULTIES
end

local function InGroup(group, d)
    for _, x in ipairs(group) do
        if x.value == d then return true end
    end
    return false
end

-- 預設難度：上次看的 → 現在所在副本的難度 → 英雄
local function DefaultDiff(group)
    if InGroup(group, View().difficulty) then return View().difficulty end
    local _, instanceType, d = GetInstanceInfo()
    if instanceType ~= "none" and InGroup(group, d) then return d end
    for _, x in ipairs(group) do
        if x.value == 15 or x.value == 2 then return x.value end     -- 英雄
    end
    return group[1] and group[1].value
end

-- 設定檔摘要用的難度列表：「英雄、傳奇」／「全部難度」
local function DiffListText(p)
    if not p.difficulties or not next(p.difficulties) then return L["All difficulties"] end
    local parts, seen = {}, {}
    for _, group in ipairs({ DiffGroup(), Plans.RAID_DIFFICULTIES, Plans.DUNGEON_DIFFICULTIES }) do
        for _, d in ipairs(group) do
            if p.difficulties[d.value] and not seen[d.value] then
                seen[d.value] = true
                parts[#parts + 1] = L[d.label]
            end
        end
    end
    for d in pairs(p.difficulties) do
        if not seen[d] then parts[#parts + 1] = Plans.DifficultyLabel(d) end
    end
    return table.concat(parts, L[", "])
end

------------------------------------------------------------
-- 選擇：每一層變了就把下一層夾回合法值，並記進 planView
------------------------------------------------------------
local function Remember()
    local v = View()
    v.instance, v.boss, v.difficulty, v.profile = sel.inst, sel.boss, sel.diff, sel.pid
end

local function FixProfile()
    local list_ = (sel.boss and sel.diff) and Plans.Profiles(sel.boss, sel.diff) or {}
    local keep
    for _, p in ipairs(list_) do
        if p.id == sel.pid then keep = p.id end
    end
    if not keep then
        for _, p in ipairs(list_) do
            if p.id == View().profile then keep = p.id end
        end
    end
    sel.pid = keep or (list_[1] and list_[1].id) or nil
end

local function FixDiff()
    local group = DiffGroup()
    if not InGroup(group, sel.diff) then sel.diff = DefaultDiff(group) end
    FixProfile()
end

local function FixBoss()
    local rows = BossRows(sel.inst)
    if not FindRow(rows, sel.boss) then
        local remembered = View().boss
        sel.boss = FindRow(rows, remembered) and remembered or (rows[1] and rows[1].id) or nil
    end
    FixDiff()
    return rows
end

-- 第一次打開：所在副本 → 上次看的 → 最新資料片第一個團隊副本 → 第一個副本 → 其他首領
local function ChooseDefaults(cur)
    chosen = true
    local v = View()
    if cur then
        sel.inst = cur.value
    elseif v.instance == OTHER or instanceById[v.instance] then
        sel.inst = v.instance
    else
        for _, inst in ipairs(instances) do
            if inst.isRaid then
                sel.inst = inst.value
                break
            end
        end
        sel.inst = sel.inst or (instances[1] and instances[1].value) or OTHER
    end
    sel.boss, sel.diff, sel.pid = v.boss, nil, v.profile
end

-- 跳到某一份設定檔（匯入後）：首領所在的副本、一個它適用的難度分頁
local function GoToProfile(pid)
    local encID = Plans.BossOf(pid)
    local p = Plans.Get(pid)
    if not encID or not p then return end
    sel.inst = InstanceOf(encID)
    sel.boss = encID
    local group = DiffGroup()
    if not (InGroup(group, sel.diff) and Plans.AppliesTo(p, sel.diff)) then
        sel.diff = nil
        for _, d in ipairs(group) do
            if Plans.AppliesTo(p, d.value) then
                sel.diff = d.value
                break
            end
        end
        sel.diff = sel.diff or DefaultDiff(group)
    end
    sel.pid = pid
end

------------------------------------------------------------
-- 清單資料
------------------------------------------------------------
local function MRTVariant(profile)
    if not sel.boss or not MD.Has(sel.boss) then return end
    local idx = profile and profile.mrtVariant
    local variants = MD.Variants(sel.boss)
    if idx and variants[idx] then return idx end
    return MD.DefaultVariant(sel.boss, sel.diff)
end

local function Items()
    local items = {}
    local profile = Profile()
    if not profile then return items end
    for i, e in ipairs(profile.entries) do
        -- 「每一次」的沒有秒數：排在最前面（-1 秒；它們之間照 entries 本來的順序）
        local every = Plans.IsEvery(e)
        items[#items + 1] = { kind = "entry", index = i, entry = e, t = every and -1 or (e.t or 0), every = every }
    end
    if View().mrt then
        local v = MRTVariant(profile)
        if v then
            local nth = {}
            for _, ev in ipairs(MD.Events(sel.boss, v)) do
                nth[ev.spell] = (nth[ev.spell] or 0) + 1
                items[#items + 1] = { kind = "mrt", ev = ev, t = ev.t, n = nth[ev.spell] }
            end
            for _, ph in ipairs(MD.Phases(sel.boss, v)) do
                items[#items + 1] = { kind = "phase", phase = ph.phase, t = ph.t }
            end
        end
    end
    local rec = View().recorded and ns.db.recorded[sel.boss]
    if rec then
        for _, ev in ipairs(rec.events) do
            items[#items + 1] = { kind = "recorded", ev = ev, t = ev.t or 0 }
        end
    end
    table.sort(items, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
        return (a.index or 0) < (b.index or 0)
    end)
    return items
end

------------------------------------------------------------
-- 彈窗
------------------------------------------------------------
-- entry：要改的那一條（表的參考）。排序後 index 會變，所以存檔前才找它現在的位置
local function OpenEntryPopup(values, entry)
    local pid = sel.pid
    if not Plans.Get(pid) then return end
    ns.EntryEditor.Open(values, function(v)
        Plans.SaveEntry(pid, v, entry and Plans.IndexOf(pid, entry))
        ns.Fire("PlansChanged")
    end, entry and L["Edit reminder"] or L["Add reminder"], sel.boss)
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

-- 貼上匯入：米利字串（!MBT1!）、DreamForgeTools（DSR1!）、NSRT 筆記、MRT 筆記行，自動判斷。
-- 預設新增一份設定檔（預設不生效）；可以改成併入目前的設定檔
local function CreateImportPopup(parent)
    local W_, H_ = 560, 440
    local popup = PopupShell("MiliUIBT_ImportPopup", parent, W_, H_, L["Paste reminders"])
    popup.hint:SetText(L["Paste any of these: a MiliUI Boss Timeline string (!MBT1!), a DreamForgeTools plan (DSR1!), an NSRT note (starts with EncounterID:), or MRT note lines like {time:01:30} {spell:31821} text. Times counted from a later phase ({time:00:54,p2}) are skipped; turn off the dynamic timer when exporting from lorrgs."])

    -- 說明列了四種格式、三四行長：貼上框接在說明下面，不寫死位置
    local box = W.CreateScrollEditBox(popup, W_ - 28, 204)
    box:SetPoint("TOPLEFT", popup.hint, "BOTTOMLEFT", 0, -10)
    popup.box = box

    -- 新增一份／併入目前那份
    local mode = "new"
    local bNew = W.CreateButton(popup, L["Add as a new profile"], "accent-hover", 120, 20)
    local bMerge = W.CreateButton(popup, L["Merge into the current profile"], "accent-hover", 120, 20)
    W.FitButton(bNew, 120, 20)
    W.FitButton(bMerge, 120, 20)
    bNew.id, bMerge.id = "new", "merge"
    bNew:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -10)
    bMerge:SetPoint("LEFT", bNew, "RIGHT", 3, 0)
    local modeNote = popup:CreateFontString(nil, "OVERLAY")
    modeNote:SetFontObject(W.fontSmall)
    modeNote:SetTextColor(0.6, 0.6, 0.6)
    modeNote:SetPoint("TOPLEFT", bNew, "BOTTOMLEFT", 0, -6)
    modeNote:SetWidth(W_ - 28)
    modeNote:SetJustifyH("LEFT")
    local function SetMode(id)
        mode = id
        modeNote:SetText(id == "merge"
            and L["Adds the reminders to the profile you are looking at; ones already there are skipped."]
            or L["A new profile is added and left inactive, so it won't stack with yours until you tick Active."])
    end
    local highlight = W.CreateButtonGroup({ bNew, bMerge }, SetMode)

    local function Done(pid)
        popup:Hide()
        if pid then
            GoToProfile(pid)
            -- 匯入的字串不一定帶首領名稱（DreamForgeTools、NSRT 只有 ID）：側欄認得這隻首領就用冒險指南的名字
            local row = FindRow(BossRows(sel.inst), sel.boss)
            local boss = Plans.Boss(sel.boss)
            if row and boss and (not boss.name or boss.name == tostring(sel.boss)) then
                Plans.EnsureBoss(sel.boss, row.name, row.journal, sel.inst ~= OTHER and sel.inst or nil)
            end
        end
        ns.Fire("PlansChanged")
    end

    -- 匯入結果的補充說明（DreamForgeTools／NSRT 才有 stats）
    local function ReportStats(stats)
        if not stats then return end
        if stats.phased > 0 then
            ns.Print(L["%d reminders are in phase 2 or later. Their times were worked out from the plan's phase timings; real phase changes drift from pull to pull."]:format(stats.phased))
        end
        if stats.phaseSkipped > 0 then
            ns.Print(L["%d lines count from a later phase (ph:2 or more) and were skipped: the note doesn't say when phases start."]:format(stats.phaseSkipped))
        end
        if stats.notMe then
            ns.Print(L["Your character isn't in this plan (%d personal reminders skipped)."]:format(stats.personal))
        end
        if stats.skipped > 0 then
            ns.Print(L["%d lines were skipped (before the pull, empty or unreadable)."]:format(stats.skipped))
        end
    end

    local function AddNew(payload)
        local added, _, pid = ns.Share.Import(payload)
        local boss = Plans.Boss(payload.id)
        local p = Plans.Get(pid)
        ns.Print(L["Added the profile \"%s\" to %s with %d reminders. It is not active yet; tick Active to use it."]:format(
            p and p.name or "", boss and boss.name or tostring(payload.id), added))
        ReportStats(payload.stats)
        Done(pid)
    end

    -- 米利字串、DreamForgeTools、NSRT 解出來的 payload 都走這裡
    local function ImportPayload(payload)
        local cur = Profile()
        if mode == "merge" and cur then
            if Plans.BossOf(sel.pid) == payload.id then
                local pid = sel.pid
                local added, skipped = Plans.Batch(pid, function() return ns.Share.ImportInto(pid, payload) end)
                ns.Print(L["Merged %d reminders into %s (%d were already there)."]:format(added, cur.name or "", skipped))
                ReportStats(payload.stats)
                Done(pid)
                return
            end
            ns.Print(L["This string is for another boss, so it was added as a new profile instead."])
        end
        -- DreamForgeTools 同一份方案（boardId 相同）匯入過：問要覆蓋、另存一份、還是取消
        local old = payload.dftBoardId and ns.Share.FindDftProfile(payload.id, payload.dftBoardId)
        if old then
            popup:Hide()
            local p = Plans.Get(old)
            choicePopup.text:SetText(L["You already imported this DreamForgeTools plan as \"%s\". Overwrite it, or keep both?"]:format(p and p.name or ""))
            choicePopup.onOverwrite = function()
                local added = ns.Share.Overwrite(old, payload)
                ns.Print(L["Overwrote \"%s\" with %d reminders."]:format(payload.name or "", added))
                ReportStats(payload.stats)
                Done(old)
            end
            choicePopup.onNew = function() AddNew(payload) end
            choicePopup:Show()
            return
        end
        AddNew(payload)
    end

    local function ImportString(text, decode)
        local payload, err = decode(text)
        if not payload then
            ns.Print(err)
            return
        end
        ImportPayload(payload)
    end

    -- MRT 筆記行：沒有首領資訊，一律進目前選的首領
    local function ImportLines(text)
        if not sel.boss then
            ns.Print(L["Pick a boss on the left first; MRT note lines don't say which boss they are for."])
            return
        end
        if not Plans.LooksLikeNote(text) then
            ns.Print(L["Nothing to import: no {time:} lines found."])
            return
        end
        local pid, created = sel.pid, false
        if mode ~= "merge" or not Profile() then
            local row = FindRow(BossRows(sel.inst), sel.boss)
            Plans.EnsureBoss(sel.boss, row and row.name, row and row.journal, sel.inst ~= OTHER and sel.inst or nil)
            local p = Plans.NewProfile(sel.boss, L["Imported plan"], sel.diff)
            p.active, p.source = false, "import"
            pid, created = p.id, true
        end
        local added, skipped, phased = Plans.ImportNote(pid, text)
        ns.Print(L["Imported %d, skipped %d, phase-relative (not supported) %d."]:format(added, skipped, phased))
        if created then
            if added == 0 then
                Plans.DeleteProfile(pid)      -- 什麼都沒匯進來就不留一份空的
                pid = nil
            else
                ns.Print(L["The new profile is not active yet; tick Active to use it."])
            end
        end
        Done(pid)
    end

    local ok = W.CreateButton(popup, L["Import"], "primary", 90, 22)
    W.FitButton(ok, 90, 22)
    ok:SetPoint("BOTTOMLEFT", 26, 12)
    ok:SetScript("OnClick", function()
        local text = box.editBox:GetText() or ""
        if ns.Share.IsShareString(text) then
            ImportString(text, ns.Share.Decode)
        elseif ns.Convert.IsDSR(text) then
            ImportString(text, ns.Convert.DecodeDSR)
        elseif ns.Convert.IsNSRT(text) then
            ImportString(text, ns.Convert.ParseNSRT)
        else
            ImportLines(text)
        end
    end)
    local cancel = W.CreateButton(popup, L["Cancel"], "normal", 90, 22)
    cancel:SetPoint("BOTTOMRIGHT", -26, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)

    function popup:Open()
        box.editBox:SetText("")
        -- 沒有目前的設定檔就沒有東西可以併入
        bMerge:SetShown(Profile() ~= nil)
        highlight(bNew)
        SetMode("new")
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
        if format == "note" then return ns.Share.ExportNote(sel.pid) end
        return ns.Share.Export(sel.pid) or L["This game client can't create share strings."]
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
        local hint = id == "note"
            and L["MRT note lines: time, spell and text only. MRT notes and other addons that read {time:} lines can use it."]
            or L["Everything in this profile, including sounds, conditions and anchors. Paste it into Paste reminders on another character or for a friend; it arrives as a new profile."]
        -- MRT 筆記只有秒數：「每一次」的提示放不進去，講一聲有幾條
        local every = id == "note" and Plans.CountEvery(Plans.Get(sel.pid)) or 0
        if every > 0 then
            hint = hint .. "\n" .. L["%d \"every cast\" reminders are not in the MRT note lines (they have no time)."]:format(every)
        end
        popup.hint:SetText(hint)
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

-- 戰後回顧：錨點提示 上一場實際 vs 備援時間；一鍵套用、整份平移（都只動目前這份設定檔）
local function CreateReviewPopup(parent)
    local W_, H_ = 600, 420
    local popup = PopupShell("MiliUIBT_ReviewPopup", parent, W_, H_, L["Review last pull"])
    popup.hint:SetText(L["Reminders that follow a boss cast are compared with when that cast actually happened in your last pull. Reminders with a fixed time have nothing to compare; use Shift all to move them."])

    local rlist = W.CreateRowList(popup, W_ - 28, 220, 22, function(row)
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
    rlist:SetPoint("TOPLEFT", 14, -84)

    local summary = popup:CreateFontString(nil, "OVERLAY")
    summary:SetFontObject(W.fontSmall)
    summary:SetPoint("TOPLEFT", rlist, "BOTTOMLEFT", 0, -6)
    summary:SetWidth(W_ - 28)
    summary:SetJustifyH("LEFT")

    local function Refresh_()
        local rows = ns.Review.Rows(sel.pid)
        local off = 0
        rlist:Update(rows, function(row, r)
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
        summary:SetText((sel.boss and ns.db.recorded[sel.boss]) and L["%d reminders differ from your last pull."]:format(off)
            or L["No recorded pull for this boss yet."])
    end

    local apply = W.CreateButton(popup, L["Use last pull's times"], "primary", 150, 22)
    W.FitButton(apply, 150, 22)
    apply:SetPoint("BOTTOMLEFT", 14, 44)
    apply:SetScript("OnClick", function()
        local n = ns.Review.ApplyAnchored(sel.pid)
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
        ns.Review.ShiftAll(sel.pid, d)
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

    -- 改名與新增共用（標題每次開都給）
    renamePopup = W.CreateInputPopup(parent, 340, L["Rename"], {
        { key = "name", label = L["Name"] },
    })

    deletePopup = W.CreateConfirmPopup(parent, 320, L["Delete this profile?"], function()
        if Plans.Get(sel.pid) then
            Plans.DeleteProfile(sel.pid)
            sel.pid = nil
            ns.Fire("PlansChanged")
        end
    end)

    -- 手動輸入首領戰 ID（冒險指南沒收的首領：世界首領的活動版、測試用、舊資料片）
    idPopup = W.CreateInputPopup(parent, 380, L["Enter an encounter ID"], {
        { key = "id",   label = L["Encounter ID"],
          hint = L["The ID from the boss fight itself, not the Adventure Guide. After one pull the last boss you fought is filled in for you."] },
        { key = "name", label = L["Name"] },
    })

    -- DreamForgeTools 同一份方案再匯入：覆蓋／另存一份／取消（文字與動作每次開之前填）
    choicePopup = W.CreateChoicePopup(parent, 420, "", {
        { text = L["Overwrite"], color = "primary",
          onClick = function() if choicePopup.onOverwrite then choicePopup.onOverwrite() end end },
        { text = L["Save as a new profile"], color = "normal",
          onClick = function() if choicePopup.onNew then choicePopup.onNew() end end },
        { text = L["Cancel"], color = "normal" },
    })

    importPopup = CreateImportPopup(parent)
    exportPopup = CreateExportPopup(parent)
    reviewPopup = CreateReviewPopup(parent)
end

------------------------------------------------------------
-- 側欄的首領列
--
-- 選中＝整列亮底＋左緣一條職業色（顏色以外的第二個訊號）＋白字；其他列灰白字、滑過微亮。
-- 右邊灰色數字＝設定檔數、綠點＝有生效中的（綠是唯一的例外色：它講的是「開戰會跑」，跟選取無關）。
------------------------------------------------------------
local function BuildBossRow(row)
    local b = CreateFrame("Button", nil, row)
    b:SetAllPoints()
    row.btn = b
    row.bg = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.bg:Hide()
    row.bar = b:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT")
    row.bar:SetWidth(P.Scale(2))
    row.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.bar:SetVertexColor(W.Accent(1))
    row.bar:Hide()
    row.dot = b:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(6, 6)
    row.dot:SetPoint("RIGHT", -4, 0)
    row.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.dot:SetVertexColor(GREEN[1], GREEN[2], GREEN[3], 1)
    row.count = b:CreateFontString(nil, "OVERLAY")
    row.count:SetFontObject(W.fontSmall)
    row.count:SetPoint("RIGHT", -14, 0)
    row.count:SetTextColor(0.6, 0.6, 0.6)
    row.text = b:CreateFontString(nil, "OVERLAY")
    row.text:SetFontObject(W.fontNormal)
    row.text:SetPoint("LEFT", 8, 0)
    row.text:SetPoint("RIGHT", -30, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    local function Paint(hover)
        local on = row.item and row.item.id == sel.boss
        if on then
            row.bg:SetVertexColor(W.Accent(0.35))
            row.bg:Show()
        elseif hover then
            row.bg:SetVertexColor(1, 1, 1, 0.06)
            row.bg:Show()
        else
            row.bg:Hide()
        end
        row.bar:SetShown(on)
        local c = on and 1 or 0.8
        row.text:SetTextColor(c, c, c)
    end
    row.Paint = Paint
    b:SetScript("OnEnter", function() Paint(true) end)
    b:SetScript("OnLeave", function() Paint(false) end)
    b:SetScript("OnClick", function()
        local it = row.item
        if not it or it.id == sel.boss then return end
        sel.boss = it.id
        sel.pid = nil
        FixDiff()
        Remember()
        ns.Fire("PlansChanged")
    end)
end

local function UpdateBossRow(row, it)
    row.item = it
    row.text:SetText(it.num and ("%d. %s"):format(it.num, it.name) or it.name)
    local n, active = Plans.BossSummary(it.id)
    row.count:SetText(n > 0 and n or "")
    row.dot:SetShown(active)
    row.Paint(row.btn:IsMouseOver())
end

------------------------------------------------------------
-- 清單列（清單檢視）
--
-- 欄位：時間、圖示、文字（撐滿）、提前、來源、按鈕。右邊四欄錨在列的右緣，寬度變了文字欄自己伸縮
------------------------------------------------------------
local COL = { time = 8, icon = 70, text = 94 }
local RCOL = { btn = 96, src = 218, lead = 278 }      -- 離列右緣多遠（各欄的左緣）

local function Font(parent, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function PlaceCols(parent, f)
    f.time:SetPoint("LEFT", parent, "LEFT", COL.time, 0)
    f.time:SetWidth(58)
    f.lead:SetPoint("LEFT", parent, "RIGHT", -RCOL.lead, 0)
    f.lead:SetWidth(52)
    f.src:SetPoint("LEFT", parent, "RIGHT", -RCOL.src, 0)
    f.src:SetWidth(RCOL.src - RCOL.btn - 8)
    f.text:SetPoint("LEFT", parent, "LEFT", COL.text, 0)
    f.text:SetPoint("RIGHT", parent, "RIGHT", -RCOL.lead - 8, 0)
end

local function BuildRow(row)
    row.time = Font(row, "RIGHT")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row, "LEFT", COL.icon, 0)
    row.text = Font(row)
    row.lead = Font(row, "RIGHT")
    row.src  = Font(row)
    row.src:SetFontObject(W.fontSmall)
    PlaceCols(row, row)

    row.edit = W.CreateButton(row, L["Edit"], "normal", 44, 18)
    row.edit:SetPoint("LEFT", row, "RIGHT", -RCOL.btn, 0)
    row.edit:SetScript("OnClick", function()
        local it = row.item
        if it and it.kind == "entry" then OpenEntryPopup(EntryValues(it.entry), it.entry) end
    end)

    row.del = W.CreateButton(row, L["Delete"], "red", 44, 18)
    row.del:SetPoint("LEFT", row.edit, "RIGHT", 4, 0)
    row.del:SetScript("OnClick", function()
        local it = row.item
        if it and it.kind == "entry" then
            Plans.RemoveEntry(sel.pid, it.index)
            ns.Fire("PlansChanged")
        end
    end)

    -- 唯讀列：以這一秒新增一條自己的提示
    row.copy = W.CreateButton(row, L["Add at this time"], "normal", 92, 18)
    W.FitButton(row.copy, 92, 18)
    row.copy:SetPoint("LEFT", row, "RIGHT", -RCOL.btn, 0)
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
        row.time:SetText(it.every and L["Every"] or Plans.FormatTime(e.t))
        row.icon:SetTexture(icon)
        row.icon:SetDesaturated(not on)
        local tags = ""
        if it.every then
            -- 「每一次」：寫出綁的是哪個技能、偏移多少
            local a = e.anchor
            local name = MD.SpellInfo(a.spell) or ("#" .. a.spell)
            local off = (a.offset or 0) ~= 0 and (" %+gs"):format(a.offset) or ""
            tags = tags .. "  |cffffd100" .. L["[every %s]"]:format(name .. off) .. "|r"
        elseif e.anchor then
            tags = tags .. "  |cffffd100" .. L["[follows]"] .. "|r"
        end
        if e.sound or e.tts then tags = tags .. " |cff9d9d9d" .. L["[sound]"] .. "|r" end
        if Plans.HasAudience(e) then tags = tags .. " |cff9d9d9d" .. L["[only some]"] .. "|r" end
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
-- 下拉項目
------------------------------------------------------------
local function InstanceItems()
    local items = {}
    for _, inst in ipairs(instances) do
        items[#items + 1] = { text = inst.text, value = inst.value }
    end
    items[#items + 1] = { text = L["Other bosses"], value = OTHER }
    return items
end

-- 「✓ 名稱  (英雄、傳奇) · 作者」：生效中的打勾，沒生效的前面留同寬空白
local function ProfileItems()
    local items = {}
    for _, p in ipairs(Plans.Profiles(sel.boss, sel.diff)) do
        local text = (p.active and CHECK_MARK or CHECK_BLANK) .. " " .. (p.name or "?")
            .. "  |cff9d9d9d(" .. DiffListText(p) .. ")"
            .. (p.author and (" · " .. p.author) or "") .. "|r"
        items[#items + 1] = { text = text, value = p.id }
    end
    return items
end

local function VariantItems()
    local items = {}
    for _, v in ipairs(MD.Variants(sel.boss)) do
        local label = v.difficulty and Plans.DifficultyLabel(v.difficulty) or ("#" .. v.index)
        if v.keystone then label = label .. " +" .. v.keystone end
        if v.length then label = label .. "  " .. Plans.FormatTime(math.floor(v.length)) end
        if v.note then label = label .. "  " .. v.note end
        items[#items + 1] = { text = label, value = v.index }
    end
    return items
end

------------------------------------------------------------
-- 首領頭像：標題列左邊一格 3D 模型，只抓目前選的那隻
--
-- 找模型的成本在 Journal.BossArt（側欄給了冒險指南首領 ID 就直接查；沒有才看所在副本＋最新資料片，
-- 不整本掃）；找到就存進首領紀錄（bosses[id].display／journal），之後切到這隻首領零成本。
-- 還沒有紀錄的首領（沒建過設定檔）不為了頭像建紀錄，Journal 那邊本來就有快取。
-- 同一個模型不重設：SetDisplayInfo 會重新串流、閃一下（.claude/notes/wow-playermodel-setunit-restreams.md）
------------------------------------------------------------
local function UpdateBoss(encID, journal)
    if not bossBox then return end
    bossBox:SetShown(encID ~= nil)
    if not encID then return end
    local boss = Plans.Boss(encID)
    local display = boss and boss.display
    if not display then
        local jEnc
        display, jEnc = J.BossArt(encID, journal or (boss and boss.journal))
        if display and boss then boss.display, boss.journal = display, boss.journal or jEnc end
    end
    if display == bossModel.display and bossModel.encID == encID then return end
    bossModel.display, bossModel.encID = display, encID
    bossModel:ClearModel()
    if display and pcall(bossModel.SetDisplayInfo, bossModel, display) then
        bossModel:SetAlpha(1)
        bossSkull:Hide()
    else
        bossModel:SetAlpha(0)
        bossSkull:Show()
    end
end

------------------------------------------------------------
-- 版面（Init 與收合側欄時跑）：內容區的東西全部從 ContentX／ContentW 推算
------------------------------------------------------------
local function Layout()
    local open = View().sidebar
    local cx, cw = ContentX(), ContentW()
    local lw = cw - 20                      -- 卡片內距左右各 10

    instDD:SetShown(open)
    bossList:SetShown(open)
    btnManual:SetShown(open)
    btnCollapse:ClearAllPoints()
    if open then
        btnCollapse:SetPoint("BOTTOMLEFT", tab, "TOPLEFT", SIDE_X + SIDE_W - 22, CARD_BOTTOM)
        btnCollapse:SetText("<<")
    else
        btnCollapse:SetPoint("BOTTOMLEFT", tab, "TOPLEFT", SIDE_X, CARD_BOTTOM)
        btnCollapse:SetText(">>")
    end

    bossBox:ClearAllPoints()
    bossBox:SetPoint("TOPLEFT", tab, "TOPLEFT", cx, TOP)
    noBossText:ClearAllPoints()
    noBossText:SetPoint("TOPLEFT", tab, "TOPLEFT", cx + 2, TOP - 4)
    noBossText:SetWidth(cw - 4)

    local stripH = diffTabs:Place(cx, TOP - AVATAR - 10, cw)
    diffTabs:SetBottom(CARD_BOTTOM)
    local ct = TOP - AVATAR - 10 - stripH      -- 卡片上緣
    local x = cx + 10

    profLbl:ClearAllPoints()
    profLbl:SetPoint("TOPLEFT", tab, "TOPLEFT", x, ct - 12)
    activeCB:ClearAllPoints()
    activeCB:SetPoint("TOPLEFT", tab, "TOPLEFT", x, ct - 36)
    activeNote:ClearAllPoints()
    activeNote:SetPoint("TOPLEFT", tab, "TOPLEFT", x, ct - 60)
    activeNote:SetWidth(lw)
    btnPreview:ClearAllPoints()
    btnPreview:SetPoint("TOPLEFT", tab, "TOPLEFT", x, ct - 80)

    local edTop = ct - 108
    local edH = edTop - BOTTOM_ROW_Y - 8
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", tab, "TOPLEFT", x, edTop)
    P.Size(head, lw - 20, 18)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", tab, "TOPLEFT", x, edTop - 20)
    P.Size(list, lw, edH - 20)
    editor:SetWidth(lw)
    editor.frame:SetHeight(edH)
    editor.frame:ClearAllPoints()
    editor.frame:SetPoint("TOPLEFT", tab, "TOPLEFT", x, edTop)

    btnAdd:ClearAllPoints()
    btnAdd:SetPoint("TOPLEFT", tab, "TOPLEFT", x, BOTTOM_ROW_Y)
    recNote:ClearAllPoints()
    recNote:SetPoint("TOPLEFT", tab, "TOPLEFT", x, NOTE_Y)
    recNote:SetWidth(lw)

    emptyText:ClearAllPoints()
    emptyText:SetPoint("TOPLEFT", tab, "TOPLEFT", x, ct - 14)
    emptyText:SetWidth(lw)
    btnCreate:ClearAllPoints()
    btnCreate:SetPoint("TOPLEFT", emptyText, "BOTTOMLEFT", 0, -12)
end

------------------------------------------------------------
-- 重畫整頁
------------------------------------------------------------
local profileWidgets

local function Refresh()
    if not tab then return end
    local cur = RebuildInstances()
    if not chosen then ChooseDefaults(cur) end
    -- 離開副本之後「所在副本」那一筆就不在清單裡了
    if sel.inst ~= OTHER and not instanceById[sel.inst] then
        sel.inst = instances[1] and instances[1].value or OTHER
    end
    local rows = FixBoss()
    Remember()

    -- 側欄
    instDD:SetItems(InstanceItems())
    instDD:SetSelectedValue(sel.inst)
    bossList:Update(rows, UpdateBossRow)
    sideEmpty:SetShown(View().sidebar and #rows == 0)
    sideEmpty:SetText(sel.inst == OTHER and L["Bosses you entered by ID, or from older expansions, show up here."]
        or L["The Adventure Guide has no bosses for this instance yet."])

    -- 標題列
    local row = FindRow(rows, sel.boss)
    local boss = Plans.Boss(sel.boss)
    local hasBoss = sel.boss ~= nil
    UpdateBoss(sel.boss, row and row.journal)
    bossName:SetShown(hasBoss)
    bossSub:SetShown(hasBoss)
    if hasBoss then
        bossName:SetText((row and row.name) or (boss and boss.name) or tostring(sel.boss))
        local inst = instanceById[sel.inst]
        bossSub:SetText(((inst and inst.text) and (inst.text .. "  ") or "") .. "|cff6f6f6fID " .. sel.boss .. "|r")
    end
    noBossText:SetShown(not hasBoss)
    noBossText:SetText(View().sidebar and L["Pick a boss on the left."] or L["Pick a boss: open the list with >> on the left."])

    -- 難度分頁
    diffTabs:SetShown(hasBoss)
    if hasBoss then
        local ids = {}
        for _, d in ipairs(DiffGroup()) do ids[#ids + 1] = d.value end
        local h = diffTabs:SetTabs(ids)
        diffTabs:Select(sel.diff)
        if diffTabs.lastH ~= h then
            diffTabs.lastH = h
            Layout()
        end
    end

    local profile = Profile()
    local has = profile ~= nil
    for _, w in ipairs(profileWidgets) do w:SetShown(has) end
    for _, cb in ipairs(alsoCBs) do cb:SetShown(false) end
    local mode = View().mode == "timeline" and "timeline" or "list"
    head:SetShown(has and mode == "list")
    list:SetShown(has and mode == "list")
    editor.frame:SetShown(has and mode == "timeline")
    for _, b in ipairs(modeButtons) do
        b:SetShown(has)
        if b.id == mode then highlightMode(b) end
    end

    -- 空狀態：選了首領、這個難度沒有設定檔
    emptyText:SetShown(hasBoss and not has)
    btnCreate:SetShown(hasBoss and not has)
    btnEmptyImport:SetShown(hasBoss and not has)
    if hasBoss and not has then
        local total = Plans.BossSummary(sel.boss)
        emptyText:SetText(total > 0
            and L["None of this boss's profiles are used on %s. Create one, or tick it under Also for on another difficulty's profile."]:format(Plans.DifficultyShort(sel.diff))
            or L["No profile for this boss yet. Create one for %s, or paste one from someone else."]:format(Plans.DifficultyShort(sel.diff)))
    end

    local running = ns.Scheduler.Running()
    btnStop:SetShown(has and running and running.test and true or false)

    local hasMRT = has and MD.Has(sel.boss)
    showRecCB:SetShown(has)
    showMRTCB:SetShown(hasMRT)
    mrtDD:SetShown(hasMRT and View().mrt)

    if not has then
        statusText:SetText("")
        recNote:SetText("")
        return
    end

    profDD:SetItems(ProfileItems())
    profDD:SetSelectedValue(sel.pid)
    activeCB:SetChecked(profile.active == true)
    btnUndo:SetAlpha(Plans.CanUndo(sel.pid) and 1 or 0.4)

    -- 也用在：每個難度一個勾；目前分頁那個一定勾著、不能拿掉（拿掉就從眼前消失了）
    local prev
    for i, d in ipairs(DiffGroup()) do
        local cb = alsoCBs[i]
        cb.diff = d.value
        cb.label:SetText(L[d.label])
        cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 8), 0, 0)
        cb:SetChecked(Plans.AppliesTo(profile, d.value))
        local locked = d.value == sel.diff
        cb:SetEnabled(not locked)
        local c = locked and 0.5 or 1
        cb.label:SetTextColor(c, c, c)
        cb:ClearAllPoints()
        if prev then
            cb:SetPoint("LEFT", prev.label, "RIGHT", 12, 0)
        else
            cb:SetPoint("LEFT", alsoLbl, "RIGHT", 8, 0)
        end
        cb:Show()
        prev = cb
    end

    showRecCB:SetChecked(View().recorded)
    showMRTCB:SetChecked(View().mrt)
    if hasMRT then
        mrtDD:SetItems(VariantItems())
        mrtDD:SetSelectedValue(MRTVariant(profile))
    end

    -- 立即測試：沒有會跑的提示就停用（不然按了什麼都不會發生）；正在測這份＝字改現況＋停用
    local testingThis = running and running.test and running.id == sel.pid
    local everyN = Plans.CountEvery(profile)
    btnTest.reason = ns.Scheduler.RunnableCount(profile) == 0
        and (#profile.entries == 0 and L["Add a reminder first."]
             or everyN == #profile.entries and L["\"Every cast\" reminders only appear when the ability is recognized in combat, so they can't be tested."]
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
    local rec = ns.db.recorded[sel.boss]
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
    -- 時間軸檢視沒有 MRT 列就畫不出「每一次」的重複標記：講一聲去清單看
    local edVariant = View().mrt and hasMRT and MRTVariant(profile) or nil
    if mode == "timeline" and not edVariant and everyN > 0 then
        notes[#notes + 1] = L["%d \"every cast\" reminders are shown in the list view."]:format(everyN)
    end
    recNote:SetText(table.concat(notes, "\n"))

    if mode == "timeline" then
        editor:SetPlan(sel.pid, {
            encounterID = sel.boss,
            mrtVariant  = edVariant,
            recorded    = View().recorded,
            review      = ns.Review.Rows(sel.pid),
        })
    else
        list:Update(Items(), UpdateRow)
    end
end

-- 建一份設定檔要先有首領紀錄：名稱、冒險指南 ID、副本從側欄那一列帶
local function EnsureSelectedBoss()
    local row = FindRow(BossRows(sel.inst), sel.boss)
    return Plans.EnsureBoss(sel.boss, row and row.name, row and row.journal, sel.inst ~= OTHER and sel.inst or nil)
end

local function SelectNewProfile(p)
    if not p then return end
    sel.pid = p.id
    Remember()
    ns.Fire("PlansChanged")
end

local function BuildSidebar()
    --------------------------------------------------------
    -- 側欄
    --------------------------------------------------------
    instDD = W.CreateDropdown(tab, SIDE_W, {}, function(value)
        if value == sel.inst then return end
        sel.inst = value
        sel.boss, sel.pid = nil, nil
        Refresh()
    end)
    instDD:SetPoint("TOPLEFT", tab, "TOPLEFT", SIDE_X, TOP)

    bossList = W.CreateRowList(tab, SIDE_W, (TOP - 26) - (CARD_BOTTOM + 30), BOSS_ROW_H, BuildBossRow)
    bossList:SetPoint("TOPLEFT", tab, "TOPLEFT", SIDE_X, TOP - 26)

    sideEmpty = tab:CreateFontString(nil, "OVERLAY")
    sideEmpty:SetFontObject(W.fontSmall)
    sideEmpty:SetTextColor(0.6, 0.6, 0.6)
    sideEmpty:SetPoint("TOPLEFT", bossList, "TOPLEFT", 4, -4)
    sideEmpty:SetWidth(SIDE_W - 8)
    sideEmpty:SetJustifyH("LEFT")

    btnManual = W.CreateButton(tab, L["Enter an encounter ID"], "normal", SIDE_W - 26, 22)
    btnManual:SetPoint("BOTTOMLEFT", tab, "TOPLEFT", SIDE_X, CARD_BOTTOM)
    btnManual:SetScript("OnClick", function()
        local last = ns.db.lastEncounter
        idPopup:Open({ id = last and last.id or "", name = last and last.name or "" }, function(v)
            local id = tonumber(v.id)
            if not id or id <= 0 then
                ns.Print(L["Encounter ID must be a number."])
                return false
            end
            id = math.floor(id)
            -- 名字：自己填的 → 上一場紀錄 → ID（不查冒險指南整本，會卡）
            local rec = ns.db.recorded[id]
            local name = v.name ~= "" and v.name or (Plans.Boss(id) and Plans.Boss(id).name) or (rec and rec.name) or tostring(id)
            Plans.EnsureBoss(id, name)
            sel.inst = InstanceOf(id)
            sel.boss, sel.pid = id, nil
            ns.Fire("PlansChanged")
        end, L["Enter an encounter ID"])
    end)

    btnCollapse = W.CreateButton(tab, "<<", "normal", 22, 22)
    btnCollapse:SetScript("OnClick", function()
        View().sidebar = not View().sidebar
        Layout()
        Refresh()
    end)

end

local function BuildHeader()
    --------------------------------------------------------
    -- 標題列：頭像、首領名稱、清單｜時間軸、參考列
    --------------------------------------------------------
    bossBox = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    bossBox:SetSize(AVATAR, AVATAR)
    W.Stylize(bossBox, { 0.05, 0.05, 0.05, 1 }, { W.Accent(1) })
    bossModel = CreateFrame("PlayerModel", nil, bossBox)
    bossModel:SetPoint("TOPLEFT", 1, -1)
    bossModel:SetPoint("BOTTOMRIGHT", -1, 1)
    -- 鏡頭要等模型載好才吃得進去；1＝特寫臉
    bossModel:SetScript("OnModelLoaded", function(self)
        pcall(self.SetPortraitZoom, self, 1)
    end)
    -- 隱藏時模型會被丟掉（切分頁、關視窗），再顯示要重套一次
    bossModel:SetScript("OnShow", function(self)
        if self.display then pcall(self.SetDisplayInfo, self, self.display) end
    end)
    bossSkull = bossBox:CreateTexture(nil, "ARTWORK")
    bossSkull:SetSize(22, 22)
    bossSkull:SetPoint("CENTER")
    bossSkull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    bossSkull:SetAlpha(0.5)

    bossName = tab:CreateFontString(nil, "OVERLAY")
    bossName:SetFontObject(W.fontTitle)
    bossName:SetPoint("TOPLEFT", bossBox, "TOPRIGHT", 10, -2)
    bossName:SetPoint("RIGHT", tab, "RIGHT", -150, 0)
    bossName:SetJustifyH("LEFT")
    bossName:SetWordWrap(false)

    bossSub = tab:CreateFontString(nil, "OVERLAY")
    bossSub:SetFontObject(W.fontSmall)
    bossSub:SetTextColor(0.6, 0.6, 0.6)
    bossSub:SetPoint("BOTTOMLEFT", bossBox, "BOTTOMRIGHT", 10, 2)
    bossSub:SetJustifyH("LEFT")

    noBossText = tab:CreateFontString(nil, "OVERLAY")
    noBossText:SetFontObject(W.fontNormal)
    noBossText:SetJustifyH("LEFT")

    -- 清單｜時間軸 切換（右上角）
    local bList = W.CreateButton(tab, L["List"], "accent-hover", 60, 20)
    local bTime = W.CreateButton(tab, L["Timeline"], "accent-hover", 60, 20)
    W.FitButton(bList, 60, 20)
    W.FitButton(bTime, 60, 20)
    bList.id, bTime.id = "list", "timeline"
    bTime:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -RIGHT_PAD, TOP)
    bList:SetPoint("RIGHT", bTime, "LEFT", -3, 0)
    modeButtons = { bList, bTime }
    highlightMode = W.CreateButtonGroup(modeButtons, function(id)
        View().mode = id
        Refresh()
    end)

    -- 參考列（看的是這隻首領，跟設定檔無關）：右上第二排，靠右
    mrtDD = W.CreateDropdown(tab, 150, {}, function(value)
        local p = Profile()
        if p then
            p.mrtVariant = value
            Refresh()
        end
    end)
    mrtDD:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -RIGHT_PAD, TOP - 24)
    showMRTCB = W.CreateCheckButton(tab, L["MRT timeline"], function(checked)
        View().mrt = checked
        Refresh()
    end)
    showMRTCB:SetPoint("RIGHT", mrtDD, "LEFT", -(showMRTCB.labelGap + showMRTCB.label:GetStringWidth() + 10), 0)
    showRecCB = W.CreateCheckButton(tab, L["Last pull"], function(checked)
        View().recorded = checked
        Refresh()
    end)
    showRecCB:SetPoint("RIGHT", showMRTCB, "LEFT", -(showRecCB.labelGap + showRecCB.label:GetStringWidth() + 14), 0)

    --------------------------------------------------------
    -- 難度分頁卡片：卡片包住下面全部
    --------------------------------------------------------
    local tabDefs, seenTab = {}, {}
    for _, group in ipairs({ Plans.RAID_DIFFICULTIES, Plans.DUNGEON_DIFFICULTIES }) do
        for _, d in ipairs(group) do
            if not seenTab[d.value] then
                seenTab[d.value] = true
                tabDefs[#tabDefs + 1] = { id = d.value, label = L[d.label] }
            end
        end
    end
    diffTabs = W.CreateTabCard(tab, {
        tabs = tabDefs,
        onSelect = function(id)
            sel.diff = id
            FixProfile()
            Remember()
            Refresh()
        end,
    })

end

local function BuildCard()
    --------------------------------------------------------
    -- 卡片第一排：設定檔下拉、新增、複製、改名、刪除
    --------------------------------------------------------
    profLbl = tab:CreateFontString(nil, "OVERLAY")
    profLbl:SetFontObject(W.fontNormal)
    profLbl:SetText(L["Profile"])

    profDD = W.CreateDropdown(tab, 220, {}, function(value)
        sel.pid = value
        Remember()
        Refresh()
    end)
    profDD:SetPoint("LEFT", profLbl, "RIGHT", 8, 0)

    btnNew = W.CreateButton(tab, L["New"], "normal", 50, 20)
    W.FitButton(btnNew, 50, 20)
    btnNew:SetPoint("LEFT", profDD, "RIGHT", 8, 0)
    btnNew:SetScript("OnClick", function()
        if not sel.boss then return end
        renamePopup:Open({ name = L["My plan"] }, function(v)
            if v.name == "" then return false end
            EnsureSelectedBoss()
            SelectNewProfile(Plans.NewProfile(sel.boss, v.name, sel.diff))
        end, L["New profile"])
    end)

    btnCopy = W.CreateButton(tab, L["Copy"], "normal", 50, 20)
    W.FitButton(btnCopy, 50, 20)
    btnCopy:SetPoint("LEFT", btnNew, "RIGHT", 4, 0)
    btnCopy:SetScript("OnClick", function()
        SelectNewProfile(Plans.CopyProfile(sel.pid))
    end)

    btnRename = W.CreateButton(tab, L["Rename"], "normal", 50, 20)
    W.FitButton(btnRename, 50, 20)
    btnRename:SetPoint("LEFT", btnCopy, "RIGHT", 4, 0)
    btnRename:SetScript("OnClick", function()
        local p = Profile()
        if not p then return end
        local pid = p.id
        renamePopup:Open({ name = p.name }, function(v)
            if v.name == "" then return false end
            Plans.RenameProfile(pid, v.name)
            ns.Fire("PlansChanged")
        end, L["Rename"])
    end)

    btnDelete = W.CreateButton(tab, L["Delete"], "red", 50, 20)
    W.FitButton(btnDelete, 50, 20)
    btnDelete:SetPoint("LEFT", btnRename, "RIGHT", 4, 0)
    btnDelete:SetScript("OnClick", function() deletePopup:Show() end)

    --------------------------------------------------------
    -- 卡片第二排：生效、也用在（＋說明灰字）
    --------------------------------------------------------
    activeCB = W.CreateCheckButton(tab, L["Active"], function(checked)
        if sel.pid then
            Plans.SetActive(sel.pid, checked)
            ns.Fire("PlansChanged")
        end
    end)

    alsoLbl = tab:CreateFontString(nil, "OVERLAY")
    alsoLbl:SetFontObject(W.fontNormal)
    alsoLbl:SetPoint("LEFT", activeCB.label, "RIGHT", 28, 0)
    alsoLbl:SetText(L["Also for:"])

    -- 全勾＝全部難度（nil）；目前分頁那個是勾著且停用的，所以這裡只會改到別的難度
    alsoCBs = {}
    for i = 1, 4 do
        local cb
        cb = W.CreateCheckButton(tab, "", function(checked)
            local p = Profile()
            if not p or not cb.diff then return end
            local group = DiffGroup()
            local set = {}
            for _, d in ipairs(group) do
                if Plans.AppliesTo(p, d.value) then set[d.value] = true end
            end
            set[cb.diff] = checked or nil
            set[sel.diff] = true
            local all = true
            for _, d in ipairs(group) do
                if not set[d.value] then all = false end
            end
            Plans.SetDifficulties(sel.pid, not all and set or nil)
            ns.Fire("PlansChanged")
        end)
        alsoCBs[i] = cb
    end

    activeNote = tab:CreateFontString(nil, "OVERLAY")
    activeNote:SetFontObject(W.fontSmall)
    activeNote:SetTextColor(0.6, 0.6, 0.6)
    activeNote:SetJustifyH("LEFT")
    activeNote:SetText(L["Ticked profiles run when the pull starts. Several can be active for one boss; identical reminders only run once."])

    --------------------------------------------------------
    -- 卡片第三排：預覽播放、立即測試、戰後回顧、停止
    --------------------------------------------------------
    btnPreview = W.CreateButton(tab, L["Preview"], "primary", 70, 20)
    W.FitButton(btnPreview, 70, 20)
    btnPreview:SetScript("OnClick", function() ns.PlanPreview.Open(sel.pid, sel.diff) end)

    btnTest = W.CreateButton(tab, L["Test now"], "normal", 80, 20)
    W.FitButton(btnTest, 80, 20)
    btnTest:SetPoint("LEFT", btnPreview, "RIGHT", 6, 0)
    btnTest:SetScript("OnClick", function()
        ns.Scheduler.Test(sel.pid)
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

end

local function BuildBottom()
    --------------------------------------------------------
    -- 清單／時間軸
    --------------------------------------------------------
    head = CreateFrame("Frame", nil, tab)
    headCols = {}
    local function Head(key, text, justify)
        local fs = Font(head, justify)
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(W.Accent(1))
        fs:SetText(text)
        headCols[key] = fs
    end
    Head("time", L["Time"], "RIGHT")
    Head("text", L["Reminder"])
    Head("lead", L["On timeline"], "RIGHT")
    Head("src", L["From"])
    PlaceCols(head, headCols)

    list = W.CreateRowList(tab, 400, 200, ROW_H, BuildRow)

    -- 時間軸檢視：跟「表頭＋清單」同一塊位置，二選一
    editor = ns.PlanEditor.Create(tab, 400, 200, {
        onAdd  = function(values) OpenEntryPopup(values) end,
        onEdit = function(entry) OpenEntryPopup(EntryValues(entry), entry) end,
        onMove = function(entry, t, fromT)
            Plans.MoveEntry(sel.pid, entry, t, fromT)
            ns.Fire("PlansChanged")
        end,
        onMenu = function(entry, btn)
            W.Menu.Show({
                { text = L["Edit"], onClick = function() OpenEntryPopup(EntryValues(entry), entry) end },
                { text = entry.enabled == false and L["Enable"] or L["Disable"], onClick = function()
                    Plans.SetEnabled(sel.pid, entry, entry.enabled == false)
                    ns.Fire("PlansChanged")
                end },
                { text = L["Delete"], onClick = function()
                    local i = Plans.IndexOf(sel.pid, entry)
                    if i then Plans.RemoveEntry(sel.pid, i) end
                    ns.Fire("PlansChanged")
                end },
            }, btn)
        end,
    })

    --------------------------------------------------------
    -- 底下：新增、貼上匯入、匯出、復原
    --------------------------------------------------------
    btnAdd = W.CreateButton(tab, L["+ Add reminder"], "primary", 110, 22)
    W.FitButton(btnAdd, 110, 22)
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

    -- 復原（也可以 Ctrl＋Z）：只記這次登入、每份設定檔 20 步
    btnUndo = W.CreateButton(tab, L["Undo"], "normal", 60, 22)
    W.FitButton(btnUndo, 60, 22)
    btnUndo:SetPoint("LEFT", btnExport, "RIGHT", 6, 0)
    btnUndo:SetScript("OnClick", function()
        if Plans.Undo(sel.pid) then ns.Fire("PlansChanged") end
    end)
    btnUndo:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Undo the last change (Ctrl+Z)"], 1, 1, 1)
        GameTooltip:Show()
    end)
    btnUndo:HookScript("OnLeave", function() GameTooltip:Hide() end)

    recNote = tab:CreateFontString(nil, "OVERLAY")
    recNote:SetFontObject(W.fontSmall)
    recNote:SetJustifyH("LEFT")
    recNote:SetSpacing(2)

    --------------------------------------------------------
    -- 空狀態：這個難度還沒有設定檔
    --------------------------------------------------------
    emptyText = tab:CreateFontString(nil, "OVERLAY")
    emptyText:SetFontObject(W.fontNormal)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetSpacing(4)

    btnCreate = W.CreateButton(tab, L["Create a profile"], "primary", 110, 22)
    W.FitButton(btnCreate, 110, 22)
    btnCreate:SetScript("OnClick", function()
        if not sel.boss then return end
        EnsureSelectedBoss()
        SelectNewProfile(Plans.NewProfile(sel.boss, L["My plan"], sel.diff))
    end)
    btnEmptyImport = W.CreateButton(tab, L["Paste reminders"], "normal", 90, 22)
    W.FitButton(btnEmptyImport, 90, 22)
    btnEmptyImport:SetPoint("LEFT", btnCreate, "RIGHT", 6, 0)
    btnEmptyImport:SetScript("OnClick", function() importPopup:Open() end)

    -- 有設定檔才顯示的（也用在的勾另外管：數量跟著難度那一組）
    profileWidgets = {
        profLbl, profDD, btnNew, btnCopy, btnRename, btnDelete,
        activeCB, alsoLbl, activeNote,
        btnPreview, btnTest, btnReview, statusText,
        btnAdd, btnImport, btnExport, btnUndo, recNote,
    }
end

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, L["Custom timelines"], ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    CreatePopups()
    -- 拆成幾段：一個函式引用的 file-scope local 不能超過 60 個（Lua 5.1 upvalue 上限）
    BuildSidebar()
    BuildHeader()
    BuildCard()
    BuildBottom()

    Layout()

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
                if Plans.Undo(sel.pid) then ns.Fire("PlansChanged") end
            end
        end)
    end
    Refresh()
    tab:Show()
end)

-- 分頁沒開著就不重畫（打完一場、測試結束都會發事件；重畫會碰冒險指南，沒人看就不必）
local function RefreshIfShown()
    if tab and tab:IsVisible() then Refresh() end
end
ns.RegisterCallback("PlansChanged", "plansTab", RefreshIfShown)
ns.RegisterCallback("RecordedChanged", "plansTab", RefreshIfShown)
ns.RegisterCallback("SchedulerChanged", "plansTab", RefreshIfShown)
