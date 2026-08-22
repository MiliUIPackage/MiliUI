------------------------------------------------------------
-- 「爆發巨集」分頁：那一行 /click 指令，唯讀但可整段選起來複製
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function BuildMacroRow(parent, x, y, width)
    local box = W.CreateCopyBox(parent, math.min(width, 320), 26,
        function() return ns.MACRO_LINE end, L["BTN_SELECT_ALL"])
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    return box.totalHeight + 10, function() box:Refresh() end
end

local CONTROLS = {
    { type = "header", label = L["SECTION_MACRO"] },
    { type = "text",   label = L["MACRO_HELP"] },
    { type = "custom", label = L["MACRO_LABEL"], build = BuildMacroRow },
    { type = "text",   label = L["COPY_HINT"] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["SECTION_MACRO"])
    -- 這一頁沒有任何 DB 欄位，ctx 只是 Controls.Build 的必要參數
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, function() RefreshAll() end)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "macroTab", function(id)
    if id ~= "macro" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
