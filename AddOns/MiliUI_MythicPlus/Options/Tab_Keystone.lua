------------------------------------------------------------
-- 「鑰石」分頁：鑰石視窗上的兩個功能（UI/Keystone.lua）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function BuildSpecs()
    return {
        { type = "header", label = L["Keystone window"] },
        { type = "toggle", sub = "keystone", key = "autoSlot", label = L["Insert keystone"],
          hint = L["Put your keystone in the slot as soon as the window opens."] },
        { type = "toggle", sub = "keystone", key = "buttons", label = L["Ready check and countdown"],
          hint = L["Show a ready check and a countdown button under the window."] },
        { type = "slider", sub = "keystone", key = "countdown", label = L["Countdown seconds"],
          min = ns.Keystone.MIN_SECONDS, max = ns.Keystone.MAX_SECONDS, step = 1 },
        { type = "text", label = L["Ready check needs the group leader or an assistant."] },
    }
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Keystone"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db end, function()
        ns.Keystone.Apply()
    end)
    local _, built = ns.Options.BuildScrollBody(scroll, BuildSpecs(), ctx)
    refreshers = built
end

ns.Options.RegisterTab("keystone", function(show)
    if not show then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
