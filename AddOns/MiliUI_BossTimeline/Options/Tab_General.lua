------------------------------------------------------------
-- 「一般」分頁：開關、要畫哪些來源、時間軸上現在有什麼
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
        seen[#seen + 1] = ns.Owners.Label(addon) .. " ×" .. n
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

local CONTROLS = {
    { type = "header", label = L["MiliUI Boss Timeline"] },
    { type = "toggle", sub = "display", key = "enabled", label = L["Draw the timeline with MiliUI"] },
    { type = "text", label = L["Off: Blizzard's timeline stays as it is. Custom timelines still run and still show which addon added what."] },
    { type = "toggle", sub = "display", key = "hideBlizzard", label = L["Hide Blizzard's timeline"],
      requires = { sub = "display", key = "enabled" } },
    { type = "text", label = L["Only the picture is hidden. Blizzard's sounds, and other addons' timeline sounds such as DBM countdowns, keep working."] },
    { type = "toggle", key = "previewOnScreen", label = L["Preview on screen while this window is open"] },

    { type = "header", label = L["Show entries from"] },
    { type = "toggle", sub = "display", sub2 = "sources", key = "blizzard", label = L["Blizzard (boss abilities)"] },
    { type = "toggle", sub = "display", sub2 = "sources", key = "mine",     label = L["My custom timelines"] },
    { type = "toggle", sub = "display", sub2 = "sources", key = "other",    label = L["Other addons"] },
    { type = "text", label = L["Other addons: anything written into Blizzard's timeline by an addon, such as DiGua Voice. DBM and BigWigs only read the timeline, so they don't show up here."] },

    { type = "header", label = L["On the timeline right now"] },
    { type = "custom", label = "", build = BuildLive },
    { type = "text", label = L["Blizzard hides boss ability names from addons during combat. The ones listed by name were recognized through DBM or the MRT timeline (see below)."] },

    { type = "header", label = L["Recognizing boss abilities in combat"] },
    { type = "toggle", sub = "identify", key = "dbm", label = L["Use DBM's recognition"] },
    { type = "text", label = L["When DBM recognizes a timeline entry, it announces the ability by name; this addon picks that up. Needs DBM with its boss modules."] },
    { type = "toggle", sub = "identify", key = "mrt", label = L["Guess from the MRT timeline"] },
    { type = "text", label = L["Matches the time into the fight against MRT's statistics for the same difficulty. Skipped when two abilities are too close to tell apart. DBM's answer wins when both are available."] },
    { type = "text", label = L["Recognized abilities are what make \"Hide on the timeline\" (Boss abilities tab) work, and let your last pull remember their names."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["General"])
    local ctx = ns.Options.MakeCtx(Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
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
