------------------------------------------------------------
-- 「鑰石」分頁：畫在暴雪鑰石介面上的東西
--   鑰石視窗（放鑰石那一格）：UI/Keystone.lua
--   傳奇鑰石頁（地城格子那一頁）：UI/PartyKeystone.lua、UI/LootTable.lua
-- 會自己往聊天貼東西的在「聊天」分頁（Options/Tab_Chat.lua）
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

        { type = "header", label = L["Mythic+ page"] },
        { type = "toggle", sub = "keystone", key = "partyPanel", label = L["Party keystones"],
          hint = L["List everyone's keystone in the bottom-right corner, with a button to post it to party chat."] },
        { type = "toggle", sub = "keystone", key = "lootTable", label = L["Loot table"],
          hint = L["Show item levels and crests per key level beside the page. The button above its corner folds it away."] },
    }
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Keystone"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db end, function()
        ns.Keystone.Apply()
        ns.PartyKeystone.Apply()
        ns.LootTable.Apply()
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
