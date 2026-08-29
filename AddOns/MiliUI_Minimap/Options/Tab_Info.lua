------------------------------------------------------------
-- 「資訊列」分頁：左右兩格放什麼、外觀、提示內容
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Specs = ns.Specs

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local CONTROLS = {
    { type = "toggle",   key = "infoBar", label = L["Show the info bar"] },
    { type = "text",     label = L["A single strip under the map, split into three slots. Left-click a slot for its whisper / invite menu, right-click to open the full panel, hover for the list."] },

    { type = "header",   label = L["Contents"] },
    { type = "dropdown", key = "infoSlot1", label = L["Slot 1"], items = Specs.INFO_SOURCES },
    { type = "dropdown", key = "infoSlot2", label = L["Slot 2"], items = Specs.INFO_SOURCES },
    { type = "dropdown", key = "infoSlot3", label = L["Slot 3"], items = Specs.INFO_SOURCES },
    { type = "text",     label = L["The addon-button slot is a fixed square; the others split whatever width is left evenly. A slot set to \"Nothing\" takes up no space at all, so the rest fill the bar."] },
    { type = "text",     label = L["If no slot shows the addon buttons, the bag has no way to open — /mmap bag still works."] },

    { type = "header",   label = L["Appearance"] },
    { type = "toggle",   key = "infoBarAttached", label = L["Stick to the bottom of the map"] },
    { type = "text",     label = L["Unstick it to place the bar somewhere else; it keeps the map's width."] },
    { type = "numbers",  label = L["Position"], fields = {
        { key = "infoBarX", label = L["X"] },
        { key = "infoBarY", label = L["Y"] },
    } },
    { type = "slider",   key = "infoBarHeight", label = L["Height"], min = 12, max = 30, step = 1 },
    { type = "slider",   key = "infoBarGap",    label = L["Gap below the map"], min = 0, max = 12, step = 1 },
    { type = "slider",   key = "infoBarFontSize", label = L["Font size"], min = 8, max = 18, step = 1 },
    { type = "toggle",   key = "infoAccentNumbers", label = L["Numbers use your class colour"] },
    { type = "text",     label = L["Labels stay white either way. Colour carries \"what this is\"; the number is the part that changes, so it gets the accent."] },

    { type = "header",   label = L["Hover list"] },
    { type = "toggle",   key = "tipShowZone", label = L["Show each player's zone"] },
    { type = "text",     label = L["People in your current zone are marked green."] },
    { type = "slider",   key = "tipMaxRows", label = L["Maximum rows"], min = 5, max = 60, step = 5 },
    { type = "text",     label = L["The list is read live when you hover, so nothing is tracked in the background. Past about thirty rows you are searching rather than glancing — that is what the guild panel is for."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Info bar"])
    local ctx = ns.Options.MakeCtx()
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "infoTab", function(id)
    if id ~= "info" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
