------------------------------------------------------------
-- 「確認倒數」分頁：顯示條件、左／中／右鍵各自的動作與倒數秒數
--
-- 資料在 db.readycheck（Config.lua 的 DB_DEFAULTS），每顆鍵是 sub2 那一層。
-- 巨集屬性由 ApplyAll → 方塊的 Update → ReadyCheck.ApplyBindings 重寫。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.ApplyAll()
    RefreshAll()
end

local function BuildControls()
    local RC = ns.ReadyCheck
    local actionItems = {}
    for _, action in ipairs(RC.ACTIONS) do
        actionItems[#actionItems + 1] = { value = action, text = RC.ActionLabel(action) }
    end

    local controls = {
        { type = "header", label = L["SECTION_READYCHECK"] },
        { type = "toggle", key = "onlyInGroup", sub = "readycheck", label = L["READYCHECK_ONLY_IN_GROUP"] },
        { type = "text",   label = L["READYCHECK_ONLY_IN_GROUP_DESC"] },

        { type = "header", label = L["SECTION_READYCHECK_BUTTONS"] },
        { type = "text",   label = L["READYCHECK_BUTTONS_DESC"] },
    }
    for _, b in ipairs(RC.BUTTONS) do
        controls[#controls + 1] = { type = "header", nested = true, label = L[b.label] }
        controls[#controls + 1] = {
            type = "dropdown", key = "action", sub = "readycheck", sub2 = b.key,
            label = L["READYCHECK_ACTION"], items = actionItems,
        }
        controls[#controls + 1] = {
            type = "slider", key = "seconds", sub = "readycheck", sub2 = b.key,
            label = L["READYCHECK_SECONDS"], min = RC.MIN_SECONDS, max = RC.MAX_SECONDS, step = 1,
        }
    end
    return controls
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["TAB_READYCHECK"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(), ctx)
end

ns.RegisterCallback("ShowOptionsTab", "readycheckTab", function(id)
    if id ~= "readycheck" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
