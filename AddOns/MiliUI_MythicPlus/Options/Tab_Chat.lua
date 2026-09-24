------------------------------------------------------------
-- 「聊天」分頁：插件會自己往隊伍頻道貼的東西
--
-- 結算的「發佈」不在這裡：那是玩家按了才送，格式在結算面板的發佈選單裡選
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function BuildSpecs()
    return {
        { type = "header", label = L["Party chat"] },
        { type = "toggle", sub = "announce", key = "keyReply", label = L["Answer \"key\""] },
        { type = "text", label = L["When someone types key or 鑰石 in party chat, post everyone's keystone. Only one MiliUI in the group answers."] },
        { type = "toggle", sub = "announce", key = "newKey", label = L["New keystone"] },
        { type = "text", label = L["Post your new keystone after finishing your own key, or after changing it at the keystone NPC."] },
        { type = "text", label = L["Blizzard blocks addon chat messages during Mythic+ runs, boss fights and PvP matches."] },
    }
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Chat"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db end, function() end)
    local _, built = ns.Options.BuildScrollBody(scroll, BuildSpecs(), ctx)
    refreshers = built
end

ns.Options.RegisterTab("chat", function(show)
    if not show then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
