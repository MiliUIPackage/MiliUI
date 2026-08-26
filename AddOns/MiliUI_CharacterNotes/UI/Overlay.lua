------------------------------------------------------------
-- 副本浮動視窗：走進副本、首領戰開打時自己跳出來的唯讀小視窗
--
-- 唯讀是刻意的——戰鬥中要的是「看得到」而不是「改得到」。但兩件事例外：
--   * 勾選框點得動（打副本的檢查清單本來就是邊打邊勾的）
--   * 底部有一格「快速記一行」，Enter 就把那行接在筆記後面
-- 要大改內容請按「編輯」，那會開主視窗的編輯器。
--
-- ⚠ 首領切換靠 ENCOUNTER_START，它給的是 dungeonEncounterID；換算成冒險指南的
--   journalEncounterID 要靠 Modules/Journal.lua。換算不出來時還有第二條路：
--   我們自己存的首領筆記上記了 dungeonEncounterID（見 UI/Window.lua 的
--   OpenInstanceNote），直接反查就好。
------------------------------------------------------------
local _, ns = ...

ns.Overlay = {}
local Overlay = ns.Overlay

local W, P, L = ns.W, ns.P, ns.L
local Notes, Media, Journal = ns.Notes, ns.Media, ns.Journal

-- 圖示只用兩種來源：純色方塊（自己畫）與 Interface\ICONS\（那個命名空間只增不減）。
-- Interface\Buttons\ 底下的檔案暴雪改版時會消失，而且是**靜默**的 —— 貼圖路徑錯了
-- 不會報錯，只是那顆按鈕變空白，等玩家回報才會知道。
local NOTE_ICON = "Interface\\ICONS\\INV_Misc_Note_01"

local HEADER_H = 22
local FOOTER_H = 22
local MIN_W, MIN_H = 180, 120

local frame, viewer, headerText, quickBox, footer, emptyText
local bodyHolder, editBtn, pickBtn, lockBtn, collapseBtn, syncBanner
local BANNER_H = 16
local curInstance, curEncounter
local curDiff = ns.Notes.DIFF_ALL   -- 目前顯示的是哪個難度的那一份
local showSynced = false            -- 玩家在選單裡選了「看同步版」
local collapsed = false

------------------------------------------------------------
-- 目前顯示的是哪一筆
------------------------------------------------------------
-- 回傳 note, 來源（nil＝自己的，字串＝由誰同步）
local function CurrentNote()
    if not curInstance then return nil, nil end
    local mine = Notes.GetInstanceNote(curInstance, curEncounter, curDiff)
    local synced, from = ns.Sync.Get(curInstance, curEncounter, curDiff)

    -- 玩家明確選了看同步版，就給同步版（有的話）
    if showSynced and synced then return synced, from end
    -- 自己那一格沒寫東西才自動顯示同步版；自己寫了就顯示自己的
    if (not mine or Notes.IsEmpty(mine)) and synced then return synced, from end
    return mine, nil
end

-- 這個副本現在「應該優先看」哪個難度：團本看遊戲給的難度，其餘一律 all
local function PreferredDiff(instanceType, difficultyID)
    if instanceType ~= "raid" then return Notes.DIFF_ALL end
    if type(difficultyID) ~= "number" then return Notes.DIFF_ALL end
    return difficultyID
end

local function ContextLabel()
    if not curInstance then return "" end
    local instName = Journal.InstanceName(curInstance) or "?"
    local tag = ""
    if curDiff ~= Notes.DIFF_ALL then
        tag = " |cff808080[" .. Journal.DifficultyName(curDiff) .. "]|r"
    end
    if curEncounter then
        local bossName = Journal.EncounterName(curInstance, curEncounter)
        if not bossName then
            local note = Notes.GetInstanceNote(curInstance, curEncounter, curDiff)
            bossName = note and note.title or "?"
        end
        return instName .. " |cff808080-|r " .. bossName .. tag
    end
    return instName .. tag
end

------------------------------------------------------------
-- 存檔／還原
------------------------------------------------------------
local function SavePos()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        ns.db.windows.overlay = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    end
end

local function RestorePos()
    local p = ns.db.windows.overlay
    frame:ClearAllPoints()
    if type(p) == "table" and p.point then
        frame:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 60)
    end
