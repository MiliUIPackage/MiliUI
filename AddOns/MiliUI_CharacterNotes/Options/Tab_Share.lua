------------------------------------------------------------
-- 「分享」分頁
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function Apply()
    ns.Fire("SettingsChanged")
end

local ACCEPT_ITEMS = {
    { text = L["My group and my guild"], value = "group" },
    { text = L["Nobody"],                value = "none" },
}

local CONTROLS = {
    { type = "header", label = L["How sharing works"] },
    { type = "text", label = L["Right-click a note (or use the button in the editor) and pick who to share it with. Your group gets a chat line with a link; clicking it opens a preview, and nothing is saved until they press Save."] },
    { type = "text", label = L["People without this addon just see the line as ordinary text. Clicking it does nothing for them, and they never see a wall of gibberish."] },

    { type = "header", label = L["Receiving"] },
    { type = "dropdown", sub = "share", key = "accept", label = L["Accept notes from"],
      items = ACCEPT_ITEMS },
    { type = "toggle", sub = "share", key = "autoOpen", label = L["Open the preview at once"] },
    { type = "text", label = L["Pop the preview open as soon as a note arrives, without waiting for me to click the link"] },

    { type = "header", label = L["Good to know"] },
    { type = "text", label = L["The game blocks addon messages during a boss fight, a Mythic+ run and inside battlegrounds. Sharing during those will tell you to try again afterwards."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Sharing"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.settings end, Apply)
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "shareTab", function(id)
    if id ~= "share" then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
