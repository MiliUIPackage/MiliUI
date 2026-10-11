------------------------------------------------------------
-- 「一般」分頁：開關、要畫哪些來源、首領警告、語音播報、時間軸上現在有什麼
--
-- 首領警告與語音播報放在這裡而不是每條提示的編輯視窗：那是「長相／聲音」的全域設定
-- （警告畫在哪、用哪個語音念），每條提示只決定要不要用、用哪個等級、念什麼字。
--
-- 「現在有什麼」那一段是這支插件第二個用途的入口：看得到誰在往暴雪的時間軸寫東西。
-- 暴雪的首領技能名稱戰鬥中是秘密值，這裡不顯示（只算條數）；
-- 插件加的條（Script 來源）是明文，名稱、剩幾秒、哪個插件都列出來。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local S = ns.Secret

local tab, scroll, refreshers, ticker

local KIND_COLOR = {
    blizzard = "|cffff7f00",
    mine     = "|cff55ff55",
    other    = "|cff66ccff",
}

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.Screen.Apply()
    if ns.Minimap then ns.Minimap.Apply() end
    RefreshAll()
end

------------------------------------------------------------
-- 時間軸現況（custom spec）
------------------------------------------------------------
local function LiveLines()
    local counts = { blizzard = 0, mine = 0, other = 0 }
    local rows = {}
    for id, rec in ns.Events.Iterate() do
        local kind = rec.kind
        if counts[kind] then
            counts[kind] = counts[kind] + 1
            -- 暴雪的只有認得出來（DBM／MRT）的才有明文名稱可列
            local name
            if kind == "blizzard" then
                name = rec.ident and (rec.ident.name .. "  |cff9d9d9d" .. (rec.ident.source == "dbm" and "DBM" or L["MRT guess"]) .. "|r")
            else
                name = S.PlainText(rec.name) or "?"
            end
            if name then
                local rem = S.PlainNumber(S.SafeCall(C_EncounterTimeline.GetEventTimeRemaining, id))
                local who = kind == "mine" and L["My custom timeline"]
                    or kind == "blizzard" and L["Blizzard"] or ns.Owners.Label(rec.owner)
                rows[#rows + 1] = {
                    rem = rem or 0,
                    text = ("%s%s|r  %s  |cff9d9d9d%s|r"):format(KIND_COLOR[kind], who,
                        name, rem and ("%.0fs"):format(rem) or ""),
                }
            end
        end
    end
    table.sort(rows, function(a, b) return a.rem < b.rem end)

    local lines = {}
    lines[#lines + 1] = ("%s%s|r %d   %s%s|r %d   %s%s|r %d"):format(
        KIND_COLOR.blizzard, L["Blizzard"], counts.blizzard,
        KIND_COLOR.mine, L["Mine"], counts.mine,
        KIND_COLOR.other, L["Other addons"], counts.other)
    if #rows == 0 then
        lines[#lines + 1] = "|cff9d9d9d" .. L["Nothing named on the timeline right now."] .. "|r"
    else
        for i = 1, math.min(#rows, 8) do lines[#lines + 1] = rows[i].text end
    end

    -- 本次登入看過哪些插件寫時間軸
    local seen = {}
    for addon, n in pairs(ns.Owners.Seen()) do
        seen[#seen + 1] = ns.Owners.Label(addon) .. " x" .. n
    end
    table.sort(seen)
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Addons that wrote to the timeline since login:"] .. " "
        .. (#seen > 0 and table.concat(seen, "、") or ("|cff9d9d9d" .. L["none yet"] .. "|r"))
    return table.concat(lines, "\n")
end

local function BuildLive(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(4)
    fs:SetText("")
    tab.liveText = fs
    return 200, function() fs:SetText(LiveLines()) end
end

-- 首領警告：三顆「試看看」（normal 鈕：示範動作，不是這一頁的主動作）
local function BuildWarningTry(parent, x, y)
    local prev
    for sev, label in ipairs({ L["Try minor"], L["Try medium"], L["Try critical"] }) do
        local b = W.CreateButton(parent, label, "normal", 80, 20)
        W.FitButton(b, 80, 20)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        else
            b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        end
        b:SetScript("OnClick", function() ns.Warnings.Preview(sev - 1) end)
        prev = b
    end
    return 28
end

-- 語音播報：試聽鈕
local function BuildVoiceTest(parent, x, y)
    local b = W.CreateButton(parent, L["Test voice"], "normal", 80, 20)
    W.FitButton(b, 80, 20)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    b:SetScript("OnClick", function() ns.Scheduler.Speak(L["Sample reminder"]) end)
    return 28
end

-- 語音清單：開分頁那一刻才問（系統語音包可能後來才裝）；「遊戲預設」存成 nil（見 Build 的 nilAs）
local function VoiceItems()
    local items = { { text = L["Game default"], value = "" } }
    if C_VoiceChat and C_VoiceChat.GetTtsVoices then
        local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
        if ok and type(voices) == "table" then
            for _, v in ipairs(voices) do
                if type(v) == "table" and v.voiceID then
                    items[#items + 1] = { text = v.name or ("#" .. v.voiceID), value = v.voiceID }
                end
            end
        end
    end
    return items
end

local BASIC = {
    { type = "header", label = L["MiliUI Boss Timeline"] },
    { type = "toggle", sub = "display", key = "enabled", label = L["Draw the timeline with MiliUI"] },
    { type = "text", label = L["Off: Blizzard's timeline stays as it is. Custom timelines still run and still show which addon added what."] },
    { type = "toggle", sub = "display", key = "hideBlizzard", label = L["Hide Blizzard's timeline"],
      requires = { sub = "display", key = "enabled" } },
    { type = "text", label = L["Only the picture is hidden. Blizzard's sounds, and other addons' timeline sounds such as DBM countdowns, keep working."] },
    { type = "toggle", key = "previewOnScreen", label = L["Preview on screen while this window is open"] },
    { type = "toggle", sub = "minimap", key = "show", label = L["Show minimap button"] },
    { type = "text", label = L["Hidden? Type /mbt minimap to bring it back."] },

    { type = "header", label = L["When to show it"] },
    { type = "dropdown", sub = "display", key = "visibility", label = L["Show"], items = {
        { text = L["Whenever something is on the timeline"], value = "always" },
        { text = L["Only in dungeons and raids"],           value = "instance" },
    } },
    { type = "slider", sub = "display", key = "oocAlpha", label = L["Opacity out of combat"], min = 0, max = 1, step = 0.05 },
    { type = "text", label = L["The timeline never takes mouse clicks, so it won't get in the way of clicking the world behind it."] },

    { type = "header", label = L["Boss warnings"] },
    { type = "toggle", sub = "warnings", key = "enabled", label = L["Show my reminders as boss warnings"] },
    { type = "text", label = L["Reminders that have a warning level show in the same place and style as Blizzard's boss warnings (Edit Mode → Boss Warnings moves them). Only reminders you gave a level use this."] },
    { type = "toggle", sub = "warnings", key = "blizzardSound", label = L["Also play Blizzard's warning sound"],
      requires = { sub = "warnings", key = "enabled" } },
    { type = "custom", label = "", build = BuildWarningTry, h = 28 },

    { type = "header", label = L["Spoken reminders"] },
    { type = "dropdown", sub = "tts", key = "voice", label = L["Voice"], items = VoiceItems, nilAs = "" },
    { type = "slider", sub = "tts", key = "rate", label = L["Speech rate"], min = -10, max = 10, step = 1 },
    { type = "slider", sub = "tts", key = "volume", label = L["Volume"], min = 0, max = 100, step = 5 },
    { type = "custom", label = "", build = BuildVoiceTest, h = 28 },
    { type = "text", label = L["Used by every reminder that speaks. Each reminder can still have its own words."] },

    { type = "header", label = L["Show entries from"] },
    { type = "toggle", sub = "display", sub2 = "sources", key = "blizzard", label = L["Blizzard (boss abilities)"] },
    { type = "toggle", sub = "display", sub2 = "sources", key = "mine",     label = L["My custom timelines"] },
    { type = "toggle", sub = "display", sub2 = "sources", key = "other",    label = L["Other addons"] },
    { type = "text", label = L["Other addons: anything written into Blizzard's timeline by an addon, such as DiGua Voice. DBM and BigWigs only read the timeline, so they don't show up here."] },

    { type = "header", label = L["On the timeline right now"] },
    { type = "custom", label = "", build = BuildLive },
    { type = "text", label = L["Blizzard hides boss ability names from addons during combat. The ones listed by name were recognized through DBM or the MRT timeline (Advanced, below)."] },
}

-- 進階：平常用不到、預設收起來（展開狀態記在存檔）
local ADVANCED = {
    { type = "header", label = L["Recognizing boss abilities in combat"] },
    { type = "toggle", sub = "identify", key = "dbm", label = L["Use DBM's recognition"] },
    { type = "text", label = L["When DBM recognizes a timeline entry, it announces the ability by name; this addon picks that up. Needs DBM with its boss modules."] },
    { type = "toggle", sub = "identify", key = "mrt", label = L["Guess from the MRT timeline"] },
    { type = "text", label = L["Matches the time into the fight against MRT's statistics for the same difficulty. Skipped when two abilities are too close to tell apart. DBM's answer wins when both are available."] },
    { type = "text", label = L["Recognized abilities are what make \"Hide\" (Bosses → Abilities) work, and let your last pull remember their names."] },
}

local content
local Build

-- 「進階設定」展開／收起：整頁重建（共用層的表單沒有局部顯示隱藏）
local function BuildAdvancedToggle(parent, x, y)
    local b = W.CreateButton(parent, ns.db.showAdvanced and L["Hide advanced settings"] or L["Show advanced settings"], "normal", 140, 20)
    W.FitButton(b, 140, 20)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    b:SetScript("OnClick", function()
        ns.db.showAdvanced = not ns.db.showAdvanced
        Build()
    end)
    return 28
end

local function Controls()
    local list = {}
    for _, c in ipairs(BASIC) do list[#list + 1] = c end
    list[#list + 1] = { type = "space", h = 6 }
    list[#list + 1] = { type = "custom", label = "", build = BuildAdvancedToggle, h = 28 }
    if ns.db.showAdvanced then
        for _, c in ipairs(ADVANCED) do list[#list + 1] = c end
    end
    return list
end

Build = function()
    if content then content:Hide() end
    local ctx = ns.Options.MakeCtx(Apply)
    -- spec.nilAs：存檔裡 nil 的值在表單上當成什麼（語音下拉的「遊戲預設」＝""）；選回它就存回 nil。
    -- 共用層的下拉值原樣存，nil 對不到任何選項會顯示空白，所以在這一頁的 ctx 外面包一層
    local get, set = ctx.get, ctx.set
    ctx.get = function(spec)
        local v = get(spec)
        if v == nil and spec.nilAs ~= nil then return spec.nilAs end
        return v
    end
    ctx.set = function(spec, v)
        if spec.nilAs ~= nil and v == spec.nilAs then v = nil end
        set(spec, v)
    end
    content, refreshers = ns.Options.BuildScrollBody(scroll, Controls(), ctx)
    RefreshAll()
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["General"])
    Build()
end

local function StopTicker()
    if ticker then ticker:Cancel() ticker = nil end
end

ns.RegisterCallback("ShowOptionsTab", "generalTab", function(id)
    if id ~= "general" then
        if tab then tab:Hide() end
        StopTicker()
        return
    end
    Init()
    RefreshAll()
    tab:Show()
    -- 剩餘秒數每秒更新一次就夠（這只是清單，不是時間軸本身）
    StopTicker()
    ticker = C_Timer.NewTicker(1, function()
        if tab and tab:IsVisible() and tab.liveText then
            tab.liveText:SetText(LiveLines())
        else
            StopTicker()
        end
    end)
end)

ns.RegisterCallback("OptionsClosed", "generalTab", StopTicker)