end

local function SaveSize()
    local inst = ns.db.settings.instance
    inst.width  = math.floor(frame:GetWidth() + 0.5)
    inst.height = math.floor(frame:GetHeight() + 0.5)
end

------------------------------------------------------------
-- 版面
------------------------------------------------------------
-- body（捲動內容）的上緣：有同步橫幅就讓出一行
local function LayoutBody()
    if not bodyHolder then return end
    local top = HEADER_H + 2
    if syncBanner and syncBanner:IsShown() then top = top + BANNER_H end
    bodyHolder:ClearAllPoints()
    bodyHolder:SetPoint("TOPLEFT", 6, -top)
    bodyHolder:SetPoint("BOTTOMRIGHT", -6, footer:IsShown() and (FOOTER_H + 6) or 6)
end

local function ApplyLayout()
    local inst = ns.db.settings.instance
    frame:SetAlpha(inst.alpha / 100)
    frame:SetMovable(not inst.locked)
    footer:SetShown(inst.quickAdd and not collapsed)

    if collapsed then
        frame:SetHeight(P.Scale(HEADER_H))
        bodyHolder:Hide()
    else
        frame:SetSize(inst.width, inst.height)
        bodyHolder:Show()
        LayoutBody()
    end
    collapseBtn:SetText(collapsed and "+" or "-")
    if lockBtn.setLock then lockBtn.setLock(lockBtn, inst.locked) end
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
------------------------------------------------------------
-- 標題列：副本／首領 ＋ 正在跑的戰鬥計時
--
-- 計時放在標題而不是另外開一格：這個視窗本來就窄，而計時只有在跑的時候才有東西看。
------------------------------------------------------------
local headerTicker

local function UpdateHeader()
    if not headerText then return end
    local label = ContextLabel()
    local clock = ns.Clock.Label()
    if clock then
        if ns.Clock.IsTest() then
            label = label .. "  |cffffd200" .. L["Test"] .. " " .. clock .. "|r"
        else
            label = label .. "  |cffffffff" .. clock .. "|r"
        end
    end
    headerText:SetText(label)
end

local function SyncHeaderTicker()
    local want = frame and frame:IsShown() and ns.Clock.IsRunning()
    if want and not headerTicker then
        headerTicker = C_Timer.NewTicker(0.5, UpdateHeader)
    elseif not want and headerTicker then
        headerTicker:Cancel()
        headerTicker = nil
    end
    UpdateHeader()
end

local function RefreshBody()
    if not frame then return end
    SyncHeaderTicker()
    local note, from = CurrentNote()
    -- 由隊友同步進來的：頂上一條橫幅講清楚，免得誤以為是自己寫的
    if syncBanner then
        if from then
            syncBanner:SetText(("|cff33ff99🔄 " .. L["Synced from %s"] .. "|r"):format(from))
            syncBanner:Show()
        else
            syncBanner:Hide()
        end
        LayoutBody()
    end
    if note and not Notes.IsEmpty(note) then
        viewer:SetNote(note)
        viewer.scroll:Show()
        emptyText:Hide()
    else
        viewer:SetNote(nil)
        viewer.scroll:Hide()
        emptyText:SetText(ns.db.settings.instance.quickAdd
            and L["Nothing written here yet — type below to start."]
            or L["Nothing written here yet."])
        emptyText:Show()
    end
end

Overlay.RefreshBody = RefreshBody

------------------------------------------------------------
-- 切換要看哪一筆
------------------------------------------------------------
-- 玩家沒在副本裡也要能叫出來測試：挑一個「有寫過筆記」的，沒有就本季第一個
local function FallbackInstance()
    local season = Journal.SeasonInstances()
    local cat = Journal.Catalogue()
    local firstSeason
    for _, e in ipairs(cat.list) do
        if season[e.id] then
            if Notes.InstanceHasNotes(e.id) then return e.id end
            firstSeason = firstSeason or e.id
        end
    end
    return firstSeason or (cat.list[1] and cat.list[1].id)
end

local function SelectInstance(instanceID)
    if not instanceID then return end
    curInstance  = instanceID
    curEncounter = nil
    showSynced = false
    local info = Journal.InstanceInfo(instanceID)
    if not (info and info.isRaid) then curDiff = Notes.DIFF_ALL end
    RefreshBody()
