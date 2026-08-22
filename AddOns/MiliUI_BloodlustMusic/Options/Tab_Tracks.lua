------------------------------------------------------------
-- 「曲目」分頁：內建曲目 ＋ 自訂曲目的開關／試聽／編輯／刪除
--
-- 這一頁不是表單，所以不走 Controls.Build，直接排在分頁 frame 上；
-- 清單本體是共用層的 W.CreateRowList（列會回收再用）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local ROW_H    = 26
local TOP_AREA = 110        -- 標題＋說明＋按鈕列佔掉的高度

local tab, list, editPopup, delPopup
local previewKey            -- 現在正在試聽哪一列（source .. index）
local pendingDelete         -- 確認彈窗按下「確定」時要刪的自訂曲目編號

local function RowKey(source, index)
    return source .. index
end

------------------------------------------------------------
-- 清單資料：內建曲目在前，自訂曲目接在後面
------------------------------------------------------------
local function GetTrackRows()
    local rows = {}
    for i, t in ipairs(ns.MUSIC_FILES) do
        rows[#rows + 1] = { source = "builtin", index = i, name = t.name }
    end
    local db = ns.GetDB()
    for i, t in ipairs(db.customTracks or {}) do
        local name = (t.name and t.name ~= "") and t.name or (t.filename or "?")
        rows[#rows + 1] = { source = "custom", index = i, name = name }
    end
    return rows
end

local function IsTrackEnabled(entry)
    local db = ns.GetDB()
    if entry.source == "builtin" then
        return db.trackEnabled[entry.index] ~= false
    end
    local t = db.customTracks and db.customTracks[entry.index]
    return t and t.enabled ~= false
end

local function SetTrackEnabled(entry, on)
    local db = ns.GetDB()
    if entry.source == "builtin" then
        db.trackEnabled[entry.index] = on
    elseif db.customTracks and db.customTracks[entry.index] then
        db.customTracks[entry.index].enabled = on
    end
end

local RefreshList   -- 前向宣告（下面幾支互相呼叫）

------------------------------------------------------------
-- 試聽：同一列再點一次＝停止
------------------------------------------------------------
local function TogglePreview(entry)
    local key = RowKey(entry.source, entry.index)
    local wasThisRow = ns.IsPreviewPlaying() and previewKey == key

    if ns.IsPreviewPlaying() then ns.StopPreview() end
    previewKey = nil

    if wasThisRow then
        RefreshList()
        return
    end

    if not ns.PreviewTrack(entry.source, entry.index) then
        print(L["MSG_PREVIEW_FAIL"])
        RefreshList()
        return
    end
    previewKey = key
    RefreshList()
    -- 播完自己把按鈕字改回來（試聽長度就是實際播放長度）
    C_Timer.After(ns.MUSIC_DURATION + 1, function()
        if previewKey == key then
            previewKey = nil
            RefreshList()
        end
    end)
end

------------------------------------------------------------
-- 新增／編輯自訂曲目
------------------------------------------------------------
local function EnsureEditPopup()
    if editPopup then return editPopup end
    editPopup = W.CreateInputPopup(ns.Options.panel, 460, L["TRACK_ADD"], {
        { key = "name",     label = L["TRACK_NAME"],     maxLetters = 80 },
        { key = "filename", label = L["TRACK_FILENAME"], maxLetters = 200,
          hint = L["TRACK_FILENAME_HINT"] },
    })
    return editPopup
end

-- editIndex 為 nil ＝ 新增
local function OpenTrackEditor(editIndex)
    local db = ns.GetDB()
    db.customTracks = db.customTracks or {}
    local t = editIndex and db.customTracks[editIndex]

    EnsureEditPopup():Open(
        t and { name = t.name, filename = t.filename } or nil,
        function(values)
            if values.filename == "" then
                print(L["MSG_TRACK_NEED_FILENAME"])
                return false                    -- 檔名是必填，不關窗讓玩家補
            end
            local name = values.name ~= "" and values.name or values.filename
            local d = ns.GetDB()
            d.customTracks = d.customTracks or {}
            if editIndex then
                local track = d.customTracks[editIndex]
                if track then
                    track.name, track.filename = name, values.filename
                    if track.enabled == nil then track.enabled = true end
                end
            else
                tinsert(d.customTracks, { name = name, filename = values.filename, enabled = true })
            end
            RefreshList()
        end,
        editIndex and L["TRACK_EDIT"] or L["TRACK_ADD"])
end

local function EnsureDelPopup()
    if delPopup then return delPopup end
    delPopup = W.CreateConfirmPopup(ns.Options.panel, 340, "", function()
        local db = ns.GetDB()
        if pendingDelete and db.customTracks and db.customTracks[pendingDelete] then
            tremove(db.customTracks, pendingDelete)
            RefreshList()
        end
        pendingDelete = nil
    end)
    return delPopup
end

------------------------------------------------------------
-- 一列的樣子：勾選框 ＋ 名稱 ＋ 試聽／編輯／刪除
--
-- ⚠ 列是回收再用的，所以每個 handler 都讀 row.entry（更新時才填），
-- 不要在這裡把曲目編號抓進 closure —— 那樣捲動幾次之後按鈕就會動到別首歌。
------------------------------------------------------------
local function BuildRow(row)
    row.check = W.CreateCheckButton(row, "", function(checked)
        if row.entry then
            SetTrackEnabled(row.entry, checked)
        end
    end)
    row.check:SetPoint("LEFT", 6, 0)

    row.del = W.CreateButton(row, "X", "red", 20, 18)
    row.del:SetPoint("RIGHT", -6, 0)
    row.del:SetScript("OnClick", function()
        if not (row.entry and row.entry.source == "custom") then return end
        pendingDelete = row.entry.index
        local popup = EnsureDelPopup()
        popup.text:SetText(L["TRACK_DELETE_CONFIRM"]:format(row.entry.name or ""))
        popup:Show()
    end)

    row.edit = W.CreateButton(row, L["TRACK_EDIT_SHORT"], "normal", 54, 18)
    row.edit:SetPoint("RIGHT", row.del, "LEFT", -4, 0)
    row.edit:SetScript("OnClick", function()
        if row.entry and row.entry.source == "custom" then
            OpenTrackEditor(row.entry.index)
        end
    end)

    row.preview = W.CreateButton(row, L["PREVIEW"], "normal", 64, 18)
    row.preview:SetPoint("RIGHT", row.edit, "LEFT", -4, 0)
    row.preview:SetScript("OnClick", function()
        if row.entry then TogglePreview(row.entry) end
    end)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("LEFT", row.check, "RIGHT", 10, 0)
    row.name:SetPoint("RIGHT", row.preview, "LEFT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
end

local function UpdateRow(row, entry)
    row.entry = entry
    row.name:SetText(entry.name or "")
    row.check:SetChecked(IsTrackEnabled(entry) and true or false)

    local playing = ns.IsPreviewPlaying() and previewKey == RowKey(entry.source, entry.index)
    row.preview:SetText(playing and L["STOP_PREVIEW"] or L["PREVIEW"])

    -- 內建曲目沒有檔名可改，也不能刪掉（否則下次更新又會冒出來，玩家會以為壞了）
    row.edit:SetShown(entry.source == "custom")
    row.del:SetShown(entry.source == "custom")
end

------------------------------------------------------------
-- 分頁組裝
------------------------------------------------------------
local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local title = W.CreateSectionTitle(tab, L["TAB_TRACKS"], ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    local desc = tab:CreateFontString(nil, "OVERLAY")
    desc:SetFontObject(W.fontSmall)
    desc:SetPoint("TOPLEFT", 18, -46)
    desc:SetWidth(ns.Options.PANEL_W - 40)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["TRACKS_DESC"])

    local addBtn = W.CreateButton(tab, L["TRACK_ADD"], "accent", 130, 22)
    addBtn:SetPoint("TOPLEFT", 18, -(TOP_AREA - 30))
    addBtn:SetScript("OnClick", function() OpenTrackEditor(nil) end)

    list = W.CreateRowList(tab, ns.Options.PANEL_W - 36, ns.Options.PANEL_H - TOP_AREA - 12,
        ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", 18, -TOP_AREA)
end

-- IsVisible 而不是 IsShown：分頁自己是 Show 的，但整個視窗關著時不必重畫
RefreshList = function()
    if not (tab and tab:IsVisible()) then return end
    list:Update(GetTrackRows(), UpdateRow)
end

ns.RegisterCallback("ShowOptionsTab", "tracksTab", function(id)
    if id ~= "tracks" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
    RefreshList()
end)
