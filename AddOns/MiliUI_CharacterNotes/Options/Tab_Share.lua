------------------------------------------------------------
-- 「分享」分頁
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function Apply()
    -- broadcast 這顆有副作用（開起來要立刻推一次），走 Sync 的入口而不是只寫 DB
    ns.Sync.SetBroadcast(ns.db.settings.share.broadcast)
    ns.Fire("SettingsChanged")
end

local ACCEPT_ITEMS = {
    { text = L["My group and my guild"], value = "group" },
    { text = L["Nobody"],                value = "none" },
}

local SYNC_ACCEPT_ITEMS = {
    { text = L["My group"], value = "group" },
    { text = L["Nobody"],   value = "none" },
}

local CONTROLS = {
    { type = "header", label = L["How sharing works"] },
    { type = "text", label = L["Right-click a note (or use the button in the editor) and pick who to share it with. Your group gets a chat line with a link; clicking it opens a preview, and nothing is saved until they press Save."] },
    { type = "text", label = L["People without this addon just see the line as ordinary text. Clicking it does nothing for them, and they never see a wall of gibberish."] },
    { type = "text", label = L["Dungeon and boss notes remember what they belong to, so they land in the right slot on the other side."] },

    { type = "header", label = L["Receiving"] },
    { type = "dropdown", sub = "share", key = "accept", label = L["Accept notes from"],
      items = ACCEPT_ITEMS },
    { type = "toggle", sub = "share", key = "autoOpen", label = L["Open the preview at once"],
      hint = L["Pop the preview open as soon as a note arrives, without waiting for me to click the link"] },

    { type = "header", label = L["Syncing (live)"] },
    { type = "text", label = L["Sharing hands someone a copy they own. Syncing is different: your dungeon and boss notes stay live on their screen and update whenever you change them — they never become theirs."] },
    { type = "toggle", sub = "share", key = "broadcast", label = L["Sync to my group"],
      hint = L["Push my dungeon and boss notes to the group and keep them updated"] },
    { type = "dropdown", sub = "share", key = "syncAccept", label = L["Accept synced notes from"],
      items = SYNC_ACCEPT_ITEMS },
    { type = "text", label = L["A synced note only shows up where you have not written your own — your own notes always win. It sits in memory and is gone when you leave the group or reload."] },

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