end

------------------------------------------------------------
-- 切換選單：副本 → 難度 → 筆記 → 測試計時
--
-- 副本也放進來（不只是「目前所在的那個」），玩家才有辦法在城裡就把版面與
-- 內容試過一遍 —— 這個視窗平常只在副本裡出現，不給選的話等於沒辦法測。
------------------------------------------------------------
local function InstanceSubmenu()
    local season = Journal.SeasonInstances()
    local cat = Journal.Catalogue()
    local items, others = {}, {}
    for _, e in ipairs(cat.list) do
        local entry = {
            text = e.name .. (Notes.InstanceHasNotes(e.id) and " |cff808080*|r" or ""),
            isActive = curInstance == e.id,
            onClick = function() SelectInstance(e.id) end,
        }
        if season[e.id] then items[#items + 1] = entry
        elseif Notes.InstanceHasNotes(e.id) then others[#others + 1] = entry end
    end
    -- 本季以外的，只列「寫過筆記」的：全部列出來是好幾百筆，選單捲不完
    if #others > 0 then
        items[#items + 1] = { isSeparator = true }
        for _, e in ipairs(others) do items[#items + 1] = e end
    end
    if #items == 0 then
        items[1] = { text = "|cff808080" .. L["Nothing written here yet."] .. "|r",
                     onClick = function() end }
    end
    return items
end

local function ShowPickMenu(anchor)
    local items = {}

    local function Mark(note)
        return (note and not Notes.IsEmpty(note)) and " |cff808080*|r" or ""
    end

    items[#items + 1] = {
        text = L["Instance"],
        value = curInstance and (Journal.InstanceName(curInstance) or "?") or nil,
        submenu = InstanceSubmenu(),
    }

    if curInstance then
        local info = Journal.InstanceInfo(curInstance)
        -- 團本先給難度。玩家明確挑了哪個難度就顯示哪個，不再退回「全部」——
        -- 退回去的話「我明明選了傳奇卻看到別的」比看到空白更難解釋。
        if info and info.isRaid then
            local written = Notes.WrittenDifficulties(curInstance)
            local function DiffItem(key)
                return {
                    text = Journal.DifficultyName(key) .. (written[key] and " |cff808080*|r" or ""),
                    isActive = curDiff == key,
                    onClick = function()
                        curDiff = key
                        RefreshBody()
                    end,
                }
            end
            local diffs = { DiffItem(Notes.DIFF_ALL) }
            for _, d in ipairs(Journal.RaidDifficulties()) do
                diffs[#diffs + 1] = DiffItem(d.key)
            end
            items[#items + 1] = {
                text = L["Difficulty"],
                value = Journal.DifficultyName(curDiff),
                submenu = diffs,
            }
        end

        items[#items + 1] = { isSeparator = true }
        items[#items + 1] = { text = L["Note"], isTitle = true }
        items[#items + 1] = {
            text = L["Dungeon overview"] .. Mark(Notes.GetInstanceNote(curInstance, nil, curDiff)),
            isActive = curEncounter == nil,
            onClick = function()
                curEncounter = nil
                RefreshBody()
            end,
        }
        for _, e in ipairs(Journal.Encounters(curInstance)) do
            local encID = e.id
            items[#items + 1] = {
                text = e.name .. Mark(Notes.GetInstanceNote(curInstance, encID, curDiff)),
                isActive = curEncounter == encID,
                onClick = function()
                    curEncounter = encID
                    RefreshBody()
                end,
            }
        end
    end

    -- 同步
    items[#items + 1] = { isSeparator = true }
    items[#items + 1] = { text = L["Sync"], isTitle = true }
    items[#items + 1] = {
        text = L["Sync my dungeon notes to the group"],
        isActive = ns.Sync.IsBroadcasting(),
        onClick = function() ns.Sync.ToggleBroadcast() end,
    }
    -- 這一格有隊友同步進來，而且自己也寫了 → 給個切換看哪一份
    if curInstance and ns.Sync.Get(curInstance, curEncounter, curDiff) then
        local mine = Notes.GetInstanceNote(curInstance, curEncounter, curDiff)
        if mine and not Notes.IsEmpty(mine) then
            items[#items + 1] = {
                text = showSynced and L["Show my own"] or L["Show the synced one"],
                onClick = function()
                    showSynced = not showSynced
                    RefreshBody()
                end,
            }
        end
    end

    -- 測試計時：一按就開始跑，跑到再按一次為止。{time:...} 的倒數靠它。
    items[#items + 1] = { isSeparator = true }
    items[#items + 1] = {
        text = ns.Clock.IsTest() and L["Stop the test timer"] or L["Start the test timer"],
        value = ns.Clock.Label(),
        onClick = function() ns.Clock.ToggleTest() end,
    }

    W.Menu.Show(items, anchor)
end

------------------------------------------------------------
-- 快速記一行
------------------------------------------------------------
local function QuickAdd(text)
    text = strtrim(text or "")
    if text == "" or not curInstance then return end
    -- 現在螢幕上是隊友同步的那份，不是自己的 → 快速記一行會憑空多出一筆自己的，
    -- 而且畫面不會馬上換過去，玩家會覺得「打了字卻沒反應」。先擋掉並講一聲。
    local _, from = CurrentNote()
    if from then
        ns.Print(L["That note is synced from a teammate — switch to your own before jotting."])
        return
    end

    local instName = Journal.InstanceName(curInstance) or "?"
    local title = instName
    if curEncounter then
        title = Journal.EncounterName(curInstance, curEncounter) or L["Untitled"]
    end
    local note = Notes.EnsureInstanceNote(curInstance, curEncounter, curDiff, title,
                                          { name = instName })
    if not note then return end
    Journal.StampDungeonID(note, curInstance, curEncounter)

    -- 第一塊如果是空的（新建出來的預設塊）就直接用掉，不要留一行空白在最上面
    local blocks = note.blocks
    if #blocks == 1 and (blocks[1].text or "") == "" and blocks[1].type == Notes.TYPE_TEXT then
        blocks[1].text = text
    else
        blocks[#blocks + 1] = { type = Notes.TYPE_TEXT, text = text }
    end
    Notes.Touch(note)
    RefreshBody()
    ns.Fire("NotesChanged")

    -- 捲到底：剛記下的那行要看得到
    C_Timer.After(0, function()
        if viewer and viewer.container and viewer.scroll then
            local maxScroll = math.max(0, viewer.container:GetHeight() - viewer.scroll:GetHeight())
            viewer.scroll:SetVerticalScroll(maxScroll)
        end
    end)
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
local function Build()
    if frame then return end

    frame = W.CreateFrame("MiliUINote_Overlay", UIParent, 280, 240)
    frame:Hide()
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(300)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    -- ⚠ 尺寸不走 P.Scale：玩家用把手拖出來的大小是**已縮放後**的實際像素，
    --   存回去再 Scale 一次就會愈開愈大。邊框的 1px 對齊在 Stylize 裡各自處理。
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_W, MIN_H)
    end
    RestorePos()

    -- 標題列兼拖曳把手
    local header = W.CreateFrame(nil, frame)
    header:SetHeight(P.Scale(HEADER_H))
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if ns.db.settings.instance.locked then return end
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePos()
    end)

    headerText = header:CreateFontString(nil, "OVERLAY")
    headerText:SetFontObject(W.fontSmall)
    headerText:SetPoint("LEFT", 6, 0)
    headerText:SetPoint("RIGHT", -104, 0)
    headerText:SetJustifyH("LEFT")
    headerText:SetWordWrap(false)
    headerText:SetTextColor(W.Accent(1))

    -- 掛鎖：四塊純色方塊拼出來（鎖身 ＋ ㄇ 字形鎖環）。開鎖時把右邊那根柱子藏掉、
    -- 橫桿往右移，鎖環就是開的 —— **狀態靠形狀，不靠換顏色**，只換明暗。
    local function BuildLockGlyph(b)
        local function block(w, h, x, y)
            local t = b:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(1, 1, 1, 1)
            t:SetSize(w, h)
            t:SetPoint("CENTER", b, "CENTER", x, y)
            return t
        end
        b.lockParts = { block(9, 6, 0, -3), block(2, 5, -3, 3), block(6, 2, 0, 5), block(2, 5, 3, 3) }
        b.lockTop, b.lockRight = b.lockParts[3], b.lockParts[4]
    end

    local function SetLockGlyph(b, locked)
        if not b.lockParts then return end
        local v = locked and 1 or 0.62
        for _, t in ipairs(b.lockParts) do t:SetColorTexture(v, v, v, 1) end
        b.lockRight:SetShown(locked)
        b.lockTop:ClearAllPoints()
        b.lockTop:SetPoint("CENTER", b, "CENTER", locked and 0 or 2, 5)
    end

    -- label 給字串就是文字鈕，給 { tex = 路徑 } 就是圖示鈕，給 { lock = true } 就是掛鎖
    local function HeaderButton(label, tooltip, onClick, anchorTo)
        local b = W.CreateButton(header, type(label) == "string" and label or "", "normal", 18, 16)
        if type(label) == "table" and label.lock then
            BuildLockGlyph(b)
            b.setLock = SetLockGlyph
        elseif type(label) == "table" then
            b.icon = b:CreateTexture(nil, "OVERLAY")
            b.icon:SetSize(11, 11)
            b.icon:SetPoint("CENTER")
            b.icon:SetTexture(label.tex)
            -- ICONS 的素材四周有內建外框，縮到 11px 會糊成一團，裁掉再用
            b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            b.icon:SetVertexColor(0.9, 0.9, 0.9)
        end
        if anchorTo then
            b:SetPoint("RIGHT", anchorTo, "LEFT", -2, 0)
        else
            b:SetPoint("RIGHT", -3, 0)
        end
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(self._colors[2]))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(self._colors[1]))
            GameTooltip:Hide()
        end)
        return b
    end

    local closeBtn = HeaderButton({ tex = "Interface\\Buttons\\UI-StopButton" },
        L["Close"], function() Overlay.Hide() end)
    collapseBtn = HeaderButton("-", L["Collapse"], function()
        collapsed = not collapsed
        ApplyLayout()
    end, closeBtn)
    lockBtn = HeaderButton({ lock = true }, L["Lock in place"], function()
        ns.db.settings.instance.locked = not ns.db.settings.instance.locked
        ApplyLayout()
        ns.Fire("SettingsChanged")
    end, collapseBtn)
    editBtn = HeaderButton({ tex = NOTE_ICON },
        L["Open in the editor"], function()
        if curInstance then ns.Window.EditInstanceNote(curInstance, curEncounter, curDiff) end
    end, lockBtn)
    pickBtn = HeaderButton("v", L["Pick a boss"], function(self)
        ShowPickMenu(self)
    end, editBtn)

    -- 同步來源橫幅（由隊友同步進來時才顯示）
    syncBanner = frame:CreateFontString(nil, "OVERLAY")
    syncBanner:SetFontObject(W.fontSmall)
    syncBanner:SetPoint("TOPLEFT", 8, -(HEADER_H + 2))
    syncBanner:SetPoint("TOPRIGHT", -8, -(HEADER_H + 2))
    syncBanner:SetJustifyH("LEFT")
    syncBanner:Hide()

    -- 內容
    bodyHolder = CreateFrame("Frame", nil, frame)
    bodyHolder:SetPoint("TOPLEFT", 6, -(HEADER_H + 2))
    bodyHolder:SetPoint("BOTTOMRIGHT", -6, FOOTER_H + 6)
    local scroll = W.CreateScrollFrame(bodyHolder)
    viewer = ns.Blocks.CreateViewer(scroll, {
        interactive = true,
        follow = true,     -- 計時中跟著時間軸捲動
        onChanged = function() ns.Fire("NotesChanged") end,
    })

    emptyText = bodyHolder:CreateFontString(nil, "OVERLAY")
    emptyText:SetFontObject(W.fontSmall)
    emptyText:SetPoint("TOPLEFT", 2, -4)
    emptyText:SetPoint("TOPRIGHT", -2, -4)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetSpacing(3)
    emptyText:Hide()

    -- 快速記一行
    footer = CreateFrame("Frame", nil, frame)
    footer:SetHeight(P.Scale(FOOTER_H))
    footer:SetPoint("BOTTOMLEFT", 6, 6)
    footer:SetPoint("BOTTOMRIGHT", -6, 6)

    quickBox = W.CreateEditBox(footer, 100, FOOTER_H)
    quickBox:SetPoint("TOPLEFT", 0, 0)
    quickBox:SetPoint("BOTTOMRIGHT", 0, 0)
    quickBox:SetFontObject(Media.fontBody)
    quickBox:SetMaxLetters(300)

    local hint = quickBox:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("LEFT", 6, 0)
    hint:SetTextColor(0.45, 0.45, 0.45)
    hint:SetText(L["Jot a line down..."])
    quickBox:SetScript("OnTextChanged", function(self)
        hint:SetShown((self:GetText() or "") == "")
    end)
    quickBox:SetScript("OnEnterPressed", function(self)
        QuickAdd(self:GetText())
        self:SetText("")
        self:ClearFocus()
    end)

    -- 右下角縮放把手
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(12, 12)
    grip:SetPoint("BOTTOMRIGHT", 0, 0)
    grip:EnableMouse(true)
    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetColorTexture(W.Accent(0.35))
    grip:SetScript("OnMouseDown", function()
        if ns.db.settings.instance.locked or collapsed then return end
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveSize()
        viewer:Relayout()
    end)

    frame:SetScript("OnHide", function()
        W.Menu.Hide()
        SyncHeaderTicker()
    end)
    ApplyLayout()
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
function Overlay.Show(instanceID, encounterID, diffKey)
    if not instanceID then return end
    Build()
    curInstance  = instanceID
    curEncounter = encounterID
    curDiff      = Notes.NormalizeDiffKey(diffKey)
    collapsed = false
    ApplyLayout()
    -- 先 Show 再 RefreshBody：標題的計時 ticker 只在「視窗看得見」時才跑，
    -- 順序反過來的話開窗那一次不會啟動，要等下一次事件才補上
    frame:Show()
    RefreshBody()
end

function Overlay.Hide()
    if frame then frame:Hide() end
end

function Overlay.IsShown()
    return frame and frame:IsShown()
end

-- 目前顯示的是哪一格（/mnote debug 與測試用）
function Overlay.Current()
    return curInstance, curEncounter, curDiff
end

-- 指令／設定頁的「現在就顯示」：不在副本裡就講一聲
function Overlay.Toggle()
    if Overlay.IsShown() then
        Overlay.Hide()
        return
    end
    local jInst, _, instanceType, difficultyID = Journal.CurrentInstance()
    local diff = curDiff
    if jInst then
        diff = PreferredDiff(instanceType, difficultyID)
    else
        -- 不在副本裡也要開得起來：玩家在城裡就能把版面、內容、倒數整套試過一遍。
        -- 這個視窗平常只在副本裡自己跳出來，不給手動開等於沒辦法測。
        jInst = curInstance or FallbackInstance()
    end
    if not jInst then
        ns.Print(L["No dungeons to show yet."])
        return
    end
    Overlay.Show(jInst, curEncounter, diff)
end

------------------------------------------------------------
-- 自動顯示
------------------------------------------------------------
-- 冒險指南換算不出來時的第二條路：翻自己存的首領筆記
local function FindSavedBoss(dungeonEncounterID)
    for instanceID, entry in pairs(ns.db.instanceNotes) do
        if type(entry) == "table" and type(entry.diffs) == "table" then
            for diffKey, bucket in pairs(entry.diffs) do
                for encID, note in pairs(bucket.bosses or {}) do
                    if note.dungeonEncounterID == dungeonEncounterID then
                        return instanceID, encID, diffKey
                    end
                end
            end
        end
    end
end

-- 進副本時要顯示哪一筆：總覽有寫東西就用總覽，否則挑第一隻有筆記的首領。
-- 直接開一個空的總覽出來，玩家會覺得「跳出來一個沒東西的視窗」。
--
-- 難度：先看現在這個難度那一份，沒有才退回「全部」。兩輪都先問總覽再問首領 ——
-- 「這個難度的總覽」比「全部難度的第一隻首領」更貼近玩家現在需要的東西。
-- 回傳 encounterID, 難度 key, 有沒有找到
local function FirstWrittenNote(instanceID, pref)
    local keys = { pref }
    if pref ~= Notes.DIFF_ALL then keys[2] = Notes.DIFF_ALL end

    for _, k in ipairs(keys) do
        local overview = Notes.GetInstanceNote(instanceID, nil, k)
        if overview and not Notes.IsEmpty(overview) then return nil, k, true end
    end
    -- 依冒險指南的首領順序找，pairs 的順序不保證、玩家看到的會跳來跳去
    for _, k in ipairs(keys) do
        for _, e in ipairs(Journal.Encounters(instanceID)) do
            local note = Notes.GetInstanceNote(instanceID, e.id, k)
            if note and not Notes.IsEmpty(note) then return e.id, k, true end
        end
    end
    return nil, Notes.DIFF_ALL, false
end

local function EvaluateZone()
    local inst = ns.db.settings.instance
    local jInst, _, instanceType, difficultyID = Journal.CurrentInstance()

    if not jInst then
        curInstance, curEncounter = nil, nil
        curDiff = Notes.DIFF_ALL
        if inst.autoHide then Overlay.Hide() end
        return
    end

    -- 同一個副本重進（換樓層、重載）不要把玩家正在看的首領筆記切掉
    if curInstance == jInst then return end
    local pref = PreferredDiff(instanceType, difficultyID)
    curInstance, curEncounter, curDiff = jInst, nil, pref

    if not inst.autoShow then return end
    if inst.onlyRaid and instanceType ~= "raid" then return end
    local encID, diffKey, any = FirstWrittenNote(jInst, pref)
    if not any then return end
    Overlay.Show(jInst, encID, diffKey)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, ...)
    local inst = ns.db and ns.db.settings.instance
    if not inst then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        -- 剛進場時 GetInstanceInfo 有機會還沒定案，稍等一下再問
        C_Timer.After(1.5, EvaluateZone)

    elseif event == "ENCOUNTER_START" then
        if not inst.autoBoss then return end
        -- ENCOUNTER_START 自己就帶難度，比再去問 GetInstanceInfo 準
        local dungeonEncID, _, encDifficultyID = ...
        local liveInst, _, instanceType, zoneDiff = Journal.CurrentInstance()
        -- ⚠ 現場那個優先。curInstance 有可能是玩家自己從選單挑來看的**別的副本**
        --   （「試試看」現在在哪裡都開得起來），拿它去查首領當然查不到。
        local jInst = liveInst or curInstance
        local pref = PreferredDiff(instanceType, encDifficultyID or zoneDiff)

        local jEnc
        if jInst then jEnc = Journal.EncounterByDungeonID(jInst, dungeonEncID) end
        if not jEnc then
            local savedInst, savedEnc, savedDiff = FindSavedBoss(dungeonEncID)
            if savedInst then
                jInst, jEnc = savedInst, savedEnc
                if savedDiff then pref = savedDiff end
            end
        end
        if not (jInst and jEnc) then return end

        local note, diffKey = Notes.ResolveInstanceNote(jInst, jEnc, pref)
        if not note or Notes.IsEmpty(note) then return end
        Overlay.Show(jInst, jEnc, diffKey)

    elseif event == "ENCOUNTER_END" then
        if not (inst.autoBoss and Overlay.IsShown() and curEncounter) then return end
        -- 打完回到副本總覽，但只在總覽真的有寫東西的時候（沒有的話留著首領筆記，
        -- 團滅重來還看得到）
        C_Timer.After(5, function()
            if not (Overlay.IsShown() and curInstance and curEncounter) then return end
            local overview, diffKey = Notes.ResolveInstanceNote(curInstance, nil, curDiff)
            if overview and not Notes.IsEmpty(overview) then
                curEncounter = nil
                curDiff = diffKey
                RefreshBody()
            end
        end)
    end
end)

ns.RegisterCallback("Init", "overlay", function()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ev:RegisterEvent("ENCOUNTER_START")
    ev:RegisterEvent("ENCOUNTER_END")
end)

ns.RegisterCallback("SettingsChanged", "overlay", function()
    if frame then
        ApplyLayout()
        RefreshBody()
    end
end)

ns.RegisterCallback("NotesChanged", "overlay", function()
    if frame and frame:IsShown() then RefreshBody() end
end)

ns.RegisterCallback("ClockChanged", "overlay", function()
    SyncHeaderTicker()
end)

ns.RegisterCallback("SyncChanged", "overlay", function()
    if frame and frame:IsShown() then RefreshBody() end
end)
